import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pateeznews_admin/frontend/features/home/data/home_repository.dart';

void main() {
  test('fetchHome maps featured slider and live feed items', () async {
    final repository = HomeRepository(
      apiBaseUrl: 'http://localhost:4321',
      httpClient: MockClient((request) async {
        expect(request.url.path, '/api/app/home');
        expect(request.url.queryParameters['lang'], 'tr');
        expect(request.url.queryParameters['limit'], '10');
        expect(request.url.queryParameters['feedLimit'], '30');

        final payload = {
          'featured': [
            {
              'id': 'manset-1',
              'category': 'Gündem',
              'title': 'Manşet başlığı',
              'summary': 'Manşet özeti',
              'imageUrl': 'http://localhost:4321/local-upload/manset.jpg',
              'publishedAt': '2026-06-07T13:45:00.000Z',
              'source': 'Pateeznews',
              'slug': 'manset-basligi',
              'imageAspectRatio': 2,
            },
          ],
          'feed': [
            {
              'id': 'news-1',
              'category': 'Ekonomi',
              'title': 'Canlı haber başlığı',
              'summary': 'Canlı haber özeti',
              'imageUrl': 'http://localhost:4321/local-upload/news.jpg',
              'publishedAt': '2026-06-08T13:08:00.000Z',
              'source': 'Pateez Ekonomi',
              'sourceAvatar': 'http://localhost:4321/local-upload/avatar.jpg',
              'slug': 'canli-haber-basligi',
              'likes': 12,
              'dislikes': 1,
              'comments': 3,
              'shares': 4,
              'views': 138,
              'saves': 5,
              'readMinutes': 4,
              'isPinned': true,
              'isManset': false,
              'imageAspectRatio': 1.5,
            },
          ],
        };

        return http.Response(
          jsonEncode(payload),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final data = await repository.fetchHome();

    expect(data.featured, hasLength(1));
    expect(data.featured.single.id, 'manset-1');
    expect(data.featured.single.imageAspectRatio, 2);
    expect(data.feed, hasLength(1));
    expect(data.feed.single.id, 'news-1');
    expect(data.feed.single.title, 'Canlı haber başlığı');
    expect(data.feed.single.region, isEmpty);
    expect(data.feed.single.views, 138);
    expect(data.feed.single.readMinutes, 4);
    expect(data.feed.single.saves, 5);
    expect(data.feed.single.isPinned, isTrue);
    expect(data.feed.single.imageAspectRatio, 1.5);
  });
}
