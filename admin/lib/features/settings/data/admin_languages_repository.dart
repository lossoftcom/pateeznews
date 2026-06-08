import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pateeznews_admin/core/network/admin_api_headers.dart';

import '../../../core/localization/admin_translations.dart';
import '../../auth/data/admin_auth_models.dart';
import 'admin_language_models.dart';

abstract class AdminLanguagesRepository {
  Future<List<AdminLanguage>> fetchActiveLanguages();

  Future<LanguagesPageResult> fetchLanguages({
    required String search,
    required int page,
    required int pageSize,
    required String sortKey,
    required bool sortAscending,
  });

  Future<void> upsertLanguage({
    required AdminSession session,
    required LanguageFormData data,
  });

  Future<void> deleteLanguage({
    required AdminSession session,
    required String code,
  });

  Future<void> setDefaultLanguage({
    required AdminSession session,
    required String code,
  });

  Future<Map<String, String>> fetchTranslations(String code);

  Future<void> saveTranslations({
    required AdminSession session,
    required String code,
    required Map<String, String> translations,
  });

  Future<String> exportLanguagePack(AdminLanguage language);

  Future<void> importLanguagePack({
    required AdminSession session,
    required String jsonContent,
  });
}

class SupabaseAdminLanguagesRepository implements AdminLanguagesRepository {
  const SupabaseAdminLanguagesRepository({this.httpClient, this.apiBaseUrl});

  static const _apiBaseUrl = String.fromEnvironment('PATEEZNEWS_API_BASE_URL');
  static const _requestTimeout = Duration(seconds: 8);

  final http.Client? httpClient;
  final String? apiBaseUrl;

  @override
  Future<List<AdminLanguage>> fetchActiveLanguages() async {
    final result = await _postJson('/api/admin/query', {
      'table': 'languages',
      'method': 'select',
      'select': 'code,name,direction,status,flag_code,is_default',
      'filters': [
        {
          'type': 'comparison',
          'op': 'eq',
          'column': 'status',
          'value': 'active',
        },
      ],
      'orders': [
        {'column': 'code', 'ascending': true},
      ],
    });
    _throwIfApiError(result, fallbackMessage: 'Diller alınamadı');
    return _languagesFromData(result['data']);
  }

  @override
  Future<LanguagesPageResult> fetchLanguages({
    required String search,
    required int page,
    required int pageSize,
    required String sortKey,
    required bool sortAscending,
  }) async {
    final result = await _postJson('/api/admin/query', {
      'table': 'languages',
      'method': 'select',
      'select': 'code,name,direction,status,flag_code,is_default',
      'orders': [
        {'column': 'code', 'ascending': true},
      ],
    });
    _throwIfApiError(result, fallbackMessage: 'Dil verileri alınamadı');

    final allLanguages = _languagesFromData(result['data']);
    final term = search.trim().toLowerCase();
    final filtered = term.isEmpty
        ? allLanguages
        : allLanguages
              .where(
                (language) =>
                    language.code.contains(term) ||
                    language.name.toLowerCase().contains(term),
              )
              .toList(growable: false);

    final sorted = filtered.toList(growable: false)
      ..sort((a, b) => _compareLanguagesBySort(a, b, sortKey, sortAscending));
    final safePage = page < 1 ? 1 : page;
    final from = (safePage - 1) * pageSize;
    final paged = from >= sorted.length
        ? const <AdminLanguage>[]
        : sorted.skip(from).take(pageSize).toList(growable: false);

    return LanguagesPageResult(
      languages: _renumber(paged, from),
      totalCount: sorted.length,
    );
  }

  @override
  Future<void> upsertLanguage({
    required AdminSession session,
    required LanguageFormData data,
  }) {
    return _accountAction(session, 'admin-upsert-language', _formPayload(data));
  }

  @override
  Future<void> deleteLanguage({
    required AdminSession session,
    required String code,
  }) {
    return _accountAction(session, 'admin-delete-language', {'code': code});
  }

  @override
  Future<void> setDefaultLanguage({
    required AdminSession session,
    required String code,
  }) {
    return _accountAction(session, 'admin-set-default-language', {
      'code': code,
    });
  }

  @override
  Future<Map<String, String>> fetchTranslations(String code) async {
    final result = await _postJson('/api/admin/query', {
      'table': 'language_translations',
      'method': 'select',
      'select': 'key,value',
      'filters': [
        {
          'type': 'comparison',
          'op': 'eq',
          'column': 'language_code',
          'value': code.trim().toLowerCase(),
        },
      ],
      'orders': [
        {'column': 'key', 'ascending': true},
      ],
    });
    _throwIfApiError(result, fallbackMessage: 'Çeviriler alınamadı');

    final stored = <String, String>{};
    final data = result['data'];
    if (data is List) {
      for (final row in data.whereType<Map>()) {
        final item = _asStringKeyMap(row);
        final key = item['key']?.toString() ?? '';
        if (key.isEmpty) continue;
        stored[normalizeAdminTranslationKey(key)] =
            item['value']?.toString() ?? '';
      }
    }
    return {...defaultTranslationsFor(code), ...stored};
  }

  @override
  Future<void> saveTranslations({
    required AdminSession session,
    required String code,
    required Map<String, String> translations,
  }) {
    return _accountAction(session, 'admin-save-language-translations', {
      'code': code,
      'translations': normalizeAdminTranslationMapKeys(translations),
    });
  }

  @override
  Future<String> exportLanguagePack(AdminLanguage language) async {
    final translations = await fetchTranslations(language.code);
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert({
      'meta': language.toJson(),
      'translations': translations,
    });
  }

  @override
  Future<void> importLanguagePack({
    required AdminSession session,
    required String jsonContent,
  }) async {
    final pack = _decodeLanguagePack(jsonContent);
    await _accountAction(session, 'admin-import-language', pack);
  }

  Future<void> _accountAction(
    AdminSession session,
    String action,
    Map<String, Object?> payload,
  ) async {
    final result = await _postJson('/api/app/account', {
      'action': action,
      'token': session.accessToken,
      ...payload,
    }, token: session.accessToken);
    _throwIfApiError(result, fallbackMessage: 'Dil işlemi tamamlanamadı');
  }

  Map<String, Object?> _formPayload(LanguageFormData data) {
    return {
      'code': data.code.trim().toLowerCase(),
      'name': data.name.trim(),
      'direction': data.direction == 'rtl' ? 'rtl' : 'ltr',
      'status': data.status == 'passive' ? 'passive' : 'active',
      'flagCode': data.flagCode.trim().toLowerCase(),
    };
  }

  Map<String, Object?> _decodeLanguagePack(String jsonContent) {
    final decoded = jsonDecode(jsonContent);
    if (decoded is! Map) {
      throw const AdminLanguagesException('JSON dil dosyası nesne olmalı');
    }
    final root = _asStringKeyMap(decoded);
    final metaSource = root['meta'] is Map
        ? _asStringKeyMap(root['meta'] as Map)
        : root['language'] is Map
        ? _asStringKeyMap(root['language'] as Map)
        : root;
    final code = metaSource['code']?.toString().trim().toLowerCase() ?? '';
    final name = metaSource['name']?.toString().trim() ?? '';
    if (code.isEmpty || name.isEmpty) {
      throw const AdminLanguagesException(
        'JSON meta.code ve meta.name zorunlu',
      );
    }

    final translationsSource = root['translations'];
    final translations = <String, String>{};
    if (translationsSource is Map) {
      for (final entry in translationsSource.entries) {
        final key = entry.key.toString().trim();
        if (key.isEmpty) continue;
        translations[normalizeAdminTranslationKey(key)] =
            entry.value?.toString() ?? '';
      }
    }

    return {
      'language': {
        'code': code,
        'name': name,
        'direction': metaSource['direction']?.toString() == 'rtl'
            ? 'rtl'
            : 'ltr',
        'status': metaSource['status']?.toString() == 'passive'
            ? 'passive'
            : 'active',
        'flagCode': _cleanMetaCode(metaSource['flag_code']).isNotEmpty
            ? _cleanMetaCode(metaSource['flag_code'])
            : _cleanMetaCode(metaSource['flagCode']).isNotEmpty
            ? _cleanMetaCode(metaSource['flagCode'])
            : code,
      },
      'translations': normalizeAdminTranslationMapKeys(translations),
    };
  }

  String _cleanMetaCode(Object? value) {
    return value?.toString().trim().toLowerCase() ?? '';
  }

  Future<Map<String, Object?>> _postJson(
    String path,
    Map<String, Object?> body, {
    String? token,
  }) async {
    final headers = await adminJsonHeaders(token: token);

    final response =
        await (httpClient?.post(
                  _uri(path),
                  headers: headers,
                  body: jsonEncode(body),
                ) ??
                adminHttpClient.post(
                  _uri(path),
                  headers: headers,
                  body: jsonEncode(body),
                ))
            .timeout(_requestTimeout);

    final decoded = response.body.isEmpty
        ? <String, Object?>{}
        : jsonDecode(response.body);
    if (decoded is! Map) {
      throw const AdminLanguagesException('Geçersiz sunucu yanıtı');
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

  List<AdminLanguage> _languagesFromData(Object? data) {
    if (data is! List) return fallbackAdminLanguages;
    final rows = data
        .whereType<Map>()
        .map((item) => AdminLanguage.fromJson(item, 0))
        .where((language) => language.code.isNotEmpty)
        .toList();
    rows.sort(_compareLanguages);
    return _renumber(rows, 0);
  }

  int _compareLanguages(AdminLanguage a, AdminLanguage b) {
    final aCore = defaultAdminLanguageCodes.indexOf(a.code);
    final bCore = defaultAdminLanguageCodes.indexOf(b.code);
    if (aCore != -1 || bCore != -1) {
      if (aCore == -1) return 1;
      if (bCore == -1) return -1;
      return aCore.compareTo(bCore);
    }
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  int _compareLanguagesBySort(
    AdminLanguage a,
    AdminLanguage b,
    String sortKey,
    bool ascending,
  ) {
    final result = switch (sortKey) {
      'order' => a.rowNumber.compareTo(b.rowNumber),
      'name' => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      'default' =>
        a.isDefault == b.isDefault
            ? 0
            : a.isDefault
            ? -1
            : 1,
      'status' => a.status.compareTo(b.status),
      _ => a.rowNumber.compareTo(b.rowNumber),
    };
    final normalized = result == 0
        ? a.rowNumber.compareTo(b.rowNumber)
        : result;
    return ascending ? normalized : -normalized;
  }

  List<AdminLanguage> _renumber(List<AdminLanguage> rows, int offset) {
    return [
      for (var index = 0; index < rows.length; index++)
        rows[index].copyWith(rowNumber: offset + index + 1),
    ];
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
        throw AdminLanguagesException(message);
      }
    }
    throw AdminLanguagesException(fallbackMessage);
  }
}

class AdminLanguagesException implements Exception {
  const AdminLanguagesException(this.message);

  final String message;

  @override
  String toString() => message;
}

Map<String, Object?> _asStringKeyMap(Map<dynamic, dynamic> value) {
  return value.map((key, nestedValue) => MapEntry(key.toString(), nestedValue));
}
