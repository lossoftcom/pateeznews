import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/mock/home_mock_data.dart';
import '../../../core/network/local_api_base_url.dart';

@immutable
class HomeData {
  const HomeData({this.featured = const [], this.feed = const []});

  const HomeData.empty() : this();

  final List<FeaturedNews> featured;
  final List<NewsArticle> feed;
}

class HomeRepository {
  const HomeRepository({this.httpClient, this.apiBaseUrl});

  static const _apiBaseUrl = String.fromEnvironment('PATEEZNEWS_API_BASE_URL');
  static const _timeout = Duration(seconds: 10);

  final http.Client? httpClient;
  final String? apiBaseUrl;

  Future<HomeData> fetchHome({String lang = 'tr'}) async {
    final uri = _uri('/api/app/home').replace(
      queryParameters: {'lang': lang, 'limit': '10', 'feedLimit': '30'},
    );
    final client = httpClient ?? http.Client();
    try {
      final response = await client
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(_timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const HomeData.empty();
      }
      return compute(_parseHomeData, utf8.decode(response.bodyBytes));
    } catch (_) {
      return const HomeData.empty();
    } finally {
      if (httpClient == null) client.close();
    }
  }

  Future<List<FeaturedNews>> fetchFeatured({String lang = 'tr'}) async {
    final data = await fetchHome(lang: lang);
    return data.featured;
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
      imageAspectRatio: _positiveDouble(json['imageAspectRatio']),
    );
  }

  static NewsArticle _mapArticle(Map<dynamic, dynamic> json) {
    final source = _str(json['source'], fallback: 'Pateeznews');
    return NewsArticle(
      id: _str(json['id']),
      author: NewsAuthor(
        name: source,
        avatarUrl: _str(json['sourceAvatar']),
        isVerified: _bool(json['isVerified']),
        isOfficial: _bool(json['isOfficial']),
      ),
      region: _str(json['region']),
      category: _str(json['category']),
      title: _str(json['title']),
      summary: _str(json['summary']),
      imageUrl: _str(json['imageUrl']),
      publishedAt: _parseDate(json['publishedAt']),
      readMinutes: _nonNegativeInt(json['readMinutes']),
      likes: _nonNegativeInt(json['likes']),
      dislikes: _nonNegativeInt(json['dislikes']),
      comments: _nonNegativeInt(json['comments']),
      shares: _nonNegativeInt(json['shares']),
      views: _nonNegativeInt(json['views']),
      saves: _nonNegativeInt(json['saves']),
      slug: _str(json['slug']),
      imageAspectRatio: _positiveDouble(json['imageAspectRatio']),
      isManset: _bool(json['isManset']),
      isPinned: _bool(json['isPinned']),
      sliderImages: _strList(json['sliderImages']),
      videoUrl: _str(json['videoUrl']),
      audioUrl: _str(json['audioUrl']),
    );
  }
}

HomeData _parseHomeData(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! Map) return const HomeData.empty();
  return HomeData(
    featured: _mapItems(decoded['featured'], HomeRepository._mapFeatured),
    feed: _mapItems(decoded['feed'], HomeRepository._mapArticle),
  );
}

List<T> _mapItems<T>(Object? raw, T Function(Map<dynamic, dynamic>) mapper) {
  if (raw is! List || raw.isEmpty) return const [];
  return [
    for (final item in raw)
      if (item is Map) mapper(item),
  ];
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

double? _positiveDouble(Object? value) {
  final result = double.tryParse(value?.toString() ?? '');
  if (result == null || !result.isFinite || result <= 0) return null;
  return result;
}

int _nonNegativeInt(Object? value) {
  final parsed = value is num
      ? value.toInt()
      : int.tryParse(value?.toString() ?? '') ?? 0;
  return parsed < 0 ? 0 : parsed;
}

bool _bool(Object? value) {
  if (value is bool) return value;
  final normalized = value?.toString().trim().toLowerCase();
  return normalized == 'true' || normalized == '1';
}

List<String> _strList(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item != null && item.toString().trim().isNotEmpty) item.toString().trim(),
  ];
}
