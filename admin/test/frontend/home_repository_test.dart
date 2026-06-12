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
        expect(request.url.queryParameters.containsKey('limit'), isFalse);
        expect(request.url.queryParameters.containsKey('feedLimit'), isFalse);

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
              'article': {
                'id': 'manset-1',
                'category': 'Gündem',
                'title': 'Manşet başlığı',
                'summary': '<p>Manşet detay özeti</p>',
                'imageUrl': 'http://localhost:4321/local-upload/manset.jpg',
                'publishedAt': '2026-06-07T13:45:00.000Z',
                'source': 'Pateeznews',
                'sourceAvatar':
                    'http://localhost:4321/local-upload/manset-avatar.jpg',
                'slug': 'manset-basligi',
                'likes': 6,
                'dislikes': 0,
                'comments': 2,
                'shares': 1,
                'views': 55,
                'saves': 4,
                'userLiked': true,
                'readMinutes': 3,
                'isManset': true,
                'detailItems': [
                  {
                    'id': 'detail-1',
                    'type': 'paragraph',
                    'title': 'Detay',
                    'description': '<p>Detay açıklaması</p>',
                  },
                ],
              },
            },
          ],
          'feed': [
            {
              'id': 'news-1',
              'category': 'Ekonomi',
              'categoryTrail': ['Niğde', 'Çamardı', 'Testler'],
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
                'https://youtube.com/shorts/shortID1234',
              ],
              'videoThumbUrls': [
                '',
                'https://example.invalid/short-thumb.webp',
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
              'quizData': {
                'quizType': 'trivia',
                'questionSorting': 'desc',
                'allowMultiple': false,
                'showResults': true,
                'results': [
                  {
                    'id': 'strong',
                    'title': 'Gündemi yakından takip ediyorsun',
                    'description': '<p>Niğde gündemine hakimsin.</p>',
                    'minScore': 1,
                    'maxScore': 1,
                  },
                ],
                'questions': [
                  {
                    'id': 'q1',
                    'title': 'Gümüşler’de gündem olan olay neydi?',
                    'description': '<p>Haberdeki ana afet başlığını seç.</p>',
                    'layout': 'list',
                    'answers': [
                      {
                        'id': 'a1',
                        'text': 'Sel felaketi',
                        'isCorrect': true,
                        'explanation': '<p>Haberin ana konusu seldi.</p>',
                      },
                      {
                        'id': 'a2',
                        'text': 'Kültür festivali',
                        'isCorrect': false,
                      },
                    ],
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
              'detailItems': [
                {
                  'id': 'toc-1',
                  'type': 'toc',
                  'title': 'Çamardı rehberi',
                  'description': '<p>Başlıklara dokunarak bölümlere geç.</p>',
                  'tocData': {
                    'title': 'İçindekiler',
                    'linkListStyle': {
                      'level1': 'decimal-leading-zero',
                      'level2': 'lower-alpha',
                      'level3': 'none',
                    },
                    'showInText': {
                      'level1': true,
                      'level2': false,
                      'level3': false,
                    },
                    'items': [
                      {
                        'id': 'intro',
                        'title': 'Giriş',
                        'content': '<p>Çamardı için kısa giriş.</p>',
                        'orderNumber': 1,
                      },
                      {
                        'id': 'route',
                        'title': 'Demirkazık rotası',
                        'parentId': 'intro',
                        'imageUrl':
                            'http://localhost:4321/local-upload/route.jpg',
                        'imageDescription': '<p>Demirkazık manzarası</p>',
                        'content': '<p>Rota ve ulaşım bilgileri.</p>',
                        'orderNumber': 2,
                      },
                    ],
                  },
                },
              ],
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
          'settings': {
            'showFeaturedSection': true,
            'commentSystem': false,
            'commentApprovalSystem': true,
            'emojiReactions': false,
            'homePageSize': 24,
            'featuredContentSource': 'manual',
            'featuredSortingLogic': 'slider_order',
            'featuredDurationDays': 10,
            'featuredLimit': 15,
          },
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
    expect(data.featured.single.article, isNotNull);
    expect(data.featured.single.article?.id, 'manset-1');
    expect(data.featured.single.article?.summary, 'Manşet detay özeti');
    expect(data.featured.single.article?.views, 55);
    expect(data.featured.single.article?.isManset, isTrue);
    expect(
      data.featured.single.article?.detailItems.single.description,
      'Detay açıklaması',
    );
    expect(data.settings.showFeaturedSection, isTrue);
    expect(data.settings.commentSystem, isFalse);
    expect(data.settings.commentApprovalSystem, isTrue);
    expect(data.settings.emojiReactions, isFalse);
    expect(data.settings.homePageSize, 24);
    expect(data.settings.featuredContentSource, 'manual');
    expect(data.settings.featuredSortingLogic, 'slider_order');
    expect(data.settings.featuredDurationDays, 10);
    expect(data.settings.featuredLimit, 15);
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
      'https://youtube.com/shorts/shortID1234',
    ]);
    expect(data.feed.single.videoThumbUrls, [
      '',
      'https://example.invalid/short-thumb.webp',
    ]);
    expect(
      data.feed.single.videoFeedPosterFor(
        data.feed.single.videoFeedUrls.first,
        0,
      ),
      isEmpty,
    );
    expect(
      data.feed.single.videoFeedPosterFor(
        data.feed.single.videoFeedUrls.last,
        1,
      ),
      'https://example.invalid/short-thumb.webp',
    );
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
    expect(data.feed.single.quizData, isNotNull);
    expect(data.feed.single.quizData?.quizType, 'trivia');
    expect(data.feed.single.quizData?.questionSorting, 'desc');
    expect(data.feed.single.categoryTrail, ['Niğde', 'Çamardı', 'Testler']);
    expect(
      data.feed.single.quizData?.results.single.title,
      'Gündemi yakından takip ediyorsun',
    );
    expect(
      data.feed.single.quizData?.results.single.description,
      'Niğde gündemine hakimsin.',
    );
    expect(
      data.feed.single.quizData?.questions.single.title,
      'Gümüşler’de gündem olan olay neydi?',
    );
    expect(
      data.feed.single.quizData?.questions.single.description,
      'Haberdeki ana afet başlığını seç.',
    );
    expect(
      data.feed.single.quizData?.questions.single.answers.first.isCorrect,
      isTrue,
    );
    expect(
      data.feed.single.quizData?.questions.single.answers.first.explanation,
      'Haberin ana konusu seldi.',
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
    expect(data.feed.single.detailItems, hasLength(1));
    final tocData = data.feed.single.detailItems.single.tocData;
    expect(tocData, isNotNull);
    expect(tocData?.title, 'İçindekiler');
    expect(tocData?.level1Style, 'decimal-leading-zero');
    expect(tocData?.level2Style, 'lower-alpha');
    expect(tocData?.showLevel1InText, isTrue);
    expect(tocData?.items, hasLength(2));
    expect(tocData?.items.last.parentId, 'intro');
    expect(
      tocData?.items.last.imageUrl,
      'http://localhost:4321/local-upload/route.jpg',
    );
    expect(tocData?.items.last.imageDescription, 'Demirkazık manzarası');
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
