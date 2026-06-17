import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/network/frontend_http_client.dart';

import '../../../core/mock/home_mock_data.dart';
import '../../../core/network/local_api_base_url.dart';
import '../../home/data/home_repository.dart';

@immutable
class SearchData {
  const SearchData({this.posts = const [], this.profiles = const []});

  const SearchData.empty() : this();

  final List<NewsArticle> posts;
  final List<SearchProfile> profiles;
}

@immutable
class SearchProfile {
  const SearchProfile({
    required this.id,
    required this.username,
    required this.fullName,
    required this.avatarUrl,
    required this.role,
    required this.expertise,
  });

  final String id;
  final String username;
  final String fullName;
  final String avatarUrl;
  final String role;
  final String expertise;

  String get displayName {
    final cleanName = fullName.trim();
    if (cleanName.isNotEmpty) return cleanName;
    final cleanUsername = username.trim();
    return cleanUsername.isEmpty ? 'Pateez' : cleanUsername;
  }

  String get handle {
    final cleanUsername = username.trim();
    if (cleanUsername.isEmpty) return '';
    return cleanUsername.startsWith('@') ? cleanUsername : '@$cleanUsername';
  }
}

class SearchRepository {
  const SearchRepository({this.httpClient, this.apiBaseUrl});

  static const _apiBaseUrl = String.fromEnvironment('PATEEZNEWS_API_BASE_URL');
  static const _timeout = Duration(seconds: 8);

  final http.Client? httpClient;
  final String? apiBaseUrl;

  Future<SearchData> search({
    required String query,
    String lang = 'tr',
    String? token,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.length < 2) return const SearchData.empty();
    final uri = _uri('/api/app/search').replace(
      queryParameters: {
        'q': cleanQuery,
        'lang': lang,
        'limit': '14',
        'profilesLimit': '8',
      },
    );
    final client = httpClient ?? sharedFrontendClient;
    final authToken = token?.trim() ?? '';
    try {
      final response = await client
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              if (authToken.isNotEmpty) 'Authorization': 'Bearer $authToken',
            },
          )
          .timeout(_timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const SearchData.empty();
      }
      return compute(_parseSearchData, utf8.decode(response.bodyBytes));
    } catch (_) {
      return const SearchData.empty();
    } finally {
      // Shared frontend client is not closed.
    }
  }

  Uri _uri(String path) =>
      frontendApiUri(path, configuredBaseUrl: apiBaseUrl ?? _apiBaseUrl);
}

SearchData _parseSearchData(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! Map) return const SearchData.empty();
  return SearchData(
    posts: _mapList(decoded['posts'], HomeRepository.mapArticle),
    profiles: _mapList(decoded['profiles'], _mapProfile),
  );
}

List<T> _mapList<T>(Object? raw, T Function(Map<dynamic, dynamic>) mapper) {
  if (raw is! List || raw.isEmpty) return const [];
  return [
    for (final item in raw)
      if (item is Map) mapper(item),
  ];
}

SearchProfile _mapProfile(Map<dynamic, dynamic> json) {
  return SearchProfile(
    id: _str(json['id']),
    username: _str(json['username']),
    fullName: _str(json['full_name']),
    avatarUrl: _str(json['avatar_url']),
    role: _str(json['role']),
    expertise: _str(json['expertise']),
  );
}

String _str(Object? value) => (value ?? '').toString().trim();
