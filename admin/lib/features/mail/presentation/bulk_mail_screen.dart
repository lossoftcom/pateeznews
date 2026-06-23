import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/widgets/admin_mobile_list.dart';
import 'package:http/http.dart' as http;
import 'package:pateeznews_admin/shared/widgets/admin_table_chrome.dart';
import 'package:pateeznews_admin/shared/widgets/admin_toast.dart';

import '../../../core/localization/admin_date_formatter.dart';
import '../../../core/localization/admin_language_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/branding/admin_branding.dart';
import '../../../shared/icons/symbols.dart';
import '../../../shared/widgets/admin_date_time_picker.dart';
import '../../../shared/widgets/app_confirmation_dialog.dart';
import '../../../shared/widgets/sortable_table_header.dart';
import '../../../shared/widgets/symbol_icon.dart';
import '../../auth/data/admin_auth_models.dart';
import '../data/admin_mail_repository.dart';
import 'builder/posta_mjml_builder.dart';
import 'bulk_mail_models.dart';
import 'contact_list_models.dart';
import 'mail_mobile_chrome.dart';
import 'mail_settings_models.dart';
import 'mail_template_models.dart';

final Map<String, Future<String>> _mailPreviewLogoDataUriCache =
    <String, Future<String>>{};

Future<String> _mailPreviewLogoDataUri(String url) {
  final normalized = url.trim();
  if (normalized.isEmpty) return Future<String>.value('');
  return _mailPreviewLogoDataUriCache.putIfAbsent(normalized, () async {
    try {
      final response = await http
          .get(Uri.parse(normalized))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) return '';
      final contentType =
          response.headers['content-type']?.split(';').first.trim() ??
          _mailPreviewLogoMimeType(normalized);
      if (!contentType.startsWith('image/')) return '';
      return 'data:$contentType;base64,${base64Encode(response.bodyBytes)}';
    } catch (_) {
      return '';
    }
  });
}

String _mailPreviewLogoMimeType(String url) {
  final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
  if (path.endsWith('.svg')) return 'image/svg+xml';
  if (path.endsWith('.webp')) return 'image/webp';
  if (path.endsWith('.jpg') || path.endsWith('.jpeg')) return 'image/jpeg';
  if (path.endsWith('.gif')) return 'image/gif';
  return 'image/png';
}

class BulkMailScreen extends StatefulWidget {
  const BulkMailScreen({
    super.key,
    required this.session,
    this.repository = const SupabaseAdminMailRepository(),
  });

  final AdminSession session;
  final AdminMailRepository repository;

  @override
  State<BulkMailScreen> createState() => _BulkMailScreenState();
}

class _BulkMailScreenState extends State<BulkMailScreen> {
  final _searchController = TextEditingController();
  var _campaigns = <AdminBulkMailCampaign>[];
  var _templates = <AdminMailTemplate>[];
  var _accounts = <AdminMailAccount>[];
  var _lists = <AdminContactList>[];
  final _selectedIds = <int>{};
  var _statusFilter = bulkMailFilterAll;
  var _page = 1;
  var _pageSize = 25;
  var _sortState = const TableSortState(key: 'date', ascending: false);
  var _loading = true;
  Future<void>? _loadBulkMailFuture;

  @override
  void initState() {
    super.initState();
    unawaited(_loadBulkMail());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBulkMail() {
    final activeLoad = _loadBulkMailFuture;
    if (activeLoad != null) return activeLoad;

    final nextLoad = _performLoadBulkMail();
    _loadBulkMailFuture = nextLoad;
    unawaited(
      nextLoad.whenComplete(() {
        if (identical(_loadBulkMailFuture, nextLoad)) {
          _loadBulkMailFuture = null;
        }
      }),
    );
    return nextLoad;
  }

  Future<void> _performLoadBulkMail() async {
    if (mounted) setState(() => _loading = true);
    final errors = <String>[];
    final campaignsLoad = _loadMailResource<List<AdminBulkMailCampaign>>(
      'Toplu mail',
      () => widget.repository.fetchCampaigns(widget.session),
      errors,
    );
    final templatesLoad = _loadMailResource<List<AdminMailTemplate>>(
      'Sablon',
      () => widget.repository.fetchTemplates(widget.session),
      errors,
    );
    final accountsLoad = _loadMailResource<List<AdminMailAccount>>(
      'Mail hesabi',
      () => widget.repository.fetchAccounts(widget.session),
      errors,
    );
    final listsLoad = _loadMailResource<List<AdminContactList>>(
      'Kisi listesi',
      () => widget.repository.fetchContactLists(widget.session),
      errors,
    );

    final campaigns = await campaignsLoad;
    final templates = await templatesLoad;
    final accounts = await accountsLoad;
    final lists = await listsLoad;

    if (!mounted) return;
    setState(() {
      if (campaigns != null) {
        _campaigns = campaigns;
        _resetListState();
      }
      if (templates != null) _templates = templates;
      if (accounts != null) _accounts = accounts;
      if (lists != null) _lists = lists;
      _loading = false;
    });
    if (errors.isNotEmpty) {
      _showMailError(AdminMailException(errors.join('\n')));
    }
  }

  Future<T?> _loadMailResource<T>(
    String label,
    Future<T> Function() request,
    List<String> errors,
  ) async {
    try {
      return await request();
    } catch (error) {
      errors.add('$label: $error');
      return null;
    }
  }

  void _showMailError(Object error) {
    AdminToast.show(
      context,
      message: error.toString(),
      tone: AdminToastTone.error,
    );
  }

  List<AdminBulkMailCampaign> get _filteredCampaigns {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = _campaigns.where((campaign) {
      if (_statusFilter != bulkMailFilterAll &&
          campaign.status.value != _statusFilter) {
        return false;
      }
      if (query.isEmpty) return true;
      final searchable = [
        campaign.name,
        campaign.subject,
        campaign.preview,
        campaign.templateName,
        campaign.templateCategory,
        campaign.senderAccount,
        campaign.senderEmail,
        campaign.recipientList,
        campaign.status.labelKey,
      ].join(' ').toLowerCase();
      return searchable.contains(query);
    }).toList();

    filtered.sort((left, right) {
      final result = switch (_sortState.key) {
        'name' => left.name.compareTo(right.name),
        'recipient' => left.recipientCount.compareTo(right.recipientCount),
        'sent' => left.sentCount.compareTo(right.sentCount),
        'open' => left.openRate.compareTo(right.openRate),
        'click' => left.clickRate.compareTo(right.clickRate),
        'bounce' => left.bounceRate.compareTo(right.bounceRate),
        'status' => left.status.index.compareTo(right.status.index),
        'date' || _ => left.tableDate.compareTo(right.tableDate),
      };
      return _sortState.ascending ? result : -result;
    });

    return filtered;
  }

  List<AdminBulkMailCampaign> get _pagedCampaigns {
    final filtered = _filteredCampaigns;
    if (filtered.isEmpty) return const <AdminBulkMailCampaign>[];
    final start = (_page - 1) * _pageSize;
    if (start >= filtered.length) return filtered.take(_pageSize).toList();
    final end = start + _pageSize > filtered.length
        ? filtered.length
        : start + _pageSize;
    return filtered.sublist(start, end);
  }

  void _resetListState() {
    _page = 1;
    _selectedIds.clear();
  }

  void _changeStatus(String value) {
    setState(() {
      _statusFilter = value;
      _resetListState();
    });
  }

  void _changePageSize(int? value) {
    if (value == null || value == _pageSize) return;
    setState(() {
      _pageSize = value;
      _resetListState();
    });
  }

  void _changeSearch(String value) {
    setState(_resetListState);
  }

  void _changePage(int value) {
    if (value == _page) return;
    setState(() {
      _page = value;
      _selectedIds.clear();
    });
  }

  void _changeSort(String key) {
    setState(() {
      _sortState = _sortState.toggled(key);
      _resetListState();
    });
  }

  void _toggleCampaign(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _toggleAllCampaigns() {
    final pageIds = _pagedCampaigns.map((campaign) => campaign.id).toSet();
    setState(() {
      if (pageIds.isNotEmpty && _selectedIds.containsAll(pageIds)) {
        _selectedIds.removeAll(pageIds);
      } else {
        _selectedIds
          ..clear()
          ..addAll(pageIds);
      }
    });
  }

  void _refreshDesign() {
    unawaited(_loadBulkMail());
  }

  List<String> get _missingCreateResources {
    final missing = <String>[];
    final hasReadyTemplate = _templates.any(
      (template) => template.active && template.ready,
    );
    if (!hasReadyTemplate) missing.add('aktif hazir sablon');
    if (_accounts.isEmpty) missing.add('gonderen mail hesabi');
    if (_lists.isEmpty) missing.add('kisi listesi');
    return missing;
  }

  void _updateCampaign(
    AdminBulkMailCampaign campaign,
    AdminBulkMailCampaign updated,
  ) {
    setState(() {
      _campaigns = [
        for (final current in _campaigns)
          if (current.id == campaign.id) updated else current,
      ];
    });
  }

  Future<void> _deleteCampaign(AdminBulkMailCampaign campaign) async {
    final confirmed = await showAppConfirmationDialog(
      context,
      title: context.t('mail.campaign.deleteTitle'),
      message: context.t('mail.campaign.deleteMessage'),
      confirmLabel: context.t('common.delete'),
      danger: true,
    );
    if (!confirmed || !mounted) return;
    try {
      await widget.repository.deleteCampaigns(widget.session, [campaign.id]);
      if (!mounted) return;
      setState(() {
        _campaigns = _campaigns
            .where((current) => current.id != campaign.id)
            .toList(growable: false);
        _selectedIds.remove(campaign.id);
      });
    } catch (error) {
      if (mounted) _showMailError(error);
    }
  }

  Future<void> _deleteSelectedCampaigns() async {
    if (_selectedIds.isEmpty) return;
    final confirmed = await showAppConfirmationDialog(
      context,
      title: context.t('mail.campaign.deleteSelectedTitle'),
      message: context.t(
        'mail.campaign.deleteSelectedMessage',
        values: {'count': _selectedIds.length},
      ),
      confirmLabel: context.t('common.delete'),
      danger: true,
    );
    if (!confirmed || !mounted) return;
    try {
      final ids = _selectedIds.toList(growable: false);
      await widget.repository.deleteCampaigns(widget.session, ids);
      if (!mounted) return;
      setState(() {
        _campaigns = _campaigns
            .where((campaign) => !ids.contains(campaign.id))
            .toList(growable: false);
        _selectedIds.clear();
      });
    } catch (error) {
      if (mounted) _showMailError(error);
    }
  }

  Future<void> _startCampaign(AdminBulkMailCampaign campaign) async {
    await _campaignAction(campaign, 'start');
  }

  Future<void> _pauseCampaign(AdminBulkMailCampaign campaign) async {
    await _campaignAction(campaign, 'pause');
  }

  Future<void> _resumeCampaign(AdminBulkMailCampaign campaign) async {
    await _campaignAction(campaign, 'resume');
  }

  Future<void> _scheduleCampaign(AdminBulkMailCampaign campaign) async {
    final scheduledAt = await showAdminDateTimePicker(
      context,
      initialValue:
          campaign.scheduledAt ?? DateTime.now().add(const Duration(days: 1)),
    );
    if (scheduledAt == null || !mounted) return;
    await _campaignAction(campaign, 'schedule', scheduledAt: scheduledAt);
  }

  Future<void> _cancelCampaign(AdminBulkMailCampaign campaign) async {
    await _campaignAction(campaign, 'cancel');
  }

  Future<void> _campaignAction(
    AdminBulkMailCampaign campaign,
    String action, {
    DateTime? scheduledAt,
  }) async {
    try {
      final updated = await widget.repository.updateCampaignAction(
        widget.session,
        campaign,
        action,
        scheduledAt: scheduledAt,
      );
      if (mounted) _updateCampaign(campaign, updated);
    } catch (error) {
      if (mounted) _showMailError(error);
    }
  }

  void _showDetail(AdminBulkMailCampaign campaign) {
    showMailSideDrawer<void>(
      context: context,
      maxWidth: 760,
      child: _BulkMailDetailDialog(campaign: campaign),
    );
  }

  Future<void> _showCreateDialog({AdminBulkMailCampaign? campaign}) async {
    await _loadBulkMail();
    if (!mounted) return;
    final missingResources = _missingCreateResources;
    if (missingResources.isNotEmpty) {
      _showMailError(
        AdminMailException(
          'Toplu mail olusturmak icin ${missingResources.join(', ')} yuklenemedi.',
        ),
      );
      return;
    }

    final created = await showMailSideDrawer<AdminBulkMailCampaign>(
      context: context,
      minWidth: 740,
      maxWidth: 1180,
      child: _BulkMailCreateDialog(
        campaign: campaign,
        session: widget.session,
        repository: widget.repository,
        templates: _templates,
        accounts: _accounts,
        lists: _lists,
      ),
    );

    if (created == null || !mounted) return;
    late final AdminBulkMailCampaign saved;
    try {
      saved = await widget.repository.saveCampaign(
        widget.session,
        id: campaign?.id,
        campaign: created,
      );
    } catch (error) {
      if (mounted) _showMailError(error);
      return;
    }
    if (!mounted) return;
    if (campaign == null) {
      setState(() {
        _campaigns = [saved, ..._campaigns];
        _resetListState();
      });
    } else {
      _updateCampaign(campaign, saved);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 640 ? 16.0 : 28.0;
        final mobile = constraints.maxWidth < AdminMobile.breakpoint;
        final compact = constraints.maxWidth < 900;
        final topPadding = mobile ? 18.0 : 28.0;
        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _BulkMailTitle(title: context.t('nav.mail.campaigns')),
            SizedBox(height: mobile ? 12 : 24),
            Expanded(
              child: _BulkMailContent(
                campaigns: _campaigns,
                visibleCampaigns: _pagedCampaigns,
                totalCount: _filteredCampaigns.length,
                selectedIds: _selectedIds,
                statusFilter: _statusFilter,
                page: _page,
                pageSize: _pageSize,
                sortState: _sortState,
                searchController: _searchController,
                onStatusChanged: _changeStatus,
                onPageSizeChanged: _changePageSize,
                onSearchChanged: _changeSearch,
                onPageChanged: _changePage,
                onSort: _changeSort,
                onToggleCampaign: _toggleCampaign,
                onToggleAllCampaigns: _toggleAllCampaigns,
                onDeleteSelected: _deleteSelectedCampaigns,
                onRefresh: _refreshDesign,
                onCreate: () => _showCreateDialog(),
                onDetail: _showDetail,
                onEdit: (campaign) => _showCreateDialog(campaign: campaign),
                onStart: (campaign) => unawaited(_startCampaign(campaign)),
                onPause: (campaign) => unawaited(_pauseCampaign(campaign)),
                onResume: (campaign) => unawaited(_resumeCampaign(campaign)),
                onSchedule: (campaign) =>
                    unawaited(_scheduleCampaign(campaign)),
                onCancel: (campaign) => unawaited(_cancelCampaign(campaign)),
                onDelete: _deleteCampaign,
              ),
            ),
            if (_loading) const LinearProgressIndicator(minHeight: 2),
          ],
        );

        if (mobile) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              topPadding,
              horizontalPadding,
              0,
            ),
            child: content,
          );
        }

        if (compact) {
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              topPadding,
              horizontalPadding,
              28,
            ),
            child: SizedBox(height: 1080, child: content),
          );
        }

        return Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            topPadding,
            horizontalPadding,
            28,
          ),
          child: content,
        );
      },
    );
  }
}

class _BulkMailTitle extends StatelessWidget {
  const _BulkMailTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
        color: AppColors.deepOcean,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
    );
  }
}

class _BulkMailContent extends StatelessWidget {
  const _BulkMailContent({
    required this.campaigns,
    required this.visibleCampaigns,
    required this.totalCount,
    required this.selectedIds,
    required this.statusFilter,
    required this.page,
    required this.pageSize,
    required this.sortState,
    required this.searchController,
    required this.onStatusChanged,
    required this.onPageSizeChanged,
    required this.onSearchChanged,
    required this.onPageChanged,
    required this.onSort,
    required this.onToggleCampaign,
    required this.onToggleAllCampaigns,
    required this.onDeleteSelected,
    required this.onRefresh,
    required this.onCreate,
    required this.onDetail,
    required this.onEdit,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onSchedule,
    required this.onCancel,
    required this.onDelete,
  });

  final List<AdminBulkMailCampaign> campaigns;
  final List<AdminBulkMailCampaign> visibleCampaigns;
  final int totalCount;
  final Set<int> selectedIds;
  final String statusFilter;
  final int page;
  final int pageSize;
  final TableSortState sortState;
  final TextEditingController searchController;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<int?> onPageSizeChanged;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<String> onSort;
  final ValueChanged<int> onToggleCampaign;
  final VoidCallback onToggleAllCampaigns;
  final VoidCallback onDeleteSelected;
  final VoidCallback onRefresh;
  final VoidCallback onCreate;
  final ValueChanged<AdminBulkMailCampaign> onDetail;
  final ValueChanged<AdminBulkMailCampaign> onEdit;
  final ValueChanged<AdminBulkMailCampaign> onStart;
  final ValueChanged<AdminBulkMailCampaign> onPause;
  final ValueChanged<AdminBulkMailCampaign> onResume;
  final ValueChanged<AdminBulkMailCampaign> onSchedule;
  final ValueChanged<AdminBulkMailCampaign> onCancel;
  final ValueChanged<AdminBulkMailCampaign> onDelete;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < AdminMobile.breakpoint;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _BulkMailMetricGrid(campaigns: campaigns),
            SizedBox(height: mobile ? 12 : 18),
            _BulkMailStatusFilters(
              selected: statusFilter,
              onChanged: onStatusChanged,
            ),
            const SizedBox(height: 12),
            _BulkMailToolbar(
              pageSize: pageSize,
              totalCount: totalCount,
              selectedCount: selectedIds.length,
              searchController: searchController,
              onPageSizeChanged: onPageSizeChanged,
              onSearchChanged: onSearchChanged,
              onDeleteSelected: onDeleteSelected,
              onRefresh: onRefresh,
              onCreate: onCreate,
            ),
            SizedBox(height: mobile ? 14 : 18),
            Expanded(
              child: _BulkMailTable(
                campaigns: visibleCampaigns,
                selectedIds: selectedIds,
                sortState: sortState,
                onToggleCampaign: onToggleCampaign,
                onToggleAllCampaigns: onToggleAllCampaigns,
                onSort: onSort,
                onDetail: onDetail,
                onEdit: onEdit,
                onStart: onStart,
                onPause: onPause,
                onResume: onResume,
                onSchedule: onSchedule,
                onCancel: onCancel,
                onDelete: onDelete,
              ),
            ),
            SizedBox(height: mobile ? 4 : 16),
            _BulkMailFooter(
              page: page,
              pageSize: pageSize,
              totalCount: totalCount,
              onPageChanged: onPageChanged,
            ),
          ],
        );
      },
    );
  }
}

class _BulkMailMetricGrid extends StatelessWidget {
  const _BulkMailMetricGrid({required this.campaigns});

  final List<AdminBulkMailCampaign> campaigns;

  int _statusCount(AdminBulkMailStatus status) {
    return campaigns.where((campaign) => campaign.status == status).length;
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      _MetricData(
        label: 'mail.campaign.total_bulk_mail',
        value: '${campaigns.length}',
        icon: Symbols.alternate_email,
        color: AppColors.deepOcean,
      ),
      _MetricData(
        label: 'mail.campaign.status.draft',
        value: '${_statusCount(AdminBulkMailStatus.draft)}',
        icon: Symbols.edit_square,
        color: AppColors.support,
      ),
      _MetricData(
        label: 'mail.campaign.status.sending',
        value: '${_statusCount(AdminBulkMailStatus.sending)}',
        icon: Symbols.schedule_send,
        color: const Color(0xFF3B82F6),
      ),
      _MetricData(
        label: 'mail.campaign.status.completed',
        value: '${_statusCount(AdminBulkMailStatus.completed)}',
        icon: Symbols.check,
        color: const Color(0xFF198754),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final density = width < 560
            ? _MetricDensity.tight
            : width < 840
            ? _MetricDensity.compact
            : _MetricDensity.regular;
        final gap = switch (density) {
          _MetricDensity.tight => 6.0,
          _MetricDensity.compact => 8.0,
          _MetricDensity.regular => 12.0,
        };

        return Row(
          children: [
            for (var index = 0; index < items.length; index++) ...[
              Expanded(
                child: _MetricBox(data: items[index], density: density),
              ),
              if (index != items.length - 1) SizedBox(width: gap),
            ],
          ],
        );
      },
    );
  }
}

class _MetricData {
  const _MetricData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

enum _MetricDensity { regular, compact, tight }

class _MetricBox extends StatelessWidget {
  const _MetricBox({required this.data, required this.density});

  final _MetricData data;
  final _MetricDensity density;

  @override
  Widget build(BuildContext context) {
    final isTight = density == _MetricDensity.tight;
    final isCompact = density == _MetricDensity.compact;
    final label = context.t(data.label);
    final minHeight = isTight
        ? 68.0
        : isCompact
        ? 72.0
        : 78.0;
    final horizontalPadding = isTight
        ? 8.0
        : isCompact
        ? 10.0
        : 14.0;
    final verticalPadding = isTight
        ? 8.0
        : isCompact
        ? 10.0
        : 12.0;
    final iconBoxSize = isTight
        ? 26.0
        : isCompact
        ? 30.0
        : 34.0;
    final iconSize = isTight
        ? 16.0
        : isCompact
        ? 17.0
        : 19.0;
    final gap = isTight
        ? 6.0
        : isCompact
        ? 8.0
        : 12.0;
    final labelStyle = TextStyle(
      color: AppColors.inkSoft,
      fontSize: isTight
          ? 10
          : isCompact
          ? 11
          : 12,
      height: 1,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    );
    final valueStyle = TextStyle(
      color: AppColors.deepOcean,
      fontSize: isTight
          ? 18
          : isCompact
          ? 19
          : 21,
      height: 1,
      fontWeight: FontWeight.w700,
      letterSpacing: 0,
    );

    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line.withValues(alpha: 0.72)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showLabel = constraints.maxWidth >= 96;
          final showIcon = constraints.maxWidth >= 68;

          Widget icon() {
            return Container(
              width: iconBoxSize,
              height: iconBoxSize,
              decoration: BoxDecoration(
                color: data.color.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(AppRadius.value),
              ),
              child: Center(
                child: SymbolIcon(data.icon, color: data.color, size: iconSize),
              ),
            );
          }

          if (!showLabel) {
            return Tooltip(
              message: label,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (showIcon) ...[icon(), SizedBox(width: gap)],
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(data.value, style: valueStyle),
                    ),
                  ),
                ],
              ),
            );
          }

          return Row(
            children: [
              if (showIcon) ...[icon(), SizedBox(width: gap)],
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: labelStyle,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: valueStyle,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BulkMailStatusFilters extends StatelessWidget {
  const _BulkMailStatusFilters({
    required this.selected,
    required this.onChanged,
  });

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final filters = [
      _StatusFilterData(
        value: bulkMailFilterAll,
        label: 'common.all',
        icon: Symbols.draft,
        count: null,
      ),
      ...AdminBulkMailStatus.values.map(
        (status) => _StatusFilterData(
          value: status.value,
          label: status.labelKey,
          icon: _iconForStatus(status),
          count: null,
        ),
      ),
    ];
    final selectedFilter = filters.firstWhere(
      (filter) => filter.value == selected,
      orElse: () => filters.first,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < AdminMobile.breakpoint;
        final width = mobile ? constraints.maxWidth : 280.0;

        return Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: width,
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.value),
                border: Border.all(
                  color: AppColors.line.withValues(alpha: 0.86),
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedFilter.value,
                  isExpanded: true,
                  borderRadius: BorderRadius.circular(AppRadius.value),
                  icon: const SymbolIcon(
                    Symbols.keyboard_arrow_down,
                    color: AppColors.iconMuted,
                    size: 18,
                  ),
                  selectedItemBuilder: (context) {
                    return filters.map((filter) {
                      return _StatusSelectLabel(filter: filter);
                    }).toList();
                  },
                  items: [
                    for (final filter in filters)
                      DropdownMenuItem<String>(
                        value: filter.value,
                        child: _StatusSelectLabel(filter: filter),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) onChanged(value);
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StatusFilterData {
  const _StatusFilterData({
    required this.value,
    required this.label,
    required this.icon,
    required this.count,
  });

  final String value;
  final String label;
  final IconData icon;
  final int? count;
}

class _StatusSelectLabel extends StatelessWidget {
  const _StatusSelectLabel({required this.filter});

  final _StatusFilterData filter;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SymbolIcon(filter.icon, color: AppColors.deepOcean, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            context.t(filter.label),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.deepOcean,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _BulkMailToolbar extends StatelessWidget {
  const _BulkMailToolbar({
    required this.pageSize,
    required this.totalCount,
    required this.selectedCount,
    required this.searchController,
    required this.onPageSizeChanged,
    required this.onSearchChanged,
    required this.onDeleteSelected,
    required this.onRefresh,
    required this.onCreate,
  });

  final int pageSize;
  final int totalCount;
  final int selectedCount;
  final TextEditingController searchController;
  final ValueChanged<int?> onPageSizeChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onDeleteSelected;
  final VoidCallback onRefresh;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final left = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PageSizeSelect(value: pageSize, onChanged: onPageSizeChanged),
            if (selectedCount > 0) ...[
              const SizedBox(width: 10),
              _SelectedDeleteButton(
                count: selectedCount,
                onPressed: onDeleteSelected,
              ),
            ],
          ],
        );
        final actions = Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: compact ? constraints.maxWidth : 280,
              child: _SearchField(
                controller: searchController,
                onChanged: onSearchChanged,
              ),
            ),
            _SoftActionButton(
              icon: Symbols.redo,
              label: 'mail.action.refresh',
              onPressed: onRefresh,
            ),
            _PrimaryActionButton(
              icon: Symbols.add,
              label: 'mail.campaign.new',
              onPressed: onCreate,
            ),
          ],
        );

        if (constraints.maxWidth < AdminMobile.breakpoint) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MailMobileSearchPanel(
                controller: searchController,
                query: searchController.text,
                hintText: context.t('mail.campaign.searchPlaceholder'),
                onSearchChanged: onSearchChanged,
                recordCount: totalCount,
                pageSize: pageSize,
                onPageSizeChanged: onPageSizeChanged,
              ),
              const SizedBox(height: 10),
              if (selectedCount > 0) ...[
                _SelectedDeleteButton(
                  count: selectedCount,
                  onPressed: onDeleteSelected,
                ),
                const SizedBox(height: 10),
              ],
              Row(
                children: [
                  Expanded(
                    child: _SoftActionButton(
                      icon: Symbols.redo,
                      label: 'mail.action.refresh',
                      onPressed: onRefresh,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _PrimaryActionButton(
                      icon: Symbols.add,
                      label: 'mail.campaign.new',
                      onPressed: onCreate,
                    ),
                  ),
                ],
              ),
            ],
          );
        }

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [left, const SizedBox(height: 12), actions],
          );
        }

        return Row(children: [left, const Spacer(), actions]);
      },
    );
  }
}

class _PageSizeSelect extends StatelessWidget {
  const _PageSizeSelect({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return AdminTablePageSizeSelect(value: value, onChanged: onChanged);
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return AdminTableSearchField(
      controller: controller,
      hintText: context.t('mail.campaign.searchPlaceholder'),
      onChanged: onChanged,
    );
  }
}

class _SelectedDeleteButton extends StatelessWidget {
  const _SelectedDeleteButton({required this.count, required this.onPressed});

  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return _SoftActionButton(
      icon: Symbols.delete,
      label: context.t(
        'mail.campaign.selectedDelete',
        values: {'count': count},
      ),
      translatedLabel: true,
      danger: true,
      onPressed: onPressed,
    );
  }
}

class _SoftActionButton extends StatelessWidget {
  const _SoftActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.translatedLabel = false,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool translatedLabel;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.actionRed : AppColors.deepOcean;

    return SizedBox(
      height: 38,
      child: TextButton(
        onPressed: onPressed,
        style:
            TextButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: color,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.value),
                side: BorderSide(color: AppColors.line.withValues(alpha: 0.82)),
              ),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ).copyWith(
              mouseCursor: const WidgetStatePropertyAll(
                SystemMouseCursors.click,
              ),
            ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SymbolIcon(icon, size: 17, color: color),
            const SizedBox(width: 8),
            Flexible(child: Text(translatedLabel ? label : context.t(label))),
          ],
        ),
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: TextButton(
        onPressed: onPressed,
        style:
            TextButton.styleFrom(
              backgroundColor: AppColors.actionRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.value),
              ),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ).copyWith(
              mouseCursor: const WidgetStatePropertyAll(
                SystemMouseCursors.click,
              ),
            ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SymbolIcon(icon, size: 17, color: Colors.white),
            const SizedBox(width: 7),
            Flexible(child: Text(context.t(label))),
          ],
        ),
      ),
    );
  }
}

class _BulkMailTable extends StatelessWidget {
  const _BulkMailTable({
    required this.campaigns,
    required this.selectedIds,
    required this.sortState,
    required this.onToggleCampaign,
    required this.onToggleAllCampaigns,
    required this.onSort,
    required this.onDetail,
    required this.onEdit,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onSchedule,
    required this.onCancel,
    required this.onDelete,
  });

  final List<AdminBulkMailCampaign> campaigns;
  final Set<int> selectedIds;
  final TableSortState sortState;
  final ValueChanged<int> onToggleCampaign;
  final VoidCallback onToggleAllCampaigns;
  final ValueChanged<String> onSort;
  final ValueChanged<AdminBulkMailCampaign> onDetail;
  final ValueChanged<AdminBulkMailCampaign> onEdit;
  final ValueChanged<AdminBulkMailCampaign> onStart;
  final ValueChanged<AdminBulkMailCampaign> onPause;
  final ValueChanged<AdminBulkMailCampaign> onResume;
  final ValueChanged<AdminBulkMailCampaign> onSchedule;
  final ValueChanged<AdminBulkMailCampaign> onCancel;
  final ValueChanged<AdminBulkMailCampaign> onDelete;

  static const _selectWidth = 42.0;
  static const _campaignWidth = 220.0;
  static const _recipientWidth = 84.0;
  static const _metricWidth = 90.0;
  static const _bounceWidth = 78.0;
  static const _statusWidth = 110.0;
  static const _controlWidth = 112.0;
  static const _dateWidth = 150.0;
  static const _menuWidth = 70.0;
  static const _horizontalPadding = 32.0;
  static const _columnsMinWidth =
      _selectWidth +
      _campaignWidth +
      _recipientWidth +
      (_metricWidth * 3) +
      _bounceWidth +
      _statusWidth +
      _controlWidth +
      _dateWidth +
      _menuWidth;
  static const _minWidth = _columnsMinWidth + _horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final allSelected =
        campaigns.isNotEmpty &&
        campaigns.every((campaign) => selectedIds.contains(campaign.id));
    final someSelected =
        campaigns.any((campaign) => selectedIds.contains(campaign.id)) &&
        !allSelected;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < AdminMobile.breakpoint) {
          return AdminMobileListView(
            loading: false,
            itemCount: campaigns.length,
            emptyLabel: context.t('mail.campaign.empty'),
            itemBuilder: (context, index) {
              final campaign = campaigns[index];
              return _BulkMailMobileCard(
                campaign: campaign,
                selected: selectedIds.contains(campaign.id),
                onToggle: () => onToggleCampaign(campaign.id),
                onDetail: onDetail,
                onEdit: onEdit,
                onStart: onStart,
                onPause: onPause,
                onResume: onResume,
                onSchedule: onSchedule,
                onCancel: onCancel,
                onDelete: onDelete,
              );
            },
          );
        }

        final tableWidth = constraints.maxWidth < _minWidth
            ? _minWidth
            : constraints.maxWidth;
        final contentWidth = tableWidth - _horizontalPadding;
        final extraWidth = (contentWidth - _columnsMinWidth)
            .clamp(0.0, double.infinity)
            .toDouble();
        final campaignWidth = _campaignWidth + extraWidth * 0.36;
        final recipientWidth = _recipientWidth + extraWidth * 0.06;
        final metricWidth = _metricWidth + extraWidth * 0.06;
        final bounceWidth = _bounceWidth + extraWidth * 0.05;
        final statusWidth = _statusWidth + extraWidth * 0.08;
        final controlWidth = _controlWidth + extraWidth * 0.08;
        final dateWidth = _dateWidth + extraWidth * 0.15;
        final menuWidth = _menuWidth + extraWidth * 0.04;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.value),
            border: Border.all(color: AppColors.line.withValues(alpha: 0.72)),
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              child: Column(
                children: [
                  Container(
                    height: 58,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: AppColors.softLine.withValues(alpha: 0.86),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: _selectWidth,
                          child: _BulkMailCheckbox(
                            value: allSelected
                                ? true
                                : someSelected
                                ? null
                                : false,
                            tristate: true,
                            onChanged: (_) => onToggleAllCampaigns(),
                          ),
                        ),
                        _HeaderSortable(
                          width: campaignWidth,
                          label: 'mail.campaign.bulk_mail',
                          sortKey: 'name',
                          sortState: sortState,
                          onSort: onSort,
                        ),
                        _HeaderSortable(
                          width: recipientWidth,
                          label: 'common.recipient',
                          sortKey: 'recipient',
                          sortState: sortState,
                          onSort: onSort,
                          centered: true,
                        ),
                        _HeaderSortable(
                          width: metricWidth,
                          label: 'common.sent',
                          sortKey: 'sent',
                          sortState: sortState,
                          onSort: onSort,
                          centered: true,
                        ),
                        _HeaderSortable(
                          width: metricWidth,
                          label: 'common.opening',
                          sortKey: 'open',
                          sortState: sortState,
                          onSort: onSort,
                          centered: true,
                        ),
                        _HeaderSortable(
                          width: metricWidth,
                          label: 'common.clicking',
                          sortKey: 'click',
                          sortState: sortState,
                          onSort: onSort,
                          centered: true,
                        ),
                        _HeaderSortable(
                          width: bounceWidth,
                          label: 'Bounce',
                          sortKey: 'bounce',
                          sortState: sortState,
                          onSort: onSort,
                          translated: true,
                          centered: true,
                        ),
                        _HeaderSortable(
                          width: statusWidth,
                          label: 'common.status',
                          sortKey: 'status',
                          sortState: sortState,
                          onSort: onSort,
                        ),
                        SizedBox(
                          width: controlWidth,
                          child: _HeaderText('mail.campaign.control'),
                        ),
                        _HeaderSortable(
                          width: dateWidth,
                          label: 'mail.campaign.startDate',
                          sortKey: 'date',
                          sortState: sortState,
                          onSort: onSort,
                        ),
                        SizedBox(
                          width: menuWidth,
                          child: _HeaderText('common.action', centered: true),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: campaigns.isEmpty
                        ? const _BulkMailEmpty()
                        : ListView.builder(
                            itemCount: campaigns.length,
                            itemBuilder: (context, index) {
                              final campaign = campaigns[index];
                              return _BulkMailRow(
                                campaign: campaign,
                                campaignWidth: campaignWidth,
                                recipientWidth: recipientWidth,
                                metricWidth: metricWidth,
                                bounceWidth: bounceWidth,
                                statusWidth: statusWidth,
                                controlWidth: controlWidth,
                                dateWidth: dateWidth,
                                menuWidth: menuWidth,
                                selected: selectedIds.contains(campaign.id),
                                onToggle: () => onToggleCampaign(campaign.id),
                                onDetail: onDetail,
                                onEdit: onEdit,
                                onStart: onStart,
                                onPause: onPause,
                                onResume: onResume,
                                onSchedule: onSchedule,
                                onCancel: onCancel,
                                onDelete: onDelete,
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HeaderSortable extends StatelessWidget {
  const _HeaderSortable({
    required this.width,
    required this.label,
    required this.sortKey,
    required this.sortState,
    required this.onSort,
    this.translated = false,
    this.centered = false,
  });

  final double width;
  final String label;
  final String sortKey;
  final TableSortState sortState;
  final ValueChanged<String> onSort;
  final bool translated;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    if (translated) {
      return SizedBox(
        width: width,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onSort(sortKey),
            child: Row(
              mainAxisAlignment: centered
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: centered ? TextAlign.center : TextAlign.start,
                    style: TextStyle(
                      color: sortState.key == sortKey
                          ? AppColors.deepOcean
                          : AppColors.inkSoft,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                SymbolIcon(
                  Symbols.keyboard_arrow_down,
                  color: sortState.key == sortKey
                      ? AppColors.deepOcean
                      : AppColors.support,
                  size: 14,
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (centered) {
      final selected = sortState.key == sortKey;
      final icon = SymbolIcon(
        Symbols.keyboard_arrow_down,
        color: selected ? AppColors.deepOcean : AppColors.support,
        size: 14,
      );

      return SizedBox(
        width: width,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onSort(sortKey),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    context.t(label),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selected ? AppColors.deepOcean : AppColors.inkSoft,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                selected && sortState.ascending
                    ? RotatedBox(quarterTurns: 2, child: icon)
                    : icon,
              ],
            ),
          ),
        ),
      );
    }

    final selected = sortState.key == sortKey;
    final icon = SymbolIcon(
      Symbols.keyboard_arrow_down,
      color: selected ? AppColors.deepOcean : AppColors.support,
      size: 14,
    );

    return SizedBox(
      width: width,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onSort(sortKey),
          child: Row(
            children: [
              Flexible(
                fit: FlexFit.loose,
                child: Text(
                  context.t(label),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? AppColors.deepOcean : AppColors.inkSoft,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              selected && sortState.ascending
                  ? RotatedBox(quarterTurns: 2, child: icon)
                  : icon,
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderText extends StatelessWidget {
  const _HeaderText(this.label, {this.centered = false});

  final String label;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: centered ? Alignment.center : Alignment.centerLeft,
      child: Text(
        context.t(label),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: centered ? TextAlign.center : TextAlign.start,
        style: const TextStyle(
          color: AppColors.inkSoft,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _BulkMailRow extends StatelessWidget {
  const _BulkMailRow({
    required this.campaign,
    required this.campaignWidth,
    required this.recipientWidth,
    required this.metricWidth,
    required this.bounceWidth,
    required this.statusWidth,
    required this.controlWidth,
    required this.dateWidth,
    required this.menuWidth,
    required this.selected,
    required this.onToggle,
    required this.onDetail,
    required this.onEdit,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onSchedule,
    required this.onCancel,
    required this.onDelete,
  });

  final AdminBulkMailCampaign campaign;
  final double campaignWidth;
  final double recipientWidth;
  final double metricWidth;
  final double bounceWidth;
  final double statusWidth;
  final double controlWidth;
  final double dateWidth;
  final double menuWidth;
  final bool selected;
  final VoidCallback onToggle;
  final ValueChanged<AdminBulkMailCampaign> onDetail;
  final ValueChanged<AdminBulkMailCampaign> onEdit;
  final ValueChanged<AdminBulkMailCampaign> onStart;
  final ValueChanged<AdminBulkMailCampaign> onPause;
  final ValueChanged<AdminBulkMailCampaign> onResume;
  final ValueChanged<AdminBulkMailCampaign> onSchedule;
  final ValueChanged<AdminBulkMailCampaign> onCancel;
  final ValueChanged<AdminBulkMailCampaign> onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 92),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: selected ? AppColors.surface : Colors.white,
        border: Border(
          bottom: BorderSide(color: AppColors.softLine.withValues(alpha: 0.86)),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _BulkMailTable._selectWidth,
            child: _BulkMailCheckbox(
              value: selected,
              onChanged: (_) => onToggle(),
            ),
          ),
          SizedBox(
            width: campaignWidth,
            child: _RowTapTarget(
              onTap: () => onDetail(campaign),
              child: _CampaignCell(campaign: campaign),
            ),
          ),
          SizedBox(
            width: recipientWidth,
            child: _TextCell(value: '${campaign.recipientCount}'),
          ),
          SizedBox(
            width: metricWidth,
            child: _TextCell(value: '${campaign.sentCount}'),
          ),
          SizedBox(
            width: metricWidth,
            child: _RateCell(
              count: campaign.openCount,
              rate: campaign.openRate,
            ),
          ),
          SizedBox(
            width: metricWidth,
            child: _RateCell(
              count: campaign.clickCount,
              rate: campaign.clickRate,
            ),
          ),
          SizedBox(
            width: bounceWidth,
            child: _RateCell(
              count: campaign.bounceCount,
              rate: campaign.bounceRate,
            ),
          ),
          SizedBox(
            width: statusWidth,
            child: _CampaignStatusBadge(status: campaign.status),
          ),
          SizedBox(
            width: controlWidth,
            child: _CampaignControlButton(
              campaign: campaign,
              onStart: () => onStart(campaign),
              onPause: () => onPause(campaign),
              onResume: () => onResume(campaign),
            ),
          ),
          SizedBox(
            width: dateWidth,
            child: _CampaignDateCell(campaign: campaign),
          ),
          SizedBox(
            width: menuWidth,
            child: Align(
              alignment: Alignment.center,
              child: _BulkMailRowMenu(
                campaign: campaign,
                onDetail: () => onDetail(campaign),
                onEdit: () => onEdit(campaign),
                onStart: () => onStart(campaign),
                onPause: () => onPause(campaign),
                onResume: () => onResume(campaign),
                onSchedule: () => onSchedule(campaign),
                onCancel: () => onCancel(campaign),
                onDelete: () => onDelete(campaign),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BulkMailMobileCard extends StatelessWidget {
  const _BulkMailMobileCard({
    required this.campaign,
    required this.selected,
    required this.onToggle,
    required this.onDetail,
    required this.onEdit,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onSchedule,
    required this.onCancel,
    required this.onDelete,
  });

  final AdminBulkMailCampaign campaign;
  final bool selected;
  final VoidCallback onToggle;
  final ValueChanged<AdminBulkMailCampaign> onDetail;
  final ValueChanged<AdminBulkMailCampaign> onEdit;
  final ValueChanged<AdminBulkMailCampaign> onStart;
  final ValueChanged<AdminBulkMailCampaign> onPause;
  final ValueChanged<AdminBulkMailCampaign> onResume;
  final ValueChanged<AdminBulkMailCampaign> onSchedule;
  final ValueChanged<AdminBulkMailCampaign> onCancel;
  final ValueChanged<AdminBulkMailCampaign> onDelete;

  @override
  Widget build(BuildContext context) {
    final status = campaign.status;
    final date =
        '${formatAdminFullDate(context, campaign.tableDate)} ${formatAdminTime(campaign.tableDate)}';

    return AdminMobileCard(
      selected: selected,
      onTap: () => onDetail(campaign),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: AdminMobileCheckbox(
                  value: selected,
                  onChanged: (_) => onToggle(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      campaign.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF2F4053),
                        fontWeight: FontWeight.w700,
                        fontSize: 14.2,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      campaign.subject,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF7A7F85),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        height: 1.18,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Transform.scale(
                scale: 0.88,
                alignment: Alignment.topRight,
                child: AdminMobileMenuButton(
                  tooltip: context.t('mail.campaign.actions'),
                  actions: [
                    AdminMobileMenuAction(
                      icon: Symbols.visibility,
                      label: context.t('mail.campaign.action.detail'),
                      onTap: () => onDetail(campaign),
                    ),
                    AdminMobileMenuAction(
                      icon: Symbols.edit_square,
                      label: context.t('mail.campaign.action.edit'),
                      onTap: () => onEdit(campaign),
                    ),
                    if (status.canStart)
                      AdminMobileMenuAction(
                        icon: Symbols.schedule_send,
                        label: context.t('mail.campaign.action.start'),
                        onTap: () => onStart(campaign),
                      ),
                    if (status.canSchedule)
                      AdminMobileMenuAction(
                        icon: Symbols.schedule,
                        label: context.t('mail.campaign.action.schedule'),
                        onTap: () => onSchedule(campaign),
                      ),
                    if (status.canPause)
                      AdminMobileMenuAction(
                        icon: Symbols.pending_actions,
                        label: context.t('mail.campaign.action.pause'),
                        onTap: () => onPause(campaign),
                      ),
                    if (status.canResume)
                      AdminMobileMenuAction(
                        icon: Symbols.schedule_send,
                        label: context.t('mail.campaign.action.continue'),
                        onTap: () => onResume(campaign),
                      ),
                    if (status != AdminBulkMailStatus.completed &&
                        status != AdminBulkMailStatus.cancelled)
                      AdminMobileMenuAction(
                        icon: Symbols.close,
                        label: context.t('mail.campaign.action.cancel'),
                        onTap: () => onCancel(campaign),
                      ),
                    AdminMobileMenuAction(
                      icon: Symbols.delete,
                      label: context.t('common.delete'),
                      danger: true,
                      onTap: () => onDelete(campaign),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.value),
                  child: LinearProgressIndicator(
                    value: campaign.progress,
                    minHeight: 5,
                    backgroundColor: AppColors.softLine,
                    color: status.dotColor,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${(campaign.progress * 100).round()}%',
                style: const TextStyle(
                  color: AppColors.inkSoft,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AdminMobileStatusPill(
                label: context.t(status.labelKey),
                color: status.dotColor,
              ),
              AdminMobileMeta(
                icon: Symbols.group,
                value:
                    '${campaign.recipientCount} ${context.t('common.recipient')}',
              ),
              AdminMobileMeta(
                icon: Symbols.check,
                value: '${campaign.sentCount} ${context.t('common.sent')}',
              ),
              AdminMobileMeta(
                icon: Symbols.visibility,
                value:
                    '${campaign.openCount} / ${(campaign.openRate * 100).toStringAsFixed(1)}%',
              ),
              AdminMobileMeta(
                icon: Symbols.cursor_hand,
                value:
                    '${campaign.clickCount} / ${(campaign.clickRate * 100).toStringAsFixed(1)}%',
              ),
              AdminMobileMeta(
                icon: Symbols.close,
                value:
                    '${campaign.bounceCount} / ${(campaign.bounceRate * 100).toStringAsFixed(1)}%',
              ),
              AdminMobileMeta(icon: Symbols.schedule, value: date),
            ],
          ),
          const SizedBox(height: 12),
          _CampaignControlButton(
            campaign: campaign,
            onStart: () => onStart(campaign),
            onPause: () => onPause(campaign),
            onResume: () => onResume(campaign),
          ),
        ],
      ),
    );
  }
}

class _BulkMailCheckbox extends StatelessWidget {
  const _BulkMailCheckbox({
    required this.value,
    required this.onChanged,
    this.tristate = false,
  });

  final bool? value;
  final ValueChanged<bool?> onChanged;
  final bool tristate;

  @override
  Widget build(BuildContext context) {
    return Checkbox(
      value: value,
      tristate: tristate,
      mouseCursor: SystemMouseCursors.click,
      activeColor: AppColors.deepOcean,
      checkColor: Colors.white,
      side: BorderSide(color: AppColors.line.withValues(alpha: 0.76)),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      onChanged: onChanged,
    );
  }
}

class _RowTapTarget extends StatelessWidget {
  const _RowTapTarget({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: child,
      ),
    );
  }
}

class _CampaignCell extends StatelessWidget {
  const _CampaignCell({required this.campaign});

  final AdminBulkMailCampaign campaign;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 18),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            campaign.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.deepOcean,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            campaign.subject,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.inkSoft,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.value),
                  child: LinearProgressIndicator(
                    value: campaign.progress,
                    minHeight: 5,
                    backgroundColor: AppColors.softLine,
                    color: campaign.status.dotColor,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${(campaign.progress * 100).round()}%',
                style: const TextStyle(
                  color: AppColors.inkSoft,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            context.t(
              'mail.campaign.sent_progress',
              values: {
                'sent': campaign.sentCount,
                'total': campaign.recipientCount,
              },
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.support,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _TextCell extends StatelessWidget {
  const _TextCell({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.deepOcean,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _RateCell extends StatelessWidget {
  const _RateCell({required this.count, required this.rate});

  final int count;
  final double rate;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          '$count',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.deepOcean,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          '${(rate * 100).toStringAsFixed(1)}%',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.support,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _CampaignStatusBadge extends StatelessWidget {
  const _CampaignStatusBadge({required this.status});

  final AdminBulkMailStatus status;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: status.backgroundColor,
          borderRadius: BorderRadius.circular(AppRadius.value),
          border: Border.all(color: status.dotColor.withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: status.dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                context.t(status.labelKey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: status.dotColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CampaignControlButton extends StatelessWidget {
  const _CampaignControlButton({
    required this.campaign,
    required this.onStart,
    required this.onPause,
    required this.onResume,
  });

  final AdminBulkMailCampaign campaign;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final status = campaign.status;
    final label = status.canPause
        ? 'mail.campaign.action.pause'
        : status.canResume
        ? 'mail.campaign.action.continue'
        : status.canStart
        ? 'mail.campaign.action.start'
        : null;
    final action = status.canPause
        ? onPause
        : status.canResume
        ? onResume
        : status.canStart
        ? onStart
        : null;
    final icon = status.canPause
        ? Symbols.pending_actions
        : status.canResume || status.canStart
        ? Symbols.schedule_send
        : Symbols.check;

    if (label == null || action == null) {
      return const Text(
        '-',
        style: TextStyle(
          color: AppColors.support,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        height: 32,
        child: TextButton(
          onPressed: action,
          style:
              TextButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.deepOcean,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.value),
                  side: BorderSide(
                    color: AppColors.line.withValues(alpha: 0.82),
                  ),
                ),
                textStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ).copyWith(
                mouseCursor: const WidgetStatePropertyAll(
                  SystemMouseCursors.click,
                ),
              ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SymbolIcon(icon, size: 16),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  context.t(label),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CampaignDateCell extends StatelessWidget {
  const _CampaignDateCell({required this.campaign});

  final AdminBulkMailCampaign campaign;

  @override
  Widget build(BuildContext context) {
    final primary = formatAdminFullDate(context, campaign.tableDate);
    final time = formatAdminTime(campaign.tableDate);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          primary,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.deepOcean,
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          time,
          style: const TextStyle(
            color: AppColors.support,
            fontSize: 10,
            fontWeight: FontWeight.w400,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _BulkMailRowMenu extends StatefulWidget {
  const _BulkMailRowMenu({
    required this.campaign,
    required this.onDetail,
    required this.onEdit,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onSchedule,
    required this.onCancel,
    required this.onDelete,
  });

  final AdminBulkMailCampaign campaign;
  final VoidCallback onDetail;
  final VoidCallback onEdit;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onSchedule;
  final VoidCallback onCancel;
  final VoidCallback onDelete;

  @override
  State<_BulkMailRowMenu> createState() => _BulkMailRowMenuState();
}

class _BulkMailRowMenuState extends State<_BulkMailRowMenu> {
  final _layerLink = LayerLink();
  OverlayEntry? _menuEntry;

  @override
  void dispose() {
    _closeMenu();
    super.dispose();
  }

  void _openMenu() {
    if (_menuEntry != null) return;

    _menuEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _closeMenu,
                child: const SizedBox.expand(),
              ),
            ),
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              targetAnchor: Alignment.bottomRight,
              followerAnchor: Alignment.topRight,
              offset: const Offset(0, 8),
              child: _BulkMailMenuCard(
                campaign: widget.campaign,
                onDetail: () => _runAndClose(widget.onDetail),
                onEdit: () => _runAndClose(widget.onEdit),
                onStart: () => _runAndClose(widget.onStart),
                onPause: () => _runAndClose(widget.onPause),
                onResume: () => _runAndClose(widget.onResume),
                onSchedule: () => _runAndClose(widget.onSchedule),
                onCancel: () => _runAndClose(widget.onCancel),
                onDelete: () => _runAndClose(widget.onDelete),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(_menuEntry!);
  }

  void _runAndClose(VoidCallback action) {
    _closeMenu();
    action();
  }

  void _closeMenu() {
    _menuEntry?.remove();
    _menuEntry = null;
  }

  void _toggleMenu() {
    if (_menuEntry == null) {
      _openMenu();
    } else {
      _closeMenu();
    }
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Tooltip(
        message: context.t('mail.campaign.actions'),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleMenu,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Text(
                '...',
                style: TextStyle(
                  color: AppColors.support.withValues(alpha: 0.92),
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BulkMailMenuCard extends StatelessWidget {
  const _BulkMailMenuCard({
    required this.campaign,
    required this.onDetail,
    required this.onEdit,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onSchedule,
    required this.onCancel,
    required this.onDelete,
  });

  final AdminBulkMailCampaign campaign;
  final VoidCallback onDetail;
  final VoidCallback onEdit;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onSchedule;
  final VoidCallback onCancel;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final status = campaign.status;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 232,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.value),
          border: Border.all(color: AppColors.line),
          boxShadow: [
            BoxShadow(
              color: AppColors.deepOcean.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _BulkMailMenuItem(
              icon: Symbols.visibility,
              label: 'mail.campaign.action.detail',
              onTap: onDetail,
            ),
            _BulkMailMenuItem(
              icon: Symbols.edit_square,
              label: 'mail.campaign.action.edit',
              onTap: onEdit,
            ),
            if (status.canStart)
              _BulkMailMenuItem(
                icon: Symbols.schedule_send,
                label: 'mail.campaign.action.start',
                onTap: onStart,
              ),
            if (status.canSchedule)
              _BulkMailMenuItem(
                icon: Symbols.schedule,
                label: 'mail.campaign.action.schedule',
                onTap: onSchedule,
              ),
            if (status.canPause)
              _BulkMailMenuItem(
                icon: Symbols.pending_actions,
                label: 'mail.campaign.action.pause',
                onTap: onPause,
              ),
            if (status.canResume)
              _BulkMailMenuItem(
                icon: Symbols.schedule_send,
                label: 'mail.campaign.action.continue',
                onTap: onResume,
              ),
            if (status != AdminBulkMailStatus.completed &&
                status != AdminBulkMailStatus.cancelled)
              _BulkMailMenuItem(
                icon: Symbols.close,
                label: 'mail.campaign.action.cancel',
                onTap: onCancel,
              ),
            _BulkMailMenuItem(
              icon: Symbols.delete,
              label: 'common.delete',
              onTap: onDelete,
              danger: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _BulkMailMenuItem extends StatelessWidget {
  const _BulkMailMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.actionRed : AppColors.deepOcean;

    return InkWell(
      mouseCursor: SystemMouseCursors.click,
      borderRadius: BorderRadius.circular(AppRadius.value),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          children: [
            SymbolIcon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.t(label),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BulkMailEmpty extends StatelessWidget {
  const _BulkMailEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        context.t('mail.campaign.empty'),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.inkSoft,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _BulkMailFooter extends StatelessWidget {
  const _BulkMailFooter({
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
    final lastPage = totalCount == 0 ? 1 : ((totalCount - 1) ~/ pageSize) + 1;
    final from = totalCount == 0 ? 0 : ((page - 1) * pageSize) + 1;
    final to = totalCount == 0
        ? 0
        : (page * pageSize > totalCount ? totalCount : page * pageSize);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 640;
        final rangeText = context.t(
          'common.recordRange',
          values: {'from': from, 'to': to, 'total': totalCount},
        );
        final summary = Text(
          rangeText,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.inkSoft,
            fontWeight: FontWeight.w500,
            letterSpacing: 0,
          ),
        );
        final pager = _BulkMailPagination(
          page: page,
          lastPage: lastPage,
          onPageChanged: onPageChanged,
        );

        if (compact) {
          return AdminMobilePager(
            page: page,
            lastPage: lastPage,
            rangeText: rangeText,
            loading: false,
            onPageChanged: onPageChanged,
          );
        }

        return Column(
          children: [
            const Divider(height: 1, color: AppColors.line),
            const SizedBox(height: 16),
            Row(children: [summary, const Spacer(), pager]),
          ],
        );
      },
    );
  }
}

class _BulkMailPagination extends StatelessWidget {
  const _BulkMailPagination({
    required this.page,
    required this.lastPage,
    required this.onPageChanged,
  });

  final int page;
  final int lastPage;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return AdminTablePagination(
      page: page,
      pageCount: lastPage,
      onPageChanged: onPageChanged,
    );
  }
}

class _BulkMailDetailDialog extends StatelessWidget {
  const _BulkMailDetailDialog({required this.campaign});

  final AdminBulkMailCampaign campaign;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.t('mail.campaign.detailTitle'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.deepOcean,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  mouseCursor: SystemMouseCursors.click,
                  icon: const SymbolIcon(
                    Symbols.close,
                    color: AppColors.deepOcean,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DetailHeader(campaign: campaign),
                  const SizedBox(height: 20),
                  _DetailGrid(campaign: campaign),
                  const SizedBox(height: 22),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.value),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Text(
                      campaign.preview,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.deepOcean,
                        height: 1.55,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(28, 14, 28, 22),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.softLine)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style:
                      TextButton.styleFrom(
                        foregroundColor: AppColors.deepOcean,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ).copyWith(
                        mouseCursor: const WidgetStatePropertyAll(
                          SystemMouseCursors.click,
                        ),
                      ),
                  child: Text(context.t('common.cancel')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({required this.campaign});

  final AdminBulkMailCampaign campaign;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
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
              color: campaign.status.backgroundColor,
              borderRadius: BorderRadius.circular(AppRadius.value),
            ),
            child: Center(
              child: SymbolIcon(
                _iconForStatus(campaign.status),
                color: campaign.status.dotColor,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  campaign.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.deepOcean,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  campaign.subject,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.inkSoft,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          _CampaignStatusBadge(status: campaign.status),
        ],
      ),
    );
  }
}

class _DetailGrid extends StatelessWidget {
  const _DetailGrid({required this.campaign});

  final AdminBulkMailCampaign campaign;

  @override
  Widget build(BuildContext context) {
    final items = [
      _DetailItem(
        label: 'mail.campaign.template',
        value: campaign.templateName,
      ),
      _DetailItem(
        label: 'mail.campaign.senderAccount',
        value: campaign.senderAccount,
      ),
      _DetailItem(
        label: 'mail.campaign.contactList',
        value: campaign.recipientList,
      ),
      _DetailItem(
        label: 'common.recipient',
        value: '${campaign.recipientCount}',
      ),
      _DetailItem(label: 'common.sent', value: '${campaign.sentCount}'),
      _DetailItem(
        label: 'mail.campaign.startDate',
        value:
            '${formatAdminFullDate(context, campaign.tableDate)} '
            '${formatAdminTime(campaign.tableDate)}',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 620 ? 1 : 3;
        final spacing = 12.0;
        final itemWidth =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final item in items) SizedBox(width: itemWidth, child: item),
          ],
        );
      },
    );
  }
}

class _DetailItem extends StatelessWidget {
  const _DetailItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t(label),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.support,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.deepOcean,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _BulkMailCreateDialog extends StatefulWidget {
  const _BulkMailCreateDialog({
    this.campaign,
    required this.session,
    required this.repository,
    required this.templates,
    required this.accounts,
    required this.lists,
  });

  final AdminBulkMailCampaign? campaign;
  final AdminSession session;
  final AdminMailRepository repository;
  final List<AdminMailTemplate> templates;
  final List<AdminMailAccount> accounts;
  final List<AdminContactList> lists;

  @override
  State<_BulkMailCreateDialog> createState() => _BulkMailCreateDialogState();
}

class _BulkMailCreateDialogState extends State<_BulkMailCreateDialog> {
  static const _emptyTemplateOption = '';
  static const _emptyAccountOption = '';
  static const _emptyListOption = '';

  late final TextEditingController _nameController;
  late final TextEditingController _subjectController;
  late final TextEditingController _previewController;
  late String _category;
  late String _template;
  late String _account;
  late String _recipientList;
  DateTime? _scheduledAt;
  final _previewContactByListId = <int, AdminMailContact?>{};
  var _previewContactRequestId = 0;
  AdminMailContact? _previewContact;

  List<AdminMailTemplate> get _usableTemplates => widget.templates
      .where((template) => template.active && template.ready)
      .toList(growable: false);

  List<AdminContactList> get _usableLists => widget.lists;

  List<AdminMailTemplateCategory> get _availableCategories {
    final categories = <AdminMailTemplateCategory>[];
    for (final template in _usableTemplates) {
      if (!categories.contains(template.category)) {
        categories.add(template.category);
      }
    }
    return categories.isEmpty
        ? AdminMailTemplateCategory.values
        : categories.toList(growable: false);
  }

  AdminMailTemplateCategory get _selectedCategoryValue {
    final category = _categoryFromValue(_category);
    return category != null && _availableCategories.contains(category)
        ? category
        : _availableCategories.first;
  }

  List<AdminMailTemplate> get _templatesForCategory {
    final category = _selectedCategoryValue;
    return _usableTemplates
        .where((template) => template.category == category)
        .toList(growable: false);
  }

  List<_SelectOption> get _categoryOptions => _availableCategories
      .map(
        (category) =>
            _SelectOption(value: category.value, label: category.labelKey),
      )
      .toList(growable: false);

  List<_SelectOption> get _templateOptions => [
    const _SelectOption(
      value: _emptyTemplateOption,
      label: 'mail.campaign.templatePlaceholder',
    ),
    ..._templatesForCategory.map(
      (template) =>
          _SelectOption(value: template.id.toString(), label: template.nameKey),
    ),
  ];

  List<_SelectOption> get _accountOptions => widget.accounts.isEmpty
      ? const [
          _SelectOption(
            value: _emptyAccountOption,
            label: 'mail.settings.empty',
          ),
        ]
      : widget.accounts
            .map(
              (account) => _SelectOption(
                value: account.id.toString(),
                label: account.accountName,
              ),
            )
            .toList(growable: false);

  List<_SelectOption> get _listOptions => _usableLists.isEmpty
      ? const [
          _SelectOption(value: _emptyListOption, label: 'mail.contacts.empty'),
        ]
      : _usableLists
            .map(
              (list) => _SelectOption(
                value: list.id.toString(),
                label: '${list.name} (${list.contactCount})',
              ),
            )
            .toList(growable: false);

  @override
  void initState() {
    super.initState();
    final campaign = widget.campaign;
    final initialTemplate = _initialTemplate(campaign);
    final preferredCategory =
        initialTemplate?.category ??
        _categoryFromLabel(campaign?.templateCategory) ??
        _availableCategories.first;
    final initialCategory = _availableCategories.contains(preferredCategory)
        ? preferredCategory
        : _availableCategories.first;
    final firstTemplate = initialTemplate ?? _firstTemplateFor(initialCategory);
    final initialAccount = _initialAccount(campaign);
    final initialList = _initialList(campaign);

    _nameController = TextEditingController(text: campaign?.name ?? '');
    _subjectController = TextEditingController(
      text: campaign?.subject ?? firstTemplate?.subject ?? '',
    );
    _previewController = TextEditingController(
      text: campaign?.preview ?? firstTemplate?.previewText ?? '',
    );
    _category = initialCategory.value;
    _template = firstTemplate?.id.toString() ?? _emptyTemplateOption;
    _account =
        initialAccount?.id.toString() ??
        (widget.accounts.isNotEmpty
            ? widget.accounts.first.id.toString()
            : _emptyAccountOption);
    _recipientList =
        initialList?.id.toString() ??
        (_usableLists.isNotEmpty
            ? _usableLists.first.id.toString()
            : _emptyListOption);
    _scheduledAt = campaign?.scheduledAt;
    _nameController.addListener(_refresh);
    _subjectController.addListener(_refresh);
    _previewController.addListener(_refresh);
    _loadPreviewContactForSelectedList();
  }

  @override
  void dispose() {
    _nameController
      ..removeListener(_refresh)
      ..dispose();
    _subjectController
      ..removeListener(_refresh)
      ..dispose();
    _previewController
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _pickSchedule() async {
    final picked = await showAdminDateTimePicker(
      context,
      initialValue:
          _scheduledAt ?? DateTime.now().add(const Duration(hours: 1)),
    );
    if (picked == null || !mounted) return;
    setState(() => _scheduledAt = picked);
  }

  void _clearSchedule() {
    setState(() => _scheduledAt = null);
  }

  bool get _scheduleValid =>
      _scheduledAt == null || _scheduledAt!.isAfter(DateTime.now());

  bool get _canSave =>
      _selectedAccount() != null &&
      (_selectedList()?.contactCount ?? 0) > 0 &&
      _selectedTemplate() != null &&
      _nameController.text.trim().isNotEmpty &&
      _subjectController.text.trim().isNotEmpty &&
      _previewController.text.trim().isNotEmpty &&
      _scheduleValid;

  void _save() {
    if (!_canSave) return;
    final previous = widget.campaign;
    final now = DateTime.now();
    final selectedAccount = _selectedAccount();
    final selectedTemplate = _selectedTemplate();
    final selectedList = _selectedList();
    if (selectedAccount == null || selectedList == null) {
      return;
    }
    final campaign = AdminBulkMailCampaign(
      id: previous?.id ?? now.millisecondsSinceEpoch.remainder(100000),
      accountId: selectedAccount.id.toString(),
      templateId: selectedTemplate?.id.toString() ?? '',
      contactListId: selectedList.id.toString(),
      name: _nameController.text.trim(),
      subject: _subjectController.text.trim(),
      preview: _previewController.text.trim(),
      contentHtml: selectedTemplate?.body ?? '',
      templateName: selectedTemplate?.nameKey ?? '',
      templateCategory: selectedTemplate == null
          ? context.t(_selectedCategoryValue.labelKey)
          : context.t(selectedTemplate.category.labelKey),
      senderAccount: selectedAccount.accountName,
      senderEmail: selectedAccount.senderEmail,
      recipientList: selectedList.name,
      recipientCount: selectedList.contactCount,
      sentCount: previous?.sentCount ?? 0,
      openCount: previous?.openCount ?? 0,
      clickCount: previous?.clickCount ?? 0,
      bounceCount: previous?.bounceCount ?? 0,
      status: _statusForSchedule(previous),
      createdAt: previous?.createdAt ?? now,
      startedAt: previous?.startedAt,
      scheduledAt: _scheduledAt,
    );
    Navigator.of(context).pop(campaign);
  }

  AdminBulkMailStatus _statusForSchedule(AdminBulkMailCampaign? previous) {
    if (_scheduledAt != null) return AdminBulkMailStatus.scheduled;
    if (previous?.status == AdminBulkMailStatus.scheduled) {
      return AdminBulkMailStatus.draft;
    }
    return previous?.status ?? AdminBulkMailStatus.draft;
  }

  AdminMailTemplate? _selectedTemplate() {
    return _templateById(_template);
  }

  void _selectTemplate(String value) {
    final selected = _templateById(value);
    setState(() {
      _template = value;
      if (selected == null) {
        _subjectController.clear();
        _previewController.clear();
      } else {
        _category = selected.category.value;
        _subjectController.text = selected.subject;
        _previewController.text = selected.previewText;
      }
    });
  }

  void _selectCategory(String value) {
    final category = _categoryFromValue(value) ?? _availableCategories.first;
    final template = _firstTemplateFor(category);
    setState(() {
      _category = category.value;
      _template = template?.id.toString() ?? _emptyTemplateOption;
      if (template == null) {
        _subjectController.clear();
        _previewController.clear();
      } else {
        _subjectController.text = template.subject;
        _previewController.text = template.previewText;
      }
    });
  }

  void _selectRecipientList(String value) {
    setState(() {
      _recipientList = value;
      _previewContact = null;
    });
    _loadPreviewContactForSelectedList();
  }

  void _loadPreviewContactForSelectedList() {
    final selectedList = _selectedList();
    final requestId = ++_previewContactRequestId;
    if (selectedList == null || selectedList.contactCount <= 0) {
      _previewContact = null;
      return;
    }

    final listId = selectedList.id;
    if (_previewContactByListId.containsKey(listId)) {
      final cached = _previewContactByListId[listId];
      if (mounted) {
        setState(() => _previewContact = cached);
      } else {
        _previewContact = cached;
      }
      return;
    }

    unawaited(_fetchPreviewContact(listId, requestId));
  }

  Future<void> _fetchPreviewContact(int listId, int requestId) async {
    try {
      final contacts = await widget.repository.fetchContacts(
        widget.session,
        listId,
        limit: 1,
      );
      final contact = contacts.firstOrNull;
      _previewContactByListId[listId] = contact;
      if (!mounted ||
          requestId != _previewContactRequestId ||
          _recipientList != '$listId') {
        return;
      }
      setState(() => _previewContact = contact);
    } catch (_) {
      if (!mounted ||
          requestId != _previewContactRequestId ||
          _recipientList != '$listId') {
        return;
      }
      setState(() => _previewContact = null);
    }
  }

  AdminMailAccount? _selectedAccount() {
    for (final account in widget.accounts) {
      if (account.id.toString() == _account) return account;
    }
    return null;
  }

  AdminContactList? _selectedList() {
    for (final list in _usableLists) {
      if (list.id.toString() == _recipientList) return list;
    }
    return null;
  }

  AdminMailTemplate? _templateById(String value) {
    final id = int.tryParse(value);
    if (id == null) return null;
    for (final template in _usableTemplates) {
      if (template.id == id) return template;
    }
    return null;
  }

  AdminMailTemplate? _firstTemplateFor(AdminMailTemplateCategory category) {
    for (final template in _usableTemplates) {
      if (template.category == category) return template;
    }
    return null;
  }

  AdminMailTemplate? _initialTemplate(AdminBulkMailCampaign? campaign) {
    if (campaign == null) return _usableTemplates.firstOrNull;
    final id = int.tryParse(campaign.templateId);
    if (id != null) {
      for (final template in _usableTemplates) {
        if (template.id == id) return template;
      }
    }
    for (final template in _usableTemplates) {
      if (template.nameKey == campaign.templateName) return template;
    }
    return _usableTemplates.firstOrNull;
  }

  AdminMailAccount? _initialAccount(AdminBulkMailCampaign? campaign) {
    if (campaign == null) return null;
    final id = int.tryParse(campaign.accountId);
    if (id != null) {
      for (final account in widget.accounts) {
        if (account.id == id) return account;
      }
    }
    for (final account in widget.accounts) {
      if (account.accountName == campaign.senderAccount) return account;
    }
    return null;
  }

  AdminContactList? _initialList(AdminBulkMailCampaign? campaign) {
    if (campaign == null) return null;
    final id = int.tryParse(campaign.contactListId);
    if (id != null) {
      for (final list in _usableLists) {
        if (list.id == id) return list;
      }
    }
    for (final list in _usableLists) {
      if (list.name == campaign.recipientList) return list;
    }
    return null;
  }

  AdminMailTemplateCategory? _categoryFromValue(String value) {
    for (final category in AdminMailTemplateCategory.values) {
      if (category.value == value) return category;
    }
    return null;
  }

  AdminMailTemplateCategory? _categoryFromLabel(String? value) {
    final normalized = value?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return null;
    for (final category in AdminMailTemplateCategory.values) {
      if (category.value == normalized) return category;
    }
    if (normalized.contains('bilgi') || normalized.contains('info')) {
      return AdminMailTemplateCategory.info;
    }
    if (normalized.contains('davet') || normalized.contains('invitation')) {
      return AdminMailTemplateCategory.invitation;
    }
    if (normalized.contains('sipari') || normalized.contains('order')) {
      return AdminMailTemplateCategory.order;
    }
    if (normalized.contains('teklif') || normalized.contains('quote')) {
      return AdminMailTemplateCategory.quote;
    }
    if (normalized.contains('kampanya') || normalized.contains('campaign')) {
      return AdminMailTemplateCategory.campaign;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 18, 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.t(
                      widget.campaign == null
                          ? 'mail.campaign.createTitle'
                          : 'mail.campaign.editTitle',
                    ),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.deepOcean,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  mouseCursor: SystemMouseCursors.click,
                  icon: const SymbolIcon(
                    Symbols.close,
                    color: AppColors.deepOcean,
                    size: 21,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.value),
                  border: Border.all(color: AppColors.line),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 820) {
                      final previewHeight = constraints.maxWidth < 480
                          ? 430.0
                          : 520.0;
                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _CreatePanel(
                              categories: _categoryOptions,
                              templates: _templateOptions,
                              accounts: _accountOptions,
                              lists: _listOptions,
                              category: _category,
                              template: _template,
                              account: _account,
                              recipientList: _recipientList,
                              nameController: _nameController,
                              subjectController: _subjectController,
                              previewController: _previewController,
                              onCategoryChanged: _selectCategory,
                              onTemplateChanged: _selectTemplate,
                              onAccountChanged: (value) =>
                                  setState(() => _account = value),
                              onRecipientListChanged: _selectRecipientList,
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: previewHeight,
                              child: _LivePreview(
                                template: _selectedTemplate(),
                                sampleContact: _previewContact,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: 322,
                          child: _CreatePanel(
                            categories: _categoryOptions,
                            templates: _templateOptions,
                            accounts: _accountOptions,
                            lists: _listOptions,
                            category: _category,
                            template: _template,
                            account: _account,
                            recipientList: _recipientList,
                            nameController: _nameController,
                            subjectController: _subjectController,
                            previewController: _previewController,
                            onCategoryChanged: _selectCategory,
                            onTemplateChanged: _selectTemplate,
                            onAccountChanged: (value) =>
                                setState(() => _account = value),
                            onRecipientListChanged: _selectRecipientList,
                          ),
                        ),
                        Container(width: 1, color: AppColors.line),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: _LivePreview(
                              template: _selectedTemplate(),
                              sampleContact: _previewContact,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 14, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style:
                      TextButton.styleFrom(
                        foregroundColor: AppColors.deepOcean,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                      ).copyWith(
                        mouseCursor: const WidgetStatePropertyAll(
                          SystemMouseCursors.click,
                        ),
                      ),
                  child: Text(context.t('common.cancel')),
                ),
                const SizedBox(width: 12),
                _ScheduleFooterButton(
                  scheduledAt: _scheduledAt,
                  onPressed: _pickSchedule,
                  onClear: _scheduledAt == null ? null : _clearSchedule,
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 38,
                  child: TextButton(
                    onPressed: _canSave ? _save : null,
                    style:
                        TextButton.styleFrom(
                          backgroundColor: _canSave
                              ? AppColors.deepOcean
                              : AppColors.softLine,
                          foregroundColor: _canSave
                              ? Colors.white
                              : AppColors.support,
                          disabledForegroundColor: AppColors.support,
                          padding: const EdgeInsets.symmetric(horizontal: 22),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppRadius.value,
                            ),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                          ),
                        ).copyWith(
                          mouseCursor: WidgetStatePropertyAll(
                            _canSave
                                ? SystemMouseCursors.click
                                : SystemMouseCursors.basic,
                          ),
                        ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SymbolIcon(
                          Symbols.save,
                          color: _canSave ? Colors.white : AppColors.support,
                          size: 17,
                        ),
                        const SizedBox(width: 8),
                        Text(context.t('common.save')),
                      ],
                    ),
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

class _ScheduleFooterButton extends StatelessWidget {
  const _ScheduleFooterButton({
    required this.scheduledAt,
    required this.onPressed,
    required this.onClear,
  });

  final DateTime? scheduledAt;
  final VoidCallback onPressed;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final selected = scheduledAt != null;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 230),
      child: SizedBox(
        height: 38,
        child: Material(
          color: selected
              ? AppColors.warmHorizon.withValues(alpha: 0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.value),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(AppRadius.value),
            mouseCursor: SystemMouseCursors.click,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.value),
                border: Border.all(
                  color: selected
                      ? AppColors.warmHorizon.withValues(alpha: 0.52)
                      : AppColors.line,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SymbolIcon(
                    Symbols.schedule,
                    color: selected
                        ? AppColors.warmHorizon
                        : AppColors.deepOcean,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      selected
                          ? _formatScheduleFooterLabel(context, scheduledAt!)
                          : context.t('mail.campaign.action.schedule'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected
                            ? AppColors.deepOcean
                            : AppColors.inkSoft,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  if (selected && onClear != null) ...[
                    const SizedBox(width: 6),
                    Tooltip(
                      message: context.t('common.clear'),
                      child: InkResponse(
                        onTap: onClear,
                        radius: 15,
                        mouseCursor: SystemMouseCursors.click,
                        child: const Padding(
                          padding: EdgeInsets.all(3),
                          child: SymbolIcon(
                            Symbols.close,
                            color: AppColors.support,
                            size: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _formatScheduleFooterLabel(BuildContext context, DateTime value) {
  final local = value.toLocal();
  final month = context.t('date.month.${local.month}');
  return '${local.day} $month ${formatAdminTime(local)}';
}

class _SelectOption {
  const _SelectOption({required this.value, required this.label});

  final String value;
  final String label;
}

class _CreatePanel extends StatelessWidget {
  const _CreatePanel({
    required this.categories,
    required this.templates,
    required this.accounts,
    required this.lists,
    required this.category,
    required this.template,
    required this.account,
    required this.recipientList,
    required this.nameController,
    required this.subjectController,
    required this.previewController,
    required this.onCategoryChanged,
    required this.onTemplateChanged,
    required this.onAccountChanged,
    required this.onRecipientListChanged,
  });

  final List<_SelectOption> categories;
  final List<_SelectOption> templates;
  final List<_SelectOption> accounts;
  final List<_SelectOption> lists;
  final String category;
  final String template;
  final String account;
  final String recipientList;
  final TextEditingController nameController;
  final TextEditingController subjectController;
  final TextEditingController previewController;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<String> onTemplateChanged;
  final ValueChanged<String> onAccountChanged;
  final ValueChanged<String> onRecipientListChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface.withValues(alpha: 0.7),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CreateSectionTitle(
              icon: Symbols.language,
              label: 'mail.campaign.templateSelection',
              color: AppColors.support,
            ),
            const SizedBox(height: 12),
            _CreateSelectField(
              label: 'mail.campaign.templateCategory',
              value: category,
              options: categories,
              onChanged: onCategoryChanged,
            ),
            const SizedBox(height: 12),
            _CreateSelectField(
              label: 'mail.campaign.template',
              value: template,
              options: templates,
              onChanged: onTemplateChanged,
            ),
            const SizedBox(height: 22),
            const Divider(height: 1, color: AppColors.line),
            const SizedBox(height: 18),
            _CreateSectionTitle(
              icon: Symbols.schedule_send,
              label: 'mail.campaign.sendingInfo',
              color: AppColors.deepOcean,
            ),
            const SizedBox(height: 12),
            _CreateTextField(
              label: 'mail.campaign.name',
              hint: 'mail.campaign.nameHint',
              controller: nameController,
              icon: Symbols.alternate_email,
              requiredField: true,
            ),
            const SizedBox(height: 12),
            _CreateTextField(
              label: 'mail.campaign.email_subject',
              hint: 'mail.campaign.subjectHint',
              controller: subjectController,
              icon: Symbols.short_text,
              requiredField: true,
            ),
            const SizedBox(height: 12),
            _CreateTextField(
              label: 'mail.campaign.preview_text',
              hint: 'mail.campaign.previewHint',
              controller: previewController,
              icon: Symbols.short_text,
              requiredField: true,
            ),
            const SizedBox(height: 22),
            const Divider(height: 1, color: AppColors.line),
            const SizedBox(height: 18),
            _CreateSectionTitle(
              icon: Symbols.group,
              label: 'mail.campaign.accountRecipients',
              color: const Color(0xFF3B82F6),
            ),
            const SizedBox(height: 12),
            _CreateSelectCard(
              icon: Symbols.alternate_email,
              label: 'mail.campaign.senderAccount',
              value: account,
              options: accounts,
              onChanged: onAccountChanged,
            ),
            const SizedBox(height: 10),
            _CreateSelectCard(
              icon: Symbols.group,
              label: 'mail.campaign.contactList',
              value: recipientList,
              options: lists,
              onChanged: onRecipientListChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateSectionTitle extends StatelessWidget {
  const _CreateSectionTitle({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.value),
          ),
          child: Center(child: SymbolIcon(icon, color: color, size: 18)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            context.t(label),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.deepOcean,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _CreateSelectField extends StatelessWidget {
  const _CreateSelectField({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<_SelectOption> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CreateLabel(label),
        const SizedBox(height: 6),
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.value),
            border: Border.all(
              color: AppColors.support.withValues(alpha: 0.42),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: const SymbolIcon(
                Symbols.keyboard_arrow_down,
                color: AppColors.iconMuted,
                size: 18,
              ),
              borderRadius: BorderRadius.circular(AppRadius.value),
              items: options
                  .map(
                    (option) => DropdownMenuItem<String>(
                      value: option.value,
                      child: Text(
                        context.t(option.label),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.deepOcean,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (next) {
                if (next != null) onChanged(next);
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _CreateTextField extends StatelessWidget {
  const _CreateTextField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.icon,
    required this.requiredField,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final IconData icon;
  final bool requiredField;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CreateLabel(label, requiredField: requiredField),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          style: const TextStyle(
            color: AppColors.deepOcean,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
          decoration: InputDecoration(
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 2, right: 8),
              child: SymbolIcon(icon, color: AppColors.support, size: 17),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 28,
              minHeight: 38,
            ),
            hintText: context.t(hint),
            hintStyle: const TextStyle(
              color: AppColors.support,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.actionRed),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.actionRed, width: 1.2),
            ),
          ),
        ),
      ],
    );
  }
}

class _CreateSelectCard extends StatelessWidget {
  const _CreateSelectCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final String value;
  final List<_SelectOption> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.value),
            ),
            child: Center(
              child: SymbolIcon(icon, color: AppColors.deepOcean, size: 18),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                icon: const SymbolIcon(
                  Symbols.keyboard_arrow_down,
                  color: AppColors.iconMuted,
                  size: 18,
                ),
                borderRadius: BorderRadius.circular(AppRadius.value),
                selectedItemBuilder: (context) {
                  return options.map((option) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.t(label),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.support,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          context.t(option.label),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.deepOcean,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    );
                  }).toList();
                },
                items: options
                    .map(
                      (option) => DropdownMenuItem<String>(
                        value: option.value,
                        child: Text(context.t(option.label)),
                      ),
                    )
                    .toList(),
                onChanged: (next) {
                  if (next != null) onChanged(next);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateLabel extends StatelessWidget {
  const _CreateLabel(this.label, {this.requiredField = false});

  final String label;
  final bool requiredField;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: context.t(label),
        children: [
          if (requiredField)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: AppColors.actionRed),
            ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: AppColors.inkSoft,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
    );
  }
}

class _LivePreview extends StatelessWidget {
  const _LivePreview({required this.template, required this.sampleContact});

  final AdminMailTemplate? template;
  final AdminMailContact? sampleContact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.value),
            border: Border.all(color: AppColors.line),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 330;
              final title = Row(
                children: [
                  const SymbolIcon(
                    Symbols.visibility,
                    color: AppColors.deepOcean,
                    size: 17,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.t('mail.campaign.livePreview'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.deepOcean,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _LivePreviewBadge(label: context.t('mail.campaign.live')),
                ],
              );
              final hint = Text(
                context.t('mail.campaign.variableHint'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.support,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [title, const SizedBox(height: 5), hint],
                );
              }

              return Row(
                children: [
                  Expanded(flex: 5, child: title),
                  const SizedBox(width: 10),
                  Expanded(flex: 4, child: hint),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            alignment: Alignment.topCenter,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.value),
              border: Border.all(color: AppColors.line),
            ),
            child: SingleChildScrollView(
              child: template == null
                  ? const _PreviewEmptyState()
                  : _EmailHtmlPreview(
                      template: template!,
                      sampleContact: sampleContact,
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LivePreviewBadge extends StatelessWidget {
  const _LivePreviewBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF198754).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.value),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFF198754),
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _PreviewEmptyState extends StatelessWidget {
  const _PreviewEmptyState();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 320,
      child: Center(
        child: Text(
          context.t('mail.campaign.templatePlaceholder'),
          style: const TextStyle(
            color: AppColors.support,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _EmailHtmlPreview extends StatelessWidget {
  const _EmailHtmlPreview({
    required this.template,
    required this.sampleContact,
  });

  final AdminMailTemplate template;
  final AdminMailContact? sampleContact;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AdminBrandingData>(
      valueListenable: adminBranding,
      builder: (context, branding, _) {
        final siteName = branding.siteName.trim().isNotEmpty
            ? branding.siteName.trim()
            : context.t('brand.name');
        final logoUrl = branding.emailLogoUrl.trim().isNotEmpty
            ? branding.emailLogoUrl.trim()
            : branding.logoUrl.trim();
        if (logoUrl.isNotEmpty) {
          return FutureBuilder<String>(
            future: _mailPreviewLogoDataUri(logoUrl),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }
              return _EmailHtmlPreviewFrame(
                template: template,
                sampleContact: sampleContact,
                siteName: siteName,
                logoUrl: logoUrl,
                logoDataUri: snapshot.data ?? '',
              );
            },
          );
        }

        return _EmailHtmlPreviewFrame(
          template: template,
          sampleContact: sampleContact,
          siteName: siteName,
          logoUrl: '',
          logoDataUri: '',
        );
      },
    );
  }
}

class _EmailHtmlPreviewFrame extends StatelessWidget {
  const _EmailHtmlPreviewFrame({
    required this.template,
    required this.sampleContact,
    required this.siteName,
    required this.logoUrl,
    required this.logoDataUri,
  });

  final AdminMailTemplate template;
  final AdminMailContact? sampleContact;
  final String siteName;
  final String logoUrl;
  final String logoDataUri;

  @override
  Widget build(BuildContext context) {
    final html = _applyPreviewValues(
      template.body,
      siteName: siteName,
      logoUrl: logoUrl,
      contact: sampleContact,
    );
    final mjml = _applyPreviewValues(
      template.contentMjml,
      siteName: siteName,
      logoUrl: logoUrl,
      contact: sampleContact,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.value),
      child: Container(
        width: 640,
        height: 760,
        color: Colors.white,
        child: PostaMjmlPreview(
          key: ValueKey(
            '${template.id}-${template.updatedAt.toIso8601String()}-${sampleContact?.id ?? 0}-$siteName-$logoUrl',
          ),
          html: html,
          mjml: mjml,
          projectData: template.designJson,
          previewSiteName: siteName,
          previewLogoUrl: logoUrl,
          previewLogoDataUri: logoDataUri,
        ),
      ),
    );
  }

  String _applyPreviewValues(
    String value, {
    required String siteName,
    required String logoUrl,
    required AdminMailContact? contact,
  }) {
    var result = value
        .replaceAll('__SITE_NAME__', siteName)
        .replaceAll('{{site_adi}}', siteName)
        .replaceAll('{{kod_gecerlilik}}', adminMailVerificationCodeValidity);
    if (logoUrl.isNotEmpty) {
      result = result
          .replaceAll('__SITE_LOGO_URL__', logoUrl)
          .replaceAll('{{site_logo}}', logoUrl);
    }
    final contactValues = _contactPreviewValues(contact);
    for (final entry in contactValues.entries) {
      result = result.replaceAll(entry.key, entry.value);
    }
    return result;
  }

  Map<String, String> _contactPreviewValues(AdminMailContact? contact) {
    if (contact == null) return const <String, String>{};

    final email = contact.email.trim();
    final name = contact.fullName.trim().isNotEmpty
        ? contact.fullName.trim()
        : email;
    final phone = contact.phone.trim();
    final values = <String, String>{};

    void put(String token, String value) {
      final clean = value.trim();
      if (clean.isNotEmpty) values[token] = clean;
    }

    put('{{uye_adi}}', name);
    put('{{uye_eposta}}', email);
    put('{{uye_telefon}}', phone);
    put('{{abone_adi}}', name);
    put('{{abone_eposta}}', email);
    put('{{abone_telefon}}', phone);
    return values;
  }
}

IconData _iconForStatus(AdminBulkMailStatus status) {
  return switch (status) {
    AdminBulkMailStatus.draft => Symbols.edit_square,
    AdminBulkMailStatus.sending => Symbols.schedule_send,
    AdminBulkMailStatus.completed => Symbols.check,
    AdminBulkMailStatus.scheduled => Symbols.schedule,
    AdminBulkMailStatus.paused => Symbols.pending_actions,
    AdminBulkMailStatus.cancelled => Symbols.close,
  };
}
