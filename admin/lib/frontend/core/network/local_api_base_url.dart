import 'package:flutter/foundation.dart';

Uri frontendLocalApiBaseUrl({String configuredBaseUrl = ''}) {
  final configured = configuredBaseUrl.trim();
  if (configured.isNotEmpty) {
    return _normalizeLocalhostForPlatform(Uri.parse(configured));
  }
  if (kIsWeb) return Uri.base;
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => Uri.parse('http://10.0.2.2:4321'),
    // Windows: dart:io localhost → 127.0.0.1 (IPv4), Node.js localhost → ::1 (IPv6)
    // çakışmasını önlemek için Windows'ta explicit IPv4 kullanıyoruz.
    TargetPlatform.windows => Uri.parse('http://127.0.0.1:4321'),
    _ => Uri.parse('http://127.0.0.1:4321'),
  };
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
