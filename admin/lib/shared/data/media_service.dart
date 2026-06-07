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

class MediaService {
  MediaService({this.httpClient, this.apiBaseUrl});

  static const _apiBaseUrl = String.fromEnvironment('PATEEZNEWS_API_BASE_URL');
  static const _timeout = Duration(seconds: 15);
  static const _uploadTimeout = Duration(seconds: 120);

  final http.Client? httpClient;
  final String? apiBaseUrl;

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
        .toList();
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
          : 'http://localhost:4321';
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
      final streamed = await (client.send(request)).timeout(_timeout);
      return http.Response.fromStream(streamed);
    } finally {
      if (closeClient) client.close();
    }
  }
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
