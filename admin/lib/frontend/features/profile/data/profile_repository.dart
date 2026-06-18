import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart' show Color, IconData;
import 'package:http/http.dart' as http;
import '../../../core/network/frontend_http_client.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../core/mock/home_mock_data.dart';
import '../../../core/network/local_api_base_url.dart';
import '../../account/data/frontend_auth_repository.dart';
import '../../home/data/home_repository.dart';
import 'profile_content.dart';

class ProfileException implements Exception {
  const ProfileException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ProfileSaveResult {
  const ProfileSaveResult({required this.profile, required this.authProfile});

  final ProfileData profile;
  final FrontendProfile authProfile;
}

class ProfileUploadResult {
  const ProfileUploadResult({
    required this.publicSrc,
    required this.displayUrl,
    required this.id,
  });

  final String publicSrc;
  final String displayUrl;
  final String id;
}

class ProfileUpdateInput {
  const ProfileUpdateInput({
    required this.fullName,
    required this.username,
    required this.email,
    required this.expertise,
    required this.aboutMe,
    required this.website,
    required this.address,
    required this.city,
    required this.instagram,
    required this.x,
    required this.facebook,
    required this.youtube,
    required this.whatsapp,
    required this.linkedin,
    required this.tiktok,
    required this.pinterest,
    required this.snapchat,
    required this.telegram,
    required this.discord,
    required this.reddit,
    required this.bluesky,
    required this.twitch,
    required this.showEmail,
    required this.rssFeeds,
    required this.avatarPath,
    required this.coverPath,
  });

  final String fullName;
  final String username;
  final String email;
  final String expertise;
  final String aboutMe;
  final String website;
  final String address;
  final String city;
  final String instagram;
  final String x;
  final String facebook;
  final String youtube;
  final String whatsapp;
  final String linkedin;
  final String tiktok;
  final String pinterest;
  final String snapchat;
  final String telegram;
  final String discord;
  final String reddit;
  final String bluesky;
  final String twitch;
  final bool showEmail;
  final bool rssFeeds;
  final String avatarPath;
  final String coverPath;

  Map<String, Object?> toJson() {
    return {
      'action': 'update-profile',
      'fullName': fullName.trim(),
      'username': username.trim().replaceFirst(RegExp(r'^@+'), ''),
      'email': email.trim().toLowerCase(),
      'expertise': expertise.trim(),
      'aboutMe': aboutMe.trim(),
      'website': website.trim(),
      'address': address.trim(),
      'city': city.trim(),
      'showEmail': showEmail,
      'rssFeeds': rssFeeds,
      'avatarUrl': avatarPath.trim(),
      'coverUrl': coverPath.trim(),
      'socialLinks': {
        'instagram': instagram.trim(),
        'x': x.trim(),
        'facebook': facebook.trim(),
        'youtube': youtube.trim(),
        'whatsapp': whatsapp.trim(),
        'linkedin': linkedin.trim(),
        'tiktok': tiktok.trim(),
        'pinterest': pinterest.trim(),
        'snapchat': snapchat.trim(),
        'telegram': telegram.trim(),
        'discord': discord.trim(),
        'reddit': reddit.trim(),
        'bluesky': bluesky.trim(),
        'twitch': twitch.trim(),
      },
    };
  }
}

class ProfileRepository {
  const ProfileRepository({this.httpClient, this.apiBaseUrl});

  static const _apiBaseUrl = String.fromEnvironment('PATEEZNEWS_API_BASE_URL');
  static const _timeout = Duration(seconds: 12);
  static const _uploadTimeout = Duration(seconds: 120);

  final http.Client? httpClient;
  final String? apiBaseUrl;

  Future<ProfileSaveResult> fetchSelf({
    required String token,
    String languageCode = 'tr',
  }) {
    return fetchProfile(token: token, languageCode: languageCode);
  }

  Future<ProfileSaveResult> fetchProfile({
    String token = '',
    String userId = '',
    String username = '',
    String languageCode = 'tr',
  }) async {
    final query = <String, String>{'lang': languageCode};
    final cleanUserId = userId.trim();
    final cleanUsername = username.trim().replaceFirst(RegExp(r'^@+'), '');
    if (cleanUserId.isNotEmpty) query['userId'] = cleanUserId;
    if (cleanUsername.isNotEmpty) query['username'] = cleanUsername;
    final uri = _uri('/api/app/profile').replace(queryParameters: query);
    final client = httpClient ?? sharedFrontendClient;
    late final http.Response response;
    try {
      response = await client
          .get(uri, headers: _authHeaders(token))
          .timeout(_timeout);
    } finally {
      // Shared frontend client is not closed.
    }
    return _parseProfileResult(response);
  }

  Future<bool> toggleFollow({
    required String token,
    required String profileId,
  }) async {
    final client = httpClient ?? sharedFrontendClient;
    late final http.Response response;
    try {
      response = await client
          .post(
            _uri('/api/app/post-action'),
            headers: _jsonAuthHeaders(token),
            body: jsonEncode({
              'action': 'toggle_follow',
              'publisherId': profileId.trim(),
            }),
          )
          .timeout(_timeout);
    } finally {
      // Shared frontend client is not closed.
    }
    final decoded = _decodeMap(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwApiError(decoded, fallback: 'Takip durumu güncellenemedi');
    }
    _throwIfApiError(decoded, fallback: 'Takip durumu güncellenemedi');
    return _bool(decoded['following'], fallback: false);
  }

  Future<ProfileSaveResult> updateProfile({
    required String token,
    required ProfileUpdateInput input,
  }) async {
    final client = httpClient ?? sharedFrontendClient;
    late final http.Response response;
    try {
      response = await client
          .post(
            _uri('/api/app/profile'),
            headers: _jsonAuthHeaders(token),
            body: jsonEncode(input.toJson()),
          )
          .timeout(_timeout);
    } finally {
      // Shared frontend client is not closed.
    }
    return _parseProfileResult(response);
  }

  Future<void> updatePassword({
    required String token,
    required String currentPassword,
    required String newPassword,
  }) async {
    final client = httpClient ?? sharedFrontendClient;
    late final http.Response response;
    try {
      response = await client
          .post(
            _uri('/api/app/account'),
            headers: _jsonAuthHeaders(token),
            body: jsonEncode({
              'action': 'update-password',
              'currentPassword': currentPassword,
              'newPassword': newPassword,
            }),
          )
          .timeout(_timeout);
    } finally {
      // Shared frontend client is not closed.
    }
    final decoded = _decodeMap(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwApiError(decoded, fallback: 'Şifre güncellenemedi');
    }
    _throwIfApiError(decoded, fallback: 'Şifre güncellenemedi');
  }

  Future<ProfileUploadResult> uploadProfileImage({
    required String token,
    required String kind,
    required String fileName,
    required List<int> bytes,
  }) async {
    final uri = _uri('/api/app/profile-upload');
    final request = http.MultipartRequest('POST', uri);
    if (!kIsWeb) {
      request.headers['Origin'] = '${uri.scheme}://${uri.authority}';
    }
    request
      ..headers.addAll(_authHeaders(token))
      ..fields['kind'] = kind
      ..fields['languageCode'] = 'tr'
      ..files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: fileName),
      );

    final client = httpClient ?? sharedFrontendClient;
    // Shared frontend client is not closed.
    try {
      final streamed = await client.send(request).timeout(_uploadTimeout);
      final response = await http.Response.fromStream(
        streamed,
      ).timeout(_timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _throwApiError(_decodeMap(response), fallback: 'Görsel yüklenemedi');
      }
      final decoded = _decodeMap(response);
      final publicSrc = _str(decoded['publicSrc']);
      if (publicSrc.isEmpty) {
        throw const ProfileException('Görsel yolu alınamadı');
      }
      return ProfileUploadResult(
        publicSrc: publicSrc,
        displayUrl: _resolveProfileUrl(publicSrc),
        id: _str(decoded['id']),
      );
    } finally {
      // Shared frontend client is not closed.
    }
  }

  ProfileSaveResult _parseProfileResult(http.Response response) {
    final decoded = _decodeMap(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwApiError(decoded, fallback: 'Profil isteği başarısız');
    }
    final rawProfile = _map(decoded['profile']);
    if (rawProfile.isEmpty) {
      throw const ProfileException('Profil verisi alınamadı');
    }
    final profile = _profileData(rawProfile);
    final authProfile = FrontendProfile.fromJson(
      rawProfile,
      _resolveProfileUrl,
    );
    return ProfileSaveResult(profile: profile, authProfile: authProfile);
  }

  ProfileData _profileData(Map<String, Object?> json) {
    final role = _str(json['role']).toLowerCase();
    final expertise = _str(json['expertise']);
    final social = _map(json['social_links']);
    final stats = _map(json['stats']);
    final avatarPath = _str(json['avatar_url']);
    final coverPath = _str(json['cover_url']);
    final posts = _posts(json['posts']);
    final followerProfiles = _profilePreviews(json['follower_profiles']);
    final followingProfiles = _profilePreviews(json['following_profiles']);
    return ProfileData(
      id: _str(json['id']),
      name: _firstNonEmpty([
        json['full_name'],
        json['username'],
        json['email'],
      ]),
      handle: _handle(_str(json['username'])),
      roleLabel: expertise.isNotEmpty ? expertise : _roleLabel(role),
      expertise: expertise,
      aboutMe: _str(json['about_me']),
      email: _str(json['email']),
      showEmail: _bool(json['show_email'], fallback: true),
      avatarUrl: _resolveProfileUrl(avatarPath),
      avatarPath: avatarPath,
      coverUrl: _resolveProfileUrl(coverPath),
      coverPath: coverPath,
      joinedLabel: _joinedLabel(json['created_at']),
      joinedYear: _joinedYear(json['created_at']),
      isVerified: _isOfficialRole(role),
      isOnline: true,
      isOwnProfile: _bool(json['is_own_profile'], fallback: true),
      isFollowing: _bool(json['viewer_following'], fallback: false),
      website: _str(json['website']),
      address: _str(json['address']),
      city: _str(json['city']).isEmpty ? 'Niğde' : _str(json['city']),
      rssFeeds: _bool(json['rss_feeds'], fallback: true),
      postsCount: _int(stats['posts']),
      followers: _int(stats['followers']),
      following: _int(stats['following']),
      likedPostsCount: _int(stats['liked_posts']),
      commentsCount: _int(stats['comments']),
      socialLinks: _socialLinks(social, _str(json['website'])),
      followerAvatars: followerProfiles.isNotEmpty
          ? followerProfiles.map((item) => item.avatarUrl).toList()
          : _resolvedList(json['follower_avatars']),
      followingAvatars: followingProfiles.isNotEmpty
          ? followingProfiles.map((item) => item.avatarUrl).toList()
          : _resolvedList(json['following_avatars']),
      followerProfiles: followerProfiles,
      followingProfiles: followingProfiles,
      posts: posts,
    );
  }

  List<ProfilePreview> _profilePreviews(Object? value) {
    if (value is! List) return const [];
    return [
      for (final item in value)
        if (item is Map) _profilePreview(_map(item)),
    ];
  }

  ProfilePreview _profilePreview(Map<String, Object?> json) {
    final role = _str(json['role']).toLowerCase();
    final username = _str(json['username']);
    return ProfilePreview(
      id: _str(json['id']),
      name: _firstNonEmpty([json['full_name'], username, json['email']]),
      handle: _handle(username),
      avatarUrl: _resolveProfileUrl(_str(json['avatar_url'])),
      isVerified: _isOfficialRole(role),
      isOfficial: _isOfficialRole(role),
    );
  }

  List<NewsArticle> _posts(Object? value) {
    if (value is! List) return const [];
    return [
      for (final item in value)
        if (item is Map) HomeRepository.mapArticle(item),
    ];
  }

  List<ProfileSocialLink> _socialLinks(
    Map<String, Object?> social,
    String website,
  ) {
    final items = <ProfileSocialLink>[];
    void add(String key, String label, IconData icon, Color color) {
      final url = key == 'website' ? website : _str(social[key]);
      if (url.isEmpty) return;
      items.add(
        ProfileSocialLink(
          key: key,
          label: label,
          url: url,
          icon: icon,
          color: color,
        ),
      );
    }

    add('x', 'X', Symbols.twitter_x_fill, const Color(0xFF000000));
    add(
      'instagram',
      'Instagram',
      Symbols.instagram_fill,
      const Color(0xFFE4405F),
    );
    add('facebook', 'Facebook', Symbols.facebook_fill, const Color(0xFF1877F2));
    add('youtube', 'YouTube', Symbols.youtube_fill, const Color(0xFFFF0000));
    add('whatsapp', 'WhatsApp', Symbols.whatsapp_fill, const Color(0xFF25D366));
    add('linkedin', 'LinkedIn', Symbols.linkedin_fill, const Color(0xFF0A66C2));
    add('tiktok', 'TikTok', Symbols.tiktok_fill, const Color(0xFF000000));
    add(
      'pinterest',
      'Pinterest',
      Symbols.pinterest_fill,
      const Color(0xFFE60023),
    );
    add('snapchat', 'Snapchat', Symbols.snapchat_fill, const Color(0xFFFFFC00));
    add('telegram', 'Telegram', Symbols.telegram_fill, const Color(0xFF26A5E4));
    add('discord', 'Discord', Symbols.discord_fill, const Color(0xFF5865F2));
    add('reddit', 'Reddit', Symbols.reddit_fill, const Color(0xFFFF4500));
    add('bluesky', 'Bluesky', Symbols.bluesky_fill, const Color(0xFF1185FE));
    add('twitch', 'Twitch', Symbols.twitch_fill, const Color(0xFF9146FF));
    add(
      'website',
      'Web sitesi',
      Symbols.public_rounded,
      const Color(0xFF607D8B),
    );
    return items;
  }

  Uri _uri(String path) {
    return frontendApiUri(path, configuredBaseUrl: apiBaseUrl ?? _apiBaseUrl);
  }

  Map<String, String> _authHeaders(String token) {
    final cleanToken = token.trim();
    return {
      'Accept': 'application/json',
      if (cleanToken.isNotEmpty) 'Authorization': 'Bearer $cleanToken',
    };
  }

  Map<String, String> _jsonAuthHeaders(String token) {
    return {
      ..._authHeaders(token),
      'Content-Type': 'application/json; charset=UTF-8',
    };
  }

  String _resolveProfileUrl(String value) {
    final input = value.trim();
    if (input.isEmpty) return '';
    final uri = Uri.tryParse(input);
    if (uri != null && (uri.hasScheme || input.startsWith('data:'))) {
      return input;
    }
    if (input.startsWith('/')) return _uri(input).toString();
    if (input.startsWith('profile/')) {
      return _uri('/api/storage/file/$input').toString();
    }
    return _uri('/api/storage/file/profile/$input').toString();
  }

  List<String> _resolvedList(Object? value) {
    if (value is! List) return const [];
    return [
      for (final item in value)
        if (_str(item).isNotEmpty) _resolveProfileUrl(_str(item)),
    ];
  }

  Map<String, Object?> _decodeMap(http.Response response) {
    if (response.bodyBytes.isEmpty) return const {};
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    return _map(decoded);
  }

  void _throwIfApiError(
    Map<String, Object?> decoded, {
    required String fallback,
  }) {
    if (decoded['error'] == null) return;
    _throwApiError(decoded, fallback: fallback);
  }

  void _throwApiError(
    Map<String, Object?> decoded, {
    required String fallback,
  }) {
    final error = decoded['error'];
    if (error is Map) {
      final message = _str(error['message']);
      if (message.isNotEmpty) throw ProfileException(message);
    }
    throw ProfileException(fallback);
  }
}

Map<String, Object?> _map(Object? value) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) {
    return value.map((key, nested) => MapEntry(key.toString(), nested));
  }
  return const {};
}

String _str(Object? value) => (value ?? '').toString().trim();

String _firstNonEmpty(List<Object?> values) {
  for (final value in values) {
    final text = _str(value);
    if (text.isNotEmpty) return text;
  }
  return 'Pateez';
}

String _handle(String username) {
  if (username.isEmpty) return '';
  return username.startsWith('@') ? username : '@$username';
}

bool _bool(Object? value, {required bool fallback}) {
  if (value is bool) return value;
  final text = _str(value).toLowerCase();
  if (text == 'true' || text == '1') return true;
  if (text == 'false' || text == '0') return false;
  return fallback;
}

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(_str(value)) ?? 0;
}

bool _isOfficialRole(String role) {
  return role == 'admin' || role == 'super_admin' || role == 'editor';
}

String _roleLabel(String role) {
  return switch (role) {
    'admin' || 'super_admin' => 'Yönetici',
    'editor' => 'Editör',
    'publisher' => 'Yayıncı',
    _ => 'Üye',
  };
}

DateTime? _date(Object? value) {
  try {
    return DateTime.parse(_str(value)).toLocal();
  } catch (_) {
    return null;
  }
}

String _joinedLabel(Object? value) {
  final date = _date(value);
  if (date == null) return '';
  const months = [
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];
  return '${months[date.month - 1]} ${date.year}';
}

String _joinedYear(Object? value) {
  final date = _date(value);
  return date?.year.toString() ?? '';
}
