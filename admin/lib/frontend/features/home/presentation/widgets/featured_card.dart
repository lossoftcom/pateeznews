import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../../core/mock/home_mock_data.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/cached_image.dart';

/// Featured slider kartı — yalnızca görsel taşır.
///
/// Üzerinde başlık, özet, kategori, badge veya buton yoktur. Bunlar slider'ın
/// alt içerik panelinde gösterilir. Görselin alt kısmı saf bırakılır; image
/// ile içerik paneli arasındaki yumuşak geçiş slider tarafında, content
/// panel'in üst gradient'i ile yapılır (overlap + opacity ramp).
class FeaturedCard extends StatelessWidget {
  const FeaturedCard({super.key, required this.news, this.onTap});

  final FeaturedNews news;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: _Cover(imageUrl: news.imageUrl),
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return CachedImage(
      url: imageUrl,
      fit: BoxFit.contain,
      memCacheWidth: _cacheWidthFor(context),
      errorWidget: Container(
        color: AppColors.surfaceInk,
        alignment: Alignment.center,
        child: const Icon(
          Symbols.image_outlined,
          color: AppColors.support,
          size: 36,
        ),
      ),
    );
  }

  int _cacheWidthFor(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final target = (width * dpr).round();
    if (target <= 0) return 720;
    return target > 1800 ? 1800 : target;
  }
}
