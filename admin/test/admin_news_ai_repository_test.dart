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
      final thinkingConfig =
          generationConfig['thinkingConfig'] as Map<String, Object?>;
      final schema =
          generationConfig['responseJsonSchema'] as Map<String, Object?>;
      final properties = schema['properties'] as Map<String, Object?>;
      final tabItemSchema = properties['tabItem'] as Map<String, Object?>;
      final tabItemProperties =
          tabItemSchema['properties'] as Map<String, Object?>;
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
      expect(thinkingConfig['thinkingLevel'], 'low');
      expect(itemsSchema.containsKey('maxItems'), isFalse);
      expect(properties, contains('tabItem'));
      expect(tabItemProperties, isEmpty);
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
    final tabItemSchema = properties['tabItem'] as Map<String, Object?>;
    final tabItemProperties =
        tabItemSchema['properties'] as Map<String, Object?>;
    final tabItemTypeSchema = tabItemProperties['type'] as Map<String, Object?>;

    expect(prompt, contains('Aktif Format/Tab: Quiz/Test / alt tür: trivia'));
    expect(prompt, contains('tabItem.type kesin "quiz" olsun'));
    expect(prompt, contains('quizData.quizType otomatik belirlensin'));
    expect(prompt, contains('quizData.questions her soruda'));
    expect(prompt, contains('1 kısa cümlelik soru açıklaması'));
    expect(prompt, contains('boş bırakma, sonuç açıklaması yazma'));
    expect(prompt, contains('explanation alanları kullanılabilir'));
    expect(prompt, contains('minScore ile maxScore'));
    expect(prompt, contains('boşluk ve çakışma olmadan'));
    expect(prompt, contains('15 soruluk bilgi yarışması 15 soru'));
    expect(prompt, contains('Doğru cevabın "Cevap sonrası açıklama"'));
    expect(prompt, contains('items yalnız seçili ek item planını taşısın'));
    expect(properties, contains('tabItem'));
    expect(tabItemTypeSchema['enum'], ['quiz']);
    expect(tabItemProperties, contains('quizData'));
    expect(tabItemProperties, isNot(contains('recipeData')));
    expect(tabItemProperties, isNot(contains('eventData')));
    final quizDataSchema =
        tabItemProperties['quizData'] as Map<String, Object?>;
    final quizRequired = quizDataSchema['required'] as List<Object?>;
    final encodedQuizDataSchema = jsonEncode(quizDataSchema);
    final questionsSchema =
        (quizDataSchema['properties'] as Map<String, Object?>)['questions']
            as Map<String, Object?>;
    final questionItemSchema = questionsSchema['items'] as Map<String, Object?>;
    final questionProperties =
        questionItemSchema['properties'] as Map<String, Object?>;
    final answersSchema = questionProperties['answers'] as Map<String, Object?>;
    final answerItemSchema = answersSchema['items'] as Map<String, Object?>;
    final answerProperties =
        answerItemSchema['properties'] as Map<String, Object?>;
    expect(quizRequired, containsAll(['results', 'questions']));
    expect(answerProperties, contains('explanation'));
    expect(encodedQuizDataSchema, isNot(contains('"minItems"')));
    expect(encodedQuizDataSchema, isNot(contains('"maxItems"')));
    expect(encodedQuizDataSchema, isNot(contains('"enum"')));
    expect(draft.items, isEmpty);
    expect(draft.tabItem['type'], 'quiz');
    expect(draft.tabItem['quizData'], isA<Map<String, Object?>>());
  });

  test('poll formatı anket tab verisini profesyonel şemayla ister', () async {
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
                          'type': 'poll',
                          'title': 'Niğde için en güçlü turizm rotası hangisi?',
                          'descriptionHtml':
                              '<p>Niğde rotaları için okur görüşünü al.</p>',
                          'source': '',
                          'mediaUrl': '',
                          'showOnHomepage': false,
                          'isImagePoll': false,
                          'pollColumns': 2,
                          'options': [
                            {
                              'id': 'o1',
                              'text': 'Gümüşler Manastırı',
                              'image': '',
                              'votes': 0,
                            },
                            {
                              'id': 'o2',
                              'text': 'Aladağlar',
                              'image': '',
                              'votes': 0,
                            },
                          ],
                          'pollData': {
                            'questions': [
                              {
                                'id': 'q1',
                                'title':
                                    'Niğde için en güçlü turizm rotası hangisi?',
                                'descriptionHtml':
                                    '<p>Niğde rotaları için okur görüşünü al.</p>',
                                'source': '',
                                'mediaUrl': '',
                                'showOnHomepage': false,
                                'isImagePoll': false,
                                'pollColumns': 2,
                                'options': [
                                  {
                                    'id': 'q1o1',
                                    'text': 'Gümüşler Manastırı',
                                    'image': '',
                                    'votes': 0,
                                  },
                                  {
                                    'id': 'q1o2',
                                    'text': 'Aladağlar',
                                    'image': '',
                                    'votes': 0,
                                  },
                                ],
                              },
                              {
                                'id': 'q2',
                                'title':
                                    'Niğde tanıtımında önce hangi alan güçlenmeli?',
                                'descriptionHtml':
                                    '<p>Şehrin tanıtım önceliğini seç.</p>',
                                'source': '',
                                'mediaUrl': '',
                                'showOnHomepage': false,
                                'isImagePoll': false,
                                'pollColumns': 2,
                                'options': [
                                  {
                                    'id': 'q2o1',
                                    'text': 'Tarihi miras',
                                    'image': '',
                                    'votes': 0,
                                  },
                                  {
                                    'id': 'q2o2',
                                    'text': 'Doğa rotaları',
                                    'image': '',
                                    'votes': 0,
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
        category: 'Niğde',
        tone: 'entertaining',
        contentType: 'article',
        outputTarget: 'all',
        includeSeo: true,
        topic: 'Niğde turizmi için eğlenceli bir okur anketi hazırla',
        sourceNotes: '',
        itemCounts: {},
        formatType: 'poll',
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
    final tabItemSchema = properties['tabItem'] as Map<String, Object?>;
    final tabItemProperties =
        tabItemSchema['properties'] as Map<String, Object?>;
    final tabItemTypeSchema = tabItemProperties['type'] as Map<String, Object?>;
    final pollDataSchema =
        tabItemProperties['pollData'] as Map<String, Object?>;
    final pollDataProperties =
        pollDataSchema['properties'] as Map<String, Object?>;
    final questionsSchema =
        pollDataProperties['questions'] as Map<String, Object?>;
    final questionItemSchema = questionsSchema['items'] as Map<String, Object?>;
    final questionProperties =
        questionItemSchema['properties'] as Map<String, Object?>;
    final questionOptionsSchema =
        questionProperties['options'] as Map<String, Object?>;
    final questionOptionItemSchema =
        questionOptionsSchema['items'] as Map<String, Object?>;
    final optionProperties =
        questionOptionItemSchema['properties'] as Map<String, Object?>;
    final systemInstruction =
        body['system_instruction'] as Map<String, Object?>;
    final systemParts = systemInstruction['parts'] as List<Object?>;
    final systemPrompt =
        (systemParts.single as Map<String, Object?>)['text'] as String;

    expect(generationConfig['temperature'], 0.62);
    expect(systemPrompt, contains('Anket İçerik Mimarı'));
    expect(prompt, contains('Aktif Format/Tab: Anket'));
    expect(prompt, contains('tabItem.type kesin "poll" olsun'));
    expect(prompt, contains('pollData.questions'));
    expect(prompt, contains('Kaynakta 15 anket sorusu varsa'));
    expect(prompt, contains('soru metnini descriptionHtml içine gömme'));
    expect(prompt, contains('tabItem.options geriye uyumluluk'));
    expect(prompt, contains('isImagePoll metin ağırlıklı ankette false'));
    expect(prompt, contains('items boş dizi olsun'));
    expect(tabItemTypeSchema['enum'], ['poll']);
    expect(
      tabItemProperties.keys,
      containsAll(['isImagePoll', 'pollColumns', 'pollData']),
    );
    expect(tabItemProperties, isNot(contains('quizData')));
    expect(questionProperties.keys, containsAll(['title', 'options']));
    expect(
      optionProperties.keys,
      containsAll(['id', 'text', 'image', 'votes']),
    );
    expect(jsonEncode(pollDataSchema), isNot(contains('"minItems"')));
    expect(jsonEncode(pollDataSchema), isNot(contains('"maxItems"')));
    expect(draft.items, isEmpty);
    expect(draft.tabItem['type'], 'poll');
    expect(draft.tabItem['options'], isA<List<Object?>>());
    expect(draft.tabItem['pollData'], isA<Map<String, Object?>>());
  });

  test(
    'video formatı ayrı promptla ilk video tabItem ve ek item planını ister',
    () async {
      Map<String, Object?>? capturedBody;
      final repository = GeminiAdminNewsAiRepository(
        settingsRepository: const _FakeAiSettingsRepository(
          prompts: [
            AdminAiPrompt(
              id: 'prompt-video',
              title: 'Video İçerik Üretici',
              prompt: 'Aktif video promptu',
              languageCode: 'tr',
              isActive: true,
            ),
            _fakeActiveNewsPrompt,
          ],
        ),
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
                          items: [_textItem('Ek video arka planı')],
                          tabItem: {
                            'type': 'video',
                            'title': 'Festivalden ilk video notları',
                            'descriptionHtml':
                                '<p>Festival alanındaki görüntüler haber bağlamıyla aktarıldı.</p>',
                            'source': 'Pateez TV',
                            'mediaUrl': 'https://youtu.be/test-video',
                            'showOnHomepage': false,
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
          category: 'Kültür',
          tone: 'neutral',
          contentType: 'article',
          outputTarget: 'all',
          includeSeo: true,
          topic: 'Festival alanından video haber hazırla',
          sourceNotes: 'Video URL: https://youtu.be/test-video',
          itemCounts: {'text': 1},
          formatType: 'video',
        ),
      );

      final body = capturedBody!;
      final contents = body['contents'] as List<Object?>;
      final userContent = contents.single as Map<String, Object?>;
      final parts = userContent['parts'] as List<Object?>;
      final prompt = (parts.single as Map<String, Object?>)['text'] as String;
      final systemInstruction =
          body['system_instruction'] as Map<String, Object?>;
      final systemParts = systemInstruction['parts'] as List<Object?>;
      final systemPrompt =
          (systemParts.single as Map<String, Object?>)['text'] as String;
      final generationConfig = body['generationConfig'] as Map<String, Object?>;
      final schema =
          generationConfig['responseJsonSchema'] as Map<String, Object?>;
      final properties = schema['properties'] as Map<String, Object?>;
      final tabItemSchema = properties['tabItem'] as Map<String, Object?>;
      final tabItemProperties =
          tabItemSchema['properties'] as Map<String, Object?>;
      final tabItemTypeSchema =
          tabItemProperties['type'] as Map<String, Object?>;

      expect(systemPrompt, contains('Aktif video promptu'));
      expect(systemPrompt, isNot(contains('Aktif haber promptu')));
      expect(prompt, contains('İçerik Türü: Video Haber'));
      expect(prompt, contains('Aktif Format/Tab: Video Haber'));
      expect(prompt, contains('tabItem.type kesin "video" olsun'));
      expect(prompt, contains('ilk "Video İçerik Bloğu"'));
      expect(prompt, contains('tabItem video verisini items içine kopyalama'));
      expect(prompt, contains('mediaUrl alanına aynen taşı'));
      expect(prompt, contains('- text: 1 adet'));
      expect(tabItemTypeSchema['enum'], ['video']);
      expect(
        tabItemProperties.keys,
        containsAll(['source', 'mediaUrl', 'showOnHomepage']),
      );
      expect(tabItemProperties, isNot(contains('quizData')));
      expect(tabItemProperties, isNot(contains('pollData')));
      expect(draft.tabItem['type'], 'video');
      expect(draft.items.where((item) => item.type == 'text'), hasLength(1));
    },
  );

  test(
    'içindekiler formatı ayrı promptla tocData alanlarını eksiksiz ister',
    () async {
      Map<String, Object?>? capturedBody;
      final repository = GeminiAdminNewsAiRepository(
        settingsRepository: const _FakeAiSettingsRepository(
          prompts: [
            AdminAiPrompt(
              id: 'prompt-contents',
              title: 'İçindekiler İçerik Üretici',
              prompt: 'Aktif içindekiler promptu',
              languageCode: 'tr',
              isActive: true,
            ),
            _fakeActiveNewsPrompt,
          ],
        ),
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
                            'type': 'toc',
                            'title': 'Table of Contents',
                            'descriptionHtml': '',
                            'tocData': {
                              'linkListStyle': {
                                'level1': 'none',
                                'level2': 'none',
                                'level3': 'none',
                              },
                              'showInText': {
                                'level1': false,
                                'level2': false,
                                'level3': false,
                              },
                              'items': [
                                {
                                  'id': '1',
                                  'title': 'Introduction',
                                  'parentId': '',
                                  'image': '',
                                  'imageDescription': '',
                                  'content':
                                      '<p>Quantum computing intro text.</p>',
                                  'orderNumber': 1,
                                },
                                {
                                  'id': '1.1',
                                  'title': 'Understanding Quantum Mechanics',
                                  'parentId': '1',
                                  'image': '',
                                  'imageDescription': '',
                                  'content':
                                      '<p>Quantum mechanics section text.</p>',
                                  'orderNumber': 2,
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
          category: 'Teknoloji',
          tone: 'neutral',
          contentType: 'article',
          outputTarget: 'all',
          includeSeo: true,
          topic: 'Quantum computing revolutionizing information processing',
          sourceNotes:
              'Table of Contents\nIntroduction\nUnderstanding Quantum Mechanics',
          itemCounts: {},
          preserveSource: true,
          formatType: 'contents',
        ),
      );

      final body = capturedBody!;
      final contents = body['contents'] as List<Object?>;
      final userContent = contents.single as Map<String, Object?>;
      final parts = userContent['parts'] as List<Object?>;
      final prompt = (parts.single as Map<String, Object?>)['text'] as String;
      final systemInstruction =
          body['system_instruction'] as Map<String, Object?>;
      final systemParts = systemInstruction['parts'] as List<Object?>;
      final systemPrompt =
          (systemParts.single as Map<String, Object?>)['text'] as String;
      final generationConfig = body['generationConfig'] as Map<String, Object?>;
      final schema =
          generationConfig['responseJsonSchema'] as Map<String, Object?>;
      final properties = schema['properties'] as Map<String, Object?>;
      final tabItemSchema = properties['tabItem'] as Map<String, Object?>;
      final tabItemProperties =
          tabItemSchema['properties'] as Map<String, Object?>;
      final tabItemRequired = tabItemSchema['required'] as List<Object?>;
      final tabItemTypeSchema =
          tabItemProperties['type'] as Map<String, Object?>;
      final tocDataSchema =
          tabItemProperties['tocData'] as Map<String, Object?>;
      final tocDataProperties =
          tocDataSchema['properties'] as Map<String, Object?>;
      final linkListStyle =
          tocDataProperties['linkListStyle'] as Map<String, Object?>;
      final linkListProperties =
          linkListStyle['properties'] as Map<String, Object?>;
      final level1Schema = linkListProperties['level1'] as Map<String, Object?>;
      final tocItems = tocDataProperties['items'] as Map<String, Object?>;
      final tocItemSchema = tocItems['items'] as Map<String, Object?>;

      expect(systemPrompt, contains('Aktif içindekiler promptu'));
      expect(systemPrompt, isNot(contains('Aktif haber promptu')));
      expect(prompt, contains('İçerik Türü: İçindekiler/Listeli İçerik'));
      expect(prompt, contains('Aktif Format/Tab: İçindekiler/Listeli İçerik'));
      expect(prompt, contains('tabItem.type kesin "toc" olsun'));
      expect(prompt, contains('tabItem.tocData.items'));
      expect(prompt, contains('Genel "items" boş dizi olsun'));
      expect(
        prompt,
        contains('Olduğu gibi kalsın açıkken Table of Contents/İçindekiler'),
      );
      expect(tabItemTypeSchema['enum'], ['toc']);
      expect(tabItemRequired, contains('tocData'));
      expect(tabItemProperties, contains('tocData'));
      expect(tabItemProperties, isNot(contains('quizData')));
      expect(tabItemProperties, isNot(contains('pollData')));
      expect(level1Schema, isNot(contains('enum')));
      expect(tocItems, isNot(contains('maxItems')));
      expect(
        tocItemSchema['required'],
        containsAll([
          'id',
          'title',
          'parentId',
          'image',
          'imageDescription',
          'content',
          'orderNumber',
        ]),
      );
      expect(draft.items, isEmpty);
      expect(draft.tabItem['type'], 'toc');
      final tocData = draft.tabItem['tocData'] as Map<String, Object?>;
      expect(tocData['items'], isA<List<Object?>>());
    },
  );

  test(
    'olduğu gibi kalsın anket kaynağında soru başlıklarını yerli yerine taşır',
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
                          tabItem: {
                            'type': 'poll',
                            'title': '',
                            'descriptionHtml':
                                '<p>Sosyal medya paylaşım metni yanlışlıkla buraya geldi.</p>',
                            'source': '',
                            'mediaUrl': '',
                            'showOnHomepage': false,
                            'isImagePoll': false,
                            'pollColumns': 2,
                            'options': <Map<String, Object?>>[],
                            'pollData': {
                              'questions': [
                                {
                                  'id': 'ai-q1',
                                  'title': '',
                                  'descriptionHtml': '',
                                  'source': '',
                                  'mediaUrl': '',
                                  'showOnHomepage': false,
                                  'isImagePoll': false,
                                  'pollColumns': 2,
                                  'options': <Map<String, Object?>>[],
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

      const source = '''
# Niğde Siyaset Anketi: Halk Kimi Çalışkan, Kimi Sessiz, Kimi Sadece Tabelada Görüyor? **SEO Başlık:** Niğde Siyaset Anketi: Niğdeliler Hangi Siyasetçiyi Daha Başarılı Buluyor? ## Giriş Metni Niğde’de siyaset deyince herkesin söyleyecek en az bir cümlesi vardır. --- ## 1. Niğde siyasetinde bugün en görünür isim sence kim? A) Emrah Özdemir B) Cevahir Uzkurt C) Ömer Fethi Gürer D) Cumali İnce E) Hepsi görünür ama sorun çözmede aynı görünürlük yok F) Hiçbiri yeterince görünür değil --- ## 2. Niğde’nin sorunlarını Ankara’da en çok gündeme taşıyan isim sence kim? A) Cevahir Uzkurt B) Ömer Fethi Gürer C) Cumali İnce D) Hepsi dönem dönem gündeme taşıyor E) Gündeme taşımak var, çözmek var; ben çözüm görmek istiyorum F) Niğde’nin sesi hâlâ yeterince güçlü çıkmıyor --- # Sonuç Başlıkları ## Çoğunluk A-B ise: Mevcut Siyasete Güven Var Ama Takip Sıkı
''';

      final draft = await repository.generateDraft(
        const AdminNewsAiDraftRequest(
          languageCode: 'tr',
          category: 'Niğde',
          tone: 'entertaining',
          contentType: 'article',
          outputTarget: 'all',
          includeSeo: true,
          topic: source,
          sourceNotes: '',
          itemCounts: {},
          preserveSource: true,
          formatType: 'poll',
        ),
      );

      final tabItem = draft.tabItem;
      final pollData = tabItem['pollData'] as Map<String, Object?>;
      final questions = pollData['questions'] as List<Object?>;
      final firstQuestion = questions[0] as Map<String, Object?>;
      final secondQuestion = questions[1] as Map<String, Object?>;
      final firstOptions = firstQuestion['options'] as List<Object?>;
      final secondOptions = secondQuestion['options'] as List<Object?>;

      expect(questions, hasLength(2));
      expect(
        tabItem['title'],
        'Niğde Siyaset Anketi: Halk Kimi Çalışkan, Kimi Sessiz, Kimi Sadece Tabelada Görüyor?',
      );
      expect(
        firstQuestion['title'],
        'Niğde siyasetinde bugün en görünür isim sence kim?',
      );
      expect(
        secondQuestion['title'],
        'Niğde’nin sorunlarını Ankara’da en çok gündeme taşıyan isim sence kim?',
      );
      expect(firstQuestion['descriptionHtml'], isNot(''));
      expect(firstOptions.map((item) => (item as Map)['text']), [
        'Emrah Özdemir',
        'Cevahir Uzkurt',
        'Ömer Fethi Gürer',
        'Cumali İnce',
        'Hepsi görünür ama sorun çözmede aynı görünürlük yok',
        'Hiçbiri yeterince görünür değil',
      ]);
      expect(secondOptions.map((item) => (item as Map)['text']), [
        'Cevahir Uzkurt',
        'Ömer Fethi Gürer',
        'Cumali İnce',
        'Hepsi dönem dönem gündeme taşıyor',
        'Gündeme taşımak var, çözmek var; ben çözüm görmek istiyorum',
        'Niğde’nin sesi hâlâ yeterince güçlü çıkmıyor',
      ]);
    },
  );

  test(
    'olduğu gibi kalsın modu article metnini yeniden yazmadan yerleştirmeyi ister',
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
                    {'text': jsonEncode(_draftJson(items: const []))},
                  ],
                },
              },
            ],
          });
        }),
      );

      await repository.generateDraft(
        const AdminNewsAiDraftRequest(
          languageCode: 'tr',
          category: 'Niğde',
          tone: 'entertaining',
          contentType: 'article',
          outputTarget: 'all',
          includeSeo: true,
          topic:
              '[Başlık] Niğde testi\n[Spot] Niğdeyi ne kadar biliyorsun?\n[Ara Başlık] Kale ve tarih',
          sourceNotes: '',
          itemCounts: {},
          preserveSource: true,
        ),
      );

      final body = capturedBody!;
      final contents = body['contents'] as List<Object?>;
      final userContent = contents.single as Map<String, Object?>;
      final parts = userContent['parts'] as List<Object?>;
      final prompt = (parts.single as Map<String, Object?>)['text'] as String;

      expect(prompt, contains('Olduğu gibi kalsın: Açık'));
      expect(prompt, contains('Kaynak metin yeniden yazılmayacak'));
      expect(prompt, contains('doğru CMS alanlarına yerleştirmektir'));
      expect(prompt, contains('[Başlık]'));
      expect(prompt, contains('[Ara Başlık]'));
      expect(prompt, contains('Etiket içerik değilse final metne yazma'));
      expect(prompt, contains('SEO açık olduğunda seoTitle'));
      expect(prompt, contains('ölçülü emoji/ikon'));
      expect(prompt, contains('mainContentHtml kaynak akışını aynen korusun'));
    },
  );

  test(
    'olduğu gibi kalsın modu quiz soru cevaplarını yeniden yazdırmaz',
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
                    {
                      'text': jsonEncode(
                        _draftJson(
                          items: const [],
                          tabItem: {
                            'type': 'quiz',
                            'title': 'Niğde testi',
                            'descriptionHtml': '<p>Niğdeyi biliyor musun?</p>',
                            'quizData': {
                              'quizType': 'trivia',
                              'questionSorting': 'asc',
                              'allowMultiple': false,
                              'showResults': true,
                              'endDate': '',
                              'results': <Map<String, Object?>>[],
                              'questions': <Map<String, Object?>>[],
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

      await repository.generateDraft(
        const AdminNewsAiDraftRequest(
          languageCode: 'tr',
          category: 'Niğde',
          tone: 'entertaining',
          contentType: 'article',
          outputTarget: 'all',
          includeSeo: true,
          topic:
              '[Soru] Niğde Kalesi hangi şehirde?\n[Cevap] Niğde\n[Sonuç] Niğdeyi iyi biliyorsun!',
          sourceNotes: '',
          itemCounts: {},
          preserveSource: true,
          formatType: 'quiz',
          formatSubtype: 'trivia',
        ),
      );

      final body = capturedBody!;
      final contents = body['contents'] as List<Object?>;
      final userContent = contents.single as Map<String, Object?>;
      final parts = userContent['parts'] as List<Object?>;
      final prompt = (parts.single as Map<String, Object?>)['text'] as String;

      expect(prompt, contains('Olduğu gibi kalsın: Açık'));
      expect(
        prompt,
        contains(
          'mevcut soru, cevap, doğru cevap, sonuç ve açıklamaları aynen taşı',
        ),
      );
      expect(prompt, contains('id, layout, resultId, isCorrect'));
      expect(prompt, isNot(contains('Kopya gibi görünmeyecek şekilde')));
      expect(prompt, isNot(contains('eş anlamlı kelimeler')));
    },
  );

  test(
    'quiz derin araştırma önce googleSearch yapar sonra JSON taslak üretir',
    () async {
      final capturedBodies = <Map<String, Object?>>[];
      final repository = GeminiAdminNewsAiRepository(
        settingsRepository: const _FakeAiSettingsRepository(),
        httpClient: MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, Object?>;
          capturedBodies.add(body);
          if (capturedBodies.length == 1) {
            return _jsonResponse({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {
                        'text':
                            'Niğde araştırma notu: Niğde, İç Anadolu Bölgesi’nde yer alır ve Aladağlar Milli Parkı ile bilinir.',
                      },
                    ],
                  },
                },
              ],
            });
          }
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
                            'title': 'Güncel teknoloji testi',
                            'descriptionHtml':
                                '<p>Teknoloji bilgin ne kadar güncel?</p>',
                            'quizData': {
                              'quizType': 'trivia',
                              'questionSorting': 'asc',
                              'allowMultiple': false,
                              'showResults': true,
                              'endDate': '',
                              'results': [
                                {
                                  'id': 'r1',
                                  'title': 'Güncel takipçi',
                                  'image': '',
                                  'description': '<p>Temeli biliyorsun.</p>',
                                  'minScore': 0,
                                  'maxScore': 2,
                                  'answerCount': 0,
                                },
                              ],
                              'questions': [
                                {
                                  'id': 'q1',
                                  'title': 'Gemini hangi amaçla kullanılır?',
                                  'image': '',
                                  'description': '',
                                  'layout': 'list',
                                  'answers': [
                                    {
                                      'id': 'a1',
                                      'text': 'Yapay zeka içerik üretimi',
                                      'image': '',
                                      'resultId': '',
                                      'isCorrect': true,
                                    },
                                    {
                                      'id': 'a2',
                                      'text': 'Fiziksel kargo takibi',
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

      await repository.generateDraft(
        const AdminNewsAiDraftRequest(
          languageCode: 'tr',
          category: 'Teknoloji',
          tone: 'entertaining',
          contentType: 'article',
          outputTarget: 'all',
          includeSeo: true,
          topic: 'Güncel yapay zeka araçları testi',
          sourceNotes: '',
          itemCounts: {},
          deepResearch: true,
          formatType: 'quiz',
        ),
      );

      expect(capturedBodies, hasLength(2));

      final researchBody = capturedBodies.first;
      final researchTools = researchBody['tools'] as List<Object?>;
      final researchGenerationConfig =
          researchBody['generationConfig'] as Map<String, Object?>;
      final researchContents = researchBody['contents'] as List<Object?>;
      final researchUserContent =
          researchContents.single as Map<String, Object?>;
      final researchParts = researchUserContent['parts'] as List<Object?>;
      final researchPrompt =
          (researchParts.single as Map<String, Object?>)['text'] as String;
      expect(researchTools.single, contains('googleSearch'));
      expect(researchGenerationConfig, isNot(contains('responseMimeType')));
      expect(researchGenerationConfig, isNot(contains('responseJsonSchema')));
      expect(researchGenerationConfig, isNot(contains('responseFormat')));
      expect(researchPrompt, contains('Google Search ile quiz/test'));

      final body = capturedBodies.last;
      final generationConfig = body['generationConfig'] as Map<String, Object?>;
      final contents = body['contents'] as List<Object?>;
      final userContent = contents.single as Map<String, Object?>;
      final parts = userContent['parts'] as List<Object?>;
      final prompt = (parts.single as Map<String, Object?>)['text'] as String;
      final systemInstruction =
          body['system_instruction'] as Map<String, Object?>;
      final systemParts = systemInstruction['parts'] as List<Object?>;
      final systemPrompt =
          (systemParts.single as Map<String, Object?>)['text'] as String;

      expect(body, isNot(contains('tools')));
      expect(generationConfig['temperature'], 0.62);
      expect(generationConfig['responseMimeType'], 'application/json');
      expect(
        generationConfig['responseJsonSchema'],
        isA<Map<String, Object?>>(),
      );
      expect(generationConfig, isNot(contains('responseFormat')));
      expect(systemPrompt, contains('Quiz İçerik Mimarı'));
      expect(prompt, contains('Derin Araştırma: Tamamlandı'));
      expect(prompt, contains('Google Search derin araştırma notları'));
      expect(prompt, contains('Niğde araştırma notu'));
    },
  );

  test(
    'poll derin araştırma önce googleSearch yapar sonra anket taslağı üretir',
    () async {
      final capturedBodies = <Map<String, Object?>>[];
      final repository = GeminiAdminNewsAiRepository(
        settingsRepository: const _FakeAiSettingsRepository(),
        httpClient: MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, Object?>;
          capturedBodies.add(body);
          if (capturedBodies.length == 1) {
            return _jsonResponse({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {
                        'text':
                            'Niğde anket araştırma notu: Turizm rotaları arasında Aladağlar ve Gümüşler Manastırı öne çıkar.',
                      },
                    ],
                  },
                },
              ],
            });
          }
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
                            'type': 'poll',
                            'title':
                                'Niğde’de ilk görmek isteyeceğin rota hangisi?',
                            'descriptionHtml':
                                '<p>Niğde rotaları için fikrini seç.</p>',
                            'source': '',
                            'mediaUrl': '',
                            'showOnHomepage': false,
                            'isImagePoll': false,
                            'pollColumns': 2,
                            'options': [
                              {
                                'id': 'o1',
                                'text': 'Aladağlar',
                                'image': '',
                                'votes': 0,
                              },
                              {
                                'id': 'o2',
                                'text': 'Gümüşler Manastırı',
                                'image': '',
                                'votes': 0,
                              },
                            ],
                            'pollData': {
                              'questions': [
                                {
                                  'id': 'q1',
                                  'title':
                                      'Niğde’de ilk görmek isteyeceğin rota hangisi?',
                                  'descriptionHtml':
                                      '<p>Niğde rotaları için fikrini seç.</p>',
                                  'source': '',
                                  'mediaUrl': '',
                                  'showOnHomepage': false,
                                  'isImagePoll': false,
                                  'pollColumns': 2,
                                  'options': [
                                    {
                                      'id': 'q1o1',
                                      'text': 'Aladağlar',
                                      'image': '',
                                      'votes': 0,
                                    },
                                    {
                                      'id': 'q1o2',
                                      'text': 'Gümüşler Manastırı',
                                      'image': '',
                                      'votes': 0,
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

      await repository.generateDraft(
        const AdminNewsAiDraftRequest(
          languageCode: 'tr',
          category: 'Niğde',
          tone: 'entertaining',
          contentType: 'article',
          outputTarget: 'all',
          includeSeo: true,
          topic: 'Niğde turizmi için anket hazırla',
          sourceNotes: '',
          itemCounts: {},
          deepResearch: true,
          formatType: 'poll',
        ),
      );

      expect(capturedBodies, hasLength(2));

      final researchBody = capturedBodies.first;
      final researchTools = researchBody['tools'] as List<Object?>;
      final researchContents = researchBody['contents'] as List<Object?>;
      final researchUserContent =
          researchContents.single as Map<String, Object?>;
      final researchParts = researchUserContent['parts'] as List<Object?>;
      final researchPrompt =
          (researchParts.single as Map<String, Object?>)['text'] as String;
      expect(researchTools.single, contains('googleSearch'));
      expect(researchPrompt, contains('Google Search ile anket'));
      expect(
        researchPrompt,
        contains('Ankette kullanılabilecek soru ve seçenek fikirleri'),
      );

      final body = capturedBodies.last;
      final generationConfig = body['generationConfig'] as Map<String, Object?>;
      final contents = body['contents'] as List<Object?>;
      final userContent = contents.single as Map<String, Object?>;
      final parts = userContent['parts'] as List<Object?>;
      final prompt = (parts.single as Map<String, Object?>)['text'] as String;
      final systemInstruction =
          body['system_instruction'] as Map<String, Object?>;
      final systemParts = systemInstruction['parts'] as List<Object?>;
      final systemPrompt =
          (systemParts.single as Map<String, Object?>)['text'] as String;

      expect(body, isNot(contains('tools')));
      expect(generationConfig['temperature'], 0.62);
      expect(systemPrompt, contains('Anket İçerik Mimarı'));
      expect(prompt, contains('Derin Araştırma: Tamamlandı'));
      expect(prompt, contains('Niğde anket araştırma notu'));
    },
  );

  test('gemini 3 flash-lite thinkingLevel küçük harfle gönderilir', () async {
    Map<String, Object?>? capturedBody;
    final repository = GeminiAdminNewsAiRepository(
      settingsRepository: const _FakeAiSettingsRepository(
        model: 'gemini-3.1-flash-lite',
      ),
      httpClient: MockClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, Object?>;
        return _jsonResponse({
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': jsonEncode(_draftJson(items: const []))},
                ],
              },
            },
          ],
        });
      }),
    );

    await repository.generateDraft(
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
    );

    final generationConfig =
        capturedBody!['generationConfig'] as Map<String, Object?>;
    final thinkingConfig =
        generationConfig['thinkingConfig'] as Map<String, Object?>;

    expect(thinkingConfig['thinkingLevel'], 'minimal');
  });

  test('aktif format schema sadece kendi tabItem alanını taşır', () async {
    final cases = [
      ('poll', 'poll', 'options'),
      ('video', 'video', ''),
      ('contents', 'toc', 'tocData'),
      ('recipe', 'recipe', 'recipeData'),
      ('event', 'event', 'eventData'),
    ];

    for (final (formatType, storageType, dataKey) in cases) {
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
                            'type': storageType,
                            'title': 'Tab başlığı',
                            'descriptionHtml': '<p>Tab açıklaması.</p>',
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

      await repository.generateDraft(
        AdminNewsAiDraftRequest(
          languageCode: 'tr',
          category: 'Gündem',
          tone: 'neutral',
          contentType: 'article',
          outputTarget: 'all',
          includeSeo: true,
          topic: '$formatType haber metni',
          sourceNotes: '',
          itemCounts: const {},
          formatType: formatType,
        ),
      );

      final generationConfig =
          capturedBody!['generationConfig'] as Map<String, Object?>;
      final schema =
          generationConfig['responseJsonSchema'] as Map<String, Object?>;
      final properties = schema['properties'] as Map<String, Object?>;
      final tabItemSchema = properties['tabItem'] as Map<String, Object?>;
      final tabItemProperties =
          tabItemSchema['properties'] as Map<String, Object?>;
      final tabItemTypeSchema =
          tabItemProperties['type'] as Map<String, Object?>;

      expect(tabItemTypeSchema['enum'], [storageType]);
      for (final otherKey in [
        'quizData',
        'eventData',
        'recipeData',
        'tocData',
      ]) {
        if (otherKey != dataKey) {
          expect(tabItemProperties, isNot(contains(otherKey)));
        }
      }
      if (dataKey.isNotEmpty) {
        expect(tabItemProperties, contains(dataKey));
      }
    }
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

const _fakeActiveNewsPrompt = AdminAiPrompt(
  id: 'prompt-1',
  title: 'Haber İçerik Üretici',
  prompt: 'Aktif haber promptu',
  languageCode: 'tr',
  isActive: true,
);

class _FakeAiSettingsRepository implements AdminAiSettingsRepository {
  const _FakeAiSettingsRepository({
    this.model = 'gemini-3.5-flash',
    this.prompts = const [_fakeActiveNewsPrompt],
  });

  final String model;
  final List<AdminAiPrompt> prompts;

  @override
  Future<AdminAiSettingsData> fetchSettings(String languageCode) async {
    return AdminAiSettingsData(
      languageCode: languageCode,
      googleAiApiKey: 'test-key',
      googleAiModel: model,
      googleAiActive: true,
    );
  }

  @override
  Future<List<AdminAiPrompt>> fetchPrompts(String languageCode) async {
    return prompts;
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
