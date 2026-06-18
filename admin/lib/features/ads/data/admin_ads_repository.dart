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
    this.adsenseSlotId = '',
    this.weight = 1,
    this.active = true,
    this.accentColor,
  });

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
    return AdSettingsData(
      masterEnabled: json['masterEnabled'] != false,
      adsenseConnected: json['adsenseConnected'] == true,
      adsensePublisherId: json['adsensePublisherId']?.toString() ?? '',
      localEnabled: json['localEnabled'] != false,
      slots: rawSlots is List
          ? rawSlots.whereType<Map>().map(AdSlot.fromJson).toList()
          : <AdSlot>[],
    );
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

  /// İlk açılışta gösterilecek örnek yapılandırma (gerçek veriler bağlanana dek).
  factory AdSettingsData.seed() {
    return AdSettingsData(
      masterEnabled: true,
      adsenseConnected: true,
      adsensePublisherId: 'ca-pub-7421000000000093',
      localEnabled: true,
      slots: [
        AdSlot(
          id: _generateId('slot'),
          key: 'web_home_top',
          name: 'Anasayfa — Üst Banner',
          description: 'Manşetin üstü · sayfa başı',
          platform: AdPlatform.web,
          width: 728,
          height: 90,
          creatives: [
            AdCreative(
              id: _generateId('ad'),
              name: 'Premium üyelik kampanyası',
              type: AdCreativeType.image,
              width: 728,
              height: 90,
              weight: 5,
              accentColor: 0xFF2C3E50,
            ),
            AdCreative(
              id: _generateId('ad'),
              name: 'Demirören Optik — bahar',
              type: AdCreativeType.image,
              width: 728,
              height: 90,
              weight: 3,
              accentColor: 0xFFF39C12,
            ),
            AdCreative(
              id: _generateId('ad'),
              name: 'AdSense otomatik reklam',
              type: AdCreativeType.adsense,
              width: 728,
              height: 90,
              weight: 2,
            ),
          ],
        ),
        AdSlot(
          id: _generateId('slot'),
          key: 'web_home_sidebar',
          name: 'Anasayfa — Kenar Çubuğu',
          description: 'Sağ sütun · sabit',
          platform: AdPlatform.web,
          width: 300,
          height: 600,
          creatives: [
            AdCreative(
              id: _generateId('ad'),
              name: 'Yerel emlak ofisi',
              type: AdCreativeType.image,
              width: 300,
              height: 600,
              weight: 1,
              accentColor: 0xFF1D9E75,
            ),
            AdCreative(
              id: _generateId('ad'),
              name: 'AdSense yarım sayfa',
              type: AdCreativeType.adsense,
              width: 300,
              height: 600,
              weight: 1,
            ),
          ],
        ),
        AdSlot(
          id: _generateId('slot'),
          key: 'web_news_incontent',
          name: 'Haber Detay — İçerik Arası',
          description: 'Paragraf arası · akış içi',
          platform: AdPlatform.web,
          width: 300,
          height: 250,
          creatives: [
            AdCreative(
              id: _generateId('ad'),
              name: 'AdSense içerik reklamı',
              type: AdCreativeType.adsense,
              width: 300,
              height: 250,
              weight: 1,
            ),
          ],
        ),
        AdSlot(
          id: _generateId('slot'),
          key: 'web_home_below_hero',
          name: 'Anasayfa — Manşet Altı',
          description: 'Manşet bloğunun altı',
          platform: AdPlatform.web,
          width: 0,
          height: 0,
          responsive: true,
        ),
        AdSlot(
          id: _generateId('slot'),
          key: 'mobile_feed_inline',
          name: 'Mobil — Liste Arası',
          description: 'Haber akışı · her 5 kartta bir',
          platform: AdPlatform.mobile,
          width: 320,
          height: 100,
          creatives: [
            AdCreative(
              id: _generateId('ad'),
              name: 'Uygulama içi kampanya',
              type: AdCreativeType.image,
              width: 320,
              height: 100,
              weight: 2,
              accentColor: 0xFFEA4335,
            ),
            AdCreative(
              id: _generateId('ad'),
              name: 'AdSense mobil banner',
              type: AdCreativeType.adsense,
              width: 320,
              height: 100,
              weight: 1,
            ),
          ],
        ),
        AdSlot(
          id: _generateId('slot'),
          key: 'mobile_anchor',
          name: 'Mobil — Alt Sabit (Anchor)',
          description: 'Ekran altı · sabit yapışkan',
          platform: AdPlatform.mobile,
          width: 320,
          height: 50,
          creatives: [
            AdCreative(
              id: _generateId('ad'),
              name: 'AdSense alt banner',
              type: AdCreativeType.adsense,
              width: 320,
              height: 50,
              weight: 1,
            ),
          ],
        ),
        AdSlot(
          id: _generateId('slot'),
          key: 'mobile_interstitial',
          name: 'Mobil — Haber Açılışı (Tam Ekran)',
          description: 'Geçiş reklamı · interstitial',
          platform: AdPlatform.mobile,
          width: 0,
          height: 0,
          fullscreen: true,
          active: false,
          creatives: [
            AdCreative(
              id: _generateId('ad'),
              name: 'AdSense geçiş reklamı',
              type: AdCreativeType.adsense,
              width: 0,
              height: 0,
              responsive: true,
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

/// Varsayılan repository — örnek verilerle çalışır ve değişiklikleri oturum
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
