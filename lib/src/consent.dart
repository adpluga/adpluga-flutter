import 'package:meta/meta.dart';

@immutable
class ConsentState {
  const ConsentState({
    this.gdpr = false,
    this.tcfString,
    this.uspString,
    this.gppString,
    this.adPersonalization = true,
    this.limitedTracking = false,
  });

  final bool gdpr;
  final String? tcfString;
  final String? uspString;
  final String? gppString;
  final bool adPersonalization;
  final bool limitedTracking;

  bool get isPersonalized => adPersonalization && !limitedTracking;

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
