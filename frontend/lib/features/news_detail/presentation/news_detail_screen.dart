import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/mock/home_mock_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/social_action.dart';
import '../data/news_detail_mock.dart';
import 'widgets/detail_app_bar.dart';
import 'widgets/detail_body.dart';
import 'widgets/detail_comments.dart';
import 'widgets/detail_floating_dock.dart';
import 'widgets/detail_lede.dart';
import 'widgets/detail_next_article.dart';
import 'widgets/detail_reactions.dart';
import 'widgets/detail_share_bar.dart';

/// Pateeznews haber detay sayfası.
///
/// Yapı:
///   - Üstte parallax hero görsel + sticky transparan app bar.
///   - Beyaz yüzeyde editorial başlık, spot, gövde ve pull-quote.
///   - Tepki şeridi, paylaşım barı ve yorum bölümü.
///   - Sayfa altında "Sonraki Haber" geçişi; kaydırma veya tıklama ile
///     bir sonraki habere akıcı geçiş.
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

class _NewsDetailScreenState extends State<NewsDetailScreen>
    with TickerProviderStateMixin {
  late int _index;
  late ScrollController _scrollController;
  late AnimationController _transition;
  double _scrollOffset = 0;
  bool _isTransitioning = false;
  double _bottomOverscroll = 0;
  static const double _overscrollThreshold = 96;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.articles.length - 1);
    _scrollController = ScrollController()..addListener(_onScroll);
    _transition = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
      value: 1,
    );
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _transition.dispose();
    super.dispose();
  }

  void _onScroll() {
    final offset = _scrollController.offset.clamp(0.0, 1000.0);
    if ((offset - _scrollOffset).abs() < 0.5) return;
    setState(() => _scrollOffset = offset);
  }

  NewsArticle get _article => widget.articles[_index];
  NewsArticle get _nextArticle =>
      NewsDetailMock.nextOf(_article, widget.articles);

  /// Sağ üst floating dock'un belirme/ kaybolma ilerlemesi (0-1).
  /// App bar saydam → opak geçişiyle senkron çalışır.
  double get _dockProgress {
    const start = 90.0;
    const end = 230.0;
    return ((_scrollOffset - start) / (end - start)).clamp(0.0, 1.0);
  }

  Future<void> _goToNext() async {
    if (_isTransitioning) return;
    setState(() {
      _isTransitioning = true;
      _bottomOverscroll = 0;
    });
    HapticFeedback.selectionClick();
    await _transition.reverse();
    if (!mounted) return;
    final nextIndex = widget.articles.indexWhere(
      (a) => a.id == _nextArticle.id,
    );
    setState(() {
      _index = nextIndex == -1 ? 0 : nextIndex;
      _scrollOffset = 0;
    });
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    await _transition.forward();
    if (!mounted) return;
    setState(() => _isTransitioning = false);
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (_isTransitioning) return false;
    final metrics = notification.metrics;
    final atBottom = metrics.pixels >= metrics.maxScrollExtent - 0.5;
    if (notification is OverscrollNotification &&
        atBottom &&
        notification.overscroll > 0) {
      _bottomOverscroll += notification.overscroll;
      if (_bottomOverscroll >= _overscrollThreshold) {
        _bottomOverscroll = 0;
        _goToNext();
      }
    } else if (notification is ScrollEndNotification && !atBottom) {
      _bottomOverscroll = 0;
    }
    return false;
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
    final article = _article;
    final body = NewsDetailMock.bodyFor(article);
    final reactions = NewsDetailMock.reactionsFor(article);
    final comments = NewsDetailMock.commentsFor(article);
    final next = _nextArticle;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _scrollOffset > 120 ? AppTheme.lightOverlay : AppTheme.darkOverlay,
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        body: Stack(
          children: [
            FadeTransition(
              opacity: _transition,
              child: AnimatedBuilder(
                animation: _transition,
                builder: (context, child) {
                  // Sonraki habere geçerken hafif yukarı kayma efekti.
                  final dy = (1 - _transition.value) * -32;
                  return Transform.translate(
                    offset: Offset(0, dy),
                    child: child,
                  );
                },
                child: NotificationListener<ScrollNotification>(
                  onNotification: _onScrollNotification,
                  child: _DetailContent(
                    key: ValueKey<String>('detail-${article.id}'),
                    scrollController: _scrollController,
                    article: article,
                    body: body,
                    reactions: reactions,
                    comments: comments,
                    next: next,
                    onLike: () => _showMessage('Beğenildi.'),
                    onComment: () =>
                        _showMessage('Yorumlar bölümüne yönlendiriliyor.'),
                    onShare: () => _showMessage('Paylaşım menüsü açıldı.'),
                    onSave: () => _showMessage('Haber kaydedildi.'),
                    onFollow: () => _showMessage('Yazar takip ediliyor.'),
                    onAllComments: () =>
                        _showMessage('Tüm yorumlar yakında açılacak.'),
                    onNext: _goToNext,
                  ),
                ),
              ),
            ),
            // Üstte daima görünen, scrolla göre saydam → opak app bar.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: DetailAppBar(
                scrollOffset: _scrollOffset,
                onBack: () => Navigator.of(context).maybePop(),
                title: article.title,
              ),
            ),
            // Sağ üstte, scroll edilince beliren paylaşım & aksiyon dock'u.
            Positioned(
              top: MediaQuery.viewPaddingOf(context).top + 64,
              right: 12,
              child: IgnorePointer(
                ignoring: _dockProgress < 0.4,
                child: AnimatedOpacity(
                  opacity: _dockProgress,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  child: AnimatedSlide(
                    offset: Offset(
                      (1 - _dockProgress) * 0.35,
                      0,
                    ),
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    child: DetailFloatingDock(
                      onInstagram: () =>
                          _showMessage('Instagram\'da paylaşılıyor.'),
                      onFacebook: () =>
                          _showMessage('Facebook\'ta paylaşılıyor.'),
                      onX: () => _showMessage('X\'te paylaşılıyor.'),
                      onWhatsApp: () =>
                          _showMessage('WhatsApp\'ta paylaşılıyor.'),
                      onLike: () => _showMessage('Beğenildi.'),
                      onSave: () => _showMessage('Haber kaydedildi.'),
                      shareCount: _article.shares,
                      likeCount: _article.likes,
                      saveCount: (_article.shares * 0.4).round() + 12,
                    ),
                  ),
                ),
              ),
            ),
            // Sol alttaki okuma ilerleme şeridi.
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: IgnorePointer(
                child: _ReadingProgressBar(scrollController: _scrollController),
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
    required this.article,
    required this.body,
    required this.reactions,
    required this.comments,
    required this.next,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.onSave,
    required this.onFollow,
    required this.onAllComments,
    required this.onNext,
  });

  final ScrollController scrollController;
  final NewsArticle article;
  final NewsBody body;
  final NewsReactionStats reactions;
  final NewsCommentThread comments;
  final NewsArticle next;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onSave;
  final VoidCallback onFollow;
  final VoidCallback onAllComments;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: scrollController,
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: _DetailHero(
            article: article,
            scrollController: scrollController,
            onLike: onLike,
            onComment: onComment,
            onSave: onSave,
            onShare: onShare,
          ),
        ),
        SliverToBoxAdapter(
          child: DetailLede(article: article, onFollow: onFollow)
              .animate()
              .fadeIn(
                delay: 80.ms,
                duration: 340.ms,
                curve: Curves.easeOutCubic,
              )
              .slideY(
                begin: 0.03,
                end: 0,
                delay: 80.ms,
                duration: 340.ms,
                curve: Curves.easeOutCubic,
              ),
        ),
        SliverToBoxAdapter(
          child: DetailBody(body: body)
              .animate()
              .fadeIn(
                delay: 140.ms,
                duration: 360.ms,
                curve: Curves.easeOutCubic,
              )
              .slideY(
                begin: 0.025,
                end: 0,
                delay: 140.ms,
                duration: 360.ms,
                curve: Curves.easeOutCubic,
              ),
        ),
        SliverToBoxAdapter(child: DetailReactionsStrip(stats: reactions)),
        SliverToBoxAdapter(child: DetailShareBar(onShare: onShare)),
        SliverToBoxAdapter(
          child: DetailCommentsSection(
            thread: comments,
            currentUser: HomeMockData.currentUser,
            onSeeAll: onAllComments,
          ),
        ),
        SliverToBoxAdapter(
          child: DetailNextArticleHandoff(next: next, onTap: onNext),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: AppSpacing.huge + MediaQuery.viewPaddingOf(context).bottom,
          ),
        ),
      ],
    );
  }
}

class _DetailHero extends StatelessWidget {
  const _DetailHero({
    required this.article,
    required this.scrollController,
    required this.onLike,
    required this.onComment,
    required this.onSave,
    required this.onShare,
  });

  final NewsArticle article;
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
        final offset = scrollController.hasClients
            ? scrollController.offset.clamp(-height, height)
            : 0.0;
        final parallax = offset * 0.35;
        final scale = (1 + (offset.clamp(-height, 0)) / height * -0.18).clamp(
          1.0,
          1.18,
        );
        return SizedBox(
          height: height,
          width: width,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Transform.translate(
                offset: Offset(0, -parallax),
                child: Transform.scale(
                  scale: scale,
                  alignment: Alignment.center,
                  child: child,
                ),
              ),
              const _HeroTopScrim(),
              const _HeroBottomScrim(),
              Positioned(
                left: AppSpacing.pageHorizontal,
                right: AppSpacing.pageHorizontal,
                bottom: AppSpacing.xxxl,
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
    return Image.network(
      url,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      cacheWidth: cacheWidth > 0 ? cacheWidth : null,
      filterQuality: FilterQuality.medium,
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
            Colors.black.withValues(alpha: 0.18),
            Colors.black.withValues(alpha: 0.62),
            Colors.black.withValues(alpha: 0.86),
          ],
          stops: const [0, 0.55, 0.85, 1],
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
        const SizedBox(height: AppSpacing.md),
        Text(
          article.title,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: 'PateezInter',
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
            height: 1.06,
            shadows: [
              Shadow(
                color: Color(0x66000000),
                offset: Offset(0, 1),
                blurRadius: 8,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Başlığın altında, ana sayfadaki "1 g" karakterinde ince/küçük tarih.
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
          Icons.schedule_rounded,
          size: 12,
          color: Colors.white.withValues(alpha: 0.78),
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            _formatted,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'PateezInter',
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.1,
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

/// Sayfanın en üstünde, scroll ilerlemesini gösteren ince kırmızı bar.
class _ReadingProgressBar extends StatefulWidget {
  const _ReadingProgressBar({required this.scrollController});

  final ScrollController scrollController;

  @override
  State<_ReadingProgressBar> createState() => _ReadingProgressBarState();
}

class _ReadingProgressBarState extends State<_ReadingProgressBar> {
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (!widget.scrollController.hasClients) return;
    final position = widget.scrollController.position;
    final max = position.maxScrollExtent;
    if (max <= 0) return;
    final progress = (position.pixels / max).clamp(0.0, 1.0);
    if ((progress - _progress).abs() < 0.005) return;
    setState(() => _progress = progress);
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.viewPaddingOf(context).top;
    return Padding(
      padding: EdgeInsets.only(top: topPadding + 52),
      child: SizedBox(
        height: 2,
        child: LayoutBuilder(
          builder: (context, c) {
            return Stack(
              children: [
                Container(color: Colors.black.withValues(alpha: 0.04)),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: c.maxWidth * _progress,
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
    );
  }
}
