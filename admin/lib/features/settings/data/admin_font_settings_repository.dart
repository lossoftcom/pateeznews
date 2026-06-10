import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pateeznews_admin/core/network/admin_api_headers.dart';

import '../../auth/data/admin_auth_models.dart';

class AdminFontRow {
  const AdminFontRow({
    required this.id,
    required this.name,
    required this.family,
    required this.type,
    required this.source,
    required this.webFontPath,
    required this.flutterFamily,
    required this.fallbackStack,
    required this.fontFiles,
    required this.active,
    required this.sortOrder,
  });

  factory AdminFontRow.fromJson(Map<dynamic, dynamic> json) {
    final item = _asStringKeyMap(json);
    return AdminFontRow(
      id: _int(item['id']),
      name: _string(item['name']),
      family: _string(item['family']),
      type: _string(item['type'], fallback: 'sans_serif'),
      source: _string(item['source'], fallback: 'local'),
      webFontPath: _string(item['web_font_path']),
      flutterFamily: _string(item['flutter_family']),
      fallbackStack: _string(item['fallback_stack']),
      fontFiles: _stringMap(item['font_files']),
      active: item['is_active'] != false,
      sortOrder: _int(item['sort_order']),
    );
  }

  final int id;
  final String name;
  final String family;
  final String type;
  final String source;
  final String webFontPath;
  final String flutterFamily;
  final String fallbackStack;
  final Map<String, String> fontFiles;
  final bool active;
  final int sortOrder;

  bool get isLocal => source == 'local';

  String get labelSourceKey =>
      isLocal ? 'fontSettings.source.local' : 'fontSettings.source.system';
}

class AdminFontSettingsData {
  const AdminFontSettingsData({
    required this.languageCode,
    required this.primaryFont,
    required this.titleFont,
    required this.contentFont,
    required this.mobilePrimaryFont,
    required this.mobileTitleFont,
    required this.mobileContentFont,
    required this.fontSizes,
    required this.mobileFontSizes,
    required this.fontWeights,
    required this.mobileFontWeights,
  });

  factory AdminFontSettingsData.empty(String languageCode) {
    final fontSizes = Map<String, int>.of(defaultWebFontSizes);
    return AdminFontSettingsData(
      languageCode: _cleanLanguageCode(languageCode),
      primaryFont: 'PateezInter',
      titleFont: 'PateezInter',
      contentFont: 'PateezInter',
      mobilePrimaryFont: 'PateezInter',
      mobileTitleFont: 'PateezInter',
      mobileContentFont: 'PateezInter',
      fontSizes: fontSizes,
      mobileFontSizes: _defaultMobileFontSizesFromWeb(fontSizes),
      fontWeights: Map<String, int>.of(defaultWebFontWeights),
      mobileFontWeights: Map<String, int>.of(defaultMobileFontWeights),
    );
  }

  factory AdminFontSettingsData.fromJson(
    Map<dynamic, dynamic> json,
    String languageCode,
  ) {
    final item = _asStringKeyMap(json);
    final fontPayload = item['site_font_sizes'];
    final legacyFontSizes = _legacyFontSizeMap(fontPayload);
    final webFontSizes = _webFontSizeMap(fontPayload, legacyFontSizes);
    final webFonts = _targetFontFamiliesMap(
      fontPayload,
      target: 'web',
      primary: _string(item['site_primary_font'], fallback: 'PateezInter'),
      title: _string(item['site_title_font'], fallback: 'PateezInter'),
      content: _string(item['site_content_font'], fallback: 'PateezInter'),
    );
    final mobileFonts = _targetFontFamiliesMap(
      fontPayload,
      target: 'mobile',
      primary: webFonts['primary'] ?? 'PateezInter',
      title: webFonts['title'] ?? 'PateezInter',
      content: webFonts['content'] ?? 'PateezInter',
    );
    return AdminFontSettingsData(
      languageCode: _cleanLanguageCode(
        _string(item['language_code'], fallback: languageCode),
      ),
      primaryFont: webFonts['primary'] ?? 'PateezInter',
      titleFont: webFonts['title'] ?? 'PateezInter',
      contentFont: webFonts['content'] ?? 'PateezInter',
      mobilePrimaryFont: mobileFonts['primary'] ?? 'PateezInter',
      mobileTitleFont: mobileFonts['title'] ?? 'PateezInter',
      mobileContentFont: mobileFonts['content'] ?? 'PateezInter',
      fontSizes: webFontSizes,
      mobileFontSizes: _mobileFontSizeMap(fontPayload, webFontSizes),
      fontWeights: _fontWeightMap(
        fontPayload,
        target: 'web',
        defaults: defaultWebFontWeights,
      ),
      mobileFontWeights: _fontWeightMap(
        fontPayload,
        target: 'mobile',
        defaults: defaultMobileFontWeights,
      ),
    );
  }

  final String languageCode;
  final String primaryFont;
  final String titleFont;
  final String contentFont;
  final String mobilePrimaryFont;
  final String mobileTitleFont;
  final String mobileContentFont;
  final Map<String, int> fontSizes;
  final Map<String, int> mobileFontSizes;
  final Map<String, int> fontWeights;
  final Map<String, int> mobileFontWeights;

  Map<String, Object?> toJson() {
    final legacyFontSizes = _legacyFontSizesFromWeb(fontSizes);
    return {
      'language_code': languageCode,
      'site_primary_font': primaryFont,
      'site_title_font': titleFont,
      'site_content_font': contentFont,
      'site_font_sizes': {
        ...legacyFontSizes,
        'web': fontSizes,
        'mobile': mobileFontSizes,
        'weights': {'web': fontWeights, 'mobile': mobileFontWeights},
        'fonts': {
          'web': {
            'primary': primaryFont,
            'title': titleFont,
            'content': contentFont,
          },
          'mobile': {
            'primary': mobilePrimaryFont,
            'title': mobileTitleFont,
            'content': mobileContentFont,
          },
        },
      },
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  AdminFontSettingsData copyWith({
    String? languageCode,
    String? primaryFont,
    String? titleFont,
    String? contentFont,
    String? mobilePrimaryFont,
    String? mobileTitleFont,
    String? mobileContentFont,
    Map<String, int>? fontSizes,
    Map<String, int>? mobileFontSizes,
    Map<String, int>? fontWeights,
    Map<String, int>? mobileFontWeights,
  }) {
    return AdminFontSettingsData(
      languageCode: languageCode ?? this.languageCode,
      primaryFont: primaryFont ?? this.primaryFont,
      titleFont: titleFont ?? this.titleFont,
      contentFont: contentFont ?? this.contentFont,
      mobilePrimaryFont: mobilePrimaryFont ?? this.mobilePrimaryFont,
      mobileTitleFont: mobileTitleFont ?? this.mobileTitleFont,
      mobileContentFont: mobileContentFont ?? this.mobileContentFont,
      fontSizes: fontSizes ?? this.fontSizes,
      mobileFontSizes: mobileFontSizes ?? this.mobileFontSizes,
      fontWeights: fontWeights ?? this.fontWeights,
      mobileFontWeights: mobileFontWeights ?? this.mobileFontWeights,
    );
  }
}

class AdminFontSettingsBundle {
  const AdminFontSettingsBundle({required this.settings, required this.fonts});

  final AdminFontSettingsData settings;
  final List<AdminFontRow> fonts;
}

class AdminFontUploadFile {
  const AdminFontUploadFile({required this.fileName, required this.bytes});

  final String fileName;
  final List<int> bytes;
}

class AdminFontFormData {
  const AdminFontFormData({
    required this.name,
    required this.type,
    required this.files,
  });

  final String name;
  final String type;
  final Map<int, AdminFontUploadFile> files;
}

abstract class AdminFontSettingsRepository {
  Future<AdminFontSettingsBundle> fetchSettings(String languageCode);

  Future<AdminFontSettingsData> saveSettings({
    required AdminSession session,
    required AdminFontSettingsData settings,
  });

  Future<AdminFontRow> addFont({
    required AdminSession session,
    required AdminFontFormData data,
  });

  Future<AdminFontRow> updateFont({
    required AdminSession session,
    required AdminFontRow font,
    required AdminFontFormData data,
  });
}

class SupabaseAdminFontSettingsRepository
    implements AdminFontSettingsRepository {
  const SupabaseAdminFontSettingsRepository({this.httpClient, this.apiBaseUrl});

  static const _apiBaseUrl = String.fromEnvironment('PATEEZNEWS_API_BASE_URL');
  static const _requestTimeout = Duration(seconds: 18);

  final http.Client? httpClient;
  final String? apiBaseUrl;

  @override
  Future<AdminFontSettingsBundle> fetchSettings(String languageCode) async {
    final normalizedCode = _cleanLanguageCode(languageCode);
    final result = await _postJson('/api/admin/font-settings', {
      'languageCode': normalizedCode,
    });
    _throwIfApiError(result, fallbackMessage: 'Font ayarlari alinamadi');

    final payload = result['data'];
    final data = payload is Map
        ? _asStringKeyMap(payload)
        : <String, Object?>{};
    final fonts = _fontsFromData(data['fonts']);
    final settingsData = data['settings'];
    final settings = settingsData is Map
        ? AdminFontSettingsData.fromJson(settingsData, normalizedCode)
        : AdminFontSettingsData.empty(normalizedCode);

    return AdminFontSettingsBundle(
      settings: _sanitizeSettings(settings, fonts),
      fonts: fonts.isEmpty ? fallbackSiteFonts : fonts,
    );
  }

  @override
  Future<AdminFontSettingsData> saveSettings({
    required AdminSession session,
    required AdminFontSettingsData settings,
  }) async {
    final normalized = settings.copyWith(
      languageCode: _cleanLanguageCode(settings.languageCode),
      fontSizes: _clampedWebSizes(settings.fontSizes),
      mobileFontSizes: _clampedMobileSizes(settings.mobileFontSizes),
      fontWeights: _clampedWebWeights(settings.fontWeights),
      mobileFontWeights: _clampedMobileWeights(settings.mobileFontWeights),
    );
    final result = await _postJson('/api/admin/query', {
      'table': 'site_settings',
      'method': 'upsert',
      'select': _settingsSelect,
      'values': normalized.toJson(),
      'options': {'onConflict': 'language_code'},
      'single': 'maybeSingle',
    });
    _throwIfApiError(result, fallbackMessage: 'Font ayarlari kaydedilemedi');
    final data = result['data'];
    if (data is! Map) return normalized;
    return AdminFontSettingsData.fromJson(data, normalized.languageCode);
  }

  @override
  Future<AdminFontRow> addFont({
    required AdminSession session,
    required AdminFontFormData data,
  }) async {
    final name = data.name.trim();
    if (name.isEmpty) {
      throw const AdminFontSettingsException('Font adi zorunlu');
    }
    final family = _fontFamilyFromName(name);
    final uploadedFiles = <String, String>{};
    for (final entry in data.files.entries) {
      final src = await _uploadFontFile(
        family: family,
        weight: entry.key,
        file: entry.value,
      );
      uploadedFiles[entry.key.toString()] = src;
    }
    final webFontPath =
        uploadedFiles['400'] ??
        (uploadedFiles.isEmpty ? '' : uploadedFiles.values.first);
    final result = await _postJson('/api/admin/query', {
      'table': 'site_fonts',
      'method': 'insert',
      'select': _fontSelect,
      'values': {
        'name': name,
        'family': family,
        'type': _cleanFontType(data.type),
        'source': 'local',
        'web_font_path': webFontPath,
        'flutter_family': family,
        'fallback_stack': "'$family', Arial, sans-serif",
        'font_files': uploadedFiles,
        'is_active': true,
        'sort_order': 100,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      'single': 'maybeSingle',
    });
    _throwIfApiError(result, fallbackMessage: 'Font eklenemedi');
    final row = result['data'];
    if (row is Map) return AdminFontRow.fromJson(row);
    throw const AdminFontSettingsException('Font ekleme yaniti gecersiz');
  }

  @override
  Future<AdminFontRow> updateFont({
    required AdminSession session,
    required AdminFontRow font,
    required AdminFontFormData data,
  }) async {
    final name = data.name.trim();
    if (name.isEmpty) {
      throw const AdminFontSettingsException('Font adi zorunlu');
    }
    final family = font.family.trim().isEmpty
        ? _fontFamilyFromName(font.name)
        : font.family.trim();
    final values = <String, Object?>{
      'name': name,
      'type': _cleanFontType(data.type),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    if (data.files.isNotEmpty) {
      final uploadedFiles = Map<String, String>.of(font.fontFiles);
      for (final entry in data.files.entries) {
        final src = await _uploadFontFile(
          family: family,
          weight: entry.key,
          file: entry.value,
        );
        uploadedFiles[entry.key.toString()] = src;
      }
      final existingWebFontPath = font.webFontPath.trim();
      final fallbackUploadedPath = uploadedFiles.isEmpty
          ? ''
          : uploadedFiles.values.first;
      values['source'] = 'local';
      values['web_font_path'] =
          uploadedFiles['400'] ??
          (existingWebFontPath.isEmpty
              ? fallbackUploadedPath
              : existingWebFontPath);
      values['font_files'] = uploadedFiles;
    }

    final result = await _postJson('/api/admin/query', {
      'table': 'site_fonts',
      'method': 'update',
      'select': _fontSelect,
      'values': values,
      'filters': [
        {'type': 'comparison', 'op': 'eq', 'column': 'id', 'value': font.id},
      ],
      'single': 'maybeSingle',
    });
    _throwIfApiError(result, fallbackMessage: 'Font guncellenemedi');
    final row = result['data'];
    if (row is Map) return AdminFontRow.fromJson(row);
    throw const AdminFontSettingsException('Font guncelleme yaniti gecersiz');
  }

  Future<String> _uploadFontFile({
    required String family,
    required int weight,
    required AdminFontUploadFile file,
  }) async {
    final uploadUri = _uri('/api/storage/upload');
    final request = http.MultipartRequest('POST', uploadUri);
    if (!kIsWeb) {
      request.headers['Origin'] =
          '${uploadUri.scheme}://${uploadUri.authority}';
    }
    request.headers.addAll(await adminAuthHeaders());
    request.fields['type'] = 'font';
    request.fields['customPath'] = 'site/$family';
    request.fields['customFilename'] = '$family-$weight';
    request.files.add(
      http.MultipartFile.fromBytes('file', file.bytes, filename: file.fileName),
    );

    final uploadClient = httpClient ?? adminHttpClient;
    final streamedResponse = await uploadClient
        .send(request)
        .timeout(const Duration(seconds: 120));
    final response = await http.Response.fromStream(
      streamedResponse,
    ).timeout(_requestTimeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AdminFontSettingsException(
        response.body.isEmpty ? 'Font dosyasi yuklenemedi' : response.body,
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const AdminFontSettingsException('Gecersiz yukleme yaniti');
    }
    final src = decoded['src']?.toString() ?? '';
    if (src.isEmpty) {
      throw const AdminFontSettingsException('Font URL alinamadi');
    }
    return src;
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
      throw const AdminFontSettingsException('Gecersiz sunucu yaniti');
    }
    final result = _asStringKeyMap(decoded);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwIfApiError(result, fallbackMessage: 'Sunucu istegi basarisiz');
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
        throw AdminFontSettingsException(message);
      }
    }
    throw AdminFontSettingsException(fallbackMessage);
  }
}

class AdminFontSettingsException implements Exception {
  const AdminFontSettingsException(this.message);

  final String message;

  @override
  String toString() => message;
}

const defaultFontSizes = <String, int>{
  'fs-base': 15,
  'fs-post-title': 32,
  'fs-post-summary': 18,
  'fs-content': 17,
  'fs-main-nav': 14,
  'fs-tiny': 11,
  'fs-xs': 12,
  'fs-sm': 13,
  'fs-md': 15,
  'fs-lg': 16,
  'fs-xl': 18,
  'fs-title-xs': 14,
  'fs-title-sm': 16,
  'fs-title-md': 18,
  'fs-title-lg': 20,
  'fs-title-xl': 22,
  'fs-title-2xl': 24,
  'fs-title-3xl': 28,
  'fs-title-4xl': 30,
  'fs-title-5xl': 32,
};

const defaultWebFontSizes = <String, int>{
  'web-nav-label': 14,
  'web-featured-title': 36,
  'web-featured-summary': 16,
  'web-card-title': 38,
  'web-card-summary': 16,
  'web-detail-title': 48,
  'web-detail-summary': 18,
  'web-detail-body': 17,
};

const defaultMobileFontSizes = <String, int>{
  'mobile-nav-label': 14,
  'mobile-featured-title': 28,
  'mobile-featured-summary': 15,
  'mobile-card-title': 28,
  'mobile-card-summary': 15,
  'mobile-detail-title': 32,
  'mobile-detail-summary': 18,
  'mobile-detail-body': 17,
};

const defaultWebFontWeights = <String, int>{
  'web-nav-label': 700,
  'web-featured-title': 800,
  'web-featured-summary': 500,
  'web-card-title': 800,
  'web-card-summary': 500,
  'web-detail-title': 800,
  'web-detail-summary': 500,
  'web-detail-body': 400,
};

const defaultMobileFontWeights = <String, int>{
  'mobile-nav-label': 600,
  'mobile-featured-title': 800,
  'mobile-featured-summary': 400,
  'mobile-card-title': 800,
  'mobile-card-summary': 400,
  'mobile-detail-title': 800,
  'mobile-detail-summary': 500,
  'mobile-detail-body': 400,
};

const fallbackSiteFonts = <AdminFontRow>[
  AdminFontRow(
    id: 25,
    name: 'Nunito Sans',
    family: 'NunitoSans',
    type: 'sans_serif',
    source: 'local',
    webFontPath: '/fonts/site/nunito_sans/NunitoSans.ttf',
    flutterFamily: 'NunitoSans',
    fallbackStack: "'NunitoSans', Arial, sans-serif",
    fontFiles: {
      '200': '/fonts/site/nunito_sans/NunitoSans.ttf',
      '300': '/fonts/site/nunito_sans/NunitoSans.ttf',
      '400': '/fonts/site/nunito_sans/NunitoSans.ttf',
      '500': '/fonts/site/nunito_sans/NunitoSans.ttf',
      '600': '/fonts/site/nunito_sans/NunitoSans.ttf',
      '700': '/fonts/site/nunito_sans/NunitoSans.ttf',
      '800': '/fonts/site/nunito_sans/NunitoSans.ttf',
      '900': '/fonts/site/nunito_sans/NunitoSans.ttf',
      '1000': '/fonts/site/nunito_sans/NunitoSans.ttf',
    },
    active: true,
    sortOrder: 25,
  ),
  AdminFontRow(
    id: 24,
    name: 'Baloo 2 ExtraBold',
    family: 'Baloo2',
    type: 'sans_serif',
    source: 'local',
    webFontPath: '/fonts/site/baloo_2/Baloo2.ttf',
    flutterFamily: 'Baloo2',
    fallbackStack: "'Baloo2', Arial, sans-serif",
    fontFiles: {
      '400': '/fonts/site/baloo_2/Baloo2.ttf',
      '500': '/fonts/site/baloo_2/Baloo2.ttf',
      '600': '/fonts/site/baloo_2/Baloo2.ttf',
      '700': '/fonts/site/baloo_2/Baloo2.ttf',
      '800': '/fonts/site/baloo_2/Baloo2.ttf',
    },
    active: true,
    sortOrder: 24,
  ),
  AdminFontRow(
    id: 23,
    name: 'Fredoka',
    family: 'Fredoka',
    type: 'sans_serif',
    source: 'local',
    webFontPath: '/fonts/site/fredoka/Fredoka.ttf',
    flutterFamily: 'Fredoka',
    fallbackStack: "'Fredoka', Arial, sans-serif",
    fontFiles: {
      '300': '/fonts/site/fredoka/Fredoka.ttf',
      '400': '/fonts/site/fredoka/Fredoka.ttf',
      '500': '/fonts/site/fredoka/Fredoka.ttf',
      '600': '/fonts/site/fredoka/Fredoka.ttf',
      '700': '/fonts/site/fredoka/Fredoka.ttf',
    },
    active: true,
    sortOrder: 23,
  ),
  AdminFontRow(
    id: 22,
    name: 'Work Sans',
    family: 'WorkSans',
    type: 'sans_serif',
    source: 'local',
    webFontPath: '/fonts/site/work_sans/WorkSans.ttf',
    flutterFamily: 'WorkSans',
    fallbackStack: "'WorkSans', Arial, sans-serif",
    fontFiles: {'400': '/fonts/site/work_sans/WorkSans.ttf'},
    active: true,
    sortOrder: 22,
  ),
  AdminFontRow(
    id: 21,
    name: 'Verdana',
    family: 'Verdana',
    type: 'sans_serif',
    source: 'system',
    webFontPath: '',
    flutterFamily: 'Verdana',
    fallbackStack: 'Verdana, Geneva, sans-serif',
    fontFiles: {},
    active: true,
    sortOrder: 21,
  ),
  AdminFontRow(
    id: 20,
    name: 'Trebuchet MS',
    family: 'TrebuchetMS',
    type: 'sans_serif',
    source: 'system',
    webFontPath: '',
    flutterFamily: 'Trebuchet MS',
    fallbackStack: "'Trebuchet MS', Arial, sans-serif",
    fontFiles: {},
    active: true,
    sortOrder: 20,
  ),
  AdminFontRow(
    id: 19,
    name: 'Times New Roman',
    family: 'TimesNewRoman',
    type: 'serif',
    source: 'system',
    webFontPath: '',
    flutterFamily: 'Times New Roman',
    fallbackStack: "'Times New Roman', Times, serif",
    fontFiles: {},
    active: true,
    sortOrder: 19,
  ),
  AdminFontRow(
    id: 18,
    name: 'Tahoma',
    family: 'Tahoma',
    type: 'sans_serif',
    source: 'system',
    webFontPath: '',
    flutterFamily: 'Tahoma',
    fallbackStack: 'Tahoma, Geneva, sans-serif',
    fontFiles: {},
    active: true,
    sortOrder: 18,
  ),
  AdminFontRow(
    id: 17,
    name: 'Source Sans 3',
    family: 'SourceSans3',
    type: 'sans_serif',
    source: 'local',
    webFontPath: '/fonts/site/source_sans_3/SourceSans3.ttf',
    flutterFamily: 'SourceSans3',
    fallbackStack: "'SourceSans3', Arial, sans-serif",
    fontFiles: {'400': '/fonts/site/source_sans_3/SourceSans3.ttf'},
    active: true,
    sortOrder: 17,
  ),
  AdminFontRow(
    id: 16,
    name: 'Roboto',
    family: 'Roboto',
    type: 'sans_serif',
    source: 'local',
    webFontPath: '/fonts/roboto-latin-ext.woff2',
    flutterFamily: 'Roboto',
    fallbackStack: "'Roboto', Arial, sans-serif",
    fontFiles: {'400': '/fonts/roboto-latin-ext.woff2'},
    active: true,
    sortOrder: 16,
  ),
  AdminFontRow(
    id: 15,
    name: 'Poppins',
    family: 'Poppins',
    type: 'sans_serif',
    source: 'local',
    webFontPath: '/fonts/site/poppins/Poppins-Regular.ttf',
    flutterFamily: 'Poppins',
    fallbackStack: "'Poppins', Arial, sans-serif",
    fontFiles: {
      '400': '/fonts/site/poppins/Poppins-Regular.ttf',
      '600': '/fonts/site/poppins/Poppins-SemiBold.ttf',
      '700': '/fonts/site/poppins/Poppins-Bold.ttf',
    },
    active: true,
    sortOrder: 15,
  ),
  AdminFontRow(
    id: 14,
    name: 'Plus Jakarta Sans',
    family: 'PlusJakartaSans',
    type: 'sans_serif',
    source: 'local',
    webFontPath: '/fonts/site/plus_jakarta_sans/PlusJakartaSans.ttf',
    flutterFamily: 'PlusJakartaSans',
    fallbackStack: "'PlusJakartaSans', Arial, sans-serif",
    fontFiles: {'400': '/fonts/site/plus_jakarta_sans/PlusJakartaSans.ttf'},
    active: true,
    sortOrder: 14,
  ),
  AdminFontRow(
    id: 13,
    name: 'Open Sans',
    family: 'OpenSans',
    type: 'sans_serif',
    source: 'local',
    webFontPath: '/fonts/site/open_sans/OpenSans.ttf',
    flutterFamily: 'OpenSans',
    fallbackStack: "'OpenSans', Arial, sans-serif",
    fontFiles: {'400': '/fonts/site/open_sans/OpenSans.ttf'},
    active: true,
    sortOrder: 13,
  ),
  AdminFontRow(
    id: 12,
    name: 'Noto Serif',
    family: 'NotoSerif',
    type: 'serif',
    source: 'local',
    webFontPath: '/fonts/site/noto_serif/NotoSerif.ttf',
    flutterFamily: 'NotoSerif',
    fallbackStack: "'NotoSerif', Georgia, serif",
    fontFiles: {'400': '/fonts/site/noto_serif/NotoSerif.ttf'},
    active: true,
    sortOrder: 12,
  ),
  AdminFontRow(
    id: 11,
    name: 'Montserrat',
    family: 'Montserrat',
    type: 'sans_serif',
    source: 'local',
    webFontPath: '/fonts/site/montserrat/Montserrat.ttf',
    flutterFamily: 'Montserrat',
    fallbackStack: "'Montserrat', Arial, sans-serif",
    fontFiles: {'400': '/fonts/site/montserrat/Montserrat.ttf'},
    active: true,
    sortOrder: 11,
  ),
  AdminFontRow(
    id: 10,
    name: 'Merriweather',
    family: 'Merriweather',
    type: 'serif',
    source: 'local',
    webFontPath: '/fonts/site/merriweather/Merriweather.ttf',
    flutterFamily: 'Merriweather',
    fallbackStack: "'Merriweather', Georgia, serif",
    fontFiles: {'400': '/fonts/site/merriweather/Merriweather.ttf'},
    active: true,
    sortOrder: 10,
  ),
  AdminFontRow(
    id: 9,
    name: 'Libre Baskerville',
    family: 'LibreBaskerville',
    type: 'serif',
    source: 'local',
    webFontPath: '/fonts/site/libre_baskerville/LibreBaskerville.ttf',
    flutterFamily: 'LibreBaskerville',
    fallbackStack: "'LibreBaskerville', Georgia, serif",
    fontFiles: {'400': '/fonts/site/libre_baskerville/LibreBaskerville.ttf'},
    active: true,
    sortOrder: 9,
  ),
  AdminFontRow(
    id: 8,
    name: 'Jost',
    family: 'Jost',
    type: 'sans_serif',
    source: 'local',
    webFontPath: '/fonts/site/jost/Jost.ttf',
    flutterFamily: 'Jost',
    fallbackStack: "'Jost', Arial, sans-serif",
    fontFiles: {'400': '/fonts/site/jost/Jost.ttf'},
    active: true,
    sortOrder: 8,
  ),
  AdminFontRow(
    id: 7,
    name: 'Inter',
    family: 'PateezInter',
    type: 'sans_serif',
    source: 'local',
    webFontPath: '/fonts/inter-latin-ext.woff2',
    flutterFamily: 'PateezInter',
    fallbackStack: "'PateezInter', 'Inter', Arial, sans-serif",
    fontFiles: {'400': '/fonts/inter-latin-ext.woff2'},
    active: true,
    sortOrder: 7,
  ),
  AdminFontRow(
    id: 6,
    name: 'IBM Plex Sans',
    family: 'IBMPlexSans',
    type: 'sans_serif',
    source: 'local',
    webFontPath: '/fonts/site/ibm_plex_sans/IBMPlexSans.ttf',
    flutterFamily: 'IBMPlexSans',
    fallbackStack: "'IBMPlexSans', Arial, sans-serif",
    fontFiles: {'400': '/fonts/site/ibm_plex_sans/IBMPlexSans.ttf'},
    active: true,
    sortOrder: 6,
  ),
  AdminFontRow(
    id: 5,
    name: 'Helvetica Neue',
    family: 'HelveticaNeue',
    type: 'sans_serif',
    source: 'system',
    webFontPath: '',
    flutterFamily: 'Helvetica Neue',
    fallbackStack: "'Helvetica Neue', Helvetica, Arial, sans-serif",
    fontFiles: {},
    active: true,
    sortOrder: 5,
  ),
  AdminFontRow(
    id: 4,
    name: 'Georgia',
    family: 'Georgia',
    type: 'serif',
    source: 'system',
    webFontPath: '',
    flutterFamily: 'Georgia',
    fallbackStack: "Georgia, 'Times New Roman', serif",
    fontFiles: {},
    active: true,
    sortOrder: 4,
  ),
  AdminFontRow(
    id: 3,
    name: 'DM Sans',
    family: 'DMSans',
    type: 'sans_serif',
    source: 'local',
    webFontPath: '/fonts/site/dm_sans/DMSans.ttf',
    flutterFamily: 'DMSans',
    fallbackStack: "'DMSans', Arial, sans-serif",
    fontFiles: {'400': '/fonts/site/dm_sans/DMSans.ttf'},
    active: true,
    sortOrder: 3,
  ),
  AdminFontRow(
    id: 2,
    name: 'Arial',
    family: 'Arial',
    type: 'sans_serif',
    source: 'system',
    webFontPath: '',
    flutterFamily: 'Arial',
    fallbackStack: 'Arial, Helvetica, sans-serif',
    fontFiles: {},
    active: true,
    sortOrder: 2,
  ),
  AdminFontRow(
    id: 1,
    name: 'PateezSans',
    family: 'PateezSans',
    type: 'sans_serif',
    source: 'local',
    webFontPath: '/fonts/site/google_sans_flex/GoogleSansFlex-400.ttf',
    flutterFamily: 'PateezSans',
    fallbackStack: "'PateezSans', 'Segoe UI', Arial, sans-serif",
    fontFiles: {'400': '/fonts/site/google_sans_flex/GoogleSansFlex-400.ttf'},
    active: true,
    sortOrder: 1,
  ),
];

const _settingsSelect =
    'language_code,site_primary_font,site_title_font,site_content_font,'
    'site_font_sizes';

const _fontSelect =
    'id,name,family,type,source,web_font_path,flutter_family,fallback_stack,'
    'font_files,is_active,sort_order';

List<AdminFontRow> _fontsFromData(Object? data) {
  if (data is! List) return fallbackSiteFonts;
  final rows = data
      .whereType<Map>()
      .map(AdminFontRow.fromJson)
      .where((font) => font.name.isNotEmpty && font.family.isNotEmpty)
      .toList(growable: false);
  if (rows.isEmpty) return fallbackSiteFonts;
  return rows;
}

AdminFontSettingsData _sanitizeSettings(
  AdminFontSettingsData settings,
  List<AdminFontRow> fonts,
) {
  final families = fonts.map((font) => font.family).toSet();
  String safeFamily(String value) {
    if (families.isEmpty || families.contains(value)) return value;
    return 'PateezInter';
  }

  return settings.copyWith(
    primaryFont: safeFamily(settings.primaryFont),
    titleFont: safeFamily(settings.titleFont),
    contentFont: safeFamily(settings.contentFont),
    mobilePrimaryFont: safeFamily(settings.mobilePrimaryFont),
    mobileTitleFont: safeFamily(settings.mobileTitleFont),
    mobileContentFont: safeFamily(settings.mobileContentFont),
    fontSizes: _clampedWebSizes(settings.fontSizes),
    mobileFontSizes: _clampedMobileSizes(settings.mobileFontSizes),
    fontWeights: _clampedWebWeights(settings.fontWeights),
    mobileFontWeights: _clampedMobileWeights(settings.mobileFontWeights),
  );
}

Map<String, int> _clampedLegacySizes(Map<String, int> values) {
  final result = Map<String, int>.of(defaultFontSizes);
  for (final entry in values.entries) {
    if (!defaultFontSizes.containsKey(entry.key)) continue;
    result[entry.key] = entry.value.clamp(8, 96);
  }
  return result;
}

Map<String, int> _clampedWebSizes(Map<String, int> values) {
  final result = Map<String, int>.of(defaultWebFontSizes);
  for (final entry in values.entries) {
    if (!defaultWebFontSizes.containsKey(entry.key)) continue;
    result[entry.key] = entry.value.clamp(8, 96);
  }
  return result;
}

Map<String, int> _clampedMobileSizes(Map<String, int> values) {
  final result = Map<String, int>.of(defaultMobileFontSizes);
  for (final entry in values.entries) {
    if (!defaultMobileFontSizes.containsKey(entry.key)) continue;
    result[entry.key] = entry.value.clamp(8, 96);
  }
  return result;
}

Map<String, int> _clampedWebWeights(Map<String, int> values) {
  final result = Map<String, int>.of(defaultWebFontWeights);
  for (final entry in values.entries) {
    if (!defaultWebFontWeights.containsKey(entry.key)) continue;
    result[entry.key] = _clampFontWeight(entry.value);
  }
  return result;
}

Map<String, int> _clampedMobileWeights(Map<String, int> values) {
  final result = Map<String, int>.of(defaultMobileFontWeights);
  for (final entry in values.entries) {
    if (!defaultMobileFontWeights.containsKey(entry.key)) continue;
    result[entry.key] = _clampFontWeight(entry.value);
  }
  return result;
}

int _clampFontWeight(int value) {
  final clamped = value.clamp(100, 900);
  return ((clamped / 100).round() * 100).clamp(100, 900);
}

Map<String, int> _legacyFontSizeMap(Object? value) {
  final result = Map<String, int>.of(defaultFontSizes);
  Map<dynamic, dynamic>? source;
  if (value is Map) {
    source = value;
  } else if (value is String && value.trim().isNotEmpty) {
    final decoded = jsonDecode(value);
    if (decoded is Map) source = decoded;
  }
  if (source != null) {
    for (final entry in source.entries) {
      final key = entry.key.toString();
      final parsed = _int(entry.value, fallback: defaultFontSizes[key] ?? 0);
      if (defaultFontSizes.containsKey(key)) {
        result[key] = parsed.clamp(8, 96);
      }
    }
  }
  return _clampedLegacySizes(result);
}

Map<String, int> _webFontSizeMap(Object? value, Map<String, int> legacySizes) {
  final result = _defaultWebFontSizesFromLegacy(legacySizes);
  final source = _nestedMap(value, 'web');
  if (source != null) {
    for (final entry in source.entries) {
      final key = entry.key.toString();
      if (!defaultWebFontSizes.containsKey(key)) continue;
      final parsed = _int(
        entry.value,
        fallback: result[key] ?? defaultWebFontSizes[key] ?? 0,
      );
      result[key] = parsed.clamp(8, 96);
    }
  }
  return _clampedWebSizes(result);
}

Map<String, int> _mobileFontSizeMap(Object? value, Map<String, int> webSizes) {
  final result = _defaultMobileFontSizesFromWeb(webSizes);
  final source = _nestedMap(value, 'mobile');
  if (source != null) {
    for (final entry in source.entries) {
      final key = entry.key.toString();
      final parsed = _int(
        entry.value,
        fallback: result[key] ?? defaultMobileFontSizes[key] ?? 0,
      );
      if (defaultMobileFontSizes.containsKey(key)) {
        result[key] = parsed.clamp(8, 96);
      }
    }
  }
  return result;
}

Map<String, int> _fontWeightMap(
  Object? value, {
  required String target,
  required Map<String, int> defaults,
}) {
  final result = Map<String, int>.of(defaults);
  final weights = _nestedMap(value, 'weights');
  final source = weights == null ? null : _mapFromUnknown(weights[target]);
  if (source != null) {
    for (final entry in source.entries) {
      final key = entry.key.toString();
      if (!defaults.containsKey(key)) continue;
      final parsed = _int(entry.value, fallback: result[key] ?? 400);
      result[key] = _clampFontWeight(parsed);
    }
  }
  return result;
}

Map<String, String> _targetFontFamiliesMap(
  Object? value, {
  required String target,
  required String primary,
  required String title,
  required String content,
}) {
  final result = <String, String>{
    'primary': primary,
    'title': title,
    'content': content,
  };
  final fonts = _nestedMap(value, 'fonts');
  final source = fonts == null ? null : _mapFromUnknown(fonts[target]);
  if (source != null) {
    for (final key in result.keys.toList()) {
      final parsed = _string(source[key]);
      if (parsed.isNotEmpty) result[key] = parsed;
    }
  }
  return result;
}

Map<String, int> _defaultWebFontSizesFromLegacy(Map<String, int> legacySizes) {
  return {
    'web-nav-label':
        legacySizes['fs-main-nav'] ?? defaultWebFontSizes['web-nav-label']!,
    'web-featured-title':
        legacySizes['fs-title-4xl'] ??
        legacySizes['fs-title-5xl'] ??
        defaultWebFontSizes['web-featured-title']!,
    'web-featured-summary':
        legacySizes['fs-post-summary'] ??
        defaultWebFontSizes['web-featured-summary']!,
    'web-card-title':
        legacySizes['fs-title-5xl'] ??
        legacySizes['fs-title-3xl'] ??
        defaultWebFontSizes['web-card-title']!,
    'web-card-summary': legacySizes['fs-content'] == null
        ? defaultWebFontSizes['web-card-summary']!
        : (legacySizes['fs-content']! - 2).clamp(8, 96),
    'web-detail-title':
        legacySizes['fs-post-title'] ??
        defaultWebFontSizes['web-detail-title']!,
    'web-detail-summary':
        legacySizes['fs-post-summary'] ??
        defaultWebFontSizes['web-detail-summary']!,
    'web-detail-body':
        legacySizes['fs-content'] ?? defaultWebFontSizes['web-detail-body']!,
  };
}

Map<String, int> _legacyFontSizesFromWeb(Map<String, int> webSizes) {
  final result = Map<String, int>.of(defaultFontSizes);
  result['fs-base'] = webSizes['web-detail-body'] ?? result['fs-base']!;
  result['fs-main-nav'] = webSizes['web-nav-label'] ?? result['fs-main-nav']!;
  result['fs-post-title'] =
      webSizes['web-detail-title'] ?? result['fs-post-title']!;
  result['fs-post-summary'] =
      webSizes['web-detail-summary'] ?? result['fs-post-summary']!;
  result['fs-content'] = webSizes['web-detail-body'] ?? result['fs-content']!;
  result['fs-md'] = webSizes['web-card-summary'] ?? result['fs-md']!;
  result['fs-title-3xl'] =
      webSizes['web-card-title'] ?? result['fs-title-3xl']!;
  result['fs-title-4xl'] =
      webSizes['web-featured-title'] ?? result['fs-title-4xl']!;
  result['fs-title-5xl'] =
      webSizes['web-card-title'] ?? result['fs-title-5xl']!;
  return _clampedLegacySizes(result);
}

Map<String, int> _defaultMobileFontSizesFromWeb(Map<String, int> webSizes) {
  return {
    'mobile-nav-label':
        webSizes['web-nav-label'] ??
        defaultMobileFontSizes['mobile-nav-label']!,
    'mobile-featured-title':
        webSizes['web-featured-title'] ??
        defaultMobileFontSizes['mobile-featured-title']!,
    'mobile-featured-summary':
        webSizes['web-featured-summary'] ??
        defaultMobileFontSizes['mobile-featured-summary']!,
    'mobile-card-title':
        webSizes['web-card-title'] ??
        defaultMobileFontSizes['mobile-card-title']!,
    'mobile-card-summary':
        webSizes['web-card-summary'] ??
        defaultMobileFontSizes['mobile-card-summary']!,
    'mobile-detail-title':
        webSizes['web-detail-title'] ??
        defaultMobileFontSizes['mobile-detail-title']!,
    'mobile-detail-summary':
        webSizes['web-detail-summary'] ??
        defaultMobileFontSizes['mobile-detail-summary']!,
    'mobile-detail-body':
        webSizes['web-detail-body'] ??
        defaultMobileFontSizes['mobile-detail-body']!,
  };
}

Map<dynamic, dynamic>? _nestedMap(Object? value, String key) {
  final source = _mapFromUnknown(value);
  if (source == null) return null;
  return _mapFromUnknown(source[key]);
}

Map<dynamic, dynamic>? _mapFromUnknown(Object? value) {
  if (value is Map) return value;
  if (value is String && value.trim().isNotEmpty) {
    final decoded = jsonDecode(value);
    if (decoded is Map) return decoded;
  }
  return null;
}

Map<String, String> _stringMap(Object? value) {
  final result = <String, String>{};
  Map<dynamic, dynamic>? source;
  if (value is Map) {
    source = value;
  } else if (value is String && value.trim().isNotEmpty) {
    final decoded = jsonDecode(value);
    if (decoded is Map) source = decoded;
  }
  if (source == null) return result;
  for (final entry in source.entries) {
    result[entry.key.toString()] = entry.value?.toString() ?? '';
  }
  return result;
}

String _string(Object? value, {String fallback = ''}) {
  final text = value?.toString();
  if (text == null || text.isEmpty) return fallback;
  return text;
}

int _int(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

String _cleanLanguageCode(String value) {
  final code = value.trim().toLowerCase().replaceAll('_', '-');
  return code.isEmpty ? 'tr' : code;
}

String _cleanFontType(String value) {
  return switch (value.trim()) {
    'serif' => 'serif',
    'monospace' => 'monospace',
    'cursive' => 'cursive',
    'fantasy' => 'fantasy',
    'system_ui' || 'systemUi' => 'system_ui',
    _ => 'sans_serif',
  };
}

String _fontFamilyFromName(String name) {
  final buffer = StringBuffer();
  var nextUpper = true;
  for (final codeUnit in name.runes) {
    final char = String.fromCharCode(codeUnit);
    if (RegExp(r'[A-Za-z0-9]').hasMatch(char)) {
      buffer.write(nextUpper ? char.toUpperCase() : char);
      nextUpper = false;
    } else {
      nextUpper = true;
    }
  }
  final value = buffer.toString();
  return value.isEmpty ? 'CustomFont' : value;
}

Map<String, Object?> _asStringKeyMap(Map<dynamic, dynamic> value) {
  return value.map((key, nestedValue) => MapEntry(key.toString(), nestedValue));
}
