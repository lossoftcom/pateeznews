# Flutter Admin Hız Optimizasyonu — Uygulama Planı

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Flutter **admin panelini** (`admin/lib/features/`, `admin/lib/shared/`) — tüm modüller, tüm sayfalar, tüm görseller ve yükleme akışları dahil — "ışık hızı resim + her sayfaya girişte yeniden yükleme yok + soğuk başlangıçta boş ekran yok" hedefine taşımak; çalışan hiçbir özelliği ve masaüstü görünümü bozmadan.

**Architecture:** Üç katman: (1) **Görsel** — tek paylaşılan `AdminCachedImage` (kalıcı disk + bellek cache + downscale) + tek `adminImageUrl()` yardımcısı (her zaman doğru genişlikte WebP varyant ister); ham `Image.network` ve 5 kopya `_publicUrl` tasfiye edilir. (2) **Yükleme deneyimi** — arka plan yenilemesi sessizleşir (spinner çakması biter), ilk yükleme skeleton gösterir. (3) **Geçiş & dayanıklılık** — repository düzeyinde kısa ömürlü cache (stale-while-revalidate) + kritik GET'lerde retry/backoff. Her görev geriye dönük uyumlu ve bağımsız test edilebilir.

**Tech Stack:** Flutter (Dart 3.12), `cached_network_image: ^3.4.1` (zaten pubspec'te), `http` (paylaşılan `adminHttpClient`), `flutter_animate` (shimmer için opsiyonel). Sunucu tarafı zaten varyant üretiyor (`scripts/local-storage-server.mjs`, `src/lib/server/imageVariants.ts`); bu plan **yalnızca istemci** (Dart) tarafına dokunur.

---

## Rapor maddeleri → Plan görevleri eşlemesi

Kaynak rapor: `docs/2026-06-13-flutter-admin-hiz-raporu.md`

| Rapor # | Konu | Plan görevi |
|---------|------|-------------|
| A2 | `Image.network` → disk cache yok | Task 1 (widget) + Task 3–12 (uygulama) |
| A1 | Thumb/avatar tam-orijinal (`?w=` yok) | Task 2 (yardımcı) + Task 3–6 |
| A4 | 302 redirect | Task 2 notu (disk cache ile hafifler; opsiyonel server Task) |
| A5 | 30 sn spinner çakması / boşaltan yenileme | Task 13–14 |
| A3 | Her geçişte yeniden fetch | Task 15–16 |
| A6 | `no-store` + retry yok → ilk açılış boş | Task 17 |
| Ek | Admin home statik | Task 18 (opsiyonel) |

**Önerilen uygulama sırası:** Task 1 → 2 → 3 → 4 → 5 → 6 (Faz 1, en yüksek etki) → 7–12 (Faz 2) → 13–14 (Faz 3) → 15–17 (Faz 4) → 18 (opsiyonel).

## Doğrulama araçları (bu repoda mevcut)

- **Dart statik analiz:** `cd admin && flutter analyze` (Flutter 3.44, `/Users/nasip/development/flutter`). Her görevde çalıştır; 0 hata beklenir.
- **Dart birim/widget testi:** `cd admin && flutter test <dosya>` — mevcut desen: `MockClient` + `SharedPreferences.setMockInitialValues` (bkz. `admin/test/frontend/home_repository_test.dart`).
- **Görsel manuel doğrulama:** `npm run dev` ile sunucu; admin'i aç, DevTools/Network'te (a) liste açılınca inen görsellerin **orijinal değil varyant** (`.variants/wNNN`) olduğunu, (b) sayfadan çıkıp dönünce görsellerin **ağdan tekrar inmediğini** (disk cache) gör.
- **Commit:** Her görev sonunda küçük, odaklı commit. Co-Authored-By satırını ekle.

> **DİKKAT (her iki rapordan ortak):** Prod'a çıkmadan `migration/2026-06-11-mobile-home-performance-indexes.sql`, `migration/2026-06-10-mobile-comments-admin-flow.sql`, `migration/2026-06-11-mobile-search-vector.sql` dosyalarının canlı Supabase'de uygulandığını doğrula (indeksler `veritabani.sql` dump'ında yok).

---

## Dosya Yapısı (oluşturulacak / değiştirilecek)

**Oluşturulacak:**
- `admin/lib/shared/widgets/admin_cached_image.dart` — Tüm admin için tek görsel bileşeni (kalıcı disk + bellek cache, downscale, placeholder, fadeIn). Sorumluluk: ağ görseli render'ı.
- `admin/lib/shared/data/admin_image_url.dart` — Tek `adminImageUrl(path, {width, quality})` yardımcısı. Sorumluluk: storage yolunu doğru varyant URL'sine çevirmek (5 kopya `_publicUrl`'ün yerini alır).
- `admin/lib/shared/data/admin_request_retry.dart` — `withAdminRetry()` küçük retry/backoff sarmalayıcı. Sorumluluk: geçici ağ hatalarında yeniden deneme.
- Test: `admin/test/shared/admin_image_url_test.dart`, `admin/test/shared/admin_request_retry_test.dart`.

**Değiştirilecek (özet — tam liste ilgili görevlerde):**
- `admin/lib/shared/widgets/admin_mobile_list.dart` (Task 3)
- `admin/lib/features/news/presentation/widgets/news_table_card.dart` (Task 4, 7)
- `admin/lib/features/users/presentation/widgets/users_table_card.dart` (Task 5)
- `admin/lib/features/comments/presentation/widgets/comments_table_card.dart` (Task 5)
- `admin/lib/features/stories/presentation/stories_screen.dart` (Task 6)
- `admin/lib/features/dashboard/presentation/widgets/user_avatar_menu.dart` (Task 6)
- `admin/lib/features/news/presentation/widgets/article_*_block.dart` (Task 7)
- `admin/lib/features/news/presentation/news_add_screen.dart` (Task 8)
- `admin/lib/shared/widgets/media_library_dialog.dart` (Task 9)
- `admin/lib/features/social/presentation/previews/*_preview.dart`, `social_preview_panel.dart` (Task 10)
- `admin/lib/features/settings/presentation/{general,announcements}_settings_screen.dart`, `account/presentation/account_settings_screen.dart` (Task 11)
- `admin/lib/features/news/presentation/news_screen.dart` (Task 13)
- Repository sınıfları (Task 15–17)

---

## FAZ 1 — Görseller: paylaşılan altyapı + Kategori A (liste/kart/avatar)

### Task 1: `AdminCachedImage` paylaşılan bileşeni

**Amaç:** Frontend'deki `admin/lib/frontend/shared/widgets/cached_image.dart` ile aynı kalitede, admin için tek görsel bileşeni. Kalıcı disk cache + bellek cache + downscale (`memCacheWidth`) + placeholder + fadeIn. Tüm `Image.network` çağrıları buna geçecek.

**Files:**
- Create: `admin/lib/shared/widgets/admin_cached_image.dart`

- [ ] **Step 1: Bileşeni oluştur**

Create `admin/lib/shared/widgets/admin_cached_image.dart`:

```dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Diske kalıcı cache'lenen ağ görseli (admin paneli geneli).
///
/// Ham `Image.network` yerine bunu kullan: görsel bir kez iner, geri kaydırınca
/// veya sayfa yeniden açılınca ağdan tekrar inmez. `cached_network_image`
/// üstüne ince sarmalayıcı; frontend'deki `CachedImage`'ın admin eşi.
class AdminCachedImage extends StatelessWidget {
  const AdminCachedImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.memCacheWidth,
    this.placeholderColor = AppColors.surface,
    this.errorWidget,
    this.fadeIn = true,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;

  /// Görseli bu piksel genişliğinde decode et (bellek tasarrufu). Eski
  /// `cacheWidth`/`Image.network(cacheWidth:)` karşılığı.
  final int? memCacheWidth;

  /// İnerken/boşken gösterilecek düz zemin rengi.
  final Color placeholderColor;

  /// Görsel inmezse gösterilecek widget. Verilmezse düz [placeholderColor].
  final Widget? errorWidget;

  /// Liste hücrelerinde kısa fade; tek görsellerde de kullanılabilir.
  final bool fadeIn;

  @override
  Widget build(BuildContext context) {
    final cacheWidth = (memCacheWidth != null && memCacheWidth! > 0)
        ? memCacheWidth
        : null;
    return CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: cacheWidth,
      filterQuality: FilterQuality.medium,
      fadeInDuration: Duration(milliseconds: fadeIn ? 180 : 0),
      fadeOutDuration: Duration(milliseconds: fadeIn ? 120 : 0),
      placeholder: (context, _) => Container(color: placeholderColor),
      errorWidget: (context, _, _) =>
          errorWidget ?? Container(color: placeholderColor),
    );
  }
}
```

- [ ] **Step 2: Analiz et**

Run: `cd admin && flutter analyze lib/shared/widgets/admin_cached_image.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add admin/lib/shared/widgets/admin_cached_image.dart
git commit -m "feat(admin): add shared AdminCachedImage (disk+mem cache, downscale)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: `adminImageUrl()` tek yardımcısı (genişlikli varyant + DRY)

**Amaç:** Storage yolunu **her zaman doğru genişlikte** WebP varyant URL'sine çeviren tek fonksiyon. `news_table_card`, `users_table_card`, `comments_table_card`, `stories_screen`, `user_avatar_menu` içindeki 5 kopya `_publicUrl`'ün yerini alır (DRY). Genişlik geçildiğinde `MediaService.resolveImageUrl`'e (zaten `?w=&q=` ekliyor) delege eder; geçilmezse mevcut davranış (tam yol) korunur.

**Files:**
- Create: `admin/lib/shared/data/admin_image_url.dart`
- Test: `admin/test/shared/admin_image_url_test.dart`

- [ ] **Step 1: Testi yaz (önce başarısız)**

Create `admin/test/shared/admin_image_url_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pateeznews_admin/shared/data/admin_image_url.dart';

void main() {
  test('http(s)/data url olduğu gibi döner', () {
    expect(adminImageUrl('https://x/y.png'), 'https://x/y.png');
    expect(adminImageUrl('data:image/png;base64,AAAA'),
        'data:image/png;base64,AAAA');
  });

  test('boş değer boş döner', () {
    expect(adminImageUrl(''), '');
    expect(adminImageUrl('   '), '');
  });

  test('genişlik verilince ?w= ve ?q= ekler', () {
    final url = adminImageUrl('image/2026/foo.png', width: 180);
    expect(url, contains('w=180'));
    expect(url, contains('q=86'));
  });
}
```

- [ ] **Step 2: Çalıştır, başarısız olduğunu gör**

Run: `cd admin && flutter test test/shared/admin_image_url_test.dart`
Expected: FAIL — `admin_image_url.dart` yok / `adminImageUrl` tanımlı değil.

- [ ] **Step 3: Yardımcıyı yaz**

Create `admin/lib/shared/data/admin_image_url.dart`:

```dart
import 'media_service.dart';

/// Storage yolunu görüntülenebilir URL'ye çevirir.
///
/// - `http`, `https`, `data:` ile başlayan değerler olduğu gibi döner.
/// - [width] verilirse, o genişlikteki WebP varyantı istenir (sunucu
///   `?w=&q=` ile en yakın varyanta yönlendirir). Liste/kart/avatar gibi
///   küçük görsellerde MUTLAKA bir genişlik geç — yoksa tam-boy orijinal iner.
/// - [width] verilmezse mevcut davranış: tam çözünürlüklü yol.
///
/// `features/**` içindeki 5 kopya `_publicUrl` bununla değiştirilir (DRY).
String adminImageUrl(String value, {int? width, int quality = 86}) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';
  if (trimmed.startsWith('http://') ||
      trimmed.startsWith('https://') ||
      trimmed.startsWith('data:')) {
    return trimmed;
  }
  return MediaService().resolveImageUrl(
    trimmed,
    width: width,
    quality: width != null ? quality : null,
  );
}
```

> NOT: `MediaService.resolveImageUrl` zaten `_resolve()` ile platforma göre taban URL'yi (web/Android emülatör/iOS) çözüyor; `_publicUrl`'ün yaptığı işin aynısı + genişlik. Yani davranış genişlik geçilmediğinde birebir korunur.

- [ ] **Step 4: Çalıştır, geçtiğini gör**

Run: `cd admin && flutter test test/shared/admin_image_url_test.dart`
Expected: PASS (3 test).

- [ ] **Step 5: Analiz + Commit**

```bash
cd admin && flutter analyze lib/shared/data/admin_image_url.dart
git add admin/lib/shared/data/admin_image_url.dart admin/test/shared/admin_image_url_test.dart
git commit -m "feat(admin): add adminImageUrl helper (width-correct variant, DRY)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

> **A4 (302 redirect) notu:** Task 1 disk cache'i sayesinde redirect her görsel için cihaz başına yalnızca BİR kez yaşanır (sonrası diskten gelir), bu yüzden A4 düşük önceliğe iner. Doğrudan `.variants` URL'si istemek istenirse, bu yardımcıya ileride `imageVariants.ts` mantığının Dart eşi eklenebilir; bu ayrı ve opsiyonel bir görevdir (riski: yalnızca `image/`/`profile/` önekleri için güvenli).

---

### Task 3: Paylaşılan kart widget'ları — `AdminMobileThumb` & `AdminMobileAvatar`

**Amaç:** Bu iki widget **18 ekran** tarafından kullanılıyor (comments, mail, news, pages, sms, social, stories, subscribers, users, whatsapp...). Tek düzeltme hepsine yayılır. Ham `Image.network` → `AdminCachedImage` (disk cache + downscale).

**Files:**
- Modify: `admin/lib/shared/widgets/admin_mobile_list.dart:853` (`AdminMobileThumb`), `:907` (`AdminMobileAvatar`)

- [ ] **Step 1: Import ekle**

`admin_mobile_list.dart` üst importlarına ekle:

```dart
import 'admin_cached_image.dart';
```

- [ ] **Step 2: `AdminMobileThumb` içindeki `Image.network`'ü değiştir**

`:853` civarındaki bloğu:

```dart
              : Image.network(
                  url,
                  width: size,
                  height: size,
                  fit: fit,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (context, _, _) => Center(
                    child: SymbolIcon(
                      fallbackIcon,
                      color: AppColors.iconMuted,
                      size: size * 0.4,
                    ),
                  ),
                )),
```

şununla değiştir:

```dart
              : AdminCachedImage(
                  url: url,
                  width: size,
                  height: size,
                  fit: fit,
                  memCacheWidth: (size * MediaQuery.devicePixelRatioOf(context))
                      .round(),
                  placeholderColor: AppColors.surface,
                  errorWidget: Center(
                    child: SymbolIcon(
                      fallbackIcon,
                      color: AppColors.iconMuted,
                      size: size * 0.4,
                    ),
                  ),
                )),
```

- [ ] **Step 3: `AdminMobileAvatar` içindeki `Image.network`'ü değiştir**

`:907` civarındaki `Image.network(url, ...)` bloğunu, baş-harf `Text`'i `errorWidget` olarak veren `AdminCachedImage`'a çevir:

```dart
          : AdminCachedImage(
              url: url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              memCacheWidth: (size * MediaQuery.devicePixelRatioOf(context))
                  .round(),
              errorWidget: Text(
                initials,
                style: TextStyle(
                  fontSize: size * 0.36,
                  fontWeight: FontWeight.w700,
                  color: AppColors.deepOcean,
                ),
              ),
            ),
```

- [ ] **Step 4: Analiz**

Run: `cd admin && flutter analyze lib/shared/widgets/admin_mobile_list.dart`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add admin/lib/shared/widgets/admin_mobile_list.dart
git commit -m "perf(admin): cache+downscale thumbs/avatars in shared mobile cards

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

> NOT: Bu widget'lara gelen `imageUrl` çağıranlarda genişlikle üretilecek (Task 4–6). Genişlik düzeltmesi olmadan da disk cache + downscale tek başına büyük kazanç.

---

### Task 4: Haber listesi/tablosu thumbnail'leri (`news_table_card.dart`)

**Amaç:** Haber thumb'larını (a) doğru genişlikte varyant iste (`adminImageUrl(width:)`), (b) ham `Image.network` → `AdminCachedImage`. Yerel kopya `_publicUrl` → paylaşılan `adminImageUrl`.

**Files:**
- Modify: `admin/lib/features/news/presentation/widgets/news_table_card.dart`
  - `:1841` video thumb (`Image.network(_publicUrl(thumb))`)
  - `:2627` (`Image.network(_publicUrl(url))`)
  - `:3823` `AdminMobileThumb(imageUrl: _publicUrl(thumb))` → genişlik ekle
  - `:3984` yerel `_publicUrl` tanımı → kaldır, importla değiştir

- [ ] **Step 1: Importları düzenle**

Üst importlara ekle:

```dart
import '../../../../shared/data/admin_image_url.dart';
import '../../../../shared/widgets/admin_cached_image.dart';
```

- [ ] **Step 2: `:3823` mobil kart thumb'ına genişlik ver**

```dart
                imageUrl: thumb.isEmpty ? null : adminImageUrl(thumb, width: 180),
```

(`AdminMobileThumb` zaten Task 3'te downscale + cache yapıyor; burada amaç tam-orijinal yerine 180px varyantı indirmek.)

- [ ] **Step 3: `:1841` video thumb'ını değiştir**

`Image.network(_publicUrl(thumb), ...)` → `AdminCachedImage(url: adminImageUrl(thumb, width: 360), ...)`. Mevcut `width/height/fit/errorBuilder` parametrelerini `AdminCachedImage` karşılıklarına taşı (`errorBuilder` → `errorWidget`).

- [ ] **Step 4: `:2627` görselini değiştir**

Aynı desen: `Image.network(_publicUrl(url), ...)` → `AdminCachedImage(url: adminImageUrl(url, width: 720), ...)`. (Bu daha büyük bir önizleme; 720 uygundur.)

- [ ] **Step 5: Yerel `_publicUrl`'ü kaldır**

`:3984`'teki `String _publicUrl(String value) { ... }` fonksiyonunu sil. Kalan `_publicUrl(...)` çağrıları (örn. `:2224` link açma) `adminImageUrl(...)` ile değiştir (link açmada genişlik geçme: `adminImageUrl(widget.url.trim())`).

- [ ] **Step 6: Analiz + Commit**

```bash
cd admin && flutter analyze lib/features/news/presentation/widgets/news_table_card.dart
git add admin/lib/features/news/presentation/widgets/news_table_card.dart
git commit -m "perf(admin): news list thumbnails use cached width-correct variants

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 5: Kullanıcı & yorum tablosu avatarları

**Amaç:** Avatarları küçük varyant + cache yap. `users_table_card.dart` ve `comments_table_card.dart` içindeki `_publicUrl` → `adminImageUrl(..., width: 96)` ve `Image.network` → `AdminCachedImage`.

**Files:**
- Modify: `admin/lib/features/users/presentation/widgets/users_table_card.dart` (`:453` AdminMobileAvatar imageUrl, `:1549` Image.network, `:2149` `_publicUrl` tanımı)
- Modify: `admin/lib/features/comments/presentation/widgets/comments_table_card.dart` (`:434` AdminMobileAvatar imageUrl, `:1511` Image.network, `:2175` `_publicUrl` tanımı)

- [ ] **Step 1: users_table_card importları**

```dart
import '../../../../shared/data/admin_image_url.dart';
import '../../../../shared/widgets/admin_cached_image.dart';
```

- [ ] **Step 2: users_table_card `:453` avatar genişliği**

```dart
                imageUrl: avatar.isEmpty ? null : adminImageUrl(avatar, width: 96),
```

- [ ] **Step 3: users_table_card `:1549` Image.network → AdminCachedImage**

`Image.network(_publicUrl(avatarUrl), ...)` bloğunu `AdminCachedImage(url: adminImageUrl(avatarUrl, width: 96), memCacheWidth: ..., errorWidget: <mevcut baş harf/ikon>)` ile değiştir.

- [ ] **Step 4: users_table_card `:2149` yerel `_publicUrl`'ü sil**

- [ ] **Step 5: comments_table_card için Step 1–4'ün aynısını uygula** (`:434`, `:1511`, `:2175`)

comments importları:

```dart
import '../../../../shared/data/admin_image_url.dart';
import '../../../../shared/widgets/admin_cached_image.dart';
```

comments `:434`:

```dart
                imageUrl: avatar.isEmpty ? null : adminImageUrl(avatar, width: 96),
```

comments `:1511` `Image.network(_publicUrl(avatarUrl), ...)` → `AdminCachedImage(url: adminImageUrl(avatarUrl, width: 96), ...)`; `:2175` yerel `_publicUrl`'ü sil.

- [ ] **Step 6: Analiz + Commit**

```bash
cd admin && flutter analyze lib/features/users/presentation/widgets/users_table_card.dart lib/features/comments/presentation/widgets/comments_table_card.dart
git add admin/lib/features/users/presentation/widgets/users_table_card.dart admin/lib/features/comments/presentation/widgets/comments_table_card.dart
git commit -m "perf(admin): user/comment avatars use cached small variants

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 6: Stories ekranı + üst-bar avatar menüsü

**Amaç:** Stories medya kartları ve top-bar kullanıcı avatarı için cache + genişlik. `_publicUrl` → `adminImageUrl`, `Image.network` → `AdminCachedImage`.

**Files:**
- Modify: `admin/lib/features/stories/presentation/stories_screen.dart` (`:618` AdminMobileThumb imageUrl, `:1539` Image.network, `:2703` `_publicUrl`; `:232` link açma — genişliksiz `adminImageUrl`)
- Modify: `admin/lib/features/dashboard/presentation/widgets/user_avatar_menu.dart` (`:136` Image.network, `:156` `_publicUrl`)

- [ ] **Step 1: stories_screen importları + değişiklikler**

```dart
import '../../../shared/data/admin_image_url.dart';
import '../../../shared/widgets/admin_cached_image.dart';
```

- `:618` → `imageUrl: media.isEmpty ? null : adminImageUrl(media, width: 360)` (story önizleme kartı orta boy).
- `:1539` `Image.network(_publicUrl(url), ...)` → `AdminCachedImage(url: adminImageUrl(url, width: 720), ...)` (büyük önizleme).
- `:232` `openNewsLink(_publicUrl(mediaUrl))` → `openNewsLink(adminImageUrl(mediaUrl))` (link açma; genişlik yok).
- `:2703` yerel `_publicUrl`'ü sil.

- [ ] **Step 2: user_avatar_menu importları + değişiklik**

```dart
import '../../../../shared/data/admin_image_url.dart';
import '../../../../shared/widgets/admin_cached_image.dart';
```

- `:136` `Image.network(_publicUrl(avatarUrl), ...)` → `AdminCachedImage(url: adminImageUrl(avatarUrl, width: 96), memCacheWidth: ..., errorWidget: <mevcut baş harf>)`.
- `:156` yerel `_publicUrl`'ü sil.

- [ ] **Step 3: Analiz + Commit**

```bash
cd admin && flutter analyze lib/features/stories/presentation/stories_screen.dart lib/features/dashboard/presentation/widgets/user_avatar_menu.dart
git add admin/lib/features/stories/presentation/stories_screen.dart admin/lib/features/dashboard/presentation/widgets/user_avatar_menu.dart
git commit -m "perf(admin): stories + topbar avatar use cached width-correct variants

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

> **Faz 1 sonu — kontrol:** `cd admin && flutter analyze` (tüm proje) → 0 hata. `npm run dev` + admin'i aç → News/Users/Comments/Stories listelerinde görsellerin küçük varyant indirdiğini ve sayfa geçişlerinde diskten geldiğini doğrula. Kategori A bitti.

---

## FAZ 2 — Görseller: Kategori B (editör/blok) + Kategori C (sosyal önizleme)

> Bu görsellerin çoğu zaten doğru genişlikte varyant istiyor (`resolveImageUrl(width:720/360)`) **ama disk cache'i yok** (ham `Image.network`). Tek değişiklik: `Image.network` → `AdminCachedImage`, mevcut `cacheWidth` değerini `memCacheWidth`'e taşı. Genişlik mantığına dokunma.

### Task 7: Haber editör blokları (`article_*_block.dart`)

**Amaç:** 14 blok widget'ında `Image.network` → `AdminCachedImage`. Her birinde mevcut `cacheWidth: N` → `memCacheWidth: N`; mevcut `errorBuilder` → `errorWidget`; URL üreten `_resolvedImageUrl` çağrıları (zaten `resolveImageUrl(width:)` döndüğü için) korunur.

**Files (her birinde import + Image.network değişimi):**
- `article_before_after_block.dart:571, :924`
- `article_slider_image_block.dart:584`
- `article_vs_block.dart:608`
- `article_image_block.dart:517`
- `article_audio_block.dart:1063`
- `quiz_result_block.dart:555`
- `article_event_block.dart:1381`
- `poll_question_block.dart:1198`
- `article_recipe_block.dart:1054`
- `article_table_of_contents_block.dart:1042`
- `article_video_block.dart:864, :1328`
- `article_review_block.dart:640`
- `quiz_question_block.dart:613`
- `article_flipcard_block.dart:623, :826`

- [ ] **Step 1: Her dosyaya import ekle**

```dart
import '../../../../shared/widgets/admin_cached_image.dart';
```

- [ ] **Step 2: Tek desen — `Image.network` → `AdminCachedImage` (her blokta birebir aynı dönüşüm)**

Önce (tipik):

```dart
Image.network(
  imageUrl,                 // çoğunlukla _resolvedImageUrl(...) = resolveImageUrl(width:720)
  fit: BoxFit.cover,
  cacheWidth: 720,
  errorBuilder: (context, _, _) => <fallback>,
)
```

Sonra:

```dart
AdminCachedImage(
  url: imageUrl,
  fit: BoxFit.cover,
  memCacheWidth: 720,       // mevcut cacheWidth değerini birebir taşı
  errorWidget: <fallback>,
)
```

> Her blok için `cacheWidth` değeri farklı olabilir (`360`, `720`, `1100`); o dosyadaki **mevcut** değeri `memCacheWidth`'e taşı. `cacheWidth` olmayan blokta (`article_audio_block:1063`, `article_video_block`) `memCacheWidth` verme (varsayılan null) — davranış korunur, sadece disk cache eklenir. `width/height/loadingBuilder` gibi mevcut parametreleri `AdminCachedImage`'ın karşılıklarına taşı; karşılığı olmayan `loadingBuilder` zaten `placeholder` ile karşılanır (kaldır).

- [ ] **Step 3: Analiz (tüm bloklar)**

Run: `cd admin && flutter analyze lib/features/news/presentation/widgets/`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add admin/lib/features/news/presentation/widgets/article_*_block.dart admin/lib/features/news/presentation/widgets/quiz_*_block.dart admin/lib/features/news/presentation/widgets/poll_question_block.dart
git commit -m "perf(admin): article editor blocks use disk-cached images

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 8: Haber ekleme/düzenleme ekranı (`news_add_screen.dart`)

**Amaç:** Editördeki 7 `Image.network` (`:8024, :10784, :10820, :11239, :11509, :13015, :13755`) → `AdminCachedImage`. URL üreten yerler zaten `resolveImageUrl(width:720)` kullanıyor (`:7752, :12979, :13706`); `:3189` ve `:11044` genişliksiz `resolveImageUrl` çağrıları — küçük önizleme ise genişlik ekle (`width: 720`).

**Files:**
- Modify: `admin/lib/features/news/presentation/news_add_screen.dart`

- [ ] **Step 1: Import ekle**

```dart
import '../../../shared/widgets/admin_cached_image.dart';
```

- [ ] **Step 2: 7 `Image.network`'ü `AdminCachedImage`'a çevir**

Task 7'deki birebir aynı desen: `cacheWidth` → `memCacheWidth`, `errorBuilder` → `errorWidget`. Mevcut genişlik değerlerini koru.

- [ ] **Step 3: Genişliksiz URL'lere genişlik ekle**

`:3189` `resolveImageUrl(raw)` → `resolveImageUrl(raw, width: 720, quality: 90)` (büyük önizleme ise); `:11044` çağrısına da uygun bir `width` ver (o noktadaki kutu boyutuna göre, ör. avatar/küçükse 96, içerik görseliyse 720).

- [ ] **Step 4: Analiz + Commit**

```bash
cd admin && flutter analyze lib/features/news/presentation/news_add_screen.dart
git add admin/lib/features/news/presentation/news_add_screen.dart
git commit -m "perf(admin): news editor screen uses disk-cached images

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 9: Medya kütüphanesi (`media_library_dialog.dart`)

**Amaç:** Grid zaten `resolveImageUrl(width:260)` + `CachedNetworkImage` (iyi). Ama dosyada 6 ham `Image.network` daha var (`:1536, :1590, :2216, :3507, :3562, :4163` — büyük önizleme/seçim panelleri). Bunları `AdminCachedImage`'a çevir. URL üreten `:370`, `:494` genişliksiz `resolveImageUrl` ise uygun genişlik ekle (büyük önizleme `width: 1200`).

**Files:**
- Modify: `admin/lib/shared/widgets/media_library_dialog.dart`

- [ ] **Step 1: Import ekle**

```dart
import 'admin_cached_image.dart';
```

- [ ] **Step 2: 6 `Image.network` → `AdminCachedImage`** (Task 7 deseni).

- [ ] **Step 3: `:370`, `:494` genişliksiz `resolveImageUrl` çağrılarına büyük önizleme genişliği ekle** (`width: 1200, quality: 86`).

- [ ] **Step 4: Analiz + Commit**

```bash
cd admin && flutter analyze lib/shared/widgets/media_library_dialog.dart
git add admin/lib/shared/widgets/media_library_dialog.dart
git commit -m "perf(admin): media library previews use disk-cached images

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 10: Sosyal medya önizlemeleri (`previews/*_preview.dart` + panel)

**Amaç:** 14 platform önizlemesi + `social_preview_panel.dart` dış URL görselleri gösteriyor (`Image.network`). Dış URL'ler için varyant yok; sadece disk cache + makul `memCacheWidth` ekle. URL'ler dış olduğu için `adminImageUrl` GEREKMEZ — sadece widget swap.

**Files (her birinde import + `Image.network` → `AdminCachedImage`):**
- `previews/google_business_preview.dart:188`, `mastodon_preview.dart:96`, `pinterest_preview.dart:44`, `discord_preview.dart:165`, `facebook_preview.dart:134`, `bluesky_preview.dart:101`, `slack_preview.dart:194`, `linkedin_preview.dart:107`, `threads_preview.dart:115`, `instagram_preview.dart:109`, `reddit_preview.dart:166`, `tiktok_preview.dart:29`, `youtube_preview.dart:38`, `twitter_preview.dart:120`, `widgets/social_preview_panel.dart:359`

- [ ] **Step 1: Her dosyaya import**

```dart
import '../../../../shared/widgets/admin_cached_image.dart';
```
(panel için derinlik: `../../../../shared/widgets/admin_cached_image.dart` — yola göre ayarla.)

- [ ] **Step 2: `Image.network(url, ...)` → `AdminCachedImage(url: url, memCacheWidth: <kutu*dpr veya 720>, errorWidget: <mevcut fallback>)`** her dosyada.

- [ ] **Step 3: Analiz + Commit**

```bash
cd admin && flutter analyze lib/features/social/presentation/
git add admin/lib/features/social/presentation/
git commit -m "perf(admin): social previews use disk-cached images

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 11: Ayar ekranları + hesap ekranı

**Amaç:** Kalan `Image.network`'ler: `general_settings_screen.dart:1708, :1908` (logo/favicon önizleme), `announcements_settings_screen.dart:1239, :1623, :1946` (kaynak/öğe görselleri), `account_settings_screen.dart:777, :818` (avatar önizleme). → `AdminCachedImage`. Storage yolu olanlara `adminImageUrl(width:)`, dış URL olanlara doğrudan.

**Files:**
- `admin/lib/features/settings/presentation/general_settings_screen.dart`
- `admin/lib/features/settings/presentation/announcements_settings_screen.dart`
- `admin/lib/features/account/presentation/account_settings_screen.dart`

- [ ] **Step 1: Importlar** (`admin_cached_image.dart` + gerekiyorsa `admin_image_url.dart`).
- [ ] **Step 2: `Image.network` → `AdminCachedImage`** (Task 7 deseni). Logo/avatar gibi storage görsellerinde URL'yi `adminImageUrl(path, width: <önizleme kutusu>)` ile üret; dış URL ise doğrudan ver.
- [ ] **Step 3: Analiz + Commit**

```bash
cd admin && flutter analyze lib/features/settings/presentation/general_settings_screen.dart lib/features/settings/presentation/announcements_settings_screen.dart lib/features/account/presentation/account_settings_screen.dart
git add admin/lib/features/settings/presentation/general_settings_screen.dart admin/lib/features/settings/presentation/announcements_settings_screen.dart admin/lib/features/account/presentation/account_settings_screen.dart
git commit -m "perf(admin): settings/account previews use disk-cached images

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

> **Faz 2 sonu — kontrol:** `cd admin && flutter analyze` (tüm proje) → 0 hata. `grep -rn "Image.network" admin/lib/features admin/lib/shared` → **boş** (frontend hariç tüm admin görselleri artık cache'li). Kategori B+C bitti.

---

## FAZ 3 — Yükleme deneyimi (spinner çakması yok)

### Task 12: News listesi sessiz arka plan yenilemesi (A5)

**Amaç:** `news_screen.dart`'taki 30 sn periyodik yenileme artık ekranı **boşaltmasın**. Yeni bir `_refreshing` bayrağı ekle; periyodik/arka plan yüklemesi `_loading=true` yapmasın, yalnızca veri gelince yerine koysun. İlk yükleme ve kullanıcı kaynaklı yenileme `_loading` kullanmaya devam etsin.

**Files:**
- Modify: `admin/lib/features/news/presentation/news_screen.dart` (`:46` `_loading`, `:64` timer, `:107-131` `_loadPosts`)

- [ ] **Step 1: Sessiz yenileme metodu ekle**

`_loadPosts()`'un yanına, `_loading`'e dokunmayan bir varyant ekle:

```dart
  Future<void> _refreshPostsSilently() async {
    try {
      final result = await _fetchPosts();
      if (!mounted) return;
      setState(() {
        _posts = result.posts;
        _totalCount = result.totalCount;
        _selectedPostIds.removeWhere(
          (id) => !_posts.any((post) => post.id == id),
        );
        _errorText = null;
      });
    } catch (_) {
      // Arka plan yenilemesi sessizdir; mevcut liste korunur.
    }
  }
```

- [ ] **Step 2: Periyodik timer'ı sessiz yenilemeye bağla**

`:64`:

```dart
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      unawaited(_refreshPostsSilently());
    });
```

- [ ] **Step 3: Analiz**

Run: `cd admin && flutter analyze lib/features/news/presentation/news_screen.dart`
Expected: `No issues found!`

- [ ] **Step 4: Manuel doğrula**

`npm run dev` → News listesini aç, 30+ sn bekle. Liste **boşalmamalı/spinner'a düşmemeli**; veri sessizce güncellenmeli.

- [ ] **Step 5: Commit**

```bash
git add admin/lib/features/news/presentation/news_screen.dart
git commit -m "perf(admin): silent background refresh on news list (no spinner flash)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 13: Liste boş/yükleme durumu — skeleton (opsiyonel, düşük risk)

**Amaç:** İlk yüklemede çıplak spinner yerine kart iskeleti (shimmer) göster. `flutter_animate` zaten pubspec'te. `AdminMobileListView`'in `loading` durumunu skeleton placeholder'a çevir (tek yerde — tüm 18 ekrana yayılır).

**Files:**
- Modify: `admin/lib/shared/widgets/admin_mobile_list.dart` (`AdminMobileListView` loading dalı)

- [ ] **Step 1:** `AdminMobileListView`'in `loading == true` dalında, mevcut `CircularProgressIndicator` yerine 4–6 adet gri kart placeholder (sabit yükseklikli `Container`'lar) döndür; `flutter_animate`'in `.animate(onPlay:..).shimmer()` efektini ekle.
- [ ] **Step 2:** Analiz + manuel: ilk yüklemede iskelet görünmeli.
- [ ] **Step 3:** Commit.

> NOT: Bu görsel bir iyileştirme; davranışı değiştirmez. Riski düşük ama istenirse atlanabilir.

---

## FAZ 4 — Geçiş hızı + dayanıklılık

### Task 14: Repository kısa-ömürlü cache (stale-while-revalidate) (A3)

**Amaç:** Sayfa geçişinde ekran sıfırlanıp yeniden fetch ettiğinde, son veri **anında** gösterilsin, arka planda tazelensin. Genel bir küçük cache yardımcısı + en çok ziyaret edilen ekranlarda (News list/filters, Comments, Users) uygulama.

**Files:**
- Create: `admin/lib/shared/data/admin_memory_cache.dart`
- Test: `admin/test/shared/admin_memory_cache_test.dart`
- Modify: ilgili repository'ler (önce `admin_news_repository.dart`)

- [ ] **Step 1: Testi yaz (önce başarısız)**

Create `admin/test/shared/admin_memory_cache_test.dart`:

```dart
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
}
```

- [ ] **Step 2: Çalıştır, başarısız gör**

Run: `cd admin && flutter test test/shared/admin_memory_cache_test.dart` → FAIL (sınıf yok).

- [ ] **Step 3: Cache'i yaz**

Create `admin/lib/shared/data/admin_memory_cache.dart`:

```dart
/// Oturum-içi, kısa ömürlü bellek cache'i. Sayfa geçişlerinde son veriyi
/// anında gösterip arka planda tazelemek (stale-while-revalidate) için.
class AdminMemoryCache<T> {
  AdminMemoryCache({this.ttl = const Duration(seconds: 45)});

  final Duration ttl;
  final Map<String, _Entry<T>> _store = {};

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

  void clear() => _store.clear();
}

class _Entry<T> {
  _Entry(this.value, this.expiresAt);
  final T value;
  final DateTime expiresAt;
}
```

- [ ] **Step 4: Çalıştır, geçtiğini gör**

Run: `cd admin && flutter test test/shared/admin_memory_cache_test.dart` → PASS.

- [ ] **Step 5: News repository'ye uygula (örnek)**

`admin_news_repository.dart`'ta `fetchFilterOptions()` ve `fetchPosts(...)` sonuçlarını anahtara (filtre+sayfa) göre `static final AdminMemoryCache` ile sakla. Ekran tarafı (`news_screen._loadAll`) önce cache'ten anlık göster, ardından `_refreshPostsSilently()` ile tazele. (Sunucu yanıtı değişmez; cache yalnızca istemci-içi ve kısa ömürlü.)

- [ ] **Step 6: Analiz + Commit**

```bash
cd admin && flutter analyze lib/shared/data/admin_memory_cache.dart lib/features/news/data/admin_news_repository.dart
git add admin/lib/shared/data/admin_memory_cache.dart admin/test/shared/admin_memory_cache_test.dart admin/lib/features/news/data/admin_news_repository.dart admin/lib/features/news/presentation/news_screen.dart
git commit -m "perf(admin): stale-while-revalidate cache for news list/filters

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

> Aynı desen sırayla Comments, Users, Pages, Subscribers repository'lerine genişletilebilir (her biri ayrı küçük commit). Önce News ile doğrula.

---

### Task 15: Kabukta state koruma — `IndexedStack`/keep-alive (A3 yapısal, opsiyonel)

**Amaç:** En sık kullanılan ekranlar bir kez yüklendikten sonra geçişte canlı kalsın (initState tekrar çalışmasın). `dashboard_screen.dart`'taki `switch` gövdesini en sık ekranlar için `IndexedStack` ile sar (ziyaret edileni canlı tut). Masaüstü/mobil görünüm değişmez.

**Files:**
- Modify: `admin/lib/features/dashboard/presentation/dashboard_screen.dart:1043-1266`

- [ ] **Step 1:** Sık ekranlar (home, news, comments, users) için `IndexedStack(index: _activeIndex, children: [...])` deseni; nadir ayar ekranları `switch`'te kalabilir (lazy). Yalnızca ziyaret edilen ekranı inşa etmek için "lazy IndexedStack" (ziyaret edilince doldur) kullan.
- [ ] **Step 2:** Analiz + manuel: News→Comments→News geçişinde News'in **yeniden yüklenmediğini** doğrula.
- [ ] **Step 3:** Commit.

> NOT: Bu, Task 14'e göre daha büyük bir yapısal değişiklik. Task 14 (cache) çoğu "her girişte spinner" şikayetini zaten çözer; bu görev en akıcı sonucu verir ama opsiyoneldir ve dikkatli test ister.

---

### Task 16: Kritik GET'lerde retry + backoff (A6)

**Amaç:** Soğuk/yavaş başlangıçta tek başarısız istek = boş ekran sorununu bitir. Geçici hatalarda 2–3 kez yeniden dene.

**Files:**
- Create: `admin/lib/shared/data/admin_request_retry.dart`
- Test: `admin/test/shared/admin_request_retry_test.dart`
- Modify: repository GET yardımcıları (önce `admin_news_repository.dart` `_getJson`/`_postJson`)

- [ ] **Step 1: Testi yaz (önce başarısız)**

Create `admin/test/shared/admin_request_retry_test.dart`:

```dart
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
}
```

- [ ] **Step 2:** Run → FAIL.

- [ ] **Step 3: Yardımcıyı yaz**

Create `admin/lib/shared/data/admin_request_retry.dart`:

```dart
import 'dart:async';

/// Geçici ağ/sunucu hatalarında üstel geri-çekilmeli yeniden deneme.
/// Soğuk başlangıçta tek hatanın ekranı boşaltmasını engeller.
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
```

- [ ] **Step 4:** Run → PASS (2 test).

- [ ] **Step 5:** Repository GET'lerini sar. `admin_news_repository.dart` içinde `fetchMetrics/fetchFilterOptions/fetchPosts`'un ağ çağrılarını `withAdminRetry(() => _getJson(...))` ile sar. Yalnızca **idempotent GET/list** çağrılarına uygula; yazma (POST/DELETE) işlemlerine UYGULAMA (çift işlem riski).

- [ ] **Step 6: Analiz + Commit**

```bash
cd admin && flutter analyze lib/shared/data/admin_request_retry.dart lib/features/news/data/admin_news_repository.dart
git add admin/lib/shared/data/admin_request_retry.dart admin/test/shared/admin_request_retry_test.dart admin/lib/features/news/data/admin_news_repository.dart
git commit -m "fix(admin): retry idempotent reads to avoid empty cold-start screens

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

> Aynı sarmalama diğer repository'lerin GET'lerine genişletilebilir (ayrı commit'ler).

---

## FAZ 5 — Opsiyonel

### Task 17: Admin ana sayfasını gerçek metriklere bağla (ek bulgu)

**Amaç:** `DashboardContent`/`PublishingPanel`/`StatusPanel`/`ResponsiveMetricGrid` şu an statik sahte veri gösteriyor. `GET /api/admin/news/metrics` (mevcut) ve gerekiyorsa yeni uçlardan gerçek veriyi çek. **Bu bir hız görevi değil**; kullanıcı onayına bağlı kapsam.

**Files:** `admin/lib/features/dashboard/presentation/widgets/{responsive_metric_grid,publishing_panel,status_panel}.dart` (StatelessWidget → StatefulWidget + repository).

- [ ] Karar: Bu ekran gerçek veriye bağlansın mı? Onay sonrası ayrı plan/görev. (Şimdilik kapsam dışı bırakılabilir.)

---

## Self-Review (plan ↔ rapor kapsamı)

- **A1 (tam-orijinal):** Task 2 (`adminImageUrl` width) + Task 4–6 + 8–11. ✅
- **A2 (Image.network cache yok):** Task 1 (widget) + Task 3–11 (tüm `Image.network` siteleri; Faz 2 sonu grep boş olmalı). ✅
- **A3 (her geçişte fetch):** Task 14 (cache, hızlı) + Task 15 (IndexedStack, yapısal). ✅
- **A4 (302 redirect):** Task 2 notu (disk cache ile hafifler; doğrudan-varyant opsiyonel). ✅ (bilinçli düşük öncelik)
- **A5 (spinner çakması):** Task 12 (sessiz yenileme) + Task 13 (skeleton). ✅
- **A6 (no-store + retry yok):** Task 16 (retry). ✅
- **Ek (statik home):** Task 17 (opsiyonel). ✅

**Tip tutarlılığı:** `AdminCachedImage` (url, width, height, fit, memCacheWidth, placeholderColor, errorWidget, fadeIn) — tüm görevlerde aynı imza. `adminImageUrl(value, {width, quality})` — tüm görevlerde aynı imza. `AdminMemoryCache<T>(ttl).{get,set,clear}` ve `withAdminRetry(action, {maxAttempts, initialDelay})` — tanım ve kullanım eşleşiyor.

**Placeholder taraması:** Faz 2'deki tekrarlı `Image.network`→`AdminCachedImage` siteleri "tek desen" olarak bir kez tam kod ile verildi; mekanik ve birebir aynı dönüşüm olduğundan her site için kod tekrarı yerine dosya:satır + uygulanacak genişlik listelendi. Yeni mantık içeren tüm görevler (Task 1, 2, 12, 14, 16) tam kod içerir.

---

*Bu plan yalnızca uygulama rehberidir. Onayınla, seçtiğin yürütme moduyla (subagent-driven veya inline) görev-görev, her adımda `flutter analyze`/test doğrulayarak uygularım.*
