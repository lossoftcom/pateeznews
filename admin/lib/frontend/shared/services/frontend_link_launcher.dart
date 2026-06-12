import 'package:url_launcher/url_launcher.dart';

Uri? frontendUriFromUserInput(String value) {
  final raw = value.trim();
  if (raw.isEmpty) return null;

  final parsed = Uri.tryParse(raw);
  if (parsed != null && parsed.hasScheme) return parsed;

  return Uri.tryParse('https://$raw');
}

Future<bool> openFrontendLink(
  String value, {
  bool preferNativeApp = false,
}) async {
  final uri = frontendUriFromUserInput(value);
  if (uri == null) return false;
  return openFrontendUri(uri, preferNativeApp: preferNativeApp);
}

Future<bool> openFrontendUri(Uri uri, {bool preferNativeApp = false}) async {
  if (preferNativeApp || _isSocialHttpUri(uri)) {
    final openedNative = await _tryLaunch(
      uri,
      LaunchMode.externalNonBrowserApplication,
    );
    if (openedNative) return true;
  }

  if (_isHttpUri(uri)) {
    final openedInApp = await _tryLaunch(uri, LaunchMode.inAppBrowserView);
    if (openedInApp) return true;
  }

  return _tryLaunch(uri, LaunchMode.platformDefault);
}

bool _isHttpUri(Uri uri) {
  final scheme = uri.scheme.toLowerCase();
  return scheme == 'http' || scheme == 'https';
}

bool _isSocialHttpUri(Uri uri) {
  if (!_isHttpUri(uri)) return false;
  final host = uri.host.toLowerCase();
  return host == 'x.com' ||
      host == 'twitter.com' ||
      host.endsWith('.twitter.com') ||
      host == 'facebook.com' ||
      host.endsWith('.facebook.com') ||
      host == 'instagram.com' ||
      host.endsWith('.instagram.com') ||
      host == 'wa.me' ||
      host == 'whatsapp.com' ||
      host.endsWith('.whatsapp.com') ||
      host == 'tiktok.com' ||
      host.endsWith('.tiktok.com') ||
      host == 'youtube.com' ||
      host.endsWith('.youtube.com') ||
      host == 'youtu.be' ||
      host == 'linkedin.com' ||
      host.endsWith('.linkedin.com') ||
      host == 'pinterest.com' ||
      host.endsWith('.pinterest.com') ||
      host == 'snapchat.com' ||
      host.endsWith('.snapchat.com') ||
      host == 't.me' ||
      host == 'telegram.me' ||
      host == 'bsky.app' ||
      host.endsWith('.bsky.app') ||
      host == 'reddit.com' ||
      host.endsWith('.reddit.com') ||
      host == 'twitch.tv' ||
      host.endsWith('.twitch.tv');
}

Future<bool> _tryLaunch(Uri uri, LaunchMode mode) async {
  try {
    return launchUrl(uri, mode: mode);
  } catch (_) {
    return false;
  }
}
