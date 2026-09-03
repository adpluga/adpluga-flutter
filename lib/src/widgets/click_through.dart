import 'package:url_launcher/url_launcher.dart';

import '../logger.dart';

/// Opens the advertiser destination for a tapped creative.
///
/// The click is reported separately through the signed track token, so this
/// only navigates: HTML and video creatives have always done both, while image
/// creatives reported the click and went nowhere, leaving the advertiser paying
/// for a tap that never reached them.
///
/// Only http(s) is followed, so a creative cannot drive the host app into an
/// arbitrary scheme.
Future<void> openClickThrough(String? url) async {
  final raw = url?.trim() ?? '';
  if (raw.isEmpty) return;
  final uri = Uri.tryParse(raw);
  if (uri == null) return;
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') {
    logger.warn('click-through refused for scheme "$scheme"');
    return;
  }
  try {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  } catch (e) {
    logger.warn('click-through failed', e);
  }
}
