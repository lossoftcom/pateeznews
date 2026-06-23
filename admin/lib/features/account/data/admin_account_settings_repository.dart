import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pateeznews_admin/core/network/admin_api_headers.dart';
import 'package:pateeznews_admin/shared/constants/turkey_cities.dart';

import '../../auth/data/admin_auth_models.dart';

enum AccountProfileImageKind { avatar, cover }

class AdminAccountProfile {
  const AdminAccountProfile({
    required this.id,
    required this.fullName,
    required this.username,
    required this.email,
    required this.phone,
    required this.expertise,
    required this.foundationDate,
    required this.address,
    required this.city,
    required this.website,
    required this.aboutMe,
    required this.slug,
    required this.metaTitle,
    required this.metaKeywords,
    required this.metaDescription,
    required this.canonicalUrl,
    required this.avatarUrl,
    required this.coverUrl,
    required this.socialLinks,
    required this.rewardSystem,
    required this.showEmail,
    required this.rssFeeds,
    required this.supportsShowEmail,
    required this.supportsRssFeeds,
  });

  factory AdminAccountProfile.empty(AdminSession session) {
    return AdminAccountProfile(
      id: session.user.id,
      fullName: '',
      username: '',
      email: session.user.email ?? '',
      phone: '',
      expertise: '',
      foundationDate: '',
      address: '',
      city: defaultTurkeyCity,
      website: '',
      aboutMe: '',
      slug: '',
      metaTitle: '',
      metaKeywords: '',
      metaDescription: '',
      canonicalUrl: '',
      avatarUrl: '',
      coverUrl: '',
      socialLinks: const {},
      rewardSystem: false,
      showEmail: true,
      rssFeeds: true,
      supportsShowEmail: false,
      supportsRssFeeds: false,
    );
  }

  factory AdminAccountProfile.fromJson(
    Map<dynamic, dynamic> json, {
    required AdminSession session,
  }) {
    final item = _asStringKeyMap(json);
    final socialLinks = _stringMap(item['social_links']);
    return AdminAccountProfile(
      id: item['id']?.toString() ?? session.user.id,
      fullName: item['full_name']?.toString() ?? '',
      username: item['username']?.toString() ?? '',
      email: item['email']?.toString() ?? session.user.email ?? '',
      phone: item['phone']?.toString() ?? '',
      expertise: item['expertise']?.toString() ?? '',
      foundationDate: item['foundation_date']?.toString() ?? '',
      address: item['address']?.toString() ?? '',
      city: normalizeTurkeyCity(item['city']?.toString() ?? defaultTurkeyCity),
      website: item['website']?.toString() ?? '',
      aboutMe: item['about_me']?.toString() ?? '',
      slug: item['slug']?.toString() ?? '',
      metaTitle: item['meta_title']?.toString() ?? '',
      metaKeywords: item['meta_keywords']?.toString() ?? '',
      metaDescription: item['meta_description']?.toString() ?? '',
      canonicalUrl: item['canonical_url']?.toString() ?? '',
      avatarUrl: item['avatar_url']?.toString() ?? '',
      coverUrl: socialLinks['cover_url'] ?? '',
      socialLinks: socialLinks,
      rewardSystem: item['reward_system'] == true,
      showEmail: item.containsKey('show_email')
          ? item['show_email'] == true
          : true,
      rssFeeds: item.containsKey('rss_feeds')
          ? item['rss_feeds'] == true
          : true,
      supportsShowEmail: item.containsKey('show_email'),
      supportsRssFeeds: item.containsKey('rss_feeds'),
    );
  }

  final String id;
  final String fullName;
  final String username;
  final String email;
  final String phone;
  final String expertise;
  final String foundationDate;
  final String address;
  final String city;
  final String website;
  final String aboutMe;
  final String slug;
  final String metaTitle;
  final String metaKeywords;
  final String metaDescription;
  final String canonicalUrl;
  final String avatarUrl;
  final String coverUrl;
  final Map<String, String> socialLinks;
  final bool rewardSystem;
  final bool showEmail;
  final bool rssFeeds;
  final bool supportsShowEmail;
  final bool supportsRssFeeds;

  AdminAccountProfile copyWith({
    String? fullName,
    String? username,
    String? email,
    String? phone,
    String? expertise,
    String? foundationDate,
    String? address,
    String? city,
    String? website,
    String? aboutMe,
    String? slug,
    String? metaTitle,
    String? metaKeywords,
    String? metaDescription,
    String? canonicalUrl,
    String? avatarUrl,
    String? coverUrl,
    Map<String, String>? socialLinks,
    bool? rewardSystem,
    bool? showEmail,
    bool? rssFeeds,
  }) {
    return AdminAccountProfile(
      id: id,
      fullName: fullName ?? this.fullName,
      username: username ?? this.username,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      expertise: expertise ?? this.expertise,
      foundationDate: foundationDate ?? this.foundationDate,
      address: address ?? this.address,
      city: city ?? this.city,
      website: website ?? this.website,
      aboutMe: aboutMe ?? this.aboutMe,
      slug: slug ?? this.slug,
      metaTitle: metaTitle ?? this.metaTitle,
      metaKeywords: metaKeywords ?? this.metaKeywords,
      metaDescription: metaDescription ?? this.metaDescription,
      canonicalUrl: canonicalUrl ?? this.canonicalUrl,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      socialLinks: socialLinks ?? this.socialLinks,
      rewardSystem: rewardSystem ?? this.rewardSystem,
      showEmail: showEmail ?? this.showEmail,
      rssFeeds: rssFeeds ?? this.rssFeeds,
      supportsShowEmail: supportsShowEmail,
      supportsRssFeeds: supportsRssFeeds,
    );
  }

  Map<String, Object?> toProfileUpdateJson() {
    final nextSocialLinks = Map<String, String>.from(socialLinks);
    final normalizedCoverUrl = _storedProfileMediaUrl(coverUrl);
    if (normalizedCoverUrl.isEmpty) {
      nextSocialLinks.remove('cover_url');
    } else {
      nextSocialLinks['cover_url'] = normalizedCoverUrl;
    }

    final values = <String, Object?>{
      'full_name': fullName.trim(),
      'username': username.trim(),
      'email': email.trim(),
      'phone': phone.trim(),
      'expertise': expertise.trim(),
      'foundation_date': foundationDate.trim(),
      'address': address.trim(),
      'city': normalizeTurkeyCity(city),
      'website': website.trim(),
      'about_me': aboutMe.trim(),
      'slug': slug.trim(),
      'social_links': nextSocialLinks,
      'reward_system': rewardSystem,
      'meta_title': metaTitle.trim(),
      'meta_keywords': metaKeywords.trim(),
      'meta_description': metaDescription.trim(),
      'canonical_url': canonicalUrl.trim(),
      'avatar_url': _storedProfileMediaUrl(avatarUrl),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (supportsShowEmail) values['show_email'] = showEmail;
    if (supportsRssFeeds) values['rss_feeds'] = rssFeeds;
    return values;
  }
}

abstract class AdminAccountSettingsRepository {
  Future<AdminAccountProfile> fetchProfile(AdminSession session);

  Future<AdminAccountProfile> saveProfile({
    required AdminSession session,
    required AdminAccountProfile profile,
  });

  Future<String> uploadProfileImage({
    required AdminSession session,
    required AccountProfileImageKind kind,
    required String fileName,
    required List<int> bytes,
  });

  Future<void> updatePassword({
    required AdminSession session,
    required String currentPassword,
    required String newPassword,
  });

  Future<void> deleteAccount({
    required AdminSession session,
    required String currentPassword,
  });

  String publicUrl(String value);
}

class SupabaseAdminAccountSettingsRepository
    implements AdminAccountSettingsRepository {
  const SupabaseAdminAccountSettingsRepository({
    this.httpClient,
    this.apiBaseUrl,
  });

  static const _apiBaseUrl = String.fromEnvironment('PATEEZNEWS_API_BASE_URL');
  static const _requestTimeout = Duration(seconds: 8);

  final http.Client? httpClient;
  final String? apiBaseUrl;

  @override
  Future<AdminAccountProfile> fetchProfile(AdminSession session) async {
    await _ensureSchema(session);
    final result = await _postJson('/api/admin/query', {
      'table': 'profiles',
      'method': 'select',
      'select':
          'id,full_name,username,email,phone,expertise,foundation_date,address,city,website,about_me,slug,meta_title,meta_keywords,meta_description,canonical_url,avatar_url,social_links,reward_system,show_email,rss_feeds',
      'filters': [_idFilter(session.user.id)],
      'single': 'maybeSingle',
    });
    _throwIfApiError(result, fallbackMessage: 'Profil bilgileri alınamadı');
    final data = result['data'];
    if (data is Map) {
      return AdminAccountProfile.fromJson(data, session: session);
    }
    return AdminAccountProfile.empty(session);
  }

  @override
  Future<AdminAccountProfile> saveProfile({
    required AdminSession session,
    required AdminAccountProfile profile,
  }) async {
    final username = profile.username.trim();
    if (username.isNotEmpty) {
      final conflict = await _postJson('/api/admin/query', {
        'table': 'profiles',
        'method': 'select',
        'select': 'id',
        'filters': [
          {
            'type': 'comparison',
            'op': 'eq',
            'column': 'username',
            'value': username,
          },
          {
            'type': 'comparison',
            'op': 'neq',
            'column': 'id',
            'value': session.user.id,
          },
        ],
        'single': 'maybeSingle',
      });
      _throwIfApiError(
        conflict,
        fallbackMessage: 'Kullanıcı adı kontrol edilemedi',
      );
      if (conflict['data'] is Map) {
        throw const AdminAccountSettingsException('Username is already taken');
      }
    }

    final result = await _postJson('/api/admin/query', {
      'table': 'profiles',
      'method': 'update',
      'values': profile.toProfileUpdateJson(),
      'filters': [_idFilter(session.user.id)],
      'single': 'maybeSingle',
    });
    _throwIfApiError(result, fallbackMessage: 'Profil kaydedilemedi');
    final data = result['data'];
    if (data is Map) {
      return AdminAccountProfile.fromJson(data, session: session);
    }
    return profile.copyWith(
      avatarUrl: _storedProfileMediaUrl(profile.avatarUrl),
      coverUrl: _storedProfileMediaUrl(profile.coverUrl),
    );
  }

  @override
  Future<String> uploadProfileImage({
    required AdminSession session,
    required AccountProfileImageKind kind,
    required String fileName,
    required List<int> bytes,
  }) async {
    final uploadUri = _uri('/api/storage/upload');
    final request = http.MultipartRequest('POST', uploadUri);
    if (!kIsWeb) {
      request.headers['Origin'] =
          '${uploadUri.scheme}://${uploadUri.authority}';
    }
    request.headers.addAll(await adminAuthHeaders(token: session.accessToken));
    request.fields['type'] = 'profile';
    request.fields['customFilename'] = '${session.user.id}-${kind.name}';
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
      throw AdminAccountSettingsException(
        response.body.isEmpty ? 'Profil görseli yüklenemedi' : response.body,
      );
    }
    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    if (decoded is! Map) {
      throw const AdminAccountSettingsException('Geçersiz yükleme yanıtı');
    }
    final src = decoded['src']?.toString() ?? '';
    if (src.isEmpty) {
      throw const AdminAccountSettingsException('Profil görseli URL alınamadı');
    }
    return src;
  }

  @override
  Future<void> updatePassword({
    required AdminSession session,
    required String currentPassword,
    required String newPassword,
  }) async {
    final result = await _accountAction(session, 'update-password', {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
    _throwIfApiError(result, fallbackMessage: 'Şifre değiştirilemedi');
  }

  @override
  Future<void> deleteAccount({
    required AdminSession session,
    required String currentPassword,
  }) async {
    final result = await _accountAction(session, 'delete-self', {
      'currentPassword': currentPassword,
    });
    _throwIfApiError(result, fallbackMessage: 'Hesap silinemedi');
  }

  @override
  String publicUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('data:')) return trimmed;
    final parsed = Uri.tryParse(trimmed);
    if (parsed != null && parsed.hasScheme) return trimmed;
    if (trimmed.startsWith('/')) return _uri(trimmed).toString();
    if (trimmed.startsWith('api/storage/file/')) {
      return _uri('/$trimmed').toString();
    }
    if (trimmed.startsWith('profile/')) {
      return _uri('/api/storage/file/$trimmed').toString();
    }
    return _uri('/api/storage/file/profile/$trimmed').toString();
  }

  Future<void> _ensureSchema(AdminSession session) async {
    try {
      final result = await _accountAction(session, 'ensure-schema', const {});
      _throwIfApiError(result, fallbackMessage: 'Profil şeması hazırlanamadı');
    } catch (_) {
      // React admin also treats schema preparation as best effort for profile load.
    }
  }

  Future<Map<String, Object?>> _accountAction(
    AdminSession session,
    String action,
    Map<String, Object?> payload,
  ) {
    return _postJson('/api/app/account', {
      'action': action,
      'token': session.accessToken,
      ...payload,
    }, token: session.accessToken);
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
      throw const AdminAccountSettingsException('Geçersiz sunucu yanıtı');
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
      TargetPlatform.android => Uri.parse('https://pateez.com'),
      _ => Uri.parse('https://pateez.com'),
    };
  }

  Map<String, Object?> _idFilter(String id) {
    return {'type': 'comparison', 'op': 'eq', 'column': 'id', 'value': id};
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
        throw AdminAccountSettingsException(message);
      }
    }
    throw AdminAccountSettingsException(fallbackMessage);
  }
}

class AdminAccountSettingsException implements Exception {
  const AdminAccountSettingsException(this.message);

  final String message;

  @override
  String toString() => message;
}

String _storedProfileMediaUrl(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty ||
      trimmed.startsWith('/') ||
      trimmed.startsWith('http://') ||
      trimmed.startsWith('https://') ||
      trimmed.startsWith('data:')) {
    return trimmed;
  }
  if (trimmed.startsWith('api/storage/file/')) return '/$trimmed';
  if (trimmed.startsWith('profile/')) return '/api/storage/file/$trimmed';
  return '/api/storage/file/profile/$trimmed';
}

Map<String, String> _stringMap(Object? value) {
  if (value is! Map) return <String, String>{};
  return value.map(
    (key, nestedValue) =>
        MapEntry(key.toString(), nestedValue?.toString() ?? ''),
  );
}

Map<String, Object?> _asStringKeyMap(Map<dynamic, dynamic> value) {
  return value.map((key, nestedValue) => MapEntry(key.toString(), nestedValue));
}
