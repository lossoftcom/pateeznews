import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pateeznews_admin/frontend/core/mock/home_mock_data.dart';
import 'package:pateeznews_admin/frontend/features/news_detail/presentation/widgets/detail_quiz.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

void main() {
  testWidgets('quiz result card renders v2 design', (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(390, 1400);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: DetailQuizBlock(
                title: 'Tasarım kanıt testi',
                description: 'Sonuç kartı v2 görünümü.',
                data: const NewsQuizData(
                  quizType: 'trivia',
                  questions: [
                    NewsQuizQuestion(
                      id: 'q1',
                      title: 'Tek soru',
                      answers: [
                        NewsQuizAnswer(
                          id: 'a1',
                          text: 'Doğru şık',
                          isCorrect: true,
                        ),
                        NewsQuizAnswer(id: 'a2', text: 'Yanlış şık'),
                      ],
                    ),
                  ],
                  results: [
                    NewsQuizResult(
                      id: 'r1',
                      title: 'Harikasın!',
                      description: 'Bu yazı Newsreader italik olmalı.',
                      minScore: 0,
                      maxScore: 1,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Doğru şık'));
    await tester.pumpAndSettle();

    // Sonuç kartı açıldı.
    expect(find.text('Harikasın!'), findsOneWidget);

    // 1) Başlık solundaki ikon artık lacivert kutuda "verified" rozeti.
    expect(find.byIcon(Symbols.verified), findsOneWidget);

    // 2) "Sonucun" bölüm etiketi turuncu ışıltı ikonu kullanıyor.
    expect(find.byIcon(Symbols.sparkling_fill), findsOneWidget);

    // 3) Açıklama Newsreader, italik ve ince (w400), 17 punto.
    final descText = tester.widget<Text>(
      find.text('Bu yazı Newsreader italik olmalı.'),
    );
    expect(descText.style?.fontFamily, 'Newsreader');
    expect(descText.style?.fontStyle, FontStyle.italic);
    expect(descText.style?.fontWeight, FontWeight.w400);
    expect(descText.style?.fontSize, 17);

    // 4) Ağaçta tek bir gradyan dekorasyon yok.
    final gradientCount = tester
        .widgetList(find.byType(DecoratedBox))
        .whereType<DecoratedBox>()
        .where(
          (box) =>
              box.decoration is BoxDecoration &&
              (box.decoration as BoxDecoration).gradient != null,
        )
        .length;
    final containerGradients = tester
        .widgetList(find.byType(Container))
        .whereType<Container>()
        .where(
          (box) =>
              box.decoration is BoxDecoration &&
              (box.decoration as BoxDecoration).gradient != null,
        )
        .length;
    expect(gradientCount + containerGradients, 0);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
