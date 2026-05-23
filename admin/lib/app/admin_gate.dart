import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../features/account/data/admin_account_settings_repository.dart';
import '../features/auth/data/admin_auth_models.dart';
import '../features/auth/data/admin_auth_repository.dart';
import '../features/comments/data/admin_comments_repository.dart';
import '../features/navigation/data/admin_navigation_repository.dart';
import '../features/news/data/admin_news_repository.dart';
import '../features/settings/data/admin_ai_settings_repository.dart';
import '../features/settings/data/admin_general_settings_repository.dart';
import '../features/settings/data/admin_module_settings_repository.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/settings/data/admin_languages_repository.dart';
import '../features/users/data/admin_roles_repository.dart';
import '../features/users/data/admin_users_repository.dart';

class AdminGate extends StatefulWidget {
  const AdminGate({
    super.key,
    required this.authRepository,
    required this.newsRepository,
    required this.commentsRepository,
    required this.navigationRepository,
    required this.usersRepository,
    required this.rolesRepository,
    required this.languagesRepository,
    required this.generalSettingsRepository,
    required this.aiSettingsRepository,
    required this.moduleSettingsRepository,
    required this.accountSettingsRepository,
  });

  final AdminAuthRepository authRepository;
  final AdminNewsRepository newsRepository;
  final AdminCommentsRepository commentsRepository;
  final AdminNavigationRepository navigationRepository;
  final AdminUsersRepository usersRepository;
  final AdminRolesRepository rolesRepository;
  final AdminLanguagesRepository languagesRepository;
  final AdminGeneralSettingsRepository generalSettingsRepository;
  final AdminAiSettingsRepository aiSettingsRepository;
  final AdminModuleSettingsRepository moduleSettingsRepository;
  final AdminAccountSettingsRepository accountSettingsRepository;

  @override
  State<AdminGate> createState() => _AdminGateState();
}

class _AdminGateState extends State<AdminGate> {
  var _checkingSession = true;
  AdminSession? _session;
  AdminProfile? _profile;

  @override
  void initState() {
    super.initState();
    unawaited(_restoreSession());
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
            commentsRepository: widget.commentsRepository,
            navigationRepository: widget.navigationRepository,
            usersRepository: widget.usersRepository,
            rolesRepository: widget.rolesRepository,
            languagesRepository: widget.languagesRepository,
            generalSettingsRepository: widget.generalSettingsRepository,
            aiSettingsRepository: widget.aiSettingsRepository,
            moduleSettingsRepository: widget.moduleSettingsRepository,
            accountSettingsRepository: widget.accountSettingsRepository,
          )
        : LoginScreen(onLogin: _login);
  }
}
