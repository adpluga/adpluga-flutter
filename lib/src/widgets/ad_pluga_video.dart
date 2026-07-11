import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../tracking/quartile_firer.dart';

typedef VideoAdClickHandler = void Function();
typedef VideoAdProgressHandler = void Function(int positionMs, int durationMs);
typedef VideoAdCompleteHandler = void Function();

class AdPlugaVideo extends StatefulWidget {
  const AdPlugaVideo({
    super.key,
    required this.videoUrl,
    this.clickThroughUrl,
    this.quartilePings,
    this.onClick,
    this.onProgress,
    this.onComplete,
    this.autoplay = true,
    this.muted = true,
    this.openClickExternally = true,
    this.backgroundColor = Colors.black,
  });

  final String videoUrl;
  final String? clickThroughUrl;
  final Map<String, String>? quartilePings;
  final VideoAdClickHandler? onClick;
  final VideoAdProgressHandler? onProgress;
  final VideoAdCompleteHandler? onComplete;
  final bool autoplay;
  final bool muted;
  final bool openClickExternally;
  final Color backgroundColor;

  @override
  State<AdPlugaVideo> createState() => _AdPlugaVideoState();
}

class _AdPlugaVideoState extends State<AdPlugaVideo> {
  VideoPlayerController? _controller;
  QuartileFirer? _quartiles;
  bool _completed = false;
  bool _clickFired = false;
  bool _initFailed = false;

  @override
  void initState() {
    super.initState();
    _quartiles = QuartileFirer(widget.quartilePings);
    _setupController();
  }

  @override
  void didUpdateWidget(covariant AdPlugaVideo old) {
    super.didUpdateWidget(old);
    if (old.videoUrl != widget.videoUrl) {
      _teardown();
      _completed = false;
      _clickFired = false;
      _initFailed = false;
      _quartiles = QuartileFirer(widget.quartilePings);
      _setupController();
    }
  }

  Future<void> _setupController() async {
    final uri = Uri.tryParse(widget.videoUrl);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      setState(() => _initFailed = true);
      return;
    }
    final controller = VideoPlayerController.networkUrl(uri);
    _controller = controller;
    controller.addListener(_onControllerUpdate);
    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      if (widget.muted) {
        await controller.setVolume(0);
      }
      await controller.setLooping(false);
      if (widget.autoplay) {
        await controller.play();
      }
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => _initFailed = true);
    }
  }

  void _onControllerUpdate() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final positionMs = c.value.position.inMilliseconds;
    final durationMs = c.value.duration.inMilliseconds;
    if (durationMs > 0) {
      _quartiles?.update(positionMs: positionMs, durationMs: durationMs);
      widget.onProgress?.call(positionMs, durationMs);
      if (!_completed && positionMs >= durationMs) {
        _completed = true;
        widget.onComplete?.call();
      }
    }
    if (c.value.hasError && !_initFailed) {
      setState(() => _initFailed = true);
    }
  }

  Future<void> _handleTap() async {
    if (_clickFired) return;
    _clickFired = true;
    widget.onClick?.call();
    final target = widget.clickThroughUrl;
    if (!widget.openClickExternally || target == null || target.isEmpty) {
      return;
    }
    final uri = Uri.tryParse(target);
    if (uri == null) return;
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return;
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  void _teardown() {
    final c = _controller;
    if (c != null) {
      c.removeListener(_onControllerUpdate);
      unawaited(c.dispose());
      _controller = null;
    }
  }

  @override
  void dispose() {
    _teardown();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (_initFailed) {
      return ColoredBox(color: widget.backgroundColor);
    }
    if (c == null || !c.value.isInitialized) {
      return ColoredBox(color: widget.backgroundColor);
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: ColoredBox(
        color: widget.backgroundColor,
        child: Center(
          child: AspectRatio(
            aspectRatio: c.value.aspectRatio,
            child: VideoPlayer(c),
          ),
        ),
      ),
    );
  }
}
