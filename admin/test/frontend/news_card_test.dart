import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pateeznews_admin/frontend/core/mock/home_mock_data.dart';
import 'package:pateeznews_admin/frontend/core/theme/app_typography.dart';
import 'package:pateeznews_admin/frontend/features/account/data/frontend_auth_repository.dart';
import 'package:pateeznews_admin/frontend/features/home/data/news_comments_repository.dart';
import 'package:pateeznews_admin/frontend/features/home/data/post_action_repository.dart';
import 'package:pateeznews_admin/frontend/features/home/presentation/widgets/news_card.dart';
import 'package:pateeznews_admin/frontend/shared/widgets/social_action.dart';
import 'package:pateeznews_admin/frontend/shared/widgets/frontend_toast.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    FrontendToast.dismiss();
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('news card renders cover overlay and below-image content', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final article = NewsArticle(
      id: 'test-news',
      author: const NewsAuthor(
        name: 'Pateez Ekonomi',
        avatarUrl: 'https://example.invalid/avatar.jpg',
        isOfficial: true,
      ),
      region: '',
      category: 'YAŞAM',
      title: 'Merkez Bankası faiz kararını açıkladı',
      summary: 'Politika faizinde değişikliğe gidilmedi.',
      imageUrl: 'https://example.invalid/cover.jpg',
      publishedAt: DateTime.utc(2026, 6, 7, 13, 21),
      readMinutes: 3,
      likes: 1240,
      dislikes: 82,
      comments: 214,
      shares: 96,
      views: 138,
      previewComments: HomeMockData.samplePreviewComments,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: NewsCard(
              article: article,
              categoryTrail: const ['Niğde', 'Yaşam'],
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('TAKİP'), findsNothing);
    expect(find.text('Niğde / Yaşam'), findsOneWidget);
    expect(find.text('YAŞAM'), findsNothing);
    expect(find.text('7 Haziran 2026 Pazar'), findsOneWidget);
    expect(find.byIcon(Symbols.time_fill), findsOneWidget);
    expect(find.text('16:21'), findsOneWidget);
    expect(find.text('3 dk okuma'), findsOneWidget);
    expect(find.text('138 görüntüleme'), findsOneWidget);
    expect(find.text('Yorumunuzu ekleyin...'), findsNothing);
    expect(find.text('Yorumunuzu ekleyin'), findsOneWidget);
    expect(find.text('Ad soyad'), findsOneWidget);
    expect(find.text('E-posta'), findsOneWidget);
    expect(find.text('Gönder'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('news-card-inline-comments')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('news-card-inline-comment-composer')),
      findsOneWidget,
    );
    expect(
      find.text('Konuyu farklı bir açıdan ele almışsınız, kalemine sağlık.'),
      findsOneWidget,
    );
    expect(
      find.text('Veriler net, tarafsız bir özet olmuş. Pateez böyle devam.'),
      findsOneWidget,
    );
    expect(
      find.text('Grafikler özellikle çok aydınlatıcı oldu.'),
      findsOneWidget,
    );
    expect(find.text('24 beğeni'), findsOneWidget);
    expect(find.text('11 beğeni'), findsOneWidget);
    expect(find.text('Yanıtla'), findsWidgets);
    expect(find.byIcon(Symbols.heart_3_line), findsWidgets);
    expect(find.byIcon(Symbols.thumb_up_line), findsWidgets);
    expect(find.byIcon(Symbols.thumb_down_line), findsWidgets);
    expect(find.byIcon(Symbols.bookmark_line), findsWidgets);
    expect(find.byIcon(Symbols.bookmark_3_line), findsNothing);

    final sourceText = tester.widget<Text>(find.text('Pateez Ekonomi'));
    expect(sourceText.style?.fontSize, 13.5);

    // Kapak görseli artık diske cache'lenen CachedNetworkImage (CachedImage
    // sarmalayıcısı üzerinden). Doğru URL ile ve BoxFit.contain ile render
    // edilmeli.
    final coverImage = tester.widget<CachedNetworkImage>(
      find.byWidgetPredicate(
        (widget) =>
            widget is CachedNetworkImage && widget.imageUrl == article.imageUrl,
      ),
    );
    expect(coverImage.fit, BoxFit.contain);

    final titleText = tester.widget<Text>(find.text(article.title));
    expect(titleText.style?.color, const Color(0xFF101820));
    expect(titleText.style?.fontSize, 28);
    expect(titleText.maxLines, isNull);

    final summaryText = tester.widget<Text>(find.text(article.summary));
    expect(summaryText.maxLines, isNull);
    expect(summaryText.overflow, isNull);

    final coverRect = tester.getRect(
      find.byKey(const ValueKey<String>('news-card-cover-stage')),
    );
    final metaRect = tester.getRect(find.text('Niğde / Yaşam'));
    final titleRect = tester.getRect(find.text(article.title));

    expect(metaRect.top, greaterThanOrEqualTo(coverRect.top));
    expect(metaRect.bottom, lessThan(coverRect.bottom));
    expect(titleRect.top, greaterThan(coverRect.bottom));
  });

  testWidgets('news card records read and updates live view count on tap', (
    tester,
  ) async {
    final repository = _ReadTrackingPostActionRepository();
    var opened = false;
    final article = NewsArticle(
      id: '123',
      author: const NewsAuthor(name: 'Pateez Ekonomi', avatarUrl: ''),
      region: '',
      category: 'Ekonomi',
      title: 'Canlı okuma sayısı',
      summary: 'Okuma sayısı canlı güncellenir.',
      imageUrl: 'https://example.invalid/read.jpg',
      publishedAt: DateTime.utc(2026, 6, 10, 10),
      readMinutes: 2,
      likes: 1,
      dislikes: 0,
      comments: 0,
      shares: 0,
      views: 12,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: NewsCard(
              article: article,
              postActionRepository: repository,
              onTap: () => opened = true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('12 görüntüleme'), findsOneWidget);

    await tester.tap(find.byType(NewsCard));
    await tester.pump();

    expect(opened, isTrue);
    expect(repository.calls, 1);
    expect(repository.lastPostId, '123');
    expect(repository.lastSource, 'open_detail');
    expect(find.text('13 görüntüleme'), findsOneWidget);
  });

  testWidgets('guest comment identity is remembered and email is validated', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: NewsCard(article: _guestCommentArticle('123'), onTap: () {}),
          ),
        ),
      ),
    );
    await tester.pump();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Nasip Gün');
    await tester.enterText(fields.at(1), 'yanlis-mail');
    await tester.pump();

    expect(find.text('Mail adresi yanlış'), findsOneWidget);

    await tester.enterText(fields.at(1), 'nasip@example.com');
    await tester.pump();

    expect(find.text('Mail adresi yanlış'), findsNothing);

    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('pateez_guest_comment_name'), 'Nasip Gün');
    expect(
      preferences.getString('pateez_guest_comment_email'),
      'nasip@example.com',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: NewsCard(article: _guestCommentArticle('456'), onTap: () {}),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Nasip Gün'), findsOneWidget);
    expect(find.text('nasip@example.com'), findsOneWidget);
  });

  testWidgets('comment composer inserts emoji from picker', (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: NewsCard(
              article: _guestCommentArticle('123'),
              authState: _signedInState(),
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final commentField = find.byType(TextField);
    expect(commentField, findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('news-card-inline-emoji-panel')),
      findsNothing,
    );

    await tester.tap(find.byIcon(Symbols.emotion_happy_line));
    await tester.pump(const Duration(milliseconds: 220));
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('news-card-inline-emoji-panel')),
      findsOneWidget,
    );
    expect(find.text('😀'), findsWidgets);

    await tester.tap(find.text('😀').first);
    await tester.pump();

    final editable = tester.widget<EditableText>(
      find.descendant(of: commentField, matching: find.byType(EditableText)),
    );
    expect(editable.controller.text, '😀');
  });

  testWidgets('comment composer enforces live api character limit', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: NewsCard(
              article: _guestCommentArticle('123'),
              authState: _signedInState(),
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final commentField = find.byType(TextField);
    expect(commentField, findsOneWidget);

    final textField = tester.widget<TextField>(commentField);
    expect(textField.maxLength, 2000);
    expect(textField.maxLengthEnforcement, MaxLengthEnforcement.enforced);

    await tester.enterText(commentField, 'a' * 2005);
    await tester.pump();

    final editable = tester.widget<EditableText>(
      find.descendant(of: commentField, matching: find.byType(EditableText)),
    );
    expect(editable.controller.text.length, 2000);
    expect(find.text('2000/2000'), findsOneWidget);
  });

  testWidgets('comment composer shows loading state and success toast', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final submitter = Completer<void>();
    final repository = _PendingNewsCommentsRepository(submitter);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: NewsCard(
              article: _guestCommentArticle('123'),
              commentsRepository: repository,
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Nasip Gün');
    await tester.enterText(fields.at(1), 'nasip@example.com');
    await tester.enterText(fields.at(2), 'Evet yorum deniyoruz');
    await tester.pump();

    await tester.tap(find.text('Gönder'));
    await tester.pump(const Duration(milliseconds: 40));

    expect(repository.submitCalls, 1);
    expect(find.text('Gönderiliyor'), findsOneWidget);

    submitter.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 260));

    expect(find.text('Yorum onaya gönderildi.'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2400));
    await tester.pump(const Duration(milliseconds: 180));

    expect(find.text('Yorum onaya gönderildi.'), findsNothing);
  });

  testWidgets('reply target switches composer into reply mode', (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: NewsCard(
              article: _guestCommentArticle(
                '123',
                previewComments: [_ownComment(canDelete: false)],
              ),
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Yanıtla'));
    await tester.pump();

    expect(find.text('Nasip Gün yanıtlanıyor'), findsOneWidget);
    expect(find.text('Yanıtınızı yazın'), findsOneWidget);
    expect(find.text('Ad soyad'), findsOneWidget);
    expect(find.text('E-posta'), findsOneWidget);
  });

  testWidgets('comment preview expands and collapses extra comments', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(390, 1200);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final allComments = [
      _threadedComment(
        id: '1',
        authorName: 'Nasip Gün',
        body: 'İlk ana yorum.',
        replies: [
          _threadedComment(
            id: '11',
            authorName: 'Emre A.',
            body: 'İlk alt yorum.',
          ),
        ],
      ),
      _threadedComment(
        id: '2',
        authorName: 'Ayşe K.',
        body: 'İkinci ana yorum.',
        replies: [
          _threadedComment(
            id: '22',
            authorName: 'Zeynep T.',
            body: 'İkinci alt yorum.',
          ),
        ],
      ),
      _threadedComment(
        id: '3',
        authorName: 'Mehmet B.',
        body: 'Üçüncü ana yorum.',
      ),
    ];
    final repository = _ExpandingNewsCommentsRepository(allComments);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: NewsCard(
              article: _guestCommentArticle(
                '123',
                comments: 3,
                previewComments: allComments.take(2).toList(),
              ),
              commentsRepository: repository,
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('İlk ana yorum.'), findsOneWidget);
    expect(find.text('İkinci ana yorum.'), findsOneWidget);
    expect(find.text('İlk alt yorum.'), findsOneWidget);
    expect(find.text('İkinci alt yorum.'), findsNothing);
    expect(find.text('Üçüncü ana yorum.'), findsNothing);
    expect(find.text('Daha fazla'), findsOneWidget);

    await tester.tap(find.text('Daha fazla'));
    await tester.pump(const Duration(milliseconds: 420));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 420));

    expect(repository.lastLimit, 3);
    expect(find.text('Üçüncü ana yorum.'), findsOneWidget);
    expect(find.text('İkinci alt yorum.'), findsOneWidget);
    expect(find.text('Daha az'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('news-card-comments-more-toggle')),
    );
    await tester.pump(const Duration(milliseconds: 420));

    expect(find.text('Üçüncü ana yorum.'), findsNothing);
    expect(find.text('İkinci alt yorum.'), findsNothing);
    expect(find.text('Daha fazla'), findsOneWidget);
  });

  testWidgets('comment action icon hides and opens full comments', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final allComments = [
      _threadedComment(id: '1', authorName: 'Nasip Gün', body: 'İlk yorum.'),
      _threadedComment(id: '2', authorName: 'Ayşe K.', body: 'İkinci yorum.'),
      _threadedComment(id: '3', authorName: 'Mehmet B.', body: 'Üçüncü yorum.'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: NewsCard(
              article: _guestCommentArticle(
                '123',
                comments: 3,
                previewComments: allComments,
              ),
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('İlk yorum.'), findsOneWidget);
    expect(find.text('Üçüncü yorum.'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('news-card-inline-comment-composer')),
      findsOneWidget,
    );

    final commentAction = find.byWidgetPredicate(
      (widget) => widget is SocialAction && widget.semanticLabel == 'Yorumlar',
    );

    await tester.tap(commentAction);
    await tester.pump(const Duration(milliseconds: 420));

    expect(find.text('İlk yorum.'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('news-card-inline-comment-composer')),
      findsNothing,
    );

    await tester.tap(commentAction);
    await tester.pump(const Duration(milliseconds: 420));

    expect(find.text('İlk yorum.'), findsOneWidget);
    expect(find.text('Üçüncü yorum.'), findsOneWidget);
    expect(find.text('Daha az'), findsOneWidget);
  });

  testWidgets('reply trail supports one nested reply level only', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final root = _threadedComment(
      id: '1',
      authorName: 'Nasip Gün',
      body: 'Ana yorum.',
      replies: [
        _threadedComment(
          id: '2',
          authorName: 'Ali Kemal Gündoğu',
          body: 'Alt yorum.',
          replies: [
            _threadedComment(
              id: '3',
              authorName: 'Zeynep T.',
              body: 'Alt yoruma yanıt.',
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: NewsCard(
              article: _guestCommentArticle(
                '123',
                comments: 3,
                previewComments: [root],
              ),
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Ana yorum.'), findsOneWidget);
    expect(find.text('Alt yorum.'), findsOneWidget);
    expect(find.text('Alt yoruma yanıt.'), findsOneWidget);
    expect(find.text('Yanıtla'), findsNWidgets(2));

    await tester.tap(find.text('Yanıtla').last);
    await tester.pump();

    expect(find.text('Ali Kemal Gündoğu yanıtlanıyor'), findsOneWidget);
    expect(find.text('Yanıtınızı yazın'), findsOneWidget);
  });

  testWidgets('signed in user can delete own comment with loading toast', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final deleter = Completer<List<NewsComment>>();
    final repository = _DeletingNewsCommentsRepository(deleter);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: NewsCard(
              article: _guestCommentArticle(
                '123',
                previewComments: [_ownComment(canDelete: true)],
              ),
              authState: _signedInState(),
              commentsRepository: repository,
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Sil'), findsOneWidget);

    await tester.tap(find.text('Sil'));
    await tester.pump(const Duration(milliseconds: 40));

    expect(repository.deleteCalls, 1);
    expect(find.text('Siliniyor'), findsOneWidget);

    deleter.complete(const []);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 260));

    expect(find.text('Bu benim yorumum.'), findsNothing);
    expect(find.text('Yorum silindi.'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2400));
    await tester.pump(const Duration(milliseconds: 180));

    expect(find.text('Yorum silindi.'), findsNothing);
  });

  testWidgets('news card renders selected social homepage item', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;

    try {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      final article = NewsArticle(
        id: 'social-news',
        author: const NewsAuthor(
          name: 'Pateez Niğde',
          avatarUrl: '',
          isOfficial: true,
        ),
        region: '',
        category: 'Yaşam',
        title: 'Gümüşler’de Sel Acısı, Gebere’de Yeni Proje',
        summary: 'Niğde gündeminden sosyal medya paylaşımı.',
        imageUrl: 'https://example.invalid/cover.jpg',
        publishedAt: DateTime.utc(2026, 6, 9, 16, 24),
        readMinutes: 2,
        likes: 185,
        dislikes: 0,
        comments: 9,
        shares: 12,
        views: 9017,
        socialEmbed: 'https://www.instagram.com/p/test-code/',
        socialSourceUrl: 'https://www.instagram.com/p/test-code/',
        socialPlatform: 'instagram',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: NewsCard(
                article: article,
                categoryTrail: const ['Niğde', 'Yaşam'],
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Pateez Niğde'), findsOneWidget);
      expect(find.text('Niğde / Yaşam'), findsOneWidget);
      expect(find.text('instagram.com/p/test-code'), findsNothing);
      expect(find.text('Instagram gönderisi'), findsOneWidget);
      expect(find.text('Gönderiyi aç'), findsOneWidget);
      expect(find.text(article.title), findsOneWidget);
      expect(find.text(article.summary), findsNothing);

      final stageRect = tester.getRect(
        find.byKey(const ValueKey<String>('news-card-cover-stage')),
      );
      final titleRect = tester.getRect(find.text(article.title));
      expect(stageRect.width, 390);
      expect(titleRect.top, greaterThan(stageRect.top));
      expect(titleRect.bottom, lessThan(stageRect.bottom));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('news card renders selected iframe homepage item', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;

    try {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      const iframe =
          '<iframe src="https://programiz.pro" title="programiz pro website" height="500" width="500"></iframe>';
      final article = NewsArticle(
        id: 'iframe-news',
        author: const NewsAuthor(
          name: 'Pateez Niğde',
          avatarUrl: '',
          isOfficial: true,
        ),
        region: '',
        category: 'Yaşam',
        title: 'Gümüşler Belde Konum Haritası',
        summary: 'Bu özet iframe kartında ayrıca basılmaz.',
        imageUrl: 'https://example.invalid/cover.jpg',
        publishedAt: DateTime.utc(2026, 6, 10, 9, 11),
        readMinutes: 1,
        likes: 12,
        dislikes: 0,
        comments: 1,
        shares: 3,
        views: 240,
        socialEmbed: iframe,
        socialSourceUrl: 'https://programiz.pro',
        socialPlatform: 'link',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: NewsCard(
                article: article,
                categoryTrail: const ['Niğde', 'Yaşam'],
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Pateez Niğde'), findsOneWidget);
      expect(find.text('Niğde / Yaşam'), findsOneWidget);
      expect(find.text('Web içeriği'), findsOneWidget);
      expect(find.text('İçeriği aç'), findsOneWidget);
      expect(find.text('Sosyal medya gönderisi'), findsNothing);
      expect(find.text(article.title), findsOneWidget);
      expect(find.text(article.summary), findsNothing);

      final stageRect = tester.getRect(
        find.byKey(const ValueKey<String>('news-card-cover-stage')),
      );
      final titleRect = tester.getRect(find.text(article.title));
      expect(stageRect.width, 390);
      expect(titleRect.top, greaterThan(stageRect.top));
      expect(titleRect.bottom, lessThan(stageRect.bottom));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('news card renders selected quote homepage item', (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final article = NewsArticle(
      id: 'quote-news',
      author: const NewsAuthor(
        name: 'Pateez Niğde',
        avatarUrl: '',
        isOfficial: true,
      ),
      region: '',
      category: 'Yaşam',
      title: 'Gümüşler’de Sel Acısı, Gebere’de Yeni Proje, OSB’de Yatırım',
      summary: 'Bu özet alıntı kartında ayrıca basılmaz.',
      imageUrl: 'https://example.invalid/cover.jpg',
      publishedAt: DateTime.utc(2026, 6, 9, 16, 24),
      readMinutes: 2,
      likes: 31,
      dislikes: 2,
      comments: 5,
      shares: 7,
      views: 640,
      quoteData: const NewsQuoteData(
        text:
            '“Su tahliye, temizlik ve hasar tespit çalışmaları sürdürülmektedir.”',
        author: 'Vali Nedim Akmeşe’den Açıklama',
        sourceUrl: 'https://example.com/kaynak',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: NewsCard(
              article: article,
              categoryTrail: const ['Niğde', 'Yaşam'],
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Pateez Niğde'), findsOneWidget);
    expect(find.text('Niğde / Yaşam'), findsOneWidget);
    expect(find.text(article.title), findsOneWidget);
    expect(find.text(article.summary), findsNothing);
    expect(
      find.text(
        '“Su tahliye, temizlik ve hasar tespit çalışmaları sürdürülmektedir.”',
      ),
      findsOneWidget,
    );
    expect(find.text('VALİ NEDİM AKMEŞE’DEN AÇIKLAMA'), findsOneWidget);

    final stageRect = tester.getRect(
      find.byKey(const ValueKey<String>('news-card-cover-stage')),
    );
    final titleRect = tester.getRect(find.text(article.title));
    final quoteRect = tester.getRect(
      find.byKey(const ValueKey<String>('news-card-quote-card')),
    );
    final quoteText = tester.widget<Text>(
      find.text(
        '“Su tahliye, temizlik ve hasar tespit çalışmaları sürdürülmektedir.”',
      ),
    );

    expect(stageRect.width, 390);
    expect(titleRect.top, greaterThan(stageRect.top));
    expect(quoteRect.top, greaterThan(titleRect.bottom));
    expect(quoteText.maxLines, isNull);
    expect(quoteText.overflow, isNull);
    expect(quoteText.style?.fontStyle, FontStyle.italic);
    expect(quoteText.style?.fontSize, 22);
  });

  testWidgets('news card renders selected review homepage item', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final article = NewsArticle(
      id: 'review-news',
      author: const NewsAuthor(
        name: 'Pateez Niğde',
        avatarUrl: '',
        isOfficial: true,
      ),
      region: '',
      category: 'Yaşam',
      title: 'Bu başlık review kartında ayrıca basılmaz',
      summary: 'Niğde son 15 günde hem afet sınavı hem yatırım gündemi yaşadı.',
      imageUrl: 'https://example.invalid/cover.jpg',
      publishedAt: DateTime.utc(2026, 6, 9, 16, 24),
      readMinutes: 3,
      likes: 15,
      dislikes: 4,
      comments: 11,
      shares: 7,
      views: 1204,
      reviewData: const NewsReviewData(
        productName: 'Niğde şehir performansı',
        productImage: 'https://example.invalid/review.jpg',
        score: 82,
        pros: [
          'Afet sonrası hızlı saha müdahalesi',
          'Gebere projesiyle sosyal potansiyelin artması',
        ],
        cons: ['Yağmur suyu altyapısı için önleyici plan ihtiyacı'],
        breakdown: [
          NewsReviewCriterion(label: 'Afet müdahale refleksi', score: 86),
          NewsReviewCriterion(label: 'Ekonomik yatırım gündemi', score: 88),
        ],
        verdict:
            'Niğde son 15 günde hem acı bir afet sınavı hem de hizmet gündemi yaşadı.',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: NewsCard(
              article: article,
              categoryTrail: const ['Niğde', 'Yaşam'],
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Pateez Niğde'), findsOneWidget);
    expect(find.text('Niğde / Yaşam'), findsOneWidget);
    expect(find.text('İNCELEME'), findsOneWidget);
    expect(find.text('Niğde şehir performansı'), findsOneWidget);
    expect(find.text('82'), findsOneWidget);
    expect(find.text('PUAN'), findsOneWidget);
    expect(find.text('ARTILAR'), findsOneWidget);
    expect(find.text('EKSİLER'), findsOneWidget);
    expect(find.text('DETAYLI PUANLAMA'), findsOneWidget);
    expect(find.text('SONUÇ'), findsOneWidget);
    expect(find.text(article.summary), findsOneWidget);
    expect(
      find.text('Bu başlık review kartında ayrıca basılmaz'),
      findsNothing,
    );
    expect(find.text('Afet sonrası hızlı saha müdahalesi'), findsOneWidget);
    expect(
      find.text('Yağmur suyu altyapısı için önleyici plan ihtiyacı'),
      findsOneWidget,
    );
    expect(find.text('Afet müdahale refleksi'), findsOneWidget);
    expect(find.text('86/100'), findsOneWidget);
    expect(find.textContaining('hem acı bir afet sınavı'), findsOneWidget);

    final stageRect = tester.getRect(
      find.byKey(const ValueKey<String>('news-card-cover-stage')),
    );
    final imageRect = tester.getRect(
      find.byKey(const ValueKey<String>('news-card-review-image')),
    );
    final scoreRect = tester.getRect(
      find.byKey(const ValueKey<String>('news-card-review-score')),
    );
    final reviewTitleRect = tester.getRect(
      find.text('Niğde şehir performansı'),
    );
    final verdictRect = tester.getRect(find.text('SONUÇ'));
    expect(stageRect.width, 390);
    expect(reviewTitleRect.bottom, lessThan(imageRect.top));
    expect(scoreRect.right, lessThanOrEqualTo(imageRect.right));
    expect(scoreRect.bottom, lessThanOrEqualTo(imageRect.bottom));
    expect(scoreRect.left, greaterThan(imageRect.center.dx));
    expect(scoreRect.top, greaterThan(imageRect.center.dy));
    expect(verdictRect.top, greaterThan(stageRect.top));

    final reviewTitleText = tester.widget<Text>(
      find.text('Niğde şehir performansı'),
    );
    expect(
      reviewTitleText.style?.fontSize,
      AppTypography.mobileNewsCardTitle.fontSize,
    );

    final proText = tester.widget<Text>(
      find.text('Afet sonrası hızlı saha müdahalesi'),
    );
    final conText = tester.widget<Text>(
      find.text('Yağmur suyu altyapısı için önleyici plan ihtiyacı'),
    );
    expect(proText.maxLines, isNull);
    expect(proText.overflow, isNull);
    expect(conText.maxLines, isNull);
    expect(conText.overflow, isNull);
  });

  testWidgets('news card renders selected poll homepage item and vote result', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final article = NewsArticle(
      id: 'poll-news',
      author: const NewsAuthor(
        name: 'Pateez Niğde',
        avatarUrl: '',
        isOfficial: true,
      ),
      region: '',
      category: 'Yaşam',
      title: 'Bu başlık anket kartında ayrıca basılmaz',
      summary: 'Anket açıklaması kendi bloğunda gösterilir.',
      imageUrl: 'https://example.invalid/poll-cover.jpg',
      publishedAt: DateTime.utc(2026, 6, 9, 16, 24),
      readMinutes: 2,
      likes: 22,
      dislikes: 1,
      comments: 4,
      shares: 6,
      views: 380,
      pollData: const NewsPollData(
        title: 'Niğde’de bundan sonra en acil öncelik sizce ne olmalı?',
        description: 'Gümüşler’de yaşanan sel felaketi sonrası okur önceliği.',
        totalVotes: 3,
        options: [
          NewsPollOption(
            id: 'poll-a',
            text: 'Afet hazırlığı ve sel altyapısı',
            votes: 2,
          ),
          NewsPollOption(
            id: 'poll-b',
            text: 'Yol, yağmur suyu ve mahalle altyapısı',
            votes: 1,
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: NewsCard(
              article: article,
              categoryTrail: const ['Niğde', 'Yaşam'],
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Pateez Niğde'), findsOneWidget);
    expect(find.text('Niğde / Yaşam'), findsOneWidget);
    expect(find.text('Anket'), findsWidgets);
    expect(find.text(article.pollData!.title), findsOneWidget);
    expect(find.text(article.pollData!.description), findsOneWidget);
    expect(find.text('Afet hazırlığı ve sel altyapısı'), findsOneWidget);
    expect(find.text('Yol, yağmur suyu ve mahalle altyapısı'), findsOneWidget);
    expect(find.text('3 katılımcı'), findsOneWidget);
    expect(
      find.text('Bu başlık anket kartında ayrıca basılmaz'),
      findsOneWidget,
    );

    await tester.tap(find.text('Afet hazırlığı ve sel altyapısı'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));

    expect(find.text('%75'), findsOneWidget);
    expect(find.text('3 oy'), findsOneWidget);
    expect(find.text('4 katılımcı'), findsOneWidget);
    expect(find.text('Oyun alındı'), findsOneWidget);

    final stageRect = tester.getRect(
      find.byKey(const ValueKey<String>('news-card-cover-stage')),
    );
    final questionRect = tester.getRect(find.text(article.pollData!.title));
    expect(stageRect.width, 390);
    expect(questionRect.top, greaterThan(stageRect.top));
  });

  testWidgets('news card renders selected VS homepage item and vote result', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final article = NewsArticle(
      id: 'vs-news',
      author: const NewsAuthor(
        name: 'Pateez Niğde',
        avatarUrl: '',
        isOfficial: true,
      ),
      region: '',
      category: 'Yaşam',
      title: 'Bu başlık vs kartında header altında olsun',
      summary: 'Haberin gerçek alt başlığı burada görünür.',
      imageUrl: 'https://example.invalid/vs-cover.jpg',
      publishedAt: DateTime.utc(2026, 6, 9, 16, 24),
      readMinutes: 2,
      likes: 22,
      dislikes: 1,
      comments: 4,
      shares: 6,
      views: 380,
      vsData: const NewsVsData(
        title: 'Niğde’de öncelik hangisi olmalı?',
        description: 'Düello item açıklaması burada görünür.',
        options: [
          NewsVsOption(
            id: 'vs-left',
            text: 'Afetlere dayanıklı altyapı',
            imageUrl: 'https://example.invalid/vs-left.jpg',
          ),
          NewsVsOption(
            id: 'vs-right',
            text: 'Sosyal yaşam ve yatırım projeleri',
            imageUrl: 'https://example.invalid/vs-right.jpg',
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: NewsCard(
              article: article,
              categoryTrail: const ['Niğde', 'Yaşam'],
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Pateez Niğde'), findsOneWidget);
    expect(find.text('Niğde / Yaşam'), findsOneWidget);
    expect(find.text('Düello'), findsOneWidget);
    expect(find.text(article.title), findsOneWidget);
    expect(find.text(article.summary), findsOneWidget);
    expect(find.text(article.vsData!.title), findsOneWidget);
    expect(find.text(article.vsData!.description), findsOneWidget);
    expect(find.text('Tıkla Oy\nKullan'), findsNWidgets(2));
    expect(find.text('Afetlere dayanıklı altyapı'), findsOneWidget);
    expect(find.text('Sosyal yaşam ve yatırım projeleri'), findsOneWidget);
    expect(find.text('VS'), findsOneWidget);
    expect(find.text('0 oy verildi'), findsOneWidget);
    expect(find.text('Tarafını seç'), findsOneWidget);

    final coverImage = tester.widget<CachedNetworkImage>(
      find.byWidgetPredicate(
        (widget) =>
            widget is CachedNetworkImage && widget.imageUrl == article.imageUrl,
      ),
    );
    expect(coverImage.fit, BoxFit.contain);

    final leftImage = tester.widget<CachedNetworkImage>(
      find.byWidgetPredicate(
        (widget) =>
            widget is CachedNetworkImage &&
            widget.imageUrl == article.vsData!.options.first.imageUrl,
      ),
    );
    expect(leftImage.fit, BoxFit.contain);

    final arenaRect = tester.getRect(
      find.byKey(const ValueKey<String>('news-card-vs-arena')),
    );
    expect(arenaRect.width, 362);
    expect(arenaRect.height, 181);

    await tester.tap(find.text('Afetlere dayanıklı altyapı'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));

    expect(find.text('100%'), findsOneWidget);
    expect(find.text('1 oy'), findsOneWidget);
    expect(find.text('1 oy verildi'), findsOneWidget);
    expect(find.text('Oyun alındı'), findsOneWidget);

    final stageRect = tester.getRect(
      find.byKey(const ValueKey<String>('news-card-cover-stage')),
    );
    final titleRect = tester.getRect(find.text(article.title));
    final vsTitleRect = tester.getRect(find.text(article.vsData!.title));
    expect(stageRect.width, 390);
    expect(titleRect.top, greaterThan(stageRect.top));
    expect(vsTitleRect.top, greaterThan(titleRect.bottom));
  });
}

NewsArticle _guestCommentArticle(
  String id, {
  int comments = 0,
  List<NewsComment> previewComments = const [],
}) {
  return NewsArticle(
    id: id,
    author: const NewsAuthor(
      name: 'Pateez Niğde',
      avatarUrl: 'https://example.invalid/avatar.jpg',
      isOfficial: true,
    ),
    region: '',
    category: 'YAŞAM',
    title: 'Niğde yorum testi',
    summary: 'Kısa özet.',
    imageUrl: 'https://example.invalid/cover.jpg',
    publishedAt: DateTime.utc(2026, 6, 10, 10),
    readMinutes: 1,
    likes: 0,
    dislikes: 0,
    comments: comments,
    shares: 0,
    previewComments: previewComments,
  );
}

NewsComment _threadedComment({
  required String id,
  required String authorName,
  required String body,
  List<NewsComment> replies = const [],
}) {
  return NewsComment(
    id: id,
    author: NewsAuthor(name: authorName, avatarUrl: ''),
    body: body,
    publishedAt: DateTime.utc(2026, 6, 10, 10),
    likes: 0,
    replies: replies,
  );
}

NewsComment _ownComment({required bool canDelete}) {
  return NewsComment(
    id: '77',
    author: const NewsAuthor(
      name: 'Nasip Gün',
      avatarUrl: '',
      isVerified: true,
    ),
    body: 'Bu benim yorumum.',
    publishedAt: DateTime.utc(2026, 6, 10, 10, 20),
    likes: 0,
    canDelete: canDelete,
  );
}

FrontendAuthState _signedInState() {
  return const FrontendAuthState(
    session: FrontendAuthSession(
      accessToken: 'token-123',
      tokenType: 'bearer',
      expiresAt: 4102444800,
      user: FrontendAuthUser(
        id: 'user-1',
        email: 'nasip@example.com',
        userMetadata: {},
      ),
    ),
    profile: FrontendProfile(
      id: 'user-1',
      username: 'nasip',
      fullName: 'Nasip Gün',
      avatarUrl: '',
      coverUrl: '',
      role: 'user',
      email: 'nasip@example.com',
    ),
  );
}

class _ReadTrackingPostActionRepository extends PostActionRepository {
  int calls = 0;
  String? lastPostId;
  String? lastSource;

  @override
  Future<PostActionState> recordView({
    required String postId,
    String? token,
    String source = 'read',
  }) async {
    calls += 1;
    lastPostId = postId;
    lastSource = source;
    return const PostActionState(
      likes: 1,
      dislikes: 0,
      shares: 0,
      views: 13,
      saves: 0,
      liked: false,
      disliked: false,
      saved: false,
    );
  }
}

class _PendingNewsCommentsRepository extends NewsCommentsRepository {
  _PendingNewsCommentsRepository(this.submitter);

  final Completer<void> submitter;
  int submitCalls = 0;

  @override
  Future<void> submitComment({
    required String postId,
    required String content,
    String? token,
    String? guestName,
    String? guestEmail,
    String? parentId,
  }) {
    submitCalls += 1;
    return submitter.future;
  }

  @override
  Future<List<NewsComment>> fetchComments({
    required String postId,
    String? token,
    int limit = 2,
  }) async {
    return const [];
  }
}

class _ExpandingNewsCommentsRepository extends NewsCommentsRepository {
  _ExpandingNewsCommentsRepository(this.comments);

  final List<NewsComment> comments;
  int? lastLimit;

  @override
  Future<List<NewsComment>> fetchComments({
    required String postId,
    String? token,
    int limit = 2,
  }) async {
    lastLimit = limit;
    return comments.take(limit).toList();
  }
}

class _DeletingNewsCommentsRepository extends NewsCommentsRepository {
  _DeletingNewsCommentsRepository(this.deleter);

  final Completer<List<NewsComment>> deleter;
  int deleteCalls = 0;

  @override
  Future<List<NewsComment>> deleteComment({
    required String postId,
    required String commentId,
    required String token,
    int limit = 2,
  }) {
    deleteCalls += 1;
    expect(postId, '123');
    expect(commentId, '77');
    expect(token, 'token-123');
    return deleter.future;
  }
}
