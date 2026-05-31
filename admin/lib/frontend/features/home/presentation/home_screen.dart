import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/mock/home_mock_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../news_detail/presentation/news_detail_screen.dart';
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
///   [Beyaz üst blok: stories + featured slider]
///   [Gri zemin: bölüm başlığı + sosyal post tarzı haber kartları]
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isElevated = false;
  FeedFilter _feedFilter = FeedFilter.latest;

  /// Giriş animasyonu yalnızca ilk bu kadar karta uygulanır (ilk ekran).
  static const int _staggerLimit = 6;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final elevated = _scrollController.offset > 4;
    if (elevated != _isElevated) {
      setState(() => _isElevated = elevated);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _openDetail(int index) {
    final feed = HomeMockData.feed;
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
    final feed = HomeMockData.feed;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
          HomeAppBar(
            elevated: _isElevated,
            onMenuTap: () {},
            onSearchTap: () {},
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.actionRed,
              backgroundColor: AppColors.surface,
              displacement: 32,
              onRefresh: () async {
                await Future<void>.delayed(const Duration(milliseconds: 800));
              },
              child: CustomScrollView(
                controller: _scrollController,
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
                          const SizedBox(height: AppSpacing.sm),
                          FeaturedSlider(items: HomeMockData.featured)
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
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SectionHeader(
                      title: 'Senin için',
                      accent: 'akış',
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
                        onTap: () => _openDetail(index),
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
}
