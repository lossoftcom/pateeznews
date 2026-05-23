import 'package:flutter/material.dart';
import 'package:pateeznews_admin/features/account/data/admin_account_settings_repository.dart';
import 'package:pateeznews_admin/features/account/presentation/account_settings_screen.dart';
import 'package:pateeznews_admin/features/comments/data/admin_comments_repository.dart';
import 'package:pateeznews_admin/features/comments/presentation/comments_screen.dart';
import 'package:pateeznews_admin/features/mail/presentation/bulk_mail_screen.dart';
import 'package:pateeznews_admin/features/mail/presentation/contact_lists_screen.dart';
import 'package:pateeznews_admin/features/mail/presentation/mail_inbox_screen.dart';
import 'package:pateeznews_admin/features/mail/presentation/mail_settings_screen.dart';
import 'package:pateeznews_admin/features/mail/presentation/mail_templates_screen.dart';
import 'package:pateeznews_admin/features/whatsapp/presentation/whatsapp_bulk_screen.dart';
import 'package:pateeznews_admin/features/whatsapp/presentation/whatsapp_contact_lists_screen.dart';
import 'package:pateeznews_admin/features/whatsapp/presentation/whatsapp_messaging_screen.dart';
import 'package:pateeznews_admin/features/whatsapp/presentation/whatsapp_settings_screen.dart';
import 'package:pateeznews_admin/features/whatsapp/presentation/whatsapp_templates_screen.dart';
import 'package:pateeznews_admin/features/navigation/data/admin_navigation_repository.dart';
import 'package:pateeznews_admin/features/navigation/presentation/navigation_screen.dart';
import 'package:pateeznews_admin/features/news/data/admin_news_repository.dart';
import 'package:pateeznews_admin/features/news/presentation/news_screen.dart';
import 'package:pateeznews_admin/features/settings/presentation/ai_settings_screen.dart';
import 'package:pateeznews_admin/features/settings/presentation/death_notice_settings_screen.dart';
import 'package:pateeznews_admin/features/settings/presentation/general_settings_screen.dart';
import 'package:pateeznews_admin/features/settings/presentation/language_settings_screen.dart';
import 'package:pateeznews_admin/features/settings/presentation/pharmacy_settings_screen.dart';
import 'package:pateeznews_admin/features/settings/presentation/weather_settings_screen.dart';
import 'package:pateeznews_admin/features/social/presentation/social_publish_screen.dart';
import 'package:pateeznews_admin/features/auth/data/admin_auth_models.dart';
import 'package:pateeznews_admin/features/settings/data/admin_ai_settings_repository.dart';
import 'package:pateeznews_admin/features/settings/data/admin_general_settings_repository.dart';
import 'package:pateeznews_admin/features/settings/data/admin_languages_repository.dart';
import 'package:pateeznews_admin/features/settings/data/admin_module_settings_repository.dart';
import 'package:pateeznews_admin/features/users/data/admin_roles_repository.dart';
import 'package:pateeznews_admin/features/users/data/admin_users_repository.dart';
import 'package:pateeznews_admin/features/users/presentation/roles_permissions_screen.dart';
import 'package:pateeznews_admin/features/users/presentation/users_screen.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/localization/admin_language_controller.dart';
import 'widgets/dashboard_content.dart';
import 'widgets/sidebar.dart';
import 'widgets/top_bar.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.session,
    required this.profile,
    required this.onLogout,
    this.newsRepository = const NeonAdminNewsRepository(),
    this.commentsRepository = const NeonAdminCommentsRepository(),
    this.navigationRepository = const NeonAdminNavigationRepository(),
    this.usersRepository = const NeonAdminUsersRepository(),
    this.rolesRepository = const NeonAdminRolesRepository(),
    this.languagesRepository = const NeonAdminLanguagesRepository(),
    this.generalSettingsRepository = const NeonAdminGeneralSettingsRepository(),
    this.aiSettingsRepository = const NeonAdminAiSettingsRepository(),
    this.moduleSettingsRepository = const NeonAdminModuleSettingsRepository(),
    this.accountSettingsRepository = const NeonAdminAccountSettingsRepository(),
  });

  final AdminSession session;
  final AdminProfile? profile;
  final VoidCallback onLogout;
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
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  var _selectedPage = _DashboardPage.home;
  var _permissionLoading = true;
  String? _permissionError;
  Set<String> _permissionKeys = const {};

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  @override
  void didUpdateWidget(covariant DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_roleName != _roleNameFor(oldWidget.profile, oldWidget.session)) {
      _loadPermissions();
    }
  }

  String get _roleName => _roleNameFor(widget.profile, widget.session);

  String _roleNameFor(AdminProfile? profile, AdminSession session) {
    final profileRole = profile?.role?.trim();
    if (profileRole != null && profileRole.isNotEmpty) return profileRole;
    final metadataRole = session.user.userMetadata['role']?.toString().trim();
    if (metadataRole != null && metadataRole.isNotEmpty) return metadataRole;
    return 'member';
  }

  bool get _adminRole => _roleName == 'admin' || _roleName == 'super_admin';

  Future<void> _loadPermissions() async {
    if (_adminRole) {
      if (!mounted) return;
      setState(() {
        _permissionKeys = {'*'};
        _permissionError = null;
        _permissionLoading = false;
      });
      return;
    }

    setState(() {
      _permissionLoading = true;
      _permissionError = null;
    });

    try {
      final keys = await widget.rolesRepository.fetchPermissionKeysForRole(
        _roleName,
      );
      if (!mounted) return;
      setState(() {
        _permissionKeys = keys;
        _permissionLoading = false;
      });
      _ensureSelectedPageAllowed();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _permissionKeys = const {};
        _permissionError = error.toString();
        _permissionLoading = false;
      });
      _ensureSelectedPageAllowed();
    }
  }

  bool _hasAny(Iterable<String> keys) {
    if (_adminRole || _permissionKeys.contains('*')) return true;
    return keys.any(_permissionKeys.contains);
  }

  bool _canOpen(_DashboardPage page) {
    return switch (page) {
      _DashboardPage.home => _hasAny(['view_overview', 'dashboard_access']),
      _DashboardPage.news => _hasAny([
        'manage_content',
        'posts_access',
        'news_access',
      ]),
      _DashboardPage.comments => _hasAny(['comments_manage']),
      _DashboardPage.mailInbox ||
      _DashboardPage.bulkMail ||
      _DashboardPage.mailTemplates ||
      _DashboardPage.contactLists ||
      _DashboardPage.mailSettings => _hasAny([
        'manage_content',
        'mail_access',
        'posts_access',
        'news_access',
      ]),
      _DashboardPage.navigation => _hasAny([
        'manage_content',
        'posts_access',
        'news_access',
      ]),
      _DashboardPage.whatsappMessaging ||
      _DashboardPage.whatsappBulk ||
      _DashboardPage.whatsappTemplates ||
      _DashboardPage.whatsappContacts ||
      _DashboardPage.whatsappSettings ||
      _DashboardPage.socialPublish => _hasAny([
        'manage_content',
        'posts_access',
        'news_access',
      ]),
      _DashboardPage.users => _hasAny(['manage_users', 'users_access']),
      _DashboardPage.accountSettings => true,
      _DashboardPage.rolesPermissions => _hasAny([
        'view_roles',
        'roles_access',
      ]),
      _DashboardPage.aiSettings ||
      _DashboardPage.pharmacySettings ||
      _DashboardPage.weatherSettings ||
      _DashboardPage.deathNoticeSettings ||
      _DashboardPage.generalSettings => _hasAny([
        'view_settings',
        'settings_access',
      ]),
      _DashboardPage.languageSettings => _hasAny([
        'view_languages',
        'view_settings',
        'settings_access',
      ]),
    };
  }

  void _ensureSelectedPageAllowed() {
    if (_canOpen(_selectedPage)) return;
    for (final page in _DashboardPage.values) {
      if (_canOpen(page)) {
        setState(() => _selectedPage = page);
        return;
      }
    }
  }

  void _openPage(_DashboardPage page) {
    if (!_canOpen(page)) return;
    setState(() => _selectedPage = page);
  }

  void _openHome() {
    _openPage(_DashboardPage.home);
  }

  void _openNews() {
    _openPage(_DashboardPage.news);
  }

  void _openUsers() {
    _openPage(_DashboardPage.users);
  }

  void _openAccountSettings() {
    _openPage(_DashboardPage.accountSettings);
  }

  void _openComments() {
    _openPage(_DashboardPage.comments);
  }

  void _openMailInbox() {
    _openPage(_DashboardPage.mailInbox);
  }

  void _openBulkMail() {
    _openPage(_DashboardPage.bulkMail);
  }

  void _openMailTemplates() {
    _openPage(_DashboardPage.mailTemplates);
  }

  void _openContactLists() {
    _openPage(_DashboardPage.contactLists);
  }

  void _openMailSettings() {
    _openPage(_DashboardPage.mailSettings);
  }

  void _openNavigation() {
    _openPage(_DashboardPage.navigation);
  }

  void _openWhatsappMessaging() {
    _openPage(_DashboardPage.whatsappMessaging);
  }

  void _openWhatsappBulk() {
    _openPage(_DashboardPage.whatsappBulk);
  }

  void _openWhatsappTemplates() {
    _openPage(_DashboardPage.whatsappTemplates);
  }

  void _openWhatsappContacts() {
    _openPage(_DashboardPage.whatsappContacts);
  }

  void _openWhatsappSettings() {
    _openPage(_DashboardPage.whatsappSettings);
  }

  void _openSocialPublish() {
    _openPage(_DashboardPage.socialPublish);
  }

  void _openLanguageSettings() {
    _openPage(_DashboardPage.languageSettings);
  }

  void _openGeneralSettings() {
    _openPage(_DashboardPage.generalSettings);
  }

  void _openAiSettings() {
    _openPage(_DashboardPage.aiSettings);
  }

  void _openPharmacySettings() {
    _openPage(_DashboardPage.pharmacySettings);
  }

  void _openWeatherSettings() {
    _openPage(_DashboardPage.weatherSettings);
  }

  void _openDeathNoticeSettings() {
    _openPage(_DashboardPage.deathNoticeSettings);
  }

  void _openRolesPermissions() {
    _openPage(_DashboardPage.rolesPermissions);
  }

  @override
  Widget build(BuildContext context) {
    final aiSettingsSelected = _selectedPage == _DashboardPage.aiSettings;
    final pharmacySettingsSelected =
        _selectedPage == _DashboardPage.pharmacySettings;
    final weatherSettingsSelected =
        _selectedPage == _DashboardPage.weatherSettings;
    final deathNoticeSettingsSelected =
        _selectedPage == _DashboardPage.deathNoticeSettings;
    final newsSelected = _selectedPage == _DashboardPage.news;
    final commentsSelected = _selectedPage == _DashboardPage.comments;
    final mailInboxSelected = _selectedPage == _DashboardPage.mailInbox;
    final bulkMailSelected = _selectedPage == _DashboardPage.bulkMail;
    final mailTemplatesSelected = _selectedPage == _DashboardPage.mailTemplates;
    final contactListsSelected = _selectedPage == _DashboardPage.contactLists;
    final mailSettingsSelected = _selectedPage == _DashboardPage.mailSettings;
    final whatsappMessagingSelected =
        _selectedPage == _DashboardPage.whatsappMessaging;
    final whatsappBulkSelected = _selectedPage == _DashboardPage.whatsappBulk;
    final whatsappTemplatesSelected =
        _selectedPage == _DashboardPage.whatsappTemplates;
    final whatsappContactsSelected =
        _selectedPage == _DashboardPage.whatsappContacts;
    final whatsappSettingsSelected =
        _selectedPage == _DashboardPage.whatsappSettings;
    final socialPublishSelected = _selectedPage == _DashboardPage.socialPublish;
    final navigationSelected = _selectedPage == _DashboardPage.navigation;
    final accountSettingsSelected =
        _selectedPage == _DashboardPage.accountSettings;
    final usersSelected =
        _selectedPage == _DashboardPage.users || accountSettingsSelected;
    final rolesPermissionsSelected =
        _selectedPage == _DashboardPage.rolesPermissions;
    final languageSettingsSelected =
        _selectedPage == _DashboardPage.languageSettings;
    final generalSettingsSelected =
        _selectedPage == _DashboardPage.generalSettings;
    final settingsSelected =
        languageSettingsSelected || generalSettingsSelected;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 900;
        final homeVisible = _canOpen(_DashboardPage.home);
        final newsVisible = _canOpen(_DashboardPage.news);
        final commentsVisible = _canOpen(_DashboardPage.comments);
        final mailInboxVisible = _canOpen(_DashboardPage.mailInbox);
        final bulkMailVisible = _canOpen(_DashboardPage.bulkMail);
        final mailTemplatesVisible = _canOpen(_DashboardPage.mailTemplates);
        final contactListsVisible = _canOpen(_DashboardPage.contactLists);
        final mailSettingsVisible = _canOpen(_DashboardPage.mailSettings);
        final whatsappVisible =
            _canOpen(_DashboardPage.whatsappMessaging) ||
            _canOpen(_DashboardPage.whatsappBulk) ||
            _canOpen(_DashboardPage.whatsappTemplates) ||
            _canOpen(_DashboardPage.whatsappContacts) ||
            _canOpen(_DashboardPage.whatsappSettings);
        final socialMediaVisible = _canOpen(_DashboardPage.socialPublish);
        final navigationVisible = _canOpen(_DashboardPage.navigation);
        final usersVisible = _canOpen(_DashboardPage.users);
        final rolesPermissionsVisible = _canOpen(
          _DashboardPage.rolesPermissions,
        );
        final aiSettingsVisible = _canOpen(_DashboardPage.aiSettings);
        final pharmacySettingsVisible = _canOpen(
          _DashboardPage.pharmacySettings,
        );
        final weatherSettingsVisible = _canOpen(_DashboardPage.weatherSettings);
        final deathNoticeSettingsVisible = _canOpen(
          _DashboardPage.deathNoticeSettings,
        );
        final generalSettingsVisible = _canOpen(_DashboardPage.generalSettings);
        final languageSettingsVisible = _canOpen(
          _DashboardPage.languageSettings,
        );

        return Scaffold(
          drawer: isCompact
              ? AdminDrawer(
                  onLogout: widget.onLogout,
                  homeVisible: homeVisible,
                  newsVisible: newsVisible,
                  commentsVisible: commentsVisible,
                  mailInboxVisible: mailInboxVisible,
                  bulkMailVisible: bulkMailVisible,
                  mailTemplatesVisible: mailTemplatesVisible,
                  contactListsVisible: contactListsVisible,
                  mailSettingsVisible: mailSettingsVisible,
                  whatsappVisible: whatsappVisible,
                  socialMediaVisible: socialMediaVisible,
                  navigationVisible: navigationVisible,
                  usersVisible: usersVisible,
                  rolesPermissionsVisible: rolesPermissionsVisible,
                  aiSettingsVisible: aiSettingsVisible,
                  pharmacySettingsVisible: pharmacySettingsVisible,
                  weatherSettingsVisible: weatherSettingsVisible,
                  deathNoticeSettingsVisible: deathNoticeSettingsVisible,
                  generalSettingsVisible: generalSettingsVisible,
                  languageSettingsVisible: languageSettingsVisible,
                  homeSelected:
                      !settingsSelected &&
                      !newsSelected &&
                      !commentsSelected &&
                      !mailInboxSelected &&
                      !bulkMailSelected &&
                      !mailTemplatesSelected &&
                      !contactListsSelected &&
                      !mailSettingsSelected &&
                      !whatsappMessagingSelected &&
                      !whatsappBulkSelected &&
                      !whatsappTemplatesSelected &&
                      !whatsappContactsSelected &&
                      !whatsappSettingsSelected &&
                      !socialPublishSelected &&
                      !navigationSelected &&
                      !usersSelected &&
                      !rolesPermissionsSelected &&
                      !aiSettingsSelected &&
                      !pharmacySettingsSelected &&
                      !weatherSettingsSelected &&
                      !deathNoticeSettingsSelected,
                  newsSelected: newsSelected,
                  commentsSelected: commentsSelected,
                  mailInboxSelected: mailInboxSelected,
                  bulkMailSelected: bulkMailSelected,
                  mailTemplatesSelected: mailTemplatesSelected,
                  contactListsSelected: contactListsSelected,
                  mailSettingsSelected: mailSettingsSelected,
                  whatsappMessagingSelected: whatsappMessagingSelected,
                  whatsappBulkSelected: whatsappBulkSelected,
                  whatsappTemplatesSelected: whatsappTemplatesSelected,
                  whatsappContactsSelected: whatsappContactsSelected,
                  whatsappSettingsSelected: whatsappSettingsSelected,
                  socialPublishSelected: socialPublishSelected,
                  navigationSelected: navigationSelected,
                  usersSelected: usersSelected,
                  rolesPermissionsSelected: rolesPermissionsSelected,
                  aiSettingsSelected: aiSettingsSelected,
                  pharmacySettingsSelected: pharmacySettingsSelected,
                  weatherSettingsSelected: weatherSettingsSelected,
                  deathNoticeSettingsSelected: deathNoticeSettingsSelected,
                  generalSettingsSelected: generalSettingsSelected,
                  languageSettingsSelected: languageSettingsSelected,
                  onHomeSelected: _openHome,
                  onNewsSelected: _openNews,
                  onCommentsSelected: _openComments,
                  onMailInboxSelected: _openMailInbox,
                  onBulkMailSelected: _openBulkMail,
                  onMailTemplatesSelected: _openMailTemplates,
                  onContactListsSelected: _openContactLists,
                  onMailSettingsSelected: _openMailSettings,
                  onWhatsappMessagingSelected: _openWhatsappMessaging,
                  onWhatsappBulkSelected: _openWhatsappBulk,
                  onWhatsappTemplatesSelected: _openWhatsappTemplates,
                  onWhatsappContactsSelected: _openWhatsappContacts,
                  onWhatsappSettingsSelected: _openWhatsappSettings,
                  onSocialPublishSelected: _openSocialPublish,
                  onNavigationSelected: _openNavigation,
                  onUsersSelected: _openUsers,
                  onRolesPermissionsSelected: _openRolesPermissions,
                  onAiSettingsSelected: _openAiSettings,
                  onPharmacySettingsSelected: _openPharmacySettings,
                  onWeatherSettingsSelected: _openWeatherSettings,
                  onDeathNoticeSettingsSelected: _openDeathNoticeSettings,
                  onGeneralSettingsSelected: _openGeneralSettings,
                  onLanguageSettingsSelected: _openLanguageSettings,
                )
              : null,
          body: SafeArea(
            child: Row(
              children: [
                if (!isCompact)
                  Sidebar(
                    onLogout: widget.onLogout,
                    homeVisible: homeVisible,
                    newsVisible: newsVisible,
                    commentsVisible: commentsVisible,
                    mailInboxVisible: mailInboxVisible,
                    bulkMailVisible: bulkMailVisible,
                    mailTemplatesVisible: mailTemplatesVisible,
                    contactListsVisible: contactListsVisible,
                    mailSettingsVisible: mailSettingsVisible,
                    whatsappVisible: whatsappVisible,
                    socialMediaVisible: socialMediaVisible,
                    navigationVisible: navigationVisible,
                    usersVisible: usersVisible,
                    rolesPermissionsVisible: rolesPermissionsVisible,
                    aiSettingsVisible: aiSettingsVisible,
                    pharmacySettingsVisible: pharmacySettingsVisible,
                    weatherSettingsVisible: weatherSettingsVisible,
                    deathNoticeSettingsVisible: deathNoticeSettingsVisible,
                    generalSettingsVisible: generalSettingsVisible,
                    languageSettingsVisible: languageSettingsVisible,
                    homeSelected:
                        !settingsSelected &&
                        !newsSelected &&
                        !commentsSelected &&
                        !mailInboxSelected &&
                        !bulkMailSelected &&
                        !mailTemplatesSelected &&
                        !contactListsSelected &&
                        !mailSettingsSelected &&
                        !whatsappMessagingSelected &&
                        !whatsappBulkSelected &&
                        !whatsappTemplatesSelected &&
                        !whatsappContactsSelected &&
                        !whatsappSettingsSelected &&
                        !socialPublishSelected &&
                        !navigationSelected &&
                        !usersSelected &&
                        !rolesPermissionsSelected &&
                        !aiSettingsSelected &&
                        !pharmacySettingsSelected &&
                        !weatherSettingsSelected &&
                        !deathNoticeSettingsSelected,
                    newsSelected: newsSelected,
                    commentsSelected: commentsSelected,
                    mailInboxSelected: mailInboxSelected,
                    bulkMailSelected: bulkMailSelected,
                    mailTemplatesSelected: mailTemplatesSelected,
                    contactListsSelected: contactListsSelected,
                    mailSettingsSelected: mailSettingsSelected,
                    whatsappMessagingSelected: whatsappMessagingSelected,
                    whatsappBulkSelected: whatsappBulkSelected,
                    whatsappTemplatesSelected: whatsappTemplatesSelected,
                    whatsappContactsSelected: whatsappContactsSelected,
                    whatsappSettingsSelected: whatsappSettingsSelected,
                    socialPublishSelected: socialPublishSelected,
                    navigationSelected: navigationSelected,
                    usersSelected: usersSelected,
                    rolesPermissionsSelected: rolesPermissionsSelected,
                    aiSettingsSelected: aiSettingsSelected,
                    pharmacySettingsSelected: pharmacySettingsSelected,
                    weatherSettingsSelected: weatherSettingsSelected,
                    deathNoticeSettingsSelected: deathNoticeSettingsSelected,
                    generalSettingsSelected: generalSettingsSelected,
                    languageSettingsSelected: languageSettingsSelected,
                    onHomeSelected: _openHome,
                    onNewsSelected: _openNews,
                    onCommentsSelected: _openComments,
                    onMailInboxSelected: _openMailInbox,
                    onBulkMailSelected: _openBulkMail,
                    onMailTemplatesSelected: _openMailTemplates,
                    onContactListsSelected: _openContactLists,
                    onMailSettingsSelected: _openMailSettings,
                    onWhatsappMessagingSelected: _openWhatsappMessaging,
                    onWhatsappBulkSelected: _openWhatsappBulk,
                    onWhatsappTemplatesSelected: _openWhatsappTemplates,
                    onWhatsappContactsSelected: _openWhatsappContacts,
                    onWhatsappSettingsSelected: _openWhatsappSettings,
                    onSocialPublishSelected: _openSocialPublish,
                    onNavigationSelected: _openNavigation,
                    onUsersSelected: _openUsers,
                    onRolesPermissionsSelected: _openRolesPermissions,
                    onAiSettingsSelected: _openAiSettings,
                    onPharmacySettingsSelected: _openPharmacySettings,
                    onWeatherSettingsSelected: _openWeatherSettings,
                    onDeathNoticeSettingsSelected: _openDeathNoticeSettings,
                    onGeneralSettingsSelected: _openGeneralSettings,
                    onLanguageSettingsSelected: _openLanguageSettings,
                  ),
                Expanded(
                  child: Column(
                    children: [
                      TopBar(
                        compact: isCompact,
                        session: widget.session,
                        profile: widget.profile,
                        onLogout: widget.onLogout,
                        onAccountSettings: _openAccountSettings,
                      ),
                      Expanded(
                        child: _permissionLoading
                            ? const _DashboardPermissionLoading()
                            : !_canOpen(_selectedPage)
                            ? _DashboardAccessDenied(error: _permissionError)
                            : switch (_selectedPage) {
                                _DashboardPage.home => const DashboardContent(),
                                _DashboardPage.news => NewsScreen(
                                  repository: widget.newsRepository,
                                ),
                                _DashboardPage.comments => CommentsScreen(
                                  session: widget.session,
                                  repository: widget.commentsRepository,
                                ),
                                _DashboardPage.mailInbox =>
                                  const MailInboxScreen(),
                                _DashboardPage.bulkMail =>
                                  const BulkMailScreen(),
                                _DashboardPage.mailTemplates =>
                                  const MailTemplatesScreen(),
                                _DashboardPage.contactLists =>
                                  const ContactListsScreen(),
                                _DashboardPage.mailSettings =>
                                  const MailSettingsScreen(),
                                _DashboardPage.whatsappMessaging =>
                                  const WhatsappMessagingScreen(),
                                _DashboardPage.whatsappBulk =>
                                  const WhatsappBulkScreen(),
                                _DashboardPage.whatsappTemplates =>
                                  const WhatsappTemplatesScreen(),
                                _DashboardPage.whatsappContacts =>
                                  const WhatsappContactListsScreen(),
                                _DashboardPage.whatsappSettings =>
                                  const WhatsappSettingsScreen(),
                                _DashboardPage.socialPublish =>
                                  SocialPublishScreen(
                                    newsRepository: widget.newsRepository,
                                  ),
                                _DashboardPage.navigation => NavigationScreen(
                                  repository: widget.navigationRepository,
                                ),
                                _DashboardPage.users => UsersScreen(
                                  session: widget.session,
                                  repository: widget.usersRepository,
                                ),
                                _DashboardPage.accountSettings =>
                                  AccountSettingsScreen(
                                    session: widget.session,
                                    repository:
                                        widget.accountSettingsRepository,
                                    onAccountDeleted: widget.onLogout,
                                  ),
                                _DashboardPage.rolesPermissions =>
                                  RolesPermissionsScreen(
                                    session: widget.session,
                                    repository: widget.rolesRepository,
                                  ),
                                _DashboardPage.aiSettings => AiSettingsScreen(
                                  session: widget.session,
                                  repository: widget.aiSettingsRepository,
                                ),
                                _DashboardPage.pharmacySettings =>
                                  PharmacySettingsScreen(
                                    repository: widget.moduleSettingsRepository,
                                  ),
                                _DashboardPage.weatherSettings =>
                                  WeatherSettingsScreen(
                                    session: widget.session,
                                    repository: widget.moduleSettingsRepository,
                                  ),
                                _DashboardPage.deathNoticeSettings =>
                                  DeathNoticeSettingsScreen(
                                    repository: widget.moduleSettingsRepository,
                                  ),
                                _DashboardPage.generalSettings =>
                                  GeneralSettingsScreen(
                                    session: widget.session,
                                    repository:
                                        widget.generalSettingsRepository,
                                  ),
                                _DashboardPage.languageSettings =>
                                  LanguageSettingsScreen(
                                    session: widget.session,
                                    repository: widget.languagesRepository,
                                  ),
                              },
                      ),
                    ],
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

class _DashboardPermissionLoading extends StatelessWidget {
  const _DashboardPermissionLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.deepOcean,
        ),
      ),
    );
  }
}

// _WhatsappScreen has been replaced by WhatsappMessagingScreen

class _DashboardAccessDenied extends StatelessWidget {
  const _DashboardAccessDenied({this.error});

  final String? error;

  @override
  Widget build(BuildContext context) {
    final message = error == null
        ? context.t('dashboard.accessDenied')
        : context.t('dashboard.permissionError');

    return Center(
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: AppColors.deepOcean,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

enum _DashboardPage {
  home,
  news,
  comments,
  mailInbox,
  bulkMail,
  mailTemplates,
  contactLists,
  mailSettings,
  whatsappMessaging,
  whatsappBulk,
  whatsappTemplates,
  whatsappContacts,
  whatsappSettings,
  socialPublish,
  navigation,
  users,
  accountSettings,
  rolesPermissions,
  aiSettings,
  pharmacySettings,
  weatherSettings,
  deathNoticeSettings,
  generalSettings,
  languageSettings,
}
