import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../ad_pluga.dart';
import '../tracking/quartile_firer.dart';
import 'test_badge.dart';

/// Called on the first tap on a playing video.
typedef VideoAdClickHandler = void Function();

/// Called on each player update with the playback position and total
/// duration, in milliseconds.
typedef VideoAdProgressHandler = void Function(int positionMs, int durationMs);

/// Called once when playback reaches the end.
typedef VideoAdCompleteHandler = void Function();

/// Plays a video creative and fires its quartile beacons.
///
/// Only http(s) [videoUrl]s are played; otherwise, and while loading, the
/// widget shows [backgroundColor]. Playback does not loop.
///
/// Used by `AdPlugaBanner` and the full-screen formats; it reports no
/// impressions or clicks to AdPluga itself.
class AdPlugaVideo extends StatefulWidget {
  /// Creates a video creative player.
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
    this.isTest = false,
  });

  /// URL of the video to play.
  final String videoUrl;

  /// Destination opened on tap when [openClickExternally] is true. Must be
  /// http(s).
  final String? clickThroughUrl;

  /// Beacon URLs fired as playback crosses `start`, `first_quartile`,
  /// `midpoint`, `third_quartile` and `complete`.
  final Map<String, String>? quartilePings;

  /// Called on the first tap.
  final VideoAdClickHandler? onClick;

  /// Called on playback progress.
  final VideoAdProgressHandler? onProgress;

  /// Called when playback completes.
  final VideoAdCompleteHandler? onComplete;

  /// Whether to start playing once the video is initialized.
  final bool autoplay;

  /// Whether to play with the volume at zero.
  final bool muted;

  /// Whether a tap opens [clickThroughUrl] in an external application.
  final bool openClickExternally;

  /// Colour behind the video and shown while it is not playable.
  final Color backgroundColor;

  /// Whether to draw the `TEST` badge over the creative.
  final bool isTest;

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
    _quartiles = QuartileFirer(widget.quartilePings,
        endpoint: AdPluga.maybeInstance?.config.endpoint);
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
      _quartiles = QuartileFirer(widget.quartilePings,
          endpoint: AdPluga.maybeInstance?.config.endpoint);
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
    final Widget child;
    if (_initFailed || c == null || !c.value.isInitialized) {
      child = ColoredBox(color: widget.backgroundColor);
    } else {
      child = GestureDetector(
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
    return withTestBadge(child, isTest: widget.isTest);
  }
}
