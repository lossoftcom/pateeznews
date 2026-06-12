import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pateeznews_admin/frontend/features/search/data/search_repository.dart';

void main() {
  test('search maps posts and profiles from app search endpoint', () async {
    final repository = SearchRepository(
      apiBaseUrl: 'http://localhost:4321',
      httpClient: MockClient((request) async {
        expect(request.url.path, '/api/app/search');
        expect(request.url.queryParameters['q'], 'nigde');
        expect(request.url.queryParameters['lang'], 'tr');
        expect(request.url.queryParameters['limit'], '14');
        expect(request.headers['Authorization'], 'Bearer token-1');

        return http.Response(
          jsonEncode({
            'posts': [
              {
                'id': '37',
                'category': 'Kültür',
                'title': 'Niğde Kitap Fuarı',
                'summary': 'Kitapseverler buluşuyor.',
                'imageUrl': 'http://localhost:4321/local-upload/book.webp',
                'publishedAt': '2026-06-11T09:00:00.000Z',
                'source': 'Pateeznews',
                'slug': 'nigde-kitap-fuari',
                'likes': 4,
                'comments': 2,
                'shares': 1,
                'views': 90,
              },
            ],
            'profiles': [
              {
                'id': 'profile-1',
                'username': 'pateez',
                'full_name': 'Pateez Editör',
                'avatar_url': 'http://localhost:4321/avatar.webp',
                'role': 'editor',
                'expertise': 'Yerel haber',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final data = await repository.search(query: 'nigde', token: 'token-1');

    expect(data.posts, hasLength(1));
    expect(data.posts.first.title, 'Niğde Kitap Fuarı');
    expect(data.posts.first.slug, 'nigde-kitap-fuari');
    expect(data.profiles, hasLength(1));
    expect(data.profiles.first.displayName, 'Pateez Editör');
    expect(data.profiles.first.handle, '@pateez');
  });
}
