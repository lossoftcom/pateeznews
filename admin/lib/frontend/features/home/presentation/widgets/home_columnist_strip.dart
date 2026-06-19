import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../../core/mock/home_mock_data.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/cached_image.dart';
import '../../../category/data/opinion_summary.dart';

/// Ana sayfada haberlerin arasına giren "Yazarlar" (köşe yazısı) şeridi.
///
/// Tasarım hedefi: piyasa ve hava şeritleriyle aynı ritim — açık başlık +
/// kullanıcı kaydırınca akan kartlar. Sakin ve minimal; haber kartlarının
/// önüne geçmez (yumuşak gölge, ölçülü tipografi, küçük yazar fotoğrafı).
///
class HomeColumnistStrip extends StatelessWidget {
  const HomeColumnistStrip({
    super.key,
    this.articles = const [],
    this.onSeeAll,
    this.onArticleTap,
    this.onAuthorTap,
  });

  final List<NewsArticle> articles;
  final VoidCallback? onSeeAll;
  final ValueChanged<NewsArticle>? onArticleTap;
  final ValueChanged<NewsAuthor>? onAuthorTap;

  @override
  Widget build(BuildContext context) {
    final items = buildOpinionAuthorSummaries(
      articles,
    ).map(_Columnist.fromSummary).toList(growable: false);

    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ColumnistHeader(onSeeAll: onSeeAll),
        SizedBox(
          height: 162,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageHorizontal,
              2,
              AppSpacing.pageHorizontal,
              2,
            ),
            clipBehavior: Clip.none,
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) => _ColumnistCard(
              item: items[index],
              onTap: () => onArticleTap?.call(items[index].article),
              onAuthorTap: () => onAuthorTap?.call(items[index].author),
            ),
          ),
        ),
      ],
    );
  }
}

/// Yazarlar şeridi başlığı — piyasa/hava şeritleriyle aynı ölçek ve ritimde:
/// koyu kalın başlık + sağda soluk, küçük "Tümü" linki. Üst dolgusu 2'dir ki
/// üstündeki boşluk hava kartı başlığıyla birebir aynı dursun.
class _ColumnistHeader extends StatelessWidget {
  const _ColumnistHeader({this.onSeeAll});

  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        2,
        AppSpacing.pageHorizontal,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Yazarlar',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.titleM.copyWith(
                color: AppColors.inkStrong,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onSeeAll,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Tümü',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.meta.copyWith(
                        color: AppColors.support,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Symbols.arrow_forward_rounded,
                      size: 13,
                      color: AppColors.support,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ColumnistCard extends StatelessWidget {
  const _ColumnistCard({required this.item, this.onTap, this.onAuthorTap});

  final _Columnist item;
  final VoidCallback? onTap;
  final VoidCallback? onAuthorTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: item.title,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 250,
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.line),
            boxShadow: [
              BoxShadow(
                color: AppColors.deepOcean.withValues(alpha: 0.035),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.titleM.copyWith(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.inkStrong,
                  height: 1.22,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                item.excerpt,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodySmall.copyWith(
                  fontSize: 12.5,
                  color: AppColors.inkSoft,
                  height: 1.42,
                ),
              ),
              const Spacer(),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onAuthorTap,
                child: Row(
                  children: [
                    _Avatar(
                      initials: item.initials,
                      color: item.color,
                      imageUrl: item.avatarUrl,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.titleS.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.deepOcean,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            item.date,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.meta.copyWith(
                              fontSize: 11,
                              color: AppColors.support,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Baş harfli veya gerçek görselli yumuşak tonlu yuvarlak yazar avatarı.
class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.initials,
    required this.color,
    required this.imageUrl,
  });

  final String initials;
  final Color color;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final cleanImage = imageUrl.trim();
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: cleanImage.isEmpty
          ? Text(
              initials,
              style: AppTypography.titleS.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            )
          : CachedImage(
              url: cleanImage,
              fit: BoxFit.cover,
              memCacheWidth: 96,
              errorWidget: Center(
                child: Text(
                  initials,
                  style: AppTypography.titleS.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ),
    );
  }
}

/// Şeritte gösterilen tek bir canlı köşe yazısı özeti.
@immutable
class _Columnist {
  const _Columnist({
    required this.name,
    required this.initials,
    required this.title,
    required this.excerpt,
    required this.date,
    required this.color,
    required this.avatarUrl,
    required this.author,
    required this.article,
  });

  factory _Columnist.fromSummary(OpinionAuthorSummary summary) {
    final article = summary.latestArticle;
    return _Columnist(
      name: summary.author.name,
      initials: summary.initials,
      title: article.title,
      excerpt: summary.info,
      date: _dateLabel(article.publishedAt),
      color: _colorFor(summary.key),
      avatarUrl: summary.author.avatarUrl,
      author: summary.author,
      article: article,
    );
  }

  final String name;
  final String initials;
  final String title;
  final String excerpt;
  final String date;
  final Color color;
  final String avatarUrl;
  final NewsAuthor author;
  final NewsArticle article;
}

String _dateLabel(DateTime date) {
  const months = [
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];
  final month = months[(date.month - 1).clamp(0, months.length - 1)];
  return '${date.day} $month ${date.year}';
}

Color _colorFor(String key) {
  const colors = [
    AppColors.deepOcean,
    Color(0xFFB45309),
    Color(0xFF0F766E),
    Color(0xFF6D28D9),
    Color(0xFFBE123C),
  ];
  final index = key.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
  return colors[index % colors.length];
}
