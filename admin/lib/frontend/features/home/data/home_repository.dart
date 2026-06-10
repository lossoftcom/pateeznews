import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/mock/home_mock_data.dart';
import '../../../core/network/local_api_base_url.dart';

@immutable
class HomeContentSettings {
  const HomeContentSettings({
    this.showFeaturedSection = true,
    this.commentSystem = true,
    this.commentApprovalSystem = true,
    this.emojiReactions = true,
    this.homePageSize = 16,
    this.featuredContentSource = 'manual',
    this.featuredSortingLogic = 'slider_order',
    this.featuredDurationDays = 10,
    this.featuredLimit = 15,
  });

  const HomeContentSettings.defaults() : this();

  final bool showFeaturedSection;
  final bool commentSystem;
  final bool commentApprovalSystem;
  final bool emojiReactions;
  final int homePageSize;
  final String featuredContentSource;
  final String featuredSortingLogic;
  final int featuredDurationDays;
  final int featuredLimit;

  factory HomeContentSettings.fromJson(Object? value) {
    if (value is! Map) return const HomeContentSettings.defaults();
    return HomeContentSettings(
      showFeaturedSection: _boolSetting(value['showFeaturedSection']),
      commentSystem: _boolSetting(value['commentSystem']),
      commentApprovalSystem: _boolSetting(value['commentApprovalSystem']),
      emojiReactions: _boolSetting(value['emojiReactions']),
      homePageSize: _pageSize(value['homePageSize']),
      featuredContentSource: _str(
        value['featuredContentSource'],
        fallback: 'manual',
      ),
      featuredSortingLogic: _str(
        value['featuredSortingLogic'],
        fallback: 'slider_order',
      ),
      featuredDurationDays: _boundedInt(
        value['featuredDurationDays'],
        fallback: 10,
        min: 1,
        max: 365,
      ),
      featuredLimit: _boundedInt(
        value['featuredLimit'],
        fallback: 15,
        min: 1,
        max: 50,
      ),
    );
  }
}

@immutable
class HomeData {
  const HomeData({
    this.featured = const [],
    this.feed = const [],
    this.settings = const HomeContentSettings.defaults(),
  });

  const HomeData.empty() : this();

  final List<FeaturedNews> featured;
  final List<NewsArticle> feed;
  final HomeContentSettings settings;
}

class HomeRepository {
  const HomeRepository({this.httpClient, this.apiBaseUrl});

  static const _apiBaseUrl = String.fromEnvironment('PATEEZNEWS_API_BASE_URL');
  static const _timeout = Duration(seconds: 10);

  final http.Client? httpClient;
  final String? apiBaseUrl;

  Future<HomeData> fetchHome({String lang = 'tr', String? token}) async {
    final uri = _uri('/api/app/home').replace(queryParameters: {'lang': lang});
    final client = httpClient ?? http.Client();
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

  static NewsArticle mapArticle(Map<dynamic, dynamic> json) {
    return _mapArticle(json);
  }

  Uri _uri(String path) =>
      frontendApiUri(path, configuredBaseUrl: apiBaseUrl ?? _apiBaseUrl);

  static FeaturedNews _mapFeatured(Map<dynamic, dynamic> json) {
    return FeaturedNews(
      id: _str(json['id']),
      category: _str(json['category']),
      title: _str(json['title']),
      summary: _plainText(json['summary']),
      imageUrl: _str(json['imageUrl']),
      publishedAt: _parseDate(json['publishedAt']),
      source: _str(json['source'], fallback: 'Pateeznews'),
      slug: _str(json['slug']),
      imageAspectRatio: _positiveDouble(json['imageAspectRatio']),
    );
  }

  static NewsArticle _mapArticle(Map<dynamic, dynamic> json) {
    final source = _str(json['source'], fallback: 'Pateeznews');
    final videoUrl = _str(json['videoUrl']);
    return NewsArticle(
      id: _str(json['id']),
      author: NewsAuthor(
        id: _str(json['publisherId']),
        name: source,
        avatarUrl: _str(json['sourceAvatar']),
        handle: _nullableStr(json['publisherHandle']),
        isVerified: _bool(json['isVerified']),
        isOfficial: _bool(json['isOfficial']),
      ),
      region: _str(json['region']),
      category: _str(json['category']),
      title: _str(json['title']),
      summary: _plainText(json['summary']),
      imageUrl: _str(json['imageUrl']),
      publishedAt: _parseDate(json['publishedAt']),
      readMinutes: _nonNegativeInt(json['readMinutes']),
      likes: _nonNegativeInt(json['likes']),
      dislikes: _nonNegativeInt(json['dislikes']),
      comments: _nonNegativeInt(json['comments']),
      shares: _nonNegativeInt(json['shares']),
      views: _nonNegativeInt(json['views']),
      saves: _nonNegativeInt(json['saves']),
      userLiked: _bool(json['userLiked']),
      userDisliked: _bool(json['userDisliked']),
      userSaved: _bool(json['userSaved']),
      slug: _str(json['slug']),
      imageAspectRatio: _positiveDouble(json['imageAspectRatio']),
      isManset: _bool(json['isManset']),
      isPinned: _bool(json['isPinned']),
      sliderImages: _strList(json['sliderImages']),
      videoUrl: videoUrl,
      videoUrls: _strList(json['videoUrls']),
      videoThumbUrls: _strListPreservePositions(json['videoThumbUrls']),
      audioUrl: _str(json['audioUrl']),
      socialEmbed: _str(json['socialEmbed']),
      socialSourceUrl: _str(json['socialSourceUrl']),
      socialPlatform: _str(json['socialPlatform']),
      flipData: _parseFlipData(json['flipData']),
      beforeAfterData: _parseBeforeAfterData(json['beforeAfterData']),
      reviewData: _parseReviewData(json['reviewData']),
      pollData: _parsePollData(json['pollData']),
      vsData: _parseVsData(json['vsData']),
      quoteData: _parseQuoteData(json['quoteData']),
      previewComments: _parseComments(json['previewComments']),
    );
  }
}

HomeData _parseHomeData(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! Map) return const HomeData.empty();
  return HomeData(
    featured: _mapItems(decoded['featured'], HomeRepository._mapFeatured),
    feed: _mapItems(decoded['feed'], HomeRepository._mapArticle),
    settings: HomeContentSettings.fromJson(decoded['settings']),
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

String? _nullableStr(Object? value) {
  final result = _str(value);
  return result.isEmpty ? null : result;
}

Map<dynamic, dynamic> _asMap(Object? value) {
  return value is Map ? value : const {};
}

/// HTML içerikli özetleri ("<p>...</p>" gibi) düz metne indirger: etiketleri
/// ayıklar, yaygın HTML varlıklarını çözer, boşlukları sadeleştirir. İçinde
/// "<" veya "&" yoksa metni olduğu gibi döndürür (gereksiz işlem yapılmaz).
String _plainText(Object? value) {
  final raw = _str(value);
  if (!raw.contains('<') && !raw.contains('&')) return raw;
  final text = raw
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'");
  return text.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Flip kart verisini ayrıştırır. Ön/arka görsel yoksa null döner (kart normal
/// medya akışına düşer). Başlık ve açıklamalar HTML'den arındırılır.
NewsFlipData? _parseFlipData(Object? value) {
  if (value is! Map) return null;
  final frontImage = _str(value['frontImage']);
  final backImage = _str(value['backImage']);
  if (frontImage.isEmpty || backImage.isEmpty) return null;
  return NewsFlipData(
    frontImage: frontImage,
    frontTitle: _plainText(value['frontTitle']),
    backImage: backImage,
    backTitle: _plainText(value['backTitle']),
    frontDescription: _plainText(value['frontDescription']),
    backDescription: _plainText(value['backDescription']),
    frontLink: _str(value['frontLink']),
    backLink: _str(value['backLink']),
  );
}

/// Önce & Sonra verisini ayrıştırır. Görsellerden biri yoksa null döner (kart
/// normal medya akışına düşer). Etiketler HTML'den arındırılır.
NewsBeforeAfterData? _parseBeforeAfterData(Object? value) {
  if (value is! Map) return null;
  final beforeImage = _str(value['beforeImage']);
  final afterImage = _str(value['afterImage']);
  if (beforeImage.isEmpty || afterImage.isEmpty) return null;
  return NewsBeforeAfterData(
    beforeImage: beforeImage,
    afterImage: afterImage,
    beforeLabel: _plainText(value['beforeLabel']),
    afterLabel: _plainText(value['afterLabel']),
  );
}

NewsReviewData? _parseReviewData(Object? value) {
  if (value is! Map) return null;
  final pros = _plainTextList(value['pros']);
  final cons = _plainTextList(value['cons']);
  final breakdown = _parseReviewBreakdown(value['breakdown']);
  final productName = _plainText(value['productName']);
  final productImage = _str(value['productImage']);
  final verdict = _plainText(value['verdict']);
  if (productName.isEmpty &&
      productImage.isEmpty &&
      pros.isEmpty &&
      cons.isEmpty &&
      breakdown.isEmpty &&
      verdict.isEmpty) {
    return null;
  }
  return NewsReviewData(
    productName: productName,
    productImage: productImage,
    score: _score(value['score']),
    pros: pros,
    cons: cons,
    breakdown: breakdown,
    verdict: verdict,
  );
}

NewsPollData? _parsePollData(Object? value) {
  if (value is! Map) return null;
  final options = _parsePollOptions(value['options']);
  final title = _plainText(value['title']);
  if (title.isEmpty || options.length < 2) return null;
  final columns = _pollColumns(value['columns'], _bool(value['isImagePoll']));
  return NewsPollData(
    title: title,
    description: _plainText(value['description']),
    options: options,
    isImagePoll: _bool(value['isImagePoll']),
    columns: columns,
    totalVotes: _nonNegativeInt(value['totalVotes']),
  );
}

List<NewsPollOption> _parsePollOptions(Object? value) {
  if (value is! List) return const [];
  final options = <NewsPollOption>[];
  for (var index = 0; index < value.length; index++) {
    final item = value[index];
    if (item is! Map) continue;
    final text = _plainText(item['text']);
    if (text.isEmpty) continue;
    final id = _str(item['id'], fallback: 'poll-option-${index + 1}');
    options.add(
      NewsPollOption(
        id: id,
        text: text,
        imageUrl: _str(item['imageUrl']),
        votes: _nonNegativeInt(item['votes']),
      ),
    );
  }
  return options;
}

NewsVsData? _parseVsData(Object? value) {
  if (value is! Map) return null;
  final options = _parseVsOptions(value['options']);
  final title = _plainText(value['title']);
  if (title.isEmpty || options.length < 2) return null;
  return NewsVsData(
    title: title,
    description: _plainText(value['description']),
    options: options,
    totalVotes: _nonNegativeInt(value['totalVotes']),
  );
}

List<NewsVsOption> _parseVsOptions(Object? value) {
  if (value is! List) return const [];
  final options = <NewsVsOption>[];
  for (var index = 0; index < value.length && index < 2; index++) {
    final item = value[index];
    if (item is! Map) continue;
    final text = _plainText(item['text']);
    if (text.isEmpty) continue;
    final id = _str(item['id'], fallback: 'vs-option-${index + 1}');
    options.add(
      NewsVsOption(
        id: id,
        text: text,
        imageUrl: _str(item['imageUrl']),
        votes: _nonNegativeInt(item['votes']),
      ),
    );
  }
  return options;
}

NewsQuoteData? _parseQuoteData(Object? value) {
  if (value is! Map) return null;
  final text = _plainText(value['text']);
  if (text.isEmpty) return null;
  return NewsQuoteData(
    text: text,
    author: _plainText(value['author']),
    sourceUrl: _str(value['sourceUrl']),
  );
}

List<NewsComment> _parseComments(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is Map) _parseComment(item),
  ];
}

NewsComment _parseComment(Map<dynamic, dynamic> json) {
  final author = _asMap(json['author']);
  return NewsComment(
    id: _str(json['id']),
    parentId: _str(json['parentId']),
    author: NewsAuthor(
      id: _str(author['id']),
      name: _str(author['name'], fallback: 'Misafir'),
      avatarUrl: _str(author['avatarUrl']),
      handle: _nullableStr(author['handle']),
      isVerified: _bool(author['isVerified']),
      isOfficial: _bool(author['isOfficial']),
    ),
    body: _plainText(json['body']),
    publishedAt: _parseDate(json['publishedAt']),
    likes: _nonNegativeInt(json['likes']),
    userLiked: _bool(json['userLiked']),
    canDelete: _bool(json['canDelete']),
    replies: _parseComments(json['replies']),
  );
}

int _pollColumns(Object? value, bool isImagePoll) {
  final parsed = _nonNegativeInt(value);
  if (!isImagePoll) return 1;
  if (parsed == 3) return 3;
  return 2;
}

List<NewsReviewCriterion> _parseReviewBreakdown(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is Map && _plainText(item['label']).isNotEmpty)
        NewsReviewCriterion(
          label: _plainText(item['label']),
          score: _score(item['score']),
        ),
  ];
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

int _pageSize(Object? value) {
  final parsed = value is num
      ? value.toInt()
      : int.tryParse(value?.toString() ?? '') ?? 16;
  return parsed.clamp(1, 50).toInt();
}

int _boundedInt(
  Object? value, {
  required int fallback,
  required int min,
  required int max,
}) {
  final parsed = value is num
      ? value.toInt()
      : int.tryParse(value?.toString() ?? '') ?? fallback;
  return parsed.clamp(min, max).toInt();
}

int _score(Object? value) {
  final parsed = _nonNegativeInt(value);
  return parsed > 100 ? 100 : parsed;
}

bool _bool(Object? value) {
  if (value is bool) return value;
  final normalized = value?.toString().trim().toLowerCase();
  return normalized == 'true' || normalized == '1';
}

bool _boolSetting(Object? value) {
  if (value == null) return true;
  if (value is bool) return value;
  final normalized = value.toString().trim().toLowerCase();
  if (normalized == 'false' || normalized == '0' || normalized == 'no') {
    return false;
  }
  return true;
}

List<String> _strList(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item != null && item.toString().trim().isNotEmpty)
        item.toString().trim(),
  ];
}

List<String> _strListPreservePositions(Object? value) {
  if (value is! List) return const [];
  return [for (final item in value) item?.toString().trim() ?? ''];
}

List<String> _plainTextList(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (_plainText(item).isNotEmpty) _plainText(item),
  ];
}
