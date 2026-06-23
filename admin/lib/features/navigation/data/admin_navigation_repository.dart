import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pateeznews_admin/core/network/admin_api_headers.dart';

import '../presentation/navigation_models.dart';

abstract class AdminNavigationRepository {
  Future<AdminNavigationInitialData> fetchInitialData();

  Future<List<AdminNavigationItem>> fetchItems(String menuId);

  Future<AdminNavigationMenu> createDefaultMenu();

  Future<AdminNavigationMenu> ensureDefaultMenu(String code);

  Future<void> createItem({
    required String menuId,
    required NavigationItemFormData data,
    required int orderIndex,
  });

  Future<void> updateItem({
    required String itemId,
    required String menuId,
    required int orderIndex,
    required NavigationItemFormData data,
  });

  Future<void> reorderItems(List<AdminNavigationItem> items);

  Future<void> deleteItems(List<String> itemIds);
}

class SupabaseAdminNavigationRepository implements AdminNavigationRepository {
  const SupabaseAdminNavigationRepository({this.httpClient, this.apiBaseUrl});

  static const _apiBaseUrl = String.fromEnvironment('PATEEZNEWS_API_BASE_URL');
  static const _requestTimeout = Duration(seconds: 8);

  final http.Client? httpClient;
  final String? apiBaseUrl;

  @override
  Future<AdminNavigationInitialData> fetchInitialData() async {
    final responses = await Future.wait([
      _postJson('/api/admin/query', {
        'table': 'navigation_menus',
        'method': 'select',
        'select': 'id,code,name,description,created_at',
        'orders': [
          {'column': 'created_at', 'ascending': true},
        ],
      }),
      _postJson('/api/admin/query', {
        'table': 'languages',
        'method': 'select',
        'select': 'code,name',
        'orders': [
          {'column': 'name', 'ascending': true},
        ],
      }),
    ]);
    for (final response in responses) {
      _throwIfApiError(
        response,
        fallbackMessage: 'Navigasyon verileri alınamadı',
      );
    }
    return AdminNavigationInitialData(
      menus: _menusFromRows(responses[0]['data']),
      languages: _languagesFromRows(responses[1]['data']),
    );
  }

  @override
  Future<List<AdminNavigationItem>> fetchItems(String menuId) async {
    final result = await _postJson('/api/admin/query', {
      'table': 'navigation_items',
      'method': 'select',
      'select':
          'id,menu_id,parent_id,label,type,value,icon,image_url,order_index,is_active,language_code',
      'filters': [
        {
          'type': 'comparison',
          'op': 'eq',
          'column': 'menu_id',
          'value': menuId,
        },
      ],
      'orders': [
        {'column': 'order_index', 'ascending': true},
      ],
    });
    _throwIfApiError(result, fallbackMessage: 'Navigasyon öğeleri alınamadı');
    return _itemsFromRows(result['data']);
  }

  @override
  Future<AdminNavigationMenu> createDefaultMenu() async {
    final menuResult = await _postJson('/api/admin/query', {
      'table': 'navigation_menus',
      'method': 'insert',
      'values': {
        'code': 'sidebar_main',
        'name': 'Ana Sidebar',
        'description': 'Sol taraftaki ana navigasyon menüsü.',
      },
      'single': 'single',
    });
    _throwIfApiError(
      menuResult,
      fallbackMessage: 'Varsayılan menü oluşturulamadı',
    );
    final menu = AdminNavigationMenu.fromJson(menuResult['data'] as Map);

    final cities = await _insertItem({
      'menu_id': menu.id,
      'label': 'Şehirler',
      'type': 'dropdown',
      'icon': 'location_on',
      'order_index': 0,
    });
    await _insertItem({
      'menu_id': menu.id,
      'label': 'Trend Başlıklar',
      'type': 'header',
      'icon': 'trending_up',
      'order_index': 10,
    });
    final nigde = await _insertItem({
      'menu_id': menu.id,
      'parent_id': cities.id,
      'label': 'Niğde',
      'type': 'dropdown',
      'value': 'nigde',
      'icon': 'location_on',
      'order_index': 1,
    });
    await _insertItem({
      'menu_id': menu.id,
      'parent_id': cities.id,
      'label': 'İstanbul',
      'type': 'category',
      'value': 'istanbul',
      'icon': 'location_on',
      'order_index': 2,
    });
    await _insertItems([
      {
        'menu_id': menu.id,
        'parent_id': nigde.id,
        'label': 'Trendler',
        'type': 'link',
        'value': '/nigde-trend',
        'icon': 'trending_up',
        'order_index': 3,
      },
      {
        'menu_id': menu.id,
        'parent_id': nigde.id,
        'label': 'Anketler',
        'type': 'category',
        'value': 'anketler',
        'icon': 'poll',
        'order_index': 4,
      },
      {
        'menu_id': menu.id,
        'parent_id': nigde.id,
        'label': 'Testler',
        'type': 'category',
        'value': 'testler',
        'icon': 'quiz',
        'order_index': 5,
      },
      {
        'menu_id': menu.id,
        'parent_id': nigde.id,
        'label': 'Video',
        'type': 'category',
        'value': 'video',
        'icon': 'smart_display',
        'order_index': 6,
      },
      {
        'menu_id': menu.id,
        'parent_id': nigde.id,
        'label': 'Tarif',
        'type': 'category',
        'value': 'tarif',
        'icon': 'restaurant',
        'order_index': 8,
      },
      {
        'menu_id': menu.id,
        'parent_id': nigde.id,
        'label': 'Etkinlik',
        'type': 'category',
        'value': 'etkinlik',
        'icon': 'calendar_month',
        'order_index': 9,
      },
      {
        'menu_id': menu.id,
        'parent_id': nigde.id,
        'label': 'Köşe Yazısı',
        'type': 'category',
        'value': 'kose-yazisi',
        'icon': 'forum',
        'order_index': 10,
      },
      {
        'menu_id': menu.id,
        'parent_id': nigde.id,
        'label': 'Spor',
        'type': 'category',
        'value': 'spor',
        'icon': 'sports_soccer',
        'order_index': 11,
      },
      {
        'menu_id': menu.id,
        'parent_id': nigde.id,
        'label': 'İçindekiler',
        'type': 'category',
        'value': 'icindekiler',
        'icon': 'format_list_numbered',
        'order_index': 99,
      },
    ]);

    return menu;
  }

  @override
  Future<AdminNavigationMenu> ensureDefaultMenu(String code) async {
    final normalizedCode = code.trim();
    final existing = await _findMenuByCode(normalizedCode);
    if (existing != null) return existing;
    if (normalizedCode == 'sidebar_main') return createDefaultMenu();
    if (normalizedCode == 'top_navbar') return _createDefaultTopNavbarMenu();
    throw AdminNavigationException('Bilinmeyen navigasyon menüsü: $code');
  }

  Future<AdminNavigationMenu?> _findMenuByCode(String code) async {
    final result = await _postJson('/api/admin/query', {
      'table': 'navigation_menus',
      'method': 'select',
      'select': 'id,code,name,description,created_at',
      'filters': [
        {'type': 'comparison', 'op': 'eq', 'column': 'code', 'value': code},
      ],
      'single': 'maybeSingle',
    });
    _throwIfApiError(result, fallbackMessage: 'Navigasyon menüsü alınamadı');
    final data = result['data'];
    if (data is Map) return AdminNavigationMenu.fromJson(data);
    return null;
  }

  Future<AdminNavigationMenu> _createDefaultTopNavbarMenu() async {
    final menuResult = await _postJson('/api/admin/query', {
      'table': 'navigation_menus',
      'method': 'insert',
      'values': {
        'code': 'top_navbar',
        'name': 'Üst Navbar',
        'description': 'Önyüz üst navigasyon menüsü.',
      },
      'single': 'single',
    });
    _throwIfApiError(
      menuResult,
      fallbackMessage: 'Üst navbar menüsü oluşturulamadı',
    );
    final menu = AdminNavigationMenu.fromJson(menuResult['data'] as Map);
    await _insertItems([
      {
        'menu_id': menu.id,
        'label': 'Ana Sayfa',
        'type': 'link',
        'value': '/',
        'icon': 'home',
        'order_index': 0,
      },
      {
        'menu_id': menu.id,
        'label': 'Anket',
        'type': 'category',
        'value': 'anketler',
        'icon': 'poll',
        'order_index': 1,
      },
      {
        'menu_id': menu.id,
        'label': 'Test',
        'type': 'category',
        'value': 'testler',
        'icon': 'quiz',
        'order_index': 2,
      },
      {
        'menu_id': menu.id,
        'label': 'Video',
        'type': 'category',
        'value': 'video',
        'icon': 'smart_display',
        'order_index': 3,
      },
      {
        'menu_id': menu.id,
        'label': 'Etkinlik',
        'type': 'category',
        'value': 'etkinlik',
        'icon': 'calendar_month',
        'order_index': 4,
      },
      {
        'menu_id': menu.id,
        'label': 'Tarif',
        'type': 'category',
        'value': 'tarif',
        'icon': 'restaurant',
        'order_index': 5,
      },
      {
        'menu_id': menu.id,
        'label': 'İçindekiler',
        'type': 'category',
        'value': 'icindekiler',
        'icon': 'format_list_numbered',
        'order_index': 6,
      },
    ]);
    return menu;
  }

  @override
  Future<void> createItem({
    required String menuId,
    required NavigationItemFormData data,
    required int orderIndex,
  }) async {
    final result = await _postJson('/api/admin/query', {
      'table': 'navigation_items',
      'method': 'insert',
      'values': _payload(menuId: menuId, data: data, orderIndex: orderIndex),
    });
    _throwIfApiError(result, fallbackMessage: 'Navigasyon öğesi eklenemedi');
  }

  @override
  Future<void> updateItem({
    required String itemId,
    required String menuId,
    required int orderIndex,
    required NavigationItemFormData data,
  }) async {
    final result = await _postJson('/api/admin/query', {
      'table': 'navigation_items',
      'method': 'update',
      'values': _payload(menuId: menuId, data: data, orderIndex: orderIndex),
      'filters': [_idFilter(itemId)],
    });
    _throwIfApiError(
      result,
      fallbackMessage: 'Navigasyon öğesi güncellenemedi',
    );
  }

  @override
  Future<void> reorderItems(List<AdminNavigationItem> items) async {
    for (var index = 0; index < items.length; index++) {
      final result = await _postJson('/api/admin/query', {
        'table': 'navigation_items',
        'method': 'update',
        'values': {'order_index': index},
        'filters': [_idFilter(items[index].id)],
      });
      _throwIfApiError(result, fallbackMessage: 'Sıralama kaydedilemedi');
    }
  }

  @override
  Future<void> deleteItems(List<String> itemIds) async {
    if (itemIds.isEmpty) return;
    final result = await _postJson('/api/admin/query', {
      'table': 'navigation_items',
      'method': 'delete',
      'filters': [
        {'type': 'comparison', 'op': 'in', 'column': 'id', 'value': itemIds},
      ],
    });
    _throwIfApiError(result, fallbackMessage: 'Navigasyon öğesi silinemedi');
  }

  Future<AdminNavigationItem> _insertItem(Map<String, Object?> values) async {
    final result = await _postJson('/api/admin/query', {
      'table': 'navigation_items',
      'method': 'insert',
      'values': values,
      'single': 'single',
    });
    _throwIfApiError(result, fallbackMessage: 'Varsayılan öğe eklenemedi');
    return AdminNavigationItem.fromJson(result['data'] as Map);
  }

  Future<void> _insertItems(List<Map<String, Object?>> values) async {
    final result = await _postJson('/api/admin/query', {
      'table': 'navigation_items',
      'method': 'insert',
      'values': values,
    });
    _throwIfApiError(result, fallbackMessage: 'Varsayılan öğeler eklenemedi');
  }

  Map<String, Object?> _payload({
    required String menuId,
    required NavigationItemFormData data,
    required int orderIndex,
  }) {
    return {
      'menu_id': menuId,
      'label': data.label.trim(),
      'type': data.type,
      'value': data.value.trim().isEmpty ? null : data.value.trim(),
      'icon': data.icon.trim().isEmpty ? null : data.icon.trim(),
      'image_url': data.imageUrl.trim().isEmpty ? null : data.imageUrl.trim(),
      'parent_id': data.parentId,
      'order_index': orderIndex,
      'language_code': data.languageCode.trim().isEmpty
          ? 'tr'
          : data.languageCode.trim(),
    };
  }

  List<AdminNavigationMenu> _menusFromRows(Object? data) {
    if (data is! List) return const [];
    return [
      for (final row in data.whereType<Map>())
        AdminNavigationMenu.fromJson(row),
    ];
  }

  List<AdminNavigationLanguage> _languagesFromRows(Object? data) {
    if (data is! List) return const [];
    return [
      for (final row in data.whereType<Map>())
        if ((row['code']?.toString().trim() ?? '').isNotEmpty)
          AdminNavigationLanguage.fromJson(row),
    ];
  }

  List<AdminNavigationItem> _itemsFromRows(Object? data) {
    if (data is! List) return const [];
    return [
      for (final row in data.whereType<Map>())
        AdminNavigationItem.fromJson(row),
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
      if (decoded is Map<String, dynamic>) return decoded;
      throw const AdminNavigationException('Geçersiz sunucu yanıtı');
    } on TimeoutException {
      throw const AdminNavigationException(
        'Sunucu yanıtı zaman aşımına uğradı',
      );
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
          ? 'https://pateez.com'
          : 'https://pateez.com';
      return Uri.parse(host).resolve(path);
    }
    return Uri.base.resolve(path);
  }

  Map<String, Object?> _idFilter(String id) {
    return {'type': 'comparison', 'op': 'eq', 'column': 'id', 'value': id};
  }

  void _throwIfApiError(
    Map<String, dynamic> response, {
    required String fallbackMessage,
  }) {
    final error = response['error'];
    if (error == null) return;
    if (error is Map && error['message'] != null) {
      throw AdminNavigationException(error['message'].toString());
    }
    throw AdminNavigationException(fallbackMessage);
  }
}

class AdminNavigationException implements Exception {
  const AdminNavigationException(this.message);

  final String message;

  @override
  String toString() => message;
}
