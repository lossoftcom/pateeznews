import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/mock/home_mock_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../home/presentation/widgets/feed_filter_tabs.dart';
import '../../home/presentation/widgets/news_card.dart';
import '../../news_detail/presentation/news_detail_screen.dart';
import '../data/category_content.dart';
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
  });

  /// Yan menüden tıklanan öğenin etiketi (ör. "Ekonomi").
  final String categoryName;

  /// Öğe tipi: category / district / trends / dropdown / link.
  final String categoryType;

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _scrollY = ValueNotifier<double>(0);

  late final CategoryContent _content = CategoryContent.fromNavigation(
    label: widget.categoryName,
    type: widget.categoryType,
  );

  FeedFilter _filter = FeedFilter.latest;

  /// Giriş animasyonu yalnızca ilk ekrandaki kartlara uygulanır.
  static const int _staggerLimit = 6;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
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

  /// Seçilen sıralamaya göre düzenlenmiş akış. Mock veride bile gerçek bir
  /// his vermesi için "En yeni" yayın zamanına, "Popüler" görüntülenmeye göre
  /// sıralanır.
  List<NewsArticle> get _sortedFeed {
    final feed = [...HomeMockData.feed];
    switch (_filter) {
      case FeedFilter.latest:
        feed.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
      case FeedFilter.popular:
        feed.sort((a, b) => b.views.compareTo(a.views));
    }
    return feed;
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
    final totalReads = feed.fold<int>(0, (sum, article) => sum + article.views);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

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
                            articleCount: feed.length,
                            totalReads: totalReads,
                          ).animate().fadeIn(
                            duration: 360.ms,
                            curve: Curves.easeOutCubic,
                          ).slideY(
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
                  SliverList.builder(
                    itemCount: feed.length,
                    itemBuilder: (context, index) {
                      Widget card = NewsCard(
                        article: feed[index],
                        onTap: () => _openDetail(feed, index),
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
                          bottom: index < feed.length - 1 ? AppSpacing.xxl : 0,
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
          ],
        ),
      ),
    );
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
                      TextSpan(
                        text: 'Sizin İçin',
                        style: AppTypography.titleL,
                      ),
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
