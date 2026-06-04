import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pateeznews_admin/frontend/features/announcements/presentation/announcements_screen.dart';
import 'package:pateeznews_admin/frontend/features/etkinlik/presentation/etkinlik_screen.dart';
import 'package:pateeznews_admin/frontend/features/markets/presentation/markets_screen.dart';
import 'package:pateeznews_admin/frontend/features/obituaries/presentation/obituaries_screen.dart';
import 'package:pateeznews_admin/frontend/features/pharmacy/presentation/pharmacy_screen.dart';
import 'package:pateeznews_admin/frontend/features/weather/presentation/weather_screen.dart';

void main() {
  testWidgets('Duyurular sayfası resmi kurum duyurularını gösterir', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: AnnouncementsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Duyurular'), findsOneWidget);
    expect(find.text('Resmi duyurular tek ekranda'), findsOneWidget);
    expect(find.text('VALİLİK'), findsOneWidget);
    expect(find.text('BELEDİYE'), findsOneWidget);
    expect(find.text('KAMU'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Hava Durumu sayfası Niğde verisini ve bölümleri gösterir', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 1700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: WeatherScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Hava Durumu'), findsOneWidget);
    expect(find.text('Niğde · Merkez'), findsOneWidget);
    expect(find.text('Parçalı Bulutlu'), findsOneWidget);
    expect(find.text('Saatlik tahmin'), findsOneWidget);
    expect(find.text('7 günlük tahmin'), findsOneWidget);
    expect(find.text('Detaylar'), findsOneWidget);
    expect(find.text('Nem'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Nöbetçi Eczane sayfası eczaneleri ve aksiyonları gösterir', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 1500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: PharmacyScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Nöbetçi Eczane'), findsOneWidget);
    expect(find.text('Yeni Eczane'), findsOneWidget);
    expect(find.text('Ara'), findsWidgets);
    expect(find.text('Yol Tarifi'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Ölüm İlanları sayfası ilanları ve cenaze programını gösterir', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 1700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: ObituariesScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Ölüm İlanları'), findsOneWidget);
    expect(find.text('HÜVELBÂKİ'), findsOneWidget);
    expect(find.text('Mehmet Yıldız'), findsOneWidget);
    expect(find.text('Cenaze Programı'), findsWidgets);
    expect(find.text('Taziye Mesajı Gönder'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Döviz & Altın sayfası segment ve kurları gösterir', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: MarketsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Döviz & Altın'), findsOneWidget);
    expect(find.text('Döviz'), findsOneWidget);
    expect(find.text('Altın'), findsOneWidget);
    expect(find.text('USD'), findsOneWidget);
    expect(find.text('48,2040'), findsOneWidget);

    await tester.tap(find.text('Altın'));
    await tester.pumpAndSettle();
    expect(find.text('Gram Altın'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Etkinlik sayfası filtreler ve etkinlikleri gösterir', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 1500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: EtkinlikScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Etkinlik'), findsOneWidget);
    expect(find.text('Tümü'), findsOneWidget);
    expect(find.text('Niğde Bağ Bozumu Festivali'), findsOneWidget);

    await tester.tap(find.text('Konser'));
    await tester.pumpAndSettle();
    expect(find.text('Niğde Bağ Bozumu Festivali'), findsNothing);
    expect(find.textContaining('Senfoni'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
