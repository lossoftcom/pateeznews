import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/widgets/admin_table_chrome.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/localization/admin_date_formatter.dart';
import '../../../core/localization/admin_language_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
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
    final title = account.displayName.trim().isNotEmpty
        ? account.displayName.trim()
        : account.accountName.trim();
    final handle = account.username.trim().isNotEmpty
        ? '@${account.username.replaceFirst(RegExp(r'^@'), '')}'
        : account.channelName;
    return _SocialAccountRowData(
      platform: info,
      accountName: title.isEmpty ? account.accountName : title,
      handle: handle,
      permissionSummary: account.channelName.trim().isEmpty
          ? account.platformType
          : account.channelName.trim(),
      connectionLabel: 'Bundle.social',
      statusKey: account.status == 'connected'
          ? 'social.accounts.status.ready'
          : 'social.accounts.status.review',
      statusColor: account.status == 'connected'
          ? const Color(0xFF198754)
          : AppColors.warmHorizon,
      connectedAt: account.connectedAt == null
          ? ''
          : formatAdminFullDate(context, account.connectedAt!),
    );
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error.toString()),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openLoginDialog() async {
    final platforms = await showDialog<Set<SocialPlatform>>(
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
            initiallySelected: socialPlatforms
                .map((info) => info.platform)
                .toSet(),
          ),
        );
      },
    );
    if (platforms == null || platforms.isEmpty || !mounted) return;
    final openFailedMessage = context.t('social.accounts.openFailed');
    try {
      final url = await widget.repository.createPortalLink(
        widget.session,
        platforms: platforms,
      );
      final launched = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!launched) throw Exception(openFailedMessage);
    } catch (error) {
      _showError(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 640 ? 16.0 : 28.0;
        final compact = constraints.maxWidth < 920;
        final filteredRows = _filteredRows;
        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SocialAccountsTitle(),
            const SizedBox(height: 18),
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
            child: SizedBox(height: 780, child: content),
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
  });

  static const _minTableWidth = 1220.0;

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

  @override
  Widget build(BuildContext context) {
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
  const _SocialAccountsTableRow({required this.row});

  final _SocialAccountRowData row;

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
            child: _SoftBadge(
              label: row.connectionLabel,
              color: row.platform.color,
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
              child: Text(
                '...',
                style: TextStyle(
                  color: AppColors.iconMuted.withValues(alpha: 0.9),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
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

class _SocialAccountLoginDialog extends StatefulWidget {
  const _SocialAccountLoginDialog({required this.initiallySelected});

  final Set<SocialPlatform> initiallySelected;

  @override
  State<_SocialAccountLoginDialog> createState() =>
      _SocialAccountLoginDialogState();
}

class _SocialAccountLoginDialogState extends State<_SocialAccountLoginDialog> {
  late var _selected = Set<SocialPlatform>.of(widget.initiallySelected);

  void _toggle(SocialPlatform platform) {
    setState(() {
      if (_selected.contains(platform)) {
        _selected = {..._selected}..remove(platform);
      } else {
        _selected = {..._selected, platform};
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
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
                Expanded(
                  child: Text(
                    context.t('social.accounts.dialog.title'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.deepOcean,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.close,
                    size: 18,
                    color: AppColors.deepOcean,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              context.t('social.accounts.dialog.subtitle'),
              style: const TextStyle(
                color: AppColors.inkSoft,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppColors.line),
                borderRadius: BorderRadius.circular(AppRadius.value),
              ),
              padding: const EdgeInsets.all(16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final itemWidth = (constraints.maxWidth - 12) / 2;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      for (final info in socialPlatforms)
                        SizedBox(
                          width: itemWidth,
                          child: _SocialLoginButton(
                            info: info,
                            selected: _selected.contains(info.platform),
                            onPressed: () => _toggle(info.platform),
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
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.t('social.publish.cancel')),
                ),
                const SizedBox(width: 10),
                _PrimaryActionButton(
                  label: context.t('social.accounts.connectSelected'),
                  onPressed: _selected.isEmpty
                      ? null
                      : () => Navigator.pop(context, _selected),
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
    required this.selected,
    required this.onPressed,
  });

  final SocialPlatformInfo info;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final platform = _platformDisplayName(info);
    return SizedBox(
      height: 46,
      child: TextButton(
        onPressed: onPressed,
        style:
            TextButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.deepOcean,
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
              side: WidgetStatePropertyAll(
                BorderSide(
                  color: selected
                      ? info.color
                      : info.color.withValues(alpha: 0.24),
                ),
              ),
              mouseCursor: const WidgetStatePropertyAll(
                SystemMouseCursors.click,
              ),
            ),
        child: Row(
          children: [
            SocialBrandLogo(info: info, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.t(
                  'social.accounts.dialog.loginWith',
                  values: {'platform': platform},
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? info.color : AppColors.iconMuted,
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
            const Icon(Icons.refresh, size: 17, color: AppColors.deepOcean),
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
                icon: const Icon(Icons.chevron_left),
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
                icon: const Icon(Icons.chevron_right),
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
    required this.platform,
    required this.accountName,
    required this.handle,
    required this.permissionSummary,
    required this.connectionLabel,
    required this.statusKey,
    required this.statusColor,
    required this.connectedAt,
  });

  final SocialPlatformInfo platform;
  final String accountName;
  final String handle;
  final String permissionSummary;
  final String connectionLabel;
  final String statusKey;
  final Color statusColor;
  final String connectedAt;
}

String _platformDisplayName(SocialPlatformInfo info) => switch (info.platform) {
  SocialPlatform.twitter => 'X / Twitter',
  SocialPlatform.googleBusiness => 'Google Business Profile',
  _ => info.label,
};
