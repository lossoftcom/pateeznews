import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/frontend_toast.dart';
import '../../account/data/frontend_auth_repository.dart';
import '../../account/presentation/account_sign_in_screen.dart';
import '../../announcements/data/announcements_repository.dart';
import '../../announcements/presentation/announcements_screen.dart';
import '../../apps/data/app_item.dart';
import '../../apps/presentation/app_feature_screen.dart';
import '../../apps/presentation/apps_sheet.dart';
import '../../category/presentation/category_screen.dart';
import '../../corporate/presentation/corporate_pages_screen.dart';
import '../../etkinlik/data/etkinlik_mock.dart';
import '../../etkinlik/presentation/etkinlik_screen.dart';
import '../../home/data/home_repository.dart';
import '../../home/presentation/home_screen.dart';
import '../../home/presentation/video_feed_screen.dart';
import '../../home/presentation/widgets/news_video_player.dart';
import '../../../core/mock/home_mock_data.dart';
import '../../markets/data/markets_repository.dart';
import '../../markets/presentation/markets_screen.dart';
import '../../obituaries/data/death_notice_repository.dart';
import '../../obituaries/presentation/obituaries_screen.dart';
import '../../pharmacy/data/pharmacy_repository.dart';
import '../../pharmacy/presentation/pharmacy_screen.dart';
import '../../prayer_times/data/prayer_times_repository.dart';
import '../../prayer_times/presentation/prayer_times_screen.dart';
import '../../profile/data/profile_content.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../search/presentation/search_screen.dart';
import '../../weather/data/weather_repository.dart';
import '../../weather/presentation/weather_screen.dart';
import '../data/app_shell_repository.dart';
import 'widgets/pateez_bottom_nav.dart';
import 'widgets/section_placeholder.dart';
import 'widgets/pateez_side_menu.dart';

/// Bottom navigation ile yönetilen üst kabuk.
///
/// Sekmeler arası geçiş `IndexedStack` ile yapılır; böylece ana sayfa state'i
/// kaybolmaz, kaydırma konumu korunur.
class ShellScreen extends StatefulWidget {
  const ShellScreen({
    super.key,
    this.accountPage,
    this.shellData = const AppShellData.empty(),
    this.dutyPharmacyData = const DutyPharmacyData.empty(),
    this.deathNoticeData = const DeathNoticeData.empty(),
    this.weatherData = const WeatherData.empty(),
    this.marketsData = const MarketsData.empty(),
    this.prayerTimesData = const PrayerTimesData.empty(),
    this.eventItems = const [],
    this.announcementData = const AnnouncementData.empty(),
    this.contentSettings = const HomeContentSettings.defaults(),
    this.featuredItems = const [],
    this.homeFeedItems = const [],
    this.onRefreshHome,
    this.authState,
    this.profileData,
    this.profileRepository = const ProfileRepository(),
    this.authLoading = false,
    this.onSignIn,
    this.onSignOut,
    this.onOpenAdminPanel,
    this.onProfileUpdated,
  });

  final Widget? accountPage;
  final AppShellData shellData;
  final DutyPharmacyData dutyPharmacyData;
  final DeathNoticeData deathNoticeData;
  final WeatherData weatherData;
  final MarketsData marketsData;
  final PrayerTimesData prayerTimesData;
  final List<EtkinlikEvent> eventItems;
  final AnnouncementData announcementData;
  final HomeContentSettings contentSettings;
  final List<FeaturedNews> featuredItems;
  final List<NewsArticle> homeFeedItems;
  final Future<void> Function()? onRefreshHome;
  final FrontendAuthState? authState;
  final ProfileData? profileData;
  final ProfileRepository profileRepository;
  final bool authLoading;
  final FrontendSignInCallback? onSignIn;
  final Future<void> Function()? onSignOut;
  final Future<void> Function()? onOpenAdminPanel;
  final ValueChanged<ProfileSaveResult>? onProfileUpdated;

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen>
    with SingleTickerProviderStateMixin {
  int _index = 0;
  var _accountRouteOpen = false;
  var _videoRouteOpen = false;
  var _menuOpen = false;
  var _accountMenuOpen = false;
  var _appsSheetOpen = false;
  var _menuDarkModeSelected = false;
  final _videoFeedArticleId = '';
  final _videoFeedRevealSerial = 0;
  var _homeResetSerial = 0;

  late final AnimationController _appsController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    reverseDuration: const Duration(milliseconds: 240),
  );

  static const _accountNavIndex = 4;
  static const _appsNavIndex = 2;
  static const _videoNavIndex = 1;

  @override
  void dispose() {
    _appsController.dispose();
    super.dispose();
  }

  static const _items = <PateezNavItem>[
    PateezNavItem(
      label: 'Anasayfa',
      icon: Symbols.home_outlined,
      activeIcon: Symbols.home_rounded,
    ),
    PateezNavItem(
      label: 'Video',
      icon: Symbols.play_circle_outline_rounded,
      activeIcon: Symbols.play_circle_rounded,
    ),
    PateezNavItem(
      label: 'Uygulamalar',
      icon: Symbols.apps,
      activeIcon: Symbols.apps_fill,
    ),
    PateezNavItem(
      label: 'Arama',
      icon: Symbols.search_ai_line,
      activeIcon: Symbols.search_ai_fill,
    ),
    PateezNavItem(
      label: 'Hesap',
      icon: Symbols.person_outline_rounded,
      activeIcon: Symbols.person_rounded,
    ),
  ];

  Future<void> _openAccount() async {
    _closeAccountMenu();
    if (_accountRouteOpen) return;
    _accountRouteOpen = true;
    try {
      await Navigator.of(context).push<void>(
        PageRouteBuilder<void>(
          transitionDuration: const Duration(milliseconds: 420),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (_, _, _) => AnnotatedRegion<SystemUiOverlayStyle>(
            value: AppTheme.lightOverlay,
            child: Material(
              color: Colors.transparent,
              child:
                  widget.accountPage ??
                  AccountSignInScreen(
                    authState: widget.authState,
                    authLoading: widget.authLoading,
                    onSignIn: widget.onSignIn,
                    onSignOut: widget.onSignOut,
                    shellSettings: widget.shellData.siteSettings,
                  ),
            ),
          ),
          transitionsBuilder: (context, animation, secondary, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(curved),
                child: child,
              ),
            );
          },
        ),
      );
    } finally {
      _accountRouteOpen = false;
    }
  }

  void _openAccountForRequiredAuth() {
    unawaited(_openAccount());
  }

  Future<void> _openVideoFeedFromNav() async {
    _closeAccountMenu();
    _closeAppsSheet();

    final videos = dateSortedVideoArticles(widget.homeFeedItems);
    if (videos.isEmpty) {
      _returnHomeFromFullscreenVideo();
      return;
    }
    if (_videoRouteOpen) return;

    final items = videoFeedItemsFromArticles(
      articles: videos,
      shellSettings: widget.shellData.siteSettings,
      navigationItems: widget.shellData.navigationItems,
    );
    if (items.isEmpty) {
      _returnHomeFromFullscreenVideo();
      return;
    }

    _videoRouteOpen = true;
    try {
      await Navigator.of(context).push<int>(
        PageRouteBuilder<int>(
          transitionDuration: const Duration(milliseconds: 180),
          reverseTransitionDuration: const Duration(milliseconds: 120),
          pageBuilder: (_, _, _) => NewsFullscreenVideoFeedPage(
            items: items,
            authState: widget.authState,
            onAuthorTap: _openAuthorProfile,
            onAuthRequired: _openAccountForRequiredAuth,
          ),
          transitionsBuilder: (context, animation, secondary, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return FadeTransition(opacity: curved, child: child);
          },
        ),
      );
      if (!mounted) return;
      _returnHomeFromFullscreenVideo();
    } finally {
      _videoRouteOpen = false;
    }
  }

  void _returnHomeFromFullscreenVideo() {
    _closeAccountMenu();
    _closeAppsSheet();
    setState(() {
      _index = 0;
      _homeResetSerial++;
    });
  }

  void _returnHomeFromProfile() {
    if (!mounted) return;
    _closeAccountMenu();
    _closeAppsSheet();
    setState(() => _index = 0);
  }

  void _returnHomeFromSearch() {
    if (!mounted) return;
    _closeMenu();
    _closeAccountMenu();
    _closeAppsSheet();
    setState(() => _index = 0);
  }

  /// Hesap menüsündeki "Profilim" bu sayfayı açar. Splash canlı profili
  /// tamamlayamadıysa eksik detaylar route açılmadan önce çözülür.
  Future<void> _openProfile() async {
    _closeAccountMenu();
    final auth = widget.authState;
    final profile = auth?.profile;
    if (auth == null) {
      await _openAccount();
      return;
    }
    final role = (profile?.role ?? '').trim().toLowerCase();
    final verified =
        role == 'admin' || role == 'super_admin' || role == 'editor';
    final fallbackData =
        widget.profileData ??
        ProfileData(
          id: profile?.id ?? auth.session.user.id,
          name: profile?.fullName?.trim().isNotEmpty == true
              ? profile!.fullName!.trim()
              : auth.displayName,
          handle: profile?.handle ?? '',
          roleLabel: _roleLabelFor(role),
          expertise: _roleLabelFor(role),
          aboutMe: '',
          email: profile?.email ?? auth.session.user.email ?? '',
          showEmail: true,
          avatarUrl: profile?.avatarUrl ?? '',
          avatarPath: '',
          coverUrl: profile?.coverUrl ?? '',
          coverPath: '',
          joinedLabel: '',
          joinedYear: '',
          isVerified: verified,
          isOnline: true,
          isOwnProfile: true,
          website: '',
          address: '',
          rssFeeds: true,
          postsCount: 0,
          followers: 0,
          following: 0,
          socialLinks: const [],
          followerAvatars: const [],
          followingAvatars: const [],
          posts: const [],
        );
    final data = await _resolveOwnProfileData(auth, fallbackData);
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 360),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (_, _, _) => ProfileScreen(
          data: data,
          authToken: auth.session.accessToken,
          repository: widget.profileRepository,
          shellSettings: widget.shellData.siteSettings,
          navigationItems: widget.shellData.navigationItems,
          contentSettings: widget.contentSettings,
          homeFeedItems: widget.homeFeedItems,
          authState: widget.authState,
          onAuthRequired: _openAccountForRequiredAuth,
          onAuthorTap: _openAuthorProfile,
          onFullscreenVideoExit: _returnHomeFromFullscreenVideo,
          onProfileUpdated: widget.onProfileUpdated,
          onReturnHome: _returnHomeFromProfile,
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

  Future<void> _openAuthorProfile(NewsAuthor author) async {
    final cleanId = author.id.trim();
    final cleanHandle = (author.handle ?? '').trim().replaceFirst(
      RegExp(r'^@+'),
      '',
    );
    if (cleanId.isEmpty && cleanHandle.isEmpty) return;

    final auth = widget.authState;
    final authProfileId = auth?.profile?.id.trim() ?? auth?.session.user.id;
    if (auth != null && cleanId.isNotEmpty && cleanId == authProfileId) {
      await _openProfile();
      return;
    }

    _closeAccountMenu();
    _closeAppsSheet();
    final fallbackData = ProfileData(
      id: cleanId,
      name: author.name.trim().isEmpty ? 'Pateez' : author.name.trim(),
      handle: cleanHandle.isEmpty ? '' : '@$cleanHandle',
      roleLabel: author.isOfficial ? 'Yayıncı' : 'Üye',
      expertise: author.isOfficial ? 'Yayıncı' : 'Üye',
      aboutMe: '',
      email: '',
      showEmail: false,
      avatarUrl: author.avatarUrl,
      avatarPath: '',
      coverUrl: '',
      coverPath: '',
      joinedLabel: '',
      joinedYear: '',
      isVerified: author.isVerified || author.isOfficial,
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
    final data = await _resolveTargetProfileData(
      fallback: fallbackData,
      token: auth?.session.accessToken ?? '',
      userId: cleanId,
      username: cleanHandle,
    );
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 360),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (_, _, _) => ProfileScreen(
          data: data,
          authToken: auth?.session.accessToken ?? '',
          targetUserId: cleanId,
          targetUsername: cleanHandle,
          repository: widget.profileRepository,
          shellSettings: widget.shellData.siteSettings,
          navigationItems: widget.shellData.navigationItems,
          contentSettings: widget.contentSettings,
          homeFeedItems: widget.homeFeedItems,
          authState: widget.authState,
          onAuthRequired: _openAccountForRequiredAuth,
          onAuthorTap: _openAuthorProfile,
          onFullscreenVideoExit: _returnHomeFromFullscreenVideo,
          onProfileUpdated: widget.onProfileUpdated,
          onReturnHome: _returnHomeFromProfile,
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

  Future<ProfileData> _resolveOwnProfileData(
    FrontendAuthState auth,
    ProfileData fallback,
  ) async {
    if (_profileDataLooksLive(fallback)) return fallback;
    try {
      final result = await widget.profileRepository.fetchSelf(
        token: auth.session.accessToken,
      );
      widget.onProfileUpdated?.call(result);
      return result.profile;
    } catch (_) {
      return fallback;
    }
  }

  Future<ProfileData> _resolveTargetProfileData({
    required ProfileData fallback,
    required String token,
    required String userId,
    required String username,
  }) async {
    try {
      final result = await widget.profileRepository.fetchProfile(
        token: token,
        userId: userId,
        username: username,
      );
      if (result.profile.isOwnProfile) widget.onProfileUpdated?.call(result);
      return result.profile;
    } catch (_) {
      return fallback;
    }
  }

  bool _profileDataLooksLive(ProfileData data) {
    return data.joinedLabel.trim().isNotEmpty ||
        data.joinedYear.trim().isNotEmpty;
  }

  String _roleLabelFor(String role) {
    switch (role) {
      case 'admin':
      case 'super_admin':
        return 'Yönetici';
      case 'editor':
        return 'Editör';
      case 'publisher':
        return 'Yayıncı';
      default:
        return 'Üye';
    }
  }

  void _openMenu() {
    _closeAccountMenu();
    _closeAppsSheet();
    if (_menuOpen) return;
    setState(() => _menuOpen = true);
  }

  void _showSubmitNewsHint() {
    _closeMenu();
    _closeAccountMenu();
    _closeAppsSheet();
    _showMessage('WhatsApp haber gönderme hattı hazırlanıyor.');
  }

  void _showMessage(String message) {
    FrontendToast.show(context, message: message, tone: FrontendToastTone.info);
  }

  void _closeMenu() {
    if (!_menuOpen) return;
    setState(() => _menuOpen = false);
  }

  void _openAccountMenu() {
    if (widget.authState == null || _accountMenuOpen) return;
    _closeMenu();
    _closeAppsSheet();
    setState(() => _accountMenuOpen = true);
  }

  void _toggleAccountMenu() {
    if (_accountMenuOpen) {
      _closeAccountMenu();
    } else {
      _openAccountMenu();
    }
  }

  void _closeAccountMenu() {
    if (!_accountMenuOpen) return;
    setState(() => _accountMenuOpen = false);
  }

  void _selectFromMenu(int index) {
    _closeMenu();
    if (index == _accountNavIndex) {
      if (widget.authState != null) {
        _openAccountMenu();
      } else {
        _openAccount();
      }
      return;
    }
    if (index == _appsNavIndex) {
      _openAppsSheet();
      return;
    }
    _closeAccountMenu();
    _closeAppsSheet();
    setState(() => _index = index);
  }

  void _selectNavigationItem(AppShellNavigationItem item) {
    _closeMenu();
    _closeAccountMenu();
    final tabIndex = _appDestinationIndex(item);
    if (tabIndex != null) {
      if (tabIndex == _videoNavIndex) {
        unawaited(_openVideoFeedFromNav());
        return;
      }
      setState(() => _index = tabIndex);
      return;
    }
    _openCategory(item);
  }

  /// Öğe uygulamanın sabit bir sekmesine (ana sayfa / video / arama) işaret
  /// ediyorsa o sekmenin index'ini, aksi halde null döner. Null dönen tüm
  /// içerik öğeleri (kategori, ilçe, trend, dropdown, link...) kategori
  /// sayfasını açar.
  int? _appDestinationIndex(AppShellNavigationItem item) {
    final key = '${item.label} ${item.value} ${item.type}'.toLowerCase();
    if (item.value == '/' ||
        key.contains('ana sayfa') ||
        key.contains('anasayfa') ||
        key.contains('home')) {
      return 0;
    }
    if (key.contains('video')) return 1;
    if (key.contains('arama') || key.contains('search')) return 3;
    return null;
  }

  void _openCategory(AppShellNavigationItem item) {
    Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 360),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (_, _, _) => CategoryScreen(
          categoryName: item.label,
          categoryType: item.type,
          categoryValue: item.value,
          shellSettings: widget.shellData.siteSettings,
          navigationItems: widget.shellData.navigationItems,
          contentSettings: widget.contentSettings,
          authState: widget.authState,
          onAuthRequired: _openAccountForRequiredAuth,
          onAuthorTap: _openAuthorProfile,
          onFullscreenVideoExit: _returnHomeFromFullscreenVideo,
          onSearch: _openSearchRoute,
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

  void _openCorporatePages(AppShellNavigationItem? root) {
    _closeMenu();
    _closeAccountMenu();
    _closeAppsSheet();
    final pages = widget.shellData.pagesForRoot(root?.id ?? '');
    if (pages.isEmpty) {
      _showMessage('Sayfa bulunamadı.');
      return;
    }
    Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 340),
        reverseTransitionDuration: const Duration(milliseconds: 240),
        pageBuilder: (_, _, _) => CorporatePagesScreen(
          pages: pages,
          rootLabel: root?.label ?? '',
          onSearch: _openSearchRoute,
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

  Future<void> _openSearchRoute() async {
    _closeMenu();
    _closeAccountMenu();
    _closeAppsSheet();
    await Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 240),
        pageBuilder: (routeContext, _, _) => SearchScreen(
          showBackButton: true,
          onBack: () {
            Navigator.of(routeContext).popUntil((route) => route.isFirst);
            _returnHomeFromSearch();
          },
          shellSettings: widget.shellData.siteSettings,
          navigationItems: widget.shellData.navigationItems,
          contentSettings: widget.contentSettings,
          homeFeedItems: widget.homeFeedItems,
          authState: widget.authState,
          onAuthRequired: _openAccountForRequiredAuth,
          onAuthorTap: _openAuthorProfile,
          onOpenApp: _openApp,
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

  void _openAppsSheet() {
    _closeMenu();
    _closeAccountMenu();
    if (_appsSheetOpen) return;
    setState(() => _appsSheetOpen = true);
    _appsController.forward();
  }

  void _closeAppsSheet() {
    if (!_appsSheetOpen) return;
    setState(() => _appsSheetOpen = false);
    _appsController.reverse();
  }

  void _toggleAppsSheet() {
    if (_appsSheetOpen) {
      _closeAppsSheet();
    } else {
      _openAppsSheet();
    }
  }

  void _openApp(AppItem item) {
    _closeAppsSheet();
    Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 360),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (_, _, _) => switch (item.id) {
          'nobetci-eczane' => PharmacyScreen(
            initialData: widget.dutyPharmacyData,
            onSearch: _openSearchRoute,
          ),
          'duyurular' => AnnouncementsScreen(
            initialData: widget.announcementData,
            onSearch: _openSearchRoute,
          ),
          'etkinlik' =>
            widget.eventItems.isEmpty
                ? EtkinlikScreen(
                    shellSettings: widget.shellData.siteSettings,
                    navigationItems: widget.shellData.navigationItems,
                    contentSettings: widget.contentSettings,
                    homeFeedItems: widget.homeFeedItems,
                    authState: widget.authState,
                    onAuthRequired: _openAccountForRequiredAuth,
                    onAuthorTap: _openAuthorProfile,
                    onFullscreenVideoExit: _returnHomeFromFullscreenVideo,
                    onSearch: _openSearchRoute,
                  )
                : EtkinlikScreen(
                    events: widget.eventItems,
                    shellSettings: widget.shellData.siteSettings,
                    navigationItems: widget.shellData.navigationItems,
                    contentSettings: widget.contentSettings,
                    homeFeedItems: widget.homeFeedItems,
                    authState: widget.authState,
                    onAuthRequired: _openAccountForRequiredAuth,
                    onAuthorTap: _openAuthorProfile,
                    onFullscreenVideoExit: _returnHomeFromFullscreenVideo,
                    onSearch: _openSearchRoute,
                  ),
          'hava-durumu' => WeatherScreen(
            initialData: widget.weatherData,
            onSearch: _openSearchRoute,
          ),
          'namaz-vakitleri' => PrayerTimesScreen(
            initialData: widget.prayerTimesData,
            onSearch: _openSearchRoute,
          ),
          'doviz-altin' => MarketsScreen(
            initialData: widget.marketsData,
            onSearch: _openSearchRoute,
          ),
          'olum-ilanlari' => ObituariesScreen(
            initialData: widget.deathNoticeData,
            authState: widget.authState,
            onSearch: _openSearchRoute,
          ),
          _ => AppFeatureScreen(item: item, onSearch: _openSearchRoute),
        },
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

  void _setMenuMode(bool darkModeSelected) {
    if (_menuDarkModeSelected == darkModeSelected) return;
    setState(() => _menuDarkModeSelected = darkModeSelected);
  }

  @override
  void didUpdateWidget(covariant ShellScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.authState == null && _accountMenuOpen) {
      _accountMenuOpen = false;
    }
  }

  Future<void> _openAdminPanel() async {
    _closeAccountMenu();
    await widget.onOpenAdminPanel?.call();
  }

  Future<void> _signOut() async {
    _closeAccountMenu();
    await widget.onSignOut?.call();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final maxMenuWidth = math.max(0.0, screenWidth - 84);
    final preferredMenuWidth = math.max(220.0, screenWidth * 0.68);
    final menuWidth = math.min(
      276.0,
      math.min(maxMenuWidth, preferredMenuWidth),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.lightOverlay,
      child: Stack(
        children: [
          if (_menuOpen)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: menuWidth,
              child: PateezSideMenu(
                width: menuWidth,
                items: _items,
                shellData: widget.shellData,
                activeIndex: _index,
                darkModeSelected: _menuDarkModeSelected,
                onClose: _closeMenu,
                onSelected: _selectFromMenu,
                onNavigationItemSelected: _selectNavigationItem,
                onPagesSelected: _openCorporatePages,
                onModeChanged: _setMenuMode,
              ),
            ),
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              transform: Matrix4.translationValues(
                _menuOpen ? menuWidth : 0,
                0,
                0,
              ),
              child: _buildScaffold(),
            ),
          ),
          Positioned.fill(
            child: _AppsOverlay(
              controller: _appsController,
              navHeight:
                  MediaQuery.paddingOf(context).bottom +
                  AppSpacing.bottomNavHeight,
              onClose: _closeAppsSheet,
              onSelect: _openApp,
            ),
          ),
          if (_accountMenuOpen && widget.authState != null) ...[
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (_) => _closeAccountMenu(),
                child: const SizedBox.expand(),
              ),
            ),
            Positioned(
              right: 10,
              bottom:
                  MediaQuery.paddingOf(context).bottom +
                  AppSpacing.bottomNavHeight +
                  10,
              child: _AccountQuickMenu(
                authState: widget.authState!,
                onAdminPanel:
                    widget.authState!.isAdmin && widget.onOpenAdminPanel != null
                    ? _openAdminPanel
                    : null,
                onProfile: _openProfile,
                onSignOut: _signOut,
              ),
            ),
          ],
          if (_menuOpen)
            Positioned(
              left: menuWidth,
              top: 0,
              right: 0,
              bottom: 0,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _closeMenu,
                child: const SizedBox.expand(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScaffold() {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Scaffold(
          body: SafeArea(
            top: false,
            bottom: false,
            child: IndexedStack(
              index: _index,
              children: [
                HomeScreen(
                  shellSettings: widget.shellData.siteSettings,
                  dutyPharmacyData: widget.dutyPharmacyData,
                  weatherData: widget.weatherData,
                  prayerTimesData: widget.prayerTimesData,
                  events: widget.eventItems,
                  navigationItems: widget.shellData.navigationItems,
                  contentSettings: widget.contentSettings,
                  featuredItems: widget.featuredItems,
                  feedItems: widget.homeFeedItems,
                  authState: widget.authState,
                  onRefresh: widget.onRefreshHome,
                  resetToTopSerial: _homeResetSerial,
                  onMenuTap: _openMenu,
                  onSubmitNewsTap: _showSubmitNewsHint,
                  onPharmacyTap: () => _openApp(AppItems.nobetciEczane),
                  onSearch: _openSearchRoute,
                  onAuthRequired: _openAccountForRequiredAuth,
                  onAuthorTap: _openAuthorProfile,
                  onFullscreenVideoExit: _returnHomeFromFullscreenVideo,
                ),
                _index == 1
                    ? VideoFeedScreen(
                        feedItems: widget.homeFeedItems,
                        shellSettings: widget.shellData.siteSettings,
                        navigationItems: widget.shellData.navigationItems,
                        contentSettings: widget.contentSettings,
                        initialArticleId: _videoFeedArticleId,
                        revealSerial: _videoFeedRevealSerial,
                        authState: widget.authState,
                        onRefresh: widget.onRefreshHome,
                        onAuthRequired: _openAccountForRequiredAuth,
                        onAuthorTap: _openAuthorProfile,
                        onFullscreenVideoExit: _returnHomeFromFullscreenVideo,
                      )
                    : const SizedBox.shrink(),
                const SectionPlaceholder(
                  icon: Symbols.grid_view_rounded,
                  title: 'Pateez uygulamaları',
                  message:
                      'Anketler, testler ve mini araçlar bu bölümde tek '
                      'çatı altında toplanacak.',
                ),
                SearchScreen(
                  showBackButton: true,
                  autoFocus: _index == 3,
                  onBack: _returnHomeFromSearch,
                  shellSettings: widget.shellData.siteSettings,
                  navigationItems: widget.shellData.navigationItems,
                  contentSettings: widget.contentSettings,
                  homeFeedItems: widget.homeFeedItems,
                  authState: widget.authState,
                  onAuthRequired: _openAccountForRequiredAuth,
                  onAuthorTap: _openAuthorProfile,
                  onOpenApp: _openApp,
                ),
              ],
            ),
          ),
          bottomNavigationBar: PateezBottomNav(
            items: _items,
            activeIndex: _accountMenuOpen
                ? _accountNavIndex
                : _appsSheetOpen
                ? _appsNavIndex
                : _index,
            authState: widget.authState,
            authLoading: widget.authLoading,
            onSelected: (i) {
              if (i == _accountNavIndex) {
                if (widget.authState != null) {
                  _toggleAccountMenu();
                } else {
                  _openAccount();
                }
                return;
              }
              if (i == _appsNavIndex) {
                _toggleAppsSheet();
                return;
              }
              if (i == _videoNavIndex) {
                _openVideoFeedFromNav();
                return;
              }
              _closeAccountMenu();
              _closeAppsSheet();
              setState(() => _index = i);
            },
          ),
        ),
        if (_index == 0 && !_menuOpen && !_appsSheetOpen && !_accountMenuOpen)
          Positioned(
            right: 2,
            bottom: bottomInset + AppSpacing.bottomNavHeight - 8,
            child: _FloatingSubmitNewsButton(onTap: _showSubmitNewsHint),
          ),
      ],
    );
  }
}

class _FloatingSubmitNewsButton extends StatefulWidget {
  const _FloatingSubmitNewsButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_FloatingSubmitNewsButton> createState() =>
      _FloatingSubmitNewsButtonState();
}

class _FloatingSubmitNewsButtonState extends State<_FloatingSubmitNewsButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  late final Animation<double> _heartbeat = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1,
        end: 1.035,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 9,
    ),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1.035,
        end: 0.99,
      ).chain(CurveTween(curve: Curves.easeInOutCubic)),
      weight: 8,
    ),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 0.99,
        end: 1.018,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 7,
    ),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1.018,
        end: 1,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 8,
    ),
    TweenSequenceItem(tween: ConstantTween<double>(1), weight: 68),
  ]).animate(_controller);

  static const _whatsappGreen = Color(0xFF25D366);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'WhatsApp ile haber gönder',
      button: true,
      child: AnimatedBuilder(
        animation: _heartbeat,
        builder: (context, child) =>
            Transform.scale(scale: _heartbeat.value, child: child),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: SizedBox(
            width: 70,
            height: 58,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF32E176),
                        _whatsappGreen,
                        Color(0xFF119C4A),
                      ],
                      stops: [0, 0.58, 1],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _whatsappGreen.withValues(alpha: 0.24),
                        blurRadius: 14,
                        offset: const Offset(0, 7),
                      ),
                    ],
                  ),
                  child: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.22),
                      ),
                    ),
                    child: const Icon(
                      Symbols.whatsapp_fill,
                      color: Colors.white,
                      size: 19,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.86),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.deepOcean.withValues(alpha: 0.07),
                        blurRadius: 7,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    child: Text(
                      'Haber gönder',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppTypography.eyebrow.copyWith(
                        color: AppColors.deepOcean,
                        fontSize: 8.2,
                        fontWeight: FontWeight.w900,
                        height: 1,
                        letterSpacing: 0,
                        decoration: TextDecoration.none,
                        decorationColor: Colors.transparent,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Uygulamalar" alt sayfasının kabuk içindeki kaplaması: içerik alanını
/// karartan örtü + aşağıdan yukarı kayan [AppsSheet]. Bottom nav'ın üstünde
/// konumlanır (nav görünür ve etkileşimli kalır); kapanırken sheet nav çizgisi
/// altında kırpılarak gizlenir. Sheet parmakla aşağı çekilerek de kapatılır:
/// sürükleme parmağı takip eder, bırakınca eşiğe göre kapanır ya da geri yapışır.
class _AppsOverlay extends StatefulWidget {
  const _AppsOverlay({
    required this.controller,
    required this.navHeight,
    required this.onClose,
    required this.onSelect,
  });

  final AnimationController controller;
  final double navHeight;
  final VoidCallback onClose;
  final ValueChanged<AppItem> onSelect;

  @override
  State<_AppsOverlay> createState() => _AppsOverlayState();
}

class _AppsOverlayState extends State<_AppsOverlay> {
  final GlobalKey _sheetKey = GlobalKey();
  bool _dismissing = false;

  double get _sheetHeight {
    final size = _sheetKey.currentContext?.size;
    return (size != null && size.height > 0) ? size.height : 320;
  }

  void _onDragStart(DragStartDetails _) => _dismissing = false;

  void _onDragUpdate(DragUpdateDetails details) {
    if (_dismissing) return;
    final next =
        widget.controller.value - (details.primaryDelta ?? 0) / _sheetHeight;
    if (next <= 0.02) {
      _dismissing = true;
      widget.onClose();
      return;
    }
    widget.controller.value = next.clamp(0.0, 1.0);
  }

  void _onDragEnd(DragEndDetails details) {
    if (_dismissing) return;
    final velocity = details.primaryVelocity ?? 0;
    if (velocity > 600 || widget.controller.value < 0.6) {
      widget.onClose();
    } else {
      widget.controller.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final t = widget.controller.value;
        if (t == 0) return const SizedBox.shrink();
        return Padding(
          padding: EdgeInsets.only(bottom: widget.navHeight),
          child: ClipRect(
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onClose,
                    child: ColoredBox(
                      color: Colors.black.withValues(alpha: 0.45 * t),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: FractionalTranslation(
                    translation: Offset(0, 1 - t),
                    child: GestureDetector(
                      onVerticalDragStart: _onDragStart,
                      onVerticalDragUpdate: _onDragUpdate,
                      onVerticalDragEnd: _onDragEnd,
                      child: KeyedSubtree(
                        key: _sheetKey,
                        child: AppsSheet(
                          items: AppItems.all,
                          onSelect: widget.onSelect,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AccountQuickMenu extends StatelessWidget {
  const _AccountQuickMenu({
    required this.authState,
    required this.onProfile,
    required this.onSignOut,
    this.onAdminPanel,
  });

  final FrontendAuthState authState;
  final VoidCallback? onAdminPanel;
  final VoidCallback onProfile;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final labelStyle = AppTypography.mobileMenuLabel;
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 230,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.value),
          border: Border.all(color: AppColors.softLine),
          boxShadow: [
            BoxShadow(
              color: AppColors.deepOcean.withValues(alpha: 0.16),
              blurRadius: 28,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 7, 8, 9),
              child: Row(
                children: [
                  _MenuAvatar(authState: authState, size: 38),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          authState.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: labelStyle.copyWith(
                            color: AppColors.inkStrong,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          authState.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: labelStyle.copyWith(
                            color: AppColors.support,
                            fontSize: (labelStyle.fontSize ?? 12) * 0.82,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (onAdminPanel != null)
              _MenuAction(
                icon: Symbols.open_in_new,
                label: 'Admin panel',
                onTap: onAdminPanel!,
              ),
            _MenuAction(
              icon: Symbols.person_rounded,
              label: 'Profilim',
              onTap: onProfile,
            ),
            _MenuAction(
              icon: Symbols.logout,
              label: 'Çıkış yap',
              destructive: true,
              onTap: onSignOut,
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuAction extends StatelessWidget {
  const _MenuAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.actionRed : AppColors.deepOcean;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        mouseCursor: SystemMouseCursors.click,
        borderRadius: BorderRadius.circular(AppRadius.value),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Icon(icon, color: color.withValues(alpha: 0.78), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.mobileMenuLabel.copyWith(
                    color: color,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuAvatar extends StatelessWidget {
  const _MenuAvatar({required this.authState, required this.size});

  final FrontendAuthState authState;
  final double size;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = authState.avatarUrl;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipOval(
            child: avatarUrl.isEmpty
                ? _MenuAvatarFallback(authState: authState, size: size)
                : Image.network(
                    avatarUrl,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (_, _, _) =>
                        _MenuAvatarFallback(authState: authState, size: size),
                  ),
          ),
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.line),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuAvatarFallback extends StatelessWidget {
  const _MenuAvatarFallback({required this.authState, required this.size});

  final FrontendAuthState authState;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surfaceSoft,
      child: Center(
        child: Text(
          authState.initials,
          style: AppTypography.mobileMenuLabel.copyWith(
            color: AppColors.deepOcean,
            fontSize: size * 0.34,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}
