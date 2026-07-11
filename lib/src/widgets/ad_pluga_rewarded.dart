import 'dart:async';

import 'package:flutter/material.dart';

import '../ad_pluga.dart';
import '../errors.dart';
import '../models/serve_response.dart';
import 'ad_pluga_video.dart';

typedef RewardHandler = void Function(int amount, String currency);

class RewardedAd {
  RewardedAd._({required this.response, required this.slotId});

  final ServeResponse response;
  final String slotId;

  bool _shown = false;

  static Future<RewardedAd> load({
    required String slotId,
    String? format,
  }) async {
    final sdk = AdPluga.instance;
    final resp = await sdk.serve(slotId: slotId, format: format ?? 'video_rewarded');
    if (resp == null) throw const NetworkError('no fill');
    if (resp.ad.kind != AdKind.videoRewarded &&
        resp.ad.kind != AdKind.video &&
        resp.ad.kind != AdKind.image) {
      throw UnsupportedFormatError(resp.ad.kind.name);
    }
    return RewardedAd._(response: resp, slotId: slotId);
  }

  Future<void> show(BuildContext context, {required RewardHandler onReward}) async {
    if (_shown) return;
    _shown = true;
    final sdk = AdPluga.maybeInstance;
    if (sdk == null) throw const NotInitializedError();
    final navigator = Navigator.of(context, rootNavigator: true);
    final completer = Completer<void>();
    unawaited(
      navigator.push<void>(
        _RewardedRoute(
          response: response,
          onShown: () => sdk.fireImpression(response, slotId),
          onClick: () => sdk.fireClick(response, slotId),
          onReward: () {
            final amount = response.ad.rewardAmount;
            final currency = response.ad.rewardCurrency ?? 'USD';
            if (amount > 0) onReward(amount, currency);
          },
          onDismiss: () {
            if (!completer.isCompleted) completer.complete();
          },
        ),
      ),
    );
    return completer.future;
  }
}

class _RewardedRoute extends PageRoute<void> {
  _RewardedRoute({
    required this.response,
    required this.onShown,
    required this.onClick,
    required this.onReward,
    required this.onDismiss,
  });

  final ServeResponse response;
  final VoidCallback onShown;
  final VoidCallback onClick;
  final VoidCallback onReward;
  final VoidCallback onDismiss;

  @override
  Color? get barrierColor => const Color(0xF2000000);

  @override
  String? get barrierLabel => 'AdPluga rewarded';

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 200);

  @override
  bool get opaque => true;

  @override
  bool get barrierDismissible => false;

  @override
  Widget buildPage(BuildContext context, Animation<double> a, Animation<double> b) {
    return _RewardedSurface(
      response: response,
      onShown: onShown,
      onClick: onClick,
      onReward: onReward,
      onDismiss: () {
        onDismiss();
        Navigator.of(context, rootNavigator: true).pop();
      },
    );
  }
}

class _RewardedSurface extends StatefulWidget {
  const _RewardedSurface({
    required this.response,
    required this.onShown,
    required this.onClick,
    required this.onReward,
    required this.onDismiss,
  });

  final ServeResponse response;
  final VoidCallback onShown;
  final VoidCallback onClick;
  final VoidCallback onReward;
  final VoidCallback onDismiss;

  @override
  State<_RewardedSurface> createState() => _RewardedSurfaceState();
}

class _RewardedSurfaceState extends State<_RewardedSurface> {
  Timer? _countdown;
  bool _impressionFired = false;
  bool _clickFired = false;
  bool _rewardGranted = false;
  int _secondsLeft = 5;
  int _positionMs = 0;
  int _durationMs = 0;
  bool _skippable = false;

  bool get _isVideo {
    final k = widget.response.ad.kind;
    return k == AdKind.videoRewarded || k == AdKind.video;
  }

  @override
  void initState() {
    super.initState();
    final total = widget.response.ad.durationMs;
    if (total > 0) {
      _secondsLeft = (total / 1000).ceil().clamp(1, 60);
    }
    _durationMs = total;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _impressionFired) return;
      _impressionFired = true;
      widget.onShown();
    });
    if (!_isVideo) {
      _startStaticCountdown();
    }
  }

  void _startStaticCountdown() {
    _countdown = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _secondsLeft = _secondsLeft > 0 ? _secondsLeft - 1 : 0);
      if (_secondsLeft == 0) {
        t.cancel();
        _grantReward();
      }
    });
  }

  void _grantReward() {
    if (_rewardGranted) return;
    _rewardGranted = true;
    widget.onReward();
  }

  void _onVideoProgress(int positionMs, int durationMs) {
    if (!mounted) return;
    final skippableAfter = widget.response.ad.skippableAfterMs;
    final remainingMs = durationMs - positionMs;
    final secs = remainingMs > 0 ? (remainingMs / 1000).ceil() : 0;
    final canSkip = skippableAfter > 0 && positionMs >= skippableAfter;
    if (secs != _secondsLeft ||
        positionMs != _positionMs ||
        durationMs != _durationMs ||
        canSkip != _skippable) {
      setState(() {
        _secondsLeft = secs;
        _positionMs = positionMs;
        _durationMs = durationMs;
        _skippable = canSkip;
      });
    }
  }

  void _onVideoComplete() {
    if (!mounted) return;
    setState(() {
      _secondsLeft = 0;
      _skippable = true;
    });
    _grantReward();
  }

  @override
  void dispose() {
    _countdown?.cancel();
    _countdown = null;
    super.dispose();
  }

  void _tap() {
    if (_clickFired) return;
    _clickFired = true;
    widget.onClick();
  }

  @override
  Widget build(BuildContext context) {
    final ad = widget.response.ad;
    final Widget content;
    final bool canClose;
    if (_isVideo) {
      final videoUrl = ad.videoUrl ?? ad.assetUrl ?? '';
      canClose = _skippable || _rewardGranted;
      if (videoUrl.isEmpty) {
        content = const SizedBox.shrink();
      } else {
        content = AdPlugaVideo(
          videoUrl: videoUrl,
          clickThroughUrl: ad.clickUrl,
          quartilePings: widget.response.quartilePings,
          onClick: _tap,
          onProgress: _onVideoProgress,
          onComplete: _onVideoComplete,
          openClickExternally: false,
        );
      }
    } else {
      final url = ad.assetUrl ?? ad.mainImageUrl ?? '';
      canClose = _secondsLeft == 0;
      content = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _tap,
        child: Center(
          child: url.isEmpty
              ? const SizedBox.shrink()
              : Image.network(url, fit: BoxFit.contain),
        ),
      );
    }
    return Material(
      color: Colors.black,
      child: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: content),
            Positioned(
              top: 12,
              right: 12,
              child: canClose
                  ? _CloseButton(onPressed: widget.onDismiss)
                  : _Countdown(seconds: _secondsLeft),
            ),
          ],
        ),
      ),
    );
  }
}

class _Countdown extends StatelessWidget {
  const _Countdown({required this.seconds});
  final int seconds;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: const BoxDecoration(
        color: Color(0x99000000),
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      child: Text(
        '$seconds',
        style: const TextStyle(color: Colors.white, fontSize: 14),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Close ad',
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            color: Color(0x99000000),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.close, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}
