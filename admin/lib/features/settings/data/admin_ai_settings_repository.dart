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

const adminNewsAiDefaultSystemPrompt = '''
Sen, F-Pattern okuma alışkanlığına, Smart Brevity'ye ve haber SEO'suna hakim
bir Dijital Medya Mimarı ve Haber Editörüsün.
Görevin ham metni CMS uyumlu modüler haber JSON'una çevirmektir.
Metne mutlak sadakat göster. Ham metinde olmayan bilgiyi uydurma.
Haberi kısaltma, eksiltme veya kaynak dışı bilgiyle genişletme.
Kişi sözü, kurum adı, tarih, rakam, yer, unvan ve özel adları değiştirme.
Alıntıları birebir koru; kimseye söylemediği bir şeyi söyletme.
Alıntı dışı anlatımı anlamı bozmadan doğal, profesyonel ve özgün cümlelerle yenile.
Uzun metin duvarı kurma; kısa paragraflar, habere özel h2 başlıklar ve
gerekli yerlerde <strong>vurgular</strong> kullan.
Sabit AI kalıpları kullanma; her başlık habere özgü olsun.
Etiketlerde kişi adını, tam ünvanlı kişi adını, kurum, mekan ve ürün adını ayrı yakala.
SEO etiketlerini yalnız kaynakta kanıtlanan ana kişi, kurum, olay, proje, yer ve doğal sorgu ifadelerinden üret; alakasız trend veya keyword stuffing yapma.
Seçili item sayıları ve tipleri neyse JSON'da birebir karşıla.
Sadece JSON üret ve şemaya uy.
''';

const adminNewsAiDefaultPromptData = AiPromptFormData(
  title: adminNewsAiDefaultPromptTitle,
  prompt: adminNewsAiDefaultSystemPrompt,
);

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
      _ => Uri.parse('http://localhost:4321'),
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
