import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'admin_branding.dart';

/// Masaüstü (macOS) pencere başlığını genel ayarlardaki **site adıyla** günceller.
///
/// macOS pencere başlık çubuğu native `PRODUCT_NAME`'i gösterir; Flutter'ın
/// saf-Dart bir API'si yok. Bu yüzden native `pateez/window` kanalına `setTitle`
/// göndeririz (bkz. MainFlutterWindow.swift). Marka [adminBranding] değiştikçe
/// (splash önbelleği → shell → oturumlu kesin güncelleme) başlık canlı yenilenir.
///
/// Web/mobil ve diğer masaüstlerinde no-op (sessiz). Hata/timeout yutulur.
class DesktopWindowTitle {
  DesktopWindowTitle._();

  static const _channel = MethodChannel('pateez/window');
  static bool _started = false;

  /// main()'de (admin masaüstü dalında) bir kez çağrılır. Dinleyici ekler +
  /// ilk kareden sonra başlığı uygular (native kanal o anda hazır olur).
  static void start() {
    if (_started || kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.macOS) return;
    _started = true;
    adminBranding.addListener(_apply);
    WidgetsBinding.instance.addPostFrameCallback((_) => _apply());
  }

  static void _apply() {
    final branding = adminBranding.value;
    final title = branding.hasSiteName ? branding.siteName.trim() : 'Pateez';
    // Native handler henüz kayıtlı değilse sessizce yutulur; sonraki marka
    // değişiminde tekrar denenir.
    _channel.invokeMethod<void>('setTitle', title).catchError((_) {});
  }
}
