import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pateeznews_admin/core/network/admin_api_headers.dart';
import 'package:pateeznews_admin/shared/data/admin_request_retry.dart';

class AutomaticNewsSource {
  const AutomaticNewsSource({
    required this.id,
    required this.url,
    required this.displayName,
    required this.sourceType,
    required this.isActive,
    required this.pollIntervalMinutes,
    required this.lastCheckedAt,
    required this.lastSuccessAt,
    required this.lastError,
  });

  factory AutomaticNewsSource.fromJson(Map<String, Object?> json) {
    return AutomaticNewsSource(
      id: json['id']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? '',
      sourceType: json['sourceType']?.toString() ?? 'website',
      isActive: json['isActive'] != false,
      pollIntervalMinutes: _asInt(json['pollIntervalMinutes'], fallback: 5),
      lastCheckedAt: _parseDate(json['lastCheckedAt']),
      lastSuccessAt: _parseDate(json['lastSuccessAt']),
      lastError: json['lastError']?.toString() ?? '',
    );
  }

  final String id;
  final String url;
  final String displayName;
  final String sourceType;
  final bool isActive;
  final int pollIntervalMinutes;
  final DateTime? lastCheckedAt;
  final DateTime? lastSuccessAt;
  final String lastError;
}

class AutomaticNewsItem {
  const AutomaticNewsItem({
    required this.id,
    required this.displayId,
    required this.sourceId,
    required this.sourceName,
    required this.sourceType,
    required this.sourceUrl,
    required this.canonicalUrl,
    required this.title,
    required this.summary,
    required this.contentText,
    required this.category,
    required this.status,
    required this.languageCode,
    required this.originLabel,
    required this.qualityScore,
    required this.imageUrl,
    required this.videoUrl,
    required this.publishedAt,
    required this.capturedAt,
  });

  factory AutomaticNewsItem.fromJson(Map<String, Object?> json) {
    return AutomaticNewsItem(
      id: json['id']?.toString() ?? '',
      displayId: _asInt(json['displayId']),
      sourceId: json['sourceId']?.toString() ?? '',
      sourceName: json['sourceName']?.toString() ?? '',
      sourceType: json['sourceType']?.toString() ?? '',
      sourceUrl: json['sourceUrl']?.toString() ?? '',
      canonicalUrl: json['canonicalUrl']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      contentText: json['contentText']?.toString() ?? '',
      category: json['category']?.toString() ?? 'Gündem',
      status: json['status']?.toString() ?? 'Hazır',
      languageCode: json['languageCode']?.toString() ?? 'tr',
      originLabel: json['originLabel']?.toString() ?? '',
      qualityScore: _asInt(json['qualityScore']),
      imageUrl: json['imageUrl']?.toString() ?? '',
      videoUrl: json['videoUrl']?.toString() ?? '',
      publishedAt: _parseDate(json['publishedAt']),
      capturedAt: _parseDate(json['capturedAt']) ?? DateTime.now(),
    );
  }

  final String id;
  final int displayId;
  final String sourceId;
  final String sourceName;
  final String sourceType;
  final String sourceUrl;
  final String canonicalUrl;
  final String title;
  final String summary;
  final String contentText;
  final String category;
  final String status;
  final String languageCode;
  final String originLabel;
  final int qualityScore;
  final String imageUrl;
  final String videoUrl;
  final DateTime? publishedAt;
  final DateTime capturedAt;
}

class AutomaticNewsPageResult {
  const AutomaticNewsPageResult({
    required this.items,
    required this.totalCount,
  });

  final List<AutomaticNewsItem> items;
  final int totalCount;
}

class AutomaticNewsImageFile {
  const AutomaticNewsImageFile({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
  });

  final Uint8List bytes;
  final String fileName;
  final String mimeType;
}

class AutomaticNewsRefreshResult {
  const AutomaticNewsRefreshResult({
    required this.status,
    required this.checkedSources,
    required this.candidatesFound,
    required this.insertedCount,
    required this.skippedDuplicateCount,
    required this.errorCount,
    required this.errors,
    required this.previews,
  });

  factory AutomaticNewsRefreshResult.fromJson(Map<String, Object?> json) {
    final rawErrors = json['errors'];
    final rawPreviews = json['previews'];
    return AutomaticNewsRefreshResult(
      status: json['status']?.toString() ?? '',
      checkedSources: _asInt(json['checkedSources']),
      candidatesFound: _asInt(json['candidatesFound']),
      insertedCount: _asInt(json['insertedCount']),
      skippedDuplicateCount: _asInt(json['skippedDuplicateCount']),
      errorCount: _asInt(json['errorCount']),
      errors: rawErrors is List
          ? [
              for (final item in rawErrors)
                if (item is Map)
                  AutomaticNewsRefreshError.fromJson(_asStringKeyMap(item)),
            ]
          : const [],
      previews: rawPreviews is List
          ? [
              for (final item in rawPreviews)
                if (item is Map)
                  AutomaticNewsSourcePreview.fromJson(_asStringKeyMap(item)),
            ]
          : const [],
    );
  }

  final String status;
  final int checkedSources;
  final int candidatesFound;
  final int insertedCount;
  final int skippedDuplicateCount;
  final int errorCount;
  final List<AutomaticNewsRefreshError> errors;
  final List<AutomaticNewsSourcePreview> previews;
}

class AutomaticNewsRefreshError {
  const AutomaticNewsRefreshError({
    required this.sourceId,
    required this.sourceName,
    required this.sourceUrl,
    required this.message,
  });

  factory AutomaticNewsRefreshError.fromJson(Map<String, Object?> json) {
    return AutomaticNewsRefreshError(
      sourceId: json['sourceId']?.toString() ?? '',
      sourceName: json['sourceName']?.toString() ?? '',
      sourceUrl: json['sourceUrl']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
    );
  }

  final String sourceId;
  final String sourceName;
  final String sourceUrl;
  final String message;
}

class AutomaticNewsSourcePreview {
  const AutomaticNewsSourcePreview({
    required this.sourceId,
    required this.sourceName,
    required this.sourceUrl,
    required this.title,
    required this.url,
    required this.inserted,
  });

  factory AutomaticNewsSourcePreview.fromJson(Map<String, Object?> json) {
    return AutomaticNewsSourcePreview(
      sourceId: json['sourceId']?.toString() ?? '',
      sourceName: json['sourceName']?.toString() ?? '',
      sourceUrl: json['sourceUrl']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      inserted: json['inserted'] == true,
    );
  }

  final String sourceId;
  final String sourceName;
  final String sourceUrl;
  final String title;
  final String url;
  final bool inserted;
}

abstract class AdminAutomaticNewsRepository {
  Future<AutomaticNewsPageResult> fetchItems({
    required String search,
    required String platform,
    required String category,
    required String status,
    required String language,
    required int page,
    required int pageSize,
    required String sortKey,
    required bool sortAscending,
  });

  Future<List<AutomaticNewsSource>> fetchSources();

  Future<List<AutomaticNewsSource>> addSources(List<String> urls);

  Future<List<AutomaticNewsSource>> saveSources(List<String> urls);

  Future<AutomaticNewsSource?> setSourceActive({
    required String id,
    required bool isActive,
  });

  Future<AutomaticNewsRefreshResult> refreshNow();

  Future<AutomaticNewsRefreshResult> testSources();

  Future<AutomaticNewsImageFile> downloadImage(String id);

  Future<void> deleteItems(List<String> ids);
}

class SupabaseAdminAutomaticNewsRepository
    implements AdminAutomaticNewsRepository {
  const SupabaseAdminAutomaticNewsRepository({
    this.httpClient,
    this.apiBaseUrl,
  });

  static const _apiBaseUrl = String.fromEnvironment('PATEEZNEWS_API_BASE_URL');
  static const _requestTimeout = Duration(seconds: 12);
  static const _refreshTimeout = Duration(seconds: 40);

  final http.Client? httpClient;
  final String? apiBaseUrl;

  @override
  Future<AutomaticNewsPageResult> fetchItems({
    required String search,
    required String platform,
    required String category,
    required String status,
    required String language,
    required int page,
    required int pageSize,
    required String sortKey,
    required bool sortAscending,
  }) async {
    final query = <String, String>{
      'search': search.trim(),
      'platform': platform,
      'category': category,
      'status': status,
      'language': language,
      'page': '$page',
      'pageSize': '$pageSize',
      'sortKey': sortKey,
      'sortAscending': sortAscending ? '1' : '0',
    }..removeWhere((_, value) => value.isEmpty);
    final uri = _resolveUri(
      '/api/admin/automatic-news/items',
    ).replace(queryParameters: query);
    final result = await withAdminRetry(() => _getJson(uri));
    _throwIfApiError(result, fallbackMessage: 'Otomatik haberler alınamadı');
    final data = result['data'];
    final rows = data is List ? data.whereType<Map>().toList() : const <Map>[];
    return AutomaticNewsPageResult(
      items: [
        for (final row in rows)
          AutomaticNewsItem.fromJson(_asStringKeyMap(row)),
      ],
      totalCount: _asInt(result['count']),
    );
  }

  @override
  Future<List<AutomaticNewsSource>> fetchSources() async {
    final result = await withAdminRetry(
      () => _getJson(_resolveUri('/api/admin/automatic-news/sources')),
    );
    _throwIfApiError(result, fallbackMessage: 'Kaynak adresleri alınamadı');
    final data = result['data'];
    if (data is! List) return const [];
    return [
      for (final row in data)
        if (row is Map) AutomaticNewsSource.fromJson(_asStringKeyMap(row)),
    ];
  }

  @override
  Future<List<AutomaticNewsSource>> addSources(List<String> urls) async {
    final result = await _postJson('/api/admin/automatic-news/sources', {
      'action': 'addMany',
      'urls': urls,
    });
    _throwIfApiError(result, fallbackMessage: 'Adresler kaydedilemedi');
    final data = result['data'];
    if (data is! List) return const [];
    return [
      for (final row in data)
        if (row is Map) AutomaticNewsSource.fromJson(_asStringKeyMap(row)),
    ];
  }

  @override
  Future<List<AutomaticNewsSource>> saveSources(List<String> urls) async {
    final result = await _postJson('/api/admin/automatic-news/sources', {
      'action': 'sync',
      'urls': urls,
    });
    _throwIfApiError(result, fallbackMessage: 'Adresler güncellenemedi');
    final data = result['data'];
    if (data is! List) return const [];
    return [
      for (final row in data)
        if (row is Map) AutomaticNewsSource.fromJson(_asStringKeyMap(row)),
    ];
  }

  @override
  Future<AutomaticNewsSource?> setSourceActive({
    required String id,
    required bool isActive,
  }) async {
    final result = await _postJson('/api/admin/automatic-news/sources', {
      'action': 'setActive',
      'id': id,
      'isActive': isActive,
    });
    _throwIfApiError(result, fallbackMessage: 'Kaynak durumu güncellenemedi');
    final data = result['data'];
    return data is Map
        ? AutomaticNewsSource.fromJson(_asStringKeyMap(data))
        : null;
  }

  @override
  Future<AutomaticNewsRefreshResult> refreshNow() async {
    final result = await _postJson('/api/admin/automatic-news/refresh', {
      'force': true,
      'pageSize': 25,
    }, timeout: _refreshTimeout);
    _throwIfApiError(result, fallbackMessage: 'Haberler çekilemedi');
    final data = result['data'];
    final totals = data is Map ? data['totals'] : null;
    if (totals is Map) {
      return AutomaticNewsRefreshResult.fromJson(_asStringKeyMap(totals));
    }
    return const AutomaticNewsRefreshResult(
      status: '',
      checkedSources: 0,
      candidatesFound: 0,
      insertedCount: 0,
      skippedDuplicateCount: 0,
      errorCount: 0,
      errors: [],
      previews: [],
    );
  }

  @override
  Future<AutomaticNewsRefreshResult> testSources() async {
    final result = await _postJson('/api/admin/automatic-news/refresh', {
      'mode': 'test',
      'pageSize': 25,
    }, timeout: _refreshTimeout);
    _throwIfApiError(result, fallbackMessage: 'Kaynaklar test edilemedi');
    final data = result['data'];
    final totals = data is Map ? data['totals'] : null;
    if (totals is Map) {
      return AutomaticNewsRefreshResult.fromJson(_asStringKeyMap(totals));
    }
    return const AutomaticNewsRefreshResult(
      status: '',
      checkedSources: 0,
      candidatesFound: 0,
      insertedCount: 0,
      skippedDuplicateCount: 0,
      errorCount: 0,
      errors: [],
      previews: [],
    );
  }

  @override
  Future<AutomaticNewsImageFile> downloadImage(String id) async {
    final normalized = id.trim();
    if (normalized.isEmpty) {
      throw const AutomaticNewsException('İndirilecek haber seçilmedi');
    }
    final uri = _resolveUri(
      '/api/admin/automatic-news/image',
    ).replace(queryParameters: {'id': normalized});
    final client = httpClient ?? adminHttpClient;
    final closeClient = shouldCloseAdminHttpClient(client, httpClient);
    try {
      final response = await client
          .get(uri, headers: await adminAuthHeaders())
          .timeout(_requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _throwBytesApiError(
          response,
          fallbackMessage: 'Otomatik haber görseli indirilemedi',
        );
      }
      final rawFileName = response.headers['x-pateez-file-name'] ?? '';
      final decodedFileName = rawFileName.isEmpty
          ? ''
          : Uri.decodeComponent(rawFileName);
      final mimeType =
          response.headers['content-type']?.split(';').first.trim() ??
          'application/octet-stream';
      return AutomaticNewsImageFile(
        bytes: response.bodyBytes,
        fileName: decodedFileName.isEmpty
            ? 'otomatik-haber-gorseli.jpg'
            : decodedFileName,
        mimeType: mimeType.isEmpty ? 'application/octet-stream' : mimeType,
      );
    } on TimeoutException {
      throw const AutomaticNewsException('Sunucu yanıtı zaman aşımına uğradı');
    } finally {
      if (closeClient) client.close();
    }
  }

  @override
  Future<void> deleteItems(List<String> ids) async {
    final normalized = ids
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList();
    if (normalized.isEmpty) return;
    final result = await _postJson('/api/admin/automatic-news/items', {
      'action': 'delete',
      'ids': normalized,
    });
    _throwIfApiError(
      result,
      fallbackMessage: 'Seçili otomatik haberler silinemedi',
    );
  }

  Future<Map<String, Object?>> _getJson(Uri uri) async {
    final client = httpClient ?? adminHttpClient;
    final closeClient = shouldCloseAdminHttpClient(client, httpClient);
    try {
      final response = await client
          .get(uri, headers: await adminAuthHeaders())
          .timeout(_requestTimeout);
      final decoded = response.body.isEmpty
          ? <String, Object?>{}
          : jsonDecode(response.body);
      if (decoded is! Map) {
        throw const AutomaticNewsException('Geçersiz sunucu yanıtı');
      }
      final result = _asStringKeyMap(decoded);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _throwIfApiError(result, fallbackMessage: 'Sunucu isteği başarısız');
      }
      return result;
    } on TimeoutException {
      throw const AutomaticNewsException('Sunucu yanıtı zaman aşımına uğradı');
    } finally {
      if (closeClient) client.close();
    }
  }

  Future<Map<String, Object?>> _postJson(
    String path,
    Map<String, Object?> body, {
    Duration? timeout,
  }) async {
    final client = httpClient ?? adminHttpClient;
    final closeClient = shouldCloseAdminHttpClient(client, httpClient);
    try {
      final response = await client
          .post(
            _resolveUri(path),
            headers: await adminJsonHeaders(),
            body: jsonEncode(body),
          )
          .timeout(timeout ?? _requestTimeout);
      final decoded = response.body.isEmpty
          ? <String, Object?>{}
          : jsonDecode(response.body);
      if (decoded is! Map) {
        throw const AutomaticNewsException('Geçersiz sunucu yanıtı');
      }
      final result = _asStringKeyMap(decoded);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _throwIfApiError(result, fallbackMessage: 'Sunucu isteği başarısız');
      }
      return result;
    } on TimeoutException {
      throw const AutomaticNewsException('Sunucu yanıtı zaman aşımına uğradı');
    } finally {
      if (closeClient) client.close();
    }
  }

  Uri _resolveUri(String path) {
    final configured = (apiBaseUrl ?? _apiBaseUrl).trim();
    if (configured.isNotEmpty) return Uri.parse(configured).resolve(path);
    if (!kIsWeb) {
      final host = defaultTargetPlatform == TargetPlatform.android
          ? 'https://pateez.com'
          : 'https://pateez.com';
      return Uri.parse(host).resolve(path);
    }
    return Uri.base.resolve(path);
  }

  void _throwIfApiError(
    Map<String, Object?> result, {
    required String fallbackMessage,
  }) {
    final error = result['error'];
    if (error == null) return;
    if (error is Map) {
      final message = error['message']?.toString();
      throw AutomaticNewsException(
        message == null || message.isEmpty ? fallbackMessage : message,
      );
    }
    throw AutomaticNewsException(fallbackMessage);
  }

  void _throwBytesApiError(
    http.Response response, {
    required String fallbackMessage,
  }) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map) {
        _throwIfApiError(
          _asStringKeyMap(decoded),
          fallbackMessage: fallbackMessage,
        );
      }
    } catch (_) {
      // Fall through to the stable fallback message.
    }
    throw AutomaticNewsException(fallbackMessage);
  }
}

class AutomaticNewsException implements Exception {
  const AutomaticNewsException(this.message);

  final String message;

  @override
  String toString() => message;
}

int _asInt(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

DateTime? _parseDate(Object? value) {
  final raw = value?.toString();
  if (raw == null || raw.isEmpty) return null;
  return DateTime.tryParse(raw)?.toLocal();
}

Map<String, Object?> _asStringKeyMap(Map<dynamic, dynamic> value) {
  return value.map((key, nestedValue) => MapEntry(key.toString(), nestedValue));
}
