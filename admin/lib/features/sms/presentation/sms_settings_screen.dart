import 'dart:async';
import 'dart:math' as math;

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
import '../data/admin_sms_repository.dart';
import 'sms_settings_models.dart';

class SmsSettingsScreen extends StatefulWidget {
  const SmsSettingsScreen({
    super.key,
    required this.session,
    this.repository = const SupabaseAdminSmsRepository(),
  });

  final AdminSession session;
  final AdminSmsRepository repository;

  @override
  State<SmsSettingsScreen> createState() => _SmsSettingsScreenState();
}

class _SmsSettingsScreenState extends State<SmsSettingsScreen> {
  final _searchController = TextEditingController();
  final _selectedIds = <int>{};
  var _accounts = <AdminSmsAccount>[];
  var _searchQuery = '';
  var _page = 1;
  var _pageSize = 25;
  var _sortState = const TableSortState(key: 'date', ascending: false);
  int? _activeAccountId;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadAccounts());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    setState(() => _loading = true);
    try {
      final accounts = await widget.repository.fetchAccounts(widget.session);
      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        _activeAccountId =
            accounts.any((account) => account.id == _activeAccountId)
            ? _activeAccountId
            : accounts.firstOrNull?.id;
        _loading = false;
        _resetListState();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showSmsError(error);
    }
  }

  void _showSmsError(Object error) {
    AdminToast.show(
      context,
      message: error.toString(),
      tone: AdminToastTone.error,
    );
  }

  List<AdminSmsAccount> get _filteredAccounts {
    final query = _searchQuery.trim().toLowerCase();
    final filtered = _accounts.where((account) {
      if (query.isEmpty) return true;
      final searchable = [
        account.accountName,
        account.senderName,
        account.senderEmail,
        account.serviceName,
        account.domain,
        account.trackingDomain,
        context.t(account.mode.labelKey),
        account.dnsReady
            ? context.t('sms.settings.dns.ready')
            : context.t('sms.settings.dns.missing'),
        account.active
            ? context.t('sms.settings.status.active')
            : context.t('sms.settings.status.passive'),
      ].join(' ').toLowerCase();
      return searchable.contains(query);
    }).toList();

    filtered.sort((left, right) {
      final result = switch (_sortState.key) {
        'account' => left.accountName.compareTo(right.accountName),
        'sender' => left.senderName.compareTo(right.senderName),
        'service' => left.serviceName.compareTo(right.serviceName),
        'domain' => left.domain.compareTo(right.domain),
        'limit' => left.dailyLimit.compareTo(right.dailyLimit),
        'dns' => left.dnsReady.toString().compareTo(right.dnsReady.toString()),
        'status' => left.active.toString().compareTo(right.active.toString()),
        'date' || _ => left.createdAt.compareTo(right.createdAt),
      };
      return _sortState.ascending ? result : -result;
    });

    return filtered;
  }

  List<AdminSmsAccount> get _pagedAccounts {
    final filtered = _filteredAccounts;
    if (filtered.isEmpty) return const <AdminSmsAccount>[];
    final start = (_page - 1) * _pageSize;
    if (start >= filtered.length) return filtered.take(_pageSize).toList();
    final end = math.min(start + _pageSize, filtered.length);
    return filtered.sublist(start, end);
  }

  AdminSmsAccount? get _activeAccount {
    final id = _activeAccountId;
    if (id == null) return null;
    for (final account in _accounts) {
      if (account.id == id) return account;
    }
    return null;
  }

  int get _trackingCount {
    return _accounts
        .where((account) => account.trackingDomain.trim().isNotEmpty)
        .length;
  }

  int get _hygieneReadyCount {
    return _accounts
        .where((account) => account.active && account.dnsReady)
        .length;
  }

  void _resetListState() {
    _page = 1;
    _selectedIds.clear();
  }

  void _changePageSize(int? value) {
    if (value == null || value == _pageSize) return;
    setState(() {
      _pageSize = value;
      _resetListState();
    });
  }

  void _changeSearch(String value) {
    setState(() {
      _searchQuery = value;
      _resetListState();
    });
  }

  void _changeSort(String key) {
    setState(() {
      _sortState = _sortState.toggled(key);
      _resetListState();
    });
  }

  void _changePage(int value) {
    if (value == _page) return;
    setState(() {
      _page = value;
      _selectedIds.clear();
    });
  }

  void _toggleAccount(int id) {
    setState(() {
      _activeAccountId = id;
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _toggleAllAccounts() {
    final pageIds = _pagedAccounts.map((account) => account.id).toSet();
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

  void _replaceAccount(AdminSmsAccount account) {
    setState(() {
      _accounts = [
        for (final current in _accounts)
          if (current.id == account.id) account else current,
      ];
      _activeAccountId = account.id;
    });
  }

  Future<void> _toggleActive(AdminSmsAccount account) async {
    try {
      final updated = await widget.repository.updateAccount(
        widget.session,
        account,
        {'is_active': !account.active},
      );
      if (mounted) _replaceAccount(updated);
    } catch (error) {
      if (mounted) _showSmsError(error);
    }
  }

  Future<void> _markDnsReady(AdminSmsAccount account) async {
    try {
      final updated = await widget.repository.checkAccount(
        widget.session,
        account.id,
      );
      if (mounted) _replaceAccount(updated);
    } catch (error) {
      if (mounted) _showSmsError(error);
    }
  }

  Future<void> _deleteAccount(AdminSmsAccount account) async {
    final confirmed = await showAppConfirmationDialog(
      context,
      title: context.t('sms.settings.deleteTitle'),
      message: context.t('sms.settings.deleteMessage'),
      confirmLabel: context.t('common.delete'),
      danger: true,
    );
    if (!confirmed || !mounted) return;
    try {
      await widget.repository.deleteAccounts(widget.session, [account.id]);
      if (!mounted) return;
      setState(() {
        _accounts = _accounts
            .where((current) => current.id != account.id)
            .toList(growable: false);
        _selectedIds.remove(account.id);
        if (_activeAccountId == account.id) {
          _activeAccountId = _accounts.firstOrNull?.id;
        }
      });
    } catch (error) {
      if (mounted) _showSmsError(error);
    }
  }

  Future<void> _deleteSelectedAccounts() async {
    if (_selectedIds.isEmpty) return;
    final confirmed = await showAppConfirmationDialog(
      context,
      title: context.t('sms.settings.deleteSelectedTitle'),
      message: context.t(
        'sms.settings.deleteSelectedMessage',
        values: {'count': _selectedIds.length},
      ),
      confirmLabel: context.t('common.delete'),
      danger: true,
    );
    if (!confirmed || !mounted) return;
    try {
      final ids = _selectedIds.toList(growable: false);
      await widget.repository.deleteAccounts(widget.session, ids);
      if (!mounted) return;
      setState(() {
        _accounts = _accounts
            .where((account) => !ids.contains(account.id))
            .toList(growable: false);
        _selectedIds.clear();
        if (_activeAccountId != null &&
            !_accounts.any((account) => account.id == _activeAccountId)) {
          _activeAccountId = _accounts.firstOrNull?.id;
        }
      });
    } catch (error) {
      if (mounted) _showSmsError(error);
    }
  }

  Future<void> _openProviderPicker() async {
    final preset = await showDialog<AdminSmsProviderPreset>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        final size = MediaQuery.sizeOf(context);
        final width = math.max(340.0, math.min(size.width - 48, 860.0));
        final height = math.max(540.0, math.min(size.height - 48, 820.0));
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          child: SizedBox(
            width: width,
            height: height,
            child: const _ProviderPickerDialog(),
          ),
        );
      },
    );

    if (preset == null || !mounted) return;
    await _openConnectionDialog(preset: preset);
  }

  Future<void> _openSelectedSettings() async {
    final account = _activeAccount;
    if (account == null) {
      await _openProviderPicker();
      return;
    }
    await _openConnectionDialog(account: account);
  }

  Future<void> _openConnectionDialog({
    AdminSmsAccount? account,
    AdminSmsProviderPreset? preset,
  }) async {
    final result = await showDialog<AdminSmsAccount>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        final size = MediaQuery.sizeOf(context);
        final width = math.max(340.0, math.min(size.width - 48, 860.0));
        final height = math.max(560.0, math.min(size.height - 48, 840.0));
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          child: SizedBox(
            width: width,
            height: height,
            child: _ConnectionSettingsDialog(account: account, preset: preset),
          ),
        );
      },
    );

    if (result == null || !mounted) return;
    late final AdminSmsAccount saved;
    try {
      saved = await widget.repository.saveAccount(
        widget.session,
        id: account?.id,
        account: result,
      );
    } catch (error) {
      if (mounted) _showSmsError(error);
      return;
    }
    if (!mounted) return;
    setState(() {
      final index = _accounts.indexWhere((current) => current.id == saved.id);
      if (index == -1) {
        _accounts = [saved, ..._accounts];
      } else {
        _accounts = [
          for (final current in _accounts)
            if (current.id == saved.id) saved else current,
        ];
      }
      _activeAccountId = saved.id;
      _resetListState();
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 640 ? 16.0 : 28.0;
        final compact = constraints.maxWidth < 980;
        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SmsSettingsTitle(
              selectedCount: _selectedIds.length,
              onDeleteSelected: _deleteSelectedAccounts,
            ),
            const SizedBox(height: 24),
            _SmsSettingsMetricGrid(
              totalAccounts: _accounts.length,
              compatibleDomains: _accounts
                  .where((account) => account.dnsReady)
                  .length,
              trackingCount: _trackingCount,
              hygieneReady: _hygieneReadyCount,
              suppressionCount: 3,
            ),
            const SizedBox(height: 14),
            Expanded(
              child: _SmsSettingsTableCard(
                accounts: _pagedAccounts,
                page: _page,
                pageSize: _pageSize,
                totalCount: _filteredAccounts.length,
                searchController: _searchController,
                searchQuery: _searchQuery,
                selectedIds: _selectedIds,
                activeAccountId: _activeAccountId,
                sortState: _sortState,
                onPageSizeChanged: _changePageSize,
                onSearchChanged: _changeSearch,
                onPageChanged: _changePage,
                onToggleAccount: _toggleAccount,
                onToggleAllAccounts: _toggleAllAccounts,
                onSort: _changeSort,
                onRefresh: () => unawaited(_loadAccounts()),
                onSettings: _openSelectedSettings,
                onCreate: _openProviderPicker,
                onSelectRow: (account) =>
                    setState(() => _activeAccountId = account.id),
                onEdit: (account) => _openConnectionDialog(account: account),
                onDnsCheck: _markDnsReady,
                onToggleActive: _toggleActive,
                onDelete: _deleteAccount,
              ),
            ),
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
            child: SizedBox(height: 1000, child: content),
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
}

class _SmsSettingsTitle extends StatelessWidget {
  const _SmsSettingsTitle({
    required this.selectedCount,
    required this.onDeleteSelected,
  });

  final int selectedCount;
  final VoidCallback onDeleteSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                context.t('sms.settings.centerTitle'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.deepOcean,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ),
            if (selectedCount > 0)
              _DangerTextButton(
                label: context.t(
                  'sms.settings.selectedDelete',
                  values: {'count': selectedCount},
                ),
                onTap: onDeleteSelected,
              ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          context.t('sms.settings.centerDescription'),
          style: const TextStyle(
            color: AppColors.inkSoft,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _SmsSettingsMetricGrid extends StatelessWidget {
  const _SmsSettingsMetricGrid({
    required this.totalAccounts,
    required this.compatibleDomains,
    required this.trackingCount,
    required this.hygieneReady,
    required this.suppressionCount,
  });

  final int totalAccounts;
  final int compatibleDomains;
  final int trackingCount;
  final int hygieneReady;
  final int suppressionCount;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _MetricData(
        label: 'sms.settings.metric.totalAccounts',
        value: '$totalAccounts',
        icon: Symbols.dns_outlined,
        color: AppColors.deepOcean,
      ),
      _MetricData(
        label: 'sms.settings.metric.compatibleDomains',
        value: '$compatibleDomains',
        icon: Symbols.verified,
        color: const Color(0xFF198754),
      ),
      _MetricData(
        label: 'sms.settings.metric.tracking',
        value: '$trackingCount',
        icon: Symbols.ads_click_outlined,
        color: const Color(0xFF2F80ED),
      ),
      _MetricData(
        label: 'sms.settings.metric.hygiene',
        value: '$hygieneReady',
        icon: Symbols.fact_check_outlined,
        color: const Color(0xFF16A085),
      ),
      _MetricData(
        label: 'sms.settings.metric.suppression',
        value: '$suppressionCount',
        icon: Symbols.block_outlined,
        color: AppColors.actionRed,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 1180) {
          final itemWidth = constraints.maxWidth < 620
              ? constraints.maxWidth
              : (constraints.maxWidth - 12) / 2;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final metric in metrics)
                SizedBox(
                  width: itemWidth,
                  child: _MetricBox(data: metric),
                ),
            ],
          );
        }
        return Row(
          children: [
            for (var index = 0; index < metrics.length; index++) ...[
              Expanded(child: _MetricBox(data: metrics[index])),
              if (index != metrics.length - 1) const SizedBox(width: 12),
            ],
          ],
        );
      },
    );
  }
}

class _SmsSettingsTableCard extends StatelessWidget {
  const _SmsSettingsTableCard({
    required this.accounts,
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.searchController,
    required this.searchQuery,
    required this.selectedIds,
    required this.activeAccountId,
    required this.sortState,
    required this.onPageSizeChanged,
    required this.onSearchChanged,
    required this.onPageChanged,
    required this.onToggleAccount,
    required this.onToggleAllAccounts,
    required this.onSort,
    required this.onRefresh,
    required this.onSettings,
    required this.onCreate,
    required this.onSelectRow,
    required this.onEdit,
    required this.onDnsCheck,
    required this.onToggleActive,
    required this.onDelete,
  });

  static const _minTableWidth = 1040.0;

  final List<AdminSmsAccount> accounts;
  final int page;
  final int pageSize;
  final int totalCount;
  final TextEditingController searchController;
  final String searchQuery;
  final Set<int> selectedIds;
  final int? activeAccountId;
  final TableSortState sortState;
  final ValueChanged<int?> onPageSizeChanged;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onToggleAccount;
  final VoidCallback onToggleAllAccounts;
  final ValueChanged<String> onSort;
  final VoidCallback onRefresh;
  final VoidCallback onSettings;
  final VoidCallback onCreate;
  final ValueChanged<AdminSmsAccount> onSelectRow;
  final ValueChanged<AdminSmsAccount> onEdit;
  final ValueChanged<AdminSmsAccount> onDnsCheck;
  final ValueChanged<AdminSmsAccount> onToggleActive;
  final ValueChanged<AdminSmsAccount> onDelete;

  @override
  Widget build(BuildContext context) {
    final pageIds = accounts.map((account) => account.id).toSet();
    final allSelected = pageIds.isNotEmpty && selectedIds.containsAll(pageIds);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SmsSettingsToolbar(
          pageSize: pageSize,
          searchController: searchController,
          searchQuery: searchQuery,
          onPageSizeChanged: onPageSizeChanged,
          onSearchChanged: onSearchChanged,
          onRefresh: onRefresh,
          onSettings: onSettings,
          onCreate: onCreate,
        ),
        const SizedBox(height: 18),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.line),
              borderRadius: BorderRadius.circular(AppRadius.value),
            ),
            clipBehavior: Clip.antiAlias,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = math.max(constraints.maxWidth, _minTableWidth);
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: width,
                    height: constraints.hasBoundedHeight
                        ? constraints.maxHeight
                        : null,
                    child: Column(
                      children: [
                        _SmsSettingsTableHeader(
                          selected: allSelected,
                          sortState: sortState,
                          onToggle: onToggleAllAccounts,
                          onSort: onSort,
                        ),
                        Expanded(
                          child: accounts.isEmpty
                              ? const _SmsSettingsEmptyState()
                              : ListView.builder(
                                  itemCount: accounts.length,
                                  itemBuilder: (context, index) {
                                    final account = accounts[index];
                                    return _SmsSettingsTableRow(
                                      account: account,
                                      selected: selectedIds.contains(
                                        account.id,
                                      ),
                                      active: account.id == activeAccountId,
                                      onToggle: () =>
                                          onToggleAccount(account.id),
                                      onSelect: () => onSelectRow(account),
                                      onEdit: () => onEdit(account),
                                      onDnsCheck: () => onDnsCheck(account),
                                      onToggleActive: () =>
                                          onToggleActive(account),
                                      onDelete: () => onDelete(account),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        _SmsSettingsFooter(
          page: page,
          pageSize: pageSize,
          totalCount: totalCount,
          onPageChanged: onPageChanged,
        ),
      ],
    );
  }
}

class _SmsSettingsToolbar extends StatelessWidget {
  const _SmsSettingsToolbar({
    required this.pageSize,
    required this.searchController,
    required this.searchQuery,
    required this.onPageSizeChanged,
    required this.onSearchChanged,
    required this.onRefresh,
    required this.onSettings,
    required this.onCreate,
  });

  final int pageSize;
  final TextEditingController searchController;
  final String searchQuery;
  final ValueChanged<int?> onPageSizeChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onRefresh;
  final VoidCallback onSettings;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 840;
        final actions = Wrap(
          spacing: 12,
          runSpacing: 10,
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: compact ? constraints.maxWidth : 280,
              child: _SearchField(
                controller: searchController,
                query: searchQuery,
                hint: context.t('sms.settings.searchPlaceholder'),
                onChanged: onSearchChanged,
              ),
            ),
            _SecondaryActionButton(
              icon: Symbols.refresh,
              label: context.t('sms.settings.refresh'),
              onPressed: onRefresh,
            ),
            _SecondaryActionButton(
              icon: Symbols.settings_outlined,
              label: context.t('sms.settings.settingsButton'),
              onPressed: onSettings,
            ),
            _PrimaryActionButton(
              icon: Symbols.add,
              label: context.t('sms.settings.addAccount'),
              onPressed: onCreate,
            ),
          ],
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PageSizeSelect(value: pageSize, onChanged: onPageSizeChanged),
              const SizedBox(height: 12),
              actions,
            ],
          );
        }

        return Row(
          children: [
            _PageSizeSelect(value: pageSize, onChanged: onPageSizeChanged),
            const Spacer(),
            actions,
          ],
        );
      },
    );
  }
}

class _SmsSettingsTableHeader extends StatelessWidget {
  const _SmsSettingsTableHeader({
    required this.selected,
    required this.sortState,
    required this.onToggle,
    required this.onSort,
  });

  static const _selectWidth = 42.0;
  static const _limitWidth = 132.0;
  static const _dnsWidth = 148.0;
  static const _statusWidth = 126.0;
  static const _actionsWidth = 76.0;
  static const _accountFlex = 5;
  static const _senderFlex = 4;
  static const _domainFlex = 3;
  static const _dateFlex = 3;

  final bool selected;
  final TableSortState sortState;
  final VoidCallback onToggle;
  final ValueChanged<String> onSort;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.softLine.withValues(alpha: 0.86)),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _selectWidth,
            child: Center(
              child: _ListCheckbox(selected: selected, onTap: onToggle),
            ),
          ),
          Expanded(
            flex: _accountFlex,
            child: _SmsSettingsSortableHeader(
              label: 'sms.settings.column.account',
              sortKey: 'account',
              sortState: sortState,
              onSort: onSort,
            ),
          ),
          Expanded(
            flex: _senderFlex,
            child: _SmsSettingsSortableHeader(
              label: 'sms.settings.column.sender',
              sortKey: 'sender',
              sortState: sortState,
              onSort: onSort,
            ),
          ),
          Expanded(
            flex: _domainFlex,
            child: _SmsSettingsSortableHeader(
              label: 'sms.settings.column.domain',
              sortKey: 'domain',
              sortState: sortState,
              onSort: onSort,
            ),
          ),
          SizedBox(
            width: _limitWidth,
            child: _SmsSettingsSortableHeader(
              label: 'sms.settings.column.limit',
              sortKey: 'limit',
              sortState: sortState,
              onSort: onSort,
              centered: true,
            ),
          ),
          SizedBox(
            width: _dnsWidth,
            child: _SmsSettingsSortableHeader(
              label: 'sms.settings.column.dns',
              sortKey: 'dns',
              sortState: sortState,
              onSort: onSort,
            ),
          ),
          SizedBox(
            width: _statusWidth,
            child: _SmsSettingsSortableHeader(
              label: 'sms.settings.column.status',
              sortKey: 'status',
              sortState: sortState,
              onSort: onSort,
            ),
          ),
          Expanded(
            flex: _dateFlex,
            child: _SmsSettingsSortableHeader(
              label: 'sms.settings.column.date',
              sortKey: 'date',
              sortState: sortState,
              onSort: onSort,
            ),
          ),
          SizedBox(
            width: _actionsWidth,
            child: Center(
              child: Text(
                context.t('sms.settings.column.actions'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.inkSoft,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmsSettingsSortableHeader extends StatelessWidget {
  const _SmsSettingsSortableHeader({
    required this.label,
    required this.sortKey,
    required this.sortState,
    required this.onSort,
    this.centered = false,
  });

  final String label;
  final String sortKey;
  final TableSortState sortState;
  final ValueChanged<String> onSort;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    if (centered) {
      final selected = sortState.key == sortKey;
      final icon = SymbolIcon(
        Symbols.keyboard_arrow_down,
        color: selected ? AppColors.deepOcean : AppColors.support,
        size: 14,
      );

      return DefaultTextStyle.merge(
        style: const TextStyle(letterSpacing: 0),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onSort(sortKey),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.t(label),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? AppColors.deepOcean : AppColors.inkSoft,
                      fontWeight: FontWeight.w600,
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
        ),
      );
    }

    return DefaultTextStyle.merge(
      style: const TextStyle(letterSpacing: 0),
      child: SortableTableHeader(
        label: label,
        sortKey: sortKey,
        sortState: sortState,
        onSort: onSort,
      ),
    );
  }
}

class _SmsSettingsTableRow extends StatelessWidget {
  const _SmsSettingsTableRow({
    required this.account,
    required this.selected,
    required this.active,
    required this.onToggle,
    required this.onSelect,
    required this.onEdit,
    required this.onDnsCheck,
    required this.onToggleActive,
    required this.onDelete,
  });

  final AdminSmsAccount account;
  final bool selected;
  final bool active;
  final VoidCallback onToggle;
  final VoidCallback onSelect;
  final VoidCallback onEdit;
  final VoidCallback onDnsCheck;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final provider = adminSmsProviderById(account.providerId);
    final serviceCaption = _smsSettingsServiceCaption(context, account);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onSelect,
        child: Container(
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: active
                ? AppColors.deepOcean.withValues(alpha: 0.03)
                : Colors.white,
            border: Border(
              bottom: BorderSide(
                color: AppColors.softLine.withValues(alpha: 0.86),
              ),
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: _SmsSettingsTableHeader._selectWidth,
                child: Center(
                  child: _ListCheckbox(selected: selected, onTap: onToggle),
                ),
              ),
              Expanded(
                flex: _SmsSettingsTableHeader._accountFlex,
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: provider.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.value),
                      ),
                      child: Icon(
                        provider.icon,
                        color: provider.color,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            account.accountName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.deepOcean,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            account.smtpHost.isNotEmpty
                                ? account.smtpHost
                                : account.apiBaseUrl,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.iconMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: _SmsSettingsTableHeader._senderFlex,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.senderName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.deepOcean,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      account.senderEmail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.iconMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      serviceCaption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.iconMuted,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: _SmsSettingsTableHeader._domainFlex,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.domain,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.deepOcean,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      account.trackingDomain.isEmpty
                          ? context.t('sms.settings.noTrackingDomain')
                          : account.trackingDomain,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.iconMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: _SmsSettingsTableHeader._limitWidth,
                child: Center(
                  child: Text(
                    context.t(
                      'sms.settings.limitDaily',
                      values: {
                        'used': account.sentToday,
                        'limit': account.dailyLimit,
                      },
                    ),
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
                ),
              ),
              SizedBox(
                width: _SmsSettingsTableHeader._dnsWidth,
                child: Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: [
                    _DnsChip(label: 'URL', ready: account.spfReady),
                    _DnsChip(label: 'Token', ready: account.dkimReady),
                    _DnsChip(label: 'Event', ready: account.dmarcReady),
                  ],
                ),
              ),
              SizedBox(
                width: _SmsSettingsTableHeader._statusWidth,
                child: _StatusBadge(
                  label: account.active
                      ? context.t('sms.settings.status.active')
                      : context.t('sms.settings.status.passive'),
                  color: account.active
                      ? const Color(0xFF198754)
                      : AppColors.support,
                ),
              ),
              Expanded(
                flex: _SmsSettingsTableHeader._dateFlex,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatAdminFullDate(context, account.createdAt),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.deepOcean,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0,
                      ),
                    ),
                    Text(
                      formatAdminTime(account.createdAt),
                      style: const TextStyle(
                        color: AppColors.iconMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: _SmsSettingsTableHeader._actionsWidth,
                child: Align(
                  alignment: Alignment.center,
                  child: _SmsSettingsRowMenu(
                    account: account,
                    onEdit: onEdit,
                    onDnsCheck: onDnsCheck,
                    onToggleActive: onToggleActive,
                    onDelete: onDelete,
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

String _smsSettingsServiceCaption(
  BuildContext context,
  AdminSmsAccount account,
) {
  final serviceName = _smsSettingsServiceNameLabel(account.serviceName);
  final modeLabel = _smsSettingsModeLabel(context.t(account.mode.labelKey));
  return '$serviceName - $modeLabel';
}

String _smsSettingsServiceNameLabel(String value) {
  final trimmed = value.trim();
  if (trimmed == 'NetGSM') return 'Net GSM';
  if (trimmed.endsWith(' API')) {
    return trimmed.substring(0, trimmed.length - 4).trim();
  }
  return trimmed;
}

String _smsSettingsModeLabel(String value) {
  final trimmed = value.trim();
  if (trimmed.toUpperCase() == 'API') return 'Api';
  return trimmed;
}

class _ProviderPickerDialog extends StatelessWidget {
  const _ProviderPickerDialog();

  @override
  Widget build(BuildContext context) {
    final standard = adminSmsProviderPresets
        .where((preset) => !preset.easySetup)
        .toList(growable: false);
    final easy = adminSmsProviderPresets
        .where((preset) => preset.easySetup)
        .toList(growable: false);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.value),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 18, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.t('sms.settings.providerDialog.title'),
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: AppColors.deepOcean,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.t('sms.settings.providerDialog.subtitle'),
                        style: const TextStyle(
                          color: AppColors.inkSoft,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
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
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppColors.line),
                  borderRadius: BorderRadius.circular(AppRadius.value),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        context.t('sms.settings.providerDialog.categories'),
                        style: const TextStyle(
                          color: AppColors.deepOcean,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _ProviderGrid(presets: standard),
                      const SizedBox(height: 22),
                      Text(
                        context.t('sms.settings.providerDialog.easySetup'),
                        style: const TextStyle(
                          color: AppColors.deepOcean,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _ProviderGrid(
                        presets: easy,
                        highlightedId: 'iletimerkezi',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderGrid extends StatelessWidget {
  const _ProviderGrid({required this.presets, this.highlightedId});

  final List<AdminSmsProviderPreset> presets;
  final String? highlightedId;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 560 ? 1 : 2;
        final spacing = 10.0;
        final itemWidth =
            (constraints.maxWidth - (columns - 1) * spacing) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final preset in presets)
              SizedBox(
                width: itemWidth,
                child: _ProviderCard(
                  preset: preset,
                  highlighted: preset.id == highlightedId,
                  onTap: () => Navigator.of(context).pop(preset),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ProviderCard extends StatelessWidget {
  const _ProviderCard({
    required this.preset,
    required this.highlighted,
    required this.onTap,
  });

  final AdminSmsProviderPreset preset;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 86),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: highlighted
                ? AppColors.warmHorizon.withValues(alpha: 0.08)
                : Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.value),
            border: Border.all(
              color: highlighted ? AppColors.warmHorizon : AppColors.line,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: preset.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.value),
                ),
                child: Icon(preset.icon, color: preset.color, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            preset.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.deepOcean,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                        if (preset.badgeKey != null) ...[
                          const SizedBox(width: 8),
                          _SoftBadge(
                            label: context.t(preset.badgeKey!),
                            color: preset.color,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.t('sms.settings.providerDialog.description'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.inkSoft,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        height: 1.28,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConnectionSettingsDialog extends StatefulWidget {
  const _ConnectionSettingsDialog({this.account, this.preset});

  final AdminSmsAccount? account;
  final AdminSmsProviderPreset? preset;

  @override
  State<_ConnectionSettingsDialog> createState() =>
      _ConnectionSettingsDialogState();
}

class _ConnectionSettingsDialogState extends State<_ConnectionSettingsDialog> {
  late final AdminSmsProviderPreset _preset;
  late final TextEditingController _accountName;
  late final TextEditingController _senderName;
  late final TextEditingController _senderEmail;
  late final TextEditingController _domain;
  late final TextEditingController _smtpHost;
  late final TextEditingController _smtpPort;
  late final TextEditingController _smtpUser;
  late final TextEditingController _smtpPassword;
  late final TextEditingController _apiBaseUrl;
  late final TextEditingController _apiKey;
  late final TextEditingController _apiSecret;
  late final TextEditingController _trackingDomain;
  late final TextEditingController _dailyLimit;
  late final TextEditingController _monthlyLimit;
  late final TextEditingController _hourlyLimit;
  late AdminSmsSecurity _security;
  late bool _active;
  var _accountError = false;
  var _senderEmailError = false;
  var _domainError = false;

  @override
  void initState() {
    super.initState();
    final account = widget.account;
    _preset =
        widget.preset ??
        (account == null
            ? adminSmsProviderById('iletimerkezi')
            : adminSmsProviderById(account.providerId));
    _accountName = TextEditingController(text: account?.accountName ?? '');
    _senderName = TextEditingController(text: account?.senderName ?? '');
    _senderEmail = TextEditingController(text: account?.senderEmail ?? '');
    _domain = TextEditingController(text: account?.domain ?? '');
    _smtpHost = TextEditingController(
      text: account?.smtpHost ?? _preset.smtpHost,
    );
    _smtpPort = TextEditingController(
      text: '${account?.smtpPort ?? _preset.smtpPort}',
    );
    _smtpUser = TextEditingController(text: account?.smtpUser ?? '');
    _smtpPassword = TextEditingController();
    _apiBaseUrl = TextEditingController(
      text: account?.apiBaseUrl ?? _preset.apiBaseUrl,
    );
    _apiKey = TextEditingController();
    _apiSecret = TextEditingController();
    _trackingDomain = TextEditingController(
      text: account?.trackingDomain ?? '',
    );
    _dailyLimit = TextEditingController(text: '${account?.dailyLimit ?? 5000}');
    _monthlyLimit = TextEditingController(
      text: '${account?.monthlyLimit ?? 150000}',
    );
    _hourlyLimit = TextEditingController(
      text: '${account?.hourlyLimit ?? 700}',
    );
    _security = account?.security ?? _preset.security;
    _active = account?.active ?? true;
  }

  @override
  void dispose() {
    _accountName.dispose();
    _senderName.dispose();
    _senderEmail.dispose();
    _domain.dispose();
    _smtpHost.dispose();
    _smtpPort.dispose();
    _smtpUser.dispose();
    _smtpPassword.dispose();
    _apiBaseUrl.dispose();
    _apiKey.dispose();
    _apiSecret.dispose();
    _trackingDomain.dispose();
    _dailyLimit.dispose();
    _monthlyLimit.dispose();
    _hourlyLimit.dispose();
    super.dispose();
  }

  void _submit() {
    final hasAccountError = _accountName.text.trim().isEmpty;
    final hasEmailError = _senderEmail.text.trim().isEmpty;
    final hasDomainError = _domain.text.trim().isEmpty;
    if (hasAccountError || hasEmailError || hasDomainError) {
      setState(() {
        _accountError = hasAccountError;
        _senderEmailError = hasEmailError;
        _domainError = hasDomainError;
      });
      return;
    }

    final existing = widget.account;
    final account = AdminSmsAccount(
      id: existing?.id ?? DateTime.now().millisecondsSinceEpoch,
      accountName: _accountName.text.trim(),
      senderName: _senderName.text.trim(),
      senderEmail: _senderEmail.text.trim(),
      domain: _domain.text.trim(),
      providerId: _preset.id,
      serviceName: _preset.name,
      mode: _preset.mode,
      smtpHost: _smtpHost.text.trim(),
      smtpPort: int.tryParse(_smtpPort.text.trim()) ?? _preset.smtpPort,
      security: _security,
      smtpUser: _smtpUser.text.trim(),
      apiBaseUrl: _apiBaseUrl.text.trim(),
      apiKey: _apiKey.text.trim(),
      apiSecret: _apiSecret.text.trim(),
      dailyLimit: int.tryParse(_dailyLimit.text.trim()) ?? 5000,
      monthlyLimit: int.tryParse(_monthlyLimit.text.trim()) ?? 150000,
      hourlyLimit: int.tryParse(_hourlyLimit.text.trim()) ?? 700,
      sentToday: existing?.sentToday ?? 0,
      spfReady: existing?.spfReady ?? false,
      dkimReady: existing?.dkimReady ?? false,
      dmarcReady: existing?.dmarcReady ?? false,
      trackingDomain: _trackingDomain.text.trim(),
      active: _active,
      createdAt: existing?.createdAt ?? DateTime.now(),
    );
    Navigator.of(context).pop(account);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.value),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 18, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.t('sms.settings.connection.title'),
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: AppColors.deepOcean,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.t(
                          'sms.settings.connection.subtitle',
                          values: {'provider': _preset.name},
                        ),
                        style: const TextStyle(
                          color: AppColors.inkSoft,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
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
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppColors.line),
                  borderRadius: BorderRadius.circular(AppRadius.value),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 700;
                    return ScrollConfiguration(
                      behavior: ScrollConfiguration.of(
                        context,
                      ).copyWith(scrollbars: false),
                      child: SingleChildScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _ConnectionSectionTitle(
                              icon: Symbols.badge_outlined,
                              title: context.t(
                                'sms.settings.connection.identity',
                              ),
                            ),
                            const SizedBox(height: 12),
                            _ResponsivePair(
                              compact: compact,
                              first: _UnderlinedInput(
                                label: context.t(
                                  'sms.settings.field.accountName',
                                ),
                                hint: context.t(
                                  'sms.settings.hint.accountName',
                                ),
                                controller: _accountName,
                                icon: Symbols.dns_outlined,
                                requiredInput: true,
                                hasError: _accountError,
                                errorText: context.t(
                                  'sms.settings.validation.accountName',
                                ),
                                onChanged: (_) {
                                  if (_accountError) {
                                    setState(() => _accountError = false);
                                  }
                                },
                              ),
                              second: _UnderlinedInput(
                                label: context.t(
                                  'sms.settings.field.senderName',
                                ),
                                hint: context.t('sms.settings.hint.senderName'),
                                controller: _senderName,
                                icon: Symbols.person_outline,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _ResponsivePair(
                              compact: compact,
                              first: _UnderlinedInput(
                                label: context.t(
                                  'sms.settings.field.senderEmail',
                                ),
                                hint: context.t(
                                  'sms.settings.hint.senderEmail',
                                ),
                                controller: _senderEmail,
                                icon: Symbols.alternate_email,
                                requiredInput: true,
                                hasError: _senderEmailError,
                                errorText: context.t(
                                  'sms.settings.validation.senderEmail',
                                ),
                                onChanged: (_) {
                                  if (_senderEmailError) {
                                    setState(() => _senderEmailError = false);
                                  }
                                },
                              ),
                              second: _UnderlinedInput(
                                label: context.t('sms.settings.field.domain'),
                                hint: context.t('sms.settings.hint.domain'),
                                controller: _domain,
                                icon: Symbols.language_outlined,
                                requiredInput: true,
                                hasError: _domainError,
                                errorText: context.t(
                                  'sms.settings.validation.domain',
                                ),
                                onChanged: (_) {
                                  if (_domainError) {
                                    setState(() => _domainError = false);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(height: 24),
                            _ConnectionSectionTitle(
                              icon: _preset.mode == AdminSmsProviderMode.api
                                  ? Symbols.api_outlined
                                  : Symbols.outgoing_mail,
                              title: context.t(
                                _preset.mode == AdminSmsProviderMode.api
                                    ? 'sms.settings.connection.api'
                                    : 'sms.settings.connection.smtp',
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (_preset.mode == AdminSmsProviderMode.api)
                              _ResponsivePair(
                                compact: compact,
                                first: _UnderlinedInput(
                                  label: context.t(
                                    'sms.settings.field.apiBaseUrl',
                                  ),
                                  hint: context.t(
                                    'sms.settings.hint.apiBaseUrl',
                                  ),
                                  controller: _apiBaseUrl,
                                  icon: Symbols.link_outlined,
                                ),
                                second: _UnderlinedInput(
                                  label: context.t('sms.settings.field.apiKey'),
                                  hint: context.t('sms.settings.hint.apiKey'),
                                  controller: _apiKey,
                                  icon: Symbols.key_outlined,
                                ),
                              )
                            else ...[
                              _ResponsivePair(
                                compact: compact,
                                first: _UnderlinedInput(
                                  label: context.t(
                                    'sms.settings.field.smtpHost',
                                  ),
                                  hint: context.t('sms.settings.hint.smtpHost'),
                                  controller: _smtpHost,
                                  icon: Symbols.dns_outlined,
                                ),
                                second: _ResponsivePair(
                                  compact: false,
                                  firstFlex: 2,
                                  secondFlex: 3,
                                  first: _UnderlinedInput(
                                    label: context.t(
                                      'sms.settings.field.smtpPort',
                                    ),
                                    hint: '587',
                                    controller: _smtpPort,
                                    icon: Symbols.numbers_outlined,
                                    keyboardType: TextInputType.number,
                                  ),
                                  second: _SecuritySelect(
                                    value: _security,
                                    onChanged: (value) {
                                      if (value == null) return;
                                      setState(() => _security = value);
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              _ResponsivePair(
                                compact: compact,
                                first: _UnderlinedInput(
                                  label: context.t(
                                    'sms.settings.field.smtpUser',
                                  ),
                                  hint: context.t('sms.settings.hint.smtpUser'),
                                  controller: _smtpUser,
                                  icon: Symbols.person_outline,
                                ),
                                second: _UnderlinedInput(
                                  label: context.t(
                                    'sms.settings.field.smtpPassword',
                                  ),
                                  hint: context.t(
                                    'sms.settings.hint.smtpPassword',
                                  ),
                                  controller: _smtpPassword,
                                  icon: Symbols.lock_outline,
                                  obscure: true,
                                ),
                              ),
                            ],
                            if (_preset.mode == AdminSmsProviderMode.api) ...[
                              const SizedBox(height: 16),
                              _UnderlinedInput(
                                label: context.t(
                                  'sms.settings.field.apiSecret',
                                ),
                                hint: context.t('sms.settings.hint.apiSecret'),
                                controller: _apiSecret,
                                icon: Symbols.lock_outline,
                                obscure: true,
                              ),
                            ],
                            const SizedBox(height: 24),
                            _ConnectionSectionTitle(
                              icon: Symbols.speed_outlined,
                              title: context.t(
                                'sms.settings.connection.limits',
                              ),
                            ),
                            const SizedBox(height: 12),
                            _ResponsiveTriple(
                              compact: compact,
                              first: _UnderlinedInput(
                                label: context.t(
                                  'sms.settings.field.dailyLimit',
                                ),
                                hint: '5000',
                                controller: _dailyLimit,
                                icon: Symbols.today_outlined,
                                keyboardType: TextInputType.number,
                              ),
                              second: _UnderlinedInput(
                                label: context.t(
                                  'sms.settings.field.monthlyLimit',
                                ),
                                hint: '150000',
                                controller: _monthlyLimit,
                                icon: Symbols.calendar_month_outlined,
                                keyboardType: TextInputType.number,
                              ),
                              third: _UnderlinedInput(
                                label: context.t(
                                  'sms.settings.field.hourlyLimit',
                                ),
                                hint: '700',
                                controller: _hourlyLimit,
                                icon: Symbols.schedule_outlined,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _ResponsivePair(
                              compact: compact,
                              firstFlex: 2,
                              secondFlex: 1,
                              first: _UnderlinedInput(
                                label: context.t(
                                  'sms.settings.field.trackingDomain',
                                ),
                                hint: context.t(
                                  'sms.settings.hint.trackingDomain',
                                ),
                                controller: _trackingDomain,
                                icon: Symbols.ads_click_outlined,
                              ),
                              second: _StatusRadioGroup(
                                active: _active,
                                onChanged: (value) =>
                                    setState(() => _active = value),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 14, 16, 16),
            child: Wrap(
              spacing: 12,
              runSpacing: 10,
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _TextOnlyButton(
                  label: context.t('common.cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                _PrimaryActionButton(
                  icon: Symbols.save,
                  label: context.t('common.save'),
                  backgroundColor: AppColors.deepOcean,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ],
      ),
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

class _MetricBox extends StatelessWidget {
  const _MetricBox({required this.data});

  final _MetricData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 78,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line.withValues(alpha: 0.72)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(AppRadius.value),
            ),
            child: Center(child: Icon(data.icon, color: data.color, size: 19)),
          ),
          const SizedBox(width: 12),
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
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  data.value,
                  style: const TextStyle(
                    color: AppColors.deepOcean,
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
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

class _ConnectionSectionTitle extends StatelessWidget {
  const _ConnectionSectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.value),
          ),
          child: Icon(icon, color: AppColors.deepOcean, size: 17),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.deepOcean,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _ResponsivePair extends StatelessWidget {
  const _ResponsivePair({
    required this.compact,
    required this.first,
    required this.second,
    this.firstFlex = 1,
    this.secondFlex = 1,
  });

  final bool compact;
  final Widget first;
  final Widget second;
  final int firstFlex;
  final int secondFlex;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [first, const SizedBox(height: 16), second],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: firstFlex, child: first),
        const SizedBox(width: 24),
        Expanded(flex: secondFlex, child: second),
      ],
    );
  }
}

class _ResponsiveTriple extends StatelessWidget {
  const _ResponsiveTriple({
    required this.compact,
    required this.first,
    required this.second,
    required this.third,
  });

  final bool compact;
  final Widget first;
  final Widget second;
  final Widget third;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          first,
          const SizedBox(height: 16),
          second,
          const SizedBox(height: 16),
          third,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: first),
        const SizedBox(width: 18),
        Expanded(child: second),
        const SizedBox(width: 18),
        Expanded(child: third),
      ],
    );
  }
}

class _SecuritySelect extends StatelessWidget {
  const _SecuritySelect({required this.value, required this.onChanged});

  final AdminSmsSecurity value;
  final ValueChanged<AdminSmsSecurity?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.t('sms.settings.field.smtpSecurity'),
          style: const TextStyle(
            color: AppColors.deepOcean,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
        SizedBox(
          height: 42,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<AdminSmsSecurity>(
              value: value,
              isExpanded: true,
              icon: const SymbolIcon(
                Symbols.keyboard_arrow_down,
                color: AppColors.iconMuted,
                size: 18,
              ),
              items: AdminSmsSecurity.values
                  .map(
                    (security) => DropdownMenuItem<AdminSmsSecurity>(
                      value: security,
                      child: Text(
                        context.t(security.labelKey),
                        style: const TextStyle(
                          color: AppColors.deepOcean,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
        const Divider(height: 1, color: AppColors.line),
      ],
    );
  }
}

class _UnderlinedInput extends StatelessWidget {
  const _UnderlinedInput({
    required this.label,
    required this.hint,
    required this.controller,
    required this.icon,
    this.requiredInput = false,
    this.hasError = false,
    this.errorText,
    this.onChanged,
    this.keyboardType,
    this.obscure = false,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final IconData icon;
  final bool requiredInput;
  final bool hasError;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final bool obscure;

  @override
  Widget build(BuildContext context) {
    final color = hasError ? AppColors.actionRed : AppColors.deepOcean;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          requiredInput ? '$label *' : label,
          style: TextStyle(
            color: requiredInput || hasError ? AppColors.actionRed : color,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
        SizedBox(
          height: hasError ? 58 : 42,
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            keyboardType: keyboardType,
            obscureText: obscure,
            style: const TextStyle(
              color: AppColors.deepOcean,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              letterSpacing: 0,
            ),
            decoration: InputDecoration(
              hintText: hint,
              errorText: hasError ? errorText : null,
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 10, right: 8),
                child: Icon(icon, color: AppColors.support, size: 18),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 34),
              hintStyle: const TextStyle(
                color: AppColors.placeholder,
                fontSize: 13,
                fontWeight: FontWeight.w400,
                letterSpacing: 0,
              ),
              errorStyle: const TextStyle(
                color: AppColors.actionRed,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 11),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: hasError ? AppColors.actionRed : AppColors.line,
                ),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: color),
              ),
              errorBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.actionRed),
              ),
              focusedErrorBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.actionRed),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusRadioGroup extends StatelessWidget {
  const _StatusRadioGroup({required this.active, required this.onChanged});

  final bool active;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.t('sms.settings.field.status'),
          style: const TextStyle(
            color: AppColors.deepOcean,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            _RadioChoice(
              label: context.t('sms.settings.status.active'),
              selected: active,
              onTap: () => onChanged(true),
            ),
            _RadioChoice(
              label: context.t('sms.settings.status.passive'),
              selected: !active,
              onTap: () => onChanged(false),
            ),
          ],
        ),
      ],
    );
  }
}

class _RadioChoice extends StatelessWidget {
  const _RadioChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.deepOcean, width: 1.8),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.deepOcean,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.deepOcean,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmsSettingsRowMenu extends StatefulWidget {
  const _SmsSettingsRowMenu({
    required this.account,
    required this.onEdit,
    required this.onDnsCheck,
    required this.onToggleActive,
    required this.onDelete,
  });

  final AdminSmsAccount account;
  final VoidCallback onEdit;
  final VoidCallback onDnsCheck;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;

  @override
  State<_SmsSettingsRowMenu> createState() => _SmsSettingsRowMenuState();
}

class _SmsSettingsRowMenuState extends State<_SmsSettingsRowMenu> {
  final _layerLink = LayerLink();
  OverlayEntry? _entry;

  @override
  void dispose() {
    _removeMenu();
    super.dispose();
  }

  void _toggleMenu() {
    if (_entry == null) {
      _showMenu();
    } else {
      _removeMenu();
    }
  }

  void _showMenu() {
    _entry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _removeMenu,
            ),
          ),
          CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            targetAnchor: Alignment.bottomRight,
            followerAnchor: Alignment.topRight,
            offset: const Offset(0, 8),
            child: _SmsSettingsMenuCard(
              account: widget.account,
              onEdit: () => _tap(widget.onEdit),
              onDnsCheck: () => _tap(widget.onDnsCheck),
              onToggleActive: () => _tap(widget.onToggleActive),
              onDelete: () => _tap(widget.onDelete),
            ),
          ),
        ],
      ),
    );
    Overlay.of(context).insert(_entry!);
  }

  void _tap(VoidCallback callback) {
    _removeMenu();
    callback();
  }

  void _removeMenu() {
    _entry?.remove();
    _entry = null;
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Tooltip(
        message: context.t('sms.settings.actions'),
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

class _SmsSettingsMenuCard extends StatelessWidget {
  const _SmsSettingsMenuCard({
    required this.account,
    required this.onEdit,
    required this.onDnsCheck,
    required this.onToggleActive,
    required this.onDelete,
  });

  final AdminSmsAccount account;
  final VoidCallback onEdit;
  final VoidCallback onDnsCheck;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
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
            _SmsSettingsMenuItem(
              icon: Symbols.edit_square,
              label: 'sms.settings.action.edit',
              onTap: onEdit,
            ),
            _SmsSettingsMenuItem(
              icon: Symbols.verified_outlined,
              label: 'sms.settings.action.dnsCheck',
              onTap: onDnsCheck,
            ),
            _SmsSettingsMenuItem(
              icon: account.active
                  ? Symbols.toggle_off_outlined
                  : Symbols.toggle_on,
              label: account.active
                  ? 'sms.settings.action.deactivate'
                  : 'sms.settings.action.activate',
              onTap: onToggleActive,
            ),
            _SmsSettingsMenuItem(
              icon: Symbols.delete,
              label: 'sms.settings.action.delete',
              color: AppColors.actionRed,
              onTap: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _SmsSettingsMenuItem extends StatelessWidget {
  const _SmsSettingsMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = AppColors.deepOcean,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
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

class _DnsChip extends StatelessWidget {
  const _DnsChip({required this.label, required this.ready});

  final String label;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    final color = ready ? const Color(0xFF198754) : AppColors.warmHorizon;
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.value),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ready ? Symbols.check_circle : Symbols.pending_outlined,
            color: color,
            size: 12,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftBadge extends StatelessWidget {
  const _SoftBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.value),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _ListCheckbox extends StatelessWidget {
  const _ListCheckbox({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: selected ? AppColors.deepOcean : Colors.white,
            border: Border.all(
              color: selected ? AppColors.deepOcean : AppColors.line,
            ),
            borderRadius: BorderRadius.circular(AppRadius.value),
          ),
          child: selected
              ? const SymbolIcon(Symbols.check, color: Colors.white, size: 14)
              : null,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.value),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
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
  const _SearchField({
    required this.controller,
    required this.query,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String query;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return AdminTableSearchField(
      controller: controller,
      query: query,
      hintText: hint,
      showClearButton: true,
      onChanged: onChanged,
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.backgroundColor = AppColors.actionRed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: TextButton(
        onPressed: onPressed,
        style:
            TextButton.styleFrom(
              backgroundColor: backgroundColor,
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
            SymbolIcon(icon, color: Colors.white, size: 17),
            const SizedBox(width: 7),
            Flexible(child: Text(label)),
          ],
        ),
      ),
    );
  }
}

class _SecondaryActionButton extends StatelessWidget {
  const _SecondaryActionButton({
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
        style: TextButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.deepOcean,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.value),
            side: const BorderSide(color: AppColors.line),
          ),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.deepOcean, size: 17),
            const SizedBox(width: 7),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _TextOnlyButton extends StatelessWidget {
  const _TextOnlyButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.deepOcean,
        textStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          letterSpacing: 0,
        ),
      ),
      child: Text(label),
    );
  }
}

class _DangerTextButton extends StatelessWidget {
  const _DangerTextButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon: const SymbolIcon(
        Symbols.delete,
        color: AppColors.actionRed,
        size: 17,
      ),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.actionRed,
        textStyle: const TextStyle(
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _SmsSettingsFooter extends StatelessWidget {
  const _SmsSettingsFooter({
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
    final pageCount = totalCount == 0 ? 1 : (totalCount / pageSize).ceil();
    final start = totalCount == 0 ? 0 : (page - 1) * pageSize + 1;
    final end = math.min(page * pageSize, totalCount);
    return Row(
      children: [
        Expanded(
          child: Text(
            context.t(
              'sms.settings.recordRange',
              values: {'start': start, 'end': end, 'total': totalCount},
            ),
            style: const TextStyle(
              color: AppColors.inkSoft,
              fontWeight: FontWeight.w500,
              letterSpacing: 0,
            ),
          ),
        ),
        _PaginationButton(
          label: '<<',
          enabled: page > 1,
          onTap: () => onPageChanged(1),
        ),
        const SizedBox(width: 8),
        _PaginationButton(
          label: '<',
          enabled: page > 1,
          onTap: () => onPageChanged(page - 1),
        ),
        const SizedBox(width: 8),
        AdminTablePageButton(label: '$page', selected: true),
        const SizedBox(width: 8),
        _PaginationButton(
          label: '>',
          enabled: page < pageCount,
          onTap: () => onPageChanged(page + 1),
        ),
        const SizedBox(width: 8),
        _PaginationButton(
          label: '>>',
          enabled: page < pageCount,
          onTap: () => onPageChanged(pageCount),
        ),
      ],
    );
  }
}

class _PaginationButton extends StatelessWidget {
  const _PaginationButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AdminTablePageButton(
      label: label,
      enabled: enabled,
      onPressed: onTap,
    );
  }
}

class _SmsSettingsEmptyState extends StatelessWidget {
  const _SmsSettingsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        context.t('sms.settings.empty'),
        style: const TextStyle(
          color: AppColors.inkSoft,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
