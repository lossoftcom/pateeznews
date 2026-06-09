import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sdk;

import '../../app/pateeznews_admin_app.dart';
import '../../features/auth/data/admin_auth_models.dart';
import '../../features/auth/data/admin_session_store.dart';
import '../core/brand/default_brand_assets.dart';
import '../core/mock/home_mock_data.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_typography.dart';
import '../core/theme/frontend_font_settings.dart';
import '../features/account/data/frontend_auth_repository.dart';
import '../features/announcements/data/announcements_repository.dart';
import '../features/home/data/home_repository.dart';
import '../features/markets/data/markets_repository.dart';
import '../features/obituaries/data/death_notice_repository.dart';
import '../features/pharmacy/data/pharmacy_repository.dart';
import '../features/prayer_times/data/prayer_times_repository.dart';
import '../features/shell/data/app_shell_repository.dart';
import '../features/shell/presentation/shell_screen.dart';
import '../features/splash/presentation/splash_screen.dart';
import '../features/weather/data/weather_repository.dart';

class PateeznewsApp extends StatefulWidget {
  const PateeznewsApp({
    super.key,
    this.accountPage,
    this.fontSettingsRepository = const FrontendFontSettingsRepository(),
    this.shellRepository = const AppShellRepository(),
    this.pharmacyRepository = const PharmacyRepository(),
    this.deathNoticeRepository = const DeathNoticeRepository(),
    this.weatherRepository = const WeatherRepository(),
    this.marketsRepository = const MarketsRepository(),
    this.prayerTimesRepository = const PrayerTimesRepository(),
    this.announcementsRepository = const AnnouncementsRepository(),
    this.homeRepository = const HomeRepository(),
    this.authRepository = const FrontendAuthRepository(),
    this.adminSessionStore = const AdminSessionStore(),
    this.adminApp,
  });

  final Widget? accountPage;
  final FrontendFontSettingsRepository fontSettingsRepository;
  final AppShellRepository shellRepository;
  final PharmacyRepository pharmacyRepository;
  final DeathNoticeRepository deathNoticeRepository;
  final WeatherRepository weatherRepository;
  final MarketsRepository marketsRepository;
  final PrayerTimesRepository prayerTimesRepository;
  final AnnouncementsRepository announcementsRepository;
  final HomeRepository homeRepository;
  final FrontendAuthRepository authRepository;
  final AdminSessionStore adminSessionStore;
  final Widget? adminApp;

  @override
  State<PateeznewsApp> createState() => _PateeznewsAppState();
}

class _PateeznewsAppState extends State<PateeznewsApp> {
  var _fontSettings = FrontendFontSettings.empty();
  var _shellData = const AppShellData.empty();
  var _dutyPharmacyData = const DutyPharmacyData.empty();
  var _deathNoticeData = const DeathNoticeData.empty();
  var _weatherData = const WeatherData.empty();
  var _marketsData = const MarketsData.empty();
  var _prayerTimesData = const PrayerTimesData.empty();
  var _announcementData = const AnnouncementData.empty();
  List<FeaturedNews> _featuredItems = const [];
  List<NewsArticle> _homeFeedItems = const [];
  FrontendAuthState? _authState;
  var _authLoading = true;
  var _adminOpen = false;
  var _ready = false;

  /// Splash en az bu kadar görünür kalır (animasyon okunabilsin). Yüklemeler
  /// bundan önce biterse aradaki fark kadar beklenir.
  static const _minSplash = Duration(milliseconds: 700);

  /// Ağ yavaşsa splash en fazla bu kadar bekler, sonra güvenli fallback'lerle
  /// asıl ekrana geçilir. Repo timeout'ları ayrıca devrededir.
  static const _maxSplash = Duration(milliseconds: 3000);

  @override
  void initState() {
    super.initState();
    AppTypography.configure(_fontSettings);
    unawaited(_bootstrap());
  }

  /// Açılış akışı: font ayarları, kabuk verisi (logo/menü) ve oturum durumu
  /// paralel yüklenir; bu sırada [SplashScreen] görünür. Mini uygulama verileri
  /// de aynı açılış paketinde alınır. Hepsi hazır olunca — ya da ağ yavaşsa
  /// [_maxSplash] dolunca — asıl ekrana geçilir. Böylece [ShellScreen] ilk
  /// çiziminde tema, font, logo ve eczane verisi zaten kesinleşmiş olur.
  Future<void> _bootstrap() async {
    final started = DateTime.now();
    try {
      await Future.wait([
        _loadFontSettings(),
        _loadShellData(),
        _loadDutyPharmacyData(),
        _loadDeathNoticeData(),
        _loadWeatherData(),
        _loadMarketsData(),
        _loadPrayerTimesData(),
        _loadAnnouncementData(),
        _loadHomeData(),
        _restoreAuthState(),
      ]).timeout(_maxSplash);
    } catch (_) {
      // Timeout ya da bir yükleme hatası olsa da açılışı bloklamayız; ilgili
      // repo'lar güvenli boş değere düşer.
    }

    final elapsed = DateTime.now().difference(started);
    if (elapsed < _minSplash) {
      await Future<void>.delayed(_minSplash - elapsed);
    }

    if (!mounted) return;
    setState(() => _ready = true);
  }

  Future<void> _loadFontSettings() async {
    final settings = await widget.fontSettingsRepository.fetch('tr');
    if (!mounted) return;
    setState(() => _fontSettings = settings);
  }

  Future<void> _loadShellData() async {
    final shellData = await widget.shellRepository.fetch('tr');
    if (!mounted) return;
    setState(() => _shellData = shellData);
    await _precacheBrandLogos(shellData.siteSettings);
  }

  Future<void> _loadDutyPharmacyData() async {
    final data = await widget.pharmacyRepository.fetch();
    if (!mounted) return;
    setState(() => _dutyPharmacyData = data);
  }

  Future<void> _loadDeathNoticeData() async {
    final data = await widget.deathNoticeRepository.fetch();
    if (!mounted) return;
    setState(() => _deathNoticeData = data);
  }

  Future<void> _loadWeatherData() async {
    final data = await widget.weatherRepository.fetch();
    if (!mounted) return;
    setState(() => _weatherData = data);
  }

  Future<void> _loadMarketsData() async {
    final data = await widget.marketsRepository.fetch();
    if (!mounted) return;
    setState(() => _marketsData = data);
  }

  Future<void> _loadPrayerTimesData() async {
    final data = await widget.prayerTimesRepository.fetch();
    if (!mounted) return;
    setState(() => _prayerTimesData = data);
  }

  Future<void> _loadAnnouncementData() async {
    final data = await widget.announcementsRepository.fetch();
    if (!mounted) return;
    setState(() => _announcementData = data);
  }

  Future<void> _loadHomeData() async {
    final data = await widget.homeRepository.fetchHome();
    if (!mounted) return;
    setState(() {
      _featuredItems = data.featured;
      _homeFeedItems = data.feed;
    });
  }

  /// App bar ve tam ekran video üst barında kullanılan marka logolarını splash
  /// bitmeden cache'e alır. Ağ logosu gecikirse asset fallback zaten hazır olur.
  Future<void> _precacheBrandLogos(AppShellSettings settings) async {
    if (!mounted) return;
    try {
      final futures = <Future<void>>[
        precacheImage(const AssetImage(DefaultBrandAssets.logo), context),
        precacheImage(const AssetImage(DefaultBrandAssets.whiteLogo), context),
        precacheImage(const AssetImage(DefaultBrandAssets.darkLogo), context),
      ];
      final seen = <String>{};
      for (final url in [settings.displayLogoUrl, settings.darkLogoUrl]) {
        final clean = url.trim();
        if (clean.isEmpty || !seen.add(clean)) continue;
        futures.add(
          precacheImage(NetworkImage(clean), context, onError: (_, _) {}),
        );
      }
      await Future.wait(
        futures,
      ).timeout(const Duration(milliseconds: 1500), onTimeout: () => const []);
    } catch (_) {
      // Logo önceden yüklenemese de açılış sürmeli.
    }
  }

  Future<void> _restoreAuthState() async {
    try {
      final authState = await widget.authRepository.restoreSession();
      if (!mounted) return;
      setState(() {
        _authState = authState;
        _authLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _authState = null;
        _authLoading = false;
      });
    }
  }

  Future<FrontendAuthState> _signIn({
    required String identifier,
    required String password,
  }) async {
    final authState = await widget.authRepository.signInWithPassword(
      identifier: identifier,
      password: password,
    );
    if (mounted) {
      setState(() => _authState = authState);
    }
    return authState;
  }

  Future<void> _signOut() async {
    await widget.authRepository.signOut();
    await widget.adminSessionStore.clearAuth();
    if (!mounted) return;
    setState(() => _authState = null);
  }

  Future<void> _openAdminPanel() async {
    final authState = _authState;
    if (authState == null || !authState.isAdmin) return;

    await widget.adminSessionStore.saveSession(
      _adminSessionFromFrontend(authState.session),
    );
    await _recoverSupabaseSession(authState.session);
    final profile = _adminProfileFromFrontend(authState.profile);
    if (profile != null) {
      await widget.adminSessionStore.saveProfileCache(profile);
    }

    if (!mounted) return;
    setState(() => _adminOpen = true);
  }

  void _openFrontend() {
    if (!_adminOpen) return;
    setState(() => _adminOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_adminOpen) {
      return widget.adminApp ??
          PateeznewsAdminApp(onOpenFrontend: _openFrontend);
    }

    SystemChrome.setSystemUIOverlayStyle(AppTheme.lightOverlay);
    return MaterialApp(
      title: 'Pateeznews',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(fontSettings: _fontSettings),
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: _ready
            ? ShellScreen(
                key: const ValueKey('shell'),
                accountPage: widget.accountPage,
                shellData: _shellData,
                dutyPharmacyData: _dutyPharmacyData,
                deathNoticeData: _deathNoticeData,
                weatherData: _weatherData,
                marketsData: _marketsData,
                prayerTimesData: _prayerTimesData,
                announcementData: _announcementData,
                featuredItems: _featuredItems,
                homeFeedItems: _homeFeedItems,
                onRefreshHome: _loadHomeData,
                authState: _authState,
                authLoading: _authLoading,
                onSignIn: _signIn,
                onSignOut: _signOut,
                onOpenAdminPanel: _openAdminPanel,
              )
            : const SplashScreen(key: ValueKey('splash')),
      ),
    );
  }
}

Future<void> _recoverSupabaseSession(FrontendAuthSession session) async {
  try {
    await sdk.Supabase.instance.client.auth.recoverSession(
      jsonEncode(_supabaseSessionJson(session)),
    );
  } catch (_) {
    // AdminSessionStore fallback keeps the admin handoff working in API-only runs.
  }
}

AdminSession _adminSessionFromFrontend(FrontendAuthSession session) {
  return AdminSession(
    accessToken: session.accessToken,
    tokenType: session.tokenType,
    expiresAt: session.expiresAt,
    user: AdminUser(
      id: session.user.id,
      email: session.user.email,
      role: 'authenticated',
      aud: 'authenticated',
      userMetadata: session.user.userMetadata,
      appMetadata: const {},
    ),
  );
}

Map<String, Object?> _supabaseSessionJson(FrontendAuthSession session) {
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final expiresIn = session.expiresAt > now ? session.expiresAt - now : 0;
  return {
    'access_token': session.accessToken,
    'expires_in': expiresIn,
    'expires_at': session.expiresAt,
    'refresh_token': null,
    'token_type': session.tokenType,
    'provider_token': null,
    'provider_refresh_token': null,
    'user': {
      'id': session.user.id,
      'app_metadata': const {},
      'user_metadata': session.user.userMetadata,
      'aud': 'authenticated',
      'email': session.user.email,
      'phone': null,
      'created_at': '',
      'role': 'authenticated',
    },
  };
}

AdminProfile? _adminProfileFromFrontend(FrontendProfile? profile) {
  if (profile == null) return null;
  return AdminProfile(
    id: profile.id,
    username: profile.username,
    fullName: profile.fullName,
    avatarUrl: profile.avatarUrl,
    role: profile.role,
    email: profile.email,
  );
}
