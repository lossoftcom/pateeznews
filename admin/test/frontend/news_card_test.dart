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
      region: 'TÜRKİYE',
      category: 'EKONOMİ',
      title: 'Merkez Bankası faiz kararını açıkladı',
      summary: 'Politika faizinde değişikliğe gidilmedi.',
      imageUrl: 'https://example.invalid/cover.jpg',
      publishedAt: DateTime(2026, 5, 26, 13),
      readMinutes: 3,
      likes: 1240,
      dislikes: 82,
      comments: 214,
      shares: 96,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: NewsCard(article: article, onTap: () {}),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('TAKİP'), findsNothing);
    expect(find.text('Türkiye  /  Ekonomi'), findsOneWidget);
    expect(find.text('TÜRKİYE  /  EKONOMİ'), findsNothing);
    expect(find.byIcon(Symbols.heart_3_line), findsWidgets);
    expect(find.byIcon(Symbols.bookmark_3_line), findsWidgets);

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

    final coverRect = tester.getRect(
      find.byKey(const ValueKey<String>('news-card-cover-stage')),
    );
    final metaRect = tester.getRect(find.text('Türkiye  /  Ekonomi'));
    final titleRect = tester.getRect(find.text(article.title));

    expect(metaRect.top, greaterThanOrEqualTo(coverRect.top));
    expect(metaRect.bottom, lessThan(coverRect.bottom));
    expect(titleRect.top, greaterThan(coverRect.bottom));
  });
}
