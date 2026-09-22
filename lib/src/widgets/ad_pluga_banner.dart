import 'dart:async';

import 'package:flutter/material.dart';

import '../ad_pluga.dart';
import 'ad_label.dart';
import '../constants.dart';
import '../errors.dart';
import '../logger.dart';
import '../models/serve_response.dart';
import '../viewability/visibility_tracker.dart';
import 'ad_pluga_carousel.dart';
import 'click_through.dart';
import 'ad_pluga_html.dart';
import 'ad_pluga_video.dart';
import 'test_badge.dart';

typedef AdPlugaErrorHandler = void Function(AdPlugaError error);
typedef AdPlugaImpressionHandler = void Function();
typedef AdPlugaClickHandler = void Function();

class AdPlugaBanner extends StatefulWidget {
  const AdPlugaBanner({
    super.key,
    required this.slotId,
    this.format,
    this.width,
    this.height,
    this.onImpression,
    this.onClick,
    this.onError,
    this.placeholder,
  });

  final String slotId;
  final String? format;
  final double? width;
  final double? height;
  final AdPlugaImpressionHandler? onImpression;
  final AdPlugaClickHandler? onClick;
  final AdPlugaErrorHandler? onError;
  final Widget? placeholder;

  @override
  State<AdPlugaBanner> createState() => _AdPlugaBannerState();
}

class _AdPlugaBannerState extends State<AdPlugaBanner>
    with WidgetsBindingObserver {
  ServeResponse? _response;
  int? _visibilityHandle;
  bool _clickFired = false;
  bool _disposed = false;
  Timer? _refreshTimer;
  int _refreshSeq = 0;
  bool _foreground = true;
  DateTime? _lastDeckInteraction;
  int _fillFailures = 0;
  // Read in build, where depending on an inherited widget is legal, and probed
  // from the viewability tick. Covers a hidden IndexedStack page and an
  // explicit Visibility(maintainSize: true), both of which keep geometry.
  bool _painting = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      _cancelRefresh();
    } else if (_response == null) {
      _scheduleRetry();
    } else {
      _scheduleRefresh();
    }
  }

  @override
  void didUpdateWidget(covariant AdPlugaBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slotId != widget.slotId ||
        oldWidget.format != widget.format) {
      _cancelRefresh();
      _teardownVisibility();
      _response = null;
      _clickFired = false;
      _refreshSeq = 0;
      _fillFailures = 0;
      _lastDeckInteraction = null;
      _load();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelRefresh();
    _teardownVisibility();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _load() async {
    final ad = AdPluga.maybeInstance;
    if (ad == null) {
      widget.onError?.call(const NotInitializedError());
      _scheduleRetry();
      return;
    }
    try {
      final resp = await ad.serve(
        slotId: widget.slotId,
        format: widget.format,
        refreshSeq: _refreshSeq,
      );
      if (_disposed) return;
      if (resp == null) {
        widget.onError?.call(const NetworkError('no fill'));
        _scheduleRetry();
        return;
      }
      _fillFailures = 0;
      setState(() {
        _response = resp;
        _clickFired = false;
      });
      _armVisibility(ad, resp);
      _scheduleRefresh();
    } on AdPlugaError catch (e) {
      _scheduleRetry();
      widget.onError?.call(e);
    }
  }

  /// Arms the next rotation for the cadence the server published for this
  /// slot. Nothing is scheduled when the slot has no cadence, when the app is
  /// backgrounded, or when the value is below the industry floor.
  void _scheduleRefresh() {
    _cancelRefresh();
    if (_disposed || !_foreground) return;
    final resp = _response;
    final secs = resp?.refreshAfterSeconds ?? 0;
    if (resp == null || secs <= 0) return;
    final floor = resp.ad.isTest ? kMinRefreshSecondsTest : kMinRefreshSeconds;
    _refreshTimer =
        Timer(Duration(seconds: secs < floor ? floor : secs), _onRefreshTick);
  }

  /// Arms another attempt after a failed fill, backing off exponentially from
  /// the client's cadence floor. Independent of the slot's rotation cadence:
  /// rotation is off by default, so a slot that relied on it would stay blank
  /// for the rest of the session after a single miss.
  void _scheduleRetry() {
    _cancelRefresh();
    if (_disposed || !_foreground) return;
    final ad = AdPluga.maybeInstance;
    final base =
        (ad?.isTestKey ?? false) ? kMinRefreshSecondsTest : kMinRefreshSeconds;
    final capped = _fillFailures > 10 ? 10 : _fillFailures;
    final backoff = base * (1 << capped);
    final secs = backoff > kFillRetryMaxBackoffSeconds
        ? kFillRetryMaxBackoffSeconds
        : backoff;
    _fillFailures += 1;
    logger.warn('slot ${widget.slotId} unfilled; retrying in ${secs}s');
    _refreshTimer = Timer(Duration(seconds: secs), _onRetryTick);
  }

  void _onRetryTick() {
    if (_disposed || !_foreground) return;
    _load();
  }

  void _cancelRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  /// Records a swipe so a scheduled rotation backs off: replacing the deck
  /// while the reader is moving through it would throw away their place.
  void _noteDeckInteraction() {
    _lastDeckInteraction = DateTime.now();
  }

  void _onRefreshTick() {
    if (_disposed || !_foreground) return;
    // Rotating an off-screen ad would spend a decision on an impression the
    // MRC guidelines classify as non-viewable: wait for it to come back into
    // view instead, re-arming on the same cadence.
    final visible = VisibilityTracker.instance.isVisible(
      () => context.findRenderObject() as RenderBox?,
      isPainting: () => _painting,
    );
    if (!visible) {
      _scheduleRefresh();
      return;
    }
    // A deck the reader is still swiping through keeps the slot; rotation
    // resumes one full cadence after the last swipe.
    final last = _lastDeckInteraction;
    final secs = _response?.refreshAfterSeconds ?? 0;
    if (last != null &&
        secs > 0 &&
        DateTime.now().difference(last) < Duration(seconds: secs)) {
      _scheduleRefresh();
      return;
    }
    _refreshSeq += 1;
    _load();
  }

  void _armVisibility(AdPluga ad, ServeResponse resp) {
    _teardownVisibility();
    _visibilityHandle = VisibilityTracker.instance.register(
      () => context.findRenderObject() as RenderBox?,
      isPainting: () => _painting,
      () {
        if (_disposed) return;
        ad.fireImpression(resp, widget.slotId);
        ad.fireViewable(resp, widget.slotId);
        widget.onImpression?.call();
      },
    );
  }

  void _teardownVisibility() {
    final h = _visibilityHandle;
    if (h != null) {
      VisibilityTracker.instance.unregister(h);
      _visibilityHandle = null;
    }
  }

  void _handleTap() {
    final ad = AdPluga.maybeInstance;
    final resp = _response;
    if (ad == null || resp == null || _clickFired) return;
    _clickFired = true;
    ad.fireClick(resp, widget.slotId);
    unawaited(openClickThrough(resp.ad.clickUrl));
    widget.onClick?.call();
  }

  @override
  Widget build(BuildContext context) {
    _painting = Visibility.of(context);
    final resp = _response;
    final w = widget.width ?? resp?.ad.width.toDouble();
    final h = widget.height ?? resp?.ad.height.toDouble();
    final w0 = (w == null || w == 0) ? 320.0 : w;
    final h0 = (h == null || h == 0) ? 100.0 : h;

    if (resp == null) {
      return SizedBox(
        width: w0,
        height: h0,
        child: widget.placeholder,
      );
    }

    final ad = resp.ad;
    Widget content;
    switch (ad.kind) {
      case AdKind.image:
      case AdKind.template:
        final url = ad.assetUrl ?? ad.mainImageUrl ?? '';
        if (url.isEmpty) {
          content = widget.placeholder ?? const SizedBox.shrink();
        } else {
          content = withTestBadge(
            Image.network(
              url,
              fit: BoxFit.contain,
              semanticLabel: adLabel(ad),
              errorBuilder: (_, __, ___) =>
                  widget.placeholder ?? const SizedBox.shrink(),
            ),
            isTest: ad.isTest,
          );
        }
        break;
      case AdKind.html:
        final inline = ad.html;
        final url = ad.assetUrl ?? ad.mainImageUrl ?? '';
        final hasInline = inline != null && inline.isNotEmpty;
        if (!hasInline && url.isEmpty) {
          content = widget.placeholder ?? const SizedBox.shrink();
        } else {
          content = AdPlugaHtml(
            html: hasInline ? inline : null,
            assetUrl: hasInline ? null : url,
            onClick: _handleTap,
            isTest: ad.isTest,
          );
        }
        break;
      case AdKind.video:
      case AdKind.videoRewarded:
      case AdKind.audio:
        final videoUrl = ad.videoUrl ?? ad.assetUrl ?? '';
        if (videoUrl.isEmpty) {
          content = widget.placeholder ?? const SizedBox.shrink();
        } else {
          content = AdPlugaVideo(
            videoUrl: videoUrl,
            clickThroughUrl: ad.clickUrl,
            quartilePings: resp.quartilePings,
            onClick: _handleTap,
            isTest: ad.isTest,
          );
        }
        break;
      case AdKind.carousel:
        if (ad.slides.isEmpty) {
          content = widget.placeholder ?? const SizedBox.shrink();
        } else {
          content = AdPlugaCarousel(
            slides: ad.slides,
            fallbackLabel: adLabel(ad),
            onClick: _handleTap,
            onInteraction: _noteDeckInteraction,
            isTest: ad.isTest,
          );
        }
        break;
      case AdKind.native:
      case AdKind.unknown:
        content = widget.placeholder ?? const SizedBox.shrink();
        break;
    }

    final slot = Semantics(
      label: ad.sponsoredBy != null
          ? 'Sponsored by ${ad.sponsoredBy}'
          : 'Sponsored',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: (ad.kind == AdKind.html ||
                ad.kind == AdKind.video ||
                ad.kind == AdKind.videoRewarded ||
                ad.kind == AdKind.audio ||
                ad.kind == AdKind.carousel)
            ? null
            : _handleTap,
        child: content,
      ),
    );

    // The host always wins when it sized the slot itself. Otherwise the box
    // takes the served creative's own ratio, so the fit is exact by
    // construction and the integrator has nothing to guess. Pinning the box to
    // the creative's pixel width instead would overflow any screen narrower
    // than the creative.
    if (widget.width != null && widget.height != null) {
      return SizedBox(width: w0, height: h0, child: slot);
    }
    final ratio = _servedRatio(ad);
    if (ratio == null) {
      return SizedBox(width: w0, height: h0, child: slot);
    }
    return AspectRatio(aspectRatio: ratio, child: slot);
  }

  double? _servedRatio(Ad ad) {
    if (ad.width <= 0 || ad.height <= 0) return null;
    return ad.width / ad.height;
  }
}
