import 'package:url_launcher/url_launcher.dart';

import 'app_links.dart';

/// Opens an external URL. Overridable so widget tests can verify the link
/// without launching a real browser.
typedef ExternalUrlOpener = Future<bool> Function(Uri uri);

Future<bool> _launchInExternalBrowser(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

/// Test/app override point. Restore it after use in tests.
ExternalUrlOpener externalUrlOpener = _launchInExternalBrowser;

/// Opens [url] in the external browser. Returns false when the URL is a
/// placeholder, unparseable, or the launcher reports failure.
Future<bool> openExternalUrl(String url) async {
  if (!isConfiguredUrl(url)) return false;
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  try {
    return await externalUrlOpener(uri);
  } catch (_) {
    return false;
  }
}
