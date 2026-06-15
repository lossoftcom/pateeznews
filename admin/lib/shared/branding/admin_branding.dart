import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Admin panelinin marka bilgisi (genel ayarlardan): site adı + logo/favicon.
@immutable
class AdminBrandingData {
  const AdminBrandingData({
    this.siteName = '',
    this.logoUrl = '',
    this.faviconUrl = '',
  });

  final String siteName;
  final String logoUrl;
  final String faviconUrl;

  /// Kare marka kutusunda gösterilecek görsel: kare favicon tercih edilir,
  /// yoksa logo. Hiçbiri yoksa boş (widget eski ikona düşer).
  String get markUrl {
    final favicon = faviconUrl.trim();
    if (favicon.isNotEmpty) return favicon;
    return logoUrl.trim();
  }

  bool get hasMark => markUrl.isNotEmpty;
  bool get hasSiteName => siteName.trim().isNotEmpty;

  Map<String, Object?> toJson() => {
    'siteName': siteName,
    'logoUrl': logoUrl,
    'faviconUrl': faviconUrl,
  };

  factory AdminBrandingData.fromJson(Map<dynamic, dynamic> json) {
    return AdminBrandingData(
      siteName: (json['siteName'] ?? '').toString(),
      logoUrl: (json['logoUrl'] ?? '').toString(),
      faviconUrl: (json['faviconUrl'] ?? '').toString(),
    );
  }
}

/// Global, kalıcı önbellekli marka durumu.
///
/// Giriş ekranı (oturum öncesi) ve kenar çubuğu başlığı bunu dinler. Splash'ta
/// kalıcı değerle anında tohumlanır, ardından arka planda tazelenir → doğru
/// logo + ad "şak diye" görünür, hiç boş/yanlış marka beklemeden.
final ValueNotifier<AdminBrandingData> adminBranding =
    ValueNotifier<AdminBrandingData>(const AdminBrandingData());

class AdminBrandingStore {
  AdminBrandingStore._();

  static const _prefsKey = 'admin_branding_v1';
  static const _apiBaseUrl = String.fromEnvironment('PATEEZNEWS_API_BASE_URL');
  static const _shellTimeout = Duration(seconds: 6);

  /// Splash önyüklemesi: kalıcı markayı yükle; **önbellek varsa** anında göster
  /// + tazelemeyi arka planda yap; **yoksa (ilk açılış)** splash sırasında kısa
  /// süre (≤3sn) taze çekmeyi bekle → login/dashboard açılınca doğru logo + ad
  /// hazır olur, boş/yanlış marka görünmez.
  static Future<void> bootstrap({String languageCode = 'tr'}) async {
    await loadPersisted();
    final hasCached =
        adminBranding.value.hasMark || adminBranding.value.hasSiteName;
    if (hasCached) {
      unawaited(refreshFromShell(languageCode: languageCode));
      return;
    }
    await refreshFromShell(
      languageCode: languageCode,
    ).timeout(const Duration(seconds: 3), onTimeout: () {});
  }

  /// Splash: kalıcı markayı yükle (yerel prefs, ~ms — login öncesi hazır).
  static Future<void> loadPersisted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        adminBranding.value = AdminBrandingData.fromJson(decoded);
      }
    } catch (_) {
      // yoksay — varsayılan marka kalır
    }
  }

  /// Public `/api/app/shell` (oturumsuz) üzerinden taze marka çek → güncelle +
  /// kalıcı yaz. İlk açılışta (önbellek yokken) bile doğru logonun gelmesi için
  /// splash'ta çağrılır. Hata/timeout'ta sessizdir; mevcut marka ekranda kalır.
  static Future<void> refreshFromShell({String languageCode = 'tr'}) async {
    final client = http.Client();
    try {
      final uri = _resolveApiUri('/api/app/shell').replace(
        queryParameters: {'lang': _safeLang(languageCode)},
      );
      final response = await client.get(uri).timeout(_shellTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) return;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return;
      final settings = decoded['siteSettings'];
      if (settings is! Map) return;
      await update(
        AdminBrandingData(
          siteName: (settings['siteName'] ?? '').toString().trim(),
          logoUrl: _publicUrl((settings['logoUrl'] ?? '').toString()),
          faviconUrl: _publicUrl((settings['faviconUrl'] ?? '').toString()),
        ),
      );
    } catch (_) {
      // sessiz
    } finally {
      client.close();
    }
  }

  /// Oturum açıkken (gate) gerçek admin ayarlarından kesin güncelleme + kalıcı yaz.
  static Future<void> update(AdminBrandingData data) async {
    adminBranding.value = data;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(data.toJson()));
    } catch (_) {
      // yoksay
    }
  }

  static String _safeLang(String value) {
    final cleaned = value.trim().toLowerCase();
    return cleaned.isEmpty ? 'tr' : cleaned;
  }

  static Uri _resolveApiUri(String path) {
    final base = _apiBaseUrl.trim();
    if (base.isNotEmpty) return Uri.parse(base).resolve(path);
    if (!kIsWeb) {
      final host = defaultTargetPlatform == TargetPlatform.android
          ? 'http://10.0.2.2:4321'
          : 'http://127.0.0.1:4321';
      return Uri.parse(host).resolve(path);
    }
    return Uri.base.resolve(path);
  }

  /// Göreli logo yolunu (örn. `/local-upload/logo/...`) gösterilebilir tam
  /// URL'ye çevirir; zaten şemalı (http...) ise olduğu gibi bırakır.
  static String _publicUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    final parsed = Uri.tryParse(trimmed);
    if (parsed != null && parsed.hasScheme) return trimmed;
    return _resolveApiUri(trimmed).toString();
  }
}
