import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pateeznews_admin/core/network/admin_api_headers.dart';

class MediaItem {
  const MediaItem({
    required this.id,
    required this.value,
    required this.size,
    required this.date,
    required this.type,
    required this.src,
    this.thumb,
    required this.path,
  });

  final String id;
  final String value;
  final int size;
  final int date;
  final String type;
  final String src;
  final String? thumb;
  final String path;

  factory MediaItem.fromJson(Map<String, dynamic> json, String fallbackType) {
    return MediaItem(
      id: (json['id'] ?? '').toString(),
      value: (json['value'] ?? '').toString(),
      size: (json['size'] as num?)?.toInt() ?? 0,
      date: (json['date'] as num?)?.toInt() ?? 0,
      type: (json['type'] ?? fallbackType).toString(),
      src: (json['src'] ?? '').toString(),
      thumb: json['thumb']?.toString(),
      path: (json['path'] ?? json['id']?.toString().split('/').first ?? '')
          .toString(),
    );
  }
}

class MediaSeoReplacement {
  const MediaSeoReplacement({
    required this.oldId,
    required this.newId,
    required this.oldSrc,
    required this.newSrc,
    this.oldPublicSrc = '',
    this.newPublicSrc = '',
  });

  factory MediaSeoReplacement.fromJson(Map<String, dynamic> json) {
    return MediaSeoReplacement(
      oldId: (json['oldId'] ?? '').toString(),
      newId: (json['newId'] ?? '').toString(),
      oldSrc: (json['oldSrc'] ?? '').toString(),
      newSrc: (json['newSrc'] ?? '').toString(),
      oldPublicSrc: (json['oldPublicSrc'] ?? '').toString(),
      newPublicSrc: (json['newPublicSrc'] ?? '').toString(),
    );
  }

  final String oldId;
  final String newId;
  final String oldSrc;
  final String newSrc;
  final String oldPublicSrc;
  final String newPublicSrc;
}

class MediaSeoRenameResult {
  const MediaSeoRenameResult({
    required this.success,
    required this.filename,
    required this.src,
    required this.replacements,
    this.error = '',
  });

  factory MediaSeoRenameResult.failure(String error) {
    return MediaSeoRenameResult(
      success: false,
      filename: '',
      src: '',
      replacements: const [],
      error: error,
    );
  }

  factory MediaSeoRenameResult.fromJson(Map<String, dynamic> json) {
    return MediaSeoRenameResult(
      success: json['success'] == true,
      filename: (json['filename'] ?? '').toString(),
      src: (json['src'] ?? '').toString(),
      replacements: [
        for (final row in (json['replacements'] as List? ?? const []))
          if (row is Map<String, dynamic>) MediaSeoReplacement.fromJson(row),
      ],
      error: (json['error'] ?? '').toString(),
    );
  }

  final bool success;
  final String filename;
  final String src;
  final List<MediaSeoReplacement> replacements;
  final String error;
}

class MediaSeoAltTextResult {
  const MediaSeoAltTextResult({
    required this.success,
    required this.altText,
    required this.usedVision,
  });

  factory MediaSeoAltTextResult.fromJson(Map<String, dynamic> json) {
    return MediaSeoAltTextResult(
      success: json['success'] == true,
      altText: (json['altText'] ?? '').toString(),
      usedVision: json['usedVision'] == true,
    );
  }

  final bool success;
  final String altText;
  final bool usedVision;
}

class MediaVideoThumbnailResult {
  const MediaVideoThumbnailResult({
    required this.success,
    required this.thumbnailUrl,
    required this.provider,
  });

  factory MediaVideoThumbnailResult.fromJson(Map<String, dynamic> json) {
    final thumb = (json['thumbnailUrl'] ?? json['thumb'] ?? '').toString();
    return MediaVideoThumbnailResult(
      success: json['success'] == true && thumb.trim().isNotEmpty,
      thumbnailUrl: thumb,
      provider: (json['provider'] ?? '').toString(),
    );
  }

  final bool success;
  final String thumbnailUrl;
  final String provider;
}

int compareNewestMedia(MediaItem a, MediaItem b) {
  final dateCompare = b.date.compareTo(a.date);
  if (dateCompare != 0) return dateCompare;
  return b.id.compareTo(a.id);
}

class MediaTransferProgress {
  const MediaTransferProgress({
    required this.phase,
    required this.progress,
    required this.remaining,
  });

  final String phase;
  final double? progress;
  final Duration? remaining;
}

class MediaUploadSettings {
  const MediaUploadSettings({
    required this.imageFileFormat,
    required this.allowedExtensions,
    required this.maxImageSizeMb,
    required this.maxVideoSizeMb,
    required this.maxAudioSizeMb,
    required this.maxFileSizeMb,
  });

  factory MediaUploadSettings.defaults() {
    return const MediaUploadSettings(
      imageFileFormat: 'WEBP',
      allowedExtensions: {..._defaultAllowedUploadExtensions},
      maxImageSizeMb: 20,
      maxVideoSizeMb: 50,
      maxAudioSizeMb: 20,
      maxFileSizeMb: 50,
    );
  }

  factory MediaUploadSettings.fromJson(Map<String, Object?> json) {
    final fallback = MediaUploadSettings.defaults();
    return MediaUploadSettings(
      imageFileFormat: _imageFileFormat(
        json['content_upload_image_format'],
        fallback: fallback.imageFileFormat,
      ),
      allowedExtensions: _extensionSet(
        json['content_upload_allowed_extensions'],
        fallback: fallback.allowedExtensions,
      ),
      maxImageSizeMb: _megabyteLimit(
        json['content_upload_max_image_mb'],
        fallback: fallback.maxImageSizeMb,
      ),
      maxVideoSizeMb: _megabyteLimit(
        json['content_upload_max_video_mb'],
        fallback: fallback.maxVideoSizeMb,
      ),
      maxAudioSizeMb: _megabyteLimit(
        json['content_upload_max_audio_mb'],
        fallback: fallback.maxAudioSizeMb,
      ),
      maxFileSizeMb: _megabyteLimit(
        json['content_upload_max_file_mb'],
        fallback: fallback.maxFileSizeMb,
      ),
    );
  }

  final String imageFileFormat;
  final Set<String> allowedExtensions;
  final int maxImageSizeMb;
  final int maxVideoSizeMb;
  final int maxAudioSizeMb;
  final int maxFileSizeMb;

  List<String> extensionsFor(String type) {
    final known = switch (type) {
      'video' => _videoUploadExtensions,
      'audio' => _audioUploadExtensions,
      'file' => _fileUploadExtensions,
      _ => _imageUploadExtensions,
    };
    final filtered =
        known
            .where((extension) => allowedExtensions.contains(extension))
            .toList()
          ..sort();
    if (filtered.isNotEmpty) return filtered;
    return known.toList()..sort();
  }

  int maxBytesFor(String type) {
    final mb = switch (type) {
      'video' => maxVideoSizeMb,
      'audio' => maxAudioSizeMb,
      'file' => maxFileSizeMb,
      _ => maxImageSizeMb,
    };
    return mb * 1024 * 1024;
  }
}

class MediaService {
  MediaService({this.httpClient, this.apiBaseUrl});

  static const _apiBaseUrl = String.fromEnvironment('PATEEZNEWS_API_BASE_URL');
  static const _timeout = Duration(seconds: 15);
  static const _aiTimeout = Duration(seconds: 120);
  static const _uploadTimeout = Duration(seconds: 120);
  static final _uploadSettingsCache = <String, MediaUploadSettings>{};

  final http.Client? httpClient;
  final String? apiBaseUrl;

  static MediaUploadSettings? cachedUploadSettings({
    String languageCode = 'tr',
  }) {
    return _uploadSettingsCache[_normalizeLanguageCode(languageCode)];
  }

  static void cacheUploadSettings(
    MediaUploadSettings settings, {
    String languageCode = 'tr',
  }) {
    _uploadSettingsCache[_normalizeLanguageCode(languageCode)] = settings;
  }

  Future<List<MediaItem>> listFiles({String type = 'image'}) async {
    final uri = _resolve(
      '/api/storage/list',
    ).replace(queryParameters: {'type': type});
    final response = await _get(uri, headers: await adminAuthHeaders());
    if (response.statusCode < 200 || response.statusCode >= 300) return [];

    final decoded = jsonDecode(response.body);
    if (decoded is! List) return [];

    return decoded
        .whereType<Map<String, dynamic>>()
        .map((json) => MediaItem.fromJson(json, type))
        .toList()
      ..sort(compareNewestMedia);
  }

  Future<MediaUploadSettings> fetchUploadSettings({
    String languageCode = 'tr',
  }) async {
    final normalizedLanguageCode = _normalizeLanguageCode(languageCode);
    final response = await _request(
      'POST',
      _resolve('/api/admin/query'),
      headers: await adminJsonHeaders(),
      body: jsonEncode({
        'table': 'site_settings',
        'method': 'select',
        'select':
            'language_code,content_upload_image_format,'
            'content_upload_allowed_extensions,content_upload_max_image_mb,'
            'content_upload_max_video_mb,content_upload_max_audio_mb,'
            'content_upload_max_file_mb',
        'filters': [
          {
            'type': 'comparison',
            'op': 'eq',
            'column': 'language_code',
            'value': normalizedLanguageCode,
          },
        ],
        'single': 'maybeSingle',
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return cachedUploadSettings(languageCode: normalizedLanguageCode) ??
          MediaUploadSettings.defaults();
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      return cachedUploadSettings(languageCode: normalizedLanguageCode) ??
          MediaUploadSettings.defaults();
    }
    final data = decoded['data'];
    if (data is! Map) {
      return cachedUploadSettings(languageCode: normalizedLanguageCode) ??
          MediaUploadSettings.defaults();
    }
    final settings = MediaUploadSettings.fromJson(
      data.map((key, value) => MapEntry(key.toString(), value)),
    );
    cacheUploadSettings(settings, languageCode: normalizedLanguageCode);
    return settings;
  }

  Future<MediaItem?> uploadFile({
    required String fileName,
    required List<int> bytes,
    String type = 'image',
    String? customPath,
    String? customFilename,
    String? replaceId,
    ValueChanged<double>? onUploadProgress,
    VoidCallback? onProcessing,
    ValueChanged<MediaTransferProgress>? onTransferProgress,
  }) async {
    final uri = _resolve('/api/storage/upload');
    final request = http.MultipartRequest('POST', uri);
    final uploadId = type == 'video' && onTransferProgress != null
        ? _newUploadId()
        : null;
    if (!kIsWeb) {
      request.headers['Origin'] = '${uri.scheme}://${uri.authority}';
    }
    request.headers.addAll(await adminAuthHeaders());
    request.fields['type'] = type;
    _addMultipartField(request, 'uploadId', uploadId);
    _addMultipartField(request, 'customPath', customPath);
    _addMultipartField(request, 'customFilename', customFilename);
    _addMultipartField(request, 'replaceId', replaceId);
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: fileName),
    );

    final client = httpClient ?? adminHttpClient;
    final closeClient = shouldCloseAdminHttpClient(client, httpClient);
    late final http.Response response;
    var stopPolling = false;
    Future<void>? pollProgress;

    void startProcessingPoll() {
      if (uploadId == null || pollProgress != null) return;
      pollProgress = _pollProcessingProgress(
        uploadId,
        shouldStop: () => stopPolling,
        onProgress: onTransferProgress,
      );
    }

    try {
      final streamed = await _sendMultipartWithProgress(
        client,
        request,
        onUploadProgress: onUploadProgress,
        onTransferProgress: onTransferProgress,
        onProcessing: () {
          onProcessing?.call();
          onTransferProgress?.call(
            const MediaTransferProgress(
              phase: 'processing',
              progress: 0,
              remaining: null,
            ),
          );
          startProcessingPoll();
        },
      ).timeout(_uploadTimeout);
      response = await http.Response.fromStream(streamed).timeout(_timeout);
    } finally {
      stopPolling = true;
      final activePoll = pollProgress;
      if (activePoll != null) await activePoll;
      if (closeClient) client.close();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) return null;

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return null;

    return MediaItem(
      id: (decoded['id'] ?? '').toString(),
      value: (decoded['value'] ?? fileName).toString(),
      size: (decoded['size'] as num?)?.toInt() ?? bytes.length,
      date: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      type: (decoded['type'] ?? type).toString(),
      src: (decoded['src'] ?? '').toString(),
      thumb: decoded['thumb']?.toString(),
      path: (decoded['id'] ?? '').toString().split('/').first,
    );
  }

  Future<MediaItem?> replaceFile({
    required String fileId,
    required String fileName,
    required List<int> bytes,
    String type = 'image',
  }) {
    return uploadFile(
      fileName: fileName,
      bytes: bytes,
      type: type,
      replaceId: fileId,
    );
  }

  Future<MediaItem?> uploadRemoteImage({
    required String imageUrl,
    ValueChanged<double>? onUploadProgress,
    ValueChanged<MediaTransferProgress>? onTransferProgress,
  }) async {
    final remoteUri = Uri.tryParse(imageUrl.trim());
    if (remoteUri == null ||
        (remoteUri.scheme != 'http' && remoteUri.scheme != 'https')) {
      return null;
    }

    final uri = _resolve('/api/storage/upload');
    final request = http.MultipartRequest('POST', uri);
    if (!kIsWeb) {
      request.headers['Origin'] = '${uri.scheme}://${uri.authority}';
    }
    request.headers.addAll(await adminAuthHeaders());
    request.fields['type'] = 'image';
    request.fields['remoteUrl'] = remoteUri.toString();

    final client = httpClient ?? adminHttpClient;
    final closeClient = shouldCloseAdminHttpClient(client, httpClient);
    late final http.Response response;
    try {
      onTransferProgress?.call(
        const MediaTransferProgress(
          phase: 'downloading',
          progress: null,
          remaining: null,
        ),
      );
      final streamed = await client.send(request).timeout(_uploadTimeout);
      onUploadProgress?.call(1);
      onTransferProgress?.call(
        const MediaTransferProgress(
          phase: 'processing',
          progress: null,
          remaining: null,
        ),
      );
      response = await http.Response.fromStream(streamed).timeout(_timeout);
    } finally {
      if (closeClient) client.close();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) return null;

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return null;
    onTransferProgress?.call(
      const MediaTransferProgress(
        phase: 'done',
        progress: 1,
        remaining: Duration.zero,
      ),
    );

    return MediaItem(
      id: (decoded['id'] ?? '').toString(),
      value: (decoded['value'] ?? _remoteImageFileName(remoteUri, ''))
          .toString(),
      size: (decoded['size'] as num?)?.toInt() ?? 0,
      date: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      type: (decoded['type'] ?? 'image').toString(),
      src: (decoded['src'] ?? '').toString(),
      thumb: decoded['thumb']?.toString(),
      path: (decoded['id'] ?? '').toString().split('/').first,
    );
  }

  Future<http.StreamedResponse> _sendMultipartWithProgress(
    http.Client client,
    http.MultipartRequest request, {
    ValueChanged<double>? onUploadProgress,
    VoidCallback? onProcessing,
    ValueChanged<MediaTransferProgress>? onTransferProgress,
  }) {
    if (onUploadProgress == null &&
        onProcessing == null &&
        onTransferProgress == null) {
      return client.send(request);
    }

    final totalBytes = request.contentLength;
    final finalized = request.finalize();
    final streamedRequest = http.StreamedRequest(request.method, request.url)
      ..headers.addAll(request.headers)
      ..contentLength = totalBytes
      ..followRedirects = request.followRedirects
      ..maxRedirects = request.maxRedirects
      ..persistentConnection = request.persistentConnection;

    var sentBytes = 0;
    final startedAt = DateTime.now();
    final progressStream = _trackedUploadStream(
      finalized,
      totalBytes: totalBytes,
      onChunkSent: (chunkLength) {
        sentBytes += chunkLength;
        if (totalBytes <= 0) return;
        final progress = (sentBytes / totalBytes).clamp(0, 1).toDouble();
        onUploadProgress?.call(progress);
        onTransferProgress?.call(
          MediaTransferProgress(
            phase: 'uploading',
            progress: progress,
            remaining: _estimateRemaining(
              totalBytes: totalBytes,
              sentBytes: sentBytes,
              startedAt: startedAt,
            ),
          ),
        );
      },
    );

    unawaited(
      streamedRequest.sink.addStream(progressStream).then((_) {
        onUploadProgress?.call(1);
        onTransferProgress?.call(
          const MediaTransferProgress(
            phase: 'uploading',
            progress: 1,
            remaining: Duration.zero,
          ),
        );
        onProcessing?.call();
        return streamedRequest.sink.close();
      }),
    );

    return client.send(streamedRequest);
  }

  Stream<List<int>> _trackedUploadStream(
    Stream<List<int>> source, {
    required int totalBytes,
    required ValueChanged<int> onChunkSent,
  }) async* {
    const chunkSize = 64 * 1024;
    await for (final chunk in source) {
      var offset = 0;
      while (offset < chunk.length) {
        final end = math.min(offset + chunkSize, chunk.length);
        final part = chunk.sublist(offset, end);
        onChunkSent(part.length);
        yield part;
        offset = end;
      }
    }
  }

  Duration? _estimateRemaining({
    required int totalBytes,
    required int sentBytes,
    required DateTime startedAt,
  }) {
    if (sentBytes <= 0 || totalBytes <= sentBytes) return Duration.zero;
    final elapsedMs = DateTime.now().difference(startedAt).inMilliseconds;
    if (elapsedMs <= 0) return null;
    final bytesPerMs = sentBytes / elapsedMs;
    if (bytesPerMs <= 0) return null;
    return Duration(
      milliseconds: ((totalBytes - sentBytes) / bytesPerMs).round(),
    );
  }

  Future<void> _pollProcessingProgress(
    String uploadId, {
    required bool Function() shouldStop,
    required ValueChanged<MediaTransferProgress>? onProgress,
  }) async {
    if (onProgress == null) return;
    final client = adminHttpClient;
    try {
      while (!shouldStop()) {
        await Future<void>.delayed(const Duration(milliseconds: 350));
        if (shouldStop()) break;
        final uri = _resolve('/api/storage/upload-progress/$uploadId');
        final response = await client
            .get(uri)
            .timeout(const Duration(seconds: 4));
        if (response.statusCode < 200 || response.statusCode >= 300) continue;
        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) continue;
        final phase = (decoded['phase'] ?? 'processing').toString();
        final progress = (decoded['progress'] as num?)?.toDouble();
        final etaSeconds = (decoded['etaSeconds'] as num?)?.toDouble();
        onProgress(
          MediaTransferProgress(
            phase: phase == 'done' ? 'processing' : phase,
            progress: progress,
            remaining: etaSeconds == null
                ? null
                : Duration(milliseconds: (etaSeconds * 1000).round()),
          ),
        );
        if (phase == 'done' || phase == 'error') break;
      }
    } catch (_) {
      // Polling is a UI aid; the upload request response remains authoritative.
    }
  }

  String _newUploadId() {
    final micros = DateTime.now().microsecondsSinceEpoch;
    final random = math.Random().nextInt(0x7fffffff).toRadixString(16);
    return '$micros-$random';
  }

  Future<MediaSeoRenameResult?> renameMediaWithAi({
    required String src,
    String type = 'image',
    required String languageCode,
    required String mediaKind,
    required String context,
  }) async {
    final response = await _request(
      'POST',
      _resolve('/api/storage/seo-rename'),
      headers: await adminJsonHeaders(),
      body: jsonEncode({
        'src': src,
        'type': type,
        'languageCode': languageCode,
        'mediaKind': mediaKind,
        'context': context,
      }),
      timeout: _aiTimeout,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return MediaSeoRenameResult.failure(_responseError(response));
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return null;
    return MediaSeoRenameResult.fromJson(decoded);
  }

  Future<MediaSeoAltTextResult?> generateMediaAltTextWithAi({
    required String src,
    required String languageCode,
    required String mediaKind,
    required String context,
    String currentAlt = '',
  }) async {
    final response = await _request(
      'POST',
      _resolve('/api/storage/seo-alt-text'),
      headers: await adminJsonHeaders(),
      body: jsonEncode({
        'src': src,
        'languageCode': languageCode,
        'mediaKind': mediaKind,
        'context': context,
        'currentAlt': currentAlt,
      }),
      timeout: _aiTimeout,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) return null;

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return null;
    return MediaSeoAltTextResult.fromJson(decoded);
  }

  Future<MediaVideoThumbnailResult?> resolveVideoThumbnail({
    required String url,
    String title = '',
  }) async {
    final response = await _request(
      'POST',
      _resolve('/api/storage/video-thumbnail'),
      headers: await adminJsonHeaders(),
      body: jsonEncode({'url': url, 'title': title}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) return null;

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return null;
    return MediaVideoThumbnailResult.fromJson(decoded);
  }

  Future<bool> deleteFile(String fileId, {String? type}) async {
    final uri = _resolve('/api/storage/delete');
    final body = <String, dynamic>{'id': fileId};
    final normalizedType = type?.trim();
    if (normalizedType != null && normalizedType.isNotEmpty) {
      body['type'] = normalizedType;
    }
    final response = await _request(
      'DELETE',
      uri,
      body: jsonEncode(body),
      headers: await adminJsonHeaders(),
    );
    return response.statusCode >= 200 && response.statusCode < 300;
  }

  String resolveUrl(String path) => _resolve(path).toString();

  String resolveImageUrl(String path, {int? width, int? quality}) {
    final uri = _resolve(path);
    final query = <String, String>{...uri.queryParameters};
    if (width != null && width > 0) query['w'] = width.toString();
    if (quality != null && quality > 0) query['q'] = quality.toString();
    return uri
        .replace(queryParameters: query.isEmpty ? null : query)
        .toString();
  }

  void _addMultipartField(
    http.MultipartRequest request,
    String name,
    String? value,
  ) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) return;
    request.fields[name] = normalized;
  }

  Uri _resolve(String path) {
    final configured = (apiBaseUrl ?? _apiBaseUrl).trim();
    if (configured.isNotEmpty) return Uri.parse(configured).resolve(path);
    if (!kIsWeb) {
      final host = defaultTargetPlatform == TargetPlatform.android
          ? 'http://10.0.2.2:4321'
          : 'http://127.0.0.1:4321';
      return Uri.parse(host).resolve(path);
    }
    return Uri.base.resolve(path);
  }

  Future<http.Response> _get(Uri uri, {Map<String, String>? headers}) async {
    final client = httpClient ?? adminHttpClient;
    final closeClient = shouldCloseAdminHttpClient(client, httpClient);
    try {
      return await client.get(uri, headers: headers).timeout(_timeout);
    } finally {
      if (closeClient) client.close();
    }
  }

  Future<http.Response> _request(
    String method,
    Uri uri, {
    String? body,
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    final client = httpClient ?? adminHttpClient;
    final closeClient = shouldCloseAdminHttpClient(client, httpClient);
    try {
      final request = http.Request(method, uri);
      if (headers != null) request.headers.addAll(headers);
      if (!kIsWeb) {
        request.headers['Origin'] = '${uri.scheme}://${uri.authority}';
      }
      if (body != null) request.body = body;
      final effectiveTimeout = timeout ?? _timeout;
      final streamed = await (client.send(request)).timeout(effectiveTimeout);
      return http.Response.fromStream(streamed).timeout(effectiveTimeout);
    } finally {
      if (closeClient) client.close();
    }
  }
}

String _responseError(http.Response response) {
  final body = response.body.trim();
  if (body.isEmpty) return 'HTTP ${response.statusCode}';
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map) {
      final error = decoded['error'];
      if (error is String && error.trim().isNotEmpty) return error.trim();
      if (error is Map && error['message'] != null) {
        final message = error['message'].toString().trim();
        if (message.isNotEmpty) return message;
      }
    }
  } catch (_) {
    // Plain text response.
  }
  return body.length > 180 ? '${body.substring(0, 177)}...' : body;
}

String _remoteImageFileName(Uri uri, String contentType) {
  final lastSegment = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
  final decoded = Uri.decodeComponent(lastSegment).trim();
  final fallback = 'source-image-${DateTime.now().millisecondsSinceEpoch}';
  final name = decoded.isEmpty ? fallback : decoded;
  final pathExt = _extensionFromPath(name);
  final contentExt = _extensionFromContentType(contentType);
  final ext = contentExt.isNotEmpty
      ? contentExt
      : pathExt.isNotEmpty
      ? pathExt
      : 'jpg';
  final dotIndex = name.lastIndexOf('.');
  final base = dotIndex > 0 ? name.substring(0, dotIndex) : name;
  final safeBase = base.trim().isEmpty ? fallback : base.trim();
  return '$safeBase.$ext';
}

String _extensionFromPath(String path) {
  final cleanPath = path.split('?').first.split('#').first.toLowerCase();
  final dotIndex = cleanPath.lastIndexOf('.');
  if (dotIndex < 0 || dotIndex == cleanPath.length - 1) return '';
  final ext = cleanPath.substring(dotIndex + 1);
  return _knownImageExtensions.contains(ext) ? ext : '';
}

String _extensionFromContentType(String contentType) {
  final normalized = contentType.toLowerCase().split(';').first.trim();
  return switch (normalized) {
    'image/jpeg' || 'image/jpg' => 'jpg',
    'image/png' => 'png',
    'image/webp' => 'webp',
    'image/gif' => 'gif',
    'image/avif' => 'avif',
    'image/bmp' => 'bmp',
    'image/heic' => 'heic',
    'image/heif' => 'heif',
    'image/svg+xml' => 'svg',
    _ => '',
  };
}

const _knownImageExtensions = {
  'jpg',
  'jpeg',
  'png',
  'webp',
  'gif',
  'avif',
  'bmp',
  'heic',
  'heif',
  'svg',
};

const _imageUploadExtensions = {
  'jpg',
  'jpeg',
  'webp',
  'png',
  'gif',
  'avif',
  'bmp',
  'tif',
  'tiff',
  'heic',
  'heif',
  'svg',
};

const _videoUploadExtensions = {
  'mp4',
  'm4v',
  'webm',
  'mov',
  'avi',
  'mkv',
  '3gp',
  '3g2',
};

const _audioUploadExtensions = {
  'mp3',
  'wav',
  'ogg',
  'oga',
  'm4a',
  'aac',
  'flac',
  'opus',
};

const _fileUploadExtensions = {
  'pdf',
  'doc',
  'docx',
  'ppt',
  'pptx',
  'xls',
  'xlsx',
  'txt',
  'csv',
  'zip',
  'rar',
};

const _defaultAllowedUploadExtensions = {
  'jpg',
  'jpeg',
  'webp',
  'png',
  'gif',
  'avif',
  'heic',
  'svg',
  'mp4',
  'm4v',
  'webm',
  'mov',
  'avi',
  'mkv',
  '3gp',
  'mp3',
  'wav',
  'ogg',
  'm4a',
  'aac',
  'flac',
  'opus',
  'pdf',
  'doc',
  'docx',
  'ppt',
  'pptx',
  'xls',
  'xlsx',
  'txt',
  'csv',
  'zip',
  'rar',
};

String _imageFileFormat(Object? value, {required String fallback}) {
  final normalized = value?.toString().trim().toUpperCase();
  if (normalized == 'JPG') return 'JPEG';
  if (normalized == 'WEBP' || normalized == 'JPEG' || normalized == 'PNG') {
    return normalized!;
  }
  return fallback;
}

Set<String> _extensionSet(Object? value, {required Set<String> fallback}) {
  if (value is Iterable) {
    final parsed = value
        .map((item) => _cleanUploadExtension(item.toString()))
        .where((item) => item.isNotEmpty)
        .toSet();
    return parsed.isEmpty ? {...fallback} : parsed;
  }
  if (value is String) {
    try {
      final decoded = jsonDecode(value);
      return _extensionSet(decoded, fallback: fallback);
    } catch (_) {
      final parsed = value
          .split(RegExp(r'[\s,;]+'))
          .map(_cleanUploadExtension)
          .where((item) => item.isNotEmpty)
          .toSet();
      return parsed.isEmpty ? {...fallback} : parsed;
    }
  }
  return {...fallback};
}

String _cleanUploadExtension(String value) {
  return value.trim().toLowerCase().replaceFirst(RegExp(r'^\.+'), '');
}

int _megabyteLimit(Object? value, {required int fallback}) {
  if (value is num) return value.round().clamp(1, 1024).toInt();
  return (int.tryParse(value?.toString() ?? '') ?? fallback)
      .clamp(1, 1024)
      .toInt();
}

String _normalizeLanguageCode(String value) {
  final code = value.trim().toLowerCase().replaceAll('_', '-');
  return code.isEmpty ? 'tr' : code;
}
