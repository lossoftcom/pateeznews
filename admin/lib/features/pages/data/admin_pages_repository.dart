import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pateeznews_admin/core/network/admin_api_headers.dart';
import 'package:pateeznews_admin/shared/widgets/highlighted_text.dart';

import '../../../shared/widgets/admin_rich_text_editor.dart';
import '../presentation/pages_models.dart';

abstract class AdminPagesRepository {
  Future<AdminPagesFilterOptions> fetchFilterOptions();

  Future<AdminPagesPageResult> fetchPages({
    required String search,
    required String category,
    required String type,
    required String status,
    required int page,
    required int pageSize,
    required String sortKey,
    required bool sortAscending,
  });

  Future<AdminPage> savePage({String? id, required AdminPageFormData data});

  Future<void> toggleStatus(AdminPage page);

  Future<void> deletePage(String pageId);
}

class SupabaseAdminPagesRepository implements AdminPagesRepository {
  const SupabaseAdminPagesRepository({this.httpClient, this.apiBaseUrl});

  static const _apiBaseUrl = String.fromEnvironment('PATEEZNEWS_API_BASE_URL');
  static const _requestTimeout = Duration(seconds: 8);
  static const _all = 'Tümü';

  final http.Client? httpClient;
  final String? apiBaseUrl;

  @override
  Future<AdminPagesFilterOptions> fetchFilterOptions() async {
    final responses = await Future.wait([
      _postJson('/api/admin/query', {
        'table': 'languages',
        'method': 'select',
        'select': 'code,name,status',
        'filters': [_eqFilter('status', 'active')],
        'orders': [
          {'column': 'name', 'ascending': true},
        ],
      }),
      _postJson('/api/admin/query', {
        'table': 'navigation_menus',
        'method': 'select',
        'select': 'id,code,name',
        'orders': [
          {'column': 'created_at', 'ascending': true},
        ],
      }),
      _postJson('/api/admin/query', {
        'table': 'navigation_items',
        'method': 'select',
        'select':
            'id,menu_id,label,parent_id,type,value,is_active,language_code,order_index',
        'filters': [_eqFilter('is_active', true)],
        'orders': [
          {'column': 'order_index', 'ascending': true},
          {'column': 'label', 'ascending': true},
        ],
      }),
      _postJson('/api/admin/query', {
        'table': 'pages',
        'method': 'select',
        'select': 'id,title,page_type,language_code',
        'orders': [
          {'column': 'title', 'ascending': true},
        ],
      }),
    ]);

    for (final response in responses) {
      _throwIfApiError(
        response,
        fallbackMessage: 'Sayfa seçenekleri alınamadı',
      );
    }

    final pageRows = responses[3]['data'] is List
        ? (responses[3]['data'] as List).whereType<Map>().toList()
        : const <Map>[];
    final types =
        pageRows
            .map((row) => row['page_type']?.toString().trim() ?? '')
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    return AdminPagesFilterOptions(
      languages: _languageItems(responses[0]['data']),
      categories: _categoryItems(responses[1]['data'], responses[2]['data']),
      types: types.isEmpty ? const ['custom'] : types,
      parents: [
        for (final row in pageRows)
          if ((row['id']?.toString().trim() ?? '').isNotEmpty)
            AdminPageParentOption(
              id: row['id'].toString(),
              title: _decodeText(row['title']),
              languageCode: row['language_code']?.toString() ?? 'tr',
            ),
      ],
    );
  }

  @override
  Future<AdminPagesPageResult> fetchPages({
    required String search,
    required String category,
    required String type,
    required String status,
    required int page,
    required int pageSize,
    required String sortKey,
    required bool sortAscending,
  }) async {
    final baseFilters = <Map<String, Object?>>[];
    if (category != _all) baseFilters.add(_eqFilter('category_id', category));
    if (type != _all) baseFilters.add(_eqFilter('page_type', type));
    if (status != _all) baseFilters.add(_eqFilter('status', status));

    final term = _safeSearchTerm(search);
    if (term.isEmpty) {
      return _fetchPagesPage(
        filters: baseFilters,
        page: page,
        pageSize: pageSize,
        sortKey: sortKey,
        sortAscending: sortAscending,
      );
    }
    // Haberler ile AYNI teknoloji: normalize (Türkçe-duyarsız) + trigram'lı
    // admin_search_text. Şema/sürüm güncel değilse eski ham filtreye düşeriz.
    try {
      return await _fetchPagesPage(
        filters: [_normalizedSearchFilter(term), ...baseFilters],
        page: page,
        pageSize: pageSize,
        sortKey: sortKey,
        sortAscending: sortAscending,
      );
    } catch (_) {
      return _fetchPagesPage(
        filters: [_legacySearchFilter(term), ...baseFilters],
        page: page,
        pageSize: pageSize,
        sortKey: sortKey,
        sortAscending: sortAscending,
      );
    }
  }

  Map<String, Object?> _normalizedSearchFilter(String term) {
    final pattern =
        '%${normalizeSearchText(term).replaceAll(',', ' ').trim()}%';
    return {'type': 'or', 'value': 'admin_search_text.ilike.$pattern'};
  }

  Map<String, Object?> _legacySearchFilter(String term) {
    final pattern = '%$term%';
    return {
      'type': 'or',
      'value':
          'title.ilike.$pattern,slug.ilike.$pattern,page_group.ilike.$pattern,category.ilike.$pattern,page_type.ilike.$pattern,status.ilike.$pattern,language_code.ilike.$pattern',
    };
  }

  Future<AdminPagesPageResult> _fetchPagesPage({
    required List<Map<String, Object?>> filters,
    required int page,
    required int pageSize,
    required String sortKey,
    required bool sortAscending,
  }) async {
    final safePage = page < 1 ? 1 : page;
    final from = (safePage - 1) * pageSize;
    final to = from + pageSize - 1;
    final result = await _postJson('/api/admin/query', {
      'table': 'pages',
      'method': 'select',
      'select':
          'id,title,slug,page_group,category,category_id,page_type,status,language_code,location,parent_page_id,show_title,show_breadcrumb,show_sidebar,registered_only,menu_order,content_delta,content_plain,meta_title,meta_keywords,meta_description,canonical_url,created_at',
      'filters': filters,
      'orders': _pageOrders(sortKey, sortAscending),
      'range': {'from': from, 'to': to},
      'count': 'exact',
    });
    _throwIfApiError(result, fallbackMessage: 'Sayfalar alınamadı');

    final rows = result['data'] is List
        ? (result['data'] as List).whereType<Map>().toList()
        : const <Map>[];
    final categoryParents = await _categoryParentsFor(rows);
    return AdminPagesPageResult(
      pages: [
        for (var index = 0; index < rows.length; index++)
          _pageFromJson(rows[index], from + index + 1, categoryParents),
      ],
      totalCount: _asInt(result['count']),
    );
  }

  @override
  Future<AdminPage> savePage({
    String? id,
    required AdminPageFormData data,
  }) async {
    final pageId = id?.trim();
    final method = pageId == null || pageId.isEmpty ? 'insert' : 'update';
    final body = <String, Object?>{
      'table': 'pages',
      'method': method,
      'values': _payload(data),
      'single': 'maybeSingle',
    };
    if (method == 'update') {
      body['filters'] = [_eqFilter('id', pageId)];
    }
    final result = await _postJson('/api/admin/query', body);
    _throwIfApiError(result, fallbackMessage: 'Sayfa kaydedilemedi');
    final row = result['data'];
    if (row is Map) {
      return _pageFromJson(row, 1, const {});
    }
    throw const AdminPagesException('Sayfa kaydedilemedi');
  }

  @override
  Future<void> toggleStatus(AdminPage page) async {
    final result = await _postJson('/api/admin/query', {
      'table': 'pages',
      'method': 'update',
      'values': {
        'status': page.active ? 'passive' : 'active',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      'filters': [_eqFilter('id', page.id)],
    });
    _throwIfApiError(result, fallbackMessage: 'Sayfa durumu güncellenemedi');
  }

  @override
  Future<void> deletePage(String pageId) async {
    final result = await _postJson('/api/admin/query', {
      'table': 'pages',
      'method': 'delete',
      'filters': [_eqFilter('id', pageId)],
    });
    _throwIfApiError(result, fallbackMessage: 'Sayfa silinemedi');
  }

  Map<String, Object?> _payload(AdminPageFormData data) {
    return {
      'title': data.title.trim(),
      'slug': data.slug.trim().isEmpty
          ? _slugify(data.title)
          : _slugify(data.slug),
      'page_group': data.pageGroup.trim().isEmpty
          ? 'Kurumsal'
          : data.pageGroup.trim(),
      'language_code': data.languageCode.trim().isEmpty
          ? 'tr'
          : data.languageCode.trim(),
      'category_id': data.categoryId.trim().isEmpty
          ? null
          : data.categoryId.trim(),
      'category': data.category.trim(),
      'page_type': data.type.trim().isEmpty ? 'custom' : data.type.trim(),
      'status': data.status.trim().isEmpty ? 'active' : data.status.trim(),
      'location': data.location.trim().isEmpty
          ? 'top_menu'
          : data.location.trim(),
      'parent_page_id': data.parentPageId.trim().isEmpty
          ? null
          : data.parentPageId.trim(),
      'show_title': data.showTitle,
      'show_breadcrumb': data.showBreadcrumb,
      'show_sidebar': data.showSidebar,
      'registered_only': data.registeredOnly,
      'menu_order': data.menuOrder,
      'content_delta': _decodeDelta(data.contentDeltaJson),
      'content_plain': data.contentPlainText,
      'meta_title': data.metaTitle.trim(),
      'meta_keywords': data.metaKeywords.trim(),
      'meta_description': data.metaDescription.trim(),
      'canonical_url': data.canonicalUrl.trim(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  Object _decodeDelta(String value) {
    try {
      final decoded = jsonDecode(
        value.trim().isEmpty ? adminEmptyQuillDeltaJson : value.trim(),
      );
      if (decoded is List || decoded is Map) return decoded;
    } catch (_) {}
    return jsonDecode(adminEmptyQuillDeltaJson);
  }

  Future<Map<String, String>> _categoryParentsFor(List<Map> rows) async {
    final categoryIds = rows
        .map((row) => row['category_id']?.toString().trim() ?? '')
        .where((value) => value.isNotEmpty)
        .toSet();
    final labels = rows
        .map((row) => row['category']?.toString().trim() ?? '')
        .where((value) => value.isNotEmpty)
        .toSet();
    if (categoryIds.isEmpty && labels.isEmpty) return const {};

    final filters = <Map<String, Object?>>[];
    if (categoryIds.isNotEmpty) {
      filters.add({
        'type': 'comparison',
        'op': 'in',
        'column': 'id',
        'value': categoryIds.toList(),
      });
    } else {
      filters.add({
        'type': 'comparison',
        'op': 'in',
        'column': 'label',
        'value': labels.toList(),
      });
    }

    final result = await _postJson('/api/admin/query', {
      'table': 'navigation_items',
      'method': 'select',
      'select': 'id,label,parent_id',
      'filters': filters,
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

    final parentResult = await _postJson('/api/admin/query', {
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
        if ((row['id']?.toString().trim() ?? '').isNotEmpty)
          row['id'].toString():
              parentLabels[row['parent_id']?.toString()] ?? '',
      for (final row in navRows)
        if ((row['label']?.toString().trim() ?? '').isNotEmpty)
          _decodeText(row['label']):
              parentLabels[row['parent_id']?.toString()] ?? '',
    };
  }

  List<Map<String, Object?>> _pageOrders(String sortKey, bool ascending) {
    final column = switch (sortKey) {
      'title' => 'title',
      'group' => 'page_group',
      'category' => 'category',
      'type' => 'page_type',
      'status' => 'status',
      'createdAt' => 'created_at',
      _ => 'created_at',
    };
    return [
      {'column': column, 'ascending': ascending},
    ];
  }

  List<AdminPageLanguage> _languageItems(Object? data) {
    if (data is! List) return const [];
    return [
      for (final row in data.whereType<Map>())
        if ((row['code']?.toString().trim() ?? '').isNotEmpty)
          AdminPageLanguage(
            code: row['code'].toString(),
            name: _decodeText(row['name']),
          ),
    ];
  }

  List<AdminPageCategory> _categoryItems(Object? menuData, Object? itemData) {
    if (itemData is! List) return const [];
    final menuRows = menuData is List ? menuData.whereType<Map>().toList() : [];
    final rows = itemData.whereType<Map>().toList();
    final menuLabelsById = {
      for (final row in menuRows)
        row['id']?.toString() ?? '': _navigationSurfaceLabel(
          row['code']?.toString() ?? '',
          row['name'],
        ),
    };
    final byId = {for (final row in rows) row['id']?.toString() ?? '': row};
    final items = <AdminPageCategory>[];
    for (final row in rows) {
      final id = row['id']?.toString().trim() ?? '';
      final label = _decodeText(row['label']);
      final type = row['type']?.toString().trim() ?? '';
      if (id.isEmpty || label.isEmpty) continue;
      if (type == 'link' || type == 'header') continue;
      final parentId = row['parent_id']?.toString().trim() ?? '';
      final parentLabel = parentId.isEmpty ? null : _parentPath(parentId, byId);
      items.add(
        AdminPageCategory(
          id: id,
          label: label,
          languageCode: row['language_code']?.toString() ?? 'tr',
          type: type.isEmpty ? 'category' : type,
          parentId: parentId.isEmpty ? null : parentId,
          parentLabel: parentLabel,
          menuLabel: menuLabelsById[row['menu_id']?.toString() ?? ''],
        ),
      );
    }
    items.sort((a, b) {
      final language = a.languageCode.compareTo(b.languageCode);
      if (language != 0) return language;
      return a.displayLabel.compareTo(b.displayLabel);
    });
    return items;
  }

  String? _parentPath(String parentId, Map<String, Map> byId) {
    final labels = <String>[];
    var currentId = parentId;
    final visited = <String>{};
    while (currentId.isNotEmpty && visited.add(currentId)) {
      final row = byId[currentId];
      if (row == null) break;
      final label = _decodeText(row['label']);
      if (label.isNotEmpty) labels.insert(0, label);
      currentId = row['parent_id']?.toString().trim() ?? '';
    }
    return labels.isEmpty ? null : labels.join(' > ');
  }

  String _navigationSurfaceLabel(String code, Object? fallback) {
    return switch (code) {
      'sidebar_main' => 'Sol Sidebar',
      'top_navbar' => 'Üst Navbar',
      _ => _decodeText(fallback),
    };
  }

  AdminPage _pageFromJson(
    Map<dynamic, dynamic> json,
    int rowNumber,
    Map<String, String> categoryParents,
  ) {
    final category = _decodeText(json['category']);
    final categoryId = json['category_id']?.toString() ?? '';
    final parentById = categoryParents[categoryId]?.trim() ?? '';
    final parentByLabel = categoryParents[category]?.trim() ?? '';
    return AdminPage(
      id: json['id']?.toString() ?? '',
      rowNumber: rowNumber,
      title: _decodeText(json['title']),
      slug: json['slug']?.toString() ?? '',
      pageGroup: _decodeText(json['page_group']),
      category: category,
      categoryId: categoryId,
      type: json['page_type']?.toString() ?? 'custom',
      status: json['status']?.toString() ?? 'active',
      languageCode: json['language_code']?.toString() ?? 'tr',
      location: json['location']?.toString() ?? 'top_menu',
      parentPageId: json['parent_page_id']?.toString() ?? '',
      showTitle: json['show_title'] != false,
      showBreadcrumb: json['show_breadcrumb'] != false,
      showSidebar: json['show_sidebar'] != false,
      registeredOnly: json['registered_only'] == true,
      menuOrder: _asInt(json['menu_order'], fallback: 1),
      contentDeltaJson: _deltaToString(json['content_delta']),
      contentPlainText: _decodeText(json['content_plain']),
      metaTitle: _decodeText(json['meta_title']),
      metaKeywords: _decodeText(json['meta_keywords']),
      metaDescription: _decodeText(json['meta_description']),
      canonicalUrl: _decodeText(json['canonical_url']),
      createdAt: _parseDate(json['created_at']),
      parentCategory: parentById.isNotEmpty ? parentById : parentByLabel,
    );
  }

  String _deltaToString(Object? value) {
    if (value is List || value is Map) return jsonEncode(value);
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? adminEmptyQuillDeltaJson : text;
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
      throw const AdminPagesException('Geçersiz sunucu yanıtı');
    } on TimeoutException {
      throw const AdminPagesException('Sunucu yanıtı zaman aşımına uğradı');
    } finally {
      if (closeClient) client.close();
    }
  }

  Uri _resolveUri(String path) {
    final configured = (apiBaseUrl ?? _apiBaseUrl).trim();
    if (configured.isNotEmpty && !isLocalAdminApiBaseUrl(configured))
      return Uri.parse(configured).resolve(path);
    return Uri.parse('https://pateez.com').resolve(path);
  }

  Map<String, Object?> _eqFilter(String column, Object? value) {
    return {'type': 'comparison', 'op': 'eq', 'column': column, 'value': value};
  }

  String _safeSearchTerm(String value) {
    return value
        .trim()
        .replaceAll('%', r'\%')
        .replaceAll(',', ' ')
        .replaceAll('\n', ' ')
        .replaceAll('\r', ' ');
  }

  int _asInt(Object? value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  DateTime? _parseDate(Object? value) {
    final text = value?.toString();
    if (text == null || text.isEmpty) return null;
    return DateTime.tryParse(text)?.toLocal();
  }

  String _decodeText(Object? value) {
    if (value == null) return '';
    final text = value.toString();
    try {
      return utf8.decode(latin1.encode(text));
    } catch (_) {
      return text;
    }
  }

  String _slugify(String value) {
    final mapped = value
        .trim()
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return mapped.isEmpty ? 'sayfa' : mapped;
  }

  void _throwIfApiError(
    Map<String, dynamic> result, {
    required String fallbackMessage,
  }) {
    final error = result['error'];
    if (error == null) return;
    if (error is Map && error['message'] != null) {
      throw AdminPagesException(error['message'].toString());
    }
    throw AdminPagesException(fallbackMessage);
  }
}

class AdminPagesException implements Exception {
  const AdminPagesException(this.message);

  final String message;

  @override
  String toString() => message;
}
