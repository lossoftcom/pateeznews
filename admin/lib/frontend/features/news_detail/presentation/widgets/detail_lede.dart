import 'package:flutter/material.dart';

import '../../../../core/mock/home_mock_data.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/cached_image.dart';
import '../../../../shared/widgets/verified_badge.dart';

/// Hero görselin altına oturan editorial blok.
///
/// İçinde sırayla:
///   - Yazar şeridi (avatar, ad, doğrulama, sağda yazılı turuncu Takip et)
///   - Yazar altı byline: "Türkiye / Ekonomi · 7 sa" (ana sayfa kartıyla aynı dil)
///   - Meta satırı: tek satır okuma süresi + görüntüleme
///   - Kırmızı dikey vurgu çubuklu büyük başlık (in-page)
///   - Spot/lead paragrafı
class DetailLede extends StatelessWidget {
  const DetailLede({super.key, required this.article, required this.onFollow});

  final NewsArticle article;
  final VoidCallback onFollow;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        AppSpacing.xl + 4,
        AppSpacing.pageHorizontal,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AuthorRow(article: article, onFollow: onFollow),
          const SizedBox(height: AppSpacing.lg),
          _MetaStrip(article: article),
          const SizedBox(height: AppSpacing.lg),
          _HeadlineBlock(title: article.title),
          const SizedBox(height: AppSpacing.md),
          _LedeSpot(summary: article.summary),
        ],
      ),
    );
  }
}

class _AuthorRow extends StatelessWidget {
  const _AuthorRow({required this.article, required this.onFollow});

  final NewsArticle article;
  final VoidCallback onFollow;

  @override
  Widget build(BuildContext context) {
    final author = article.author;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _AuthorAvatar(author: author),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      author.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleS.copyWith(
                        color: AppColors.inkStrong,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  if (author.isVerified || author.isOfficial) ...[
                    const SizedBox(width: 4),
                    VerifiedBadge(official: author.isOfficial),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              _AuthorByline(article: article),
            ],
          ),
        ),
        _FollowTextButton(onTap: onFollow),
      ],
    );
  }
}

/// Ana sayfa news_card'ındaki "Türkiye / Ekonomi  ·  7 sa" eyebrow stiliyle
/// birebir aynı dile sahip alt yazı.
class _AuthorByline extends StatelessWidget {
  const _AuthorByline({required this.article});

  final NewsArticle article;

  @override
  Widget build(BuildContext context) {
    final region = _titleCaseLabel(article.region);
    final category = _titleCaseLabel(article.category);
    final color = AppColors.inkSoft;
    return DefaultTextStyle.merge(
      style: AppTypography.eyebrow.copyWith(
        color: color,
        fontSize: 10,
        letterSpacing: 0.45,
      ),
      child: Row(
        children: [
          Flexible(
            child: Text(
              '$region  /  $category',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 2.5,
            height: 2.5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(RelativeTime.format(article.publishedAt)),
        ],
      ),
    );
  }
}

class _AuthorAvatar extends StatelessWidget {
  const _AuthorAvatar({required this.author});

  final NewsAuthor author;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        children: [
          ClipOval(
            child: Container(
              width: 42,
              height: 42,
              color: AppColors.surfaceInk,
              child: CachedImage(
                url: author.avatarUrl,
                fit: BoxFit.cover,
                memCacheWidth: (42 * dpr).round(),
                placeholderColor: AppColors.surfaceInk,
                errorWidget: Container(
                  color: AppColors.surfaceInk,
                  alignment: Alignment.center,
                  child: Text(
                    author.name.characters.first.toUpperCase(),
                    style: AppTypography.titleM.copyWith(
                      color: AppColors.deepOcean,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: author.isOfficial
                    ? AppColors.warmHorizon
                    : AppColors.actionRed,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surface, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kutusuz, yalın "Takip et" yazısı — projedeki turuncu (`warmHorizon`)
/// ile vurgulanır; aktif olunca sönük destek tonuna geçer.
class _FollowTextButton extends StatefulWidget {
  const _FollowTextButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_FollowTextButton> createState() => _FollowTextButtonState();
}

class _FollowTextButtonState extends State<_FollowTextButton> {
  bool _following = false;

  void _handleTap() {
    setState(() => _following = !_following);
    if (_following) widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final following = _following;
    final fg = following ? AppColors.support : AppColors.warmHorizon;
    final label = following ? 'TAKİPTE' : '+ TAKİP ET';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _handleTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 220),
            style: AppTypography.eyebrow.copyWith(
              color: fg,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}

/// Sade tek satır: okuma süresi · görüntüleme.
class _MetaStrip extends StatelessWidget {
  const _MetaStrip({required this.article});

  final NewsArticle article;

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle.merge(
      style: AppTypography.meta.copyWith(
        color: AppColors.support,
        fontSize: 11.5,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
      ),
      child: Row(
        children: [
          const Icon(
            Icons.menu_book_rounded,
            size: 13,
            color: AppColors.support,
          ),
          const SizedBox(width: 5),
          Text('${article.readMinutes} dk okuma'),
          const SizedBox(width: 10),
          Container(
            width: 2.5,
            height: 2.5,
            decoration: const BoxDecoration(
              color: AppColors.placeholderSoft,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          const Icon(
            Icons.visibility_outlined,
            size: 13,
            color: AppColors.support,
          ),
          const SizedBox(width: 5),
          Text('${CountFormat.compact(article.views)} görüntüleme'),
        ],
      ),
    );
  }
}

class _HeadlineBlock extends StatelessWidget {
  const _HeadlineBlock({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 3,
          height: 28,
          margin: const EdgeInsets.only(top: 5, right: 12),
          decoration: BoxDecoration(
            color: AppColors.actionRed,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Expanded(
          child: Text(
            title,
            style: AppTypography.postTitle.copyWith(
              color: AppColors.inkStrong,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
              height: 1.1,
            ),
          ),
        ),
      ],
    );
  }
}

class _LedeSpot extends StatelessWidget {
  const _LedeSpot({required this.summary});

  final String summary;

  @override
  Widget build(BuildContext context) {
    return Text(
      summary,
      style: AppTypography.postSummary.copyWith(
        color: AppColors.inkSoft,
        height: 1.45,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Türkçe ile uyumlu title-case yardımcıları — news_card.dart ile aynı dilden.
// ─────────────────────────────────────────────────────────────────────────────

String _titleCaseLabel(String value) {
  final lower = _lowerTr(value.trim());
  if (lower.isEmpty) return lower;

  final buffer = StringBuffer();
  var capitalizeNext = true;
  for (final rune in lower.runes) {
    final char = String.fromCharCode(rune);
    if (_isWordSeparator(char)) {
      capitalizeNext = true;
      buffer.write(char);
      continue;
    }
    buffer.write(capitalizeNext ? _upperFirstTr(char) : char);
    capitalizeNext = false;
  }
  return buffer.toString();
}

String _lowerTr(String value) {
  return value.replaceAll('I', 'ı').replaceAll('İ', 'i').toLowerCase();
}

String _upperFirstTr(String value) {
  if (value == 'i') return 'İ';
  if (value == 'ı') return 'I';
  return value.toUpperCase();
}

bool _isWordSeparator(String value) {
  return value == ' ' ||
      value == '\t' ||
      value == '\n' ||
      value == '/' ||
      value == '-' ||
      value == '_' ||
      value == '.';
}
