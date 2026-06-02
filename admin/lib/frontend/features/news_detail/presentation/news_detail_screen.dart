import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/mock/home_mock_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/cached_image.dart';
import '../../../shared/widgets/social_action.dart';
import '../data/news_detail_mock.dart';
import 'widgets/detail_app_bar.dart';
import 'widgets/detail_body.dart';
import 'widgets/detail_comments.dart';
import 'widgets/detail_floating_dock.dart';
import 'widgets/detail_lede.dart';
import 'widgets/detail_reactions.dart';
import 'widgets/detail_share_bar.dart';

/// Pateeznews haber detay sayfası.
///
/// Yapı:
///   - Üstte parallax hero görsel + sticky transparan app bar.
///   - Beyaz yüzeyde editorial başlık, spot, gövde ve pull-quote.
///   - Tepki şeridi, paylaşım barı ve yorum bölümü.
///   - Yorumlardan sonra aynı stilde tam haber bloğu devam eder; sticky app bar
///     ve okuma çizgisi aktif haber bölümüne göre güncellenir.
///
/// Tasarım, ana sayfanın 4px keskin radius dilini, action red vurgularını
/// ve PateezInter tipografisini korur.
class NewsDetailScreen extends StatefulWidget {
  const NewsDetailScreen({
    super.key,
    required this.articles,
    required this.initialIndex,
  });

  /// Detay ekranı, ana sayfa akışını taşır; "sonraki haber" deneyimi bu
  /// listede sırayla ilerler.
  final List<NewsArticle> articles;

  /// Hangi haberden başlanacak.
  final int initialIndex;

  @override
  State<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends State<NewsDetailScreen> {
  late ScrollController _scrollController;
  late List<NewsArticle> _articleSequence;
  late List<GlobalKey> _articleKeys;

  // Scroll'a bağlı UI durumu artık setState ile değil; bu notifier'larla
  // yönetiliyor. Böylece kaydırma sırasında haber listesi yeniden çizilmez —
  // yalnızca dinleyen küçük parçalar (app bar başlığı, okuma çizgisi, status
  // bar overlay) güncellenir.
  final ValueNotifier<int> _activeArticleIndex = ValueNotifier<int>(0);
  final ValueNotifier<double> _readingProgress = ValueNotifier<double>(0);
  final ValueNotifier<bool> _usesLightOverlay = ValueNotifier<bool>(false);
  double _scrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _buildArticleSequence();
    _scrollController = ScrollController()..addListener(_onScroll);
    _scheduleInitialSync();
  }

  @override
  void didUpdateWidget(covariant NewsDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.articles != widget.articles ||
        oldWidget.initialIndex != widget.initialIndex) {
      _buildArticleSequence();
      _scheduleInitialSync();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _activeArticleIndex.dispose();
    _readingProgress.dispose();
    _usesLightOverlay.dispose();
    super.dispose();
  }

  void _buildArticleSequence() {
    if (widget.articles.isEmpty) {
      _articleSequence = const [];
      _articleKeys = const [];
      _activeArticleIndex.value = 0;
      return;
    }

    final start = widget.initialIndex.clamp(0, widget.articles.length - 1);
    _articleSequence = List<NewsArticle>.generate(
      widget.articles.length,
      (i) => widget.articles[(start + i) % widget.articles.length],
      growable: false,
    );
    _articleKeys = List<GlobalKey>.generate(
      _articleSequence.length,
      (i) => GlobalKey(debugLabel: 'detail-article-$i'),
      growable: false,
    );
    _activeArticleIndex.value = 0;
    _readingProgress.value = 0;
    _usesLightOverlay.value = false;
    _scrollOffset = 0;
  }

  void _onScroll() {
    _syncReadingState();
  }

  /// İlk yerleşimden sonra (ve haber sırası değişince) tek seferlik senkron —
  /// kullanıcı hiç kaydırmadan da app bar başlığı ve okuma durumu doğru
  /// başlasın diye.
  void _scheduleInitialSync() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncReadingState();
    });
  }

  /// Aktif haberi, okuma ilerlemesini ve status bar overlay'ini hesaplar.
  ///
  /// Ölçüm yalnızca o an **ekranda inşa edilmiş** (lazy) bölümler üzerinden,
  /// canlı scroll konumundan yapılır; tüm feed'i baştan ölçmez. Böylece maliyet
  /// feed büyüse de görünen birkaç bölümle sınırlı kalır.
  void _syncReadingState() {
    if (!mounted || !_scrollController.hasClients) return;

    final scrollOffset = _scrollController.offset;
    _scrollOffset = scrollOffset;
    _usesLightOverlay.value = scrollOffset > 120;

    // App bar'ın hemen altındaki "okuma çizgisi" (ekran koordinatı).
    final anchor = MediaQuery.viewPaddingOf(context).top + 54;

    int? activeIndex;
    var progress = 0.0;
    int? firstBuiltIndex;
    var firstBuiltBelowAnchor = false;

    for (var i = 0; i < _articleKeys.length; i++) {
      final sectionContext = _articleKeys[i].currentContext;
      if (sectionContext == null) continue; // lazy: henüz inşa edilmedi
      final box = sectionContext.findRenderObject() as RenderBox?;
      if (box == null || !box.attached || !box.hasSize) continue;

      final top = box.localToGlobal(Offset.zero).dy;
      final height = box.size.height;
      if (height <= 0) continue;
      final bottom = top + height;

      if (firstBuiltIndex == null) {
        firstBuiltIndex = i;
        firstBuiltBelowAnchor = top > anchor;
      }

      if (top <= anchor && bottom > anchor) {
        // Anchor bu bölümün içinde → aktif bölüm + okuma ilerlemesi.
        activeIndex = i;
        final readable = (height - anchor).clamp(1.0, double.infinity);
        progress = (-top / readable).clamp(0.0, 1.0);
        break;
      } else if (bottom <= anchor) {
        // Bölüm tamamen anchor'ın üstünde kaldı → okunmuş say.
        activeIndex = i;
        progress = 1.0;
      }
    }

    if (activeIndex == null) {
      // Anchor ilk bölümün de üstünde (sayfanın en tepesi / overscroll).
      activeIndex = firstBuiltIndex ?? 0;
      if (firstBuiltBelowAnchor) progress = 0.0;
    }

    _activeArticleIndex.value = activeIndex;
    _readingProgress.value = progress;
  }

  /// Sağ üst floating dock'un belirme/ kaybolma ilerlemesi (0-1).
  /// App bar saydam → opak geçişiyle senkron çalışır.
  double _dockProgressFor(double scrollOffset) {
    const start = 90.0;
    const end = 230.0;
    return ((scrollOffset - start) / (end - start)).clamp(0.0, 1.0);
  }

  double get _currentScrollOffset {
    return _scrollController.hasClients
        ? _scrollController.offset
        : _scrollOffset;
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.deepOcean,
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(4)),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    if (_articleSequence.isEmpty) {
      return const Scaffold(backgroundColor: AppColors.canvas);
    }

    // NOT: Bu build yalnızca haber sırası değişince çalışır, kaydırma sırasında
    // değil. Scroll'a bağlı parçalar aşağıda kendi notifier'larını dinler; bu
    // yüzden kaydırırken haber listesi (_DetailContent) asla yeniden çizilmez.
    return ValueListenableBuilder<bool>(
      valueListenable: _usesLightOverlay,
      builder: (context, light, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: light ? AppTheme.lightOverlay : AppTheme.darkOverlay,
        child: child!,
      ),
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        body: Stack(
          children: [
            _DetailContent(
              key: ValueKey<String>(
                'detail-feed-${_articleSequence.first.id}-${_articleSequence.length}',
              ),
              scrollController: _scrollController,
              articles: _articleSequence,
              articleKeys: _articleKeys,
              onLike: () => _showMessage('Beğenildi.'),
              onComment: () =>
                  _showMessage('Yorumlar bölümüne yönlendiriliyor.'),
              onShare: () => _showMessage('Paylaşım menüsü açıldı.'),
              onSave: () => _showMessage('Haber kaydedildi.'),
              onFollow: () => _showMessage('Yazar takip ediliyor.'),
              onAllComments: () =>
                  _showMessage('Tüm yorumlar yakında açılacak.'),
            ),
            // Üstte daima görünen, scrolla göre saydam → opak app bar.
            // Başlık aktif habere göre güncellenir.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  _scrollController,
                  _activeArticleIndex,
                ]),
                builder: (context, _) {
                  return DetailAppBar(
                    scrollOffset: _currentScrollOffset,
                    onBack: () => Navigator.of(context).maybePop(),
                    title: _articleSequence[_activeArticleIndex.value].title,
                  );
                },
              ),
            ),
            // Sağ üstte, scroll edilince beliren paylaşım & aksiyon dock'u.
            // Opaklık scroll'a, sayılar aktif habere bağlı.
            Positioned(
              top: MediaQuery.viewPaddingOf(context).top + 64,
              right: 12,
              child: AnimatedBuilder(
                animation: _scrollController,
                child: ValueListenableBuilder<int>(
                  valueListenable: _activeArticleIndex,
                  builder: (context, index, _) {
                    final article = _articleSequence[index];
                    return DetailFloatingDock(
                      onInstagram: () =>
                          _showMessage('Instagram\'da paylaşılıyor.'),
                      onFacebook: () =>
                          _showMessage('Facebook\'ta paylaşılıyor.'),
                      onX: () => _showMessage('X\'te paylaşılıyor.'),
                      onWhatsApp: () =>
                          _showMessage('WhatsApp\'ta paylaşılıyor.'),
                      onLike: () => _showMessage('Beğenildi.'),
                      onSave: () => _showMessage('Haber kaydedildi.'),
                      shareCount: article.shares,
                      likeCount: article.likes,
                      saveCount: (article.shares * 0.4).round() + 12,
                    );
                  },
                ),
                builder: (context, child) {
                  final progress = _dockProgressFor(_currentScrollOffset);
                  return IgnorePointer(
                    ignoring: progress < 0.4,
                    child: Opacity(
                      opacity: progress,
                      child: FractionalTranslation(
                        translation: Offset((1 - progress) * 0.35, 0),
                        child: child,
                      ),
                    ),
                  );
                },
              ),
            ),
            // Sol alttaki okuma ilerleme şeridi.
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: Listenable.merge([
                    _scrollController,
                    _readingProgress,
                  ]),
                  builder: (context, _) {
                    return _ReadingProgressBar(
                      progress: _readingProgress.value,
                      isVisible: _currentScrollOffset > 0.5,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Detay sayfasının sonsuz akışını destekleyen iç içerik blokları.
class _DetailContent extends StatelessWidget {
  const _DetailContent({
    super.key,
    required this.scrollController,
    required this.articles,
    required this.articleKeys,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.onSave,
    required this.onFollow,
    required this.onAllComments,
  });

  final ScrollController scrollController;
  final List<NewsArticle> articles;
  final List<GlobalKey> articleKeys;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onSave;
  final VoidCallback onFollow;
  final VoidCallback onAllComments;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return CustomScrollView(
      controller: scrollController,
      physics: const BouncingScrollPhysics(),
      // Tembel akış: yalnızca ekrandaki + cacheExtent kadar haber inşa edilir;
      // uzaktaki haberler otomatik dispose olur. (Eskiden for + SliverToBoxAdapter
      // ile haberlerin tamamı ilk karede kurulurdu.)
      slivers: [
        SliverList.builder(
          itemCount: articles.length + 1,
          itemBuilder: (context, i) {
            if (i == articles.length) {
              return SizedBox(height: AppSpacing.huge + bottomInset);
            }
            return _DetailArticleSection(
              sectionKey: articleKeys[i],
              article: articles[i],
              isFirst: i == 0,
              scrollController: scrollController,
              onLike: onLike,
              onComment: onComment,
              onShare: onShare,
              onSave: onSave,
              onFollow: onFollow,
              onAllComments: onAllComments,
            );
          },
        ),
      ],
    );
  }
}

class _DetailArticleSection extends StatelessWidget {
  const _DetailArticleSection({
    required this.sectionKey,
    required this.article,
    required this.isFirst,
    required this.scrollController,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.onSave,
    required this.onFollow,
    required this.onAllComments,
  });

  final GlobalKey sectionKey;
  final NewsArticle article;
  final bool isFirst;
  final ScrollController scrollController;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onSave;
  final VoidCallback onFollow;
  final VoidCallback onAllComments;

  @override
  Widget build(BuildContext context) {
    final body = NewsDetailMock.bodyFor(article);
    final reactions = NewsDetailMock.reactionsFor(article);
    final comments = NewsDetailMock.commentsFor(article);

    return Column(
      key: sectionKey,
      children: [
        _DetailHero(
          article: article,
          isFirst: isFirst,
          scrollController: scrollController,
          onLike: onLike,
          onComment: onComment,
          onSave: onSave,
          onShare: onShare,
        ),
        DetailLede(article: article, onFollow: onFollow)
            .animate()
            .fadeIn(delay: 80.ms, duration: 340.ms, curve: Curves.easeOutCubic)
            .slideY(
              begin: 0.03,
              end: 0,
              delay: 80.ms,
              duration: 340.ms,
              curve: Curves.easeOutCubic,
            ),
        DetailBody(body: body)
            .animate()
            .fadeIn(delay: 140.ms, duration: 360.ms, curve: Curves.easeOutCubic)
            .slideY(
              begin: 0.025,
              end: 0,
              delay: 140.ms,
              duration: 360.ms,
              curve: Curves.easeOutCubic,
            ),
        DetailReactionsStrip(stats: reactions),
        DetailShareBar(onShare: onShare),
        DetailCommentsSection(
          thread: comments,
          currentUser: HomeMockData.currentUser,
          onSeeAll: onAllComments,
        ),
      ],
    );
  }
}

class _DetailHero extends StatelessWidget {
  const _DetailHero({
    required this.article,
    required this.isFirst,
    required this.scrollController,
    required this.onLike,
    required this.onComment,
    required this.onSave,
    required this.onShare,
  });

  final NewsArticle article;
  final bool isFirst;
  final ScrollController scrollController;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onSave;
  final VoidCallback onShare;

  static const double _aspectRatio = 4 / 5;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final height = width / _aspectRatio;

    return AnimatedBuilder(
      animation: scrollController,
      builder: (context, child) {
        final scrollOffset = scrollController.hasClients
            ? scrollController.offset
            : 0.0;
        // Parallax'i bölümün canlı ekran konumundan hesapla — lazy listede
        // sabit "sectionStart" yok. Yalnızca görünen hero'lar için çalışır,
        // maliyeti ihmal edilebilir (bir RenderBox konum okuması).
        final box = context.findRenderObject() as RenderBox?;
        final heroTop = (box != null && box.attached && box.hasSize)
            ? box.localToGlobal(Offset.zero).dy
            : 0.0;
        final localScroll = -heroTop;
        final offset = localScroll.clamp(0.0, height);
        final overscroll = isFirst ? scrollOffset.clamp(-height, 0.0) : 0.0;
        final parallax = offset * 0.35;
        final pullScale = (1 + overscroll / height * -0.18).clamp(1.0, 1.18);
        final parallaxCoverScale = 1 + parallax / height;
        final scale = pullScale > parallaxCoverScale
            ? pullScale
            : parallaxCoverScale;
        return RepaintBoundary(
          child: SizedBox(
            height: height,
            width: width,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Transform.translate(
                  offset: Offset(0, -parallax),
                  child: Transform.scale(
                    scale: scale,
                    alignment: Alignment.topCenter,
                    child: child,
                  ),
                ),
                const _HeroTopScrim(),
                const _HeroBottomScrim(),
                Positioned(
                  left: AppSpacing.pageHorizontal,
                  right: AppSpacing.pageHorizontal,
                  bottom: AppSpacing.xxl,
                  child: _HeroOverlay(
                    article: article,
                    onLike: onLike,
                    onComment: onComment,
                    onSave: onSave,
                    onShare: onShare,
                  ),
                ),
              ],
            ),
          ),
        );
      },
      child: _HeroImage(url: article.imageUrl),
    );
  }
}

class _HeroImage extends StatelessWidget {
  const _HeroImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = (MediaQuery.sizeOf(context).width * dpr).round();
    return CachedImage(
      url: url,
      fit: BoxFit.cover,
      memCacheWidth: cacheWidth,
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
}

class _HeroTopScrim extends StatelessWidget {
  const _HeroTopScrim();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xA8000000), Color(0x44000000), Color(0x00000000)],
          stops: [0, 0.32, 0.6],
        ),
      ),
    );
  }
}

class _HeroBottomScrim extends StatelessWidget {
  const _HeroBottomScrim();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0x00000000),
            Colors.black.withValues(alpha: 0.10),
            Colors.black.withValues(alpha: 0.38),
            Colors.black.withValues(alpha: 0.66),
          ],
          stops: const [0, 0.62, 0.86, 1],
        ),
      ),
    );
  }
}

class _HeroOverlay extends StatefulWidget {
  const _HeroOverlay({
    required this.article,
    required this.onLike,
    required this.onComment,
    required this.onSave,
    required this.onShare,
  });

  final NewsArticle article;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onSave;
  final VoidCallback onShare;

  @override
  State<_HeroOverlay> createState() => _HeroOverlayState();
}

class _HeroOverlayState extends State<_HeroOverlay> {
  bool _liked = false;
  bool _saved = false;

  void _toggleLike() {
    setState(() => _liked = !_liked);
    if (_liked) widget.onLike();
  }

  void _toggleSave() {
    setState(() => _saved = !_saved);
    if (_saved) widget.onSave();
  }

  @override
  Widget build(BuildContext context) {
    final article = widget.article;
    final likes = article.likes + (_liked ? 1 : 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Sosyal aksiyonlar + sağda kaydet
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SocialAction(
              glyph: PateezSocialGlyph.heart,
              isActive: _liked,
              activeColor: AppColors.actionRed,
              inactiveColor: Colors.white,
              semanticLabel: 'Beğen',
              iconSize: 20,
              count: likes,
              countFontSize: 10.5,
              onTap: _toggleLike,
            ),
            SocialAction(
              glyph: PateezSocialGlyph.conversation,
              isActive: false,
              activeColor: AppColors.deepOcean,
              inactiveColor: Colors.white,
              semanticLabel: 'Yorumlar',
              iconSize: 20,
              count: article.comments,
              countFontSize: 10.5,
              onTap: widget.onComment,
            ),
            SocialAction(
              glyph: PateezSocialGlyph.orbitShare,
              isActive: false,
              activeColor: AppColors.warmHorizon,
              inactiveColor: Colors.white,
              semanticLabel: 'Paylaş',
              iconSize: 20,
              count: article.shares,
              countFontSize: 10.5,
              onTap: widget.onShare,
            ),
            const Spacer(),
            SocialAction(
              glyph: PateezSocialGlyph.ribbon,
              isActive: _saved,
              activeColor: AppColors.warmHorizon,
              inactiveColor: Colors.white,
              semanticLabel: 'Kaydet',
              iconSize: 22,
              onTap: _toggleSave,
            ),
          ],
        ),
        const SizedBox(height: 10),
        _HeroPublishedAt(date: article.publishedAt),
      ],
    );
  }
}

class _HeroPublishedAt extends StatelessWidget {
  const _HeroPublishedAt({required this.date});

  final DateTime date;

  static const _months = [
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

  String get _formatted {
    final day = date.day.toString().padLeft(2, '0');
    final month = _months[(date.month - 1).clamp(0, 11)];
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day $month ${date.year}  ·  $hour.$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Symbols.schedule_rounded,
          size: 12,
          color: Colors.white.withValues(alpha: 0.78),
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            _formatted,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.meta.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
              fontWeight: FontWeight.w500,
              letterSpacing: 0,
              height: 1.2,
              shadows: const [
                Shadow(
                  color: Color(0x88000000),
                  offset: Offset(0, 1),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Sayfanın en üstünde, aktif haberin okuma ilerlemesini gösteren ince bar.
class _ReadingProgressBar extends StatelessWidget {
  const _ReadingProgressBar({required this.progress, required this.isVisible});

  final double progress;
  final bool isVisible;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.viewPaddingOf(context).top;
    final clampedProgress = progress.clamp(0.0, 1.0).toDouble();
    return Visibility(
      visible: isVisible,
      maintainSize: true,
      maintainAnimation: true,
      maintainState: true,
      child: Padding(
        padding: EdgeInsets.only(top: topPadding + 52),
        child: SizedBox(
          height: 2,
          child: LayoutBuilder(
            builder: (context, c) {
              return Stack(
                children: [
                  Container(color: Colors.black.withValues(alpha: 0.04)),
                  Container(
                    width: c.maxWidth * clampedProgress,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.actionRed, AppColors.warmHorizon],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
