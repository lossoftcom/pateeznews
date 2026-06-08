import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pateeznews_admin/core/network/admin_api_headers.dart';

import '../../auth/data/admin_auth_models.dart';

class AdminAiSettingsData {
  const AdminAiSettingsData({
    required this.languageCode,
    required this.googleAiApiKey,
    required this.googleAiModel,
    required this.googleAiActive,
  });

  factory AdminAiSettingsData.empty(String languageCode) {
    return AdminAiSettingsData(
      languageCode: _cleanLanguageCode(languageCode),
      googleAiApiKey: '',
      googleAiModel: '',
      googleAiActive: false,
    );
  }

  factory AdminAiSettingsData.fromJson(
    Map<String, Object?> json,
    String languageCode,
  ) {
    return AdminAiSettingsData(
      languageCode: _string(json['language_code'], fallback: languageCode),
      googleAiApiKey: _string(json['google_ai_api_key']),
      googleAiModel: _string(json['google_ai_model']),
      googleAiActive: json['google_ai_active'] == true,
    );
  }

  final String languageCode;
  final String googleAiApiKey;
  final String googleAiModel;
  final bool googleAiActive;

  Map<String, Object?> toJson() {
    return {
      'language_code': _cleanLanguageCode(languageCode),
      'google_ai_api_key': googleAiApiKey.trim(),
      'google_ai_model': googleAiModel.trim(),
      'google_ai_active': googleAiActive,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  AdminAiSettingsData copyWith({
    String? languageCode,
    String? googleAiApiKey,
    String? googleAiModel,
    bool? googleAiActive,
  }) {
    return AdminAiSettingsData(
      languageCode: languageCode ?? this.languageCode,
      googleAiApiKey: googleAiApiKey ?? this.googleAiApiKey,
      googleAiModel: googleAiModel ?? this.googleAiModel,
      googleAiActive: googleAiActive ?? this.googleAiActive,
    );
  }
}

class AdminAiPrompt {
  const AdminAiPrompt({
    required this.id,
    required this.title,
    required this.prompt,
    required this.languageCode,
    required this.isActive,
    this.isBuiltin = false,
  });

  factory AdminAiPrompt.builtin({
    required String id,
    required String title,
    required String prompt,
  }) {
    return AdminAiPrompt(
      id: id,
      title: title,
      prompt: prompt,
      languageCode: 'tr',
      isActive: true,
      isBuiltin: true,
    );
  }

  factory AdminAiPrompt.fromJson(Map<String, Object?> json) {
    return AdminAiPrompt(
      id: _string(json['id']),
      title: _string(json['title']),
      prompt: _string(json['prompt']),
      languageCode: _string(json['language_code'], fallback: 'tr'),
      isActive: json['is_active'] != false,
    );
  }

  final String id;
  final String title;
  final String prompt;
  final String languageCode;
  final bool isActive;
  final bool isBuiltin;

  bool get canMutate => !isBuiltin && id.isNotEmpty;

  AdminAiPrompt copyWith({
    String? id,
    String? title,
    String? prompt,
    String? languageCode,
    bool? isActive,
    bool? isBuiltin,
  }) {
    return AdminAiPrompt(
      id: id ?? this.id,
      title: title ?? this.title,
      prompt: prompt ?? this.prompt,
      languageCode: languageCode ?? this.languageCode,
      isActive: isActive ?? this.isActive,
      isBuiltin: isBuiltin ?? this.isBuiltin,
    );
  }
}

class AiPromptFormData {
  const AiPromptFormData({required this.title, required this.prompt});

  final String title;
  final String prompt;

  Map<String, Object?> toJson(String languageCode) {
    return {
      'title': title.trim(),
      'prompt': prompt.trim(),
      'language_code': _cleanLanguageCode(languageCode),
      'is_active': true,
    };
  }
}

const adminNewsAiDefaultPromptTitle = 'Haber İçerik Üretici';
const adminQuizAiDefaultPromptTitle = 'Quiz/Test İçerik Üretici';
const adminPollAiDefaultPromptTitle = 'Anket İçerik Üretici';
const adminVideoAiDefaultPromptTitle = 'Video İçerik Üretici';
const adminContentsAiDefaultPromptTitle = 'İçindekiler İçerik Üretici';
const adminRecipeAiDefaultPromptTitle = 'Tarif İçerik Üretici';
const adminEventAiDefaultPromptTitle = 'Etkinlik İçerik Üretici';

const adminNewsAiCompactStructureInstruction = '''
Yapısal düzen kuralı:
Haberi gereksiz ara başlıklarla bölme; kısa ve tek akışlı haberlerde ana gövde tek metin akışında kalsın.
Tek cümle, tek paragraf veya kısa bilgi için ara başlık üretme.
Kaynak uzun ve gerçek bölüm ayrımları taşıyorsa 2-4 arası anlamlı h2 kullan; h2 başlıklar haberi bölmek için değil, okuma akışını toparlamak için olsun.
H3 kullanma; bölüm gerekiyorsa sade ve editör eli değmiş gibi doğal h2 kullan.
Seçili text itemleri kısa ara başlık parçaları değil, gerçekten ek bilgi gerektiren bağımsız ve sınırlı bloklar olarak üret.
Liste ve tablo gibi ham verileri paragrafa yığma; sıralı veri için ol/li, maddeli veri için ul/li kullan.
Forma numarası, takvim, kadro, puan, rakam veya etiket gibi satır içi ana veriyi <strong> ile vurgula.
Çok kolonlu tablo verisini table etiketiyle değil, editör uyumlu okunur ul/li satırlarına dönüştür.
''';

const adminNewsAiDefaultSystemPrompt =
    '''
Sen, F-Pattern okuma alışkanlığına, Smart Brevity'ye ve haber SEO'suna hakim
bir Dijital Medya Mimarı ve Haber Editörüsün.
Görevin ham metni CMS uyumlu modüler haber JSON'una çevirmektir.
Metne mutlak sadakat göster. Ham metinde olmayan bilgiyi uydurma.
Haberi kısaltma, eksiltme veya kaynak dışı bilgiyle genişletme.
Kişi sözü, kurum adı, tarih, rakam, yer, unvan ve özel adları değiştirme.
Alıntıları birebir koru; kimseye söylemediği bir şeyi söyletme.
Alıntı dışı anlatımı anlamı bozmadan doğal, profesyonel ve özgün cümlelerle yenile.
Uzun metin duvarı kurma; kısa paragraflar ve gerekli yerlerde <strong>vurgular</strong> kullan.
$adminNewsAiCompactStructureInstruction
Sabit AI kalıpları kullanma; her başlık habere özgü olsun.
Etiketlerde kişi adını, tam ünvanlı kişi adını, kurum, mekan ve ürün adını ayrı yakala.
SEO etiketlerini yalnız kaynakta kanıtlanan ana kişi, kurum, olay, proje, yer ve doğal sorgu ifadelerinden üret; alakasız trend veya keyword stuffing yapma.
Kadro veya liste haberlerinde bütün isimleri etiketlere doldurma; ana olay/kurum etiketlerini koruyarak kaynak sırasındaki merkezi kişi adlarından ölçülü seçim yap.
Seçili item sayıları ve tipleri neyse JSON'da birebir karşıla.
Sadece JSON üret ve şemaya uy.
	''';

const adminNewsAiDefaultPromptData = AiPromptFormData(
  title: adminNewsAiDefaultPromptTitle,
  prompt: adminNewsAiDefaultSystemPrompt,
);

const adminQuizAiDefaultSystemPrompt = '''
Sen, eğlenceli testler, bilgi yarışmaları ve kişilik testleri üreten profesyonel
bir Quiz İçerik Mimarı, SEO editörü ve CMS yapılandırma uzmanısın.
Görevin kullanıcının verdiği konu, kaynak metin veya test linkinden çıkarılan ham veriyi
PateezNews CMS quiz JSON'una eksiksiz çevirmektir.

Quiz üretiminde tüm alanları doldur:
- Test başlığı, spot, SEO başlığı, slug, meta açıklama, schemaType, keywords ve FAQ.
- tabItem.type kesin quiz olsun.
- tabItem.title ve tabItem.descriptionHtml dolu olsun.
- quizData.quizType konuya göre otomatik seçilsin: ölçülebilir doğru cevap varsa trivia,
  karakter/stil/uyum profili varsa personality, yapılacaklar/uygunluk/adım kontrolü varsa checklist.
- quizData.results, quizData.questions, answers, questionSorting, allowMultiple, showResults ve endDate alanları eksiksiz gelsin.
- Her quizData.questions[].description 1 kısa cümlelik soru açıklaması olsun; boş bırakma, sonuç açıklaması yazma.
- Kişilik/checklist testlerinde sonuçlar anlamlı segmentler olsun; cevap resultId değerleri results id değerleriyle eşleşsin.
- Trivia testlerinde doğru cevap isCorrect true, diğerleri false olsun; doğru cevap kaynakta veya güvenilir araştırmada yoksa soru üretme. Doğru cevabın kısa cevap sonrası açıklamasını answers[].explanation alanına yaz.
- Trivia sonuçlarında minScore ve maxScore alanları doğru cevap sayısı aralıklarını kapsasın; 0'dan toplam soru sayısına kadar boşluk ve çakışma olmasın. answerCount alanını genel skor bandı için kullanma.
- Soru ve cevap sayısını konuya göre profesyonel seç; gereksiz kısa veya şişirilmiş test yapma. Kaynakta hazır test veya net soru sayısı varsa bu sayıyı azaltma; 15 soruluk bilgi yarışması 15 soru olarak taşınsın.
- Görsel URL uydurma; görselleri admin ekler. Linkten görsel seçildiyse uygulama onu ayrıca kullanır.

Kaynak test linkinden gelen soru, cevap, sonuç ve açıklamaları eksiltme.
Kopya gibi görünmeyecek şekilde güvenli eş anlamlılar ve yeni cümle yapıları kullan,
ama anlamı, doğru cevapları, sonuç mantığını, özel adları, tarihleri ve sayıları değiştirme.
Eğlenceli tonda daha canlı, sosyal medya ritmi olan, ölçülü emoji kullanabilen bir dil kur;
hassas, adli, ölüm, afet, sağlık veya siyasi riskli içerikte emoji kullanma.
SEO alanlarını konuya özgü, arama niyetini yakalayan ve keyword stuffing yapmayan şekilde üret.
Sadece JSON üret ve şemaya uy.
''';

const adminQuizAiDefaultPromptData = AiPromptFormData(
  title: adminQuizAiDefaultPromptTitle,
  prompt: adminQuizAiDefaultSystemPrompt,
);

const adminPollAiDefaultSystemPrompt = '''
Sen, profesyonel anketler ve okur katılımı içerikleri üreten bir
Anket İçerik Mimarı, SEO editörü ve CMS yapılandırma uzmanısın.
Görevin kullanıcının verdiği konu, kaynak metin veya haber linkinden çıkarılan ham veriyi
PateezNews CMS anket JSON'una eksiksiz çevirmektir.

Anket üretiminde tüm alanları doldur:
- Haber başlığı, spot, SEO başlığı, slug, meta açıklama, schemaType, keywords ve FAQ.
- tabItem.type kesin poll olsun.
- tabItem.title net, kısa ve oylanabilir bir anket sorusu olsun.
- tabItem.descriptionHtml anketin bağlamını açıklayan 1-2 kısa paragraf olsun.
- tabItem.options 2-6 seçenek içersin; her seçenekte id, text, image ve votes alanı bulunsun.
- votes alanı yeni anket için 0 olsun.
- Seçenekler kısa, birbirinden net ayrılan, manipülatif olmayan ve aynı eksende karşılaştırılabilir seçenekler olsun.
- isImagePoll ve pollColumns konuya göre seçilsin; admin görsel ekleyeceği için image ve mediaUrl alanlarında URL uydurma.
- Görselli anket gerekiyorsa isImagePoll true, 2 veya 3 kolon seç; metin ağırlıklı ankette isImagePoll false kullan.

Kaynak haber veya linkten gelen anket sorusu ve seçeneklerini eksiltme.
Kopya gibi görünmeyecek şekilde güvenli eş anlamlılar ve yeni cümle yapıları kullan,
ama anlamı, özel adları, tarihleri, sayıları ve kaynak bağlamını değiştirme.
Eğlenceli tonda daha canlı, sosyal medya ritmi olan, ölçülü emoji kullanabilen bir dil kur;
hassas, adli, ölüm, afet, sağlık veya siyasi riskli içerikte emoji kullanma.
SEO alanlarını konuya özgü, arama niyetini yakalayan ve keyword stuffing yapmayan şekilde üret.
Sadece JSON üret ve şemaya uy.
''';

const adminPollAiDefaultPromptData = AiPromptFormData(
  title: adminPollAiDefaultPromptTitle,
  prompt: adminPollAiDefaultSystemPrompt,
);

const adminVideoAiDefaultSystemPrompt = '''
Sen, video haberleri PateezNews CMS yapısına eksiksiz yerleştiren profesyonel
bir Video İçerik Mimarı, haber editörü ve SEO yapılandırma uzmanısın.
Görevin kullanıcının verdiği konu, ham metin, haber linki veya video kaynak bilgisini
video tabına özel modüler haber JSON'una çevirmektir.

Video üretiminde tüm alanları doldur:
- Haber başlığı, spot, SEO başlığı, slug, meta açıklama, schemaType, keywords ve FAQ.
- tabItem.type kesin video olsun.
- tabItem ilk CMS itemidir ve video tabındaki ilk "Video İçerik Bloğu" alanına yerleşecektir.
- tabItem.title video bloğu başlığıdır; kısa, net ve haber bağlamını taşıyan bir başlık olsun.
- tabItem.descriptionHtml video bloğunun açıklamasıdır; video haberini izlenecek bağlama oturtan tam ve okunur açıklama olsun.
- tabItem.source yalnız kaynakta açıkça video kaynağı, kurum, platform veya kredi bilgisi varsa dolsun.
- tabItem.mediaUrl yalnız kullanıcı kaynakta video, YouTube, embed veya doğrudan dosya URL'si verdiyse dolsun; URL uydurma.
- tabItem.showOnHomepage yalnız editör açıkça isterse true olsun; aksi halde false kalsın.
- mainContentHtml video haber için kısa giriş olabilir; asıl ilk video bloğu tabItem içindedir.
- items yalnız kullanıcının seçtiği ek item planını taşısın; ilk video tabItem verisini items içine kopyalama.
- Kullanıcı ek video item istediyse bu, ilk tabItem'dan ayrı ikinci video bloğudur.

Metne mutlak sadakat göster. Kaynakta olmayan kişi, kurum, tarih, sayı, yer, iddia,
alıntı, URL, embed, video süresi veya platform bilgisi ekleme.
Alıntıları birebir koru; kimseye söylemediği bir şeyi söyletme.
Alıntı dışı anlatımı anlamı bozmadan doğal, profesyonel ve özgün cümlelerle yenile.
Kısa paragraflar, gerekli yerlerde <strong>vurgular</strong>, uzun ve doğal bölüm ayrımı varsa az sayıda h2 kullan.
Tek cümle, tek paragraf veya kısa bilgi için ara başlık üretme.
Liste ve tablo gibi ham verileri paragrafa yığma; sıralı veri için ol/li, maddeli veri için ul/li kullan.
SEO alanlarını yalnız kaynakta kanıtlanan ana kişi, kurum, olay, proje, yer, video konusu ve doğal sorgu ifadelerinden üret.
Eğlenceli ton seçilmediyse emoji kullanma; hassas/adli/ölüm/afet/sağlık/siyaset riskli içerikte emoji kullanma.
Sadece JSON üret ve şemaya uy.
''';

const adminVideoAiDefaultPromptData = AiPromptFormData(
  title: adminVideoAiDefaultPromptTitle,
  prompt: adminVideoAiDefaultSystemPrompt,
);

const adminContentsAiDefaultSystemPrompt = '''
Sen, Table of Contents / İçindekiler formatındaki uzun içerikleri PateezNews CMS
yapısına eksiksiz yerleştiren profesyonel bir İçindekiler İçerik Mimarı,
haber editörü ve SEO yapılandırma uzmanısın.
Görevin kullanıcının verdiği konu, ham metin veya haber linkinden çıkan başlık,
spot, içindekiler listesi ve bölüm metinlerini içindekiler tabına özel JSON'a çevirmektir.

İçindekiler üretiminde tüm alanları doldur:
- Haber başlığı, spot, SEO başlığı, slug, meta açıklama, schemaType, keywords ve FAQ.
- tabItem.type kesin toc olsun.
- tabItem.title genel içindekiler bloğu başlığıdır; kaynakta özel liste başlığı yoksa "Table of Contents" kullan.
- tabItem.descriptionHtml kısa giriş/bağlamdır; kaynakta yoksa boş bırakılabilir.
- tabItem.tocData.linkListStyle içinde level1, level2 ve level3 mutlaka dolsun.
- tabItem.tocData.showInText içinde level1, level2 ve level3 mutlaka boolean olsun.
- tabItem.tocData.items kaynakta kaç madde varsa tamamını kaynak sırasıyla taşısın.
- Her tocData.items satırında id, title, parentId, image, imageDescription, content ve orderNumber dolsun.
- title madde başlığıdır; content içine gömülmeyecek.
- parentId yalnız kaynak hiyerarşisi açıkça üst-alt ilişki veriyorsa üst maddenin id/orderNumber değeriyle dolsun; düz listede boş string kalsın.
- image ve imageDescription yalnız kaynakta açık görsel veya açıklama varsa dolsun; görsel URL uydurma.
- content ilgili başlığın gövde metnidir; kaynakta aynı başlık altında kaç paragraf varsa eksiltmeden taşı.
- Link stili kaynakta açıkça farklı değilse level1/level2/level3 "none", showInText değerleri false olsun.

Olduğu gibi kalsın açıkken başlıkları, içindekiler sırasını, üst-alt ilişkiyi ve bölüm metinlerini
yeniden yazma, kısaltma, genişletme veya eş anlamlıya çevirme. Yalnız CMS alanlarına yerleştir.
Kaynakta Table of Contents listesi ve aynı başlıklarla devam eden bölüm metinleri varsa,
listedeki her başlığı karşılık gelen bölüm metniyle birebir eşleştir.
Kaynakta olmayan madde, üst bağlantı, görsel, tarih, kişi, kurum, iddia veya açıklama üretme.
Alıntıları birebir koru; kimseye söylemediği bir şeyi söyletme.
SEO alanlarını yalnız kaynakta kanıtlanan ana konu, kişi, kurum, olay, yer ve doğal sorgu ifadelerinden üret.
Sadece JSON üret ve şemaya uy.
''';

const adminContentsAiDefaultPromptData = AiPromptFormData(
  title: adminContentsAiDefaultPromptTitle,
  prompt: adminContentsAiDefaultSystemPrompt,
);

const adminRecipeAiDefaultSystemPrompt = '''
Sen, yemek tariflerini PateezNews CMS Recipe yapısına eksiksiz yerleştiren
profesyonel bir Tarif İçerik Mimarı, mutfak editörü, besin değeri araştırmacısı
ve SEO yapılandırma uzmanısın.
Görevin kullanıcının verdiği konu, ham tarif metni veya tarif linkinden çıkan veriyi
tarif tabına özel JSON'a çevirmektir.

Tarif üretiminde tüm alanları doldur:
- Haber başlığı, spot, SEO başlığı, slug, meta açıklama, schemaType, keywords ve FAQ.
- tabItem.type kesin recipe olsun.
- tabItem.title ve tabItem.descriptionHtml kısa, okunur ve tarif bağlamına sadık olsun.
- recipeData.prepTime, cookTime, serving, difficulty, ingredients, nutrition ve directions alanları eksiksiz gelsin.
- difficulty teknik select value'dur; yalnız "easy", "medium", "hard" veya kaynakta hiç yoksa "" dön.
  Easy/Beginner/Kolay -> easy, Intermediate/Medium/Orta -> medium, Advanced/Hard/Zor -> hard.
- ingredients kaynakta verilen sırayla taşınsın; miktar, birim ve malzeme adı değiştirilmesin.
- directions her adımda id, title, content, image, imageDescription ve orderNumber taşısın.
- direction title kısa adım başlığıdır; content adım açıklamasıdır. Başlığı content içine gömme.
- nutrition label ve value olarak gelsin; Calories, Total Fat, Saturated Fat, Cholesterol, Sodium,
  Total Carbohydrates, Dietary Fiber, Sugars ve Protein gibi kaynakta olan değerleri eksiltme.
- Besin değeri varsa porsiyon başına değer mantığı korunur. Birim yazımı kaynakta nasılsa aynen kalır.
- Görsel, video, embed veya medya URL uydurma; image, mediaUrl ve video alanları kaynakta yoksa boş kalsın.

Olduğu gibi kalsın açıkken tarif başlığı, spot, açıklama, süreler, porsiyon, zorluk,
malzeme satırları, besin değeri etiket/değerleri ve tarif adımlarını yeniden yazma,
kısaltma, genişletme veya eş anlamlıya çevirme. Yalnız CMS alanlarına yerleştir.

Olduğu gibi kalsın kapalıysa kaynak tarifi eksiltmeden profesyonel mutfak editörü diliyle düzenle;
anlamı, miktarları, pişirme sıcaklıklarını, süreleri, sıra mantığını, özel adları ve besin değerlerini değiştirme.

Derin araştırma kapalıysa kaynakta olmayan süre, porsiyon, zorluk, besin değeri, teknik iddia veya sağlık iddiası üretme.
Derin araştırma açıksa yalnız kaynakta eksik kalan prepTime, cookTime, serving, difficulty ve nutrition alanlarını
güvenilir web araştırması ve tarifin malzeme/porsiyon mantığıyla profesyonelce tamamlayabilirsin.
Kaynakta dolu olan değerleri derin araştırma açık olsa bile değiştirme.

SEO alanlarını tarifin ana yemek adı, yöntem, malzeme, porsiyon ve arama niyetine göre doğal üret.
schemaType Recipe olsun.
Sadece JSON üret ve şemaya uy.
''';

const adminRecipeAiDefaultPromptData = AiPromptFormData(
  title: adminRecipeAiDefaultPromptTitle,
  prompt: adminRecipeAiDefaultSystemPrompt,
);

const adminEventAiDefaultSystemPrompt = '''
Sen, etkinlik duyurularını PateezNews CMS Event yapısına eksiksiz yerleştiren
profesyonel bir Etkinlik İçerik Mimarı, kültür-sanat editörü, afiş/poster okuma
uzmanı ve SEO yapılandırma uzmanısın.
Görevin kullanıcının verdiği konu, ham etkinlik metni, etkinlik linki veya yüklenen
poster/afiş görsellerinden çıkan veriyi etkinlik tabına özel JSON'a çevirmektir.

Etkinlik üretiminde tüm alanları doldur:
- Haber başlığı, spot, SEO başlığı, slug, meta açıklama, schemaType, keywords ve FAQ.
- tabItem.type kesin event olsun.
- tabItem.title ve tabItem.descriptionHtml etkinliği net anlatan kısa ve okunur metinler olsun.
- eventData.startDateTime, endDateTime, organizer, venueName, address, latitude, longitude,
  registrationType, ticketUrl, ticketPrice, capacity, scheduleTitle, highlightsTitle,
  speakersTitle, schedule, highlights ve speakers alanları şemaya uygun gelsin.
- Tarih/saat formatı kullanıcıya görünen form değerine uygun olsun: gg.aa.yyyy --:--.
  Program satırlarında date ve time ayrı gelsin; örnek date "01.05.2026", time "09:00-09:30".
- registrationType yalnız "none", "required", "tickets" veya "external" olabilir.
- schedule kaynakta kaç oturum/oyun/konser/gösterim varsa tamamını kaynak sırasıyla taşısın.
- Poster bir festival programıysa her afiş/oyun/oturum ayrı schedule satırı olabilir.
- highlights yaş sınırı, ücret, kategori, festival yılı, süre, hedef kitle, kayıt koşulu gibi kısa etiket/değer bilgileridir.
- speakers yalnız kaynakta kişi/konuşmacı/oyuncu/konuk açıkça varsa dolsun; yoksa boş liste olabilir.
- image, mediaUrl, speaker image ve schedule image alanlarında URL uydurma; yüklenen görseller uygulama tarafından ayrıca forma yerleştirilebilir.

Olduğu gibi kalsın açıkken poster/metin üzerindeki etkinlik adı, tarih, saat, mekan, program,
oyun/oturum adları, kişi adları, kurum adları, ücret, yaş sınırı ve notları yeniden yazma,
kısaltma, genişletme veya eş anlamlıya çevirme. Yalnız CMS alanlarına yerleştir.

Olduğu gibi kalsın kapalıysa etkinlik metnini profesyonel duyuru diliyle düzenle;
özel adları, tarihleri, saatleri, mekanları, fiyatları, yaş sınırlarını, kurum adlarını ve program sırasını değiştirme.

Derin araştırma kapalıysa kaynakta veya yüklenen görselde olmayan tarih, saat, mekan, ücret,
kayıt linki, koordinat, kontenjan, konuşmacı veya program satırı üretme.
Derin araştırma açıksa eksik mekan adresi, resmi organizatör, kayıt/bilet bilgisi, koordinat,
program teyidi ve SEO arama niyetini güvenilir web kaynaklarıyla tamamlayabilirsin.
Kaynakta dolu olan bilgi derin araştırma açık olsa bile değiştirilmez.

Yüklenen etkinlik görselleri varsa onları ana kaynak gibi oku: başlık, festival adı, tarih,
mekan, oyun/oturum adları, saatler, kurum logoları, QR/link notları ve küçük yazıları dikkatle çıkar.
Görselde okunamayan veya emin olunmayan küçük metni kesin bilgiye dönüştürme.

SEO alanlarını etkinlik adı, şehir, mekan, tarih, kategori ve arama niyetine göre doğal üret.
schemaType Event olsun.
Sadece JSON üret ve şemaya uy.
''';

const adminEventAiDefaultPromptData = AiPromptFormData(
  title: adminEventAiDefaultPromptTitle,
  prompt: adminEventAiDefaultSystemPrompt,
);

const adminAiDefaultPromptDataList = <AiPromptFormData>[
  adminNewsAiDefaultPromptData,
  adminQuizAiDefaultPromptData,
  adminPollAiDefaultPromptData,
  adminVideoAiDefaultPromptData,
  adminContentsAiDefaultPromptData,
  adminRecipeAiDefaultPromptData,
  adminEventAiDefaultPromptData,
];

abstract class AdminAiSettingsRepository {
  Future<AdminAiSettingsData> fetchSettings(String languageCode);

  Future<AdminAiSettingsData> saveSettings({
    required AdminSession session,
    required AdminAiSettingsData settings,
  });

  Future<List<AdminAiPrompt>> fetchPrompts(String languageCode);

  Future<AdminAiPrompt> savePrompt({
    required AdminSession session,
    required String languageCode,
    required AiPromptFormData data,
    String? id,
  });

  Future<void> deletePrompt({
    required AdminSession session,
    required String id,
  });

  Future<List<String>> fetchGeminiModels(String apiKey);
}

class SupabaseAdminAiSettingsRepository implements AdminAiSettingsRepository {
  const SupabaseAdminAiSettingsRepository({this.httpClient, this.apiBaseUrl});

  static const _apiBaseUrl = String.fromEnvironment('PATEEZNEWS_API_BASE_URL');
  static const _requestTimeout = Duration(seconds: 18);

  final http.Client? httpClient;
  final String? apiBaseUrl;

  @override
  Future<AdminAiSettingsData> fetchSettings(String languageCode) async {
    final normalizedCode = _cleanLanguageCode(languageCode);
    final result = await _postJson('/api/admin/query', {
      'table': 'site_settings',
      'method': 'select',
      'select':
          'language_code,google_ai_api_key,google_ai_model,google_ai_active',
      'filters': [
        {
          'type': 'comparison',
          'op': 'eq',
          'column': 'language_code',
          'value': normalizedCode,
        },
      ],
      'single': 'maybeSingle',
    });
    _throwIfApiError(result, fallbackMessage: 'AI ayarları alınamadı');
    final data = result['data'];
    if (data is! Map) return AdminAiSettingsData.empty(normalizedCode);
    return AdminAiSettingsData.fromJson(_asStringKeyMap(data), normalizedCode);
  }

  @override
  Future<AdminAiSettingsData> saveSettings({
    required AdminSession session,
    required AdminAiSettingsData settings,
  }) async {
    final normalizedSettings = settings.copyWith(
      languageCode: _cleanLanguageCode(settings.languageCode),
    );
    final result = await _postJson('/api/admin/query', {
      'table': 'site_settings',
      'method': 'upsert',
      'values': normalizedSettings.toJson(),
      'options': {'onConflict': 'language_code'},
      'single': 'maybeSingle',
    });
    _throwIfApiError(result, fallbackMessage: 'AI ayarları kaydedilemedi');
    final data = result['data'];
    if (data is! Map) return normalizedSettings;
    return AdminAiSettingsData.fromJson(
      _asStringKeyMap(data),
      normalizedSettings.languageCode,
    );
  }

  @override
  Future<List<AdminAiPrompt>> fetchPrompts(String languageCode) async {
    final result = await _postJson('/api/admin/query', {
      'table': 'ai_ready_formats',
      'method': 'select',
      'select': 'id,title,prompt,language_code,is_active,created_at,updated_at',
      'filters': [
        {
          'type': 'comparison',
          'op': 'eq',
          'column': 'language_code',
          'value': _cleanLanguageCode(languageCode),
        },
      ],
      'orders': [
        {'column': 'created_at', 'ascending': false},
      ],
    });
    _throwIfApiError(result, fallbackMessage: 'AI promtları alınamadı');
    final data = result['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((row) => AdminAiPrompt.fromJson(_asStringKeyMap(row)))
        .where((prompt) => prompt.title.trim().isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<AdminAiPrompt> savePrompt({
    required AdminSession session,
    required String languageCode,
    required AiPromptFormData data,
    String? id,
  }) async {
    final cleanId = id?.trim() ?? '';
    final result = cleanId.isEmpty
        ? await _postJson('/api/admin/query', {
            'table': 'ai_ready_formats',
            'method': 'insert',
            'values': data.toJson(languageCode),
            'single': 'maybeSingle',
          })
        : await _postJson('/api/admin/query', {
            'table': 'ai_ready_formats',
            'method': 'update',
            'values': {
              'title': data.title.trim(),
              'prompt': data.prompt.trim(),
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            },
            'filters': [
              {
                'type': 'comparison',
                'op': 'eq',
                'column': 'id',
                'value': cleanId,
              },
            ],
            'single': 'maybeSingle',
          });
    _throwIfApiError(result, fallbackMessage: 'AI promtu kaydedilemedi');
    final row = result['data'];
    if (row is! Map) {
      throw const AdminAiSettingsException('AI promtu kaydedilemedi');
    }
    return AdminAiPrompt.fromJson(_asStringKeyMap(row));
  }

  @override
  Future<void> deletePrompt({
    required AdminSession session,
    required String id,
  }) async {
    final result = await _postJson('/api/admin/query', {
      'table': 'ai_ready_formats',
      'method': 'delete',
      'filters': [
        {'type': 'comparison', 'op': 'eq', 'column': 'id', 'value': id},
      ],
    });
    _throwIfApiError(result, fallbackMessage: 'AI promtu silinemedi');
  }

  @override
  Future<List<String>> fetchGeminiModels(String apiKey) async {
    final trimmedKey = apiKey.trim();
    if (trimmedKey.isEmpty) {
      throw const AdminAiSettingsException('Google AI API Key boş olamaz');
    }

    final results = await Future.wait([
      _fetchGeminiModelList('v1beta', trimmedKey),
      _fetchGeminiModelList('v1', trimmedKey),
    ]);
    final models = filterGeminiTextGenerationModels([
      for (final result in results) ...result.modelIds,
    ]);
    if (models.isNotEmpty) return models;

    final message = results
        .map((result) => result.error)
        .where((error) => error.trim().isNotEmpty)
        .firstOrNull;
    throw AdminAiSettingsException(message ?? 'Model listesi alınamadı');
  }

  Future<_GeminiModelListResult> _fetchGeminiModelList(
    String version,
    String apiKey,
  ) async {
    try {
      final modelIds = <String>[];
      var pageToken = '';

      for (var page = 0; page < 20; page++) {
        final uri =
            Uri.https('generativelanguage.googleapis.com', '/$version/models', {
              'key': apiKey,
              'pageSize': '1000',
              if (pageToken.isNotEmpty) 'pageToken': pageToken,
            });
        final response = await (httpClient?.get(uri) ?? http.get(uri)).timeout(
          _requestTimeout,
        );
        final decoded = response.body.isEmpty
            ? <String, Object?>{}
            : jsonDecode(response.body);
        if (decoded is! Map) {
          return const _GeminiModelListResult(
            modelIds: [],
            error: 'Geçersiz model yanıtı',
          );
        }
        final error = decoded['error'];
        if (error is Map) {
          return _GeminiModelListResult(
            modelIds: const [],
            error: error['message']?.toString() ?? 'Model listesi alınamadı',
          );
        }
        final models = decoded['models'];
        if (models is List) {
          modelIds.addAll(
            [
              for (final item in models.whereType<Map>())
                if (_supportsGenerateContent(item))
                  normalizeGeminiModelId(_string(item['name'])),
            ].where((id) => id.isNotEmpty),
          );
        }
        pageToken = _string(decoded['nextPageToken']);
        if (pageToken.isEmpty) break;
      }

      return _GeminiModelListResult(modelIds: modelIds);
    } catch (error) {
      return _GeminiModelListResult(modelIds: const [], error: '$error');
    }
  }

  bool _supportsGenerateContent(Map<dynamic, dynamic> item) {
    final rawMethods =
        item['supportedGenerationMethods'] ?? item['supportedActions'];
    if (rawMethods is! List) return false;
    return rawMethods.any(
      (method) => method.toString().trim() == 'generateContent',
    );
  }

  Future<Map<String, Object?>> _postJson(
    String path,
    Map<String, Object?> body,
  ) async {
    final response =
        await (httpClient?.post(
                  _uri(path),
                  headers: await adminJsonHeaders(),
                  body: jsonEncode(body),
                ) ??
                adminHttpClient.post(
                  _uri(path),
                  headers: await adminJsonHeaders(),
                  body: jsonEncode(body),
                ))
            .timeout(_requestTimeout);

    final decoded = response.body.isEmpty
        ? <String, Object?>{}
        : jsonDecode(response.body);
    if (decoded is! Map) {
      throw const AdminAiSettingsException('Geçersiz sunucu yanıtı');
    }
    final result = _asStringKeyMap(decoded);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwIfApiError(result, fallbackMessage: 'Sunucu isteği başarısız');
    }
    return result;
  }

  Uri _uri(String path) {
    final baseUrl = (apiBaseUrl ?? _apiBaseUrl).trim();
    if (baseUrl.isNotEmpty) return Uri.parse(baseUrl).resolve(path);
    if (!kIsWeb) return _defaultLocalApiBaseUrl().resolve(path);
    return Uri.base.resolve(path);
  }

  Uri _defaultLocalApiBaseUrl() {
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => Uri.parse('http://10.0.2.2:4321'),
      _ => Uri.parse('http://127.0.0.1:4321'),
    };
  }

  void _throwIfApiError(
    Map<String, Object?> result, {
    required String fallbackMessage,
  }) {
    final error = result['error'];
    if (error == null) return;
    if (error is Map) {
      final message = error['message']?.toString();
      if (message != null && message.isNotEmpty) {
        throw AdminAiSettingsException(message);
      }
    }
    throw AdminAiSettingsException(fallbackMessage);
  }
}

class _GeminiModelListResult {
  const _GeminiModelListResult({required this.modelIds, this.error = ''});

  final List<String> modelIds;
  final String error;
}

String normalizeGeminiModelId(Object? value) {
  return _string(
    value,
  ).trim().replaceFirst(RegExp(r'^models/', caseSensitive: false), '').trim();
}

List<String> filterGeminiTextGenerationModels(List<String> rawModels) {
  final seen = <String>{};
  final models = <String>[];

  for (final rawModel in rawModels) {
    final model = normalizeGeminiModelId(rawModel);
    final lower = model.toLowerCase();
    if (model.isEmpty || !seen.add(lower)) continue;
    if (!isSupportedGeminiTextGenerationModel(model)) continue;
    models.add(model);
  }

  return models..sort((a, b) {
    final rankDiff = _geminiTextModelRank(b) - _geminiTextModelRank(a);
    if (rankDiff != 0) return rankDiff;
    return a.compareTo(b);
  });
}

bool isSupportedGeminiTextGenerationModel(String model) {
  final lower = normalizeGeminiModelId(model).toLowerCase();
  if (lower.isEmpty) return false;
  if (!lower.startsWith('gemini-') && !lower.startsWith('gemma-')) {
    return false;
  }
  if (_isDeprecatedGeminiTextModel(lower)) return false;
  if (_isNonTextGenerationModel(lower)) return false;
  return true;
}

bool isFreeGeminiTextGenerationModel(String model) {
  final lower = normalizeGeminiModelId(model).toLowerCase();
  if (!isSupportedGeminiTextGenerationModel(lower)) return false;
  if (_freeGeminiTextModelIds.contains(lower)) return true;
  if (lower.startsWith('gemini-2.5-flash-preview')) return true;
  if (lower.startsWith('gemma-3') || lower.startsWith('gemma-3n')) return true;
  return false;
}

const _freeGeminiTextModelIds = <String>{
  'gemini-3.5-flash',
  'gemini-3.1-flash-lite',
  'gemini-3-flash-preview',
  'gemini-2.5-pro',
  'gemini-2.5-flash',
  'gemini-2.5-flash-lite',
  'gemini-2.5-flash-lite-preview-09-2025',
};

bool _isDeprecatedGeminiTextModel(String lower) {
  return lower.startsWith('gemini-1.5') ||
      lower.startsWith('gemini-2.0') ||
      lower == 'gemini-3-pro-preview' ||
      lower.startsWith('gemini-3.1-flash-lite-preview');
}

bool _isNonTextGenerationModel(String lower) {
  const blockedFragments = [
    'image',
    'imagen',
    'veo',
    'lyria',
    'tts',
    'audio',
    'live',
    'embedding',
    'embed',
    'aqa',
    'robot',
    'computer-use',
    'deep-research',
    'antigravity',
  ];
  return blockedFragments.any(lower.contains);
}

int _geminiTextModelRank(String model) {
  final lower = normalizeGeminiModelId(model).toLowerCase();
  const exactRanks = <String, int>{
    'gemini-3.5-flash': 20000,
    'gemini-3.1-flash-lite': 19000,
    'gemini-3-flash-preview': 18000,
    'gemini-2.5-flash': 17000,
    'gemini-2.5-flash-lite': 16000,
    'gemini-2.5-pro': 15000,
    'gemini-2.5-flash-lite-preview-09-2025': 14500,
  };

  var score = exactRanks[lower] ?? 0;
  if (score == 0) {
    if (lower.startsWith('gemini-3.1-pro')) score = 14000;
    if (lower.startsWith('gemini-2.5-flash-preview')) score = 13500;
    if (lower.startsWith('gemini-3')) score = 12000;
    if (lower.startsWith('gemini-2.5')) score = 10000;
    if (lower.startsWith('gemini-')) score = 8000;
    if (lower.startsWith('gemma-3n')) score = 6000;
    if (lower.startsWith('gemma-3')) score = 5800;
    if (lower.startsWith('gemma-')) score = 5000;
  }
  if (lower.contains('latest')) score += 400;
  if (lower.contains('preview')) score -= 80;
  if (lower.contains('experimental') || lower.contains('-exp')) score -= 300;
  return score;
}

class AdminAiSettingsException implements Exception {
  const AdminAiSettingsException(this.message);

  final String message;

  @override
  String toString() => message;
}

String _string(Object? value, {String fallback = ''}) {
  final text = value?.toString();
  if (text == null || text.isEmpty) return fallback;
  return text;
}

String _cleanLanguageCode(String value) {
  final code = value.trim().toLowerCase().replaceAll('_', '-');
  return code.isEmpty ? 'tr' : code;
}

Map<String, Object?> _asStringKeyMap(Map<dynamic, dynamic> value) {
  return value.map((key, nestedValue) => MapEntry(key.toString(), nestedValue));
}
