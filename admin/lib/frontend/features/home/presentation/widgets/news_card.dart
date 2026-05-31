import 'package:flutter/material.dart';

import '../../../../core/mock/home_mock_data.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/cached_image.dart';
import '../../../../shared/widgets/social_action.dart';
import '../../../../shared/widgets/verified_badge.dart';

/// Pateeznews sosyal post kartı.
///
/// Görsel üstü yayıncı overlay'i, görsel altı editorial başlık ve özgün
/// sosyal aksiyon diliyle haber + sosyal medya hissini tek kartta birleştirir.
class NewsCard extends StatefulWidget {
  const NewsCard({super.key, required this.article, required this.onTap});

  final NewsArticle article;
  final VoidCallback onTap;

  @override
  State<NewsCard> createState() => _NewsCardState();
}

class _NewsCardState extends State<NewsCard> {
  bool _isLiked = false;
  bool _isSaved = false;
  late int _likes = widget.article.likes;

  void _toggleLike() {
    setState(() {
      if (_isLiked) {
        _isLiked = false;
        _likes--;
      } else {
        _isLiked = true;
        _likes++;
      }
    });
  }

  void _toggleSave() => setState(() => _isSaved = !_isSaved);

  @override
  Widget build(BuildContext context) {
    final article = widget.article;
    return Material(
      color: AppColors.surface,
      child: InkWell(
        onTap: widget.onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MediaStage(article: article),
            _Title(title: article.title),
            _Summary(summary: article.summary),
            _ReadStats(article: article),
            _ActionBar(
              article: article,
              isLiked: _isLiked,
              isSaved: _isSaved,
              likes: _likes,
              onLike: _toggleLike,
              onSave: _toggleSave,
            ),
            _CommentsPreview(comments: HomeMockData.samplePreviewComments),
            _CommentComposer(currentUser: HomeMockData.currentUser),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER
// ─────────────────────────────────────────────────────────────────────────────

class _HeaderOverlay extends StatelessWidget {
  const _HeaderOverlay({required this.article});

  final NewsArticle article;

  @override
  Widget build(BuildContext context) {
    final author = article.author;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Avatar(author: author, overlay: true),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        author.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleS.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
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
                _Meta(article: article, overlay: true),
              ],
            ),
          ),
          const SizedBox(width: 6),
          _IconBtn(
            icon: Icons.more_horiz_rounded,
            onTap: () {},
            semantics: 'Diğer seçenekler',
            color: Colors.white.withValues(alpha: 0.86),
            backgroundColor: Colors.black.withValues(alpha: 0.18),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.author, this.overlay = false});

  final NewsAuthor author;
  final bool overlay;

  @override
  Widget build(BuildContext context) {
    final isOfficial = author.isOfficial;
    final borderColor = overlay
        ? Colors.white.withValues(alpha: 0.78)
        : AppColors.surface;
    final fallbackColor = overlay
        ? Colors.black.withValues(alpha: 0.22)
        : AppColors.surfaceInk;
    final fallbackTextColor = overlay ? Colors.white : AppColors.deepOcean;
    return SizedBox(
      width: 46,
      height: 46,
      child: Stack(
        children: [
          ClipOval(
            child: Container(
              width: 44,
              height: 44,
              color: fallbackColor,
              child: CachedImage(
                url: author.avatarUrl,
                fit: BoxFit.cover,
                memCacheWidth: 96,
                placeholderColor: fallbackColor,
                errorWidget: Container(
                  color: fallbackColor,
                  alignment: Alignment.center,
                  child: Text(
                    _upperFirstTr(author.name.characters.first),
                    style: AppTypography.titleM.copyWith(
                      color: fallbackTextColor,
                      fontSize: 16,
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
                color: isOfficial ? AppColors.warmHorizon : AppColors.actionRed,
                shape: BoxShape.circle,
                border: Border.all(color: borderColor, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.article, this.overlay = false});

  final NewsArticle article;
  final bool overlay;

  @override
  Widget build(BuildContext context) {
    final region = _titleCaseLabel(article.region);
    final category = _titleCaseLabel(article.category);
    final color = overlay
        ? Colors.white.withValues(alpha: 0.78)
        : AppColors.support;
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

class _IconBtn extends StatelessWidget {
  const _IconBtn({
    required this.icon,
    required this.onTap,
    required this.semantics,
    this.color = AppColors.iconMuted,
    this.backgroundColor = Colors.transparent,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String semantics;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semantics,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TITLE & SUMMARY
// ─────────────────────────────────────────────────────────────────────────────

class _Title extends StatelessWidget {
  const _Title({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final headlineColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : const Color(0xFF101820);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        14,
        AppSpacing.pageHorizontal,
        AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 22,
            margin: const EdgeInsets.only(top: 4, right: 10),
            decoration: BoxDecoration(
              color: AppColors.actionRed,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: Text(
              title,
              style: AppTypography.display.copyWith(
                color: headlineColor,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
                height: 1.08,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.summary});

  final String summary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageHorizontal,
      ),
      child: Text(
        summary,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.body.copyWith(
          color: AppColors.inkSoft,
          fontSize: 15,
          height: 1.5,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// READ STATS
// ─────────────────────────────────────────────────────────────────────────────

class _ReadStats extends StatelessWidget {
  const _ReadStats({required this.article});

  final NewsArticle article;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        AppSpacing.sm,
        AppSpacing.pageHorizontal,
        0,
      ),
      child: DefaultTextStyle.merge(
        style: AppTypography.meta.copyWith(
          color: AppColors.placeholderSoft,
          fontSize: 11.5,
          letterSpacing: 0.1,
          fontWeight: FontWeight.w500,
        ),
        child: Row(
          children: [
            const Icon(
              Icons.menu_book_rounded,
              size: 13,
              color: AppColors.placeholderSoft,
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
              color: AppColors.placeholderSoft,
            ),
            const SizedBox(width: 5),
            Text('${CountFormat.compact(article.views)} görüntüleme'),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COVER
// ─────────────────────────────────────────────────────────────────────────────

class _MediaStage extends StatelessWidget {
  const _MediaStage({required this.article});

  final NewsArticle article;

  static const double _fallbackAspectRatio = 3 / 2;

  /// Görselin en-boy oranını URL'den okur (picsum: `.../<genişlik>/<yükseklik>`).
  /// Oran baştan bilindiği için kart, görsel inerken yeniden boyutlanmaz —
  /// kaydırma sırasında içerik zıplaması (layout shift) sıfırlanır. Çözülemezse
  /// güvenli 3/2'ye düşer. Üretimde bu oran backend'den gelmeli.
  double _aspectRatioFromUrl(String url) {
    final segments = Uri.tryParse(url)?.pathSegments;
    if (segments != null && segments.length >= 2) {
      final h = int.tryParse(segments[segments.length - 1]);
      final w = int.tryParse(segments[segments.length - 2]);
      if (w != null && h != null && w > 0 && h > 0) return w / h;
    }
    return _fallbackAspectRatio;
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      key: const ValueKey<String>('news-card-cover-stage'),
      child: AspectRatio(
        aspectRatio: _aspectRatioFromUrl(article.imageUrl),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _CoverImage(imageUrl: article.imageUrl),
            const _MediaTopScrim(),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _HeaderOverlay(article: article),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverImage extends StatelessWidget {
  const _CoverImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return CachedImage(
      url: imageUrl,
      fit: BoxFit.contain,
      memCacheWidth: _imageCacheWidth(context),
      errorWidget: Container(
        color: AppColors.surfaceInk,
        alignment: Alignment.center,
        child: const Icon(
          Icons.image_outlined,
          color: AppColors.support,
          size: 32,
        ),
      ),
    );
  }
}

int? _imageCacheWidth(BuildContext context) {
  final dpr = MediaQuery.devicePixelRatioOf(context);
  final width =
      MediaQuery.sizeOf(context).width - AppSpacing.pageHorizontal * 2;
  final cacheWidth = (width * dpr).round();
  return cacheWidth > 0 ? cacheWidth : null;
}

class _MediaTopScrim extends StatelessWidget {
  const _MediaTopScrim();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xA6000000), Color(0x52000000), Color(0x00000000)],
          stops: [0, 0.36, 0.74],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTION BAR
// ─────────────────────────────────────────────────────────────────────────────

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.article,
    required this.isLiked,
    required this.isSaved,
    required this.likes,
    required this.onLike,
    required this.onSave,
  });

  final NewsArticle article;
  final bool isLiked;
  final bool isSaved;
  final int likes;
  final VoidCallback onLike;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal - 6,
        AppSpacing.sm,
        AppSpacing.pageHorizontal - 6,
        AppSpacing.lg,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 350;
          final spacing = compact ? 2.0 : 6.0;
          return Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: spacing,
                  runSpacing: 2,
                  children: [
                    SocialAction(
                      glyph: PateezSocialGlyph.heart,
                      isActive: isLiked,
                      activeColor: AppColors.actionRed,
                      semanticLabel: 'Beğen',
                      count: likes,
                      onTap: onLike,
                      iconSize: 26,
                    ),
                    SocialAction(
                      glyph: PateezSocialGlyph.conversation,
                      isActive: false,
                      activeColor: AppColors.deepOcean,
                      semanticLabel: 'Yorumlar',
                      count: article.comments,
                      onTap: () {},
                      iconSize: 26,
                    ),
                    SocialAction(
                      glyph: PateezSocialGlyph.orbitShare,
                      isActive: false,
                      activeColor: AppColors.warmHorizon,
                      semanticLabel: 'Paylaş',
                      count: article.shares,
                      onTap: () {},
                      iconSize: 26,
                    ),
                  ],
                ),
              ),
              SocialAction(
                glyph: PateezSocialGlyph.ribbon,
                isActive: isSaved,
                activeColor: AppColors.warmHorizon,
                semanticLabel: 'Kaydet',
                onTap: onSave,
                iconSize: 28,
              ),
            ],
          );
        },
      ),
    );
  }
}

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

// ─────────────────────────────────────────────────────────────────────────────
// COMMENTS PREVIEW + COMPOSER
// ─────────────────────────────────────────────────────────────────────────────

class _CommentsPreview extends StatelessWidget {
  const _CommentsPreview({required this.comments});

  final List<NewsComment> comments;

  @override
  Widget build(BuildContext context) {
    if (comments.isEmpty) return const SizedBox.shrink();
    final visible = comments.take(2).toList(growable: false);
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.softLine, width: 1)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        AppSpacing.md,
        AppSpacing.pageHorizontal,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < visible.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.md),
            _CommentRow(comment: visible[i]),
            if (visible[i].replies.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Padding(
                padding: const EdgeInsets.only(left: 36),
                child: _CommentRow(
                  comment: visible[i].replies.first,
                  isReply: true,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _CommentRow extends StatelessWidget {
  const _CommentRow({required this.comment, this.isReply = false});

  final NewsComment comment;
  final bool isReply;

  @override
  Widget build(BuildContext context) {
    final author = comment.author;
    final avatarSize = isReply ? 22.0 : 26.0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MiniAvatar(author: author, size: avatarSize),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      author.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleS.copyWith(
                        fontSize: isReply ? 11.5 : 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                        height: 1.2,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  if (author.isVerified || author.isOfficial) ...[
                    const SizedBox(width: 4),
                    VerifiedBadge(
                      official: author.isOfficial,
                      size: isReply ? 10 : 11,
                    ),
                  ],
                  const SizedBox(width: 6),
                  Text(
                    '·',
                    style: AppTypography.meta.copyWith(
                      color: AppColors.support,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    RelativeTime.format(comment.publishedAt),
                    style: AppTypography.meta.copyWith(
                      color: AppColors.support,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                comment.body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.inkSoft,
                  fontSize: isReply ? 12 : 12.5,
                  height: 1.4,
                ),
              ),
              if (!isReply) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.thumb_up_outlined,
                      size: 12,
                      color: AppColors.support,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      CountFormat.compact(comment.likes),
                      style: AppTypography.meta.copyWith(
                        color: AppColors.support,
                        fontSize: 10.5,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      'Yanıtla',
                      style: AppTypography.meta.copyWith(
                        color: AppColors.inkSoft,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniAvatar extends StatelessWidget {
  const _MiniAvatar({required this.author, required this.size});

  final NewsAuthor author;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return ClipOval(
      child: Container(
        width: size,
        height: size,
        color: AppColors.surfaceInk,
        child: CachedImage(
          url: author.avatarUrl,
          fit: BoxFit.cover,
          memCacheWidth: (size * dpr).round(),
          placeholderColor: AppColors.surfaceInk,
          errorWidget: Container(
            color: AppColors.surfaceInk,
            alignment: Alignment.center,
            child: Text(
              author.name.characters.first.toUpperCase(),
              style: AppTypography.titleS.copyWith(
                color: AppColors.deepOcean,
                fontSize: size * 0.42,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CommentComposer extends StatefulWidget {
  const _CommentComposer({required this.currentUser});

  final NewsAuthor currentUser;

  @override
  State<_CommentComposer> createState() => _CommentComposerState();
}

class _CommentComposerState extends State<_CommentComposer> {
  final TextEditingController _controller = TextEditingController();
  bool _canSend = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChange);
  }

  void _onChange() {
    final canSend = _controller.text.trim().isNotEmpty;
    if (canSend != _canSend) {
      setState(() => _canSend = canSend);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onChange);
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    if (!_canSend) return;
    _controller.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.softLine, width: 1)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        AppSpacing.sm + 2,
        AppSpacing.pageHorizontal - 6,
        AppSpacing.sm + 2,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _MiniAvatar(author: widget.currentUser, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _controller,
              cursorColor: AppColors.actionRed,
              cursorWidth: 1.2,
              maxLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              style: AppTypography.bodySmall.copyWith(
                fontSize: 13,
                color: AppColors.ink,
                height: 1.3,
              ),
              decoration: InputDecoration(
                hintText: 'Yorumunuzu ekleyin...',
                hintStyle: AppTypography.bodySmall.copyWith(
                  color: AppColors.support,
                  fontSize: 13,
                  height: 1.3,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                filled: false,
              ),
            ),
          ),
          const SizedBox(width: 4),
          TextButton(
            onPressed: _canSend ? _send : null,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.actionRed,
              disabledForegroundColor: AppColors.support,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
            child: const Text(
              'Gönder',
              style: TextStyle(
                fontFamily: 'PateezInter',
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
