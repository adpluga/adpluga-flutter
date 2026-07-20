import 'package:flutter/material.dart';

import '../ad_pluga.dart';
import '../errors.dart';
import '../models/serve_response.dart';
import '../viewability/visibility_tracker.dart';
import 'ad_pluga_html.dart';
import 'ad_pluga_video.dart';

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

class _AdPlugaBannerState extends State<AdPlugaBanner> {
  ServeResponse? _response;
  int? _visibilityHandle;
  bool _clickFired = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AdPlugaBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slotId != widget.slotId ||
        oldWidget.format != widget.format) {
      _teardownVisibility();
      _response = null;
      _clickFired = false;
      _load();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _teardownVisibility();
    super.dispose();
  }

  Future<void> _load() async {
    final ad = AdPluga.maybeInstance;
    if (ad == null) {
      widget.onError?.call(const NotInitializedError());
      return;
    }
    try {
      final resp = await ad.serve(slotId: widget.slotId, format: widget.format);
      if (_disposed) return;
      if (resp == null) {
        widget.onError?.call(const NetworkError('no fill'));
        return;
      }
      setState(() => _response = resp);
      _armVisibility(ad, resp);
    } on AdPlugaError catch (e) {
      widget.onError?.call(e);
    }
  }

  void _armVisibility(AdPluga ad, ServeResponse resp) {
    _teardownVisibility();
    _visibilityHandle = VisibilityTracker.instance.register(
      () => context.findRenderObject() as RenderBox?,
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
    widget.onClick?.call();
  }

  @override
  Widget build(BuildContext context) {
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
          content = Image.network(
            url,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
                widget.placeholder ?? const SizedBox.shrink(),
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
          );
        }
        break;
      case AdKind.video:
        final videoUrl = ad.videoUrl ?? ad.assetUrl ?? '';
        if (videoUrl.isEmpty) {
          content = widget.placeholder ?? const SizedBox.shrink();
        } else {
          content = AdPlugaVideo(
            videoUrl: videoUrl,
            clickThroughUrl: ad.clickUrl,
            quartilePings: resp.quartilePings,
            onClick: _handleTap,
          );
        }
        break;
      case AdKind.native:
      case AdKind.videoRewarded:
      case AdKind.unknown:
        content = widget.placeholder ?? const SizedBox.shrink();
        break;
    }

    return SizedBox(
      width: w0,
      height: h0,
      child: Semantics(
        label: ad.sponsoredBy != null
            ? 'Sponsored by ${ad.sponsoredBy}'
            : 'Sponsored',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: (ad.kind == AdKind.html || ad.kind == AdKind.video)
              ? null
              : _handleTap,
          child: content,
        ),
      ),
    );
  }
}
