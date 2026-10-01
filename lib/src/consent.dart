import 'package:meta/meta.dart';

/// User consent signals held by the SDK.
///
/// Pass one to `AdPluga.initialize` or `AdPluga.setConsent`, usually filled
/// from your consent management platform. [gdpr] and [tcfString] are sent with
/// every ad request and forwarded to mediation networks; [adPersonalization]
/// and [limitedTracking] decide, through [isPersonalized], whether a user id
/// is sent. [uspString] and [gppString] are kept but not transmitted.
@immutable
class ConsentState {
  /// Creates a consent state. By default personalisation is allowed and
  /// tracking is not limited.
  const ConsentState({
    this.gdpr = false,
    this.tcfString,
    this.uspString,
    this.gppString,
    this.adPersonalization = true,
    this.limitedTracking = false,
  });

  /// Whether GDPR applies to this user. `true` is sent as `gdpr=1`; `false`
  /// means not stated, and nothing is sent.
  final bool gdpr;

  /// IAB TCF v2 consent string, sent in the `X-Consent-String` header.
  final String? tcfString;

  /// IAB US Privacy (CCPA) string.
  final String? uspString;

  /// IAB Global Privacy Platform string.
  final String? gppString;

  /// Whether the user allows personalised ads.
  final bool adPersonalization;

  /// Whether the platform reports limited ad tracking.
  final bool limitedTracking;

  /// True when [adPersonalization] is allowed and [limitedTracking] is off.
  ///
  /// When false, serve requests are flagged non-personalised and carry no
  /// SDK-generated user id.
  bool get isPersonalized => adPersonalization && !limitedTracking;

  /// Returns a copy with the given fields replaced. A null argument keeps the
  /// current value, so a consent string cannot be cleared this way.
  ConsentState copyWith({
    bool? gdpr,
    String? tcfString,
    String? uspString,
    String? gppString,
    bool? adPersonalization,
    bool? limitedTracking,
  }) {
    return ConsentState(
      gdpr: gdpr ?? this.gdpr,
      tcfString: tcfString ?? this.tcfString,
      uspString: uspString ?? this.uspString,
      gppString: gppString ?? this.gppString,
      adPersonalization: adPersonalization ?? this.adPersonalization,
      limitedTracking: limitedTracking ?? this.limitedTracking,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ConsentState &&
        other.gdpr == gdpr &&
        other.tcfString == tcfString &&
        other.uspString == uspString &&
        other.gppString == gppString &&
        other.adPersonalization == adPersonalization &&
        other.limitedTracking == limitedTracking;
  }

  @override
  int get hashCode => Object.hash(
        gdpr,
        tcfString,
        uspString,
        gppString,
        adPersonalization,
        limitedTracking,
      );
}

typedef ConsentListener = void Function(ConsentState state);

class ConsentStore {
  ConsentStore([ConsentState? initial])
      : _state = initial ?? const ConsentState();

  ConsentState _state;
  final Set<ConsentListener> _listeners = <ConsentListener>{};

  ConsentState get state => _state;

  void set(ConsentState next) {
    if (next == _state) return;
    _state = next;
    for (final l in _listeners.toList(growable: false)) {
      try {
        l(next);
      } catch (_) {
        // isolate a listener crash from the store
      }
    }
  }

  void addListener(ConsentListener listener) => _listeners.add(listener);
  void removeListener(ConsentListener listener) => _listeners.remove(listener);
  void dispose() => _listeners.clear();
}
