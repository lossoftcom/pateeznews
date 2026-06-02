import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pateeznews_admin/frontend/features/shell/presentation/shell_screen.dart';

void main() {
  testWidgets('hesap sekmesi verilmis admin yuzeyini tiklayinca acar', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ShellScreen(accountPage: Text('Admin giris yuzeyi')),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text('Admin giris yuzeyi'), findsNothing);
    expect(find.text('Anasayfa'), findsOneWidget);

    await tester.tap(find.text('Hesap'));
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text('Admin giris yuzeyi'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('hesap sekmesi varsayilan giris ve kayit tasarimini acar', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ShellScreen()));
    await tester.pump(const Duration(milliseconds: 1));

    await tester.tap(find.text('Hesap'));
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text('Hesabına giriş yap'), findsOneWidget);
    expect(find.text('Google ile giriş'), findsOneWidget);
    expect(find.text('Apple ile giriş'), findsOneWidget);
    expect(find.text('Kullanıcı adı'), findsOneWidget);
    expect(find.text('Şifre'), findsOneWidget);
    expect(find.text('Giriş yap'), findsOneWidget);
    expect(find.text('Üye ol'), findsOneWidget);

    await tester.tap(find.text('Üye ol'));
    await tester.pumpAndSettle();

    expect(find.text('Hesabını oluştur'), findsOneWidget);
    expect(find.text('Google ile kayıt ol'), findsOneWidget);
    expect(find.text('Apple ile kayıt ol'), findsOneWidget);
    expect(find.text('Ad soyad'), findsOneWidget);
    expect(find.text('E-posta'), findsOneWidget);
    expect(find.text('Şifre tekrar'), findsOneWidget);
  });
}
