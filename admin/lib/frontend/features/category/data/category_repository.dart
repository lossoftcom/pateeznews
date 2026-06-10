import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/mock/home_mock_data.dart';
import '../../../core/network/local_api_base_url.dart';
import '../../home/data/home_repository.dart';

class CategoryNewsData {
  const CategoryNewsData({
    this.items = const [],
    this.total = 0,
    this.totalViews = 0,
    this.nextOffset = 0,
    this.hasMore = false,
  });

  const CategoryNewsData.empty() : this();

  final List<NewsArticle> items;
  final int total;
  final int totalViews;
  final int nextOffset;
  final bool hasMore;

  factory CategoryNewsData.fromJson(Map<dynamic, dynamic> json) {
    final rawItems = json['items'];
    return CategoryNewsData(
      items: rawItems is List
          ? [
              for (final item in rawItems)
                if (item is Map) HomeRepository.mapArticle(item),
            ]
          : const [],
      total: _nonNegativeInt(json['total']),
      totalViews: _nonNegativeInt(json['totalViews']),
      nextOffset: _nonNegativeInt(json['nextOffset']),
      hasMore: json['hasMore'] == true,
    );
  }
}

class CategoryRepository {
  const CategoryRepository({this.httpClient, this.apiBaseUrl});

  static const _apiBaseUrl = String.fromEnvironment('PATEEZNEWS_API_BASE_URL');
  static const _timeout = Duration(seconds: 10);

  final http.Client? httpClient;
  final String? apiBaseUrl;

  Future<CategoryNewsData> fetchCategory({
    required String category,
    String type = 'category',
    String value = '',
    String lang = 'tr',
    int limit = 16,
    int offset = 0,
    String? token,
  }) async {
    final cleanCategory = category.trim();
    if (cleanCategory.isEmpty) return const CategoryNewsData.empty();
    final authToken = token?.trim() ?? '';
    final uri = _uri('/api/app/category-news').replace(
      queryParameters: {
        'lang': lang,
        'category': cleanCategory,
        'type': type.trim(),
        'value': value.trim(),
        'limit': limit.clamp(1, 50).toString(),
        'offset': offset < 0 ? '0' : offset.toString(),
      },
    );
    final client = httpClient ?? http.Client();
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
        return const CategoryNewsData.empty();
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map) return const CategoryNewsData.empty();
      return CategoryNewsData.fromJson(decoded);
    } catch (_) {
      return const CategoryNewsData.empty();
    } finally {
      if (httpClient == null) client.close();
    }
  }

  Uri _uri(String path) =>
      frontendApiUri(path, configuredBaseUrl: apiBaseUrl ?? _apiBaseUrl);
}

int _nonNegativeInt(Object? value) {
  final parsed = value is num
      ? value.toInt()
      : int.tryParse(value?.toString() ?? '') ?? 0;
  return parsed < 0 ? 0 : parsed;
}
