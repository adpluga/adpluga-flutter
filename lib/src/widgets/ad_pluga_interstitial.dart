import 'dart:async';

import 'package:flutter/material.dart';

import '../ad_pluga.dart';
import '../errors.dart';
import '../models/serve_response.dart';
import 'ad_pluga_html.dart';
import 'ad_pluga_video.dart';

class InterstitialAd {
  InterstitialAd._({required this.response, required this.slotId});

  final ServeResponse response;
  final String slotId;

  bool _shown = false;
  bool _dismissed = false;

  static const _supportedKinds = <AdKind>{
    AdKind.image,
    AdKind.template,
    AdKind.html,
    AdKind.video,
  };

  static Future<InterstitialAd> load({
    required String slotId,
    String? format,
  }) async {
    final sdk = AdPluga.instance;
    final resp = await sdk.serve(slotId: slotId, format: format);
    if (resp == null) {
      throw const NetworkError('no fill');
    }
    final kind = resp.ad.kind;
    if (!_supportedKinds.contains(kind)) {
      throw UnsupportedFormatError(kind.name);
    }
    return InterstitialAd._(response: resp, slotId: slotId);
  }

  Future<void> show(BuildContext context) async {
    if (_shown || _dismissed) return;
    _shown = true;
    final sdk = AdPluga.maybeInstance;
    if (sdk == null) throw const NotInitializedError();
    final navigator = Navigator.of(context, rootNavigator: true);
    final completer = Completer<void>();
    unawaited(
      navigator.push<void>(
        _InterstitialRoute(
          response: response,
          onShown: () => sdk.fireImpression(response, slotId),
          onClick: () => sdk.fireClick(response, slotId),
          onDismiss: () {
            _dismissed = true;
            if (!completer.isCompleted) completer.complete();
          },
        ),
      ),
    );
    return completer.future;
  }
}

class _InterstitialRoute extends PageRoute<void> {
  _InterstitialRoute({
    required this.response,
    required this.onShown,
    required this.onClick,
    required this.onDismiss,
  });

  final ServeResponse response;
  final VoidCallback onShown;
  final VoidCallback onClick;
  final VoidCallback onDismiss;

  @override
  Color? get barrierColor => const Color(0xE6000000);

  @override
  String? get barrierLabel => 'AdPluga interstitial';

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 180);

  @override
  bool get opaque => false;

  @override
  bool get barrierDismissible => false;

  @override
  Widget buildPage(BuildContext context, Animation<double> a, Animation<double> b) {
    return _InterstitialSurface(
      response: response,
      onShown: onShown,
      onClick: onClick,
      onDismiss: () {
        onDismiss();
        Navigator.of(context, rootNavigator: true).pop();
      },
    );
  }
}

class _InterstitialSurface extends StatefulWidget {
  const _InterstitialSurface({
    required this.response,
    required this.onShown,
    required this.onClick,
    required this.onDismiss,
  });

  final ServeResponse response;
  final VoidCallback onShown;
  final VoidCallback onClick;
  final VoidCallback onDismiss;

  @override
  State<_InterstitialSurface> createState() => _InterstitialSurfaceState();
}

class _InterstitialSurfaceState extends State<_InterstitialSurface> {
  bool _impressionFired = false;
  bool _clickFired = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _impressionFired) return;
      _impressionFired = true;
      widget.onShown();
    });
  }

  void _tap() {
    if (_clickFired) return;
    _clickFired = true;
    widget.onClick();
  }

  @override
  Widget build(BuildContext context) {
    final ad = widget.response.ad;
    final Widget adContent;
    if (ad.kind == AdKind.html) {
      final inline = ad.html;
      final url = ad.assetUrl ?? ad.mainImageUrl ?? '';
      final hasInline = inline != null && inline.isNotEmpty;
      if (!hasInline && url.isEmpty) {
        adContent = const SizedBox.shrink();
      } else {
        adContent = AdPlugaHtml(
          html: hasInline ? inline : null,
          assetUrl: hasInline ? null : url,
          onClick: _tap,
        );
      }
    } else if (ad.kind == AdKind.video) {
      final videoUrl = ad.videoUrl ?? ad.assetUrl ?? '';
      if (videoUrl.isEmpty) {
        adContent = const SizedBox.shrink();
      } else {
        adContent = AdPlugaVideo(
          videoUrl: videoUrl,
          clickThroughUrl: ad.clickUrl,
          quartilePings: widget.response.quartilePings,
          onClick: _tap,
        );
      }
    } else {
      final url = ad.assetUrl ?? ad.mainImageUrl ?? '';
      adContent = GestureDetector(
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
      color: Colors.transparent,
      child: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: adContent),
            Positioned(
              top: 12,
              right: 12,
              child: _CloseButton(onPressed: widget.onDismiss),
            ),
          ],
        ),
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
