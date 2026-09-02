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

@immutable
class AdPlugaConfig {
  const AdPlugaConfig({
    required this.publisherKey,
    this.endpoint = kDefaultEndpoint,
    this.consent = const ConsentState(),
    this.telemetryEnabled = true,
  });

  final String publisherKey;
  final String endpoint;
  final ConsentState consent;
  final bool telemetryEnabled;
}

typedef UpgradeRequiredHandler = void Function(String minVersion);

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

  static AdPluga? get maybeInstance => _instance;

  static AdPluga get instance {
    final s = _instance;
    if (s == null) throw const NotInitializedError();
    return s;
  }

  final AdPlugaConfig config;
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

  Stream<SdkEvent> get events => _events.stream;
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
  FeaturesView get featuresValue => _features.value;
  bool get isUpgradeBlocked => _upgradeBlocked;

  static Future<AdPluga> initialize({
    required String publisherKey,
    String endpoint = kDefaultEndpoint,
    ConsentState consent = const ConsentState(),
    bool telemetryEnabled = true,
    UpgradeRequiredHandler? onUpgradeRequired,
  }) async {
    if (_instance != null) return _instance!;
    if (!_isValidKey(publisherKey)) {
      throw const InvalidKeyError(
          'publisherKey must start with pk_live_ or pk_test_');
    }
    final normalizedEndpoint = _normalizeEndpoint(endpoint);
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

  void fireImpression(ServeResponse resp, String slotId) {
    final url = resp.impressionUrl;
    if (url != null && url.isNotEmpty) {
      unawaited(_transport.beacon(url));
    } else {
      unawaited(_transport.track(event: 'impression', token: resp.trackToken));
    }
    _telemetry.record(SdkEventType.impression);
    _emit(ImpressionEvent(slotId: slotId, source: resp.source));
  }

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

  void setConsent(ConsentState next) {
    _consent.set(next);
    _emit(ConsentChangedEvent(next));
  }

  Future<void> ensureFeatures() => _features.ensure();

  Future<void> flushTelemetry() => _telemetry.flush();

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

  String get upgradeMinVersion => _upgradeMinVersion;
}
