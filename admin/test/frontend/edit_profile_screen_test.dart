import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pateeznews_admin/frontend/features/profile/data/profile_content.dart';
import 'package:pateeznews_admin/frontend/features/profile/presentation/edit_profile_screen.dart';

void main() {
  testWidgets('düzenleme formu tüm bölümleri ve aksiyonları gösterir', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(440, 4200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(home: EditProfileScreen(data: ProfileData.demo())),
    );
    await tester.pump();

    expect(find.text('Profili Düzenle'), findsOneWidget);
    expect(find.text('Fotoğraflar'), findsOneWidget);
    expect(find.text('Hesap Bilgileri'), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);
    expect(find.text('Sosyal Bağlantılar'), findsOneWidget);
    expect(find.text('Tercihler'), findsOneWidget);
    expect(find.text('Şifre Değiştir'), findsOneWidget);
    expect(find.text('Tehlikeli Alan'), findsOneWidget);

    expect(find.text('Değişiklikleri Kaydet'), findsOneWidget);
    expect(find.text('Şifreyi Güncelle'), findsOneWidget);
    expect(find.text('Hesabı Sil'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('boş şifre güncellemesi doğrulama hatası gösterir', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(440, 4200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(home: EditProfileScreen(data: ProfileData.demo())),
    );
    await tester.pump();

    await tester.tap(find.text('Şifreyi Güncelle'));
    await tester.pump();

    expect(find.text('Mevcut ve yeni şifre zorunlu.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
