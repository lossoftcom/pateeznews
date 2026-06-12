import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pateeznews_admin/frontend/features/profile/data/profile_content.dart';
import 'package:pateeznews_admin/frontend/features/profile/presentation/profile_screen.dart';

void main() {
  testWidgets('profil sayfası tüm bölümleri ve istatistikleri gösterir', (
    tester,
  ) async {
    // Profil uzun bir sayfa; tüm bölümlerin (lazy sliver'lar dahil) kurulması
    // için test penceresini yükselt.
    tester.view.physicalSize = const Size(440, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(home: ProfileScreen(data: ProfileData.demo())),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    // Kimlik
    expect(find.text('Pateez Niğde'), findsWidgets);
    expect(find.text('Çevrimiçi'), findsOneWidget);
    expect(find.text('Profili Düzenle'), findsOneWidget);

    // İstatistik şeridi
    expect(find.text('HABER'), findsOneWidget);
    expect(find.text('TAKİPÇİ'), findsOneWidget);
    expect(find.text('TAKİP'), findsOneWidget);
    expect(find.text('KATILDI'), findsOneWidget);

    // Bilgi kartları
    expect(find.text('Hakkında'), findsOneWidget);
    expect(find.text('Sosyal Bağlantılar'), findsOneWidget);
    expect(find.text('Takipçiler'), findsOneWidget);
    expect(find.text('Takip Edilen'), findsOneWidget);

    // Gönderiler
    expect(find.text('Gönderiler'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'başkasının profilinde takip butonu görünür, düzenleme görünmez',
    (tester) async {
      tester.view.physicalSize = const Size(440, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: ProfileScreen(
            data: ProfileData.demo(name: 'Aylin Yılmaz', isOwnProfile: false),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.text('Aylin Yılmaz'), findsWidgets);
      expect(find.text('TAKİP ET'), findsOneWidget);
      expect(find.text('Profili Düzenle'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
