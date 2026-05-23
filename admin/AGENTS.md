Pateeznews admin kuralları ve özellikleri

Çalışma kuralları:
- Çalışan hiçbir sistem bozulmayacaktır.
- Verilen talimatların dışına çıkılmayacaktır.
- Yalnızca güncellenmesi gereken alan güncellenecektir.
- Gereksiz dosya, fonksiyon, özellik veya sistem değişikliği yapılmayacaktır.
- Sorunun kaynağı anlaşılmadan kod değişikliği yapılmayacaktır.
- Tahmin, yama, halüsinasyon ve yüzeysel çözüm yasaktır.
- Her değişiklikten sonra ilgili akışın başka bir yeri bozup bozmadığı kontrol edilecektir.
- Değişiklikler nokta atışı, kontrollü ve minimum etkili yapılacaktır.
- Analiz ve test süreci gereksiz uzatılmayacak; hızlı, net ve kanıta dayalı ilerlenilecektir.
- Görsel verilmişse piksel detayları, mevcut tasarım dili ve ilgili kod birlikte incelenecektir.
- Tarayıcı veya canlı UI denemesi kullanıcı açıkça istemedikçe yapılmayacaktır; varsayılan doğrulama terminal üzerinden yapılacaktır.

Mimari kurallar:
- `main.dart` sadece uygulama girişini başlatacaktır.
- Ekranlar, tema, shared widgetlar, ikonlar ve veri yardımcıları ayrı modül dosyalarında tutulacaktır.
- Tek dosyada büyüyen ekran veya widget yığılması yapılmayacaktır.
- Auth, dashboard, shared ve core parçaları kendi klasörlerinde kalacaktır.
- Yeni özellik eklenirken önce mevcut modül sınırı bulunacak, sonra yalnızca ilgili modül genişletilecektir.
- Yeni sayfa veya widget yazılırken önce mevcut tema, radius, renk, font, ikon ve cursor kuralları kullanılacaktır.

Tasarım dili:
- Tüm radius değerleri kesinlikle 4 olacaktır.
- Geçişli renk kullanılmayacaktır.
- Tasarım sade, soft, beyaz ağırlıklı, profesyonel ve 2026 modern admin panel dilinde olacaktır.
- Başlıklar dahil hiçbir görünür metinde tüm kelime büyük harf yapılmayacaktır.
- Görünen metinlerde cümle düzeni korunacak; sadece gerektiği yerde baş harf büyük olacaktır.
- Kartlar, inputlar, menüler ve butonlar net çizgili, düşük kontrastlı ve temiz görünmelidir.
- Gereksiz hero, tanıtım, ekstra panel veya süsleme eklenmeyecektir.
- Ayarlar ve modül ayar sayfalarında üst yapı aynı ritimde olacaktır: sayfa başlığı solda, varsa kısa açıklama altında, `Ayarları Dili` seçimi başlık bloğunun altında solda, tab butonları bunun altında, ana içerik kartı tam genişlikte devam edecektir.
- Ayarlar ve modül ayar sayfalarındaki tab butonları `Genel Ayarlar` sayfasındaki tab standardını aynen kullanacaktır: 38 yükseklik, 13 font, 4 radius, aktif durumda `Aksiyon kırmızısı`, pasif durumda beyaz yüzey/yumuşak çizgi; tablarda ikon veya seçili tik kullanılmayacaktır.
- Projede switch gerekiyorsa native büyük switch kullanılmayacaktır; küçük, 4 radius/soft çizgi diline uyumlu, aktif durumda `Aksiyon kırmızısı` ve tik işaretli kompakt switch kullanılacaktır.
- Modal pencereler tüm modüllerde aynı standartta olacaktır: beyaz yüzey, 4 radius, soft overlay, başlık solda, kapatma ikonu sağda, footer sağda; ikincil buton metni `İptal`, birincil kaydet butonu `Derin okyanus` arka planlı `Kaydet` olacaktır. Modallarda `Vazgeç` metni ve kırmızı kaydet butonu kullanılmayacaktır.
- Modal içindeki yazı giriş alanlarında tıklama, hover veya focus sırasında gri arka plan oluşmayacaktır; `filled` kullanılacaksa sadece açıkça gerekli kutulu yüzeylerde kalacak, varsayılan modal inputları şeffaf kalacaktır.
- Modal inputlarında metin/placeholder ile alt çizgi veya input sınırı arasında gereksiz dikey boşluk bırakılmayacaktır; alt çizgili alanlarda kompakt `contentPadding` kullanılacak, focus çizgisi proje destek grisi `#95A5A6` dilinde kalacaktır.
- Onay pencereleri tüm modüllerde ortak `lib/shared/widgets/app_confirmation_dialog.dart` içindeki `showAppConfirmationDialog` ile açılacaktır; silme ve toplu silme dahil yeni onay akışlarında özel modal yazılmayacaktır.

Renk paleti:
- Derin okyanus: `#2C3E50`
- Yüzey: `#F8F9FA`
- Aksiyon kırmızısı: `#EA4335`
- Sıcak ufuk: `#F39C12`
- Destek gri: `#95A5A6`
- Çizgi: `#E6ECEE`
- Yumuşak çizgi: `#F0F3F4`
- Placeholder ve yardımcı metinler soluk gri ailede kalacaktır.

Font sistemi:
- Runtime internet font isteği yapılmayacaktır.
- Metin fontu yerel Google Fonts variable font asset üzerinden çalışacaktır.
- Aktif metin font ailesi `PateezInter` olacaktır.
- San Francisco ailesi fallback olarak korunacaktır: `SF Pro Display`, `SF Pro Text`, `San Francisco`.
- Flutter resmi font asset yöntemi kullanılacaktır: fontlar `pubspec.yaml` içindeki `flutter.fonts` alanından bağlanacaktır.
- Yazı ağırlıkları variable font üzerinden doğal çalışmalıdır; gereksiz ayrı font dosyası eklenmeyecektir.

İkon sistemi:
- İkonlarda Google Material Symbols Outlined kullanılacaktır.
- Runtime internet ikon/font isteği yapılmayacaktır.
- Material Symbols yerel subset font olarak kullanılacaktır: `assets/fonts/material_symbols/MaterialSymbolsOutlinedSubset.ttf`.
- İkon codepoint tanımları `lib/shared/icons/symbols.dart` içinde tutulacaktır.
- `material_symbols_icons` paketi geri eklenmeyecektir.
- Material Symbols ayarları her ikon için `fill 0`, `weight 100`, `grade 100`, `opticalSize 20` olacaktır.
- Yeni ikon gerektiğinde önce Google Material Symbols Outlined icon adı ve codepoint doğrulanacaktır.
- Yeni ikon için `symbols.dart` içine yerel `IconData` eklenecek, sonra subset font sadece gereken codepointler ile yeniden üretilecektir.
- Yeni ikon eklenince `flutter analyze`, `flutter test` ve gerekiyorsa ilgili platform build doğrulanacaktır.

Input kuralları:
- Placeholder örnekleri Flutter'ın native `hintText` özelliği ile verilecektir.
- Label metinleri Flutter'ın native `labelText` özelliği ile verilecektir.
- Placeholder ve label metinleri ince ve soluk olacaktır.
- Kullanıcının yazdığı gerçek input metni soluk olmayacaktır; normal okunur koyu metin rengi kullanılacaktır.
- `TextFormField.style` kesinlikle placeholder rengine bağlanmayacaktır.
- Focus durumunda border, label ve yardımcı görsel dil soft kalacaktır.
- E-posta ve şifre alanlarında örnek metin placeholder olarak kalacak; kayıtlı veya yazılmış değer normal metin gibi görünecektir.

Mouse pointer kuralı:
- Tıklanabilir olan her şey hover sırasında mouse pointer gösterecektir.
- Button, IconButton, TextButton, FilledButton, InkWell, GestureDetector, DropdownButton, dropdown menü itemleri, avatar, sidebar itemleri ve input tıklama alanları bu kurala dahildir.
- Sadece dışarı `MouseRegion` koymak yeterli değildir; widget'ın kendi `mouseCursor` özelliği varsa ayrıca `SystemMouseCursors.click` verilecektir.
- Yeni tıklanabilir kontrol eklenirse cursor kuralı eklenmeden iş bitmiş sayılmayacaktır.

Login özellikleri:
- Login ekranında sadece giriş formu bulunacaktır.
- Login ekranında ek panel, istatistik, tanıtım veya dashboard parçası bulunmayacaktır.
- Giriş butonu metni `Giriş yap` olacaktır.
- `Beni hatırla` animasyonlu çalışacaktır.
- `Beni hatırla` açıkken e-posta ve şifre yerel olarak kaydedilecek, sonraki açılışta forma yüklenecektir.
- `Beni hatırla` kapatıldığında kayıtlı bilgiler temizlenecektir.
- Enter tuşu giriş butonuyla aynı submit akışını çalıştıracaktır.
- Şifre göster/gizle ikonlu olacaktır.
- Login auth hataları genel alert kutusu olarak gösterilmeyecektir; e-posta ve şifre inputlarının altında ince, kırmızı ve düşük ağırlıklı hata metni olarak görünecektir.
- Login ekranında `Şifremi unuttum` bağlantısı gösterilmeyecektir.

Dashboard özellikleri:
- Giriş başarılı olduğunda sadece dashboard ekranı açılacaktır.
- Dashboard tam genişlik kullanacak ve responsive olacaktır.
- Dashboard içinde sol sidebar ve üst appbar bulunacaktır.
- Sidebar'da `Ana Sayfa` ve açılır `Ayarlar` ana menüsü bulunacaktır.
- `Ayarlar` altında `Dil Ayarları` alt menüsü bulunacaktır.
- Sidebar alt menü seçimi kutulu olmayacak; seçili alt menü sağında `Aksiyon kırmızısı` renginde ince dikey çizgiyle belirtilecektir.
- Sidebar ana menüsü seçili olduğunda mevcut soft yüzey ve ince çizgi dili korunacaktır.
- Appbar başlıksızdır; arama alanı sola yaslıdır.
- Appbar sağında sırasıyla site görüntüle ikonu, dil seçimi, bildirim ikonu ve daire avatar bulunacaktır.
- Appbar ve kullanıcı tablosu avatarları gerçek daire olarak kırpılacak, görselde iç boşluk bırakılmayacak ve avatar border rengi proje destek grisi `#95A5A6` olacaktır.
- Avatar hover/tap ile profil menüsü açacaktır.
- Avatar menüsünde sadece iconlu `Profil` ve `Çıkış` seçenekleri bulunacaktır.
- Avatar menüsü dışarı tıklanınca kapanacaktır.

Dil ayarları ekranı:
- `Dil Ayarları` ekranı proje stilinde sade, soft, beyaz ağırlıklı ve tablo odaklı olacaktır.
- Üst araç çubuğunda kayıt adedi seçimi solda; arama alanı ve aksiyon butonları sağa yaslı tek grup olarak duracaktır.
- Kayıt adedi, arama alanı ve üst aksiyon butonları aynı yükseklik standardında olacaktır.
- Tabloda son kolon başlığı `İşlem` olacaktır.
- Tablo satırındaki `Varsayılan`, `Çevirileri Düzenle`, `Dili Dışa Aktar` ve `Aktif` kontrolleri aynı yükseklik dilinde olacaktır.
- `Aktif` rozeti soft yeşil yazı/nokta ile gösterilecektir.
- Tablo kalan dikey alanı dolduracak; birkaç satırdan sonra kart erken bitmeyecektir.

Flutter dil sistemi:
- Flutter admin varsayılan çevirileri tek dosyada tutulmayacaktır.
- Varsayılan kaynak çeviri dosyaları `lib/core/localization/admin_translations/tr.dart`, `en.dart` ve `ar.dart` içinde ayrı tutulacaktır.
- `lib/core/localization/admin_locale_maps.dart` yalnızca eski importlar için uyumluluk exportu olarak kalacaktır; içine çeviri map'i eklenmeyecektir.
- Çeviri registry, fallback merge ve key normalizasyonu `lib/core/localization/admin_translations.dart` içinde yönetilecektir.
- Uygulama kodunda ve Dil Ayarları JSON import/export akışında çeviri anahtarları İngilizce olacaktır.
- Eski Türkçe veya eski literal anahtarlar yalnızca `legacy_key_aliases.dart` üzerinden geriye dönük uyumluluk için normalize edilecektir; yeni geliştirmede buraya yeni anahtar eklemek yerine doğrudan İngilizce key kullanılacaktır.
- Dil Ayarları ekranındaki çeviri düzenleme listesinde namespaced keyler önce gösterilecek, legacy literal keyler sadece uyumluluk için arkada kalacaktır.
- Admin panelinden eklenen yeni runtime diller Neon `languages` ve `language_translations` kayıtlarıyla çalışacaktır; derlenmiş Flutter uygulaması çalışma anında Dart kaynak dosyası üretemez.
- Kaynak kod fallback dili eklenecekse yeni `<code>.dart` çeviri dosyası oluşturulacak ve `admin_translations.dart` registry'sine aynı değişiklikte eklenecektir.
- Dil sistemi değişikliğinden sonra `dart format`, `flutter analyze` ve `flutter test` çalıştırılmadan iş bitmiş sayılmayacaktır.

Menü ve açılır kart kuralları:
- Üç nokta gibi satır aksiyon menüleri `PopupMenuButton` ile yapılmayacaktır.
- Satır aksiyon menüleri appbar avatar menüsüyle aynı mimaride kurulacaktır: `OverlayEntry`, `CompositedTransformTarget`, `CompositedTransformFollower`, dışarı tıklayınca kapanan overlay ve kart widgetı.
- Açılır kart üç nokta tetikleyicisinin hemen altında açılacaktır.
- Açılır kartlarda gereksiz ayırıcı çizgi kullanılmayacaktır; avatar menüsündeki gibi beyaz yüzey, 4 radius, ince border, soft gölge, iconlu satırlar ve click cursor kullanılacaktır.
- Üç nokta ve tablo başlıklarındaki tıklanabilir/sıralanabilir alanlar hover sırasında click cursor gösterecektir.

Doğrulama kuralları:
- Her değişiklikten sonra en az `flutter analyze` ve `flutter test` çalıştırılacaktır.
- Font/icon veya platform asset değişikliğinde ilgili platform buildleri terminalden doğrulanacaktır.
- Web için yerel fontların `build/web/assets/FontManifest.json` içine girdiği kontrol edilecektir.
- Kullanıcı istemedikçe tarayıcı, simulator canlı çalıştırma veya görsel deneme yapılmayacaktır.
