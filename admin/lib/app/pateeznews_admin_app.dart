import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/localization/admin_language_controller.dart';
import '../core/theme/app_theme.dart';
import '../features/account/data/admin_account_settings_repository.dart';
import '../features/auth/data/admin_auth_repository.dart';
import '../features/auth/data/neon_auth_client.dart';
import '../features/comments/data/admin_comments_repository.dart';
import '../features/navigation/data/admin_navigation_repository.dart';
import '../features/news/data/admin_news_repository.dart';
import '../features/settings/data/admin_ai_settings_repository.dart';
import '../features/settings/data/admin_general_settings_repository.dart';
import '../features/settings/data/admin_languages_repository.dart';
import '../features/settings/data/admin_module_settings_repository.dart';
import '../features/users/data/admin_roles_repository.dart';
import '../features/users/data/admin_users_repository.dart';
import 'admin_gate.dart';

class PateeznewsAdminApp extends StatefulWidget {
  const PateeznewsAdminApp({
    super.key,
    this.authRepository,
    this.newsRepository,
    this.commentsRepository,
    this.navigationRepository,
    this.usersRepository,
    this.rolesRepository,
    this.languagesRepository,
    this.generalSettingsRepository,
    this.aiSettingsRepository,
    this.moduleSettingsRepository,
    this.accountSettingsRepository,
    this.languageController,
  });

  final AdminAuthRepository? authRepository;
  final AdminNewsRepository? newsRepository;
  final AdminCommentsRepository? commentsRepository;
  final AdminNavigationRepository? navigationRepository;
  final AdminUsersRepository? usersRepository;
  final AdminRolesRepository? rolesRepository;
  final AdminLanguagesRepository? languagesRepository;
  final AdminGeneralSettingsRepository? generalSettingsRepository;
  final AdminAiSettingsRepository? aiSettingsRepository;
  final AdminModuleSettingsRepository? moduleSettingsRepository;
  final AdminAccountSettingsRepository? accountSettingsRepository;
  final AdminLanguageController? languageController;

  @override
  State<PateeznewsAdminApp> createState() => _PateeznewsAdminAppState();
}

class _PateeznewsAdminAppState extends State<PateeznewsAdminApp> {
  late final AdminLanguagesRepository _languagesRepository;
  late final AdminLanguageController _languageController;

  @override
  void initState() {
    super.initState();
    _languagesRepository =
        widget.languagesRepository ?? const NeonAdminLanguagesRepository();
    _languageController =
        widget.languageController ??
        AdminLanguageController(repository: _languagesRepository);
    unawaited(_languageController.loadInitial());
  }

  @override
  Widget build(BuildContext context) {
    return AdminLocalizationScope(
      controller: _languageController,
      child: AnimatedBuilder(
        animation: _languageController,
        builder: (context, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: _languageController.t('app.title'),
            locale: _languageController.locale,
            supportedLocales: _languageController.supportedLocales,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: AppTheme.light(),
            home: AdminGate(
              authRepository: widget.authRepository ?? const NeonAuthClient(),
              newsRepository:
                  widget.newsRepository ?? const NeonAdminNewsRepository(),
              commentsRepository:
                  widget.commentsRepository ??
                  const NeonAdminCommentsRepository(),
              navigationRepository:
                  widget.navigationRepository ??
                  const NeonAdminNavigationRepository(),
              usersRepository:
                  widget.usersRepository ?? const NeonAdminUsersRepository(),
              rolesRepository:
                  widget.rolesRepository ?? const NeonAdminRolesRepository(),
              languagesRepository: _languagesRepository,
              generalSettingsRepository:
                  widget.generalSettingsRepository ??
                  const NeonAdminGeneralSettingsRepository(),
              aiSettingsRepository:
                  widget.aiSettingsRepository ??
                  const NeonAdminAiSettingsRepository(),
              moduleSettingsRepository:
                  widget.moduleSettingsRepository ??
                  const NeonAdminModuleSettingsRepository(),
              accountSettingsRepository:
                  widget.accountSettingsRepository ??
                  const NeonAdminAccountSettingsRepository(),
            ),
          );
        },
      ),
    );
  }
}
