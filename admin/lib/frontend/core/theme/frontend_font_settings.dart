import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

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
  'Roboto',
  'SourceSans3',
  'WorkSans',
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
    required this.fonts,
  });

  factory FrontendFontSettings.empty() {
    return FrontendFontSettings(
      primaryFontFamily: 'PateezInter',
      titleFontFamily: 'PateezInter',
      contentFontFamily: 'PateezInter',
      fontSizes: Map<String, int>.of(frontendDefaultFontSizes),
      fonts: const [],
    );
  }

  final String primaryFontFamily;
  final String titleFontFamily;
  final String contentFontFamily;
  final Map<String, int> fontSizes;
  final List<FrontendFontRow> fonts;

  double size(String key) {
    return (fontSizes[key] ?? frontendDefaultFontSizes[key] ?? 15).toDouble();
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
    final client = httpClient ?? http.Client();
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
      final result = FrontendFontSettings(
        primaryFontFamily: _safeFamily(
          settings['primaryFont'],
          fallback: 'PateezInter',
        ),
        titleFontFamily: _safeFamily(
          settings['titleFont'],
          fallback: 'PateezInter',
        ),
        contentFontFamily: _safeFamily(
          settings['contentFont'],
          fallback: 'PateezInter',
        ),
        fontSizes: _fontSizeMap(settings['fontSizes']),
        fonts: fonts,
      );
      await _loadNetworkFonts(result);
      return result;
    } catch (_) {
      return FrontendFontSettings.empty();
    } finally {
      if (httpClient == null) client.close();
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
        final client = httpClient ?? http.Client();
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
          if (httpClient == null) client.close();
        }
      } catch (_) {
        continue;
      }
    }
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
