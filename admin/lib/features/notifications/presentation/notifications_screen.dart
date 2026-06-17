import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/widgets/admin_table_chrome.dart';
import 'package:pateeznews_admin/shared/widgets/admin_toast.dart';

import '../../../core/localization/admin_date_formatter.dart';
import '../../../core/localization/admin_language_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/icons/symbols.dart';
import '../../../shared/widgets/app_confirmation_dialog.dart';
import '../../../shared/widgets/sortable_table_header.dart';
import '../../../shared/widgets/symbol_icon.dart';
import '../../auth/data/admin_auth_models.dart';
import '../data/admin_notifications_repository.dart';
import 'notification_models.dart';

class NotificationCampaignsScreen extends StatelessWidget {
  const NotificationCampaignsScreen({
    super.key,
    required this.session,
    this.repository = const SupabaseAdminNotificationsRepository(),
  });

  final AdminSession session;
  final AdminNotificationsRepository repository;

  @override
  Widget build(BuildContext context) {
    return NotificationsScreen(
      section: AdminNotificationSection.campaigns,
      session: session,
      repository: repository,
    );
  }
}

class NotificationTemplatesScreen extends StatelessWidget {
  const NotificationTemplatesScreen({
    super.key,
    required this.session,
    this.repository = const SupabaseAdminNotificationsRepository(),
  });

  final AdminSession session;
  final AdminNotificationsRepository repository;

  @override
  Widget build(BuildContext context) {
    return NotificationsScreen(
      section: AdminNotificationSection.templates,
      session: session,
      repository: repository,
    );
  }
}

class NotificationDevicesScreen extends StatelessWidget {
  const NotificationDevicesScreen({
    super.key,
    required this.session,
    this.repository = const SupabaseAdminNotificationsRepository(),
  });

  final AdminSession session;
  final AdminNotificationsRepository repository;

  @override
  Widget build(BuildContext context) {
    return NotificationsScreen(
      section: AdminNotificationSection.devices,
      session: session,
      repository: repository,
    );
  }
}

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({
    super.key,
    required this.session,
    this.repository = const SupabaseAdminNotificationsRepository(),
  });

  final AdminSession session;
  final AdminNotificationsRepository repository;

  @override
  Widget build(BuildContext context) {
    return NotificationsScreen(
      section: AdminNotificationSection.settings,
      session: session,
      repository: repository,
    );
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    required this.section,
    required this.session,
    required this.repository,
  });

  final AdminNotificationSection section;
  final AdminSession session;
  final AdminNotificationsRepository repository;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _searchController = TextEditingController();
  var _campaigns = <AdminNotificationCampaign>[];
  var _templates = <AdminNotificationTemplate>[];
  var _devices = <AdminNotificationDevice>[];
  AdminNotificationSettings? _settings;
  var _stats = const AdminNotificationStats();
  var _page = 1;
  var _pageSize = 25;
  var _total = 0;
  var _loading = true;
  var _sortState = const TableSortState(key: 'date', ascending: false);
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant NotificationsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.section != widget.section) {
      _page = 1;
      _searchController.clear();
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final offset = (_page - 1) * _pageSize;
      final search = _searchController.text.trim();
      switch (widget.section) {
        case AdminNotificationSection.campaigns:
          final page = await widget.repository.fetchCampaigns(
            widget.session,
            limit: _pageSize,
            offset: offset,
            search: search,
          );
          if (!mounted) return;
          setState(() {
            _campaigns = page.items;
            _stats = page.stats;
            _total = page.total;
          });
        case AdminNotificationSection.templates:
          final page = await widget.repository.fetchTemplates(
            widget.session,
            limit: _pageSize,
            offset: offset,
            search: search,
          );
          if (!mounted) return;
          setState(() {
            _templates = page.items;
            _stats = page.stats;
            _total = page.total;
          });
        case AdminNotificationSection.devices:
          final page = await widget.repository.fetchDevices(
            widget.session,
            limit: _pageSize,
            offset: offset,
            search: search,
          );
          if (!mounted) return;
          setState(() {
            _devices = page.items;
            _stats = page.stats;
            _total = page.total;
          });
        case AdminNotificationSection.settings:
          final settings = await widget.repository.fetchSettings(
            widget.session,
          );
          if (!mounted) return;
          setState(() {
            _settings = settings ?? _emptySettings();
            _stats = const AdminNotificationStats(total: 1);
            _total = 1;
          });
      }
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  AdminNotificationSettings _emptySettings() {
    return const AdminNotificationSettings(
      id: 0,
      projectId: '',
      clientEmail: '',
      webVapidKey: '',
      apiBaseUrl: 'https://fcm.googleapis.com/v1',
      defaultLanguageCode: 'tr',
      dailyLimit: 100000,
      monthlyLimit: 3000000,
      hourlyLimit: 10000,
      batchSize: 100,
      androidEnabled: true,
      iosEnabled: true,
      flutterWebEnabled: true,
      astroWebEnabled: true,
      tokenVerified: false,
      active: true,
      connectionStatus: 'pending',
      hasPrivateKey: false,
      serverCredentialsConfigured: false,
    );
  }

  void _showError(Object error) {
    AdminToast.show(
      context,
      message: error.toString(),
      tone: AdminToastTone.error,
    );
  }

  void _changeSearch(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 260), () {
      if (!mounted) return;
      setState(() => _page = 1);
      unawaited(_load());
    });
  }

  void _changePageSize(int? value) {
    if (value == null || value == _pageSize) return;
    setState(() {
      _pageSize = value;
      _page = 1;
    });
    unawaited(_load());
  }

  void _changePage(int page) {
    if (page == _page) return;
    setState(() => _page = page);
    unawaited(_load());
  }

  void _changeSort(String key) {
    setState(() => _sortState = _sortState.toggled(key));
  }

  Future<void> _deleteCampaign(AdminNotificationCampaign campaign) async {
    final confirmed = await showAppConfirmationDialog(
      context,
      title: context.t('notifications.deleteTitle'),
      message: context.t('notifications.deleteMessage'),
      confirmLabel: context.t('common.delete'),
      danger: true,
    );
    if (!confirmed || !mounted) return;
    try {
      await widget.repository.deleteCampaigns(widget.session, [campaign.id]);
      if (mounted) unawaited(_load());
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<void> _deleteTemplate(AdminNotificationTemplate template) async {
    final confirmed = await showAppConfirmationDialog(
      context,
      title: context.t('notifications.templates.deleteTitle'),
      message: context.t('notifications.templates.deleteMessage'),
      confirmLabel: context.t('common.delete'),
      danger: true,
    );
    if (!confirmed || !mounted) return;
    try {
      await widget.repository.deleteTemplates(widget.session, [template.id]);
      if (mounted) unawaited(_load());
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<void> _deleteDevice(AdminNotificationDevice device) async {
    final confirmed = await showAppConfirmationDialog(
      context,
      title: context.t('notifications.devices.deleteTitle'),
      message: context.t('notifications.devices.deleteMessage'),
      confirmLabel: context.t('common.delete'),
      danger: true,
    );
    if (!confirmed || !mounted) return;
    try {
      await widget.repository.deleteDevices(widget.session, [device.id]);
      if (mounted) unawaited(_load());
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<void> _campaignAction(
    AdminNotificationCampaign campaign,
    String action,
  ) async {
    try {
      await widget.repository.updateCampaignAction(
        widget.session,
        campaign,
        action,
      );
      if (mounted) unawaited(_load());
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<void> _deviceAction(
    AdminNotificationDevice device,
    String action,
  ) async {
    try {
      await widget.repository.updateDeviceAction(
        widget.session,
        device,
        action,
      );
      if (mounted) unawaited(_load());
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<void> _showCampaignDialog({
    AdminNotificationCampaign? campaign,
  }) async {
    final result = await showDialog<AdminNotificationCampaign>(
      context: context,
      builder: (context) => _CampaignDialog(campaign: campaign),
    );
    if (result == null || !mounted) return;
    try {
      await widget.repository.saveCampaign(
        widget.session,
        id: campaign?.id,
        campaign: result,
      );
      if (mounted) unawaited(_load());
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<void> _showTemplateDialog({
    AdminNotificationTemplate? template,
  }) async {
    final result = await showDialog<AdminNotificationTemplate>(
      context: context,
      builder: (context) => _TemplateDialog(template: template),
    );
    if (result == null || !mounted) return;
    try {
      await widget.repository.saveTemplate(
        widget.session,
        id: template?.id,
        template: result,
      );
      if (mounted) unawaited(_load());
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<void> _saveSettings(
    AdminNotificationSettings settings,
    String privateKey,
  ) async {
    try {
      final saved = await widget.repository.saveSettings(
        widget.session,
        settings: settings,
        privateKey: privateKey,
      );
      if (!mounted) return;
      setState(() => _settings = saved);
      AdminToast.show(
        context,
        message: context.t('notifications.settings.saved'),
        tone: AdminToastTone.success,
      );
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<void> _checkSettings() async {
    final settings = _settings;
    if (settings == null) return;
    try {
      final checked = await widget.repository.checkSettings(
        widget.session,
        settings,
      );
      if (!mounted) return;
      setState(() => _settings = checked);
      AdminToast.show(
        context,
        message: context.t('notifications.settings.checked'),
        tone: checked.tokenVerified
            ? AdminToastTone.success
            : AdminToastTone.info,
      );
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 900;
        final horizontalPadding = constraints.maxWidth < 640 ? 16.0 : 28.0;
        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _NotificationsHeader(section: widget.section),
            const SizedBox(height: 24),
            _MetricGrid(
              section: widget.section,
              stats: _stats,
              settings: _settings,
            ),
            const SizedBox(height: 18),
            if (widget.section == AdminNotificationSection.settings)
              Expanded(
                child: _SettingsPanel(
                  settings: _settings ?? _emptySettings(),
                  onSave: _saveSettings,
                  onCheck: _checkSettings,
                ),
              )
            else ...[
              _Toolbar(
                section: widget.section,
                pageSize: _pageSize,
                searchController: _searchController,
                onPageSizeChanged: _changePageSize,
                onSearchChanged: _changeSearch,
                onRefresh: () => unawaited(_load()),
                onCreate: widget.section == AdminNotificationSection.campaigns
                    ? () => unawaited(_showCampaignDialog())
                    : widget.section == AdminNotificationSection.templates
                    ? () => unawaited(_showTemplateDialog())
                    : null,
              ),
              const SizedBox(height: 18),
              Expanded(child: _buildTable()),
              const SizedBox(height: 16),
              _Footer(
                page: _page,
                pageSize: _pageSize,
                totalCount: _total,
                onPageChanged: _changePage,
              ),
            ],
            if (_loading) const LinearProgressIndicator(minHeight: 2),
          ],
        );

        if (compact) {
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              28,
              horizontalPadding,
              28,
            ),
            child: SizedBox(height: 1040, child: content),
          );
        }

        return Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            28,
            horizontalPadding,
            28,
          ),
          child: content,
        );
      },
    );
  }

  Widget _buildTable() {
    return switch (widget.section) {
      AdminNotificationSection.campaigns => _NotificationTable(
        headers: [
          _TableHeader('notifications.table.campaign', 'name', flex: 3),
          _TableHeader('notifications.table.target', 'target', flex: 2),
          _TableHeader('notifications.table.status', 'status', flex: 2),
          _TableHeader(
            'notifications.table.performance',
            'performance',
            flex: 2,
          ),
          _TableHeader('notifications.table.date', 'date', flex: 2),
        ],
        rows: [
          for (final campaign in _campaigns)
            _CampaignRow(
              campaign: campaign,
              onDispatch: () =>
                  unawaited(_campaignAction(campaign, 'dispatch')),
              onPause: () => unawaited(_campaignAction(campaign, 'pause')),
              onResume: () => unawaited(_campaignAction(campaign, 'resume')),
              onEdit: () => unawaited(_showCampaignDialog(campaign: campaign)),
              onDelete: () => unawaited(_deleteCampaign(campaign)),
            ),
        ],
        sortState: _sortState,
        onSort: _changeSort,
        emptyLabel: 'notifications.empty',
      ),
      AdminNotificationSection.templates => _NotificationTable(
        headers: [
          _TableHeader('notifications.table.template', 'name', flex: 3),
          _TableHeader('notifications.table.content', 'content', flex: 4),
          _TableHeader('notifications.table.language', 'language', flex: 1),
          _TableHeader('notifications.table.status', 'status', flex: 2),
          _TableHeader('notifications.table.date', 'date', flex: 2),
        ],
        rows: [
          for (final template in _templates)
            _TemplateRow(
              template: template,
              onEdit: () => unawaited(_showTemplateDialog(template: template)),
              onDelete: () => unawaited(_deleteTemplate(template)),
            ),
        ],
        sortState: _sortState,
        onSort: _changeSort,
        emptyLabel: 'notifications.templates.empty',
      ),
      AdminNotificationSection.devices => _NotificationTable(
        headers: [
          _TableHeader('notifications.table.device', 'device', flex: 3),
          _TableHeader('notifications.table.token', 'token', flex: 4),
          _TableHeader('notifications.table.permission', 'permission', flex: 2),
          _TableHeader('notifications.table.status', 'status', flex: 2),
          _TableHeader('notifications.table.date', 'date', flex: 2),
        ],
        rows: [
          for (final device in _devices)
            _DeviceRow(
              device: device,
              onActivate: () => unawaited(_deviceAction(device, 'activate')),
              onInvalidate: () =>
                  unawaited(_deviceAction(device, 'invalidate')),
              onDelete: () => unawaited(_deleteDevice(device)),
            ),
        ],
        sortState: _sortState,
        onSort: _changeSort,
        emptyLabel: 'notifications.devices.empty',
      ),
      AdminNotificationSection.settings => const SizedBox.shrink(),
    };
  }
}

class _NotificationsHeader extends StatelessWidget {
  const _NotificationsHeader({required this.section});

  final AdminNotificationSection section;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.t(switch (section) {
            AdminNotificationSection.campaigns =>
              'notifications.campaigns.title',
            AdminNotificationSection.templates =>
              'notifications.templates.title',
            AdminNotificationSection.devices => 'notifications.devices.title',
            AdminNotificationSection.settings => 'notifications.settings.title',
          }),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: AppColors.deepOcean,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          context.t(switch (section) {
            AdminNotificationSection.campaigns =>
              'notifications.campaigns.description',
            AdminNotificationSection.templates =>
              'notifications.templates.description',
            AdminNotificationSection.devices =>
              'notifications.devices.description',
            AdminNotificationSection.settings =>
              'notifications.settings.description',
          }),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppColors.inkSoft,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({
    required this.section,
    required this.stats,
    required this.settings,
  });

  final AdminNotificationSection section;
  final AdminNotificationStats stats;
  final AdminNotificationSettings? settings;

  @override
  Widget build(BuildContext context) {
    final items = switch (section) {
      AdminNotificationSection.campaigns => [
        _MetricData(
          'notifications.metrics.totalCampaigns',
          '${stats.total}',
          Symbols.campaign_outlined,
          AppColors.deepOcean,
        ),
        _MetricData(
          'notifications.metrics.sending',
          '${stats.sending}',
          Symbols.schedule_send,
          const Color(0xFF3B82F6),
        ),
        _MetricData(
          'notifications.metrics.sent',
          '${stats.sent}',
          Symbols.check_circle,
          const Color(0xFF198754),
        ),
        _MetricData(
          'notifications.metrics.failed',
          '${stats.failed}',
          Symbols.close,
          AppColors.actionRed,
        ),
      ],
      AdminNotificationSection.templates => [
        _MetricData(
          'notifications.metrics.totalTemplates',
          '${stats.total}',
          Symbols.draft,
          AppColors.deepOcean,
        ),
        _MetricData(
          'notifications.metrics.ready',
          '${stats.ready}',
          Symbols.check_circle,
          const Color(0xFF198754),
        ),
        _MetricData(
          'notifications.metrics.active',
          '${stats.active}',
          Symbols.notifications_active_outlined,
          const Color(0xFF0F766E),
        ),
        _MetricData(
          'notifications.metrics.language',
          '3',
          Symbols.language,
          const Color(0xFF3B82F6),
        ),
      ],
      AdminNotificationSection.devices => [
        _MetricData(
          'notifications.metrics.totalDevices',
          '${stats.total}',
          Symbols.notifications,
          AppColors.deepOcean,
        ),
        _MetricData(
          'notifications.metrics.activeDevices',
          '${stats.active}',
          Symbols.check_circle,
          const Color(0xFF198754),
        ),
        _MetricData(
          'notifications.metrics.invalidTokens',
          '${stats.invalid}',
          Symbols.close,
          AppColors.actionRed,
        ),
        _MetricData(
          'notifications.metrics.webTokens',
          '${stats.web}',
          Symbols.public,
          const Color(0xFF3B82F6),
        ),
      ],
      AdminNotificationSection.settings => [
        _MetricData(
          'notifications.metrics.provider',
          'FCM',
          Symbols.notifications,
          AppColors.deepOcean,
        ),
        _MetricData(
          'notifications.metrics.tokenVerified',
          settings?.tokenVerified == true ? '1' : '0',
          Symbols.check_circle,
          const Color(0xFF198754),
        ),
        _MetricData(
          'notifications.metrics.mobile',
          settings?.androidEnabled == true || settings?.iosEnabled == true
              ? '1'
              : '0',
          Symbols.send,
          const Color(0xFF3B82F6),
        ),
        _MetricData(
          'notifications.metrics.web',
          settings?.flutterWebEnabled == true ||
                  settings?.astroWebEnabled == true
              ? '1'
              : '0',
          Symbols.public,
          const Color(0xFF0F766E),
        ),
      ],
    };

    return Row(
      children: [
        for (var index = 0; index < items.length; index++) ...[
          Expanded(child: _MetricBox(data: items[index])),
          if (index != items.length - 1) const SizedBox(width: 14),
        ],
      ],
    );
  }
}

class _MetricData {
  const _MetricData(this.label, this.value, this.icon, this.color);

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class _MetricBox extends StatelessWidget {
  const _MetricBox({required this.data});

  final _MetricData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.value),
            ),
            child: Center(
              child: SymbolIcon(data.icon, color: data.color, size: 22),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t(data.label),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.inkSoft,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  data.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.deepOcean,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.section,
    required this.pageSize,
    required this.searchController,
    required this.onPageSizeChanged,
    required this.onSearchChanged,
    required this.onRefresh,
    required this.onCreate,
  });

  final AdminNotificationSection section;
  final int pageSize;
  final TextEditingController searchController;
  final ValueChanged<int?> onPageSizeChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onRefresh;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AdminTablePageSizeSelect(value: pageSize, onChanged: onPageSizeChanged),
        const Spacer(),
        SizedBox(
          width: 348,
          child: AdminTableSearchField(
            controller: searchController,
            hintText: context.t('common.searchPlaceholder'),
            onChanged: onSearchChanged,
          ),
        ),
        const SizedBox(width: 14),
        AdminTableSecondaryActionButton(
          icon: Symbols.sync,
          label: context.t('common.refresh'),
          onPressed: onRefresh,
        ),
        if (onCreate != null) ...[
          const SizedBox(width: 14),
          AdminTablePrimaryActionButton(
            icon: Symbols.add,
            label: context.t(
              section == AdminNotificationSection.campaigns
                  ? 'notifications.campaigns.add'
                  : 'notifications.templates.add',
            ),
            onPressed: onCreate!,
          ),
        ],
      ],
    );
  }
}

class _TableHeader {
  const _TableHeader(this.label, this.key, {this.flex = 1});

  final String label;
  final String key;
  final int flex;
}

class _NotificationTable extends StatelessWidget {
  const _NotificationTable({
    required this.headers,
    required this.rows,
    required this.sortState,
    required this.onSort,
    required this.emptyLabel,
  });

  final List<_TableHeader> headers;
  final List<Widget> rows;
  final TableSortState sortState;
  final ValueChanged<String> onSort;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            height: 70,
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 34),
            child: Row(
              children: [
                const SizedBox(
                  width: 38,
                  child: Checkbox(value: false, onChanged: null),
                ),
                for (final header in headers)
                  Expanded(
                    flex: header.flex,
                    child: SortableTableHeader(
                      label: header.label,
                      sortKey: header.key,
                      sortState: sortState,
                      onSort: onSort,
                    ),
                  ),
                SizedBox(
                  width: 92,
                  child: Text(
                    context.t('common.actions'),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: AppColors.inkSoft,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.line),
          Expanded(
            child: rows.isEmpty
                ? Center(child: AdminTableEmptyText(label: emptyLabel))
                : ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: AppColors.line),
                    itemBuilder: (context, index) => rows[index],
                  ),
          ),
        ],
      ),
    );
  }
}

class _CampaignRow extends StatelessWidget {
  const _CampaignRow({
    required this.campaign,
    required this.onDispatch,
    required this.onPause,
    required this.onResume,
    required this.onEdit,
    required this.onDelete,
  });

  final AdminNotificationCampaign campaign;
  final VoidCallback onDispatch;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return _TableRowShell(
      menuItems: [
        _RowMenuItem(Symbols.edit_square, 'common.edit', onEdit),
        if (campaign.status == AdminNotificationStatus.paused)
          _RowMenuItem(
            Symbols.schedule_send,
            'notifications.actions.resume',
            onResume,
          )
        else
          _RowMenuItem(
            Symbols.send,
            'notifications.actions.dispatch',
            onDispatch,
          ),
        if (campaign.status == AdminNotificationStatus.sending)
          _RowMenuItem(
            Symbols.pending_actions,
            'notifications.actions.pause',
            onPause,
          ),
        _RowMenuItem(Symbols.delete, 'common.delete', onDelete, danger: true),
      ],
      children: [
        Expanded(
          flex: 3,
          child: _TitleCell(
            icon: Symbols.notifications,
            title: campaign.name,
            subtitle: campaign.title,
            color: AppColors.actionRed,
          ),
        ),
        Expanded(
          flex: 2,
          child: _TwoLineCell(
            title: context.t('notifications.target.${campaign.targetType}'),
            subtitle: campaign.targetPlatforms.isEmpty
                ? context.t('notifications.target.all')
                : campaign.targetPlatforms.join(', '),
          ),
        ),
        Expanded(
          flex: 2,
          child: Align(
            alignment: Alignment.centerLeft,
            child: _StatusBadge(
              label: context.t(notificationStatusLabelKey(campaign.status)),
              tone: _toneForStatus(campaign.status),
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: _TwoLineCell(
            title: '${campaign.sentCount} / ${campaign.recipientCount}',
            subtitle:
                '${context.t('notifications.table.failed')}: ${campaign.failedCount}',
          ),
        ),
        Expanded(
          flex: 2,
          child: _TwoLineCell(
            title: formatAdminFullDate(context, campaign.createdAt),
            subtitle: formatAdminTime(campaign.createdAt),
          ),
        ),
      ],
    );
  }
}

class _TemplateRow extends StatelessWidget {
  const _TemplateRow({
    required this.template,
    required this.onEdit,
    required this.onDelete,
  });

  final AdminNotificationTemplate template;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return _TableRowShell(
      menuItems: [
        _RowMenuItem(Symbols.edit_square, 'common.edit', onEdit),
        _RowMenuItem(Symbols.delete, 'common.delete', onDelete, danger: true),
      ],
      children: [
        Expanded(
          flex: 3,
          child: _TitleCell(
            icon: Symbols.draft,
            title: template.name,
            subtitle: template.category,
            color: const Color(0xFF3B82F6),
          ),
        ),
        Expanded(
          flex: 4,
          child: _TwoLineCell(title: template.title, subtitle: template.body),
        ),
        Expanded(
          flex: 1,
          child: _TwoLineCell(
            title: template.languageCode.toUpperCase(),
            subtitle: template.priority,
          ),
        ),
        Expanded(
          flex: 2,
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _StatusBadge(
                label: context.t(
                  template.ready
                      ? 'notifications.templates.ready'
                      : 'notifications.templates.notReady',
                ),
                tone: template.ready ? _BadgeTone.success : _BadgeTone.warning,
              ),
              _StatusBadge(
                label: context.t(
                  template.active ? 'common.active' : 'common.passive',
                ),
                tone: template.active ? _BadgeTone.success : _BadgeTone.muted,
              ),
            ],
          ),
        ),
        Expanded(
          flex: 2,
          child: _TwoLineCell(
            title: formatAdminFullDate(context, template.createdAt),
            subtitle: formatAdminTime(template.createdAt),
          ),
        ),
      ],
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({
    required this.device,
    required this.onActivate,
    required this.onInvalidate,
    required this.onDelete,
  });

  final AdminNotificationDevice device;
  final VoidCallback onActivate;
  final VoidCallback onInvalidate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return _TableRowShell(
      menuItems: [
        if (device.active)
          _RowMenuItem(
            Symbols.visibility_off,
            'notifications.actions.invalidate',
            onInvalidate,
          )
        else
          _RowMenuItem(
            Symbols.check_circle,
            'notifications.actions.activate',
            onActivate,
          ),
        _RowMenuItem(Symbols.delete, 'common.delete', onDelete, danger: true),
      ],
      children: [
        Expanded(
          flex: 3,
          child: _TitleCell(
            icon: Symbols.notifications,
            title: device.platform,
            subtitle: device.appSurface,
            color: const Color(0xFF0F766E),
          ),
        ),
        Expanded(
          flex: 4,
          child: _TwoLineCell(
            title: _shortToken(device.fcmToken),
            subtitle: device.deviceModel.isEmpty
                ? device.appVersion
                : device.deviceModel,
          ),
        ),
        Expanded(
          flex: 2,
          child: _TwoLineCell(
            title: device.permissionStatus,
            subtitle: device.languageCode.toUpperCase(),
          ),
        ),
        Expanded(
          flex: 2,
          child: Align(
            alignment: Alignment.centerLeft,
            child: _StatusBadge(
              label: context.t(
                device.active ? 'common.active' : 'common.passive',
              ),
              tone: device.active ? _BadgeTone.success : _BadgeTone.muted,
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: _TwoLineCell(
            title: formatAdminFullDate(context, device.lastSeenAt),
            subtitle: formatAdminTime(device.lastSeenAt),
          ),
        ),
      ],
    );
  }
}

class _TableRowShell extends StatelessWidget {
  const _TableRowShell({required this.children, required this.menuItems});

  final List<Widget> children;
  final List<_RowMenuItem> menuItems;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 92),
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 14),
      child: Row(
        children: [
          const SizedBox(
            width: 38,
            child: Checkbox(value: false, onChanged: null),
          ),
          ...children,
          SizedBox(
            width: 92,
            child: Align(
              alignment: Alignment.centerRight,
              child: _RowActionMenu(items: menuItems),
            ),
          ),
        ],
      ),
    );
  }
}

class _TitleCell extends StatelessWidget {
  const _TitleCell({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.value),
          ),
          child: Center(child: SymbolIcon(icon, color: color, size: 22)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _TwoLineCell(title: title, subtitle: subtitle),
        ),
      ],
    );
  }
}

class _TwoLineCell extends StatelessWidget {
  const _TwoLineCell({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.deepOcean,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.support,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

enum _BadgeTone { success, warning, danger, muted, info }

_BadgeTone _toneForStatus(AdminNotificationStatus status) {
  return switch (status) {
    AdminNotificationStatus.completed => _BadgeTone.success,
    AdminNotificationStatus.sending => _BadgeTone.info,
    AdminNotificationStatus.scheduled => _BadgeTone.warning,
    AdminNotificationStatus.failed ||
    AdminNotificationStatus.cancelled => _BadgeTone.danger,
    AdminNotificationStatus.paused ||
    AdminNotificationStatus.draft => _BadgeTone.muted,
  };
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.tone});

  final String label;
  final _BadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      _BadgeTone.success => const Color(0xFF198754),
      _BadgeTone.warning => const Color(0xFFF59E0B),
      _BadgeTone.danger => AppColors.actionRed,
      _BadgeTone.info => const Color(0xFF3B82F6),
      _BadgeTone.muted => AppColors.support,
    };
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.value),
      ),
      alignment: Alignment.center,
      child: Text(
        '• $label',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _RowMenuItem {
  const _RowMenuItem(this.icon, this.label, this.onTap, {this.danger = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;
}

class _RowActionMenu extends StatefulWidget {
  const _RowActionMenu({required this.items});

  final List<_RowMenuItem> items;

  @override
  State<_RowActionMenu> createState() => _RowActionMenuState();
}

class _RowActionMenuState extends State<_RowActionMenu> {
  final _link = LayerLink();
  OverlayEntry? _entry;

  @override
  void dispose() {
    _close();
    super.dispose();
  }

  void _toggle() {
    if (_entry == null) {
      _open();
    } else {
      _close();
    }
  }

  void _open() {
    _entry = OverlayEntry(
      builder: (context) => Positioned.fill(
        child: Stack(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _close,
              child: const SizedBox.expand(),
            ),
            CompositedTransformFollower(
              link: _link,
              targetAnchor: Alignment.bottomRight,
              followerAnchor: Alignment.topRight,
              offset: const Offset(0, 8),
              child: Material(
                color: Colors.transparent,
                child: _MenuCard(items: widget.items, onClose: _close),
              ),
            ),
          ],
        ),
      ),
    );
    Overlay.of(context).insert(_entry!);
    setState(() {});
  }

  void _close() {
    _entry?.remove();
    _entry = null;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggle,
          child: const SizedBox(
            width: 38,
            height: 34,
            child: Center(
              child: SymbolIcon(
                Symbols.more_horiz,
                color: AppColors.iconMuted,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.items, required this.onClose});

  final List<_RowMenuItem> items;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepOcean.withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final item in items) _MenuButton(item: item, onClose: onClose),
        ],
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({required this.item, required this.onClose});

  final _RowMenuItem item;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final color = item.danger ? AppColors.actionRed : AppColors.deepOcean;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: () {
          onClose();
          item.onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            children: [
              SymbolIcon(item.icon, color: color, size: 19),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  context.t(item.label),
                  style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.onPageChanged,
  });

  final int page;
  final int pageSize;
  final int totalCount;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final pageCount = (totalCount / pageSize).ceil().clamp(1, 999999);
    final start = totalCount == 0 ? 0 : ((page - 1) * pageSize) + 1;
    final end = totalCount == 0
        ? 0
        : (start + pageSize - 1).clamp(1, totalCount);
    return Row(
      children: [
        Text(
          context.t(
            'common.tableRange',
            values: {'start': start, 'end': end, 'total': totalCount},
          ),
          style: const TextStyle(
            color: AppColors.inkSoft,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        const Spacer(),
        AdminTablePageButton(
          label: '<<',
          enabled: page > 1,
          onPressed: () => onPageChanged(1),
        ),
        const SizedBox(width: 8),
        AdminTablePageButton(
          label: '<',
          enabled: page > 1,
          onPressed: () => onPageChanged(page - 1),
        ),
        const SizedBox(width: 8),
        AdminTablePageButton(label: '$page', selected: true),
        const SizedBox(width: 8),
        AdminTablePageButton(
          label: '>',
          enabled: page < pageCount,
          onPressed: () => onPageChanged(page + 1),
        ),
        const SizedBox(width: 8),
        AdminTablePageButton(
          label: '>>',
          enabled: page < pageCount,
          onPressed: () => onPageChanged(pageCount),
        ),
      ],
    );
  }
}

class _CampaignDialog extends StatefulWidget {
  const _CampaignDialog({this.campaign});

  final AdminNotificationCampaign? campaign;

  @override
  State<_CampaignDialog> createState() => _CampaignDialogState();
}

class _CampaignDialogState extends State<_CampaignDialog> {
  late final TextEditingController _name;
  late final TextEditingController _title;
  late final TextEditingController _body;
  late final TextEditingController _deepLink;
  late final TextEditingController _platforms;
  var _priority = 'normal';

  @override
  void initState() {
    super.initState();
    final campaign = widget.campaign;
    _name = TextEditingController(text: campaign?.name ?? '');
    _title = TextEditingController(text: campaign?.title ?? '');
    _body = TextEditingController(text: campaign?.body ?? '');
    _deepLink = TextEditingController(text: campaign?.deepLink ?? '');
    _platforms = TextEditingController(
      text: campaign?.targetPlatforms.join(', ') ?? '',
    );
    _priority = campaign?.priority == 'high' ? 'high' : 'normal';
  }

  @override
  void dispose() {
    _name.dispose();
    _title.dispose();
    _body.dispose();
    _deepLink.dispose();
    _platforms.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _EditDialogShell(
      title: context.t(
        widget.campaign == null
            ? 'notifications.campaigns.add'
            : 'notifications.campaigns.edit',
      ),
      onSave: () {
        Navigator.of(context).pop(
          AdminNotificationCampaign(
            id: widget.campaign?.id ?? 0,
            name: _name.text.trim(),
            title: _title.text.trim(),
            body: _body.text.trim(),
            targetType: _platforms.text.trim().isEmpty ? 'all' : 'platform',
            targetPlatforms: _commaList(_platforms.text),
            status: widget.campaign?.status ?? AdminNotificationStatus.draft,
            priority: _priority,
            recipientCount: widget.campaign?.recipientCount ?? 0,
            queuedCount: widget.campaign?.queuedCount ?? 0,
            sentCount: widget.campaign?.sentCount ?? 0,
            failedCount: widget.campaign?.failedCount ?? 0,
            openedCount: widget.campaign?.openedCount ?? 0,
            clickedCount: widget.campaign?.clickedCount ?? 0,
            createdAt: widget.campaign?.createdAt ?? DateTime.now(),
            deepLink: _deepLink.text.trim(),
          ),
        );
      },
      children: [
        _DialogTextField(label: 'notifications.form.name', controller: _name),
        _DialogTextField(label: 'notifications.form.title', controller: _title),
        _DialogTextField(
          label: 'notifications.form.body',
          controller: _body,
          maxLines: 3,
        ),
        _DialogTextField(
          label: 'notifications.form.deepLink',
          controller: _deepLink,
        ),
        _DialogTextField(
          label: 'notifications.form.platforms',
          controller: _platforms,
        ),
        _DialogSelect(
          label: 'notifications.form.priority',
          value: _priority,
          items: const ['normal', 'high'],
          onChanged: (value) => setState(() => _priority = value),
        ),
      ],
    );
  }
}

class _TemplateDialog extends StatefulWidget {
  const _TemplateDialog({this.template});

  final AdminNotificationTemplate? template;

  @override
  State<_TemplateDialog> createState() => _TemplateDialogState();
}

class _TemplateDialogState extends State<_TemplateDialog> {
  late final TextEditingController _name;
  late final TextEditingController _category;
  late final TextEditingController _title;
  late final TextEditingController _body;
  late final TextEditingController _deepLink;
  late final TextEditingController _language;
  var _priority = 'normal';
  var _active = true;
  var _ready = true;

  @override
  void initState() {
    super.initState();
    final template = widget.template;
    _name = TextEditingController(text: template?.name ?? '');
    _category = TextEditingController(text: template?.category ?? 'general');
    _title = TextEditingController(text: template?.title ?? '');
    _body = TextEditingController(text: template?.body ?? '');
    _deepLink = TextEditingController(text: template?.deepLink ?? '');
    _language = TextEditingController(text: template?.languageCode ?? 'tr');
    _priority = template?.priority == 'high' ? 'high' : 'normal';
    _active = template?.active ?? true;
    _ready = template?.ready ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    _title.dispose();
    _body.dispose();
    _deepLink.dispose();
    _language.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _EditDialogShell(
      title: context.t(
        widget.template == null
            ? 'notifications.templates.add'
            : 'notifications.templates.edit',
      ),
      onSave: () {
        Navigator.of(context).pop(
          AdminNotificationTemplate(
            id: widget.template?.id ?? 0,
            name: _name.text.trim(),
            category: _category.text.trim().isEmpty
                ? 'general'
                : _category.text.trim(),
            title: _title.text.trim(),
            body: _body.text.trim(),
            languageCode: _language.text.trim().isEmpty
                ? 'tr'
                : _language.text.trim(),
            priority: _priority,
            ready: _ready,
            active: _active,
            createdAt: widget.template?.createdAt ?? DateTime.now(),
            deepLink: _deepLink.text.trim(),
          ),
        );
      },
      children: [
        _DialogTextField(label: 'notifications.form.name', controller: _name),
        _DialogTextField(
          label: 'notifications.form.category',
          controller: _category,
        ),
        _DialogTextField(label: 'notifications.form.title', controller: _title),
        _DialogTextField(
          label: 'notifications.form.body',
          controller: _body,
          maxLines: 3,
        ),
        _DialogTextField(
          label: 'notifications.form.deepLink',
          controller: _deepLink,
        ),
        _DialogTextField(
          label: 'notifications.form.language',
          controller: _language,
        ),
        _DialogSelect(
          label: 'notifications.form.priority',
          value: _priority,
          items: const ['normal', 'high'],
          onChanged: (value) => setState(() => _priority = value),
        ),
        _SwitchRow(
          label: 'notifications.templates.ready',
          value: _ready,
          onChanged: (value) => setState(() => _ready = value),
        ),
        _SwitchRow(
          label: 'common.active',
          value: _active,
          onChanged: (value) => setState(() => _active = value),
        ),
      ],
    );
  }
}

class _EditDialogShell extends StatelessWidget {
  const _EditDialogShell({
    required this.title,
    required this.children,
    required this.onSave,
  });

  final String title;
  final List<Widget> children;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: 560,
        constraints: const BoxConstraints(maxHeight: 760),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.value),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
              child: Text(
                title,
                style: const TextStyle(
                  color: AppColors.deepOcean,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ),
            const Divider(height: 1, color: AppColors.line),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final child in children) ...[
                      child,
                      const SizedBox(height: 14),
                    ],
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: AppColors.line),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AdminTableSecondaryActionButton(
                    icon: Symbols.close,
                    label: context.t('common.cancel'),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 10),
                  AdminTablePrimaryActionButton(
                    icon: Symbols.save,
                    label: context.t('common.save'),
                    onPressed: onSave,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogTextField extends StatelessWidget {
  const _DialogTextField({
    required this.label,
    required this.controller,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(
        color: AppColors.deepOcean,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      decoration: InputDecoration(
        labelText: context.t(label),
        labelStyle: const TextStyle(color: AppColors.inkSoft),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.value),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.value),
          borderSide: const BorderSide(color: AppColors.deepOcean),
        ),
      ),
    );
  }
}

class _DialogSelect extends StatelessWidget {
  const _DialogSelect({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: context.t(label),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.value),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.value),
          borderSide: const BorderSide(color: AppColors.deepOcean),
        ),
      ),
      items: [
        for (final item in items)
          DropdownMenuItem(
            value: item,
            child: Text(context.t('notifications.priority.$item')),
          ),
      ],
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: value,
      contentPadding: EdgeInsets.zero,
      activeThumbColor: AppColors.deepOcean,
      title: Text(
        context.t(label),
        style: const TextStyle(
          color: AppColors.deepOcean,
          fontWeight: FontWeight.w700,
        ),
      ),
      onChanged: onChanged,
    );
  }
}

class _SettingsPanel extends StatefulWidget {
  const _SettingsPanel({
    required this.settings,
    required this.onSave,
    required this.onCheck,
  });

  final AdminNotificationSettings settings;
  final void Function(AdminNotificationSettings settings, String privateKey)
  onSave;
  final VoidCallback onCheck;

  @override
  State<_SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<_SettingsPanel> {
  late TextEditingController _projectId;
  late TextEditingController _clientEmail;
  late TextEditingController _privateKey;
  late TextEditingController _vapid;
  late TextEditingController _apiBaseUrl;
  late TextEditingController _batchSize;
  var _android = true;
  var _ios = true;
  var _flutterWeb = true;
  var _astroWeb = true;
  var _active = true;

  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  @override
  void didUpdateWidget(covariant _SettingsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings.id != widget.settings.id ||
        oldWidget.settings.connectionStatus !=
            widget.settings.connectionStatus) {
      _hydrate();
    }
  }

  void _hydrate() {
    _projectId = TextEditingController(text: widget.settings.projectId);
    _clientEmail = TextEditingController(text: widget.settings.clientEmail);
    _privateKey = TextEditingController();
    _vapid = TextEditingController(text: widget.settings.webVapidKey);
    _apiBaseUrl = TextEditingController(text: widget.settings.apiBaseUrl);
    _batchSize = TextEditingController(text: '${widget.settings.batchSize}');
    _android = widget.settings.androidEnabled;
    _ios = widget.settings.iosEnabled;
    _flutterWeb = widget.settings.flutterWebEnabled;
    _astroWeb = widget.settings.astroWebEnabled;
    _active = widget.settings.active;
  }

  @override
  void dispose() {
    _projectId.dispose();
    _clientEmail.dispose();
    _privateKey.dispose();
    _vapid.dispose();
    _apiBaseUrl.dispose();
    _batchSize.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 14),
            child: Row(
              children: [
                _StatusBadge(
                  label: context.t(
                    settings.tokenVerified
                        ? 'notifications.settings.ready'
                        : 'notifications.settings.pending',
                  ),
                  tone: settings.tokenVerified
                      ? _BadgeTone.success
                      : _BadgeTone.warning,
                ),
                const SizedBox(width: 10),
                if (settings.hasPrivateKey ||
                    settings.serverCredentialsConfigured)
                  _StatusBadge(
                    label: context.t('notifications.settings.secretReady'),
                    tone: _BadgeTone.success,
                  ),
                const Spacer(),
                AdminTableSecondaryActionButton(
                  icon: Symbols.sync,
                  label: context.t('notifications.settings.check'),
                  onPressed: widget.onCheck,
                ),
                const SizedBox(width: 10),
                AdminTablePrimaryActionButton(
                  icon: Symbols.save,
                  label: context.t('common.save'),
                  onPressed: () {
                    widget.onSave(
                      AdminNotificationSettings(
                        id: settings.id,
                        projectId: _projectId.text.trim(),
                        clientEmail: _clientEmail.text.trim(),
                        webVapidKey: _vapid.text.trim(),
                        apiBaseUrl: _apiBaseUrl.text.trim().isEmpty
                            ? 'https://fcm.googleapis.com/v1'
                            : _apiBaseUrl.text.trim(),
                        defaultLanguageCode: settings.defaultLanguageCode,
                        dailyLimit: settings.dailyLimit,
                        monthlyLimit: settings.monthlyLimit,
                        hourlyLimit: settings.hourlyLimit,
                        batchSize:
                            int.tryParse(_batchSize.text.trim()) ??
                            settings.batchSize,
                        androidEnabled: _android,
                        iosEnabled: _ios,
                        flutterWebEnabled: _flutterWeb,
                        astroWebEnabled: _astroWeb,
                        tokenVerified: settings.tokenVerified,
                        active: _active,
                        connectionStatus: settings.connectionStatus,
                        hasPrivateKey: settings.hasPrivateKey,
                        serverCredentialsConfigured:
                            settings.serverCredentialsConfigured,
                        lastErrorMessage: settings.lastErrorMessage,
                      ),
                      _privateKey.text,
                    );
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.line),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _DialogTextField(
                          label: 'notifications.settings.projectId',
                          controller: _projectId,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _DialogTextField(
                          label: 'notifications.settings.clientEmail',
                          controller: _clientEmail,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _DialogTextField(
                    label: settings.hasPrivateKey
                        ? 'notifications.settings.privateKeyUpdate'
                        : 'notifications.settings.privateKey',
                    controller: _privateKey,
                    maxLines: 4,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _DialogTextField(
                          label: 'notifications.settings.vapidKey',
                          controller: _vapid,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _DialogTextField(
                          label: 'notifications.settings.apiBaseUrl',
                          controller: _apiBaseUrl,
                        ),
                      ),
                      const SizedBox(width: 14),
                      SizedBox(
                        width: 140,
                        child: _DialogTextField(
                          label: 'notifications.settings.batchSize',
                          controller: _batchSize,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _SwitchRow(
                    label: 'notifications.settings.android',
                    value: _android,
                    onChanged: (value) => setState(() => _android = value),
                  ),
                  _SwitchRow(
                    label: 'notifications.settings.ios',
                    value: _ios,
                    onChanged: (value) => setState(() => _ios = value),
                  ),
                  _SwitchRow(
                    label: 'notifications.settings.flutterWeb',
                    value: _flutterWeb,
                    onChanged: (value) => setState(() => _flutterWeb = value),
                  ),
                  _SwitchRow(
                    label: 'notifications.settings.astroWeb',
                    value: _astroWeb,
                    onChanged: (value) => setState(() => _astroWeb = value),
                  ),
                  _SwitchRow(
                    label: 'common.active',
                    value: _active,
                    onChanged: (value) => setState(() => _active = value),
                  ),
                  if (settings.lastErrorMessage.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _StatusBadge(
                      label: settings.lastErrorMessage,
                      tone: _BadgeTone.danger,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _shortToken(String token) {
  if (token.length <= 28) return token;
  return '${token.substring(0, 14)}...${token.substring(token.length - 10)}';
}

List<String> _commaList(String value) {
  return value
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}
