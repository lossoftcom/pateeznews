import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pateeznews_admin/frontend/core/network/local_api_base_url.dart';
import 'package:pateeznews_admin/frontend/core/theme/frontend_font_settings.dart';

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('Android emulator host makineye 10.0.2.2 ile baglanir', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    expect(frontendLocalApiBaseUrl().toString(), 'http://10.0.2.2:4321');
  });

  test('iOS ve desktop local dev icin localhost kullanir', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    expect(frontendLocalApiBaseUrl().toString(), 'http://localhost:4321');
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
    'Font ayarlari Androidde dart-define olmadan local APIyi kullanir',
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
        contains('http://10.0.2.2:4321/api/app/font-settings?lang=tr'),
      );
    },
  );
}
