import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

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

class NeonAdminAiSettingsRepository implements AdminAiSettingsRepository {
  const NeonAdminAiSettingsRepository({this.httpClient, this.apiBaseUrl});

  static const _apiBaseUrl = String.fromEnvironment('PATEEZNEWS_API_BASE_URL');
  static const _requestTimeout = Duration(seconds: 18);

  final http.Client? httpClient;
  final String? apiBaseUrl;

  @override
  Future<AdminAiSettingsData> fetchSettings(String languageCode) async {
    final normalizedCode = _cleanLanguageCode(languageCode);
    final result = await _postJson('/api/neon/query', {
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
    final result = await _postJson('/api/neon/query', {
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
    final result = await _postJson('/api/neon/query', {
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
        ? await _postJson('/api/neon/query', {
            'table': 'ai_ready_formats',
            'method': 'insert',
            'values': data.toJson(languageCode),
            'single': 'maybeSingle',
          })
        : await _postJson('/api/neon/query', {
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
    final result = await _postJson('/api/neon/query', {
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
      _fetchGeminiModelList('v1', trimmedKey),
      _fetchGeminiModelList('v1beta', trimmedKey),
    ]);
    final models = _filterPreferredModels([
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
      final uri = Uri.https(
        'generativelanguage.googleapis.com',
        '/$version/models',
        {'key': apiKey},
      );
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
      if (models is! List) return const _GeminiModelListResult(modelIds: []);
      return _GeminiModelListResult(
        modelIds: [
          for (final item in models.whereType<Map>())
            if (_supportsGenerateContent(item))
              _string(item['name']).replaceFirst('models/', '').trim(),
        ].where((id) => id.isNotEmpty).toList(growable: false),
      );
    } catch (error) {
      return _GeminiModelListResult(modelIds: const [], error: '$error');
    }
  }

  bool _supportsGenerateContent(Map<dynamic, dynamic> item) {
    final methods = item['supportedGenerationMethods'];
    return methods is List && methods.contains('generateContent');
  }

  List<String> _filterPreferredModels(List<String> rawModels) {
    final seen = <String>{};
    final unique = <String>[
      for (final model in rawModels.map((model) => model.trim()))
        if (model.isNotEmpty && seen.add(model)) model,
    ];
    final geminiFlash = unique
        .where((id) {
          final lower = id.toLowerCase();
          if (lower.contains('image')) return false;
          return lower.contains('gemini-3-flash') ||
              lower.contains('gemini-3.1-flash');
        })
        .toList(growable: false);

    final gemini25FlashCandidates = unique
        .where((id) {
          final lower = id.toLowerCase();
          if (lower.contains('image')) return false;
          return lower.contains('gemini-2.5-flash');
        })
        .toList(growable: false);
    final exactGemini25Flash = gemini25FlashCandidates
        .where((model) => model.toLowerCase() == 'gemini-2.5-flash')
        .firstOrNull;
    final bestGemini25Flash =
        exactGemini25Flash ?? _pickBestModel(gemini25FlashCandidates);

    final gemmaModels = unique
        .where((id) => id.toLowerCase().contains('gemma'))
        .toList(growable: false);
    final bestGemma = _pickBestGemma(gemmaModels);

    final filtered = <String>[...geminiFlash];
    if (bestGemini25Flash.isNotEmpty && !filtered.contains(bestGemini25Flash)) {
      filtered.add(bestGemini25Flash);
    }
    if (bestGemma.isNotEmpty && !filtered.contains(bestGemma)) {
      filtered.add(bestGemma);
    }
    return filtered;
  }

  String _pickBestModel(List<String> candidates) {
    if (candidates.isEmpty) return '';
    final sorted = candidates.toList(growable: false)
      ..sort((a, b) {
        final scoreDiff = _modelRank(b) - _modelRank(a);
        if (scoreDiff != 0) return scoreDiff;
        return b.compareTo(a);
      });
    return sorted.first;
  }

  int _modelRank(String id) {
    final lower = id.toLowerCase();
    var score = 0;
    if (lower.contains('latest')) score += 1000;
    if (!lower.contains('preview') &&
        !lower.contains('exp') &&
        !lower.contains('experimental')) {
      score += 200;
    }
    if (lower.contains('preview')) score -= 50;
    if (lower.contains('flash-lite') || lower.contains('-lite')) {
      score -= 2000;
    }
    return score;
  }

  String _pickBestGemma(List<String> models) {
    if (models.isEmpty) return '';
    return models.where((model) => model.contains('27b')).firstOrNull ??
        models.where((model) => model.contains('9b')).firstOrNull ??
        models.where((model) => model.contains('7b')).firstOrNull ??
        models.first;
  }

  Future<Map<String, Object?>> _postJson(
    String path,
    Map<String, Object?> body,
  ) async {
    final response =
        await (httpClient?.post(
                  _uri(path),
                  headers: const {
                    'Accept': 'application/json',
                    'Content-Type': 'application/json; charset=UTF-8',
                  },
                  body: jsonEncode(body),
                ) ??
                http.post(
                  _uri(path),
                  headers: const {
                    'Accept': 'application/json',
                    'Content-Type': 'application/json; charset=UTF-8',
                  },
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
