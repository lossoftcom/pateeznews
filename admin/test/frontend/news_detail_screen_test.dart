import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pateeznews_admin/frontend/core/mock/home_mock_data.dart';
import 'package:pateeznews_admin/frontend/features/home/data/post_action_repository.dart';
import 'package:pateeznews_admin/frontend/features/home/presentation/widgets/news_card.dart';
import 'package:pateeznews_admin/frontend/features/news_detail/presentation/news_detail_screen.dart';
import 'package:pateeznews_admin/frontend/features/news_detail/presentation/widgets/detail_reactions.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('detail screen keeps cover first and renders ordered items', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final article = NewsArticle(
      id: '123',
      author: const NewsAuthor(
        id: 'publisher-1',
        name: 'Pateez Niğde',
        avatarUrl: 'https://example.invalid/avatar.jpg',
        isOfficial: true,
      ),
      region: 'Niğde',
      category: 'Gündem',
      title: 'Gümüşler’de Sel Acısı, Gebere’de Yeni Proje',
      summary:
          'Niğde’de son günlerin en ağır gündemi sel ve yeni yatırım oldu.',
      imageUrl: 'https://example.invalid/cover.jpg',
      imageAspectRatio: 16 / 9,
      videoUrl: 'https://example.invalid/homepage-video.mp4',
      publishedAt: DateTime.utc(2026, 6, 11, 10, 15),
      readMinutes: 3,
      likes: 1,
      dislikes: 0,
      comments: 2,
      shares: 2,
      views: 4,
      saves: 1,
      previewComments: HomeMockData.samplePreviewComments,
      detailItems: const [
        NewsDetailItem(
          id: 'text-1',
          type: 'text',
          title: 'Sel sonrası ilk değerlendirme',
          description: 'Ekipler bölgede hasar tespit çalışmalarını sürdürüyor.',
          source: 'Pateez Haber Merkezi',
        ),
        NewsDetailItem(
          id: 'image-1',
          type: 'image',
          title: 'Bölgeden kare',
          description: 'Görsel blok haber akışındaki sırasında yer alır.',
          altText: 'Sel sonrası bölgede çalışma yapan ekipler',
          source: 'https://www.gzt.com/dunya/ornek-haber',
          mediaUrl: 'https://example.invalid/detail-image.jpg',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: NewsDetailScreen(
          articles: [article],
          initialIndex: 0,
          postActionRepository: const _DetailPostActionRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NewsCard), findsWidgets);
    expect(find.text(article.title), findsWidgets);
    expect(find.text(article.summary), findsOneWidget);
    expect(find.text('Sel sonrası ilk değerlendirme'), findsOneWidget);
    expect(find.text('Pateez Haber Merkezi'), findsOneWidget);
    expect(find.text('Bölgeden kare'), findsOneWidget);
    expect(
      find.text('Görsel blok haber akışındaki sırasında yer alır.'),
      findsOneWidget,
    );
    expect(
      find.text('Sel sonrası bölgede çalışma yapan ekipler'),
      findsOneWidget,
    );
    expect(find.text('https://www.gzt.com/dunya/ornek-haber'), findsOneWidget);
    expect(find.text('Yorumunuzu ekleyin'), findsOneWidget);
    expect(find.text('Emojiyle Tepki Ver'), findsOneWidget);
    expect(
      find.text('Pateeznews muhabir ağı ve kurumsal açıklamalardan derlendi.'),
      findsNothing,
    );

    final coverImage = tester.widget<CachedNetworkImage>(
      find.byWidgetPredicate(
        (widget) =>
            widget is CachedNetworkImage && widget.imageUrl == article.imageUrl,
      ),
    );
    expect(coverImage.fit, BoxFit.contain);

    final detailImageFinder = find.byWidgetPredicate(
      (widget) =>
          widget is CachedNetworkImage &&
          widget.imageUrl == 'https://example.invalid/detail-image.jpg',
    );
    expect(detailImageFinder, findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Bölgeden kare')).dy,
      lessThan(
        tester
            .getTopLeft(
              find.text('Görsel blok haber akışındaki sırasında yer alır.'),
            )
            .dy,
      ),
    );
    expect(
      tester
          .getTopLeft(
            find.text('Görsel blok haber akışındaki sırasında yer alır.'),
          )
          .dy,
      lessThan(tester.getTopLeft(detailImageFinder).dy),
    );
    expect(
      tester.getTopLeft(detailImageFinder).dy,
      lessThan(
        tester
            .getTopLeft(find.text('Sel sonrası bölgede çalışma yapan ekipler'))
            .dy,
      ),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('detail reactions toggle for guest without auth prompt', (
    tester,
  ) async {
    final repository = _GuestReactionRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DetailReactionsStrip(
            postId: '123',
            postActionRepository: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Beğendim'));
    await tester.pumpAndSettle();

    expect(repository.toggleCalls, 1);
    expect(repository.lastToken, isNull);
    expect(repository.lastReaction, 'love');
    expect(find.text('Emoji tepkisi için giriş yapın.'), findsNothing);
  });

  testWidgets(
    'detail social item keeps one title and description before embed',
    (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      const itemTitle = 'Sosyal Medyada Niğde Gündemi';
      const itemDescription =
          'Niğde gündemine dair sosyal medya paylaşımı ve kısa özeti.';

      await tester.pumpWidget(
        MaterialApp(
          home: NewsDetailScreen(
            articles: [
              _detailArticle(
                detailItems: const [
                  NewsDetailItem(
                    id: 'social-1',
                    type: 'social',
                    title: itemTitle,
                    description: itemDescription,
                    mediaUrl: 'https://x.com/pateez/status/123',
                  ),
                ],
              ),
            ],
            initialIndex: 0,
            postActionRepository: const _DetailPostActionRepository(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text(itemTitle), findsOneWidget);
      expect(find.text(itemDescription), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets('detail poll item does not repeat the poll heading above media', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    const question = 'Niğde’de bundan sonra en acil öncelik sizce ne olmalı?';
    const description =
        'Gümüşler’de yaşanan sel felaketi sonrası Niğde’nin öncelikli odak noktası ne olmalı?';

    await tester.pumpWidget(
      MaterialApp(
        home: NewsDetailScreen(
          articles: [
            _detailArticle(
              detailItems: const [
                NewsDetailItem(
                  id: 'poll-1',
                  type: 'poll',
                  title: question,
                  description: description,
                  pollData: NewsPollData(
                    title: question,
                    description: description,
                    isImagePoll: true,
                    columns: 2,
                    options: [
                      NewsPollOption(
                        id: 'infrastructure',
                        text: 'Altyapı',
                        imageUrl: 'https://example.invalid/altyapi.jpg',
                      ),
                      NewsPollOption(
                        id: 'alarm',
                        text: 'Afet alarmı',
                        imageUrl: 'https://example.invalid/afet.jpg',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          initialIndex: 0,
          postActionRepository: const _DetailPostActionRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(question), findsOneWidget);
    expect(find.text(description), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}

NewsArticle _detailArticle({required List<NewsDetailItem> detailItems}) {
  return NewsArticle(
    id: '123',
    author: const NewsAuthor(
      id: 'publisher-1',
      name: 'Pateez Niğde',
      avatarUrl: 'https://example.invalid/avatar.jpg',
      isOfficial: true,
    ),
    region: 'Niğde',
    category: 'Gündem',
    title: 'Gümüşler’de Sel Acısı, Gebere’de Yeni Proje',
    summary: 'Niğde gündemine dair detaylı haber özeti.',
    imageUrl: 'https://example.invalid/cover.jpg',
    imageAspectRatio: 16 / 9,
    publishedAt: DateTime.utc(2026, 6, 11, 10, 15),
    readMinutes: 3,
    likes: 1,
    dislikes: 0,
    comments: 2,
    shares: 2,
    views: 4,
    saves: 1,
    detailItems: detailItems,
  );
}

class _DetailPostActionRepository extends PostActionRepository {
  const _DetailPostActionRepository();

  @override
  Future<PostActionState> fetchState({required String postId, String? token}) {
    return Future<PostActionState>.value(
      const PostActionState(
        likes: 1,
        dislikes: 0,
        shares: 2,
        views: 4,
        saves: 1,
        liked: false,
        disliked: false,
        saved: false,
        reactions: {'love': 3, 'great': 1},
        userReactions: [],
      ),
    );
  }
}

class _GuestReactionRepository extends PostActionRepository {
  int toggleCalls = 0;
  String? lastToken;
  String? lastReaction;

  @override
  Future<PostActionState> fetchState({required String postId, String? token}) {
    return Future<PostActionState>.value(
      const PostActionState(
        likes: 0,
        dislikes: 0,
        shares: 0,
        views: 0,
        saves: 0,
        liked: false,
        disliked: false,
        saved: false,
        reactions: {},
        userReactions: [],
      ),
    );
  }

  @override
  Future<PostActionState> toggleReaction({
    required String postId,
    String? token,
    required String reaction,
  }) {
    toggleCalls++;
    lastToken = token;
    lastReaction = reaction;
    return Future<PostActionState>.value(
      PostActionState(
        likes: 0,
        dislikes: 0,
        shares: 0,
        views: 0,
        saves: 0,
        liked: false,
        disliked: false,
        saved: false,
        reactions: {reaction: 1},
        userReactions: [reaction],
      ),
    );
  }
}
