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
    this.deepResearch = false,
    this.deepResearchCompleted = false,
    this.preserveSource = false,
    this.formatType = 'article',
    this.formatSubtype = '',
    this.sourceImageUrls = const <String>[],
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
  final bool deepResearch;
  final bool deepResearchCompleted;
  final bool preserveSource;
  final String formatType;
  final String formatSubtype;
  final List<String> sourceImageUrls;
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
    required this.tabItem,
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
      tabItem: _map(json['tabItem']),
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
  final Map<String, Object?> tabItem;
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
    final systemPrompt = await _fetchSystemPrompt(
      request.languageCode,
      formatType: request.formatType,
    );

    final generationRequest = _usesGoogleSearchGrounding(request)
        ? await _requestWithDeepResearchNotes(
            request: request,
            apiKey: apiKey,
            model: model,
          )
        : request;

    AdminNewsAiException? lastError;
    for (final candidateModel in _modelAttempts(model)) {
      try {
        final draft = await _generateWithModel(
          request: generationRequest,
          apiKey: apiKey,
          model: candidateModel,
          systemPrompt: systemPrompt,
        );
        final enrichedDraft = _enrichDraft(draft, generationRequest);
        _validateItemCounts(enrichedDraft, generationRequest.itemCounts);
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

  Future<AdminNewsAiDraftRequest> _requestWithDeepResearchNotes({
    required AdminNewsAiDraftRequest request,
    required String apiKey,
    required String model,
  }) async {
    final researchNotes = await _fetchDeepResearchNotes(
      request: request,
      apiKey: apiKey,
      model: model,
    );
    final currentNotes = request.sourceNotes.trim();
    final mergedNotes = [
      if (currentNotes.isNotEmpty) currentNotes,
      'Google Search derin araştırma notları:\n$researchNotes',
    ].join('\n\n');
    return AdminNewsAiDraftRequest(
      languageCode: request.languageCode,
      category: request.category,
      tone: request.tone,
      contentType: request.contentType,
      outputTarget: request.outputTarget,
      includeSeo: request.includeSeo,
      topic: request.topic,
      sourceNotes: mergedNotes,
      itemCounts: request.itemCounts,
      deepResearchCompleted: true,
      preserveSource: request.preserveSource,
      formatType: request.formatType,
      formatSubtype: request.formatSubtype,
      sourceImageUrls: request.sourceImageUrls,
    );
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
    final body = jsonEncode(
      await _buildRequestBody(request, model, systemPrompt),
    );
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

  Future<Map<String, Object?>> _buildRequestBody(
    AdminNewsAiDraftRequest request,
    String model,
    String systemPrompt,
  ) async {
    final schema = _draftJsonSchemaFor(request);
    final generationConfig = <String, Object?>{
      'candidateCount': 1,
      'maxOutputTokens': _maxOutputTokensFor(request),
      'temperature': _temperatureForTone(request.tone, request.formatType),
      'topP': 0.9,
      'responseMimeType': 'application/json',
      'responseJsonSchema': schema,
    };
    final thinkingConfig = _thinkingConfigForModel(model);
    if (thinkingConfig != null) {
      generationConfig['thinkingConfig'] = thinkingConfig;
    }

    final userParts = <Map<String, Object?>>[
      {'text': _buildUserPrompt(request)},
      ...await _sourceImageParts(request),
    ];

    final body = <String, Object?>{
      'system_instruction': {
        'parts': [
          {'text': _systemPromptWithCompactStructureRule(systemPrompt)},
        ],
      },
      'contents': [
        {'role': 'user', 'parts': userParts},
      ],
      'generationConfig': generationConfig,
    };
    return body;
  }

  Future<List<Map<String, Object?>>> _sourceImageParts(
    AdminNewsAiDraftRequest request,
  ) async {
    if (!_isEventFormat(request.formatType)) return const [];
    final urls = [
      for (final url in request.sourceImageUrls)
        if (url.trim().isNotEmpty) url.trim(),
    ];
    if (urls.isEmpty) return const [];

    final parts = <Map<String, Object?>>[
      {
        'text':
            'Etkinlik görselleri eklendi. Afiş/poster/program görsellerindeki okunabilir metinleri birincil kaynak gibi analiz et; okunmayan küçük yazıları tahmin etme.',
      },
    ];
    for (final url in urls.take(5)) {
      final uri = Uri.tryParse(url);
      if (uri == null || !uri.hasScheme) continue;
      late final http.Response response;
      try {
        response = await (httpClient?.get(uri) ?? http.get(uri)).timeout(
          const Duration(seconds: 12),
        );
      } on TimeoutException {
        continue;
      } on Object {
        continue;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) continue;
      final mimeType = _imageMimeType(url, response.headers['content-type']);
      if (mimeType.isEmpty || response.bodyBytes.isEmpty) continue;
      parts.add({
        'inlineData': {
          'mimeType': mimeType,
          'data': base64Encode(response.bodyBytes),
        },
      });
    }
    if (parts.length == 1) {
      throw const AdminNewsAiException(
        'Etkinlik görseli AI analizi için okunamadı.',
      );
    }
    return parts;
  }

  Future<String> _fetchDeepResearchNotes({
    required AdminNewsAiDraftRequest request,
    required String apiKey,
    required String model,
  }) async {
    AdminNewsAiException? lastError;
    for (final candidateModel in _modelAttempts(model)) {
      try {
        return await _fetchDeepResearchNotesWithModel(
          request: request,
          apiKey: apiKey,
          model: candidateModel,
        );
      } on AdminNewsAiException catch (error) {
        lastError = error;
      }
    }
    throw lastError ??
        const AdminNewsAiException('Google Search araştırması yapılamadı.');
  }

  Future<String> _fetchDeepResearchNotesWithModel({
    required AdminNewsAiDraftRequest request,
    required String apiKey,
    required String model,
  }) async {
    final uri = Uri.https(
      'generativelanguage.googleapis.com',
      '/v1beta/models/$model:generateContent',
    );
    final headers = {
      'Content-Type': 'application/json',
      'x-goog-api-key': apiKey,
    };
    final body = jsonEncode(_buildDeepResearchRequestBody(request, model));
    late final http.Response response;
    try {
      response =
          await (httpClient?.post(uri, headers: headers, body: body) ??
                  http.post(uri, headers: headers, body: body))
              .timeout(_requestTimeout);
    } on TimeoutException {
      throw const AdminNewsAiException(
        'Google Search araştırması gecikti.',
        retryable: true,
      );
    }

    final decoded = response.body.trim().isEmpty
        ? <String, Object?>{}
        : jsonDecode(response.body);
    if (decoded is! Map) {
      throw const AdminNewsAiException('Google AI araştırma yanıtı geçersiz.');
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

    final text = _extractResponseText(result);
    if (text.isEmpty) {
      throw const AdminNewsAiException('Google Search araştırması boş döndü.');
    }
    return text;
  }

  Map<String, Object?> _buildDeepResearchRequestBody(
    AdminNewsAiDraftRequest request,
    String model,
  ) {
    final generationConfig = <String, Object?>{
      'candidateCount': 1,
      'maxOutputTokens': 4096,
      'temperature': 0.2,
      'topP': 0.9,
    };
    final thinkingConfig = _thinkingConfigForModel(model);
    if (thinkingConfig != null) {
      generationConfig['thinkingConfig'] = thinkingConfig;
    }

    return {
      'system_instruction': {
        'parts': [
          {
            'text':
                'Sen güvenilir web araştırması yapan Türkçe haber/quiz/anket/tarif araştırmacısısın. Yanlış veya doğrulanamayan bilgi yazma.',
          },
        ],
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': _buildDeepResearchPrompt(request)},
          ],
        },
      ],
      'tools': [
        {'googleSearch': <String, Object?>{}},
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
${_sourceRewriteRule(request)}
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
	- İçerik Türü: ${_contentTypeInstruction(request.contentType, formatType: request.formatType)}
- Doldurulacak Alan: ${_outputTargetInstruction(request.outputTarget, request.includeSeo)}
- Aktif Format/Tab: ${_formatTypeInstruction(request.formatType, request.formatSubtype)}
${_deepResearchSettingsLine(request)}
${_preserveSourceSettingsLine(request)}

Seçili item planı:
${itemLines.isEmpty ? '- Ek item yok. "items" boş dizi olsun.' : itemLines}

Bölüm ve text item eşleme:
${_sectionMappingInstruction(request)}

Aktif tab veri kuralları:
${_formatSpecificInstruction(request)}
${_preserveSourceInstruction(request)}

Haber içeriği / ham kaynak:
${request.topic.trim()}

Editör talimatları / notlar:
${request.sourceNotes.trim()}

JSON alan kuralları:
${_contentFieldRules(request)}
- seoTitle: title ile aynı kalıp olmasın; arama sonucu için güçlü olsun.
- Makale/Article formatında mainContentHtml kısa özet değil, tam haber olsun. Quiz, anket, video, içindekiler, tarif ve etkinlik formatlarında mainContentHtml kısa giriş olabilir; asıl CMS tab verisi tabItem içinde eksiksiz taşınacak.
- Liste, kadro, forma numarası ve tablo benzeri veri varsa HTML içinde semantik ul/ol/li kullan; satırları <p> ile tek tek yazma.
- tabItem: Article/Makale formatında boş nesne {} döndür. Quiz, anket, video, içindekiler, tarif ve etkinlik formatlarında aktif tabın ana CMS verisini yalnız tabItem içinde döndür.
- seoTitle: Google/Yandex için sayfayı doğru anlatan, tekil, açık ve tıklanabilir başlık olsun; ana anahtar ifadeyi doğal geçir, ana başlığı kopyalama.
- keywords: SEO açıksa Google'da meta keywords sıralama hilesi değildir; Yandex'te sayfa ilgisini destekleyebilir. Bu yüzden 8-14 adet, yalnız kaynakta geçen veya doğrudan kaynakla kanıtlanan, haberin ana sorgu niyetini anlatan odak etiket üret.
- Kadro/liste haberlerinde bütün isimleri keywords alanına doldurma; ana kurum/olay/yer/sorgu etiketleriyle birlikte kaynak sırasındaki merkezi 4-8 kişi adını dengeli ekle.
- Etiketlerde keyword stuffing yapma; alakasız trend, genel kelime, kaynakta olmayan kurum/proje/teknoloji ekleme. Aynı kelimenin ufak çekim farklarını tekrar etme.
- Etiket sırası: ana kişi/kurum, ana olay/proje, şehir/ilçe, rota/konu, kaynakta geçen önemli sayı veya resmi ad.
- metaDescription SEO açıksa 140-155 karakter aralığında, tek cümle gibi okunabilen, haberin en önemli bilgilerini eksiltmeden veren özgün açıklama olsun.
- schemaType aktif formatla uyumlu olsun: quiz için Quiz, video için VideoObject, tarif için Recipe, etkinlik için Event; haber/makale/anket/içindekiler için kaynak türüne göre NewsArticle veya Article kullan.
- faq yalnız ham metinde cevabı açıkça olan sorulardan oluşsun; kaynakta cevap yoksa boş dizi döndür.

Item kuralları:
- items dizisinde sadece seçili item planındaki tipler olsun.
- Her tipten istenen adetle birebir aynı sayıda üret.
- Her item.title ayrı ve dolu olsun; başlığı descriptionHtml içine gömme.
- Aynı tipten birden fazla item varsa her biri kaynak içindeki farklı ama gerçek bir açıya dayansın.
- text item: ${_textItemInstruction(request)}
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

  Future<String> _fetchSystemPrompt(
    String languageCode, {
    required String formatType,
  }) async {
    final prompts = await settingsRepository.fetchPrompts(languageCode);
    final activePrompts = <AdminAiPrompt>[];
    for (final prompt in prompts) {
      final text = prompt.prompt.trim();
      if (prompt.isActive && text.isNotEmpty) activePrompts.add(prompt);
    }
    if (_isQuizFormat(formatType)) {
      for (final prompt in activePrompts) {
        if (_isQuizPromptTitle(prompt.title)) return prompt.prompt.trim();
      }
      return adminQuizAiDefaultSystemPrompt;
    }
    if (_isPollFormat(formatType)) {
      for (final prompt in activePrompts) {
        if (_isPollPromptTitle(prompt.title)) return prompt.prompt.trim();
      }
      return adminPollAiDefaultSystemPrompt;
    }
    if (_isVideoFormat(formatType)) {
      for (final prompt in activePrompts) {
        if (_isVideoPromptTitle(prompt.title)) return prompt.prompt.trim();
      }
      return adminVideoAiDefaultSystemPrompt;
    }
    if (_isContentsFormat(formatType)) {
      for (final prompt in activePrompts) {
        if (_isContentsPromptTitle(prompt.title)) return prompt.prompt.trim();
      }
      return adminContentsAiDefaultSystemPrompt;
    }
    if (_isRecipeFormat(formatType)) {
      for (final prompt in activePrompts) {
        if (_isRecipePromptTitle(prompt.title)) return prompt.prompt.trim();
      }
      return adminRecipeAiDefaultSystemPrompt;
    }
    if (_isEventFormat(formatType)) {
      for (final prompt in activePrompts) {
        if (_isEventPromptTitle(prompt.title)) return prompt.prompt.trim();
      }
      return adminEventAiDefaultSystemPrompt;
    }
    for (final prompt in activePrompts) {
      if (!_isDedicatedFormatPromptTitle(prompt.title)) {
        return prompt.prompt.trim();
      }
    }
    if (activePrompts.isNotEmpty) return activePrompts.first.prompt.trim();
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

double _temperatureForTone(String tone, String formatType) {
  return switch (tone) {
    'local' => 0.55,
    'critical' => 0.42,
    'entertaining' => _isInteractiveFormat(formatType) ? 0.62 : 0.5,
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

String _sourceRewriteRule(AdminNewsAiDraftRequest request) {
  if (request.preserveSource) {
    return '- Olduğu gibi kalsın modu açık: kaynak metni, soru/cevapları, anket seçeneklerini, video başlığı/açıklamasını, içindekiler madde başlıklarını/bölüm metinlerini, tarif süre/malzeme/besin/adım metinlerini, etkinlik tarih/saat/mekan/program/not/konuşmacı metinlerini ve sonuç açıklamalarını aynen taşı; yalnız CMS alanlarına yerleştir.';
  }
  return '- Alıntı dışındaki anlatımı güvenli eş anlamlılar ve doğal cümle yapılarıyla profesyonelce yenile; anlamı değiştirme.';
}

bool _usesGoogleSearchGrounding(AdminNewsAiDraftRequest request) {
  return request.deepResearch &&
      _supportsDeepResearchFormat(request.formatType);
}

bool _isQuizFormat(String formatType) {
  return formatType.trim().toLowerCase() == 'quiz';
}

bool _isPollFormat(String formatType) {
  return formatType.trim().toLowerCase() == 'poll';
}

bool _isVideoFormat(String formatType) {
  return formatType.trim().toLowerCase() == 'video';
}

bool _isContentsFormat(String formatType) {
  return switch (formatType.trim().toLowerCase()) {
    'contents' || 'toc' || 'table of contents' => true,
    _ => false,
  };
}

bool _isRecipeFormat(String formatType) {
  return formatType.trim().toLowerCase() == 'recipe';
}

bool _isEventFormat(String formatType) {
  return formatType.trim().toLowerCase() == 'event';
}

bool _isInteractiveFormat(String formatType) {
  return _isQuizFormat(formatType) || _isPollFormat(formatType);
}

bool _supportsDeepResearchFormat(String formatType) {
  return _isInteractiveFormat(formatType) ||
      _isRecipeFormat(formatType) ||
      _isEventFormat(formatType);
}

bool _isQuizPromptTitle(String title) {
  final normalized = title.trim().toLowerCase();
  return normalized.contains('quiz') || normalized.contains('test');
}

bool _isPollPromptTitle(String title) {
  final normalized = title.trim().toLowerCase();
  return normalized.contains('anket') || normalized.contains('poll');
}

bool _isVideoPromptTitle(String title) {
  final normalized = title.trim().toLowerCase();
  return normalized.contains('video');
}

bool _isContentsPromptTitle(String title) {
  final normalized = title.trim().toLowerCase();
  return normalized.contains('çindekiler') ||
      normalized.contains('icindekiler') ||
      normalized.contains('contents') ||
      normalized.contains('toc') ||
      normalized.contains('table of contents');
}

bool _isRecipePromptTitle(String title) {
  final normalized = title.trim().toLowerCase();
  return normalized.contains('tarif') || normalized.contains('recipe');
}

bool _isEventPromptTitle(String title) {
  final normalized = title.trim().toLowerCase();
  return normalized.contains('etkinlik') ||
      normalized.contains('event') ||
      normalized.contains('festival') ||
      normalized.contains('program');
}

bool _isMediaSeoPromptTitle(String title) {
  final normalized = title.trim().toLowerCase();
  return normalized.contains('medya seo') ||
      normalized.contains('media seo') ||
      normalized.contains('ai medya') ||
      normalized.contains('yapay zeka medya');
}

bool _isInteractivePromptTitle(String title) {
  return _isQuizPromptTitle(title) || _isPollPromptTitle(title);
}

bool _isDedicatedFormatPromptTitle(String title) {
  return _isInteractivePromptTitle(title) ||
      _isVideoPromptTitle(title) ||
      _isContentsPromptTitle(title) ||
      _isRecipePromptTitle(title) ||
      _isEventPromptTitle(title) ||
      _isMediaSeoPromptTitle(title);
}

String _deepResearchSettingsLine(AdminNewsAiDraftRequest request) {
  if (_isEventFormat(request.formatType)) {
    if (request.deepResearchCompleted) {
      return '- Derin Araştırma: Tamamlandı. Google Search araştırma notları editör notlarına eklendi; etkinlikte eksik tarih, mekan, adres, organizatör, bilet/kayıt ve program alanları yalnız bu doğrulanabilir notlarla tamamlanabilir.';
    }
    return request.deepResearch
        ? '- Derin Araştırma: Açık. Google Search grounding ile eksik etkinlik tarihi, mekan, adres, organizatör, bilet/kayıt ve program bilgilerini araştır.'
        : '- Derin Araştırma: Kapalı. Etkinlik alanlarında yalnız verilen konu, kaynak metin, kaynak linki ve seçilen görsellerden çıkarılan bilgiyi kullan.';
  }
  if (_isRecipeFormat(request.formatType)) {
    if (request.deepResearchCompleted) {
      return '- Derin Araştırma: Tamamlandı. Google Search araştırma notları editör notlarına eklendi; tarifte eksik süre, porsiyon, zorluk ve besin değeri alanları yalnız bu doğrulanabilir notlarla tamamlanabilir.';
    }
    return request.deepResearch
        ? '- Derin Araştırma: Açık. Google Search grounding ile eksik tarif süreleri, porsiyon, zorluk ve besin değeri araştırması yap.'
        : '- Derin Araştırma: Kapalı. Tarif alanlarında yalnız verilen konu, kaynak metin ve kaynak linkinden çıkarılan bilgiyi kullan.';
  }
  if (!_isInteractiveFormat(request.formatType)) return '';
  final contentLabel = _isPollFormat(request.formatType) ? 'ankette' : 'quizde';
  final contentType = _isPollFormat(request.formatType) ? 'anket' : 'quiz';
  if (request.deepResearchCompleted) {
    return '- Derin Araştırma: Tamamlandı. Google Search araştırma notları editör notlarına eklendi; $contentLabel yalnız bu doğrulanabilir notları ve verilen kaynakları kullan.';
  }
  return request.deepResearch
      ? '- Derin Araştırma: Açık. Google Search grounding ile güncel, güvenilir ve SEO uyumlu $contentType araştırması yap.'
      : '- Derin Araştırma: Kapalı. Yalnız verilen konu, not ve kaynak linkinden çıkarılan metni kullan.';
}

String _preserveSourceSettingsLine(AdminNewsAiDraftRequest request) {
  if (!request.preserveSource) return '';
  return '- Olduğu gibi kalsın: Açık. Kaynak metin yeniden yazılmayacak; yalnız CMS alanlarına yerleştirilecek.';
}

String _preserveSourceInstruction(AdminNewsAiDraftRequest request) {
  if (!request.preserveSource) return '';
  final entertaining = request.tone.trim().toLowerCase() == 'entertaining';
  final toneRule = entertaining
      ? '- Ton eğlenceli ise kaynak kelimelerine dokunmadan yalnız kısa başlık, etiket veya sonuç başlığı gibi alanlara ölçülü emoji/ikon ekleyebilirsin; soru, cevap, alıntı ve ana gövde cümlelerini değiştirme.'
      : '- Emoji veya ikon ekleme; kaynak metni olduğu gibi taşı.';
  return '''

Olduğu gibi kalsın modu:
- Kaynak metin, soru, cevap, sonuç ve açıklama cümlelerini yeniden yazma, eş anlamlıya çevirme, kısaltma, genişletme veya anlatımını değiştirme.
	- Görevin metni düzenlemek değil, doğru CMS alanlarına yerleştirmektir: title, summary, mainContentHtml, items, tabItem, questions, answers, results, video alanları, recipeData ve eventData alanlarını kaynak sırasına göre doldur.
	- Kaynakta açıkça etiketlenmiş veya köşeli parantezle verilmiş bölüm işaretlerini ([Başlık], [Spot], [Ara Başlık], [İçindekiler], [Madde], [Üst Bağlantı], [Görsel Açıklaması], [İçerik], [Video Başlığı], [Video Açıklaması], [Video URL], [Tarif Başlığı], [Hazırlık Süresi], [Pişirme Süresi], [Porsiyon], [Zorluk], [Malzeme], [Besin], [Adım], [Etkinlik Tarihi], [Etkinlik Saati], [Mekan], [Organizatör], [Program], [Not], [Konuşmacı], [Soru], [Cevap], [Sonuç], [Item: Metin] gibi) alan eşleme işareti olarak kullan. Etiket içerik değilse final metne yazma; etiketin yanındaki metni ilgili alana aynen taşı.
	- SEO açık olduğunda seoTitle, slug, metaDescription, schemaType, keywords ve FAQ üret; bu alanlar kaynak metnin yerleşimini tamamlar ama kaynak cümleleri değiştirme izni vermez.
	- Kaynakta olmayan soru, cevap, anket seçeneği, video URL, tarif malzemesi, tarif adımı, etkinlik programı, etkinlik tarihi, mekan, konuşmacı, sonuç, ara başlık, iddia, tarih, sayı veya açıklama üretme. Yalnız teknik CMS alanları (id, layout, resultId, isCorrect, questionSorting, allowMultiple, showResults, endDate, isImagePoll, pollColumns, votes, showOnHomepage, orderNumber, registrationType) kaynak anlamını koruyacak şekilde tamamlanabilir.
$toneRule''';
}

String _interactiveDeepResearchInstruction(AdminNewsAiDraftRequest request) {
  final isPoll = _isPollFormat(request.formatType);
  final contentName = isPoll ? 'anket' : 'quiz';
  final contentField = isPoll
      ? 'anket seçeneği, soru bağlamı'
      : 'soru, doğru cevap veya sonuç mantığı';
  if (request.deepResearchCompleted) {
    return '- Derin araştırma tamamlandı; editör notlarındaki Google Search araştırma sonuçlarını kaynak kabul et. Notlarda doğrulanmayan, çelişkili veya şüpheli bilgiyi $contentName verisine dönüştürme.';
  }
  final enabled = request.deepResearch;
  if (!enabled) {
    return '- Derin araştırma kapalıdır; kaynakta olmayan bilgi, $contentField ekleme.';
  }
  if (isPoll) {
    return '''
- Derin araştırma açıktır: Google Search grounding ile konunun güncel bağlamını, tartışma eksenlerini, okur katılımı değerini ve arama niyetini araştır.
- Araştırmada birden fazla güvenilir kaynakla desteklenmeyen iddiayı anket sorusuna veya seçeneklerine taşıma.
- Web araştırmasını kopya metin üretmek için değil; anket sorusunu, seçenek dengesini, SEO başlık/meta/keywords ve FAQ alanlarını güçlendirmek için kullan.
- Anket özgün olsun; başka bir anketin soru kalıbını veya seçenek sırasını aynen kopyalama.
- Seçenekler dengeli, anlaşılır ve aynı ölçekte karşılaştırılabilir olsun; yönlendirici veya manipülatif seçenek yazma.''';
  }
  return '''
- Derin araştırma açıktır: Google Search grounding ile konunun güncel bağlamını, temel kavramlarını, doğru cevaplarını ve arama niyetini araştır.
- Araştırmada birden fazla güvenilir kaynakla desteklenmeyen iddiayı soru veya doğru cevap yapma.
- Web araştırmasını kopya metin üretmek için değil; quiz türünü, soru zorluğunu, SEO başlık/meta/keywords ve FAQ alanlarını güçlendirmek için kullan.
- Araştırma sonucunda konu trivia'ya daha uygunsa doğru cevaplı bilgi yarışması, kişilik/stil analizine daha uygunsa personality, uygunluk/adım kontrolüne daha uygunsa checklist üret.
- Test özgün olsun; başka bir testin soru sırasını, kalıplarını veya cevap metinlerini aynen kopyalama.''';
}

String _buildDeepResearchPrompt(AdminNewsAiDraftRequest request) {
  if (_isEventFormat(request.formatType)) {
    return _buildEventDeepResearchPrompt(request);
  }
  if (_isRecipeFormat(request.formatType)) {
    return _buildRecipeDeepResearchPrompt(request);
  }
  final isPoll = _isPollFormat(request.formatType);
  final targetLabel = isPoll ? 'anket' : 'quiz/test';
  final outputIdeaLabel = isPoll
      ? 'Ankette kullanılabilecek soru ve seçenek fikirleri'
      : 'Quizde kullanılabilecek soru fikirleri';
  final contentGoal = isPoll
      ? 'Kullanıcı için eğlenceli ama gerçek bağlama dayanan, dengeli seçenekleri olan bir anket hazırlanacak.'
      : 'Kullanıcı için eğlenceli ama gerçek bilgilere dayalı bir quiz hazırlanacak.';
  final scopeGoal = isPoll
      ? 'Konuya göre tartışma ekseni, okur katılımı değeri, seçenek dengesi, yerel/kültürel bağlam ve SEO arama niyeti çıkar.'
      : 'Şehir, tarih, coğrafya, kültür, turizm, gastronomi, ekonomi, spor ve yerel yaşam gibi doğrulanabilir başlıklardan dengeli bilgi çıkar.';
  final suspiciousRule = isPoll
      ? 'Kaynaklarda kesinleşmeyen veya ankette yönlendirici olacak bilgiyi "kullanma" diye işaretle.'
      : 'Kaynaklarda kesinleşmeyen bilgiyi "kullanma" diye işaretle.';
  return '''
Google Search ile $targetLabel için güvenilir araştırma yap.

Konu:
${request.topic.trim()}

Editör notları:
${request.sourceNotes.trim().isEmpty ? 'Yok' : request.sourceNotes.trim()}

Araştırma hedefi:
- $contentGoal
- $scopeGoal
- Zorluk/dengeli katılım seviyesi kur: kolay anlaşılır ama tekdüze olmayan fikir maddeleri belirle.
- Yanlış, söylenti, kaynaksız veya çelişkili bilgi yazma.
- $suspiciousRule
- Görsel URL üretme; görselleri admin ekleyecek.

Çıktı JSON olmasın. Türkçe kısa araştırma raporu ver:
1. Doğrulanabilir bilgi maddeleri
2. $outputIdeaLabel
3. SEO arama niyeti ve anahtar kelime önerileri
4. Kullanılmaması gereken şüpheli bilgiler varsa not
5. Yararlanılan kaynak/site adları veya URL'ler
''';
}

String _buildEventDeepResearchPrompt(AdminNewsAiDraftRequest request) {
  return '''
Google Search ile etkinlik için güvenilir araştırma yap.

Konu, link veya kaynak etkinlik:
${request.topic.trim()}

Editör notları:
${request.sourceNotes.trim().isEmpty ? 'Yok' : request.sourceNotes.trim()}

Araştırma hedefi:
- Verilen link/metin/görsel temel kaynak kabul edilecek; kaynakta dolu olan başlık, açıklama, tarih, saat, mekan, organizatör, program, bilet/kayıt ve konuşmacı bilgileri değiştirilmeyecek.
- Kaynakta eksik kalan başlangıç/bitiş zamanı, mekan adı, adres, organizatör, bilet/kayıt URL'si, ücret, kontenjan, program ve notlar için resmi kurum, mekan, belediye, bilet platformu veya güvenilir etkinlik sayfalarını araştır.
- Etkinlik geçmiş/future bilgisini net tarih üzerinden kur; tarih/saat yoksa tahmin etme.
- Program, yaş sınırı, ücret, kontenjan ve konuşmacı bilgilerini yalnız doğrulanabilir kaynaklarda açıkça geçiyorsa öner.
- Koordinat sadece güvenilir harita/adres kaynağı açıkça veriyorsa yazılabilir; emin değilsen boş bırak.
- Görsel URL üretme; admin seçtiği görselleri ayrıca CMS bloklarına yerleştirecek.
- Çelişkili veya doğrulanamayan bilgiyi "kullanma" diye işaretle.

Çıktı JSON olmasın. Türkçe kısa araştırma raporu ver:
1. Doğrulanabilir etkinlik bilgileri
2. Eksik alanları tamamlamak için önerilen tarih, mekan, adres, kayıt/bilet, program ve not bilgileri
3. Çelişkili veya kullanılmaması gereken bilgiler
4. Yararlanılan kaynak/site adları veya URL'ler
''';
}

String _buildRecipeDeepResearchPrompt(AdminNewsAiDraftRequest request) {
  return '''
Google Search ile tarif için güvenilir araştırma yap.

Konu veya kaynak tarif:
${request.topic.trim()}

Editör notları:
${request.sourceNotes.trim().isEmpty ? 'Yok' : request.sourceNotes.trim()}

Araştırma hedefi:
- Verilen link/metin temel kaynak kabul edilecek; kaynakta dolu olan başlık, açıklama, süre, porsiyon, zorluk, malzeme, besin değeri ve adım metinleri değiştirilmeyecek.
- Kaynakta eksik kalan prepTime, cookTime, serving, difficulty ve nutrition değerleri için güvenilir tarif/nutrition kaynaklarından makul, porsiyon başına kullanılabilir değerleri araştır.
- Besin değerlerinde Calories, Total Fat, Saturated Fat, Cholesterol, Sodium, Total Carbohydrates, Dietary Fiber, Sugars ve Protein varsa değer ve birimleri yakala.
- Malzeme listesi veya tarif adımı uydurma; yalnız kaynakta açıkça verilen malzeme ve adımları kullan.
- Sağlık iddiası, diyet iddiası veya kesin tıbbi yorum yazma.
- Görsel, video veya medya URL üretme; admin ekleyecek.
- Çelişkili veya doğrulanamayan değeri "kullanma" diye işaretle.

Çıktı JSON olmasın. Türkçe kısa araştırma raporu ver:
1. Doğrulanabilir tarif bilgileri
2. Eksik alanları tamamlamak için önerilen süre, porsiyon, zorluk ve besin değerleri
3. Besin değerlerinde kullanılan porsiyon varsayımı
4. Kullanılmaması gereken şüpheli veya çelişkili bilgiler
5. Yararlanılan kaynak/site adları veya URL'ler
''';
}

String _contentTypeInstruction(
  String contentType, {
  required String formatType,
}) {
  if (_isVideoFormat(formatType) &&
      contentType.trim().toLowerCase() == 'article') {
    return 'Video Haber: ilk CMS bloğu video olacak; başlık, spot, video açıklaması, kaynak/URL alanları ve SEO haber disipliniyle hazırlansın.';
  }
  if (_isContentsFormat(formatType) &&
      contentType.trim().toLowerCase() == 'article') {
    return 'İçindekiler/Listeli İçerik: başlık, spot, içindekiler listesi, bölüm metinleri, üst bağlantılar ve SEO alanları eksiksiz hazırlansın.';
  }
  if (_isRecipeFormat(formatType) &&
      contentType.trim().toLowerCase() == 'article') {
    return 'Tarif: başlık, spot, tarif açıklaması, hazırlık/pişirme süresi, porsiyon, zorluk, malzemeler, besin değerleri, adımlar ve SEO Recipe alanları eksiksiz hazırlansın.';
  }
  if (_isEventFormat(formatType) &&
      contentType.trim().toLowerCase() == 'article') {
    return 'Etkinlik: başlık, spot, etkinlik açıklaması, tarih/saat, mekan, adres, organizatör, bilet/kayıt, program, notlar, konuşmacılar ve SEO Event alanları eksiksiz hazırlansın.';
  }
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

String _contentFieldRules(AdminNewsAiDraftRequest request) {
  if (request.preserveSource) {
    return '''
- title: kaynakta [Başlık] veya açık başlık varsa aynen taşı; yoksa kaynak konudan en kısa başlığı kaynak kelimelerini değiştirmeden çıkar.
- summary: kaynakta [Spot] veya açık özet varsa aynen taşı; yoksa kaynak ilk kısa açıklamayı değiştirmeden kullan.
- mainContentTitle: ilk metin bloğunun başlığıdır; kaynakta işaretli başlık varsa aynen taşı, yoksa title ile uyumlu kaynak ifadesini kullan.
- mainContentHtml: kaynak gövdesini aynen ve eksiksiz taşı; yalnız güvenli HTML etiketlerine dönüştür. [Ara Başlık] veya açık bölüm başlıklarını h2 yap; olmayan ara başlığı üretme.''';
  }
  return '''
- title: SEO uyumlu, fiil odaklı, clickbait olmayan okur başlığı.
- summary: vurucu spot. En fazla 2 kısa cümle.
- mainContentTitle: ilk metin bloğunun başlığıdır; mutlaka dolu olsun.
- mainContentHtml: Makale/Article formatında ana haber gövdesini mümkün olduğunca tek akışta taşı. Kaynakta zorunlu büyük bölüm ayrımı yoksa h2 kullanma; uzun ve doğal bölümlü haberlerde 2-4 arası anlamlı h2 kullan. H2 forma ayrı metin bloğu olur, bu yüzden tek cümleye veya kısa paragrafa başlık açma.''';
}

String _textItemInstruction(AdminNewsAiDraftRequest request) {
  if (request.preserveSource) {
    return 'yalnız seçili plandaki adet kadar üret. Kaynakta [Item], [Ek Bilgi], [Ara Bilgi] veya doğal ayrılmış ek bloklar varsa title ve descriptionHtml alanlarına cümle değiştirmeden taşı; yeni metin uydurma.';
  }
  return 'yalnız seçili plandaki adet kadar üret. Kısa ara başlık parçası yapma; ana gövdeyi kopyalamayan ek arka plan, takvim veya dikkat çeken detayı bağımsız ve sınırlı metin bloğu yap.';
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

String _sectionMappingInstruction(AdminNewsAiDraftRequest request) {
  final textCount = request.itemCounts['text'] ?? 0;
  final requestedItemCount = _requestedAiItemCount(request);
  final isVideo = _isVideoFormat(request.formatType);
  final isContents = _isContentsFormat(request.formatType);
  final isRecipe = _isRecipeFormat(request.formatType);
  final isEvent = _isEventFormat(request.formatType);
  if (request.preserveSource) {
    if (isVideo) {
      if (textCount <= 0) {
        return '- Olduğu gibi kalsın açık: ilk video bloğunu kaynakta görünen video başlığı, açıklaması, URL ve kaynak bilgisiyle aynen tabItem içine yerleştir; ek item seçilmediyse "items" boş dizi olsun.';
      }
      return '- Olduğu gibi kalsın açık: ilk video bloğunu aynen tabItem içine yerleştir. Ayrıca $textCount adet text item için kaynakta işaretli veya doğal ayrılmış ek blokları cümle değiştirmeden kullan; tabItem video verisini items içine kopyalama.';
    }
    if (isContents) {
      return '- Olduğu gibi kalsın açık: kaynakta Table of Contents/İçindekiler listesi, "Kaynak HTML başlık hiyerarşisi ve bölüm metni" bloğu veya H2/H3/H4 bölüm akışı varsa her başlığı kaynak sırasıyla tabItem.tocData.items içine yerleştir; üst-alt ilişkiyi parentId alanına, bölüm metinlerini cümle değiştirmeden ilgili item.content alanına taşı. Genel "items" boş dizi olsun.';
    }
    if (isRecipe) {
      return '- Olduğu gibi kalsın açık: tarif başlığı, açıklama, süreler, porsiyon, zorluk, malzemeler, besin değerleri, adımlar ve kaynakta verilen yemek videosu başlık/açıklama/URL bilgisini kaynak sırasıyla tabItem.recipeData içine cümle/değer değiştirmeden yerleştir. Genel "items" boş dizi olsun.';
    }
    if (isEvent) {
      if (requestedItemCount > 0) {
        return '- Olduğu gibi kalsın açık: etkinlik başlığı, açıklama, tarih/saat, mekan, organizatör, adres, program, not ve konuşmacı bilgilerini kaynak/görsel sırasıyla tabItem.eventData içine cümle/değer değiştirmeden yerleştir. Ayrıca seçili item planındaki ek itemleri tam adetle "items" içinde üret; tabItem.eventData program/not/konuşmacı verisini aynen kopyalayıp şişirme, her item etkinlik kaynağındaki farklı ve gerçek bir bilgi açısına dayansın.';
      }
      return '- Olduğu gibi kalsın açık: etkinlik başlığı, açıklama, tarih/saat, mekan, organizatör, adres, program, not ve konuşmacı bilgilerini kaynak/görsel sırasıyla tabItem.eventData içine cümle/değer değiştirmeden yerleştir. Genel "items" boş dizi olsun.';
    }
    if (request.formatType.trim().toLowerCase() != 'article') {
      if (textCount <= 0) {
        return '- Olduğu gibi kalsın açık: aktif tab verisini kaynakta görünen soru, cevap, sonuç, açıklama ve işaretli bloklardan aynen tabItem içine yerleştir; ek item seçilmediyse "items" boş dizi olsun.';
      }
      return '- Olduğu gibi kalsın açık: aktif tab verisini aynen tabItem içine yerleştir. Ayrıca $textCount adet text item için kaynakta işaretli veya doğal ayrılmış ek blokları cümle değiştirmeden kullan; tabItem verisini items içine kopyalama.';
    }
    if (textCount <= 0) {
      return '- Olduğu gibi kalsın açık: mainContentHtml kaynak akışını aynen korusun; [Ara Başlık] gibi işaretler varsa h2 olarak yerleştir, yoksa yeni ara başlık üretme. "items" boş dizi olsun.';
    }
    return '- Olduğu gibi kalsın açık: mainContentHtml kaynak akışını aynen korusun. Tam $textCount adet text item için kaynakta [Item], [Ek Bilgi], [Ara Bilgi] veya doğal ayrılmış blokları cümle değiştirmeden kullan; yeni metin uydurma.';
  }
  if (isVideo) {
    if (textCount <= 0) {
      return '- Aktif format video haberdir; ilk video bloğu tabItem içinde üretilecek. Ek item seçilmediyse "items" boş dizi olsun; tabItem video verisini items içine kopyalama.';
    }
    return '- Aktif format video haberdir; ilk video bloğu tabItem içinde üretilecek. Kullanıcı ayrıca $textCount adet text item seçtiyse "items" içinde yalnız bu ek metin bloklarını üret; tabItem video verisini items içine kopyalama.';
  }
  if (isContents) {
    return '- Aktif format içindekiler/listeli içeriktir; tüm liste ve bölüm verileri tabItem.tocData.items içinde üretilecek. Genel "items" dizisi boş kalsın; içindekiler maddelerini items içine kopyalama.';
  }
  if (isRecipe) {
    return '- Aktif format tariftir; ana tarif verisi ve tarif tabındaki Yemek Videosu alt bloğuna ait başlık/açıklama/URL tabItem.recipeData içinde üretilecek. Genel "items" dizisi boş kalsın; tarif veya yemek videosu verisini items içine kopyalama.';
  }
  if (isEvent) {
    if (requestedItemCount > 0) {
      return '- Aktif format etkinliktir; ana etkinlik verisi tabItem.eventData içinde üretilecek. Kullanıcı ayrıca item seçtiyse "items" içinde yalnız seçili item planındaki ek blokları üret; eventData programı/notları/konuşmacıları items içine kopyalama, item başlık ve açıklamalarını etkinlik kaynağındaki gerçek farklı detaylardan yaz.';
    }
    return '- Aktif format etkinliktir; ana etkinlik verisi tabItem.eventData içinde üretilecek. Genel "items" dizisi boş kalsın; etkinlik programı/notları/konuşmacıları items içine kopyalama.';
  }
  if (request.formatType.trim().toLowerCase() != 'article') {
    if (textCount <= 0) {
      return '- Aktif format article değildir; mainContentHtml kısa giriş olabilir, ana tab verisi tabItem içinde üretilecek. Ek item seçilmediyse "items" boş dizi olsun.';
    }
    return '- Aktif format article değildir; ana tab verisi tabItem içinde üretilecek. Kullanıcı ayrıca $textCount adet text item seçtiyse "items" içinde yalnız bu ek metin bloklarını üret; tabItem verisini items içine kopyalama.';
  }
  if (textCount <= 0) {
    return '- Text item seçilmediyse mainContentHtml ana akışı korusun. Kısa haberde h2 üretme; uzun ve gerçek bölüm ayrımı olan kaynakta 2-4 arası anlamlı h2 kullanılabilir. "items" boş dizi olsun.';
  }
  return '- Seçili text itemler zaten ayrı blok olacağı için mainContentHtml h2 sayısını yalnız haberin doğal ana bölümleriyle sınırlı tut; kısa haberde h2 üretme, uzun ve gerçek bölümlü haberde 2-4 arası anlamlı h2 kullanılabilir. Ayrıca kullanıcı isteği için tam $textCount adet text item üret; bu text itemler kısa ara başlık parçası veya mainContentHtml kopyası olmasın, kaynakta bulunan ek arka plan, takvim veya dikkat çeken detayı bağımsız blok yapsın.';
}

int _requestedAiItemCount(AdminNewsAiDraftRequest request) {
  return request.itemCounts.values.fold<int>(
    0,
    (total, count) => count > 0 ? total + count : total,
  );
}

String _formatTypeInstruction(String formatType, String formatSubtype) {
  final subtype = formatSubtype.trim();
  final suffix = subtype.isEmpty ? '' : ' / alt tür: $subtype';
  return switch (formatType.trim().toLowerCase()) {
    'quiz' => 'Quiz/Test$suffix',
    'poll' => 'Anket$suffix',
    'video' => 'Video Haber$suffix',
    'contents' ||
    'toc' ||
    'table of contents' => 'İçindekiler/Listeli İçerik$suffix',
    'recipe' => 'Tarif$suffix',
    'event' => 'Etkinlik$suffix',
    _ => 'Makale Haber$suffix',
  };
}

String _formatSpecificInstruction(AdminNewsAiDraftRequest request) {
  final subtype = request.formatSubtype.trim().toLowerCase();
  return switch (request.formatType.trim().toLowerCase()) {
    'quiz' =>
      '''
- Aktif tab quiz/testtir. Article akışını bozma: mainContentHtml yalnız kısa, davetkar bir giriş olabilir; items yalnız seçili ek item planını taşısın.
- tabItem.type kesin "quiz" olsun; tabItem.title ve tabItem.descriptionHtml dolu olsun.
- quizData.quizType otomatik belirlensin: ölçülebilir doğru cevap ve kaynaklı bilgi varsa "trivia", kişilik/stil/uyum sonucu varsa "personality", yapılacaklar/uygunluk/kontrol mantığı varsa "checklist". Alt tür ipucu "${subtype.isEmpty ? 'yok' : subtype}" ama konu daha uygun başka tür gerektiriyorsa quizType'ı düzelt.
- Kullanıcı yalnız konu verdiyse test mimarisini sen kur: soru sayısı, cevap sayısı, sonuç sayısı, quizType, questionSorting, allowMultiple, showResults ve endDate değerlerini konuya göre profesyonel seç. Gereksiz soru şişirme yok; kısa test 5-6, zengin konu 7-10 soru olabilir. Kaynakta hazır test, açık soru listesi veya editörün istediği net soru sayısı varsa bu sayıyı azaltma; 15 soruluk bilgi yarışması 15 soru olarak taşınsın.
- quizData.questions her soruda id, title, image, description, layout ve answers alanlarını taşısın. Her description alanı 1 kısa cümlelik soru açıklaması olsun; boş bırakma, sonuç açıklaması yazma. Cevaplar kısa, doğal ve birbirinden ayırt edilebilir olsun; her soru 2-5 cevap içersin. Her answer içinde id, text, image, resultId, isCorrect ve explanation alanları kullanılabilir.
- quizData.results her quiz türünde dolu olsun. Personality/checklist için 3-5 sonuç profili üret; trivia için doğru cevap sayısına göre skor bandı üret ve her result içinde minScore ile maxScore alanlarını doldur. Skor bandı 0'dan toplam soru sayısına kadar boşluk ve çakışma olmadan kapsasın. answerCount alanını yalnız tek bir doğru sayısına özel sonuç gerekiyorsa kullan; genel skor bandı için kullanma.
- Trivia/test alt türünde her soruda tam bir doğru cevap için isCorrect true kullan; kaynakta veya araştırmada doğrulanamayan doğru cevap uydurma. Doğru cevabın "Cevap sonrası açıklama" metnini correct answer'ın explanation alanına kısa ve net yaz; yanlış cevapların explanation alanı boş olabilir.
- Personality/checklist alt türlerinde cevapların resultId değerleri results içindeki id değerleriyle eşleşsin; cevabın götürdüğü sonuç mantığı açık ve tutarlı olsun.
${_quizSourceTextInstruction(request)}
${_quizToneStyleInstruction(request)}
- Görsel URL uydurma; image alanları boş kalsın. Linkten görsel seçilirse uygulama adminin seçtiği görseli ayrıca kullanır.
- questionSorting normalde "asc" olsun; kaynak ters akış gerektiriyorsa "desc", soru numaraları gizlenmeli ise "hide" seçilebilir. allowMultiple sadece çoklu doğru cevap veya checklist mantığı varsa true olsun. showResults true olsun; endDate kaynakta yoksa boş string olsun.
${_interactiveDeepResearchInstruction(request)}''',
    'poll' =>
      '''
- Aktif tab ankettir. Bu akış quiz/test akışından bağımsızdır; quizData, results, isCorrect veya resultId üretme. Article akışını bozma: mainContentHtml yalnız kısa, davetkar bir giriş olabilir; items boş dizi olsun.
- tabItem.type kesin "poll" olsun; tabItem.title ve tabItem.descriptionHtml dolu olsun.
- Kullanıcı yalnız konu verdiyse anket mimarisini sen kur: soru sayısı, seçenek sayısı, seçenek tonu, layout, isImagePoll ve pollColumns değerlerini konuya göre profesyonel seç. Tek soru yeterliyse 1 soru; zengin kaynak veya editörün verdiği çok sorulu anket varsa tamamını taşı. Kaynakta 15 anket sorusu varsa pollData.questions tam 15 soru içersin.
- tabItem.title genel anket başlığıdır; tabItem.descriptionHtml kısa giriş/bağlamdır. Tek tek oylanacak soruların tamamı tabItem.pollData.questions içinde olmalıdır.
- pollData.questions her soruda id, title, descriptionHtml, source, mediaUrl, showOnHomepage, isImagePoll, pollColumns ve options alanlarını taşısın. Her question.title dolu ve net bir anket sorusu olsun; boş string olamaz. Soru başlığı editördeki "Anket Sorusu / Başlık" inputuna gidecek ana metindir; soru metnini yalnız descriptionHtml içine gömme.
- Her question.options her seçenekte id, text, image ve votes alanlarını taşısın. text kısa, doğal, aynı ölçekte karşılaştırılabilir ve birbirinden ayırt edilebilir olsun. votes yeni anket için 0 olsun.
- tabItem.options geriye uyumluluk için ilk anket sorusunun options alanını aynen yansıtabilir; asıl çoklu soru verisi pollData.questions içindedir.
- Kaynakta hazır anket sorusu ve seçenekleri varsa eksiltme; "Olduğu gibi kalsın" açık değilse anlamı koruyarak özgünleştir. Kaynakta seçenek yoksa konuya göre dengeli seçenekler üret ama kaynak dışı iddia, tarih, sayı veya kişi isnadı ekleme.
- isImagePoll metin ağırlıklı ankette false olsun. Görsel cevap kartı gerekiyorsa true seç, pollColumns 2 veya 3 olsun; image ve mediaUrl alanlarında URL uydurma, görselleri admin ekleyecek.
- source alanını yalnız kaynak URL/metin açıkça verildiyse doldur; showOnHomepage false kalsın.
${_pollSourceTextInstruction(request)}
${_interactiveDeepResearchInstruction(request)}''',
    'video' =>
      '''
	- Aktif tab video haberdir. Article akışındaki genel başlık, spot, SEO, FAQ, "Olduğu gibi kalsın" ve ek item davranışı korunur; ancak ilk CMS itemi her zaman video tabına özel tabItem içindedir.
	- tabItem.type kesin "video" olsun. tabItem video tabındaki ilk "Video İçerik Bloğu" alanına yerleşecek; bu ilk video bloğunu items içine ayrıca kopyalama.
	- tabItem.title video bloğu başlığıdır; boş bırakma, descriptionHtml içine gömme.
	- tabItem.descriptionHtml video için okunur, tam ve haber bağlamına sadık açıklama olsun. HTML sadece p, ul, ol, li, strong kullansın.
	- tabItem.source yalnız kaynakta video kaynağı, kurum, platform, ajans veya kredi bilgisi açıkça varsa dolsun.
	- Kullanıcı açıkça video, YouTube, embed veya doğrudan dosya URL'si verdiyse tabItem.mediaUrl alanına aynen taşı; verilmediyse mediaUrl boş kalsın. URL uydurma, temsili link üretme.
	- tabItem.showOnHomepage yalnız editör açıkça isterse true olsun; aksi halde false kalsın.
	- mainContentHtml video haber için kısa giriş/bağlam metni olabilir; asıl video bloğu tabItem içindedir.
	- items yalnız seçili ek item planını taşısın. Ek item seçilmediyse items boş dizi olsun. Kullanıcı ek "video" item seçtiyse bu ilk tabItem'dan ayrı ek video bloğudur.
	${_videoSourceTextInstruction(request)}''',
    'contents' || 'toc' || 'table of contents' =>
      '''
- Aktif tab içindekiler/listeli içeriktir. Article akışındaki genel başlık, spot, SEO, FAQ ve "Olduğu gibi kalsın" davranışı korunur; ancak liste ve bölüm verilerinin tamamı tabItem.tocData içindedir.
- tabItem.type kesin "toc" olsun. tabItem.title kaynakta özel içindekiler/list başlığı varsa onu, yoksa "Table of Contents" değerini taşısın.
- tabItem.descriptionHtml kaynakta listeye ait kısa açıklama varsa dolsun; yoksa boş string olabilir. Bölüm metinlerini descriptionHtml içine yığma.
- tabItem.tocData.linkListStyle zorunludur; level1, level2 ve level3 alanları "none", "decimal", "decimal-leading-zero", "circle", "disc", "square", "lower-alpha", "upper-alpha", "lower-roman" veya "upper-roman" değerlerinden biri olsun.
- Kaynak hiyerarşikse veya "Kaynak HTML başlık hiyerarşisi ve bölüm metni" bloğunda [LI L1]/[LI L2], [H2]/[H3] ya da [H3 L1]/[H3 L2] işaretleri varsa level1 ve level2 için "decimal" kullan; üçüncü seviye yoksa level3 "none" kalsın. Kaynak düz listeyse yalnız level1 "decimal", diğer seviyeler "none" olabilir.
- tabItem.tocData.showInText zorunludur; level1, level2 ve level3 boolean dönsün. Kaynakta liste numaralarının metin içinde görüneceği açıkça istenmiyorsa false kullan.
- tabItem.tocData.items kaynakta Table of Contents/İçindekiler listesinde, "Kaynak HTML başlık hiyerarşisi ve bölüm metni" bloğunda veya H2/H3/H4 bölüm akışında kaç başlık varsa tamamını kaynak sırasıyla taşısın. Kullanıcı yalnız konu verdiyse 4-8 anlamlı bölüm üret; kaynakta 10 bölüm varsa 10 bölümün tamamını taşı.
- Table of Contents listesi gövde bölüm başlıklarından daha kısa veya düz görünüyorsa gövdedeki H2/H3/H4 ya da [H* L*] akışı esas alınır; hiçbir gerçek alt başlığı parent madde içinde eritme veya tek iteme özetleme.
- Her item içinde id, title, parentId, image, imageDescription, content ve orderNumber alanları eksiksiz olsun. title boş kalmasın; content ilgili başlığın metnidir ve boş kalmasın.
- id değerleri stabil ve kısa olsun: düz listede "1", "2", "3"; hiyerarşik listede üst madde "1", alt madde "1.1", üçüncü seviye "1.1.1" gibi olsun.
- parentId hiyerarşik kaynakta tam üst maddenin id değerini taşısın: "1.1" için parentId "1", "1.1.1" için parentId "1.1". En üst seviye maddelerde parentId boş string kalsın. Üst bağlantı alanı boş kalıyorsa yalnız kaynak gerçekten düz listedir.
- orderNumber ekrandaki sıra numarasıdır; 1'den başlasın ve kaynak sırasını izlesin.
- image ve imageDescription yalnız kaynakta o maddeye ait açık görsel URL/açıklama varsa dolsun; yoksa boş string kalsın. Görsel URL uydurma.
- content HTML sadece p, ul, ol, li ve strong kullansın. İçerikte h2/h3 üretme; başlık zaten item.title alanındadır.
- mainContentHtml içindekiler haberinde kısa giriş/bağlam olabilir; bölüm metinlerinin ana kopyası tabItem.tocData.items[].content alanındadır.
- Genel items dizisi boş olsun; içindekiler maddelerini items içine kopyalama.
${_tocSourceTextInstruction(request)}''',
    'recipe' =>
      '''
- Aktif tab tariftir. Article akışındaki genel başlık, spot, SEO, FAQ, "Olduğu gibi kalsın" ve kaynak okuma davranışı korunur; ancak tarif verisinin tamamı tabItem.recipeData içindedir.
- tabItem.type kesin "recipe" olsun. tabItem.title tarif bloğu başlığıdır; boş bırakma, descriptionHtml içine gömme.
- tabItem.descriptionHtml tarifin kısa giriş/açıklama metnidir; kaynakta giriş açıklaması varsa onu kullan, yoksa 1 kısa paragraf yazılabilir.
- recipeData.prepTime, cookTime ve serving alanlarını kaynakta açıkça verilen değerlerle doldur. Kaynakta "Prep Time 15 min", "Cook Time 35 min", "Serving 6" gibi alanlar varsa süre/porsiyon kelimelerini ve değerleri aynen taşı.
- recipeData.difficulty teknik select value'dur; yalnız "easy", "medium", "hard" veya kaynakta zorluk yoksa "" dön. Easy/Beginner/Kolay değerlerini "easy", Intermediate/Medium/Orta değerlerini "medium", Advanced/Hard/Zor değerlerini "hard" olarak map et.
- recipeData.ingredients kaynakta kaç malzeme varsa tamamını kaynak sırasıyla taşısın. Her ingredient.text tek satır malzemedir; miktar, birim, parantez içi açıklama ve opsiyonel notlar değiştirilmez.
- recipeData.nutrition kaynakta kaç besin değeri varsa tamamını label/value olarak taşısın. "Protein" gibi değeri boş gelen satırlarda kaynakta değer yoksa value boş string kalabilir.
- recipeData.directions kaynakta kaç adım varsa tamamını kaynak sırasıyla taşısın. Her adımda id, title, content, image, imageDescription ve orderNumber dolu şema alanları dönsün; image ve imageDescription kaynakta yoksa boş string.
- direction.title adım başlığıdır; content içine tekrar gömme. direction.content HTML sadece p, ul, ol, li ve strong kullansın.
- recipeData.videoTitle, videoDescriptionHtml ve videoUrl yalnız Tarif tabındaki "Yemek Videosu" alt bloğu içindir; genel Video tabı değildir. Kaynakta "Yemek Videosu Başlığı", "Yemek Videosu Açıklaması", "Video URL", YouTube veya embed linki varsa bu alanlara taşı. Kaynakta video bilgisi yoksa üçü de boş string kalsın. Video item üretme; items boş kalsın.
- mainContentHtml tarif için kısa giriş olabilir; malzeme, besin değeri, adımlar ve yemek videosu bilgisini mainContentHtml içine yığma. Genel items dizisi boş olsun; tarif verisini items içine kopyalama.
- Görsel URL, video URL, embed, pişirme sıcaklığı, süre, porsiyon, besin değeri veya malzeme uydurma; videoUrl yalnız kaynakta açıkça verilen link ise dolsun.
${_recipeSourceTextInstruction(request)}
${_recipeDeepResearchInstruction(request)}''',
    'event' =>
      '''
- Aktif tab etkinliktir. Article akışındaki genel başlık, spot, SEO, FAQ, "Olduğu gibi kalsın" ve kaynak okuma davranışı korunur; ancak etkinlik verisinin tamamı tabItem.eventData içindedir.
- tabItem.type kesin "event" olsun. tabItem.title etkinlik bloğu başlığıdır; boş bırakma, descriptionHtml içine gömme.
- tabItem.descriptionHtml etkinlik için kısa giriş/açıklama metnidir; kaynakta giriş açıklaması varsa onu kullan, yoksa yalnız kaynak/görselin izin verdiği ölçüde 1 kısa paragraf yaz.
- eventData.startDateTime ve endDateTime alanları CMS input formatına uygun metin olmalı: "gg.aa.yyyy --:--" veya kaynakta saat varsa "gg.aa.yyyy HH:mm". Tarih/saat yoksa boş string; yıl, ay, gün veya saat tahmin etme.
- eventData.organizer, venueName, address, ticketUrl, ticketPrice ve capacity alanlarını yalnız kaynakta, linkte, araştırma notlarında veya okunabilir görsel metninde açıkça varsa doldur.
- eventData.latitude ve longitude yalnız güvenilir kaynakta koordinat açıkça varsa string olarak yaz; adresi koordinata çevirerek tahmin etme.
- eventData.registrationType teknik select value'dur; yalnız "none", "required", "tickets" veya "external" dön. Biletli/ücretli etkinlikte "tickets", harici kayıt linki varsa "external", kayıt/rezervasyon gerekiyor ama bilet yoksa "required", açık bilgi yoksa "none".
- eventData.scheduleTitle, highlightsTitle ve speakersTitle alanları boş kalmasın; içerik yoksa varsayılan kısa başlıklar kullanılabilir.
- eventData.schedule kaynakta veya görselde kaç program/oturum/oyun/konser gösteriliyorsa okunabildiği kadarıyla kaynak sırasıyla taşısın. Her schedule item id, date, time, title, description, image ve imageDescription alanlarını taşısın; image URL uydurma.
- schedule.date CMS satırı için "gg.aa.yyyy" biçiminde veya kaynakta yazıldığı biçimde; schedule.time kaynakta görünen saat aralığıdır. Açık saat yoksa boş string.
- eventData.highlights etkinlik notlarıdır: yaş sınırı, ücretsiz/ücretli bilgi, kayıt şartı, süre, festival aralığı, erişim, kontenjan gibi açık bilgiler label/value olarak yazılır. Açık bilgi yoksa boş dizi.
- eventData.speakers yalnız kaynakta konuşmacı, sanatçı, moderatör, eğitmen veya konuk bilgisi varsa doldur; yoksa boş dizi. Kişi adı/rol uydurma.
- Seçilen etkinlik görselleri varsa afiş/poster/program görsellerindeki okunabilir metinleri birincil kaynak gibi kullan. Düşük çözünürlüklü veya okunmayan küçük yazıları tahmin etme; yalnız net okunan isim/tarih/saat/mekan bilgisini yaz.
${_eventItemsInstruction(request)}
- Görsel URL, bilet URL'si, mekan, konuşmacı, koordinat, tarih, saat, fiyat veya kontenjan uydurma.
${_eventSourceTextInstruction(request)}
${_eventDeepResearchInstruction(request)}''',
    _ =>
      '''
- Aktif tab makale haberdir. Mevcut article üretim davranışı korunur.
- tabItem boş nesne {} olsun.
- mainContentHtml tam haber gövdesini taşısın; items yalnız seçili item planındaki ek blokları taşısın.''',
  };
}

String _quizSourceTextInstruction(AdminNewsAiDraftRequest request) {
  if (request.preserveSource) {
    return '- Olduğu gibi kalsın açıkken mevcut soru, cevap, doğru cevap, sonuç ve açıklamaları aynen taşı; "Cevap sonrası açıklama" metnini doğru cevabın explanation alanına aynen yerleştir. Yalnız id, layout, resultId, isCorrect, minScore, maxScore ve sıralama gibi teknik CMS alanlarını tamamla.';
  }
  return '- Test linkinden gelen kaynakta mevcut soru, cevap, doğru cevap, sonuç ve açıklamaları eksiltme. Kopya gibi görünmeyecek şekilde eş anlamlı kelimeler ve yeni cümle düzeni kullan; anlamı, doğru cevabı, sonuç mantığını, özel adları, tarihleri ve rakamları değiştirme.';
}

String _quizToneStyleInstruction(AdminNewsAiDraftRequest request) {
  if (request.preserveSource) {
    return '- Eğlenceli ton seçiliyse kaynak soru, cevap ve açıklama metnine dokunma; yalnız kısa başlık/sonuç etiketi gibi alanlarda ölçülü emoji veya ikon ekleyebilirsin. Hassas/adli/ölüm/afet/sağlık/siyaset riskli içerikte emoji kullanma.';
  }
  return '- Eğlenceli ton seçiliyse başlık, spot, soru ve sonuç açıklamalarında daha canlı, sosyal medya ritmi olan, ölçülü emoji kullanabilen özgün PateezNews dili kur. Hassas/adli/ölüm/afet/sağlık/siyaset riskli içerikte emoji kullanma.';
}

String _pollSourceTextInstruction(AdminNewsAiDraftRequest request) {
  if (request.preserveSource) {
    return '- Olduğu gibi kalsın açıkken mevcut anket başlığı, giriş metni, soru başlıkları ve seçenek metinlerini aynen taşı; yalnız id, isImagePoll, pollColumns, votes ve sıralama gibi teknik CMS alanlarını tamamla. Kaynakta soru açıklaması yoksa her question.descriptionHtml alanına sorunun neyi ölçtüğünü anlatan 1 kısa cümle yaz; soru ve seçenek metinlerini değiştirme.';
  }
  return '- Kaynakta hazır anket varsa tüm soru ve seçenekleri eksiltme. Anlamı, özel adları, tarihleri ve rakamları koruyarak doğal anket diline düzenle; kaynakta olmayan iddia veya kişi isnadı ekleme.';
}

String _videoSourceTextInstruction(AdminNewsAiDraftRequest request) {
  if (request.preserveSource) {
    return '- Olduğu gibi kalsın açıkken mevcut video başlığı, video açıklaması, kaynak/kredi ve video URL metinlerini aynen taşı; yalnız id, type ve showOnHomepage gibi teknik CMS alanlarını tamamla.';
  }
  return '- Kaynakta hazır video başlığı, açıklaması veya URL varsa eksiltme. Alıntıları, özel adları, tarihleri, rakamları ve video URL bilgisini değiştirme; kaynakta olmayan video süresi, platform, embed veya link üretme.';
}

String _tocSourceTextInstruction(AdminNewsAiDraftRequest request) {
  if (request.preserveSource) {
    return '- Olduğu gibi kalsın açıkken Table of Contents/İçindekiler başlıklarını, "Kaynak HTML başlık hiyerarşisi ve bölüm metni" içindeki [LI L*], [H*] ve [H* L*] işaretlerini, hiyerarşiyi ve her başlığın bölüm metnini aynen taşı. Başlıkları yeniden yazma, bölüm metnini özetleme, paragrafları eksiltme; yalnız id, parentId, orderNumber, linkListStyle ve showInText gibi teknik CMS alanlarını tamamla.';
  }
  return '- Kaynakta hazır içindekiler listesi, H2/H3/H4 başlık akışı veya "Kaynak HTML başlık hiyerarşisi ve bölüm metni" bloğu varsa tümünü eksiltme. Başlık sırasını, üst-alt ilişkiyi, özel adları, tarihleri, rakamları ve alıntıları koru; kaynakta olmayan yeni madde, görsel, üst bağlantı veya açıklama ekleme.';
}

String _recipeSourceTextInstruction(AdminNewsAiDraftRequest request) {
  if (request.preserveSource) {
    return '- Olduğu gibi kalsın açıkken mevcut tarif başlığı, spot, açıklama, hazırlık süresi, pişirme süresi, porsiyon, malzeme satırları, besin değeri label/value çiftleri, adım başlık/içerikleri ve yemek videosu başlık/açıklama/URL bilgisini aynen taşı. Zorluk alanı teknik select value olduğu için kaynak zorluk metnini yalnız easy/medium/hard değerlerinden birine map et. Yalnız id, type, orderNumber ve boş teknik CMS alanlarını tamamla.';
  }
  return '- Kaynakta hazır tarif varsa başlık, açıklama, süreler, porsiyon, zorluk, malzemeler, besin değerleri, adımlar ve yemek videosu başlık/açıklama/URL bilgisini eksiltme. Kopya gibi görünmeyecek şekilde genel açıklama, video açıklaması ve adım anlatımını profesyonel mutfak editörü diliyle düzenleyebilirsin; video URL, miktarları, birimleri, süreleri, sıcaklıkları, sıra mantığını ve besin değerlerini değiştirme.';
}

String _eventSourceTextInstruction(AdminNewsAiDraftRequest request) {
  if (request.preserveSource) {
    return '- Olduğu gibi kalsın açıkken mevcut etkinlik başlığı, spot, açıklama, tarih/saat, mekan, organizatör, adres, program, not, bilet/kayıt ve konuşmacı metinlerini aynen taşı. Yalnız id, type, registrationType ve boş teknik CMS alanlarını tamamla.';
  }
  return '- Kaynakta hazır etkinlik varsa başlık, açıklama, tarih/saat, mekan, organizatör, adres, program, notlar, bilet/kayıt ve konuşmacı bilgilerini eksiltme. Kopya gibi görünmeyecek şekilde genel açıklamayı profesyonel kültür-sanat/etkinlik editörü diliyle düzenleyebilirsin; tarihleri, saatleri, mekanları, isimleri, ücretleri ve program sırasını değiştirme.';
}

String _eventItemsInstruction(AdminNewsAiDraftRequest request) {
  if (_requestedAiItemCount(request) <= 0) {
    return '- mainContentHtml etkinlik için kısa giriş olabilir; program, not ve konuşmacı verilerini mainContentHtml içine yığma. Genel items dizisi boş olsun; etkinlik verisini items içine kopyalama.';
  }
  return '''
- mainContentHtml etkinlik için kısa giriş olabilir; program, not ve konuşmacı verilerini mainContentHtml içine yığma.
- Kullanıcı sağdaki AI item panelinden ne seçtiyse items dizisinde sadece o tipleri ve tam o adetleri üret.
- Her item.title dolu, kısa ve etkinliğe özgü olsun; her item.descriptionHtml etkinlik kaynağına/görsele dayanan gerçek ek açıklama taşısın.
- Seçilen image/slider/video/audio/file/social/iframe itemlerinde medya URL uydurma; sadece başlık, açıklama, altText ve source alanlarını kaynak metne göre doldur. Görselleri admin seçtiği medya bloklarıyla ayrıca ekleyecek.
- Etkinlik programını, notları veya konuşmacı listesini items içine düz kopya olarak çoğaltma; itemler kaynakta bulunan ama tab verisini destekleyen farklı ek bilgi açıları olsun.''';
}

String _recipeDeepResearchInstruction(AdminNewsAiDraftRequest request) {
  if (request.deepResearchCompleted) {
    if (request.preserveSource) {
      return '- Derin araştırma tamamlandı; kaynakta dolu olan tarif metin/değerleri aynen kalır. Yalnız kaynakta eksik olan süre, porsiyon, zorluk veya besin değeri alanlarını editör notlarındaki Google Search araştırma sonuçlarıyla tamamla; notlarda doğrulanmayan değeri yazma.';
    }
    return '- Derin araştırma tamamlandı; editör notlarındaki Google Search araştırma sonuçlarını kaynak kabul et. Eksik süre, porsiyon, zorluk ve besin değeri alanlarını bu notlarla tamamla; doğrulanmayan, çelişkili veya şüpheli değeri tarif verisine dönüştürme.';
  }
  if (!request.deepResearch) {
    return '- Derin araştırma kapalıdır; kaynakta olmayan süre, porsiyon, zorluk, besin değeri, malzeme, adım veya sağlık iddiası ekleme.';
  }
  return '''
- Derin araştırma açıktır: Google Search grounding ile verilen tarifin güvenilir kaynaklardaki süre, porsiyon, zorluk ve besin değeri bilgisini araştır.
- Kaynakta dolu olan tarif metni, malzeme, adım, süre, porsiyon, zorluk ve besin değeri değerlerini değiştirme; araştırma yalnız eksik alanları tamamlamak içindir.
- Besin değerlerini porsiyon başına ve yaygın birimlerle yaz; değer aralığı şüpheli veya çelişkiliyse boş bırak.
- Malzeme listesi ve tarif adımı üretmek için web araştırması kullanma; bunlar yalnız verilen kaynak/metinden gelir.
- Web araştırmasını kopya metin üretmek için değil; eksik alan doğrulama, SEO başlık/meta/keywords ve FAQ alanlarını güçlendirmek için kullan.''';
}

String _eventDeepResearchInstruction(AdminNewsAiDraftRequest request) {
  if (request.deepResearchCompleted) {
    if (request.preserveSource) {
      return '- Derin araştırma tamamlandı; kaynakta dolu olan etkinlik metin/değerleri aynen kalır. Yalnız kaynakta eksik olan tarih, saat, mekan, adres, organizatör, kayıt/bilet, program, not veya konuşmacı alanlarını editör notlarındaki Google Search araştırma sonuçlarıyla tamamla; notlarda doğrulanmayan bilgiyi yazma.';
    }
    return '- Derin araştırma tamamlandı; editör notlarındaki Google Search araştırma sonuçlarını kaynak kabul et. Eksik etkinlik alanlarını bu notlarla tamamla; doğrulanmayan, çelişkili veya şüpheli bilgiyi etkinlik verisine dönüştürme.';
  }
  if (!request.deepResearch) {
    return '- Derin araştırma kapalıdır; kaynakta veya seçilen görsellerde olmayan tarih, saat, mekan, organizatör, adres, bilet/kayıt, kontenjan, program, not, konuşmacı veya koordinat ekleme.';
  }
  return '''
- Derin araştırma açıktır: Google Search grounding ile verilen etkinliğin resmi/güvenilir kaynaklardaki tarih, saat, mekan, adres, organizatör, kayıt/bilet, program, not ve konuşmacı bilgisini araştır.
- Kaynakta dolu olan etkinlik metni, program sırası, tarih, saat, mekan ve kişi adlarını değiştirme; araştırma yalnız eksik alanları tamamlamak içindir.
- Etkinlik geçmiş/future ve saat bilgisini resmi kaynakta doğrulamadan yazma.
- Web araştırmasını kopya metin üretmek için değil; eksik alan doğrulama, SEO başlık/meta/keywords ve FAQ alanlarını güçlendirmek için kullan.''';
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
    return {'thinkingLevel': id.contains('lite') ? 'minimal' : 'low'};
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
    'gemini-3-pro-preview',
    'gemini-3-flash-preview',
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
  var enrichedDraft = draft;
  if (_isPollFormat(request.formatType)) {
    enrichedDraft = _draftWithNormalizedPollData(enrichedDraft);
  }
  if (request.preserveSource && _isPollFormat(request.formatType)) {
    enrichedDraft = _draftWithPreservedPollSource(enrichedDraft, request);
    enrichedDraft = _draftWithNormalizedPollData(enrichedDraft);
  }
  if (!request.includeSeo) return enrichedDraft;
  final source = '${request.topic}\n${request.sourceNotes}';
  final officialKeywordHints = _officialKeywordHintsFromSource(source);
  final personNameHints = _personNameKeywordHintsFromSource(source);
  if (officialKeywordHints.isEmpty && personNameHints.isEmpty) {
    return enrichedDraft;
  }

  final keywords = _mergeKeywords(
    officialKeywordHints,
    _mergeKeywords(enrichedDraft.keywords, personNameHints, limit: 14),
    limit: 14,
  );
  return AdminNewsAiDraft(
    title: enrichedDraft.title,
    summary: enrichedDraft.summary,
    mainContentTitle: enrichedDraft.mainContentTitle,
    seoTitle: enrichedDraft.seoTitle,
    slug: enrichedDraft.slug,
    metaDescription: enrichedDraft.metaDescription,
    schemaType: enrichedDraft.schemaType,
    keywords: keywords,
    faqEntries: enrichedDraft.faqEntries,
    mainContentHtml: enrichedDraft.mainContentHtml,
    items: enrichedDraft.items,
    tabItem: enrichedDraft.tabItem,
  );
}

AdminNewsAiDraft _draftWithNormalizedPollData(AdminNewsAiDraft draft) {
  final tabItem = draft.tabItem;
  if (tabItem.isEmpty) return draft;

  final pollData = _map(tabItem['pollData']);
  final sourceQuestions = _mapList(pollData['questions']);
  final fallbackQuestions = sourceQuestions.isEmpty
      ? [
          {
            'id': _cleanText(tabItem['id']),
            'title': _cleanText(tabItem['title']),
            'descriptionHtml': _cleanHtml(tabItem['descriptionHtml']),
            'source': _cleanText(tabItem['source']),
            'mediaUrl': _cleanText(tabItem['mediaUrl']),
            'showOnHomepage': _boolFromJson(tabItem['showOnHomepage']),
            'isImagePoll': _boolFromJson(tabItem['isImagePoll']),
            'pollColumns': _pollColumnsFromJson(tabItem['pollColumns']),
            'options': _normalizePollOptions(tabItem['options'], 'poll-q1'),
          },
        ]
      : sourceQuestions;
  final normalizedQuestions = <Map<String, Object?>>[];

  for (var index = 0; index < fallbackQuestions.length; index++) {
    final question = fallbackQuestions[index];
    final rawDescription = _firstNonEmptyString([
      _cleanHtml(question['descriptionHtml']),
      _cleanHtml(question['description']),
      if (index == 0) _cleanHtml(tabItem['descriptionHtml']),
      draft.mainContentHtml,
      draft.summary,
    ]);
    final title = _firstNonEmptyString([
      _cleanText(question['title']),
      _cleanText(question['question']),
      _cleanText(question['label']),
      _cleanText(question['name']),
      _pollQuestionTitleFromDescription(rawDescription),
      if (index == 0) _cleanText(tabItem['title']),
      draft.mainContentTitle,
      draft.title,
    ]);
    final options = _normalizePollOptions(
      _firstNonEmptyPollOptions([
        question['options'],
        question['answers'],
        question['choices'],
        if (index == 0) tabItem['options'],
      ]),
      'poll-q${index + 1}',
    );
    final questionTitle = title.isEmpty ? 'Anket sorusu ${index + 1}' : title;

    normalizedQuestions.add({
      ...question,
      'id': _firstNonEmptyString([
        _cleanText(question['id']),
        'poll-q${index + 1}',
      ]),
      'title': questionTitle,
      'descriptionHtml': rawDescription.isEmpty
          ? _sourcePollQuestionDescription(questionTitle)
          : rawDescription,
      'source': _firstNonEmptyString([
        _cleanText(question['source']),
        _cleanText(tabItem['source']),
      ]),
      'mediaUrl': _firstNonEmptyString([
        _cleanText(question['mediaUrl']),
        _cleanText(question['image']),
        if (index == 0) _cleanText(tabItem['mediaUrl']),
      ]),
      'showOnHomepage': question.containsKey('showOnHomepage')
          ? _boolFromJson(question['showOnHomepage'])
          : _boolFromJson(tabItem['showOnHomepage']),
      'isImagePoll': question.containsKey('isImagePoll')
          ? _boolFromJson(question['isImagePoll'])
          : _boolFromJson(tabItem['isImagePoll']),
      'pollColumns': question.containsKey('pollColumns')
          ? _pollColumnsFromJson(question['pollColumns'])
          : _pollColumnsFromJson(tabItem['pollColumns']),
      'options': options,
    });
  }

  final firstQuestion = normalizedQuestions.first;
  return AdminNewsAiDraft(
    title: draft.title,
    summary: draft.summary,
    mainContentTitle: draft.mainContentTitle,
    seoTitle: draft.seoTitle,
    slug: draft.slug,
    metaDescription: draft.metaDescription,
    schemaType: draft.schemaType,
    keywords: draft.keywords,
    faqEntries: draft.faqEntries,
    mainContentHtml: draft.mainContentHtml,
    items: draft.items,
    tabItem: {
      ...tabItem,
      'type': 'poll',
      'title': _firstNonEmptyString([
        _cleanText(tabItem['title']),
        _cleanText(firstQuestion['title']),
        draft.title,
      ]),
      'descriptionHtml': _firstNonEmptyString([
        _cleanHtml(tabItem['descriptionHtml']),
        draft.mainContentHtml,
        draft.summary,
        _cleanHtml(firstQuestion['descriptionHtml']),
      ]),
      'source': _cleanText(tabItem['source']),
      'mediaUrl': _cleanText(tabItem['mediaUrl']),
      'showOnHomepage': _boolFromJson(tabItem['showOnHomepage']),
      'isImagePoll': _boolFromJson(tabItem['isImagePoll']),
      'pollColumns': _pollColumnsFromJson(tabItem['pollColumns']),
      'options': _normalizePollOptions(
        _firstNonEmptyPollOptions([
          tabItem['options'],
          firstQuestion['options'],
        ]),
        'poll-q1',
      ),
      'pollData': {'questions': normalizedQuestions},
    },
  );
}

AdminNewsAiDraft _draftWithPreservedPollSource(
  AdminNewsAiDraft draft,
  AdminNewsAiDraftRequest request,
) {
  final parsed = _parsePreservedPollSource(
    '${request.topic}\n${request.sourceNotes}',
  );
  if (parsed.questions.isEmpty) return draft;

  final tabItem = <String, Object?>{...draft.tabItem};
  final pollData = _map(tabItem['pollData']);
  final aiQuestions = _mapList(pollData['questions']);
  final questions = <Map<String, Object?>>[];

  for (var index = 0; index < parsed.questions.length; index++) {
    final sourceQuestion = parsed.questions[index];
    final aiQuestion = index < aiQuestions.length
        ? aiQuestions[index]
        : const <String, Object?>{};
    final aiOptions = _mapList(aiQuestion['options']);
    final options = <Map<String, Object?>>[];
    for (
      var optionIndex = 0;
      optionIndex < sourceQuestion.options.length;
      optionIndex++
    ) {
      final aiOption = optionIndex < aiOptions.length
          ? aiOptions[optionIndex]
          : const <String, Object?>{};
      options.add({
        'id': _firstNonEmptyString([
          _cleanText(aiOption['id']),
          'poll-q${index + 1}-o${optionIndex + 1}',
        ]),
        'text': sourceQuestion.options[optionIndex],
        'image': _cleanText(aiOption['image']),
        'votes': _intFromJson(aiOption['votes']),
      });
    }

    questions.add({
      'id': _firstNonEmptyString([
        _cleanText(aiQuestion['id']),
        'poll-q${index + 1}',
      ]),
      'title': sourceQuestion.title,
      'descriptionHtml': _sourcePollQuestionDescription(sourceQuestion.title),
      'source': _cleanText(aiQuestion['source']),
      'mediaUrl': _cleanText(aiQuestion['mediaUrl']),
      'showOnHomepage': _boolFromJson(aiQuestion['showOnHomepage']),
      'isImagePoll': _boolFromJson(aiQuestion['isImagePoll']),
      'pollColumns': _pollColumnsFromJson(aiQuestion['pollColumns']),
      'options': options,
    });
  }

  final firstQuestion = questions.first;
  return AdminNewsAiDraft(
    title: draft.title,
    summary: draft.summary,
    mainContentTitle: draft.mainContentTitle,
    seoTitle: draft.seoTitle,
    slug: draft.slug,
    metaDescription: draft.metaDescription,
    schemaType: draft.schemaType,
    keywords: draft.keywords,
    faqEntries: draft.faqEntries,
    mainContentHtml: draft.mainContentHtml,
    items: draft.items,
    tabItem: {
      ...tabItem,
      'type': 'poll',
      'title': _firstNonEmptyString([
        parsed.title,
        _cleanText(tabItem['title']),
        draft.title,
      ]),
      'descriptionHtml': _firstNonEmptyString([
        parsed.introHtml,
        _cleanHtml(tabItem['descriptionHtml']),
        draft.mainContentHtml,
      ]),
      'source': _cleanText(tabItem['source']),
      'mediaUrl': _cleanText(tabItem['mediaUrl']),
      'showOnHomepage': _boolFromJson(tabItem['showOnHomepage']),
      'isImagePoll': _boolFromJson(tabItem['isImagePoll']),
      'pollColumns': _pollColumnsFromJson(tabItem['pollColumns']),
      'options': firstQuestion['options'],
      'pollData': {'questions': questions},
    },
  );
}

_ParsedPollSource _parsePreservedPollSource(String source) {
  final normalized = source
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n');
  final questions = <_ParsedPollQuestion>[];
  final questionPattern = RegExp(
    r'(?:^|\s+(?:---\s*)?)##\s*(\d+)\.\s*([\s\S]*?)(?=\s+(?:---\s*)?##\s*\d+\.|\s+(?:---\s*)?#\s*Sonuç|\s+(?:---\s*)?#\s*Sosyal|$)',
    caseSensitive: false,
  );
  for (final match in questionPattern.allMatches(normalized)) {
    final body = match.group(2) ?? '';
    final parsed = _parsePreservedPollQuestion(body);
    if (parsed != null) questions.add(parsed);
  }

  return _ParsedPollSource(
    title: _parsePreservedPollTitle(normalized),
    introHtml: _parsePreservedPollIntroHtml(normalized),
    questions: questions,
  );
}

_ParsedPollQuestion? _parsePreservedPollQuestion(String body) {
  final optionPattern = RegExp(r'(?:^|\s)([A-ZÇĞİÖŞÜ])\)\s+');
  final optionMatches = optionPattern.allMatches(body).toList(growable: false);
  if (optionMatches.isEmpty) return null;

  final title = _cleanPollMarkdownText(
    body.substring(0, optionMatches.first.start),
  );
  if (title.isEmpty) return null;

  final options = <String>[];
  for (var index = 0; index < optionMatches.length; index++) {
    final start = optionMatches[index].end;
    final end = index + 1 < optionMatches.length
        ? optionMatches[index + 1].start
        : body.length;
    final option = _cleanPollMarkdownText(body.substring(start, end));
    if (option.isNotEmpty) options.add(option);
  }
  if (options.isEmpty) return null;
  return _ParsedPollQuestion(title: title, options: options);
}

String _parsePreservedPollTitle(String source) {
  final match = RegExp(
    r'^\s*#\s+([\s\S]*?)(?=\s+\*\*SEO Başlık:|\s+##\s+Giriş|\s+(?:---\s*)?##\s*\d+\.|$)',
    caseSensitive: false,
  ).firstMatch(source);
  return _cleanPollMarkdownText(match?.group(1) ?? '');
}

String _parsePreservedPollIntroHtml(String source) {
  final match = RegExp(
    r'##\s*Giriş Metni\s*([\s\S]*?)(?=\s+(?:---\s*)?##\s*\d+\.|$)',
    caseSensitive: false,
  ).firstMatch(source);
  final intro = _cleanPollMarkdownText(match?.group(1) ?? '');
  return intro.isEmpty ? '' : '<p>$intro</p>';
}

String _cleanPollMarkdownText(String value) {
  return _cleanText(
    value
        .replaceAll(RegExp(r'^\s*#+\s*'), '')
        .replaceAllMapped(
          RegExp(r'\*\*([^*]+)\*\*'),
          (match) => match.group(1) ?? '',
        )
        .replaceAll(RegExp(r'\s+---\s*$'), '')
        .replaceAll(RegExp(r'\s+'), ' '),
  );
}

String _sourcePollQuestionDescription(String title) {
  final cleanTitle = _cleanText(title);
  if (cleanTitle.isEmpty) {
    return '<p>Bu soru, okurun anket konusundaki görüşünü ölçmek için hazırlandı.</p>';
  }
  return '<p>Bu soru, "$cleanTitle" başlığı üzerinden okurun görüşünü ölçmek için hazırlandı.</p>';
}

Object? _firstNonEmptyPollOptions(List<Object?> values) {
  for (final value in values) {
    if (value is List && value.isNotEmpty) return value;
  }
  return null;
}

List<Map<String, Object?>> _normalizePollOptions(
  Object? value,
  String idPrefix,
) {
  if (value is! List) return const [];
  final options = <Map<String, Object?>>[];
  for (final item in value) {
    final option = _map(item);
    final text = option.isEmpty
        ? _cleanText(item)
        : _firstNonEmptyString([
            _cleanText(option['text']),
            _cleanText(option['label']),
            _cleanText(option['title']),
            _cleanText(option['value']),
            _cleanText(option['answer']),
          ]);
    if (text.isEmpty) continue;
    options.add({
      'id': _firstNonEmptyString([
        _cleanText(option['id']),
        '$idPrefix-o${options.length + 1}',
      ]),
      'text': text,
      'image': _cleanText(option['image']),
      'votes': _intFromJson(option['votes']),
    });
  }
  return options;
}

String _pollQuestionTitleFromDescription(String html) {
  final plain = _htmlToPlainText(html);
  if (plain.isEmpty) return '';
  final questionMark = plain.indexOf('?');
  if (questionMark >= 0 && questionMark < 220) {
    return plain.substring(0, questionMark + 1).trim();
  }
  return plain.length > 180 ? plain.substring(0, 180).trim() : plain;
}

String _firstNonEmptyString(List<String> values) {
  for (final value in values) {
    final text = value.trim();
    if (text.isNotEmpty) return text;
  }
  return '';
}

bool _boolFromJson(Object? value) {
  if (value is bool) return value;
  return value?.toString().toLowerCase() == 'true';
}

int _intFromJson(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int _pollColumnsFromJson(Object? value) {
  return _intFromJson(value) == 3 ? 3 : 2;
}

class _ParsedPollSource {
  const _ParsedPollSource({
    required this.title,
    required this.introHtml,
    required this.questions,
  });

  final String title;
  final String introHtml;
  final List<_ParsedPollQuestion> questions;
}

class _ParsedPollQuestion {
  const _ParsedPollQuestion({required this.title, required this.options});

  final String title;
  final List<String> options;
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
        'Quiz',
        'VideoObject',
        'Recipe',
        'Event',
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
    'tabItem': {
      'type': 'object',
      'description':
          'Article dışındaki aktif formatın ana CMS item verisi. Article için boş nesne.',
      'additionalProperties': false,
      'properties': {
        'id': {'type': 'string'},
        'type': {
          'type': 'string',
          'enum': ['', 'quiz', 'poll', 'video', 'toc', 'recipe', 'event'],
        },
        'title': {'type': 'string'},
        'descriptionHtml': {'type': 'string'},
        'source': {'type': 'string'},
        'mediaUrl': {'type': 'string'},
        'altText': {'type': 'string'},
        'showOnHomepage': {'type': 'boolean'},
        'isImagePoll': {'type': 'boolean'},
        'pollColumns': {'type': 'integer'},
        'options': {
          'type': 'array',
          'items': {
            'type': 'object',
            'additionalProperties': false,
            'properties': {
              'id': {'type': 'string'},
              'text': {'type': 'string'},
              'image': {'type': 'string'},
              'votes': {'type': 'integer'},
            },
          },
          'maxItems': 6,
        },
        'quizData': {
          'type': 'object',
          'additionalProperties': false,
          'properties': {
            'quizType': {
              'type': 'string',
              'enum': ['personality', 'trivia', 'checklist'],
            },
            'questionSorting': {
              'type': 'string',
              'enum': ['asc', 'desc', 'hide'],
            },
            'allowMultiple': {'type': 'boolean'},
            'showResults': {'type': 'boolean'},
            'endDate': {'type': 'string'},
            'results': {
              'type': 'array',
              'items': {
                'type': 'object',
                'additionalProperties': false,
                'properties': {
                  'id': {'type': 'string'},
                  'title': {'type': 'string'},
                  'image': {'type': 'string'},
                  'description': {'type': 'string'},
                  'minScore': {'type': 'integer'},
                  'maxScore': {'type': 'integer'},
                  'answerCount': {'type': 'integer'},
                },
              },
              'maxItems': 6,
            },
            'questions': {
              'type': 'array',
              'items': {
                'type': 'object',
                'additionalProperties': false,
                'properties': {
                  'id': {'type': 'string'},
                  'title': {'type': 'string'},
                  'image': {'type': 'string'},
                  'description': {'type': 'string'},
                  'layout': {
                    'type': 'string',
                    'enum': ['', 'list', 'grid2', 'grid3'],
                  },
                  'answers': {
                    'type': 'array',
                    'items': {
                      'type': 'object',
                      'additionalProperties': false,
                      'properties': {
                        'id': {'type': 'string'},
                        'text': {'type': 'string'},
                        'image': {'type': 'string'},
                        'resultId': {'type': 'string'},
                        'isCorrect': {'type': 'boolean'},
                        'explanation': {'type': 'string'},
                      },
                    },
                    'maxItems': 5,
                  },
                },
              },
              'maxItems': 8,
            },
          },
        },
        'tocData': {
          'type': 'object',
          'additionalProperties': false,
          'properties': {
            'linkListStyle': {
              'type': 'object',
              'additionalProperties': false,
              'properties': {
                'level1': {'type': 'string'},
                'level2': {'type': 'string'},
                'level3': {'type': 'string'},
              },
            },
            'showInText': {
              'type': 'object',
              'additionalProperties': false,
              'properties': {
                'level1': {'type': 'boolean'},
                'level2': {'type': 'boolean'},
                'level3': {'type': 'boolean'},
              },
            },
            'items': {
              'type': 'array',
              'items': {
                'type': 'object',
                'additionalProperties': false,
                'properties': {
                  'id': {'type': 'string'},
                  'title': {'type': 'string'},
                  'parentId': {'type': 'string'},
                  'image': {'type': 'string'},
                  'imageDescription': {'type': 'string'},
                  'content': {'type': 'string'},
                  'orderNumber': {'type': 'integer'},
                },
              },
              'maxItems': 20,
            },
          },
        },
        'recipeData': {
          'type': 'object',
          'additionalProperties': false,
          'properties': {
            'prepTime': {'type': 'string'},
            'cookTime': {'type': 'string'},
            'serving': {'type': 'string'},
            'difficulty': {
              'type': 'string',
              'enum': ['', 'easy', 'medium', 'hard'],
            },
            'ingredients': {
              'type': 'array',
              'items': {
                'type': 'object',
                'additionalProperties': false,
                'properties': {
                  'text': {'type': 'string'},
                },
              },
              'maxItems': 30,
            },
            'nutrition': {
              'type': 'array',
              'items': {
                'type': 'object',
                'additionalProperties': false,
                'properties': {
                  'label': {'type': 'string'},
                  'value': {'type': 'string'},
                },
              },
              'maxItems': 12,
            },
            'directions': {
              'type': 'array',
              'items': {
                'type': 'object',
                'additionalProperties': false,
                'properties': {
                  'id': {'type': 'string'},
                  'title': {'type': 'string'},
                  'content': {'type': 'string'},
                  'image': {'type': 'string'},
                  'imageDescription': {'type': 'string'},
                  'orderNumber': {'type': 'integer'},
                },
              },
              'maxItems': 12,
            },
          },
        },
        'eventData': {
          'type': 'object',
          'additionalProperties': false,
          'properties': {
            'startDateTime': {'type': 'string'},
            'endDateTime': {'type': 'string'},
            'organizer': {'type': 'string'},
            'venueName': {'type': 'string'},
            'address': {'type': 'string'},
            'latitude': {'type': 'string'},
            'longitude': {'type': 'string'},
            'registrationType': {
              'type': 'string',
              'enum': ['none', 'required', 'tickets', 'external'],
            },
            'ticketUrl': {'type': 'string'},
            'ticketPrice': {'type': 'string'},
            'capacity': {'type': 'string'},
            'scheduleTitle': {'type': 'string'},
            'highlightsTitle': {'type': 'string'},
            'speakersTitle': {'type': 'string'},
            'schedule': {
              'type': 'array',
              'items': {
                'type': 'object',
                'additionalProperties': false,
                'properties': {
                  'id': {'type': 'string'},
                  'date': {'type': 'string'},
                  'time': {'type': 'string'},
                  'title': {'type': 'string'},
                  'description': {'type': 'string'},
                  'image': {'type': 'string'},
                  'imageDescription': {'type': 'string'},
                },
              },
              'maxItems': 12,
            },
            'highlights': {
              'type': 'array',
              'items': {
                'type': 'object',
                'additionalProperties': false,
                'properties': {
                  'label': {'type': 'string'},
                  'value': {'type': 'string'},
                },
              },
              'maxItems': 12,
            },
            'speakers': {
              'type': 'array',
              'items': {
                'type': 'object',
                'additionalProperties': false,
                'properties': {
                  'id': {'type': 'string'},
                  'name': {'type': 'string'},
                  'role': {'type': 'string'},
                  'bio': {'type': 'string'},
                  'image': {'type': 'string'},
                  'imageDescription': {'type': 'string'},
                },
              },
              'maxItems': 12,
            },
          },
        },
      },
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
    'tabItem',
    'items',
  ],
};

Map<String, Object?> _draftJsonSchemaFor(AdminNewsAiDraftRequest request) {
  final schema = _deepSchemaCopy(_draftJsonSchema) as Map<String, Object?>;
  final properties = schema['properties'];
  if (properties is Map<String, Object?>) {
    properties['tabItem'] = _tabItemJsonSchemaFor(request);
  }
  return schema;
}

Map<String, Object?> _tabItemJsonSchemaFor(AdminNewsAiDraftRequest request) {
  final formatType = request.formatType.trim().toLowerCase();
  if (formatType == 'article' || formatType.isEmpty) {
    return const {
      'type': 'object',
      'description': 'Article/Makale formatında boş nesne.',
      'additionalProperties': false,
      'properties': <String, Object?>{},
    };
  }

  final type = switch (formatType) {
    'contents' || 'toc' || 'table of contents' => 'toc',
    'quiz' => 'quiz',
    'poll' => 'poll',
    'video' => 'video',
    'recipe' => 'recipe',
    'event' => 'event',
    _ => '',
  };
  if (type.isEmpty) {
    return const {
      'type': 'object',
      'description': 'Bilinmeyen format için boş tab verisi.',
      'additionalProperties': false,
      'properties': <String, Object?>{},
    };
  }

  final properties = <String, Object?>{
    'id': {'type': 'string'},
    'type': {
      'type': 'string',
      'enum': [type],
    },
    'title': {'type': 'string'},
    'descriptionHtml': {'type': 'string'},
    'source': {'type': 'string'},
    'mediaUrl': {'type': 'string'},
    'altText': {'type': 'string'},
    'showOnHomepage': {'type': 'boolean'},
  };

  final required = <String>['type', 'title', 'descriptionHtml'];
  switch (type) {
    case 'quiz':
      properties['quizData'] = _quizDataJsonSchema();
      required.add('quizData');
    case 'poll':
      properties['isImagePoll'] = {'type': 'boolean'};
      properties['pollColumns'] = {'type': 'integer'};
      properties['options'] = {
        'type': 'array',
        'items': _pollOptionJsonSchema(),
      };
      properties['pollData'] = _pollDataJsonSchema();
      required.addAll(['isImagePoll', 'pollColumns', 'options', 'pollData']);
    case 'toc':
      properties['tocData'] = _tocDataJsonSchema();
      required.add('tocData');
    case 'recipe':
      properties['recipeData'] = _recipeDataJsonSchema();
      required.add('recipeData');
    case 'event':
      properties['eventData'] = _eventDataJsonSchema();
      required.add('eventData');
    case 'video':
      break;
  }

  return {
    'type': 'object',
    'description': 'Aktif formatın ana CMS item verisi.',
    'additionalProperties': false,
    'properties': properties,
    'required': required,
  };
}

Map<String, Object?> _quizDataJsonSchema() {
  return {
    'type': 'object',
    'additionalProperties': false,
    'properties': {
      'quizType': {'type': 'string'},
      'questionSorting': {'type': 'string'},
      'allowMultiple': {'type': 'boolean'},
      'showResults': {'type': 'boolean'},
      'endDate': {'type': 'string'},
      'results': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'id': {'type': 'string'},
            'title': {'type': 'string'},
            'image': {'type': 'string'},
            'description': {'type': 'string'},
            'minScore': {'type': 'integer'},
            'maxScore': {'type': 'integer'},
            'answerCount': {'type': 'integer'},
          },
        },
      },
      'questions': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'id': {'type': 'string'},
            'title': {'type': 'string'},
            'image': {'type': 'string'},
            'description': {'type': 'string'},
            'layout': {'type': 'string'},
            'answers': {
              'type': 'array',
              'items': {
                'type': 'object',
                'properties': {
                  'id': {'type': 'string'},
                  'text': {'type': 'string'},
                  'image': {'type': 'string'},
                  'resultId': {'type': 'string'},
                  'isCorrect': {'type': 'boolean'},
                  'explanation': {'type': 'string'},
                },
              },
            },
          },
        },
      },
    },
    'required': [
      'quizType',
      'questionSorting',
      'allowMultiple',
      'showResults',
      'endDate',
      'results',
      'questions',
    ],
  };
}

Map<String, Object?> _pollDataJsonSchema() {
  return {
    'type': 'object',
    'additionalProperties': false,
    'properties': {
      'questions': {'type': 'array', 'items': _pollQuestionJsonSchema()},
    },
    'required': ['questions'],
  };
}

Map<String, Object?> _pollQuestionJsonSchema() {
  return {
    'type': 'object',
    'additionalProperties': false,
    'properties': {
      'id': {'type': 'string'},
      'title': {
        'type': 'string',
        'description':
            'Editördeki Anket Sorusu / Başlık inputuna yazılacak dolu soru metni.',
      },
      'descriptionHtml': {
        'type': 'string',
        'description':
            'Soru başlığını tekrar etmeyen kısa bağlam veya açıklama HTML metni.',
      },
      'source': {'type': 'string'},
      'mediaUrl': {'type': 'string'},
      'showOnHomepage': {'type': 'boolean'},
      'isImagePoll': {'type': 'boolean'},
      'pollColumns': {'type': 'integer'},
      'options': {'type': 'array', 'items': _pollOptionJsonSchema()},
    },
    'required': [
      'id',
      'title',
      'descriptionHtml',
      'source',
      'mediaUrl',
      'showOnHomepage',
      'isImagePoll',
      'pollColumns',
      'options',
    ],
  };
}

Map<String, Object?> _pollOptionJsonSchema() {
  return {
    'type': 'object',
    'additionalProperties': false,
    'properties': {
      'id': {'type': 'string'},
      'text': {'type': 'string'},
      'image': {'type': 'string'},
      'votes': {'type': 'integer'},
    },
    'required': ['id', 'text', 'image', 'votes'],
  };
}

Map<String, Object?> _tocDataJsonSchema() {
  return {
    'type': 'object',
    'additionalProperties': false,
    'properties': {
      'linkListStyle': {
        'type': 'object',
        'additionalProperties': false,
        'properties': {
          'level1': _tocListStyleJsonSchema(),
          'level2': _tocListStyleJsonSchema(),
          'level3': _tocListStyleJsonSchema(),
        },
        'required': ['level1', 'level2', 'level3'],
      },
      'showInText': {
        'type': 'object',
        'additionalProperties': false,
        'properties': {
          'level1': {'type': 'boolean'},
          'level2': {'type': 'boolean'},
          'level3': {'type': 'boolean'},
        },
        'required': ['level1', 'level2', 'level3'],
      },
      'items': {'type': 'array', 'items': _tocItemJsonSchema()},
    },
    'required': ['linkListStyle', 'showInText', 'items'],
  };
}

Map<String, Object?> _tocListStyleJsonSchema() {
  return {'type': 'string'};
}

Map<String, Object?> _tocItemJsonSchema() {
  return {
    'type': 'object',
    'additionalProperties': false,
    'properties': {
      'id': {'type': 'string'},
      'title': {'type': 'string'},
      'parentId': {'type': 'string'},
      'image': {'type': 'string'},
      'imageDescription': {'type': 'string'},
      'content': {'type': 'string'},
      'orderNumber': {'type': 'integer'},
    },
    'required': [
      'id',
      'title',
      'parentId',
      'image',
      'imageDescription',
      'content',
      'orderNumber',
    ],
  };
}

Map<String, Object?> _recipeDataJsonSchema() {
  return {
    'type': 'object',
    'additionalProperties': false,
    'properties': {
      'prepTime': {'type': 'string'},
      'cookTime': {'type': 'string'},
      'serving': {'type': 'string'},
      'difficulty': {
        'type': 'string',
        'enum': ['', 'easy', 'medium', 'hard'],
      },
      'ingredients': {'type': 'array', 'items': _recipeIngredientJsonSchema()},
      'nutrition': {'type': 'array', 'items': _recipeNutritionJsonSchema()},
      'directions': {'type': 'array', 'items': _recipeDirectionJsonSchema()},
      'videoTitle': {
        'type': 'string',
        'description':
            'Tarif tabındaki Yemek Videosu başlık inputuna yazılacak metin; kaynakta yoksa boş string.',
      },
      'videoDescriptionHtml': {
        'type': 'string',
        'description':
            'Tarif tabındaki Yemek Videosu açıklama editorüne yazılacak HTML; kaynakta yoksa boş string.',
      },
      'videoUrl': {
        'type': 'string',
        'description':
            'Tarif tabındaki Yemek Videosu paneline eklenecek YouTube/embed/dosya URL; kaynakta yoksa boş string.',
      },
    },
    'required': [
      'prepTime',
      'cookTime',
      'serving',
      'difficulty',
      'ingredients',
      'nutrition',
      'directions',
      'videoTitle',
      'videoDescriptionHtml',
      'videoUrl',
    ],
  };
}

Map<String, Object?> _recipeIngredientJsonSchema() {
  return {
    'type': 'object',
    'additionalProperties': false,
    'properties': {
      'text': {'type': 'string'},
    },
    'required': ['text'],
  };
}

Map<String, Object?> _recipeNutritionJsonSchema() {
  return {
    'type': 'object',
    'additionalProperties': false,
    'properties': {
      'label': {'type': 'string'},
      'value': {'type': 'string'},
    },
    'required': ['label', 'value'],
  };
}

Map<String, Object?> _recipeDirectionJsonSchema() {
  return {
    'type': 'object',
    'additionalProperties': false,
    'properties': {
      'id': {'type': 'string'},
      'title': {'type': 'string'},
      'content': {'type': 'string'},
      'image': {'type': 'string'},
      'imageDescription': {'type': 'string'},
      'orderNumber': {'type': 'integer'},
    },
    'required': [
      'id',
      'title',
      'content',
      'image',
      'imageDescription',
      'orderNumber',
    ],
  };
}

Map<String, Object?> _eventDataJsonSchema() {
  return {
    'type': 'object',
    'additionalProperties': false,
    'properties': {
      'startDateTime': {'type': 'string'},
      'endDateTime': {'type': 'string'},
      'organizer': {'type': 'string'},
      'venueName': {'type': 'string'},
      'address': {'type': 'string'},
      'latitude': {'type': 'string'},
      'longitude': {'type': 'string'},
      'registrationType': {
        'type': 'string',
        'enum': ['none', 'required', 'tickets', 'external'],
      },
      'ticketUrl': {'type': 'string'},
      'ticketPrice': {'type': 'string'},
      'capacity': {'type': 'string'},
      'scheduleTitle': {'type': 'string'},
      'highlightsTitle': {'type': 'string'},
      'speakersTitle': {'type': 'string'},
      'schedule': {'type': 'array', 'items': _eventScheduleJsonSchema()},
      'highlights': {'type': 'array', 'items': _eventHighlightJsonSchema()},
      'speakers': {'type': 'array', 'items': _eventSpeakerJsonSchema()},
    },
    'required': [
      'startDateTime',
      'endDateTime',
      'organizer',
      'venueName',
      'address',
      'latitude',
      'longitude',
      'registrationType',
      'ticketUrl',
      'ticketPrice',
      'capacity',
      'scheduleTitle',
      'highlightsTitle',
      'speakersTitle',
      'schedule',
      'highlights',
      'speakers',
    ],
  };
}

Map<String, Object?> _eventScheduleJsonSchema() {
  return {
    'type': 'object',
    'additionalProperties': false,
    'properties': {
      'id': {'type': 'string'},
      'date': {'type': 'string'},
      'time': {'type': 'string'},
      'title': {'type': 'string'},
      'description': {'type': 'string'},
      'image': {'type': 'string'},
      'imageDescription': {'type': 'string'},
    },
    'required': [
      'id',
      'date',
      'time',
      'title',
      'description',
      'image',
      'imageDescription',
    ],
  };
}

Map<String, Object?> _eventHighlightJsonSchema() {
  return {
    'type': 'object',
    'additionalProperties': false,
    'properties': {
      'label': {'type': 'string'},
      'value': {'type': 'string'},
    },
    'required': ['label', 'value'],
  };
}

Map<String, Object?> _eventSpeakerJsonSchema() {
  return {
    'type': 'object',
    'additionalProperties': false,
    'properties': {
      'id': {'type': 'string'},
      'name': {'type': 'string'},
      'role': {'type': 'string'},
      'bio': {'type': 'string'},
      'image': {'type': 'string'},
      'imageDescription': {'type': 'string'},
    },
    'required': ['id', 'name', 'role', 'bio', 'image', 'imageDescription'],
  };
}

Object? _deepSchemaCopy(Object? value) {
  if (value is Map) {
    return {
      for (final entry in value.entries)
        entry.key.toString(): _deepSchemaCopy(entry.value),
    };
  }
  if (value is List) {
    return [for (final item in value) _deepSchemaCopy(item)];
  }
  return value;
}

Map<String, Object?> _extractDraftJson(Map<String, Object?> response) {
  final text = _extractResponseText(response);
  final decoded = jsonDecode(_stripJsonFence(text));
  if (decoded is! Map) {
    throw const AdminNewsAiException('Google AI JSON taslağı geçersiz.');
  }
  return _asStringKeyMap(decoded);
}

String _extractResponseText(Map<String, Object?> response) {
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
  return text;
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

String _imageMimeType(String url, String? contentType) {
  final header = (contentType ?? '').split(';').first.trim().toLowerCase();
  if (header.startsWith('image/')) return header;
  final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
  if (path.endsWith('.jpg') || path.endsWith('.jpeg')) return 'image/jpeg';
  if (path.endsWith('.png')) return 'image/png';
  if (path.endsWith('.webp')) return 'image/webp';
  if (path.endsWith('.gif')) return 'image/gif';
  return '';
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

Map<String, Object?> _map(Object? value) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) return _asStringKeyMap(value);
  return const {};
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
