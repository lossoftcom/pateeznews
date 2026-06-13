import 'media_service.dart';

/// Storage yolunu görüntülenebilir URL'ye çevirir.
///
/// - `http`, `https`, `data:` ile başlayan değerler olduğu gibi döner.
/// - [width] verilirse, o genişlikteki WebP varyantı istenir (sunucu
///   `?w=&q=` ile en yakın varyanta yönlendirir). Liste/kart/avatar gibi
///   küçük görsellerde MUTLAKA bir genişlik geç — yoksa tam-boy orijinal iner.
/// - [width] verilmezse mevcut davranış: tam çözünürlüklü yol.
///
/// `features/**` içindeki 5 kopya `_publicUrl` bununla değiştirilir (DRY).
String adminImageUrl(String value, {int? width, int quality = 86}) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';
  if (trimmed.startsWith('http://') ||
      trimmed.startsWith('https://') ||
      trimmed.startsWith('data:')) {
    return trimmed;
  }
  return MediaService().resolveImageUrl(
    trimmed,
    width: width,
    quality: width != null ? quality : null,
  );
}
