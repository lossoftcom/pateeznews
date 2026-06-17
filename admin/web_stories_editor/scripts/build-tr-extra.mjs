// Generates src/i18n/tr-extra.json: Turkish for every string the official tr_TR
// catalog left untranslated. Keyed by the editor's exact msgid (context kept via
// the EOT separator). Values are [tr, tr] so both singular and plural lookups
// resolve to Turkish. URLs / symbols / pure-format strings map to themselves.
import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const EOT = '';
const untranslatedKeys = JSON.parse(
  readFileSync(new URL('/tmp/untranslated.json', 'file:///'), 'utf8')
);

// English source -> Turkish. Placeholders (%s, %d, %1$s, %%) and HTML tags are
// preserved verbatim.
const T = {
  '%1$d of %2$d page': 'Sayfa %1$d / %2$d',
  '%1$s and %2$s should always be updated together.':
    '%1$s ve %2$s her zaman birlikte güncellenmelidir.',
  '%1$s ‹ %2$s': '%1$s ‹ %2$s',
  '%1$s: %2$s': '%1$s: %2$s',
  '%d Revision': '%d Düzeltme',
  '%d%%': '%d%%',
  '%s Copy': '%s Kopya',
  '%s added to page': '%s sayfaya eklendi',
  '%s is currently working on this story, which means you cannot make changes, unless you take over.':
    '%s şu anda bu hikaye üzerinde çalışıyor; devralmadığınız sürece değişiklik yapamazsınız.',
  '%s removed': '%s kaldırıldı',
  '<a>Learn how to get one</a>.': '<a>Nasıl edinebileceğinizi öğrenin</a>.',
  '<a>Learn more</a> about using headings in stories.':
    'Hikayelerde başlık kullanımı hakkında <a>daha fazla bilgi edinin</a>.',
  '<a>Update your settings now</a>.': '<a>Ayarlarınızı şimdi güncelleyin</a>.',
  '<b>Note: </b>If Site Kit is active, it will be used to set up Google Analytics by default. However, you can customize the behavior in case you need more flexibility.':
    '<b>Not: </b>Site Kit etkinse, Google Analytics varsayılan olarak onunla kurulur. Daha fazla esneklik gerekirse bu davranışı özelleştirebilirsiniz.',
  '<lkbd>%s</lkbd> <span>+ arrow keys</span>': '<lkbd>%s</lkbd> <span>+ ok tuşları</span>',
  'A font with the name %s already exists.': '%s adında bir yazı tipi zaten var.',
  'A font with this name already exists': 'Bu adda bir yazı tipi zaten var',
  'A new version of the plugin is available. <a>Please update now</a>.':
    'Eklentinin yeni bir sürümü mevcut. <a>Lütfen şimdi güncelleyin</a>.',
  'AM or PM': 'ÖÖ veya ÖS',
  'API connection status': 'API bağlantı durumu',
  'Access floating toolbar': 'Kayan araç çubuğuna eriş',
  'Activate <a>WooCommerce</a> to easily add shoppable products to Web Stories.':
    'Web Hikayelerine alışveriş yapılabilir ürünleri kolayca eklemek için <a>WooCommerce</a>’u etkinleştirin.',
  'Add %s': '%s ekle',
  'Add Font': 'Yazı Tipi Ekle',
  'Add an image, video or template to get started':
    'Başlamak için bir resim, video veya şablon ekleyin',
  'Add and manage your custom and brand fonts via link here. They’ll appear in your font list in the editor.':
    'Özel ve marka yazı tiplerinizi buradan bağlantıyla ekleyip yönetin. Editördeki yazı tipi listenizde görünürler.',
  'Add as background': 'Arka plan olarak ekle',
  'Add content': 'İçerik ekle',
  'Add new text': 'Yeni metin ekle',
  'Add to Saved Colors': 'Kayıtlı Renklere ekle',
  Added: 'Eklendi',
  'All Authors': 'Tüm Yazarlar',
  'Alphabetical: A-Z': 'Alfabetik: A-Z',
  'Alphabetical: Z-A': 'Alfabetik: Z-A',
  'Always hide': 'Her zaman gizle',
  'Analytics Type': 'Analiz Türü',
  'Animations Disabled': 'Animasyonlar Devre Dışı',
  'Animations on the first page of a story are not supported for user experience and performance reasons.':
    'Hikayenin ilk sayfasındaki animasyonlar, kullanıcı deneyimi ve performans nedeniyle desteklenmez.',
  'Apply preset: %s': 'Hazır ayarı uygula: %s',
  'Attachment BlurHash': 'Ek BlurHash',
  'Attachment base color': 'Ek temel rengi',
  'Audio Cloud': 'Ses Bulutu',
  'Audio Input': 'Ses Girişi',
  'Audio Sticker': 'Ses Çıkartması',
  'Audio Sticker Size': 'Ses Çıkartması Boyutu',
  'Audio Sticker Style': 'Ses Çıkartması Stili',
  'Audio Sticker Type': 'Ses Çıkartması Türü',
  'Audio Sticker selection': 'Ses çıkartması seçimi',
  Automatic: 'Otomatik',
  'Automatic (%s)': 'Otomatik (%s)',
  'Automatic video optimization enabled. <b>Reload the page</b> to apply changes.':
    'Otomatik video optimizasyonu etkin. Değişiklikleri uygulamak için <b>sayfayı yeniden yükleyin</b>.',
  Autosave: 'Otomatik kaydetme',
  'Autosave Available': 'Otomatik Kayıt Mevcut',
  'Available authors': 'Kullanılabilir yazarlar',
  'Available font families': 'Kullanılabilir yazı tipi aileleri',
  'Available publisher logos': 'Kullanılabilir yayımcı logoları',
  'Average rating.': 'Ortalama puan.',
  'Back to dashboard': 'Panoya dön',
  'Background blur': 'Arka plan bulanıklığı',
  'Bad Request': 'Hatalı İstek',
  Baker: 'Baker',
  'Border width': 'Kenarlık genişliği',
  Browse: 'Gözat',
  'Browse Page Templates': 'Sayfa Şablonlarına Gözat',
  'Browse Stock Images and Video': 'Stok Resim ve Videolara Gözat',
  'Call to Action': 'Eylem Çağrısı',
  'Call to Action text': 'Eylem Çağrısı metni',
  Camera: 'Kamera',
  'Camera Capture': 'Kamera Yakalama',
  'Cancel trimming': 'Kırpmayı iptal et',
  'Canvas Area. To navigate into the page, press Enter.':
    'Tuval Alanı. Sayfaya girmek için Enter’a basın.',
  'Change text alignment': 'Metin hizalamasını değiştir',
  'Choose Image or Video': 'Resim veya Video seç',
  'Choose a page to serve as your Web Stories archive. Use the Web Stories block to add stories to this page.':
    'Web Hikayeleri arşivi olarak kullanılacak bir sayfa seçin. Bu sayfaya hikaye eklemek için Web Hikayeleri bloğunu kullanın.',
  'Choose the camera and microphone to use for the recording.':
    'Kayıt için kullanılacak kamerayı ve mikrofonu seçin.',
  'Clear product search': 'Ürün aramasını temizle',
  Collapse: 'Daralt',
  'Color input': 'Renk girişi',
  'Color input (floating menu)': 'Renk girişi (kayan menü)',
  'Connect your store so you can easily add products to your stories.':
    'Hikayelerinize kolayca ürün ekleyebilmek için mağazanızı bağlayın.',
  'Connection failed. Please try again.': 'Bağlantı başarısız. Lütfen tekrar deneyin.',
  'Connection successful': 'Bağlantı başarılı',
  'Consider using a minimum resolution of %1$s (%2$s) to represent portrait videos':
    'Dikey videolar için en az %1$s (%2$s) çözünürlük kullanmayı düşünün',
  Content: 'İçerik',
  'Control whether this page auto-advances to the next page, or whether the reader has to manually tap to advance.':
    'Bu sayfanın bir sonraki sayfaya otomatik mi ilerleyeceğini yoksa okuyucunun ilerlemek için elle mi dokunması gerektiğini belirleyin.',
  'Could not initialize recording.': 'Kayıt başlatılamadı.',
  'Cover Preview': 'Kapak Önizlemesi',
  'Create your own': 'Kendininkini oluştur',
  'Crop Off-Screen Video': 'Ekran Dışı Videoyu Kırp',
  'Crop off-screen video parts': 'Ekran dışı video bölümlerini kırp',
  'Current Fonts': 'Mevcut Yazı Tipleri',
  'Custom Fonts': 'Özel Yazı Tipleri',
  'Customizer settings': 'Özelleştirici ayarları',
  'Data Removal': 'Veri Kaldırma',
  'Default Page Duration': 'Varsayılan Sayfa Süresi',
  'Delete %1$s color: %2$s': '%1$s rengini sil: %2$s',
  'Delete %s': '%s sil',
  'Delete Font': 'Yazı Tipini Sil',
  'Delete Group': 'Grubu Sil',
  'Delete Template': 'Şablonu Sil',
  'Delete font': 'Yazı tipini sil',
  'Delete from library': 'Kitaplıktan sil',
  'Deleting a font will delete it from every previous story it’s in. Would you like to proceed?':
    'Bir yazı tipini silmek, onu bulunduğu tüm önceki hikayelerden de siler. Devam etmek istiyor musunuz?',
  'Deleting fonts will delete them from your in-editor font list and all previous stories.':
    'Yazı tiplerini silmek, onları editör yazı tipi listenizden ve tüm önceki hikayelerden kaldırır.',
  'Design menu': 'Tasarım menüsü',
  'Design options for selected element': 'Seçili öge için tasarım seçenekleri',
  'Disable Audio': 'Sesi Devre Dışı Bırak',
  'Disable Background Blur': 'Arka Plan Bulanıklığını Kapat',
  'Disable Video': 'Videoyu Devre Dışı Bırak',
  'Disable snapping and drop targeting': 'Yapışmayı ve hedefe bırakmayı devre dışı bırak',
  'Dismiss menu': 'Menüyü kapat',
  'Display as preview': 'Önizleme olarak göster',
  'Display name for the user.': 'Kullanıcı için görünen ad.',
  'Displays the story poster that opens the story in a lightbox on click':
    'Tıklandığında hikayeyi bir ışık kutusunda açan hikaye posterini gösterir',
  "Don't worry, your changes up to this moment have been saved":
    'Endişelenmeyin, şu ana kadarki değişiklikleriniz kaydedildi',
  'Drop shadow': 'Gölge',
  'Duplicate Element': 'Ögeyi Çoğalt',
  'Duplicate Group': 'Grubu Çoğalt',
  'Duplicated elements.': 'Ögeler çoğaltıldı.',
  'Edit meta data': 'Meta verisini düzenle',
  'Edit style': 'Stili düzenle',
  'Element: %s': 'Öge: %s',
  'Elements with links must not cover most of the page. Decrease the size of elements with links.':
    'Bağlantılı ögeler sayfanın çoğunu kaplamamalıdır. Bağlantılı ögelerin boyutunu küçültün.',
  'Empty state layer': 'Boş durum katmanı',
  'Enable Audio': 'Sesi Etkinleştir',
  'Enable Background Blur': 'Arka Plan Bulanıklığını Aç',
  'Enable Video': 'Videoyu Etkinleştir',
  'Enable setting video volume': 'Video ses düzeyini ayarlamayı etkinleştir',
  'Enable support for cropping cut off-screen parts of videos':
    'Videoların ekran dışı bölümlerini kırpma desteğini etkinleştir',
  'Enable support for segmenting video files':
    'Video dosyalarını bölme desteğini etkinleştir',
  'Enter your .myshopify.com domain': '.myshopify.com alan adınızı girin',
  'Enter your API access token': 'API erişim jetonunuzu girin',
  'Enter your Google Analytics Measurement ID': 'Google Analytics Ölçüm Kimliğinizi girin',
  'Enter your MGID Widget ID': 'MGID Widget Kimliğinizi girin',
  Error: 'Hata',
  'Error fetching products': 'Ürünler getirilirken hata oluştu',
  'Error fetching products from Shopify.': 'Shopify’dan ürünler getirilirken hata oluştu.',
  'Exit detail templates view': 'Ayrıntılı şablon görünümünden çık',
  'External file': 'Harici dosya',
  'Failed to save the story: %1$s (%2$s)': 'Hikaye kaydedilemedi: %1$s (%2$s)',
  'Failed to save the story: %s': 'Hikaye kaydedilemedi: %s',
  'Fallback fonts': 'Yedek yazı tipleri',
  'File removed': 'Dosya kaldırıldı',
  'Fill in some text': 'Biraz metin girin',
  'Filter fonts by service.': 'Yazı tiplerini hizmete göre süz.',
  'First Page Animations': 'İlk Sayfa Animasyonları',
  'Fix to element': 'Ögeye sabitle',
  'Fix to top': 'Üste sabitle',
  'Font URL.': 'Yazı tipi URL’si.',
  'Font deleted': 'Yazı tipi silindi',
  'Font metrics': 'Yazı tipi ölçümleri',
  'Font service': 'Yazı tipi hizmeti',
  'Font styles': 'Yazı tipi stilleri',
  'Font variants': 'Yazı tipi varyantları',
  'Font weights': 'Yazı tipi kalınlıkları',
  Forbidden: 'Yasak',
  'Full bleed images and videos are automatically set as background. Double click to scale and position at any time.':
    'Taşmalı resim ve videolar otomatik olarak arka plan yapılır. Ölçeklemek ve konumlandırmak için istediğiniz zaman çift tıklayın.',
  'Getting font data failed, please ensure the URL points directly to a %s file.':
    'Yazı tipi verisi alınamadı; lütfen URL’nin doğrudan bir %s dosyasına işaret ettiğinden emin olun.',
  'Go to the Style tab. Scroll down to <strong>Link</strong> and enter a URL. To remove a link, select the "X" <screenreader> (clear)</screenreader> button next to the URL box.':
    'Stil sekmesine gidin. <strong>Bağlantı</strong> bölümüne inip bir URL girin. Bir bağlantıyı kaldırmak için URL kutusunun yanındaki "X" <screenreader> (temizle)</screenreader> düğmesini seçin.',
  Group: 'Grup',
  'Group %d': 'Grup %d',
  'Group Layers': 'Katmanları Grupla',
  'Group is Locked': 'Grup Kilitli',
  'Group is Unlocked': 'Grup Kilidi Açık',
  'Havana White': 'Havana Beyazı',
  'Heading Level': 'Başlık Düzeyi',
  'Heading Levels': 'Başlık Düzeyleri',
  'Headphone Cat': 'Kulaklıklı Kedi',
  'Highest Price': 'En Yüksek Fiyat',
  'If poster needs to be proxied': 'Posterin proxy üzerinden geçmesi gerekiyorsa',
  'If you take over, %s will lose editing control to the story, but their changes will be saved.':
    'Devralırsanız %s hikaye üzerindeki düzenleme denetimini kaybeder, ancak değişiklikleri kaydedilir.',
  'Image capture': 'Görüntü yakalama',
  'Image dimensions (%1$s) do not match required image dimensions (%2$s).':
    'Resim boyutları (%1$s) gereken resim boyutlarıyla (%2$s) eşleşmiyor.',
  'Image height (%1$s) does not match required image height (%2$s).':
    'Resim yüksekliği (%1$s) gereken resim yüksekliğiyle (%2$s) eşleşmiyor.',
  'Image selection': 'Resim seçimi',
  'Image width (%1$s) does not match required image width (%2$s).':
    'Resim genişliği (%1$s) gereken resim genişliğiyle (%2$s) eşleşmiyor.',
  'Inactive Shopify shop.': 'Etkin olmayan Shopify mağazası.',
  'Increase video resolution': 'Video çözünürlüğünü artır',
  'Insert Font URL': 'Yazı Tipi URL’si Ekle',
  'Insert a public URL to a font file. Allowed formats are .otf, .ttf, .woff.':
    'Bir yazı tipi dosyasının herkese açık URL’sini girin. İzin verilen biçimler: .otf, .ttf, .woff.',
  'Insert audio sticker': 'Ses çıkartması ekle',
  'Insert external background audio': 'Harici arka plan sesi ekle',
  'Insert external captions': 'Harici altyazı ekle',
  'Insert image': 'Resim ekle',
  'Insert page background audio': 'Sayfa arka plan sesi ekle',
  'Insert video': 'Video ekle',
  'Inserting video segments': 'Video bölümleri ekleniyor',
  'Instagram - @%s': 'Instagram - @%s',
  'Install <a>WooCommerce</a> to easily add shoppable products to Web Stories.':
    'Web Hikayelerine alışveriş yapılabilir ürünleri kolayca eklemek için <a>WooCommerce</a>’u kurun.',
  'Internal Server Error': 'Sunucu İç Hatası',
  'Invalid API credentials.': 'Geçersiz API kimlik bilgileri.',
  'Invalid Shopify API credentials provided.': 'Geçersiz Shopify API kimlik bilgileri sağlandı.',
  'Invalid Shopify hostname.': 'Geçersiz Shopify ana bilgisayar adı.',
  'Invalid URL format': 'Geçersiz URL biçimi',
  'Invalid format': 'Geçersiz biçim',
  'Layer Name': 'Katman Adı',
  'Layers (%d)': 'Katmanlar (%d)',
  'Layers Panel': 'Katmanlar Paneli',
  'Learn how to start <a>monetizing Web Stories with MGID Native Solution</a>':
    '<a>MGID Native Solution ile Web Hikayelerinden gelir elde etmeye</a> nasıl başlayacağınızı öğrenin',
  'Limit result set to specific fonts.': 'Sonuç kümesini belirli yazı tipleriyle sınırla.',
  'Limit results to those matching a string.':
    'Sonuçları bir dizeyle eşleşenlerle sınırla.',
  'Link to a file': 'Bir dosyaya bağlantı',
  'Link to audio file': 'Ses dosyasına bağlantı',
  'Link to caption file': 'Altyazı dosyasına bağlantı',
  'Link to story page': 'Hikaye sayfasına bağlantı',
  'Loading Story…': 'Hikaye yükleniyor…',
  'Loading more products': 'Daha fazla ürün yükleniyor',
  'Local file': 'Yerel dosya',
  'Lock Group': 'Grubu Kilitle',
  'Lock Layer': 'Katmanı Kilitle',
  'Lock/Unlock': 'Kilitle/Kilit Aç',
  'Locked element: %s': 'Kilitli öge: %s',
  'Lorem ipsum dolor sit amet': 'Lorem ipsum dolor sit amet',
  'Loud Speaker': 'Hoparlör',
  'Low Warning': 'Düşük Uyarı',
  'Lowest Price': 'En Düşük Fiyat',
  MGID: 'MGID',
  'MGID Widget ID': 'MGID Widget Kimliği',
  'Manage products in <a>WooCommerce</a> to make them available in Web Stories.':
    'Ürünleri Web Hikayelerinde kullanılabilir yapmak için <a>WooCommerce</a>’da yönetin.',
  'Maximum duration is %d minute': 'En fazla süre %d dakikadır',
  'Media Recording': 'Ortam Kaydı',
  'Media Recording Options': 'Ortam Kaydı Seçenekleri',
  'Media Recording layer': 'Ortam Kaydı katmanı',
  Menu: 'Menü',
  'Menu settings': 'Menü ayarları',
  Microphone: 'Mikrofon',
  'Missing API credentials.': 'API kimlik bilgileri eksik.',
  'Missing Fonts': 'Eksik Yazı Tipleri',
  More: 'Daha fazla',
  'Move element 1px': 'Ögeyi 1px taşı',
  'Multi selection': 'Çoklu seçim',
  'No Styles Saved': 'Kayıtlı Stil Yok',
  'No authors found': 'Yazar bulunamadı',
  'No camera found': 'Kamera bulunamadı',
  'No more products': 'Başka ürün yok',
  'No products found.': 'Ürün bulunamadı.',
  'No shopping provider set up.': 'Kurulu alışveriş sağlayıcısı yok.',
  Nofollow: 'Nofollow',
  None: 'Yok',
  'Number of reviews.': 'Değerlendirme sayısı.',
  'Once configured you can add products from this provider.':
    'Yapılandırdıktan sonra bu sağlayıcıdan ürün ekleyebilirsiniz.',
  'Only %d item can be added per page.': 'Sayfa başına yalnızca %d öge eklenebilir.',
  'Open anyway': 'Yine de aç',
  'Open context menu': 'Bağlam menüsünü aç',
  'Open insertion menu': 'Ekleme menüsünü aç',
  'Optimizing file…': 'Dosya optimize ediliyor…',
  Options: 'Seçenekler',
  'Or, choose replacement font below:': 'Ya da aşağıdan bir yedek yazı tipi seçin:',
  'Order sort attribute ascending or descending.':
    'Sıralama özniteliğini artan veya azalan olarak sırala.',
  Outline: 'Anahat',
  'Override Story Defaults': 'Hikaye Varsayılanlarını Geçersiz Kıl',
  'Page Animations Disabled': 'Sayfa Animasyonları Devre Dışı',
  'Page Template deleted.': 'Sayfa Şablonu silindi.',
  'Page Template renamed.': 'Sayfa Şablonu yeniden adlandırıldı.',
  'Page Template trashed.': 'Sayfa Şablonu çöpe taşındı.',
  'Page side menu': 'Sayfa yan menüsü',
  'Parent ID if this is a cropped attachment':
    'Bu kırpılmış bir ekse üst kimliği',
  'Pause Recording': 'Kaydı Duraklat',
  'Permission denied': 'İzin reddedildi',
  'Please ensure correct CORS settings for allowing font usage on this site.':
    'Bu sitede yazı tipi kullanımına izin vermek için doğru CORS ayarlarını yaptığınızdan emin olun.',
  'Plugin Uninstall': 'Eklenti Kaldırma',
  'Poster ID': 'Poster Kimliği',
  'Poster URL.': 'Poster URL’si.',
  'Poster height': 'Poster yüksekliği',
  'Poster object': 'Poster nesnesi',
  'Poster width.': 'Poster genişliği.',
  'Press %s to undo the last change': 'Son değişikliği geri almak için %s tuşuna basın',
  'Press Enter to edit %s': '%s ögesini düzenlemek için Enter’a basın',
  Product: 'Ürün',
  'Product "%s" already exists on the page.': '"%s" ürünü sayfada zaten var.',
  'Product ID.': 'Ürün Kimliği.',
  'Product URL.': 'Ürün URL’si.',
  'Product brand.': 'Ürün markası.',
  'Product currency.': 'Ürün para birimi.',
  'Product description.': 'Ürün açıklaması.',
  'Product image URL': 'Ürün resmi URL’si',
  'Product image alt text': 'Ürün resmi alternatif metni',
  'Product price.': 'Ürün fiyatı.',
  'Product rating.': 'Ürün puanı.',
  'Product review URL.': 'Ürün değerlendirme URL’si.',
  'Product search': 'Ürün arama',
  'Product selection': 'Ürün seçimi',
  'Product sort options': 'Ürün sıralama seçenekleri',
  'Product title.': 'Ürün başlığı.',
  Products: 'Ürünler',
  'Products are loaded': 'Ürünler yüklendi',
  'Products list': 'Ürün listesi',
  'Products without images cannot be added.': 'Resimsiz ürünler eklenemez.',
  'Qualify outbound links': 'Giden bağlantıları niteleyin',
  'Read Documentation': 'Belgeleri Oku',
  'Reason: %s': 'Neden: %s',
  'Recently Added': 'Son Eklenenler',
  'Record Audio': 'Ses Kaydet',
  'Record Video': 'Video Kaydet',
  'Record Video/Audio': 'Video/Ses Kaydet',
  'Recording stopped': 'Kayıt durduruldu',
  'Reduce link size': 'Bağlantı boyutunu küçült',
  'Remove %s': '%s kaldır',
  'Remove Animations': 'Animasyonları Kaldır',
  'Remove all data including stories and saved templates when uninstalling the Web Stories plugin.':
    'Web Hikayeleri eklentisini kaldırırken hikayeler ve kayıtlı şablonlar dahil tüm verileri kaldır.',
  'Remove from Group': 'Gruptan Çıkar',
  'Remove product': 'Ürünü kaldır',
  Removed: 'Kaldırıldı',
  'Removed page background.': 'Sayfa arka planı kaldırıldı.',
  'Removing a font from this settings page will remove it from your font list in all stories.':
    'Bu ayarlar sayfasından bir yazı tipini kaldırmak, onu tüm hikayelerdeki yazı tipi listenizden kaldırır.',
  'Removing audio': 'Ses kaldırılıyor',
  'Rename Layer': 'Katmanı Yeniden Adlandır',
  'Rename Page Template': 'Sayfa Şablonunu Yeniden Adlandır',
  'Rename Template': 'Şablonu Yeniden Adlandır',
  'Replace file': 'Dosyayı değiştir',
  'Replace font': 'Yazı tipini değiştir',
  'Requires a secure browsing context (HTTPS)':
    'Güvenli bir tarama bağlamı (HTTPS) gerektirir',
  'Restore Backup': 'Yedeği Geri Yükle',
  Resume: 'Sürdür',
  'Resume Recording': 'Kaydı Sürdür',
  Retry: 'Yeniden dene',
  'Sample color': 'Örnek renk',
  'Save & Reload': 'Kaydet ve Yeniden Yükle',
  'Save Page Template': 'Sayfa Şablonunu Kaydet',
  'Saved Page Template': 'Kaydedilmiş Sayfa Şablonu',
  'Scale media': 'Ortamı ölçekle',
  'Search Authors': 'Yazar Ara',
  Segment: 'Bölüm',
  'Segment length': 'Bölüm uzunluğu',
  'Segment video': 'Videoyu böl',
  'Segmentation failed': 'Bölme başarısız',
  'Segmenting your video will split the video across multiple pages':
    'Videonuzu bölmek, videoyu birden çok sayfaya ayırır',
  'Segmenting…': 'Bölünüyor…',
  'Select Analytics Type': 'Analiz Türü Seç',
  'Select Audio Input': 'Ses Girişi Seç',
  'Select Layer': 'Katman Seç',
  'Select Video Effect': 'Video Efekti Seç',
  'Select Video Input': 'Video Girişi Seç',
  'Select a layer': 'Bir katman seç',
  'Selecting audio file': 'Ses dosyası seçiliyor',
  'Selecting caption': 'Altyazı seçiliyor',
  'Set page background.': 'Sayfa arka planını ayarla.',
  'Shape color': 'Şekil rengi',
  'Shape selection': 'Şekil seçimi',
  'Shop Now': 'Şimdi Alışveriş Yap',
  Shopify: 'Shopify',
  'Shopify API Access Token': 'Shopify API Erişim Jetonu',
  'Shopify API rate limit exceeded. Try again later.':
    'Shopify API hız sınırı aşıldı. Daha sonra tekrar deneyin.',
  'Shopify Domain': 'Shopify Alan Adı',
  'Shopify Host': 'Shopify Ana Bilgisayarı',
  'Shopify experienced an internal server error.':
    'Shopify bir sunucu iç hatasıyla karşılaştı.',
  Shopping: 'Alışveriş',
  'Shopping library': 'Alışveriş kitaplığı',
  'Shopping provider': 'Alışveriş sağlayıcısı',
  'Show element toolbar': 'Öge araç çubuğunu göster',
  Sidebar: 'Kenar çubuğu',
  'Sidebar Selection': 'Kenar Çubuğu Seçimi',
  'Since there are products on this page, you cannot add a regular page attachment, but only customize the appearance of the shopping call to action.':
    'Bu sayfada ürünler olduğundan, normal bir sayfa eki ekleyemezsiniz; yalnızca alışveriş eylem çağrısının görünümünü özelleştirebilirsiniz.',
  Size: 'Boyut',
  'Something went wrong, please try again.': 'Bir şeyler ters gitti, lütfen tekrar deneyin.',
  'Sorry, you are not allowed to edit page templates.':
    'Üzgünüz, sayfa şablonlarını düzenleme izniniz yok.',
  'Sorry, you are not allowed to list fonts.':
    'Üzgünüz, yazı tiplerini listeleme izniniz yok.',
  'Sorry, you are not allowed to manage products.':
    'Üzgünüz, ürünleri yönetme izniniz yok.',
  'Sort collection by product attribute.':
    'Koleksiyonu ürün özniteliğine göre sırala.',
  Sponsored: 'Sponsorlu',
  'Starting recording in %d second': 'Kayıt %d saniye içinde başlıyor',
  'Sticker Style: %s': 'Çıkartma Stili: %s',
  'Sticker Type: %s': 'Çıkartma Türü: %s',
  'Stop Recording': 'Kaydı Durdur',
  'Storefront API Access Token': 'Storefront API Erişim Jetonu',
  'Story Details': 'Hikaye Ayrıntıları',
  'Story Settings': 'Hikaye Ayarları',
  'Story Title': 'Hikaye Başlığı',
  'Story details': 'Hikaye ayrıntıları',
  'Story poster image.': 'Hikaye poster resmi.',
  'Story scheduled.': 'Hikaye zamanlandı.',
  'Story trashed.': 'Hikaye çöpe taşındı.',
  'Style Selection': 'Stil Seçimi',
  'Style tabs': 'Stil sekmeleri',
  'Submit your work for review, and an Editor will be able to approve it for you.':
    'Çalışmanızı incelemeye gönderin; bir Editör onu sizin için onaylayabilir.',
  'Submitted for Review.': 'İncelemeye Gönderildi.',
  'Take a photo': 'Fotoğraf çek',
  'Taking photo in %d second': 'Fotoğraf %d saniye içinde çekiliyor',
  'Tape Player': 'Kasetçalar',
  'Template colors': 'Şablon renkleri',
  'Template name': 'Şablon adı',
  'Template tags': 'Şablon etiketleri',
  'Test connection': 'Bağlantıyı test et',
  'Testing connection…': 'Bağlantı test ediliyor…',
  'Text alignment options': 'Metin hizalama seçenekleri',
  'Text selection': 'Metin seçimi',
  'The backup of this story in your browser is different from the current version.':
    'Tarayıcınızdaki bu hikayenin yedeği, mevcut sürümden farklı.',
  'The font family': 'Yazı tipi ailesi',
  'There is an autosave of this story that is more recent than the version you are editing.':
    'Bu hikayenin, düzenlediğiniz sürümden daha yeni bir otomatik kaydı var.',
  'There was an error recording a video. Please try again.':
    'Video kaydedilirken bir hata oluştu. Lütfen tekrar deneyin.',
  'There was an error taking a photo. Please try again.':
    'Fotoğraf çekilirken bir hata oluştu. Lütfen tekrar deneyin.',
  'This background color may make some text hard to read.':
    'Bu arka plan rengi bazı metinlerin okunmasını zorlaştırabilir.',
  'This color or font size combination may be hard for some people to read.':
    'Bu renk veya yazı tipi boyutu birleşimi bazı kişiler için okumayı zorlaştırabilir.',
  'This story contains the following font that is no longer available:':
    'Bu hikaye, artık kullanılamayan şu yazı tipini içeriyor:',
  'This story is already being edited': 'Bu hikaye zaten düzenleniyor',
  'This template’s formal yet friendly appearance will let you create stories that are informational but also fun to watch. Present office and studio tours, showcase desk setups, inspire your audience with interior ideas, or do something else entirely. The possibilities are endless.':
    'Bu şablonun resmi ama sıcak görünümü, hem bilgilendirici hem de izlemesi keyifli hikayeler oluşturmanızı sağlar. Ofis ve stüdyo turları sunun, masa düzenlerini sergileyin, kitlenizi iç mekan fikirleriyle ilham verin veya tamamen farklı bir şey yapın. Olasılıklar sonsuz.',
  'This will add products as a tappable dot on your story.':
    'Bu, ürünleri hikayenize dokunulabilir bir nokta olarak ekler.',
  'To exit the canvas area, press Escape. Press Tab to move to the next group or element.':
    'Tuval alanından çıkmak için Escape’e basın. Sonraki gruba veya ögeye geçmek için Tab’a basın.',
  'To exit the canvas area, press Escape. Press Tab to move to the next group or element. To enter floating menu, press %s.':
    'Tuval alanından çıkmak için Escape’e basın. Sonraki gruba veya ögeye geçmek için Tab’a basın. Kayan menüye girmek için %s tuşuna basın.',
  'To exit the floating menu, press Escape.': 'Kayan menüden çıkmak için Escape’e basın.',
  'To get started, you need to allow access to your camera and microphone.':
    'Başlamak için kameranıza ve mikrofonunuza erişime izin vermeniz gerekir.',
  'To replace this font with your own or re-add it, go to <a>Settings</a>. To replace this font with a default, open the story.':
    'Bu yazı tipini kendinizinkiyle değiştirmek veya yeniden eklemek için <a>Ayarlar</a>’a gidin. Bu yazı tipini varsayılanla değiştirmek için hikayeyi açın.',
  'Toggle page carousel': 'Sayfa karuselini aç/kapat',
  'Toolbar position options': 'Araç çubuğu konum seçenekleri',
  'Tracking Handler': 'İzleme İşleyicisi',
  'Trimming video': 'Video kırpılıyor',
  'Turn off the default archive page at <code>%s</code>. Users will see a 404 Not Found page when trying to access the default archive page.':
    '<code>%s</code> adresindeki varsayılan arşiv sayfasını kapatın. Kullanıcılar varsayılan arşiv sayfasına erişmeye çalıştığında 404 Bulunamadı sayfası görür.',
  'Unable to find shopping integration.': 'Alışveriş entegrasyonu bulunamadı.',
  'Unable to load media': 'Ortam yüklenemedi',
  'Unable to load media. Make sure CORS is set up correctly for the file. <a>Learn more</a>.':
    'Ortam yüklenemedi. Dosya için CORS’un doğru ayarlandığından emin olun. <a>Daha fazla bilgi</a>.',
  'Unable to remove font': 'Yazı tipi kaldırılamadı',
  'Unable to rename the template. Please try again.':
    'Şablon yeniden adlandırılamadı. Lütfen tekrar deneyin.',
  Unauthorized: 'Yetkisiz',
  'Ungroup Layers': 'Katman Grubunu Çöz',
  'Unique identifier for original attachment id.':
    'Orijinal ek kimliği için benzersiz tanımlayıcı.',
  'Unique identifier for the font.': 'Yazı tipi için benzersiz tanımlayıcı.',
  'Universal Analytics <a>stopped processing new visits</a> starting <b>July 1, 2023</b>. We recommend switching to <a2>Google Analytics 4</a2> (GA4).':
    'Universal Analytics, <b>1 Temmuz 2023</b> itibarıyla yeni ziyaretleri <a>işlemeyi durdurdu</a>. <a2>Google Analytics 4</a2>’e (GA4) geçmenizi öneririz.',
  'Unlock Group': 'Grup Kilidini Aç',
  'Unlock Layer': 'Katman Kilidini Aç',
  Unmask: 'Maskeyi Kaldır',
  'Update your Google Analytics configuration.':
    'Google Analytics yapılandırmanızı güncelleyin.',
  'Upload Image or Video': 'Resim veya Video Yükle',
  'Upload audio captions': 'Ses altyazıları yükle',
  'Use Shape as a Mask': 'Şekli Maske Olarak Kullan',
  'Use Site Kit for analytics (default)':
    'Analiz için Site Kit kullan (varsayılan)',
  'Use as GIF': 'GIF olarak kullan',
  'Use as background': 'Arka plan olarak kullan',
  'Use as video': 'Video olarak kullan',
  'Use audio file': 'Ses dosyası kullan',
  'Use both': 'İkisini de kullan',
  'Use caption': 'Altyazı kullan',
  'Use external image': 'Harici resim kullan',
  'Use external image as link icon':
    'Harici resmi bağlantı simgesi olarak kullan',
  'Use external image as poster image':
    'Harici resmi poster resmi olarak kullan',
  'Use external image as video poster':
    'Harici resmi video posteri olarak kullan',
  'Use image': 'Resim kullan',
  'Use image as link icon': 'Resmi bağlantı simgesi olarak kullan',
  'Use image as poster image': 'Resmi poster resmi olarak kullan',
  'Use image as video poster': 'Resmi video posteri olarak kullan',
  'Use larger resolution (2x or 3x) images for best appearance on screens with high pixel density':
    'Yüksek piksel yoğunluklu ekranlarda en iyi görünüm için daha büyük çözünürlüklü (2x veya 3x) resimler kullanın',
  'Use only Web Stories for analytics':
    'Analiz için yalnızca Web Hikayeleri kullan',
  'Using image': 'Resim kullanılıyor',
  'Using image as link icon': 'Resim bağlantı simgesi olarak kullanılıyor',
  'Using image as poster image': 'Resim poster resmi olarak kullanılıyor',
  'Using image as video poster': 'Resim video posteri olarak kullanılıyor',
  'Video Effect': 'Video Efekti',
  'Video Input': 'Video Girişi',
  'Video Mode': 'Video Modu',
  'Video Segment Settings': 'Video Bölme Ayarları',
  'Video Volume': 'Video Ses Düzeyi',
  'Video segmentation in progress': 'Video bölme sürüyor',
  'Video selection': 'Video seçimi',
  'Video trimming in progress. Please wait up to a few minutes depending on output video length.':
    'Video kırpma sürüyor. Çıktı video uzunluğuna bağlı olarak lütfen birkaç dakika bekleyin.',
  'View the autosave': 'Otomatik kaydı görüntüle',
  'Viewing %s': '%s görüntüleniyor',
  'Visit archive page at <a>%1$s</a>. <code>%2$s</code> will automatically redirect to this page.':
    '<a>%1$s</a> adresindeki arşiv sayfasını ziyaret edin. <code>%2$s</code> otomatik olarak bu sayfaya yönlendirir.',
  Volume: 'Ses Düzeyi',
  'We detected a potential misconfiguration that prevents media items from loading correctly. This may be due to media being hosted on an external CDN. <a>Learn how to address this</a>.':
    'Ortam ögelerinin doğru yüklenmesini engelleyen olası bir yapılandırma hatası saptadık. Bunun nedeni ortamın harici bir CDN’de barındırılması olabilir. <a>Bunu nasıl gidereceğinizi öğrenin</a>.',
  'Web Stories Publisher Logo': 'Web Hikayeleri Yayımcı Logosu',
  'Web Stories − WordPress': 'Web Hikayeleri − WordPress',
  'Whether the video is to be considered a GIF':
    'Videonun GIF olarak değerlendirilip değerlendirilmeyeceği',
  'Whether to show only hierarchical taxonomies.':
    'Yalnızca hiyerarşik sınıflandırmaların gösterilip gösterilmeyeceği.',
  'Whether to show only show taxonomies that allow a UI in the admin.':
    'Yalnızca yönetimde arayüze izin veren sınıflandırmaların gösterilip gösterilmeyeceği.',
  'Widget ID': 'Widget Kimliği',
  'Without <code>%1$s</code> or <code>%2$s</code>. Example: %3$s. <a>Find your URL</a>.':
    '<code>%1$s</code> veya <code>%2$s</code> olmadan. Örnek: %3$s. <a>URL’nizi bulun</a>.',
  WooCommerce: 'WooCommerce',
  'WooCommerce is not activated. Please activate it again try again.':
    'WooCommerce etkin değil. Lütfen yeniden etkinleştirip tekrar deneyin.',
  'WooCommerce is not installed.': 'WooCommerce kurulu değil.',
  'Workspace Footer': 'Çalışma Alanı Alt Bilgisi',
  'Your Story has been successfully submitted for review.':
    'Hikayeniz incelemeye başarıyla gönderildi.',
  'Your fonts': 'Yazı tipleriniz',
  'Your story has been successfully scheduled! <a>View story</a>.':
    'Hikayeniz başarıyla zamanlandı! <a>Hikayeyi görüntüle</a>.',
  global: 'global',
  local: 'local',
  '°': '°',
  'https://help.mgid.com/generate-revenue-with-amp-web-stories?utm_source=wp-plugin&utm_medium=web-stories-by-google':
    'https://help.mgid.com/generate-revenue-with-amp-web-stories?utm_source=wp-plugin&utm_medium=web-stories-by-google',
  'https://help.shopify.com/en/manual/apps/custom-apps#get-the-api-credentials-for-a-custom-app':
    'https://help.shopify.com/en/manual/apps/custom-apps#get-the-api-credentials-for-a-custom-app',
  'https://help.shopify.com/en/manual/domains':
    'https://help.shopify.com/en/manual/domains',
  'https://support.google.com/analytics/answer/10089681?hl=en':
    'https://support.google.com/analytics/answer/10089681?hl=en',
  'https://support.google.com/analytics/answer/11583528?hl=en':
    'https://support.google.com/analytics/answer/11583528?hl=en',
  'https://wordpress.org/plugins/woocommerce/':
    'https://wordpress.org/plugins/woocommerce/',
};

const out = {};
let missing = 0;
for (const key of untranslatedKeys) {
  const base = key.includes(EOT) ? key.split(EOT)[1] : key;
  const tr = T[base];
  if (tr === undefined) {
    missing++;
    if (missing <= 20) console.warn('MISSING translation:', JSON.stringify(base));
    continue;
  }
  // [tr, tr] resolves correctly for both singular and plural lookups.
  out[key] = [tr, tr];
}

const total = untranslatedKeys.length;
console.log('translated keys:', Object.keys(out).length, '/', total, '| missing:', missing);
if (missing > 0) {
  console.error('Refusing to write: ' + missing + ' strings lack a translation.');
  process.exit(1);
}

const outPath = fileURLToPath(new URL('../src/i18n/tr-extra.json', import.meta.url));
writeFileSync(outPath, JSON.stringify(out));
console.log('Wrote', outPath, '(' + JSON.stringify(out).length + ' bytes)');
