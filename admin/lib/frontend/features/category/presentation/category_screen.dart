import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/mock/home_mock_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/data_unavailable_state.dart';
import '../../account/data/frontend_auth_repository.dart';
import '../../home/data/feed_ranking.dart';
import '../../home/data/home_repository.dart';
import '../../home/presentation/widgets/feed_filter_tabs.dart';
import '../../home/presentation/widgets/news_card.dart';
import '../../news_detail/presentation/news_detail_screen.dart';
import '../../shell/data/app_shell_repository.dart';
import '../data/category_content.dart';
import '../data/category_repository.dart';
import 'widgets/category_app_bar.dart';
import 'widgets/category_masthead.dart';

/// Pateeznews kategori (bölüm) sayfası.
///
/// Yapı:
///   [Sabit app bar — kaydırınca başlık belirir]
///   [Beyaz üst blok: kategori masthead'i + alt başlık şeridi]
///   [Gri zemin: "Son haberler" başlığı + sıralama + sosyal haber kartları]
///
/// Tasarım, ana sayfanın beyaz-üst / gri-akış kurgusunu, 4px keskin radius
/// dilini, action red vurgularını ve PateezInter tipografisini birebir korur;
/// haber kartları ana sayfadakiyle aynı [NewsCard] widget'ıdır.
class CategoryScreen extends StatefulWidget {
  const CategoryScreen({
    super.key,
    required this.categoryName,
    this.categoryType = 'category',
    this.categoryValue = '',
    this.categoryRepository = const CategoryRepository(),
    this.initialItems,
    this.initialTotal,
    this.initialTotalViews,
    this.shellSettings = const AppShellSettings.empty(),
    this.navigationItems = const [],
    this.contentSettings = const HomeContentSettings.defaults(),
    this.authState,
    this.onAuthRequired,
    this.onAuthorTap,
    this.onFullscreenVideoExit,
  });

  /// Yan menüden tıklanan öğenin etiketi (ör. "Ekonomi").
  final String categoryName;

  /// Öğe tipi: category / district / trends / dropdown / link.
  final String categoryType;
  final String categoryValue;
  final CategoryRepository categoryRepository;
  final List<NewsArticle>? initialItems;
  final int? initialTotal;
  final int? initialTotalViews;
  final AppShellSettings shellSettings;
  final List<AppShellNavigationItem> navigationItems;
  final HomeContentSettings contentSettings;
  final FrontendAuthState? authState;
  final VoidCallback? onAuthRequired;
  final ValueChanged<NewsAuthor>? onAuthorTap;
  final VoidCallback? onFullscreenVideoExit;

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _scrollY = ValueNotifier<double>(0);

  late final CategoryContent _content = CategoryContent.fromNavigation(
    label: widget.categoryName,
    type: widget.categoryType,
    value: widget.categoryValue,
  );

  FeedFilter _filter = FeedFilter.latest;
  late List<NewsArticle> _feed = widget.initialItems ?? const [];
  late int _articleTotal = widget.initialTotal ?? _feed.length;
  late int _totalReads =
      widget.initialTotalViews ??
      _feed.fold<int>(0, (sum, article) => sum + article.views);
  late bool _loading = widget.initialItems == null;

  /// Giriş animasyonu yalnızca ilk ekrandaki kartlara uygulanır.
  static const int _staggerLimit = 6;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    if (widget.initialItems == null) {
      _loadCategory();
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    _scrollY.value = _scrollController.offset;
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _scrollY.dispose();
    super.dispose();
  }

  /// Seçilen sıralamaya göre düzenlenmiş akış. Trend sayfalarında "En yeni"
  /// seçimi yayın tarihine göre, "Popüler" seçimi etkileşim harmanına göre çalışır.
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

  Future<void> _loadCategory() async {
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
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 360),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (_, _, _) =>
            NewsDetailScreen(articles: feed, initialIndex: index),
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
                title: _content.title,
                scrollOffset: offset,
                onBack: () => Navigator.of(context).maybePop(),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.actionRed,
                backgroundColor: AppColors.surface,
                displacement: 32,
                onRefresh: _loadCategory,
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  slivers: [
                    SliverToBoxAdapter(
                      child: ColoredBox(
                        color: AppColors.surface,
                        child:
                            CategoryMasthead(
                                  content: _content,
                                  articleCount: _articleTotal,
                                  totalReads: _totalReads,
                                )
                                .animate()
                                .fadeIn(
                                  duration: 360.ms,
                                  curve: Curves.easeOutCubic,
                                )
                                .slideY(
                                  begin: 0.05,
                                  end: 0,
                                  duration: 360.ms,
                                  curve: Curves.easeOutCubic,
                                ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: _FeedSectionHeader(
                        filter: _filter,
                        onChange: (f) => setState(() => _filter = f),
                      ),
                    ),
                    if (_loading && feed.isEmpty)
                      const SliverToBoxAdapter(child: _CategoryLoadingState())
                    else if (feed.isEmpty)
                      SliverToBoxAdapter(
                        child: DataUnavailableState(
                          message:
                              '${_content.title} akışı için yayınlanmış haber bulunamadı.',
                          minHeight: 280,
                        ),
                      )
                    else
                      SliverList.builder(
                        itemCount: feed.length,
                        itemBuilder: (context, index) {
                          Widget card = NewsCard(
                            article: feed[index],
                            onTap: () => _openDetail(feed, index),
                            categoryTrail: _categoryTrail(feed[index].category),
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

  List<String> _categoryTrail(String category) {
    final cleanCategory = category.trim();
    if (cleanCategory.isEmpty) return const [];

    AppShellNavigationItem? current;
    for (final item in widget.navigationItems) {
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
      for (final item in widget.navigationItems) {
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
}

/// "Sizin İçin Seçtiklerimiz" başlığı solda, sıralama ("En yeni / Popüler")
/// sağda; tek satır. Başlık, kalan genişliğe göre `FittedBox` ile küçülerek hep
/// tek satır kalır ve sıralamayla çakışmaz. Ana sayfanın `SectionHeader`
/// tipografisini (vurgu kelimesi soluk) korur.
class _FeedSectionHeader extends StatelessWidget {
  const _FeedSectionHeader({required this.filter, required this.onChange});

  final FeedFilter filter;
  final ValueChanged<FeedFilter> onChange;

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
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: 'Sizin İçin', style: AppTypography.titleL),
                      const TextSpan(text: ' '),
                      TextSpan(
                        text: 'Seçtiklerimiz',
                        style: AppTypography.titleL.copyWith(
                          color: AppColors.support,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.clip,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          FeedFilterTabs(filter: filter, onChange: onChange),
        ],
      ),
    );
  }
}

class _CategoryLoadingState extends StatelessWidget {
  const _CategoryLoadingState();

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
