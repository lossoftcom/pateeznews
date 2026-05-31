import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Diske kalıcı cache'lenen ağ görseli.
///
/// Uygulamada ham `Image.network` yerine bunu kullan: görsel bir kez iner,
/// geri kaydırınca veya sayfa yeniden açılınca ağdan tekrar inmez. Bellekteki
/// `ImageCache`'in üstüne kalıcı disk cache ekler (cached_network_image üzerine
/// ince sarmalayıcı).
class CachedImage extends StatelessWidget {
  const CachedImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.memCacheWidth,
    this.placeholderColor = AppColors.surfaceSoft,
    this.errorWidget,
  });

  final String url;
  final BoxFit fit;

  /// Görseli bu genişlikte decode et (bellek tasarrufu). Eski `cacheWidth`'in
  /// karşılığı.
  final int? memCacheWidth;

  /// İnerken/boşken gösterilecek düz zemin rengi.
  final Color placeholderColor;

  /// Görsel inmezse gösterilecek widget (örn. avatar baş harfi). Verilmezse
  /// düz [placeholderColor] zemini gösterilir.
  final Widget? errorWidget;

  @override
  Widget build(BuildContext context) {
    final cacheWidth = (memCacheWidth != null && memCacheWidth! > 0)
        ? memCacheWidth
        : null;
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      memCacheWidth: cacheWidth,
      filterQuality: FilterQuality.medium,
      fadeInDuration: const Duration(milliseconds: 180),
      fadeOutDuration: const Duration(milliseconds: 120),
      placeholder: (context, _) => Container(color: placeholderColor),
      errorWidget: (context, _, _) =>
          errorWidget ?? Container(color: placeholderColor),
    );
  }
}
