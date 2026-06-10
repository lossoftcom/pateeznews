import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pateeznews_admin/frontend/core/mock/home_mock_data.dart';
import 'package:pateeznews_admin/frontend/features/category/data/category_repository.dart';
import 'package:pateeznews_admin/frontend/features/category/presentation/category_screen.dart';

void main() {
  final categoryData = CategoryNewsData(
    items: HomeMockData.feed.take(4).toList(growable: false),
    total: 10,
    totalViews: 4800,
  );

  testWidgets('kategori sayfası masthead, toplam okunma ve akışı gösterir', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CategoryScreen(
          categoryName: 'Ekonomi',
          categoryType: 'category',
          categoryRepository: _FakeCategoryRepository(categoryData),
        ),
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
      MaterialApp(
        home: CategoryScreen(
          categoryName: 'Spor',
          categoryType: 'category',
          categoryRepository: _FakeCategoryRepository(categoryData),
        ),
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
      MaterialApp(
        home: CategoryScreen(
          categoryName: 'Niğde',
          categoryType: 'district',
          categoryRepository: _FakeCategoryRepository(categoryData),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('İLÇE'), findsOneWidget);
    expect(find.textContaining('okunma'), findsOneWidget);
    expect(find.text('Tümü'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('trend sayfası canlı sıralama üst şeridini gösterir', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CategoryScreen(
          categoryName: 'Haftanın En Çok Okunanları',
          categoryType: 'trends',
          categoryValue: 'weekly_reads',
          categoryRepository: _FakeCategoryRepository(categoryData),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('TREND'), findsOneWidget);
    expect(find.text('Canlı sıralama'), findsOneWidget);
    expect(find.text('Son 7 gün'), findsOneWidget);
    expect(find.text('Okunma odaklı'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeCategoryRepository extends CategoryRepository {
  const _FakeCategoryRepository(this.data);

  final CategoryNewsData data;

  @override
  Future<CategoryNewsData> fetchCategory({
    required String category,
    String type = 'category',
    String value = '',
    String lang = 'tr',
    int limit = 16,
    int offset = 0,
    String? token,
  }) async {
    return data;
  }
}
