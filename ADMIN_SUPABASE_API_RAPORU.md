# 📋 PATEEZNEWS ADMIN — Supabase & API Bağlantı Sistemi Denetim Raporu

> **Tarih:** 30 Mayıs 2026
> **Kapsam:** Sadece admin (Flutter) ↔ veritabanı/API bağlantıları
> **Bakış açısı:** Flutter + Supabase + serverless mimari
> **Hazırlayan:** Claude (Flutter/Supabase mimari incelemesi)

---

## 🎯 1. ÖNCE NET CEVAP (aptala anlatır gibi, tek paragraf)

Reis, dürüst konuşayım: **kodun kalitesi gerçekten profesyonel ve temiz** — burada sıkıntı yok. AMA sorduğun asıl soru "ışık hızında, en doğru 2026 sistemi mi?" → **Hayır, şu an değil.** Sistem çalışır ve güvenli yazılmış, ama **2026'nın "en hızlı/en doğru" Supabase mimarisi değil**. Sebebi tek cümlede: Sen Supabase'i alıp **sadece "boş bir PostgreSQL kutusu" gibi kullanıyorsun**; Supabase'in hazır verdiği (ve ışık hızında olan) şeyleri kullanmak yerine onların **bir kopyasını kendi elinle yeniden yazmışsın**. Bu yüzden mobil uygulaman veriye giderken gereksiz "ara duraklara" uğruyor.

**Puan kartı:**

| Konu | Puan | Durum |
|---|---|---|
| Kod kalitesi & temizlik | 🟢 8.5/10 | Çok iyi yazılmış |
| Mimari (2026'ya uygunluk) | 🟡 5/10 | Eski (Neon dönemi) mantık |
| Hız ("ışık hızı") | 🟡 5/10 | Gereksiz ara duraklar var |
| Güvenlik | 🟡 6/10 | 1 somut açık + 1 risk |
| Sürüm güncelliği | 🟢 9/10 | Her şey güncel |

---

## 🧭 2. SİSTEM ŞU AN NASIL ÇALIŞIYOR? (basit şema)

Admin uygulaman veriye **şöyle** ulaşıyor:

```
📱 Flutter Admin (mobil/masaüstü/web)
       │  (1) HTTP POST  →  /api/admin/query   { "table": "posts", "method": "select", ... }
       ▼
☁️ Astro Backend (Vercel'de serverless fonksiyon)
       │  (2) Her istekte: Supabase Auth'a "bu token geçerli mi?" diye SOR  ──► 🌐 Supabase Auth
       │  (3) Profil + izinleri çek (2 ayrı SQL)
       │  (4) Senin yazdığın SQL üreticisi cümleyi kurar
       ▼
🐘 PostgreSQL (Supabase) — ham `pg` sürücüsüyle, "postgres" süper kullanıcısı olarak
```

**Buradaki kilit gerçek:** Flutter, veri için Supabase'e **doğrudan gitmiyor**. Önce senin Astro backend'ine (`/api/admin/query`) gidiyor; o da Supabase'in hazır veri API'sini (PostgREST) **kullanmadan**, ham `pg` sürücüsüyle veritabanına bağlanıp **elle SQL yazıyor**.

> 🔑 **Neden böyle olmuş?** Silinmiş bir dosya gördüm: `admin/lib/features/auth/data/neon_auth_client.dart`. Yani bu proje **eskiden Neon** (başka bir Postgres servisi) kullanıyordu. Neon'da PostgREST/RLS yok, o yüzden "kendi API'mizi yazıp ham SQL atalım" mantığı doğruydu. Sonra **Supabase'e geçilmiş ama eski mantık aynen kalmış.** Sadece auth (giriş) Supabase SDK'sına taşınmış, geri kalan her şey hâlâ "Neon usulü" çalışıyor. Raporun özeti bu cümlede gizli.

**Tek istisna — giriş (auth):** Giriş kısmı doğru yapılmış. `admin/lib/main.dart` Supabase SDK'sını **PKCE** akışıyla başlatıyor, `admin/lib/features/auth/data/supabase_auth_client.dart` `signInWithPassword`'ü SDK üzerinden çağırıyor. 👍

---

## ✅ 3. İYİ OLAN ŞEYLER (önce bunları bil, güven gelsin)

Bunlar gerçekten profesyonelce yapılmış, dokunma:

1. **Temiz mimari.** `features/<özellik>/data` + `presentation` ayrımı, soyut `Repository` arayüzleri (örn. `admin/lib/features/news/data/admin_news_repository.dart`). Test edilebilir, bakımı kolay. Kitabına uygun.
2. **SQL enjeksiyonuna karşı korumalı.** SQL üreticin (`src/lib/server/supabaseQuery.ts`) değerleri **parametreli** (`$1, $2`) gönderiyor ve kolon/tablo adlarını `quoteIdent` ile regex'ten geçiriyor. Doğru yapılmış — çoğu kişi burada hata yapar, sen yapmamışsın.
3. **İzin allowlist'i var.** `src/pages/api/admin/query.ts` içinde `TABLE_RULES` ile **sadece izin verilen tablolar** sorgulanabiliyor; her tabloya/işleme göre yetki (`posts_access`, `manage_content` vb.) kontrol ediliyor. Bilinmeyen tablo → 403.
4. **Mail/SMS/WhatsApp/Social uçları korumalı.** `requireMailAccess` / `requireSmsAccess` oturumu + rolü kontrol ediyor (tek tek açıp doğruladım).
5. **Serverless farkındalığı var.** Bağlantı havuzu `globalThis`'te saklanıyor, transaction pooler (port 6543) ayarlı, havuz küçük (`max: 5`). Doğru yönde.
6. **Sürümler güncel:** Astro 6, React 19, `@supabase/supabase-js 2.106`, `supabase_flutter 2.12`, Dart 3.12, Node 24, modern `@supabase/ssr`. 2026 itibarıyla taze. 👍
7. **Medya işleme profesyonel:** `src/pages/api/storage/upload.ts` görselleri WebP'ye, videoları ffmpeg ile `+faststart` mp4'e çeviriyor, thumbnail üretiyor. Kaliteli iş.

---

## 🐢 4. HIZ SORUNLARI — "ışık hızı" neden değil? (en önemli bölüm)

### 🔴 4.1 — Her istekte Supabase Auth'a ağ çağrısı (EN BÜYÜK HIZ KAYBI)
`src/lib/server/supabaseAuth.ts` (satır 136) — `getSessionFromToken`, gelen her token için Supabase'in `/auth/v1/user` adresine **internet üzerinden HTTP isteği** atıyor. Yani admin **her tıkladığında**, backend "bu token gerçek mi?" diye Supabase'e ayrı bir tur atıyor.

**Neden ışık hızını öldürüyor:** Tek bir "haber filtreleri" ekranı 4 paralel sorgu atıyor (`admin/lib/features/news/data/admin_news_repository.dart`, satır 115) → bu da **4 kez ayrı ayrı** `/auth/v1/user` çağrısı + 4×(profil SQL + izin SQL) demek. Aynı token 4 kez boşuna doğrulanıyor.

> 💡 **2026 çözümü (kesin):** Supabase **1 Ekim 2025'ten beri yeni projelerde asimetrik JWT imza anahtarlarını** varsayılan yaptı. Bunlarla token'ı **ağa hiç çıkmadan, yerelde** (Web Crypto / `jose` kütüphanesi) doğrulayabilirsin. Tek bu değişiklik bile **her admin isteğinden bir kıtalararası tur siler.**
> Kaynak: https://supabase.com/blog/jwt-signing-keys

### 🔴 4.2 — Veriyi telefon/tarayıcı tarafında toplama (israf)
`admin/lib/features/news/data/admin_news_repository.dart` (satır 83) — istatistik için **bütün haberlerin `likes_count` sütununu** çekip Dart tarafında `fold` ile topluyorsun:
```dart
'table': 'posts', 'method': 'select', 'select': 'likes_count',  // TÜM satırlar geliyor!
```
10.000 haberin varsa, sadece toplamı bulmak için **10.000 satır** telefona iniyor. Olması gereken: veritabanında `SELECT SUM(likes_count)` → tek satır, tek sayı döner.

### 🟡 4.3 — Tek ekran için zincirleme (sequential) turlar (N+1)
- `fetchMetrics()` → 3 ayrı tur
- `fetchFilterOptions()` → 4 ayrı tur
- `fetchPosts()` → 1 ana sorgu **+ ardından** `_categoryParentsFor` **2 tur daha** (üst üste, beklemeli) → toplam 3 tur. Bunlar tek bir SQL `JOIN` ile 1 tura inebilir.

### 🟡 4.4 — Gereksiz ara durak (ekstra ağ sıçraması)
"Doğru" Supabase yolunda: `Telefon → Supabase PostgREST (DB'nin yanı başında, edge'de)` = **1 bacak**.
Sizin yolunuzda: `Telefon → Vercel fonksiyonu (soğuk başlama olabilir) → pg → Supabase DB` = **2 bacak + soğuk başlama riski**. Türkiye'deki bir admin için bu, her veri çekişinde fazladan gecikme demek.

### 🟢 4.5 — Bağlantı havuzu (küçük sorun)
`src/lib/server/supabaseDb.ts` (satır 46) `pg.Pool({ max: 5 })` transaction pooler üstünde çalışıyor. 2026 rehberi "transaction pooler kullanırken uygulama içi havuzu büyütme, Supavisor yönetsin" diyor — sizinki zaten `max:5` ile küçük, yani büyük dert değil. Sadece **prod'da gerçekten 6543'lü pooler URL'i kullanıldığından emin ol.**
Kaynak: https://supabase.com/docs/guides/database/connecting-to-postgres

---

## 🔐 5. GÜVENLİK — 1 somut açık + 1 mimari risk

### 🔴 5.1 — Storage (medya) uçları admin kontrolü YAPMIYOR (somut açık)
`/api/storage/*` altındaki **hiçbir** uç (upload, delete, list, seo-rename, seo-alt-text) `requireAdmin`/oturum kontrolü yapmıyor. `src/lib/server/supabaseStorage.ts` (satır 61) token yoksa **anon (publishable) key'e düşüyor**:
```ts
Authorization: `Bearer ${bearer || publishableKey}`
```
Yani bu uçların güvenliği **tamamen Supabase bucket RLS politikalarına** bağlı. Eğer bucket politikan gevşekse, **internetteki herhangi biri token'sız dosya yükleyebilir/silebilir/listeleyebilir.**

> ✅ **Yapılacak:** `src/pages/api/storage/upload.ts`, `delete/[...id].ts`, `list.ts`, `seo-*` uçlarının başına `requireAdminToken(...)` ekle (Mail/SMS uçlarındaki gibi). **Ayrıca** bucket RLS politikalarını kontrol et.

### 🟡 5.2 — Admin yolu RLS'i tamamen atlıyor (mimari risk)
Migration dosyalarında **117 RLS politikası** var (frontend/public tarafı için iyi). AMA admin yolu veritabanına `postgres` **süper kullanıcısı** olarak bağlanıyor — ve **süper kullanıcıda RLS çalışmaz.** Yani admin tarafında **tüm güvenlik tek bir yere**, yani uygulama katmanındaki izin kontrolüne (`requireAdminToken`) bağlı. Bir uçta o kontrolü unutursan (bkz. 5.1), **o tablo komple açığa çıkar.** "İki kat savunma" yok.

> ✅ **Önerilen (ileri seviye):** Query proxy'sini `postgres` yerine, sadece gerekli tablolara `GRANT` verilmiş **ayrı bir DB rolüyle** bağla. Böylece bir guard unutulsa bile veritabanı seni korur.

### 🟢 5.3 — Küçük notlar
- Ham DB hata mesajları istemciye dönüyor (`error.message`) — prod'da iç bilgi sızdırabilir, sadeleştir.
- 12 sn timeout mobil için uzun; 6-8 sn daha iyi.

---

## ☁️ 6. CLOUDFLARE mı VERCEL mi? (bunu mutlaka oku, kafa karışıklığı var)

Sen "Cloudflare kullanıyoruz" dedin. **Ama kodun Vercel'de çalışıyor:** `astro.config.mjs` (satır 37) `adapter: vercel()`, ayrıca `.vercel`, `vercel.json`, `vercel.env` dosyaları var. Yani **deploy Vercel.** Cloudflare muhtemelen sadece **öndeki DNS/CDN** olarak duruyor.

Bu kafa karışıklığı 2026'da daha da kritik çünkü: **Cloudflare, 16 Ocak 2026'da Astro'yu satın aldı** ve sizin kullandığınız Astro 6 artık Cloudflare'in motoru üzerine kurulu. Doğal olarak "Cloudflare'e geçelim mi?" akla geliyor. Cevap:

> ⚠️ **Backend'inizi Cloudflare Workers'a TAŞIYAMAZSINIZ** (şu hâliyle). Çünkü kullandığınız `pg` (TCP), `nodemailer`, `sharp` (native), ve `ffmpeg` (`child_process.spawn` ile harici program çalıştırma) **Cloudflare Workers'da çalışmaz.** Workers, Node.js değildir. Yani **bu Node-ağırlıklı backend için doğru tercih zaten Vercel.**
> Kaynak: https://developers.cloudflare.com/workers/framework-guides/web-apps/astro/

**Net tavsiye:**
- **Frontend (Astro, SEO sayfaları):** İstersen Cloudflare Pages'e taşınabilir (statik/edge için ideal).
- **Backend (`/api/*`, ffmpeg/mail dahil):** Vercel'de kalsın. Doğru yer.
- **Cloudflare önde CDN olarak duracaksa:** `/api/*` ve SSR yollarının **cache'lenMEdiğinden** emin ol (Cache Rules ile bypass), yoksa eski/yanlış veri servis edersin.

---

## 📊 7. MEVCUT vs 2026 İDEAL (tek bakışta karşılaştırma)

| Konu | Sende ŞU AN | 2026 İdeal | Fark |
|---|---|---|---|
| Veri okuma yolu | Flutter → Astro proxy → ham `pg` → DB | Flutter → Supabase SDK/PostgREST → DB (edge) | 1 fazla bacak |
| Güvenlik modeli | Sadece uygulama katmanı (RLS atlanıyor) | RLS (DB seviyesi) + uygulama | Çift savunma yok |
| Token doğrulama | Her istekte ağ çağrısı (`/user`) | Yerel JWT (asimetrik anahtar) | Her istekte tur israfı |
| İstatistik/sayım | İstemcide toplama (tüm satırlar) | DB'de `SUM/COUNT` | Aşırı veri transferi |
| Realtime (canlı) | Yok | Supabase Realtime (yorum/bildirim) | Eksik fırsat |
| Deploy | Vercel (Cloudflare önde CDN?) | Node backend için Vercel doğru | Tutarsız algı |

---

## 🚀 8. ÖNCELİKLİ YAPILACAKLAR (etki/emek sırasına göre)

| # | Aksiyon | Etki | Emek | Tür |
|---|---|---|---|---|
| 1 | **Storage uçlarına `requireAdminToken` ekle** + bucket RLS kontrol et | 🔥 Güvenlik açığını kapatır | Düşük | Güvenlik |
| 2 | **Asimetrik JWT'ye geç, token'ı yerelde doğrula** (`/user` çağrısını sil) | 🔥 Her istek hızlanır | Orta | Hız |
| 3 | **İstatistik/sayımları SQL'e taşı** (`SUM`, `COUNT`) | Yüksek | Düşük | Hız |
| 4 | **`fetchPosts` kategori-üst sorgusunu `JOIN`'e indir** (3 tur → 1) | Orta | Orta | Hız |
| 5 | **Token başına profil+izinleri kısa süre cache'le** | Orta | Düşük | Hız |
| 6 | Query proxy'sini süper kullanıcı yerine **kısıtlı rolle** bağla | Orta | Yüksek | Güvenlik |
| 7 | Cloudflare CDN'de `/api/*` cache **bypass** kuralı | Orta | Düşük | Doğruluk |
| 8 | DB hata mesajlarını prod'da sadeleştir, timeout'u 6-8 sn yap | Düşük | Düşük | Olgunluk |

**Tek cümlelik strateji:** Backend'i (mail/sms/ffmpeg/RBAC gerçekten lazım) **silme, Vercel'de tut** — ama yukarıdaki 1-2-3'ü yaparsan sistem hem güvenli hem "ışık hızına" çok daha yakın olur. Tüm CRUD'u Supabase SDK'ya taşımak (RLS ile) "en saf 2026" yolu olurdu ama RBAC'ını sıfırdan RLS'e çevirmek demek — **şu an gereksiz büyük risk.** Önce ucuz ve yüksek etkili düzeltmeler.

---

## 📚 9. KAYNAKLAR (2026 doğrulaması)

- Supabase ile Flutter — resmî rehber: https://supabase.com/docs/guides/getting-started/quickstarts/flutter
- Flutter Authorization with RLS — Supabase Blog: https://supabase.com/blog/flutter-authorization-with-rls
- JWT Signing Keys (asimetrik, yerel doğrulama): https://supabase.com/blog/jwt-signing-keys · https://supabase.com/docs/guides/auth/signing-keys
- Connecting to Postgres / Supavisor pooling: https://supabase.com/docs/guides/database/connecting-to-postgres
- Supabase Connection String: Ports & Pooling (2026): https://www.weweb.io/blog/supabase-connection-string-guide-ports-pooling
- Astro Framework 2026: Astro 6 & Cloudflare: https://alexbobes.com/programming/a-deep-dive-into-astro-build/
- Astro on Cloudflare Workers: https://developers.cloudflare.com/workers/framework-guides/web-apps/astro/
- Astro on Vercel — resmî: https://vercel.com/docs/frameworks/frontend/astro

---

## 📂 10. İNCELENEN ANA DOSYALAR (kanıt listesi)

| Dosya | Rolü |
|---|---|
| `admin/lib/main.dart` | Supabase SDK başlatma (PKCE) |
| `admin/lib/features/auth/data/supabase_auth_client.dart` | Giriş + oturum (SDK + API hibrit) |
| `admin/lib/features/auth/data/admin_session_store.dart` | Token'ı SharedPreferences'ta saklama |
| `admin/lib/core/network/admin_api_headers.dart` | İstek header'ları (Bearer token) |
| `admin/lib/features/news/data/admin_news_repository.dart` | Veri çekme deseninin tipik örneği |
| `src/pages/api/admin/query.ts` | Generic sorgu ucu + izin allowlist |
| `src/lib/server/supabaseQuery.ts` | Elle yazılmış SQL üretici (PostgREST kopyası) |
| `src/lib/server/supabaseDb.ts` | `pg` bağlantı havuzu |
| `src/lib/server/adminAuth.ts` | Token + profil + izin kontrolü |
| `src/lib/server/supabaseAuth.ts` | Token doğrulama (`/auth/v1/user` ağ çağrısı) |
| `src/lib/server/supabaseStorage.ts` | Storage istemcisi (auth boşluğu burada) |
| `astro.config.mjs` | Vercel adapter (Cloudflare değil) |

---

*Bu rapor sadece admin (Flutter) ↔ veritabanı/API bağlantılarını kapsar. Frontend (Astro/SEO) ve public uçları ayrı bir incelemenin konusudur.*
