import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sdk;

import '../core/theme/app_colors.dart';
import '../features/account/data/admin_account_settings_repository.dart';
import '../features/auth/data/admin_auth_models.dart';
import '../features/auth/data/admin_auth_repository.dart';
import '../features/auth/data/admin_session_store.dart';
import '../features/auth/data/supabase_auth_client.dart';
import '../features/comments/data/admin_comments_repository.dart';
import '../features/navigation/data/admin_navigation_repository.dart';
import '../features/news/data/admin_news_repository.dart';
import '../features/notifications/data/admin_notifications_repository.dart';
import '../features/pages/data/admin_pages_repository.dart';
import '../features/settings/data/admin_ai_settings_repository.dart';
import '../features/settings/data/admin_content_settings_repository.dart';
import '../features/settings/data/admin_font_settings_repository.dart';
import '../features/settings/data/admin_general_settings_repository.dart';
import '../features/settings/data/admin_module_settings_repository.dart';
import '../features/settings/data/admin_security_settings_repository.dart';
import '../features/settings/data/admin_storage_settings_repository.dart';
import '../features/sms/data/admin_sms_repository.dart';
import '../features/social/data/admin_social_repository.dart';
import '../features/stories/data/admin_stories_repository.dart';
import '../shared/branding/admin_branding.dart';
import '../shared/data/media_service.dart';
import '../shared/widgets/admin_brand_mark.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/settings/data/admin_languages_repository.dart';
import '../features/users/data/admin_roles_repository.dart';
import '../features/users/data/admin_users_repository.dart';
import '../features/subscribers/data/admin_subscribers_repository.dart';

class AdminGate extends StatefulWidget {
  const AdminGate({
    super.key,
    required this.authRepository,
    required this.languageCode,
    required this.newsRepository,
    required this.storiesRepository,
    required this.pagesRepository,
    required this.commentsRepository,
    required this.navigationRepository,
    required this.usersRepository,
    required this.rolesRepository,
    required this.languagesRepository,
    required this.generalSettingsRepository,
    required this.fontSettingsRepository,
    required this.aiSettingsRepository,
    required this.contentSettingsRepository,
    required this.moduleSettingsRepository,
    required this.securitySettingsRepository,
    required this.storageSettingsRepository,
    required this.accountSettingsRepository,
    required this.subscribersRepository,
    required this.notificationsRepository,
    required this.smsRepository,
    required this.socialRepository,
    this.onOpenFrontend,
  });

  final AdminAuthRepository authRepository;
  final String languageCode;
  final AdminNewsRepository newsRepository;
  final AdminStoriesRepository storiesRepository;
  final AdminPagesRepository pagesRepository;
  final AdminCommentsRepository commentsRepository;
  final AdminNavigationRepository navigationRepository;
  final AdminUsersRepository usersRepository;
  final AdminRolesRepository rolesRepository;
  final AdminLanguagesRepository languagesRepository;
  final AdminGeneralSettingsRepository generalSettingsRepository;
  final AdminFontSettingsRepository fontSettingsRepository;
  final AdminAiSettingsRepository aiSettingsRepository;
  final AdminContentSettingsRepository contentSettingsRepository;
  final AdminModuleSettingsRepository moduleSettingsRepository;
  final AdminSecuritySettingsRepository securitySettingsRepository;
  final AdminStorageSettingsRepository storageSettingsRepository;
  final AdminAccountSettingsRepository accountSettingsRepository;
  final AdminSubscribersRepository subscribersRepository;
  final AdminNotificationsRepository notificationsRepository;
  final AdminSmsRepository smsRepository;
  final AdminSocialRepository socialRepository;
  final VoidCallback? onOpenFrontend;

  @override
  State<AdminGate> createState() => _AdminGateState();
}

class _AdminGateState extends State<AdminGate> {
  final _sessionStore = const AdminSessionStore();
  var _checkingSession = true;
  AdminSession? _session;
  AdminProfile? _profile;
  ContentSettingsSnapshot? _contentSettingsSnapshot;
  StreamSubscription<sdk.AuthState>? _supabaseAuthSubscription;

  /// Oturumu yalnızca KULLANICI ETKİNLİĞİNE göre sonlandıran inaktivite süresi.
  /// Bu süre boyunca hiç etkileşim (dokunma/kaydırma/tuş) olmazsa giriş ekranına
  /// düşülür; her etkileşimde sayaç sıfırlanır. (Eski davranış: token'ın mutlak
  /// son kullanım anında, kullanıcı aktif olsa bile çıkış yapılıyordu.)
  static const _idleTimeout = Duration(minutes: 30);
  Timer? _idleTimer;

  @override
  void initState() {
    super.initState();
    _listenToSupabaseAuthChanges();
    unawaited(_restoreSession());
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    unawaited(_supabaseAuthSubscription?.cancel());
    super.dispose();
  }

  void _listenToSupabaseAuthChanges() {
    try {
      final auth = sdk.Supabase.instance.client.auth;
      final currentSession = auth.currentSession;
      if (currentSession != null) {
        unawaited(_persistSupabaseSession(currentSession, updateUi: false));
      }
      _supabaseAuthSubscription = auth.onAuthStateChange.listen(
        (data) {
          final event = data.event;
          final session = data.session;
          if (event == sdk.AuthChangeEvent.signedOut) {
            unawaited(_clearSupabaseSession());
            return;
          }
          if (session == null) return;
          unawaited(_persistSupabaseSession(session));
        },
        onError: (Object error, StackTrace stackTrace) {
          if (kDebugMode) {
            debugPrint('Admin auth state sync failed: $error');
          }
        },
      );
    } catch (_) {
      // Supabase SDK is optional in API-only local builds.
    }
  }

  Future<void> _persistSupabaseSession(
    sdk.Session sdkSession, {
    bool updateUi = true,
  }) async {
    if (sdkSession.accessToken.trim().isEmpty) return;
    final session = adminSessionFromSupabaseSession(sdkSession);
    await _sessionStore.saveSession(session);
    if (!mounted || !updateUi) return;
    final currentSession = _session;
    if (currentSession == null || currentSession.user.id != session.user.id) {
      return;
    }
    setState(() {
      _session = session;
    });
    // Token arka planda yenilendi (SDK auto-refresh). İnaktivite sayacı
    // kullanıcı etkinliğine bağlıdır; sessiz token yenilemesi onu sıfırlamaz.
  }

  Future<void> _clearSupabaseSession() async {
    await _sessionStore.clearAuth();
    _cancelIdleTimer();
    if (!mounted || _session == null) return;
    _dismissAllModals();
    setState(() {
      _session = null;
      _profile = null;
    });
  }

  Future<void> _restoreSession() async {
    // Marka (logo + site adı) splash sırasında yüklensin → login/dashboard
    // açılınca doğru logo "şak diye" hazır gelsin (boş/yanlış marka görünmez).
    final brandingReady = AdminBrandingStore.bootstrap(
      languageCode: widget.languageCode,
    );
    try {
      final authState = await widget.authRepository.restoreSession();
      unawaited(brandingReady);
      if (!mounted) return;
      setState(() {
        _session = authState?.session;
        _profile = authState?.profile;
        _contentSettingsSnapshot = null;
        _checkingSession = false;
      });
      if (authState?.session != null) {
        _startIdleTimer();
        unawaited(_refreshInitialContentSettings(widget.languageCode));
        unawaited(_refreshBranding());
      }
    } catch (_) {
      unawaited(brandingReady);
      if (!mounted) return;
      setState(() {
        _session = null;
        _profile = null;
        _contentSettingsSnapshot = null;
        _checkingSession = false;
      });
      _cancelIdleTimer();
    }
  }

  Future<void> _refreshInitialContentSettings(String languageCode) async {
    final snapshot = await _preloadContentSettings(languageCode);
    if (!mounted || _session == null) return;
    setState(() {
      _contentSettingsSnapshot = snapshot;
    });
  }

  Future<ContentSettingsSnapshot> _preloadContentSettings(
    String languageCode,
  ) async {
    final normalizedCode = languageCode.trim().isEmpty
        ? 'tr'
        : languageCode.trim();
    try {
      final snapshot = await widget.contentSettingsRepository.fetchAllSettings(
        normalizedCode,
      );
      _cacheUploadSettings(snapshot.upload);
      return snapshot;
    } catch (_) {
      final fallback = ContentSettingsSnapshot.defaults(normalizedCode);
      _cacheUploadSettings(fallback.upload);
      return fallback;
    }
  }

  void _cacheUploadSettings(ContentUploadSettingsData settings) {
    MediaService.cacheUploadSettings(
      MediaUploadSettings(
        imageFileFormat: settings.imageFileFormat,
        allowedExtensions: settings.allowedExtensions,
        maxImageSizeMb: settings.maxImageSizeMb,
        maxVideoSizeMb: settings.maxVideoSizeMb,
        maxAudioSizeMb: settings.maxAudioSizeMb,
        maxFileSizeMb: settings.maxFileSizeMb,
      ),
      languageCode: settings.languageCode,
    );
  }

  /// Oturum açıkken gerçek admin ayarlarından markayı kesin günceller + kalıcı
  /// yazar (sonraki açılışta giriş ekranı doğru logoyu anında gösterir).
  Future<void> _refreshBranding() async {
    try {
      final settings = await widget.generalSettingsRepository.fetchSettings(
        widget.languageCode,
      );
      await AdminBrandingStore.update(
        AdminBrandingData(
          siteName: settings.siteName,
          logoUrl: widget.generalSettingsRepository.publicUrl(settings.logoUrl),
          emailLogoUrl: widget.generalSettingsRepository.publicUrl(
            settings.emailLogoUrl,
          ),
          faviconUrl: widget.generalSettingsRepository.publicUrl(
            settings.faviconUrl,
          ),
        ),
      );
    } catch (_) {
      // sessiz — splash'ta yüklenen marka ekranda kalır
    }
  }

  Future<void> _login(String email, String password) async {
    final authState = await widget.authRepository.signInWithPassword(
      email: email,
      password: password,
    );
    if (!mounted) return;
    setState(() {
      _session = authState.session;
      _profile = authState.profile;
      _contentSettingsSnapshot = null;
    });
    _startIdleTimer();
    unawaited(_refreshInitialContentSettings(widget.languageCode));
    unawaited(_refreshBranding());
  }

  Future<void> _logout() async {
    _cancelIdleTimer();
    _dismissAllModals();
    setState(() {
      _session = null;
      _profile = null;
      _contentSettingsSnapshot = null;
    });
    await widget.authRepository.signOut();
  }

  /// İnaktivite sayacını (yeniden) başlatır → her çağrıda sıfırdan 30 dk sayar.
  /// Oturum yoksa hiçbir şey yapmaz. Hem oturum kurulurken hem de her kullanıcı
  /// etkileşiminde çağrılır.
  void _startIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = null;
    if (_session == null) return;
    _idleTimer = Timer(_idleTimeout, _handleIdleTimeout);
  }

  void _cancelIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = null;
  }

  /// Uzun süre etkileşim olmadı → önce açık tüm modallar kapanır, sonra çıkış.
  void _handleIdleTimeout() {
    if (!mounted || _session == null) return;
    unawaited(_logout());
  }

  /// Root Navigator'daki tüm diyalog/bottom-sheet/route'ları kapatır; geriye
  /// yalnızca kök (gate) route'u kalır. Giriş ekranına düşünce ekranda hiçbir
  /// modal/kart açık kalmaz.
  void _dismissAllModals() {
    final navigator = Navigator.maybeOf(context, rootNavigator: true);
    navigator?.popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingSession) {
      return const _AdminStartupLoadingScreen();
    }

    final session = _session;

    return session != null
        ? _ActivityDetector(
            onActivity: _startIdleTimer,
            child: DashboardScreen(
              session: session,
              profile: _profile,
              onLogout: () => unawaited(_logout()),
              newsRepository: widget.newsRepository,
              storiesRepository: widget.storiesRepository,
              pagesRepository: widget.pagesRepository,
              commentsRepository: widget.commentsRepository,
              navigationRepository: widget.navigationRepository,
              usersRepository: widget.usersRepository,
              rolesRepository: widget.rolesRepository,
              languagesRepository: widget.languagesRepository,
              generalSettingsRepository: widget.generalSettingsRepository,
              fontSettingsRepository: widget.fontSettingsRepository,
              aiSettingsRepository: widget.aiSettingsRepository,
              contentSettingsRepository: widget.contentSettingsRepository,
              initialContentSettings:
                  _contentSettingsSnapshot ??
                  ContentSettingsSnapshot.defaults(widget.languageCode),
              moduleSettingsRepository: widget.moduleSettingsRepository,
              securitySettingsRepository: widget.securitySettingsRepository,
              storageSettingsRepository: widget.storageSettingsRepository,
              accountSettingsRepository: widget.accountSettingsRepository,
              subscribersRepository: widget.subscribersRepository,
              notificationsRepository: widget.notificationsRepository,
              smsRepository: widget.smsRepository,
              socialRepository: widget.socialRepository,
              onOpenFrontend: widget.onOpenFrontend,
            ),
          )
        : LoginScreen(onLogin: _login);
  }
}

/// Giriş yapılmış ekranı sarar; herhangi bir kullanıcı etkileşimini (dokunma,
/// kaydırma, fare hareketi/tekerleği, donanım klavye tuşu) yakalayıp
/// [onActivity] çağırır. Olayları TÜKETMEZ — alttaki widget'ların jest/giriş
/// davranışı aynen devam eder.
class _ActivityDetector extends StatefulWidget {
  const _ActivityDetector({required this.onActivity, required this.child});

  final VoidCallback onActivity;
  final Widget child;

  @override
  State<_ActivityDetector> createState() => _ActivityDetectorState();
}

class _ActivityDetectorState extends State<_ActivityDetector> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKey);
    super.dispose();
  }

  bool _handleKey(KeyEvent event) {
    widget.onActivity();
    return false; // tuşu tüketme — normal klavye akışı bozulmasın
  }

  void _handlePointer([Object? _]) => widget.onActivity();

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointer,
      onPointerMove: _handlePointer,
      onPointerHover: _handlePointer,
      onPointerSignal: _handlePointer,
      child: widget.child,
    );
  }
}

class _AdminStartupLoadingScreen extends StatelessWidget {
  const _AdminStartupLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.surface,
      body: Center(child: _AdminStartupLoading()),
    );
  }
}

class _AdminStartupLoading extends StatefulWidget {
  const _AdminStartupLoading();

  @override
  State<_AdminStartupLoading> createState() => _AdminStartupLoadingState();
}

class _AdminStartupLoadingState extends State<_AdminStartupLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1350),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value;
          final pulse = 0.97 + 0.03 * (0.5 + 0.5 * math.sin(t * 2 * math.pi));
          return SizedBox(
            width: 92,
            height: 92,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size.square(92),
                  painter: _StartupLoadingPainter(rotation: t),
                ),
                Transform.scale(scale: pulse, child: child),
              ],
            ),
          );
        },
        child: const _AdminStartupBrandMark(),
      ),
    );
  }
}

class _AdminStartupBrandMark extends StatelessWidget {
  const _AdminStartupBrandMark();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AdminBrandingData>(
      valueListenable: adminBranding,
      builder: (context, branding, _) {
        return AdminBrandMark(branding: branding, size: 40);
      },
    );
  }
}

class _StartupLoadingPainter extends CustomPainter {
  const _StartupLoadingPainter({required this.rotation});

  /// 0..1 → bir tam tur. AnimationController.value doğrudan beslenir.
  final double rotation;

  static const double _twoPi = math.pi * 2;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const stroke = 4.0;
    final radius = size.shortestSide / 2 - 6;

    // İnce, soluk tam halka (ilerleme rayı).
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = AppColors.softLine,
    );

    // Tek düz renkli dönen yay — renk geçişi / gradient YOK.
    // Yumuşak hızlanıp yavaşlayan organik dönüş (geri sarmaz).
    final spin = rotation * _twoPi + 0.5 * math.sin(rotation * _twoPi);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      spin,
      _twoPi * 0.72,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = AppColors.actionRed,
    );
  }

  @override
  bool shouldRepaint(_StartupLoadingPainter oldDelegate) {
    return oldDelegate.rotation != rotation;
  }
}
