# PateezNews — Flutter Admin Hız Denetim Raporu

> **Tarih:** 13 Haziran 2026
> **Kapsam:** Flutter **admin paneli** (`admin/lib/` → `app/`, `core/`, `shared/`, `features/`), admin API'leri (`src/pages/api/admin/*`, `src/pages/api/storage/*`), veritabanı erişim katmanı (`src/lib/server/*`).
> **Durum:** SADECE RAPOR — hiçbir kod değiştirilmedi. Onay bekleniyor.
> **İlgili:** Mobil **frontend** (haber okuyucu) için ayrı denetim ve plan mevcut: `docs/superpowers/plans/2026-06-13-pateeznews-hiz-optimizasyonu.md`. Bu rapor onun tamamlayıcısıdır ve **admin paneline** odaklanır.

---

## 0. Yönetici Özeti (TL;DR)

Admin paneli sağlam kurulmuş (tek paylaşılan HTTP client, auth context cache, DB connection pool, doğru indeksler). Ancak **"her sayfaya girişte yeniden yükleme"** ve **"resimler yavaş"** hislerinin somut, ölçülebilir 6 kök nedeni var:

| # | Sorun | Etki | Öncelik |
|---|-------|------|---------|
| A1 | Liste/tablo thumbnail & avatarları **tam boy orijinali** indiriyor (`?w=` yok) | 50px kutuya 2–5 MB görsel; her satır yavaş | **P0** |
| A2 | Paylaşılan kart widget'ları (`AdminMobileThumb`, `AdminMobileAvatar`) ve masaüstü haber tablosu **`Image.network`** kullanıyor → disk cache YOK, downscale YOK | Geri gelince/yeniden açınca her görsel tekrar iner; bellek şişer | **P0** |
| A3 | Sayfa geçişi dev `switch` ile her seferinde widget'ı **sıfırdan kuruyor** → her girişte yeniden fetch, state korunmuyor | "Her sayfaya girişte spinner" hissi | **P0** |
| A4 | Görsel isteği **302 redirect** zincirinden geçiyor (`/api/storage/file/...` → `.variants/...`) | Her görselde 1 ekstra round-trip | **P1** |
| A5 | Yenileme yüklemeleri **spinner ile ekranı boşaltıyor** (skeleton yok); News listesi 30 sn'de bir `_loading=true` ile **tam ekran çakması** yapıyor | Sürekli "yükleniyor" titremesi | **P1** |
| A6 | Admin API yanıtları **`no-store`** + soğuk başlangıçta **retry yok** → yavaş/kopuk ağda boş veya hatalı ekran | "İlk açılışta veri gelmiyor" | **P1** |

Ek bulgu (perf değil ama önemli): **Admin ana sayfası (`DashboardContent`) tamamen statik/sahte demo verisi gösteriyor** — gerçek metrik/yayın akışı çekmiyor.

Hiçbiri için kod değiştirilmedi. Her madde geriye dönük uyumlu, tek tek uygulanabilir ve test edilebilir şekilde aşağıda planlandı.

---

## 1. Sistem Nasıl Çalışıyor? (Doğrulanmış Mimari)

### 1.1 Açılış akışı
```
main.dart
  └─ Supabase.initialize (PKCE)              ← env varsa
  └─ kIsWeb veya masaüstü? → PateeznewsAdminApp   (mobilde → PateeznewsApp = frontend)
        └─ AdminLanguageController.loadInitial()    (diller)
        └─ AdminGate
              ├─ Supabase auth state dinle + restoreSession()
              ├─ session varsa → _preloadContentSettings()  (upload limitleri vb.)
              ├─ _checkingSession → küçük CircularProgressIndicator (tek splash)
              └─ session ? DashboardScreen : LoginScreen
```
- **Tek gerçek splash** burada: `AdminGate._checkingSession` sırasında 22px spinner. Bu hafif ve doğru.
- `admin/lib/app/admin_gate.dart:284` — oturum kontrolü bitene kadar boş ekran + spinner.

### 1.2 Dashboard (kabuk) ve sayfa yönetimi
- `DashboardScreen` (`dashboard_screen.dart`) tüm modülleri tek `enum _DashboardPage` + dev `switch` ile yönetir (~42 sayfa).
- `build()` içinde `switch (_selectedPage)` her seçimde **ilgili ekranı `const`/`new` olarak yeniden inşa eder**. `IndexedStack`/keep-alive YOK → bir sayfadan çıkıp dönünce ekran sıfırlanır, `initState` tekrar çalışır, veri **tekrar çekilir**. (`dashboard_screen.dart:1043-1266`)
- İzinler `_loadPermissions()` ile bir kez yüklenir; admin/super_admin için tek `setState`, diğer roller için 1 istek.

### 1.3 Ağ katmanı — sağlam
- **Tek paylaşılan `http.Client`** (`adminHttpClient`) → keep-alive korunuyor. (`core/network/admin_api_headers.dart:6`)
- Token: canlı Supabase session → sağlanan token → diskteki session sırasıyla. (`adminAuthHeaders`)
- Repolar `/api/admin/*` (örn. `news/list`, `news/metrics`, `news/filters`) ve generic `/api/admin/query` + `/api/storage/*` REST uçlarına gider. Sınıf adları `Supabase…` ama aslında **Astro API**'sine konuşurlar.
- Timeout'lar makul (liste 8 sn, medya 15/45/120 sn).

### 1.4 Sunucu / veritabanı — sağlam
- `supabaseDb.ts`: Hyperdrive varsa **istek-başı tek-kullanımlık client**, yoksa **global pool (max 5)**. `dbQuery` her sorguda connect→release yapar; ağır uçlar (`news/list`) sorguları `Promise.all` ile paralelleştirir. (`supabaseDb.ts:123-219`, `news/list.ts:368`)
- `adminAuth.ts`: **45 sn'lik token→context cache** (`ADMIN_CONTEXT_CACHE_TTL_MS`) → istek başına 2 DB sorgusu (profil + izinler) yerine cache. İyi tasarım. (`adminAuth.ts:26, 71-120`)
- İndeksler `veritabani.sql` dump'ında eksik görünür ama **migration'larda var ve doğru** (`migration/2026-06-11-*`, `2026-06-10-*`). DİKKAT: bu migration'ların prod Supabase'de uygulandığı doğrulanmalı.

### 1.5 Görsel servisi
- Upload anında **7 genişlikte WebP varyant** üretiliyor: `[180, 260, 800, 900, 1200, 1440, 1600]` (`imageVariants.ts:4`, `scripts/local-storage-server.mjs`).
- İstemci `MediaService.resolveImageUrl(path, width:, quality:)` ile `?w=&q=` ekleyebilir → `/api/storage/file/[...path].ts` **302** ile ya `.variants/wNNN-q86/...webp`'ye (yerel) ya da `/cdn-cgi/image/...`'e (prod Cloudflare) yönlendirir. (`[...path].ts:46-116`)
- **Medya kütüphanesi (`media_library_dialog.dart:170`) bunu doğru kullanıyor** (`width: 260`) → küçük varyant + `CachedNetworkImage`. Sorun burada DEĞİL.

---

## 2. Bulgular (Kanıtlı, Öncelikli)

### 🔴 A1 — Liste/tablo thumbnail & avatarları tam boy orijinali indiriyor
**Kanıt:**
- `news_table_card.dart:3823` → `imageUrl: thumb.isEmpty ? null : _publicUrl(thumb)`
- `users_table_card.dart:453` → `imageUrl: avatar.isEmpty ? null : _publicUrl(avatar)`
- `_publicUrl` (`news_table_card.dart:3984`) sadece path'i mutlak URL'ye çevirir; **`?w=` EKLEMEZ.**
- `?w=` olmayınca `[...path].ts:imageVariantOptions` `null` döner → **statik orijinale** redirect (tam boy).

**Etki:** 48–56px'lik bir kutuya 1500–1600px'lik (çoğu zaman MB'larca) orijinal görsel iniyor. 25 satırlık listede satır başına megabaytlar = yavaş liste, yüksek bant genişliği, yüksek bellek.

**Çözüm yönü:** Liste/tablo/kart görselleri için her zaman `resolveImageUrl(path, width: <kutu*dpr>, quality: 86)` kullan (thumb ~180/260 varyantı). Varyant zaten üretiliyor; sadece doğru genişliği istemek yeterli.

---

### 🔴 A2 — Paylaşılan kart widget'ları ve haber tablosu `Image.network` kullanıyor (cache & downscale yok)
**Kanıt:**
- `shared/widgets/admin_mobile_list.dart:853` (`AdminMobileThumb`) ve `:907` (`AdminMobileAvatar`) → ham `Image.network` (disk cache yok, `cacheWidth` yok).
- `news_table_card.dart:1841` (video thumb) ve `:2627` → `Image.network`.
- Oysa frontend'de **hazır, ideal bir bileşen var**: `frontend/shared/widgets/cached_image.dart` (`CachedNetworkImage` + `memCacheWidth` + placeholder + fadeIn). Admin bunu kullanmıyor.

**Etki:** `Image.network`'ün kalıcı disk cache'i yoktur; sayfadan çıkıp dönünce veya geri kaydırınca **her görsel ağdan tekrar iner**. `cacheWidth` verilmediği için tam çözünürlükte decode edilir → bellek şişer, kaydırma takılır.

> Not: Admin'in BÜYÜK kısmı zaten `CachedNetworkImage` kullanıyor (haber editör blokları, sosyal önizlemeler, stories, medya kütüphanesi). Sorun yalnızca yukarıdaki paylaşılan widget'lar + haber tablosu thumb'larında. Yani hedefli ve düşük riskli bir düzeltme.

**Çözüm yönü:** Admin için frontend'deki `CachedImage`'ın eşdeğeri bir `AdminCachedImage` (veya ortak paket) ekleyip `AdminMobileThumb`/`AdminMobileAvatar`/haber tablosu thumb'larında `Image.network` yerine onu kullan; `memCacheWidth = kutu*dpr` ile downscale.

---

### 🔴 A3 — Her sayfa geçişinde state sıfırlanıyor → yeniden fetch ("her girişte spinner")
**Kanıt:**
- `dashboard_screen.dart:1043-1266` — gövde `switch (_selectedPage)` ile her seçimde ekranı yeniden kurar.
- Liste ekranları `initState`'te yükler (`news_screen.dart:61-68`, diğer ekranlar aynı desen). `IndexedStack`/`AutomaticKeepAlive`/in-memory cache YOK (sadece sms/whatsapp templates IndexedStack kullanıyor, o da kendi içinde).

**Etki:** News → Comments → News dönüşünde News tüm filtre+liste isteklerini **baştan** atar; kullanıcı her geçişte spinner görür. En çok şikayet edilen "her sayfaya girerken yükleme" davranışının ana kaynağı budur.

**Çözüm yönü (iki seçenek, kademeli):**
1. **Hızlı kazanım:** Repository düzeyinde kısa ömürlü (örn. 30–60 sn) in-memory cache + "stale-while-revalidate": ekran açılır açılmaz son veriyi göster, arkada sessizce tazele.
2. **Yapısal:** Sık kullanılan ekranlar için kabukta `IndexedStack` veya sayfa-state önbelleği (ziyaret edilen ekranı canlı tut). Masaüstü görünüme dokunmadan uygulanabilir.

---

### 🟠 A4 — Görsel isteği 302 redirect zincirinden geçiyor
**Kanıt:** `[...path].ts:23-116` — `?w=` ile gelen her görsel önce endpoint'e, sonra 302 ile `.variants/...webp`'ye gider.

**Etki:** Her görsel için ekstra bir ağ round-trip'i (özellikle soğuk bağlantıda hissedilir). Frontend planında Task 0/3 bunu çözüyor (URL üreticileri doğrudan `.variants` statik yolu dönecek). Admin de aynı doğrudan-URL mantığından faydalanmalı.

**Çözüm yönü:** İstemci, `image/` ve `profile/` önekli yollar için doğrudan `.variants/wNNN-q86/...webp` URL'sini kurabilir (redirect'i atlar), ya da sunucu URL üreticileri zaten doğrudan döner (frontend Task 0/3 ile paylaşılır). En güvenlisi: ortak `imageVariants` mantığını istemciye de taşıyan tek bir yardımcı.

---

### 🟠 A5 — Yenilemeler ekranı boşaltıyor; News'te 30 sn'de bir tam-ekran çakması
**Kanıt:**
- `news_screen.dart:64-68` → `Timer.periodic(30s)` → `_loadPosts()` → `_loadPosts` **`_loading = true`** yapıyor (`:108-110`) → liste spinner'a düşer. Yani 30 saniyede bir liste **boşalıp** yeniden çiziliyor.
- `top_bar.dart:149` → 30 sn'de bir (bildirim/sayım) — bu daha hafif ama yine periyodik.
- Genelde ekranlar yükleme/yenileme sırasında skeleton yerine boş + spinner gösterir.

**Etki:** Kullanıcı listeye bakarken her yarım dakikada içerik kaybolup yeniden geliyor; "sürekli yükleniyor" hissi + gereksiz iş.

**Çözüm yönü:** Arka plan yenilemesi **sessiz** olsun (`_loading=true` yapma; yeni veri gelince yerine koy). Skeleton/shimmer placeholder ile ilk yükleme; sonraki yüklemelerde mevcut veriyi koru (stale-while-revalidate). Periyodik yenilemeyi sadece ekran görünürken çalıştır.

---

### 🟠 A6 — `no-store` + retry yok → "ilk açılışta veri gelmiyor"
**Kanıt:**
- Tüm admin yanıtları `adminJson`/`json` ile **`no-store`** (`adminAuth.ts:126-138`, `appDb.ts:42-70`). (Admin için veri tazeliği doğru tercih; ama hiç offline/önbellek emniyeti yok.)
- Repolarda **retry/backoff YOK**; hata → ekran ya hata metni (News) ya da boş gösterir.
- Soğuk başlangıçta `adminAuthHeaders` token'ı henüz Supabase restore etmeden okursa istek **kimliksiz** gidebilir → 401 → boş.
- `_preloadContentSettings` hatada sessizce defaults'a düşer (`admin_gate.dart:207`).

**Etki:** Yavaş/kopuk ağ veya soğuk başlangıçta tek bir başarısız istek = boş/hatalı ekran; otomatik toparlanma yok (kullanıcı manuel yenilemeli).

**Çözüm yönü:** Kritik GET'lere kısa **retry + exponential backoff** (örn. 2–3 deneme); token hazır olana kadar minik bekleme/yeniden deneme; ilk yüklemede mümkünse son başarılı veriyi (hafif disk snapshot) göster. Sunucu cache'i değişmeden kalabilir.

---

### ⚪ Ek bulgu — Admin ana sayfası statik sahte veri
**Kanıt:** `DashboardContent` → `PublishingPanel`/`StatusPanel`/`ResponsiveMetricGrid` tamamı `const`, **hardcoded** ("Ekonomi gündemi 09:40" vb.) (`publishing_panel.dart:6-40`). Gerçek metrik (`/api/admin/news/metrics` mevcut) çekilmiyor.

**Etki:** Perf sorunu değil, ama admin'in "home" ekranı gerçek veriyi yansıtmıyor. Karar senin: gerçek metriklere bağlanmalı mı, yoksa şimdilik böyle mi kalsın.

---

## 3. 2026 En İyi Uygulama Karşılaştırması (YouTube/Apple/Amazon nasıl yapardı)

| Konu | Şu an | 2026 standardı (hedef) |
|------|-------|------------------------|
| Görsel boyutu | Tam orijinal indiriliyor | Kutu boyutuna birebir varyant (`srcset` mantığı, DPR'a göre) — **zaten varyant üretiliyor** |
| Görsel cache | Bazı yerlerde yok (`Image.network`) | Her yerde kalıcı disk + bellek cache; downscale decode |
| Görsel teslim | 302 redirect | Doğrudan statik/CDN URL; format auto (WebP/AVIF) |
| Placeholder | Boş + spinner | Skeleton/shimmer veya BlurHash/ThumbHash |
| Liste yenileme | Ekranı boşaltan spinner | Stale-while-revalidate (eski veriyi göster, sessiz tazele) |
| Sayfa geçişi | Her seferinde yeniden kurulum | State koru (IndexedStack/keep-alive) + kısa cache |
| Soğuk başlangıç | Tek hata = boş ekran | Retry+backoff, offline snapshot |

İyi haber: Altyapının çoğu (varyantlar, paylaşılan client, auth cache, pool, indeksler) zaten 2026 seviyesinde. Eksik olan, istemcinin bunları **doğru kullanması**.

---

## 4. Önerilen Plan (Kademeli, Bozmadan)

> Sıralama riske göre düşükten yükseğe; her faz bağımsız test edilip commit edilebilir. **Masaüstü görünüme ve çalışan akışlara dokunulmaz.**

**Faz 1 — Görseller (en yüksek etki, en düşük risk)**
1. `AdminCachedImage` bileşeni (frontend `CachedImage`'ın admin eşi) veya ortak paket.
2. `AdminMobileThumb`, `AdminMobileAvatar`, `news_table_card` thumb'larını `Image.network` → `AdminCachedImage`'a geçir.
3. Liste/tablo/kart görsellerinde URL'leri `resolveImageUrl(width: kutu*dpr, quality: 86)` ile üret (A1).
4. (Opsiyonel, frontend Task 0/3 ile ortak) Doğrudan `.variants` URL'si → 302'yi atla (A4).

**Faz 2 — Yükleme deneyimi**
5. Arka plan/periyodik yenilemeyi sessizleştir (News 30 sn çakmasını kaldır) (A5).
6. İlk yüklemede skeleton/shimmer; sonraki yüklemelerde mevcut veriyi koru.

**Faz 3 — Geçiş hızı & dayanıklılık**
7. Repository'lerde kısa ömürlü in-memory cache + stale-while-revalidate (A3 hızlı kazanım).
8. Kritik GET'lere retry+backoff; soğuk başlangıç token bekleme (A6).
9. (İsteğe bağlı, daha büyük) Kabukta sık ekranlar için `IndexedStack`/keep-alive (A3 yapısal).

**Faz 4 — İsteğe bağlı**
10. Admin ana sayfasını gerçek metriklere bağla (ek bulgu).

---

## 5. Doğrulama Araçları (bu repoda mevcut)
- **Dart analiz:** `cd admin && flutter analyze` (Flutter 3.44, `/Users/nasip/development/flutter`).
- **Dart test:** `cd admin && flutter test <dosya>` — `MockClient` + `SharedPreferences.setMockInitialValues` deseni mevcut (`admin/test/frontend/home_repository_test.dart`).
- **Sunucu (TS):** birim test yok; `npm run wrangler:check` (derleme) + `npm run dev` + `curl` ile davranış.
- Görsel doğrulama: DevTools Network'te liste açıldığında inen görsel boyutları (orijinal yerine varyant olmalı) ve tekrar açışta cache'ten gelmesi.

## 6. Riskler / Dikkat Edilecekler
- **Migration doğrulaması:** `migration/2026-06-11-*` ve `2026-06-10-*` indekslerinin prod Supabase'de uygulandığını teyit et (dump eski).
- **Masaüstü görünüm:** Tüm görsel/cache değişiklikleri görünümden bağımsız; yine de her ekran `flutter analyze` ile doğrulanmalı.
- **Cache tazeliği:** İstemci in-memory cache kısa (≤60 sn) tutulmalı; admin verisi taze kalmalı.
- **Görsel varyant kapsamı:** Doğrudan `.variants` yalnızca `image/` ve `profile/` önekleri için güvenli (diğer tipler redirect'te kalmalı).

---

*Bu rapor yalnızca tespit ve plan içerir. Onayın sonrası fazları tek tek, test ederek uygularım.*
