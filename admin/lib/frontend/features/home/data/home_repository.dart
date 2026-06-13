import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/network/frontend_http_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  static String _snapshotKey(String lang) => 'home_snapshot_$lang';

  Future<void> _saveSnapshot(String lang, String body) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_snapshotKey(lang), body);
    } catch (_) {
      // Snapshot yazılamasa da akış sürer.
    }
  }

  /// Son başarılı home yanıtını diskten döndürür. Açılışta anlık gösterim için.
  Future<HomeData?> loadCachedHome({String lang = 'tr'}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final body = prefs.getString(_snapshotKey(lang));
      if (body == null || body.isEmpty) return null;
      return compute(_parseHomeData, body);
    } catch (_) {
      return null;
    }
  }

  Future<HomeData> fetchHome({
    String lang = 'tr',
    String? token,
    int retries = 1,
  }) async {
    final uri = _uri('/api/app/home').replace(queryParameters: {'lang': lang});
    final client = httpClient ?? sharedFrontendClient;
    final authToken = token?.trim() ?? '';
    try {
      for (var attempt = 0; attempt <= retries; attempt++) {
        try {
          final response = await client
              .get(
                uri,
                headers: {
                  'Accept': 'application/json',
                  if (authToken.isNotEmpty)
                    'Authorization': 'Bearer $authToken',
                },
              )
              .timeout(_timeout);
          if (response.statusCode >= 200 && response.statusCode < 300) {
            final body = utf8.decode(response.bodyBytes);
            await _saveSnapshot(lang, body);
            return compute(_parseHomeData, body);
          }
        } catch (_) {
          // Bu deneme başarısız; aşağıda backoff sonrası tekrar denenir.
        }
        if (attempt < retries) {
          await Future<void>.delayed(
            Duration(milliseconds: 350 * (attempt + 1)),
          );
        }
      }
      // Tüm denemeler başarısız: son snapshot varsa onu döndür.
      return await loadCachedHome(lang: lang) ?? const HomeData.empty();
    } finally {
      // Shared frontend client is not closed.
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
      article: _mapFeaturedArticle(json),
    );
  }

  static NewsArticle? _mapFeaturedArticle(Map<dynamic, dynamic> json) {
    final article = json['article'];
    if (article is! Map) return null;
    return _mapArticle(article);
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
      categoryTrail: _strList(json['categoryTrail'] ?? json['categoryPath']),
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
      quizData: _parseQuizData(json['quizData']),
      vsData: _parseVsData(json['vsData']),
      quoteData: _parseQuoteData(json['quoteData']),
      detailItems: _parseDetailItems(json['detailItems']),
      tags: _parseTags(json['tags']),
      faqData: _parseFaqData(json['faqData']),
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

NewsQuizData? _parseQuizData(Object? value) {
  if (value is! Map) return null;
  final questions = _parseQuizQuestions(value['questions']);
  if (questions.isEmpty) return null;
  return NewsQuizData(
    quizType: _normalizedQuizType(value['quizType']),
    questions: questions,
    results: _parseQuizResults(value['results']),
    questionSorting: _normalizedQuizSorting(value['questionSorting']),
    allowMultiple: _bool(value['allowMultiple']),
    showResults: value['showResults'] != false,
    endDate: _str(value['endDate']),
  );
}

List<NewsQuizQuestion> _parseQuizQuestions(Object? value) {
  if (value is! List) return const [];
  final questions = <NewsQuizQuestion>[];
  for (var index = 0; index < value.length; index++) {
    final item = value[index];
    if (item is! Map) continue;
    final answers = _parseQuizAnswers(item['answers'], index);
    final title = _plainText(item['title']);
    if (title.isEmpty || answers.isEmpty) continue;
    questions.add(
      NewsQuizQuestion(
        id: _str(item['id'], fallback: 'quiz-question-${index + 1}'),
        title: title,
        imageUrl: _str(item['imageUrl'] ?? item['image']),
        description: _plainText(item['description']),
        layout: _normalizedQuizLayout(item['layout']),
        answers: answers,
      ),
    );
  }
  return questions;
}

List<NewsQuizAnswer> _parseQuizAnswers(Object? value, int questionIndex) {
  if (value is! List) return const [];
  final answers = <NewsQuizAnswer>[];
  for (var index = 0; index < value.length; index++) {
    final item = value[index];
    if (item is! Map) continue;
    final text = _plainText(item['text']);
    if (text.isEmpty) continue;
    answers.add(
      NewsQuizAnswer(
        id: _str(
          item['id'],
          fallback: 'quiz-answer-${questionIndex + 1}-${index + 1}',
        ),
        text: text,
        imageUrl: _str(item['imageUrl'] ?? item['image']),
        resultId: _str(item['resultId']),
        isCorrect: _bool(item['isCorrect']),
        explanation: _plainText(item['explanation']),
      ),
    );
  }
  return answers;
}

List<NewsQuizResult> _parseQuizResults(Object? value) {
  if (value is! List) return const [];
  final results = <NewsQuizResult>[];
  for (var index = 0; index < value.length; index++) {
    final item = value[index];
    if (item is! Map) continue;
    final title = _plainText(item['title']);
    final imageUrl = _str(item['imageUrl'] ?? item['image']);
    final description = _plainText(item['description']);
    if (title.isEmpty && imageUrl.isEmpty && description.isEmpty) continue;
    results.add(
      NewsQuizResult(
        id: _str(item['id'], fallback: 'quiz-result-${index + 1}'),
        title: title,
        imageUrl: imageUrl,
        description: description,
        minScore: _optionalNonNegativeInt(item['minScore']),
        maxScore: _optionalNonNegativeInt(item['maxScore']),
        answerCount: _optionalNonNegativeInt(item['answerCount']),
      ),
    );
  }
  return results;
}

NewsTocData? _parseTocData(Object? value) {
  if (value is! Map) return null;
  final items = _parseTocItems(value['items']);
  if (items.isEmpty) return null;
  final styles = _asMap(value['linkListStyle']);
  final show = _asMap(value['showInText']);
  return NewsTocData(
    title: _plainText(value['title']),
    level1Style: _normalizedTocStyle(styles['level1']),
    level2Style: _normalizedTocStyle(styles['level2']),
    level3Style: _normalizedTocStyle(styles['level3']),
    showLevel1InText: _bool(show['level1']),
    showLevel2InText: _bool(show['level2']),
    showLevel3InText: _bool(show['level3']),
    items: items,
  );
}

List<NewsTocItem> _parseTocItems(Object? value) {
  if (value is! List) return const [];
  final items = <NewsTocItem>[];
  for (var index = 0; index < value.length; index++) {
    final item = value[index];
    if (item is! Map) continue;
    final title = _plainText(item['title']);
    final imageUrl = _str(
      item['imageUrl'] ?? item['image'] ?? item['mediaUrl'],
    );
    final content = _plainText(
      item['content'] ?? item['description'] ?? item['body'],
    );
    if (title.isEmpty && imageUrl.isEmpty && content.isEmpty) continue;
    final orderNumber = _nonNegativeInt(item['orderNumber']);
    items.add(
      NewsTocItem(
        id: _str(item['id'], fallback: 'toc-item-${index + 1}'),
        title: title,
        parentId: _str(item['parentId'] ?? item['parent']),
        imageUrl: imageUrl,
        imageDescription: _plainText(
          item['imageDescription'] ?? item['altText'] ?? item['caption'],
        ),
        content: content,
        orderNumber: orderNumber > 0 ? orderNumber : index + 1,
      ),
    );
  }
  return items;
}

NewsRecipeData? _parseRecipeData(Object? value) {
  if (value is! Map) return null;
  final ingredients = _parseRecipeIngredients(value['ingredients']);
  final nutrition = _parseRecipeNutrition(value['nutrition']);
  final directions = _parseRecipeDirections(value['directions']);
  final data = NewsRecipeData(
    prepTime: _plainText(value['prepTime']),
    cookTime: _plainText(value['cookTime']),
    serving: _plainText(value['serving']),
    difficulty: _normalizedRecipeDifficulty(value['difficulty']),
    ingredients: ingredients,
    nutrition: nutrition,
    directions: directions,
  );
  return data.isValid ? data : null;
}

List<NewsRecipeIngredient> _parseRecipeIngredients(Object? value) {
  if (value is! List) return const [];
  final ingredients = <NewsRecipeIngredient>[];
  for (final item in value) {
    if (item is! Map) continue;
    final text = _plainText(item['text']);
    if (text.isEmpty) continue;
    ingredients.add(NewsRecipeIngredient(text: text));
  }
  return ingredients;
}

List<NewsRecipeNutrition> _parseRecipeNutrition(Object? value) {
  if (value is! List) return const [];
  final nutrition = <NewsRecipeNutrition>[];
  for (final item in value) {
    if (item is! Map) continue;
    final label = _plainText(item['label']);
    final rowValue = _plainText(item['value']);
    if (label.isEmpty && rowValue.isEmpty) continue;
    nutrition.add(NewsRecipeNutrition(label: label, value: rowValue));
  }
  return nutrition;
}

List<NewsRecipeDirection> _parseRecipeDirections(Object? value) {
  if (value is! List) return const [];
  final directions = <NewsRecipeDirection>[];
  for (var index = 0; index < value.length; index += 1) {
    final item = value[index];
    if (item is! Map) continue;
    final title = _plainText(item['title']);
    final content = _plainText(item['content'] ?? item['description']);
    final imageUrl = _str(
      item['imageUrl'] ?? item['image'] ?? item['mediaUrl'],
    );
    if (title.isEmpty && content.isEmpty && imageUrl.isEmpty) continue;
    final orderNumber = _nonNegativeInt(item['orderNumber']);
    directions.add(
      NewsRecipeDirection(
        id: _str(item['id'], fallback: 'recipe-step-${index + 1}'),
        title: title,
        content: content,
        imageUrl: imageUrl,
        imageDescription: _plainText(
          item['imageDescription'] ?? item['altText'] ?? item['caption'],
        ),
        orderNumber: orderNumber > 0 ? orderNumber : index + 1,
      ),
    );
  }
  return directions;
}

String _normalizedRecipeDifficulty(Object? value) {
  return switch (_str(value).toLowerCase()) {
    'easy' || 'kolay' => 'easy',
    'medium' || 'intermediate' || 'orta' => 'medium',
    'hard' || 'advanced' || 'zor' => 'hard',
    _ => '',
  };
}

NewsEventData? _parseEventData(Object? value) {
  if (value is! Map) return null;
  final schedule = _parseEventSchedule(value['schedule']);
  final highlights = _parseEventHighlights(value['highlights']);
  final speakers = _parseEventSpeakers(value['speakers']);
  final data = NewsEventData(
    startDateTime: _plainText(value['startDateTime']),
    endDateTime: _plainText(value['endDateTime']),
    organizer: _plainText(value['organizer']),
    venueName: _plainText(value['venueName']),
    address: _plainText(value['address']),
    latitude: _plainText(value['latitude']),
    longitude: _plainText(value['longitude']),
    registrationType: _normalizedEventRegistrationType(
      value['registrationType'],
    ),
    ticketUrl: _str(value['ticketUrl']),
    ticketPrice: _plainText(value['ticketPrice']),
    capacity: _plainText(value['capacity']),
    scheduleTitle: _plainText(value['scheduleTitle']),
    highlightsTitle: _plainText(value['highlightsTitle']),
    speakersTitle: _plainText(value['speakersTitle']),
    schedule: schedule,
    highlights: highlights,
    speakers: speakers,
  );
  return data.isValid ? data : null;
}

List<NewsEventScheduleItem> _parseEventSchedule(Object? value) {
  if (value is! List) return const [];
  final items = <NewsEventScheduleItem>[];
  for (var index = 0; index < value.length; index += 1) {
    final item = value[index];
    if (item is! Map) continue;
    final title = _plainText(item['title']);
    final description = _plainText(item['description'] ?? item['content']);
    final imageUrl = _str(
      item['imageUrl'] ?? item['image'] ?? item['mediaUrl'],
    );
    final date = _plainText(item['date']);
    final time = _plainText(item['time']);
    if (title.isEmpty &&
        description.isEmpty &&
        imageUrl.isEmpty &&
        date.isEmpty &&
        time.isEmpty) {
      continue;
    }
    final orderNumber = _nonNegativeInt(item['orderNumber']);
    items.add(
      NewsEventScheduleItem(
        id: _str(item['id'], fallback: 'event-schedule-${index + 1}'),
        date: date,
        time: time,
        title: title,
        description: description,
        imageUrl: imageUrl,
        imageDescription: _plainText(
          item['imageDescription'] ?? item['altText'] ?? item['caption'],
        ),
        orderNumber: orderNumber > 0 ? orderNumber : index + 1,
      ),
    );
  }
  return items;
}

List<NewsEventHighlight> _parseEventHighlights(Object? value) {
  if (value is! List) return const [];
  final highlights = <NewsEventHighlight>[];
  for (final item in value) {
    if (item is! Map) continue;
    final label = _plainText(item['label']);
    final rowValue = _plainText(item['value']);
    if (label.isEmpty && rowValue.isEmpty) continue;
    highlights.add(NewsEventHighlight(label: label, value: rowValue));
  }
  return highlights;
}

List<NewsEventSpeaker> _parseEventSpeakers(Object? value) {
  if (value is! List) return const [];
  final speakers = <NewsEventSpeaker>[];
  for (var index = 0; index < value.length; index += 1) {
    final item = value[index];
    if (item is! Map) continue;
    final name = _plainText(item['name']);
    final role = _plainText(item['role']);
    final bio = _plainText(item['bio']);
    final imageUrl = _str(
      item['imageUrl'] ?? item['image'] ?? item['mediaUrl'],
    );
    if (name.isEmpty && role.isEmpty && bio.isEmpty && imageUrl.isEmpty) {
      continue;
    }
    speakers.add(
      NewsEventSpeaker(
        id: _str(item['id'], fallback: 'event-speaker-${index + 1}'),
        name: name,
        role: role,
        bio: bio,
        imageUrl: imageUrl,
        imageDescription: _plainText(
          item['imageDescription'] ?? item['altText'] ?? item['caption'],
        ),
      ),
    );
  }
  return speakers;
}

String _normalizedEventRegistrationType(Object? value) {
  return switch (_str(value).toLowerCase()) {
    'required' => 'required',
    'tickets' => 'tickets',
    'external' => 'external',
    _ => 'none',
  };
}

String _normalizedTocStyle(Object? value) {
  return switch (_str(value).toLowerCase()) {
    'decimal' => 'decimal',
    'decimal-leading-zero' => 'decimal-leading-zero',
    'circle' => 'circle',
    'disc' => 'disc',
    'square' => 'square',
    'lower-alpha' => 'lower-alpha',
    'upper-alpha' => 'upper-alpha',
    'lower-roman' => 'lower-roman',
    'upper-roman' => 'upper-roman',
    _ => 'none',
  };
}

String _normalizedQuizType(Object? value) {
  return switch (_str(value).toLowerCase()) {
    'trivia' => 'trivia',
    'checklist' => 'checklist',
    _ => 'personality',
  };
}

String _normalizedQuizSorting(Object? value) {
  return switch (_str(value).toLowerCase()) {
    'desc' => 'desc',
    'hide' || 'hidden' => 'hidden',
    _ => 'asc',
  };
}

String _normalizedQuizLayout(Object? value) {
  return switch (_str(value).toLowerCase()) {
    'grid2' => 'grid2',
    'grid3' => 'grid3',
    _ => 'list',
  };
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

List<NewsDetailItem> _parseDetailItems(Object? value) {
  if (value is! List) return const [];
  final items = <NewsDetailItem>[];
  for (var index = 0; index < value.length; index++) {
    final raw = value[index];
    if (raw is! Map) continue;
    final type = _str(raw['type']).toLowerCase();
    if (type.isEmpty) continue;
    final id = _str(raw['id'], fallback: 'detail-item-${index + 1}');
    final detailItem = NewsDetailItem(
      id: id,
      type: type,
      title: _plainText(raw['title']),
      description: _plainText(raw['description']),
      source: _plainText(raw['source']),
      moreInfoUrl: _str(raw['moreInfoUrl']),
      mediaUrl: _str(raw['mediaUrl']),
      mediaUrls: _strList(raw['mediaUrls']),
      altText: _plainText(raw['altText']),
      videoThumbUrl: _str(raw['videoThumbUrl']),
      flipData: _parseFlipData(raw['flipData']),
      beforeAfterData: _parseBeforeAfterData(raw['beforeAfterData']),
      reviewData: _parseReviewData(raw['reviewData']),
      pollData: _parsePollData(raw['pollData']),
      quizData: _parseQuizData(raw['quizData']),
      tocData: _parseTocData(raw['tocData']),
      recipeData: _parseRecipeData(raw['recipeData']),
      eventData: _parseEventData(raw['eventData']),
      vsData: _parseVsData(raw['vsData']),
      quoteData: _parseQuoteData(raw['quoteData']),
    );
    if (_detailItemHasContent(detailItem)) items.add(detailItem);
  }
  return items;
}

bool _detailItemHasContent(NewsDetailItem item) {
  return item.title.isNotEmpty ||
      item.description.isNotEmpty ||
      item.source.isNotEmpty ||
      item.mediaUrl.isNotEmpty ||
      item.mediaUrls.isNotEmpty ||
      item.flipData != null ||
      item.beforeAfterData != null ||
      item.reviewData != null ||
      item.pollData != null ||
      item.quizData != null ||
      item.tocData != null ||
      item.recipeData != null ||
      item.eventData != null ||
      item.vsData != null ||
      item.quoteData != null;
}

List<String> _parseTags(Object? value) {
  final source = value is List ? value : const [];
  final tags = <String>[];
  final seen = <String>{};
  for (final item in source) {
    final tag = _plainText(item).replaceFirst(RegExp(r'^#+'), '').trim();
    if (tag.isEmpty) continue;
    final key = tag.toLowerCase();
    if (seen.contains(key)) continue;
    seen.add(key);
    tags.add(tag);
    if (tags.length >= 14) break;
  }
  return tags;
}

List<NewsFaqItem> _parseFaqData(Object? value) {
  if (value is! List) return const [];
  final items = <NewsFaqItem>[];
  for (final item in value) {
    if (item is! Map) continue;
    final question = _plainText(item['q'] ?? item['question'] ?? item['name']);
    final answer = _plainText(item['a'] ?? item['answer'] ?? item['text']);
    if (question.isEmpty || answer.isEmpty) continue;
    items.add(NewsFaqItem(question: question, answer: answer));
    if (items.length >= 8) break;
  }
  return items;
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

int? _optionalNonNegativeInt(Object? value) {
  if (value == null) return null;
  final parsed = value is num ? value.toInt() : int.tryParse(value.toString());
  if (parsed == null) return null;
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
