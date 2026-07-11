import 'dart:async';

import '../client/transport.dart';
import '../constants.dart';
import '../logger.dart';
import '../models/features.dart';

typedef FeaturesListener = void Function(FeaturesView view);

class FeaturesCache {
  FeaturesCache(this._transport);

  final Transport _transport;

  FeaturesView _view = FeaturesView.empty;
  String? _etag;
  Timer? _timer;
  Future<void>? _inflight;
  final Set<FeaturesListener> _listeners = <FeaturesListener>{};

  FeaturesView get value => _view;

  void addListener(FeaturesListener listener) => _listeners.add(listener);
  void removeListener(FeaturesListener listener) => _listeners.remove(listener);

  Future<void> ensure() {
    return _inflight ??= _refresh().whenComplete(() => _inflight = null);
  }

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(kFeaturesRevalidate, (_) {
      unawaited(_refresh());
    });
    unawaited(ensure());
  }

  Future<void> _refresh() async {
    try {
      final result = await _transport.features(etag: _etag);
      if (result.notModified) return;
      final next = result.view;
      if (next == null) return;
      _etag = result.etag;
      _view = next;
      for (final l in _listeners.toList(growable: false)) {
        try {
          l(next);
        } catch (_) {
          // isolate listener crashes
        }
      }
    } catch (e) {
      logger.warn('features refresh failed', e);
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _listeners.clear();
  }
}
