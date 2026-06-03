import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/mock/home_mock_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../news_detail/presentation/news_detail_screen.dart';
import '../data/profile_content.dart';
import 'edit_profile_screen.dart';
import 'widgets/profile_app_bar.dart';
import 'widgets/profile_header.dart';
import 'widgets/profile_info_cards.dart';
import 'widgets/profile_post_card.dart';
import 'widgets/profile_stats.dart';

/// Pateeznews kullanıcı profili sayfası.
///
/// Yapı:
///   [Kapağın üzerinde yüzen, kaydırmaya duyarlı app bar]
///   [Kapak + çerçeveli avatar + kimlik + aksiyon]
///   [İstatistik şeridi: Haber · Takipçi · Takip · Katıldı]
///   [Hakkında · Sosyal Bağlantılar · Takipçiler / Takip Edilen]
///   [Gönderiler: kullanıcının haberleri (kompakt kartlar)]
///
/// Astro önyüzdeki profil ekranının tüm alanlarını taşır; tasarım dili olarak
/// uygulamanın 4px keskin radius, action red vurgu ve PateezInter tipografisini
/// korur.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.data});

  final ProfileData data;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _scrollY = ValueNotifier<double>(0);
  final ValueNotifier<bool> _lightStatusIcons = ValueNotifier<bool>(true);

  /// Kapak yüksekliğine yakın eşik: altında app bar saydam (kapak görünür) →
  /// açık status ikonları; üstünde beyaz bar → koyu status ikonları.
  static const double _overlayThreshold = 130;
  static const int _staggerLimit = 6;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final offset = _scrollController.offset;
    _scrollY.value = offset;
    final light = offset < _overlayThreshold;
    if (_lightStatusIcons.value != light) {
      _lightStatusIcons.value = light;
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _scrollY.dispose();
    _lightStatusIcons.dispose();
    super.dispose();
  }

  void _openPost(List<NewsArticle> posts, int index) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 360),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (_, _, _) =>
            NewsDetailScreen(articles: posts, initialIndex: index),
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

  void _openEdit() {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 360),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (_, _, _) => EditProfileScreen(data: widget.data),
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
    return ValueListenableBuilder<bool>(
      valueListenable: _lightStatusIcons,
      child: _buildScaffold(context),
      builder: (context, light, child) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: light ? AppTheme.darkOverlay : AppTheme.lightOverlay,
          child: child!,
        );
      },
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final data = widget.data;
    final posts = data.posts;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: ProfileHeader(data: data, onEdit: _openEdit),
              ),
              SliverToBoxAdapter(
                child: ProfileStats(data: data)
                    .animate()
                    .fadeIn(delay: 60.ms, duration: 320.ms, curve: Curves.easeOutCubic)
                    .slideY(
                      begin: 0.06,
                      end: 0,
                      delay: 60.ms,
                      duration: 320.ms,
                      curve: Curves.easeOutCubic,
                    ),
              ),
              SliverToBoxAdapter(
                child: ProfileInfoSection(data: data)
                    .animate()
                    .fadeIn(delay: 120.ms, duration: 340.ms, curve: Curves.easeOutCubic)
                    .slideY(
                      begin: 0.05,
                      end: 0,
                      delay: 120.ms,
                      duration: 340.ms,
                      curve: Curves.easeOutCubic,
                    ),
              ),
              SliverToBoxAdapter(child: _PostsHeader(count: data.postsCount)),
              SliverList.builder(
                itemCount: posts.length,
                itemBuilder: (context, index) {
                  Widget card = ProfilePostCard(
                    article: posts[index],
                    onTap: () => _openPost(posts, index),
                  );
                  if (index < _staggerLimit) {
                    card = card
                        .animate()
                        .fadeIn(
                          delay: (50 * index).ms,
                          duration: 300.ms,
                          curve: Curves.easeOutCubic,
                        )
                        .slideY(
                          begin: 0.05,
                          end: 0,
                          delay: (50 * index).ms,
                          duration: 300.ms,
                          curve: Curves.easeOutCubic,
                        );
                  }
                  return Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.pageHorizontal,
                      0,
                      AppSpacing.pageHorizontal,
                      index < posts.length - 1 ? AppSpacing.md : 0,
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
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ValueListenableBuilder<double>(
              valueListenable: _scrollY,
              builder: (context, offset, _) => ProfileAppBar(
                title: data.name,
                scrollOffset: offset,
                onBack: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PostsHeader extends StatelessWidget {
  const _PostsHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        AppSpacing.xl,
        AppSpacing.pageHorizontal,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 18,
            margin: const EdgeInsets.only(right: AppSpacing.sm + 2),
            decoration: BoxDecoration(
              color: AppColors.actionRed,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            'Gönderiler',
            style: AppTypography.titleL.copyWith(color: AppColors.inkStrong),
          ),
          const Spacer(),
          Text(
            '$count haber',
            style: AppTypography.meta.copyWith(color: AppColors.support),
          ),
        ],
      ),
    );
  }
}
