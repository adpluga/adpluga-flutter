import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../constants.dart';

typedef RenderBoxProvider = RenderBox? Function();

class _TrackedSlot {
  _TrackedSlot(this.provider, this.onViewable);

  final RenderBoxProvider provider;
  final VoidCallback onViewable;
  Duration accumulated = Duration.zero;
  bool fired = false;
}

class VisibilityTracker {
  VisibilityTracker._();

  static final VisibilityTracker instance = VisibilityTracker._();

  final Map<int, _TrackedSlot> _slots = <int, _TrackedSlot>{};
  Timer? _timer;
  int _nextHandle = 0;
  DateTime? _lastTick;

  int register(RenderBoxProvider provider, VoidCallback onViewable) {
    final handle = ++_nextHandle;
    _slots[handle] = _TrackedSlot(provider, onViewable);
    _ensureTicking();
    return handle;
  }

  void unregister(int handle) {
    _slots.remove(handle);
    if (_slots.isEmpty) {
      _timer?.cancel();
      _timer = null;
      _lastTick = null;
    }
  }

  /// Whether the box currently meets the IAB pixel threshold. Used by the
  /// refresh scheduler so a rotation never happens off-screen (MRC counts
  /// out-of-view auto-refresh as non-viewable).
  bool isVisible(RenderBoxProvider provider) {
    return _visibleRatio(provider.call(), _currentViewSize()) >=
        kViewabilityThreshold;
  }

  double _visibleRatio(RenderBox? box, Rect view) {
    if (box == null || !box.attached || !box.hasSize) return 0;
    final size = box.size;
    if (size.isEmpty) return 0;
    final topLeft = box.localToGlobal(Offset.zero);
    final rect = Rect.fromLTWH(topLeft.dx, topLeft.dy, size.width, size.height);
    final visible = rect.intersect(view);
    final visibleArea = visible.isEmpty ? 0 : visible.width * visible.height;
    final totalArea = size.width * size.height;
    return totalArea > 0 ? visibleArea / totalArea : 0.0;
  }

  void _ensureTicking() {
    if (_timer != null) return;
    _lastTick = DateTime.now();
    _timer = Timer.periodic(kViewabilityTick, (_) => _tick());
  }

  void _tick() {
    if (_slots.isEmpty) return;
    final now = DateTime.now();
    final elapsed = now.difference(_lastTick ?? now);
    _lastTick = now;

    final view = _currentViewSize();
    final toFire = <VoidCallback>[];
    final toDrop = <int>[];

    _slots.forEach((handle, slot) {
      if (slot.fired) return;
      final ratio = _visibleRatio(slot.provider.call(), view);
      if (ratio >= kViewabilityThreshold) {
        slot.accumulated += elapsed;
        if (slot.accumulated >= kViewabilityDwell) {
          slot.fired = true;
          toFire.add(slot.onViewable);
          toDrop.add(handle);
        }
      } else {
        slot.accumulated = Duration.zero;
      }
    });

    for (final h in toDrop) {
      _slots.remove(h);
    }
    for (final f in toFire) {
      try {
        f();
      } catch (_) {
        // isolate handler crash
      }
    }
    if (_slots.isEmpty) {
      _timer?.cancel();
      _timer = null;
      _lastTick = null;
    }
  }

  Rect _currentViewSize() {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final ui.Size physical = view.physicalSize;
    final double dpr = view.devicePixelRatio == 0 ? 1.0 : view.devicePixelRatio;
    return Rect.fromLTWH(0, 0, physical.width / dpr, physical.height / dpr);
  }
}
