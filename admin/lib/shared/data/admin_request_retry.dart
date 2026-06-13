import 'dart:async';

/// Geçici ağ/sunucu hatalarında üstel geri-çekilmeli yeniden deneme.
///
/// Soğuk/yavaş başlangıçta tek bir başarısız isteğin ekranı boşaltmasını
/// engeller. YALNIZCA idempotent okuma (GET/list) çağrılarında kullan;
/// yazma (POST/DELETE) işlemlerinde KULLANMA (çift işlem riski).
Future<T> withAdminRetry<T>(
  Future<T> Function() action, {
  int maxAttempts = 3,
  Duration initialDelay = const Duration(milliseconds: 300),
}) async {
  var attempt = 0;
  var delay = initialDelay;
  while (true) {
    attempt++;
    try {
      return await action();
    } catch (_) {
      if (attempt >= maxAttempts) rethrow;
      await Future<void>.delayed(delay);
      delay *= 2;
    }
  }
}
