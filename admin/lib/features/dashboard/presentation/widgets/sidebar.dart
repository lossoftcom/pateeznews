import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../../core/localization/admin_language_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import 'sidebar_header.dart';
import 'sidebar_item.dart';

class AdminDrawer extends StatelessWidget {
  const AdminDrawer({
    super.key,
    required this.onLogout,
    required this.homeVisible,
    required this.newsVisible,
    required this.storiesVisible,
    required this.pagesVisible,
    required this.commentsVisible,
    required this.subscribersVisible,
    required this.notificationsVisible,
    required this.mailInboxVisible,
    required this.bulkMailVisible,
    required this.mailTemplatesVisible,
    required this.contactListsVisible,
    required this.mailSettingsVisible,
    required this.smsVisible,
    required this.whatsappVisible,
    required this.socialMediaVisible,
    required this.navigationVisible,
    required this.usersVisible,
    required this.rolesPermissionsVisible,
    required this.storageSettingsVisible,
    required this.googleNewsVisible,
    required this.aiSettingsVisible,
    required this.marketSettingsVisible,
    required this.announcementsSettingsVisible,
    required this.pharmacySettingsVisible,
    required this.weatherSettingsVisible,
    required this.prayerSettingsVisible,
    required this.deathNoticeSettingsVisible,
    required this.generalSettingsVisible,
    required this.securitySettingsVisible,
    required this.contentSettingsVisible,
    required this.fontSettingsVisible,
    required this.languageSettingsVisible,
    required this.homeSelected,
    required this.newsAddSelected,
    required this.newsSelected,
    required this.storiesSelected,
    required this.pagesSelected,
    required this.commentsSelected,
    required this.subscribersSelected,
    required this.notificationCampaignsSelected,
    required this.notificationTemplatesSelected,
    required this.notificationDevicesSelected,
    required this.notificationSettingsSelected,
    required this.mailInboxSelected,
    required this.bulkMailSelected,
    required this.mailTemplatesSelected,
    required this.contactListsSelected,
    required this.mailSettingsSelected,
    required this.smsOutboxSelected,
    required this.smsBulkSelected,
    required this.smsTemplatesSelected,
    required this.smsContactsSelected,
    required this.smsSettingsSelected,
    required this.whatsappMessagingSelected,
    required this.whatsappBulkSelected,
    required this.whatsappTemplatesSelected,
    required this.whatsappContactsSelected,
    required this.whatsappSettingsSelected,
    required this.socialPublishSelected,
    required this.socialAccountsSelected,
    required this.socialSettingsSelected,
    required this.navigationSelected,
    required this.usersSelected,
    required this.rolesPermissionsSelected,
    required this.storageSettingsSelected,
    required this.googleNewsSelected,
    required this.aiSettingsSelected,
    required this.marketSettingsSelected,
    required this.announcementsSettingsSelected,
    required this.pharmacySettingsSelected,
    required this.weatherSettingsSelected,
    required this.prayerSettingsSelected,
    required this.deathNoticeSettingsSelected,
    required this.generalSettingsSelected,
    required this.securitySettingsSelected,
    required this.contentSettingsSelected,
    required this.fontSettingsSelected,
    required this.languageSettingsSelected,
    required this.onHomeSelected,
    required this.onNewsAddSelected,
    required this.onNewsSelected,
    required this.onStoriesSelected,
    required this.onPagesSelected,
    required this.onCommentsSelected,
    required this.onSubscribersSelected,
    required this.onNotificationCampaignsSelected,
    required this.onNotificationTemplatesSelected,
    required this.onNotificationDevicesSelected,
    required this.onNotificationSettingsSelected,
    required this.onMailInboxSelected,
    required this.onBulkMailSelected,
    required this.onMailTemplatesSelected,
    required this.onContactListsSelected,
    required this.onMailSettingsSelected,
    required this.onSmsOutboxSelected,
    required this.onSmsBulkSelected,
    required this.onSmsTemplatesSelected,
    required this.onSmsContactsSelected,
    required this.onSmsSettingsSelected,
    required this.onWhatsappMessagingSelected,
    required this.onWhatsappBulkSelected,
    required this.onWhatsappTemplatesSelected,
    required this.onWhatsappContactsSelected,
    required this.onWhatsappSettingsSelected,
    required this.onSocialPublishSelected,
    required this.onSocialAccountsSelected,
    required this.onSocialSettingsSelected,
    required this.onNavigationSelected,
    required this.onUsersSelected,
    required this.onRolesPermissionsSelected,
    required this.onStorageSettingsSelected,
    required this.onGoogleNewsSelected,
    required this.onAiSettingsSelected,
    required this.onMarketSettingsSelected,
    required this.onAnnouncementsSettingsSelected,
    required this.onPharmacySettingsSelected,
    required this.onWeatherSettingsSelected,
    required this.onPrayerSettingsSelected,
    required this.onDeathNoticeSettingsSelected,
    required this.onGeneralSettingsSelected,
    required this.onSecuritySettingsSelected,
    required this.onContentSettingsSelected,
    required this.onFontSettingsSelected,
    required this.onLanguageSettingsSelected,
  });

  final VoidCallback onLogout;
  final bool homeVisible;
  final bool newsVisible;
  final bool storiesVisible;
  final bool pagesVisible;
  final bool commentsVisible;
  final bool subscribersVisible;
  final bool notificationsVisible;
  final bool mailInboxVisible;
  final bool bulkMailVisible;
  final bool mailTemplatesVisible;
  final bool contactListsVisible;
  final bool mailSettingsVisible;
  final bool smsVisible;
  final bool whatsappVisible;
  final bool socialMediaVisible;
  final bool navigationVisible;
  final bool usersVisible;
  final bool rolesPermissionsVisible;
  final bool storageSettingsVisible;
  final bool googleNewsVisible;
  final bool aiSettingsVisible;
  final bool marketSettingsVisible;
  final bool announcementsSettingsVisible;
  final bool pharmacySettingsVisible;
  final bool weatherSettingsVisible;
  final bool prayerSettingsVisible;
  final bool deathNoticeSettingsVisible;
  final bool generalSettingsVisible;
  final bool securitySettingsVisible;
  final bool contentSettingsVisible;
  final bool fontSettingsVisible;
  final bool languageSettingsVisible;
  final bool homeSelected;
  final bool newsAddSelected;
  final bool newsSelected;
  final bool storiesSelected;
  final bool pagesSelected;
  final bool commentsSelected;
  final bool subscribersSelected;
  final bool notificationCampaignsSelected;
  final bool notificationTemplatesSelected;
  final bool notificationDevicesSelected;
  final bool notificationSettingsSelected;
  final bool mailInboxSelected;
  final bool bulkMailSelected;
  final bool mailTemplatesSelected;
  final bool contactListsSelected;
  final bool mailSettingsSelected;
  final bool smsOutboxSelected;
  final bool smsBulkSelected;
  final bool smsTemplatesSelected;
  final bool smsContactsSelected;
  final bool smsSettingsSelected;
  final bool whatsappMessagingSelected;
  final bool whatsappBulkSelected;
  final bool whatsappTemplatesSelected;
  final bool whatsappContactsSelected;
  final bool whatsappSettingsSelected;
  final bool socialPublishSelected;
  final bool socialAccountsSelected;
  final bool socialSettingsSelected;
  final bool navigationSelected;
  final bool usersSelected;
  final bool rolesPermissionsSelected;
  final bool storageSettingsSelected;
  final bool googleNewsSelected;
  final bool aiSettingsSelected;
  final bool marketSettingsSelected;
  final bool announcementsSettingsSelected;
  final bool pharmacySettingsSelected;
  final bool weatherSettingsSelected;
  final bool prayerSettingsSelected;
  final bool deathNoticeSettingsSelected;
  final bool generalSettingsSelected;
  final bool securitySettingsSelected;
  final bool contentSettingsSelected;
  final bool fontSettingsSelected;
  final bool languageSettingsSelected;
  final VoidCallback onHomeSelected;
  final VoidCallback onNewsAddSelected;
  final VoidCallback onNewsSelected;
  final VoidCallback onStoriesSelected;
  final VoidCallback onPagesSelected;
  final VoidCallback onCommentsSelected;
  final VoidCallback onSubscribersSelected;
  final VoidCallback onNotificationCampaignsSelected;
  final VoidCallback onNotificationTemplatesSelected;
  final VoidCallback onNotificationDevicesSelected;
  final VoidCallback onNotificationSettingsSelected;
  final VoidCallback onMailInboxSelected;
  final VoidCallback onBulkMailSelected;
  final VoidCallback onMailTemplatesSelected;
  final VoidCallback onContactListsSelected;
  final VoidCallback onMailSettingsSelected;
  final VoidCallback onSmsOutboxSelected;
  final VoidCallback onSmsBulkSelected;
  final VoidCallback onSmsTemplatesSelected;
  final VoidCallback onSmsContactsSelected;
  final VoidCallback onSmsSettingsSelected;
  final VoidCallback onWhatsappMessagingSelected;
  final VoidCallback onWhatsappBulkSelected;
  final VoidCallback onWhatsappTemplatesSelected;
  final VoidCallback onWhatsappContactsSelected;
  final VoidCallback onWhatsappSettingsSelected;
  final VoidCallback onSocialPublishSelected;
  final VoidCallback onSocialAccountsSelected;
  final VoidCallback onSocialSettingsSelected;
  final VoidCallback onNavigationSelected;
  final VoidCallback onUsersSelected;
  final VoidCallback onRolesPermissionsSelected;
  final VoidCallback onStorageSettingsSelected;
  final VoidCallback onGoogleNewsSelected;
  final VoidCallback onAiSettingsSelected;
  final VoidCallback onMarketSettingsSelected;
  final VoidCallback onAnnouncementsSettingsSelected;
  final VoidCallback onPharmacySettingsSelected;
  final VoidCallback onWeatherSettingsSelected;
  final VoidCallback onPrayerSettingsSelected;
  final VoidCallback onDeathNoticeSettingsSelected;
  final VoidCallback onGeneralSettingsSelected;
  final VoidCallback onSecuritySettingsSelected;
  final VoidCallback onContentSettingsSelected;
  final VoidCallback onFontSettingsSelected;
  final VoidCallback onLanguageSettingsSelected;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(AppRadius.value),
          bottomRight: Radius.circular(AppRadius.value),
        ),
      ),
      child: SafeArea(
        child: Sidebar(
          onLogout: onLogout,
          drawerMode: true,
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
          homeSelected: homeSelected,
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
          smsOutboxSelected: smsOutboxSelected,
          smsBulkSelected: smsBulkSelected,
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
          onHomeSelected: onHomeSelected,
          onNewsAddSelected: onNewsAddSelected,
          onNewsSelected: onNewsSelected,
          onStoriesSelected: onStoriesSelected,
          onPagesSelected: onPagesSelected,
          onCommentsSelected: onCommentsSelected,
          onSubscribersSelected: onSubscribersSelected,
          onNotificationCampaignsSelected: onNotificationCampaignsSelected,
          onNotificationTemplatesSelected: onNotificationTemplatesSelected,
          onNotificationDevicesSelected: onNotificationDevicesSelected,
          onNotificationSettingsSelected: onNotificationSettingsSelected,
          onMailInboxSelected: onMailInboxSelected,
          onBulkMailSelected: onBulkMailSelected,
          onMailTemplatesSelected: onMailTemplatesSelected,
          onContactListsSelected: onContactListsSelected,
          onMailSettingsSelected: onMailSettingsSelected,
          onSmsOutboxSelected: onSmsOutboxSelected,
          onSmsBulkSelected: onSmsBulkSelected,
          onSmsTemplatesSelected: onSmsTemplatesSelected,
          onSmsContactsSelected: onSmsContactsSelected,
          onSmsSettingsSelected: onSmsSettingsSelected,
          onWhatsappMessagingSelected: onWhatsappMessagingSelected,
          onWhatsappBulkSelected: onWhatsappBulkSelected,
          onWhatsappTemplatesSelected: onWhatsappTemplatesSelected,
          onWhatsappContactsSelected: onWhatsappContactsSelected,
          onWhatsappSettingsSelected: onWhatsappSettingsSelected,
          onSocialPublishSelected: onSocialPublishSelected,
          onSocialAccountsSelected: onSocialAccountsSelected,
          onSocialSettingsSelected: onSocialSettingsSelected,
          onNavigationSelected: onNavigationSelected,
          onUsersSelected: onUsersSelected,
          onRolesPermissionsSelected: onRolesPermissionsSelected,
          onStorageSettingsSelected: onStorageSettingsSelected,
          onGoogleNewsSelected: onGoogleNewsSelected,
          onAiSettingsSelected: onAiSettingsSelected,
          onMarketSettingsSelected: onMarketSettingsSelected,
          onAnnouncementsSettingsSelected: onAnnouncementsSettingsSelected,
          onPharmacySettingsSelected: onPharmacySettingsSelected,
          onWeatherSettingsSelected: onWeatherSettingsSelected,
          onPrayerSettingsSelected: onPrayerSettingsSelected,
          onDeathNoticeSettingsSelected: onDeathNoticeSettingsSelected,
          onGeneralSettingsSelected: onGeneralSettingsSelected,
          onSecuritySettingsSelected: onSecuritySettingsSelected,
          onContentSettingsSelected: onContentSettingsSelected,
          onFontSettingsSelected: onFontSettingsSelected,
          onLanguageSettingsSelected: onLanguageSettingsSelected,
        ),
      ),
    );
  }
}

class Sidebar extends StatefulWidget {
  const Sidebar({
    super.key,
    required this.onLogout,
    required this.homeVisible,
    required this.newsVisible,
    required this.storiesVisible,
    required this.pagesVisible,
    required this.commentsVisible,
    required this.subscribersVisible,
    required this.notificationsVisible,
    required this.mailInboxVisible,
    required this.bulkMailVisible,
    required this.mailTemplatesVisible,
    required this.contactListsVisible,
    required this.mailSettingsVisible,
    required this.smsVisible,
    required this.whatsappVisible,
    required this.socialMediaVisible,
    required this.navigationVisible,
    required this.usersVisible,
    required this.rolesPermissionsVisible,
    required this.storageSettingsVisible,
    required this.googleNewsVisible,
    required this.aiSettingsVisible,
    required this.marketSettingsVisible,
    required this.announcementsSettingsVisible,
    required this.pharmacySettingsVisible,
    required this.weatherSettingsVisible,
    required this.prayerSettingsVisible,
    required this.deathNoticeSettingsVisible,
    required this.generalSettingsVisible,
    required this.securitySettingsVisible,
    required this.contentSettingsVisible,
    required this.fontSettingsVisible,
    required this.languageSettingsVisible,
    required this.homeSelected,
    required this.newsAddSelected,
    required this.newsSelected,
    required this.storiesSelected,
    required this.pagesSelected,
    required this.commentsSelected,
    required this.subscribersSelected,
    required this.notificationCampaignsSelected,
    required this.notificationTemplatesSelected,
    required this.notificationDevicesSelected,
    required this.notificationSettingsSelected,
    required this.mailInboxSelected,
    required this.bulkMailSelected,
    required this.mailTemplatesSelected,
    required this.contactListsSelected,
    required this.mailSettingsSelected,
    required this.smsOutboxSelected,
    required this.smsBulkSelected,
    required this.smsTemplatesSelected,
    required this.smsContactsSelected,
    required this.smsSettingsSelected,
    required this.whatsappMessagingSelected,
    required this.whatsappBulkSelected,
    required this.whatsappTemplatesSelected,
    required this.whatsappContactsSelected,
    required this.whatsappSettingsSelected,
    required this.socialPublishSelected,
    required this.socialAccountsSelected,
    required this.socialSettingsSelected,
    required this.navigationSelected,
    required this.usersSelected,
    required this.rolesPermissionsSelected,
    required this.storageSettingsSelected,
    required this.googleNewsSelected,
    required this.aiSettingsSelected,
    required this.marketSettingsSelected,
    required this.announcementsSettingsSelected,
    required this.pharmacySettingsSelected,
    required this.weatherSettingsSelected,
    required this.prayerSettingsSelected,
    required this.deathNoticeSettingsSelected,
    required this.generalSettingsSelected,
    required this.securitySettingsSelected,
    required this.contentSettingsSelected,
    required this.fontSettingsSelected,
    required this.languageSettingsSelected,
    required this.onHomeSelected,
    required this.onNewsAddSelected,
    required this.onNewsSelected,
    required this.onStoriesSelected,
    required this.onPagesSelected,
    required this.onCommentsSelected,
    required this.onSubscribersSelected,
    required this.onNotificationCampaignsSelected,
    required this.onNotificationTemplatesSelected,
    required this.onNotificationDevicesSelected,
    required this.onNotificationSettingsSelected,
    required this.onMailInboxSelected,
    required this.onBulkMailSelected,
    required this.onMailTemplatesSelected,
    required this.onContactListsSelected,
    required this.onMailSettingsSelected,
    required this.onSmsOutboxSelected,
    required this.onSmsBulkSelected,
    required this.onSmsTemplatesSelected,
    required this.onSmsContactsSelected,
    required this.onSmsSettingsSelected,
    required this.onWhatsappMessagingSelected,
    required this.onWhatsappBulkSelected,
    required this.onWhatsappTemplatesSelected,
    required this.onWhatsappContactsSelected,
    required this.onWhatsappSettingsSelected,
    required this.onSocialPublishSelected,
    required this.onSocialAccountsSelected,
    required this.onSocialSettingsSelected,
    required this.onNavigationSelected,
    required this.onUsersSelected,
    required this.onRolesPermissionsSelected,
    required this.onStorageSettingsSelected,
    required this.onGoogleNewsSelected,
    required this.onAiSettingsSelected,
    required this.onMarketSettingsSelected,
    required this.onAnnouncementsSettingsSelected,
    required this.onPharmacySettingsSelected,
    required this.onWeatherSettingsSelected,
    required this.onPrayerSettingsSelected,
    required this.onDeathNoticeSettingsSelected,
    required this.onGeneralSettingsSelected,
    required this.onSecuritySettingsSelected,
    required this.onContentSettingsSelected,
    required this.onFontSettingsSelected,
    required this.onLanguageSettingsSelected,
    this.drawerMode = false,
  });

  final VoidCallback onLogout;
  final bool homeVisible;
  final bool newsVisible;
  final bool storiesVisible;
  final bool pagesVisible;
  final bool commentsVisible;
  final bool subscribersVisible;
  final bool notificationsVisible;
  final bool mailInboxVisible;
  final bool bulkMailVisible;
  final bool mailTemplatesVisible;
  final bool contactListsVisible;
  final bool mailSettingsVisible;
  final bool smsVisible;
  final bool whatsappVisible;
  final bool socialMediaVisible;
  final bool navigationVisible;
  final bool usersVisible;
  final bool rolesPermissionsVisible;
  final bool storageSettingsVisible;
  final bool googleNewsVisible;
  final bool aiSettingsVisible;
  final bool marketSettingsVisible;
  final bool announcementsSettingsVisible;
  final bool pharmacySettingsVisible;
  final bool weatherSettingsVisible;
  final bool prayerSettingsVisible;
  final bool deathNoticeSettingsVisible;
  final bool generalSettingsVisible;
  final bool securitySettingsVisible;
  final bool contentSettingsVisible;
  final bool fontSettingsVisible;
  final bool languageSettingsVisible;
  final bool homeSelected;
  final bool newsAddSelected;
  final bool newsSelected;
  final bool storiesSelected;
  final bool pagesSelected;
  final bool commentsSelected;
  final bool subscribersSelected;
  final bool notificationCampaignsSelected;
  final bool notificationTemplatesSelected;
  final bool notificationDevicesSelected;
  final bool notificationSettingsSelected;
  final bool mailInboxSelected;
  final bool bulkMailSelected;
  final bool mailTemplatesSelected;
  final bool contactListsSelected;
  final bool mailSettingsSelected;
  final bool smsOutboxSelected;
  final bool smsBulkSelected;
  final bool smsTemplatesSelected;
  final bool smsContactsSelected;
  final bool smsSettingsSelected;
  final bool whatsappMessagingSelected;
  final bool whatsappBulkSelected;
  final bool whatsappTemplatesSelected;
  final bool whatsappContactsSelected;
  final bool whatsappSettingsSelected;
  final bool socialPublishSelected;
  final bool socialAccountsSelected;
  final bool socialSettingsSelected;
  final bool navigationSelected;
  final bool usersSelected;
  final bool rolesPermissionsSelected;
  final bool storageSettingsSelected;
  final bool googleNewsSelected;
  final bool aiSettingsSelected;
  final bool marketSettingsSelected;
  final bool announcementsSettingsSelected;
  final bool pharmacySettingsSelected;
  final bool weatherSettingsSelected;
  final bool prayerSettingsSelected;
  final bool deathNoticeSettingsSelected;
  final bool generalSettingsSelected;
  final bool securitySettingsSelected;
  final bool contentSettingsSelected;
  final bool fontSettingsSelected;
  final bool languageSettingsSelected;
  final VoidCallback onHomeSelected;
  final VoidCallback onNewsAddSelected;
  final VoidCallback onNewsSelected;
  final VoidCallback onStoriesSelected;
  final VoidCallback onPagesSelected;
  final VoidCallback onCommentsSelected;
  final VoidCallback onSubscribersSelected;
  final VoidCallback onNotificationCampaignsSelected;
  final VoidCallback onNotificationTemplatesSelected;
  final VoidCallback onNotificationDevicesSelected;
  final VoidCallback onNotificationSettingsSelected;
  final VoidCallback onMailInboxSelected;
  final VoidCallback onBulkMailSelected;
  final VoidCallback onMailTemplatesSelected;
  final VoidCallback onContactListsSelected;
  final VoidCallback onMailSettingsSelected;
  final VoidCallback onSmsOutboxSelected;
  final VoidCallback onSmsBulkSelected;
  final VoidCallback onSmsTemplatesSelected;
  final VoidCallback onSmsContactsSelected;
  final VoidCallback onSmsSettingsSelected;
  final VoidCallback onWhatsappMessagingSelected;
  final VoidCallback onWhatsappBulkSelected;
  final VoidCallback onWhatsappTemplatesSelected;
  final VoidCallback onWhatsappContactsSelected;
  final VoidCallback onWhatsappSettingsSelected;
  final VoidCallback onSocialPublishSelected;
  final VoidCallback onSocialAccountsSelected;
  final VoidCallback onSocialSettingsSelected;
  final VoidCallback onNavigationSelected;
  final VoidCallback onUsersSelected;
  final VoidCallback onRolesPermissionsSelected;
  final VoidCallback onStorageSettingsSelected;
  final VoidCallback onGoogleNewsSelected;
  final VoidCallback onAiSettingsSelected;
  final VoidCallback onMarketSettingsSelected;
  final VoidCallback onAnnouncementsSettingsSelected;
  final VoidCallback onPharmacySettingsSelected;
  final VoidCallback onWeatherSettingsSelected;
  final VoidCallback onPrayerSettingsSelected;
  final VoidCallback onDeathNoticeSettingsSelected;
  final VoidCallback onGeneralSettingsSelected;
  final VoidCallback onSecuritySettingsSelected;
  final VoidCallback onContentSettingsSelected;
  final VoidCallback onFontSettingsSelected;
  final VoidCallback onLanguageSettingsSelected;
  final bool drawerMode;

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  static const double _expandedWidth = 304;
  static const double _collapsedWidth = 104;
  static const _sidebarAnimationDuration = Duration(milliseconds: 180);

  static const _mailGroup = 'mail';
  static const _notificationsGroup = 'notifications';
  static const _smsGroup = 'sms';
  static const _whatsappGroup = 'whatsapp';
  static const _socialGroup = 'social';
  static const _modulesGroup = 'modules';
  static const _settingsGroup = 'settings';

  Timer? _autoCollapseTimer;
  String? _openExpandable;
  var _autoCollapsed = false;
  var _hovering = false;
  var _hoverSuppressed = false;
  var _pinnedOpen = false;

  @override
  void initState() {
    super.initState();
    _openExpandable = _selectedExpandable;
  }

  @override
  void didUpdateWidget(covariant Sidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selected = _selectedExpandable;
    if (selected != _selectedExpandableFor(oldWidget)) {
      _autoCollapseTimer?.cancel();
      _openExpandable = selected;
    } else if (selected != null && _openExpandable != selected) {
      _autoCollapseTimer?.cancel();
      _openExpandable = selected;
    }
  }

  @override
  void dispose() {
    _autoCollapseTimer?.cancel();
    super.dispose();
  }

  String? get _selectedExpandable => _selectedExpandableFor(widget);

  String? _selectedExpandableFor(Sidebar data) {
    if (data.notificationCampaignsSelected ||
        data.notificationTemplatesSelected ||
        data.notificationDevicesSelected ||
        data.notificationSettingsSelected) {
      return _notificationsGroup;
    }
    if (data.mailInboxSelected ||
        data.bulkMailSelected ||
        data.mailTemplatesSelected ||
        data.contactListsSelected ||
        data.mailSettingsSelected) {
      return _mailGroup;
    }
    if (data.smsOutboxSelected ||
        data.smsBulkSelected ||
        data.smsTemplatesSelected ||
        data.smsContactsSelected ||
        data.smsSettingsSelected) {
      return _smsGroup;
    }
    if (data.whatsappMessagingSelected ||
        data.whatsappBulkSelected ||
        data.whatsappTemplatesSelected ||
        data.whatsappContactsSelected ||
        data.whatsappSettingsSelected) {
      return _whatsappGroup;
    }
    if (data.socialPublishSelected ||
        data.socialAccountsSelected ||
        data.socialSettingsSelected) {
      return _socialGroup;
    }
    if (data.storageSettingsSelected ||
        data.googleNewsSelected ||
        data.aiSettingsSelected ||
        data.marketSettingsSelected ||
        data.announcementsSettingsSelected ||
        data.pharmacySettingsSelected ||
        data.weatherSettingsSelected ||
        data.prayerSettingsSelected ||
        data.deathNoticeSettingsSelected) {
      return _modulesGroup;
    }
    if (data.generalSettingsSelected ||
        data.securitySettingsSelected ||
        data.contentSettingsSelected ||
        data.fontSettingsSelected ||
        data.languageSettingsSelected) {
      return _settingsGroup;
    }
    return null;
  }

  void _handleExpandableTap(String group) {
    final selected = _selectedExpandable;
    _autoCollapseTimer?.cancel();

    setState(() {
      if (_openExpandable == group && selected != group) {
        _openExpandable = selected;
      } else {
        _openExpandable = group;
      }
    });

    _scheduleAutoCollapse(group);
  }

  void _scheduleAutoCollapse(String group) {
    if (_selectedExpandable == group || _openExpandable != group) return;
    _autoCollapseTimer = Timer(const Duration(seconds: 20), () {
      if (!mounted ||
          _openExpandable != group ||
          _selectedExpandable == group) {
        return;
      }
      setState(() => _openExpandable = _selectedExpandable);
    });
  }

  void _select(BuildContext context, VoidCallback callback) {
    callback();
    if (widget.drawerMode) {
      Navigator.maybePop(context);
      return;
    }
    if (!_pinnedOpen) {
      final suppressHover = _hovering;
      setState(() {
        _autoCollapsed = true;
        _hovering = false;
        _hoverSuppressed = suppressHover;
      });
    }
  }

  void _handleHoverEnter(PointerEnterEvent _) {
    if (widget.drawerMode || _pinnedOpen || _hoverSuppressed) return;
    setState(() => _hovering = true);
  }

  void _handleHoverExit(PointerExitEvent _) {
    if (widget.drawerMode) return;
    setState(() {
      _hovering = false;
      _hoverSuppressed = false;
    });
  }

  void _handlePinnedChanged(bool value) {
    final suppressHover = !value && _hovering;
    setState(() {
      _pinnedOpen = value;
      _autoCollapsed = !value;
      _hovering = false;
      _hoverSuppressed = suppressHover;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settingsSelected =
        widget.generalSettingsSelected ||
        widget.securitySettingsSelected ||
        widget.contentSettingsSelected ||
        widget.fontSettingsSelected ||
        widget.languageSettingsSelected;
    final mailSelected =
        widget.mailInboxSelected ||
        widget.bulkMailSelected ||
        widget.mailTemplatesSelected ||
        widget.contactListsSelected ||
        widget.mailSettingsSelected;
    final notificationsSelected =
        widget.notificationCampaignsSelected ||
        widget.notificationTemplatesSelected ||
        widget.notificationDevicesSelected ||
        widget.notificationSettingsSelected;
    final smsSelected =
        widget.smsOutboxSelected ||
        widget.smsBulkSelected ||
        widget.smsTemplatesSelected ||
        widget.smsContactsSelected ||
        widget.smsSettingsSelected;
    final whatsappSelected =
        widget.whatsappMessagingSelected ||
        widget.whatsappBulkSelected ||
        widget.whatsappTemplatesSelected ||
        widget.whatsappContactsSelected ||
        widget.whatsappSettingsSelected;
    final socialSelected =
        widget.socialPublishSelected ||
        widget.socialAccountsSelected ||
        widget.socialSettingsSelected;
    final modulesSelected =
        widget.storageSettingsSelected ||
        widget.googleNewsSelected ||
        widget.aiSettingsSelected ||
        widget.marketSettingsSelected ||
        widget.announcementsSettingsSelected ||
        widget.pharmacySettingsSelected ||
        widget.weatherSettingsSelected ||
        widget.prayerSettingsSelected ||
        widget.deathNoticeSettingsSelected;
    final modulesVisible =
        widget.storageSettingsVisible ||
        widget.googleNewsVisible ||
        widget.aiSettingsVisible ||
        widget.marketSettingsVisible ||
        widget.announcementsSettingsVisible ||
        widget.pharmacySettingsVisible ||
        widget.weatherSettingsVisible ||
        widget.prayerSettingsVisible ||
        widget.deathNoticeSettingsVisible;
    final settingsVisible =
        widget.generalSettingsVisible ||
        widget.securitySettingsVisible ||
        widget.contentSettingsVisible ||
        widget.fontSettingsVisible ||
        widget.languageSettingsVisible;
    final expanded =
        widget.drawerMode || _pinnedOpen || _hovering || !_autoCollapsed;
    final compact = !expanded && !widget.drawerMode;

    final sidebar = AnimatedContainer(
      key: const ValueKey('admin-sidebar'),
      width: widget.drawerMode
          ? null
          : (expanded ? _expandedWidth : _collapsedWidth),
      duration: _sidebarAnimationDuration,
      curve: Curves.easeInOutCubic,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          right: widget.drawerMode
              ? BorderSide.none
              : const BorderSide(color: AppColors.line),
        ),
      ),
      child: ClipRect(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SidebarHeader(
              expanded: expanded,
              pinControlVisible: !widget.drawerMode,
              pinned: _pinnedOpen,
              onPinnedChanged: _handlePinnedChanged,
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 14),
                children: [
                  if (widget.homeVisible)
                    SidebarItem(
                      icon: Symbols.home,
                      label: context.t('nav.home'),
                      selected: widget.homeSelected,
                      compact: compact,
                      onTap: () => _select(context, widget.onHomeSelected),
                    ),
                  if (widget.newsVisible)
                    SidebarItem(
                      icon: Symbols.add,
                      label: context.t('nav.newsAdd'),
                      selected: widget.newsAddSelected,
                      compact: compact,
                      onTap: () => _select(context, widget.onNewsAddSelected),
                    ),
                  if (widget.newsVisible)
                    SidebarItem(
                      icon: Symbols.article,
                      label: context.t('nav.news'),
                      selected: widget.newsSelected,
                      compact: compact,
                      onTap: () => _select(context, widget.onNewsSelected),
                    ),
                  if (widget.storiesVisible)
                    SidebarItem(
                      icon: Symbols.photo_camera,
                      label: context.t('nav.stories'),
                      selected: widget.storiesSelected,
                      compact: compact,
                      onTap: () => _select(context, widget.onStoriesSelected),
                    ),
                  if (widget.commentsVisible)
                    SidebarItem(
                      icon: Symbols.short_text,
                      label: context.t('nav.comments'),
                      selected: widget.commentsSelected,
                      compact: compact,
                      onTap: () => _select(context, widget.onCommentsSelected),
                    ),
                  if (widget.subscribersVisible)
                    SidebarItem(
                      icon: Symbols.group,
                      label: context.t('nav.subscribers'),
                      selected: widget.subscribersSelected,
                      compact: compact,
                      onTap: () =>
                          _select(context, widget.onSubscribersSelected),
                    ),
                  if (widget.notificationsVisible)
                    SidebarExpandableItem(
                      icon: Symbols.notifications,
                      label: context.t('nav.notifications'),
                      selected: notificationsSelected,
                      compact: compact,
                      expanded: _openExpandable == _notificationsGroup,
                      onTap: () => _handleExpandableTap(_notificationsGroup),
                      children: [
                        SidebarSubItem(
                          label: context.t('nav.notifications.campaigns'),
                          selected: widget.notificationCampaignsSelected,
                          onTap: () => _select(
                            context,
                            widget.onNotificationCampaignsSelected,
                          ),
                        ),
                        SidebarSubItem(
                          label: context.t('nav.notifications.templates'),
                          selected: widget.notificationTemplatesSelected,
                          onTap: () => _select(
                            context,
                            widget.onNotificationTemplatesSelected,
                          ),
                        ),
                        SidebarSubItem(
                          label: context.t('nav.notifications.devices'),
                          selected: widget.notificationDevicesSelected,
                          onTap: () => _select(
                            context,
                            widget.onNotificationDevicesSelected,
                          ),
                        ),
                        SidebarSubItem(
                          label: context.t('nav.notifications.settings'),
                          selected: widget.notificationSettingsSelected,
                          onTap: () => _select(
                            context,
                            widget.onNotificationSettingsSelected,
                          ),
                        ),
                      ],
                    ),
                  if (widget.mailInboxVisible ||
                      widget.bulkMailVisible ||
                      widget.mailTemplatesVisible ||
                      widget.contactListsVisible ||
                      widget.mailSettingsVisible)
                    SidebarExpandableItem(
                      icon: Symbols.alternate_email,
                      label: context.t('nav.mail'),
                      selected: mailSelected,
                      compact: compact,
                      expanded: _openExpandable == _mailGroup,
                      onTap: () => _handleExpandableTap(_mailGroup),
                      children: [
                        if (widget.mailInboxVisible)
                          SidebarSubItem(
                            label: context.t('nav.mail.inbox'),
                            selected: widget.mailInboxSelected,
                            onTap: () =>
                                _select(context, widget.onMailInboxSelected),
                          ),
                        if (widget.bulkMailVisible)
                          SidebarSubItem(
                            label: context.t('nav.mail.campaigns'),
                            selected: widget.bulkMailSelected,
                            onTap: () =>
                                _select(context, widget.onBulkMailSelected),
                          ),
                        if (widget.mailTemplatesVisible)
                          SidebarSubItem(
                            label: context.t('nav.mail.templates'),
                            selected: widget.mailTemplatesSelected,
                            onTap: () => _select(
                              context,
                              widget.onMailTemplatesSelected,
                            ),
                          ),
                        if (widget.contactListsVisible)
                          SidebarSubItem(
                            label: context.t('nav.mail.contacts'),
                            selected: widget.contactListsSelected,
                            onTap: () =>
                                _select(context, widget.onContactListsSelected),
                          ),
                        if (widget.mailSettingsVisible)
                          SidebarSubItem(
                            label: context.t('nav.mail.settings'),
                            selected: widget.mailSettingsSelected,
                            onTap: () =>
                                _select(context, widget.onMailSettingsSelected),
                          ),
                      ],
                    ),
                  if (widget.whatsappVisible)
                    SidebarExpandableItem(
                      icon: Symbols.chat_bubble_outline,
                      label: context.t('nav.whatsapp'),
                      selected: whatsappSelected,
                      compact: compact,
                      expanded: _openExpandable == _whatsappGroup,
                      onTap: () => _handleExpandableTap(_whatsappGroup),
                      children: [
                        SidebarSubItem(
                          label: context.t('nav.whatsapp.messaging'),
                          selected: widget.whatsappMessagingSelected,
                          onTap: () => _select(
                            context,
                            widget.onWhatsappMessagingSelected,
                          ),
                        ),
                        SidebarSubItem(
                          label: context.t('nav.whatsapp.bulk'),
                          selected: widget.whatsappBulkSelected,
                          onTap: () =>
                              _select(context, widget.onWhatsappBulkSelected),
                        ),
                        SidebarSubItem(
                          label: context.t('nav.whatsapp.templates'),
                          selected: widget.whatsappTemplatesSelected,
                          onTap: () => _select(
                            context,
                            widget.onWhatsappTemplatesSelected,
                          ),
                        ),
                        SidebarSubItem(
                          label: context.t('nav.whatsapp.contacts'),
                          selected: widget.whatsappContactsSelected,
                          onTap: () => _select(
                            context,
                            widget.onWhatsappContactsSelected,
                          ),
                        ),
                        SidebarSubItem(
                          label: context.t('nav.whatsapp.settings'),
                          selected: widget.whatsappSettingsSelected,
                          onTap: () => _select(
                            context,
                            widget.onWhatsappSettingsSelected,
                          ),
                        ),
                      ],
                    ),
                  if (widget.socialMediaVisible)
                    SidebarExpandableItem(
                      icon: Symbols.alternate_email,
                      label: context.t('nav.socialMedia'),
                      selected: socialSelected,
                      compact: compact,
                      expanded: _openExpandable == _socialGroup,
                      onTap: () => _handleExpandableTap(_socialGroup),
                      children: [
                        SidebarSubItem(
                          label: context.t('nav.socialPublish'),
                          selected: widget.socialPublishSelected,
                          onTap: () =>
                              _select(context, widget.onSocialPublishSelected),
                        ),
                        SidebarSubItem(
                          label: context.t('nav.socialAccountsAdd'),
                          selected: widget.socialAccountsSelected,
                          onTap: () =>
                              _select(context, widget.onSocialAccountsSelected),
                        ),
                        SidebarSubItem(
                          label: context.t('nav.socialSettings'),
                          selected: widget.socialSettingsSelected,
                          onTap: () =>
                              _select(context, widget.onSocialSettingsSelected),
                        ),
                      ],
                    ),
                  if (widget.smsVisible)
                    SidebarExpandableItem(
                      icon: Symbols.sms_outlined,
                      label: context.t('nav.sms'),
                      selected: smsSelected,
                      compact: compact,
                      expanded: _openExpandable == _smsGroup,
                      onTap: () => _handleExpandableTap(_smsGroup),
                      children: [
                        SidebarSubItem(
                          label: context.t('nav.sms.outbox'),
                          selected: widget.smsOutboxSelected,
                          onTap: () =>
                              _select(context, widget.onSmsOutboxSelected),
                        ),
                        SidebarSubItem(
                          label: context.t('nav.sms.bulk'),
                          selected: widget.smsBulkSelected,
                          onTap: () =>
                              _select(context, widget.onSmsBulkSelected),
                        ),
                        SidebarSubItem(
                          label: context.t('nav.sms.templates'),
                          selected: widget.smsTemplatesSelected,
                          onTap: () =>
                              _select(context, widget.onSmsTemplatesSelected),
                        ),
                        SidebarSubItem(
                          label: context.t('nav.sms.contacts'),
                          selected: widget.smsContactsSelected,
                          onTap: () =>
                              _select(context, widget.onSmsContactsSelected),
                        ),
                        SidebarSubItem(
                          label: context.t('nav.sms.settings'),
                          selected: widget.smsSettingsSelected,
                          onTap: () =>
                              _select(context, widget.onSmsSettingsSelected),
                        ),
                      ],
                    ),
                  if (widget.pagesVisible)
                    SidebarItem(
                      icon: Symbols.draft,
                      label: context.t('nav.pages'),
                      selected: widget.pagesSelected,
                      compact: compact,
                      onTap: () => _select(context, widget.onPagesSelected),
                    ),
                  if (widget.navigationVisible)
                    SidebarItem(
                      icon: Symbols.format_list_numbered,
                      label: context.t('nav.navigation'),
                      selected: widget.navigationSelected,
                      compact: compact,
                      onTap: () =>
                          _select(context, widget.onNavigationSelected),
                    ),
                  if (widget.usersVisible)
                    SidebarItem(
                      icon: Symbols.group,
                      label: context.t('nav.users'),
                      selected: widget.usersSelected,
                      compact: compact,
                      onTap: () => _select(context, widget.onUsersSelected),
                    ),
                  if (widget.rolesPermissionsVisible)
                    SidebarItem(
                      icon: Symbols.verified,
                      label: context.t('nav.roles'),
                      selected: widget.rolesPermissionsSelected,
                      compact: compact,
                      onTap: () =>
                          _select(context, widget.onRolesPermissionsSelected),
                    ),
                  if (modulesVisible)
                    SidebarExpandableItem(
                      icon: Symbols.pending_actions,
                      label: context.t('nav.modules'),
                      selected: modulesSelected,
                      compact: compact,
                      expanded: _openExpandable == _modulesGroup,
                      onTap: () => _handleExpandableTap(_modulesGroup),
                      children: [
                        if (widget.storageSettingsVisible)
                          SidebarSubItem(
                            label: context.t('nav.storageSettings'),
                            selected: widget.storageSettingsSelected,
                            onTap: () => _select(
                              context,
                              widget.onStorageSettingsSelected,
                            ),
                          ),
                        if (widget.googleNewsVisible)
                          SidebarSubItem(
                            label: context.t('nav.googleNews'),
                            selected: widget.googleNewsSelected,
                            onTap: () =>
                                _select(context, widget.onGoogleNewsSelected),
                          ),
                        if (widget.aiSettingsVisible)
                          SidebarSubItem(
                            label: context.t('nav.aiSettings'),
                            selected: widget.aiSettingsSelected,
                            onTap: () =>
                                _select(context, widget.onAiSettingsSelected),
                          ),
                        if (widget.marketSettingsVisible)
                          SidebarSubItem(
                            label: context.t('nav.marketSettings'),
                            selected: widget.marketSettingsSelected,
                            onTap: () => _select(
                              context,
                              widget.onMarketSettingsSelected,
                            ),
                          ),
                        if (widget.pharmacySettingsVisible)
                          SidebarSubItem(
                            label: context.t('nav.pharmacySettings'),
                            selected: widget.pharmacySettingsSelected,
                            onTap: () => _select(
                              context,
                              widget.onPharmacySettingsSelected,
                            ),
                          ),
                        if (widget.weatherSettingsVisible)
                          SidebarSubItem(
                            label: context.t('nav.weatherSettings'),
                            selected: widget.weatherSettingsSelected,
                            onTap: () => _select(
                              context,
                              widget.onWeatherSettingsSelected,
                            ),
                          ),
                        if (widget.prayerSettingsVisible)
                          SidebarSubItem(
                            label: context.t('nav.prayerSettings'),
                            selected: widget.prayerSettingsSelected,
                            onTap: () => _select(
                              context,
                              widget.onPrayerSettingsSelected,
                            ),
                          ),
                        if (widget.deathNoticeSettingsVisible)
                          SidebarSubItem(
                            label: context.t('nav.deathNoticeSettings'),
                            selected: widget.deathNoticeSettingsSelected,
                            onTap: () => _select(
                              context,
                              widget.onDeathNoticeSettingsSelected,
                            ),
                          ),
                        if (widget.announcementsSettingsVisible)
                          SidebarSubItem(
                            label: context.t('nav.announcementsSettings'),
                            selected: widget.announcementsSettingsSelected,
                            onTap: () => _select(
                              context,
                              widget.onAnnouncementsSettingsSelected,
                            ),
                          ),
                      ],
                    ),
                  if (settingsVisible)
                    SidebarExpandableItem(
                      icon: Symbols.menu,
                      label: context.t('nav.settings'),
                      selected: settingsSelected,
                      compact: compact,
                      expanded: _openExpandable == _settingsGroup,
                      onTap: () => _handleExpandableTap(_settingsGroup),
                      children: [
                        if (widget.generalSettingsVisible)
                          SidebarSubItem(
                            label: context.t('nav.generalSettings'),
                            selected: widget.generalSettingsSelected,
                            onTap: () => _select(
                              context,
                              widget.onGeneralSettingsSelected,
                            ),
                          ),
                        if (widget.securitySettingsVisible)
                          SidebarSubItem(
                            label: context.t('nav.securitySettings'),
                            selected: widget.securitySettingsSelected,
                            onTap: () => _select(
                              context,
                              widget.onSecuritySettingsSelected,
                            ),
                          ),
                        if (widget.contentSettingsVisible)
                          SidebarSubItem(
                            label: context.t('nav.contentSettings'),
                            selected: widget.contentSettingsSelected,
                            onTap: () => _select(
                              context,
                              widget.onContentSettingsSelected,
                            ),
                          ),
                        if (widget.fontSettingsVisible)
                          SidebarSubItem(
                            label: context.t('nav.fontSettings'),
                            selected: widget.fontSettingsSelected,
                            onTap: () =>
                                _select(context, widget.onFontSettingsSelected),
                          ),
                        if (widget.languageSettingsVisible)
                          SidebarSubItem(
                            label: context.t('nav.languageSettings'),
                            selected: widget.languageSettingsSelected,
                            onTap: () => _select(
                              context,
                              widget.onLanguageSettingsSelected,
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (widget.drawerMode) return sidebar;
    return MouseRegion(
      onEnter: _handleHoverEnter,
      onExit: _handleHoverExit,
      child: sidebar,
    );
  }
}
