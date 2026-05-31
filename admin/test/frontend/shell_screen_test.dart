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
}
