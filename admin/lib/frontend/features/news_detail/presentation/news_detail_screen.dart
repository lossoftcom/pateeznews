import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../core/mock/home_mock_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/services/article_share_service.dart';
import '../../../shared/services/frontend_link_launcher.dart';
import '../../../shared/widgets/cached_image.dart';
import '../../../shared/widgets/pinch_zoom_surface.dart';
import '../../../shared/widgets/frontend_toast.dart';
import '../../../shared/widgets/social_action.dart';
import '../../account/data/frontend_auth_repository.dart';
import '../../ads/presentation/frontend_anchor_ad_dock.dart';
import '../../ads/presentation/frontend_ad_slot.dart';
import '../../home/data/home_repository.dart';
import '../../home/data/post_action_repository.dart';
import '../../home/presentation/widgets/news_card.dart';
import '../../home/presentation/widgets/news_video_player.dart';
import '../../home/presentation/widgets/social_embed_stage.dart';
import '../../shell/data/app_shell_repository.dart';
import 'widgets/detail_app_bar.dart';
import 'widgets/detail_event.dart';
import 'widgets/detail_floating_dock.dart';
import 'widgets/detail_lede.dart';
import 'widgets/detail_poll.dart';
import 'widgets/detail_quiz.dart';
import 'widgets/detail_recipe.dart';
import 'widgets/detail_reactions.dart';
import 'widgets/detail_toc.dart';

/// Pateeznews haber detay sayfası.
///
/// Kapak, başlık/spot ve editorial detail iskeleti korunur. Haber içindeki
/// bloklar ise `detailItems` sırasıyla, ana sayfada kullanılan NewsCard medya
/// renderer'ı üzerinden gösterilir.
class NewsDetailScreen extends StatefulWidget {
  const NewsDetailScreen({
    super.key,
    required this.articles,
    required this.initialIndex,
    this.shellSettings = const AppShellSettings.empty(),
    this.navigationItems = const [],
    this.contentSettings = const HomeContentSettings.defaults(),
    this.videoFeedArticles = const [],
    this.authState,
    this.postActionRepository = const PostActionRepository(),
    this.onAuthRequired,
    this.onAuthorTap,
    this.onFullscreenVideoExit,
  });

  final List<NewsArticle> articles;
  final int initialIndex;
  final AppShellSettings shellSettings;
  final List<AppShellNavigationItem> navigationItems;
  final HomeContentSettings contentSettings;
  final List<NewsArticle> videoFeedArticles;
  final FrontendAuthState? authState;
  final PostActionRepository postActionRepository;
  final VoidCallback? onAuthRequired;
  final ValueChanged<NewsAuthor>? onAuthorTap;
  final VoidCallback? onFullscreenVideoExit;

  @override
  State<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends State<NewsDetailScreen> {
  static const _anchorAdReserve = 74.0;
  late ScrollController _scrollController;
  late List<NewsArticle> _articleSequence;
  late List<GlobalKey> _articleKeys;

  final ValueNotifier<int> _activeArticleIndex = ValueNotifier<int>(0);
  final ValueNotifier<double> _readingProgress = ValueNotifier<double>(0);
  final ValueNotifier<bool> _usesLightOverlay = ValueNotifier<bool>(false);
  final Map<String, _DetailActionState> _detailActionStates = {};
  bool _detailActionBusy = false;
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
      _detailActionStates.clear();
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
    _syncDetailActionStates();
  }

  void _syncDetailActionStates() {
    final previous = Map<String, _DetailActionState>.of(_detailActionStates);
    _detailActionStates
      ..clear()
      ..addEntries(
        _articleSequence.map(
          (article) => MapEntry(
            article.id,
            previous[article.id] ?? _DetailActionState.fromArticle(article),
          ),
        ),
      );
  }

  void _onScroll() => _syncReadingState();

  void _scheduleInitialSync() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncReadingState();
    });
  }

  void _syncReadingState() {
    if (!mounted || !_scrollController.hasClients) return;

    final scrollOffset = _scrollController.offset;
    _scrollOffset = scrollOffset;
    _usesLightOverlay.value = scrollOffset > 120;

    final anchor = MediaQuery.viewPaddingOf(context).top + 54;
    int? activeIndex;
    var progress = 0.0;
    int? firstBuiltIndex;
    var firstBuiltBelowAnchor = false;

    for (var i = 0; i < _articleKeys.length; i++) {
      final sectionContext = _articleKeys[i].currentContext;
      if (sectionContext == null) continue;
      final box = sectionContext.findRenderObject() as RenderBox?;
      if (box == null || !box.attached || !box.hasSize) continue;

      final top = box.localToGlobal(Offset.zero).dy;
      final height = box.size.height;
      if (height <= 0) continue;
      final bottom = top + height;

      firstBuiltIndex ??= i;
      if (firstBuiltIndex == i) firstBuiltBelowAnchor = top > anchor;

      if (top <= anchor && bottom > anchor) {
        activeIndex = i;
        final readable = (height - anchor).clamp(1.0, double.infinity);
        progress = (-top / readable).clamp(0.0, 1.0);
        break;
      } else if (bottom <= anchor) {
        activeIndex = i;
        progress = 1.0;
      }
    }

    if (activeIndex == null) {
      activeIndex = firstBuiltIndex ?? 0;
      if (firstBuiltBelowAnchor) progress = 0.0;
    }

    _activeArticleIndex.value = activeIndex;
    _readingProgress.value = progress;
  }

  double get _currentScrollOffset {
    return _scrollController.hasClients
        ? _scrollController.offset
        : _scrollOffset;
  }

  double _dockProgressFor(double scrollOffset) {
    const start = 90.0;
    const end = 230.0;
    return ((scrollOffset - start) / (end - start)).clamp(0.0, 1.0);
  }

  void _showMessage(
    String text, {
    FrontendToastTone tone = FrontendToastTone.success,
  }) => FrontendToast.show(context, message: text, tone: tone);

  _DetailActionState _actionStateFor(NewsArticle article) {
    return _detailActionStates[article.id] ??
        _DetailActionState.fromArticle(article);
  }

  String get _authToken => widget.authState?.session.accessToken.trim() ?? '';

  bool _hasNumericPostId(NewsArticle article) =>
      int.tryParse(article.id) != null;

  bool _requireSignedIn(String message) {
    if (_authToken.isNotEmpty) return true;
    _showMessage(message, tone: FrontendToastTone.error);
    widget.onAuthRequired?.call();
    return false;
  }

  Future<void> _toggleDetailLike(NewsArticle article) {
    return _runDetailStateAction(
      article: article,
      signInMessage: 'Beğenmek için kayıt olmanız gerekiyor.',
      optimistic: (state) => state.toggleLike(),
      request: (token) => widget.postActionRepository.toggleLike(
        postId: article.id,
        token: token,
      ),
      fallbackMessage: 'Beğeni güncellenemedi.',
    );
  }

  Future<void> _toggleDetailDislike(NewsArticle article) {
    return _runDetailStateAction(
      article: article,
      signInMessage: 'Beğenmemek için kayıt olmanız gerekiyor.',
      optimistic: (state) => state.toggleDislike(),
      request: (token) => widget.postActionRepository.toggleDislike(
        postId: article.id,
        token: token,
      ),
      fallbackMessage: 'Beğenmeme güncellenemedi.',
    );
  }

  Future<void> _toggleDetailSave(NewsArticle article) {
    return _runDetailStateAction(
      article: article,
      signInMessage: 'Kaydetmek için kayıt olmanız gerekiyor.',
      optimistic: (state) => state.toggleSave(),
      request: (token) => widget.postActionRepository.toggleSave(
        postId: article.id,
        token: token,
      ),
      fallbackMessage: 'Kaydetme güncellenemedi.',
    );
  }

  Future<void> _runDetailStateAction({
    required NewsArticle article,
    required String signInMessage,
    required _DetailActionState Function(_DetailActionState state) optimistic,
    required Future<PostActionState> Function(String token) request,
    required String fallbackMessage,
  }) async {
    if (!_hasNumericPostId(article) || _detailActionBusy) return;
    if (!_requireSignedIn(signInMessage)) return;

    final previous = _actionStateFor(article);
    setState(() {
      _detailActionBusy = true;
      _detailActionStates[article.id] = optimistic(previous);
    });

    try {
      final state = await request(_authToken);
      if (!mounted) return;
      setState(() {
        _detailActionStates[article.id] =
            _DetailActionState.fromPostActionState(state);
      });
    } on PostActionException catch (error) {
      if (!mounted) return;
      setState(() => _detailActionStates[article.id] = previous);
      _showMessage(error.message, tone: FrontendToastTone.error);
    } catch (_) {
      if (!mounted) return;
      setState(() => _detailActionStates[article.id] = previous);
      _showMessage(fallbackMessage, tone: FrontendToastTone.error);
    } finally {
      if (mounted) setState(() => _detailActionBusy = false);
    }
  }

  Future<void> _shareDetailArticle(
    NewsArticle article, {
    ArticleShareTarget target = ArticleShareTarget.system,
  }) async {
    if (frontendShareUrlForArticle(article).isEmpty) return;

    final opened = await shareArticle(
      context,
      article: article,
      target: target,
    );
    if (!mounted) return;
    if (!opened) {
      _showMessage('Paylaşım açılamadı.', tone: FrontendToastTone.error);
      return;
    }

    try {
      if (_hasNumericPostId(article)) {
        final token = _authToken;
        final state = await widget.postActionRepository.share(
          postId: article.id,
          token: token.isEmpty ? null : token,
          platform: target.apiPlatform,
        );
        if (mounted) {
          setState(() {
            _detailActionStates[article.id] =
                _DetailActionState.fromPostActionState(state);
          });
        }
      }
    } catch (_) {
      // Paylaşım hedefi açıldı; sayaç güncellenemezse mevcut değer korunur.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_articleSequence.isEmpty) {
      return const Scaffold(backgroundColor: AppColors.canvas);
    }

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
              shellSettings: widget.shellSettings,
              navigationItems: widget.navigationItems,
              contentSettings: widget.contentSettings,
              videoFeedArticles: widget.videoFeedArticles,
              authState: widget.authState,
              postActionRepository: widget.postActionRepository,
              onAuthRequired: widget.onAuthRequired,
              onAuthorTap: widget.onAuthorTap,
              onFullscreenVideoExit: widget.onFullscreenVideoExit,
              actionStateFor: _actionStateFor,
              onLike: (article) => unawaited(_toggleDetailLike(article)),
              onDislike: (article) => unawaited(_toggleDetailDislike(article)),
              onComment: () =>
                  _showMessage('Yorumlar bölümüne yönlendiriliyor.'),
              onShare: (article) => unawaited(_shareDetailArticle(article)),
              onSave: (article) => unawaited(_toggleDetailSave(article)),
              onFollow: () => _showMessage('Yazar takip ediliyor.'),
            ),
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
            Positioned(
              top: MediaQuery.viewPaddingOf(context).top + 64,
              right: 12,
              child: AnimatedBuilder(
                animation: _scrollController,
                child: ValueListenableBuilder<int>(
                  valueListenable: _activeArticleIndex,
                  builder: (context, index, _) {
                    final article = _articleSequence[index];
                    final state = _actionStateFor(article);
                    return DetailFloatingDock(
                      onInstagram: () => unawaited(
                        _shareDetailArticle(
                          article,
                          target: ArticleShareTarget.instagram,
                        ),
                      ),
                      onFacebook: () => unawaited(
                        _shareDetailArticle(
                          article,
                          target: ArticleShareTarget.facebook,
                        ),
                      ),
                      onX: () => unawaited(
                        _shareDetailArticle(
                          article,
                          target: ArticleShareTarget.x,
                        ),
                      ),
                      onWhatsApp: () => unawaited(
                        _shareDetailArticle(
                          article,
                          target: ArticleShareTarget.whatsapp,
                        ),
                      ),
                      onLike: () => unawaited(_toggleDetailLike(article)),
                      onDislike: () => unawaited(_toggleDetailDislike(article)),
                      onSave: () => unawaited(_toggleDetailSave(article)),
                      shareCount: state.shares,
                      likeCount: state.likes,
                      dislikeCount: state.dislikes,
                      saveCount: state.saves,
                      isLiked: state.liked,
                      isDisliked: state.disliked,
                      isSaved: state.saved,
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
            const Positioned(
              right: 0,
              bottom: 0,
              left: 0,
              child: FrontendAnchorAdDock(),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailActionState {
  const _DetailActionState({
    required this.likes,
    required this.dislikes,
    required this.shares,
    required this.saves,
    required this.liked,
    required this.disliked,
    required this.saved,
  });

  factory _DetailActionState.fromArticle(NewsArticle article) {
    return _DetailActionState(
      likes: article.likes,
      dislikes: article.dislikes,
      shares: article.shares,
      saves: article.saves,
      liked: article.userLiked,
      disliked: article.userDisliked,
      saved: article.userSaved,
    );
  }

  factory _DetailActionState.fromPostActionState(PostActionState state) {
    return _DetailActionState(
      likes: state.likes,
      dislikes: state.dislikes,
      shares: state.shares,
      saves: state.saves,
      liked: state.liked,
      disliked: state.disliked,
      saved: state.saved,
    );
  }

  final int likes;
  final int dislikes;
  final int shares;
  final int saves;
  final bool liked;
  final bool disliked;
  final bool saved;

  _DetailActionState toggleLike() {
    if (liked) {
      return copyWith(liked: false, likes: math.max(0, likes - 1));
    }
    return copyWith(
      liked: true,
      disliked: false,
      likes: likes + 1,
      dislikes: disliked ? math.max(0, dislikes - 1) : dislikes,
    );
  }

  _DetailActionState toggleDislike() {
    if (disliked) {
      return copyWith(disliked: false, dislikes: math.max(0, dislikes - 1));
    }
    return copyWith(
      liked: false,
      disliked: true,
      likes: liked ? math.max(0, likes - 1) : likes,
      dislikes: dislikes + 1,
    );
  }

  _DetailActionState toggleSave() {
    return copyWith(
      saved: !saved,
      saves: math.max(0, saves + (saved ? -1 : 1)),
    );
  }

  _DetailActionState copyWith({
    int? likes,
    int? dislikes,
    int? shares,
    int? saves,
    bool? liked,
    bool? disliked,
    bool? saved,
  }) {
    return _DetailActionState(
      likes: likes ?? this.likes,
      dislikes: dislikes ?? this.dislikes,
      shares: shares ?? this.shares,
      saves: saves ?? this.saves,
      liked: liked ?? this.liked,
      disliked: disliked ?? this.disliked,
      saved: saved ?? this.saved,
    );
  }
}

class _DetailContent extends StatelessWidget {
  const _DetailContent({
    super.key,
    required this.scrollController,
    required this.articles,
    required this.articleKeys,
    required this.shellSettings,
    required this.navigationItems,
    required this.contentSettings,
    required this.videoFeedArticles,
    required this.authState,
    required this.postActionRepository,
    required this.onAuthRequired,
    required this.onAuthorTap,
    required this.onFullscreenVideoExit,
    required this.actionStateFor,
    required this.onLike,
    required this.onDislike,
    required this.onComment,
    required this.onShare,
    required this.onSave,
    required this.onFollow,
  });

  final ScrollController scrollController;
  final List<NewsArticle> articles;
  final List<GlobalKey> articleKeys;
  final AppShellSettings shellSettings;
  final List<AppShellNavigationItem> navigationItems;
  final HomeContentSettings contentSettings;
  final List<NewsArticle> videoFeedArticles;
  final FrontendAuthState? authState;
  final PostActionRepository postActionRepository;
  final VoidCallback? onAuthRequired;
  final ValueChanged<NewsAuthor>? onAuthorTap;
  final VoidCallback? onFullscreenVideoExit;
  final _DetailActionState Function(NewsArticle article) actionStateFor;
  final ValueChanged<NewsArticle> onLike;
  final ValueChanged<NewsArticle> onDislike;
  final VoidCallback onComment;
  final ValueChanged<NewsArticle> onShare;
  final ValueChanged<NewsArticle> onSave;
  final VoidCallback onFollow;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final resolvedVideoFeed = videoFeedArticles.isEmpty
        ? _dateSortedVideoFeed(articles)
        : videoFeedArticles;

    return CustomScrollView(
      controller: scrollController,
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverList.builder(
          itemCount: articles.length + 1,
          itemBuilder: (context, i) {
            if (i == articles.length) {
              return SizedBox(
                height:
                    AppSpacing.huge +
                    bottomInset +
                    _NewsDetailScreenState._anchorAdReserve,
              );
            }
            return _DetailArticleSection(
              sectionKey: articleKeys[i],
              article: articles[i],
              isFirst: i == 0,
              isLast: i == articles.length - 1,
              videoFeedArticles: resolvedVideoFeed,
              shellSettings: shellSettings,
              navigationItems: navigationItems,
              contentSettings: contentSettings,
              authState: authState,
              postActionRepository: postActionRepository,
              onAuthRequired: onAuthRequired,
              onAuthorTap: onAuthorTap,
              onFullscreenVideoExit: onFullscreenVideoExit,
              actionStateFor: actionStateFor,
              onLike: onLike,
              onDislike: onDislike,
              onComment: onComment,
              onShare: onShare,
              onSave: onSave,
              onFollow: onFollow,
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
    required this.isLast,
    required this.videoFeedArticles,
    required this.shellSettings,
    required this.navigationItems,
    required this.contentSettings,
    required this.authState,
    required this.postActionRepository,
    required this.onAuthRequired,
    required this.onAuthorTap,
    required this.onFullscreenVideoExit,
    required this.actionStateFor,
    required this.onLike,
    required this.onDislike,
    required this.onComment,
    required this.onShare,
    required this.onSave,
    required this.onFollow,
  });

  final GlobalKey sectionKey;
  final NewsArticle article;
  final bool isFirst;
  final bool isLast;
  final List<NewsArticle> videoFeedArticles;
  final AppShellSettings shellSettings;
  final List<AppShellNavigationItem> navigationItems;
  final HomeContentSettings contentSettings;
  final FrontendAuthState? authState;
  final PostActionRepository postActionRepository;
  final VoidCallback? onAuthRequired;
  final ValueChanged<NewsAuthor>? onAuthorTap;
  final VoidCallback? onFullscreenVideoExit;
  final _DetailActionState Function(NewsArticle article) actionStateFor;
  final ValueChanged<NewsArticle> onLike;
  final ValueChanged<NewsArticle> onDislike;
  final VoidCallback onComment;
  final ValueChanged<NewsArticle> onShare;
  final ValueChanged<NewsArticle> onSave;
  final VoidCallback onFollow;

  @override
  Widget build(BuildContext context) {
    final categoryTrail = _articleCategoryTrail(article, navigationItems);
    return Column(
      key: sectionKey,
      children: [
        if (!article.hideCoverInDetail)
          _DetailHero(
            article: article,
            isFirst: isFirst,
            categoryTrail: categoryTrail,
            shellSettings: shellSettings,
            actionState: actionStateFor(article),
            onLike: () => onLike(article),
            onDislike: () => onDislike(article),
            onComment: onComment,
            onSave: () => onSave(article),
            onShare: () => onShare(article),
            authState: authState,
            postActionRepository: postActionRepository,
            onAuthRequired: onAuthRequired,
            onAuthorTap: onAuthorTap,
          ),
        if (article.hideCoverInDetail && isFirst)
          SizedBox(height: MediaQuery.viewPaddingOf(context).top + 64),
        DetailLede(
              article: article,
              onFollow: onFollow,
              categoryTrail: categoryTrail,
            )
            .animate()
            .fadeIn(delay: 80.ms, duration: 340.ms, curve: Curves.easeOutCubic)
            .slideY(
              begin: 0.03,
              end: 0,
              delay: 80.ms,
              duration: 340.ms,
              curve: Curves.easeOutCubic,
            ),
        const FrontendAdSlot(slotKey: 'mobile_detail_after_media'),
        _DetailItemsSection(
              article: article,
              categoryTrail: categoryTrail,
              videoFeedArticles: videoFeedArticles,
              shellSettings: shellSettings,
              authState: authState,
              postActionRepository: postActionRepository,
              onAuthRequired: onAuthRequired,
              onAuthorTap: onAuthorTap,
              onFullscreenVideoExit: onFullscreenVideoExit,
            )
            .animate()
            .fadeIn(delay: 140.ms, duration: 360.ms, curve: Curves.easeOutCubic)
            .slideY(
              begin: 0.025,
              end: 0,
              delay: 140.ms,
              duration: 360.ms,
              curve: Curves.easeOutCubic,
            ),
        _DetailFaqSection(items: article.faqData),
        _DetailTagsSection(tags: article.tags),
        const FrontendAdSlot(slotKey: 'mobile_detail_end'),
        if (contentSettings.emojiReactions)
          DetailReactionsStrip(
            postId: article.id,
            authState: authState,
            postActionRepository: postActionRepository,
          ),
        NewsCard(
          article: article,
          onTap: () {},
          categoryTrail: categoryTrail,
          videoFeedArticles: videoFeedArticles,
          shellSettings: shellSettings,
          commentsEnabled: contentSettings.commentSystem,
          commentApprovalEnabled: contentSettings.commentApprovalSystem,
          emojiReactionsEnabled: contentSettings.emojiReactions,
          showMediaStage: false,
          showTitleSummary: false,
          showReadStats: false,
          showActions: false,
          relaxedInlineComments: true,
          showInlineCommentGuidance: true,
          authState: authState,
          postActionRepository: postActionRepository,
          onAuthRequired: onAuthRequired,
          onAuthorTap: onAuthorTap,
          onFullscreenVideoExit: onFullscreenVideoExit,
        ),
        if (!isLast)
          const FrontendAdSlot(slotKey: 'mobile_detail_between_articles'),
        if (!isLast) const _RelatedSectionDivider(),
      ],
    );
  }
}

class _DetailHero extends StatefulWidget {
  const _DetailHero({
    required this.article,
    required this.isFirst,
    required this.categoryTrail,
    required this.shellSettings,
    required this.actionState,
    required this.onLike,
    required this.onDislike,
    required this.onComment,
    required this.onSave,
    required this.onShare,
    required this.authState,
    required this.postActionRepository,
    required this.onAuthRequired,
    required this.onAuthorTap,
  });

  final NewsArticle article;
  final bool isFirst;
  final List<String> categoryTrail;
  final AppShellSettings shellSettings;
  final _DetailActionState actionState;
  final VoidCallback onLike;
  final VoidCallback onDislike;
  final VoidCallback onComment;
  final VoidCallback onSave;
  final VoidCallback onShare;
  final FrontendAuthState? authState;
  final PostActionRepository postActionRepository;
  final VoidCallback? onAuthRequired;
  final ValueChanged<NewsAuthor>? onAuthorTap;

  @override
  State<_DetailHero> createState() => _DetailHeroState();
}

class _DetailHeroState extends State<_DetailHero> {
  double? _resolvedImageAspectRatio;
  ImageStream? _pendingImageStream;
  ImageStreamListener? _pendingImageListener;

  @override
  void initState() {
    super.initState();
    _resolveImageAspectRatio();
  }

  @override
  void didUpdateWidget(covariant _DetailHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.article.imageUrl != widget.article.imageUrl ||
        oldWidget.article.imageAspectRatio != widget.article.imageAspectRatio) {
      _removeImageListener();
      _resolvedImageAspectRatio = null;
      _resolveImageAspectRatio();
    }
  }

  @override
  void dispose() {
    _removeImageListener();
    super.dispose();
  }

  void _resolveImageAspectRatio() {
    final knownRatio = _positiveImageAspectRatio(
      widget.article.imageAspectRatio,
    );
    if (knownRatio != null) {
      _resolvedImageAspectRatio = knownRatio;
    }

    final parsedRatio = _parseImageAspectRatioFromUrl(widget.article.imageUrl);
    if (parsedRatio != null) {
      _resolvedImageAspectRatio = parsedRatio;
    }

    final imageUrl = widget.article.imageUrl.trim();
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
      final ratio = width / height;
      final current = _resolvedImageAspectRatio;
      if (current != null && (current - ratio).abs() < 0.001) return;
      setState(() => _resolvedImageAspectRatio = ratio);
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

  void _openImageFullscreen() {
    final imageUrl = widget.article.imageUrl.trim();
    if (imageUrl.isEmpty) return;
    showNewsImageFullscreen(
      context,
      images: [imageUrl],
      item: _fullscreenItem(imageUrl),
      authState: widget.authState,
      postActionRepository: widget.postActionRepository,
      onAuthRequired: widget.onAuthRequired,
      onAuthorTap: widget.onAuthorTap,
    );
  }

  NewsVideoFeedItem _fullscreenItem(String imageUrl) {
    final article = widget.article;
    final categoryTrail = widget.categoryTrail.isNotEmpty
        ? widget.categoryTrail
        : article.categoryTrail;
    return NewsVideoFeedItem(
      postId: article.id,
      url: imageUrl,
      poster: article.imageUrl,
      slug: article.slug,
      publishedAt: article.publishedAt,
      title: article.title,
      author: article.author,
      region: article.region,
      category: article.category,
      categoryTrail: categoryTrail,
      likes: article.likes,
      dislikes: article.dislikes,
      comments: article.comments,
      shares: article.shares,
      saves: article.saves,
      userLiked: article.userLiked,
      userDisliked: article.userDisliked,
      userSaved: article.userSaved,
      fullscreenLogoUrl: widget.shellSettings.displayLogoUrl,
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final ratio =
        _resolvedImageAspectRatio ??
        _positiveImageAspectRatio(widget.article.imageAspectRatio) ??
        16 / 9;
    final height = width / ratio;
    final topPadding = widget.isFirst
        ? MediaQuery.viewPaddingOf(context).top
        : 0.0;

    return ColoredBox(
      color: AppColors.surfaceInk,
      child: Padding(
        padding: EdgeInsets.only(top: topPadding),
        child: SizedBox(
          width: width,
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _HeroImage(url: widget.article.imageUrl),
              Positioned(
                left: AppSpacing.pageHorizontal,
                right: AppSpacing.pageHorizontal,
                bottom: AppSpacing.sm,
                child: _HeroOverlay(
                  article: widget.article,
                  actionState: widget.actionState,
                  onLike: widget.onLike,
                  onDislike: widget.onDislike,
                  onComment: widget.onComment,
                  onSave: widget.onSave,
                  onShare: widget.onShare,
                ),
              ),
              if (widget.article.imageUrl.trim().isNotEmpty)
                Positioned(
                  right: AppSpacing.sm,
                  top: AppSpacing.sm,
                  child: NewsFullscreenExpandButton(
                    onTap: _openImageFullscreen,
                  ),
                ),
            ],
          ),
        ),
      ),
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
    return PinchZoomSurface(
      child: CachedImage(
        url: url,
        fit: BoxFit.contain,
        memCacheWidth: cacheWidth,
        placeholderColor: AppColors.surfaceInk,
        errorWidget: Container(
          color: AppColors.surfaceInk,
          alignment: Alignment.center,
          child: const Icon(
            Symbols.image_outlined,
            color: AppColors.support,
            size: 36,
          ),
        ),
      ),
    );
  }
}

class _HeroOverlay extends StatelessWidget {
  const _HeroOverlay({
    required this.article,
    required this.actionState,
    required this.onLike,
    required this.onDislike,
    required this.onComment,
    required this.onSave,
    required this.onShare,
  });

  final NewsArticle article;
  final _DetailActionState actionState;
  final VoidCallback onLike;
  final VoidCallback onDislike;
  final VoidCallback onComment;
  final VoidCallback onSave;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _HeroActionGlow(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SocialAction(
                glyph: PateezSocialGlyph.sparkUp,
                isActive: actionState.liked,
                activeColor: AppColors.deepOcean,
                inactiveColor: Colors.white,
                semanticLabel: 'Beğen',
                iconSize: 21,
                count: actionState.likes,
                countFontSize: 11,
                onTap: onLike,
              ),
              SocialAction(
                glyph: PateezSocialGlyph.sparkDown,
                isActive: actionState.disliked,
                activeColor: AppColors.actionRed,
                inactiveColor: Colors.white,
                semanticLabel: 'Beğenme',
                iconSize: 21,
                count: actionState.dislikes,
                countFontSize: 11,
                onTap: onDislike,
              ),
              SocialAction(
                glyph: PateezSocialGlyph.conversation,
                isActive: false,
                activeColor: AppColors.deepOcean,
                inactiveColor: Colors.white,
                semanticLabel: 'Yorumlar',
                iconSize: 24,
                count: article.comments,
                countFontSize: 11,
                onTap: onComment,
              ),
              SocialAction(
                glyph: PateezSocialGlyph.forwardShare,
                isActive: false,
                activeColor: AppColors.warmHorizon,
                inactiveColor: Colors.white,
                semanticLabel: 'Paylaş',
                iconSize: 24,
                count: actionState.shares,
                countFontSize: 11,
                onTap: onShare,
              ),
              const Spacer(),
              SocialAction(
                glyph: PateezSocialGlyph.ribbon,
                isActive: actionState.saved,
                activeColor: AppColors.warmHorizon,
                inactiveColor: Colors.white,
                semanticLabel: 'Kaydet',
                iconSize: 26,
                onTap: onSave,
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        _HeroPublishedAt(date: article.publishedAt),
      ],
    );
  }
}

class _HeroActionGlow extends StatelessWidget {
  const _HeroActionGlow({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: const RadialGradient(
          center: Alignment.center,
          radius: 1.18,
          colors: [Color(0x4A000000), Color(0x24000000), Color(0x00000000)],
          stops: [0.0, 0.58, 1.0],
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x30000000), blurRadius: 24, spreadRadius: 3),
        ],
      ),
      child: child,
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

class _RelatedSectionDivider extends StatelessWidget {
  const _RelatedSectionDivider();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.canvas,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageHorizontal,
          AppSpacing.lg,
          AppSpacing.pageHorizontal,
          AppSpacing.md,
        ),
        child: Row(
          children: [
            Expanded(child: Container(height: 1, color: AppColors.line)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'İLGİNİZİ ÇEKEBİLİR',
                style: AppTypography.meta.copyWith(
                  color: AppColors.placeholderSoft,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  letterSpacing: 0,
                ),
              ),
            ),
            Expanded(child: Container(height: 1, color: AppColors.line)),
          ],
        ),
      ),
    );
  }
}

class _DetailItemsSection extends StatelessWidget {
  const _DetailItemsSection({
    required this.article,
    required this.categoryTrail,
    required this.videoFeedArticles,
    required this.shellSettings,
    required this.authState,
    required this.postActionRepository,
    required this.onAuthRequired,
    required this.onAuthorTap,
    required this.onFullscreenVideoExit,
  });

  final NewsArticle article;
  final List<String> categoryTrail;
  final List<NewsArticle> videoFeedArticles;
  final AppShellSettings shellSettings;
  final FrontendAuthState? authState;
  final PostActionRepository postActionRepository;
  final VoidCallback? onAuthRequired;
  final ValueChanged<NewsAuthor>? onAuthorTap;
  final VoidCallback? onFullscreenVideoExit;

  @override
  Widget build(BuildContext context) {
    final items = article.detailItems;
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (items.isEmpty) ...[
            _DetailTextInset(child: _TextDetailBlock(text: article.summary)),
            const FrontendAdSlot(slotKey: 'mobile_detail_incontent'),
          ] else
            for (var i = 0; i < items.length; i++) ...[
              _DetailItemBlock(
                article: article,
                item: items[i],
                categoryTrail: categoryTrail,
                videoFeedArticles: videoFeedArticles,
                shellSettings: shellSettings,
                authState: authState,
                postActionRepository: postActionRepository,
                onAuthRequired: onAuthRequired,
                onAuthorTap: onAuthorTap,
                onFullscreenVideoExit: onFullscreenVideoExit,
              ),
              if (i == 0)
                const FrontendAdSlot(slotKey: 'mobile_detail_incontent'),
              if (i == 2)
                const FrontendAdSlot(slotKey: 'mobile_detail_midcontent'),
              if (i != items.length - 1) const SizedBox(height: AppSpacing.xxl),
            ],
        ],
      ),
    );
  }
}

class _DetailFaqSection extends StatelessWidget {
  const _DetailFaqSection({required this.items});

  final List<NewsFaqItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        AppSpacing.sm,
        AppSpacing.pageHorizontal,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _DetailFaqHeader(),
          const SizedBox(height: 8),
          for (var i = 0; i < items.length; i++) ...[
            _DetailFaqItem(item: items[i]),
            if (i != items.length - 1) const SizedBox(height: 5),
          ],
        ],
      ),
    );
  }
}

class _DetailFaqHeader extends StatelessWidget {
  const _DetailFaqHeader();

  @override
  Widget build(BuildContext context) {
    return Text(
      'FAQ',
      style: AppTypography.meta.copyWith(
        color: AppColors.placeholder,
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
        height: 1,
        letterSpacing: 0.6,
      ),
    );
  }
}

class _DetailFaqItem extends StatefulWidget {
  const _DetailFaqItem({required this.item});

  final NewsFaqItem item;

  @override
  State<_DetailFaqItem> createState() => _DetailFaqItemState();
}

class _DetailFaqItemState extends State<_DetailFaqItem> {
  bool _expanded = false;

  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      expanded: _expanded,
      label: widget.item.question,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _toggle,
          borderRadius: BorderRadius.circular(7),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
            decoration: BoxDecoration(
              color: _expanded
                  ? AppColors.surfaceSoft.withValues(alpha: 0.86)
                  : AppColors.surfaceSoft.withValues(alpha: 0.58),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: _expanded ? AppColors.line : AppColors.softLine,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      alignment: Alignment.center,
                      margin: const EdgeInsets.only(top: 1),
                      decoration: BoxDecoration(
                        color: AppColors.actionRed.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '?',
                        style: AppTypography.meta.copyWith(
                          color: AppColors.actionRed.withValues(alpha: 0.58),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          height: 1,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.item.question,
                        maxLines: _expanded ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleM.copyWith(
                          color: AppColors.inkStrong.withValues(alpha: 0.84),
                          fontSize: 12.2,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      child: const Icon(
                        Symbols.keyboard_arrow_down_rounded,
                        size: 16,
                        color: AppColors.placeholder,
                      ),
                    ),
                  ],
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: _expanded
                      ? Padding(
                          padding: const EdgeInsets.only(
                            left: 24,
                            top: 6,
                            right: 16,
                          ),
                          child: Text(
                            widget.item.answer,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.inkSoft.withValues(alpha: 0.78),
                              fontSize: 11.4,
                              fontWeight: FontWeight.w400,
                              height: 1.35,
                              letterSpacing: 0,
                            ),
                          ),
                        )
                      : const SizedBox(width: double.infinity),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailTagsSection extends StatelessWidget {
  const _DetailTagsSection({required this.tags});

  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();
    final visibleTags = tags.take(8).toList(growable: false);
    final hiddenCount = tags.length - visibleTags.length;
    return Container(
      width: double.infinity,
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        0,
        AppSpacing.pageHorizontal,
        AppSpacing.md,
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 5,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Etiketler:',
            style: AppTypography.meta.copyWith(
              color: AppColors.inkSoft,
              fontSize: 11.6,
              fontWeight: FontWeight.w700,
              height: 1.15,
              letterSpacing: 0,
            ),
          ),
          for (final tag in visibleTags) _DetailTagLabel(tag: tag),
          if (hiddenCount > 0)
            Text(
              '+$hiddenCount',
              style: AppTypography.meta.copyWith(
                color: AppColors.placeholder,
                fontSize: 10.8,
                fontWeight: FontWeight.w700,
                height: 1.15,
                letterSpacing: 0,
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailTagLabel extends StatelessWidget {
  const _DetailTagLabel({required this.tag});

  final String tag;

  @override
  Widget build(BuildContext context) {
    return Text(
      '#$tag',
      style: AppTypography.meta.copyWith(
        color: AppColors.inkStrong.withValues(alpha: 0.88),
        fontSize: 11.4,
        fontWeight: FontWeight.w700,
        height: 1.15,
        letterSpacing: 0,
        decoration: TextDecoration.underline,
        decorationColor: AppColors.warmHorizon.withValues(alpha: 0.38),
        decorationThickness: 1.1,
      ),
    );
  }
}

class _DetailItemBlock extends StatelessWidget {
  const _DetailItemBlock({
    required this.article,
    required this.item,
    required this.categoryTrail,
    required this.videoFeedArticles,
    required this.shellSettings,
    required this.authState,
    required this.postActionRepository,
    required this.onAuthRequired,
    required this.onAuthorTap,
    required this.onFullscreenVideoExit,
  });

  final NewsArticle article;
  final NewsDetailItem item;
  final List<String> categoryTrail;
  final List<NewsArticle> videoFeedArticles;
  final AppShellSettings shellSettings;
  final FrontendAuthState? authState;
  final PostActionRepository postActionRepository;
  final VoidCallback? onAuthRequired;
  final ValueChanged<NewsAuthor>? onAuthorTap;
  final VoidCallback? onFullscreenVideoExit;

  @override
  Widget build(BuildContext context) {
    final pollData = item.pollData;
    if (pollData != null && pollData.isValid) {
      return _DetailTextInset(
        child: DetailPollBlock(
          data: pollData,
          title: _nonDuplicateItemText(item.title, pollData.title),
          description: _nonDuplicateItemText(
            item.description,
            pollData.description,
          ),
          onVoteRecorded: _recordPollVote,
        ),
      );
    }

    final quizData = item.quizData;
    if (quizData != null && quizData.isValid) {
      return _DetailTextInset(
        child: DetailQuizBlock(
          data: quizData,
          title: _nonDuplicateItemText(item.title, article.title),
          description: _nonDuplicateItemText(item.description, article.summary),
        ),
      );
    }

    final tocData = item.tocData;
    if (tocData != null && tocData.isValid) {
      return _DetailTextInset(
        child: DetailTocBlock(
          data: tocData,
          title: _nonDuplicateItemText(item.title, article.title),
          description: _nonDuplicateItemText(item.description, article.summary),
        ),
      );
    }

    final recipeData = item.recipeData;
    if (recipeData != null && recipeData.isValid) {
      return _DetailTextInset(
        child: DetailRecipeBlock(
          data: recipeData,
          title: _nonDuplicateItemText(item.title, article.title),
          description: _nonDuplicateItemText(item.description, article.summary),
        ),
      );
    }

    final eventData = item.eventData;
    if (eventData != null && eventData.isValid) {
      return _DetailTextInset(
        child: DetailEventBlock(
          data: eventData,
          title: _nonDuplicateItemText(item.title, article.title),
          description: _nonDuplicateItemText(item.description, article.summary),
        ),
      );
    }

    final rendersEmbedDirectly = _rendersDetailEmbedDirectly(item);
    final mediaArticle = rendersEmbedDirectly
        ? null
        : _mediaArticleForItem(article, item);
    final hasMedia = mediaArticle != null || rendersEmbedDirectly;
    final showTitle = _showExternalItemTitle(item);
    final descriptionBeforeMedia = _descriptionRenderedBeforeMedia(item);
    final hasExtraInfo = _hasItemExtraInfo(item);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!hasMedia && item.title.isNotEmpty)
          _DetailTextInset(child: _ItemTitle(text: item.title)),
        if (!hasMedia && item.description.isNotEmpty) ...[
          if (item.title.isNotEmpty) const SizedBox(height: AppSpacing.sm),
          _DetailTextInset(child: _TextDetailBlock(text: item.description)),
        ],
        if (hasMedia) ...[
          if (showTitle) _DetailTextInset(child: _ItemTitle(text: item.title)),
          if (item.description.isNotEmpty && descriptionBeforeMedia) ...[
            const SizedBox(height: AppSpacing.xs),
            _DetailTextInset(child: _ItemDescription(text: item.description)),
          ],
          if (showTitle ||
              (item.description.isNotEmpty && descriptionBeforeMedia))
            const SizedBox(height: AppSpacing.md),
          if (rendersEmbedDirectly)
            _DetailTextInset(child: _DetailEmbedStage(item: item))
          else
            _mediaCard(mediaArticle!),
          if (item.description.isNotEmpty &&
              !descriptionBeforeMedia &&
              !_descriptionRenderedInsideMedia(item)) ...[
            const SizedBox(height: AppSpacing.md),
            _DetailTextInset(child: _ItemDescription(text: item.description)),
          ],
        ],
        if (hasExtraInfo) ...[
          const SizedBox(height: AppSpacing.xs),
          _DetailTextInset(child: _ItemExtraInfo(item: item)),
        ],
      ],
    );
  }

  Widget _mediaCard(NewsArticle mediaArticle) {
    return NewsCard(
      article: mediaArticle,
      onTap: () {},
      categoryTrail: categoryTrail,
      videoFeedArticles: videoFeedArticles,
      shellSettings: shellSettings,
      commentsEnabled: false,
      showTitleSummary: false,
      showReadStats: false,
      showActions: false,
      showComments: false,
      showMediaHeader: false,
      showStructuredMediaText: false,
      resolveActualImageAspectRatio: true,
      authState: authState,
      postActionRepository: postActionRepository,
      onAuthRequired: onAuthRequired,
      onAuthorTap: onAuthorTap,
      onFullscreenVideoExit: onFullscreenVideoExit,
    );
  }

  void _recordPollVote() {
    if (int.tryParse(article.id) == null) return;
    final token = authState?.session.accessToken.trim() ?? '';
    unawaited(_sendPollVoteRead(token));
  }

  Future<void> _sendPollVoteRead(String token) async {
    try {
      await postActionRepository.recordView(
        postId: article.id,
        token: token.isEmpty ? null : token,
        source: 'poll_vote',
      );
    } catch (_) {
      // Oy yerelde işlendi; okuma metriği yazılamazsa kullanıcı akışı bozulmaz.
    }
  }
}

class _DetailEmbedStage extends StatelessWidget {
  const _DetailEmbedStage({required this.item});

  final NewsDetailItem item;

  @override
  Widget build(BuildContext context) {
    return SocialEmbedStage(
      embed: item.mediaUrl,
      sourceUrl: item.moreInfoUrl,
      platform: item.type == 'iframe' ? 'iframe' : '',
    );
  }
}

class _DetailTextInset extends StatelessWidget {
  const _DetailTextInset({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageHorizontal,
      ),
      child: child,
    );
  }
}

class _TextDetailBlock extends StatelessWidget {
  const _TextDetailBlock({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return Text(
      text,
      style: AppTypography.mobileDetailBody.copyWith(
        color: AppColors.ink,
        height: 1.62,
        letterSpacing: 0,
      ),
    );
  }
}

class _ItemTitle extends StatelessWidget {
  const _ItemTitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTypography.titleL.copyWith(
        color: AppColors.inkStrong,
        fontSize: 20.5,
        fontWeight: FontWeight.w800,
        height: 1.2,
        letterSpacing: 0,
      ),
    );
  }
}

class _ItemDescription extends StatelessWidget {
  const _ItemDescription({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTypography.body.copyWith(
        color: AppColors.inkSoft,
        height: 1.5,
        fontSize: 14,
        letterSpacing: 0,
      ),
    );
  }
}

class _ItemExtraInfo extends StatelessWidget {
  const _ItemExtraInfo({required this.item});

  final NewsDetailItem item;

  @override
  Widget build(BuildContext context) {
    final altText = item.altText.trim();
    final source = item.source.trim();
    final moreInfoUrl = item.moreInfoUrl.trim();
    final sourceUri = _sourceUri(moreInfoUrl.isNotEmpty ? moreInfoUrl : source);
    final sourceText = _sourceText(source: source, moreInfoUrl: moreInfoUrl);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (altText.isNotEmpty) _ItemInfoLine(text: altText),
        if (altText.isNotEmpty && sourceText.isNotEmpty)
          const SizedBox(height: AppSpacing.xxs),
        if (sourceText.isNotEmpty)
          _ItemInfoLine(text: sourceText, uri: sourceUri),
      ],
    );
  }
}

class _ItemInfoLine extends StatelessWidget {
  const _ItemInfoLine({required this.text, this.uri});

  final String text;
  final Uri? uri;

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.meta.copyWith(
      color: AppColors.support.withValues(alpha: 0.72),
      fontSize: 10.5,
      fontStyle: FontStyle.italic,
      height: 1.28,
      letterSpacing: 0,
      decoration: uri == null ? null : TextDecoration.underline,
      decorationColor: AppColors.support.withValues(alpha: 0.42),
      decorationThickness: 1,
    );
    final line = Text(text, style: style);
    final targetUri = uri;
    if (targetUri == null) return line;
    return Semantics(
      link: true,
      child: InkWell(
        onTap: () => unawaited(openFrontendUri(targetUri)),
        borderRadius: BorderRadius.circular(4),
        child: line,
      ),
    );
  }
}

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

String _nonDuplicateItemText(String itemText, String articleText) {
  final cleanItem = itemText.trim();
  if (cleanItem.isEmpty) return '';
  final cleanArticle = articleText.trim();
  if (cleanArticle.isEmpty) return cleanItem;
  return cleanItem.toLowerCase() == cleanArticle.toLowerCase() ? '' : cleanItem;
}

bool _showExternalItemTitle(NewsDetailItem item) {
  final type = item.type;
  return item.title.isNotEmpty &&
      type != 'quote' &&
      type != 'paragraph' &&
      type != 'review';
}

bool _descriptionRenderedInsideMedia(NewsDetailItem item) {
  final type = item.type;
  return type == 'review' || type == 'quote';
}

bool _descriptionRenderedBeforeMedia(NewsDetailItem item) {
  return !_descriptionRenderedInsideMedia(item);
}

bool _rendersDetailEmbedDirectly(NewsDetailItem item) {
  final type = item.type;
  return (type == 'social' || type == 'iframe' || type == 'embed') &&
      item.mediaUrl.trim().isNotEmpty;
}

bool _hasItemExtraInfo(NewsDetailItem item) {
  return item.altText.trim().isNotEmpty ||
      item.source.trim().isNotEmpty ||
      item.moreInfoUrl.trim().isNotEmpty;
}

String _sourceText({required String source, required String moreInfoUrl}) {
  final cleanSource = source.trim();
  final cleanUrl = moreInfoUrl.trim();
  if (cleanSource.isNotEmpty && cleanUrl.isNotEmpty) {
    return '$cleanSource · Daha fazla bilgi';
  }
  if (cleanSource.isNotEmpty) return cleanSource;
  return cleanUrl;
}

Uri? _sourceUri(String value) {
  final raw = value.trim();
  if (raw.isEmpty || raw.contains(RegExp(r'\s'))) return null;
  final uri = Uri.tryParse(raw);
  if (uri != null && _isHttpUri(uri)) return uri;
  if (raw.startsWith('www.') ||
      RegExp(r'^[a-z0-9-]+(\.[a-z0-9-]+)+').hasMatch(raw)) {
    final withScheme = Uri.tryParse('https://$raw');
    if (withScheme != null && _isHttpUri(withScheme)) return withScheme;
  }
  return null;
}

bool _isHttpUri(Uri uri) {
  final scheme = uri.scheme.toLowerCase();
  return scheme == 'http' || scheme == 'https';
}

double? _positiveImageAspectRatio(double? value) {
  if (value == null || !value.isFinite || value <= 0) return null;
  return value;
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

NewsArticle? _mediaArticleForItem(NewsArticle base, NewsDetailItem item) {
  final type = item.type;
  final hasImage = type == 'image' && item.mediaUrl.isNotEmpty;
  final hasSlider = type == 'slider' && item.mediaUrls.isNotEmpty;
  final hasVideo = type == 'video' && item.mediaUrl.isNotEmpty;
  final hasAudio = type == 'audio' && item.mediaUrl.isNotEmpty;
  final hasEmbed =
      (type == 'social' || type == 'iframe' || type == 'embed') &&
      item.mediaUrl.isNotEmpty;
  final hasStructured =
      item.flipData != null ||
      item.beforeAfterData != null ||
      item.reviewData != null ||
      item.pollData != null ||
      item.vsData != null ||
      item.quoteData != null;

  if (!hasImage &&
      !hasSlider &&
      !hasVideo &&
      !hasAudio &&
      !hasEmbed &&
      !hasStructured) {
    return null;
  }

  final imageUrl = hasImage
      ? item.mediaUrl
      : hasSlider
      ? item.mediaUrls.first
      : base.imageUrl;
  final resolveItemImageRatio = hasImage || hasSlider;
  final hideMediaHeadline = type == 'poll' || type == 'vs';
  return NewsArticle(
    id: '${base.id}-${item.id}',
    author: base.author,
    region: base.region,
    category: base.category,
    categoryTrail: base.categoryTrail,
    title: hideMediaHeadline
        ? ''
        : (item.title.isNotEmpty ? item.title : base.title),
    summary: hideMediaHeadline ? '' : item.description,
    imageUrl: imageUrl,
    publishedAt: base.publishedAt,
    readMinutes: base.readMinutes,
    likes: base.likes,
    dislikes: base.dislikes,
    comments: base.comments,
    shares: base.shares,
    views: base.views,
    saves: base.saves,
    userLiked: base.userLiked,
    userDisliked: base.userDisliked,
    userSaved: base.userSaved,
    slug: base.slug,
    imageAspectRatio: resolveItemImageRatio ? null : base.imageAspectRatio,
    sliderImages: hasSlider ? item.mediaUrls : const [],
    videoUrl: hasVideo ? item.mediaUrl : '',
    videoUrls: hasVideo ? <String>[item.mediaUrl] : const [],
    videoThumbUrls: hasVideo && item.videoThumbUrl.isNotEmpty
        ? <String>[item.videoThumbUrl]
        : const [],
    audioUrl: hasAudio ? item.mediaUrl : '',
    socialEmbed: hasEmbed ? item.mediaUrl : '',
    socialSourceUrl: hasEmbed ? item.mediaUrl : '',
    socialPlatform: '',
    flipData: item.flipData,
    beforeAfterData: item.beforeAfterData,
    reviewData: item.reviewData,
    pollData: item.pollData,
    vsData: item.vsData,
    quoteData: item.quoteData,
  );
}

List<String> _categoryTrail(
  String category,
  List<AppShellNavigationItem> navigationItems,
) {
  final cleanCategory = category.trim();
  if (cleanCategory.isEmpty) return const [];

  AppShellNavigationItem? current;
  for (final item in navigationItems) {
    if (item.label == cleanCategory || item.value == cleanCategory) {
      current = item;
      break;
    }
  }
  if (current == null) return [cleanCategory];

  final trail = <String>[current.label];
  final visited = <String>{current.id};
  var parentId = current.parentId;
  while (parentId != null &&
      parentId != 'root' &&
      !visited.contains(parentId)) {
    visited.add(parentId);
    AppShellNavigationItem? parent;
    for (final item in navigationItems) {
      if (item.id == parentId) {
        parent = item;
        break;
      }
    }
    if (parent == null || parent.label.trim().isEmpty) break;
    trail.insert(0, parent.label);
    parentId = parent.parentId;
  }

  return trail;
}

List<String> _articleCategoryTrail(
  NewsArticle article,
  List<AppShellNavigationItem> navigationItems,
) {
  final explicitTrail = article.categoryTrail
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
  if (explicitTrail.isNotEmpty) return explicitTrail;
  return _categoryTrail(article.category, navigationItems);
}

List<NewsArticle> _dateSortedVideoFeed(List<NewsArticle> items) {
  final videos = items
      .where((item) => item.videoFeedUrls.isNotEmpty)
      .toList(growable: false);
  return List<NewsArticle>.of(videos)
    ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
}
