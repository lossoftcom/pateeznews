import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';
import 'package:pateeznews_admin/shared/widgets/admin_table_chrome.dart';
import 'package:pateeznews_admin/shared/widgets/admin_toast.dart';
import 'package:pateeznews_admin/shared/widgets/app_confirmation_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/localization/admin_date_formatter.dart';
import '../../../core/localization/admin_language_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/widgets/admin_mobile_list.dart';
import '../../../shared/widgets/symbol_icon.dart';
import '../../auth/data/admin_auth_models.dart';
import '../data/admin_social_repository.dart';
import 'social_platform_data.dart';
import 'widgets/social_brand_logo.dart';

class SocialAccountsScreen extends StatefulWidget {
  const SocialAccountsScreen({
    super.key,
    required this.session,
    required this.repository,
  });

  final AdminSession session;
  final AdminSocialRepository repository;

  @override
  State<SocialAccountsScreen> createState() => _SocialAccountsScreenState();
}

class _SocialAccountsScreenState extends State<SocialAccountsScreen> {
  final _searchController = TextEditingController();
  var _query = '';
  var _loading = true;
  var _page = 1;
  var _pageSize = 25;
  String? _errorMessage;
  var _rows = <_SocialAccountRowData>[];

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

  List<_SocialAccountRowData> get _filteredRows {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _rows;
    return _rows.where((row) {
      final haystack = [
        _platformDisplayName(row.platform),
        row.accountName,
        row.handle,
        row.permissionSummary,
        row.statusKey,
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  List<_SocialAccountRowData> _pagedRows(List<_SocialAccountRowData> rows) {
    final start = (_page - 1) * _pageSize;
    if (start >= rows.length) return rows.take(_pageSize).toList();
    final end = start + _pageSize > rows.length
        ? rows.length
        : start + _pageSize;
    return rows.sublist(start, end);
  }

  Future<void> _loadAccounts() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final accounts = await widget.repository.fetchConnectedAccounts(
        widget.session,
      );
      if (!mounted) return;
      setState(() {
        _rows = accounts.map(_rowFromAccount).toList(growable: false);
        _page = 1;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = error.toString();
      });
    }
  }

  _SocialAccountRowData _rowFromAccount(AdminSocialConnectedAccount account) {
    final info = platformInfoFor(account.platform);
    final status = account.status.trim().toLowerCase();
    final title = account.displayName.trim().isNotEmpty
        ? account.displayName.trim()
        : account.accountName.trim();
    final handle = account.username.trim().isNotEmpty
        ? '@${account.username.replaceFirst(RegExp(r'^@'), '')}'
        : account.channelName;
    final statusKey = switch (status) {
      'connected' => 'social.accounts.status.ready',
      'disabled' => 'social.accounts.status.passive',
      _ => 'social.accounts.status.review',
    };
    final statusColor = switch (status) {
      'connected' => const Color(0xFF198754),
      'disabled' => AppColors.support,
      _ => AppColors.warmHorizon,
    };
    return _SocialAccountRowData(
      account: account,
      platform: info,
      accountName: title.isEmpty ? account.accountName : title,
      handle: handle,
      permissionSummary: account.channelName.trim().isEmpty
          ? account.platformType
          : account.channelName.trim(),
      connectionLabel: 'Bundle.social',
      status: status,
      statusKey: statusKey,
      statusColor: statusColor,
      connectedAt: account.connectedAt == null
          ? ''
          : formatAdminFullDate(context, account.connectedAt!),
    );
  }

  void _showError(Object error) {
    if (!mounted) return;
    AdminToast.show(
      context,
      message: error.toString(),
      tone: AdminToastTone.error,
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    AdminToast.show(context, message: message, tone: AdminToastTone.success);
  }

  Future<void> _editAccount(_SocialAccountRowData row) async {
    final values = await showDialog<Map<String, Object?>>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.34),
      builder: (context) => _SocialAccountEditDialog(row: row),
    );
    if (values == null || !mounted) return;

    try {
      await widget.repository.updateConnectedAccount(
        widget.session,
        row.account,
        values,
      );
      if (!mounted) return;
      _showSuccess(context.t('social.accounts.toast.updated'));
      await _loadAccounts();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _toggleAccountActive(_SocialAccountRowData row) async {
    final active = row.active;
    try {
      await widget.repository.updateConnectedAccount(
        widget.session,
        row.account,
        {'status': active ? 'disabled' : 'connected'},
      );
      if (!mounted) return;
      _showSuccess(
        context.t(
          active
              ? 'social.accounts.toast.deactivated'
              : 'social.accounts.toast.activated',
        ),
      );
      await _loadAccounts();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _reconnectAccount(_SocialAccountRowData row) async {
    final openFailedMessage = context.t('social.accounts.openFailed');
    try {
      final url = await widget.repository.createPortalLink(
        widget.session,
        socialAccountId: row.account.socialAccountId,
        platforms: {row.platform.platform},
      );
      final launched = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!launched) throw Exception(openFailedMessage);
      if (!mounted) return;
      _showSuccess(context.t('social.accounts.toast.reconnectOpened'));
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _deleteAccount(_SocialAccountRowData row) async {
    final confirmed = await showAppConfirmationDialog(
      context,
      title: 'social.accounts.deleteTitle',
      message: 'social.accounts.deleteMessage',
      confirmLabel: 'common.delete',
      danger: true,
    );
    if (!confirmed || !mounted) return;

    try {
      await widget.repository.deleteConnectedAccount(
        widget.session,
        row.account,
      );
      if (!mounted) return;
      _showSuccess(context.t('social.accounts.toast.deleted'));
      await _loadAccounts();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _openLoginDialog() async {
    final openFailedMessage = context.t('social.accounts.openFailed');
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 32,
          ),
          backgroundColor: Colors.transparent,
          child: _SocialAccountLoginDialog(
            onConnect: (platform) async {
              try {
                final url = await widget.repository.createPortalLink(
                  widget.session,
                  platforms: {platform},
                );
                final launched = await launchUrl(
                  Uri.parse(url),
                  mode: LaunchMode.externalApplication,
                );
                if (!launched) throw Exception(openFailedMessage);
              } catch (error) {
                _showError(error);
                rethrow;
              }
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 640 ? 16.0 : 28.0;
        final mobile = constraints.maxWidth < AdminMobile.breakpoint;
        final compact = constraints.maxWidth < 920;
        final topPadding = mobile ? 18.0 : 28.0;
        final filteredRows = _filteredRows;
        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SocialAccountsTitle(),
            SizedBox(height: mobile ? 12 : 18),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.deepOcean,
                      ),
                    )
                  : _errorMessage != null
                  ? _SocialAccountsLoadError(
                      message: _errorMessage!,
                      onRetry: _loadAccounts,
                    )
                  : _SocialAccountsTableCard(
                      rows: _pagedRows(filteredRows),
                      page: _page,
                      pageSize: _pageSize,
                      totalCount: filteredRows.length,
                      searchController: _searchController,
                      onPageSizeChanged: (value) {
                        if (value == null || value == _pageSize) return;
                        setState(() {
                          _pageSize = value;
                          _page = 1;
                        });
                      },
                      onPageChanged: (value) => setState(() => _page = value),
                      onSearchChanged: (value) {
                        setState(() {
                          _query = value;
                          _page = 1;
                        });
                      },
                      onCreate: _openLoginDialog,
                      onRefresh: _loadAccounts,
                      onEdit: (row) => unawaited(_editAccount(row)),
                      onToggleActive: (row) =>
                          unawaited(_toggleAccountActive(row)),
                      onReconnect: (row) => unawaited(_reconnectAccount(row)),
                      onDelete: (row) => unawaited(_deleteAccount(row)),
                    ),
            ),
          ],
        );

        if (compact) {
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              topPadding,
              horizontalPadding,
              28,
            ),
            child: SizedBox(height: 780, child: content),
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

class _SocialAccountsTitle extends StatelessWidget {
  const _SocialAccountsTitle();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.t('social.accounts.title'),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: AppColors.deepOcean,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          context.t('social.accounts.description'),
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

class _SocialAccountsLoadError extends StatelessWidget {
  const _SocialAccountsLoadError({
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
            child: Text(context.t('social.accounts.refresh')),
          ),
        ],
      ),
    );
  }
}

class _SocialAccountsTableCard extends StatelessWidget {
  const _SocialAccountsTableCard({
    required this.rows,
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.searchController,
    required this.onPageSizeChanged,
    required this.onPageChanged,
    required this.onSearchChanged,
    required this.onCreate,
    required this.onRefresh,
    required this.onEdit,
    required this.onToggleActive,
    required this.onReconnect,
    required this.onDelete,
  });

  static const _minTableWidth = 1120.0;

  final List<_SocialAccountRowData> rows;
  final int page;
  final int pageSize;
  final int totalCount;
  final TextEditingController searchController;
  final ValueChanged<int?> onPageSizeChanged;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onCreate;
  final VoidCallback onRefresh;
  final ValueChanged<_SocialAccountRowData> onEdit;
  final ValueChanged<_SocialAccountRowData> onToggleActive;
  final ValueChanged<_SocialAccountRowData> onReconnect;
  final ValueChanged<_SocialAccountRowData> onDelete;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < AdminMobile.breakpoint) {
          return _SocialAccountsMobileView(
            rows: rows,
            page: page,
            pageSize: pageSize,
            totalCount: totalCount,
            searchController: searchController,
            onPageChanged: onPageChanged,
            onSearchChanged: onSearchChanged,
            onCreate: onCreate,
            onRefresh: onRefresh,
            onEdit: onEdit,
            onToggleActive: onToggleActive,
            onReconnect: onReconnect,
            onDelete: onDelete,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SocialAccountsToolbar(
              pageSize: pageSize,
              searchController: searchController,
              onPageSizeChanged: onPageSizeChanged,
              onSearchChanged: onSearchChanged,
              onCreate: onCreate,
              onRefresh: onRefresh,
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
                    final width = constraints.maxWidth < _minTableWidth
                        ? _minTableWidth
                        : constraints.maxWidth;
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: width,
                        height: constraints.hasBoundedHeight
                            ? constraints.maxHeight
                            : null,
                        child: Column(
                          children: [
                            const _SocialAccountsTableHeader(),
                            Expanded(
                              child: rows.isEmpty
                                  ? const _SocialAccountsEmptyState()
                                  : ListView.builder(
                                      itemCount: rows.length,
                                      itemBuilder: (context, index) {
                                        return _SocialAccountsTableRow(
                                          row: rows[index],
                                          onEdit: onEdit,
                                          onToggleActive: onToggleActive,
                                          onReconnect: onReconnect,
                                          onDelete: onDelete,
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
            _SocialAccountsFooter(
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

class _SocialAccountsMobileView extends StatelessWidget {
  const _SocialAccountsMobileView({
    required this.rows,
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.searchController,
    required this.onPageChanged,
    required this.onSearchChanged,
    required this.onCreate,
    required this.onRefresh,
    required this.onEdit,
    required this.onToggleActive,
    required this.onReconnect,
    required this.onDelete,
  });

  final List<_SocialAccountRowData> rows;
  final int page;
  final int pageSize;
  final int totalCount;
  final TextEditingController searchController;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onCreate;
  final VoidCallback onRefresh;
  final ValueChanged<_SocialAccountRowData> onEdit;
  final ValueChanged<_SocialAccountRowData> onToggleActive;
  final ValueChanged<_SocialAccountRowData> onReconnect;
  final ValueChanged<_SocialAccountRowData> onDelete;

  @override
  Widget build(BuildContext context) {
    final lastPage = totalCount == 0 ? 1 : ((totalCount - 1) ~/ pageSize) + 1;
    final from = totalCount == 0 ? 0 : ((page - 1) * pageSize) + 1;
    final to = totalCount == 0
        ? 0
        : (page * pageSize > totalCount ? totalCount : page * pageSize);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminMobileToolbar(
          controller: searchController,
          query: searchController.text,
          hintText: context.t('social.accounts.searchPlaceholder'),
          onSearchChanged: onSearchChanged,
          activeFilterCount: 0,
          onOpenFilters: () {},
          showFilters: false,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: AdminMobilePrimaryButton(
                icon: Symbols.add,
                label: context.t('social.accounts.addAccount'),
                fullWidth: true,
                onPressed: onCreate,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AdminMobileActionButton(
                label: context.t('social.accounts.refresh'),
                leading: const SymbolIcon(
                  Symbols.redo,
                  color: AppColors.deepOcean,
                  size: 18,
                ),
                fullWidth: true,
                onPressed: onRefresh,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Expanded(
          child: AdminMobileListView(
            loading: false,
            itemCount: rows.length,
            emptyLabel: context.t('social.accounts.empty'),
            itemBuilder: (context, index) {
              return _SocialAccountsMobileCard(
                row: rows[index],
                onEdit: onEdit,
                onToggleActive: onToggleActive,
                onReconnect: onReconnect,
                onDelete: onDelete,
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        AdminMobilePager(
          page: page,
          lastPage: lastPage,
          rangeText: context.t(
            'common.recordRange',
            values: {'from': from, 'to': to, 'total': totalCount},
          ),
          loading: false,
          onPageChanged: onPageChanged,
        ),
      ],
    );
  }
}

class _SocialAccountsMobileCard extends StatelessWidget {
  const _SocialAccountsMobileCard({
    required this.row,
    required this.onEdit,
    required this.onToggleActive,
    required this.onReconnect,
    required this.onDelete,
  });

  final _SocialAccountRowData row;
  final ValueChanged<_SocialAccountRowData> onEdit;
  final ValueChanged<_SocialAccountRowData> onToggleActive;
  final ValueChanged<_SocialAccountRowData> onReconnect;
  final ValueChanged<_SocialAccountRowData> onDelete;

  @override
  Widget build(BuildContext context) {
    final permission = row.permissionSummary.trim();
    final platformName = _platformDisplayName(row.platform);
    final meta = permission.isEmpty
        ? platformName
        : '$platformName • $permission';

    return AdminMobileCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SocialBrandLogo(info: row.platform, size: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.accountName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.deepOcean,
                      ),
                    ),
                    if (row.handle.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        row.handle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.support,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _SocialAccountRowMenu(
                row: row,
                onEdit: onEdit,
                onToggleActive: onToggleActive,
                onReconnect: onReconnect,
                onDelete: onDelete,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            meta,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.inkSoft,
            ),
          ),
          if (row.connectionLabel.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: AdminMobileChip(
                label: row.connectionLabel,
                color: row.platform.color,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Divider(height: 1, color: AppColors.softLine.withValues(alpha: 0.9)),
          const SizedBox(height: 10),
          Row(
            children: [
              AdminMobileStatusPill(
                label: context.t(row.statusKey),
                color: row.statusColor,
              ),
              const Spacer(),
              if (row.connectedAt.trim().isNotEmpty)
                Text(
                  row.connectedAt,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.support,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
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

class _SocialAccountsToolbar extends StatelessWidget {
  const _SocialAccountsToolbar({
    required this.pageSize,
    required this.searchController,
    required this.onPageSizeChanged,
    required this.onSearchChanged,
    required this.onCreate,
    required this.onRefresh,
  });

  final int pageSize;
  final TextEditingController searchController;
  final ValueChanged<int?> onPageSizeChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onCreate;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _PageSizeSelect(value: pageSize, onChanged: onPageSizeChanged),
        const Spacer(),
        SizedBox(
          width: 280,
          child: AdminTableSearchField(
            controller: searchController,
            hintText: context.t('social.accounts.searchPlaceholder'),
            onChanged: onSearchChanged,
          ),
        ),
        const SizedBox(width: 12),
        _SecondaryActionButton(
          label: context.t('social.accounts.refresh'),
          onPressed: onRefresh,
        ),
        const SizedBox(width: 12),
        _PrimaryActionButton(
          label: context.t('social.accounts.addAccount'),
          onPressed: onCreate,
        ),
      ],
    );
  }
}

class _SocialAccountsTableHeader extends StatelessWidget {
  const _SocialAccountsTableHeader();

  static const _selectWidth = 42.0;
  static const _platformWidth = 210.0;
  static const _permissionWidth = 220.0;
  static const _connectionWidth = 148.0;
  static const _statusWidth = 172.0;
  static const _dateWidth = 148.0;
  static const _actionsWidth = 76.0;

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
          const SizedBox(
            width: _selectWidth,
            child: Center(child: _ListCheckbox()),
          ),
          Expanded(
            child: _HeaderText(context.t('social.accounts.column.account')),
          ),
          SizedBox(
            width: _platformWidth,
            child: _HeaderText(context.t('social.accounts.column.platform')),
          ),
          SizedBox(
            width: _permissionWidth,
            child: _HeaderText(context.t('social.accounts.column.permission')),
          ),
          SizedBox(
            width: _connectionWidth,
            child: _HeaderText(context.t('social.accounts.column.connection')),
          ),
          SizedBox(
            width: _statusWidth,
            child: _HeaderText(context.t('social.accounts.column.status')),
          ),
          SizedBox(
            width: _dateWidth,
            child: _HeaderText(context.t('social.accounts.column.date')),
          ),
          SizedBox(
            width: _actionsWidth,
            child: Center(
              child: Text(
                context.t('social.accounts.column.actions'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.inkSoft,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderText extends StatelessWidget {
  const _HeaderText(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.inkSoft,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 4),
        const SymbolIcon(
          Symbols.keyboard_arrow_down,
          color: AppColors.support,
          size: 14,
        ),
      ],
    );
  }
}

class _SocialAccountsTableRow extends StatelessWidget {
  const _SocialAccountsTableRow({
    required this.row,
    required this.onEdit,
    required this.onToggleActive,
    required this.onReconnect,
    required this.onDelete,
  });

  final _SocialAccountRowData row;
  final ValueChanged<_SocialAccountRowData> onEdit;
  final ValueChanged<_SocialAccountRowData> onToggleActive;
  final ValueChanged<_SocialAccountRowData> onReconnect;
  final ValueChanged<_SocialAccountRowData> onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 92),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AppColors.softLine.withValues(alpha: 0.86)),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: _SocialAccountsTableHeader._selectWidth,
            child: Center(child: _ListCheckbox()),
          ),
          Expanded(
            child: Row(
              children: [
                SocialBrandLogo(info: row.platform, size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.accountName,
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
                        row.handle,
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
          SizedBox(
            width: _SocialAccountsTableHeader._platformWidth,
            child: Text(
              _platformDisplayName(row.platform),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.deepOcean,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 0,
              ),
            ),
          ),
          SizedBox(
            width: _SocialAccountsTableHeader._permissionWidth,
            child: Text(
              row.permissionSummary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.inkSoft,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 0,
              ),
            ),
          ),
          SizedBox(
            width: _SocialAccountsTableHeader._connectionWidth,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _SoftBadge(
                label: row.connectionLabel,
                color: row.platform.color,
              ),
            ),
          ),
          SizedBox(
            width: _SocialAccountsTableHeader._statusWidth,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _StatusBadge(
                label: context.t(row.statusKey),
                color: row.statusColor,
              ),
            ),
          ),
          SizedBox(
            width: _SocialAccountsTableHeader._dateWidth,
            child: Text(
              row.connectedAt,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.deepOcean,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 0,
              ),
            ),
          ),
          SizedBox(
            width: _SocialAccountsTableHeader._actionsWidth,
            child: Center(
              child: _SocialAccountRowMenu(
                row: row,
                onEdit: onEdit,
                onToggleActive: onToggleActive,
                onReconnect: onReconnect,
                onDelete: onDelete,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialAccountRowMenu extends StatefulWidget {
  const _SocialAccountRowMenu({
    required this.row,
    required this.onEdit,
    required this.onToggleActive,
    required this.onReconnect,
    required this.onDelete,
  });

  final _SocialAccountRowData row;
  final ValueChanged<_SocialAccountRowData> onEdit;
  final ValueChanged<_SocialAccountRowData> onToggleActive;
  final ValueChanged<_SocialAccountRowData> onReconnect;
  final ValueChanged<_SocialAccountRowData> onDelete;

  @override
  State<_SocialAccountRowMenu> createState() => _SocialAccountRowMenuState();
}

class _SocialAccountRowMenuState extends State<_SocialAccountRowMenu> {
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
              child: _SocialAccountMenuCard(
                row: widget.row,
                onEdit: () => _runAndClose(() => widget.onEdit(widget.row)),
                onToggleActive: () =>
                    _runAndClose(() => widget.onToggleActive(widget.row)),
                onReconnect: () =>
                    _runAndClose(() => widget.onReconnect(widget.row)),
                onDelete: () => _runAndClose(() => widget.onDelete(widget.row)),
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
        message: context.t('social.accounts.actionsTooltip'),
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

class _SocialAccountMenuCard extends StatelessWidget {
  const _SocialAccountMenuCard({
    required this.row,
    required this.onEdit,
    required this.onToggleActive,
    required this.onReconnect,
    required this.onDelete,
  });

  final _SocialAccountRowData row;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback onReconnect;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 230,
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
            _SocialAccountMenuItem(
              icon: Symbols.edit_square,
              label: 'social.accounts.action.edit',
              onTap: onEdit,
            ),
            _SocialAccountMenuItem(
              icon: row.active ? Symbols.visibility_off : Symbols.check,
              label: row.active
                  ? 'social.accounts.action.deactivate'
                  : 'social.accounts.action.activate',
              onTap: onToggleActive,
            ),
            _SocialAccountMenuItem(
              icon: Symbols.sync,
              label: 'social.accounts.action.reconnect',
              onTap: onReconnect,
            ),
            _SocialAccountMenuItem(
              icon: Symbols.delete,
              label: 'social.accounts.action.delete',
              onTap: onDelete,
              danger: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _SocialAccountMenuItem extends StatelessWidget {
  const _SocialAccountMenuItem({
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

const _bundlePortalSupportedTypes = <String>{
  'TIKTOK',
  'YOUTUBE',
  'INSTAGRAM',
  'FACEBOOK',
  'TWITTER',
  'THREADS',
  'LINKEDIN',
  'PINTEREST',
  'REDDIT',
  'MASTODON',
  'DISCORD',
  'SLACK',
  'BLUESKY',
  'GOOGLE_BUSINESS',
};

class _SocialAccountEditDialog extends StatefulWidget {
  const _SocialAccountEditDialog({required this.row});

  final _SocialAccountRowData row;

  @override
  State<_SocialAccountEditDialog> createState() =>
      _SocialAccountEditDialogState();
}

class _SocialAccountEditDialogState extends State<_SocialAccountEditDialog> {
  late final TextEditingController _displayNameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _channelNameController;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController(
      text: widget.row.account.displayName.trim().isEmpty
          ? widget.row.accountName
          : widget.row.account.displayName.trim(),
    );
    _usernameController = TextEditingController(
      text: widget.row.account.username.replaceFirst(RegExp(r'^@'), ''),
    );
    _channelNameController = TextEditingController(
      text: widget.row.account.channelName.trim(),
    );
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _usernameController.dispose();
    _channelNameController.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop({
      'display_name': _displayNameController.text.trim(),
      'username': _usernameController.text
          .replaceFirst(RegExp(r'^@+'), '')
          .trim(),
      'channel_name': _channelNameController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.value),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.t('social.accounts.editTitle'),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppColors.deepOcean,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => Navigator.of(context).pop(),
                        child: const Padding(
                          padding: EdgeInsets.all(3),
                          child: SymbolIcon(
                            Symbols.close,
                            color: AppColors.deepOcean,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _SocialAccountEditField(
                  controller: _displayNameController,
                  label: context.t('social.accounts.field.displayName'),
                ),
                const SizedBox(height: 12),
                _SocialAccountEditField(
                  controller: _usernameController,
                  label: context.t('social.accounts.field.username'),
                  prefixText: '@',
                ),
                const SizedBox(height: 12),
                _SocialAccountEditField(
                  controller: _channelNameController,
                  label: context.t('social.accounts.field.channelName'),
                ),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style:
                          TextButton.styleFrom(
                            foregroundColor: AppColors.deepOcean,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            textStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0,
                            ),
                          ).copyWith(
                            mouseCursor: const WidgetStatePropertyAll(
                              SystemMouseCursors.click,
                            ),
                          ),
                      child: Text(context.t('common.cancel')),
                    ),
                    const SizedBox(width: 14),
                    SizedBox(
                      height: 36,
                      child: TextButton(
                        onPressed: _submit,
                        style:
                            TextButton.styleFrom(
                              backgroundColor: AppColors.deepOcean,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.value,
                                ),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0,
                              ),
                            ).copyWith(
                              mouseCursor: const WidgetStatePropertyAll(
                                SystemMouseCursors.click,
                              ),
                            ),
                        child: Text(context.t('common.save')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SocialAccountEditField extends StatelessWidget {
  const _SocialAccountEditField({
    required this.controller,
    required this.label,
    this.prefixText,
  });

  final TextEditingController controller;
  final String label;
  final String? prefixText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      cursorColor: AppColors.deepOcean,
      style: const TextStyle(
        color: AppColors.deepOcean,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      decoration: InputDecoration(
        labelText: label,
        prefixText: prefixText,
        filled: true,
        fillColor: AppColors.surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.value),
          borderSide: const BorderSide(color: AppColors.line),
        ),
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

class _SocialAccountLoginDialog extends StatefulWidget {
  const _SocialAccountLoginDialog({required this.onConnect});

  final Future<void> Function(SocialPlatform platform) onConnect;

  @override
  State<_SocialAccountLoginDialog> createState() =>
      _SocialAccountLoginDialogState();
}

class _SocialAccountLoginDialogState extends State<_SocialAccountLoginDialog> {
  SocialPlatform? _connectingPlatform;

  Future<void> _connect(SocialPlatform platform) async {
    if (_connectingPlatform != null) return;
    setState(() => _connectingPlatform = platform);
    try {
      await widget.onConnect(platform);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _connectingPlatform = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.value),
        ),
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.actionRed.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppRadius.value),
                  ),
                  child: const SymbolIcon(
                    Symbols.hub_outlined,
                    color: AppColors.actionRed,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.t('social.accounts.dialog.title'),
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: AppColors.deepOcean,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0,
                            ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        context.t('social.accounts.dialog.subtitle'),
                        style: const TextStyle(
                          color: AppColors.inkSoft,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  height: 26,
                  padding: const EdgeInsets.symmetric(horizontal: 9),
                  decoration: BoxDecoration(
                    color: const Color(0xFF198754).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppRadius.value),
                  ),
                  child: Center(
                    child: Text(
                      context.t('social.accounts.status.ready'),
                      style: const TextStyle(
                        color: Color(0xFF198754),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => Navigator.pop(context),
                  mouseCursor: SystemMouseCursors.click,
                  icon: const Icon(
                    Symbols.close,
                    size: 18,
                    color: AppColors.deepOcean,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.line),
                borderRadius: BorderRadius.circular(AppRadius.value),
              ),
              padding: const EdgeInsets.all(10),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final itemWidth = constraints.maxWidth < 560
                      ? constraints.maxWidth
                      : (constraints.maxWidth - 10) / 2;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      for (final info in socialPlatforms)
                        SizedBox(
                          width: itemWidth,
                          child: _SocialLoginButton(
                            info: info,
                            enabled: _bundlePortalSupportedTypes.contains(
                              info.platform.bundleSocialType,
                            ),
                            connecting: _connectingPlatform == info.platform,
                            busy: _connectingPlatform != null,
                            onPressed: () => _connect(info.platform),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _connectingPlatform == null
                      ? () => Navigator.pop(context)
                      : null,
                  style:
                      TextButton.styleFrom(
                        foregroundColor: AppColors.deepOcean,
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
                  child: Text(context.t('social.publish.cancel')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SocialLoginButton extends StatelessWidget {
  const _SocialLoginButton({
    required this.info,
    required this.enabled,
    required this.connecting,
    required this.busy,
    required this.onPressed,
  });

  final SocialPlatformInfo info;
  final bool enabled;
  final bool connecting;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final platform = _platformDisplayName(info);
    final active = enabled && !busy;
    return SizedBox(
      height: 52,
      child: TextButton(
        onPressed: active ? onPressed : null,
        style:
            TextButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.deepOcean,
              disabledForegroundColor: AppColors.support,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.value),
              ),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ).copyWith(
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (!enabled) return AppColors.surface;
                if (connecting) return info.color.withValues(alpha: 0.06);
                if (states.contains(WidgetState.hovered)) {
                  return info.color.withValues(alpha: 0.04);
                }
                return Colors.white;
              }),
              side: WidgetStateProperty.resolveWith(
                (states) => BorderSide(
                  color: !enabled
                      ? AppColors.softLine
                      : states.contains(WidgetState.hovered) || connecting
                      ? info.color
                      : AppColors.line,
                ),
              ),
              mouseCursor: WidgetStatePropertyAll(
                active ? SystemMouseCursors.click : SystemMouseCursors.basic,
              ),
            ),
        child: Row(
          children: [
            Opacity(
              opacity: enabled ? 1 : 0.42,
              child: SocialBrandLogo(info: info, size: 30),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t(
                      'social.accounts.dialog.loginWith',
                      values: {'platform': platform},
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    enabled
                        ? context.t('social.settings.mode.bundle')
                        : context.t('social.accounts.dialog.unsupported'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: enabled ? AppColors.iconMuted : AppColors.support,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (connecting)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: info.color,
                ),
              )
            else
              Icon(
                enabled ? Symbols.open_in_new_rounded : Symbols.block_outlined,
                color: enabled ? info.color : AppColors.support,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

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
            const SymbolIcon(Symbols.add, color: Colors.white, size: 17),
            const SizedBox(width: 7),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _SecondaryActionButton extends StatelessWidget {
  const _SecondaryActionButton({required this.label, required this.onPressed});

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
              backgroundColor: Colors.white,
              foregroundColor: AppColors.deepOcean,
              padding: const EdgeInsets.symmetric(horizontal: 14),
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
              side: const WidgetStatePropertyAll(
                BorderSide(color: AppColors.line),
              ),
              mouseCursor: const WidgetStatePropertyAll(
                SystemMouseCursors.click,
              ),
            ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Symbols.refresh, size: 17, color: AppColors.deepOcean),
            const SizedBox(width: 7),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _ListCheckbox extends StatelessWidget {
  const _ListCheckbox();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppRadius.value),
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
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.value),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
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
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.softLine.withValues(alpha: 0.9)),
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
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialAccountsFooter extends StatelessWidget {
  const _SocialAccountsFooter({
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
    final rangeText = context.t(
      'common.recordRange',
      values: {'from': from, 'to': to, 'total': totalCount},
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 800;
        final compact = constraints.maxWidth < 640;
        final summary = Text(
          rangeText,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.inkSoft,
            fontWeight: FontWeight.w500,
            letterSpacing: 0,
          ),
        );
        final pager = _SocialAccountsPagination(
          page: page,
          lastPage: lastPage,
          onPageChanged: onPageChanged,
        );

        if (mobile) {
          final hasPrevious = page > 1;
          final hasNext = page < lastPage;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              IconButton(
                onPressed: hasPrevious ? () => onPageChanged(page - 1) : null,
                icon: const Icon(Symbols.chevron_left),
                constraints: const BoxConstraints.tightFor(
                  width: 32,
                  height: 32,
                ),
                padding: EdgeInsets.zero,
                splashRadius: 18,
                visualDensity: VisualDensity.compact,
              ),
              Expanded(
                child: Text(
                  rangeText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
              IconButton(
                onPressed: hasNext ? () => onPageChanged(page + 1) : null,
                icon: const Icon(Symbols.chevron_right),
                constraints: const BoxConstraints.tightFor(
                  width: 32,
                  height: 32,
                ),
                padding: EdgeInsets.zero,
                splashRadius: 18,
                visualDensity: VisualDensity.compact,
              ),
            ],
          );
        }

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(height: 1, color: AppColors.line),
              const SizedBox(height: 16),
              summary,
              const SizedBox(height: 14),
              pager,
            ],
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

class _SocialAccountsPagination extends StatelessWidget {
  const _SocialAccountsPagination({
    required this.page,
    required this.lastPage,
    required this.onPageChanged,
  });

  final int page;
  final int lastPage;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        _PageButton(
          label: '<<',
          enabled: page > 1,
          onPressed: () => onPageChanged(1),
        ),
        _PageButton(
          label: '<',
          enabled: page > 1,
          onPressed: () => onPageChanged(page - 1),
        ),
        _PageButton(label: page.toString(), selected: true),
        _PageButton(
          label: '>',
          enabled: page < lastPage,
          onPressed: () => onPageChanged(page + 1),
        ),
        _PageButton(
          label: '>>',
          enabled: page < lastPage,
          onPressed: () => onPageChanged(lastPage),
        ),
      ],
    );
  }
}

class _PageButton extends StatelessWidget {
  const _PageButton({
    required this.label,
    this.selected = false,
    this.enabled = true,
    this.onPressed,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onPressed : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.46,
          child: Container(
            width: 36,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppColors.deepOcean : Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.value),
              border: Border.all(
                color: selected
                    ? AppColors.deepOcean
                    : AppColors.line.withValues(alpha: 0.72),
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.support,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SocialAccountsEmptyState extends StatelessWidget {
  const _SocialAccountsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        context.t('social.accounts.empty'),
        style: const TextStyle(
          color: AppColors.inkSoft,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _SocialAccountRowData {
  const _SocialAccountRowData({
    required this.account,
    required this.platform,
    required this.accountName,
    required this.handle,
    required this.permissionSummary,
    required this.connectionLabel,
    required this.status,
    required this.statusKey,
    required this.statusColor,
    required this.connectedAt,
  });

  final AdminSocialConnectedAccount account;
  final SocialPlatformInfo platform;
  final String accountName;
  final String handle;
  final String permissionSummary;
  final String connectionLabel;
  final String status;
  final String statusKey;
  final Color statusColor;
  final String connectedAt;

  bool get active => status == 'connected';
}

String _platformDisplayName(SocialPlatformInfo info) => switch (info.platform) {
  SocialPlatform.twitter => 'X / Twitter',
  SocialPlatform.googleBusiness => 'Google Business Profile',
  _ => info.label,
};
