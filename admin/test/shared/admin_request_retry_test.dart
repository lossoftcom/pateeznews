import 'package:flutter_test/flutter_test.dart';
import 'package:pateeznews_admin/shared/data/admin_request_retry.dart';

void main() {
  test('ilk denemede başarılıysa tek kez çağırır', () async {
    var calls = 0;
    final result = await withAdminRetry(() async {
      calls++;
      return 42;
    });
    expect(result, 42);
    expect(calls, 1);
  });

  test('geçici hatada yeniden dener ve sonunda başarılı olur', () async {
    var calls = 0;
    final result = await withAdminRetry(
      () async {
        calls++;
        if (calls < 3) throw Exception('geçici');
        return 'ok';
      },
      maxAttempts: 3,
      initialDelay: const Duration(milliseconds: 1),
    );
    expect(result, 'ok');
    expect(calls, 3);
  });

  test('maxAttempts aşılınca son hatayı fırlatır', () async {
    var calls = 0;
    await expectLater(
      withAdminRetry(
        () async {
          calls++;
          throw Exception('hep hata');
        },
        maxAttempts: 2,
        initialDelay: const Duration(milliseconds: 1),
      ),
      throwsException,
    );
    expect(calls, 2);
  });
}
