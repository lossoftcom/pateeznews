import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../settings/data/admin_ai_settings_repository.dart';

class AdminNewsAiDraftRequest {
  const AdminNewsAiDraftRequest({
    required this.languageCode,
    required this.category,
    required this.tone,
    required this.contentType,
    required this.outputTarget,
    required this.includeSeo,
    required this.topic,
    required this.sourceNotes,
    required this.itemCounts,
  });

  final String languageCode;
  final String category;
  final String tone;
  final String contentType;
  final String outputTarget;
  final bool includeSeo;
  final String topic;
  final String sourceNotes;
  final Map<String, int> itemCounts;
}

class AdminNewsAiDraft {
  const AdminNewsAiDraft({
    required this.title,
    required this.summary,
    required this.mainContentTitle,
    required this.seoTitle,
    required this.slug,
    required this.metaDescription,
    required this.schemaType,
    required this.keywords,
    required this.faqEntries,
    required this.mainContentHtml,
    required this.items,
  });

  factory AdminNewsAiDraft.fromJson(Map<String, Object?> json) {
    return AdminNewsAiDraft(
      title: _cleanText(json['title']),
      summary: _cleanText(json['summary']),
      mainContentTitle: _cleanText(json['mainContentTitle']),
      seoTitle: _cleanText(json['seoTitle']),
      slug: _cleanText(json['slug']),
      metaDescription: _cleanText(json['metaDescription']),
      schemaType: _cleanText(json['schemaType']),
      keywords: _stringList(json['keywords'], limit: 14),
      faqEntries:
          [
                for (final row in _mapList(json['faq']))
                  AdminNewsAiFaq(
                    question: _cleanText(row['question']),
                    answer: _cleanText(row['answer']),
                  ),
              ]
              .where(
                (item) => item.question.isNotEmpty || item.answer.isNotEmpty,
              )
              .toList(growable: false),
      mainContentHtml: _cleanHtml(json['mainContentHtml']),
      items: [
        for (final row in _mapList(json['items']))
          AdminNewsAiItem.fromJson(row),
      ].where((item) => item.type.isNotEmpty).toList(growable: false),
    );
  }

  final String title;
  final String summary;
  final String mainContentTitle;
  final String seoTitle;
  final String slug;
  final String metaDescription;
  final String schemaType;
  final List<String> keywords;
  final List<AdminNewsAiFaq> faqEntries;
  final String mainContentHtml;
  final List<AdminNewsAiItem> items;
}

class AdminNewsAiContentSection {
  const AdminNewsAiContentSection({required this.title, required this.html});

  final String title;
  final String html;
}

class AdminNewsAiFaq {
  const AdminNewsAiFaq({required this.question, required this.answer});

  final String question;
  final String answer;
}

class AdminNewsAiCriterion {
  const AdminNewsAiCriterion({required this.label, required this.score});

  factory AdminNewsAiCriterion.fromJson(Map<String, Object?> json) {
    return AdminNewsAiCriterion(
      label: _cleanText(json['label']),
      score: _int(json['score'], fallback: 80).clamp(0, 100).toInt(),
    );
  }

  final String label;
  final int score;
}

class AdminNewsAiItem {
  const AdminNewsAiItem({
    required this.type,
    required this.title,
    required this.descriptionHtml,
    required this.source,
    required this.altText,
    required this.frontTitle,
    required this.frontDescriptionHtml,
    required this.backTitle,
    required this.backDescriptionHtml,
    required this.beforeLabel,
    required this.afterLabel,
    required this.options,
    required this.pros,
    required this.cons,
    required this.criteria,
  });

  factory AdminNewsAiItem.fromJson(Map<String, Object?> json) {
    return AdminNewsAiItem(
      type: _normalizeItemType(json['type']),
      title: _cleanText(json['title']),
      descriptionHtml: _cleanHtml(json['descriptionHtml']),
      source: _cleanText(json['source']),
      altText: _cleanText(json['altText']),
      frontTitle: _cleanText(json['frontTitle']),
      frontDescriptionHtml: _cleanHtml(json['frontDescriptionHtml']),
      backTitle: _cleanText(json['backTitle']),
      backDescriptionHtml: _cleanHtml(json['backDescriptionHtml']),
      beforeLabel: _cleanText(json['beforeLabel']),
      afterLabel: _cleanText(json['afterLabel']),
      options: _stringList(json['options'], limit: 6),
      pros: _stringList(json['pros'], limit: 6),
      cons: _stringList(json['cons'], limit: 6),
      criteria: [
        for (final row in _mapList(json['criteria']))
          AdminNewsAiCriterion.fromJson(row),
      ].where((item) => item.label.isNotEmpty).toList(growable: false),
    );
  }

  final String type;
  final String title;
  final String descriptionHtml;
  final String source;
  final String altText;
  final String frontTitle;
  final String frontDescriptionHtml;
  final String backTitle;
  final String backDescriptionHtml;
  final String beforeLabel;
  final String afterLabel;
  final List<String> options;
  final List<String> pros;
  final List<String> cons;
  final List<AdminNewsAiCriterion> criteria;
}

abstract class AdminNewsAiRepository {
  Future<AdminNewsAiDraft> generateDraft(AdminNewsAiDraftRequest request);
}

class GeminiAdminNewsAiRepository implements AdminNewsAiRepository {
  const GeminiAdminNewsAiRepository({
    this.httpClient,
    this.settingsRepository = const SupabaseAdminAiSettingsRepository(),
  });

  static const _requestTimeout = Duration(seconds: 24);

  final http.Client? httpClient;
  final AdminAiSettingsRepository settingsRepository;

  @override
  Future<AdminNewsAiDraft> generateDraft(
    AdminNewsAiDraftRequest request,
  ) async {
    final topic = request.topic.trim();
    final sourceNotes = request.sourceNotes.trim();
    if (topic.isEmpty && sourceNotes.isEmpty) {
      throw const AdminNewsAiException('Konu veya kaynak notu girin.');
    }

    final settings = await settingsRepository.fetchSettings(
      request.languageCode,
    );
    if (!settings.googleAiActive) {
      throw const AdminNewsAiException('Google AI ayarlarda aktif değil.');
    }
    final apiKey = settings.googleAiApiKey.trim();
    if (apiKey.isEmpty) {
      throw const AdminNewsAiException('Google AI API Key bulunamadı.');
    }
    final model = normalizeGeminiModelId(settings.googleAiModel);
    if (model.isEmpty) {
      throw const AdminNewsAiException('Google AI modeli seçilmemiş.');
    }
    final systemPrompt = await _fetchSystemPrompt(request.languageCode);

    AdminNewsAiException? lastError;
    for (final candidateModel in _modelAttempts(model)) {
      try {
        final draft = await _generateWithModel(
          request: request,
          apiKey: apiKey,
          model: candidateModel,
          systemPrompt: systemPrompt,
        );
        final enrichedDraft = _enrichDraft(draft, request);
        _validateItemCounts(enrichedDraft, request.itemCounts);
        return enrichedDraft;
      } on AdminNewsAiException catch (error) {
        lastError = error;
        if (!error.retryable) rethrow;
      }
    }

    if (lastError != null && lastError.retryable) {
      throw const AdminNewsAiException(
        'Google AI yoğunluk nedeniyle yanıt veremedi. Daha sonra tekrar deneyin veya ayarlardan Flash-Lite model seçin.',
      );
    }
    throw lastError ??
        const AdminNewsAiException('Google AI isteği başarısız oldu.');
  }

  Future<AdminNewsAiDraft> _generateWithModel({
    required AdminNewsAiDraftRequest request,
    required String apiKey,
    required String model,
    required String systemPrompt,
  }) async {
    final uri = Uri.https(
      'generativelanguage.googleapis.com',
      '/v1beta/models/$model:generateContent',
    );
    final headers = {
      'Content-Type': 'application/json',
      'x-goog-api-key': apiKey,
    };
    final body = jsonEncode(_buildRequestBody(request, model, systemPrompt));
    late final http.Response response;
    try {
      response =
          await (httpClient?.post(uri, headers: headers, body: body) ??
                  http.post(uri, headers: headers, body: body))
              .timeout(_requestTimeout);
    } on TimeoutException {
      throw const AdminNewsAiException(
        'Google AI yanıtı gecikti. Daha hızlı model deneniyor.',
        retryable: true,
      );
    }

    final decoded = response.body.trim().isEmpty
        ? <String, Object?>{}
        : jsonDecode(response.body);
    if (decoded is! Map) {
      throw const AdminNewsAiException('Google AI geçersiz yanıt verdi.');
    }
    final result = _asStringKeyMap(decoded);
    final error = result['error'];
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AdminNewsAiException(
        _errorMessage(error),
        retryable: _isRetryableStatus(response.statusCode),
      );
    }
    if (error != null) {
      throw AdminNewsAiException(_errorMessage(error));
    }

    final draftJson = _extractDraftJson(result);
    return AdminNewsAiDraft.fromJson(draftJson);
  }

  Map<String, Object?> _buildRequestBody(
    AdminNewsAiDraftRequest request,
    String model,
    String systemPrompt,
  ) {
    final generationConfig = <String, Object?>{
      'candidateCount': 1,
      'maxOutputTokens': _maxOutputTokensFor(request),
      'temperature': _temperatureForTone(request.tone),
      'topP': 0.9,
      'responseMimeType': 'application/json',
      'responseJsonSchema': _draftJsonSchema,
    };
    final thinkingConfig = _thinkingConfigForModel(model);
    if (thinkingConfig != null) {
      generationConfig['thinkingConfig'] = thinkingConfig;
    }

    return {
      'system_instruction': {
        'parts': [
          {'text': _systemPromptWithCompactStructureRule(systemPrompt)},
        ],
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': _buildUserPrompt(request)},
          ],
        },
      ],
      'generationConfig': generationConfig,
    };
  }

  String _buildUserPrompt(AdminNewsAiDraftRequest request) {
    final itemLines = request.itemCounts.entries
        .where((entry) => entry.value > 0)
        .map((entry) => '- ${entry.key}: ${entry.value} adet')
        .join('\n');
    return '''
CMS için modüler haber JSON'u üret.

Ana görev:
- Kullanıcının verdiği haber içeriğini ve editör talimatlarını CMS uyumlu, modüler haber JSON'una dönüştür.
- Haber metnini kısaltma, eksiltme, atlama veya özet metne indirgeme. Kaynakta verilen tüm doğrulanabilir bilgileri koru.
- Kaynakta olmayan isim, kurum, tarih, sayı, yer, iddia, sebep, sonuç, duygu, yorum, vaat veya alıntı ekleme.
- Doğrudan alıntıları ve konuşmacı sözlerini birebir koru. Kimseye söylemediği bir şeyi söyletme.
- Alıntı dışındaki anlatımı güvenli eş anlamlılar ve doğal cümle yapılarıyla profesyonelce yenile; anlamı değiştirme.
- Özel adları, kurum adlarını, unvanları, tarihleri, rakamları, para tutarlarını, yer adlarını ve teknik/hukuki ifadeleri değiştirme.
- Haber içeriğinde "Kaynak URL" ve "Kaynak metni" varsa bunu linkten kodla çıkarılmış ham haber kaynağı say; menü, reklam, yorum, ilgili haber ve sayfa çevresi metnini haber bilgisine dönüştürme.
- Editör talimatları haberin hangi yönünün öne çıkarılacağını, hangi isim/kurum/yerlerin çıkarılacağını veya hangi vurgunun azaltılacağını söyleyebilir. Talimat kaynakta olmayan bilgi eklettiremez; kaynak metindeki anlam, özel ad, tarih ve rakam değiştirilemez.
- "İsimleri çıkar", "konuşmayı öne al", "başkanın açıklamasını vurgula" gibi talimatlarda yalnız haber içeriğinde açıkça bulunan bilgileri kullan.

Editör modu:
- Bir insan haber editörü yazmış gibi doğal, akıcı, temiz ve profesyonel Türkçe kullan.
- F-Pattern ve Smart Brevity uygula; uzun gri metin duvarı kurma ama haberi gereksiz ara başlık veya item parçalarına bölme. Kaynak bilgisini azaltma.
- Ana haber akışını mümkün olduğunca tek metin bloğunda tut; geçişleri kısa paragraflar ve <strong>vurgular</strong> ile kur.
- Her paragraf en fazla 3 cümle olsun.
- Tek cümle, tek paragraf veya kısa haber için ara başlık üretme.
- Uzun ve doğal bölüm ayrımı olan haberlerde 2-4 arası anlamlı h2 kullanılabilir; h2 başlıklar insan editör gibi özel, net ve az sayıda olsun.
- Forma numarası, kadro, maç takvimi, puan listesi, teknik özellik, tablo veya maddeli ham veri varsa düz paragraf yapma; okunur listeye dönüştür.
- Örnekteki "1 — Mert Günok" gibi ardışık numaralı satırları <ol><li><strong>Mert Günok</strong></li></ol> yapısına çevir; numara sırası liste numarası olarak kalsın.
- Sayı satır kimliği olup ardışık değilse veya tablo çok kolonluysa <ul><li><strong>Etiket:</strong> Değer</li></ul> biçimini kullan.
- Önemli gerçekleri <strong>kalın</strong> vurgula.
- Zero AI Footprint: "Neden önemli", "Sırada ne var", "Büyük resim" gibi sabit kalıp kullanma.
- Zorunlu başlık varsa habere özel, konuşkan, net ve benzersiz üret.
- Clickbait, sansasyon, ima, uydurma bağlam ve kaynak dışı çıkarım yok.

Seçili ayarlar:
- Dil: ${request.languageCode}
- Kategori: ${request.category.trim().isEmpty ? 'Belirtilmedi' : request.category.trim()}
- Ton/Stil: ${_toneInstruction(request.tone)}
- İçerik Türü: ${_contentTypeInstruction(request.contentType)}
- Doldurulacak Alan: ${_outputTargetInstruction(request.outputTarget, request.includeSeo)}

Seçili item planı:
${itemLines.isEmpty ? '- Ek item yok. "items" boş dizi olsun.' : itemLines}

Bölüm ve text item eşleme:
${_sectionMappingInstruction(request.itemCounts)}

Haber içeriği / ham kaynak:
${request.topic.trim()}

Editör talimatları / notlar:
${request.sourceNotes.trim()}

JSON alan kuralları:
- title: SEO uyumlu, fiil odaklı, clickbait olmayan okur başlığı.
- seoTitle: title ile aynı kalıp olmasın; arama sonucu için güçlü olsun.
- summary: vurucu spot. En fazla 2 kısa cümle.
- mainContentTitle: ilk metin bloğunun başlığıdır; mutlaka dolu olsun.
- mainContentHtml: ana haber gövdesini mümkün olduğunca tek akışta taşı. Kaynakta zorunlu büyük bölüm ayrımı yoksa h2 kullanma; uzun ve doğal bölümlü haberlerde 2-4 arası anlamlı h2 kullan. H2 forma ayrı metin bloğu olur, bu yüzden tek cümleye veya kısa paragrafa başlık açma.
- mainContentHtml kısa özet değil, tam haber olsun. Kaynakta yer alan bilgi, bölüm ve detaylar korunacak.
- Liste, kadro, forma numarası ve tablo benzeri veri varsa HTML içinde semantik ul/ol/li kullan; satırları <p> ile tek tek yazma.
- seoTitle: Google/Yandex için sayfayı doğru anlatan, tekil, açık ve tıklanabilir başlık olsun; ana anahtar ifadeyi doğal geçir, ana başlığı kopyalama.
- keywords: SEO açıksa Google'da meta keywords sıralama hilesi değildir; Yandex'te sayfa ilgisini destekleyebilir. Bu yüzden 8-14 adet, yalnız kaynakta geçen veya doğrudan kaynakla kanıtlanan, haberin ana sorgu niyetini anlatan odak etiket üret.
- Kadro/liste haberlerinde bütün isimleri keywords alanına doldurma; ana kurum/olay/yer/sorgu etiketleriyle birlikte kaynak sırasındaki merkezi 4-8 kişi adını dengeli ekle.
- Etiketlerde keyword stuffing yapma; alakasız trend, genel kelime, kaynakta olmayan kurum/proje/teknoloji ekleme. Aynı kelimenin ufak çekim farklarını tekrar etme.
- Etiket sırası: ana kişi/kurum, ana olay/proje, şehir/ilçe, rota/konu, kaynakta geçen önemli sayı veya resmi ad.
- metaDescription SEO açıksa 140-155 karakter aralığında, tek cümle gibi okunabilen, haberin en önemli bilgilerini eksiltmeden veren özgün açıklama olsun.
- faq yalnız ham metinde cevabı açıkça olan sorulardan oluşsun; kaynakta cevap yoksa boş dizi döndür.

Item kuralları:
- items dizisinde sadece seçili item planındaki tipler olsun.
- Her tipten istenen adetle birebir aynı sayıda üret.
- Her item.title ayrı ve dolu olsun; başlığı descriptionHtml içine gömme.
- Aynı tipten birden fazla item varsa her biri kaynak içindeki farklı ama gerçek bir açıya dayansın.
- text item: yalnız seçili plandaki adet kadar üret. Kısa ara başlık parçası yapma; ana gövdeyi kopyalamayan ek arka plan, takvim veya dikkat çeken detayı bağımsız ve sınırlı metin bloğu yap.
- quote item: sadece kaynakta açıkça geçen sözü kullan; sözü değiştirme, uydurma alıntı üretme.
- poll/vs item: options alanına 2-6 kısa seçenek koy; seçenekler kaynak bağlamından çıksın.
- review item: pros, cons ve criteria yalnız kaynakta ürün/inceleme verisi varsa doldur; yoksa kaynak dışı puan uydurma.
- flipcard item: frontTitle/frontDescriptionHtml/backTitle/backDescriptionHtml alanlarını gerçek iki yüzlü bilgiyle doldur.
- beforeafter item: beforeLabel ve afterLabel alanlarını kaynakta karşılaştırma varsa doldur.
- image/slider/video/audio/file/social/iframe item: URL veya embed uydurma; kullanıcı medya ekleyecek. Sadece title, descriptionHtml, altText ve source alanlarını metne dayalı doldur.
- Video iteminde sadece başlık ve açıklama yaz; videoyu kullanıcı ekleyecek.
- Eğlenceli ton seçilmediyse emoji kullanma. Eğlenceli tonda bile hassas/adli/ölüm/afet/siyaset/sağlık riskli haberlerde emoji kullanma.

Kesin çıktı:
- Sadece geçerli JSON döndür.
- Markdown açıklama veya kod bloğu döndürme.
- HTML sadece p, h2, ul, ol, li, strong kullansın.
''';
  }

  Future<String> _fetchSystemPrompt(String languageCode) async {
    final prompts = await settingsRepository.fetchPrompts(languageCode);
    for (final prompt in prompts) {
      final text = prompt.prompt.trim();
      if (prompt.isActive && text.isNotEmpty) return text;
    }
    return adminNewsAiDefaultSystemPrompt;
  }
}

String _systemPromptWithCompactStructureRule(String systemPrompt) {
  final base = systemPrompt.trim().isEmpty
      ? adminNewsAiDefaultSystemPrompt.trim()
      : systemPrompt.trim();
  final rule = adminNewsAiCompactStructureInstruction.trim();
  if (base.contains('Yapısal düzen kuralı:')) return base;
  return '$base\n\n$rule';
}

class AdminNewsAiException implements Exception {
  const AdminNewsAiException(this.message, {this.retryable = false});

  final String message;
  final bool retryable;

  @override
  String toString() => message;
}

double _temperatureForTone(String tone) {
  return switch (tone) {
    'local' => 0.55,
    'critical' => 0.42,
    'entertaining' => 0.5,
    'professional' || 'formal' => 0.32,
    _ => 0.38,
  };
}

String _toneInstruction(String tone) {
  return switch (tone) {
    'professional' =>
      'Profesyonel: ciddi, düzenli, editör standardında, abartısız.',
    'entertaining' =>
      'Eğlenceli: Onedio/BuzzFeed/Webtekno tarzı viral akıştan ilham alan ama kopya olmayan özgün PateezNews dili. Başlık, spot ve item başlıklarında ölçülü mizah ve emoji kullanılabilir; haberin anlamı, alıntılar ve gerçekler değişmez.',
    'local' =>
      'Yerel Haber Dili: İç Anadolu insanına yakın, sade, sıcak ve net.',
    'critical' =>
      'Eleştirel: veriye dayalı, ölçülü, taraf tutmadan sorgulayan.',
    'formal' =>
      'Resmi: kurum açıklamalarına uygun, saygılı, ciddi ve kontrollü.',
    _ => 'Tarafsız: yorum katmadan, net ve dengeli haber dili.',
  };
}

String _contentTypeInstruction(String contentType) {
  return switch (contentType) {
    'breaking' =>
      'Son Dakika: en önemli gelişme başta, kesinleşmeyen bilgiye temkinli dil; kaynakta olmayan ayrıntı ekleme.',
    'analysis' =>
      'Analiz: olayın nedenini, etkisini ve okura sonucunu yalnız kaynak verisinin izin verdiği ölçüde sade anlat.',
    'interview' =>
      'Röportaj: konuşan kişinin sözlerini değiştirme, soru-cevap akışını ve bağlamı koru.',
    _ =>
      'Makale Haber: başlık, spot, kaynak akışına uygun ara başlıklar ve anlaşılır detay akışı.',
  };
}

String _outputTargetInstruction(String outputTarget, bool includeSeo) {
  return switch (outputTarget) {
        'contentSeo' =>
          'İçerik + SEO: ana içerik, SEO alanları ve gerekirse FAQ üret; title ve summary boş kalabilir.',
        'seoOnly' =>
          'Sadece SEO: seoTitle, slug, metaDescription, keywords, schemaType ve FAQ üret; ana içerik boş kalabilir.',
        'social' =>
          'Sosyal Medya Dili: başlık, spot ve seçili social itemleri paylaşılabilir yaz; ana içerik üretilecekse kaynak bilgisini kısaltmadan koru.',
        _ =>
          'Tümü: title, summary, mainContentHtml, SEO alanları, keywords, schemaType ve FAQ üret.',
      } +
      (includeSeo
          ? ' SEO alanları açık.'
          : ' SEO alanları kapalıysa SEO alanlarını boş bırak.');
}

String _sectionMappingInstruction(Map<String, int> itemCounts) {
  final textCount = itemCounts['text'] ?? 0;
  if (textCount <= 0) {
    return '- Text item seçilmediyse mainContentHtml ana akışı korusun. Kısa haberde h2 üretme; uzun ve gerçek bölüm ayrımı olan kaynakta 2-4 arası anlamlı h2 kullanılabilir. "items" boş dizi olsun.';
  }
  return '- Seçili text itemler zaten ayrı blok olacağı için mainContentHtml h2 sayısını yalnız haberin doğal ana bölümleriyle sınırlı tut; kısa haberde h2 üretme, uzun ve gerçek bölümlü haberde 2-4 arası anlamlı h2 kullanılabilir. Ayrıca kullanıcı isteği için tam $textCount adet text item üret; bu text itemler kısa ara başlık parçası veya mainContentHtml kopyası olmasın, kaynakta bulunan ek arka plan, takvim veya dikkat çeken detayı bağımsız blok yapsın.';
}

int _maxOutputTokensFor(AdminNewsAiDraftRequest _) => 8192;

List<AdminNewsAiContentSection> splitAdminNewsAiContentSections({
  required String title,
  required String fallbackTitle,
  required String html,
}) {
  final sourceHtml = _cleanHtml(html);
  if (sourceHtml.isEmpty) return const [];
  final baseTitle = _cleanText(title).isNotEmpty
      ? _cleanText(title)
      : _cleanText(fallbackTitle);
  final headingPattern = RegExp(
    r'<h[23]\b[^>]*>[\s\S]*?</h[23]>',
    caseSensitive: false,
  );
  final matches = headingPattern.allMatches(sourceHtml).toList(growable: false);
  if (matches.isEmpty) {
    return [AdminNewsAiContentSection(title: baseTitle, html: sourceHtml)];
  }

  final sections = <AdminNewsAiContentSection>[];
  var cursor = 0;
  var currentTitle = baseTitle;
  for (final match in matches) {
    final before = sourceHtml.substring(cursor, match.start).trim();
    if (before.isNotEmpty) {
      sections.add(
        AdminNewsAiContentSection(title: currentTitle, html: before),
      );
    }
    final headingTitle = _htmlToPlainText(match.group(0) ?? '');
    if (headingTitle.isNotEmpty) currentTitle = headingTitle;
    cursor = match.end;
  }

  final tail = sourceHtml.substring(cursor).trim();
  if (tail.isNotEmpty) {
    sections.add(AdminNewsAiContentSection(title: currentTitle, html: tail));
  }
  if (sections.isEmpty) {
    return [AdminNewsAiContentSection(title: baseTitle, html: sourceHtml)];
  }
  return sections;
}

Map<String, Object?>? _thinkingConfigForModel(String model) {
  final id = normalizeGeminiModelId(model).toLowerCase();
  if (id.contains('gemini-3')) {
    return {'thinkingLevel': id.contains('lite') ? 'MINIMAL' : 'LOW'};
  }
  if (id.contains('gemini-2.5-pro')) {
    return {'thinkingBudget': 128};
  }
  if (id.contains('gemini-2.5-flash')) {
    return {'thinkingBudget': 0};
  }
  return null;
}

List<String> _modelAttempts(String selectedModel) {
  final selected = normalizeGeminiModelId(selectedModel);
  final attempts = <String>[
    if (selected.isNotEmpty) selected,
    'gemini-2.5-flash',
    'gemini-3.1-flash-lite',
    'gemini-2.5-flash-lite',
    'gemini-2.0-flash-lite',
    'gemini-2.0-flash',
  ];
  final seen = <String>{};
  return [
    for (final model in attempts)
      if (seen.add(model.toLowerCase())) model,
  ];
}

bool _isRetryableStatus(int statusCode) {
  return statusCode == 408 ||
      statusCode == 409 ||
      statusCode == 429 ||
      statusCode == 500 ||
      statusCode == 502 ||
      statusCode == 503 ||
      statusCode == 504;
}

AdminNewsAiDraft _enrichDraft(
  AdminNewsAiDraft draft,
  AdminNewsAiDraftRequest request,
) {
  if (!request.includeSeo) return draft;
  final source = '${request.topic}\n${request.sourceNotes}';
  final officialKeywordHints = _officialKeywordHintsFromSource(source);
  final personNameHints = _personNameKeywordHintsFromSource(source);
  if (officialKeywordHints.isEmpty && personNameHints.isEmpty) return draft;

  final keywords = _mergeKeywords(
    officialKeywordHints,
    _mergeKeywords(draft.keywords, personNameHints, limit: 14),
    limit: 14,
  );
  return AdminNewsAiDraft(
    title: draft.title,
    summary: draft.summary,
    mainContentTitle: draft.mainContentTitle,
    seoTitle: draft.seoTitle,
    slug: draft.slug,
    metaDescription: draft.metaDescription,
    schemaType: draft.schemaType,
    keywords: keywords,
    faqEntries: draft.faqEntries,
    mainContentHtml: draft.mainContentHtml,
    items: draft.items,
  );
}

List<String> _officialKeywordHintsFromSource(String source) {
  final hints = <String>[];
  final seen = <String>{};
  final normalizedSource = _normalizeKeywordSource(source);

  void add(String value) {
    final text = _cleanText(value);
    if (text.length < 3) return;
    if (seen.add(text.toLowerCase())) hints.add(text);
  }

  final titlePattern = RegExp(
    r'(?:^|[^A-Za-zÇĞİÖŞÜçğıöşü])((?:[A-ZÇĞİÖŞÜ][A-Za-zÇĞİÖŞÜçğıöşü]+|[A-ZÇĞİÖŞÜ]{2,})(?:\s+(?:[A-ZÇĞİÖŞÜ][A-Za-zÇĞİÖŞÜçğıöşü]+|[A-ZÇĞİÖŞÜ]{2,})){0,4}\s+(?:Valisi|Kaymakamı|Belediye Başkanı|Başkanı|Genel Müdürü|Müdürü|Rektörü|Milletvekili|Bakanı)\s+[A-ZÇĞİÖŞÜ][A-Za-zÇĞİÖŞÜçğıöşü]+(?:\s+[A-ZÇĞİÖŞÜ][A-Za-zÇĞİÖŞÜçğıöşü]+){1,2})(?=$|[^A-Za-zÇĞİÖŞÜçğıöşü])',
  );
  for (final match in titlePattern.allMatches(normalizedSource)) {
    final titleWithName = match.group(1) ?? '';
    add(titleWithName);
    final name = _nameFromTitleKeyword(titleWithName);
    if (name.isNotEmpty) add(name);
  }

  return hints;
}

List<String> _personNameKeywordHintsFromSource(String source) {
  const maxPersonHints = 6;
  final hints = <String>[];
  final seen = <String>{};
  final normalizedSource = _normalizeKeywordSource(source);
  final personPattern = RegExp(
    r'(?:^|[^A-Za-zÇĞİÖŞÜçğıöşü])([A-ZÇĞİÖŞÜ][A-Za-zÇĞİÖŞÜçğıöşü]{1,}(?:[ \t]+[A-ZÇĞİÖŞÜ][A-Za-zÇĞİÖŞÜçğıöşü]{1,}){1,2})(?=$|[^A-Za-zÇĞİÖŞÜçğıöşü])',
  );

  for (final match in personPattern.allMatches(normalizedSource)) {
    final text = _cleanText(match.group(1) ?? '');
    if (!_looksLikePersonNameKeyword(text)) continue;
    final key = text.toLowerCase();
    if (!seen.add(key)) continue;
    hints.add(text);
    if (hints.length >= maxPersonHints) break;
  }
  return hints;
}

String _normalizeKeywordSource(String source) {
  return source.replaceAllMapped(
    RegExp(r'\(([A-ZÇĞİÖŞÜ]{2,})\)'),
    (match) => ' ${match.group(1)} ',
  );
}

bool _looksLikePersonNameKeyword(String value) {
  final words = value
      .split(RegExp(r'\s+'))
      .map((word) => word.trim())
      .where((word) => word.isNotEmpty)
      .toList(growable: false);
  if (words.length < 2 || words.length > 3) return false;
  if (words.any(_isAllUppercaseKeywordToken)) return false;
  final lowerWords = words.map((word) => word.toLowerCase()).toSet();
  if (lowerWords.any(_nonPersonKeywordTokens.contains)) return false;
  return true;
}

bool _isAllUppercaseKeywordToken(String word) {
  return word.length > 1 &&
      word == word.toUpperCase() &&
      word != word.toLowerCase();
}

const _nonPersonKeywordTokens = {
  'abd',
  'açıklandı',
  'avustralya',
  'bakanlığı',
  'belediyesi',
  'belli',
  'dünya',
  'fifa',
  'forma',
  'futbol',
  'google',
  'haziran',
  'kadro',
  'kadrosu',
  'kanada',
  'kupası',
  'meksika',
  'milli',
  'numarası',
  'numaraları',
  'oldu',
  'oyuncuları',
  'oyuncuların',
  'takımı',
  'takımımız',
  'takımımızın',
  'türkiye',
  'uefa',
  'valiliği',
  'yandex',
};

String _nameFromTitleKeyword(String value) {
  const markers = [
    'Belediye Başkanı',
    'Genel Müdürü',
    'Milletvekili',
    'Kaymakamı',
    'Başkanı',
    'Valisi',
    'Müdürü',
    'Rektörü',
    'Bakanı',
  ];
  for (final marker in markers) {
    final index = value.indexOf(marker);
    if (index == -1) continue;
    return _cleanText(value.substring(index + marker.length));
  }
  return '';
}

List<String> _mergeKeywords(
  List<String> primary,
  List<String> secondary, {
  required int limit,
}) {
  final result = <String>[];
  final seen = <String>{};
  for (final keyword in [...primary, ...secondary]) {
    final text = _cleanText(keyword);
    if (text.isEmpty || !seen.add(text.toLowerCase())) continue;
    result.add(text);
    if (result.length >= limit) break;
  }
  return result;
}

const _draftJsonSchema = {
  'type': 'object',
  'additionalProperties': false,
  'properties': {
    'title': {
      'type': 'string',
      'description': 'Okur için dikkat çekici ama abartısız haber başlığı.',
    },
    'summary': {
      'type': 'string',
      'description': 'İki kısa cümleyi aşmayan haber spotu.',
    },
    'mainContentTitle': {
      'type': 'string',
      'description': 'Ana metin bloğunun başlık inputuna yazılacak net başlık.',
    },
    'seoTitle': {
      'type': 'string',
      'description':
          'Google/Yandex için sayfayı doğru anlatan, tekil, açık ve tıklanabilir SEO başlığı.',
    },
    'slug': {'type': 'string'},
    'metaDescription': {
      'type': 'string',
      'description':
          'SEO açıksa 140-155 karakterlik, haberin en önemli bilgisini veren doğal açıklama.',
    },
    'schemaType': {
      'type': 'string',
      'enum': [
        '',
        'NewsArticle',
        'ReportageNewsArticle',
        'OpinionNewsArticle',
        'AnalysisNewsArticle',
        'Article',
      ],
    },
    'keywords': {
      'type': 'array',
      'description':
          'SEO açıksa 8-14 odak etiket. Yalnız kaynakla kanıtlanan kişi, kurum, olay, proje, yer ve doğal sorgu ifadeleri; liste haberlerinde isimleri ölçülü seç.',
      'items': {'type': 'string'},
      'minItems': 0,
      'maxItems': 14,
    },
    'faq': {
      'type': 'array',
      'minItems': 0,
      'maxItems': 4,
      'items': {
        'type': 'object',
        'additionalProperties': false,
        'properties': {
          'question': {'type': 'string'},
          'answer': {'type': 'string'},
        },
        'required': ['question', 'answer'],
      },
    },
    'mainContentHtml': {
      'type': 'string',
      'description':
          'Tam haber metni. Kaynak bilgilerini kısaltmadan ve eksiltmeden koru; kelime hedefi yoktur. Normalde p, ul, ol, li ve strong kullan; kısa haberde h2 kullanma, uzun ve doğal bölümlü haberde 2-4 arası anlamlı h2 kullan.',
    },
    'items': {
      'type': 'array',
      'items': {
        'type': 'object',
        'additionalProperties': false,
        'properties': {
          'type': {
            'type': 'string',
            'enum': [
              'text',
              'image',
              'slider',
              'video',
              'audio',
              'file',
              'social',
              'flipcard',
              'beforeafter',
              'poll',
              'vs',
              'review',
              'quote',
              'iframe',
            ],
          },
          'title': {
            'type': 'string',
            'description':
                'Ek blok başlık inputuna yazılacak bağımsız ve net başlık.',
          },
          'descriptionHtml': {
            'type': 'string',
            'description': 'Ek bloğun açıklama veya içerik HTML metni.',
          },
          'source': {'type': 'string'},
          'altText': {'type': 'string'},
          'frontTitle': {
            'type': 'string',
            'description':
                'Flipcard ön yüz başlığı; diğer tiplerde boş olabilir.',
          },
          'frontDescriptionHtml': {
            'type': 'string',
            'description':
                'Flipcard ön yüz açıklaması; kaynak dışı bilgi eklemeden HTML metni.',
          },
          'backTitle': {
            'type': 'string',
            'description':
                'Flipcard arka yüz başlığı; diğer tiplerde boş olabilir.',
          },
          'backDescriptionHtml': {
            'type': 'string',
            'description':
                'Flipcard arka yüz açıklaması; kaynak dışı bilgi eklemeden HTML metni.',
          },
          'beforeLabel': {
            'type': 'string',
            'description':
                'Önce & Sonra iteminde önce tarafı etiketi; diğer tiplerde boş olabilir.',
          },
          'afterLabel': {
            'type': 'string',
            'description':
                'Önce & Sonra iteminde sonra tarafı etiketi; diğer tiplerde boş olabilir.',
          },
          'options': {
            'type': 'array',
            'description':
                'Poll için 2-6 cevap, VS için ilk iki karşılaştırma etiketi.',
            'items': {'type': 'string'},
            'maxItems': 6,
          },
          'pros': {
            'type': 'array',
            'description': 'İnceleme iteminde kaynakta geçen artı yönler.',
            'items': {'type': 'string'},
            'maxItems': 6,
          },
          'cons': {
            'type': 'array',
            'description': 'İnceleme iteminde kaynakta geçen eksi yönler.',
            'items': {'type': 'string'},
            'maxItems': 6,
          },
          'criteria': {
            'type': 'array',
            'description':
                'İnceleme itemi için kaynak verisine dayalı kriter ve puanlar.',
            'items': {
              'type': 'object',
              'additionalProperties': false,
              'properties': {
                'label': {'type': 'string'},
                'score': {'type': 'integer'},
              },
              'required': ['label', 'score'],
            },
            'maxItems': 6,
          },
        },
        'required': ['type', 'title', 'descriptionHtml'],
      },
    },
  },
  'required': [
    'title',
    'summary',
    'mainContentTitle',
    'seoTitle',
    'slug',
    'metaDescription',
    'schemaType',
    'keywords',
    'faq',
    'mainContentHtml',
    'items',
  ],
};

Map<String, Object?> _extractDraftJson(Map<String, Object?> response) {
  final candidates = response['candidates'];
  if (candidates is! List || candidates.isEmpty) {
    throw const AdminNewsAiException('Google AI içerik döndürmedi.');
  }
  final first = candidates.first;
  if (first is! Map) {
    throw const AdminNewsAiException('Google AI içerik yapısı geçersiz.');
  }
  final content = first['content'];
  if (content is! Map) {
    throw const AdminNewsAiException('Google AI içerik metni bulunamadı.');
  }
  final parts = content['parts'];
  if (parts is! List) {
    throw const AdminNewsAiException('Google AI içerik parçası bulunamadı.');
  }
  final text = parts
      .whereType<Map>()
      .map((part) => part['text']?.toString() ?? '')
      .join('\n')
      .trim();
  if (text.isEmpty) {
    throw const AdminNewsAiException('Google AI boş içerik döndürdü.');
  }
  final decoded = jsonDecode(_stripJsonFence(text));
  if (decoded is! Map) {
    throw const AdminNewsAiException('Google AI JSON taslağı geçersiz.');
  }
  return _asStringKeyMap(decoded);
}

void _validateItemCounts(
  AdminNewsAiDraft draft,
  Map<String, int> expectedCounts,
) {
  final expected = {
    for (final entry in expectedCounts.entries)
      if (entry.value > 0) entry.key: entry.value,
  };
  final actual = <String, int>{};
  for (final item in draft.items) {
    actual[item.type] = (actual[item.type] ?? 0) + 1;
  }
  if (expected.isEmpty) {
    if (actual.isNotEmpty) {
      throw const AdminNewsAiException('AI istenmeyen item döndürdü.');
    }
    return;
  }
  for (final entry in expected.entries) {
    if ((actual[entry.key] ?? 0) != entry.value) {
      throw AdminNewsAiException(
        'AI ${entry.key} item sayısını doğru döndürmedi.',
      );
    }
  }
  for (final entry in actual.entries) {
    if (!expected.containsKey(entry.key)) {
      throw AdminNewsAiException('AI istenmeyen ${entry.key} item döndürdü.');
    }
  }
}

String _normalizeItemType(Object? value) {
  final raw = _cleanText(value).toLowerCase();
  return switch (raw) {
    'metin' || 'textblock' => 'text',
    'resim' || 'imageblock' => 'image',
    'sliderimage' || 'gallery' => 'slider',
    'ses' => 'audio',
    'dosya' => 'file',
    'sosyal' => 'social',
    'flip' => 'flipcard',
    'beforeAfter' || 'before_after' || 'once-sonra' => 'beforeafter',
    'anket' => 'poll',
    'inceleme' => 'review',
    'alinti' => 'quote',
    _ => raw,
  };
}

String _stripJsonFence(String value) {
  var text = value.trim();
  if (text.startsWith('```')) {
    text = text.replaceFirst(RegExp(r'^```(?:json)?\s*'), '');
    text = text.replaceFirst(RegExp(r'\s*```$'), '');
  }
  return text.trim();
}

String _errorMessage(Object? error) {
  if (error is Map) {
    final message = error['message']?.toString().trim();
    if (message != null && message.isNotEmpty) return message;
  }
  return 'Google AI isteği başarısız oldu.';
}

Map<String, Object?> _asStringKeyMap(Map<dynamic, dynamic> map) {
  return map.map((key, value) => MapEntry(key.toString(), value));
}

List<Map<String, Object?>> _mapList(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is Map) _asStringKeyMap(item),
  ];
}

List<String> _stringList(Object? value, {int limit = 20}) {
  if (value is! List) return const [];
  final seen = <String>{};
  final result = <String>[];
  for (final item in value) {
    final text = _cleanText(item);
    if (text.isEmpty || !seen.add(text.toLowerCase())) continue;
    result.add(text);
    if (result.length >= limit) break;
  }
  return result;
}

String _cleanText(Object? value) {
  return (value?.toString() ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
}

String _cleanHtml(Object? value) {
  final raw = value?.toString() ?? '';
  return raw
      .replaceAll(RegExp(r'<script[\s\S]*?</script>', caseSensitive: false), '')
      .replaceAll(RegExp(r'<style[\s\S]*?</style>', caseSensitive: false), '')
      .trim();
}

String _htmlToPlainText(String html) {
  return _cleanText(
    html
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'</p>|</h[1-6]>|</li>', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>'),
  );
}

int _int(Object? value, {required int fallback}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}
