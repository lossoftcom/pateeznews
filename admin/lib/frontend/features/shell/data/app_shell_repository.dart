import 'dart:convert';

import 'package:http/http.dart' as http;
import '../../../core/network/frontend_http_client.dart';

import '../../../core/network/local_api_base_url.dart';

class AppShellSettings {
  const AppShellSettings({
    required this.siteName,
    required this.logoUrl,
    required this.darkLogoUrl,
    required this.faviconUrl,
  });

  const AppShellSettings.empty()
    : siteName = '',
      logoUrl = '',
      darkLogoUrl = '',
      faviconUrl = '';

  factory AppShellSettings.fromJson(
    Map<dynamic, dynamic> json,
    String Function(String) resolveUrl,
  ) {
    return AppShellSettings(
      siteName: _string(json['siteName']),
      logoUrl: resolveUrl(_string(json['logoUrl'])),
      darkLogoUrl: resolveUrl(_string(json['darkLogoUrl'])),
      faviconUrl: resolveUrl(_string(json['faviconUrl'])),
    );
  }

  final String siteName;
  final String logoUrl;
  final String darkLogoUrl;
  final String faviconUrl;

  String get displayLogoUrl {
    if (logoUrl.isNotEmpty) return logoUrl;
    if (darkLogoUrl.isNotEmpty) return darkLogoUrl;
    return '';
  }

  String get lightSurfaceLogoUrl {
    if (logoUrl.isNotEmpty) return logoUrl;
    if (darkLogoUrl.isNotEmpty) return darkLogoUrl;
    return '';
  }

  bool get hasLogo => displayLogoUrl.isNotEmpty;
}

class AppShellNavigationItem {
  const AppShellNavigationItem({
    required this.id,
    required this.menuId,
    required this.menuCode,
    required this.parentId,
    required this.label,
    required this.type,
    required this.value,
    required this.icon,
    required this.orderIndex,
    required this.isActive,
    required this.languageCode,
  });

  factory AppShellNavigationItem.fromJson(Map<dynamic, dynamic> json) {
    return AppShellNavigationItem(
      id: _string(json['id']),
      menuId: _string(json['menuId']),
      menuCode: _string(json['menuCode']),
      parentId: _nullableString(json['parentId']),
      label: _string(json['label']),
      type: _string(json['type']),
      value: _string(json['value']),
      icon: _string(json['icon']),
      orderIndex: int.tryParse(json['orderIndex']?.toString() ?? '') ?? 0,
      isActive: json['isActive'] != false,
      languageCode: _string(json['languageCode']),
    );
  }

  final String id;
  final String menuId;
  final String menuCode;
  final String? parentId;
  final String label;
  final String type;
  final String value;
  final String icon;
  final int orderIndex;
  final bool isActive;
  final String languageCode;

  String get navigationValue => value.isNotEmpty ? value : label;
}

class AppShellPage {
  const AppShellPage({
    required this.id,
    required this.title,
    required this.slug,
    required this.categoryId,
    required this.category,
    required this.pageType,
    required this.menuOrder,
    required this.contentPlain,
    required this.metaDescription,
    required this.canonicalUrl,
  });

  factory AppShellPage.fromJson(Map<dynamic, dynamic> json) {
    return AppShellPage(
      id: _string(json['id']),
      title: _string(json['title']),
      slug: _string(json['slug']),
      categoryId: _string(json['categoryId']),
      category: _string(json['category']),
      pageType: _string(json['pageType']),
      menuOrder: int.tryParse(json['menuOrder']?.toString() ?? '') ?? 0,
      contentPlain: _string(json['contentPlain']),
      metaDescription: _string(json['metaDescription']),
      canonicalUrl: _string(json['canonicalUrl']),
    );
  }

  final String id;
  final String title;
  final String slug;
  final String categoryId;
  final String category;
  final String pageType;
  final int menuOrder;
  final String contentPlain;
  final String metaDescription;
  final String canonicalUrl;

  bool belongsToRoot(String rootId) {
    final cleanRootId = rootId.trim();
    return cleanRootId.isNotEmpty && categoryId == cleanRootId;
  }
}

class AppShellData {
  const AppShellData({
    required this.languageCode,
    required this.siteSettings,
    required this.navigationItems,
    this.pages = const [],
  });

  const AppShellData.empty()
    : languageCode = 'tr',
      siteSettings = const AppShellSettings.empty(),
      navigationItems = const [],
      pages = const [];

  factory AppShellData.fromJson(
    Map<dynamic, dynamic> json,
    String Function(String) resolveUrl,
  ) {
    final rawItems = json['navigationItems'];
    final items = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map(AppShellNavigationItem.fromJson)
              .where((item) => item.isActive && item.label.isNotEmpty)
              .toList()
        : <AppShellNavigationItem>[];
    items.sort((a, b) {
      final menu = _menuRank(a.menuCode).compareTo(_menuRank(b.menuCode));
      if (menu != 0) return menu;
      final order = a.orderIndex.compareTo(b.orderIndex);
      if (order != 0) return order;
      return a.id.compareTo(b.id);
    });

    final settings = json['siteSettings'];
    final rawPages = json['pages'];
    final pages = rawPages is List
        ? rawPages
              .whereType<Map>()
              .map(AppShellPage.fromJson)
              .where(
                (page) => page.title.isNotEmpty && page.contentPlain.isNotEmpty,
              )
              .toList()
        : <AppShellPage>[];
    pages.sort((a, b) {
      final order = a.menuOrder.compareTo(b.menuOrder);
      if (order != 0) return order;
      return a.title.compareTo(b.title);
    });

    return AppShellData(
      languageCode: _string(json['languageCode']).isEmpty
          ? 'tr'
          : _string(json['languageCode']),
      siteSettings: settings is Map
          ? AppShellSettings.fromJson(settings, resolveUrl)
          : const AppShellSettings.empty(),
      navigationItems: items,
      pages: pages,
    );
  }

  final String languageCode;
  final AppShellSettings siteSettings;
  final List<AppShellNavigationItem> navigationItems;
  final List<AppShellPage> pages;

  List<AppShellNavigationItem> get topNavigationItems => navigationItems
      .where((item) => item.menuCode == 'top_navbar')
      .toList(growable: false);

  List<AppShellNavigationItem> get sidebarNavigationItems => navigationItems
      .where((item) => item.menuCode == 'sidebar_main')
      .toList(growable: false);

  List<AppShellPage> pagesForRoot(String rootId) {
    final rootPages = pages
        .where((page) => page.belongsToRoot(rootId))
        .toList(growable: false);
    return rootPages.isEmpty ? pages : rootPages;
  }
}

class AppShellRepository {
  const AppShellRepository({this.httpClient, this.apiBaseUrl});

  static const _apiBaseUrl = String.fromEnvironment('PATEEZNEWS_API_BASE_URL');
  static const _timeout = Duration(seconds: 10);

  final http.Client? httpClient;
  final String? apiBaseUrl;

  Future<AppShellData> fetch(String languageCode) async {
    final uri = _uri(
      '/api/app/shell',
    ).replace(queryParameters: {'lang': _cleanLanguageCode(languageCode)});
    final client = httpClient ?? sharedFrontendClient;
    try {
      final response = await client
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(_timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const AppShellData.empty();
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map) return const AppShellData.empty();
      return AppShellData.fromJson(decoded, _resolveUrl);
    } catch (_) {
      return const AppShellData.empty();
    } finally {
      // Shared frontend client is not closed.
    }
  }

  Uri _uri(String path) {
    return frontendApiUri(path, configuredBaseUrl: apiBaseUrl ?? _apiBaseUrl);
  }

  String _resolveUrl(String value) {
    if (value.isEmpty) return '';
    final uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme) return value;
    return _uri(value).toString();
  }
}

String _cleanLanguageCode(String value) {
  final code = value.trim().toLowerCase().replaceAll('_', '-');
  return code.isEmpty ? 'tr' : code;
}

String _string(Object? value) => (value ?? '').toString().trim();

String? _nullableString(Object? value) {
  final result = _string(value);
  return result.isEmpty ? null : result;
}

int _menuRank(String code) {
  return switch (code) {
    'top_navbar' => 0,
    'sidebar_main' => 1,
    _ => 2,
  };
}
