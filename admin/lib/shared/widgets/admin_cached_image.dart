import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Diske kalıcı cache'lenen ağ görseli (admin paneli geneli).
///
/// Ham `Image.network` yerine bunu kullan: görsel bir kez iner, geri kaydırınca
/// veya sayfa yeniden açılınca ağdan tekrar inmez. `cached_network_image`
/// üstüne ince sarmalayıcı; frontend'deki `CachedImage`'ın admin eşi.
class AdminCachedImage extends StatelessWidget {
  const AdminCachedImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.memCacheWidth,
    this.placeholderColor = AppColors.surface,
    this.errorWidget,
    this.fadeIn = true,
    this.filterQuality = FilterQuality.medium,
    this.useOldImageOnUrlChange = false,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;

  /// Görseli bu piksel genişliğinde decode et (bellek tasarrufu). Eski
  /// `cacheWidth`/`Image.network(cacheWidth:)` karşılığı.
  final int? memCacheWidth;

  /// İnerken/boşken gösterilecek düz zemin rengi.
  final Color placeholderColor;

  /// Görsel inmezse gösterilecek widget. Verilmezse düz [placeholderColor].
  final Widget? errorWidget;

  /// Liste hücrelerinde kısa fade; tek görsellerde de kullanılabilir.
  final bool fadeIn;

  /// Decode kalitesi. Editör önizlemeleri `FilterQuality.high` ister; liste
  /// hücreleri varsayılan `medium` ile yeterli.
  final FilterQuality filterQuality;

  /// URL değişince yeni görsel inene kadar eskisini göster (eski
  /// `Image.network(gaplessPlayback: true)` karşılığı). Liste hücrelerinde
  /// (widget geri dönüştürülürken yanlış görsel riskine karşı) `false` bırak.
  final bool useOldImageOnUrlChange;

  @override
  Widget build(BuildContext context) {
    final cacheWidth = (memCacheWidth != null && memCacheWidth! > 0)
        ? memCacheWidth
        : null;
    return CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: cacheWidth,
      filterQuality: filterQuality,
      useOldImageOnUrlChange: useOldImageOnUrlChange,
      fadeInDuration: Duration(milliseconds: fadeIn ? 180 : 0),
      fadeOutDuration: Duration(milliseconds: fadeIn ? 120 : 0),
      placeholder: (context, _) => Container(color: placeholderColor),
      errorWidget: (context, _, _) =>
          errorWidget ?? Container(color: placeholderColor),
    );
  }
}
