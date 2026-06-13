import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../network/frontend_http_client.dart';

import '../network/local_api_base_url.dart';

const frontendDefaultFontSizes = <String, int>{
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

const frontendDefaultMobileFontSizes = <String, int>{
  'mobile-nav-label': 14,
  'mobile-featured-title': 28,
  'mobile-featured-summary': 15,
  'mobile-card-title': 28,
  'mobile-card-summary': 15,
  'mobile-detail-title': 32,
  'mobile-detail-summary': 18,
  'mobile-detail-body': 17,
};

const frontendDefaultMobileFontWeights = <String, int>{
  'mobile-nav-label': 600,
  'mobile-featured-title': 800,
  'mobile-featured-summary': 400,
  'mobile-card-title': 800,
  'mobile-card-summary': 400,
  'mobile-detail-title': 800,
  'mobile-detail-summary': 500,
  'mobile-detail-body': 400,
};

const _bundledFontFamilies = {
  'PateezInter',
  'PateezSans',
  'OpenSans',
  'PlusJakartaSans',
  'DMSans',
  'IBMPlexSans',
  'Jost',
  'LibreBaskerville',
  'Merriweather',
  'Montserrat',
  'NotoSerif',
  'Poppins',
  'Fredoka',
  'NunitoSans',
  'Baloo2',
  'Roboto',
  'SourceSans3',
  'WorkSans',
  'Newsreader',
  'Lexend',
};

class FrontendFontRow {
  const FrontendFontRow({
    required this.family,
    required this.source,
    required this.webFontPath,
    required this.fontFiles,
  });

  factory FrontendFontRow.fromJson(Map<dynamic, dynamic> json) {
    final item = json.map((key, value) => MapEntry(key.toString(), value));
    return FrontendFontRow(
      family: _string(item['family']),
      source: _string(item['source']),
      webFontPath: _string(item['web_font_path']),
      fontFiles: _stringMap(item['font_files']),
    );
  }

  final String family;
  final String source;
  final String webFontPath;
  final Map<String, String> fontFiles;
}

class FrontendFontSettings {
  const FrontendFontSettings({
    required this.primaryFontFamily,
    required this.titleFontFamily,
    required this.contentFontFamily,
    required this.fontSizes,
    required this.mobileFontSizes,
    required this.mobileFontWeights,
    required this.fonts,
  });

  factory FrontendFontSettings.empty() {
    final fontSizes = Map<String, int>.of(frontendDefaultFontSizes);
    return FrontendFontSettings(
      primaryFontFamily: 'PateezInter',
      titleFontFamily: 'PateezInter',
      contentFontFamily: 'PateezInter',
      fontSizes: fontSizes,
      mobileFontSizes: _defaultMobileFontSizesFrom(fontSizes),
      mobileFontWeights: Map<String, int>.of(frontendDefaultMobileFontWeights),
      fonts: const [],
    );
  }

  final String primaryFontFamily;
  final String titleFontFamily;
  final String contentFontFamily;
  final Map<String, int> fontSizes;
  final Map<String, int> mobileFontSizes;
  final Map<String, int> mobileFontWeights;
  final List<FrontendFontRow> fonts;

  double size(String key) {
    return (fontSizes[key] ?? frontendDefaultFontSizes[key] ?? 15).toDouble();
  }

  double mobileSize(String key) {
    return (mobileFontSizes[key] ??
            frontendDefaultMobileFontSizes[key] ??
            size(key))
        .toDouble();
  }

  int mobileWeightValue(String key) {
    return mobileFontWeights[key] ??
        frontendDefaultMobileFontWeights[key] ??
        400;
  }
}

class FrontendFontSettingsRepository {
  const FrontendFontSettingsRepository({this.httpClient, this.apiBaseUrl});

  static const _apiBaseUrl = String.fromEnvironment('PATEEZNEWS_API_BASE_URL');
  static const _timeout = Duration(seconds: 10);
  static final _loadedNetworkFamilies = <String>{};

  final http.Client? httpClient;
  final String? apiBaseUrl;

  Future<FrontendFontSettings> fetch(String languageCode) async {
    final uri = _uri(
      '/api/app/font-settings',
    ).replace(queryParameters: {'lang': _cleanLanguageCode(languageCode)});
    final client = httpClient ?? sharedFrontendClient;
    try {
      final response = await client
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(_timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return FrontendFontSettings.empty();
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return FrontendFontSettings.empty();
      final fonts = (decoded['fonts'] is List ? decoded['fonts'] as List : [])
          .whereType<Map>()
          .map(FrontendFontRow.fromJson)
          .where((font) => font.family.isNotEmpty)
          .toList(growable: false);
      final settings = decoded['settings'];
      if (settings is! Map) {
        return FrontendFontSettings.empty();
      }
      final fontSizes = _fontSizeMap(settings['fontSizes']);
      final result = FrontendFontSettings(
        primaryFontFamily: _safeFamily(
          settings['mobilePrimaryFont'] ?? settings['primaryFont'],
          fallback: 'PateezInter',
        ),
        titleFontFamily: _safeFamily(
          settings['mobileTitleFont'] ?? settings['titleFont'],
          fallback: 'PateezInter',
        ),
        contentFontFamily: _safeFamily(
          settings['mobileContentFont'] ?? settings['contentFont'],
          fallback: 'PateezInter',
        ),
        fontSizes: fontSizes,
        mobileFontSizes: _mobileFontSizeMap(
          settings['mobileFontSizes'],
          fontSizes,
        ),
        mobileFontWeights: _mobileFontWeightMap(settings['mobileFontWeights']),
        fonts: fonts,
      );
      await _loadNetworkFonts(result);
      return result;
    } catch (_) {
      return FrontendFontSettings.empty();
    } finally {
      // Shared frontend client is not closed.
    }
  }

  Future<void> _loadNetworkFonts(FrontendFontSettings settings) async {
    final selectedFamilies = {
      settings.primaryFontFamily,
      settings.titleFontFamily,
      settings.contentFontFamily,
    };
    final selectedRows = settings.fonts.where(
      (font) =>
          selectedFamilies.contains(font.family) &&
          font.source == 'local' &&
          !_bundledFontFamilies.contains(font.family),
    );
    for (final font in selectedRows) {
      final source =
          font.fontFiles['400'] ??
          (font.webFontPath.isNotEmpty
              ? font.webFontPath
              : (font.fontFiles.isEmpty ? '' : font.fontFiles.values.first));
      if (source.isEmpty || _loadedNetworkFamilies.contains(font.family)) {
        continue;
      }
      try {
        final uri = _uri(source);
        final client = httpClient ?? sharedFrontendClient;
        try {
          final response = await client.get(uri).timeout(_timeout);
          if (response.statusCode < 200 || response.statusCode >= 300) {
            continue;
          }
          final bytes = Uint8List.fromList(response.bodyBytes);
          final loader = FontLoader(font.family)
            ..addFont(Future.value(ByteData.sublistView(bytes)));
          await loader.load();
          _loadedNetworkFamilies.add(font.family);
        } finally {
          // Shared frontend client is not closed.
        }
      } catch (_) {
        continue;
      }
    }
  }

  Uri _uri(String path) {
    return frontendApiUri(path, configuredBaseUrl: apiBaseUrl ?? _apiBaseUrl);
  }
}

Map<String, int> _fontSizeMap(Object? value) {
  final result = Map<String, int>.of(frontendDefaultFontSizes);
  Map<dynamic, dynamic>? source;
  if (value is Map) {
    source = value;
  } else if (value is String && value.trim().isNotEmpty) {
    final decoded = jsonDecode(value);
    if (decoded is Map) source = decoded;
  }
  if (source == null) return result;
  for (final entry in source.entries) {
    final key = entry.key.toString();
    if (!frontendDefaultFontSizes.containsKey(key)) continue;
    final numeric = int.tryParse(entry.value?.toString() ?? '');
    if (numeric != null) {
      result[key] = numeric.clamp(8, 96);
    }
  }
  return result;
}

Map<String, int> _mobileFontSizeMap(Object? value, Map<String, int> webSizes) {
  final result = _defaultMobileFontSizesFrom(webSizes);
  Map<dynamic, dynamic>? source;
  if (value is Map) {
    source = value;
  } else if (value is String && value.trim().isNotEmpty) {
    final decoded = jsonDecode(value);
    if (decoded is Map) source = decoded;
  }
  if (source == null) return result;
  for (final entry in source.entries) {
    final key = entry.key.toString();
    if (!frontendDefaultMobileFontSizes.containsKey(key)) continue;
    final numeric = int.tryParse(entry.value?.toString() ?? '');
    if (numeric != null) {
      result[key] = numeric.clamp(8, 96);
    }
  }
  return result;
}

Map<String, int> _mobileFontWeightMap(Object? value) {
  final result = Map<String, int>.of(frontendDefaultMobileFontWeights);
  Map<dynamic, dynamic>? source;
  if (value is Map) {
    source = value;
  } else if (value is String && value.trim().isNotEmpty) {
    final decoded = jsonDecode(value);
    if (decoded is Map) source = decoded;
  }
  if (source == null) return result;
  for (final entry in source.entries) {
    final key = entry.key.toString();
    if (!frontendDefaultMobileFontWeights.containsKey(key)) continue;
    final numeric = int.tryParse(entry.value?.toString() ?? '');
    if (numeric != null) {
      final clamped = numeric.clamp(100, 900);
      result[key] = ((clamped / 100).round() * 100).clamp(100, 900);
    }
  }
  return result;
}

Map<String, int> _defaultMobileFontSizesFrom(Map<String, int> webSizes) {
  return {
    'mobile-nav-label':
        webSizes['fs-main-nav'] ??
        frontendDefaultMobileFontSizes['mobile-nav-label']!,
    'mobile-featured-title':
        webSizes['fs-title-3xl'] ??
        frontendDefaultMobileFontSizes['mobile-featured-title']!,
    'mobile-featured-summary':
        webSizes['fs-md'] ??
        frontendDefaultMobileFontSizes['mobile-featured-summary']!,
    'mobile-card-title':
        webSizes['fs-title-3xl'] ??
        frontendDefaultMobileFontSizes['mobile-card-title']!,
    'mobile-card-summary':
        webSizes['fs-md'] ??
        frontendDefaultMobileFontSizes['mobile-card-summary']!,
    'mobile-detail-title':
        webSizes['fs-post-title'] ??
        frontendDefaultMobileFontSizes['mobile-detail-title']!,
    'mobile-detail-summary':
        webSizes['fs-post-summary'] ??
        frontendDefaultMobileFontSizes['mobile-detail-summary']!,
    'mobile-detail-body':
        webSizes['fs-content'] ??
        frontendDefaultMobileFontSizes['mobile-detail-body']!,
  };
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

String _safeFamily(Object? value, {required String fallback}) {
  final raw = _string(value).replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
  return raw.isEmpty ? fallback : raw;
}

String _cleanLanguageCode(String value) {
  final code = value.trim().toLowerCase().replaceAll('_', '-');
  return code.isEmpty ? 'tr' : code;
}

String _string(Object? value) => value?.toString().trim() ?? '';
