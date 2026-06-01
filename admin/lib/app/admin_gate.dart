import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
import '../features/pages/data/admin_pages_repository.dart';
import '../features/settings/data/admin_ai_settings_repository.dart';
import '../features/settings/data/admin_font_settings_repository.dart';
import '../features/settings/data/admin_general_settings_repository.dart';
import '../features/settings/data/admin_module_settings_repository.dart';
import '../features/sms/data/admin_sms_repository.dart';
import '../features/social/data/admin_social_repository.dart';
import '../features/stories/data/admin_stories_repository.dart';
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
    required this.moduleSettingsRepository,
    required this.accountSettingsRepository,
    required this.subscribersRepository,
    required this.smsRepository,
    required this.socialRepository,
  });

  final AdminAuthRepository authRepository;
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
  final AdminModuleSettingsRepository moduleSettingsRepository;
  final AdminAccountSettingsRepository accountSettingsRepository;
  final AdminSubscribersRepository subscribersRepository;
  final AdminSmsRepository smsRepository;
  final AdminSocialRepository socialRepository;

  @override
  State<AdminGate> createState() => _AdminGateState();
}

class _AdminGateState extends State<AdminGate> {
  final _sessionStore = const AdminSessionStore();
  var _checkingSession = true;
  AdminSession? _session;
  AdminProfile? _profile;
  StreamSubscription<sdk.AuthState>? _supabaseAuthSubscription;

  @override
  void initState() {
    super.initState();
    _listenToSupabaseAuthChanges();
    unawaited(_restoreSession());
  }

  @override
  void dispose() {
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
  }

  Future<void> _clearSupabaseSession() async {
    await _sessionStore.clearAuth();
    if (!mounted || _session == null) return;
    setState(() {
      _session = null;
      _profile = null;
    });
  }

  Future<void> _restoreSession() async {
    try {
      final authState = await widget.authRepository.restoreSession();
      if (!mounted) return;
      setState(() {
        _session = authState?.session;
        _profile = authState?.profile;
        _checkingSession = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _session = null;
        _profile = null;
        _checkingSession = false;
      });
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
    });
  }

  Future<void> _logout() async {
    setState(() {
      _session = null;
      _profile = null;
    });
    await widget.authRepository.signOut();
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingSession) {
      return const Scaffold(
        body: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.deepOcean,
            ),
          ),
        ),
      );
    }

    final session = _session;

    return session != null
        ? DashboardScreen(
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
            moduleSettingsRepository: widget.moduleSettingsRepository,
            accountSettingsRepository: widget.accountSettingsRepository,
            subscribersRepository: widget.subscribersRepository,
            smsRepository: widget.smsRepository,
            socialRepository: widget.socialRepository,
          )
        : LoginScreen(onLogin: _login);
  }
}
