import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

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

class NeonAdminNewsRepository implements AdminNewsRepository {
  const NeonAdminNewsRepository({this.httpClient, this.apiBaseUrl});

  static const _apiBaseUrl = String.fromEnvironment('PATEEZNEWS_API_BASE_URL');
  static const _requestTimeout = Duration(seconds: 12);
  static const _all = 'Tümü';

  final http.Client? httpClient;
  final String? apiBaseUrl;

  @override
  Future<AdminNewsMetricData> fetchMetrics() async {
    final responses = await Future.wait([
      _postJson('/api/neon/query', {
        'table': 'posts',
        'method': 'select',
        'select': 'id',
        'count': 'exact',
        'head': true,
      }),
      _postJson('/api/neon/query', {
        'table': 'posts',
        'method': 'select',
        'select': 'id',
        'filters': [
          {
            'type': 'comparison',
            'op': 'eq',
            'column': 'status',
            'value': 'published',
          },
        ],
        'count': 'exact',
        'head': true,
      }),
      _postJson('/api/neon/query', {
        'table': 'posts',
        'method': 'select',
        'select': 'likes_count',
      }),
    ]);

    for (final response in responses) {
      _throwIfApiError(
        response,
        fallbackMessage: 'Haber istatistikleri alınamadı',
      );
    }

    final viewRows = responses[2]['data'];
    final views = viewRows is List
        ? viewRows.whereType<Map>().fold<int>(
            0,
            (sum, row) => sum + _asInt(row['likes_count']),
          )
        : 0;

    return AdminNewsMetricData(
      total: _asInt(responses[0]['count']),
      published: _asInt(responses[1]['count']),
      views: views,
      scheduled: 0,
    );
  }

  @override
  Future<AdminNewsFilterOptions> fetchFilterOptions() async {
    final responses = await Future.wait([
      _postJson('/api/neon/query', {
        'table': 'languages',
        'method': 'select',
        'select': 'code,name',
        'orders': [
          {'column': 'name', 'ascending': true},
        ],
      }),
      _postJson('/api/neon/query', {
        'table': 'navigation_items',
        'method': 'select',
        'select': 'id,label,parent_id',
        'orders': [
          {'column': 'label', 'ascending': true},
        ],
      }),
      _postJson('/api/neon/query', {
        'table': 'profiles',
        'method': 'select',
        'select': 'id,full_name',
        'orders': [
          {'column': 'full_name', 'ascending': true},
        ],
      }),
      _postJson('/api/neon/query', {
        'table': 'posts',
        'method': 'select',
        'select': 'category,type,publisher_id',
      }),
    ]);

    for (final response in responses) {
      _throwIfApiError(response, fallbackMessage: 'Haber filtreleri alınamadı');
    }

    final usedRows = responses[3]['data'] is List
        ? (responses[3]['data'] as List).whereType<Map>().toList()
        : const <Map>[];
    final usedCategories = usedRows
        .map((row) => row['category']?.toString().trim() ?? '')
        .where((value) => value.isNotEmpty)
        .toSet();
    final usedTypes = usedRows
        .map((row) => row['type']?.toString().trim() ?? '')
        .where((value) => value.isNotEmpty)
        .toSet();
    final usedPublishers = usedRows
        .map((row) => row['publisher_id']?.toString().trim() ?? '')
        .where((value) => value.isNotEmpty)
        .toSet();

    final navRows = responses[1]['data'] is List
        ? (responses[1]['data'] as List).whereType<Map>().toList()
        : const <Map>[];
    final navById = {
      for (final row in navRows) row['id']?.toString() ?? '': row,
    };

    return AdminNewsFilterOptions(
      languages: _languageItems(responses[0]['data']),
      categories: _categoryItems(navRows, navById, usedCategories),
      types: [
        for (final type in usedTypes.toList()..sort())
          AdminNewsFilterItem(id: type, label: type),
      ],
      publishers: _publisherItems(responses[2]['data'], usedPublishers),
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
            'title.ilike.$pattern,slug.ilike.$pattern,category.ilike.$pattern,type.ilike.$pattern,status.ilike.$pattern,seo_title.ilike.$pattern,seo_description.ilike.$pattern,keywords.ilike.$pattern,summary.ilike.$pattern',
      });
    }
    if (language != _all) {
      filters.add(_eqFilter('language_code', language));
    }
    if (category != _all) {
      filters.add(_eqFilter('category', category));
    }
    if (type != _all) {
      filters.add(_eqFilter('type', type));
    }
    if (status != _all) {
      filters.add(_eqFilter('status', status));
    }
    if (publisher != _all) {
      filters.add(_eqFilter('publisher_id', publisher));
    }

    final safePage = page < 1 ? 1 : page;
    final from = (safePage - 1) * pageSize;
    final to = from + pageSize - 1;
    final result = await _postJson('/api/neon/query', {
      'table': 'posts',
      'method': 'select',
      'select':
          'id,title,category,type,status,slug,created_at,thumbnail_url,likes_count,comments_count,language_code,is_pinned,publisher_id,profiles:publisher_id(full_name,username,email)',
      'filters': filters,
      'orders': _postOrders(sortKey, sortAscending),
      'range': {'from': from, 'to': to},
      'count': 'exact',
    });
    _throwIfApiError(result, fallbackMessage: 'Haberler alınamadı');

    final data = result['data'];
    final rows = data is List ? data.whereType<Map>().toList() : const <Map>[];
    final categoryParents = await _categoryParentsFor(rows);
    return AdminNewsPageResult(
      posts: [
        for (var index = 0; index < rows.length; index++)
          _postFromJson(rows[index], from + index + 1, categoryParents),
      ],
      totalCount: _asInt(result['count']),
    );
  }

  @override
  Future<void> toggleStatus(AdminNewsPost post) async {
    final nextStatus = post.published ? 'draft' : 'published';
    final result = await _postJson('/api/neon/query', {
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
      final countResult = await _postJson('/api/neon/query', {
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

    final result = await _postJson('/api/neon/query', {
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
    final result = await _postJson('/api/neon/query', {
      'table': 'posts',
      'method': 'delete',
      'filters': [_idFilter(postId)],
    });
    _throwIfApiError(result, fallbackMessage: 'Haber silinemedi');
  }

  @override
  Future<void> deletePosts(List<String> postIds) async {
    final ids = postIds.map(int.tryParse).whereType<int>().toList();
    if (ids.isEmpty) return;
    final result = await _postJson('/api/neon/query', {
      'table': 'posts',
      'method': 'delete',
      'filters': [
        {'type': 'comparison', 'op': 'in', 'column': 'id', 'value': ids},
      ],
    });
    _throwIfApiError(result, fallbackMessage: 'Seçili haberler silinemedi');
  }

  @override
  Future<AdminNewsEditorBootstrap> fetchEditorBootstrap() async {
    final responses = await Future.wait([
      _postJson('/api/neon/query', {
        'table': 'languages',
        'method': 'select',
        'select': 'code,name',
        'orders': [
          {'column': 'name', 'ascending': true},
        ],
      }),
      _postJson('/api/neon/query', {
        'table': 'navigation_items',
        'method': 'select',
        'select': 'id,label,parent_id,language_code,order_index',
        'orders': [
          {'column': 'order_index', 'ascending': true},
          {'column': 'label', 'ascending': true},
        ],
      }),
      _postJson('/api/neon/query', {
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
    final categoryRows = responses[1]['data'] is List
        ? (responses[1]['data'] as List).whereType<Map>().toList()
        : const <Map>[];
    final publisherRows = responses[2]['data'] is List
        ? (responses[2]['data'] as List).whereType<Map>().toList()
        : const <Map>[];

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
    final result = await _postJson('/api/neon/query', {
      'table': 'posts',
      'method': 'select',
      'select': '*',
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
    final result = await _postJson('/api/neon/query', {
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
    }

    final result = await _postJson('/api/neon/query', {
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

  Future<Map<String, String>> _categoryParentsFor(List<Map> rows) async {
    final labels = rows
        .map((row) => row['category']?.toString().trim() ?? '')
        .where((value) => value.isNotEmpty)
        .toSet();
    if (labels.isEmpty) return const {};

    final result = await _postJson('/api/neon/query', {
      'table': 'navigation_items',
      'method': 'select',
      'select': 'id,label,parent_id',
      'filters': [
        {
          'type': 'comparison',
          'op': 'in',
          'column': 'label',
          'value': labels.toList(),
        },
      ],
    });
    if (result['error'] != null) return const {};
    final navRows = result['data'] is List
        ? (result['data'] as List).whereType<Map>().toList()
        : const <Map>[];
    final parentIds = navRows
        .map((row) => row['parent_id']?.toString().trim() ?? '')
        .where((value) => value.isNotEmpty)
        .toSet();
    if (parentIds.isEmpty) return const {};

    final parentResult = await _postJson('/api/neon/query', {
      'table': 'navigation_items',
      'method': 'select',
      'select': 'id,label',
      'filters': [
        {
          'type': 'comparison',
          'op': 'in',
          'column': 'id',
          'value': parentIds.toList(),
        },
      ],
    });
    if (parentResult['error'] != null) return const {};
    final parents = parentResult['data'] is List
        ? (parentResult['data'] as List).whereType<Map>().toList()
        : const <Map>[];
    final parentLabels = {
      for (final parent in parents)
        parent['id']?.toString() ?? '': _decodeText(parent['label']),
    };

    return {
      for (final row in navRows)
        row['label']?.toString() ?? '':
            parentLabels[row['parent_id']?.toString() ?? ''] ?? '',
    };
  }

  List<Map<String, Object?>> _postOrders(String sortKey, bool ascending) {
    final column = switch (sortKey) {
      'id' => 'id',
      'post' => 'title',
      'category' => 'category',
      'status' => 'status',
      'language' => 'language_code',
      'author' => 'publisher_id',
      'views' => 'likes_count',
      'comments' => 'comments_count',
      'date' => 'created_at',
      _ => 'created_at',
    };
    return [
      {'column': 'is_pinned', 'ascending': false},
      {'column': column, 'ascending': ascending},
    ];
  }

  List<AdminNewsFilterItem> _languageItems(Object? data) {
    if (data is! List) return const [];
    return [
      for (final row in data.whereType<Map>())
        if ((row['code']?.toString().trim() ?? '').isNotEmpty)
          AdminNewsFilterItem(
            id: row['code'].toString(),
            label: _decodeText(row['name']),
          ),
    ];
  }

  List<AdminNewsFilterItem> _categoryItems(
    List<Map> navRows,
    Map<String, Map> navById,
    Set<String> usedCategories,
  ) {
    final items = <AdminNewsFilterItem>[];
    for (final row in navRows) {
      final label = _decodeText(row['label']);
      if (label.isEmpty || !usedCategories.contains(label)) continue;
      final parentId = row['parent_id']?.toString() ?? '';
      final parentLabel = parentId.isEmpty
          ? null
          : _decodeText(navById[parentId]?['label']);
      items.add(
        AdminNewsFilterItem(id: label, label: label, parentLabel: parentLabel),
      );
    }
    items.sort((a, b) => a.displayLabel.compareTo(b.displayLabel));
    return items;
  }

  List<AdminNewsFilterItem> _publisherItems(Object? data, Set<String> usedIds) {
    if (data is! List) return const [];
    final items = <AdminNewsFilterItem>[];
    for (final row in data.whereType<Map>()) {
      final id = row['id']?.toString().trim() ?? '';
      final label = _decodeText(row['full_name']);
      if (id.isEmpty || label.isEmpty || !usedIds.contains(id)) continue;
      items.add(AdminNewsFilterItem(id: id, label: label));
    }
    items.sort((a, b) => a.label.compareTo(b.label));
    return items;
  }

  AdminNewsPost _postFromJson(
    Map<dynamic, dynamic> json,
    int rowNumber,
    Map<String, String> categoryParents,
  ) {
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
      likesCount: _asInt(json['likes_count']),
      commentsCount: _asInt(json['comments_count']),
      languageCode: json['language_code']?.toString() ?? 'tr',
      isPinned: json['is_pinned'] == true,
      publisherId: json['publisher_id']?.toString() ?? '',
      publisherName: _decodeText(profile['full_name']),
      publisherUsername: _decodeText(profile['username']),
      publisherEmail: _decodeText(profile['email']),
      parentCategory: categoryParents[category],
    );
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, Object?> body,
  ) async {
    final client = httpClient ?? http.Client();
    final closeClient = httpClient == null;
    try {
      final uri = _resolveUri(path);
      final response = await client
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
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

  Uri _resolveUri(String path) {
    final configured = (apiBaseUrl ?? _apiBaseUrl).trim();
    if (configured.isNotEmpty) {
      return Uri.parse(configured).resolve(path);
    }
    if (!kIsWeb) {
      final host = defaultTargetPlatform == TargetPlatform.android
          ? 'http://10.0.2.2:4321'
          : 'http://localhost:4321';
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
    return value
        .trim()
        .replaceAll('%', r'\%')
        .replaceAll(',', ' ')
        .replaceAll('\n', ' ')
        .replaceAll('\r', ' ');
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
