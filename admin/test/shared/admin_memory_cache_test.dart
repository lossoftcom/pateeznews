import 'package:flutter_test/flutter_test.dart';
import 'package:pateeznews_admin/shared/data/admin_memory_cache.dart';

void main() {
  test('TTL içinde değer döner, sonra null', () async {
    final cache = AdminMemoryCache<int>(ttl: const Duration(milliseconds: 50));
    cache.set('k', 7);
    expect(cache.get('k'), 7);
    await Future<void>.delayed(const Duration(milliseconds: 70));
    expect(cache.get('k'), isNull);
  });

  test('farklı anahtarlar ayrışır', () {
    final cache = AdminMemoryCache<String>(ttl: const Duration(seconds: 60));
    cache.set('a', 'x');
    cache.set('b', 'y');
    expect(cache.get('a'), 'x');
    expect(cache.get('b'), 'y');
  });

  test('clear tüm girişleri siler', () {
    final cache = AdminMemoryCache<int>(ttl: const Duration(seconds: 60));
    cache.set('a', 1);
    cache.clear();
    expect(cache.get('a'), isNull);
  });
}
