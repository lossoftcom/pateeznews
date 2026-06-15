import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pateeznews_admin/core/network/admin_api_headers.dart';
import 'package:pateeznews_admin/shared/data/admin_request_retry.dart';

import '../presentation/news_models.dart';

abstract class AdminNewsRepository {
  Future<AdminNewsMetricData> fetchMetrics();

  Future<AdminNewsFilterOptions> fetchFilterOptions();

  Future<AdminNewsPageResult> fetchPosts({
    required String search,
    required String language,
    required String category,
    required String type,
    required String status,
    required String publisher,
    required bool trash,
    required bool videoOnly,
    required int page,
    required int pageSize,
    required String sortKey,
    required bool sortAscending,
  });

  Future<void> toggleStatus(AdminNewsPost post);

  Future<void> togglePinned(AdminNewsPost post);

  Future<void> deletePost(String postId);

  Future<void> deletePosts(List<String> postIds);

  Future<AdminNewsEditorBootstrap> fetchEditorBootstrap();

  Future<AdminNewsEditorPost> fetchEditorPost(String postId);

  Future<int> countPinnedPosts({String? excludingPostId});

  Future<AdminNewsEditorPost> saveEditorPost({
    required String? postId,
    required AdminNewsEditorSavePayload payload,
  });
}

class SupabaseAdminNewsRepository implements AdminNewsRepository {
  const SupabaseAdminNewsRepository({this.httpClient, this.apiBaseUrl});

  static const _apiBaseUrl = String.fromEnvironment('PATEEZNEWS_API_BASE_URL');
  static const _requestTimeout = Duration(seconds: 8);

  final http.Client? httpClient;
  final String? apiBaseUrl;

  @override
  Future<AdminNewsMetricData> fetchMetrics() async {
    final response = await withAdminRetry(
      () => _getJson('/api/admin/news/metrics'),
    );
    _throwIfApiError(
      response,
      fallbackMessage: 'Haber istatistikleri alınamadı',
    );
    final data = response['data'];
    return AdminNewsMetricData(
      total: data is Map ? _asInt(data['total']) : 0,
      published: data is Map ? _asInt(data['published']) : 0,
      views: data is Map ? _asInt(data['views']) : 0,
      scheduled: data is Map ? _asInt(data['scheduled']) : 0,
    );
  }

  @override
  Future<AdminNewsFilterOptions> fetchFilterOptions() async {
    final response = await withAdminRetry(
      () => _getJson('/api/admin/news/filters'),
    );
    _throwIfApiError(response, fallbackMessage: 'Haber filtreleri alınamadı');
    final data = response['data'];
    return AdminNewsFilterOptions(
      languages: data is Map ? _filterItems(data['languages']) : const [],
      categories: data is Map ? _filterItems(data['categories']) : const [],
      types: data is Map ? _filterItems(data['types']) : const [],
      publishers: data is Map ? _filterItems(data['publishers']) : const [],
    );
  }

  @override
  Future<AdminNewsPageResult> fetchPosts({
    required String search,
    required String language,
    required String category,
    required String type,
    required String status,
    required String publisher,
    required bool trash,
    required bool videoOnly,
    required int page,
    required int pageSize,
    required String sortKey,
    required bool sortAscending,
  }) async {
    final safePage = page < 1 ? 1 : page;
    final from = (safePage - 1) * pageSize;
    final result = await withAdminRetry(
      () => _postJson('/api/admin/news/list', {
        'search': _safeSearchTerm(search),
        'language': language,
        'category': category,
        'type': type,
        'status': status,
        'publisher': publisher,
        'trash': trash,
        'videoOnly': videoOnly,
        'page': safePage,
        'pageSize': pageSize,
        'sortKey': sortKey,
        'sortAscending': sortAscending,
      }),
    );
    _throwIfApiError(result, fallbackMessage: 'Haberler alınamadı');

    final data = result['data'];
    final rows = data is List ? data.whereType<Map>().toList() : const <Map>[];
    return AdminNewsPageResult(
      posts: [
        for (var index = 0; index < rows.length; index++)
          _postFromJson(rows[index], from + index + 1),
      ],
      totalCount: _asInt(result['count']),
    );
  }

  @override
  Future<void> toggleStatus(AdminNewsPost post) async {
    final nextStatus = post.published ? 'draft' : 'published';
    final result = await _postJson('/api/admin/query', {
      'table': 'posts',
      'method': 'update',
      'values': {
        'status': nextStatus,
        'published_at': nextStatus == 'published'
            ? DateTime.now().toUtc().toIso8601String()
            : null,
      },
      'filters': [_idFilter(post.id)],
    });
    _throwIfApiError(result, fallbackMessage: 'Haber durumu güncellenemedi');
  }

  @override
  Future<void> togglePinned(AdminNewsPost post) async {
    final nextPinned = !post.isPinned;
    if (nextPinned) {
      final countResult = await _postJson('/api/admin/query', {
        'table': 'posts',
        'method': 'select',
        'select': 'id',
        'filters': [_eqFilter('is_pinned', true)],
        'count': 'exact',
        'head': true,
      });
      _throwIfApiError(
        countResult,
        fallbackMessage: 'Sabit haberler alınamadı',
      );
      if (_asInt(countResult['count']) >= 2) {
        throw const AdminNewsException('En fazla 2 haber sabitlenebilir.');
      }
    }

    final result = await _postJson('/api/admin/query', {
      'table': 'posts',
      'method': 'update',
      'values': {'is_pinned': nextPinned},
      'filters': [_idFilter(post.id)],
    });
    _throwIfApiError(
      result,
      fallbackMessage: 'Haber sabitleme işlemi tamamlanamadı',
    );
  }

  @override
  Future<void> deletePost(String postId) async {
    final result = await _postJson('/api/admin/news/delete', {'id': postId});
    _throwIfApiError(result, fallbackMessage: 'Haber silinemedi');
  }

  @override
  Future<void> deletePosts(List<String> postIds) async {
    final ids = postIds.map(int.tryParse).whereType<int>().toList();
    if (ids.isEmpty) return;
    final result = await _postJson('/api/admin/news/delete', {'ids': ids});
    _throwIfApiError(result, fallbackMessage: 'Seçili haberler silinemedi');
  }

  @override
  Future<AdminNewsEditorBootstrap> fetchEditorBootstrap() async {
    final responses = await Future.wait([
      _postJson('/api/admin/query', {
        'table': 'languages',
        'method': 'select',
        'select': 'code,name',
        'orders': [
          {'column': 'name', 'ascending': true},
        ],
      }),
      _postJson('/api/admin/query', {
        'table': 'navigation_menus',
        'method': 'select',
        'select': 'id,code',
      }),
      _postJson('/api/admin/query', {
        'table': 'navigation_items',
        'method': 'select',
        'select':
            'id,menu_id,label,parent_id,language_code,order_index,type,value,icon',
        'orders': [
          {'column': 'order_index', 'ascending': true},
          {'column': 'label', 'ascending': true},
        ],
      }),
      _postJson('/api/admin/query', {
        'table': 'profiles',
        'method': 'select',
        'select': 'id,full_name,username,email,role',
        'orders': [
          {'column': 'full_name', 'ascending': true},
        ],
      }),
    ]);

    for (final response in responses) {
      _throwIfApiError(
        response,
        fallbackMessage: 'Haber editör verileri alınamadı',
      );
    }

    final languageRows = responses[0]['data'] is List
        ? (responses[0]['data'] as List).whereType<Map>().toList()
        : const <Map>[];
    final menuRows = responses[1]['data'] is List
        ? (responses[1]['data'] as List).whereType<Map>().toList()
        : const <Map>[];
    final rawCategoryRows = responses[2]['data'] is List
        ? (responses[2]['data'] as List).whereType<Map>().toList()
        : const <Map>[];
    final publisherRows = responses[3]['data'] is List
        ? (responses[3]['data'] as List).whereType<Map>().toList()
        : const <Map>[];
    final sidebarMenuIds = menuRows
        .where((row) => row['code']?.toString() == 'sidebar_main')
        .map((row) => row['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    final categoryRows = sidebarMenuIds.isEmpty
        ? rawCategoryRows
        : rawCategoryRows
              .where(
                (row) =>
                    sidebarMenuIds.contains(row['menu_id']?.toString() ?? ''),
              )
              .toList(growable: false);

    return AdminNewsEditorBootstrap(
      languages: [
        for (final row in languageRows)
          if ((row['code']?.toString().trim() ?? '').isNotEmpty)
            AdminNewsEditorLanguage.fromJson({
              ...row,
              'name': _decodeText(row['name']),
            }),
      ],
      categories: [
        for (final row in categoryRows)
          if ((row['label']?.toString().trim() ?? '').isNotEmpty)
            AdminNewsEditorCategory.fromJson({
              ...row,
              'label': _decodeText(row['label']),
            }),
      ],
      publishers: [
        for (final row in publisherRows)
          if ((row['id']?.toString().trim() ?? '').isNotEmpty)
            AdminNewsEditorPublisher.fromJson({
              ...row,
              'full_name': _decodeText(row['full_name']),
              'username': _decodeText(row['username']),
              'email': _decodeText(row['email']),
            }),
      ],
    );
  }

  @override
  Future<AdminNewsEditorPost> fetchEditorPost(String postId) async {
    final result = await _postJson('/api/admin/query', {
      'table': 'posts',
      'method': 'select',
      'select':
          'id,title,summary,category,type,thumbnail_url,thumbnail_alt,seo_title,seo_description,keywords,slug,status,language_code,publisher_id,is_pinned,show_in_manset,fact_checked,schema_type,published_at,card_data,items,faq_data',
      'filters': [_idFilter(postId)],
      'single': 'single',
    });
    _throwIfApiError(result, fallbackMessage: 'Haber detayı alınamadı');
    final data = result['data'];
    if (data is! Map) {
      throw const AdminNewsException('Haber detayı bulunamadı');
    }
    return AdminNewsEditorPost.fromJson(data);
  }

  @override
  Future<int> countPinnedPosts({String? excludingPostId}) async {
    final filters = <Map<String, Object?>>[_eqFilter('is_pinned', true)];
    if (excludingPostId != null && excludingPostId.trim().isNotEmpty) {
      filters.add({
        'type': 'comparison',
        'op': 'neq',
        'column': 'id',
        'value': int.tryParse(excludingPostId) ?? excludingPostId,
      });
    }
    final result = await _postJson('/api/admin/query', {
      'table': 'posts',
      'method': 'select',
      'select': 'id',
      'filters': filters,
      'count': 'exact',
      'head': true,
    });
    _throwIfApiError(result, fallbackMessage: 'Sabit haberler alınamadı');
    return _asInt(result['count']);
  }

  @override
  Future<AdminNewsEditorPost> saveEditorPost({
    required String? postId,
    required AdminNewsEditorSavePayload payload,
  }) async {
    final editing = postId != null && postId.trim().isNotEmpty;
    final values = Map<String, Object?>.from(payload.values);
    values['updated_at'] = DateTime.now().toUtc().toIso8601String();
    if (!editing) {
      values.putIfAbsent('likes_count', () => 0);
      values.putIfAbsent('shares_count', () => 0);
      values.putIfAbsent('comments_count', () => 0);
      values.putIfAbsent('views_count', () => 0);
    }

    final result = await _postJson('/api/admin/query', {
      'table': 'posts',
      'method': editing ? 'update' : 'insert',
      'values': values,
      if (editing) 'filters': [_idFilter(postId)],
      'single': 'single',
    });
    _throwIfApiError(
      result,
      fallbackMessage: editing ? 'Haber güncellenemedi' : 'Haber eklenemedi',
    );
    final data = result['data'];
    if (data is! Map) {
      throw const AdminNewsException('Haber kaydı döndürülemedi');
    }
    return AdminNewsEditorPost.fromJson(data);
  }

  List<AdminNewsFilterItem> _filterItems(Object? data) {
    if (data is! List) return const [];
    return [
      for (final row in data.whereType<Map>())
        if ((row['id']?.toString().trim() ?? '').isNotEmpty)
          AdminNewsFilterItem(
            id: row['id'].toString(),
            label: _decodeText(row['label']),
            parentLabel: _decodeText(row['parent_label'] ?? row['parentLabel']),
          ),
    ];
  }

  AdminNewsPost _postFromJson(Map<dynamic, dynamic> json, int rowNumber) {
    final profiles = json['profiles'];
    final profile = profiles is Map ? profiles : const {};
    final category = _decodeText(json['category']);
    return AdminNewsPost(
      id: json['id']?.toString() ?? '',
      rowNumber: rowNumber,
      title: _decodeText(json['title']),
      category: category,
      type: json['type']?.toString() ?? '',
      status: json['status']?.toString() ?? 'draft',
      slug: json['slug']?.toString() ?? '',
      createdAt: _parseDate(json['created_at']),
      thumbnailUrl: json['thumbnail_url']?.toString() ?? '',
      viewsCount: _asInt(json['views_count'] ?? json['likes_count']),
      commentsCount: _asInt(json['comments_count']),
      languageCode: json['language_code']?.toString() ?? 'tr',
      isPinned: json['is_pinned'] == true,
      publisherId: json['publisher_id']?.toString() ?? '',
      publisherName: _decodeText(profile['full_name']),
      publisherUsername: _decodeText(profile['username']),
      publisherEmail: _decodeText(profile['email']),
      categoryPath: _stringList(json['category_path'] ?? json['categoryPath']),
      parentCategory: _decodeText(json['parent_category']),
      videos: _videoSummaries(json['video_summaries']),
    );
  }

  List<AdminNewsVideo> _videoSummaries(Object? data) {
    if (data is! List) return const [];
    return [
      for (final item in data)
        if (item is Map)
          AdminNewsVideo(
            id: item['id']?.toString() ?? '',
            title: _decodeText(item['title']),
            url: item['url']?.toString() ?? '',
            thumbnailUrl: item['thumbnail_url']?.toString() ?? '',
            platformLabel: _decodeText(
              item['platform_label'] ?? item['platformLabel'],
            ),
            sizeLabel: item['size_label']?.toString() ?? '-',
            publishedAt: _parseDate(
              item['published_at'] ??
                  item['publishedAt'] ??
                  item['video_published_at'] ??
                  item['videoPublishedAt'],
            ),
            viewsCount: _asInt(item['views_count']),
          ),
    ];
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
      if (decoded is Map<String, dynamic>) {
        if (response.statusCode < 200 || response.statusCode >= 300) {
          final error = decoded['error'];
          if (error is Map && error['message'] != null) {
            throw AdminNewsException(error['message'].toString());
          }
          throw AdminNewsException(
            'Sunucu yanıtı başarısız: ${response.statusCode}',
          );
        }
        return decoded;
      }
      throw const AdminNewsException('Geçersiz sunucu yanıtı');
    } on TimeoutException {
      throw const AdminNewsException('Sunucu yanıtı zaman aşımına uğradı');
    } finally {
      if (closeClient) client.close();
    }
  }

  Future<Map<String, dynamic>> _getJson(String path) async {
    final client = httpClient ?? adminHttpClient;
    final closeClient = shouldCloseAdminHttpClient(client, httpClient);
    try {
      final uri = _resolveUri(path);
      final response = await client
          .get(uri, headers: await adminAuthHeaders())
          .timeout(_requestTimeout);
      final decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        if (response.statusCode < 200 || response.statusCode >= 300) {
          final error = decoded['error'];
          if (error is Map && error['message'] != null) {
            throw AdminNewsException(error['message'].toString());
          }
          throw AdminNewsException(
            'Sunucu yanıtı başarısız: ${response.statusCode}',
          );
        }
        return decoded;
      }
      throw const AdminNewsException('Geçersiz sunucu yanıtı');
    } on TimeoutException {
      throw const AdminNewsException('Sunucu yanıtı zaman aşımına uğradı');
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

  Map<String, Object?> _eqFilter(String column, Object? value) {
    return {'type': 'comparison', 'op': 'eq', 'column': column, 'value': value};
  }

  Map<String, Object?> _idFilter(String postId) {
    return _eqFilter('id', int.tryParse(postId) ?? postId);
  }

  String _safeSearchTerm(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
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

  List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return [
      for (final item in value)
        if (item != null && item.toString().trim().isNotEmpty)
          item.toString().trim(),
    ];
  }

  void _throwIfApiError(
    Map<String, dynamic> response, {
    required String fallbackMessage,
  }) {
    final error = response['error'];
    if (error == null) return;
    if (error is Map && error['message'] != null) {
      throw AdminNewsException(error['message'].toString());
    }
    throw AdminNewsException(fallbackMessage);
  }
}

class AdminNewsException implements Exception {
  const AdminNewsException(this.message);

  final String message;

  @override
  String toString() => message;
}
