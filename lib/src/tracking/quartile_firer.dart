import 'dart:async';

import 'package:http/http.dart' as http;

class QuartileFirer {
  QuartileFirer(this._pings, {http.Client? client})
      : _client = client ?? http.Client();

  final Map<String, String>? _pings;
  final http.Client _client;
  final Set<String> _fired = <String>{};

  static const List<_Threshold> _thresholds = <_Threshold>[
    _Threshold('start', 0.0),
    _Threshold('first_quartile', 0.25),
    _Threshold('midpoint', 0.5),
    _Threshold('third_quartile', 0.75),
    _Threshold('complete', 1.0),
  ];

  void update({required int positionMs, required int durationMs}) {
    final pings = _pings;
    if (pings == null || pings.isEmpty || durationMs <= 0) return;
    for (final t in _thresholds) {
      if (_fired.contains(t.key)) continue;
      final threshold = (durationMs * t.ratio).round();
      if (positionMs < threshold) continue;
      final url = pings[t.key];
      _fired.add(t.key);
      if (url == null || url.isEmpty) continue;
      unawaited(_fire(url));
    }
  }

  void reset() => _fired.clear();

  Future<void> _fire(String url) async {
    try {
      await _client.get(Uri.parse(url)).timeout(const Duration(seconds: 3));
    } catch (_) {}
  }
}

class _Threshold {
  const _Threshold(this.key, this.ratio);
  final String key;
  final double ratio;
}
