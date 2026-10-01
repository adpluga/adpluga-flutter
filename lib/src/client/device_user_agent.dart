import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// The platform WebView's User-Agent: what an SSP expects in device.ua for an
/// in-app impression. The Dart HTTP client would otherwise send `Dart/x.y`,
/// which bidders read as a server. On the web the browser sends its own UA.
Future<String?> webViewUserAgent() async {
  if (kIsWeb) return null;
  return WebViewController().getUserAgent();
}
