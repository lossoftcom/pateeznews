import 'package:flutter/foundation.dart';

final Uri _productionApiBaseUrl = Uri.parse('https://pateez.com');

Uri frontendLocalApiBaseUrl({String configuredBaseUrl = ''}) {
  final configured = configuredBaseUrl.trim();
  if (configured.isNotEmpty) {
    return _normalizeLocalhostForPlatform(Uri.parse(configured));
  }
  if (kIsWeb) return Uri.base;
  return _productionApiBaseUrl;
}

Uri frontendApiUri(String path, {String configuredBaseUrl = ''}) {
  return frontendLocalApiBaseUrl(
    configuredBaseUrl: configuredBaseUrl,
  ).resolve(path);
}

Uri _normalizeLocalhostForPlatform(Uri uri) {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return uri;
  final host = uri.host.toLowerCase();
  if (host == 'localhost' || host == '127.0.0.1' || host == '::1') {
    return uri.replace(host: '10.0.2.2');
  }
  return uri;
}
