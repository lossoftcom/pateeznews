import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pateeznews_admin/frontend/core/network/local_api_base_url.dart';
import 'package:pateeznews_admin/frontend/core/theme/frontend_font_settings.dart';
import 'package:pateeznews_admin/frontend/features/shell/data/app_shell_repository.dart';

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('Android emulator varsayilan olarak canli APIye baglanir', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    expect(frontendLocalApiBaseUrl().toString(), 'https://pateez.com');
  });

  test('iOS simulator varsayilan olarak canli APIye baglanir', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    expect(frontendLocalApiBaseUrl().toString(), 'https://pateez.com');
  });

  test(
    'Android localhost override degerini emulator host aliasina cevirir',
    () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      expect(
        frontendLocalApiBaseUrl(
          configuredBaseUrl: 'http://localhost:4321',
        ).toString(),
        'http://10.0.2.2:4321',
      );
    },
  );

  test(
    'Font ayarlari Androidde dart-define olmadan canli APIyi kullanir',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final requestedUrls = <String>[];
      final repository = FrontendFontSettingsRepository(
        httpClient: MockClient((request) async {
          requestedUrls.add(request.url.toString());
          return http.Response(
            jsonEncode({
              'fonts': [],
              'settings': {
                'primaryFont': 'PateezInter',
                'titleFont': 'PateezInter',
                'contentFont': 'PateezInter',
                'fontSizes': {},
                'mobileFontSizes': {},
              },
            }),
            200,
            headers: {'Content-Type': 'application/json'},
          );
        }),
      );

      await repository.fetch('tr');

      expect(
        requestedUrls,
        contains('https://pateez.com/api/app/font-settings?lang=tr'),
      );
    },
  );

  test('Shell verisi logo ve menuleri app APIden okur', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final requestedUrls = <String>[];
    final payload = {
      'languageCode': 'tr',
      'siteSettings': {
        'siteName': 'Pateez.com',
        'logoUrl': '/api/storage/file/logo/tr/pateezlogoson.png',
        'darkLogoUrl': '',
        'faviconUrl': '',
      },
      'navigationItems': [
        {
          'id': 'nav-home',
          'menuId': 'top',
          'menuCode': 'top_navbar',
          'parentId': null,
          'label': 'Ana Sayfa',
          'type': 'link',
          'value': '/',
          'icon': 'home',
          'orderIndex': 0,
          'isActive': true,
          'languageCode': 'tr',
        },
        {
          'id': 'side-root',
          'menuId': 'side',
          'menuCode': 'sidebar_main',
          'parentId': null,
          'label': 'Niğde',
          'type': 'dropdown',
          'value': '',
          'icon': 'location_on',
          'orderIndex': 0,
          'isActive': true,
          'languageCode': 'tr',
        },
      ],
    };
    final repository = AppShellRepository(
      httpClient: MockClient((request) async {
        requestedUrls.add(request.url.toString());
        return http.Response.bytes(
          utf8.encode(jsonEncode(payload)),
          200,
          headers: {'Content-Type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final direct = AppShellData.fromJson(
      payload,
      (value) => frontendApiUri(value).toString(),
    );
    expect(
      direct.siteSettings.logoUrl,
      'https://pateez.com/api/storage/file/logo/tr/pateezlogoson.png',
    );

    final data = await repository.fetch('tr');

    expect(
      requestedUrls,
      contains('https://pateez.com/api/app/shell?lang=tr'),
    );
    expect(
      data.siteSettings.logoUrl,
      'https://pateez.com/api/storage/file/logo/tr/pateezlogoson.png',
    );
    expect(data.topNavigationItems.single.label, 'Ana Sayfa');
    expect(data.sidebarNavigationItems.single.label, 'Niğde');
  });
}
