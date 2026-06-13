# PateezNews Hız Optimizasyonu — Uygulama Planı

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Flutter mobil önyüzünde "ilk açılışta veri gelmiyor" sorununu bitirmek ve açılış + resim yüklemesini ışık hızına çıkarmak; mevcut çalışan hiçbir özelliği bozmadan.

**Architecture:** Üç katmana dokunuyoruz: (1) Flutter repository/bootstrap (offline snapshot + retry + tek istek + doğru precache + paylaşılan HTTP client), (2) sunucu görsel-URL üretimi (302 redirect'i kaldırıp doğrudan `.variants` statik URL'si dönmek), (3) anonim feed/shell yanıtlarına edge-cache başlığı. Her değişiklik geriye dönük uyumlu ve bağımsız test edilebilir.

**Tech Stack:** Flutter (Dart 3.12, `http`, `cached_network_image`, `shared_preferences`), Astro + Cloudflare Workers (TypeScript), `pg` + Cloudflare Hyperdrive + Supabase Postgres, `sharp` (varyant üretimi).

---

## Rapor maddeleri → Plan görevleri eşlemesi

| Rapor # | Konu | Plan görevi |
|---------|------|-------------|
| P0-5 | Resim 302 redirect | Task 0 + Task 3 |
| P0-1,2 | İlk açılış boş + retry | Task 1A + Task 1B |
| P0-3 / Rapor #7 | Çift home isteği | Task 1B |
| P0-4 | precache provider uyumsuzluğu | Task 2 |
| P1-6 | Logo/poster disk cache | Task 4 |
| P1-7 | Paylaşılan http.Client | Task 5 |
| P1-9 | Anonim feed edge-cache | Task 6 |

**Önerilen uygulama sırası:** Task 0 → 3 → 1A → 1B → 2 → 4 → 5 → 6. (Task 2 ve 4 birbirine bağlı: logo precache'i Task 4'te güncellenir.)

## Doğrulama araçları (bu repoda mevcut olan)

- **Dart testleri:** `cd admin && flutter test <dosya>` — `package:http/testing` `MockClient` ve `SharedPreferences.setMockInitialValues` kullanılıyor (bkz. `admin/test/frontend/home_repository_test.dart`).
- **Dart statik analiz:** `cd admin && flutter analyze`
- **Sunucu (TS) için birim test altyapısı YOK.** Sunucu değişiklikleri şu şekilde doğrulanır:
  - Tip/derleme: `npm run wrangler:check` (wrangler dry-run; worker'ı derler).
  - Davranış: `npm run dev` ile yerel sunucu + `curl` çıktısı kontrolü (her görevde tam komut verilmiştir).
- **Commit:** Her görevin sonunda küçük, odaklı commit.

> NOT: Production'da bu değişiklikleri açmadan önce `migration/2026-06-11-mobile-home-performance-indexes.sql`, `migration/2026-06-10-mobile-comments-admin-flow.sql` ve `migration/2026-06-11-mobile-search-vector.sql` dosyalarının canlı Supabase'de uygulandığını doğrula (indeksler `veritabani.sql` dump'ında YOK ama migration'larda var).

---

## Task 0: Paylaşılan görsel-varyant modülü (server)

**Amaç:** `nearestVariantWidth` ve "doğrudan `.variants` statik yolu" mantığını tek yerde toplayıp hem redirect endpoint'inin hem de URL üreticilerin (appFeed.ts, home.ts) kullanmasını sağlamak (DRY). Task 3 buna dayanır. Bu görev davranışı DEĞİŞTİRMEZ; sadece ortak yardımcıyı oluşturur ve redirect endpoint'ini ona bağlar.

**Files:**
- Create: `src/lib/server/imageVariants.ts`
- Modify: `src/pages/api/storage/file/[...path].ts` (mevcut sabitleri/fonksiyonları yeni modülden import et)

- [ ] **Step 1: Ortak modülü oluştur**

Create `src/lib/server/imageVariants.ts`:

```typescript
// Görsel varyantları için tek kaynak. Hem redirect endpoint'i ([...path].ts)
// hem de API yanıtlarındaki URL üreticileri (appFeed.ts, home.ts) bunu kullanır.

export const SUPPORTED_VARIANT_WIDTHS = [180, 260, 800, 900, 1200, 1440, 1600];
export const SUPPORTED_VARIANT_QUALITY = 86;

// image/ ve profile/ tipleri upload anında 7 genişlikte webp varyant üretir
// (bkz. scripts/local-storage-server.mjs). Yalnızca bu önekler için doğrudan
// statik varyant yolu güvenle kullanılabilir.
export const LOCAL_VARIANT_PREFIXES = ["image/", "profile/"];
export const TRANSFORMABLE_IMAGE_EXTENSIONS = new Set([
  ".jpg",
  ".jpeg",
  ".png",
  ".webp",
  ".avif",
]);

export function nearestVariantWidth(width: number): number {
  for (const candidate of SUPPORTED_VARIANT_WIDTHS) {
    if (width <= candidate) return candidate;
  }
  return SUPPORTED_VARIANT_WIDTHS[SUPPORTED_VARIANT_WIDTHS.length - 1];
}

export function objectExtension(objectPath: string): string {
  const clean = objectPath.split("?")[0].split("#")[0].toLowerCase();
  const dotIndex = clean.lastIndexOf(".");
  return dotIndex === -1 ? "" : clean.slice(dotIndex);
}

// "image/2026-06-12/foo.png" -> ".variants/w1200-q86/image/2026-06-12/foo.webp"
export function variantObjectPath(
  objectPath: string,
  width: number,
  quality: number = SUPPORTED_VARIANT_QUALITY,
): string {
  const clean = objectPath.replace(/^\/+/, "");
  const dotIndex = clean.lastIndexOf(".");
  const withoutExtension = dotIndex === -1 ? clean : clean.slice(0, dotIndex);
  return `.variants/w${width}-q${quality}/${withoutExtension}.webp`;
}
```

- [ ] **Step 2: Redirect endpoint'ini ortak modüle bağla**

`src/pages/api/storage/file/[...path].ts` içinde yerel kopyaları kaldır ve import et. Mevcut satırlar (12-16):

```typescript
const IMAGE_VARIANT_CACHE = 'public, max-age=86400, stale-while-revalidate=604800';
const TRANSFORMABLE_IMAGE_EXTENSIONS = new Set(['.jpg', '.jpeg', '.png', '.webp', '.avif']);
const LOCAL_VARIANT_PREFIXES = ['image/', 'profile/'];
const SUPPORTED_VARIANT_WIDTHS = [180, 260, 800, 900, 1200, 1440, 1600];
const SUPPORTED_VARIANT_QUALITY = 86;
```

Şununla değiştir:

```typescript
import {
  SUPPORTED_VARIANT_QUALITY,
  TRANSFORMABLE_IMAGE_EXTENSIONS,
  LOCAL_VARIANT_PREFIXES,
  nearestVariantWidth,
  objectExtension,
  variantObjectPath,
} from '@/lib/server/imageVariants';

const IMAGE_VARIANT_CACHE = 'public, max-age=86400, stale-while-revalidate=604800';
```

Ardından dosyadaki yerel `nearestVariantWidth`, `objectExtension`, `variantObjectPath` fonksiyon tanımlarını sil (artık import ediliyorlar). `imageVariantOptions` içindeki `SUPPORTED_VARIANT_QUALITY` referansı import'tan gelir; aynen kalır.

- [ ] **Step 3: Derleme doğrulaması**

Run: `npm run wrangler:check`
Expected: Hata yok (worker derlenir). Eğer `@/lib/server/imageVariants` çözülemezse `tsconfig.json` path alias'larını kontrol et (mevcut `@/lib/...` import'ları zaten çalışıyor).

- [ ] **Step 4: Davranış doğrulaması (regresyon yok)**

Terminal 1: `npm run dev`
Terminal 2:
```bash
curl -s -I "http://127.0.0.1:4321/api/storage/file/image/2026-05-24/1779656103320-Ekran_Resmi_2026-05-24_23.39.03.png?w=1200" | grep -i "location\|HTTP"
```
Expected: `HTTP/1.1 302` ve `location: /local-upload/.variants/w1200-q86/image/2026-05-24/1779656103320-Ekran_Resmi_2026-05-24_23.39.03.webp` (Task 0 öncesiyle birebir aynı).

- [ ] **Step 5: Commit**

```bash
git add src/lib/server/imageVariants.ts src/pages/api/storage/file/\[...path\].ts
git commit -m "refactor(server): extract shared image variant helpers"
```

---

## Task 3: API yanıtlarında doğrudan .variants URL'si (302 redirect'i kaldır)

**Amaç:** `image/` ve `profile/` görselleri için API JSON'unda `?w=` yerine doğrudan `/local-upload/.variants/wNNN-q86/...webp` statik yolunu döndürmek. Böylece istemci tek istekle CDN'den indirir, worker hiç çalışmaz. Redirect endpoint'i (Task 0) eski `?w=` URL'leri için fallback olarak KALIR — yani önbellekte eski URL'si olan istemciler bozulmaz.

> Güvence: `[...path].ts` zaten `image/`+`profile/` önekleri için her durumda (dev ve prod) statik `.variants` yoluna 302 atıyor. Bu yolu doğrudan üretmek davranışsal olarak birebir aynı sonuç verir.

**Files:**
- Modify: `src/lib/server/appFeed.ts:23-51` (`withLocalImageVariant`)
- Modify: `src/pages/api/app/home.ts:27-56` (`withLocalImageVariant` — birebir kopya)

- [ ] **Step 1: appFeed.ts'te doğrudan varyant üretimini ekle**

`src/lib/server/appFeed.ts` başına import ekle (mevcut import bloğunun altına):

```typescript
import {
  LOCAL_VARIANT_PREFIXES,
  TRANSFORMABLE_IMAGE_EXTENSIONS,
  nearestVariantWidth,
  objectExtension,
  variantObjectPath,
} from "@/lib/server/imageVariants";
```

Mevcut `withLocalImageVariant` (satır 23-51) gövdesinde, `parsed.searchParams.set("w", ...)` bloğunu doğrudan varyant yolu üretimiyle değiştir. Yeni gövde:

```typescript
const withLocalImageVariant = (
  resolvedUrl: string,
  base: string,
  options: ImageVariantOptions = {},
): string => {
  const width = Math.round(Number(options.width || 0));
  if (!resolvedUrl || width <= 0) return resolvedUrl;

  try {
    const baseUrl = new URL(base);
    const parsed = new URL(resolvedUrl, baseUrl);
    if (parsed.origin !== baseUrl.origin) return resolvedUrl;
    if (
      !LOCAL_IMAGE_PATH_PREFIXES.some((prefix) =>
        parsed.pathname.startsWith(prefix),
      )
    ) {
      return resolvedUrl;
    }

    // "/api/storage/file/image/.." veya "/local-upload/image/.." -> "image/.."
    const objectPath = parsed.pathname
      .replace(/^\/api\/storage\/file\//, "")
      .replace(/^\/local-upload\//, "");
    const extension = objectExtension(objectPath);
    const isVariantEligible =
      LOCAL_VARIANT_PREFIXES.some((prefix) => objectPath.startsWith(prefix)) &&
      TRANSFORMABLE_IMAGE_EXTENSIONS.has(extension);

    if (isVariantEligible) {
      // Doğrudan statik varyant: tek istek, CDN'den, redirect yok.
      const target = nearestVariantWidth(Math.min(Math.max(width, 64), 3840));
      const variantPath = variantObjectPath(objectPath, target);
      return new URL(`/local-upload/${variantPath}`, baseUrl).toString();
    }

    // Diğer durumlar (ör. cdn-cgi yolu gereken haller) eski davranışta kalır.
    parsed.searchParams.set("w", String(Math.min(Math.max(width, 64), 3840)));
    const quality = Math.round(Number(options.quality || 0));
    if (quality > 0) {
      parsed.searchParams.set("q", String(Math.min(Math.max(quality, 40), 95)));
    }
    return parsed.toString();
  } catch {
    return resolvedUrl;
  }
};
```

- [ ] **Step 2: home.ts'teki birebir kopyaya aynı değişikliği uygula**

`src/pages/api/app/home.ts` başına aynı import'u ekle:

```typescript
import {
  LOCAL_VARIANT_PREFIXES,
  TRANSFORMABLE_IMAGE_EXTENSIONS,
  nearestVariantWidth,
  objectExtension,
  variantObjectPath,
} from "@/lib/server/imageVariants";
```

`home.ts:27-56` içindeki `withLocalImageVariant` gövdesini Step 1'deki gövdeyle birebir aynı yap (değişken adları zaten aynı: `LOCAL_IMAGE_PATH_PREFIXES` home.ts'te de tanımlı, satır 14).

- [ ] **Step 3: Derleme doğrulaması**

Run: `npm run wrangler:check`
Expected: Hata yok.

- [ ] **Step 4: Davranış doğrulaması — API artık doğrudan .variants döndürüyor**

Terminal 1: `npm run dev`
Terminal 2:
```bash
curl -s "http://127.0.0.1:4321/api/app/home?lang=tr" | python3 -c "import sys,json; d=json.load(sys.stdin); print([i['imageUrl'] for i in d['feed'][:3]])"
```
Expected: URL'ler `/local-upload/.variants/w...-q86/....webp` formatında (içinde `?w=` YOK).

Sonra o URL'lerden birinin redirect olmadan 200 döndüğünü doğrula:
```bash
curl -s -o /dev/null -w "%{http_code} %{url_effective}\n" "http://127.0.0.1:4321<DÖNEN_VARIANT_YOLU>"
```
Expected: `200` ve URL değişmeden (redirect yok).

- [ ] **Step 5: Regresyon — Dart parse testleri hâlâ geçiyor**

Run: `cd admin && flutter test test/frontend/home_repository_test.dart`
Expected: PASS (testler mutlak `http://localhost:4321/local-upload/...` URL'leri mock'luyor; değişiklik yalnızca gerçek sunucu yanıtını etkiler, parse mantığını değil).

- [ ] **Step 6: Commit**

```bash
git add src/lib/server/appFeed.ts src/pages/api/app/home.ts
git commit -m "perf(server): emit direct .variants image URLs (no redirect hop)"
```

---

## Task 1A: HomeRepository — offline snapshot + retry

**Amaç:** Başarılı home yanıtının ham gövdesini `SharedPreferences`'a yazmak; ağ hatası/timeout durumunda önce kısa retry, hâlâ olmazsa son snapshot'ı döndürmek. Böylece "ilk açılışta boş" biter ve sonraki açılışlar anında son veriyi gösterir.

**Files:**
- Modify: `admin/lib/frontend/features/home/data/home_repository.dart:82-114`
- Test: `admin/test/frontend/home_repository_test.dart`

- [ ] **Step 1: Başarısızlıkta retry + snapshot fallback testini yaz**

`admin/test/frontend/home_repository_test.dart` dosyasının sonuna (kapanış `}` öncesi) ekle. Dosya başında import'lar mevcut; ek olarak `import 'package:shared_preferences/shared_preferences.dart';` ekle.

```dart
  test('fetchHome retries on failure then returns cached snapshot', () async {
    SharedPreferences.setMockInitialValues({});

    var calls = 0;
    final okBody = jsonEncode({
      'featured': [],
      'feed': [
        {'id': 'cached-1', 'title': 'Önbellekten haber'},
      ],
      'settings': {'homePageSize': 16},
    });

    // 1) Başarılı çağrı: snapshot diske yazılır.
    final okRepo = HomeRepository(
      apiBaseUrl: 'http://localhost:4321',
      httpClient: MockClient((request) async {
        return http.Response(
          okBody,
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    final okData = await okRepo.fetchHome();
    expect(okData.feed.single.title, 'Önbellekten haber');

    // 2) Sürekli hata veren çağrı: retry yapılır, sonra snapshot döner.
    final failRepo = HomeRepository(
      apiBaseUrl: 'http://localhost:4321',
      httpClient: MockClient((request) async {
        calls += 1;
        return http.Response('boom', 500);
      }),
    );
    final fallbackData = await failRepo.fetchHome(retries: 2);

    expect(calls, 3, reason: '1 ilk deneme + 2 retry');
    expect(fallbackData.feed.single.title, 'Önbellekten haber');
  });

  test('fetchHome returns empty when failing with no snapshot', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = HomeRepository(
      apiBaseUrl: 'http://localhost:4321',
      httpClient: MockClient((request) async => http.Response('x', 500)),
    );
    final data = await repo.fetchHome(retries: 1);
    expect(data.feed, isEmpty);
    expect(data.featured, isEmpty);
  });
```

- [ ] **Step 2: Testi çalıştır — başarısız olduğunu gör**

Run: `cd admin && flutter test test/frontend/home_repository_test.dart`
Expected: FAIL — `fetchHome` `retries` parametresini tanımıyor / snapshot davranışı yok.

- [ ] **Step 3: HomeRepository'yi güncelle**

`admin/lib/frontend/features/home/data/home_repository.dart` başına ekle:

```dart
import 'package:shared_preferences/shared_preferences.dart';
```

`HomeRepository` sınıfında `_timeout` sabitinin altına ekle:

```dart
  static String _snapshotKey(String lang) => 'home_snapshot_$lang';

  Future<void> _saveSnapshot(String lang, String body) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_snapshotKey(lang), body);
    } catch (_) {
      // Snapshot yazılamasa da akış sürer.
    }
  }

  /// Son başarılı home yanıtını diskten döndürür. Açılışta anlık gösterim için.
  Future<HomeData?> loadCachedHome({String lang = 'tr'}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final body = prefs.getString(_snapshotKey(lang));
      if (body == null || body.isEmpty) return null;
      return compute(_parseHomeData, body);
    } catch (_) {
      return null;
    }
  }
```

Mevcut `fetchHome` (satır 91-114) gövdesini şununla değiştir:

```dart
  Future<HomeData> fetchHome({
    String lang = 'tr',
    String? token,
    int retries = 1,
  }) async {
    final uri = _uri('/api/app/home').replace(queryParameters: {'lang': lang});
    final client = httpClient ?? http.Client();
    final authToken = token?.trim() ?? '';
    try {
      for (var attempt = 0; attempt <= retries; attempt++) {
        try {
          final response = await client
              .get(
                uri,
                headers: {
                  'Accept': 'application/json',
                  if (authToken.isNotEmpty)
                    'Authorization': 'Bearer $authToken',
                },
              )
              .timeout(_timeout);
          if (response.statusCode >= 200 && response.statusCode < 300) {
            final body = utf8.decode(response.bodyBytes);
            await _saveSnapshot(lang, body);
            return compute(_parseHomeData, body);
          }
        } catch (_) {
          // Bu deneme başarısız; aşağıda backoff sonrası tekrar denenir.
        }
        if (attempt < retries) {
          await Future<void>.delayed(
            Duration(milliseconds: 350 * (attempt + 1)),
          );
        }
      }
      // Tüm denemeler başarısız: son snapshot varsa onu döndür.
      return await loadCachedHome(lang: lang) ?? const HomeData.empty();
    } finally {
      if (httpClient == null) client.close();
    }
  }
```

- [ ] **Step 4: Testleri çalıştır — geçtiğini gör**

Run: `cd admin && flutter test test/frontend/home_repository_test.dart`
Expected: PASS (eski testler + 2 yeni test). Eski "fetchHome maps..." testi varsayılan `retries: 1` ile aynı çalışır (ilk denemede 200 döner).

- [ ] **Step 5: Commit**

```bash
git add admin/lib/frontend/features/home/data/home_repository.dart admin/test/frontend/home_repository_test.dart
git commit -m "feat(mobile): home offline snapshot + retry fallback"
```

---

## Task 1B: Bootstrap — anlık snapshot, tek home isteği, doğru token

**Amaç:** Açılışta (a) önce diskteki snapshot'ı anında göstermek, (b) oturum token'ını ağ home isteğinden ÖNCE yerel olarak geri yüklemek (böylece tek ve doğru-token'lı istek atılır, çift istek biter).

**Files:**
- Modify: `admin/lib/frontend/app/pateeznews_app.dart:109-147` (`_bootstrap`, `_loadSecondaryStartupData`)
- Modify: `admin/lib/frontend/app/pateeznews_app.dart:204-308` (`_loadHomeData`, `_restoreAuthState`)
- Test: `admin/test/frontend/pateeznews_app_bootstrap_test.dart` (yeni)

- [ ] **Step 1: Bootstrap davranış testini yaz (fake repo'larla)**

`PateeznewsApp` tüm repository'leri constructor parametresi olarak alıyor → enjekte edilebilir. Önce mevcut fake/mocking imkânını doğrulamak için sadece home isteğinin **bir kez** atıldığını ve snapshot'ın gösterildiğini test eden hafif bir widget testi:

Create `admin/test/frontend/pateeznews_app_bootstrap_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pateeznews_admin/frontend/app/pateeznews_app.dart';
import 'package:pateeznews_admin/frontend/features/home/data/home_repository.dart';

class _CountingHomeRepository extends HomeRepository {
  const _CountingHomeRepository(this._counter);
  final List<int> _counter;

  @override
  Future<HomeData> fetchHome({
    String lang = 'tr',
    String? token,
    int retries = 1,
  }) async {
    _counter.add(1);
    return const HomeData.empty();
  }

  @override
  Future<HomeData?> loadCachedHome({String lang = 'tr'}) async => null;
}

void main() {
  testWidgets('anonymous cold start fetches home exactly once', (tester) async {
    final calls = <int>[];
    await tester.pumpWidget(
      PateeznewsApp(homeRepository: _CountingHomeRepository(calls)),
    );
    // Splash min süresi + bootstrap akışı.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(calls.length, 1, reason: 'anonim açılışta tek home isteği');
  });
}
```

> NOT: `PateeznewsApp` varsayılan diğer repo'lar gerçek ağ çağrısı yapar ama testte `apiBaseUrl` ayarlı olmadığından `localhost:4321`'e gidip hata/boş döner (akışı bloklamaz; bootstrap `_maxSplash` ile sınırlı). Test yalnızca home çağrı sayısını ölçer. Eğer test ortamında ağ erişimi flakey olursa, bu testi `Task 5` sonrası genişlet (tüm repo'ları fake'le).

- [ ] **Step 2: Testi çalıştır — başarısız olduğunu gör**

Run: `cd admin && flutter test test/frontend/pateeznews_app_bootstrap_test.dart`
Expected: FAIL — `calls.length` 2 (anon + authed-restore yolundaki çift çağrı) ya da `fetchHome` override imzası uyuşmazlığı. (İmza Task 1A'dan sonra `retries` içerir; bu test onu kullanır.)

- [ ] **Step 3: Bootstrap'ı yeniden yapılandır**

`pateeznews_app.dart` içinde `_bootstrap` (satır 109-131) gövdesini şununla değiştir:

```dart
  Future<void> _bootstrap() async {
    final started = DateTime.now();

    // 1) Diskteki son feed'i anında göster (ağ beklemeden).
    unawaited(_loadCachedHomeSnapshot());

    // 2) Oturum token'ını YEREL olarak geri yükle (ağ home isteğinden önce),
    //    böylece tek ve doğru-token'lı home isteği atılır.
    await _restoreSessionToken();

    try {
      await Future.wait([
        _loadFontSettings(),
        _loadShellData(),
        _loadHomeData(),
        _refreshAuthProfile(),
      ]).timeout(_maxSplash);
    } catch (_) {
      // Timeout/hata olsa da açılışı bloklamayız.
    }

    final elapsed = DateTime.now().difference(started);
    if (elapsed < _minSplash) {
      await Future<void>.delayed(_minSplash - elapsed);
    }

    if (!mounted) return;
    setState(() => _ready = true);
    unawaited(_loadSecondaryStartupData());
  }

  Future<void> _loadCachedHomeSnapshot() async {
    final cached = await widget.homeRepository.loadCachedHome();
    if (cached == null || !mounted) return;
    // Ağ verisi henüz gelmediyse snapshot'ı göster.
    if (_homeFeedItems.isNotEmpty || _featuredItems.isNotEmpty) return;
    setState(() {
      _featuredItems = cached.featured;
      _homeFeedItems = cached.feed;
      _contentSettings = cached.settings;
    });
  }
```

`_restoreAuthState` (satır 272-308) yerine iki ayrı metoda böl: token'ı yerel geri yükleyen `_restoreSessionToken` ve profili ağdan tazeleyen `_refreshAuthProfile`. Mevcut `_restoreAuthState`'i sil ve şunları ekle:

```dart
  /// Yalnızca yerel oturum/token'ı geri yükler (ağ çağrısı yok). Home isteği
  /// bundan sonra doğru token ile TEK kez atılır.
  Future<void> _restoreSessionToken() async {
    try {
      final authState = await widget.authRepository.restoreSession();
      if (!mounted) return;
      setState(() {
        _authState = authState;
        _authLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _authState = null;
        _authLoading = false;
      });
    }
  }

  /// Giriş yapılmışsa profili ağdan tazeler. Home isteğinden bağımsız çalışır.
  Future<void> _refreshAuthProfile() async {
    final authState = _authState;
    if (authState == null) return;
    try {
      final profile = await widget.profileRepository.fetchSelf(
        token: authState.session.accessToken,
      );
      if (!mounted) return;
      await widget.authRepository.store.saveProfileCache(profile.authProfile);
      if (!mounted) return;
      setState(() {
        _profileData = profile.profile;
        _authState = FrontendAuthState(
          session: authState.session,
          profile: profile.authProfile,
        );
      });
    } catch (_) {
      // Önbellekteki profil uygulamayı açmaya yeter.
    }
  }
```

> Önemli: Eski `_restoreAuthState` sonunda bulunan `unawaited(_loadHomeData())` (satır 299) çağrısı SİLİNİR — home artık bootstrap'taki tek `_loadHomeData()` ile, doğru token hazırken atılır. Çift istek böylece biter.

- [ ] **Step 4: `restoreSession`'ın yerel (ağsız) olduğunu doğrula**

Read: `admin/lib/frontend/features/account/data/frontend_auth_repository.dart` → `restoreSession` metodu. Eğer içeride ağ çağrısı (ör. token refresh) varsa, `_restoreSessionToken`'ın `_maxSplash` ile sınırlı olduğundan emin ol; gerekiyorsa `restoreSession().timeout(const Duration(milliseconds: 1200))` ekle. Ağsızsa değişiklik gerekmez.
Expected: Bulgu notu — ağ çağrısı var/yok.

- [ ] **Step 5: Testi çalıştır — geçtiğini gör**

Run: `cd admin && flutter test test/frontend/pateeznews_app_bootstrap_test.dart`
Expected: PASS — `calls.length == 1`.

- [ ] **Step 6: Tüm frontend testleri + analiz**

Run: `cd admin && flutter test test/frontend/ && flutter analyze`
Expected: PASS, analiz temiz (yeni kullanılmayan import/uyarı yok).

- [ ] **Step 7: Commit**

```bash
git add admin/lib/frontend/app/pateeznews_app.dart admin/test/frontend/pateeznews_app_bootstrap_test.dart
git commit -m "feat(mobile): instant snapshot on boot + single correct-token home fetch"
```

---

## Task 2: Home görsel precache'ini doğru provider'a çevir

**Amaç:** `_precacheHomeImages` artık `CachedNetworkImageProvider` kullansın (gösterimle aynı cache). Böylece precache boşa gitmez; ilk görseller anında belirir.

**Files:**
- Modify: `admin/lib/frontend/app/pateeznews_app.dart:248-270` (`_precacheHomeImages`)

- [ ] **Step 1: Import ekle**

`pateeznews_app.dart` import bloğuna ekle:

```dart
import 'package:cached_network_image/cached_network_image.dart';
```

- [ ] **Step 2: precache çağrısını değiştir**

`_precacheHomeImages` içindeki (satır 263-266) bloğu:

```dart
      await Future.wait([
        for (final url in urls)
          precacheImage(NetworkImage(url), context, onError: (_, _) {}),
      ]).timeout(const Duration(milliseconds: 1400), onTimeout: () => const []);
```

şununla değiştir:

```dart
      await Future.wait([
        for (final url in urls)
          precacheImage(
            CachedNetworkImageProvider(url),
            context,
            onError: (_, _) {},
          ),
      ]).timeout(const Duration(milliseconds: 1400), onTimeout: () => const []);
```

> NOT: Marka logosu precache'i (`_precacheBrandLogos`, satır 237) ŞİMDİLİK `NetworkImage` olarak kalır — çünkü logolar hâlâ `Image.network` ile çiziliyor (eşleşme korunur). Task 4 logoları `CachedImage`'e çevirdiğinde, o görevde bu satır da `CachedNetworkImageProvider`'a güncellenir.

- [ ] **Step 3: Analiz + derleme**

Run: `cd admin && flutter analyze`
Expected: Temiz (kullanılmayan import yok — yeni import kullanılıyor).

- [ ] **Step 4: Manuel doğrulama**

Run: `cd admin && flutter run` (veya mevcut hedef cihaz). Uygulamayı soğuk aç; ilk manşet/feed görselleri görünür olduğunda anında (fade ile) gelmeli, boş placeholder süresi gözle görülür şekilde azalmalı.
Expected: İlk ekran görselleri belirgin gecikme olmadan dolu.

- [ ] **Step 5: Commit**

```bash
git add admin/lib/frontend/app/pateeznews_app.dart
git commit -m "fix(mobile): precache home images with CachedNetworkImageProvider"
```

---

## Task 4: Logo ve poster görsellerini CachedImage'e taşı

**Amaç:** Her ekranda görünen logolar ve video poster'ı disk cache'e alınsın (`Image.network` → `CachedImage`/`CachedNetworkImage`), tekrar inişler bitsin. Splash logosunun "ağ inene kadar asset göster" davranışı korunur.

**Files:**
- Modify: `admin/lib/frontend/features/home/presentation/widgets/home_app_bar.dart:166`
- Modify: `admin/lib/frontend/features/shell/presentation/widgets/pateez_side_menu.dart:388`
- Modify: `admin/lib/frontend/features/shell/presentation/widgets/pateez_bottom_nav.dart:200`
- Modify: `admin/lib/frontend/features/shell/presentation/shell_screen.dart:1481`
- Modify: `admin/lib/frontend/features/account/presentation/account_sign_in_screen.dart:189,724`
- Modify: `admin/lib/frontend/features/home/presentation/widgets/news_video_player.dart:2223`
- Modify: `admin/lib/frontend/app/pateeznews_app.dart:237` (logo precache → CachedNetworkImageProvider)

- [ ] **Step 1: Her `Image.network` kullanımını incele ve eşdeğer CachedImage'e çevir**

Her dosya için: önce o satırdaki `Image.network(...)` çağrısını (genişlik/yükseklik/fit/errorBuilder dahil) oku, sonra eşdeğer `CachedImage` ile değiştir. `CachedImage` zaten `fit`, `memCacheWidth`, `placeholderColor`, `errorWidget` destekliyor (`admin/lib/frontend/shared/widgets/cached_image.dart`).

Örnek dönüşüm kalıbı (app bar logosu, `home_app_bar.dart:166` civarı — gerçek parametreleri o dosyadan al):

```dart
// ÖNCE
Image.network(
  logoUrl,
  height: 28,
  fit: BoxFit.contain,
  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
)

// SONRA
CachedImage(
  url: logoUrl,
  fit: BoxFit.contain,
  memCacheWidth: (28 * MediaQuery.devicePixelRatioOf(context) * 6).round(),
  errorWidget: const SizedBox.shrink(),
)
```

> Logolar için yükseklik sabit; genişlik değişken olabildiğinden `memCacheWidth`'i logo en/boy oranına göre cömert tut (örn. yükseklik × dpr × ~6). `CachedImage` `height` parametresi almıyor → mevcut `SizedBox`/`ConstrainedBox` sarmalı varsa koru; yoksa `SizedBox(height: 28, child: CachedImage(...))` ile sar.

Her dosyada `import '../../../shared/widgets/cached_image.dart';` (göreli yolu o dosyanın konumuna göre ayarla) ekli değilse ekle. Kullanılmayan `Image.network` kalmayınca `package:flutter/material.dart` zaten gerekli, ekstra import temizliği gerekmez.

- [ ] **Step 2: Splash logosunu özel olarak ele al (fallback davranışı korunmalı)**

`pateez_logo_intro.dart:92` — mevcut `Image.network` `loadingBuilder` ile ağ inene kadar `_DefaultLogo` (asset) gösteriyor, `errorBuilder` ile de. `CachedNetworkImage`'in `placeholder` ve `errorWidget`'ı bunu birebir karşılar:

```dart
// SONRA (CachedNetworkImage ile, dosya başına
// import 'package:cached_network_image/cached_network_image.dart'; ekle)
CachedNetworkImage(
  imageUrl: logoUrl,
  width: logoW,
  height: logoH,
  fit: BoxFit.contain,
  filterQuality: FilterQuality.high,
  fadeInDuration: const Duration(milliseconds: 120),
  placeholder: (_, __) => _DefaultLogo(width: logoW, height: logoH),
  errorWidget: (_, __, ___) => _DefaultLogo(width: logoW, height: logoH),
)
```

> `gaplessPlayback` ve "her frame yeniden kurma" yorumu korunur — `CachedNetworkImage` zaten widget bir kez kurulduğunda görseli sabit tutar.

- [ ] **Step 3: Logo precache'ini eşle**

`pateeznews_app.dart:237` (logo precache) `NetworkImage(clean)` → `CachedNetworkImageProvider(clean)` yap (Task 2'de import zaten eklendi). Artık gösterim de CachedImage olduğu için cache eşleşir.

- [ ] **Step 4: Analiz**

Run: `cd admin && flutter analyze`
Expected: Temiz; hiçbir dosyada artık `Image.network` kalmamalı (logo/poster için).

Doğrulama:
```bash
grep -rn "Image.network" admin/lib/frontend | grep -v "_test"
```
Expected: Yalnızca `cached_image.dart` içindeki yorum satırı (kod değil) kalır; başka kullanım yok.

- [ ] **Step 5: Manuel doğrulama**

`cd admin && flutter run`. Splash → shell geçişinde logo kesintisiz; uygulamayı kapatıp tekrar açınca logo anında (diskten) gelir.

- [ ] **Step 6: Commit**

```bash
git add admin/lib/frontend
git commit -m "perf(mobile): cache logos and video poster via CachedImage"
```

---

## Task 5: Paylaşılan http.Client (bağlantı yeniden kullanımı)

**Amaç:** 16 repository'nin her istekte yeni `http.Client()` açıp kapatması yerine tek paylaşılan keep-alive client kullanması. Soğuk açılıştaki çoklu TLS handshake tek bağlantıda toplanır.

**Files:**
- Create: `admin/lib/frontend/core/network/frontend_http_client.dart`
- Modify: 16 repository dosyası (aşağıda liste) — `http.Client()` deseni
- Test: mevcut repository testleri (regresyon)

- [ ] **Step 1: Paylaşılan client modülünü oluştur**

Create `admin/lib/frontend/core/network/frontend_http_client.dart`:

```dart
import 'package:http/http.dart' as http;

/// Tüm frontend repository'lerinin paylaştığı tek HTTP client. Keep-alive
/// bağlantıları yeniden kullanır; soğuk açılışta tekrarlayan TLS el sıkışmalarını
/// azaltır. Uygulama ömrü boyunca yaşar — KAPATILMAZ.
final http.Client sharedFrontendClient = http.Client();
```

- [ ] **Step 2: Her repository'de deseni değiştir**

Her dosyada `import '../../core/network/frontend_http_client.dart';` (göreli yolu ayarla) ekle. Ardından:

```dart
// ÖNCE
final client = httpClient ?? http.Client();
...
} finally {
  if (httpClient == null) client.close();
}

// SONRA
final client = httpClient ?? sharedFrontendClient;
...
} finally {
  // Paylaşılan client kapatılmaz; yalnızca enjekte edilen (test) client'ı
  // çağıran taraf yönetir. Burada close çağrısı kaldırıldı.
}
```

Eğer `finally` bloğu yalnızca `if (httpClient == null) client.close();` içeriyorsa, bloğu tamamen kaldır (boş finally bırakma). Bazı dosyalarda `client.close()` farklı yerde olabilir — her dosyada yalnızca otomatik oluşturulan client'ın kapatılmasını kaldır.

Dosya listesi (her birinde `http.Client()` deseni var):
- `admin/lib/frontend/core/theme/frontend_font_settings.dart` (2 yer: 165, 238)
- `admin/lib/frontend/features/home/data/post_action_repository.dart:202`
- `admin/lib/frontend/features/home/data/home_repository.dart:93` (Task 1A'da `finally`'si var — orada `client.close()` kaldır, `sharedFrontendClient` kullan)
- `admin/lib/frontend/features/home/data/news_comments_repository.dart:96`
- `admin/lib/frontend/features/pharmacy/data/pharmacy_repository.dart:170`
- `admin/lib/frontend/features/category/data/category_repository.dart:74`
- `admin/lib/frontend/features/shell/data/app_shell_repository.dart:242`
- `admin/lib/frontend/features/obituaries/data/death_notice_repository.dart` (2 yer: 156, 182)
- `admin/lib/frontend/features/announcements/data/announcements_repository.dart:71`
- `admin/lib/frontend/features/search/data/search_repository.dart:76`
- `admin/lib/frontend/features/profile/data/profile_repository.dart` (5 yer: 160, 176, 204, 225, 268)
- `admin/lib/frontend/features/markets/data/markets_repository.dart:171`
- `admin/lib/frontend/features/prayer_times/data/prayer_times_repository.dart:194`
- `admin/lib/frontend/features/weather/data/weather_repository.dart:360`
- `admin/lib/frontend/features/account/data/frontend_auth_repository.dart:356`
- `admin/lib/frontend/features/etkinlik/data/etkinlik_repository.dart:23`

> Her dosyada değişiklik yaptıktan sonra o dosyadaki `import 'package:http/http.dart' as http;` satırının HÂLÂ kullanıldığını kontrol et (tipler için gerekli olabilir). Kullanılmıyorsa kaldır; kullanılıyorsa bırak.

- [ ] **Step 3: Tüm repository testlerini çalıştır (regresyon)**

Run: `cd admin && flutter test test/frontend/`
Expected: PASS — testler `httpClient: MockClient(...)` enjekte ediyor; paylaşılan client'a hiç düşmüyorlar, davranış değişmez.

- [ ] **Step 4: Analiz**

Run: `cd admin && flutter analyze`
Expected: Temiz. Doğrulama:
```bash
grep -rn "http.Client()" admin/lib/frontend | grep -v "_test" | grep -v "frontend_http_client.dart"
```
Expected: Çıktı boş (tek `http.Client()` artık yalnızca `frontend_http_client.dart`'ta).

- [ ] **Step 5: Commit**

```bash
git add admin/lib/frontend
git commit -m "perf(mobile): share a single keep-alive http client across repositories"
```

---

## Task 6: Anonim feed/shell yanıtlarına edge-cache başlığı

**Amaç:** Oturumsuz (anonim) `home` ve `shell` yanıtlarını Cloudflare edge'inde kısa süre cache'lemek (`s-maxage` + `stale-while-revalidate`), `Vary: Authorization` ile. Girişli (kişiye özel) yanıtlar ASLA cache'lenmez. Çoğu açılış DB yerine edge'den döner.

**Files:**
- Modify: `src/lib/server/appDb.ts:42-58` (`json` — opsiyonel cache başlığı)
- Modify: `src/pages/api/app/home.ts` (anonimse cache başlığı geç)
- Modify: `src/pages/api/app/shell.ts` (anonimse cache başlığı geç)

- [ ] **Step 1: `json()` helper'a opsiyonel cache-control ekle (varsayılan: no-store)**

`src/lib/server/appDb.ts` içindeki `json` (satır 42-58) imzasını ve gövdesini güncelle:

```typescript
export function json(
  data: any,
  status = 200,
  options: { cacheControl?: string } = {}
) {
  const isProduction = import.meta.env.PROD || process.env.NODE_ENV === 'production';
  const body = status >= 500 && isProduction && data?.error?.message
    ? { ...data, error: { ...data.error, message: 'Request failed' } }
    : data;
  const cacheControl =
    options.cacheControl || 'no-store, no-cache, must-revalidate, proxy-revalidate';
  const cdnCacheControl = options.cacheControl ? options.cacheControl : 'no-store';
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Cache-Control': cacheControl,
      'CDN-Cache-Control': cdnCacheControl,
      'Cloudflare-CDN-Cache-Control': cdnCacheControl,
      'Vary': 'Authorization',
      ...adminSecurityHeaders(),
    },
  });
}
```

> Mevcut tüm çağrılar (`json(data)`, `json(data, 500)`) imza geriye uyumlu olduğu için aynen no-store davranışını sürdürür.

- [ ] **Step 2: home.ts — anonimse cache başlığı**

`src/pages/api/app/home.ts` GET handler'ında, `const userId = session?.user?.id || null;` satırından sonra ve final `return json({...})` çağrısında: yalnızca `userId == null` ise cache uygula. Final dönüşü şu hâle getir:

```typescript
    const isAnonymous = userId === null;
    return json(
      {
        featured,
        feed,
        settings: {
          showFeaturedSection: settings.showFeaturedSection,
          commentSystem: settings.commentSystem,
          commentApprovalSystem: settings.commentApprovalSystem,
          emojiReactions: settings.emojiReactions,
          homePageSize: settings.homePageSize,
          featuredContentSource: settings.featuredSource,
          featuredSortingLogic: settings.featuredSorting,
          featuredDurationDays: settings.featuredDurationDays,
          featuredLimit: settings.featuredLimit,
        },
      },
      200,
      isAnonymous
        ? { cacheControl: 'public, s-maxage=30, stale-while-revalidate=300' }
        : {},
    );
```

> Güvenlik: Anonim yanıt `userLiked/userSaved` gibi kişiye özel alanları zaten `false`/boş içerir (token yok). `Vary: Authorization` sayesinde girişli istekler ayrı cache anahtarı kullanır; edge bunları karıştırmaz.

- [ ] **Step 3: shell.ts — anonimse cache başlığı**

`src/pages/api/app/shell.ts` oku. Eğer shell yanıtı kullanıcıya özel veri içermiyorsa (logo/menü/site ayarları — büyük ihtimalle içermez), final `json(...)` çağrısına koşulsuz `{ cacheControl: 'public, s-maxage=60, stale-while-revalidate=600' }` ekle. Eğer oturuma bağlı alan varsa, home.ts'teki gibi `isAnonymous` koşulu uygula.
Expected: shell.ts'in oturum kullanıp kullanmadığını doğrula (`getSessionFromRequest` çağrısı var mı?), buna göre koşullu/koşulsuz uygula.

- [ ] **Step 4: Derleme**

Run: `npm run wrangler:check`
Expected: Hata yok.

- [ ] **Step 5: Davranış doğrulaması — anonim cache'li, girişli no-store**

Terminal 1: `npm run dev`
Terminal 2:
```bash
echo "--- anonim ---"
curl -s -I "http://127.0.0.1:4321/api/app/home?lang=tr" | grep -i "cache-control"
echo "--- girisli (sahte token) ---"
curl -s -I -H "Authorization: Bearer fake.token.value" "http://127.0.0.1:4321/api/app/home?lang=tr" | grep -i "cache-control"
```
Expected:
- Anonim: `cache-control: public, s-maxage=30, stale-while-revalidate=300`
- Girişli: `cache-control: no-store, no-cache, must-revalidate, proxy-revalidate`

- [ ] **Step 6: Commit**

```bash
git add src/lib/server/appDb.ts src/pages/api/app/home.ts src/pages/api/app/shell.ts
git commit -m "perf(server): edge-cache anonymous home/shell responses"
```

---

## Self-Review (plan iç tutarlılığı)

- **Kapsam:** Rapordaki 7 maddenin tamamı görevlere eşlendi (yukarıdaki eşleme tablosu). P0-3/Rapor #7 (çift istek) Task 1B Step 3'te `_loadHomeData()` çağrısının kaldırılmasıyla kapatıldı.
- **Tip/imza tutarlılığı:** `fetchHome({lang, token, retries})` Task 1A'da tanımlandı; Task 1B testindeki fake repo ve `_CountingHomeRepository.fetchHome` aynı imzayı kullanıyor. `loadCachedHome({lang})` Task 1A'da tanımlandı, Task 1B'de çağrıldı. `CachedNetworkImageProvider` Task 2'de import edildi, Task 4 Step 3'te tekrar kullanıldı (aynı import). `sharedFrontendClient` Task 5'te tanımlandı.
- **Placeholder taraması:** Tüm kod adımları tam kod içeriyor; "TBD/uygun şekilde" ifadesi yok. Task 4 ve Task 6 Step 3'te dosyaya özel parametreler için "önce oku, sonra eşle" talimatı verildi (gerçek değerler dosyadan alınır) — bu, çok sayıda çağrı noktası olan dosyalar için kasıtlı ve nettir.
- **Risk notu:** Task 6 üretimde en dikkatli test edilecek olan; anonim/girişli ayrımı `Vary: Authorization` + `userId === null` koşuluyla iki katmanlı korunuyor.

---

**Plan complete and saved to `docs/superpowers/plans/2026-06-13-pateeznews-hiz-optimizasyonu.md`. İki uygulama seçeneği:**

**1. Subagent-Driven (önerilen)** — Her görev için taze subagent, görevler arası inceleme, hızlı iterasyon.

**2. Inline Execution** — Görevleri bu oturumda, kontrol noktalarıyla sırayla uygularım.

**Hangisini istersin?** (Hatırlatma: her görev tek tek test edilip onaylanacak; onaysız merge/push yok.)
