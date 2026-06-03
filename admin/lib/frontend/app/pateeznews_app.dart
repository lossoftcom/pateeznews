import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sdk;

import '../../app/pateeznews_admin_app.dart';
import '../../features/auth/data/admin_auth_models.dart';
import '../../features/auth/data/admin_session_store.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_typography.dart';
import '../core/theme/frontend_font_settings.dart';
import '../features/account/data/frontend_auth_repository.dart';
import '../features/shell/data/app_shell_repository.dart';
import '../features/shell/presentation/shell_screen.dart';

class PateeznewsApp extends StatefulWidget {
  const PateeznewsApp({
    super.key,
    this.accountPage,
    this.fontSettingsRepository = const FrontendFontSettingsRepository(),
    this.shellRepository = const AppShellRepository(),
    this.authRepository = const FrontendAuthRepository(),
    this.adminSessionStore = const AdminSessionStore(),
    this.adminApp,
  });

  final Widget? accountPage;
  final FrontendFontSettingsRepository fontSettingsRepository;
  final AppShellRepository shellRepository;
  final FrontendAuthRepository authRepository;
  final AdminSessionStore adminSessionStore;
  final Widget? adminApp;

  @override
  State<PateeznewsApp> createState() => _PateeznewsAppState();
}

class _PateeznewsAppState extends State<PateeznewsApp> {
  var _fontSettings = FrontendFontSettings.empty();
  var _shellData = const AppShellData.empty();
  FrontendAuthState? _authState;
  var _authLoading = true;
  var _adminOpen = false;

  @override
  void initState() {
    super.initState();
    AppTypography.configure(_fontSettings);
    unawaited(_loadFontSettings());
    unawaited(_loadShellData());
    unawaited(_restoreAuthState());
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
      home: ShellScreen(
        accountPage: widget.accountPage,
        shellData: _shellData,
        authState: _authState,
        authLoading: _authLoading,
        onSignIn: _signIn,
        onSignOut: _signOut,
        onOpenAdminPanel: _openAdminPanel,
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
