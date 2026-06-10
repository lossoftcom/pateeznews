import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pateeznews_admin/frontend/core/mock/home_mock_data.dart';
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
}
