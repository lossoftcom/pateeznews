import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../../core/mock/home_mock_data.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/cached_image.dart';
import '../../../../shared/widgets/social_action.dart';
import '../../../../shared/widgets/verified_badge.dart';
import '../../../shell/data/app_shell_repository.dart';
import 'news_audio_card.dart';
import 'news_video_player.dart';

/// Pateeznews sosyal post kartı.
///
/// Görsel üstü yayıncı overlay'i, görsel altı editorial başlık ve özgün
/// sosyal aksiyon diliyle haber + sosyal medya hissini tek kartta birleştirir.
class NewsCard extends StatefulWidget {
  const NewsCard({
    super.key,
    required this.article,
    required this.onTap,
    this.categoryTrail = const [],
    this.videoFeedArticles = const [],
    this.shellSettings = const AppShellSettings.empty(),
    this.onFullscreenVideoExit,
  });

  final NewsArticle article;
  final VoidCallback onTap;
  final List<String> categoryTrail;
  final List<NewsArticle> videoFeedArticles;
  final AppShellSettings shellSettings;
  final VoidCallback? onFullscreenVideoExit;

  @override
  State<NewsCard> createState() => _NewsCardState();
}

class _NewsCardState extends State<NewsCard> {
  bool _isLiked = false;
  bool _isDisliked = false;
  bool _isSaved = false;
  late int _likes = widget.article.likes;
  late int _dislikes = widget.article.dislikes;
  double? _resolvedImageAspectRatio;
  ImageStream? _pendingImageStream;
  ImageStreamListener? _pendingImageListener;

  @override
  void initState() {
    super.initState();
    _resolveImageAspectRatio(widget.article);
  }

  @override
  void didUpdateWidget(covariant NewsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.article.imageUrl != widget.article.imageUrl ||
        oldWidget.article.imageAspectRatio != widget.article.imageAspectRatio) {
      _removeImageListener();
      _resolvedImageAspectRatio = null;
      _resolveImageAspectRatio(widget.article);
    }
    if (oldWidget.article.id != widget.article.id) {
      _likes = widget.article.likes;
      _dislikes = widget.article.dislikes;
      _isLiked = false;
      _isDisliked = false;
      _isSaved = false;
    }
  }

  @override
  void dispose() {
    _removeImageListener();
    super.dispose();
  }

  void _toggleLike() {
    setState(() {
      if (_isLiked) {
        _isLiked = false;
        _likes--;
      } else {
        if (_isDisliked) {
          _isDisliked = false;
          _dislikes--;
        }
        _isLiked = true;
        _likes++;
      }
    });
  }

  void _toggleDislike() {
    setState(() {
      if (_isDisliked) {
        _isDisliked = false;
        _dislikes--;
      } else {
        if (_isLiked) {
          _isLiked = false;
          _likes--;
        }
        _isDisliked = true;
        _dislikes++;
      }
    });
  }

  void _toggleSave() => setState(() => _isSaved = !_isSaved);

  void _resolveImageAspectRatio(NewsArticle article) {
    final knownRatio = article.imageAspectRatio;
    if (knownRatio != null && knownRatio.isFinite && knownRatio > 0) {
      _resolvedImageAspectRatio = knownRatio;
      return;
    }

    final parsedRatio = _parseImageAspectRatioFromUrl(article.imageUrl);
    if (parsedRatio != null) {
      _resolvedImageAspectRatio = parsedRatio;
      return;
    }

    final imageUrl = article.imageUrl.trim();
    if (imageUrl.isEmpty) return;

    final stream = CachedNetworkImageProvider(
      imageUrl,
    ).resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener((image, _) {
      _removeImageListener();
      final width = image.image.width;
      final height = image.image.height;
      if (!mounted || width <= 0 || height <= 0) return;
      setState(() => _resolvedImageAspectRatio = width / height);
    }, onError: (_, _) => _removeImageListener());
    _pendingImageStream = stream;
    _pendingImageListener = listener;
    stream.addListener(listener);
  }

  void _removeImageListener() {
    final stream = _pendingImageStream;
    final listener = _pendingImageListener;
    if (stream != null && listener != null) {
      stream.removeListener(listener);
    }
    _pendingImageStream = null;
    _pendingImageListener = null;
  }

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
            _MediaStage(
              article: article,
              aspectRatio: _resolvedImageAspectRatio,
              categoryTrail: widget.categoryTrail,
              videoFeedArticles: widget.videoFeedArticles,
              shellSettings: widget.shellSettings,
              onFullscreenVideoExit: widget.onFullscreenVideoExit,
            ),
            _Title(title: article.title),
            _Summary(summary: article.summary),
            _ReadStats(article: article),
            _ActionBar(
              article: article,
              isLiked: _isLiked,
              isDisliked: _isDisliked,
              isSaved: _isSaved,
              likes: _likes,
              dislikes: _dislikes,
              onLike: _toggleLike,
              onDislike: _toggleDislike,
              onSave: _toggleSave,
            ),
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
  const _HeaderOverlay({required this.article, required this.categoryTrail});

  final NewsArticle article;
  final List<String> categoryTrail;

  @override
  Widget build(BuildContext context) {
    final author = article.author;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 11, 6, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _Avatar(author: author),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _NameLine(author: author),
                const SizedBox(height: 3),
                _Meta(article: article, categoryTrail: categoryTrail),
              ],
            ),
          ),
          const SizedBox(width: 4),
          _IconBtn(
            icon: Symbols.more_horiz_rounded,
            onTap: () {},
            semantics: 'Diğer seçenekler',
            color: Colors.white,
          ),
        ],
      ),
    );
  }
}

/// Görsel üstünde yayıncı satırı: "Pateez Niğde" + onay rozeti + @kullanıcı adı.
/// Kutu yok; beyaz metin + hafif gölge ile (üstteki degrade sayesinde) her
/// görselde net okunur — Instagram Reels başlığı dilinde.
class _NameLine extends StatelessWidget {
  const _NameLine({required this.author});

  final NewsAuthor author;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            author.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.meta.copyWith(
              fontFamily: AppTypography.primaryFamily,
              color: Colors.white,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.1,
              height: 1.1,
              shadows: _mediaTextShadows,
            ),
          ),
        ),
        if (author.isVerified || author.isOfficial) ...[
          const SizedBox(width: 4),
          VerifiedBadge(official: author.isOfficial, size: 13),
        ],
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            _handleFor(author),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.meta.copyWith(
              fontFamily: AppTypography.primaryFamily,
              color: Colors.white.withValues(alpha: 0.80),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
              height: 1.1,
              shadows: _mediaTextShadows,
            ),
          ),
        ),
      ],
    );
  }
}

/// Meta satırındaki ayraç noktası (beyaz, görsel üstü).
class _MetaDot extends StatelessWidget {
  const _MetaDot();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Container(
        width: 3,
        height: 3,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.62),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// Görselin üstündeki yumuşak koyu degrade. Başlık, görsel ne kadar karışık
/// olursa olsun okunur kalsın diye eklenir (Instagram Reels üst degradesi gibi).
class _HeaderScrim extends StatelessWidget {
  const _HeaderScrim();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 104,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x75000000), Color(0x1A000000), Color(0x00000000)],
          stops: [0, 0.6, 1],
        ),
      ),
    );
  }
}

/// Avatar — çevresinde projenin marka renklerinden (amber → kırmızı → deepOcean)
/// degrade halka + ince beyaz boşluk. Instagram'daki halkanın aynısı ama
/// Pateez renklerinde; görsel ne olursa olsun avatar net "patlar".
class _Avatar extends StatelessWidget {
  const _Avatar({required this.author});

  final NewsAuthor author;

  @override
  Widget build(BuildContext context) {
    final initial = _avatarInitial(author.name);
    final fallback = Container(
      color: AppColors.surfaceInk,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: AppTypography.titleM.copyWith(
          color: AppColors.deepOcean,
          fontSize: 16,
        ),
      ),
    );
    return Container(
      width: 48,
      height: 48,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(
          colors: [
            AppColors.warmHorizon,
            AppColors.actionRed,
            AppColors.deepOcean,
            AppColors.actionRed,
            AppColors.warmHorizon,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(2.5),
        child: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: ClipOval(
              child: author.avatarUrl.trim().isEmpty
                  ? fallback
                  : CachedImage(
                      url: author.avatarUrl,
                      fit: BoxFit.cover,
                      memCacheWidth: 120,
                      placeholderColor: AppColors.surfaceInk,
                      errorWidget: fallback,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Kategori · tarih · saat tek satırda. "Saat" kelimesi yerine saat ikonu.
/// FittedBox(scaleDown) sayesinde dar ekranda küçülerek tek satırda kalır —
/// asla alt satıra inmez, asla kesilmez (full responsive).
class _Meta extends StatelessWidget {
  const _Meta({required this.article, this.categoryTrail = const []});

  final NewsArticle article;
  final List<String> categoryTrail;

  @override
  Widget build(BuildContext context) {
    final label = _categoryLabel(categoryTrail, article);
    final date = _formatCardDate(article.publishedAt);
    final time = _formatCardClock(article.publishedAt);
    final style = AppTypography.meta.copyWith(
      fontFamily: AppTypography.primaryFamily,
      color: Colors.white.withValues(alpha: 0.95),
      fontSize: 11.5,
      letterSpacing: 0.1,
      fontWeight: FontWeight.w600,
      height: 1.1,
      shadows: _mediaTextShadows,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: constraints.maxWidth,
          child: FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (label.isNotEmpty) ...[
                  Text(label, maxLines: 1, style: style),
                  const _MetaDot(),
                ],
                Text(date, maxLines: 1, style: style),
                const SizedBox(width: 7),
                Icon(
                  Symbols.time_fill,
                  size: 12.5,
                  color: Colors.white.withValues(alpha: 0.92),
                  shadows: _mediaTextShadows,
                ),
                const SizedBox(width: 3),
                Text(time, maxLines: 1, style: style),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({
    required this.icon,
    required this.onTap,
    required this.semantics,
    this.color = AppColors.iconMuted,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String semantics;
  final Color color;

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
            child: Icon(
              icon,
              size: 22,
              color: color,
              shadows: _mediaTextShadows,
            ),
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
              style: AppTypography.mobileNewsCardTitle.copyWith(
                color: headlineColor,
                letterSpacing: 0,
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
        style: AppTypography.mobileNewsCardSummary.copyWith(
          color: AppColors.inkSoft,
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
              Symbols.menu_book_rounded,
              size: 13,
              color: AppColors.placeholderSoft,
            ),
            const SizedBox(width: 5),
            Text('${_safeReadMinutes(article.readMinutes)} dk okuma'),
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
              Symbols.visibility_outlined,
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
  const _MediaStage({
    required this.article,
    required this.aspectRatio,
    required this.categoryTrail,
    required this.videoFeedArticles,
    required this.shellSettings,
    required this.onFullscreenVideoExit,
  });

  final NewsArticle article;
  final double? aspectRatio;
  final List<String> categoryTrail;
  final List<NewsArticle> videoFeedArticles;
  final AppShellSettings shellSettings;
  final VoidCallback? onFullscreenVideoExit;

  static const double _fallbackAspectRatio = 3 / 2;

  @override
  Widget build(BuildContext context) {
    if (article.videoUrl.trim().isNotEmpty) {
      return ClipRRect(
        key: const ValueKey<String>('news-card-cover-stage'),
        child: NewsVideoPlayer(
          url: article.videoUrl,
          poster: article.imageUrl,
          fullscreenLogoUrl: _fullscreenLogoUrl,
          fullscreenFeed: _videoFeedItems(),
          onFullscreenVideoExit: _handleFullscreenVideoExit,
          topOverlay: Stack(
            fit: StackFit.expand,
            children: [
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: IgnorePointer(child: _HeaderScrim()),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _HeaderOverlay(
                  article: article,
                  categoryTrail: categoryTrail,
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (article.audioUrl.trim().isNotEmpty) {
      return ClipRRect(
        key: const ValueKey<String>('news-card-cover-stage'),
        child: Stack(
          children: [
            NewsAudioCard(url: article.audioUrl, coverUrl: article.imageUrl),
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(child: _HeaderScrim()),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _HeaderOverlay(
                article: article,
                categoryTrail: categoryTrail,
              ),
            ),
          ],
        ),
      );
    }
    return ClipRRect(
      key: const ValueKey<String>('news-card-cover-stage'),
      child: AspectRatio(
        aspectRatio: aspectRatio ?? _fallbackAspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (article.sliderImages.isNotEmpty)
              _MediaSlider(images: article.sliderImages)
            else
              _CoverImage(imageUrl: article.imageUrl),
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(child: _HeaderScrim()),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _HeaderOverlay(
                article: article,
                categoryTrail: categoryTrail,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<NewsVideoFeedItem> _videoFeedItems() {
    final source = videoFeedArticles.isEmpty
        ? <NewsArticle>[article]
        : videoFeedArticles;
    return source
        .where((item) => item.videoUrl.trim().isNotEmpty)
        .map(
          (item) => NewsVideoFeedItem(
            url: item.videoUrl,
            poster: item.imageUrl,
            slug: item.slug,
            publishedAt: item.publishedAt,
            title: item.title,
            author: item.author,
            region: item.region,
            category: item.category,
            categoryTrail: item.id == article.id
                ? categoryTrail
                : _fallbackCategoryTrail(item),
            likes: item.likes,
            dislikes: item.dislikes,
            comments: item.comments,
            shares: item.shares,
            saves: item.saves,
            fullscreenLogoUrl: _fullscreenLogoUrl,
            topOverlay: Stack(
              fit: StackFit.expand,
              children: [
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(child: _HeaderScrim()),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _HeaderOverlay(
                    article: item,
                    categoryTrail: item.id == article.id
                        ? categoryTrail
                        : _fallbackCategoryTrail(item),
                  ),
                ),
              ],
            ),
          ),
        )
        .toList(growable: false);
  }

  void _handleFullscreenVideoExit(NewsVideoFeedItem _) {
    onFullscreenVideoExit?.call();
  }

  List<String> _fallbackCategoryTrail(NewsArticle item) {
    final category = item.category.trim();
    return category.isEmpty ? const [] : <String>[category];
  }

  String get _fullscreenLogoUrl {
    return shellSettings.displayLogoUrl;
  }
}

class _CoverImage extends StatelessWidget {
  const _CoverImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: AppColors.surfaceInk,
      alignment: Alignment.center,
      child: const Icon(
        Symbols.image_outlined,
        color: AppColors.support,
        size: 32,
      ),
    );
    if (imageUrl.trim().isEmpty) return fallback;
    return CachedImage(
      url: imageUrl,
      fit: BoxFit.contain,
      memCacheWidth: _imageCacheWidth(context),
      errorWidget: Container(
        color: AppColors.surfaceInk,
        alignment: Alignment.center,
        child: const Icon(
          Symbols.image_outlined,
          color: AppColors.support,
          size: 32,
        ),
      ),
    );
  }
}

/// Ana sayfa kartında "slider" bloğu seçiliyse görselleri yatay, akıcı bir
/// galeride gösterir. Görseller tıpkı normal kapak gibi (BoxFit.contain) tam
/// genişlikte ve tam görünür; yükseklik kartın en-boy oranından gelir. Altta
/// animasyonlu, şık bir sayfa göstergesi (nokta) bulunur.
class _MediaSlider extends StatefulWidget {
  const _MediaSlider({required this.images});

  final List<String> images;

  @override
  State<_MediaSlider> createState() => _MediaSliderState();
}

class _MediaSliderState extends State<_MediaSlider> {
  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.images;
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _controller,
          physics: const BouncingScrollPhysics(),
          itemCount: images.length,
          onPageChanged: (i) {
            if (mounted) setState(() => _index = i);
          },
          itemBuilder: (context, i) => CachedImage(
            url: images[i],
            fit: BoxFit.contain,
            memCacheWidth: _imageCacheWidth(context),
            errorWidget: Container(
              color: AppColors.surfaceInk,
              alignment: Alignment.center,
              child: const Icon(
                Symbols.image_outlined,
                color: AppColors.support,
                size: 32,
              ),
            ),
          ),
        ),
        if (images.length > 1)
          Positioned(
            left: 0,
            right: 0,
            bottom: 10,
            child: IgnorePointer(
              child: Center(
                child: _SliderDots(count: images.length, index: _index),
              ),
            ),
          ),
      ],
    );
  }
}

class _SliderDots extends StatelessWidget {
  const _SliderDots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.30),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(width: 5),
            AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              width: i == index ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: i == index
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ],
        ],
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

// ─────────────────────────────────────────────────────────────────────────────
// ACTION BAR
// ─────────────────────────────────────────────────────────────────────────────

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.article,
    required this.isLiked,
    required this.isDisliked,
    required this.isSaved,
    required this.likes,
    required this.dislikes,
    required this.onLike,
    required this.onDislike,
    required this.onSave,
  });

  final NewsArticle article;
  final bool isLiked;
  final bool isDisliked;
  final bool isSaved;
  final int likes;
  final int dislikes;
  final VoidCallback onLike;
  final VoidCallback onDislike;
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
                      glyph: PateezSocialGlyph.sparkUp,
                      isActive: isLiked,
                      activeColor: AppColors.deepOcean,
                      semanticLabel: 'Beğen',
                      count: likes,
                      onTap: onLike,
                      iconSize: 23,
                    ),
                    SocialAction(
                      glyph: PateezSocialGlyph.sparkDown,
                      isActive: isDisliked,
                      activeColor: AppColors.actionRed,
                      semanticLabel: 'Beğenme',
                      count: dislikes,
                      onTap: onDislike,
                      iconSize: 23,
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SocialAction(
                    glyph: PateezSocialGlyph.ribbon,
                    isActive: isSaved,
                    activeColor: AppColors.warmHorizon,
                    semanticLabel: 'Kaydet',
                    onTap: onSave,
                    iconSize: 28,
                  ),
                ],
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

int _safeReadMinutes(int value) => value < 1 ? 1 : value;

String _categoryLabel(List<String> categoryTrail, NewsArticle article) {
  final source = categoryTrail.isNotEmpty
      ? categoryTrail
      : [article.region, article.category];
  return source
      .map(_titleCaseLabel)
      .where((value) => value.trim().isNotEmpty)
      .join(' / ');
}

String _formatCardDate(DateTime value) {
  final date = value.toUtc().add(const Duration(hours: 3));
  final day = date.day;
  final month = _turkishMonths[date.month - 1];
  final year = date.year.toString().padLeft(4, '0');
  final weekday = _turkishWeekdays[date.weekday - 1];
  return '$day $month $year $weekday';
}

String _formatCardClock(DateTime value) {
  final date = value.toUtc().add(const Duration(hours: 3));
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

/// Yayıncı adının yanında gösterilecek kullanıcı adı (@pateez gibi).
/// Modelde handle varsa onu, yoksa addan türetir (ilk kelime, Türkçe duyarlı).
String _handleFor(NewsAuthor author) {
  final handle = author.handle?.trim() ?? '';
  if (handle.isNotEmpty) {
    return handle.startsWith('@') ? handle : '@$handle';
  }
  final first = author.name.trim().split(RegExp(r'\s+')).first;
  final slug = _lowerTr(first).replaceAll(RegExp(r'[^0-9a-zçğıiöşü]'), '');
  return slug.isEmpty ? '@pateez' : '@$slug';
}

double? _parseImageAspectRatioFromUrl(String url) {
  final segments = Uri.tryParse(url)?.pathSegments;
  if (segments != null && segments.length >= 2) {
    final h = int.tryParse(segments[segments.length - 1]);
    final w = int.tryParse(segments[segments.length - 2]);
    if (w != null && h != null && w > 0 && h > 0) return w / h;
  }
  return null;
}

/// Görsel üstü beyaz yazıların arkasındaki yumuşak "siyah fon ışığı" (backlight).
/// Sert tek gölge değil; offset'siz iki katman → yazının çevresine yayılan zarif
/// karanlık hale. Görsel ne olursa olsun yazı okunur, çok modern ve abartısız
/// (Instagram/Apple'ın fotoğraf üstü beyaz yazı dili).
const _mediaTextShadows = [
  Shadow(color: Color(0x80000000), blurRadius: 6),
  Shadow(color: Color(0x4D000000), blurRadius: 16),
];

const _turkishMonths = [
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

const _turkishWeekdays = [
  'Pazartesi',
  'Salı',
  'Çarşamba',
  'Perşembe',
  'Cuma',
  'Cumartesi',
  'Pazar',
];

String _avatarInitial(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return 'P';
  return _upperFirstTr(trimmed.characters.first);
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
