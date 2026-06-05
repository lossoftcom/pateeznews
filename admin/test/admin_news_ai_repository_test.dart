import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pateeznews_admin/features/auth/data/admin_auth_models.dart';
import 'package:pateeznews_admin/features/news/data/admin_news_ai_repository.dart';
import 'package:pateeznews_admin/features/settings/data/admin_ai_settings_repository.dart';

void main() {
  test(
    'eğlenceli ton payloadında uzunluk talimatı yok ve item planı korunur',
    () async {
      Map<String, Object?>? capturedBody;
      final repository = GeminiAdminNewsAiRepository(
        settingsRepository: const _FakeAiSettingsRepository(),
        httpClient: MockClient((request) async {
          capturedBody = jsonDecode(request.body) as Map<String, Object?>;
          return _jsonResponse({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': jsonEncode(_draftJson())},
                  ],
                },
              },
            ],
          });
        }),
      );

      final draft = await repository.generateDraft(
        const AdminNewsAiDraftRequest(
          languageCode: 'tr',
          category: 'Gündem',
          tone: 'entertaining',
          contentType: 'article',
          outputTarget: 'all',
          includeSeo: false,
          topic: 'Başkan konuşmasında yeni ulaşım projesini anlattı.',
          sourceNotes:
              'Konuşmada 3 Haziran 2026 tarihi ve Niğde vurgusu geçti.',
          itemCounts: {'text': 2},
        ),
      );

      final body = capturedBody!;
      final generationConfig = body['generationConfig'] as Map<String, Object?>;
      final schema =
          generationConfig['responseJsonSchema'] as Map<String, Object?>;
      final properties = schema['properties'] as Map<String, Object?>;
      final itemsSchema = properties['items'] as Map<String, Object?>;
      final contents = body['contents'] as List<Object?>;
      final userContent = contents.single as Map<String, Object?>;
      final parts = userContent['parts'] as List<Object?>;
      final prompt = (parts.single as Map<String, Object?>)['text'] as String;
      final systemInstruction =
          body['system_instruction'] as Map<String, Object?>;
      final systemParts = systemInstruction['parts'] as List<Object?>;
      final systemPrompt =
          (systemParts.single as Map<String, Object?>)['text'] as String;

      expect(systemPrompt, contains('Aktif haber promptu'));
      expect(systemPrompt, contains('Haberi gereksiz ara başlıklarla bölme'));
      expect(
        adminNewsAiDefaultSystemPrompt,
        contains('Haberi gereksiz ara başlıklarla bölme'),
      );
      expect(systemPrompt, contains('2-4 arası anlamlı h2'));
      expect(systemPrompt, contains('Liste ve tablo gibi ham verileri'));
      expect(generationConfig['maxOutputTokens'], 8192);
      expect(generationConfig['temperature'], 0.5);
      expect(itemsSchema.containsKey('maxItems'), isFalse);
      expect(properties, contains('tabItem'));
      expect(prompt, contains('Eğlenceli'));
      expect(prompt, contains('Aktif Format/Tab: Makale Haber'));
      expect(prompt, contains('tabItem boş nesne {} olsun'));
      expect(prompt, contains('- text: 2 adet'));
      expect(prompt, contains('tam 2 adet text item'));
      expect(prompt, contains('kısa haberde h2 üretme'));
      expect(prompt, contains('2-4 arası anlamlı h2'));
      expect(prompt, contains('Kısa ara başlık parçası yapma'));
      expect(prompt, contains('okunur listeye dönüştür'));
      expect(prompt, contains('Haber içeriği / ham kaynak:'));
      expect(prompt, contains('Editör talimatları / notlar:'));
      expect(prompt, contains('Talimat kaynakta olmayan bilgi eklettiremez'));
      expect(
        prompt,
        contains('yalnız haber içeriğinde açıkça bulunan bilgileri kullan'),
      );
      expect(prompt, contains('HTML sadece p, h2, ul, ol, li, strong'));
      expect(prompt, isNot(contains('Uzunluk:')));
      expect(prompt, isNot(contains('420-620')));
      expect(prompt, isNot(contains('320-460')));
      expect(draft.items.where((item) => item.type == 'text'), hasLength(2));
      expect(draft.keywords, isEmpty);
    },
  );

  test('quiz formatı aktif tab verisini tabItem şemasıyla ister', () async {
    Map<String, Object?>? capturedBody;
    final repository = GeminiAdminNewsAiRepository(
      settingsRepository: const _FakeAiSettingsRepository(),
      httpClient: MockClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, Object?>;
        return _jsonResponse({
          'candidates': [
            {
              'content': {
                'parts': [
                  {
                    'text': jsonEncode(
                      _draftJson(
                        items: const [],
                        tabItem: {
                          'type': 'quiz',
                          'title': 'Dünya Kupası forma numarası testi',
                          'descriptionHtml':
                              '<p>Forma numaralarını ne kadar biliyorsun?</p>',
                          'quizData': {
                            'quizType': 'trivia',
                            'questionSorting': 'asc',
                            'allowMultiple': false,
                            'showResults': true,
                            'endDate': '',
                            'results': <Map<String, Object?>>[],
                            'questions': [
                              {
                                'id': 'q1',
                                'title': 'Arda Güler hangi numarayı giydi?',
                                'image': '',
                                'description': '',
                                'layout': 'list',
                                'answers': [
                                  {
                                    'id': 'a1',
                                    'text': '8',
                                    'image': '',
                                    'resultId': '',
                                    'isCorrect': true,
                                  },
                                  {
                                    'id': 'a2',
                                    'text': '10',
                                    'image': '',
                                    'resultId': '',
                                    'isCorrect': false,
                                  },
                                ],
                              },
                            ],
                          },
                        },
                      ),
                    ),
                  },
                ],
              },
            },
          ],
        });
      }),
    );

    final draft = await repository.generateDraft(
      const AdminNewsAiDraftRequest(
        languageCode: 'tr',
        category: 'Spor',
        tone: 'neutral',
        contentType: 'article',
        outputTarget: 'all',
        includeSeo: true,
        topic: 'Forma numaraları listesi',
        sourceNotes: '',
        itemCounts: {},
        formatType: 'quiz',
        formatSubtype: 'trivia',
      ),
    );

    final body = capturedBody!;
    final contents = body['contents'] as List<Object?>;
    final userContent = contents.single as Map<String, Object?>;
    final parts = userContent['parts'] as List<Object?>;
    final prompt = (parts.single as Map<String, Object?>)['text'] as String;
    final generationConfig = body['generationConfig'] as Map<String, Object?>;
    final schema =
        generationConfig['responseJsonSchema'] as Map<String, Object?>;
    final properties = schema['properties'] as Map<String, Object?>;

    expect(prompt, contains('Aktif Format/Tab: Quiz/Test / alt tür: trivia'));
    expect(prompt, contains('tabItem.type kesin "quiz" olsun'));
    expect(prompt, contains('quizData.questions alanında'));
    expect(prompt, contains('items yalnız seçili ek item planını taşısın'));
    expect(properties, contains('tabItem'));
    expect(draft.items, isEmpty);
    expect(draft.tabItem['type'], 'quiz');
    expect(draft.tabItem['quizData'], isA<Map<String, Object?>>());
  });

  test(
    'item seçilmediyse AI tarafından dönen ekstra item reddedilir',
    () async {
      final repository = GeminiAdminNewsAiRepository(
        settingsRepository: const _FakeAiSettingsRepository(),
        httpClient: MockClient((request) async {
          return _jsonResponse({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {
                      'text': jsonEncode(
                        _draftJson(items: [_textItem('İstenmeyen item')]),
                      ),
                    },
                  ],
                },
              },
            ],
          });
        }),
      );

      expect(
        () => repository.generateDraft(
          const AdminNewsAiDraftRequest(
            languageCode: 'tr',
            category: 'Gündem',
            tone: 'neutral',
            contentType: 'article',
            outputTarget: 'all',
            includeSeo: true,
            topic: 'Kısa haber metni',
            sourceNotes: '',
            itemCounts: {},
          ),
        ),
        throwsA(isA<AdminNewsAiException>()),
      );
    },
  );

  test(
    'kaynak listedeki kişi adları keywords listesine kontrollü eklenir',
    () async {
      final repository = GeminiAdminNewsAiRepository(
        settingsRepository: const _FakeAiSettingsRepository(),
        httpClient: MockClient((request) async {
          return _jsonResponse({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {
                      'text': jsonEncode(
                        _draftJson(
                          items: const [],
                          keywords: const [
                            'A Milli Futbol Takımı',
                            'Dünya Kupası',
                            '2026 Dünya Kupası',
                            'Forma Numaraları',
                            'Milli Takım Kadrosu',
                            'Mert Günok',
                            'Hakan Çalhanoğlu',
                            'Arda Güler',
                            'Kenan Yıldız',
                            'Türkiye Futbol',
                          ],
                        ),
                      ),
                    },
                  ],
                },
              },
            ],
          });
        }),
      );

      final draft = await repository.generateDraft(
        const AdminNewsAiDraftRequest(
          languageCode: 'tr',
          category: 'Spor',
          tone: 'neutral',
          contentType: 'article',
          outputTarget: 'all',
          includeSeo: true,
          topic: 'Milli Takımımızın Dünya Kupası Forma Numaraları Belli Oldu',
          sourceNotes: '''
1 — Mert Günok
2 — Zeki Çelik
3 — Merih Demiral
4 — Çağlar Söyüncü
5 — Salih Özcan
6 — Orkun Kökçü
7 — Kerem Aktürkoğlu
8 — Arda Güler
9 — Deniz Gül
10 — Hakan Çalhanoğlu
''',
          itemCounts: {},
        ),
      );

      expect(draft.keywords, contains('A Milli Futbol Takımı'));
      expect(draft.keywords, contains('Dünya Kupası'));
      expect(draft.keywords, contains('Zeki Çelik'));
      expect(draft.keywords, contains('Merih Demiral'));
      expect(draft.keywords, contains('Çağlar Söyüncü'));
      expect(draft.keywords, contains('Salih Özcan'));
      expect(draft.keywords, isNot(contains('Dünya Kupası Forma')));
      expect(draft.keywords.length, lessThanOrEqualTo(14));
    },
  );

  test('mainContentHtml ara başlıkları ayrı metin bölümlerine ayrılır', () {
    final sections = splitAdminNewsAiContentSections(
      title: 'Ulaştırma projeleri',
      fallbackTitle: 'Haber başlığı',
      html: '''
<p>Ulaştırma ve Altyapı Bakanı yeni projeleri anlattı.</p>
<h2>10 Yıl İçinde Ankara'dan İstanbul'a 80 Dakika</h2>
<p>Ankara-İstanbul arasında süper hızlı tren hedefi açıklandı.</p>
<h2>276 Kilometrelik Otoyolun Proje Çalışmaları Başladı</h2>
<p>Akyazı-Ankara otoyolu için proje çalışmalarının başladığı belirtildi.</p>
''',
    );

    expect(sections, hasLength(3));
    expect(sections[0].title, 'Ulaştırma projeleri');
    expect(
      sections[0].html,
      '<p>Ulaştırma ve Altyapı Bakanı yeni projeleri anlattı.</p>',
    );
    expect(sections[1].title, "10 Yıl İçinde Ankara'dan İstanbul'a 80 Dakika");
    expect(
      sections[1].html,
      '<p>Ankara-İstanbul arasında süper hızlı tren hedefi açıklandı.</p>',
    );
    expect(
      sections[2].title,
      '276 Kilometrelik Otoyolun Proje Çalışmaları Başladı',
    );
    expect(
      sections[2].html,
      '<p>Akyazı-Ankara otoyolu için proje çalışmalarının başladığı belirtildi.</p>',
    );
  });
}

http.Response _jsonResponse(Map<String, Object?> body) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    200,
    headers: const {'content-type': 'application/json; charset=utf-8'},
  );
}

Map<String, Object?> _draftJson({
  List<Map<String, Object?>>? items,
  List<String>? keywords,
  Map<String, Object?>? tabItem,
}) {
  return {
    'title': 'Başkan ulaşım projesini anlattı',
    'summary': 'Niğde için yeni ulaşım projesi duyuruldu.',
    'mainContentTitle': 'Yeni ulaşım projesi',
    'seoTitle': '',
    'slug': '',
    'metaDescription': '',
    'schemaType': '',
    'keywords': keywords ?? <String>[],
    'faq': <Map<String, Object?>>[],
    'mainContentHtml':
        '<p>Başkan konuşmasında yeni ulaşım projesinin detaylarını anlattı.</p>',
    'tabItem': tabItem ?? <String, Object?>{},
    'items':
        items ?? [_textItem('İlk ara başlık'), _textItem('İkinci ara başlık')],
  };
}

Map<String, Object?> _textItem(String title) {
  return {
    'type': 'text',
    'title': title,
    'descriptionHtml': '<p>Kaynak metinden gelen ek bilgi.</p>',
  };
}

class _FakeAiSettingsRepository implements AdminAiSettingsRepository {
  const _FakeAiSettingsRepository();

  @override
  Future<AdminAiSettingsData> fetchSettings(String languageCode) async {
    return AdminAiSettingsData(
      languageCode: languageCode,
      googleAiApiKey: 'test-key',
      googleAiModel: 'gemini-3.5-flash',
      googleAiActive: true,
    );
  }

  @override
  Future<List<AdminAiPrompt>> fetchPrompts(String languageCode) async {
    return [
      AdminAiPrompt(
        id: 'prompt-1',
        title: 'Haber İçerik Üretici',
        prompt: 'Aktif haber promptu',
        languageCode: languageCode,
        isActive: true,
      ),
    ];
  }

  @override
  Future<List<String>> fetchGeminiModels(String apiKey) async => const [];

  @override
  Future<AdminAiPrompt> savePrompt({
    required AdminSession session,
    required String languageCode,
    required AiPromptFormData data,
    String? id,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<AdminAiSettingsData> saveSettings({
    required AdminSession session,
    required AdminAiSettingsData settings,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> deletePrompt({
    required AdminSession session,
    required String id,
  }) async {
    throw UnimplementedError();
  }
}
