import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../constants.dart';

typedef RenderBoxProvider = RenderBox? Function();

/// Reports whether the host still allows the slot to paint. Geometry alone
/// cannot answer this: a widget inside a hidden [IndexedStack] page keeps its
/// position and size, so an impression would be counted for an ad nobody sees.
typedef PaintScopeProbe = bool Function();

class _TrackedSlot {
  _TrackedSlot(this.provider, this.onViewable, this.isPainting);

  final RenderBoxProvider provider;
  final VoidCallback onViewable;
  final PaintScopeProbe? isPainting;
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

  int register(
    RenderBoxProvider provider,
    VoidCallback onViewable, {
    PaintScopeProbe? isPainting,
  }) {
    final handle = ++_nextHandle;
    _slots[handle] = _TrackedSlot(provider, onViewable, isPainting);
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
  bool isVisible(RenderBoxProvider provider, {PaintScopeProbe? isPainting}) {
    if (isPainting != null && !isPainting.call()) return false;
    return _visibleRatio(provider.call(), _currentViewSize()) >=
        kViewabilityThreshold;
  }

  double _visibleRatio(RenderBox? box, Rect view) {
    if (box == null || !box.attached || !box.hasSize) return 0;
    final size = box.size;
    if (size.isEmpty) return 0;
    final topLeft = box.localToGlobal(Offset.zero);
    final rect = _clippedByAncestors(
      box,
      Rect.fromLTWH(topLeft.dx, topLeft.dy, size.width, size.height),
    );
    final visible = rect.intersect(view);
    final visibleArea = visible.isEmpty ? 0 : visible.width * visible.height;
    // The denominator stays the full box: a slot half-hidden by a scroll
    // viewport is half viewable, not fully viewable within what is left.
    final totalArea = size.width * size.height;
    return totalArea > 0 ? visibleArea / totalArea : 0.0;
  }

  /// Narrows [rect] by every clip an ancestor applies while painting. A box
  /// laid out at full size inside a collapsed viewport keeps valid geometry,
  /// so intersecting with the screen alone reports it fully viewable.
  ///
  /// [RenderObject.describeApproximatePaintClip] is the framework's own answer
  /// to "would this child be clipped", used by the semantics phase for the
  /// same reason. Walks to the root: O(tree depth), a few dozen nodes, once
  /// per slot per tick.
  Rect _clippedByAncestors(RenderBox box, Rect rect) {
    var out = rect;
    RenderObject child = box;
    var parent = child.parent;
    while (parent != null) {
      final clip = parent.describeApproximatePaintClip(child);
      if (clip != null && parent is RenderBox && parent.hasSize) {
        final origin = parent.localToGlobal(clip.topLeft);
        out = out.intersect(
          Rect.fromLTWH(origin.dx, origin.dy, clip.width, clip.height),
        );
        if (out.isEmpty) return Rect.zero;
      }
      child = parent;
      parent = parent.parent;
    }
    return out;
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
      final probe = slot.isPainting;
      if (probe != null && !probe.call()) {
        slot.accumulated = Duration.zero;
        return;
      }
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
