import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../core/mock/home_mock_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../news_detail/presentation/news_detail_screen.dart';
import '../../account/data/frontend_auth_repository.dart';
import '../../shell/data/app_shell_repository.dart';
import '../data/home_repository.dart';
import '../data/post_action_repository.dart';
import 'widgets/news_card.dart';
import 'widgets/news_video_player.dart';

/// Alt menüdeki Video sekmesi.
///
/// Ana sayfa ile aynı haber kaynağından yalnız video içeren haberleri alır ve
/// en yeni yayınlanan videoyu ilk sırada gösterir.
class VideoFeedScreen extends StatefulWidget {
  const VideoFeedScreen({
    super.key,
    required this.feedItems,
    this.shellSettings = const AppShellSettings.empty(),
    this.navigationItems = const [],
    this.contentSettings = const HomeContentSettings.defaults(),
    this.initialArticleId = '',
    this.revealSerial = 0,
    this.authState,
    this.postActionRepository = const PostActionRepository(),
    this.onRefresh,
    this.onAuthRequired,
    this.onAuthorTap,
    this.onFullscreenVideoExit,
  });

  final List<NewsArticle> feedItems;
  final AppShellSettings shellSettings;
  final List<AppShellNavigationItem> navigationItems;
  final HomeContentSettings contentSettings;
  final String initialArticleId;
  final int revealSerial;
  final FrontendAuthState? authState;
  final PostActionRepository postActionRepository;
  final Future<void> Function()? onRefresh;
  final VoidCallback? onAuthRequired;
  final ValueChanged<NewsAuthor>? onAuthorTap;
  final VoidCallback? onFullscreenVideoExit;

  @override
  State<VideoFeedScreen> createState() => _VideoFeedScreenState();
}

class _VideoFeedScreenState extends State<VideoFeedScreen> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _itemKeys = {};
  int _revealedSerial = -1;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final videos = dateSortedVideoArticles(widget.feedItems);
    _retainVisibleKeys(videos);
    _scheduleInitialReveal(videos);
    final feed = CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      controller: _scrollController,
      slivers: [
        if (videos.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyVideoFeed(),
          )
        else ...[
          const SliverToBoxAdapter(child: _VideoFeedHeader()),
          SliverList.builder(
            itemCount: videos.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index < videos.length - 1
                      ? AppSpacing.xxl
                      : AppSpacing.xl,
                ),
                child: KeyedSubtree(
                  key: _keyFor(videos[index]),
                  child: NewsCard(
                    article: videos[index],
                    onTap: () => _openDetail(context, videos, index),
                    categoryTrail: videoCategoryTrail(
                      videos[index],
                      widget.navigationItems,
                    ),
                    videoFeedArticles: videos,
                    shellSettings: widget.shellSettings,
                    commentsEnabled: widget.contentSettings.commentSystem,
                    commentApprovalEnabled:
                        widget.contentSettings.commentApprovalSystem,
                    emojiReactionsEnabled:
                        widget.contentSettings.emojiReactions,
                    authState: widget.authState,
                    postActionRepository: widget.postActionRepository,
                    onAuthRequired: widget.onAuthRequired,
                    onAuthorTap: widget.onAuthorTap,
                    onFullscreenVideoExit: widget.onFullscreenVideoExit,
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
    final onRefresh = widget.onRefresh;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        bottom: false,
        child: onRefresh == null
            ? feed
            : RefreshIndicator(
                color: AppColors.actionRed,
                backgroundColor: AppColors.surface,
                displacement: 32,
                onRefresh: onRefresh,
                child: feed,
              ),
      ),
    );
  }

  GlobalKey _keyFor(NewsArticle article) {
    return _itemKeys.putIfAbsent(videoArticleKey(article), GlobalKey.new);
  }

  void _retainVisibleKeys(List<NewsArticle> videos) {
    final ids = videos.map(videoArticleKey).toSet();
    _itemKeys.removeWhere((id, _) => !ids.contains(id));
  }

  void _scheduleInitialReveal(List<NewsArticle> videos) {
    final targetId = widget.initialArticleId.trim();
    if (targetId.isEmpty || widget.revealSerial == _revealedSerial) return;
    final index = videos.indexWhere(
      (item) => videoArticleKey(item) == targetId,
    );
    if (index < 0) return;

    _revealedSerial = widget.revealSerial;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _revealArticle(targetId, index, videos.length, attempt: 0);
    });
  }

  void _revealArticle(
    String targetId,
    int index,
    int itemCount, {
    required int attempt,
  }) {
    if (!_scrollController.hasClients) return;
    final targetContext = _itemKeys[targetId]?.currentContext;
    if (targetContext != null) {
      Scrollable.ensureVisible(
        targetContext,
        alignment: 0.08,
        duration: attempt == 0
            ? Duration.zero
            : const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
      return;
    }

    if (attempt >= 4) return;
    final position = _scrollController.position;
    final max = position.maxScrollExtent;
    final ratio = itemCount <= 1 ? 0.0 : index / (itemCount - 1);
    final offset = (max * ratio).clamp(position.minScrollExtent, max);
    _scrollController.jumpTo(offset);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _revealArticle(targetId, index, itemCount, attempt: attempt + 1);
      }
    });
  }

  void _openDetail(BuildContext context, List<NewsArticle> feed, int index) {
    if (index < 0 || index >= feed.length) return;
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 360),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (_, _, _) => NewsDetailScreen(
          articles: feed,
          initialIndex: index,
          shellSettings: widget.shellSettings,
          navigationItems: widget.navigationItems,
          contentSettings: widget.contentSettings,
          videoFeedArticles: feed,
          authState: widget.authState,
          postActionRepository: widget.postActionRepository,
          onAuthRequired: widget.onAuthRequired,
          onAuthorTap: widget.onAuthorTap,
          onFullscreenVideoExit: widget.onFullscreenVideoExit,
        ),
        transitionsBuilder: (context, animation, secondary, child) {
          final fade = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          final slide = Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(fade);
          return FadeTransition(
            opacity: fade,
            child: SlideTransition(position: slide, child: child),
          );
        },
      ),
    );
  }
}

List<NewsArticle> dateSortedVideoArticles(List<NewsArticle> items) {
  final videos = items
      .where((item) => item.videoFeedUrls.isNotEmpty)
      .toList(growable: false);
  return List<NewsArticle>.of(videos)
    ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
}

List<NewsVideoFeedItem> videoFeedItemsFromArticles({
  required List<NewsArticle> articles,
  required AppShellSettings shellSettings,
  required List<AppShellNavigationItem> navigationItems,
}) {
  final logoUrl = _fullscreenLogoUrl(shellSettings);
  final items = <NewsVideoFeedItem>[];
  for (final item in articles) {
    final urls = item.videoFeedUrls;
    for (var index = 0; index < urls.length; index += 1) {
      final url = urls[index];
      items.add(
        NewsVideoFeedItem(
          postId: item.id,
          url: url,
          poster: item.videoFeedPosterFor(url, index),
          slug: item.slug,
          publishedAt: item.publishedAt,
          title: item.title,
          author: item.author,
          region: item.region,
          category: item.category,
          categoryTrail: videoCategoryTrail(item, navigationItems),
          likes: item.likes,
          dislikes: item.dislikes,
          comments: item.comments,
          shares: item.shares,
          saves: item.saves,
          userLiked: item.userLiked,
          userDisliked: item.userDisliked,
          userSaved: item.userSaved,
          fullscreenLogoUrl: logoUrl,
        ),
      );
    }
  }
  return items;
}

List<String> videoCategoryTrail(
  NewsArticle article,
  List<AppShellNavigationItem> navigationItems,
) {
  final explicitTrail = article.categoryTrail
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
  if (explicitTrail.isNotEmpty) return explicitTrail;

  final cleanCategory = article.category.trim();
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

String _fullscreenLogoUrl(AppShellSettings settings) {
  return settings.displayLogoUrl;
}

String videoArticleKey(NewsArticle article) {
  final id = article.id.trim();
  if (id.isNotEmpty) return id;
  return article.primaryVideoUrl;
}

class _VideoFeedHeader extends StatelessWidget {
  const _VideoFeedHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        12,
        AppSpacing.pageHorizontal,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          const Icon(
            Symbols.play_circle_rounded,
            color: AppColors.deepOcean,
            size: 24,
          ),
          const SizedBox(width: 8),
          Text(
            'Video',
            style: AppTypography.titleM.copyWith(
              color: AppColors.inkStrong,
              height: 1.1,
            ),
          ),
          const Spacer(),
          Text(
            'En yeni',
            style: AppTypography.meta.copyWith(
              color: AppColors.support,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyVideoFeed extends StatelessWidget {
  const _EmptyVideoFeed();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pageHorizontal,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Symbols.play_circle_outline_rounded,
              size: 34,
              color: AppColors.support,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Video bulunamadı',
              style: AppTypography.titleS.copyWith(color: AppColors.ink),
            ),
          ],
        ),
      ),
    );
  }
}
