import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pateeznews_admin/frontend/features/category/presentation/category_screen.dart';

void main() {
  testWidgets('kategori sayfası masthead, toplam okunma ve akışı gösterir', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CategoryScreen(categoryName: 'Ekonomi', categoryType: 'category'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // Masthead kimliği + üstte toplam okunma
    expect(find.text('KATEGORİ'), findsOneWidget);
    expect(find.text('Ekonomi'), findsWidgets);
    expect(find.textContaining('okunma'), findsOneWidget);
    expect(find.textContaining('haber'), findsWidgets);

    // Yeni bölüm başlığı + sıralama (ana sayfayla aynı widget)
    expect(find.textContaining('Seçtiklerimiz'), findsOneWidget);
    expect(find.text('En yeni'), findsOneWidget);
    expect(find.text('Popüler'), findsOneWidget);

    // Kaldırılanlar
    expect(find.text('TAKİP ET'), findsNothing);
    expect(find.text('Tümü'), findsNothing);
    expect(find.text('Son haberler'), findsNothing);

    expect(tester.takeException(), isNull);
  });

  testWidgets('popüler sıralaması seçilebilir', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CategoryScreen(categoryName: 'Spor', categoryType: 'category'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.text('Popüler'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Popüler'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ilçe için doğru tür etiketi ve toplam okunma gösterilir', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CategoryScreen(categoryName: 'Niğde', categoryType: 'district'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('İLÇE'), findsOneWidget);
    expect(find.textContaining('okunma'), findsOneWidget);
    expect(find.text('Tümü'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
