import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'test_badge.dart';

/// Called when an HTML creative navigates away from its initial page.
typedef HtmlAdClickHandler = void Function();

/// Renders an HTML creative in a web view with JavaScript enabled.
///
/// Loads [html] when non-empty, otherwise [assetUrl] if it is an http(s) URL.
/// After the first page load, every http(s) navigation is treated as a click:
/// [onClick] is called and the URL opens in an external application. Other
/// navigations are blocked.
///
/// Used by `AdPlugaBanner` and the full-screen formats; it reports no
/// impressions or clicks to AdPluga itself.
class AdPlugaHtml extends StatefulWidget {
  /// Creates an HTML creative view.
  const AdPlugaHtml({
    super.key,
    this.html,
    this.assetUrl,
    this.baseUrl,
    this.onClick,
    this.backgroundColor,
    this.isTest = false,
  });

  /// Inline HTML markup.
  final String? html;

  /// Page URL loaded when [html] is empty.
  final String? assetUrl;

  /// Base URL for resolving relative links in [html].
  final String? baseUrl;

  /// Called on each click-through navigation.
  final HtmlAdClickHandler? onClick;

  /// Web view background; transparent when null.
  final Color? backgroundColor;

  /// Whether to draw the `TEST` badge over the creative.
  final bool isTest;

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
    return withTestBadge(
      WebViewWidget(controller: _controller),
      isTest: widget.isTest,
    );
  }
}
