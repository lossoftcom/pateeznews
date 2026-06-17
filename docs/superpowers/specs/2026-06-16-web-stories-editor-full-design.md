# Web Stories Editör — Tam Sürüm (Tasarım / Spec)

Tarih: 2026-06-16
Branch: `feat/web-stories-editor-full`

## Amaç
Flutter admin'e gömülü Google Web Stories editörünü (`@googleforcreators/story-editor`
v0.1.202410011217) tam ekran, tam özellikli, Türkçe ve sunucuya bağlı medya kütüphaneli
hâle getirmek. Başka hiçbir yeri bozmadan.

## Mimari (mevcut, korunur)
- `admin/web_stories_editor/` — React/Vite uygulaması, `StoryEditor` + `InterfaceSkeleton`.
- Build çıktısı → `admin/assets/web_stories/` (vite, `base:'./'`).
- Flutter host: `web_stories_editor_native.dart` (WebView + `InAppLocalhostServer`),
  `web_stories_editor_web.dart` (iframe). Mesajlaşma: `PATEEZ_WS_HOST` (host→editör),
  `PATEEZ_WS_EDITOR` (editör→host); native handler `PateezWebStories`,
  `window.__pateezWsReceive`.

## Gereksinimler ve çözüm

### A. Tam ekran + kendi Kaydet + sağ üstte X
- Editör, kök navigator'da opak tam ekran route olarak açılır → admin sidebar/topbar ve
  "Hikayeler/Kaydet" alt başlığı görünmez. `dashboard_screen.dart` değişmez; yalnızca
  `stories_screen.dart`'taki açılış akışı inline state-swap yerine `Navigator.push`.
- Host app-bar kaldırılır. Editörün React `header` slotuna özel başlık: opsiyonel başlık
  alanı + **Kaydet** + en sağda **X (kapat)**.
- Kaydet → editörün `saveStory()` → mevcut `SAVE` mesajı → host `saveStoryContent`. Host
  başarı/hata için `SAVE_RESULT` ack döner; `saveStoryById` bunu bekler ki editörün native
  "kaydedildi/başarısız" toast'ı doğru görünsün.
- X → `CLOSE` mesajı → host route'u kapatır; kaydedildiyse liste yenilenir. Sistem geri
  tuşu da kapatır.

### B. Stok içerik uyarısı kalkar
- `config.showMedia3p = false` → Unsplash/üçüncü taraf sekmesi ve "subject to third party
  terms" uyarısı kaldırılır.

### C. Tam özellikler
- Medya (sunucuya bağlı): `getMedia`, `uploadMedia`, `updateMedia`, `deleteMedia`. Editör →
  host mesajı (`MEDIA_LIST`, `MEDIA_UPLOAD`, `MEDIA_UPDATE`, `MEDIA_DELETE`) → Flutter
  `MediaService` (`/api/storage/list`, `/api/storage/upload`) → sonuç `*_RESULT` olarak
  döner. Editörün beklediği resource şekli (id, type, mimeType, src, width, height,
  poster, alt) host tarafında map'lenir.
- Sayfa şablonları: `canViewDefaultTemplates = true` + `cdnURL`.
- Yazı tipleri: `getFonts` → Google Fonts kataloğu (paketlenir).
- Animasyon, metin/şekil/sticker, filtre, katman, kırpma, hizalama: çekirdek; medya + tam
  UI açılınca gelir. Önizlemede doğrulanır.
- Tümü `storyData` + AMP `markup` içinde → kaydet/aç gidiş-dönüşü korunur ve doğrulanır.

### D. Türkçe (tr_TR)
- `@googleforcreators/i18n` `setLocaleData` ile resmi tr_TR Jed çevirisi render öncesi
  yüklenir. `config.locale` + `isRTL=false`. Kısmi kapsam kabul (az string İngilizce
  kalabilir).

## Dokunulmayacak alanlar
- `posta_builder` (LOSPOSTA_*), dashboard shell, haber/diğer ekranlar, diğer repository'ler.
- Değişecekler: `admin/web_stories_editor/src/*`, `admin/web_stories_editor/package.json`,
  `stories_screen.dart` (editör açılış/kapanış), editör köprü dart dosyaları,
  yeniden üretilen `admin/assets/web_stories/`.

## Build & doğrulama
- `npm install` + `npm run build` (admin/web_stories_editor).
- Vite dev + tarayıcı önizleme ile: Türkçe UI, başlık+Kaydet+X, stok uyarısı yok,
  animasyon paneli, medya yükleme UI, şablonlar, kaydet/aç gidiş-dönüşü.

## Riskler
- Medya köprüsü en büyük kalem (resource map + auth bağlamı host'ta).
- tr_TR kapsamı kısmi olabilir.
- cdnURL sürümle uyum (şablon görselleri için) — önizlemede doğrula, gerekirse ayarla.
