import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pateeznews_admin/frontend/core/mock/home_mock_data.dart';
import 'package:pateeznews_admin/frontend/features/home/presentation/widgets/featured_card.dart';
import 'package:pateeznews_admin/frontend/features/home/presentation/widgets/featured_slider.dart';
import 'package:pateeznews_admin/frontend/shared/widgets/adaptive_headline.dart';

void main() {
  testWidgets('featured slider image uses full width with natural height', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final item = FeaturedNews(
      id: 'featured-test',
      category: 'Gündem',
      title: 'Manşet görseli kırpılmadan gösterilir',
      summary: 'Görsel genişliği tam dolar, yükseklik görsel oranından gelir.',
      imageUrl: 'https://picsum.photos/seed/pateez-featured-test/1200/600',
      publishedAt: DateTime.utc(2026, 6, 7, 10, 45),
      source: 'Pateeznews',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: FeaturedSlider(items: [item])),
      ),
    );
    await tester.pump();

    final pageViewSize = tester.getSize(find.byType(PageView));
    expect(pageViewSize.width, 390);
    expect(pageViewSize.height, 195);

    final featuredImage = tester.widget<CachedNetworkImage>(
      find.byWidgetPredicate(
        (widget) =>
            widget is CachedNetworkImage && widget.imageUrl == item.imageUrl,
      ),
    );
    expect(featuredImage.fit, BoxFit.contain);
    expect(find.byType(AdaptiveHeadline), findsOneWidget);
    expect(find.text('7 Haziran 2026 Pazar Saat: 13:45'), findsOneWidget);
  });

  testWidgets('featured slider opens from image and title taps', (
    tester,
  ) async {
    final item = FeaturedNews(
      id: 'featured-open-test',
      category: 'Gündem',
      title: 'Manşet detay ekranına açılır',
      summary: 'Görsel veya başlık tıklanınca haber detayı açılır.',
      imageUrl: 'https://picsum.photos/seed/pateez-featured-open/1200/600',
      publishedAt: DateTime.utc(2026, 6, 7, 10, 45),
      source: 'Pateeznews',
    );
    final openedIds = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FeaturedSlider(
            items: [item],
            onOpen: (news) => openedIds.add(news.id),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(FeaturedCard));
    await tester.pump();
    await tester.tap(find.byType(AdaptiveHeadline));
    await tester.pump();

    expect(openedIds, ['featured-open-test', 'featured-open-test']);
  });

  testWidgets('featured slider arrows move between slides', (tester) async {
    final items = [
      FeaturedNews(
        id: 'featured-arrow-1',
        category: 'Gündem',
        title: 'İlk manşet',
        summary: 'İlk manşet özeti.',
        imageUrl: 'https://picsum.photos/seed/pateez-arrow-1/1200/600',
        publishedAt: DateTime.utc(2026, 6, 7, 10, 45),
        source: 'Pateeznews',
      ),
      FeaturedNews(
        id: 'featured-arrow-2',
        category: 'Yaşam',
        title: 'İkinci manşet',
        summary: 'İkinci manşet özeti.',
        imageUrl: 'https://picsum.photos/seed/pateez-arrow-2/1200/600',
        publishedAt: DateTime.utc(2026, 6, 7, 11, 45),
        source: 'Pateeznews',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: FeaturedSlider(items: items)),
      ),
    );
    await tester.pump();

    expect(find.byTooltip('Önceki haber'), findsOneWidget);
    expect(find.byTooltip('Sonraki haber'), findsOneWidget);
    expect(find.text('İlk manşet'), findsOneWidget);

    await tester.tap(find.byTooltip('Sonraki haber'));
    await tester.pumpAndSettle();

    expect(find.text('İkinci manşet'), findsOneWidget);
  });
}
