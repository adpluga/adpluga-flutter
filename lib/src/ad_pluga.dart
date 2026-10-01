import 'dart:async';
import 'dart:math';

import 'package:meta/meta.dart';

import 'client/transport.dart';
import 'consent.dart';
import 'constants.dart';
import 'errors.dart';
import 'events.dart';
import 'features/features_cache.dart';
import 'logger.dart';
import 'models/features.dart';
import 'models/serve_response.dart';
import 'telemetry/telemetry.dart';

/// Settings the [AdPluga] instance was initialized with.
///
/// Built by [AdPluga.initialize] and exposed as [AdPluga.config].
@immutable
class AdPlugaConfig {
  /// Creates a configuration. [endpoint] defaults to [kDefaultEndpoint].
  const AdPlugaConfig({
    required this.publisherKey,
    this.endpoint = kDefaultEndpoint,
    this.consent = const ConsentState(),
    this.telemetryEnabled = true,
  });

  /// Publisher key, starting with `pk_live_` or `pk_test_`.
  final String publisherKey;

  /// Base URL of the AdPluga API, without a trailing slash once normalized
  /// by [AdPluga.initialize].
  final String endpoint;

  /// Consent state passed at initialization.
  final ConsentState consent;

  /// Whether SDK telemetry may be sent. The remote `sdk_telemetry` flag can
  /// still turn it off, but never on when this is false.
  final bool telemetryEnabled;
}

/// Called once the server answers a serve request with HTTP 426, with the
/// minimum SDK version it requires.
typedef UpgradeRequiredHandler = void Function(String minVersion);

/// Entry point of the SDK: a process-wide singleton that requests ads and
/// reports their events.
///
/// Create it with [initialize] and reach it later through [instance]. The ad
/// widgets (`AdPlugaBanner`, `AdPlugaNative`) and the full-screen formats
/// (`InterstitialAd`, `RewardedAd`) call [serve] and the `fire*` methods for
/// you; call them directly only when rendering ads yourself.
class AdPluga {
  AdPluga._({
    required this.config,
    required Transport transport,
    required ConsentStore consentStore,
    required FeaturesCache features,
    required TelemetryBatcher telemetry,
  })  : _transport = transport,
        _consent = consentStore,
        _features = features,
        _telemetry = telemetry;

  static AdPluga? _instance;

  /// The initialized instance, or null before [initialize] or after
  /// [destroy].
  static AdPluga? get maybeInstance => _instance;

  /// The initialized instance.
  ///
  /// Throws [NotInitializedError] if [initialize] has not completed.
  static AdPluga get instance {
    final s = _instance;
    if (s == null) throw const NotInitializedError();
    return s;
  }

  /// Configuration this instance was initialized with.
  final AdPlugaConfig config;

  /// True while running against a sandbox key. Clients use it for the cadence
  /// floor before any response has arrived.
  bool get isTestKey => config.publisherKey.startsWith('pk_test_');
  final Transport _transport;
  final ConsentStore _consent;
  String? _installId;
  final FeaturesCache _features;
  final TelemetryBatcher _telemetry;
  final StreamController<SdkEvent> _events =
      StreamController<SdkEvent>.broadcast();

  bool _upgradeBlocked = false;
  String _upgradeMinVersion = '';
  UpgradeRequiredHandler? _onUpgradeRequired;

  /// Broadcast stream of [SdkEvent]s emitted by this instance. Closed by
  /// [destroy].
  Stream<SdkEvent> get events => _events.stream;

  /// Current consent state, as last set by [initialize] or [setConsent].
  ConsentState get consentState => _consent.state;

  /// First-party install id used for frequency capping and first-party
  /// audiences. Only released when the current consent state allows
  /// personalisation; without it the request carries no user at all and the
  /// server skips both gates. Held in memory for the process lifetime — pass
  /// `userHash` explicitly to key the daily cap across app launches.
  String? _resolvedUserId() {
    if (!_consent.state.isPersonalized) return null;
    return _installId ??= _randomId();
  }

  static String _randomId() {
    final rnd = Random.secure();
    const hex = '0123456789abcdef';
    final buf = StringBuffer();
    for (var i = 0; i < 32; i++) {
      buf.write(hex[rnd.nextInt(16)]);
    }
    return buf.toString();
  }

  /// Latest remote feature flags, or [FeaturesView.empty] until the first
  /// successful fetch.
  FeaturesView get featuresValue => _features.value;

  /// Whether the server has demanded an SDK upgrade. Once true, [serve]
  /// returns null without making a request.
  bool get isUpgradeBlocked => _upgradeBlocked;

  /// Creates the singleton instance and starts fetching remote features.
  ///
  /// [publisherKey] must start with `pk_live_` or `pk_test_`, otherwise an
  /// [InvalidKeyError] is thrown. [endpoint] defaults to [kDefaultEndpoint];
  /// trailing slashes are removed. [onUpgradeRequired] is called when the
  /// server rejects this SDK version.
  ///
  /// Calling it again with the same key returns the existing instance; with a
  /// different key it throws [AlreadyInitializedError]. Call [destroy] first
  /// to re-initialize.
  static Future<AdPluga> initialize({
    required String publisherKey,
    String? endpoint,
    ConsentState consent = const ConsentState(),
    bool telemetryEnabled = true,
    UpgradeRequiredHandler? onUpgradeRequired,
  }) async {
    if (!_isValidKey(publisherKey)) {
      throw const InvalidKeyError(
          'publisherKey must start with pk_live_ or pk_test_');
    }
    final normalizedEndpoint = _normalizeEndpoint(endpoint ?? kDefaultEndpoint);
    final existing = _instance;
    if (existing != null) {
      // Rotating a key revokes the previous one at once, so silently keeping
      // the old instance would leave the app serving with a dead key and no
      // way to notice. Same key: the call is idempotent as before.
      if (existing.config.publisherKey != publisherKey) {
        throw AlreadyInitializedError(
            existing.config.publisherKey, publisherKey);
      }
      return existing;
    }
    final consentStore = ConsentStore(consent);
    final transport = Transport(
      endpoint: normalizedEndpoint,
      publisherKey: publisherKey,
    );
    final features = FeaturesCache(transport);
    final telemetry = TelemetryBatcher(transport)..setEnabled(telemetryEnabled);
    final ad = AdPluga._(
      config: AdPlugaConfig(
        publisherKey: publisherKey,
        endpoint: normalizedEndpoint,
        consent: consent,
        telemetryEnabled: telemetryEnabled,
      ),
      transport: transport,
      consentStore: consentStore,
      features: features,
      telemetry: telemetry,
    );
    ad._onUpgradeRequired = onUpgradeRequired;
    features.addListener(ad._onFeaturesUpdated);
    features.start();
    telemetry.record(SdkEventType.init);
    _instance = ad;
    logger.info('sdk initialized');
    ad._emit(const InitCompletedEvent());
    return ad;
  }

  /// Requests an ad for [slotId].
  ///
  /// [format] narrows the requested creative format. [userHash] identifies
  /// the user for frequency capping and first-party audiences; when omitted,
  /// an in-memory install id is sent only if [consentState] allows
  /// personalisation. [refreshSeq] is the rotation count of the slot, 0 for
  /// the first load.
  ///
  /// Returns null instead of throwing when the request fails or an upgrade is
  /// required; the failure is reported on [events] as an [AdFailedEvent] or
  /// [UpgradeRequiredSdkEvent].
  Future<ServeResponse?> serve({
    required String slotId,
    String? format,
    String? userHash,
    int refreshSeq = 0,
  }) async {
    if (_upgradeBlocked) return null;
    final start = DateTime.now();
    try {
      final resp = await _transport.serve(
        slotId: slotId,
        format: format,
        userHash: userHash ?? _resolvedUserId(),
        nonPersonalized: !_consent.state.isPersonalized,
        gdprApplies: _consent.state.gdpr ? true : null,
        consentString: _consent.state.tcfString,
        refreshSeq: refreshSeq,
      );
      final latency = DateTime.now().difference(start).inMilliseconds;
      _telemetry.record(SdkEventType.serveRequest, latencyMs: latency);
      _emit(AdServedEvent(slotId: slotId, response: resp));
      return resp;
    } on UpgradeRequiredError catch (e) {
      _upgradeBlocked = true;
      _upgradeMinVersion = e.minVersion;
      _telemetry.record(SdkEventType.upgradeRequired);
      _emit(UpgradeRequiredSdkEvent(minVersion: e.minVersion));
      final cb = _onUpgradeRequired;
      if (cb != null) {
        try {
          cb(e.minVersion);
        } catch (_) {}
      }
      logger.error('upgrade required min=${e.minVersion}');
      return null;
    } on AdPlugaError catch (e) {
      _telemetry.record(SdkEventType.error);
      _emit(AdFailedEvent(slotId: slotId, message: e.message));
      logger.warn('serve failed', e);
      return null;
    }
  }

  /// Reports an impression for [resp], served for [slotId].
  ///
  /// Uses [ServeResponse.impressionUrl] when present, otherwise posts the
  /// track token. Emits an [ImpressionEvent].
  void fireImpression(ServeResponse resp, String slotId) {
    final url = resp.impressionUrl;
    if (url != null && url.isNotEmpty) {
      unawaited(_transport.beacon(url));
    } else {
      unawaited(_transport.track(event: 'impression', token: resp.trackToken));
    }
    for (final tracker in resp.ad.impressionTrackers) {
      unawaited(_transport.beacon(tracker));
    }
    _telemetry.record(SdkEventType.impression);
    _emit(ImpressionEvent(slotId: slotId, source: resp.source));
  }

  /// Reports that [resp] met the viewability threshold.
  ///
  /// Fires the ad's [Ad.billingUrl] when present (mediation fills) and posts
  /// the track token to the viewable endpoint when there is one.
  void fireViewable(ServeResponse resp, String slotId) {
    // Mediation fills carry no AdPluga track token: the billable impression is
    // reported to the bidder by firing its burl once. First-party fills report
    // the viewable to /track/viewable instead.
    final billingUrl = resp.ad.billingUrl;
    if (billingUrl != null && billingUrl.isNotEmpty) {
      unawaited(_transport.beacon(billingUrl));
    }
    if (resp.trackToken.isNotEmpty) {
      unawaited(_transport.trackViewable(token: resp.trackToken));
    }
  }

  /// Reports a click on [resp] through [ServeResponse.clickUrl] and emits a
  /// [ClickEvent].
  ///
  /// The click is dropped, with a warning logged, when the response carries
  /// no click URL. This does not open the advertiser destination.
  void fireClick(ServeResponse resp, String slotId) {
    // Only click_url carries the click token; track_token is the impression
    // one, so there is no honest fallback — reporting it would bill a click
    // as an impression.
    final url = resp.clickUrl;
    if (url != null && url.isNotEmpty) {
      unawaited(_transport.beacon(url));
    } else {
      logger.warn('click dropped: serve response carried no click url');
    }
    for (final tracker in resp.ad.clickTrackers) {
      unawaited(_transport.beacon(tracker));
    }
    _telemetry.record(SdkEventType.click);
    _emit(ClickEvent(slotId: slotId, source: resp.source));
  }

  /// Reports a conversion against the token handed out with the ad.
  /// [valueCents] and [convType] map onto the wire fields of the same name;
  /// [type] and [value] are the previous names, kept working.
  Future<void> conversion({
    required String token,
    String? convType,
    int? valueCents,
    String? currency,
    @Deprecated('Use convType') String? type,
    @Deprecated('Use valueCents') num? value,
  }) async {
    final extra = <String, Object?>{};
    final resolvedType = convType ?? type;
    if (resolvedType != null) extra['conv_type'] = resolvedType;
    final resolvedValue = valueCents ?? value?.round();
    if (resolvedValue != null) extra['value_cents'] = resolvedValue;
    if (currency != null) extra['currency'] = currency;
    await _transport.track(event: 'conversion', token: token, extra: extra);
  }

  /// Replaces the consent state used by later [serve] calls and emits a
  /// [ConsentChangedEvent].
  void setConsent(ConsentState next) {
    _consent.set(next);
    _emit(ConsentChangedEvent(next));
  }

  /// Fetches remote features, sharing a fetch already in flight. Failures are
  /// logged, not thrown.
  Future<void> ensureFeatures() => _features.ensure();

  /// Sends any buffered telemetry now.
  Future<void> flushTelemetry() => _telemetry.flush();

  /// Stops background work, closes [events] and releases the singleton so
  /// [initialize] can be called again.
  Future<void> destroy() async {
    _features.removeListener(_onFeaturesUpdated);
    _features.dispose();
    _telemetry.dispose();
    _consent.dispose();
    _transport.close();
    await _events.close();
    if (identical(_instance, this)) _instance = null;
  }

  void _onFeaturesUpdated(FeaturesView view) {
    final telemetryFlag = view.flag('sdk_telemetry', fallback: true);
    _telemetry.setEnabled(telemetryFlag && config.telemetryEnabled);
    _emit(FeaturesUpdatedEvent(view));
  }

  void _emit(SdkEvent e) {
    if (_events.isClosed) return;
    _events.add(e);
  }

  static bool _isValidKey(String key) {
    return key.startsWith('pk_live_') || key.startsWith('pk_test_');
  }

  static String _normalizeEndpoint(String value) {
    var v = value.trim();
    while (v.endsWith('/')) {
      v = v.substring(0, v.length - 1);
    }
    return v;
  }

  /// Minimum SDK version demanded by the server, or an empty string if no
  /// upgrade has been required.
  String get upgradeMinVersion => _upgradeMinVersion;
}
