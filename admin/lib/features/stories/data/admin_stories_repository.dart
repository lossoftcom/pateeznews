import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pateeznews_admin/core/network/admin_api_headers.dart';

import '../../auth/data/admin_auth_models.dart';
import '../presentation/stories_models.dart';

abstract class AdminStoriesRepository {
  Future<AdminStoriesPageResult> fetchStories({
    required String search,
    required int page,
    required int pageSize,
    required String sortKey,
    required bool sortAscending,
  });

  Future<void> upsertStory({
    required AdminSession session,
    required StoryFormData data,
    String? storyId,
  });

  Future<void> toggleStatus(AdminStory story);

  Future<void> deleteStory(String storyId);

  Future<void> deleteStories(List<String> storyIds);

  /// Loads the re-openable editor state for a single story.
  Future<AdminStoryContent> fetchStoryContent(String storyId);

  /// Persists the Web Stories editor output for an existing story.
  Future<void> saveStoryContent({
    required String storyId,
    required String title,
    required Map<String, dynamic> storyData,
    required String markup,
  });
}

class SupabaseAdminStoriesRepository implements AdminStoriesRepository {
  const SupabaseAdminStoriesRepository({this.httpClient, this.apiBaseUrl});

  static const _apiBaseUrl = String.fromEnvironment('PATEEZNEWS_API_BASE_URL');
  static const _requestTimeout = Duration(seconds: 8);

  final http.Client? httpClient;
  final String? apiBaseUrl;

  @override
  Future<AdminStoriesPageResult> fetchStories({
    required String search,
    required int page,
    required int pageSize,
    required String sortKey,
    required bool sortAscending,
  }) async {
    final filters = <Map<String, Object?>>[];
    final term = _safeSearchTerm(search);
    if (term.isNotEmpty) {
      final pattern = '%$term%';
      filters.add({
        'type': 'or',
        'value':
            'title.ilike.$pattern,source_name.ilike.$pattern,media_type.ilike.$pattern',
      });
    }

    final safePage = page < 1 ? 1 : page;
    final from = (safePage - 1) * pageSize;
    final to = from + pageSize - 1;
    final result = await _postJson('/api/admin/query', {
      'table': 'stories',
      'method': 'select',
      'select':
          'id,title,media_url,media_type,source_name,publisher_id,created_at,expires_at,is_active,view_count',
      'filters': filters,
      'orders': _storyOrders(sortKey, sortAscending),
      'range': {'from': from, 'to': to},
      'count': 'exact',
    });
    _throwIfApiError(result, fallbackMessage: 'Hikayeler alınamadı');

    final data = result['data'];
    final rows = data is List ? data.whereType<Map>().toList() : const <Map>[];
    return AdminStoriesPageResult(
      stories: [
        for (var index = 0; index < rows.length; index++)
          _storyFromJson(rows[index], from + index + 1),
      ],
      totalCount: _asInt(result['count']),
    );
  }

  @override
  Future<void> upsertStory({
    required AdminSession session,
    required StoryFormData data,
    String? storyId,
  }) async {
    final values = <String, Object?>{
      'title': data.title.trim(),
      'media_url': data.mediaUrl.trim(),
      'media_type': _normalizeMediaType(data.mediaType),
      'source_name': data.sourceName.trim().isEmpty
          ? null
          : data.sourceName.trim(),
      'publisher_id': session.user.id,
      'expires_at': data.expiresAt?.toUtc().toIso8601String(),
      'is_active': data.isActive,
    };
    final isUpdate = storyId != null && storyId.trim().isNotEmpty;
    final result = await _postJson('/api/admin/query', {
      'table': 'stories',
      'method': isUpdate ? 'update' : 'insert',
      'values': values,
      if (isUpdate) 'filters': [_idFilter(storyId)],
    });
    _throwIfApiError(
      result,
      fallbackMessage: isUpdate ? 'Hikaye güncellenemedi' : 'Hikaye eklenemedi',
    );
  }

  @override
  Future<void> toggleStatus(AdminStory story) async {
    final result = await _postJson('/api/admin/query', {
      'table': 'stories',
      'method': 'update',
      'values': {'is_active': !story.isActive},
      'filters': [_idFilter(story.id)],
    });
    _throwIfApiError(result, fallbackMessage: 'Hikaye durumu güncellenemedi');
  }

  @override
  Future<void> deleteStory(String storyId) async {
    final result = await _postJson('/api/admin/query', {
      'table': 'stories',
      'method': 'delete',
      'filters': [_idFilter(storyId)],
    });
    _throwIfApiError(result, fallbackMessage: 'Hikaye silinemedi');
  }

  @override
  Future<void> deleteStories(List<String> storyIds) async {
    if (storyIds.isEmpty) return;
    final result = await _postJson('/api/admin/query', {
      'table': 'stories',
      'method': 'delete',
      'filters': [
        {'type': 'comparison', 'op': 'in', 'column': 'id', 'value': storyIds},
      ],
    });
    _throwIfApiError(result, fallbackMessage: 'Seçili hikayeler silinemedi');
  }

  @override
  Future<AdminStoryContent> fetchStoryContent(String storyId) async {
    final result = await _postJson('/api/admin/query', {
      'table': 'stories',
      'method': 'select',
      'select': 'id,title,story_data,story_markup',
      'filters': [_idFilter(storyId)],
      'range': {'from': 0, 'to': 0},
    });
    _throwIfApiError(result, fallbackMessage: 'Hikaye içeriği alınamadı');

    final data = result['data'];
    final rows = data is List ? data.whereType<Map>().toList() : const <Map>[];
    if (rows.isEmpty) {
      throw const AdminStoriesException('Hikaye bulunamadı');
    }
    final row = rows.first;
    return AdminStoryContent(
      storyData: _decodeJsonMap(row['story_data']),
      title: _decodeText(row['title']),
      markup: row['story_markup']?.toString() ?? '',
    );
  }

  @override
  Future<void> saveStoryContent({
    required String storyId,
    required String title,
    required Map<String, dynamic> storyData,
    required String markup,
  }) async {
    final values = <String, Object?>{
      'story_data': storyData,
      'story_markup': markup,
    };
    // Only overwrite the title when the editor actually has one, so an empty
    // editor title never wipes the title set from the quick-add form.
    if (title.trim().isNotEmpty) {
      values['title'] = title.trim();
    }
    final result = await _postJson('/api/admin/query', {
      'table': 'stories',
      'method': 'update',
      'values': values,
      'filters': [_idFilter(storyId)],
    });
    _throwIfApiError(result, fallbackMessage: 'Hikaye kaydedilemedi');
  }

  Map<String, dynamic> _decodeJsonMap(Object? value) {
    if (value is Map) {
      return value.map((key, dynamic v) => MapEntry(key.toString(), v));
    }
    if (value is String && value.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) {
          return decoded.map((key, dynamic v) => MapEntry(key.toString(), v));
        }
      } catch (_) {
        /* fall through to empty */
      }
    }
    return <String, dynamic>{};
  }

  List<Map<String, Object?>> _storyOrders(String sortKey, bool ascending) {
    final column = switch (sortKey) {
      'id' => 'id',
      'story' => 'title',
      'views' => 'view_count',
      'expires' => 'expires_at',
      'status' => 'is_active',
      'date' => 'created_at',
      _ => 'created_at',
    };
    return [
      {'column': column, 'ascending': ascending},
    ];
  }

  AdminStory _storyFromJson(Map<dynamic, dynamic> json, int rowNumber) {
    return AdminStory(
      id: json['id']?.toString() ?? '',
      rowNumber: rowNumber,
      title: _decodeText(json['title']),
      mediaUrl: json['media_url']?.toString() ?? '',
      mediaType: _normalizeMediaType(json['media_type']?.toString() ?? ''),
      sourceName: _decodeText(json['source_name']),
      publisherId: json['publisher_id']?.toString() ?? '',
      createdAt: _parseDate(json['created_at']),
      expiresAt: _parseDate(json['expires_at']),
      isActive: json['is_active'] != false,
      viewCount: _asInt(json['view_count']),
    );
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, Object?> body,
  ) async {
    final client = httpClient ?? adminHttpClient;
    final closeClient = shouldCloseAdminHttpClient(client, httpClient);
    try {
      final uri = _resolveUri(path);
      final response = await client
          .post(uri, headers: await adminJsonHeaders(), body: jsonEncode(body))
          .timeout(_requestTimeout);
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      throw const AdminStoriesException('Geçersiz sunucu yanıtı');
    } on TimeoutException {
      throw const AdminStoriesException('Sunucu yanıtı zaman aşımına uğradı');
    } finally {
      if (closeClient) client.close();
    }
  }

  Uri _resolveUri(String path) {
    final configured = (apiBaseUrl ?? _apiBaseUrl).trim();
    if (configured.isNotEmpty) {
      return Uri.parse(configured).resolve(path);
    }
    if (!kIsWeb) {
      final host = defaultTargetPlatform == TargetPlatform.android
          ? 'http://10.0.2.2:4321'
          : 'http://127.0.0.1:4321';
      return Uri.parse(host).resolve(path);
    }
    return Uri.base.resolve(path);
  }

  Map<String, Object?> _idFilter(String storyId) {
    return {'type': 'comparison', 'op': 'eq', 'column': 'id', 'value': storyId};
  }

  String _safeSearchTerm(String value) {
    return value
        .trim()
        .replaceAll('%', r'\%')
        .replaceAll(',', ' ')
        .replaceAll('\n', ' ')
        .replaceAll('\r', ' ');
  }

  String _normalizeMediaType(String value) {
    return value.trim().toLowerCase() == 'video' ? 'video' : 'image';
  }

  DateTime? _parseDate(Object? value) {
    final raw = value?.toString();
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  String _decodeText(Object? value) {
    return _decodeHtmlEntities(
      value?.toString() ?? '',
    ).replaceAll('\u00a0', ' ').trim();
  }

  String _decodeHtmlEntities(String input) {
    const entities = {
      'amp': '&',
      'apos': "'",
      'Ccedil': 'Ç',
      'ccedil': 'ç',
      'Gbreve': 'Ğ',
      'gbreve': 'ğ',
      'hellip': '...',
      'Idot': 'İ',
      'imath': 'ı',
      'laquo': '"',
      'ldquo': '"',
      'lsquo': "'",
      'nbsp': ' ',
      'Ouml': 'Ö',
      'ouml': 'ö',
      'quot': '"',
      'raquo': '"',
      'rdquo': '"',
      'rsquo': "'",
      'Scedil': 'Ş',
      'scedil': 'ş',
      'Uuml': 'Ü',
      'uuml': 'ü',
    };

    String decodePoint(String value, int radix, String fallback) {
      final codePoint = int.tryParse(value, radix: radix);
      if (codePoint == null ||
          codePoint <= 0 ||
          codePoint == 60 ||
          codePoint == 62) {
        return fallback;
      }
      try {
        return String.fromCharCode(codePoint);
      } catch (_) {
        return fallback;
      }
    }

    String decodeOnce(String value) {
      return value
          .replaceAllMapped(
            RegExp(r'&([a-zA-Z][a-zA-Z0-9]+);'),
            (match) => entities[match.group(1)] ?? match.group(0)!,
          )
          .replaceAllMapped(
            RegExp(r'&#x([0-9a-fA-F]+);'),
            (match) => decodePoint(match.group(1)!, 16, match.group(0)!),
          )
          .replaceAllMapped(
            RegExp(r'&#(\d+);'),
            (match) => decodePoint(match.group(1)!, 10, match.group(0)!),
          );
    }

    return decodeOnce(decodeOnce(input));
  }

  int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  void _throwIfApiError(
    Map<String, dynamic> response, {
    required String fallbackMessage,
  }) {
    final error = response['error'];
    if (error == null) return;
    if (error is Map && error['message'] != null) {
      throw AdminStoriesException(error['message'].toString());
    }
    throw AdminStoriesException(fallbackMessage);
  }
}

class AdminStoriesException implements Exception {
  const AdminStoriesException(this.message);

  final String message;

  @override
  String toString() => message;
}
