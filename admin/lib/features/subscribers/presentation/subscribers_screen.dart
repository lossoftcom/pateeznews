import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/localization/admin_date_formatter.dart';
import '../../../core/localization/admin_language_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/icons/symbols.dart';
import '../../../shared/widgets/app_confirmation_dialog.dart';
import '../../../shared/widgets/sortable_table_header.dart';
import '../../../shared/widgets/symbol_icon.dart';
import '../data/admin_subscribers_repository.dart';
import 'subscribers_models.dart';

class SubscribersScreen extends StatefulWidget {
  const SubscribersScreen({
    super.key,
    this.repository = const NeonAdminSubscribersRepository(),
  });

  final AdminSubscribersRepository repository;

  @override
  State<SubscribersScreen> createState() => _SubscribersScreenState();
}

class _SubscribersScreenState extends State<SubscribersScreen> {
  final _searchController = TextEditingController();
  final _selectedIds = <String>{};
  Timer? _searchDebounce;
  var _subscribers = const <AdminSubscriber>[];
  var _loading = true;
  var _totalCount = 0;
  String? _errorText;
  var _searchQuery = '';
  var _page = 1;
  var _pageSize = 25;
  var _sortState = const TableSortState(key: 'date', ascending: false);

  @override
  void initState() {
    super.initState();
    unawaited(_loadSubscribers());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _resetTableState() {
    _page = 1;
    _selectedIds.clear();
  }

  Future<void> _loadSubscribers() async {
    setState(() {
      _loading = true;
      _errorText = null;
    });

    try {
      final result = await widget.repository.fetchSubscribers(
        search: _searchQuery,
        page: _page,
        pageSize: _pageSize,
        sortKey: _sortState.key,
        sortAscending: _sortState.ascending,
      );
      if (!mounted) return;
      setState(() {
        _subscribers = result.subscribers;
        _totalCount = result.totalCount;
        _selectedIds.removeWhere(
          (id) => !_subscribers.any((subscriber) => subscriber.id == id),
        );
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = error.toString();
        _loading = false;
      });
    }
  }

  void _changePageSize(int? value) {
    if (value == null || value == _pageSize) return;
    setState(() {
      _pageSize = value;
      _resetTableState();
    });
    unawaited(_loadSubscribers());
  }

  void _changeSearch(String value) {
    setState(() {
      _searchQuery = value;
    });
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(_resetTableState);
      unawaited(_loadSubscribers());
    });
  }

  void _changeSort(String key) {
    setState(() {
      _sortState = _sortState.toggled(key);
      _resetTableState();
    });
    unawaited(_loadSubscribers());
  }

  void _changePage(int value) {
    if (value == _page) return;
    setState(() {
      _page = value;
      _selectedIds.clear();
    });
    unawaited(_loadSubscribers());
  }

  void _toggleSubscriber(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _toggleAllSubscribers() {
    final pageIds = _subscribers.map((subscriber) => subscriber.id).toSet();
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

  Future<void> _deleteSubscriber(AdminSubscriber subscriber) async {
    final confirmed = await showAppConfirmationDialog(
      context,
      title: context.t('subscribers.deleteTitle'),
      message: context.t('subscribers.deleteMessage'),
      confirmLabel: context.t('common.delete'),
      danger: true,
    );
    if (!confirmed || !mounted) return;
    await _runMutation(
      () => widget.repository.deleteSubscriber(subscriber.id),
      'subscribers.message.deleted',
    );
  }

  Future<void> _deleteSelectedSubscribers() async {
    if (_selectedIds.isEmpty) return;
    final confirmed = await showAppConfirmationDialog(
      context,
      title: context.t('subscribers.deleteSelectedTitle'),
      message: context.t(
        'subscribers.deleteSelectedMessage',
        values: {'count': _selectedIds.length},
      ),
      confirmLabel: context.t('common.delete'),
      danger: true,
    );
    if (!confirmed || !mounted) return;
    final ids = _selectedIds.toList(growable: false);
    await _runMutation(
      () => widget.repository.deleteSubscribers(ids),
      'subscribers.message.deletedSelected',
    );
  }

  Future<void> _showSubscriberDialog({
    AdminSubscriber? subscriber,
    bool updateMode = false,
  }) async {
    final result = await showDialog<SubscriberFormData>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.34),
      builder: (context) => _SubscriberDialogFrame(
        child: _SubscriberFormDialog(
          subscriber: subscriber,
          updateMode: updateMode,
        ),
      ),
    );
    if (result == null || !mounted) return;
    await _runMutation(
      () async {
        await widget.repository.saveSubscriber(
          id: subscriber?.id,
          data: result,
        );
      },
      subscriber == null
          ? 'subscribers.message.created'
          : 'subscribers.message.updated',
    );
  }

  Future<void> _runMutation(
    Future<void> Function() action,
    String successMessageKey,
  ) async {
    setState(() {
      _loading = true;
      _errorText = null;
    });
    try {
      await action();
      if (!mounted) return;
      _selectedIds.clear();
      await _loadSubscribers();
      if (!mounted) return;
      _showMessage(successMessageKey);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = error.toString();
        _loading = false;
      });
    }
  }

  void _showMessage(String messageKey) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(context.t(messageKey)),
        backgroundColor: AppColors.deepOcean,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 640 ? 16.0 : 28.0;
        final compact = constraints.maxWidth < 900;
        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SubscribersTitle(
              selectedCount: _selectedIds.length,
              onDeleteSelected: _deleteSelectedSubscribers,
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 22),
              _SubscribersErrorBanner(message: _errorText!),
            ],
            const SizedBox(height: 24),
            Expanded(
              child: _SubscribersTableCard(
                subscribers: _subscribers,
                loading: _loading,
                page: _page,
                pageSize: _pageSize,
                totalCount: _totalCount,
                searchController: _searchController,
                searchQuery: _searchQuery,
                selectedIds: _selectedIds,
                sortState: _sortState,
                onPageSizeChanged: _changePageSize,
                onSearchChanged: _changeSearch,
                onPageChanged: _changePage,
                onToggleSubscriber: _toggleSubscriber,
                onToggleAllSubscribers: _toggleAllSubscribers,
                onSort: _changeSort,
                onCreate: () => _showSubscriberDialog(),
                onEdit: (subscriber) =>
                    _showSubscriberDialog(subscriber: subscriber),
                onUpdate: (subscriber) => _showSubscriberDialog(
                  subscriber: subscriber,
                  updateMode: true,
                ),
                onDelete: _deleteSubscriber,
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
            child: SizedBox(height: 760, child: content),
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

class _SubscribersTitle extends StatelessWidget {
  const _SubscribersTitle({
    required this.selectedCount,
    required this.onDeleteSelected,
  });

  final int selectedCount;
  final VoidCallback onDeleteSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            context.t('subscribers.title'),
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
              'subscribers.selectedDelete',
              values: {'count': selectedCount},
            ),
            onTap: onDeleteSelected,
          ),
      ],
    );
  }
}

class _SubscribersErrorBanner extends StatelessWidget {
  const _SubscribersErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.actionRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.actionRed.withValues(alpha: 0.18)),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.actionRed,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _SubscribersTableCard extends StatelessWidget {
  const _SubscribersTableCard({
    required this.subscribers,
    required this.loading,
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.searchController,
    required this.searchQuery,
    required this.selectedIds,
    required this.sortState,
    required this.onPageSizeChanged,
    required this.onSearchChanged,
    required this.onPageChanged,
    required this.onToggleSubscriber,
    required this.onToggleAllSubscribers,
    required this.onSort,
    required this.onCreate,
    required this.onEdit,
    required this.onUpdate,
    required this.onDelete,
  });

  static const _minTableWidth = 1360.0;

  final List<AdminSubscriber> subscribers;
  final bool loading;
  final int page;
  final int pageSize;
  final int totalCount;
  final TextEditingController searchController;
  final String searchQuery;
  final Set<String> selectedIds;
  final TableSortState sortState;
  final ValueChanged<int?> onPageSizeChanged;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<String> onToggleSubscriber;
  final VoidCallback onToggleAllSubscribers;
  final ValueChanged<String> onSort;
  final VoidCallback onCreate;
  final ValueChanged<AdminSubscriber> onEdit;
  final ValueChanged<AdminSubscriber> onUpdate;
  final ValueChanged<AdminSubscriber> onDelete;

  @override
  Widget build(BuildContext context) {
    final pageIds = subscribers.map((subscriber) => subscriber.id).toSet();
    final allSelected = pageIds.isNotEmpty && selectedIds.containsAll(pageIds);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SubscribersToolbar(
          pageSize: pageSize,
          searchController: searchController,
          searchQuery: searchQuery,
          onPageSizeChanged: onPageSizeChanged,
          onSearchChanged: onSearchChanged,
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
                        _SubscriberTableHeader(
                          selected: allSelected,
                          sortState: sortState,
                          onToggle: onToggleAllSubscribers,
                          onSort: onSort,
                        ),
                        Expanded(
                          child: loading && subscribers.isEmpty
                              ? const _SubscriberLoadingState()
                              : subscribers.isEmpty
                              ? const _SubscriberEmptyState()
                              : ListView.builder(
                                  itemCount: subscribers.length,
                                  itemBuilder: (context, index) {
                                    final subscriber = subscribers[index];
                                    return _SubscriberTableRow(
                                      subscriber: subscriber,
                                      selected: selectedIds.contains(
                                        subscriber.id,
                                      ),
                                      onToggle: () =>
                                          onToggleSubscriber(subscriber.id),
                                      onEdit: () => onEdit(subscriber),
                                      onUpdate: () => onUpdate(subscriber),
                                      onDelete: () => onDelete(subscriber),
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
        _SubscribersFooter(
          loading: loading,
          page: page,
          pageSize: pageSize,
          totalCount: totalCount,
          onPageChanged: onPageChanged,
        ),
      ],
    );
  }
}

class _SubscribersToolbar extends StatelessWidget {
  const _SubscribersToolbar({
    required this.pageSize,
    required this.searchController,
    required this.searchQuery,
    required this.onPageSizeChanged,
    required this.onSearchChanged,
    required this.onCreate,
  });

  final int pageSize;
  final TextEditingController searchController;
  final String searchQuery;
  final ValueChanged<int?> onPageSizeChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        final actions = Wrap(
          spacing: 12,
          runSpacing: 10,
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: compact ? constraints.maxWidth : 300,
              child: _SearchField(
                controller: searchController,
                query: searchQuery,
                hint: context.t('subscribers.searchPlaceholder'),
                onChanged: onSearchChanged,
              ),
            ),
            _PrimaryActionButton(
              icon: Symbols.add,
              label: context.t('subscribers.addButton'),
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

class _SubscriberTableHeader extends StatelessWidget {
  const _SubscriberTableHeader({
    required this.selected,
    required this.sortState,
    required this.onToggle,
    required this.onSort,
  });

  static const _selectWidth = 42.0;
  static const _phoneWidth = 144.0;
  static const _ipWidth = 132.0;
  static const _cityWidth = 118.0;
  static const _statusWidth = 120.0;
  static const _actionsWidth = 76.0;
  static const _nameFlex = 3;
  static const _emailFlex = 3;
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
            flex: _nameFlex,
            child: _SubscriberSortableHeader(
              label: 'subscribers.column.fullName',
              sortKey: 'name',
              sortState: sortState,
              onSort: onSort,
            ),
          ),
          Expanded(
            flex: _emailFlex,
            child: _SubscriberSortableHeader(
              label: 'subscribers.column.email',
              sortKey: 'email',
              sortState: sortState,
              onSort: onSort,
            ),
          ),
          SizedBox(
            width: _phoneWidth,
            child: _SubscriberSortableHeader(
              label: 'subscribers.column.phone',
              sortKey: 'phone',
              sortState: sortState,
              onSort: onSort,
            ),
          ),
          SizedBox(
            width: _ipWidth,
            child: _SubscriberSortableHeader(
              label: 'subscribers.column.ipAddress',
              sortKey: 'ip',
              sortState: sortState,
              onSort: onSort,
            ),
          ),
          SizedBox(
            width: _cityWidth,
            child: _SubscriberSortableHeader(
              label: 'subscribers.column.city',
              sortKey: 'city',
              sortState: sortState,
              onSort: onSort,
            ),
          ),
          SizedBox(
            width: _statusWidth,
            child: _SubscriberSortableHeader(
              label: 'subscribers.column.status',
              sortKey: 'status',
              sortState: sortState,
              onSort: onSort,
            ),
          ),
          Expanded(
            flex: _dateFlex,
            child: _SubscriberSortableHeader(
              label: 'subscribers.column.createdAt',
              sortKey: 'date',
              sortState: sortState,
              onSort: onSort,
            ),
          ),
          SizedBox(
            width: _actionsWidth,
            child: Center(
              child: Text(
                context.t('subscribers.column.actions'),
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

class _SubscriberSortableHeader extends StatelessWidget {
  const _SubscriberSortableHeader({
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
    return SortableTableHeader(
      label: label,
      sortKey: sortKey,
      sortState: sortState,
      onSort: onSort,
    );
  }
}

class _SubscriberTableRow extends StatelessWidget {
  const _SubscriberTableRow({
    required this.subscriber,
    required this.selected,
    required this.onToggle,
    required this.onEdit,
    required this.onUpdate,
    required this.onDelete,
  });

  final AdminSubscriber subscriber;
  final bool selected;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onUpdate;
  final VoidCallback onDelete;

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
            width: _SubscriberTableHeader._selectWidth,
            child: Center(
              child: _ListCheckbox(selected: selected, onTap: onToggle),
            ),
          ),
          Expanded(
            flex: _SubscriberTableHeader._nameFlex,
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.softLine,
                    borderRadius: BorderRadius.circular(AppRadius.value),
                  ),
                  child: Text(
                    subscriber.initials,
                    style: const TextStyle(
                      color: AppColors.deepOcean,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    subscriber.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.deepOcean,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: _SubscriberTableHeader._emailFlex,
            child: _SubscriberTextCell(value: subscriber.email),
          ),
          SizedBox(
            width: _SubscriberTableHeader._phoneWidth,
            child: _SubscriberTextCell(value: subscriber.phone, primary: true),
          ),
          SizedBox(
            width: _SubscriberTableHeader._ipWidth,
            child: _SubscriberTextCell(value: subscriber.ipAddress),
          ),
          SizedBox(
            width: _SubscriberTableHeader._cityWidth,
            child: _SubscriberTextCell(value: subscriber.city),
          ),
          SizedBox(
            width: _SubscriberTableHeader._statusWidth,
            child: _StatusBadge(
              label: subscriber.active
                  ? context.t('common.active')
                  : context.t('common.passive'),
              color: subscriber.active
                  ? const Color(0xFF198754)
                  : AppColors.support,
              compact: true,
            ),
          ),
          Expanded(
            flex: _SubscriberTableHeader._dateFlex,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatAdminFullDate(context, subscriber.createdAt),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.deepOcean,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0,
                  ),
                ),
                Text(
                  formatAdminTime(subscriber.createdAt),
                  style: const TextStyle(
                    color: AppColors.iconMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: _SubscriberTableHeader._actionsWidth,
            child: Align(
              alignment: Alignment.center,
              child: _SubscriberRowMenu(
                onEdit: onEdit,
                onUpdate: onUpdate,
                onDelete: onDelete,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubscriberTextCell extends StatelessWidget {
  const _SubscriberTextCell({required this.value, this.primary = false});

  final String value;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: primary ? AppColors.deepOcean : AppColors.inkSoft,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
      ),
    );
  }
}

class _SubscriberDialogFrame extends StatelessWidget {
  const _SubscriberDialogFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 820, maxHeight: height - 48),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.value),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(child: child),
        ),
      ),
    );
  }
}

class _SubscriberFormDialog extends StatefulWidget {
  const _SubscriberFormDialog({this.subscriber, required this.updateMode});

  final AdminSubscriber? subscriber;
  final bool updateMode;

  @override
  State<_SubscriberFormDialog> createState() => _SubscriberFormDialogState();
}

class _SubscriberFormDialogState extends State<_SubscriberFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late bool _active;

  @override
  void initState() {
    super.initState();
    final subscriber = widget.subscriber;
    _nameController = TextEditingController(text: subscriber?.fullName ?? '');
    _emailController = TextEditingController(text: subscriber?.email ?? '');
    _phoneController = TextEditingController(text: subscriber?.phone ?? '');
    _active = subscriber?.active ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      SubscriberFormData(
        fullName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        active: _active,
      ),
    );
  }

  String _titleKey() {
    if (widget.subscriber == null) return 'subscribers.dialog.addTitle';
    if (widget.updateMode) return 'subscribers.dialog.updateTitle';
    return 'subscribers.dialog.editTitle';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 26, 28, 22),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DialogHeader(
              title: context.t(_titleKey()),
              subtitle: context.t('subscribers.dialog.subtitle'),
            ),
            const SizedBox(height: 22),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 680;
                final left = Column(
                  children: [
                    _DialogLineField(
                      controller: _nameController,
                      label: context.t('subscribers.dialog.fullName'),
                      hintText: context.t('subscribers.dialog.fullNameHint'),
                      icon: Symbols.person,
                      requiredField: true,
                      validator: _requiredValidator,
                    ),
                    const SizedBox(height: 22),
                    _DialogLineField(
                      controller: _phoneController,
                      label: context.t('subscribers.dialog.phone'),
                      hintText: context.t('subscribers.dialog.phoneHint'),
                      icon: Symbols.short_text,
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                );
                final right = Column(
                  children: [
                    _DialogLineField(
                      controller: _emailController,
                      label: context.t('subscribers.dialog.email'),
                      hintText: context.t('subscribers.dialog.emailHint'),
                      icon: Symbols.alternate_email,
                      keyboardType: TextInputType.emailAddress,
                      requiredField: true,
                      validator: _emailValidator,
                    ),
                    const SizedBox(height: 22),
                    _DialogStatusGroup(
                      active: _active,
                      onChanged: (value) => setState(() => _active = value),
                    ),
                  ],
                );

                if (compact) {
                  return Column(
                    children: [left, const SizedBox(height: 22), right],
                  );
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
            ),
            const SizedBox(height: 26),
            Align(
              alignment: Alignment.centerRight,
              child: _DialogFooter(
                primaryLabel: context.t('common.save'),
                onPrimaryPressed: _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _requiredValidator(String? value) {
    return (value ?? '').trim().isEmpty
        ? context.t('subscribers.dialog.required')
        : null;
  }

  String? _emailValidator(String? value) {
    final email = (value ?? '').trim();
    if (email.isEmpty) return context.t('subscribers.dialog.required');
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return context.t('subscribers.dialog.emailInvalid');
    }
    return null;
  }
}

class _DialogHeader extends StatelessWidget {
  const _DialogHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.deepOcean,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.inkSoft,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        const _DialogCloseButton(),
      ],
    );
  }
}

class _DialogCloseButton extends StatelessWidget {
  const _DialogCloseButton();

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).maybePop(),
        child: const Padding(
          padding: EdgeInsets.all(3),
          child: SymbolIcon(
            Symbols.close,
            color: AppColors.deepOcean,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _DialogLineField extends StatelessWidget {
  const _DialogLineField({
    required this.controller,
    required this.label,
    required this.hintText,
    required this.icon,
    this.requiredField = false,
    this.keyboardType,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final IconData icon;
  final bool requiredField;
  final TextInputType? keyboardType;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DialogSectionLabel(
          requiredField ? '$label *' : label,
          color: requiredField ? AppColors.actionRed : AppColors.inkSoft,
        ),
        const SizedBox(height: 12),
        Container(
          height: 38,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: requiredField
                    ? AppColors.actionRed.withValues(alpha: 0.84)
                    : AppColors.line,
              ),
            ),
          ),
          child: Row(
            children: [
              SymbolIcon(icon, color: AppColors.placeholder, size: 19),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: controller,
                  keyboardType: keyboardType,
                  validator: validator,
                  mouseCursor: SystemMouseCursors.text,
                  cursorColor: AppColors.support,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.deepOcean,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0,
                  ),
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.placeholder,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.only(bottom: 2),
                    filled: false,
                    hoverColor: Colors.transparent,
                    focusColor: Colors.transparent,
                    errorStyle: const TextStyle(
                      color: AppColors.actionRed,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0,
                      height: 0.8,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DialogSectionLabel extends StatelessWidget {
  const _DialogSectionLabel(this.label, {this.color = AppColors.inkSoft});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: color,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
    );
  }
}

class _DialogStatusGroup extends StatelessWidget {
  const _DialogStatusGroup({required this.active, required this.onChanged});

  final bool active;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DialogSectionLabel(context.t('common.status')),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 10,
          children: [
            _DialogRadioChoice(
              label: context.t('common.active'),
              selected: active,
              onTap: () => onChanged(true),
            ),
            _DialogRadioChoice(
              label: context.t('common.passive'),
              selected: !active,
              onTap: () => onChanged(false),
            ),
          ],
        ),
      ],
    );
  }
}

class _DialogRadioChoice extends StatelessWidget {
  const _DialogRadioChoice({
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
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppColors.deepOcean : AppColors.inkSoft,
                  width: 2,
                ),
              ),
              child: selected
                  ? Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.deepOcean,
                        shape: BoxShape.circle,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.deepOcean,
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

class _DialogFooter extends StatelessWidget {
  const _DialogFooter({
    required this.primaryLabel,
    required this.onPrimaryPressed,
  });

  final String primaryLabel;
  final VoidCallback onPrimaryPressed;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.end,
      children: [
        _TextOnlyButton(
          label: context.t('common.cancel'),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        _DialogPrimaryButton(label: primaryLabel, onPressed: onPrimaryPressed),
      ],
    );
  }
}

class _DialogPrimaryButton extends StatelessWidget {
  const _DialogPrimaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 114,
      height: 36,
      child: TextButton(
        onPressed: onPressed,
        style:
            TextButton.styleFrom(
              backgroundColor: AppColors.deepOcean,
              foregroundColor: Colors.white,
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.value),
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
        child: Text(label),
      ),
    );
  }
}

class _SubscriberRowMenu extends StatefulWidget {
  const _SubscriberRowMenu({
    required this.onEdit,
    required this.onUpdate,
    required this.onDelete,
  });

  final VoidCallback onEdit;
  final VoidCallback onUpdate;
  final VoidCallback onDelete;

  @override
  State<_SubscriberRowMenu> createState() => _SubscriberRowMenuState();
}

class _SubscriberRowMenuState extends State<_SubscriberRowMenu> {
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
            offset: const Offset(10, 8),
            child: _SubscriberMenuCard(
              onEdit: () => _tap(widget.onEdit),
              onUpdate: () => _tap(widget.onUpdate),
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
        message: context.t('subscribers.actions'),
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

class _SubscriberMenuCard extends StatelessWidget {
  const _SubscriberMenuCard({
    required this.onEdit,
    required this.onUpdate,
    required this.onDelete,
  });

  final VoidCallback onEdit;
  final VoidCallback onUpdate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 188,
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
            _MenuItem(
              icon: Symbols.edit_square,
              label: 'subscribers.action.edit',
              onTap: onEdit,
            ),
            _MenuItem(
              icon: Symbols.save,
              label: 'subscribers.action.update',
              onTap: onUpdate,
            ),
            _MenuItem(
              icon: Symbols.delete,
              label: 'subscribers.action.delete',
              color: AppColors.actionRed,
              onTap: onDelete,
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
  const _StatusBadge({
    required this.label,
    required this.color,
    this.compact = false,
  });

  final String label;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        height: compact ? 28 : 26,
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
        decoration: BoxDecoration(
          color: compact ? AppColors.surface : color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.value),
          border: compact
              ? Border.all(color: AppColors.softLine.withValues(alpha: 0.9))
              : null,
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
                  fontWeight: compact ? FontWeight.w600 : FontWeight.w800,
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

class _PageSizeSelect extends StatelessWidget {
  const _PageSizeSelect({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        width: 64,
        height: 38,
        padding: const EdgeInsets.only(left: 12, right: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.value),
          border: Border.all(color: AppColors.line.withValues(alpha: 0.72)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            value: value,
            isExpanded: true,
            borderRadius: BorderRadius.circular(AppRadius.value),
            dropdownColor: Colors.white,
            focusColor: Colors.transparent,
            mouseCursor: SystemMouseCursors.click,
            dropdownMenuItemMouseCursor: SystemMouseCursors.click,
            icon: const SymbolIcon(
              Symbols.keyboard_arrow_down,
              color: AppColors.iconMuted,
              size: 18,
            ),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.deepOcean,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
            items: const [10, 25, 50, 100]
                .map(
                  (item) =>
                      DropdownMenuItem<int>(value: item, child: Text('$item')),
                )
                .toList(),
            onChanged: onChanged,
          ),
        ),
      ),
    );
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
    return SizedBox(
      height: 38,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textAlignVertical: TextAlignVertical.center,
        style: const TextStyle(
          color: AppColors.deepOcean,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        decoration: InputDecoration(
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: 14, right: 8),
            child: SymbolIcon(
              Symbols.search,
              color: AppColors.iconMuted,
              size: 18,
            ),
          ),
          suffixIcon: query.isEmpty
              ? null
              : IconButton(
                  mouseCursor: SystemMouseCursors.click,
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                  icon: const SymbolIcon(
                    Symbols.close,
                    color: AppColors.iconMuted,
                    size: 16,
                  ),
                ),
          prefixIconConstraints: const BoxConstraints(minWidth: 40),
          hintText: hint,
          hintStyle: const TextStyle(
            color: AppColors.support,
            fontWeight: FontWeight.w500,
            letterSpacing: 0,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.value),
            borderSide: BorderSide(
              color: AppColors.line.withValues(alpha: 0.7),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.value),
            borderSide: const BorderSide(color: AppColors.deepOcean),
          ),
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
            SymbolIcon(icon, color: Colors.white, size: 17),
            const SizedBox(width: 8),
            Flexible(child: Text(label)),
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
      style:
          TextButton.styleFrom(
            foregroundColor: AppColors.deepOcean,
            textStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              letterSpacing: 0,
            ),
          ).copyWith(
            mouseCursor: const WidgetStatePropertyAll(SystemMouseCursors.click),
          ),
      child: Text(label),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
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

class _SubscriberEmptyState extends StatelessWidget {
  const _SubscriberEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        context.t('subscribers.empty'),
        style: const TextStyle(
          color: AppColors.placeholder,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _SubscriberLoadingState extends StatelessWidget {
  const _SubscriberLoadingState();

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

class _SubscribersFooter extends StatelessWidget {
  const _SubscribersFooter({
    required this.loading,
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.onPageChanged,
  });

  final bool loading;
  final int page;
  final int pageSize;
  final int totalCount;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final totalPages = math.max(1, (totalCount / pageSize).ceil());
    final start = totalCount == 0 ? 0 : ((page - 1) * pageSize) + 1;
    final end = math.min(page * pageSize, totalCount);

    final rangeText = context.t(
      'common.recordRange',
      values: {'from': start, 'to': end, 'total': totalCount},
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
        final pager = _Pagination(
          loading: loading,
          page: page,
          totalPages: totalPages,
          onPageChanged: onPageChanged,
        );

        if (mobile) {
          final hasPrevious = page > 1 && !loading;
          final hasNext = page < totalPages && !loading;
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

class _Pagination extends StatelessWidget {
  const _Pagination({
    required this.loading,
    required this.page,
    required this.totalPages,
    required this.onPageChanged,
  });

  final bool loading;
  final int page;
  final int totalPages;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        _PagerButton(
          label: '<<',
          enabled: page > 1 && !loading,
          onTap: () => onPageChanged(1),
        ),
        _PagerButton(
          label: '<',
          enabled: page > 1 && !loading,
          onTap: () => onPageChanged(page - 1),
        ),
        _PagerButton(label: '$page', selected: true),
        _PagerButton(
          label: '>',
          enabled: page < totalPages && !loading,
          onTap: () => onPageChanged(page + 1),
        ),
        _PagerButton(
          label: '>>',
          enabled: page < totalPages && !loading,
          onTap: () => onPageChanged(totalPages),
        ),
      ],
    );
  }
}

class _PagerButton extends StatelessWidget {
  const _PagerButton({
    required this.label,
    this.selected = false,
    this.enabled = true,
    this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
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
      label: Text(
        label,
        style: const TextStyle(
          color: AppColors.actionRed,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
