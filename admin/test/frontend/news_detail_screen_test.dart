import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pateeznews_admin/frontend/core/mock/home_mock_data.dart';
import 'package:pateeznews_admin/frontend/features/home/data/post_action_repository.dart';
import 'package:pateeznews_admin/frontend/features/home/presentation/widgets/news_card.dart';
import 'package:pateeznews_admin/frontend/features/news_detail/presentation/news_detail_screen.dart';
import 'package:pateeznews_admin/frontend/features/news_detail/presentation/widgets/detail_quiz.dart';
import 'package:pateeznews_admin/frontend/features/news_detail/presentation/widgets/detail_reactions.dart';
import 'package:pateeznews_admin/frontend/shared/widgets/cached_image.dart';
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
    final actions = _RecordingPostActionRepository();

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
                    totalVotes: 3,
                    options: [
                      NewsPollOption(
                        id: 'infrastructure',
                        text: 'Altyapı',
                        imageUrl: 'https://example.invalid/altyapi.jpg',
                        votes: 2,
                      ),
                      NewsPollOption(
                        id: 'alarm',
                        text: 'Afet alarmı',
                        imageUrl: 'https://example.invalid/afet.jpg',
                        votes: 1,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          initialIndex: 0,
          postActionRepository: actions,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(question), findsOneWidget);
    expect(find.text(description), findsOneWidget);
    expect(
      find.text('Sonuçları görmek için bir seçeneğe oy ver'),
      findsOneWidget,
    );
    expect(find.text('%75'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is CachedImage &&
            widget.url == 'https://example.invalid/altyapi.jpg' &&
            widget.fit == BoxFit.contain,
      ),
      findsOneWidget,
    );

    final infrastructureOption = find.byKey(
      const ValueKey('detail-poll-option-infrastructure'),
    );
    await tester.ensureVisible(infrastructureOption);
    await tester.pumpAndSettle();
    await tester.tap(infrastructureOption);
    await tester.pumpAndSettle();

    expect(find.text('Sonuçlar oyunla birlikte açıldı'), findsOneWidget);
    expect(find.text('%75'), findsOneWidget);
    expect(find.text('%25'), findsOneWidget);
    expect(actions.recordedSources, ['poll_vote']);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('detail toc renders hierarchy and jumps to content sections', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: NewsDetailScreen(
          articles: [
            _detailArticle(
              detailItems: const [
                NewsDetailItem(
                  id: 'toc-1',
                  type: 'toc',
                  title: 'Çamardı rehberi',
                  description: 'Başlıklara dokunarak ilgili bölüme geç.',
                  tocData: NewsTocData(
                    title: 'İçindekiler',
                    level1Style: 'decimal-leading-zero',
                    level2Style: 'lower-alpha',
                    showLevel1InText: true,
                    items: [
                      NewsTocItem(
                        id: 'intro',
                        title: 'Giriş',
                        content: 'Çamardı için kısa giriş ve genel bağlam.',
                        orderNumber: 1,
                      ),
                      NewsTocItem(
                        id: 'route',
                        title: 'Demirkazık rotası',
                        parentId: 'intro',
                        imageUrl: 'https://example.invalid/route.jpg',
                        imageDescription: 'Demirkazık manzarası',
                        content:
                            'Rota ve ulaşım bilgileri bu bölümde yer alır.',
                        orderNumber: 2,
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

    await tester.ensureVisible(find.text('İçindekiler').first);
    await tester.pumpAndSettle();

    expect(find.text('Çamardı rehberi'), findsOneWidget);
    expect(
      find.text('Başlıklara dokunarak ilgili bölüme geç.'),
      findsOneWidget,
    );
    expect(find.text('İçindekiler'), findsOneWidget);
    expect(find.text('01'), findsWidgets);
    expect(find.text('b'), findsOneWidget);
    expect(find.text('Bölümler'), findsOneWidget);
    expect(find.text('01 Giriş'), findsOneWidget);
    expect(find.text('Demirkazık rotası'), findsWidgets);
    expect(
      find.text('Rota ve ulaşım bilgileri bu bölümde yer alır.'),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is CachedImage &&
            widget.url == 'https://example.invalid/route.jpg' &&
            widget.fit == BoxFit.contain,
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Demirkazık rotası').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 620));

    expect(find.text('Konumlandı'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('detail quiz reveals answers after tap and result last', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: NewsDetailScreen(
          articles: [
            _detailArticle(
              detailItems: const [
                NewsDetailItem(
                  id: 'quiz-1',
                  type: 'quiz',
                  title: 'Gümüşler’de Sel Acısı, Gebere’de Yeni Proje',
                  description: 'Niğde gündemine dair detaylı haber özeti.',
                  quizData: NewsQuizData(
                    quizType: 'trivia',
                    questions: [
                      NewsQuizQuestion(
                        id: 'q1',
                        title: 'Gümüşler’de yaşanan afet neydi?',
                        imageUrl: 'https://example.invalid/question.jpg',
                        description: 'Haberde geçen ana afet başlığını seç.',
                        answers: [
                          NewsQuizAnswer(
                            id: 'a1',
                            text: 'Sel felaketi',
                            isCorrect: true,
                            explanation:
                                'Gümüşler’de haberin ana gündemi sel felaketiydi.',
                          ),
                          NewsQuizAnswer(id: 'a2', text: 'Orman yangını'),
                        ],
                      ),
                      NewsQuizQuestion(
                        id: 'q2',
                        title: 'Gebere’de öne çıkan başlık hangisiydi?',
                        answers: [
                          NewsQuizAnswer(
                            id: 'a3',
                            text: 'Mesire alanı projesi',
                            isCorrect: true,
                          ),
                          NewsQuizAnswer(
                            id: 'a4',
                            text: 'Spor salonu yenilemesi',
                          ),
                        ],
                      ),
                    ],
                    results: [
                      NewsQuizResult(
                        id: 'low',
                        title: 'Gündemi yeni takip ediyorsun',
                        imageUrl: 'https://example.invalid/result-low.jpg',
                        description: 'Haberin ana başlıklarını tekrar oku.',
                        minScore: 0,
                        maxScore: 1,
                      ),
                      NewsQuizResult(
                        id: 'high',
                        title: 'Gündeme hakimsin',
                        description: 'Niğde gündemindeki detayları yakaladın.',
                        minScore: 2,
                        maxScore: 2,
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

    expect(find.text('Sonuç'), findsOneWidget);
    expect(find.text('Gündemi yeni takip ediyorsun'), findsNothing);
    expect(find.text('Gündeme hakimsin'), findsNothing);
    expect(find.text('Sorular'), findsOneWidget);
    expect(find.text('Gümüşler’de yaşanan afet neydi?'), findsOneWidget);
    expect(find.text('Gebere’de öne çıkan başlık hangisiydi?'), findsOneWidget);
    expect(find.text('Sel felaketi'), findsOneWidget);
    expect(find.text('Orman yangını'), findsOneWidget);
    expect(find.text('Mesire alanı projesi'), findsOneWidget);
    expect(find.text('Spor salonu yenilemesi'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is CachedImage &&
            widget.url == 'https://example.invalid/question.jpg' &&
            widget.fit == BoxFit.contain,
      ),
      findsOneWidget,
    );
    expect(find.text('Doğru cevap'), findsNothing);
    expect(
      find.text('Gümüşler’de haberin ana gündemi sel felaketiydi.'),
      findsNothing,
    );

    await tester.scrollUntilVisible(
      find.text('Orman yangını'),
      140,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 120));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Orman yangını'));
    await tester.pumpAndSettle();

    expect(find.text('Doğru cevap'), findsOneWidget);
    expect(
      find.text('Gümüşler’de haberin ana gündemi sel felaketiydi.'),
      findsOneWidget,
    );
    expect(find.text('Gündemi yeni takip ediyorsun'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Mesire alanı projesi'),
      140,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 120));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mesire alanı projesi'));
    await tester.pumpAndSettle();

    expect(find.text('Sonucun'), findsOneWidget);
    expect(find.text('Gündemi yeni takip ediyorsun'), findsOneWidget);
    expect(find.text('Gündeme hakimsin'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is CachedImage &&
            widget.url == 'https://example.invalid/result-low.jpg' &&
            widget.fit == BoxFit.contain,
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('image answer grids keep admin columns and contain images', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    Future<void> pumpQuiz(String layout, List<NewsQuizAnswer> answers) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: DetailQuizBlock(
                  title: 'Resimli cevap testi',
                  description: 'Admin cevap formatı mobile detailde korunur.',
                  data: NewsQuizData(
                    quizType: 'personality',
                    questions: [
                      NewsQuizQuestion(
                        id: 'q-image',
                        title: 'Çamardı için hangi rota sana yakın?',
                        layout: layout,
                        answers: answers,
                      ),
                    ],
                    results: const [
                      NewsQuizResult(id: 'r1', title: 'Rota hazır'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    final answers = [
      const NewsQuizAnswer(
        id: 'a1',
        text: 'Çukurbağ tarafında hazırlık yapıp rotayı düşünürüm.',
        imageUrl: 'https://example.invalid/a1.jpg',
      ),
      const NewsQuizAnswer(
        id: 'a2',
        text: 'Demirkazık Köyü ve zirve hattını görmek isterim.',
        imageUrl: 'https://example.invalid/a2.jpg',
      ),
      const NewsQuizAnswer(
        id: 'a3',
        text: 'Celaller tarafında eski maden hikayesini kurcalarım.',
        imageUrl: 'https://example.invalid/a3.jpg',
      ),
      const NewsQuizAnswer(
        id: 'a4',
        text: 'Kavlaktepe Yeraltı Şehri tünellerini anlamaya çalışırım.',
        imageUrl: 'https://example.invalid/a4.jpg',
      ),
    ];

    await pumpQuiz('grid3', answers);

    final grid3First = _cachedQuizImage('https://example.invalid/a1.jpg');
    final grid3Second = _cachedQuizImage('https://example.invalid/a2.jpg');
    final grid3Third = _cachedQuizImage('https://example.invalid/a3.jpg');
    final grid3Fourth = _cachedQuizImage('https://example.invalid/a4.jpg');
    expect(grid3First, findsOneWidget);
    expect(grid3Second, findsOneWidget);
    expect(grid3Third, findsOneWidget);
    expect(grid3Fourth, findsOneWidget);
    expect(
      (tester.getTopLeft(grid3First).dy - tester.getTopLeft(grid3Third).dy)
          .abs(),
      lessThan(1),
    );
    expect(
      tester.getTopLeft(grid3First).dx,
      lessThan(tester.getTopLeft(grid3Second).dx),
    );
    expect(
      tester.getTopLeft(grid3Second).dx,
      lessThan(tester.getTopLeft(grid3Third).dx),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('quiz-answer-tile-a1'))).height,
      tester.getSize(find.byKey(const ValueKey('quiz-answer-tile-a4'))).height,
    );
    expect(
      tester.getTopLeft(find.text('A')).dx,
      greaterThan(tester.getTopLeft(grid3First).dx),
    );
    expect(
      tester.getTopLeft(find.text('A')).dy,
      greaterThan(tester.getTopLeft(grid3First).dy),
    );

    await pumpQuiz('grid2', answers.take(2).toList(growable: false));

    final grid2First = _cachedQuizImage('https://example.invalid/a1.jpg');
    final grid2Second = _cachedQuizImage('https://example.invalid/a2.jpg');
    expect(grid2First, findsOneWidget);
    expect(grid2Second, findsOneWidget);
    expect(
      (tester.getTopLeft(grid2First).dy - tester.getTopLeft(grid2Second).dy)
          .abs(),
      lessThan(1),
    );
    expect(
      tester.getTopLeft(grid2First).dx,
      lessThan(tester.getTopLeft(grid2Second).dx),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('quiz-answer-tile-a1'))).height,
      tester.getSize(find.byKey(const ValueKey('quiz-answer-tile-a2'))).height,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'quiz missing-question teaser jumps back and result autoscrolls',
    (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(390, 520);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: DetailQuizBlock(
                  title: 'Atlanan soru testi',
                  description: 'Eksik cevap kaldığında yönlendirme görünür.',
                  data: NewsQuizData(
                    quizType: 'trivia',
                    questions: const [
                      NewsQuizQuestion(
                        id: 'q1',
                        title: 'İlk soru',
                        answers: [
                          NewsQuizAnswer(
                            id: 'q1-a1',
                            text: 'İlk doğru',
                            isCorrect: true,
                          ),
                          NewsQuizAnswer(id: 'q1-a2', text: 'İlk yanlış'),
                        ],
                      ),
                      NewsQuizQuestion(
                        id: 'q2',
                        title: 'İkinci soru',
                        answers: [
                          NewsQuizAnswer(
                            id: 'q2-a1',
                            text: 'İkinci doğru',
                            isCorrect: true,
                          ),
                          NewsQuizAnswer(id: 'q2-a2', text: 'İkinci yanlış'),
                        ],
                      ),
                      NewsQuizQuestion(
                        id: 'q3',
                        title: 'Üçüncü soru',
                        answers: [
                          NewsQuizAnswer(
                            id: 'q3-a1',
                            text: 'Üçüncü doğru',
                            isCorrect: true,
                          ),
                          NewsQuizAnswer(id: 'q3-a2', text: 'Üçüncü yanlış'),
                        ],
                      ),
                    ],
                    results: const [
                      NewsQuizResult(
                        id: 'done',
                        title: 'Test tamamlandı',
                        description: 'Bütün sorular tamamlandı.',
                        minScore: 0,
                        maxScore: 3,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('İkinci doğru'),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('İkinci doğru'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('2 sorunuz kaldı'),
        160,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('2 sorunuz kaldı'), findsOneWidget);
      expect(find.text('Test tamamlandı'), findsNothing);

      await tester.tap(find.text('Eksik soruya git'));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('İlk soru')).dy,
        inInclusiveRange(0, 260),
      );

      await tester.tap(find.text('İlk doğru'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Üçüncü doğru'),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Üçüncü doğru'));
      await tester.pumpAndSettle();

      expect(find.text('Sonucun'), findsOneWidget);
      expect(find.text('Test tamamlandı'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('detail uses explicit category trail from article data', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: NewsDetailScreen(
          articles: [
            _detailArticle(
              category: 'Testler',
              categoryTrail: const ['Niğde', 'Çamardı', 'Testler'],
              detailItems: const [],
            ),
          ],
          initialIndex: 0,
          postActionRepository: const _DetailPostActionRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Niğde / Çamardı / Testler'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}

Finder _cachedQuizImage(String url) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is CachedImage &&
        widget.url == url &&
        widget.fit == BoxFit.contain,
  );
}

NewsArticle _detailArticle({
  required List<NewsDetailItem> detailItems,
  String category = 'Gündem',
  List<String> categoryTrail = const [],
}) {
  return NewsArticle(
    id: '123',
    author: const NewsAuthor(
      id: 'publisher-1',
      name: 'Pateez Niğde',
      avatarUrl: 'https://example.invalid/avatar.jpg',
      isOfficial: true,
    ),
    region: 'Niğde',
    category: category,
    categoryTrail: categoryTrail,
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

class _RecordingPostActionRepository extends _DetailPostActionRepository {
  final List<String> recordedSources = [];

  @override
  Future<PostActionState> recordView({
    required String postId,
    String? token,
    String source = 'read',
  }) {
    recordedSources.add(source);
    return fetchState(postId: postId, token: token);
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
