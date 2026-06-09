import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pateeznews_admin/frontend/features/home/presentation/widgets/feed_filter_tabs.dart';
import 'package:pateeznews_admin/frontend/features/home/presentation/widgets/section_header.dart';

void main() {
  testWidgets('home section title fits on narrow mobile width', (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(320, 240);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SectionHeader(
            title: 'Senin İçin',
            accent: 'Seçtiklerimiz',
            trailing: FeedFilterTabs(
              filter: FeedFilter.latest,
              onChange: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText &&
            widget.text.toPlainText() == 'Senin İçin Seçtiklerimiz',
      ),
      findsOneWidget,
    );
    expect(find.byType(FittedBox), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
