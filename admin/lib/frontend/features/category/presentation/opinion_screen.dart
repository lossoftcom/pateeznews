import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../core/mock/home_mock_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/cached_image.dart';
import '../../../shared/widgets/data_unavailable_state.dart';
import '../../account/data/frontend_auth_repository.dart';
import '../../home/data/feed_ranking.dart';
import '../../home/data/home_repository.dart';
import '../../home/presentation/widgets/feed_filter_tabs.dart';
import '../../home/presentation/widgets/news_card.dart';
import '../../news_detail/presentation/news_detail_screen.dart';
import '../../shell/data/app_shell_repository.dart';
import '../data/category_repository.dart';
import '../data/opinion_summary.dart';
import 'widgets/category_app_bar.dart';

enum OpinionScreenView { articles, authors }

class OpinionScreen extends StatefulWidget {
  const OpinionScreen({
    super.key,
    required this.categoryName,
    this.categoryType = 'category',
    this.categoryValue = 'kose-yazisi',
    this.categoryRepository = const CategoryRepository(),
    this.initialItems,
    this.initialTotal,
    this.initialTotalViews,
    this.initialView = OpinionScreenView.articles,
    this.shellSettings = const AppShellSettings.empty(),
    this.navigationItems = const [],
    this.contentSettings = const HomeContentSettings.defaults(),
    this.authState,
    this.onAuthRequired,
    this.onAuthorTap,
    this.onFullscreenVideoExit,
    this.onSearch,
  });

  final String categoryName;
  final String categoryType;
  final String categoryValue;
  final CategoryRepository categoryRepository;
  final List<NewsArticle>? initialItems;
  final int? initialTotal;
  final int? initialTotalViews;
  final OpinionScreenView initialView;
  final AppShellSettings shellSettings;
  final List<AppShellNavigationItem> navigationItems;
  final HomeContentSettings contentSettings;
  final FrontendAuthState? authState;
  final VoidCallback? onAuthRequired;
  final ValueChanged<NewsAuthor>? onAuthorTap;
  final VoidCallback? onFullscreenVideoExit;
  final VoidCallback? onSearch;

  @override
  State<OpinionScreen> createState() => _OpinionScreenState();
}

class _OpinionScreenState extends State<OpinionScreen> {
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _scrollY = ValueNotifier<double>(0);

  late OpinionScreenView _view = widget.initialView;
  FeedFilter _filter = FeedFilter.latest;
  late List<NewsArticle> _feed = widget.initialItems ?? const [];
  late int _articleTotal = widget.initialTotal ?? _feed.length;
  late int _totalReads =
      widget.initialTotalViews ??
      _feed.fold<int>(0, (sum, article) => sum + article.views);
  late bool _loading = widget.initialItems == null;

  static const int _staggerLimit = 6;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    if (widget.initialItems == null) {
      _loadOpinion();
    }
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      _scrollY.value = _scrollController.offset;
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _scrollY.dispose();
    super.dispose();
  }

  List<NewsArticle> get _sortedFeed {
    final feed = [..._feed];
    switch (_filter) {
      case FeedFilter.latest:
        feed.sort(compareNewsByLatest);
      case FeedFilter.popular:
        feed.sort(compareNewsByPopularity);
    }
    return feed;
  }

  List<OpinionAuthorSummary> get _authors => buildOpinionAuthorSummaries(_feed);

  Future<void> _loadOpinion() async {
    setState(() => _loading = true);
    final token = widget.authState?.session.accessToken.trim() ?? '';
    final data = await widget.categoryRepository.fetchCategory(
      category: widget.categoryName,
      type: widget.categoryType,
      value: widget.categoryValue,
      limit: widget.contentSettings.homePageSize,
      token: token.isEmpty ? null : token,
    );
    if (!mounted) return;
    setState(() {
      _feed = data.items;
      _articleTotal = data.total > 0 ? data.total : data.items.length;
      _totalReads = data.totalViews > 0
          ? data.totalViews
          : data.items.fold<int>(0, (sum, article) => sum + article.views);
      _loading = false;
    });
  }

  void _openDetail(List<NewsArticle> feed, int index) {
    if (index < 0 || index >= feed.length) return;
    Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 360),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (_, _, _) => NewsDetailScreen(
          articles: feed,
          initialIndex: index,
          shellSettings: widget.shellSettings,
          navigationItems: widget.navigationItems,
          contentSettings: widget.contentSettings,
          videoFeedArticles: _dateSortedVideoFeed(_feed),
          authState: widget.authState,
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

  @override
  Widget build(BuildContext context) {
    final feed = _sortedFeed;
    final authors = _authors;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final videoFeed = _dateSortedVideoFeed(_feed);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.lightOverlay,
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        body: Column(
          children: [
            ValueListenableBuilder<double>(
              valueListenable: _scrollY,
              builder: (context, offset, _) => CategoryAppBar(
                title: 'Köşe Yazıları',
                scrollOffset: offset,
                onBack: () => Navigator.of(context).maybePop(),
                onSearch: widget.onSearch,
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.actionRed,
                backgroundColor: AppColors.surface,
                displacement: 32,
                onRefresh: _loadOpinion,
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  slivers: [
                    SliverToBoxAdapter(
                      child: ColoredBox(
                        color: AppColors.surface,
                        child: _OpinionMasthead(
                          title: widget.categoryName.trim().isEmpty
                              ? 'Köşe Yazıları'
                              : widget.categoryName.trim(),
                          articleCount: _articleTotal,
                          authorCount: authors.length,
                          totalReads: _totalReads,
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: _OpinionSwitcher(
                        view: _view,
                        filter: _filter,
                        onViewChanged: (view) => setState(() => _view = view),
                        onFilterChanged: (filter) =>
                            setState(() => _filter = filter),
                      ),
                    ),
                    if (_loading && _feed.isEmpty)
                      const SliverToBoxAdapter(child: _OpinionLoadingState())
                    else if (_feed.isEmpty)
                      const SliverToBoxAdapter(
                        child: DataUnavailableState(
                          message: 'Köşe yazısı akışı için yayın bulunamadı.',
                          minHeight: 280,
                        ),
                      )
                    else if (_view == OpinionScreenView.authors)
                      SliverList.builder(
                        itemCount: authors.length,
                        itemBuilder: (context, index) => Padding(
                          padding: EdgeInsets.fromLTRB(
                            AppSpacing.pageHorizontal,
                            index == 0 ? 0 : AppSpacing.md,
                            AppSpacing.pageHorizontal,
                            index == authors.length - 1 ? 0 : 0,
                          ),
                          child:
                              _AuthorCard(
                                summary: authors[index],
                                onAuthorTap: () => widget.onAuthorTap?.call(
                                  authors[index].author,
                                ),
                                onLatestTap: () => _openDetail(<NewsArticle>[
                                  authors[index].latestArticle,
                                ], 0),
                              ).animate().fadeIn(
                                delay: (40 * index.clamp(0, 6)).ms,
                                duration: 260.ms,
                                curve: Curves.easeOutCubic,
                              ),
                        ),
                      )
                    else
                      SliverList.builder(
                        itemCount: feed.length,
                        itemBuilder: (context, index) {
                          Widget card = NewsCard(
                            article: feed[index],
                            onTap: () => _openDetail(feed, index),
                            categoryTrail: feed[index].categoryTrail,
                            videoFeedArticles: videoFeed,
                            shellSettings: widget.shellSettings,
                            commentsEnabled:
                                widget.contentSettings.commentSystem,
                            commentApprovalEnabled:
                                widget.contentSettings.commentApprovalSystem,
                            emojiReactionsEnabled:
                                widget.contentSettings.emojiReactions,
                            authState: widget.authState,
                            onAuthRequired: widget.onAuthRequired,
                            onAuthorTap: widget.onAuthorTap,
                            onFullscreenVideoExit: widget.onFullscreenVideoExit,
                          );
                          if (index < _staggerLimit) {
                            card = card
                                .animate()
                                .fadeIn(
                                  delay: (60 * index).ms,
                                  duration: 320.ms,
                                  curve: Curves.easeOutCubic,
                                )
                                .slideY(
                                  begin: 0.04,
                                  end: 0,
                                  delay: (60 * index).ms,
                                  duration: 320.ms,
                                  curve: Curves.easeOutCubic,
                                );
                          }
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: index < feed.length - 1
                                  ? AppSpacing.xxl
                                  : 0,
                            ),
                            child: card,
                          );
                        },
                      ),
                    SliverToBoxAdapter(
                      child: SizedBox(height: AppSpacing.xxxl + bottomInset),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<NewsArticle> _dateSortedVideoFeed(List<NewsArticle> items) {
    final videos = items
        .where((item) => item.videoFeedUrls.isNotEmpty)
        .toList(growable: false);
    return List<NewsArticle>.of(videos)
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
  }
}

class _OpinionMasthead extends StatelessWidget {
  const _OpinionMasthead({
    required this.title,
    required this.articleCount,
    required this.authorCount,
    required this.totalReads,
  });

  final String title;
  final int articleCount;
  final int authorCount;
  final int totalReads;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        AppSpacing.lg,
        AppSpacing.pageHorizontal,
        AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Symbols.edit_note_outlined,
                size: 15,
                color: AppColors.actionRed,
              ),
              const SizedBox(width: 7),
              Text(
                'Köşe yazıları',
                style: AppTypography.eyebrow.copyWith(
                  color: AppColors.support,
                  fontSize: 11,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: 30,
                margin: const EdgeInsets.only(top: 4, right: AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.actionRed,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.mobileDetailTitle.copyWith(
                    color: AppColors.inkStrong,
                    height: 1.05,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          Text(
            'Yazarların güncel yorumları, gündem notları ve kişisel bakış açıları.',
            style: AppTypography.body.copyWith(
              color: AppColors.inkSoft,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _StatCell(label: 'Yazı', value: articleCount),
              ),
              Expanded(
                child: _StatCell(label: 'Yazar', value: authorCount),
              ),
              Expanded(
                child: _StatCell(label: 'Okunma', value: totalReads),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        border: Border.all(color: AppColors.softLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _compact(value),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.titleM.copyWith(
              color: AppColors.inkStrong,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTypography.meta.copyWith(
              color: AppColors.support,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _OpinionSwitcher extends StatelessWidget {
  const _OpinionSwitcher({
    required this.view,
    required this.filter,
    required this.onViewChanged,
    required this.onFilterChanged,
  });

  final OpinionScreenView view;
  final FeedFilter filter;
  final ValueChanged<OpinionScreenView> onViewChanged;
  final ValueChanged<FeedFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        AppSpacing.xl,
        AppSpacing.pageHorizontal,
        AppSpacing.md + 2,
      ),
      child: Row(
        children: [
          _ViewTab(
            label: 'Yazılar',
            active: view == OpinionScreenView.articles,
            onTap: () => onViewChanged(OpinionScreenView.articles),
          ),
          const SizedBox(width: 6),
          _ViewTab(
            label: 'Yazarlar',
            active: view == OpinionScreenView.authors,
            onTap: () => onViewChanged(OpinionScreenView.authors),
          ),
          const Spacer(),
          if (view == OpinionScreenView.articles)
            FeedFilterTabs(filter: filter, onChange: onFilterChanged),
        ],
      ),
    );
  }
}

class _ViewTab extends StatelessWidget {
  const _ViewTab({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: active ? AppColors.actionRed : AppColors.surface,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: active ? AppColors.actionRed : AppColors.line,
            ),
          ),
          child: Text(
            label,
            style: AppTypography.meta.copyWith(
              color: active ? Colors.white : AppColors.inkSoft,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthorCard extends StatelessWidget {
  const _AuthorCard({
    required this.summary,
    required this.onAuthorTap,
    required this.onLatestTap,
  });

  final OpinionAuthorSummary summary;
  final VoidCallback onAuthorTap;
  final VoidCallback onLatestTap;

  @override
  Widget build(BuildContext context) {
    final author = summary.author;
    final handle = (author.handle ?? '').trim();
    final avatarUrl = author.avatarUrl.trim();
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(5),
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
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onAuthorTap,
            child: Row(
              children: [
                _AuthorAvatar(imageUrl: avatarUrl, initials: summary.initials),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              author.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.titleM.copyWith(
                                color: AppColors.inkStrong,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const Icon(
                            Symbols.verified,
                            size: 15,
                            color: AppColors.actionRed,
                          ),
                        ],
                      ),
                      if (handle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          handle.startsWith('@') ? handle : '@$handle',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.meta.copyWith(
                            color: AppColors.support,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (summary.info.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              summary.info,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.inkSoft,
                height: 1.45,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onLatestTap,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.softLine),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    summary.latestArticle.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleS.copyWith(
                      color: AppColors.inkStrong,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${_compact(summary.postCount)} yazı · ${_compact(summary.totalViews)} okunma',
                    style: AppTypography.meta.copyWith(
                      color: AppColors.support,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthorAvatar extends StatelessWidget {
  const _AuthorAvatar({required this.imageUrl, required this.initials});

  final String imageUrl;
  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: AppColors.surfaceInk,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: imageUrl.isEmpty
          ? Text(
              initials,
              style: AppTypography.titleM.copyWith(
                color: AppColors.deepOcean,
                fontWeight: FontWeight.w900,
              ),
            )
          : CachedImage(
              url: imageUrl,
              fit: BoxFit.cover,
              memCacheWidth: 140,
              errorWidget: Center(
                child: Text(
                  initials,
                  style: AppTypography.titleM.copyWith(
                    color: AppColors.deepOcean,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
    );
  }
}

class _OpinionLoadingState extends StatelessWidget {
  const _OpinionLoadingState();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 280,
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: AppColors.actionRed,
          ),
        ),
      ),
    );
  }
}

String _compact(int value) {
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1).replaceAll('.', ',')} Mn';
  }
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(1).replaceAll('.', ',')} B';
  }
  return value.toString();
}
