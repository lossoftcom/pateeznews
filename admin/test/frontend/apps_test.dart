import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pateeznews_admin/frontend/features/apps/data/app_item.dart';
import 'package:pateeznews_admin/frontend/features/apps/presentation/app_feature_screen.dart';
import 'package:pateeznews_admin/frontend/features/apps/presentation/apps_sheet.dart';
import 'package:pateeznews_admin/frontend/features/shell/presentation/shell_screen.dart';

void main() {
  testWidgets('AppsSheet öğeleri gösterir ve seçim callback çalışır', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    AppItem? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppsSheet(
            items: AppItems.all,
            onSelect: (item) => selected = item,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(AppItems.all.take(3).map((item) => item.id), [
      'nobetci-eczane',
      'etkinlik',
      'duyurular',
    ]);
    final duyuruIndex = AppItems.all.indexWhere(
      (item) => item.id == 'duyurular',
    );
    expect(AppItems.all[duyuruIndex + 1].id, 'olum-ilanlari');
    expect(find.text('Uygulamalar'), findsOneWidget);
    expect(find.text('Nöbetçi Eczane'), findsOneWidget);
    expect(find.text('Etkinlik'), findsWidgets);
    expect(find.text('Duyurular'), findsOneWidget);
    expect(find.text('Hava Durumu'), findsOneWidget);
    expect(find.text('Döviz & Altın'), findsOneWidget);
    expect(find.text('Ölüm İlanları'), findsOneWidget);
    final grid = tester.widget<GridView>(find.byType(GridView));
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 4);

    await tester.tap(find.text('Hava Durumu'));
    expect(selected?.id, 'hava-durumu');
    expect(tester.takeException(), isNull);
  });

  testWidgets('AppFeatureScreen başlık ve boş veri durumunu gösterir', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: AppFeatureScreen(item: AppItems.nobetciEczane)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Nöbetçi Eczane'), findsOneWidget);
    expect(find.text('Veri yüklenemedi'), findsOneWidget);
    expect(find.text('Bölgendeki açık eczaneler'), findsNothing);
    expect(find.text('YAKINDA'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Uygulamalar sekmesi alt sayfayı açar', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: _TestShellScreen()));
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text('Nöbetçi Eczane'), findsNothing);

    await tester.tap(find.text('Uygulamalar'));
    await _pumpShellTransition(tester);

    expect(find.text('Nöbetçi Eczane'), findsOneWidget);
    expect(find.text('Etkinlik'), findsWidgets);
    expect(find.text('Duyurular'), findsOneWidget);
    expect(find.text('Ölüm İlanları'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('Uygulamalar sheet aşağı sürüklenince kapanır', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: _TestShellScreen()));
    await tester.pump(const Duration(milliseconds: 1));

    await tester.tap(find.text('Uygulamalar'));
    await _pumpShellTransition(tester);
    expect(find.text('Nöbetçi Eczane'), findsOneWidget);

    // Sheet'i parmakla aşağı çek → kapanmalı.
    await tester.drag(find.text('Nöbetçi Eczane'), const Offset(0, 420));
    await _pumpShellTransition(tester);

    expect(find.text('Nöbetçi Eczane'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpShellTransition(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 720));
  await tester.pump();
}

class _TestShellScreen extends StatelessWidget {
  const _TestShellScreen();

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: const ShellScreen(),
    );
  }
}
