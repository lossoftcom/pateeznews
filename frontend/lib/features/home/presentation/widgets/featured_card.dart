import 'package:flutter/material.dart';

import '../../../../core/mock/home_mock_data.dart';
import '../../../../core/theme/app_colors.dart';

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
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(color: AppColors.surfaceSoft);
      },
      errorBuilder: (_, _, _) => Container(
        color: AppColors.surfaceInk,
        alignment: Alignment.center,
        child: const Icon(
          Icons.image_outlined,
          color: AppColors.support,
          size: 36,
        ),
      ),
    );
  }
}
