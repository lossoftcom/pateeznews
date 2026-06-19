import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/mock/home_mock_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/frontend_toast.dart';
import '../../account/data/frontend_auth_repository.dart';
import '../../ads/presentation/frontend_ad_slot.dart';
import '../../home/data/home_repository.dart';
import '../../news_detail/presentation/news_detail_screen.dart';
import '../../shell/data/app_shell_repository.dart';
import '../data/profile_content.dart';
import '../data/profile_repository.dart';
import 'edit_profile_screen.dart';
import 'widgets/profile_app_bar.dart';
import 'widgets/profile_header.dart';
import 'widgets/profile_info_cards.dart';
import 'widgets/profile_post_card.dart';
import 'widgets/profile_stats.dart';

/// Pateez kullanıcı profili sayfası.
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
  const ProfileScreen({
    super.key,
    required this.data,
    this.authToken = '',
    this.targetUserId = '',
    this.targetUsername = '',
    this.repository = const ProfileRepository(),
    this.shellSettings = const AppShellSettings.empty(),
    this.navigationItems = const [],
    this.contentSettings = const HomeContentSettings.defaults(),
    this.homeFeedItems = const [],
    this.authState,
    this.onAuthRequired,
    this.onAuthorTap,
    this.onFullscreenVideoExit,
    this.onProfileUpdated,
    this.onReturnHome,
  });

  final ProfileData data;
  final String authToken;
  final String targetUserId;
  final String targetUsername;
  final ProfileRepository repository;
  final AppShellSettings shellSettings;
  final List<AppShellNavigationItem> navigationItems;
  final HomeContentSettings contentSettings;
  final List<NewsArticle> homeFeedItems;
  final FrontendAuthState? authState;
  final VoidCallback? onAuthRequired;
  final ValueChanged<NewsAuthor>? onAuthorTap;
  final VoidCallback? onFullscreenVideoExit;
  final ValueChanged<ProfileSaveResult>? onProfileUpdated;
  final VoidCallback? onReturnHome;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _scrollY = ValueNotifier<double>(0);
  final ValueNotifier<bool> _lightStatusIcons = ValueNotifier<bool>(true);
  late ProfileData _data;
  var _loadingLiveProfile = false;
  var _followBusy = false;
  var _returningHome = false;

  /// Kapak yüksekliğine yakın eşik: altında app bar saydam (kapak görünür) →
  /// açık status ikonları; üstünde beyaz bar → koyu status ikonları.
  static const double _overlayThreshold = 130;
  static const int _staggerLimit = 6;

  @override
  void initState() {
    super.initState();
    _data = widget.data;
    _scrollController.addListener(_onScroll);
    _loadLiveProfile();
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
        pageBuilder: (_, _, _) => NewsDetailScreen(
          articles: posts,
          initialIndex: index,
          shellSettings: widget.shellSettings,
          navigationItems: widget.navigationItems,
          contentSettings: widget.contentSettings,
          videoFeedArticles: widget.homeFeedItems,
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

  Future<void> _loadLiveProfile() async {
    final token = widget.authToken.trim();
    final targetUserId = widget.targetUserId.trim().isNotEmpty
        ? widget.targetUserId.trim()
        : _data.isOwnProfile
        ? ''
        : _data.id.trim();
    final targetUsername = widget.targetUsername.trim().isNotEmpty
        ? widget.targetUsername.trim()
        : _data.isOwnProfile
        ? ''
        : _data.handle.trim();
    if ((token.isEmpty && targetUserId.isEmpty && targetUsername.isEmpty) ||
        _loadingLiveProfile) {
      return;
    }
    _loadingLiveProfile = true;
    try {
      final result = await widget.repository.fetchProfile(
        token: token,
        userId: targetUserId,
        username: targetUsername,
      );
      if (!mounted) return;
      setState(() => _data = result.profile);
      if (result.profile.isOwnProfile) widget.onProfileUpdated?.call(result);
    } catch (_) {
      // Cached auth profile remains visible if the live profile request fails.
    } finally {
      _loadingLiveProfile = false;
    }
  }

  Future<void> _toggleFollow() async {
    if (_followBusy || _data.id.trim().isEmpty || _data.isOwnProfile) return;
    final token = widget.authToken.trim();
    if (token.isEmpty) {
      FrontendToast.show(
        context,
        message: 'Takip etmek için giriş yapın.',
        tone: FrontendToastTone.info,
      );
      widget.onAuthRequired?.call();
      return;
    }

    final previousFollowing = _data.isFollowing;
    final previousFollowers = _data.followers;
    setState(() {
      _followBusy = true;
      _data = _data.copyWith(
        isFollowing: !previousFollowing,
        followers: math.max(
          0,
          previousFollowers + (previousFollowing ? -1 : 1),
        ),
      );
    });
    try {
      final following = await widget.repository.toggleFollow(
        token: token,
        profileId: _data.id,
      );
      if (!mounted) return;
      final followerDelta = following == previousFollowing
          ? 0
          : following
          ? 1
          : -1;
      setState(() {
        _data = _data.copyWith(
          isFollowing: following,
          followers: math.max(0, previousFollowers + followerDelta),
        );
      });
      FrontendToast.show(
        context,
        message: following ? 'Takip edildi.' : 'Takipten çıkıldı.',
      );
    } on ProfileException catch (error) {
      if (!mounted) return;
      setState(() {
        _data = _data.copyWith(
          isFollowing: previousFollowing,
          followers: previousFollowers,
        );
      });
      FrontendToast.show(
        context,
        message: error.message,
        tone: FrontendToastTone.error,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _data = _data.copyWith(
          isFollowing: previousFollowing,
          followers: previousFollowers,
        );
      });
      FrontendToast.show(
        context,
        message: 'Takip durumu güncellenemedi.',
        tone: FrontendToastTone.error,
      );
    } finally {
      if (mounted) setState(() => _followBusy = false);
    }
  }

  Future<void> _openEdit() async {
    final result = await Navigator.of(context).push<ProfileSaveResult>(
      PageRouteBuilder<ProfileSaveResult>(
        transitionDuration: const Duration(milliseconds: 360),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (_, _, _) => EditProfileScreen(
          data: _data,
          authToken: widget.authToken,
          repository: widget.repository,
          onProfileUpdated: widget.onProfileUpdated,
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
    if (result == null || !mounted) return;
    setState(() => _data = result.profile);
    widget.onProfileUpdated?.call(result);
  }

  Future<void> _openPreviewProfile(ProfilePreview profile) async {
    final id = profile.id.trim();
    final handle = profile.handle.trim().replaceFirst(RegExp(r'^@+'), '');
    if (id.isEmpty && handle.isEmpty) return;
    if (id.isNotEmpty && id == _data.id.trim()) return;

    final fallbackData = ProfileData(
      id: id,
      name: profile.name.trim().isEmpty ? 'Pateez' : profile.name.trim(),
      handle: handle.isEmpty ? '' : '@$handle',
      roleLabel: profile.isOfficial ? 'Yayıncı' : 'Üye',
      expertise: profile.isOfficial ? 'Yayıncı' : 'Üye',
      aboutMe: '',
      email: '',
      showEmail: false,
      avatarUrl: profile.avatarUrl,
      avatarPath: '',
      coverUrl: '',
      coverPath: '',
      joinedLabel: '',
      joinedYear: '',
      isVerified: profile.isVerified,
      isOnline: true,
      isOwnProfile: false,
      postsCount: 0,
      followers: 0,
      following: 0,
      socialLinks: const [],
      followerAvatars: const [],
      followingAvatars: const [],
      posts: const [],
    );
    final data = await _resolvePreviewProfileData(
      fallback: fallbackData,
      userId: id,
      username: handle,
    );
    if (!mounted) return;
    await Navigator.of(context).pushReplacement<void, void>(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 360),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (_, _, _) => ProfileScreen(
          data: data,
          authToken: widget.authToken,
          targetUserId: id,
          targetUsername: handle,
          repository: widget.repository,
          onAuthRequired: widget.onAuthRequired,
          onProfileUpdated: widget.onProfileUpdated,
          onReturnHome: widget.onReturnHome,
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

  Future<ProfileData> _resolvePreviewProfileData({
    required ProfileData fallback,
    required String userId,
    required String username,
  }) async {
    try {
      final result = await widget.repository.fetchProfile(
        token: widget.authToken,
        userId: userId,
        username: username,
      );
      if (result.profile.isOwnProfile) widget.onProfileUpdated?.call(result);
      return result.profile;
    } catch (_) {
      return fallback;
    }
  }

  void _returnHome() {
    if (_returningHome) return;
    widget.onReturnHome?.call();
    setState(() => _returningHome = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _returningHome,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _returnHome();
      },
      child: ValueListenableBuilder<bool>(
        valueListenable: _lightStatusIcons,
        child: _buildScaffold(context),
        builder: (context, light, child) {
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: light ? AppTheme.darkOverlay : AppTheme.lightOverlay,
            child: child!,
          );
        },
      ),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final data = _data;
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
                child: ProfileHeader(
                  data: data,
                  onEdit: _openEdit,
                  onFollow: _toggleFollow,
                  followBusy: _followBusy,
                ),
              ),
              SliverToBoxAdapter(
                child: ProfileStats(data: data)
                    .animate()
                    .fadeIn(
                      delay: 60.ms,
                      duration: 320.ms,
                      curve: Curves.easeOutCubic,
                    )
                    .slideY(
                      begin: 0.06,
                      end: 0,
                      delay: 60.ms,
                      duration: 320.ms,
                      curve: Curves.easeOutCubic,
                    ),
              ),
              SliverToBoxAdapter(
                child:
                    ProfileInfoSection(
                          data: data,
                          onProfileTap: _openPreviewProfile,
                        )
                        .animate()
                        .fadeIn(
                          delay: 120.ms,
                          duration: 340.ms,
                          curve: Curves.easeOutCubic,
                        )
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
                  final postTile = Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.pageHorizontal,
                      0,
                      AppSpacing.pageHorizontal,
                      index < posts.length - 1 ? AppSpacing.md : 0,
                    ),
                    child: card,
                  );
                  if ((index + 1) % 5 != 0) return postTile;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      postTile,
                      const FrontendAdSlot(
                        slotKey: 'mobile_profile_feed_inline',
                        margin: EdgeInsets.symmetric(
                          horizontal: AppSpacing.pageHorizontal,
                        ),
                      ),
                    ],
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
                onBack: _returnHome,
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
