import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../account/data/frontend_auth_repository.dart';
import '../../account/presentation/account_sign_in_screen.dart';
import '../../announcements/data/announcements_repository.dart';
import '../../announcements/presentation/announcements_screen.dart';
import '../../apps/data/app_item.dart';
import '../../apps/presentation/app_feature_screen.dart';
import '../../apps/presentation/apps_sheet.dart';
import '../../category/presentation/category_screen.dart';
import '../../etkinlik/presentation/etkinlik_screen.dart';
import '../../home/presentation/home_screen.dart';
import '../../markets/data/markets_repository.dart';
import '../../markets/presentation/markets_screen.dart';
import '../../obituaries/data/death_notice_repository.dart';
import '../../obituaries/presentation/obituaries_screen.dart';
import '../../pharmacy/data/pharmacy_repository.dart';
import '../../pharmacy/presentation/pharmacy_screen.dart';
import '../../prayer_times/data/prayer_times_repository.dart';
import '../../prayer_times/presentation/prayer_times_screen.dart';
import '../../profile/data/profile_content.dart';
import '../../profile/presentation/profile_screen.dart';
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
    this.announcementData = const AnnouncementData.empty(),
    this.authState,
    this.authLoading = false,
    this.onSignIn,
    this.onSignOut,
    this.onOpenAdminPanel,
  });

  final Widget? accountPage;
  final AppShellData shellData;
  final DutyPharmacyData dutyPharmacyData;
  final DeathNoticeData deathNoticeData;
  final WeatherData weatherData;
  final MarketsData marketsData;
  final PrayerTimesData prayerTimesData;
  final AnnouncementData announcementData;
  final FrontendAuthState? authState;
  final bool authLoading;
  final FrontendSignInCallback? onSignIn;
  final Future<void> Function()? onSignOut;
  final Future<void> Function()? onOpenAdminPanel;

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen>
    with SingleTickerProviderStateMixin {
  int _index = 0;
  var _accountRouteOpen = false;
  var _menuOpen = false;
  var _accountMenuOpen = false;
  var _appsSheetOpen = false;
  var _menuDarkModeSelected = false;

  late final AnimationController _appsController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    reverseDuration: const Duration(milliseconds: 240),
  );

  static const _accountNavIndex = 4;
  static const _appsNavIndex = 2;

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

  /// Hesap menüsündeki "Profilim" bu sayfayı açar. Kimlik alanları (ad,
  /// kullanıcı adı, e‑posta, avatar, rol) oturum açan hesaptan beslenir;
  /// istatistik/gönderi gibi alanlar şimdilik örnek veridir (backend bağlanınca
  /// gerçeğiyle değişir). "Profili Düzenle" mevcut hesap ekranına götürür.
  Future<void> _openProfile() async {
    _closeAccountMenu();
    final auth = widget.authState;
    final profile = auth?.profile;
    final role = (profile?.role ?? '').trim().toLowerCase();
    final verified =
        role == 'admin' || role == 'super_admin' || role == 'editor';
    final data = ProfileData.demo(
      name: profile?.fullName ?? auth?.displayName,
      handle: profile?.handle,
      email: profile?.email ?? auth?.session.user.email,
      avatarUrl: profile?.avatarUrl,
      roleLabel: _roleLabelFor(role),
      isVerified: verified,
    );
    await Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 360),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (_, _, _) => ProfileScreen(data: data),
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('WhatsApp haber gönderme hattı hazırlanıyor.'),
      ),
    );
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
        pageBuilder: (_, _, _) =>
            CategoryScreen(categoryName: item.label, categoryType: item.type),
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
          ),
          'duyurular' => AnnouncementsScreen(
            initialData: widget.announcementData,
          ),
          'etkinlik' => const EtkinlikScreen(),
          'hava-durumu' => WeatherScreen(initialData: widget.weatherData),
          'namaz-vakitleri' => PrayerTimesScreen(
            initialData: widget.prayerTimesData,
          ),
          'doviz-altin' => MarketsScreen(initialData: widget.marketsData),
          'olum-ilanlari' => ObituariesScreen(
            initialData: widget.deathNoticeData,
            authState: widget.authState,
          ),
          _ => AppFeatureScreen(item: item),
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
    return Scaffold(
      body: SafeArea(
        top: false,
        bottom: false,
        child: IndexedStack(
          index: _index,
          children: [
            HomeScreen(
              shellSettings: widget.shellData.siteSettings,
              dutyPharmacyData: widget.dutyPharmacyData,
              onMenuTap: _openMenu,
              onSubmitNewsTap: _showSubmitNewsHint,
              onPharmacyTap: () => _openApp(AppItems.nobetciEczane),
            ),
            const SectionPlaceholder(
              icon: Symbols.play_circle_outline_rounded,
              title: 'Video akışı',
              message:
                  'Editör seçimi kısa videolar burada yayına alındığında '
                  'sana özel akış hazır olacak.',
            ),
            const SectionPlaceholder(
              icon: Symbols.grid_view_rounded,
              title: 'Pateez uygulamaları',
              message:
                  'Anketler, testler ve mini araçlar bu bölümde tek '
                  'çatı altında toplanacak.',
            ),
            const SectionPlaceholder(
              icon: Symbols.search_ai_line,
              title: 'Arama',
              message:
                  'Haberleri, videoları ve uygulamaları hızlıca bulman '
                  'için modern arama deneyimi burada hazırlanacak.',
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
          _closeAccountMenu();
          _closeAppsSheet();
          setState(() => _index = i);
        },
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
