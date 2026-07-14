import 'dart:async';
import 'dart:math' as math;

import '../client/transport.dart';
import '../constants.dart';
import '../logger.dart';

enum SdkEventType {
  init,
  serveRequest,
  impression,
  click,
  error,
  upgradeRequired
}

String _serializeEventType(SdkEventType e) {
  switch (e) {
    case SdkEventType.init:
      return 'init';
    case SdkEventType.serveRequest:
      return 'serve_request';
    case SdkEventType.impression:
      return 'impression';
    case SdkEventType.click:
      return 'click';
    case SdkEventType.error:
      return 'error';
    case SdkEventType.upgradeRequired:
      return 'upgrade_required';
  }
}

class _Bucket {
  int count = 0;
  final List<int> latencies = <int>[];
}

class TelemetryBatcher {
  TelemetryBatcher(this._transport, {math.Random? random})
      : _random = random ?? math.Random();

  final Transport _transport;
  final math.Random _random;

  final Map<SdkEventType, _Bucket> _buckets = <SdkEventType, _Bucket>{};
  int _pendingCount = 0;
  Timer? _timer;
  bool _enabled = false;
  bool _disposed = false;
  Future<void>? _inflight;

  void setEnabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    if (_disposed) return;
    if (value) {
      _timer?.cancel();
      _timer =
          Timer.periodic(kTelemetryFlushInterval, (_) => unawaited(flush()));
    } else {
      _timer?.cancel();
      _timer = null;
      _reset();
    }
  }

  void record(SdkEventType type, {int? latencyMs}) {
    if (!_enabled || _disposed) return;
    final bucket = _buckets.putIfAbsent(type, _Bucket.new);
    bucket.count++;
    if (latencyMs != null && latencyMs >= 0) {
      if (bucket.latencies.length < kTelemetryLatencySampleCap) {
        bucket.latencies.add(latencyMs);
      } else {
        final idx = _random.nextInt(bucket.count);
        if (idx < kTelemetryLatencySampleCap) {
          bucket.latencies[idx] = latencyMs;
        }
      }
    }
    _pendingCount++;
    if (_pendingCount >= kTelemetryFlushOnCount) {
      unawaited(flush());
    }
  }

  Future<void> flush() {
    return _inflight ??= _drain().whenComplete(() => _inflight = null);
  }

  Future<void> _drain() async {
    if (_buckets.isEmpty) return;
    final events = <Map<String, Object?>>[];
    _buckets.forEach((type, bucket) {
      if (bucket.count == 0) return;
      final entry = <String, Object?>{
        'platform': kSdkPlatform,
        'sdk_version': kSdkVersion,
        'event_type': _serializeEventType(type),
        'count': bucket.count,
      };
      if (bucket.latencies.isNotEmpty) {
        final sorted = List<int>.from(bucket.latencies)..sort();
        entry['latency_p50_ms'] = _percentile(sorted, 0.5);
        entry['latency_p95_ms'] = _percentile(sorted, 0.95);
        entry['latency_p99_ms'] = _percentile(sorted, 0.99);
      }
      events.add(entry);
      if (events.length >= kTelemetryMaxEventsPerBatch) return;
    });
    _reset();
    if (events.isEmpty) return;
    final body = <String, Object?>{
      'nonce': _newNonce(),
      'events': events,
    };
    try {
      await _transport.postTelemetry(body);
    } catch (e) {
      logger.warn('telemetry flush error', e);
    }
  }

  void _reset() {
    _buckets.clear();
    _pendingCount = 0;
  }

  int _percentile(List<int> sortedAsc, double p) {
    if (sortedAsc.isEmpty) return 0;
    final rank = (sortedAsc.length - 1) * p;
    final lo = rank.floor();
    final hi = rank.ceil();
    if (lo == hi) return sortedAsc[lo];
    final loVal = sortedAsc[lo];
    final hiVal = sortedAsc[hi];
    final frac = rank - lo;
    return (loVal + (hiVal - loVal) * frac).round();
  }

  String _newNonce() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    final buf = StringBuffer();
    for (final b in bytes) {
      buf.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return buf.toString();
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    unawaited(flush());
  }
}
