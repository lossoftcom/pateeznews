import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pateeznews_admin/frontend/features/category/data/category_repository.dart';

void main() {
  test('fetchCategory maps live category feed items', () async {
    final repository = CategoryRepository(
      apiBaseUrl: 'http://localhost:4321',
      httpClient: MockClient((request) async {
        expect(request.url.path, '/api/app/category-news');
        expect(request.url.queryParameters['lang'], 'tr');
        expect(request.url.queryParameters['category'], 'Yaşam');
        expect(request.url.queryParameters['type'], 'category');
        expect(request.url.queryParameters['value'], 'yasam');
        expect(request.url.queryParameters['limit'], '16');
        expect(request.headers['Authorization'], 'Bearer token');

        return http.Response(
          jsonEncode({
            'total': 7,
            'totalViews': 1200,
            'nextOffset': 1,
            'hasMore': true,
            'items': [
              {
                'id': '42',
                'category': 'Yaşam',
                'title': 'Canlı kategori haberi',
                'summary': '<p>Kategori haber özeti.</p>',
                'imageUrl': 'http://localhost:4321/local-upload/news.jpg',
                'publishedAt': '2026-06-10T09:15:00.000Z',
                'source': 'Pateez Yaşam',
                'sourceAvatar': 'http://localhost:4321/local-upload/avatar.jpg',
                'publisherBio': 'Yaşam gündemi yazarı',
                'publisherExpertise': 'Yerel yaşam',
                'slug': 'canli-kategori-haberi',
                'likes': 8,
                'dislikes': 1,
                'comments': 2,
                'shares': 3,
                'views': 144,
                'saves': 5,
                'userLiked': true,
                'userDisliked': false,
                'userSaved': true,
                'readMinutes': 3,
                'imageAspectRatio': 1.25,
                'previewComments': [
                  {
                    'id': '9',
                    'parentId': '',
                    'body': 'Temiz haber.',
                    'publishedAt': '2026-06-10T09:20:00.000Z',
                    'likes': 4,
                    'userLiked': false,
                    'canDelete': false,
                    'author': {
                      'name': 'Okur',
                      'avatarUrl': '',
                      'handle': '@okur',
                      'isVerified': true,
                      'isOfficial': false,
                    },
                    'replies': [],
                  },
                ],
              },
            ],
          }),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final data = await repository.fetchCategory(
      category: 'Yaşam',
      type: 'category',
      value: 'yasam',
      token: 'token',
    );

    expect(data.total, 7);
    expect(data.totalViews, 1200);
    expect(data.hasMore, isTrue);
    expect(data.items, hasLength(1));
    expect(data.items.single.id, '42');
    expect(data.items.single.title, 'Canlı kategori haberi');
    expect(data.items.single.summary, 'Kategori haber özeti.');
    expect(data.items.single.likes, 8);
    expect(data.items.single.comments, 2);
    expect(data.items.single.views, 144);
    expect(data.items.single.author.bio, 'Yaşam gündemi yazarı');
    expect(data.items.single.author.expertise, 'Yerel yaşam');
    expect(data.items.single.userLiked, isTrue);
    expect(data.items.single.userSaved, isTrue);
    expect(data.items.single.previewComments.single.body, 'Temiz haber.');
  });
}
