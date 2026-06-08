import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/mock/home_mock_data.dart';
import '../../../core/network/local_api_base_url.dart';

class HomeRepository {
  const HomeRepository({this.httpClient, this.apiBaseUrl});

  static const _apiBaseUrl = String.fromEnvironment('PATEEZNEWS_API_BASE_URL');
  static const _timeout = Duration(seconds: 10);

  final http.Client? httpClient;
  final String? apiBaseUrl;

  Future<List<FeaturedNews>> fetchFeatured({String lang = 'tr'}) async {
    final uri = _uri('/api/app/home').replace(
      queryParameters: {'lang': lang, 'limit': '10'},
    );
    final client = httpClient ?? http.Client();
    try {
      final response = await client
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(_timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const [];
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map) return const [];
      final rawList = decoded['featured'];
      if (rawList is! List || rawList.isEmpty) return const [];
      return [
        for (final item in rawList)
          if (item is Map) _mapFeatured(item),
      ];
    } catch (_) {
      return const [];
    } finally {
      if (httpClient == null) client.close();
    }
  }

  Uri _uri(String path) =>
      frontendApiUri(path, configuredBaseUrl: apiBaseUrl ?? _apiBaseUrl);

  static FeaturedNews _mapFeatured(Map<dynamic, dynamic> json) {
    return FeaturedNews(
      id: _str(json['id']),
      category: _str(json['category']),
      title: _str(json['title']),
      summary: _str(json['summary']),
      imageUrl: _str(json['imageUrl']),
      publishedAt: _parseDate(json['publishedAt']),
      source: _str(json['source'], fallback: 'Pateeznews'),
      slug: _str(json['slug']),
    );
  }
}

String _str(Object? value, {String fallback = ''}) {
  final result = (value ?? '').toString().trim();
  return result.isEmpty ? fallback : result;
}

DateTime _parseDate(Object? value) {
  if (value == null) return DateTime.now();
  try {
    return DateTime.parse(value.toString()).toLocal();
  } catch (_) {
    return DateTime.now();
  }
}
