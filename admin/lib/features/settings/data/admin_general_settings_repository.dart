import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pateeznews_admin/core/network/admin_api_headers.dart';

import '../../auth/data/admin_auth_models.dart';

enum GeneralSettingsLogoField {
  logoUrl('logo_url', 'pateezlogowhite.png'),
  footerLogoUrl('footer_logo_url', 'pateezlogofooter.png'),
  darkLogoUrl('dark_logo_url', 'pateezlogodark.png'),
  emailLogoUrl('email_logo_url', 'pateezlogoepost.png'),
  faviconUrl('favicon_url', 'pateezlogoicon.png'),
  ogImageUrl('og_image_url', 'pateezlogoson.png');

  const GeneralSettingsLogoField(this.column, this.uploadFilename);

  final String column;
  final String uploadFilename;

  String get uploadBaseName {
    final extensionIndex = uploadFilename.lastIndexOf('.');
    if (extensionIndex <= 0) return uploadFilename;
    return uploadFilename.substring(0, extensionIndex);
  }
}

class GeneralSettingsData {
  const GeneralSettingsData({
    required this.languageCode,
    required this.siteName,
    required this.timezone,
    required this.footerAbout,
    required this.optionalUrlButtonName,
    required this.copyrightText,
    required this.logoUrl,
    required this.footerLogoUrl,
    required this.darkLogoUrl,
    required this.emailLogoUrl,
    required this.faviconUrl,
    required this.homeTitle,
    required this.metaDescription,
    required this.metaKeywords,
    required this.canonicalUrl,
    required this.ogImageUrl,
    required this.organizationLegalName,
    required this.organizationPhone,
    required this.organizationAddress,
    required this.twitterUsername,
    required this.fbAppId,
    required this.googleAnalyticsId,
    required this.googleSearchConsoleCode,
    required this.bingVerificationCode,
    required this.robotsTxt,
    required this.headerCustomCodes,
    required this.footerCustomCodes,
  });

  factory GeneralSettingsData.empty(String languageCode) {
    return GeneralSettingsData(
      languageCode: languageCode,
      siteName: '',
      timezone: 'Europe/Istanbul',
      footerAbout: '',
      optionalUrlButtonName: '',
      copyrightText: '',
      logoUrl: '',
      footerLogoUrl: '',
      darkLogoUrl: '',
      emailLogoUrl: '',
      faviconUrl: '',
      homeTitle: '',
      metaDescription: '',
      metaKeywords: '',
      canonicalUrl: '',
      ogImageUrl: '',
      organizationLegalName: '',
      organizationPhone: '',
      organizationAddress: '',
      twitterUsername: '',
      fbAppId: '',
      googleAnalyticsId: '',
      googleSearchConsoleCode: '',
      bingVerificationCode: '',
      robotsTxt: '',
      headerCustomCodes: '',
      footerCustomCodes: '',
    );
  }

  factory GeneralSettingsData.fromJson(
    Map<String, Object?> json,
    String languageCode,
  ) {
    return GeneralSettingsData(
      languageCode: _string(json['language_code'], fallback: languageCode),
      siteName: _string(json['site_name']),
      timezone: _string(json['timezone'], fallback: 'Europe/Istanbul'),
      footerAbout: _string(json['footer_about']),
      optionalUrlButtonName: _string(json['optional_url_button_name']),
      copyrightText: _string(json['copyright_text']),
      logoUrl: _string(json['logo_url']),
      footerLogoUrl: _string(json['footer_logo_url']),
      darkLogoUrl: _string(json['dark_logo_url']),
      emailLogoUrl: _string(json['email_logo_url']),
      faviconUrl: _string(json['favicon_url']),
      homeTitle: _string(json['home_title']),
      metaDescription: _string(json['meta_description']),
      metaKeywords: _string(json['meta_keywords']),
      canonicalUrl: _string(json['canonical_url']),
      ogImageUrl: _string(json['og_image_url']),
      organizationLegalName: _string(json['organization_legal_name']),
      organizationPhone: _string(json['organization_phone']),
      organizationAddress: _string(json['organization_address']),
      twitterUsername: _string(json['twitter_username']),
      fbAppId: _string(json['fb_app_id']),
      googleAnalyticsId: _string(json['google_analytics_id']),
      googleSearchConsoleCode: _string(json['google_search_console_code']),
      bingVerificationCode: _string(json['bing_verification_code']),
      robotsTxt: _string(json['robots_txt']),
      headerCustomCodes: _string(json['header_custom_codes']),
      footerCustomCodes: _string(json['footer_custom_codes']),
    );
  }

  final String languageCode;
  final String siteName;
  final String timezone;
  final String footerAbout;
  final String optionalUrlButtonName;
  final String copyrightText;
  final String logoUrl;
  final String footerLogoUrl;
  final String darkLogoUrl;
  final String emailLogoUrl;
  final String faviconUrl;
  final String homeTitle;
  final String metaDescription;
  final String metaKeywords;
  final String canonicalUrl;
  final String ogImageUrl;
  final String organizationLegalName;
  final String organizationPhone;
  final String organizationAddress;
  final String twitterUsername;
  final String fbAppId;
  final String googleAnalyticsId;
  final String googleSearchConsoleCode;
  final String bingVerificationCode;
  final String robotsTxt;
  final String headerCustomCodes;
  final String footerCustomCodes;

  Map<String, Object?> toJson() {
    return {
      'language_code': languageCode,
      'site_name': siteName,
      'timezone': timezone,
      'footer_about': footerAbout,
      'optional_url_button_name': optionalUrlButtonName,
      'copyright_text': copyrightText,
      'logo_url': logoUrl,
      'footer_logo_url': footerLogoUrl,
      'dark_logo_url': darkLogoUrl,
      'email_logo_url': emailLogoUrl,
      'favicon_url': faviconUrl,
      'home_title': homeTitle,
      'meta_description': metaDescription,
      'meta_keywords': metaKeywords,
      'canonical_url': canonicalUrl,
      'og_image_url': ogImageUrl,
      'organization_legal_name': organizationLegalName,
      'organization_phone': organizationPhone,
      'organization_address': organizationAddress,
      'twitter_username': twitterUsername,
      'fb_app_id': fbAppId,
      'google_analytics_id': googleAnalyticsId,
      'google_search_console_code': googleSearchConsoleCode,
      'bing_verification_code': bingVerificationCode,
      'robots_txt': robotsTxt,
      'header_custom_codes': headerCustomCodes,
      'footer_custom_codes': footerCustomCodes,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  String logoFor(GeneralSettingsLogoField field) {
    return switch (field) {
      GeneralSettingsLogoField.logoUrl => logoUrl,
      GeneralSettingsLogoField.footerLogoUrl => footerLogoUrl,
      GeneralSettingsLogoField.darkLogoUrl => darkLogoUrl,
      GeneralSettingsLogoField.emailLogoUrl => emailLogoUrl,
      GeneralSettingsLogoField.faviconUrl => faviconUrl,
      GeneralSettingsLogoField.ogImageUrl => ogImageUrl,
    };
  }

  GeneralSettingsData copyWith({
    String? languageCode,
    String? siteName,
    String? timezone,
    String? footerAbout,
    String? optionalUrlButtonName,
    String? copyrightText,
    String? logoUrl,
    String? footerLogoUrl,
    String? darkLogoUrl,
    String? emailLogoUrl,
    String? faviconUrl,
    String? homeTitle,
    String? metaDescription,
    String? metaKeywords,
    String? canonicalUrl,
    String? ogImageUrl,
    String? organizationLegalName,
    String? organizationPhone,
    String? organizationAddress,
    String? twitterUsername,
    String? fbAppId,
    String? googleAnalyticsId,
    String? googleSearchConsoleCode,
    String? bingVerificationCode,
    String? robotsTxt,
    String? headerCustomCodes,
    String? footerCustomCodes,
  }) {
    return GeneralSettingsData(
      languageCode: languageCode ?? this.languageCode,
      siteName: siteName ?? this.siteName,
      timezone: timezone ?? this.timezone,
      footerAbout: footerAbout ?? this.footerAbout,
      optionalUrlButtonName:
          optionalUrlButtonName ?? this.optionalUrlButtonName,
      copyrightText: copyrightText ?? this.copyrightText,
      logoUrl: logoUrl ?? this.logoUrl,
      footerLogoUrl: footerLogoUrl ?? this.footerLogoUrl,
      darkLogoUrl: darkLogoUrl ?? this.darkLogoUrl,
      emailLogoUrl: emailLogoUrl ?? this.emailLogoUrl,
      faviconUrl: faviconUrl ?? this.faviconUrl,
      homeTitle: homeTitle ?? this.homeTitle,
      metaDescription: metaDescription ?? this.metaDescription,
      metaKeywords: metaKeywords ?? this.metaKeywords,
      canonicalUrl: canonicalUrl ?? this.canonicalUrl,
      ogImageUrl: ogImageUrl ?? this.ogImageUrl,
      organizationLegalName:
          organizationLegalName ?? this.organizationLegalName,
      organizationPhone: organizationPhone ?? this.organizationPhone,
      organizationAddress: organizationAddress ?? this.organizationAddress,
      twitterUsername: twitterUsername ?? this.twitterUsername,
      fbAppId: fbAppId ?? this.fbAppId,
      googleAnalyticsId: googleAnalyticsId ?? this.googleAnalyticsId,
      googleSearchConsoleCode:
          googleSearchConsoleCode ?? this.googleSearchConsoleCode,
      bingVerificationCode: bingVerificationCode ?? this.bingVerificationCode,
      robotsTxt: robotsTxt ?? this.robotsTxt,
      headerCustomCodes: headerCustomCodes ?? this.headerCustomCodes,
      footerCustomCodes: footerCustomCodes ?? this.footerCustomCodes,
    );
  }
}

abstract class AdminGeneralSettingsRepository {
  Future<GeneralSettingsData> fetchSettings(String languageCode);

  Future<GeneralSettingsData> saveSettings({
    required AdminSession session,
    required GeneralSettingsData settings,
  });

  Future<String> uploadLogo({
    required String languageCode,
    required GeneralSettingsLogoField field,
    required String fileName,
    required List<int> bytes,
  });

  String publicUrl(String value);
}

class SupabaseAdminGeneralSettingsRepository
    implements AdminGeneralSettingsRepository {
  const SupabaseAdminGeneralSettingsRepository({
    this.httpClient,
    this.apiBaseUrl,
  });

  static const _apiBaseUrl = String.fromEnvironment('PATEEZNEWS_API_BASE_URL');
  static const _requestTimeout = Duration(seconds: 18);

  final http.Client? httpClient;
  final String? apiBaseUrl;

  @override
  Future<GeneralSettingsData> fetchSettings(String languageCode) async {
    final normalizedCode = _cleanLanguageCode(languageCode);
    final result = await _postJson('/api/admin/query', {
      'table': 'site_settings',
      'method': 'select',
      'select': _settingsSelect,
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
    _throwIfApiError(result, fallbackMessage: 'Genel ayarlar alınamadı');
    final data = result['data'];
    if (data is! Map) return GeneralSettingsData.empty(normalizedCode);
    return GeneralSettingsData.fromJson(_asStringKeyMap(data), normalizedCode);
  }

  @override
  Future<GeneralSettingsData> saveSettings({
    required AdminSession session,
    required GeneralSettingsData settings,
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
    _throwIfApiError(result, fallbackMessage: 'Genel ayarlar kaydedilemedi');
    final data = result['data'];
    if (data is! Map) return normalizedSettings;
    return GeneralSettingsData.fromJson(
      _asStringKeyMap(data),
      normalizedSettings.languageCode,
    );
  }

  @override
  Future<String> uploadLogo({
    required String languageCode,
    required GeneralSettingsLogoField field,
    required String fileName,
    required List<int> bytes,
  }) async {
    final uploadUri = _uri('/api/storage/upload');
    final request = http.MultipartRequest('POST', uploadUri);
    if (!kIsWeb) {
      request.headers['Origin'] =
          '${uploadUri.scheme}://${uploadUri.authority}';
    }
    request.headers.addAll(await adminAuthHeaders());
    request.fields['type'] = 'logo';
    request.fields['lang'] = _cleanLanguageCode(languageCode);
    request.fields['customPath'] = _cleanLanguageCode(languageCode);
    request.fields['customFilename'] =
        '${field.uploadBaseName}-${DateTime.now().millisecondsSinceEpoch}';
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: fileName),
    );

    final uploadClient = httpClient ?? adminHttpClient;
    final streamedResponse = await uploadClient
        .send(request)
        .timeout(const Duration(seconds: 120));
    final response = await http.Response.fromStream(
      streamedResponse,
    ).timeout(_requestTimeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AdminGeneralSettingsException(
        response.body.isEmpty ? 'Logo yüklenemedi' : response.body,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const AdminGeneralSettingsException('Geçersiz yükleme yanıtı');
    }
    final src =
        decoded['publicSrc']?.toString() ?? decoded['src']?.toString() ?? '';
    if (src.isEmpty) {
      throw const AdminGeneralSettingsException('Logo URL alınamadı');
    }
    return src;
  }

  @override
  String publicUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    final parsed = Uri.tryParse(trimmed);
    if (parsed != null && parsed.hasScheme) return trimmed;
    return _uri(trimmed).toString();
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
      throw const AdminGeneralSettingsException('Geçersiz sunucu yanıtı');
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
        throw AdminGeneralSettingsException(message);
      }
    }
    throw AdminGeneralSettingsException(fallbackMessage);
  }
}

class AdminGeneralSettingsException implements Exception {
  const AdminGeneralSettingsException(this.message);

  final String message;

  @override
  String toString() => message;
}

const _settingsSelect =
    'language_code,site_name,timezone,footer_about,optional_url_button_name,'
    'copyright_text,logo_url,footer_logo_url,dark_logo_url,email_logo_url,'
    'favicon_url,home_title,meta_description,meta_keywords,canonical_url,'
    'og_image_url,organization_legal_name,organization_phone,'
    'organization_address,twitter_username,fb_app_id,google_analytics_id,'
    'google_search_console_code,bing_verification_code,robots_txt,'
    'header_custom_codes,footer_custom_codes';

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
