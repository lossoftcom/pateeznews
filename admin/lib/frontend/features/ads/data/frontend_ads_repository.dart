import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/network/frontend_http_client.dart';
import '../../../core/network/local_api_base_url.dart';

class FrontendAdSettings {
  const FrontendAdSettings({
    required this.masterEnabled,
    required this.adsenseConnected,
    required this.adsensePublisherId,
    required this.localEnabled,
    required this.slots,
  });

  const FrontendAdSettings.empty()
    : masterEnabled = false,
      adsenseConnected = false,
      adsensePublisherId = '',
      localEnabled = false,
      slots = const [];

  factory FrontendAdSettings.fromJson(
    Map<dynamic, dynamic> json,
    String Function(String) resolveUrl,
  ) {
    final rawSlots = json['slots'];
    return FrontendAdSettings(
      masterEnabled: json['masterEnabled'] != false,
      adsenseConnected: json['adsenseConnected'] == true,
      adsensePublisherId: _str(json['adsensePublisherId']),
      localEnabled: json['localEnabled'] != false,
      slots: rawSlots is List
          ? rawSlots
                .whereType<Map>()
                .map((slot) => FrontendAdSlotData.fromJson(slot, resolveUrl))
                .where((slot) => slot.key.isNotEmpty)
                .toList(growable: false)
          : const [],
    );
  }

  final bool masterEnabled;
  final bool adsenseConnected;
  final String adsensePublisherId;
  final bool localEnabled;
  final List<FrontendAdSlotData> slots;

  FrontendAdSlotData? slotByKey(String key) {
    final cleanKey = key.trim();
    if (cleanKey.isEmpty || !masterEnabled) return null;
    final exactSlot = _findSlotByKey(cleanKey);
    final fallbackKey = _slotFallbackKeys[cleanKey];
    final fallbackSlot = fallbackKey == null
        ? null
        : _findSlotByKey(fallbackKey);
    if (exactSlot != null) {
      return exactSlot.withFallbackImagesFrom(fallbackSlot);
    }
    if (fallbackSlot != null) return fallbackSlot;
    return null;
  }

  FrontendAdSlotData? _findSlotByKey(String key) {
    for (final slot in slots) {
      if (slot.key == key) return slot;
    }
    return null;
  }
}

const _slotFallbackKeys = <String, String>{
  'mobile_home_top': 'web_home_top',
  'mobile_home_after_hero': 'web_home_top',
  'mobile_home_after_market': 'web_home_section_break',
  'mobile_feed_inline': 'web_home_feed_inline',
  'mobile_feed_rectangle': 'web_home_feed_inline',
  'mobile_detail_incontent': 'web_news_incontent',
  'mobile_detail_between_articles': 'web_article_related_before',
  'mobile_video_feed_inline': 'web_video_feed_inline',
  'mobile_video_feed_rectangle': 'web_video_feed_inline',
  'mobile_category_after_masthead': 'web_category_feed_inline',
  'mobile_category_feed_inline': 'web_category_feed_inline',
  'mobile_detail_after_media': 'web_article_after_media',
  'mobile_detail_midcontent': 'web_article_midcontent',
  'mobile_detail_end': 'web_article_end',
  'mobile_search_results_inline': 'web_search_results_inline',
  'mobile_profile_feed_inline': 'web_profile_sidebar',
};

class FrontendAdSlotData {
  const FrontendAdSlotData({
    required this.id,
    required this.key,
    required this.width,
    required this.height,
    required this.responsive,
    required this.creatives,
  });

  factory FrontendAdSlotData.fromJson(
    Map<dynamic, dynamic> json,
    String Function(String) resolveUrl,
  ) {
    final rawCreatives = json['creatives'];
    return FrontendAdSlotData(
      id: _str(json['id']),
      key: _str(json['key']),
      width: _int(json['width']),
      height: _int(json['height']),
      responsive: json['responsive'] == true,
      creatives: rawCreatives is List
          ? rawCreatives
                .whereType<Map>()
                .map(
                  (creative) =>
                      FrontendAdCreative.fromJson(creative, resolveUrl),
                )
                .where((creative) => creative.isRenderable)
                .toList(growable: false)
          : const [],
    );
  }

  final String id;
  final String key;
  final int width;
  final int height;
  final bool responsive;
  final List<FrontendAdCreative> creatives;

  FrontendAdSlotData withFallbackImagesFrom(FrontendAdSlotData? fallback) {
    if (fallback == null || creatives.any((creative) => creative.isImage)) {
      return this;
    }
    final fallbackImages = fallback.creatives
        .where((creative) => creative.isImage)
        .toList(growable: false);
    if (fallbackImages.isEmpty) return this;
    return FrontendAdSlotData(
      id: id,
      key: key,
      width: width > 0 ? width : fallback.width,
      height: height > 0 ? height : fallback.height,
      responsive: responsive,
      creatives: [...creatives, ...fallbackImages],
    );
  }
}

class FrontendAdCreative {
  const FrontendAdCreative({
    required this.id,
    required this.name,
    required this.type,
    required this.width,
    required this.height,
    required this.responsive,
    required this.imageUrl,
    required this.linkUrl,
    required this.htmlCode,
    required this.adsenseSlotId,
    required this.publisherId,
    required this.weight,
  });

  factory FrontendAdCreative.fromJson(
    Map<dynamic, dynamic> json,
    String Function(String) resolveUrl,
  ) {
    final type = _str(json['type']);
    return FrontendAdCreative(
      id: _str(json['id']),
      name: _str(json['name'], fallback: 'Reklam'),
      type: type.isEmpty ? 'image' : type,
      width: _int(json['width']),
      height: _int(json['height']),
      responsive: json['responsive'] == true,
      imageUrl: resolveUrl(_str(json['imageUrl'])),
      linkUrl: resolveUrl(_str(json['linkUrl'])),
      htmlCode: _str(json['htmlCode']),
      adsenseSlotId: _str(json['adsenseSlotId']),
      publisherId: _str(json['publisherId']),
      weight: _int(json['weight'], fallback: 1).clamp(1, 100).toInt(),
    );
  }

  final String id;
  final String name;
  final String type;
  final int width;
  final int height;
  final bool responsive;
  final String imageUrl;
  final String linkUrl;
  final String htmlCode;
  final String adsenseSlotId;
  final String publisherId;
  final int weight;

  bool get isImage => type == 'image' && imageUrl.isNotEmpty;
  bool get isHtml => type == 'html' && htmlCode.isNotEmpty;
  bool get isAdsense =>
      type == 'adsense' && publisherId.isNotEmpty && adsenseSlotId.isNotEmpty;
  bool get isRenderable => isImage || isHtml || isAdsense;
}

class FrontendAdsRepository {
  const FrontendAdsRepository({this.httpClient, this.apiBaseUrl});

  static const _apiBaseUrl = String.fromEnvironment('PATEEZNEWS_API_BASE_URL');
  static const _timeout = Duration(seconds: 8);
  static const _cacheTtl = Duration(seconds: 30);

  static FrontendAdSettings? _cache;
  static DateTime? _cacheExpiresAt;
  static Future<FrontendAdSettings>? _inFlight;

  final http.Client? httpClient;
  final String? apiBaseUrl;

  Future<FrontendAdSettings> fetchMobileAds() {
    final now = DateTime.now();
    final cached = _cache;
    final expiresAt = _cacheExpiresAt;
    if (cached != null && expiresAt != null && now.isBefore(expiresAt)) {
      return Future.value(cached);
    }

    final current = _inFlight;
    if (current != null) return current;

    final request = _fetchMobileAds().whenComplete(() => _inFlight = null);
    _inFlight = request;
    return request;
  }

  Future<FrontendAdSettings> _fetchMobileAds() async {
    final uri = _uri('/api/app/ads');
    final client = httpClient ?? sharedFrontendClient;
    try {
      final response = await client
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(_timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const FrontendAdSettings.empty();
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map) return const FrontendAdSettings.empty();
      final data = decoded['data'];
      if (data is! Map) return const FrontendAdSettings.empty();

      final settings = FrontendAdSettings.fromJson(data, _resolveUrl);
      _cache = settings;
      _cacheExpiresAt = DateTime.now().add(_cacheTtl);
      return settings;
    } catch (_) {
      return const FrontendAdSettings.empty();
    }
  }

  Uri _uri(String path) =>
      frontendApiUri(path, configuredBaseUrl: apiBaseUrl ?? _apiBaseUrl);

  String _resolveUrl(String value) {
    final clean = value.trim();
    if (clean.isEmpty) return '';
    if (clean.startsWith('http://') ||
        clean.startsWith('https://') ||
        clean.startsWith('data:')) {
      return clean;
    }
    final path = clean.startsWith('/') ? clean : '/$clean';
    return frontendApiUri(
      path,
      configuredBaseUrl: apiBaseUrl ?? _apiBaseUrl,
    ).toString();
  }
}

String _str(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

int _int(Object? value, {int fallback = 0}) {
  final parsed = value is num ? value : num.tryParse(value?.toString() ?? '');
  if (parsed == null || !parsed.isFinite) return fallback;
  return parsed.round();
}
