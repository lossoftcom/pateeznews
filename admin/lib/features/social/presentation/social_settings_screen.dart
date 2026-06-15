import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';
import 'package:pateeznews_admin/shared/widgets/admin_table_chrome.dart';
import 'package:pateeznews_admin/shared/widgets/admin_toast.dart';

import '../../../core/localization/admin_date_formatter.dart';
import '../../../core/localization/admin_language_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/widgets/app_confirmation_dialog.dart';
import '../../../shared/widgets/sortable_table_header.dart';
import '../../../shared/widgets/symbol_icon.dart';
import '../../auth/data/admin_auth_models.dart';
import '../data/admin_social_repository.dart';
import 'social_platform_data.dart';
import 'social_settings_models.dart';
import 'widgets/social_brand_logo.dart';

class SocialSettingsScreen extends StatefulWidget {
  const SocialSettingsScreen({
    super.key,
    required this.session,
    required this.repository,
  });

  final AdminSession session;
  final AdminSocialRepository repository;

  @override
  State<SocialSettingsScreen> createState() => _SocialSettingsScreenState();
}

class _SocialSettingsScreenState extends State<SocialSettingsScreen> {
  var _accounts = <AdminSocialAccount>[];
  final _searchController = TextEditingController();
  var _searchQuery = '';
  var _pageSize = 25;
  var _page = 0;
  var _sortState = const TableSortState(key: 'date', ascending: false);
  var _selectedIds = <int>{};
  int? _activeAccountId;
  var _loading = true;
  var _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AdminSocialAccount> get _filteredAccounts {
    final query = _searchQuery.trim().toLowerCase();
    final filtered = query.isEmpty
        ? List<AdminSocialAccount>.of(_accounts)
        : _accounts.where((account) {
            final haystack = [
              account.accountName,
              account.workspaceName,
              account.platforms,
              account.providerName,
              account.teamId,
              account.apiBaseUrl,
            ].join(' ').toLowerCase();
            return haystack.contains(query);
          }).toList();

    filtered.sort((left, right) {
      final result = switch (_sortState.key) {
        'account' => left.accountName.compareTo(right.accountName),
        'provider' => left.providerName.compareTo(right.providerName),
        'platform' => left.platforms.compareTo(right.platforms),
        'team' => left.teamId.compareTo(right.teamId),
        'limit' => left.sentToday.compareTo(right.sentToday),
        'connection' => left.connectionReady.toString().compareTo(
          right.connectionReady.toString(),
        ),
        'status' => left.active.toString().compareTo(right.active.toString()),
        'date' || _ => left.createdAt.compareTo(right.createdAt),
      };
      return _sortState.ascending ? result : -result;
    });

    return filtered;
  }

  List<AdminSocialAccount> get _pagedAccounts {
    final filtered = _filteredAccounts;
    if (filtered.isEmpty) return const <AdminSocialAccount>[];
    final start = (_page * _pageSize).clamp(0, filtered.length);
    final end = math.min(start + _pageSize, filtered.length);
    return filtered.sublist(start, end);
  }

  AdminSocialAccount? get _activeAccount {
    for (final account in _accounts) {
      if (account.id == _activeAccountId) return account;
    }
    return null;
  }

  int get _bundleReadyCount => _accounts
      .where(
        (account) =>
            account.providerId == 'bundle_social' && account.connectionReady,
      )
      .length;

  int get _oauthReadyCount =>
      _accounts.where((account) => account.oauthReady).length;

  int get _webhookReadyCount =>
      _accounts.where((account) => account.webhookReady).length;

  int get _approvalRequiredCount =>
      _accounts.where((account) => account.requiresApproval).length;

  void _resetListState() {
    final maxPage = _maxPage(_filteredAccounts.length);
    if (_page > maxPage) _page = maxPage;
    _selectedIds = _selectedIds.intersection(
      _accounts.map((account) => account.id).toSet(),
    );
  }

  int _maxPage(int totalCount) {
    if (totalCount <= 0) return 0;
    return ((totalCount - 1) / _pageSize).floor();
  }

  void _changePageSize(int? value) {
    if (value == null) return;
    setState(() {
      _pageSize = value;
      _page = 0;
    });
  }

  void _changeSearch(String value) {
    setState(() {
      _searchQuery = value;
      _page = 0;
    });
  }

  void _changePage(int page) {
    setState(() => _page = page.clamp(0, _maxPage(_filteredAccounts.length)));
  }

  void _changeSort(String key) {
    setState(() => _sortState = _sortState.toggled(key));
  }

  void _toggleAccount(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds = {..._selectedIds}..remove(id);
      } else {
        _selectedIds = {..._selectedIds, id};
      }
    });
  }

  void _toggleAllAccounts() {
    final pageIds = _pagedAccounts.map((account) => account.id).toSet();
    setState(() {
      if (pageIds.isNotEmpty && _selectedIds.containsAll(pageIds)) {
        _selectedIds = {..._selectedIds}..removeAll(pageIds);
      } else {
        _selectedIds = {..._selectedIds, ...pageIds};
      }
    });
  }

  void _replaceAccount(AdminSocialAccount account) {
    final exists = _accounts.any((current) => current.id == account.id);
    setState(() {
      if (!exists) {
        _accounts = [account, ..._accounts];
      } else {
        _accounts = [
          for (final current in _accounts)
            if (current.id == account.id) account else current,
        ];
      }
      _activeAccountId = account.id;
      _resetListState();
    });
  }

  Future<void> _loadAccounts() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final accounts = await widget.repository.fetchSettings(widget.session);
      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        _activeAccountId = accounts.firstOrNull?.id;
        _loading = false;
        _resetListState();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = error.toString();
      });
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    AdminToast.show(
      context,
      message: error.toString(),
      tone: AdminToastTone.error,
    );
  }

  Future<void> _toggleActive(AdminSocialAccount account) async {
    try {
      final updated = await widget.repository.updateSetting(
        widget.session,
        account,
        {'is_active': !account.active},
      );
      if (!mounted) return;
      _replaceAccount(updated);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _markConnectionReady(AdminSocialAccount account) async {
    try {
      final updated = await widget.repository.checkSetting(
        widget.session,
        account.id,
      );
      if (!mounted) return;
      _replaceAccount(updated);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _deleteSelectedAccounts() async {
    final count = _selectedIds.length;
    if (count == 0) return;
    final confirmed = await showAppConfirmationDialog(
      context,
      title: context.t('social.settings.deleteSelectedTitle'),
      message: context.t(
        'social.settings.deleteSelectedMessage',
        values: {'count': count},
      ),
      confirmLabel: context.t('social.settings.action.delete'),
      danger: true,
    );
    if (!confirmed || !mounted) return;
    try {
      await widget.repository.deleteSettings(widget.session, _selectedIds);
      if (!mounted) return;
      setState(() {
        _accounts = _accounts
            .where((account) => !_selectedIds.contains(account.id))
            .toList();
        _selectedIds = {};
        _activeAccountId = _accounts.firstOrNull?.id;
        _resetListState();
      });
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _deleteAccount(AdminSocialAccount account) async {
    final confirmed = await showAppConfirmationDialog(
      context,
      title: context.t('social.settings.deleteTitle'),
      message: context.t('social.settings.deleteMessage'),
      confirmLabel: context.t('social.settings.action.delete'),
      danger: true,
    );
    if (!confirmed || !mounted) return;
    try {
      await widget.repository.deleteSettings(widget.session, [account.id]);
      if (!mounted) return;
      setState(() {
        _accounts = _accounts
            .where((current) => current.id != account.id)
            .toList();
        _selectedIds = {..._selectedIds}..remove(account.id);
        _activeAccountId = _accounts.firstOrNull?.id;
        _resetListState();
      });
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _openProviderPicker() async {
    final preset = await showDialog<AdminSocialProviderPreset>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 32,
          ),
          backgroundColor: Colors.transparent,
          child: const _ProviderPickerDialog(),
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
    AdminSocialAccount? account,
    AdminSocialProviderPreset? preset,
  }) async {
    final result = await showDialog<AdminSocialAccount>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 32,
          ),
          backgroundColor: Colors.transparent,
          child: _ConnectionSettingsDialog(account: account, preset: preset),
        );
      },
    );
    if (result == null || !mounted) return;
    setState(() => _saving = true);
    try {
      final saved = await widget.repository.saveSetting(
        widget.session,
        id: account?.id,
        account: result,
        apiKey: result.clientId,
        clientSecret: result.clientSecret,
      );
      if (!mounted) return;
      _replaceAccount(saved);
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
            _SocialSettingsTitle(
              selectedCount: _selectedIds.length,
              onDeleteSelected: _deleteSelectedAccounts,
            ),
            const SizedBox(height: 24),
            _SocialSettingsMetricGrid(
              totalAccounts: _accounts.length,
              bundleReady: _bundleReadyCount,
              oauthReady: _oauthReadyCount,
              webhookReady: _webhookReadyCount,
              approvalRequired: _approvalRequiredCount,
            ),
            const SizedBox(height: 14),
            if (_saving) ...[
              const LinearProgressIndicator(
                minHeight: 2,
                color: AppColors.actionRed,
                backgroundColor: AppColors.softLine,
              ),
              const SizedBox(height: 12),
            ],
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.deepOcean,
                      ),
                    )
                  : _errorMessage != null
                  ? _SocialSettingsLoadError(
                      message: _errorMessage!,
                      onRetry: _loadAccounts,
                    )
                  : _SocialSettingsTableCard(
                      accounts: _pagedAccounts,
                      page: _page,
                      pageSize: _pageSize,
                      totalCount: _filteredAccounts.length,
                      searchController: _searchController,
                      selectedIds: _selectedIds,
                      activeAccountId: _activeAccountId,
                      sortState: _sortState,
                      onPageSizeChanged: _changePageSize,
                      onSearchChanged: _changeSearch,
                      onPageChanged: _changePage,
                      onToggleAccount: _toggleAccount,
                      onToggleAllAccounts: _toggleAllAccounts,
                      onSort: _changeSort,
                      onRefresh: _loadAccounts,
                      onSettings: _openSelectedSettings,
                      onCreate: _openProviderPicker,
                      onSelectRow: (account) =>
                          setState(() => _activeAccountId = account.id),
                      onEdit: (account) =>
                          _openConnectionDialog(account: account),
                      onConnectionCheck: _markConnectionReady,
                      onToggleActive: _toggleActive,
                      onDelete: _deleteAccount,
                    ),
            ),
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

class _SocialSettingsLoadError extends StatelessWidget {
  const _SocialSettingsLoadError({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.inkSoft,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onRetry,
            child: Text(context.t('social.settings.refresh')),
          ),
        ],
      ),
    );
  }
}

class _SocialSettingsTitle extends StatelessWidget {
  const _SocialSettingsTitle({
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
                context.t('social.settings.centerTitle'),
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
                  'social.settings.selectedDelete',
                  values: {'count': selectedCount},
                ),
                onTap: onDeleteSelected,
              ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          context.t('social.settings.centerDescription'),
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

class _SocialSettingsMetricGrid extends StatelessWidget {
  const _SocialSettingsMetricGrid({
    required this.totalAccounts,
    required this.bundleReady,
    required this.oauthReady,
    required this.webhookReady,
    required this.approvalRequired,
  });

  final int totalAccounts;
  final int bundleReady;
  final int oauthReady;
  final int webhookReady;
  final int approvalRequired;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _MetricData(
        label: 'social.settings.metric.totalAccounts',
        value: '$totalAccounts',
        icon: Symbols.dns_outlined,
        color: AppColors.deepOcean,
      ),
      _MetricData(
        label: 'social.settings.metric.bundleReady',
        value: '$bundleReady',
        icon: Symbols.hub_outlined,
        color: const Color(0xFF198754),
      ),
      _MetricData(
        label: 'social.settings.metric.oauthReady',
        value: '$oauthReady',
        icon: Symbols.verified,
        color: const Color(0xFF2F80ED),
      ),
      _MetricData(
        label: 'social.settings.metric.webhooks',
        value: '$webhookReady',
        icon: Symbols.webhook_outlined,
        color: const Color(0xFF16A085),
      ),
      _MetricData(
        label: 'social.settings.metric.approval',
        value: '$approvalRequired',
        icon: Symbols.verified_user_outlined,
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

class _SocialSettingsTableCard extends StatelessWidget {
  const _SocialSettingsTableCard({
    required this.accounts,
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.searchController,
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
    required this.onConnectionCheck,
    required this.onToggleActive,
    required this.onDelete,
  });

  static const _minTableWidth = 860.0;

  final List<AdminSocialAccount> accounts;
  final int page;
  final int pageSize;
  final int totalCount;
  final TextEditingController searchController;
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
  final ValueChanged<AdminSocialAccount> onSelectRow;
  final ValueChanged<AdminSocialAccount> onEdit;
  final ValueChanged<AdminSocialAccount> onConnectionCheck;
  final ValueChanged<AdminSocialAccount> onToggleActive;
  final ValueChanged<AdminSocialAccount> onDelete;

  @override
  Widget build(BuildContext context) {
    final pageIds = accounts.map((account) => account.id).toSet();
    final allSelected = pageIds.isNotEmpty && selectedIds.containsAll(pageIds);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SocialSettingsToolbar(
          pageSize: pageSize,
          searchController: searchController,
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
                        _SocialSettingsTableHeader(
                          selected: allSelected,
                          sortState: sortState,
                          onToggle: onToggleAllAccounts,
                          onSort: onSort,
                        ),
                        Expanded(
                          child: accounts.isEmpty
                              ? const _SocialSettingsEmptyState()
                              : ListView.builder(
                                  itemCount: accounts.length,
                                  itemBuilder: (context, index) {
                                    final account = accounts[index];
                                    return _SocialSettingsTableRow(
                                      account: account,
                                      selected: selectedIds.contains(
                                        account.id,
                                      ),
                                      active: account.id == activeAccountId,
                                      onToggle: () =>
                                          onToggleAccount(account.id),
                                      onSelect: () => onSelectRow(account),
                                      onEdit: () => onEdit(account),
                                      onConnectionCheck: () =>
                                          onConnectionCheck(account),
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
        _SocialSettingsFooter(
          page: page,
          pageSize: pageSize,
          totalCount: totalCount,
          onPageChanged: onPageChanged,
        ),
      ],
    );
  }
}

class _SocialSettingsToolbar extends StatelessWidget {
  const _SocialSettingsToolbar({
    required this.pageSize,
    required this.searchController,
    required this.onPageSizeChanged,
    required this.onSearchChanged,
    required this.onRefresh,
    required this.onSettings,
    required this.onCreate,
  });

  final int pageSize;
  final TextEditingController searchController;
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
                hint: context.t('social.settings.searchPlaceholder'),
                onChanged: onSearchChanged,
              ),
            ),
            _SecondaryActionButton(
              icon: Symbols.refresh,
              label: context.t('social.settings.refresh'),
              onPressed: onRefresh,
            ),
            _SecondaryActionButton(
              icon: Symbols.settings_outlined,
              label: context.t('social.settings.settingsButton'),
              onPressed: onSettings,
            ),
            _PrimaryActionButton(
              icon: Symbols.add,
              label: context.t('social.settings.addAccount'),
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

class _SocialSettingsTableHeader extends StatelessWidget {
  const _SocialSettingsTableHeader({
    required this.selected,
    required this.sortState,
    required this.onToggle,
    required this.onSort,
  });

  static const _selectWidth = 42.0;
  static const _limitWidth = 132.0;
  static const _connectionWidth = 148.0;
  static const _statusWidth = 126.0;
  static const _actionsWidth = 76.0;
  static const _accountFlex = 3;
  static const _platformFlex = 5;
  static const _dateFlex = 2;

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
            child: _SocialSettingsSortableHeader(
              label: 'social.settings.column.account',
              sortKey: 'account',
              sortState: sortState,
              onSort: onSort,
            ),
          ),
          Expanded(
            flex: _platformFlex,
            child: _SocialSettingsSortableHeader(
              label: 'social.settings.column.platform',
              sortKey: 'platform',
              sortState: sortState,
              onSort: onSort,
            ),
          ),
          SizedBox(
            width: _limitWidth,
            child: Center(
              child: IntrinsicWidth(
                child: _SocialSettingsSortableHeader(
                  label: 'social.settings.column.limit',
                  sortKey: 'limit',
                  sortState: sortState,
                  onSort: onSort,
                ),
              ),
            ),
          ),
          SizedBox(
            width: _connectionWidth,
            child: _SocialSettingsSortableHeader(
              label: 'social.settings.column.connection',
              sortKey: 'connection',
              sortState: sortState,
              onSort: onSort,
            ),
          ),
          SizedBox(
            width: _statusWidth,
            child: _SocialSettingsSortableHeader(
              label: 'social.settings.column.status',
              sortKey: 'status',
              sortState: sortState,
              onSort: onSort,
            ),
          ),
          Expanded(
            flex: _dateFlex,
            child: _SocialSettingsSortableHeader(
              label: 'social.settings.column.date',
              sortKey: 'date',
              sortState: sortState,
              onSort: onSort,
            ),
          ),
          SizedBox(
            width: _actionsWidth,
            child: Center(
              child: Text(
                context.t('social.settings.column.actions'),
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

class _SocialSettingsSortableHeader extends StatelessWidget {
  const _SocialSettingsSortableHeader({
    required this.label,
    required this.sortKey,
    required this.sortState,
    required this.onSort,
  });

  final String label;
  final String sortKey;
  final TableSortState sortState;
  final ValueChanged<String> onSort;

  @override
  Widget build(BuildContext context) {
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

class _SocialSettingsTableRow extends StatelessWidget {
  const _SocialSettingsTableRow({
    required this.account,
    required this.selected,
    required this.active,
    required this.onToggle,
    required this.onSelect,
    required this.onEdit,
    required this.onConnectionCheck,
    required this.onToggleActive,
    required this.onDelete,
  });

  final AdminSocialAccount account;
  final bool selected;
  final bool active;
  final VoidCallback onToggle;
  final VoidCallback onSelect;
  final VoidCallback onEdit;
  final VoidCallback onConnectionCheck;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final provider = adminSocialProviderById(account.providerId);
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
                width: _SocialSettingsTableHeader._selectWidth,
                child: Center(
                  child: _ListCheckbox(selected: selected, onTap: onToggle),
                ),
              ),
              Expanded(
                flex: _SocialSettingsTableHeader._accountFlex,
                child: Row(
                  children: [
                    _ProviderLogo(preset: provider, size: 36, iconSize: 20),
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
                            account.apiBaseUrl,
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
                flex: _SocialSettingsTableHeader._platformFlex,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.platforms,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.deepOcean,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      account.workspaceName,
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
                width: _SocialSettingsTableHeader._limitWidth,
                child: Center(
                  child: Text(
                    '${account.sentToday} / ${account.dailyLimit}',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.deepOcean,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: _SocialSettingsTableHeader._connectionWidth,
                child: Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: [
                    _ConnectionChip(label: 'API', ready: account.apiReady),
                    _ConnectionChip(label: 'OAuth', ready: account.oauthReady),
                    _ConnectionChip(
                      label: 'Webhook',
                      ready: account.webhookReady,
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: _SocialSettingsTableHeader._statusWidth,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _StatusBadge(
                    label: account.active
                        ? context.t('social.settings.status.active')
                        : context.t('social.settings.status.passive'),
                    color: account.active
                        ? const Color(0xFF198754)
                        : AppColors.support,
                  ),
                ),
              ),
              Expanded(
                flex: _SocialSettingsTableHeader._dateFlex,
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
                width: _SocialSettingsTableHeader._actionsWidth,
                child: Align(
                  alignment: Alignment.center,
                  child: _SocialSettingsRowMenu(
                    account: account,
                    onEdit: onEdit,
                    onConnectionCheck: onConnectionCheck,
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

class _ProviderPickerDialog extends StatelessWidget {
  const _ProviderPickerDialog();

  @override
  Widget build(BuildContext context) {
    final unified = adminSocialProviderPresets
        .where(
          (preset) =>
              preset.categoryKey ==
              'social.settings.providerDialog.category.unified',
        )
        .toList();
    final platforms = adminSocialProviderPresets
        .where(
          (preset) =>
              preset.categoryKey ==
              'social.settings.providerDialog.category.platforms',
        )
        .toList();
    final openSocial = adminSocialProviderPresets
        .where(
          (preset) =>
              preset.categoryKey ==
              'social.settings.providerDialog.category.openSocial',
        )
        .toList();
    final messaging = adminSocialProviderPresets
        .where(
          (preset) =>
              preset.categoryKey ==
              'social.settings.providerDialog.category.messaging',
        )
        .toList();

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 860, maxHeight: 840),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.value),
        ),
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.t('social.settings.providerDialog.title'),
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: AppColors.deepOcean,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        context.t('social.settings.providerDialog.subtitle'),
                        style: const TextStyle(
                          color: AppColors.inkSoft,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  mouseCursor: SystemMouseCursors.click,
                  onPressed: () => Navigator.pop(context),
                  icon: const SymbolIcon(
                    Symbols.close,
                    color: AppColors.deepOcean,
                    size: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Flexible(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.line),
                  borderRadius: BorderRadius.circular(AppRadius.value),
                ),
                padding: const EdgeInsets.all(18),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (unified.isNotEmpty) ...[
                        _ProviderGroupTitle(
                          label: context.t(
                            'social.settings.providerDialog.category.unified',
                          ),
                        ),
                        _ProviderGrid(presets: unified),
                      ],
                      if (platforms.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _ProviderGroupTitle(
                          label: context.t(
                            'social.settings.providerDialog.category.platforms',
                          ),
                        ),
                        _ProviderGrid(presets: platforms),
                      ],
                      if (openSocial.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _ProviderGroupTitle(
                          label: context.t(
                            'social.settings.providerDialog.category.openSocial',
                          ),
                        ),
                        _ProviderGrid(presets: openSocial),
                      ],
                      if (messaging.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _ProviderGroupTitle(
                          label: context.t(
                            'social.settings.providerDialog.category.messaging',
                          ),
                        ),
                        _ProviderGrid(presets: messaging),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderGroupTitle extends StatelessWidget {
  const _ProviderGroupTitle({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.deepOcean,
          fontSize: 13,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _ProviderLogo extends StatelessWidget {
  const _ProviderLogo({
    required this.preset,
    required this.size,
    required this.iconSize,
  });

  final AdminSocialProviderPreset preset;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final platform = preset.platform;
    if (platform != null) {
      return SocialBrandLogo(
        info: platformInfoFor(platform),
        size: size,
        iconSize: iconSize,
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: preset.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.value),
      ),
      child: Icon(
        preset.fallbackIcon ?? Symbols.hub_outlined,
        color: preset.color,
        size: iconSize,
      ),
    );
  }
}

class _ProviderGrid extends StatelessWidget {
  const _ProviderGrid({required this.presets});

  final List<AdminSocialProviderPreset> presets;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 650;
        final itemWidth = twoColumns
            ? (constraints.maxWidth - 10) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final preset in presets)
              SizedBox(
                width: itemWidth,
                child: _ProviderCard(preset: preset),
              ),
          ],
        );
      },
    );
  }
}

class _ProviderCard extends StatelessWidget {
  const _ProviderCard({required this.preset});

  final AdminSocialProviderPreset preset;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.pop(context, preset),
        child: Container(
          constraints: const BoxConstraints(minHeight: 86),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(AppRadius.value),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _ProviderLogo(preset: preset, size: 38, iconSize: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                        if (preset.badgeKey != null)
                          _SoftBadge(
                            label: context.t(preset.badgeKey!),
                            color: preset.id == 'bundle_social'
                                ? const Color(0xFF198754)
                                : const Color(0xFFF39C12),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.t('social.settings.providerDialog.description'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.inkSoft,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
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

  final AdminSocialAccount? account;
  final AdminSocialProviderPreset? preset;

  @override
  State<_ConnectionSettingsDialog> createState() =>
      _ConnectionSettingsDialogState();
}

class _ConnectionSettingsDialogState extends State<_ConnectionSettingsDialog> {
  late final AdminSocialProviderPreset _preset;
  late final TextEditingController _accountNameController;
  late final TextEditingController _workspaceController;
  late final TextEditingController _platformsController;
  late final TextEditingController _apiBaseUrlController;
  late final TextEditingController _teamIdController;
  late final TextEditingController _clientIdController;
  late final TextEditingController _clientSecretController;
  late final TextEditingController _redirectUrlController;
  late final TextEditingController _webhookUrlController;
  late final TextEditingController _scopesController;
  late final TextEditingController _dailyLimitController;
  late final TextEditingController _monthlyLimitController;
  late final TextEditingController _hourlyLimitController;
  late bool _active;

  @override
  void initState() {
    super.initState();
    final account = widget.account;
    _preset =
        widget.preset ??
        (account == null
            ? adminSocialProviderById('bundle_social')
            : adminSocialProviderById(account.providerId));
    _accountNameController = TextEditingController(
      text: account?.accountName ?? _defaultAccountName(_preset),
    );
    _workspaceController = TextEditingController(
      text: account?.workspaceName ?? '',
    );
    _platformsController = TextEditingController(
      text: account?.platforms ?? _preset.defaultScopes,
    );
    _apiBaseUrlController = TextEditingController(
      text: account?.apiBaseUrl ?? _preset.apiBaseUrl,
    );
    _teamIdController = TextEditingController(text: account?.teamId ?? '');
    _clientIdController = TextEditingController(text: account?.clientId ?? '');
    _clientSecretController = TextEditingController();
    _redirectUrlController = TextEditingController(
      text: account?.redirectUrl ?? '',
    );
    _webhookUrlController = TextEditingController(
      text: account?.webhookUrl ?? '',
    );
    _scopesController = TextEditingController(
      text: account?.scopes ?? _preset.defaultScopes,
    );
    _dailyLimitController = TextEditingController(
      text: '${account?.dailyLimit ?? 10000}',
    );
    _monthlyLimitController = TextEditingController(
      text: '${account?.monthlyLimit ?? 100000}',
    );
    _hourlyLimitController = TextEditingController(
      text: '${account?.hourlyLimit ?? 700}',
    );
    _active = account?.active ?? true;
  }

  @override
  void dispose() {
    _accountNameController.dispose();
    _workspaceController.dispose();
    _platformsController.dispose();
    _apiBaseUrlController.dispose();
    _teamIdController.dispose();
    _clientIdController.dispose();
    _clientSecretController.dispose();
    _redirectUrlController.dispose();
    _webhookUrlController.dispose();
    _scopesController.dispose();
    _dailyLimitController.dispose();
    _monthlyLimitController.dispose();
    _hourlyLimitController.dispose();
    super.dispose();
  }

  String _defaultAccountName(AdminSocialProviderPreset preset) {
    if (preset.id == 'bundle_social') return 'Bundle.social';
    return preset.name;
  }

  int _parseInt(TextEditingController controller, int fallback) {
    return int.tryParse(controller.text.trim()) ?? fallback;
  }

  void _save() {
    final existing = widget.account;
    final hasStoredApiKey =
        existing?.hasApiKey == true || existing?.serverApiKeyConfigured == true;
    final apiReady =
        _apiBaseUrlController.text.trim().isNotEmpty &&
        (_clientIdController.text.trim().isNotEmpty || hasStoredApiKey);
    final oauthReady =
        _teamIdController.text.trim().isNotEmpty &&
        _redirectUrlController.text.trim().isNotEmpty;
    final webhookReady = _webhookUrlController.text.trim().isNotEmpty;
    final account = AdminSocialAccount(
      id: existing?.id ?? DateTime.now().millisecondsSinceEpoch,
      accountName: _accountNameController.text.trim().isEmpty
          ? _defaultAccountName(_preset)
          : _accountNameController.text.trim(),
      workspaceName: _workspaceController.text.trim(),
      platforms: _platformsController.text.trim(),
      providerId: _preset.id,
      providerName: _preset.name,
      mode: _preset.mode,
      apiBaseUrl: _apiBaseUrlController.text.trim(),
      teamId: _teamIdController.text.trim(),
      clientId: _clientIdController.text.trim(),
      clientSecret: _clientSecretController.text.trim(),
      redirectUrl: _redirectUrlController.text.trim(),
      webhookUrl: _webhookUrlController.text.trim(),
      scopes: _scopesController.text.trim(),
      dailyLimit: _parseInt(_dailyLimitController, 10000),
      monthlyLimit: _parseInt(_monthlyLimitController, 100000),
      hourlyLimit: _parseInt(_hourlyLimitController, 700),
      sentToday: existing?.sentToday ?? 0,
      apiReady: apiReady,
      oauthReady: oauthReady,
      webhookReady: webhookReady,
      requiresApproval: _preset.badgeKey == 'social.settings.badge.approval',
      active: _active,
      createdAt: existing?.createdAt ?? DateTime.now(),
    );
    Navigator.pop(context, account);
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 860, maxHeight: 840),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.value),
        ),
        padding: const EdgeInsets.fromLTRB(28, 24, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.t('social.settings.connection.title'),
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: AppColors.deepOcean,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        context.t(
                          'social.settings.connection.subtitle',
                          values: {'provider': _preset.name},
                        ),
                        style: const TextStyle(
                          color: AppColors.inkSoft,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  mouseCursor: SystemMouseCursors.click,
                  onPressed: () => Navigator.pop(context),
                  icon: const SymbolIcon(
                    Symbols.close,
                    color: AppColors.deepOcean,
                    size: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Flexible(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.line),
                  borderRadius: BorderRadius.circular(AppRadius.value),
                ),
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ConnectionSectionTitle(
                        icon: Symbols.badge_outlined,
                        title: context.t('social.settings.connection.identity'),
                      ),
                      const SizedBox(height: 12),
                      _ResponsivePair(
                        left: _UnderlinedInput(
                          controller: _accountNameController,
                          label: context.t('social.settings.field.accountName'),
                          hint: context.t('social.settings.hint.accountName'),
                          icon: Symbols.dns_outlined,
                          required: true,
                        ),
                        right: _UnderlinedInput(
                          controller: _workspaceController,
                          label: context.t('social.settings.field.workspace'),
                          hint: context.t('social.settings.hint.workspace'),
                          icon: Symbols.group_work_outlined,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _ResponsivePair(
                        left: _UnderlinedInput(
                          controller: _platformsController,
                          label: context.t('social.settings.field.platforms'),
                          hint: context.t('social.settings.hint.platforms'),
                          icon: Symbols.share_outlined,
                          required: true,
                        ),
                        right: _UnderlinedInput(
                          controller: _teamIdController,
                          label: context.t('social.settings.field.teamId'),
                          hint: context.t('social.settings.hint.teamId'),
                          icon: Symbols.alternate_email,
                          required: true,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _ConnectionSectionTitle(
                        icon: Symbols.api_outlined,
                        title: context.t('social.settings.connection.api'),
                      ),
                      const SizedBox(height: 12),
                      _ResponsivePair(
                        left: _UnderlinedInput(
                          controller: _apiBaseUrlController,
                          label: context.t('social.settings.field.apiBaseUrl'),
                          hint: context.t('social.settings.hint.apiBaseUrl'),
                          icon: Symbols.link_outlined,
                          required: true,
                        ),
                        right: _UnderlinedInput(
                          controller: _clientIdController,
                          label: _preset.id == 'bundle_social'
                              ? context.t('social.settings.field.apiKey')
                              : context.t('social.settings.field.clientId'),
                          hint: _preset.id == 'bundle_social'
                              ? 'x-api-key'
                              : context.t('social.settings.hint.clientId'),
                          icon: Symbols.key_outlined,
                          required: true,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _ResponsivePair(
                        left: _UnderlinedInput(
                          controller: _clientSecretController,
                          label: context.t('social.settings.field.secret'),
                          hint: context.t('social.settings.hint.secret'),
                          icon: Symbols.lock_outline,
                        ),
                        right: _UnderlinedInput(
                          controller: _redirectUrlController,
                          label: context.t('social.settings.field.redirectUrl'),
                          hint: context.t('social.settings.hint.redirectUrl'),
                          icon: Symbols.login_outlined,
                          required: true,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _UnderlinedInput(
                        controller: _scopesController,
                        label: context.t('social.settings.field.scopes'),
                        hint: context.t('social.settings.hint.scopes'),
                        icon: Symbols.fact_check_outlined,
                      ),
                      const SizedBox(height: 24),
                      _ConnectionSectionTitle(
                        icon: Symbols.speed_outlined,
                        title: context.t('social.settings.connection.limits'),
                      ),
                      const SizedBox(height: 12),
                      _ResponsiveTriple(
                        first: _UnderlinedInput(
                          controller: _dailyLimitController,
                          label: context.t('social.settings.field.dailyLimit'),
                          hint: '10000',
                          icon: Symbols.today_outlined,
                          keyboardType: TextInputType.number,
                        ),
                        second: _UnderlinedInput(
                          controller: _monthlyLimitController,
                          label: context.t(
                            'social.settings.field.monthlyLimit',
                          ),
                          hint: '100000',
                          icon: Symbols.calendar_month_outlined,
                          keyboardType: TextInputType.number,
                        ),
                        third: _UnderlinedInput(
                          controller: _hourlyLimitController,
                          label: context.t('social.settings.field.hourlyLimit'),
                          hint: '700',
                          icon: Symbols.schedule_outlined,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _ResponsivePair(
                        left: _UnderlinedInput(
                          controller: _webhookUrlController,
                          label: context.t('social.settings.field.webhookUrl'),
                          hint: context.t('social.settings.hint.webhookUrl'),
                          icon: Symbols.webhook_outlined,
                        ),
                        right: _StatusRadioGroup(
                          active: _active,
                          onChanged: (value) => setState(() => _active = value),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _TextOnlyButton(
                  label: context.t('social.settings.cancel'),
                  onTap: () => Navigator.pop(context),
                ),
                const SizedBox(width: 12),
                _PrimaryActionButton(
                  icon: Symbols.save,
                  label: context.t('social.settings.save'),
                  backgroundColor: AppColors.deepOcean,
                  onPressed: _save,
                ),
              ],
            ),
          ],
        ),
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
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppRadius.value),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.value),
            ),
            child: Icon(data.icon, color: data.color, size: 19),
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
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  data.value,
                  style: const TextStyle(
                    color: AppColors.deepOcean,
                    fontSize: 22,
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
          child: Icon(icon, size: 17, color: AppColors.deepOcean),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            color: AppColors.deepOcean,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _ResponsivePair extends StatelessWidget {
  const _ResponsivePair({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 640) {
          return Column(children: [left, const SizedBox(height: 16), right]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: 24),
            Expanded(child: right),
          ],
        );
      },
    );
  }
}

class _ResponsiveTriple extends StatelessWidget {
  const _ResponsiveTriple({
    required this.first,
    required this.second,
    required this.third,
  });

  final Widget first;
  final Widget second;
  final Widget third;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 760) {
          return Column(
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
      },
    );
  }
}

class _UnderlinedInput extends StatelessWidget {
  const _UnderlinedInput({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.required = false,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool required;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final labelText = required ? '$label *' : label;
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      cursorColor: AppColors.deepOcean,
      style: const TextStyle(
        color: AppColors.deepOcean,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hint,
        prefixIcon: Icon(icon, size: 17, color: AppColors.support),
        filled: false,
        isDense: true,
        contentPadding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
        labelStyle: TextStyle(
          color: required ? AppColors.actionRed : AppColors.inkSoft,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
        floatingLabelStyle: TextStyle(
          color: required ? AppColors.actionRed : AppColors.support,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
        hintStyle: const TextStyle(
          color: AppColors.support,
          fontWeight: FontWeight.w500,
          letterSpacing: 0,
        ),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.line),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.support),
        ),
      ),
    );
  }
}

class _StatusRadioGroup extends StatelessWidget {
  const _StatusRadioGroup({required this.active, required this.onChanged});

  final bool active;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t('social.settings.field.status'),
            style: const TextStyle(
              color: AppColors.deepOcean,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _RadioChoice(
                label: context.t('social.settings.status.active'),
                selected: active,
                onTap: () => onChanged(true),
              ),
              const SizedBox(width: 18),
              _RadioChoice(
                label: context.t('social.settings.status.passive'),
                selected: !active,
                onTap: () => onChanged(false),
              ),
            ],
          ),
        ],
      ),
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
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppColors.deepOcean : AppColors.inkSoft,
                  width: 2,
                ),
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
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.deepOcean,
                fontSize: 13,
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
        child: Container(
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
              ? const SymbolIcon(Symbols.check, color: Colors.white, size: 13)
              : null,
        ),
      ),
    );
  }
}

class _SocialSettingsRowMenu extends StatefulWidget {
  const _SocialSettingsRowMenu({
    required this.account,
    required this.onEdit,
    required this.onConnectionCheck,
    required this.onToggleActive,
    required this.onDelete,
  });

  final AdminSocialAccount account;
  final VoidCallback onEdit;
  final VoidCallback onConnectionCheck;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;

  @override
  State<_SocialSettingsRowMenu> createState() => _SocialSettingsRowMenuState();
}

class _SocialSettingsRowMenuState extends State<_SocialSettingsRowMenu> {
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
            child: _SocialSettingsMenuCard(
              account: widget.account,
              onEdit: () => _tap(widget.onEdit),
              onConnectionCheck: () => _tap(widget.onConnectionCheck),
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
        message: context.t('social.settings.actions'),
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

class _SocialSettingsMenuCard extends StatelessWidget {
  const _SocialSettingsMenuCard({
    required this.account,
    required this.onEdit,
    required this.onConnectionCheck,
    required this.onToggleActive,
    required this.onDelete,
  });

  final AdminSocialAccount account;
  final VoidCallback onEdit;
  final VoidCallback onConnectionCheck;
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
            _SocialSettingsMenuItem(
              icon: Symbols.edit_square,
              label: 'social.settings.action.edit',
              onTap: onEdit,
            ),
            _SocialSettingsMenuItem(
              icon: Symbols.verified_outlined,
              label: 'social.settings.action.connectionCheck',
              onTap: onConnectionCheck,
            ),
            _SocialSettingsMenuItem(
              icon: account.active
                  ? Symbols.toggle_off_outlined
                  : Symbols.toggle_on,
              label: account.active
                  ? 'social.settings.action.deactivate'
                  : 'social.settings.action.activate',
              onTap: onToggleActive,
            ),
            _SocialSettingsMenuItem(
              icon: Symbols.delete,
              label: 'social.settings.action.delete',
              color: AppColors.actionRed,
              onTap: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _SocialSettingsMenuItem extends StatelessWidget {
  const _SocialSettingsMenuItem({
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

class _ConnectionChip extends StatelessWidget {
  const _ConnectionChip({required this.label, required this.ready});

  final String label;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    final color = ready ? const Color(0xFF198754) : const Color(0xFFF39C12);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.value),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ready ? Symbols.check_circle : Symbols.error_outline,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.value),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
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
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ],
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
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return AdminTableSearchField(
      controller: controller,
      hintText: hint,
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
  const _TextOnlyButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.deepOcean,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.value),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0),
      ),
    );
  }
}

class _DangerTextButton extends StatelessWidget {
  const _DangerTextButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.actionRed,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.value),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0),
      ),
    );
  }
}

class _SocialSettingsFooter extends StatelessWidget {
  const _SocialSettingsFooter({
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
    final start = totalCount == 0 ? 0 : page * pageSize + 1;
    final end = math.min((page + 1) * pageSize, totalCount);
    final maxPage = totalCount <= 0 ? 0 : ((totalCount - 1) / pageSize).floor();
    return Row(
      children: [
        Expanded(
          child: Text(
            context.t(
              'social.settings.footer',
              values: {'start': start, 'end': end, 'total': totalCount},
            ),
            style: const TextStyle(
              color: AppColors.inkSoft,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ),
        _PaginationButton(
          label: '<<',
          enabled: page > 0,
          onTap: () => onPageChanged(0),
        ),
        const SizedBox(width: 8),
        _PaginationButton(
          label: '<',
          enabled: page > 0,
          onTap: () => onPageChanged(page - 1),
        ),
        const SizedBox(width: 8),
        AdminTablePageButton(label: '${page + 1}', selected: true),
        const SizedBox(width: 8),
        _PaginationButton(
          label: '>',
          enabled: page < maxPage,
          onTap: () => onPageChanged(page + 1),
        ),
        const SizedBox(width: 8),
        _PaginationButton(
          label: '>>',
          enabled: page < maxPage,
          onTap: () => onPageChanged(maxPage),
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

class _SocialSettingsEmptyState extends StatelessWidget {
  const _SocialSettingsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        context.t('social.settings.empty'),
        style: const TextStyle(
          color: AppColors.inkSoft,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
