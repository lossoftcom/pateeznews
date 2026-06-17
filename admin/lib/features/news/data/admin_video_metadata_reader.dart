import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class AdminVideoMetadata {
  const AdminVideoMetadata({
    required this.platformLabel,
    required this.publishedAt,
  });

  final String platformLabel;
  final String publishedAt;
}

class AdminVideoMetadataReader {
  const AdminVideoMetadataReader({this.httpClient});

  static const _timeout = Duration(seconds: 8);

  final http.Client? httpClient;

  Future<AdminVideoMetadata> read(String rawUrl) async {
    final url = rawUrl.trim();
    final platform = adminVideoPlatformLabel(url);
    final youtubeId = _youtubeVideoId(url);
    if (youtubeId == null) {
      return AdminVideoMetadata(platformLabel: platform, publishedAt: '');
    }

    final publishedAt = await _readYoutubePublishedAt(youtubeId);
    return AdminVideoMetadata(
      platformLabel: platform,
      publishedAt: publishedAt,
    );
  }

  Future<String> _readYoutubePublishedAt(String videoId) async {
    final uri = Uri.https('www.youtube.com', '/watch', {'v': videoId});
    final headers = {
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'User-Agent':
          'PateezAdmin/1.0 (+https://pateeznews.com) AppleWebKit/605.1.15',
    };
    try {
      final request = httpClient?.get(uri, headers: headers);
      final response = await (request ?? http.get(uri, headers: headers))
          .timeout(_timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) return '';
      return _extractYoutubeDate(_decodeResponseBody(response));
    } catch (_) {
      return '';
    }
  }
}

String adminVideoPlatformLabel(String rawUrl) {
  final url = rawUrl.trim();
  final uri = Uri.tryParse(url);
  final youtubeId = _youtubeVideoId(url);
  if (youtubeId != null) return 'YouTube';

  final path = uri?.path.toLowerCase() ?? url.toLowerCase();
  final extension = _videoExtension(path);
  final extensionLabel = extension.isEmpty
      ? ''
      : ' · ${extension.toUpperCase()}';
  final host = uri?.host.toLowerCase().replaceFirst('www.', '') ?? '';
  if (host.contains('pexels.com')) return 'Pexels$extensionLabel';
  if (host.contains('vimeo.com')) return 'Vimeo$extensionLabel';
  if (host.contains('dailymotion.com')) return 'Dailymotion$extensionLabel';
  if (host.isEmpty ||
      path.startsWith('/api/storage/file/video/') ||
      path.startsWith('/local-upload/video/')) {
    return 'Yerel Depo$extensionLabel';
  }
  return '$host$extensionLabel';
}

String _decodeResponseBody(http.Response response) {
  final contentType = response.headers['content-type'] ?? '';
  final charsetMatch = RegExp(
    r'charset=([\w\-.]+)',
    caseSensitive: false,
  ).firstMatch(contentType);
  final charset = charsetMatch?.group(1)?.toLowerCase();
  if (charset == null || charset == 'utf-8' || charset == 'utf8') {
    return utf8.decode(response.bodyBytes, allowMalformed: true);
  }
  return response.body;
}

String _extractYoutubeDate(String html) {
  for (final pattern in [
    RegExp(r'"datePublished"\s*:\s*"([^"]+)"'),
    RegExp(r'"publishDate"\s*:\s*"([^"]+)"'),
    RegExp(r'<meta\s+itemprop="datePublished"\s+content="([^"]+)"'),
  ]) {
    final value = pattern.firstMatch(html)?.group(1)?.trim() ?? '';
    if (value.isNotEmpty) return value;
  }
  return '';
}

String _videoExtension(String path) {
  final fileName = path.split('/').last.split('?').first;
  final dot = fileName.lastIndexOf('.');
  if (dot < 0 || dot == fileName.length - 1) return '';
  final extension = fileName.substring(dot + 1).toLowerCase();
  if (extension.length > 6) return '';
  return extension;
}

String? _youtubeVideoId(String value) {
  final raw = value.trim();
  if (RegExp(r'^[_\-a-zA-Z0-9]{11}$').hasMatch(raw)) return raw;
  var uri = Uri.tryParse(raw);
  if (uri != null && !uri.hasScheme && raw.contains('youtube')) {
    uri = Uri.tryParse('https://$raw');
  }
  if (uri == null || uri.host.isEmpty) return null;
  final host = uri.host.toLowerCase().replaceFirst('www.', '');
  if (host == 'youtu.be' && uri.pathSegments.isNotEmpty) {
    return _cleanYoutubeId(uri.pathSegments.first);
  }
  if (!host.endsWith('youtube.com') && host != 'youtube-nocookie.com') {
    return null;
  }
  final directId = _cleanYoutubeId(uri.queryParameters['v'] ?? '');
  if (directId != null) return directId;
  final segments = uri.pathSegments;
  for (var index = 0; index < segments.length - 1; index += 1) {
    if (const {'shorts', 'embed', 'live'}.contains(segments[index])) {
      return _cleanYoutubeId(segments[index + 1]);
    }
  }
  return null;
}

String? _cleanYoutubeId(String value) {
  final match = RegExp(r'[_\-a-zA-Z0-9]{11}').firstMatch(value);
  return match?.group(0);
}
