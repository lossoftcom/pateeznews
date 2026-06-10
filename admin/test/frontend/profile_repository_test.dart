import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pateeznews_admin/frontend/features/profile/data/profile_repository.dart';

void main() {
  test(
    'profil görseli yükleme isteği native ortamda Origin header ekler',
    () async {
      String? originHeader;
      String? requestOrigin;

      final repository = ProfileRepository(
        apiBaseUrl: 'http://127.0.0.1:4321',
        httpClient: MockClient((request) async {
          requestOrigin = '${request.url.scheme}://${request.url.authority}';
          for (final entry in request.headers.entries) {
            if (entry.key.toLowerCase() == 'origin') {
              originHeader = entry.value;
              break;
            }
          }

          expect(request.url.path, '/api/app/profile-upload');
          expect(request.method, 'POST');
          expect(request.headers['authorization'], 'Bearer token');

          return http.Response(
            jsonEncode({
              'ok': true,
              'kind': 'avatar',
              'id': 'avatar',
              'publicSrc': '/local-upload/profile/avatar.webp',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final result = await repository.uploadProfileImage(
        token: 'token',
        kind: 'avatar',
        fileName: 'avatar.jpg',
        bytes: const [0xFF, 0xD8, 0xFF, 0xD9],
      );

      expect(originHeader, requestOrigin);
      expect(result.publicSrc, '/local-upload/profile/avatar.webp');
    },
  );
}
