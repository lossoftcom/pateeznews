import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pateeznews_admin/features/account/data/admin_account_settings_repository.dart';
import 'package:pateeznews_admin/features/account/presentation/account_settings_screen.dart';
import 'package:pateeznews_admin/features/comments/data/admin_comments_repository.dart';
import 'package:pateeznews_admin/features/comments/presentation/comments_screen.dart';
import 'package:pateeznews_admin/features/mail/presentation/bulk_mail_screen.dart';
import 'package:pateeznews_admin/features/mail/presentation/contact_lists_screen.dart';
import 'package:pateeznews_admin/features/mail/data/admin_mail_repository.dart';
import 'package:pateeznews_admin/features/mail/presentation/mail_inbox_screen.dart';
import 'package:pateeznews_admin/features/mail/presentation/mail_settings_screen.dart';
import 'package:pateeznews_admin/features/mail/presentation/mail_templates_screen.dart';
import 'package:pateeznews_admin/features/sms/presentation/sms_bulk_screen.dart';
import 'package:pateeznews_admin/features/sms/presentation/sms_contact_lists_screen.dart';
import 'package:pateeznews_admin/features/sms/presentation/sms_outbox_screen.dart';
import 'package:pateeznews_admin/features/sms/presentation/sms_settings_screen.dart';
import 'package:pateeznews_admin/features/sms/presentation/sms_templates_screen.dart';
import 'package:pateeznews_admin/features/whatsapp/presentation/whatsapp_bulk_screen.dart';
import 'package:pateeznews_admin/features/whatsapp/data/admin_whatsapp_repository.dart';
import 'package:pateeznews_admin/features/whatsapp/presentation/whatsapp_contact_lists_screen.dart';
import 'package:pateeznews_admin/features/whatsapp/presentation/whatsapp_messaging_screen.dart';
import 'package:pateeznews_admin/features/whatsapp/presentation/whatsapp_settings_screen.dart';
import 'package:pateeznews_admin/features/whatsapp/presentation/whatsapp_templates_screen.dart';
import 'package:pateeznews_admin/features/navigation/data/admin_navigation_repository.dart';
import 'package:pateeznews_admin/features/navigation/presentation/navigation_screen.dart';
import 'package:pateeznews_admin/features/news/data/admin_news_repository.dart';
import 'package:pateeznews_admin/features/news/presentation/news_add_screen.dart';
import 'package:pateeznews_admin/features/news/presentation/news_screen.dart';
import 'package:pateeznews_admin/features/notifications/data/admin_notifications_repository.dart';
import 'package:pateeznews_admin/features/notifications/presentation/notifications_screen.dart';
import 'package:pateeznews_admin/features/pages/data/admin_pages_repository.dart';
import 'package:pateeznews_admin/features/pages/presentation/pages_screen.dart';
import 'package:pateeznews_admin/features/settings/presentation/ai_settings_screen.dart';
import 'package:pateeznews_admin/features/settings/presentation/announcements_settings_screen.dart';
import 'package:pateeznews_admin/features/settings/presentation/content_settings_screen.dart';
import 'package:pateeznews_admin/features/settings/data/admin_content_settings_repository.dart';
import 'package:pateeznews_admin/features/settings/presentation/death_notice_settings_screen.dart';
import 'package:pateeznews_admin/features/settings/presentation/font_settings_screen.dart';
import 'package:pateeznews_admin/features/settings/presentation/general_settings_screen.dart';
import 'package:pateeznews_admin/features/settings/presentation/google_news_settings_screen.dart';
import 'package:pateeznews_admin/features/settings/presentation/language_settings_screen.dart';
import 'package:pateeznews_admin/features/settings/presentation/market_settings_screen.dart';
import 'package:pateeznews_admin/features/settings/presentation/pharmacy_settings_screen.dart';
import 'package:pateeznews_admin/features/settings/presentation/prayer_settings_screen.dart';
import 'package:pateeznews_admin/features/settings/presentation/security_settings_screen.dart';
import 'package:pateeznews_admin/features/settings/presentation/storage_settings_screen.dart';
import 'package:pateeznews_admin/features/settings/presentation/weather_settings_screen.dart';
import 'package:pateeznews_admin/features/sms/data/admin_sms_repository.dart';
import 'package:pateeznews_admin/features/social/data/admin_social_repository.dart';
import 'package:pateeznews_admin/features/social/presentation/social_accounts_screen.dart';
import 'package:pateeznews_admin/features/social/presentation/social_publish_screen.dart';
import 'package:pateeznews_admin/features/social/presentation/social_settings_screen.dart';
import 'package:pateeznews_admin/shared/data/media_service.dart';
import 'package:pateeznews_admin/features/subscribers/data/admin_subscribers_repository.dart';
import 'package:pateeznews_admin/features/subscribers/presentation/subscribers_screen.dart';
import 'package:pateeznews_admin/features/stories/data/admin_stories_repository.dart';
import 'package:pateeznews_admin/features/stories/presentation/stories_screen.dart';
import 'package:pateeznews_admin/features/auth/data/admin_auth_models.dart';
import 'package:pateeznews_admin/features/settings/data/admin_ai_settings_repository.dart';
import 'package:pateeznews_admin/features/settings/data/admin_font_settings_repository.dart';
import 'package:pateeznews_admin/features/settings/data/admin_general_settings_repository.dart';
import 'package:pateeznews_admin/features/settings/data/admin_languages_repository.dart';
import 'package:pateeznews_admin/features/settings/data/admin_module_settings_repository.dart';
import 'package:pateeznews_admin/features/settings/data/admin_security_settings_repository.dart';
import 'package:pateeznews_admin/features/settings/data/admin_storage_settings_repository.dart';
import 'package:pateeznews_admin/features/users/data/admin_roles_repository.dart';
import 'package:pateeznews_admin/features/users/data/admin_users_repository.dart';
import 'package:pateeznews_admin/features/users/presentation/roles_permissions_screen.dart';
import 'package:pateeznews_admin/features/users/presentation/users_screen.dart';
import 'package:pateeznews_admin/features/ads/presentation/ads_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    this.newsRepository = const SupabaseAdminNewsRepository(),
    this.storiesRepository = const SupabaseAdminStoriesRepository(),
    this.pagesRepository = const SupabaseAdminPagesRepository(),
    this.commentsRepository = const SupabaseAdminCommentsRepository(),
    this.navigationRepository = const SupabaseAdminNavigationRepository(),
    this.usersRepository = const SupabaseAdminUsersRepository(),
    this.rolesRepository = const SupabaseAdminRolesRepository(),
    this.languagesRepository = const SupabaseAdminLanguagesRepository(),
    this.generalSettingsRepository =
        const SupabaseAdminGeneralSettingsRepository(),
    this.fontSettingsRepository = const SupabaseAdminFontSettingsRepository(),
    this.aiSettingsRepository = const SupabaseAdminAiSettingsRepository(),
    this.contentSettingsRepository =
        const SupabaseAdminContentSettingsRepository(),
    this.moduleSettingsRepository =
        const SupabaseAdminModuleSettingsRepository(),
    this.securitySettingsRepository =
        const SupabaseAdminSecuritySettingsRepository(),
    this.storageSettingsRepository =
        const SupabaseAdminStorageSettingsRepository(),
    this.accountSettingsRepository =
        const SupabaseAdminAccountSettingsRepository(),
    this.subscribersRepository = const SupabaseAdminSubscribersRepository(),
    this.notificationsRepository = const SupabaseAdminNotificationsRepository(),
    this.mailRepository = const SupabaseAdminMailRepository(),
    this.smsRepository = const SupabaseAdminSmsRepository(),
    this.whatsappRepository = const SupabaseAdminWhatsappRepository(),
    this.socialRepository = const SupabaseAdminSocialRepository(),
    this.initialContentSettings,
    this.onOpenFrontend,
  });

  final AdminSession session;
  final AdminProfile? profile;
  final VoidCallback onLogout;
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
  final AdminMailRepository mailRepository;
  final AdminSmsRepository smsRepository;
  final AdminWhatsappRepository whatsappRepository;
  final AdminSocialRepository socialRepository;
  final ContentSettingsSnapshot? initialContentSettings;
  final VoidCallback? onOpenFrontend;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  var _selectedPage = _DashboardPage.home;
  var _permissionLoading = true;
  String? _permissionError;
  Set<String> _permissionKeys = const {};
  String? _editingNewsPostId;
  ContentSettingsSnapshot? _contentSettingsSnapshot;
  SharedPreferences? _preferences;

  String get _selectedPageStorageKey =>
      'admin_dashboard_selected_page_${widget.session.user.id}';

  @override
  void initState() {
    super.initState();
    _contentSettingsSnapshot = widget.initialContentSettings;
    final initialUpload = _contentSettingsSnapshot?.upload;
    if (initialUpload != null) _cacheUploadSettings(initialUpload);
    unawaited(_restoreSelectedPageThenLoadPermissions());
  }

  @override
  void didUpdateWidget(covariant DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_roleName != _roleNameFor(oldWidget.profile, oldWidget.session)) {
      unawaited(_loadPermissions());
    }
    if (oldWidget.initialContentSettings != widget.initialContentSettings &&
        widget.initialContentSettings != null) {
      _contentSettingsSnapshot = widget.initialContentSettings;
      _cacheUploadSettings(widget.initialContentSettings!.upload);
    }
  }

  Future<void> _restoreSelectedPageThenLoadPermissions() async {
    await _restoreSelectedPage();
    if (!mounted) return;
    await _loadPermissions();
  }

  Future<void> _restoreSelectedPage() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      _preferences = preferences;
      final restoredPage = _dashboardPageFromName(
        preferences.getString(_selectedPageStorageKey),
      );
      if (!mounted || restoredPage == null) return;
      setState(() {
        _selectedPage = restoredPage;
      });
    } catch (_) {
      // Yerel sayfa tercihi okunamazsa mevcut varsayılan dashboard davranışı kalır.
    }
  }

  ContentSettingsSnapshot _snapshotFor(String languageCode) {
    final current = _contentSettingsSnapshot;
    if (current != null && current.languageCode == languageCode) {
      return current;
    }
    return ContentSettingsSnapshot.defaults(languageCode);
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

  void _updateContentGeneralSettings(ContentGeneralSettingsData settings) {
    final next = _snapshotFor(
      settings.languageCode,
    ).copyWith(general: settings);
    setState(() => _contentSettingsSnapshot = next);
  }

  void _updateContentPostSettings(ContentPostSettingsData settings) {
    final next = _snapshotFor(settings.languageCode).copyWith(posts: settings);
    setState(() => _contentSettingsSnapshot = next);
  }

  void _updateContentPostFormatSettings(
    ContentPostFormatSettingsData settings,
  ) {
    final next = _snapshotFor(
      settings.languageCode,
    ).copyWith(postFormats: settings);
    setState(() => _contentSettingsSnapshot = next);
  }

  void _updateContentUploadSettings(ContentUploadSettingsData settings) {
    _cacheUploadSettings(settings);
    final next = _snapshotFor(settings.languageCode).copyWith(upload: settings);
    setState(() => _contentSettingsSnapshot = next);
  }

  void _updateContentFeaturedSettings(ContentFeaturedSettingsData settings) {
    final next = _snapshotFor(
      settings.languageCode,
    ).copyWith(featured: settings);
    setState(() => _contentSettingsSnapshot = next);
  }

  void _updateContentTrashCleanupSettings(
    ContentTrashCleanupSettingsData settings,
  ) {
    final next = _snapshotFor(
      settings.languageCode,
    ).copyWith(trashCleanup: settings);
    setState(() => _contentSettingsSnapshot = next);
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
      _DashboardPage.home => _hasAny(['dashboard_access', 'view_overview']),
      _DashboardPage.newsAdd || _DashboardPage.news => _hasAny([
        'posts_access',
        'manage_content',
        'news_access',
      ]),
      _DashboardPage.stories => _hasAny(['stories_access', 'manage_stories']),
      _DashboardPage.pages => _hasAny(['pages_access', 'manage_pages']),
      _DashboardPage.comments => _hasAny(['comments_manage']),
      _DashboardPage.subscribers => _hasAny([
        'subscribers_access',
        'manage_subscribers',
      ]),
      _DashboardPage.notificationCampaigns ||
      _DashboardPage.notificationTemplates ||
      _DashboardPage.notificationDevices ||
      _DashboardPage.notificationSettings => _hasAny([
        'notifications_access',
        'manage_notifications',
      ]),
      _DashboardPage.mailInbox ||
      _DashboardPage.bulkMail ||
      _DashboardPage.mailTemplates ||
      _DashboardPage.contactLists ||
      _DashboardPage.mailSettings => _hasAny(['mail_access', 'manage_mail']),
      _DashboardPage.navigation => _hasAny([
        'navigation_access',
        'manage_navigation',
      ]),
      _DashboardPage.smsBulk ||
      _DashboardPage.smsOutbox ||
      _DashboardPage.smsTemplates ||
      _DashboardPage.smsContacts ||
      _DashboardPage.smsSettings => _hasAny(['sms_access', 'manage_sms']),
      _DashboardPage.whatsappMessaging ||
      _DashboardPage.whatsappBulk ||
      _DashboardPage.whatsappTemplates ||
      _DashboardPage.whatsappContacts ||
      _DashboardPage.whatsappSettings => _hasAny([
        'whatsapp_access',
        'manage_whatsapp',
      ]),
      _DashboardPage.socialPublish ||
      _DashboardPage.socialAccounts ||
      _DashboardPage.socialSettings => _hasAny([
        'social_access',
        'manage_social',
      ]),
      _DashboardPage.users => _hasAny(['manage_users', 'users_access']),
      _DashboardPage.accountSettings => true,
      _DashboardPage.rolesPermissions => _hasAny([
        'roles_access',
        'manage_roles',
        'view_roles',
      ]),
      _DashboardPage.storageSettings ||
      _DashboardPage.googleNews ||
      _DashboardPage.aiSettings ||
      _DashboardPage.marketSettings ||
      _DashboardPage.announcementsSettings ||
      _DashboardPage.pharmacySettings ||
      _DashboardPage.weatherSettings ||
      _DashboardPage.prayerSettings ||
      _DashboardPage.deathNoticeSettings ||
      _DashboardPage.securitySettings ||
      _DashboardPage.contentSettings ||
      _DashboardPage.fontSettings ||
      _DashboardPage.generalSettings => _hasAny([
        'view_settings',
        'settings_access',
      ]),
      _DashboardPage.languageSettings => _hasAny([
        'view_languages',
        'view_settings',
        'settings_access',
      ]),
      _DashboardPage.ads => _hasAny([
        'ads_access',
        'manage_ads',
        'view_settings',
        'settings_access',
      ]),
    };
  }

  void _ensureSelectedPageAllowed() {
    if (_canOpen(_selectedPage)) return;
    for (final page in _DashboardPage.values) {
      if (_canOpen(page)) {
        _selectPage(page);
        return;
      }
    }
  }

  void _openPage(_DashboardPage page) {
    if (!_canOpen(page)) return;
    _selectPage(page);
  }

  void _selectPage(_DashboardPage page) {
    _persistSelectedPage(page);
    setState(() => _selectedPage = page);
  }

  void _persistSelectedPage(_DashboardPage page) {
    final preferences = _preferences;
    if (preferences != null) {
      unawaited(preferences.setString(_selectedPageStorageKey, page.name));
      return;
    }
    unawaited(_persistSelectedPageAfterLoad(page));
  }

  Future<void> _persistSelectedPageAfterLoad(_DashboardPage page) async {
    final preferences = await SharedPreferences.getInstance();
    _preferences = preferences;
    await preferences.setString(_selectedPageStorageKey, page.name);
  }

  void _openHome() {
    _openPage(_DashboardPage.home);
  }

  void _openNews() {
    if (!_canOpen(_DashboardPage.news)) return;
    _persistSelectedPage(_DashboardPage.news);
    setState(() {
      _editingNewsPostId = null;
      _selectedPage = _DashboardPage.news;
    });
  }

  void _openNewsAdd() {
    if (!_canOpen(_DashboardPage.newsAdd)) return;
    _persistSelectedPage(_DashboardPage.newsAdd);
    setState(() {
      _editingNewsPostId = null;
      _selectedPage = _DashboardPage.newsAdd;
    });
  }

  void _openNewsEdit(String postId) {
    if (!_canOpen(_DashboardPage.newsAdd)) return;
    _persistSelectedPage(_DashboardPage.newsAdd);
    setState(() {
      _editingNewsPostId = postId;
      _selectedPage = _DashboardPage.newsAdd;
    });
  }

  void _openStories() {
    _openPage(_DashboardPage.stories);
  }

  void _openPages() {
    _openPage(_DashboardPage.pages);
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

  void _openSubscribers() {
    _openPage(_DashboardPage.subscribers);
  }

  void _openNotificationCampaigns() {
    _openPage(_DashboardPage.notificationCampaigns);
  }

  void _openNotificationTemplates() {
    _openPage(_DashboardPage.notificationTemplates);
  }

  void _openNotificationDevices() {
    _openPage(_DashboardPage.notificationDevices);
  }

  void _openNotificationSettings() {
    _openPage(_DashboardPage.notificationSettings);
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

  void _openSmsBulk() {
    _openPage(_DashboardPage.smsBulk);
  }

  void _openSmsOutbox() {
    _openPage(_DashboardPage.smsOutbox);
  }

  void _openSmsTemplates() {
    _openPage(_DashboardPage.smsTemplates);
  }

  void _openSmsContacts() {
    _openPage(_DashboardPage.smsContacts);
  }

  void _openSmsSettings() {
    _openPage(_DashboardPage.smsSettings);
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

  void _openSocialAccounts() {
    _openPage(_DashboardPage.socialAccounts);
  }

  void _openSocialSettings() {
    _openPage(_DashboardPage.socialSettings);
  }

  void _openLanguageSettings() {
    _openPage(_DashboardPage.languageSettings);
  }

  void _openGeneralSettings() {
    _openPage(_DashboardPage.generalSettings);
  }

  void _openSecuritySettings() {
    _openPage(_DashboardPage.securitySettings);
  }

  void _openContentSettings() {
    _openPage(_DashboardPage.contentSettings);
  }

  void _openFontSettings() {
    _openPage(_DashboardPage.fontSettings);
  }

  void _openStorageSettings() {
    _openPage(_DashboardPage.storageSettings);
  }

  void _openGoogleNews() {
    _openPage(_DashboardPage.googleNews);
  }

  void _openAiSettings() {
    _openPage(_DashboardPage.aiSettings);
  }

  void _openMarketSettings() {
    _openPage(_DashboardPage.marketSettings);
  }

  void _openAnnouncementsSettings() {
    _openPage(_DashboardPage.announcementsSettings);
  }

  void _openPharmacySettings() {
    _openPage(_DashboardPage.pharmacySettings);
  }

  void _openWeatherSettings() {
    _openPage(_DashboardPage.weatherSettings);
  }

  void _openPrayerSettings() {
    _openPage(_DashboardPage.prayerSettings);
  }

  void _openDeathNoticeSettings() {
    _openPage(_DashboardPage.deathNoticeSettings);
  }

  void _openRolesPermissions() {
    _openPage(_DashboardPage.rolesPermissions);
  }

  void _openAds() {
    _openPage(_DashboardPage.ads);
  }

  @override
  Widget build(BuildContext context) {
    final storageSettingsSelected =
        _selectedPage == _DashboardPage.storageSettings;
    final googleNewsSelected = _selectedPage == _DashboardPage.googleNews;
    final aiSettingsSelected = _selectedPage == _DashboardPage.aiSettings;
    final marketSettingsSelected =
        _selectedPage == _DashboardPage.marketSettings;
    final announcementsSettingsSelected =
        _selectedPage == _DashboardPage.announcementsSettings;
    final pharmacySettingsSelected =
        _selectedPage == _DashboardPage.pharmacySettings;
    final weatherSettingsSelected =
        _selectedPage == _DashboardPage.weatherSettings;
    final prayerSettingsSelected =
        _selectedPage == _DashboardPage.prayerSettings;
    final deathNoticeSettingsSelected =
        _selectedPage == _DashboardPage.deathNoticeSettings;
    final newsAddSelected = _selectedPage == _DashboardPage.newsAdd;
    final newsSelected = _selectedPage == _DashboardPage.news;
    final storiesSelected = _selectedPage == _DashboardPage.stories;
    final pagesSelected = _selectedPage == _DashboardPage.pages;
    final commentsSelected = _selectedPage == _DashboardPage.comments;
    final subscribersSelected = _selectedPage == _DashboardPage.subscribers;
    final notificationCampaignsSelected =
        _selectedPage == _DashboardPage.notificationCampaigns;
    final notificationTemplatesSelected =
        _selectedPage == _DashboardPage.notificationTemplates;
    final notificationDevicesSelected =
        _selectedPage == _DashboardPage.notificationDevices;
    final notificationSettingsSelected =
        _selectedPage == _DashboardPage.notificationSettings;
    final mailInboxSelected = _selectedPage == _DashboardPage.mailInbox;
    final bulkMailSelected = _selectedPage == _DashboardPage.bulkMail;
    final mailTemplatesSelected = _selectedPage == _DashboardPage.mailTemplates;
    final contactListsSelected = _selectedPage == _DashboardPage.contactLists;
    final mailSettingsSelected = _selectedPage == _DashboardPage.mailSettings;
    final smsOutboxSelected = _selectedPage == _DashboardPage.smsOutbox;
    final smsBulkSelected = _selectedPage == _DashboardPage.smsBulk;
    final smsTemplatesSelected = _selectedPage == _DashboardPage.smsTemplates;
    final smsContactsSelected = _selectedPage == _DashboardPage.smsContacts;
    final smsSettingsSelected = _selectedPage == _DashboardPage.smsSettings;
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
    final socialAccountsSelected =
        _selectedPage == _DashboardPage.socialAccounts;
    final socialSettingsSelected =
        _selectedPage == _DashboardPage.socialSettings;
    final navigationSelected = _selectedPage == _DashboardPage.navigation;
    final accountSettingsSelected =
        _selectedPage == _DashboardPage.accountSettings;
    final usersSelected =
        _selectedPage == _DashboardPage.users || accountSettingsSelected;
    final rolesPermissionsSelected =
        _selectedPage == _DashboardPage.rolesPermissions;
    final adsSelected = _selectedPage == _DashboardPage.ads;
    final languageSettingsSelected =
        _selectedPage == _DashboardPage.languageSettings;
    final generalSettingsSelected =
        _selectedPage == _DashboardPage.generalSettings;
    final securitySettingsSelected =
        _selectedPage == _DashboardPage.securitySettings;
    final contentSettingsSelected =
        _selectedPage == _DashboardPage.contentSettings;
    final fontSettingsSelected = _selectedPage == _DashboardPage.fontSettings;
    final settingsSelected =
        languageSettingsSelected ||
        generalSettingsSelected ||
        securitySettingsSelected ||
        contentSettingsSelected ||
        fontSettingsSelected;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 900;
        final homeVisible = _canOpen(_DashboardPage.home);
        final newsVisible = _canOpen(_DashboardPage.news);
        final storiesVisible = _canOpen(_DashboardPage.stories);
        final pagesVisible = _canOpen(_DashboardPage.pages);
        final commentsVisible = _canOpen(_DashboardPage.comments);
        final subscribersVisible = _canOpen(_DashboardPage.subscribers);
        final notificationsVisible =
            _canOpen(_DashboardPage.notificationCampaigns) ||
            _canOpen(_DashboardPage.notificationTemplates) ||
            _canOpen(_DashboardPage.notificationDevices) ||
            _canOpen(_DashboardPage.notificationSettings);
        final mailInboxVisible = _canOpen(_DashboardPage.mailInbox);
        final bulkMailVisible = _canOpen(_DashboardPage.bulkMail);
        final mailTemplatesVisible = _canOpen(_DashboardPage.mailTemplates);
        final contactListsVisible = _canOpen(_DashboardPage.contactLists);
        final mailSettingsVisible = _canOpen(_DashboardPage.mailSettings);
        final smsVisible =
            _canOpen(_DashboardPage.smsOutbox) ||
            _canOpen(_DashboardPage.smsBulk) ||
            _canOpen(_DashboardPage.smsTemplates) ||
            _canOpen(_DashboardPage.smsContacts) ||
            _canOpen(_DashboardPage.smsSettings);
        final whatsappVisible =
            _canOpen(_DashboardPage.whatsappMessaging) ||
            _canOpen(_DashboardPage.whatsappBulk) ||
            _canOpen(_DashboardPage.whatsappTemplates) ||
            _canOpen(_DashboardPage.whatsappContacts) ||
            _canOpen(_DashboardPage.whatsappSettings);
        final socialMediaVisible =
            _canOpen(_DashboardPage.socialPublish) ||
            _canOpen(_DashboardPage.socialAccounts) ||
            _canOpen(_DashboardPage.socialSettings);
        final navigationVisible = _canOpen(_DashboardPage.navigation);
        final usersVisible = _canOpen(_DashboardPage.users);
        final rolesPermissionsVisible = _canOpen(
          _DashboardPage.rolesPermissions,
        );
        final adsVisible = _canOpen(_DashboardPage.ads);
        final storageSettingsVisible = _canOpen(_DashboardPage.storageSettings);
        final googleNewsVisible = _canOpen(_DashboardPage.googleNews);
        final aiSettingsVisible = _canOpen(_DashboardPage.aiSettings);
        final marketSettingsVisible = _canOpen(_DashboardPage.marketSettings);
        final announcementsSettingsVisible = _canOpen(
          _DashboardPage.announcementsSettings,
        );
        final pharmacySettingsVisible = _canOpen(
          _DashboardPage.pharmacySettings,
        );
        final weatherSettingsVisible = _canOpen(_DashboardPage.weatherSettings);
        final prayerSettingsVisible = _canOpen(_DashboardPage.prayerSettings);
        final deathNoticeSettingsVisible = _canOpen(
          _DashboardPage.deathNoticeSettings,
        );
        final generalSettingsVisible = _canOpen(_DashboardPage.generalSettings);
        final securitySettingsVisible = _canOpen(
          _DashboardPage.securitySettings,
        );
        final contentSettingsVisible = _canOpen(_DashboardPage.contentSettings);
        final fontSettingsVisible = _canOpen(_DashboardPage.fontSettings);
        final languageSettingsVisible = _canOpen(
          _DashboardPage.languageSettings,
        );

        return Scaffold(
          drawer: isCompact
              ? AdminDrawer(
                  onLogout: widget.onLogout,
                  homeVisible: homeVisible,
                  newsVisible: newsVisible,
                  storiesVisible: storiesVisible,
                  pagesVisible: pagesVisible,
                  commentsVisible: commentsVisible,
                  subscribersVisible: subscribersVisible,
                  notificationsVisible: notificationsVisible,
                  mailInboxVisible: mailInboxVisible,
                  bulkMailVisible: bulkMailVisible,
                  mailTemplatesVisible: mailTemplatesVisible,
                  contactListsVisible: contactListsVisible,
                  mailSettingsVisible: mailSettingsVisible,
                  smsVisible: smsVisible,
                  whatsappVisible: whatsappVisible,
                  socialMediaVisible: socialMediaVisible,
                  navigationVisible: navigationVisible,
                  usersVisible: usersVisible,
                  rolesPermissionsVisible: rolesPermissionsVisible,
                  adsVisible: adsVisible,
                  storageSettingsVisible: storageSettingsVisible,
                  googleNewsVisible: googleNewsVisible,
                  aiSettingsVisible: aiSettingsVisible,
                  marketSettingsVisible: marketSettingsVisible,
                  announcementsSettingsVisible: announcementsSettingsVisible,
                  pharmacySettingsVisible: pharmacySettingsVisible,
                  weatherSettingsVisible: weatherSettingsVisible,
                  prayerSettingsVisible: prayerSettingsVisible,
                  deathNoticeSettingsVisible: deathNoticeSettingsVisible,
                  generalSettingsVisible: generalSettingsVisible,
                  securitySettingsVisible: securitySettingsVisible,
                  contentSettingsVisible: contentSettingsVisible,
                  fontSettingsVisible: fontSettingsVisible,
                  languageSettingsVisible: languageSettingsVisible,
                  homeSelected:
                      !settingsSelected &&
                      !newsAddSelected &&
                      !newsSelected &&
                      !storiesSelected &&
                      !pagesSelected &&
                      !commentsSelected &&
                      !subscribersSelected &&
                      !notificationCampaignsSelected &&
                      !notificationTemplatesSelected &&
                      !notificationDevicesSelected &&
                      !notificationSettingsSelected &&
                      !mailInboxSelected &&
                      !bulkMailSelected &&
                      !mailTemplatesSelected &&
                      !contactListsSelected &&
                      !mailSettingsSelected &&
                      !smsOutboxSelected &&
                      !smsBulkSelected &&
                      !smsTemplatesSelected &&
                      !smsContactsSelected &&
                      !smsSettingsSelected &&
                      !whatsappMessagingSelected &&
                      !whatsappBulkSelected &&
                      !whatsappTemplatesSelected &&
                      !whatsappContactsSelected &&
                      !whatsappSettingsSelected &&
                      !socialPublishSelected &&
                      !socialAccountsSelected &&
                      !socialSettingsSelected &&
                      !navigationSelected &&
                      !usersSelected &&
                      !rolesPermissionsSelected &&
                      !storageSettingsSelected &&
                      !googleNewsSelected &&
                      !aiSettingsSelected &&
                      !marketSettingsSelected &&
                      !announcementsSettingsSelected &&
                      !pharmacySettingsSelected &&
                      !weatherSettingsSelected &&
                      !prayerSettingsSelected &&
                      !deathNoticeSettingsSelected &&
                      !adsSelected,
                  newsAddSelected: newsAddSelected,
                  newsSelected: newsSelected,
                  storiesSelected: storiesSelected,
                  pagesSelected: pagesSelected,
                  commentsSelected: commentsSelected,
                  subscribersSelected: subscribersSelected,
                  notificationCampaignsSelected: notificationCampaignsSelected,
                  notificationTemplatesSelected: notificationTemplatesSelected,
                  notificationDevicesSelected: notificationDevicesSelected,
                  notificationSettingsSelected: notificationSettingsSelected,
                  mailInboxSelected: mailInboxSelected,
                  bulkMailSelected: bulkMailSelected,
                  mailTemplatesSelected: mailTemplatesSelected,
                  contactListsSelected: contactListsSelected,
                  mailSettingsSelected: mailSettingsSelected,
                  smsBulkSelected: smsBulkSelected,
                  smsOutboxSelected: smsOutboxSelected,
                  smsTemplatesSelected: smsTemplatesSelected,
                  smsContactsSelected: smsContactsSelected,
                  smsSettingsSelected: smsSettingsSelected,
                  whatsappMessagingSelected: whatsappMessagingSelected,
                  whatsappBulkSelected: whatsappBulkSelected,
                  whatsappTemplatesSelected: whatsappTemplatesSelected,
                  whatsappContactsSelected: whatsappContactsSelected,
                  whatsappSettingsSelected: whatsappSettingsSelected,
                  socialPublishSelected: socialPublishSelected,
                  socialAccountsSelected: socialAccountsSelected,
                  socialSettingsSelected: socialSettingsSelected,
                  navigationSelected: navigationSelected,
                  usersSelected: usersSelected,
                  rolesPermissionsSelected: rolesPermissionsSelected,
                  adsSelected: adsSelected,
                  storageSettingsSelected: storageSettingsSelected,
                  googleNewsSelected: googleNewsSelected,
                  aiSettingsSelected: aiSettingsSelected,
                  marketSettingsSelected: marketSettingsSelected,
                  announcementsSettingsSelected: announcementsSettingsSelected,
                  pharmacySettingsSelected: pharmacySettingsSelected,
                  weatherSettingsSelected: weatherSettingsSelected,
                  prayerSettingsSelected: prayerSettingsSelected,
                  deathNoticeSettingsSelected: deathNoticeSettingsSelected,
                  generalSettingsSelected: generalSettingsSelected,
                  securitySettingsSelected: securitySettingsSelected,
                  contentSettingsSelected: contentSettingsSelected,
                  fontSettingsSelected: fontSettingsSelected,
                  languageSettingsSelected: languageSettingsSelected,
                  onHomeSelected: _openHome,
                  onNewsAddSelected: _openNewsAdd,
                  onNewsSelected: _openNews,
                  onStoriesSelected: _openStories,
                  onPagesSelected: _openPages,
                  onCommentsSelected: _openComments,
                  onSubscribersSelected: _openSubscribers,
                  onNotificationCampaignsSelected: _openNotificationCampaigns,
                  onNotificationTemplatesSelected: _openNotificationTemplates,
                  onNotificationDevicesSelected: _openNotificationDevices,
                  onNotificationSettingsSelected: _openNotificationSettings,
                  onMailInboxSelected: _openMailInbox,
                  onBulkMailSelected: _openBulkMail,
                  onMailTemplatesSelected: _openMailTemplates,
                  onContactListsSelected: _openContactLists,
                  onMailSettingsSelected: _openMailSettings,
                  onSmsOutboxSelected: _openSmsOutbox,
                  onSmsBulkSelected: _openSmsBulk,
                  onSmsTemplatesSelected: _openSmsTemplates,
                  onSmsContactsSelected: _openSmsContacts,
                  onSmsSettingsSelected: _openSmsSettings,
                  onWhatsappMessagingSelected: _openWhatsappMessaging,
                  onWhatsappBulkSelected: _openWhatsappBulk,
                  onWhatsappTemplatesSelected: _openWhatsappTemplates,
                  onWhatsappContactsSelected: _openWhatsappContacts,
                  onWhatsappSettingsSelected: _openWhatsappSettings,
                  onSocialPublishSelected: _openSocialPublish,
                  onSocialAccountsSelected: _openSocialAccounts,
                  onSocialSettingsSelected: _openSocialSettings,
                  onNavigationSelected: _openNavigation,
                  onUsersSelected: _openUsers,
                  onRolesPermissionsSelected: _openRolesPermissions,
                  onAdsSelected: _openAds,
                  onStorageSettingsSelected: _openStorageSettings,
                  onGoogleNewsSelected: _openGoogleNews,
                  onAiSettingsSelected: _openAiSettings,
                  onMarketSettingsSelected: _openMarketSettings,
                  onAnnouncementsSettingsSelected: _openAnnouncementsSettings,
                  onPharmacySettingsSelected: _openPharmacySettings,
                  onWeatherSettingsSelected: _openWeatherSettings,
                  onPrayerSettingsSelected: _openPrayerSettings,
                  onDeathNoticeSettingsSelected: _openDeathNoticeSettings,
                  onGeneralSettingsSelected: _openGeneralSettings,
                  onSecuritySettingsSelected: _openSecuritySettings,
                  onContentSettingsSelected: _openContentSettings,
                  onFontSettingsSelected: _openFontSettings,
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
                    storiesVisible: storiesVisible,
                    pagesVisible: pagesVisible,
                    commentsVisible: commentsVisible,
                    subscribersVisible: subscribersVisible,
                    notificationsVisible: notificationsVisible,
                    mailInboxVisible: mailInboxVisible,
                    bulkMailVisible: bulkMailVisible,
                    mailTemplatesVisible: mailTemplatesVisible,
                    contactListsVisible: contactListsVisible,
                    mailSettingsVisible: mailSettingsVisible,
                    smsVisible: smsVisible,
                    whatsappVisible: whatsappVisible,
                    socialMediaVisible: socialMediaVisible,
                    navigationVisible: navigationVisible,
                    usersVisible: usersVisible,
                    rolesPermissionsVisible: rolesPermissionsVisible,
                    adsVisible: adsVisible,
                    storageSettingsVisible: storageSettingsVisible,
                    googleNewsVisible: googleNewsVisible,
                    aiSettingsVisible: aiSettingsVisible,
                    marketSettingsVisible: marketSettingsVisible,
                    announcementsSettingsVisible: announcementsSettingsVisible,
                    pharmacySettingsVisible: pharmacySettingsVisible,
                    weatherSettingsVisible: weatherSettingsVisible,
                    prayerSettingsVisible: prayerSettingsVisible,
                    deathNoticeSettingsVisible: deathNoticeSettingsVisible,
                    generalSettingsVisible: generalSettingsVisible,
                    securitySettingsVisible: securitySettingsVisible,
                    contentSettingsVisible: contentSettingsVisible,
                    fontSettingsVisible: fontSettingsVisible,
                    languageSettingsVisible: languageSettingsVisible,
                    homeSelected:
                        !settingsSelected &&
                        !newsAddSelected &&
                        !newsSelected &&
                        !storiesSelected &&
                        !pagesSelected &&
                        !commentsSelected &&
                        !subscribersSelected &&
                        !notificationCampaignsSelected &&
                        !notificationTemplatesSelected &&
                        !notificationDevicesSelected &&
                        !notificationSettingsSelected &&
                        !mailInboxSelected &&
                        !bulkMailSelected &&
                        !mailTemplatesSelected &&
                        !contactListsSelected &&
                        !mailSettingsSelected &&
                        !smsOutboxSelected &&
                        !smsBulkSelected &&
                        !smsTemplatesSelected &&
                        !smsContactsSelected &&
                        !smsSettingsSelected &&
                        !whatsappMessagingSelected &&
                        !whatsappBulkSelected &&
                        !whatsappTemplatesSelected &&
                        !whatsappContactsSelected &&
                        !whatsappSettingsSelected &&
                        !socialPublishSelected &&
                        !socialAccountsSelected &&
                        !socialSettingsSelected &&
                        !navigationSelected &&
                        !usersSelected &&
                        !rolesPermissionsSelected &&
                        !storageSettingsSelected &&
                        !googleNewsSelected &&
                        !aiSettingsSelected &&
                        !marketSettingsSelected &&
                        !announcementsSettingsSelected &&
                        !pharmacySettingsSelected &&
                        !weatherSettingsSelected &&
                        !prayerSettingsSelected &&
                        !deathNoticeSettingsSelected &&
                        !adsSelected,
                    newsAddSelected: newsAddSelected,
                    newsSelected: newsSelected,
                    storiesSelected: storiesSelected,
                    pagesSelected: pagesSelected,
                    commentsSelected: commentsSelected,
                    subscribersSelected: subscribersSelected,
                    notificationCampaignsSelected:
                        notificationCampaignsSelected,
                    notificationTemplatesSelected:
                        notificationTemplatesSelected,
                    notificationDevicesSelected: notificationDevicesSelected,
                    notificationSettingsSelected: notificationSettingsSelected,
                    mailInboxSelected: mailInboxSelected,
                    bulkMailSelected: bulkMailSelected,
                    mailTemplatesSelected: mailTemplatesSelected,
                    contactListsSelected: contactListsSelected,
                    mailSettingsSelected: mailSettingsSelected,
                    smsBulkSelected: smsBulkSelected,
                    smsOutboxSelected: smsOutboxSelected,
                    smsTemplatesSelected: smsTemplatesSelected,
                    smsContactsSelected: smsContactsSelected,
                    smsSettingsSelected: smsSettingsSelected,
                    whatsappMessagingSelected: whatsappMessagingSelected,
                    whatsappBulkSelected: whatsappBulkSelected,
                    whatsappTemplatesSelected: whatsappTemplatesSelected,
                    whatsappContactsSelected: whatsappContactsSelected,
                    whatsappSettingsSelected: whatsappSettingsSelected,
                    socialPublishSelected: socialPublishSelected,
                    socialAccountsSelected: socialAccountsSelected,
                    socialSettingsSelected: socialSettingsSelected,
                    navigationSelected: navigationSelected,
                    usersSelected: usersSelected,
                    rolesPermissionsSelected: rolesPermissionsSelected,
                    adsSelected: adsSelected,
                    storageSettingsSelected: storageSettingsSelected,
                    googleNewsSelected: googleNewsSelected,
                    aiSettingsSelected: aiSettingsSelected,
                    marketSettingsSelected: marketSettingsSelected,
                    announcementsSettingsSelected:
                        announcementsSettingsSelected,
                    pharmacySettingsSelected: pharmacySettingsSelected,
                    weatherSettingsSelected: weatherSettingsSelected,
                    prayerSettingsSelected: prayerSettingsSelected,
                    deathNoticeSettingsSelected: deathNoticeSettingsSelected,
                    generalSettingsSelected: generalSettingsSelected,
                    securitySettingsSelected: securitySettingsSelected,
                    contentSettingsSelected: contentSettingsSelected,
                    fontSettingsSelected: fontSettingsSelected,
                    languageSettingsSelected: languageSettingsSelected,
                    onHomeSelected: _openHome,
                    onNewsAddSelected: _openNewsAdd,
                    onNewsSelected: _openNews,
                    onStoriesSelected: _openStories,
                    onPagesSelected: _openPages,
                    onCommentsSelected: _openComments,
                    onSubscribersSelected: _openSubscribers,
                    onNotificationCampaignsSelected: _openNotificationCampaigns,
                    onNotificationTemplatesSelected: _openNotificationTemplates,
                    onNotificationDevicesSelected: _openNotificationDevices,
                    onNotificationSettingsSelected: _openNotificationSettings,
                    onMailInboxSelected: _openMailInbox,
                    onBulkMailSelected: _openBulkMail,
                    onMailTemplatesSelected: _openMailTemplates,
                    onContactListsSelected: _openContactLists,
                    onMailSettingsSelected: _openMailSettings,
                    onSmsOutboxSelected: _openSmsOutbox,
                    onSmsBulkSelected: _openSmsBulk,
                    onSmsTemplatesSelected: _openSmsTemplates,
                    onSmsContactsSelected: _openSmsContacts,
                    onSmsSettingsSelected: _openSmsSettings,
                    onWhatsappMessagingSelected: _openWhatsappMessaging,
                    onWhatsappBulkSelected: _openWhatsappBulk,
                    onWhatsappTemplatesSelected: _openWhatsappTemplates,
                    onWhatsappContactsSelected: _openWhatsappContacts,
                    onWhatsappSettingsSelected: _openWhatsappSettings,
                    onSocialPublishSelected: _openSocialPublish,
                    onSocialAccountsSelected: _openSocialAccounts,
                    onSocialSettingsSelected: _openSocialSettings,
                    onNavigationSelected: _openNavigation,
                    onUsersSelected: _openUsers,
                    onRolesPermissionsSelected: _openRolesPermissions,
                    onAdsSelected: _openAds,
                    onStorageSettingsSelected: _openStorageSettings,
                    onGoogleNewsSelected: _openGoogleNews,
                    onAiSettingsSelected: _openAiSettings,
                    onMarketSettingsSelected: _openMarketSettings,
                    onAnnouncementsSettingsSelected: _openAnnouncementsSettings,
                    onPharmacySettingsSelected: _openPharmacySettings,
                    onWeatherSettingsSelected: _openWeatherSettings,
                    onPrayerSettingsSelected: _openPrayerSettings,
                    onDeathNoticeSettingsSelected: _openDeathNoticeSettings,
                    onGeneralSettingsSelected: _openGeneralSettings,
                    onSecuritySettingsSelected: _openSecuritySettings,
                    onContentSettingsSelected: _openContentSettings,
                    onFontSettingsSelected: _openFontSettings,
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
                        onOpenFrontend: widget.onOpenFrontend,
                      ),
                      Expanded(
                        child: _permissionLoading
                            ? const _DashboardPermissionLoading()
                            : !_canOpen(_selectedPage)
                            ? _DashboardAccessDenied(error: _permissionError)
                            : switch (_selectedPage) {
                                _DashboardPage.home => const DashboardContent(),
                                _DashboardPage.ads => const AdsScreen(),
                                _DashboardPage.newsAdd => NewsAddScreen(
                                  session: widget.session,
                                  profile: widget.profile,
                                  repository: widget.newsRepository,
                                  contentSettingsRepository:
                                      widget.contentSettingsRepository,
                                  initialPostFormatSettings:
                                      _contentSettingsSnapshot?.postFormats,
                                  postId: _editingNewsPostId,
                                  onBackToNews: _openNews,
                                ),
                                _DashboardPage.news => NewsScreen(
                                  repository: widget.newsRepository,
                                  onAddPost: _openNewsAdd,
                                  onEditPost: _openNewsEdit,
                                ),
                                _DashboardPage.stories => StoriesScreen(
                                  session: widget.session,
                                  repository: widget.storiesRepository,
                                ),
                                _DashboardPage.pages => PagesScreen(
                                  repository: widget.pagesRepository,
                                ),
                                _DashboardPage.comments => CommentsScreen(
                                  session: widget.session,
                                  repository: widget.commentsRepository,
                                ),
                                _DashboardPage.subscribers => SubscribersScreen(
                                  repository: widget.subscribersRepository,
                                ),
                                _DashboardPage.notificationCampaigns =>
                                  NotificationCampaignsScreen(
                                    session: widget.session,
                                    repository: widget.notificationsRepository,
                                    newsRepository: widget.newsRepository,
                                  ),
                                _DashboardPage.notificationTemplates =>
                                  NotificationTemplatesScreen(
                                    session: widget.session,
                                    repository: widget.notificationsRepository,
                                  ),
                                _DashboardPage.notificationDevices =>
                                  NotificationDevicesScreen(
                                    session: widget.session,
                                    repository: widget.notificationsRepository,
                                  ),
                                _DashboardPage.notificationSettings =>
                                  NotificationSettingsScreen(
                                    session: widget.session,
                                    repository: widget.notificationsRepository,
                                  ),
                                _DashboardPage.mailInbox => MailInboxScreen(
                                  session: widget.session,
                                  repository: widget.mailRepository,
                                ),
                                _DashboardPage.bulkMail => BulkMailScreen(
                                  session: widget.session,
                                  repository: widget.mailRepository,
                                ),
                                _DashboardPage.mailTemplates =>
                                  MailTemplatesScreen(
                                    session: widget.session,
                                    repository: widget.mailRepository,
                                  ),
                                _DashboardPage.contactLists =>
                                  ContactListsScreen(
                                    session: widget.session,
                                    repository: widget.mailRepository,
                                  ),
                                _DashboardPage.mailSettings =>
                                  MailSettingsScreen(
                                    session: widget.session,
                                    repository: widget.mailRepository,
                                  ),
                                _DashboardPage.smsOutbox => SmsOutboxScreen(
                                  session: widget.session,
                                  repository: widget.smsRepository,
                                ),
                                _DashboardPage.smsBulk => SmsBulkScreen(
                                  session: widget.session,
                                  repository: widget.smsRepository,
                                ),
                                _DashboardPage.smsTemplates =>
                                  SmsTemplatesScreen(
                                    session: widget.session,
                                    repository: widget.smsRepository,
                                  ),
                                _DashboardPage.smsContacts =>
                                  SmsContactListsScreen(
                                    session: widget.session,
                                    repository: widget.smsRepository,
                                  ),
                                _DashboardPage.smsSettings => SmsSettingsScreen(
                                  session: widget.session,
                                  repository: widget.smsRepository,
                                ),
                                _DashboardPage.whatsappMessaging =>
                                  WhatsappMessagingScreen(
                                    session: widget.session,
                                    repository: widget.whatsappRepository,
                                  ),
                                _DashboardPage.whatsappBulk =>
                                  WhatsappBulkScreen(
                                    session: widget.session,
                                    repository: widget.whatsappRepository,
                                  ),
                                _DashboardPage.whatsappTemplates =>
                                  WhatsappTemplatesScreen(
                                    session: widget.session,
                                    repository: widget.whatsappRepository,
                                  ),
                                _DashboardPage.whatsappContacts =>
                                  WhatsappContactListsScreen(
                                    session: widget.session,
                                    repository: widget.whatsappRepository,
                                  ),
                                _DashboardPage.whatsappSettings =>
                                  WhatsappSettingsScreen(
                                    session: widget.session,
                                    repository: widget.whatsappRepository,
                                  ),
                                _DashboardPage.socialPublish =>
                                  SocialPublishScreen(
                                    session: widget.session,
                                    newsRepository: widget.newsRepository,
                                    socialRepository: widget.socialRepository,
                                  ),
                                _DashboardPage.socialAccounts =>
                                  SocialAccountsScreen(
                                    session: widget.session,
                                    repository: widget.socialRepository,
                                  ),
                                _DashboardPage.socialSettings =>
                                  SocialSettingsScreen(
                                    session: widget.session,
                                    repository: widget.socialRepository,
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
                                _DashboardPage.storageSettings =>
                                  StorageSettingsScreen(
                                    repository:
                                        widget.storageSettingsRepository,
                                  ),
                                _DashboardPage.googleNews =>
                                  GoogleNewsSettingsScreen(
                                    session: widget.session,
                                  ),
                                _DashboardPage.aiSettings => AiSettingsScreen(
                                  session: widget.session,
                                  repository: widget.aiSettingsRepository,
                                ),
                                _DashboardPage.marketSettings =>
                                  MarketSettingsScreen(
                                    session: widget.session,
                                    repository: widget.moduleSettingsRepository,
                                  ),
                                _DashboardPage.announcementsSettings =>
                                  AnnouncementsSettingsScreen(
                                    session: widget.session,
                                    repository: widget.moduleSettingsRepository,
                                    newsRepository: widget.newsRepository,
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
                                _DashboardPage.prayerSettings =>
                                  PrayerSettingsScreen(
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
                                    profile: widget.profile,
                                    repository:
                                        widget.generalSettingsRepository,
                                  ),
                                _DashboardPage.securitySettings =>
                                  SecuritySettingsScreen(
                                    session: widget.session,
                                    repository:
                                        widget.securitySettingsRepository,
                                  ),
                                _DashboardPage.contentSettings =>
                                  ContentSettingsScreen(
                                    session: widget.session,
                                    repository:
                                        widget.contentSettingsRepository,
                                    initialSettings: _contentSettingsSnapshot,
                                    onGeneralSettingsChanged:
                                        _updateContentGeneralSettings,
                                    onPostSettingsChanged:
                                        _updateContentPostSettings,
                                    onPostFormatSettingsChanged:
                                        _updateContentPostFormatSettings,
                                    onUploadSettingsChanged:
                                        _updateContentUploadSettings,
                                    onFeaturedSettingsChanged:
                                        _updateContentFeaturedSettings,
                                    onTrashCleanupSettingsChanged:
                                        _updateContentTrashCleanupSettings,
                                  ),
                                _DashboardPage.fontSettings =>
                                  FontSettingsScreen(
                                    session: widget.session,
                                    repository: widget.fontSettingsRepository,
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
  newsAdd,
  news,
  stories,
  pages,
  comments,
  subscribers,
  notificationCampaigns,
  notificationTemplates,
  notificationDevices,
  notificationSettings,
  mailInbox,
  bulkMail,
  mailTemplates,
  contactLists,
  mailSettings,
  smsOutbox,
  smsBulk,
  smsTemplates,
  smsContacts,
  smsSettings,
  whatsappMessaging,
  whatsappBulk,
  whatsappTemplates,
  whatsappContacts,
  whatsappSettings,
  socialPublish,
  socialAccounts,
  socialSettings,
  navigation,
  users,
  accountSettings,
  rolesPermissions,
  storageSettings,
  googleNews,
  aiSettings,
  marketSettings,
  announcementsSettings,
  pharmacySettings,
  weatherSettings,
  prayerSettings,
  deathNoticeSettings,
  generalSettings,
  securitySettings,
  contentSettings,
  fontSettings,
  languageSettings,
  ads,
}

_DashboardPage? _dashboardPageFromName(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  for (final page in _DashboardPage.values) {
    if (page.name == value) return page;
  }
  return null;
}
