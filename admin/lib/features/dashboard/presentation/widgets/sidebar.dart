import 'dart:async';

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
    required this.commentsVisible,
    required this.mailInboxVisible,
    required this.bulkMailVisible,
    required this.mailTemplatesVisible,
    required this.contactListsVisible,
    required this.mailSettingsVisible,
    required this.whatsappVisible,
    required this.navigationVisible,
    required this.usersVisible,
    required this.rolesPermissionsVisible,
    required this.aiSettingsVisible,
    required this.pharmacySettingsVisible,
    required this.weatherSettingsVisible,
    required this.deathNoticeSettingsVisible,
    required this.generalSettingsVisible,
    required this.languageSettingsVisible,
    required this.homeSelected,
    required this.newsSelected,
    required this.commentsSelected,
    required this.mailInboxSelected,
    required this.bulkMailSelected,
    required this.mailTemplatesSelected,
    required this.contactListsSelected,
    required this.mailSettingsSelected,
    required this.whatsappMessagingSelected,
    required this.navigationSelected,
    required this.usersSelected,
    required this.rolesPermissionsSelected,
    required this.aiSettingsSelected,
    required this.pharmacySettingsSelected,
    required this.weatherSettingsSelected,
    required this.deathNoticeSettingsSelected,
    required this.generalSettingsSelected,
    required this.languageSettingsSelected,
    required this.onHomeSelected,
    required this.onNewsSelected,
    required this.onCommentsSelected,
    required this.onMailInboxSelected,
    required this.onBulkMailSelected,
    required this.onMailTemplatesSelected,
    required this.onContactListsSelected,
    required this.onMailSettingsSelected,
    required this.onWhatsappMessagingSelected,
    required this.onNavigationSelected,
    required this.onUsersSelected,
    required this.onRolesPermissionsSelected,
    required this.onAiSettingsSelected,
    required this.onPharmacySettingsSelected,
    required this.onWeatherSettingsSelected,
    required this.onDeathNoticeSettingsSelected,
    required this.onGeneralSettingsSelected,
    required this.onLanguageSettingsSelected,
  });

  final VoidCallback onLogout;
  final bool homeVisible;
  final bool newsVisible;
  final bool commentsVisible;
  final bool mailInboxVisible;
  final bool bulkMailVisible;
  final bool mailTemplatesVisible;
  final bool contactListsVisible;
  final bool mailSettingsVisible;
  final bool whatsappVisible;
  final bool navigationVisible;
  final bool usersVisible;
  final bool rolesPermissionsVisible;
  final bool aiSettingsVisible;
  final bool pharmacySettingsVisible;
  final bool weatherSettingsVisible;
  final bool deathNoticeSettingsVisible;
  final bool generalSettingsVisible;
  final bool languageSettingsVisible;
  final bool homeSelected;
  final bool newsSelected;
  final bool commentsSelected;
  final bool mailInboxSelected;
  final bool bulkMailSelected;
  final bool mailTemplatesSelected;
  final bool contactListsSelected;
  final bool mailSettingsSelected;
  final bool whatsappMessagingSelected;
  final bool navigationSelected;
  final bool usersSelected;
  final bool rolesPermissionsSelected;
  final bool aiSettingsSelected;
  final bool pharmacySettingsSelected;
  final bool weatherSettingsSelected;
  final bool deathNoticeSettingsSelected;
  final bool generalSettingsSelected;
  final bool languageSettingsSelected;
  final VoidCallback onHomeSelected;
  final VoidCallback onNewsSelected;
  final VoidCallback onCommentsSelected;
  final VoidCallback onMailInboxSelected;
  final VoidCallback onBulkMailSelected;
  final VoidCallback onMailTemplatesSelected;
  final VoidCallback onContactListsSelected;
  final VoidCallback onMailSettingsSelected;
  final VoidCallback onWhatsappMessagingSelected;
  final VoidCallback onNavigationSelected;
  final VoidCallback onUsersSelected;
  final VoidCallback onRolesPermissionsSelected;
  final VoidCallback onAiSettingsSelected;
  final VoidCallback onPharmacySettingsSelected;
  final VoidCallback onWeatherSettingsSelected;
  final VoidCallback onDeathNoticeSettingsSelected;
  final VoidCallback onGeneralSettingsSelected;
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
          commentsVisible: commentsVisible,
          mailInboxVisible: mailInboxVisible,
          bulkMailVisible: bulkMailVisible,
          mailTemplatesVisible: mailTemplatesVisible,
          contactListsVisible: contactListsVisible,
          mailSettingsVisible: mailSettingsVisible,
          whatsappVisible: whatsappVisible,
          navigationVisible: navigationVisible,
          usersVisible: usersVisible,
          rolesPermissionsVisible: rolesPermissionsVisible,
          aiSettingsVisible: aiSettingsVisible,
          pharmacySettingsVisible: pharmacySettingsVisible,
          weatherSettingsVisible: weatherSettingsVisible,
          deathNoticeSettingsVisible: deathNoticeSettingsVisible,
          generalSettingsVisible: generalSettingsVisible,
          languageSettingsVisible: languageSettingsVisible,
          homeSelected: homeSelected,
          newsSelected: newsSelected,
          commentsSelected: commentsSelected,
          mailInboxSelected: mailInboxSelected,
          bulkMailSelected: bulkMailSelected,
          mailTemplatesSelected: mailTemplatesSelected,
          contactListsSelected: contactListsSelected,
          mailSettingsSelected: mailSettingsSelected,
          whatsappMessagingSelected: whatsappMessagingSelected,
          navigationSelected: navigationSelected,
          usersSelected: usersSelected,
          rolesPermissionsSelected: rolesPermissionsSelected,
          aiSettingsSelected: aiSettingsSelected,
          pharmacySettingsSelected: pharmacySettingsSelected,
          weatherSettingsSelected: weatherSettingsSelected,
          deathNoticeSettingsSelected: deathNoticeSettingsSelected,
          generalSettingsSelected: generalSettingsSelected,
          languageSettingsSelected: languageSettingsSelected,
          onHomeSelected: onHomeSelected,
          onNewsSelected: onNewsSelected,
          onCommentsSelected: onCommentsSelected,
          onMailInboxSelected: onMailInboxSelected,
          onBulkMailSelected: onBulkMailSelected,
          onMailTemplatesSelected: onMailTemplatesSelected,
          onContactListsSelected: onContactListsSelected,
          onMailSettingsSelected: onMailSettingsSelected,
          onWhatsappMessagingSelected: onWhatsappMessagingSelected,
          onNavigationSelected: onNavigationSelected,
          onUsersSelected: onUsersSelected,
          onRolesPermissionsSelected: onRolesPermissionsSelected,
          onAiSettingsSelected: onAiSettingsSelected,
          onPharmacySettingsSelected: onPharmacySettingsSelected,
          onWeatherSettingsSelected: onWeatherSettingsSelected,
          onDeathNoticeSettingsSelected: onDeathNoticeSettingsSelected,
          onGeneralSettingsSelected: onGeneralSettingsSelected,
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
    required this.commentsVisible,
    required this.mailInboxVisible,
    required this.bulkMailVisible,
    required this.mailTemplatesVisible,
    required this.contactListsVisible,
    required this.mailSettingsVisible,
    required this.whatsappVisible,
    required this.navigationVisible,
    required this.usersVisible,
    required this.rolesPermissionsVisible,
    required this.aiSettingsVisible,
    required this.pharmacySettingsVisible,
    required this.weatherSettingsVisible,
    required this.deathNoticeSettingsVisible,
    required this.generalSettingsVisible,
    required this.languageSettingsVisible,
    required this.homeSelected,
    required this.newsSelected,
    required this.commentsSelected,
    required this.mailInboxSelected,
    required this.bulkMailSelected,
    required this.mailTemplatesSelected,
    required this.contactListsSelected,
    required this.mailSettingsSelected,
    required this.whatsappMessagingSelected,
    required this.navigationSelected,
    required this.usersSelected,
    required this.rolesPermissionsSelected,
    required this.aiSettingsSelected,
    required this.pharmacySettingsSelected,
    required this.weatherSettingsSelected,
    required this.deathNoticeSettingsSelected,
    required this.generalSettingsSelected,
    required this.languageSettingsSelected,
    required this.onHomeSelected,
    required this.onNewsSelected,
    required this.onCommentsSelected,
    required this.onMailInboxSelected,
    required this.onBulkMailSelected,
    required this.onMailTemplatesSelected,
    required this.onContactListsSelected,
    required this.onMailSettingsSelected,
    required this.onWhatsappMessagingSelected,
    required this.onNavigationSelected,
    required this.onUsersSelected,
    required this.onRolesPermissionsSelected,
    required this.onAiSettingsSelected,
    required this.onPharmacySettingsSelected,
    required this.onWeatherSettingsSelected,
    required this.onDeathNoticeSettingsSelected,
    required this.onGeneralSettingsSelected,
    required this.onLanguageSettingsSelected,
    this.drawerMode = false,
  });

  final VoidCallback onLogout;
  final bool homeVisible;
  final bool newsVisible;
  final bool commentsVisible;
  final bool mailInboxVisible;
  final bool bulkMailVisible;
  final bool mailTemplatesVisible;
  final bool contactListsVisible;
  final bool mailSettingsVisible;
  final bool whatsappVisible;
  final bool navigationVisible;
  final bool usersVisible;
  final bool rolesPermissionsVisible;
  final bool aiSettingsVisible;
  final bool pharmacySettingsVisible;
  final bool weatherSettingsVisible;
  final bool deathNoticeSettingsVisible;
  final bool generalSettingsVisible;
  final bool languageSettingsVisible;
  final bool homeSelected;
  final bool newsSelected;
  final bool commentsSelected;
  final bool mailInboxSelected;
  final bool bulkMailSelected;
  final bool mailTemplatesSelected;
  final bool contactListsSelected;
  final bool mailSettingsSelected;
  final bool whatsappMessagingSelected;
  final bool navigationSelected;
  final bool usersSelected;
  final bool rolesPermissionsSelected;
  final bool aiSettingsSelected;
  final bool pharmacySettingsSelected;
  final bool weatherSettingsSelected;
  final bool deathNoticeSettingsSelected;
  final bool generalSettingsSelected;
  final bool languageSettingsSelected;
  final VoidCallback onHomeSelected;
  final VoidCallback onNewsSelected;
  final VoidCallback onCommentsSelected;
  final VoidCallback onMailInboxSelected;
  final VoidCallback onBulkMailSelected;
  final VoidCallback onMailTemplatesSelected;
  final VoidCallback onContactListsSelected;
  final VoidCallback onMailSettingsSelected;
  final VoidCallback onWhatsappMessagingSelected;
  final VoidCallback onNavigationSelected;
  final VoidCallback onUsersSelected;
  final VoidCallback onRolesPermissionsSelected;
  final VoidCallback onAiSettingsSelected;
  final VoidCallback onPharmacySettingsSelected;
  final VoidCallback onWeatherSettingsSelected;
  final VoidCallback onDeathNoticeSettingsSelected;
  final VoidCallback onGeneralSettingsSelected;
  final VoidCallback onLanguageSettingsSelected;
  final bool drawerMode;

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  static const _mailGroup = 'mail';
  static const _whatsappGroup = 'whatsapp';
  static const _modulesGroup = 'modules';
  static const _settingsGroup = 'settings';

  Timer? _autoCollapseTimer;
  String? _openExpandable;

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
    if (data.mailInboxSelected ||
        data.bulkMailSelected ||
        data.mailTemplatesSelected ||
        data.contactListsSelected ||
        data.mailSettingsSelected) {
      return _mailGroup;
    }
    if (data.whatsappMessagingSelected) {
      return _whatsappGroup;
    }
    if (data.aiSettingsSelected ||
        data.pharmacySettingsSelected ||
        data.weatherSettingsSelected ||
        data.deathNoticeSettingsSelected) {
      return _modulesGroup;
    }
    if (data.generalSettingsSelected || data.languageSettingsSelected) {
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsSelected =
        widget.generalSettingsSelected || widget.languageSettingsSelected;
    final mailSelected =
        widget.mailInboxSelected ||
        widget.bulkMailSelected ||
        widget.mailTemplatesSelected ||
        widget.contactListsSelected ||
        widget.mailSettingsSelected;
    final whatsappSelected = widget.whatsappMessagingSelected;
    final modulesSelected =
        widget.aiSettingsSelected ||
        widget.pharmacySettingsSelected ||
        widget.weatherSettingsSelected ||
        widget.deathNoticeSettingsSelected;
    final modulesVisible =
        widget.aiSettingsVisible ||
        widget.pharmacySettingsVisible ||
        widget.weatherSettingsVisible ||
        widget.deathNoticeSettingsVisible;
    final settingsVisible =
        widget.generalSettingsVisible || widget.languageSettingsVisible;

    return Container(
      width: widget.drawerMode ? null : 268,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          right: widget.drawerMode
              ? BorderSide.none
              : const BorderSide(color: AppColors.line),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SidebarHeader(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              children: [
                if (widget.homeVisible)
                  SidebarItem(
                    icon: Symbols.home,
                    label: context.t('nav.home'),
                    selected: widget.homeSelected,
                    onTap: () => _select(context, widget.onHomeSelected),
                  ),
                if (widget.newsVisible)
                  SidebarItem(
                    icon: Symbols.article,
                    label: context.t('nav.news'),
                    selected: widget.newsSelected,
                    onTap: () => _select(context, widget.onNewsSelected),
                  ),
                if (widget.commentsVisible)
                  SidebarItem(
                    icon: Symbols.short_text,
                    label: context.t('nav.comments'),
                    selected: widget.commentsSelected,
                    onTap: () => _select(context, widget.onCommentsSelected),
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
                          onTap: () =>
                              _select(context, widget.onMailTemplatesSelected),
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
                    icon: Icons.chat_bubble_outline,
                    label: context.t('nav.whatsapp'),
                    selected: whatsappSelected,
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
                    ],
                  ),
                if (widget.navigationVisible)
                  SidebarItem(
                    icon: Symbols.format_list_numbered,
                    label: context.t('nav.navigation'),
                    selected: widget.navigationSelected,
                    onTap: () => _select(context, widget.onNavigationSelected),
                  ),
                if (widget.usersVisible)
                  SidebarItem(
                    icon: Symbols.group,
                    label: context.t('nav.users'),
                    selected: widget.usersSelected,
                    onTap: () => _select(context, widget.onUsersSelected),
                  ),
                if (widget.rolesPermissionsVisible)
                  SidebarItem(
                    icon: Symbols.verified,
                    label: context.t('nav.roles'),
                    selected: widget.rolesPermissionsSelected,
                    onTap: () =>
                        _select(context, widget.onRolesPermissionsSelected),
                  ),
                if (modulesVisible)
                  SidebarExpandableItem(
                    icon: Symbols.pending_actions,
                    label: context.t('nav.modules'),
                    selected: modulesSelected,
                    expanded: _openExpandable == _modulesGroup,
                    onTap: () => _handleExpandableTap(_modulesGroup),
                    children: [
                      if (widget.aiSettingsVisible)
                        SidebarSubItem(
                          label: context.t('nav.aiSettings'),
                          selected: widget.aiSettingsSelected,
                          onTap: () =>
                              _select(context, widget.onAiSettingsSelected),
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
                      if (widget.deathNoticeSettingsVisible)
                        SidebarSubItem(
                          label: context.t('nav.deathNoticeSettings'),
                          selected: widget.deathNoticeSettingsSelected,
                          onTap: () => _select(
                            context,
                            widget.onDeathNoticeSettingsSelected,
                          ),
                        ),
                    ],
                  ),
                if (settingsVisible)
                  SidebarExpandableItem(
                    icon: Symbols.menu,
                    label: context.t('nav.settings'),
                    selected: settingsSelected,
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
    );
  }
}
