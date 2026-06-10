import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../core/localization/admin_language_controller.dart';
import '../core/theme/app_theme.dart';
import '../features/account/data/admin_account_settings_repository.dart';
import '../features/auth/data/admin_auth_repository.dart';
import '../features/auth/data/supabase_auth_client.dart';
import '../features/comments/data/admin_comments_repository.dart';
import '../features/navigation/data/admin_navigation_repository.dart';
import '../features/news/data/admin_news_repository.dart';
import '../features/pages/data/admin_pages_repository.dart';
import '../features/settings/data/admin_ai_settings_repository.dart';
import '../features/settings/data/admin_content_settings_repository.dart';
import '../features/settings/data/admin_font_settings_repository.dart';
import '../features/settings/data/admin_general_settings_repository.dart';
import '../features/settings/data/admin_languages_repository.dart';
import '../features/settings/data/admin_module_settings_repository.dart';
import '../features/settings/data/admin_security_settings_repository.dart';
import '../features/sms/data/admin_sms_repository.dart';
import '../features/social/data/admin_social_repository.dart';
import '../features/subscribers/data/admin_subscribers_repository.dart';
import '../features/stories/data/admin_stories_repository.dart';
import '../features/users/data/admin_roles_repository.dart';
import '../features/users/data/admin_users_repository.dart';
import 'admin_gate.dart';

class PateeznewsAdminApp extends StatefulWidget {
  const PateeznewsAdminApp({
    super.key,
    this.authRepository,
    this.newsRepository,
    this.storiesRepository,
    this.pagesRepository,
    this.commentsRepository,
    this.navigationRepository,
    this.usersRepository,
    this.rolesRepository,
    this.languagesRepository,
    this.generalSettingsRepository,
    this.fontSettingsRepository,
    this.aiSettingsRepository,
    this.contentSettingsRepository,
    this.moduleSettingsRepository,
    this.securitySettingsRepository,
    this.accountSettingsRepository,
    this.subscribersRepository,
    this.smsRepository,
    this.socialRepository,
    this.languageController,
    this.onOpenFrontend,
  });

  final AdminAuthRepository? authRepository;
  final AdminNewsRepository? newsRepository;
  final AdminStoriesRepository? storiesRepository;
  final AdminPagesRepository? pagesRepository;
  final AdminCommentsRepository? commentsRepository;
  final AdminNavigationRepository? navigationRepository;
  final AdminUsersRepository? usersRepository;
  final AdminRolesRepository? rolesRepository;
  final AdminLanguagesRepository? languagesRepository;
  final AdminGeneralSettingsRepository? generalSettingsRepository;
  final AdminFontSettingsRepository? fontSettingsRepository;
  final AdminAiSettingsRepository? aiSettingsRepository;
  final AdminContentSettingsRepository? contentSettingsRepository;
  final AdminModuleSettingsRepository? moduleSettingsRepository;
  final AdminSecuritySettingsRepository? securitySettingsRepository;
  final AdminAccountSettingsRepository? accountSettingsRepository;
  final AdminSubscribersRepository? subscribersRepository;
  final AdminSmsRepository? smsRepository;
  final AdminSocialRepository? socialRepository;
  final AdminLanguageController? languageController;
  final VoidCallback? onOpenFrontend;

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
        widget.languagesRepository ?? const SupabaseAdminLanguagesRepository();
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
              FlutterQuillLocalizations.delegate,
            ],
            theme: AppTheme.light(),
            home: AdminGate(
              languageCode: _languageController.code,
              authRepository:
                  widget.authRepository ?? const SupabaseAuthClient(),
              newsRepository:
                  widget.newsRepository ?? const SupabaseAdminNewsRepository(),
              storiesRepository:
                  widget.storiesRepository ??
                  const SupabaseAdminStoriesRepository(),
              pagesRepository:
                  widget.pagesRepository ??
                  const SupabaseAdminPagesRepository(),
              commentsRepository:
                  widget.commentsRepository ??
                  const SupabaseAdminCommentsRepository(),
              navigationRepository:
                  widget.navigationRepository ??
                  const SupabaseAdminNavigationRepository(),
              usersRepository:
                  widget.usersRepository ??
                  const SupabaseAdminUsersRepository(),
              rolesRepository:
                  widget.rolesRepository ??
                  const SupabaseAdminRolesRepository(),
              languagesRepository: _languagesRepository,
              generalSettingsRepository:
                  widget.generalSettingsRepository ??
                  const SupabaseAdminGeneralSettingsRepository(),
              fontSettingsRepository:
                  widget.fontSettingsRepository ??
                  const SupabaseAdminFontSettingsRepository(),
              aiSettingsRepository:
                  widget.aiSettingsRepository ??
                  const SupabaseAdminAiSettingsRepository(),
              contentSettingsRepository:
                  widget.contentSettingsRepository ??
                  const SupabaseAdminContentSettingsRepository(),
              moduleSettingsRepository:
                  widget.moduleSettingsRepository ??
                  const SupabaseAdminModuleSettingsRepository(),
              securitySettingsRepository:
                  widget.securitySettingsRepository ??
                  const SupabaseAdminSecuritySettingsRepository(),
              accountSettingsRepository:
                  widget.accountSettingsRepository ??
                  const SupabaseAdminAccountSettingsRepository(),
              subscribersRepository:
                  widget.subscribersRepository ??
                  const SupabaseAdminSubscribersRepository(),
              smsRepository:
                  widget.smsRepository ?? const SupabaseAdminSmsRepository(),
              socialRepository:
                  widget.socialRepository ??
                  const SupabaseAdminSocialRepository(),
              onOpenFrontend: widget.onOpenFrontend,
            ),
          );
        },
      ),
    );
  }
}
