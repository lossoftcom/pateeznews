import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pateeznews_admin/core/network/admin_api_headers.dart';

/// Yayın platformu — reklam alanının nerede gösterileceği.
enum AdPlatform { web, mobile }

/// Reklam servisi — Google AdSense veya kendi (yerel) reklamlarımız.
enum AdNetwork { adsense, local }

/// Reklam içeriği türü.
enum AdCreativeType { adsense, image, html }

AdPlatform adPlatformFromId(Object? value) =>
    value?.toString() == 'mobile' ? AdPlatform.mobile : AdPlatform.web;

String adPlatformId(AdPlatform platform) =>
    platform == AdPlatform.mobile ? 'mobile' : 'web';

AdNetwork adNetworkFromId(Object? value) =>
    value?.toString() == 'adsense' ? AdNetwork.adsense : AdNetwork.local;

String adNetworkId(AdNetwork network) =>
    network == AdNetwork.adsense ? 'adsense' : 'local';

AdCreativeType adCreativeTypeFromId(Object? value) {
  return switch (value?.toString()) {
    'adsense' => AdCreativeType.adsense,
    'html' => AdCreativeType.html,
    _ => AdCreativeType.image,
  };
}

String adCreativeTypeId(AdCreativeType type) {
  return switch (type) {
    AdCreativeType.adsense => 'adsense',
    AdCreativeType.html => 'html',
    AdCreativeType.image => 'image',
  };
}

/// Standart bir reklam ölçüsü (Google AdSense / Ad Manager boyutları).
@immutable
class AdSize {
  const AdSize({
    required this.width,
    required this.height,
    required this.label,
    required this.platform,
    this.responsive = false,
    this.fullscreen = false,
  });

  final int width;
  final int height;
  final String label;
  final AdPlatform platform;
  final bool responsive;
  final bool fullscreen;

  String get dimensionLabel {
    if (responsive) return 'Duyarlı';
    if (fullscreen) return 'Tam Ekran';
    return '$width × $height';
  }

  /// Google AdSense sabit boyut kuralları:
  /// genişlik 120–1200, yükseklik 50–1200 ve kenarlardan yalnızca biri 450'yi
  /// aşabilir.
  static bool isAdsenseCompliant(int width, int height) {
    if (width < 120 || width > 1200) return false;
    if (height < 50 || height > 1200) return false;
    if (width > 450 && height > 450) return false;
    return true;
  }

  /// Özel boyut için canlı doğrulama mesajı (uyumluysa null döner).
  static String? validationMessage(int width, int height) {
    if (width < 120 || height < 50) return 'En az 120 × 50 px olmalı';
    if (width > 1200 || height > 1200) return 'En fazla 1200 px olabilir';
    if (width > 450 && height > 450) {
      return 'Kenarlardan yalnızca biri 450 px aşabilir';
    }
    return null;
  }

  /// Web (masaüstü) için AdSense standart boyutları.
  static const List<AdSize> webSizes = [
    AdSize(
      width: 728,
      height: 90,
      label: 'Leaderboard',
      platform: AdPlatform.web,
    ),
    AdSize(
      width: 970,
      height: 90,
      label: 'Büyük Leaderboard',
      platform: AdPlatform.web,
    ),
    AdSize(
      width: 970,
      height: 250,
      label: 'Billboard',
      platform: AdPlatform.web,
    ),
    AdSize(
      width: 300,
      height: 250,
      label: 'Orta Dikdörtgen',
      platform: AdPlatform.web,
    ),
    AdSize(
      width: 336,
      height: 280,
      label: 'Büyük Dikdörtgen',
      platform: AdPlatform.web,
    ),
    AdSize(
      width: 300,
      height: 600,
      label: 'Yarım Sayfa',
      platform: AdPlatform.web,
    ),
    AdSize(
      width: 160,
      height: 600,
      label: 'Geniş Gökdelen',
      platform: AdPlatform.web,
    ),
    AdSize(
      width: 120,
      height: 600,
      label: 'Gökdelen',
      platform: AdPlatform.web,
    ),
    AdSize(width: 300, height: 1050, label: 'Portre', platform: AdPlatform.web),
    AdSize(width: 468, height: 60, label: 'Banner', platform: AdPlatform.web),
    AdSize(
      width: 234,
      height: 60,
      label: 'Yarım Banner',
      platform: AdPlatform.web,
    ),
    AdSize(width: 250, height: 250, label: 'Kare', platform: AdPlatform.web),
    AdSize(
      width: 200,
      height: 200,
      label: 'Küçük Kare',
      platform: AdPlatform.web,
    ),
    AdSize(
      width: 0,
      height: 0,
      label: 'Duyarlı (Otomatik)',
      platform: AdPlatform.web,
      responsive: true,
    ),
  ];

  /// Mobil (uygulama içi) için AdSense standart boyutları.
  static const List<AdSize> mobileSizes = [
    AdSize(
      width: 320,
      height: 50,
      label: 'Mobil Banner',
      platform: AdPlatform.mobile,
    ),
    AdSize(
      width: 320,
      height: 100,
      label: 'Büyük Mobil Banner',
      platform: AdPlatform.mobile,
    ),
    AdSize(
      width: 300,
      height: 250,
      label: 'Mobil Dikdörtgen',
      platform: AdPlatform.mobile,
    ),
    AdSize(
      width: 300,
      height: 50,
      label: 'Dar Mobil Banner',
      platform: AdPlatform.mobile,
    ),
    AdSize(width: 250, height: 250, label: 'Kare', platform: AdPlatform.mobile),
    AdSize(
      width: 336,
      height: 280,
      label: 'Büyük Dikdörtgen',
      platform: AdPlatform.mobile,
    ),
    AdSize(
      width: 0,
      height: 0,
      label: 'Tam Ekran (Geçiş)',
      platform: AdPlatform.mobile,
      fullscreen: true,
    ),
    AdSize(
      width: 0,
      height: 0,
      label: 'Duyarlı (Otomatik)',
      platform: AdPlatform.mobile,
      responsive: true,
    ),
  ];

  static List<AdSize> forPlatform(AdPlatform platform) =>
      platform == AdPlatform.mobile ? mobileSizes : webSizes;
}

/// Bir reklam alanına eklenen tek bir reklam (AdSense birimi ya da yerel görsel/HTML).
class AdCreative {
  AdCreative({
    required this.id,
    required this.name,
    required this.type,
    required this.width,
    required this.height,
    this.responsive = false,
    this.imageUrl = '',
    this.linkUrl = '',
    this.htmlCode = '',
    String adsenseSlotId = '',
    this.weight = 1,
    this.active = true,
    this.accentColor,
  }) : adsenseSlotId = adsenseSlotId.isNotEmpty
           ? adsenseSlotId
           : _defaultAdsenseSlotId(id);

  String id;
  String name;
  AdCreativeType type;
  int width;
  int height;
  bool responsive;
  String imageUrl;
  String linkUrl;
  String htmlCode;
  String adsenseSlotId;
  int weight;
  bool active;

  /// Önizleme/küçük resim için yer tutucu rengi (yerel görsel henüz seçilmemişse).
  final int? accentColor;

  AdNetwork get network =>
      type == AdCreativeType.adsense ? AdNetwork.adsense : AdNetwork.local;

  String get typeLabel {
    return switch (type) {
      AdCreativeType.adsense => 'AdSense',
      AdCreativeType.html => 'HTML',
      AdCreativeType.image => 'Görsel',
    };
  }

  String get sizeLabel => responsive ? 'Duyarlı' : '$width × $height';

  AdCreative copyWith({
    String? name,
    AdCreativeType? type,
    int? width,
    int? height,
    bool? responsive,
    String? imageUrl,
    String? linkUrl,
    String? htmlCode,
    String? adsenseSlotId,
    int? weight,
    bool? active,
  }) {
    return AdCreative(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      width: width ?? this.width,
      height: height ?? this.height,
      responsive: responsive ?? this.responsive,
      imageUrl: imageUrl ?? this.imageUrl,
      linkUrl: linkUrl ?? this.linkUrl,
      htmlCode: htmlCode ?? this.htmlCode,
      adsenseSlotId: adsenseSlotId ?? this.adsenseSlotId,
      weight: weight ?? this.weight,
      active: active ?? this.active,
      accentColor: accentColor,
    );
  }

  factory AdCreative.fromJson(Map<dynamic, dynamic> json) {
    return AdCreative(
      id: json['id']?.toString() ?? _generateId('ad'),
      name: json['name']?.toString() ?? 'Reklam',
      type: adCreativeTypeFromId(json['type']),
      width: _asInt(json['width']),
      height: _asInt(json['height']),
      responsive: json['responsive'] == true,
      imageUrl: json['imageUrl']?.toString() ?? '',
      linkUrl: json['linkUrl']?.toString() ?? '',
      htmlCode: json['htmlCode']?.toString() ?? '',
      adsenseSlotId: json['adsenseSlotId']?.toString() ?? '',
      weight: _asInt(json['weight'], fallback: 1),
      active: json['active'] != false,
      accentColor: json['accentColor'] is int
          ? json['accentColor'] as int
          : null,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'name': name,
      'type': adCreativeTypeId(type),
      'width': width,
      'height': height,
      'responsive': responsive,
      'imageUrl': imageUrl,
      'linkUrl': linkUrl,
      'htmlCode': htmlCode,
      'adsenseSlotId': adsenseSlotId,
      'weight': weight,
      'active': active,
      if (accentColor != null) 'accentColor': accentColor,
    };
  }
}

const _pateezLeaderboardImageUrl =
    '/local-upload/image/2026-06-19/pateez_728x90_reklam.gif';
const _pateezRectangleImageUrl =
    '/local-upload/image/2026-06-19/pateez_336x280_reklam.gif';
const _pateezAdTargetUrl = 'https://pateez.com/';

String _defaultAdsenseSlotId(String creativeId) {
  return switch (creativeId) {
    'ad_web_home_top_adsense' => '8185130828',
    'ad_web_home_below_hero_adsense' => '1636300275',
    'ad_web_home_feed_inline_adsense' => '8508830384',
    'ad_web_category_feed_inline_adsense' => '5076851834',
    'ad_web_home_sidebar_adsense' => '4569585377',
    'ad_web_home_left_rail_adsense' => '1137606820',
    'ad_web_side_rail_left_adsense' => '5004699646',
    'ad_web_side_rail_right_adsense' => '9630340369',
    'ad_web_article_top_adsense' => '8338429672',
    'ad_web_news_incontent_adsense' => '4399184665',
    'ad_web_article_end_adsense' => '7722096397',
    'ad_web_home_billboard_adsense' => '8146857980',
    'ad_web_home_section_break_adsense' => '7511443480',
    'ad_web_article_after_media_adsense' => '2757810259',
    'ad_web_article_midcontent_adsense' => '6039569394',
    'ad_web_article_sidebar_adsense' => '7955286290',
    'ad_web_article_related_before_adsense' => '8975734240',
    'ad_web_video_feed_inline_adsense' => '4016041280',
    'ad_web_search_results_inline_adsense' => '6505483578',
    'ad_web_profile_sidebar_adsense' => '5095933052',
    'ad_mobile_home_after_market_adsense' => '3723407568',
    'ad_mobile_feed_inline_adsense' => '2549660768',
    'ad_mobile_feed_rectangle_adsense' => '7591334532',
    'ad_mobile_detail_incontent_adsense' => '7380571228',
    'ad_mobile_detail_between_articles_adsense' => '5722619013',
    'ad_mobile_video_feed_inline_adsense' => '2339007854',
    'ad_mobile_anchor_adsense' => '1156688044',
    'ad_mobile_home_after_hero_adsense' => '4754407887',
    'ad_mobile_category_after_masthead_adsense' => '8441381779',
    'ad_mobile_category_feed_inline_adsense' => '1783374006',
    'ad_mobile_detail_after_media_adsense' => '7128300101',
    'ad_mobile_detail_midcontent_adsense' => '8843606373',
    'ad_mobile_detail_end_adsense' => '7934115317',
    'ad_mobile_video_feed_rectangle_adsense' => '4502136769',
    'ad_mobile_search_results_inline_adsense' => '9595671028',
    'ad_mobile_profile_feed_inline_adsense' => '3189055096',
    _ => '',
  };
}

AdCreative _pateezLeaderboardCreative(String slotKey, {int weight = 10}) {
  return AdCreative(
    id: 'ad_${slotKey}_pateez_728',
    name: 'Pateez tanıtım bannerı',
    type: AdCreativeType.image,
    width: 728,
    height: 90,
    imageUrl: _pateezLeaderboardImageUrl,
    linkUrl: _pateezAdTargetUrl,
    weight: weight,
    accentColor: 0xFFEF3E4A,
  );
}

AdCreative _pateezRectangleCreative(
  String slotKey, {
  required int width,
  required int height,
  int weight = 10,
}) {
  return AdCreative(
    id: 'ad_${slotKey}_pateez_rect',
    name: 'Pateez tanıtım dikdörtgeni',
    type: AdCreativeType.image,
    width: width,
    height: height,
    imageUrl: _pateezRectangleImageUrl,
    linkUrl: _pateezAdTargetUrl,
    weight: weight,
    accentColor: 0xFFEF3E4A,
  );
}

/// Önyüzde sabit bir konum. İçine istenildiği kadar reklam eklenebilir; önyüz
/// bunları ağırlığa göre otomatik döndürür.
class AdSlot {
  AdSlot({
    required this.id,
    required this.key,
    required this.name,
    required this.description,
    required this.platform,
    required this.width,
    required this.height,
    this.responsive = false,
    this.fullscreen = false,
    this.active = true,
    List<AdCreative>? creatives,
  }) : creatives = creatives ?? <AdCreative>[];

  String id;
  String key;
  String name;
  String description;
  AdPlatform platform;
  int width;
  int height;
  bool responsive;
  bool fullscreen;
  bool active;
  List<AdCreative> creatives;

  int get activeCount => creatives.where((c) => c.active).length;

  String get sizeLabel {
    if (responsive) return 'Duyarlı';
    if (fullscreen) return 'Tam Ekran';
    return '$width × $height';
  }

  factory AdSlot.fromJson(Map<dynamic, dynamic> json) {
    final rawCreatives = json['creatives'];
    return AdSlot(
      id: json['id']?.toString() ?? _generateId('slot'),
      key: json['key']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Reklam Alanı',
      description: json['description']?.toString() ?? '',
      platform: adPlatformFromId(json['platform']),
      width: _asInt(json['width']),
      height: _asInt(json['height']),
      responsive: json['responsive'] == true,
      fullscreen: json['fullscreen'] == true,
      active: json['active'] != false,
      creatives: rawCreatives is List
          ? rawCreatives.whereType<Map>().map(AdCreative.fromJson).toList()
          : <AdCreative>[],
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'key': key,
      'name': name,
      'description': description,
      'platform': adPlatformId(platform),
      'width': width,
      'height': height,
      'responsive': responsive,
      'fullscreen': fullscreen,
      'active': active,
      'creatives': creatives.map((c) => c.toJson()).toList(),
    };
  }
}

/// Tüm reklam yapılandırması.
class AdSettingsData {
  AdSettingsData({
    required this.masterEnabled,
    required this.adsenseConnected,
    required this.adsensePublisherId,
    required this.localEnabled,
    required this.slots,
  });

  bool masterEnabled;
  bool adsenseConnected;
  String adsensePublisherId;
  bool localEnabled;
  List<AdSlot> slots;

  List<AdSlot> slotsFor(AdPlatform platform) =>
      slots.where((s) => s.platform == platform).toList();

  factory AdSettingsData.fromJson(Map<dynamic, dynamic> json) {
    final rawSlots = json['slots'];
    final settings = AdSettingsData(
      masterEnabled: json['masterEnabled'] != false,
      adsenseConnected: json['adsenseConnected'] == true,
      adsensePublisherId: json['adsensePublisherId']?.toString() ?? '',
      localEnabled: json['localEnabled'] != false,
      slots: rawSlots is List
          ? rawSlots.whereType<Map>().map(AdSlot.fromJson).toList()
          : <AdSlot>[],
    );
    return settings.withDefaultSlots();
  }

  Map<String, Object?> toJson() {
    return {
      'masterEnabled': masterEnabled,
      'adsenseConnected': adsenseConnected,
      'adsensePublisherId': adsensePublisherId,
      'localEnabled': localEnabled,
      'slots': slots.map((s) => s.toJson()).toList(),
    };
  }

  AdSettingsData clone() => AdSettingsData.fromJson(toJson());

  AdSettingsData withDefaultSlots() {
    final defaults = AdSettingsData.seed();
    final existingByKey = <String, AdSlot>{
      for (final slot in slots)
        if (slot.key.trim().isNotEmpty) slot.key.trim(): slot,
    };
    final defaultKeys = defaults.slots.map((slot) => slot.key).toSet();
    final merged = <AdSlot>[
      for (final defaultSlot in defaults.slots)
        existingByKey[defaultSlot.key] ?? defaultSlot,
      for (final slot in slots)
        if (!defaultKeys.contains(slot.key)) slot,
    ];
    return AdSettingsData(
      masterEnabled: masterEnabled,
      adsenseConnected: adsenseConnected,
      adsensePublisherId: adsensePublisherId,
      localEnabled: localEnabled,
      slots: merged,
    );
  }

  /// İlk açılışta kullanılacak varsayılan reklam yapılandırması.
  factory AdSettingsData.seed() {
    return AdSettingsData(
      masterEnabled: true,
      adsenseConnected: true,
      adsensePublisherId: 'ca-pub-6674987005803282',
      localEnabled: true,
      slots: [
        AdSlot(
          id: 'slot_web_home_top',
          key: 'web_home_top',
          name: 'Anasayfa — Üst Banner',
          description: 'Manşetin üstü · sayfa başı',
          platform: AdPlatform.web,
          width: 728,
          height: 90,
          creatives: [
            _pateezLeaderboardCreative('web_home_top'),
            AdCreative(
              id: 'ad_web_home_top_adsense',
              name: 'AdSense otomatik reklam',
              type: AdCreativeType.adsense,
              width: 728,
              height: 90,
              weight: 2,
            ),
          ],
        ),
        AdSlot(
          id: 'slot_web_home_below_hero',
          key: 'web_home_below_hero',
          name: 'Anasayfa — Manşet Altı',
          description: 'Manşet sonrası · akış başlamadan',
          platform: AdPlatform.web,
          width: 0,
          height: 0,
          responsive: true,
          creatives: [
            AdCreative(
              id: 'ad_web_home_below_hero_adsense',
              name: 'AdSense duyarlı manşet altı',
              type: AdCreativeType.adsense,
              width: 0,
              height: 0,
              responsive: true,
              weight: 1,
            ),
          ],
        ),
        AdSlot(
          id: 'slot_web_home_feed_inline',
          key: 'web_home_feed_inline',
          name: 'Anasayfa — Akış İçi',
          description: 'Haber akışı · her 4 kartta bir',
          platform: AdPlatform.web,
          width: 336,
          height: 280,
          creatives: [
            _pateezRectangleCreative(
              'web_home_feed_inline',
              width: 336,
              height: 280,
            ),
            AdCreative(
              id: 'ad_web_home_feed_inline_adsense',
              name: 'AdSense akış içi dikdörtgen',
              type: AdCreativeType.adsense,
              width: 336,
              height: 280,
              weight: 1,
            ),
          ],
        ),
        AdSlot(
          id: 'slot_web_category_feed_inline',
          key: 'web_category_feed_inline',
          name: 'Kategori — Akış İçi',
          description: 'Kategori listesi · her 5 kartta bir',
          platform: AdPlatform.web,
          width: 336,
          height: 280,
          creatives: [
            _pateezRectangleCreative(
              'web_category_feed_inline',
              width: 336,
              height: 280,
            ),
            AdCreative(
              id: 'ad_web_category_feed_inline_adsense',
              name: 'AdSense kategori içi',
              type: AdCreativeType.adsense,
              width: 336,
              height: 280,
              weight: 1,
            ),
          ],
        ),
        AdSlot(
          id: 'slot_web_home_sidebar',
          key: 'web_home_sidebar',
          name: 'Anasayfa — Sağ Kenar Çubuğu',
          description: 'Sağ sütun · scroll boyunca görünür',
          platform: AdPlatform.web,
          width: 300,
          height: 600,
          creatives: [
            AdCreative(
              id: 'ad_web_home_sidebar_adsense',
              name: 'AdSense yarım sayfa',
              type: AdCreativeType.adsense,
              width: 300,
              height: 600,
              weight: 1,
            ),
          ],
        ),
        AdSlot(
          id: 'slot_web_home_left_rail',
          key: 'web_home_left_rail',
          name: 'Anasayfa — Sol Kenar Çubuğu',
          description: 'Sol menü altı · scroll ile sabit',
          platform: AdPlatform.web,
          width: 160,
          height: 600,
          creatives: [
            AdCreative(
              id: 'ad_web_home_left_rail_adsense',
              name: 'AdSense sol gökdelen',
              type: AdCreativeType.adsense,
              width: 160,
              height: 600,
              weight: 1,
            ),
          ],
        ),
        AdSlot(
          id: 'slot_web_side_rail_left',
          key: 'web_side_rail_left',
          name: 'Web — Sol Dış Ray',
          description: 'Geniş ekran · içerik dışı sticky',
          platform: AdPlatform.web,
          width: 160,
          height: 600,
          creatives: [
            AdCreative(
              id: 'ad_web_side_rail_left_adsense',
              name: 'AdSense sol dış ray',
              type: AdCreativeType.adsense,
              width: 160,
              height: 600,
              weight: 1,
            ),
          ],
        ),
        AdSlot(
          id: 'slot_web_side_rail_right',
          key: 'web_side_rail_right',
          name: 'Web — Sağ Dış Ray',
          description: 'Geniş ekran · içerik dışı sticky',
          platform: AdPlatform.web,
          width: 160,
          height: 600,
          creatives: [
            AdCreative(
              id: 'ad_web_side_rail_right_adsense',
              name: 'AdSense sağ dış ray',
              type: AdCreativeType.adsense,
              width: 160,
              height: 600,
              weight: 1,
            ),
          ],
        ),
        AdSlot(
          id: 'slot_web_article_top',
          key: 'web_article_top',
          name: 'Haber Detay — Üst Banner',
          description: 'Başlık altı · ana medya öncesi',
          platform: AdPlatform.web,
          width: 728,
          height: 90,
          creatives: [
            _pateezLeaderboardCreative('web_article_top'),
            AdCreative(
              id: 'ad_web_article_top_adsense',
              name: 'AdSense haber üstü',
              type: AdCreativeType.adsense,
              width: 728,
              height: 90,
              weight: 1,
            ),
          ],
        ),
        AdSlot(
          id: 'slot_web_news_incontent',
          key: 'web_news_incontent',
          name: 'Haber Detay — İçerik Arası',
          description: 'Paragraf arası · 2. bloktan sonra',
          platform: AdPlatform.web,
          width: 300,
          height: 250,
          creatives: [
            _pateezRectangleCreative(
              'web_news_incontent',
              width: 300,
              height: 250,
            ),
            AdCreative(
              id: 'ad_web_news_incontent_adsense',
              name: 'AdSense içerik reklamı',
              type: AdCreativeType.adsense,
              width: 300,
              height: 250,
              weight: 1,
            ),
          ],
        ),
        AdSlot(
          id: 'slot_web_article_end',
          key: 'web_article_end',
          name: 'Haber Detay — Yazı Sonu',
          description: 'Yorumlar/tepkiler öncesi · doğal mola',
          platform: AdPlatform.web,
          width: 336,
          height: 280,
          creatives: [
            _pateezRectangleCreative(
              'web_article_end',
              width: 336,
              height: 280,
            ),
            AdCreative(
              id: 'ad_web_article_end_adsense',
              name: 'AdSense yazı sonu',
              type: AdCreativeType.adsense,
              width: 336,
              height: 280,
              weight: 1,
            ),
          ],
        ),
        AdSlot(
          id: 'slot_web_home_billboard',
          key: 'web_home_billboard',
          name: 'Anasayfa — Billboard',
          description: 'Manşet üstü · geniş ekran yüksek görünürlük',
          platform: AdPlatform.web,
          width: 970,
          height: 250,
          creatives: [
            AdCreative(
              id: 'ad_web_home_billboard_adsense',
              name: 'AdSense geniş billboard',
              type: AdCreativeType.adsense,
              width: 970,
              height: 250,
              weight: 1,
            ),
          ],
        ),
        AdSlot(
          id: 'slot_web_home_section_break',
          key: 'web_home_section_break',
          name: 'Anasayfa — Bölüm Arası',
          description: 'Kategori blokları arası · doğal mola',
          platform: AdPlatform.web,
          width: 728,
          height: 90,
          creatives: [
            _pateezLeaderboardCreative('web_home_section_break'),
            AdCreative(
              id: 'ad_web_home_section_break_adsense',
              name: 'AdSense bölüm arası',
              type: AdCreativeType.adsense,
              width: 728,
              height: 90,
              weight: 1,
            ),
          ],
        ),
        AdSlot(
          id: 'slot_web_article_after_media',
          key: 'web_article_after_media',
          name: 'Haber Detay — Medya Altı',
          description: 'Kapak/video sonrası · metin başlamadan',
          platform: AdPlatform.web,
          width: 728,
          height: 90,
          creatives: [
            _pateezLeaderboardCreative('web_article_after_media'),
            AdCreative(
              id: 'ad_web_article_after_media_adsense',
              name: 'AdSense medya altı',
              type: AdCreativeType.adsense,
              width: 728,
              height: 90,
              weight: 1,
            ),
          ],
        ),
        AdSlot(
          id: 'slot_web_article_midcontent',
          key: 'web_article_midcontent',
          name: 'Haber Detay — Orta İçerik',
          description: '4.-5. içerik bloğu sonrası · okuma molası',
          platform: AdPlatform.web,
          width: 336,
          height: 280,
          creatives: [
            _pateezRectangleCreative(
              'web_article_midcontent',
              width: 336,
              height: 280,
            ),
            AdCreative(
              id: 'ad_web_article_midcontent_adsense',
              name: 'AdSense orta içerik',
              type: AdCreativeType.adsense,
              width: 336,
              height: 280,
              weight: 1,
            ),
          ],
        ),
        AdSlot(
          id: 'slot_web_article_sidebar',
          key: 'web_article_sidebar',
          name: 'Haber Detay — Sağ Sidebar',
          description: 'Detay sağ sütun · scroll boyunca görünür',
          platform: AdPlatform.web,
          width: 300,
          height: 600,
          creatives: [
            AdCreative(
              id: 'ad_web_article_sidebar_adsense',
              name: 'AdSense detay yarım sayfa',
              type: AdCreativeType.adsense,
              width: 300,
              height: 600,
              weight: 1,
            ),
          ],
        ),
        AdSlot(
          id: 'slot_web_article_related_before',
          key: 'web_article_related_before',
          name: 'Haber Detay — Önerilenler Öncesi',
          description: 'Yorumlar/ilgili haberler öncesi · doğal mola',
          platform: AdPlatform.web,
          width: 336,
          height: 280,
          creatives: [
            _pateezRectangleCreative(
              'web_article_related_before',
              width: 336,
              height: 280,
            ),
            AdCreative(
              id: 'ad_web_article_related_before_adsense',
              name: 'AdSense önerilenler öncesi',
              type: AdCreativeType.adsense,
              width: 336,
              height: 280,
              weight: 1,
            ),
          ],
        ),
        AdSlot(
          id: 'slot_web_video_feed_inline',
          key: 'web_video_feed_inline',
          name: 'Web — Video Akışı Arası',
          description: 'Video listesi · her 4 kartta bir',
          platform: AdPlatform.web,
          width: 336,
          height: 280,
          creatives: [
            _pateezRectangleCreative(
              'web_video_feed_inline',
              width: 336,
              height: 280,
            ),
            AdCreative(
              id: 'ad_web_video_feed_inline_adsense',
              name: 'AdSense web video akışı',
              type: AdCreativeType.adsense,
              width: 336,
              height: 280,
              weight: 1,
            ),
          ],
        ),
        AdSlot(
          id: 'slot_web_story_between',
          key: 'web_story_between',
          name: 'Web Hikaye — Geçiş Arası',
          description: 'Hikaye geçişi · kullanıcı aksiyonu sonrası',
          platform: AdPlatform.web,
          width: 300,
          height: 250,
          active: false,
          creatives: [
            _pateezRectangleCreative(
              'web_story_between',
              width: 300,
              height: 250,
            ),
            AdCreative(
              id: 'ad_web_story_between_adsense',
              name: 'AdSense hikaye geçişi',
              type: AdCreativeType.adsense,
              width: 300,
              height: 250,
              weight: 1,
            ),
          ],
        ),
        AdSlot(
          id: 'slot_web_search_results_inline',
          key: 'web_search_results_inline',
          name: 'Web Arama — Sonuç Arası',
          description: 'Arama sonuçları · her 6 sonuçta bir',
          platform: AdPlatform.web,
          width: 336,
          height: 280,
          creatives: [
            _pateezRectangleCreative(
              'web_search_results_inline',
              width: 336,
              height: 280,
            ),
            AdCreative(
              id: 'ad_web_search_results_inline_adsense',
              name: 'AdSense arama sonuç arası',
              type: AdCreativeType.adsense,
              width: 336,
              height: 280,
              weight: 1,
            ),
          ],
        ),
        AdSlot(
          id: 'slot_web_profile_sidebar',
          key: 'web_profile_sidebar',
          name: 'Profil — Sağ Sidebar',
          description: 'Yazar/profil sayfası sağ sütun',
          platform: AdPlatform.web,
          width: 300,
          height: 250,
          creatives: [
            _pateezRectangleCreative(
              'web_profile_sidebar',
              width: 300,
              height: 250,
            ),
            AdCreative(
              id: 'ad_web_profile_sidebar_adsense',
              name: 'AdSense profil sidebar',
              type: AdCreativeType.adsense,
              width: 300,
              height: 250,
              weight: 1,
            ),
          ],
        ),
        AdSlot(
          id: 'slot_mobile_home_after_market',
          key: 'mobile_home_after_market',
          name: 'Mobil — Piyasa Altı',
          description: 'Manşet/piyasa sonrası · akış öncesi',
          platform: AdPlatform.mobile,
          width: 320,
          height: 100,
          creatives: [
            AdCreative(
              id: 'ad_mobile_home_after_market_adsense',
              name: 'AdSense piyasa altı',
              type: AdCreativeType.adsense,
              width: 320,
              height: 100,
              weight: 1,
            ),
          ],
        ),
        AdSlot(
          id: 'slot_mobile_feed_inline',
          key: 'mobile_feed_inline',
          name: 'Mobil — Liste Arası',
          description: 'Haber akışı · her 5 kartta bir',
          platform: AdPlatform.mobile,
          width: 320,
          height: 100,
          creatives: [
            AdCreative(
              id: 'ad_mobile_feed_inline_adsense',
              name: 'AdSense mobil banner',
              type: AdCreativeType.adsense,
              width: 320,
              height: 100,
              weight: 1,
            ),
          ],
        ),
        AdSlot(
          id: 'slot_mobile_feed_rectangle',
          key: 'mobile_feed_rectangle',
          name: 'Mobil — Akış Dikdörtgen',
          description: 'Haber akışı · her 8 kartta bir',
          platform: AdPlatform.mobile,
          width: 300,
          height: 250,
          creatives: [
            _pateezRectangleCreative(
              'mobile_feed_rectangle',
              width: 300,
              height: 250,
            ),
            AdCreative(
              id: 'ad_mobile_feed_rectangle_adsense',
              name: 'AdSense mobil dikdörtgen',
              type: AdCreativeType.adsense,
              width: 300,
              height: 250,
              weight: 1,
            ),
          ],
        ),
        AdSlot(
          id: 'slot_mobile_detail_incontent',
          key: 'mobile_detail_incontent',
          name: 'Mobil — Haber İçi',
          description: 'Detay içeriği · 2. bloktan sonra',
          platform: AdPlatform.mobile,
          width: 300,
          height: 250,
          creatives: [
            _pateezRectangleCreative(
              'mobile_detail_incontent',
              width: 300,
              height: 250,
            ),
            AdCreative(
              id: 'ad_mobile_detail_incontent_adsense',
              name: 'AdSense haber içi',
              type: AdCreativeType.adsense,
              width: 300,
              height: 250,
              weight: 1,
            ),
          ],
        ),
        AdSlot(
          id: 'slot_mobile_detail_between_articles',
          key: 'mobile_detail_between_articles',
          name: 'Mobil — Haberler Arası',
          description: 'Detay scroll · sonraki haber öncesi',
          platform: AdPlatform.mobile,
          width: 320,
          height: 100,
          creatives: [
            AdCreative(
              id: 'ad_mobile_detail_between_articles_adsense',
              name: 'AdSense haberler arası',
              type: AdCreativeType.adsense,
              width: 320,
              height: 100,
              weight: 1,
            ),
          ],
        ),
        AdSlot(
          id: 'slot_mobile_video_feed_inline',
          key: 'mobile_video_feed_inline',
          name: 'Mobil — Video Akışı Arası',
          description: 'Video sekmesi · her 3 video kartında bir',
          platform: AdPlatform.mobile,
          width: 320,
          height: 100,
          creatives: [
            AdCreative(
              id: 'ad_mobile_video_feed_inline_adsense',
              name: 'AdSense video akışı',
              type: AdCreativeType.adsense,
              width: 320,
              height: 100,
              weight: 1,
            ),
          ],
        ),
        AdSlot(
          id: 'slot_mobile_anchor',
          key: 'mobile_anchor',
          name: 'Mobil — Alt Sabit (Anchor)',
          description: 'Bottom nav üstü · güvenli alan içinde',
          platform: AdPlatform.mobile,
          width: 320,
          height: 50,
          creatives: [
            AdCreative(
              id: 'ad_mobile_anchor_adsense',
              name: 'AdSense alt banner',
              type: AdCreativeType.adsense,
              width: 320,
              height: 50,
              weight: 1,
            ),
          ],
        ),
        AdSlot(
          id: 'slot_mobile_interstitial',
          key: 'mobile_interstitial',
          name: 'Mobil — Doğal Geçiş (Tam Ekran)',
          description: 'Bölüm/haber geçişi · frekans kontrollü',
          platform: AdPlatform.mobile,
          width: 0,
          height: 0,
          fullscreen: true,
          active: false,
          creatives: [
            AdCreative(
              id: 'ad_mobile_interstitial_adsense',
              name: 'AdSense geçiş reklamı',
              type: AdCreativeType.adsense,
              width: 0,
              height: 0,
              responsive: true,
              weight: 1,
            ),
          ],
        ),
        AdSlot(
          id: 'slot_mobile_home_after_hero',
          key: 'mobile_home_after_hero',
          name: 'Mobil — Manşet Altı',
          description: 'Manşet slider sonrası · akış başlamadan',
          platform: AdPlatform.mobile,
          width: 320,
          height: 100,
          creatives: [
            AdCreative(
              id: 'ad_mobile_home_after_hero_adsense',
              name: 'AdSense mobil manşet altı',
              type: AdCreativeType.adsense,
              width: 320,
              height: 100,
              weight: 1,
            ),
          ],
        ),
        AdSlot(
          id: 'slot_mobile_category_after_masthead',
          key: 'mobile_category_after_masthead',
          name: 'Mobil — Kategori Üstü',
          description: 'Kategori masthead sonrası · liste başlamadan',
          platform: AdPlatform.mobile,
          width: 320,
          height: 100,
          creatives: [
            AdCreative(
              id: 'ad_mobile_category_after_masthead_adsense',
              name: 'AdSense kategori üstü',
              type: AdCreativeType.adsense,
              width: 320,
              height: 100,
              weight: 1,
            ),
          ],
        ),
        AdSlot(
          id: 'slot_mobile_category_feed_inline',
          key: 'mobile_category_feed_inline',
          name: 'Mobil — Kategori Akış İçi',
          description: 'Kategori listesi · her 6 kartta bir',
          platform: AdPlatform.mobile,
          width: 300,
          height: 250,
          creatives: [
            _pateezRectangleCreative(
              'mobile_category_feed_inline',
              width: 300,
              height: 250,
            ),
            AdCreative(
              id: 'ad_mobile_category_feed_inline_adsense',
              name: 'AdSense kategori akış içi',
              type: AdCreativeType.adsense,
              width: 300,
              height: 250,
              weight: 1,
            ),
          ],
        ),
        AdSlot(
          id: 'slot_mobile_detail_after_media',
          key: 'mobile_detail_after_media',
          name: 'Mobil — Detay Medya Altı',
          description: 'Kapak/video sonrası · metin öncesi',
          platform: AdPlatform.mobile,
          width: 320,
          height: 100,
          creatives: [
            AdCreative(
              id: 'ad_mobile_detail_after_media_adsense',
              name: 'AdSense detay medya altı',
              type: AdCreativeType.adsense,
              width: 320,
              height: 100,
              weight: 1,
            ),
          ],
        ),
        AdSlot(
          id: 'slot_mobile_detail_midcontent',
          key: 'mobile_detail_midcontent',
          name: 'Mobil — Detay Orta İçerik',
          description: '4.-5. içerik bloğu sonrası · okuma molası',
          platform: AdPlatform.mobile,
          width: 300,
          height: 250,
          creatives: [
            _pateezRectangleCreative(
              'mobile_detail_midcontent',
              width: 300,
              height: 250,
            ),
            AdCreative(
              id: 'ad_mobile_detail_midcontent_adsense',
              name: 'AdSense mobil orta içerik',
              type: AdCreativeType.adsense,
              width: 300,
              height: 250,
              weight: 1,
            ),
          ],
        ),
        AdSlot(
          id: 'slot_mobile_detail_end',
          key: 'mobile_detail_end',
          name: 'Mobil — Detay Yazı Sonu',
          description: 'Tepkiler/yorumlar öncesi · doğal mola',
          platform: AdPlatform.mobile,
          width: 300,
          height: 250,
          creatives: [
            _pateezRectangleCreative(
              'mobile_detail_end',
              width: 300,
              height: 250,
            ),
            AdCreative(
              id: 'ad_mobile_detail_end_adsense',
              name: 'AdSense mobil yazı sonu',
              type: AdCreativeType.adsense,
              width: 300,
              height: 250,
              weight: 1,
            ),
          ],
        ),
        AdSlot(
          id: 'slot_mobile_video_feed_rectangle',
          key: 'mobile_video_feed_rectangle',
          name: 'Mobil — Video Dikdörtgen',
          description: 'Video akışı · her 5 video kartında bir',
          platform: AdPlatform.mobile,
          width: 300,
          height: 250,
          creatives: [
            _pateezRectangleCreative(
              'mobile_video_feed_rectangle',
              width: 300,
              height: 250,
            ),
            AdCreative(
              id: 'ad_mobile_video_feed_rectangle_adsense',
              name: 'AdSense mobil video dikdörtgen',
              type: AdCreativeType.adsense,
              width: 300,
              height: 250,
              weight: 1,
            ),
          ],
        ),
        AdSlot(
          id: 'slot_mobile_search_results_inline',
          key: 'mobile_search_results_inline',
          name: 'Mobil — Arama Sonuç Arası',
          description: 'Arama sonuçları · her 6 sonuçta bir',
          platform: AdPlatform.mobile,
          width: 320,
          height: 100,
          creatives: [
            AdCreative(
              id: 'ad_mobile_search_results_inline_adsense',
              name: 'AdSense mobil arama sonuç arası',
              type: AdCreativeType.adsense,
              width: 320,
              height: 100,
              weight: 1,
            ),
          ],
        ),
        AdSlot(
          id: 'slot_mobile_profile_feed_inline',
          key: 'mobile_profile_feed_inline',
          name: 'Mobil Profil — Akış Arası',
          description: 'Profil haber listesi · her 6 kartta bir',
          platform: AdPlatform.mobile,
          width: 300,
          height: 250,
          creatives: [
            _pateezRectangleCreative(
              'mobile_profile_feed_inline',
              width: 300,
              height: 250,
            ),
            AdCreative(
              id: 'ad_mobile_profile_feed_inline_adsense',
              name: 'AdSense mobil profil akışı',
              type: AdCreativeType.adsense,
              width: 300,
              height: 250,
              weight: 1,
            ),
          ],
        ),
        AdSlot(
          id: 'slot_mobile_story_between',
          key: 'mobile_story_between',
          name: 'Mobil Hikaye — Geçiş Arası',
          description: 'Hikaye geçişi · kullanıcı ilerletince',
          platform: AdPlatform.mobile,
          width: 300,
          height: 250,
          active: false,
          creatives: [
            _pateezRectangleCreative(
              'mobile_story_between',
              width: 300,
              height: 250,
            ),
            AdCreative(
              id: 'ad_mobile_story_between_adsense',
              name: 'AdSense mobil hikaye geçişi',
              type: AdCreativeType.adsense,
              width: 300,
              height: 250,
              weight: 1,
            ),
          ],
        ),
      ],
    );
  }
}

abstract class AdminAdsRepository {
  Future<AdSettingsData> fetchSettings();

  Future<AdSettingsData> saveSettings(AdSettingsData settings);
}

/// Varsayılan repository — varsayılan verilerle çalışır ve değişiklikleri oturum
/// boyunca bellekte tutar. Sunucu uç noktası hazır olduğunda
/// [SupabaseAdminAdsRepository] ile değiştirilebilir.
class LocalAdminAdsRepository implements AdminAdsRepository {
  const LocalAdminAdsRepository();

  static AdSettingsData? _store;

  @override
  Future<AdSettingsData> fetchSettings() async {
    final store = _store ??= AdSettingsData.seed();
    return store.clone();
  }

  @override
  Future<AdSettingsData> saveSettings(AdSettingsData settings) async {
    _store = settings.clone();
    return settings.clone();
  }
}

/// Sunucu tarafı hazır olduğunda kullanılacak repository. Mevcut depo/ayar
/// servislerindeki desenle aynıdır (`/api/admin/ad-settings`).
class SupabaseAdminAdsRepository implements AdminAdsRepository {
  const SupabaseAdminAdsRepository({this.httpClient, this.apiBaseUrl});

  static const _apiBaseUrl = String.fromEnvironment('PATEEZNEWS_API_BASE_URL');
  static const _requestTimeout = Duration(seconds: 18);

  final http.Client? httpClient;
  final String? apiBaseUrl;

  @override
  Future<AdSettingsData> fetchSettings() async {
    final response = await _get(_uri('/api/admin/ad-settings'));
    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AdminAdsException(
        _errorMessage(decoded, 'Reklam ayarları alınamadı'),
      );
    }
    if (decoded is! Map) return AdSettingsData.seed();
    final data = decoded['data'];
    if (data is! Map) return AdSettingsData.seed();
    return AdSettingsData.fromJson(data);
  }

  @override
  Future<AdSettingsData> saveSettings(AdSettingsData settings) async {
    final response = await _post(
      _uri('/api/admin/ad-settings'),
      jsonEncode({'values': settings.toJson()}),
    );
    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AdminAdsException(
        _errorMessage(decoded, 'Reklam ayarları kaydedilemedi'),
      );
    }
    if (decoded is! Map) return settings;
    final data = decoded['data'];
    if (data is! Map) return settings;
    return AdSettingsData.fromJson(data);
  }

  Future<http.Response> _get(Uri uri) async {
    final client = httpClient ?? adminHttpClient;
    final closeClient = shouldCloseAdminHttpClient(client, httpClient);
    try {
      return await client
          .get(uri, headers: await adminAuthHeaders())
          .timeout(_requestTimeout);
    } finally {
      if (closeClient) client.close();
    }
  }

  Future<http.Response> _post(Uri uri, String body) async {
    final client = httpClient ?? adminHttpClient;
    final closeClient = shouldCloseAdminHttpClient(client, httpClient);
    try {
      return await client
          .post(uri, headers: await adminJsonHeaders(), body: body)
          .timeout(_requestTimeout);
    } finally {
      if (closeClient) client.close();
    }
  }

  Uri _uri(String path) {
    final baseUrl = (apiBaseUrl ?? _apiBaseUrl).trim();
    if (baseUrl.isNotEmpty) return Uri.parse(baseUrl).resolve(path);
    if (kIsWeb) return Uri.base.resolve(path);
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => Uri.parse('http://10.0.2.2:4321').resolve(path),
      _ => Uri.parse('http://127.0.0.1:4321').resolve(path),
    };
  }
}

class AdminAdsException implements Exception {
  const AdminAdsException(this.message);

  final String message;

  @override
  String toString() => message;
}

int _asInt(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

var _idCounter = 0;

String _generateId(String prefix) {
  _idCounter++;
  return '${prefix}_${DateTime.now().microsecondsSinceEpoch}_$_idCounter';
}

String generateAdId(String prefix) => _generateId(prefix);

String _errorMessage(Object? decoded, String fallback) {
  if (decoded is Map) {
    final error = decoded['error'];
    if (error is Map && error['message'] != null) {
      return error['message'].toString();
    }
    if (decoded['message'] != null) return decoded['message'].toString();
  }
  return fallback;
}
