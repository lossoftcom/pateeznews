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
              'userLiked': true,
              'userDisliked': false,
              'userSaved': true,
              'readMinutes': 4,
              'isPinned': true,
              'isManset': false,
              'imageAspectRatio': 1.5,
              'videoUrl': 'http://localhost:4321/local-upload/video-a.mp4',
              'videoUrls': [
                'http://localhost:4321/local-upload/video-a.mp4',
                'https://youtube.com/shorts/test-short',
              ],
              'socialEmbed': 'https://www.instagram.com/p/test-code/',
              'socialSourceUrl': 'https://www.instagram.com/p/test-code/',
              'socialPlatform': 'instagram',
              'reviewData': {
                'productName': 'Niğde performans incelemesi',
                'productImage': 'http://localhost:4321/local-upload/review.jpg',
                'score': 82,
                'pros': ['Afet sonrası hızlı saha müdahalesi'],
                'cons': ['Anlık bilgi erişiminin geliştirilmesi gerekiyor'],
                'breakdown': [
                  {'label': 'Afet müdahale refleksi', 'score': 86},
                ],
                'verdict':
                    '<p>Niğde son 15 günde hizmet ve yatırım gündemi yaşadı.</p>',
              },
              'pollData': {
                'title': 'Niğde’de öncelik ne olmalı?',
                'description': '<p>Okurların öncelik tercihi.</p>',
                'isImagePoll': true,
                'columns': 3,
                'totalVotes': 7,
                'options': [
                  {
                    'id': 'poll-a',
                    'text': 'Afet hazırlığı ve sel altyapısı',
                    'imageUrl': 'http://localhost:4321/local-upload/a.jpg',
                    'votes': 4,
                  },
                  {
                    'id': 'poll-b',
                    'text': 'Yol ve yağmur suyu yatırımları',
                    'imageUrl': 'http://localhost:4321/local-upload/b.jpg',
                    'votes': 2,
                  },
                ],
              },
              'vsData': {
                'title': 'Niğde’de öncelik hangisi olmalı?',
                'description': '<p>Afet altyapısı mı, sosyal yatırım mı?</p>',
                'totalVotes': 10,
                'options': [
                  {
                    'id': 'vs-left',
                    'text': 'Afetlere dayanıklı altyapı',
                    'imageUrl':
                        'http://localhost:4321/local-upload/vs-left.jpg',
                    'votes': 6,
                  },
                  {
                    'id': 'vs-right',
                    'text': 'Sosyal yaşam ve yatırım projeleri',
                    'imageUrl':
                        'http://localhost:4321/local-upload/vs-right.jpg',
                    'votes': 4,
                  },
                ],
              },
              'quoteData': {
                'text':
                    '<p>Su tahliye, temizlik ve hasar tespit çalışmaları sürdürülmektedir.</p>',
                'author': 'Vali Nedim Akmeşe’den Açıklama',
                'sourceUrl': 'https://example.com/kaynak',
              },
              'previewComments': [
                {
                  'id': '17',
                  'parentId': '',
                  'body': 'Net ve sade bir haber olmuş.',
                  'publishedAt': '2026-06-10T09:10:00.000Z',
                  'likes': 8,
                  'userLiked': true,
                  'canDelete': true,
                  'author': {
                    'name': 'Ayşe K.',
                    'avatarUrl': 'http://localhost:4321/a.jpg',
                    'handle': '@aysek',
                    'isVerified': true,
                    'isOfficial': false,
                  },
                  'replies': [
                    {
                      'id': '18',
                      'parentId': '17',
                      'body': 'Katılıyorum.',
                      'publishedAt': '2026-06-10T09:14:00.000Z',
                      'likes': 2,
                      'userLiked': false,
                      'author': {
                        'name': 'Pateez Editör',
                        'avatarUrl': 'http://localhost:4321/e.jpg',
                        'handle': '@pateez',
                        'isVerified': true,
                        'isOfficial': true,
                      },
                      'replies': [],
                    },
                  ],
                },
              ],
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
    expect(data.feed.single.userLiked, isTrue);
    expect(data.feed.single.userDisliked, isFalse);
    expect(data.feed.single.userSaved, isTrue);
    expect(data.feed.single.isPinned, isTrue);
    expect(data.feed.single.imageAspectRatio, 1.5);
    expect(
      data.feed.single.primaryVideoUrl,
      'http://localhost:4321/local-upload/video-a.mp4',
    );
    expect(data.feed.single.videoFeedUrls, [
      'http://localhost:4321/local-upload/video-a.mp4',
      'https://youtube.com/shorts/test-short',
    ]);
    expect(
      data.feed.single.socialEmbed,
      'https://www.instagram.com/p/test-code/',
    );
    expect(
      data.feed.single.socialSourceUrl,
      'https://www.instagram.com/p/test-code/',
    );
    expect(data.feed.single.socialPlatform, 'instagram');
    expect(data.feed.single.reviewData, isNotNull);
    expect(
      data.feed.single.reviewData?.productName,
      'Niğde performans incelemesi',
    );
    expect(
      data.feed.single.reviewData?.productImage,
      'http://localhost:4321/local-upload/review.jpg',
    );
    expect(data.feed.single.reviewData?.score, 82);
    expect(data.feed.single.reviewData?.pros, [
      'Afet sonrası hızlı saha müdahalesi',
    ]);
    expect(data.feed.single.reviewData?.cons, [
      'Anlık bilgi erişiminin geliştirilmesi gerekiyor',
    ]);
    expect(
      data.feed.single.reviewData?.breakdown.single.label,
      'Afet müdahale refleksi',
    );
    expect(data.feed.single.reviewData?.breakdown.single.score, 86);
    expect(
      data.feed.single.reviewData?.verdict,
      'Niğde son 15 günde hizmet ve yatırım gündemi yaşadı.',
    );
    expect(data.feed.single.pollData, isNotNull);
    expect(data.feed.single.pollData?.title, 'Niğde’de öncelik ne olmalı?');
    expect(
      data.feed.single.pollData?.description,
      'Okurların öncelik tercihi.',
    );
    expect(data.feed.single.pollData?.isImagePoll, isTrue);
    expect(data.feed.single.pollData?.columns, 3);
    expect(data.feed.single.pollData?.totalVotes, 7);
    expect(data.feed.single.pollData?.resolvedTotalVotes, 7);
    expect(data.feed.single.pollData?.options, hasLength(2));
    expect(
      data.feed.single.pollData?.options.first.imageUrl,
      'http://localhost:4321/local-upload/a.jpg',
    );
    expect(data.feed.single.vsData, isNotNull);
    expect(data.feed.single.vsData?.title, 'Niğde’de öncelik hangisi olmalı?');
    expect(
      data.feed.single.vsData?.description,
      'Afet altyapısı mı, sosyal yatırım mı?',
    );
    expect(data.feed.single.vsData?.totalVotes, 10);
    expect(data.feed.single.vsData?.resolvedTotalVotes, 10);
    expect(data.feed.single.vsData?.options, hasLength(2));
    expect(
      data.feed.single.vsData?.options.last.imageUrl,
      'http://localhost:4321/local-upload/vs-right.jpg',
    );
    expect(data.feed.single.quoteData, isNotNull);
    expect(
      data.feed.single.quoteData?.text,
      'Su tahliye, temizlik ve hasar tespit çalışmaları sürdürülmektedir.',
    );
    expect(
      data.feed.single.quoteData?.author,
      'Vali Nedim Akmeşe’den Açıklama',
    );
    expect(data.feed.single.quoteData?.sourceUrl, 'https://example.com/kaynak');
    expect(data.feed.single.previewComments, hasLength(1));
    expect(data.feed.single.previewComments.single.id, '17');
    expect(data.feed.single.previewComments.single.userLiked, isTrue);
    expect(data.feed.single.previewComments.single.canDelete, isTrue);
    expect(
      data.feed.single.previewComments.single.replies.single.body,
      'Katılıyorum.',
    );
  });

  test('fetchHome sends bearer token when provided', () async {
    final repository = HomeRepository(
      apiBaseUrl: 'http://localhost:4321',
      httpClient: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer token-123');
        return http.Response(
          jsonEncode({'featured': [], 'feed': []}),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final data = await repository.fetchHome(token: 'token-123');

    expect(data.featured, isEmpty);
    expect(data.feed, isEmpty);
  });
}
