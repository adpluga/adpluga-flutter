import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

typedef HtmlAdClickHandler = void Function();

class AdPlugaHtml extends StatefulWidget {
  const AdPlugaHtml({
    super.key,
    this.html,
    this.assetUrl,
    this.baseUrl,
    this.onClick,
    this.backgroundColor,
  });

  final String? html;
  final String? assetUrl;
  final String? baseUrl;
  final HtmlAdClickHandler? onClick;
  final Color? backgroundColor;

  @override
  State<AdPlugaHtml> createState() => _AdPlugaHtmlState();
}

class _AdPlugaHtmlState extends State<AdPlugaHtml> {
  late final WebViewController _controller;
  bool _initialLoaded = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(widget.backgroundColor ?? const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: _onNavigationRequest,
        ),
      );

    final inline = widget.html;
    if (inline != null && inline.isNotEmpty) {
      _controller.loadHtmlString(inline, baseUrl: widget.baseUrl);
    } else if (widget.assetUrl != null && widget.assetUrl!.isNotEmpty) {
      final parsed = Uri.tryParse(widget.assetUrl!);
      if (parsed != null && _isAllowedScheme(parsed)) {
        _controller.loadRequest(parsed);
      }
    }
  }

  FutureOr<NavigationDecision> _onNavigationRequest(NavigationRequest request) {
    if (!_initialLoaded) {
      _initialLoaded = true;
      return NavigationDecision.navigate;
    }
    final uri = Uri.tryParse(request.url);
    if (uri == null || !_isAllowedScheme(uri)) {
      return NavigationDecision.prevent;
    }
    widget.onClick?.call();
    unawaited(_openExternal(uri));
    return NavigationDecision.prevent;
  }

  bool _isAllowedScheme(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    return scheme == 'http' || scheme == 'https';
  }

  Future<void> _openExternal(Uri uri) async {
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _controller);
  }
}
