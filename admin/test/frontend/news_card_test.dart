import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pateeznews_admin/frontend/core/mock/home_mock_data.dart';
import 'package:pateeznews_admin/frontend/features/home/presentation/widgets/news_card.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

void main() {
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
    expect(find.byIcon(Symbols.heart_3_line), findsNothing);
    expect(find.byIcon(Symbols.thumb_up_line), findsWidgets);
    expect(find.byIcon(Symbols.thumb_down_line), findsWidgets);
    expect(find.byIcon(Symbols.bookmark_line), findsWidgets);
    expect(find.byIcon(Symbols.bookmark_3_line), findsNothing);

    final sourceText = tester.widget<Text>(find.text('Pateez Ekonomi'));
    expect(sourceText.style?.fontSize, 11.5);

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
}
