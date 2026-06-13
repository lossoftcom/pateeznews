/// Oturum-içi, kısa ömürlü bellek cache'i. Sayfa geçişlerinde son veriyi
/// anında gösterip arka planda tazelemek (stale-while-revalidate) için.
///
/// Sunucu yanıtı değişmez; bu cache yalnızca istemci-içi ve kısa ömürlüdür,
/// böylece admin verisi taze kalır ama "her girişte boş ekran + spinner"
/// kaybolur.
class AdminMemoryCache<T> {
  AdminMemoryCache({this.ttl = const Duration(seconds: 45)});

  final Duration ttl;
  final Map<String, _Entry<T>> _store = {};

  /// TTL içindeyse değeri, değilse null döner (süresi geçmişse temizler).
  T? get(String key) {
    final entry = _store[key];
    if (entry == null) return null;
    if (DateTime.now().isAfter(entry.expiresAt)) {
      _store.remove(key);
      return null;
    }
    return entry.value;
  }

  void set(String key, T value) {
    _store[key] = _Entry(value, DateTime.now().add(ttl));
  }

  void remove(String key) => _store.remove(key);

  void clear() => _store.clear();
}

class _Entry<T> {
  _Entry(this.value, this.expiresAt);
  final T value;
  final DateTime expiresAt;
}
