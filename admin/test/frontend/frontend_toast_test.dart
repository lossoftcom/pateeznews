import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pateeznews_admin/frontend/shared/widgets/frontend_toast.dart';

void main() {
  setUp(FrontendToast.dismiss);
  tearDown(FrontendToast.dismiss);

  testWidgets('error toast is elevated and text is not underlined', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    const message = 'Beğenmek için kayıt olmanız gerekiyor.';
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => FrontendToast.show(
                    context,
                    message: message,
                    tone: FrontendToastTone.error,
                  ),
                  child: const Text('Göster'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Göster'));
    await tester.pump();

    final toastText = tester.widget<Text>(find.text(message));
    expect(toastText.style?.decoration, TextDecoration.none);
    expect(toastText.style?.decorationColor, Colors.transparent);
    expect(tester.getCenter(find.text(message)).dy, lessThan(700));
  });

  testWidgets('default toast stays visible longer than the old duration', (
    tester,
  ) async {
    const message = 'Kaydedildi.';
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () =>
                      FrontendToast.show(context, message: message),
                  child: const Text('Göster'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Göster'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2400));

    expect(find.text(message), findsOneWidget);
  });
}
