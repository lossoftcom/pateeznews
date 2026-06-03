import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../../core/mock/home_mock_data.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/cached_image.dart';

/// Profil akışı için kompakt haber kartı: solda kategori rozetli küçük görsel,
/// sağda başlık ve okunma · yorum · beğeni metası. Ana sayfanın yoğun sosyal
/// kartından farklı, bir kullanıcının üretimini liste hâlinde göstermeye uygun
/// sade biçim. 4px keskin radius ve projenin renk/tipografi dili korunur.
class ProfilePostCard extends StatelessWidget {
  const ProfilePostCard({super.key, required this.article, required this.onTap});

  final NewsArticle article;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppColors.line),
          ),
          padding: const EdgeInsets.all(AppSpacing.sm + 2),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Thumb(imageUrl: article.imageUrl, category: article.category),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        article.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleS.copyWith(
                          color: AppColors.inkStrong,
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                          height: 1.2,
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(height: AppSpacing.sm),
                      _MetaRow(article: article),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.imageUrl, required this.category});

  final String imageUrl;
  final String category;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 104,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: AppColors.surfaceInk,
              child: CachedImage(
                url: imageUrl,
                fit: BoxFit.cover,
                memCacheWidth: 320,
                placeholderColor: AppColors.surfaceInk,
                errorWidget: const ColoredBox(
                  color: AppColors.surfaceInk,
                  child: Icon(
                    Symbols.image_outlined,
                    color: AppColors.support,
                    size: 22,
                  ),
                ),
              ),
            ),
            if (category.trim().isNotEmpty)
              Positioned(
                left: 5,
                bottom: 5,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.actionRed,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.eyebrow.copyWith(
                      color: Colors.white,
                      fontSize: 9,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.article});

  final NewsArticle article;

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle.merge(
      style: AppTypography.meta.copyWith(
        color: AppColors.support,
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
      child: Row(
        children: [
          Flexible(
            child: Text(
              RelativeTime.format(article.publishedAt),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),
          _Stat(icon: Symbols.visibility_outlined, value: article.views),
          const SizedBox(width: 10),
          _Stat(icon: Symbols.chat_3_line, value: article.comments),
          const SizedBox(width: 10),
          _Stat(icon: Symbols.heart_3_line, value: article.likes),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value});

  final IconData icon;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.placeholderSoft),
        const SizedBox(width: 4),
        Text(CountFormat.compact(value)),
      ],
    );
  }
}
