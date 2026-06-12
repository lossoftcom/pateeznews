import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/mock/home_mock_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../account/data/frontend_auth_repository.dart';
import '../../etkinlik/data/etkinlik_mock.dart';
import '../data/feed_ranking.dart';
import '../data/home_repository.dart';
import '../../pharmacy/data/pharmacy_repository.dart';
import '../../prayer_times/data/prayer_times_repository.dart';
import '../../shell/data/app_shell_repository.dart';
import '../../news_detail/presentation/news_detail_screen.dart';
import '../../today/presentation/widgets/today_widget.dart';
import '../../weather/data/weather_repository.dart';
import 'widgets/featured_slider.dart';
import 'widgets/feed_filter_tabs.dart';
import 'widgets/home_app_bar.dart';
import 'widgets/news_card.dart';
import 'widgets/section_header.dart';
import 'widgets/stories_strip.dart';

/// Pateeznews mobil ana sayfası.
///
/// Yapı:
///   [App bar]
///   [Beyaz üst blok: stories]
///   [Gri zemin: today header + featured slider]
///   [Gri zemin: bölüm başlığı + sosyal post tarzı haber kartları]
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.shellSettings = const AppShellSettings.empty(),
    this.dutyPharmacyData = const DutyPharmacyData.empty(),
    this.weatherData = const WeatherData.empty(),
    this.prayerTimesData = const PrayerTimesData.empty(),
    this.events = const [],
    this.navigationItems = const [],
    this.contentSettings = const HomeContentSettings.defaults(),
    this.featuredItems = const [],
    this.feedItems = const [],
    this.authState,
    this.onRefresh,
    this.resetToTopSerial = 0,
    this.onMenuTap,
    this.onSubmitNewsTap,
    this.onPharmacyTap,
    this.onSearch,
    this.onAuthRequired,
    this.onAuthorTap,
    this.onFullscreenVideoExit,
  });

  final AppShellSettings shellSettings;
  final DutyPharmacyData dutyPharmacyData;
  final WeatherData weatherData;
  final PrayerTimesData prayerTimesData;
  final List<EtkinlikEvent> events;
  final List<AppShellNavigationItem> navigationItems;
  final HomeContentSettings contentSettings;
  final List<FeaturedNews> featuredItems;
  final List<NewsArticle> feedItems;
  final FrontendAuthState? authState;
  final Future<void> Function()? onRefresh;
  final int resetToTopSerial;
  final VoidCallback? onMenuTap;
  final VoidCallback? onSubmitNewsTap;
  final VoidCallback? onPharmacyTap;
  final VoidCallback? onSearch;
  final VoidCallback? onAuthRequired;
  final ValueChanged<NewsAuthor>? onAuthorTap;
  final VoidCallback? onFullscreenVideoExit;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isElevated = false;
  FeedFilter _feedFilter = FeedFilter.latest;
  late int _handledResetSerial;

  /// Giriş animasyonu yalnızca ilk bu kadar karta uygulanır (ilk ekran).
  static const int _staggerLimit = 6;

  @override
  void initState() {
    super.initState();
    _handledResetSerial = widget.resetToTopSerial;
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.resetToTopSerial != _handledResetSerial) {
      _handledResetSerial = widget.resetToTopSerial;
      _resetToTopAndRefresh();
    }
  }

  void _onScroll() {
    final elevated = _scrollController.offset > 4;
    if (elevated != _isElevated) {
      setState(() => _isElevated = elevated);
    }
  }

  void _resetToTopAndRefresh() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.minScrollExtent);
      }
      if (_isElevated) setState(() => _isElevated = false);
      final refresh = widget.onRefresh;
      if (refresh != null) await refresh();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _openDetail(List<NewsArticle> feed, int index) {
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
          videoFeedArticles: _dateSortedVideoFeed(widget.feedItems),
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

  void _openFeatured(FeaturedNews item) {
    final article = item.article;
    if (article != null) {
      _openDetail(<NewsArticle>[article], 0);
      return;
    }

    final feed = _sortedFeed(widget.feedItems);
    final index = feed.indexWhere((entry) => entry.id == item.id);
    if (index >= 0) _openDetail(feed, index);
  }

  @override
  Widget build(BuildContext context) {
    final feed = _sortedFeed(widget.feedItems);
    final videoFeed = _dateSortedVideoFeed(widget.feedItems);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
          HomeAppBar(
            elevated: _isElevated,
            shellSettings: widget.shellSettings,
            onMenuTap: widget.onMenuTap ?? () {},
            onSubmitNewsTap: widget.onSubmitNewsTap,
            onPharmacyTap: widget.onPharmacyTap,
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.actionRed,
              backgroundColor: AppColors.surface,
              displacement: 32,
              onRefresh: () async {
                await widget.onRefresh?.call();
              },
              child: CustomScrollView(
                controller: _scrollController,
                // Sıradaki kartları (video dâhil) görünmeden önce inşa edip
                // hazırlar → video "şak diye" gelir, kaydırınca beklemez.
                scrollCacheExtent: const ScrollCacheExtent.pixels(1400),
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(
                    child: Container(
                      color: AppColors.surface,
                      child: Column(
                        children: [
                          const SizedBox(height: 4),
                          StoriesStrip(stories: HomeMockData.stories),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child:
                        TodayWidget(
                              dutyPharmacyData: widget.dutyPharmacyData,
                              weatherData: widget.weatherData,
                              prayerTimesData: widget.prayerTimesData,
                              events: widget.events,
                              onSearch: widget.onSearch,
                            )
                            .animate()
                            .fadeIn(
                              delay: 60.ms,
                              duration: 320.ms,
                              curve: Curves.easeOutCubic,
                            )
                            .slideY(
                              begin: 0.05,
                              end: 0,
                              delay: 60.ms,
                              duration: 320.ms,
                              curve: Curves.easeOutCubic,
                            ),
                  ),
                  if (widget.featuredItems.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child:
                            DecoratedBox(
                                  decoration: const BoxDecoration(
                                    color: AppColors.surface,
                                  ),
                                  child: FeaturedSlider(
                                    items: widget.featuredItems,
                                    onOpen: _openFeatured,
                                  ),
                                )
                                .animate()
                                .fadeIn(
                                  delay: 120.ms,
                                  duration: 360.ms,
                                  curve: Curves.easeOutCubic,
                                )
                                .slideY(
                                  begin: 0.05,
                                  end: 0,
                                  delay: 120.ms,
                                  duration: 360.ms,
                                  curve: Curves.easeOutCubic,
                                ),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: SectionHeader(
                      title: 'Senin İçin',
                      accent: 'Seçtiklerimiz',
                      trailing: FeedFilterTabs(
                        filter: _feedFilter,
                        onChange: (f) => setState(() => _feedFilter = f),
                      ),
                    ),
                  ),
                  SliverList.builder(
                    itemCount: feed.length,
                    itemBuilder: (context, index) {
                      Widget card = NewsCard(
                        article: feed[index],
                        onTap: () => _openDetail(feed, index),
                        categoryTrail: _articleCategoryTrail(feed[index]),
                        videoFeedArticles: videoFeed,
                        shellSettings: widget.shellSettings,
                        commentsEnabled: widget.contentSettings.commentSystem,
                        commentApprovalEnabled:
                            widget.contentSettings.commentApprovalSystem,
                        emojiReactionsEnabled:
                            widget.contentSettings.emojiReactions,
                        authState: widget.authState,
                        onAuthRequired: widget.onAuthRequired,
                        onAuthorTap: widget.onAuthorTap,
                        onFullscreenVideoExit: widget.onFullscreenVideoExit,
                      );
                      // Giriş animasyonu yalnızca ilk ekrandaki kartlara;
                      // sonrakiler (ve geri kaydırınca yeniden inşa edilenler)
                      // anında gelir. Lazy listede her girişte animasyonun
                      // tekrar oynamasını ve kartların geç belirmesini önler.
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
                          bottom: index < feed.length - 1 ? AppSpacing.xxl : 0,
                        ),
                        child: card,
                      );
                    },
                  ),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: AppSpacing.xxxl),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<NewsArticle> _sortedFeed(List<NewsArticle> items) {
    final feed = List<NewsArticle>.of(items);
    feed.sort(
      _feedFilter == FeedFilter.popular
          ? compareNewsByPopularity
          : compareNewsByLatest,
    );
    return feed;
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

  List<String> _articleCategoryTrail(NewsArticle article) {
    final explicitTrail = article.categoryTrail
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    if (explicitTrail.isNotEmpty) return explicitTrail;
    return _categoryTrail(article.category);
  }
}
