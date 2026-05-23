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
import 'contact_list_models.dart';

class ContactListsScreen extends StatefulWidget {
  const ContactListsScreen({super.key});

  @override
  State<ContactListsScreen> createState() => _ContactListsScreenState();
}

class _ContactListsScreenState extends State<ContactListsScreen> {
  final _searchController = TextEditingController();
  final _selectedIds = <int>{};
  var _lists = List<AdminContactList>.of(sampleAdminContactLists);
  var _searchQuery = '';
  var _page = 1;
  var _pageSize = 25;
  var _sortState = const TableSortState(key: 'date', ascending: false);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AdminContactList> get _filteredLists {
    final query = _searchQuery.trim().toLowerCase();
    final filtered = _lists.where((list) {
      if (query.isEmpty) return true;
      final searchable = [
        list.name,
        list.description,
        list.contactCount,
        context.t(list.source.labelKey),
        list.active
            ? context.t('mail.contacts.status.active')
            : context.t('mail.contacts.status.passive'),
        list.syncEnabled
            ? context.t('mail.contacts.sync.open')
            : context.t('mail.contacts.sync.closed'),
      ].join(' ').toLowerCase();
      return searchable.contains(query);
    }).toList();

    filtered.sort((left, right) {
      final result = switch (_sortState.key) {
        'name' => left.name.compareTo(right.name),
        'description' => left.description.compareTo(right.description),
        'person' => left.contactCount.compareTo(right.contactCount),
        'sync' => left.syncEnabled.toString().compareTo(
          right.syncEnabled.toString(),
        ),
        'status' => left.active.toString().compareTo(right.active.toString()),
        'date' || _ => left.createdAt.compareTo(right.createdAt),
      };
      return _sortState.ascending ? result : -result;
    });

    return filtered;
  }

  List<AdminContactList> get _pagedLists {
    final filtered = _filteredLists;
    if (filtered.isEmpty) return const <AdminContactList>[];
    final start = (_page - 1) * _pageSize;
    if (start >= filtered.length) return filtered.take(_pageSize).toList();
    final end = math.min(start + _pageSize, filtered.length);
    return filtered.sublist(start, end);
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

  void _toggleList(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _toggleAllLists() {
    final pageIds = _pagedLists.map((list) => list.id).toSet();
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

  void _replaceList(AdminContactList list) {
    setState(() {
      _lists = [
        for (final current in _lists)
          if (current.id == list.id) list else current,
      ];
    });
  }

  void _toggleActive(AdminContactList list) {
    _replaceList(list.copyWith(active: !list.active));
  }

  void _toggleSync(AdminContactList list) {
    _replaceList(list.copyWith(syncEnabled: !list.syncEnabled));
  }

  Future<void> _deleteList(AdminContactList list) async {
    final confirmed = await showAppConfirmationDialog(
      context,
      title: context.t('mail.contacts.deleteTitle'),
      message: context.t('mail.contacts.deleteMessage'),
      confirmLabel: context.t('common.delete'),
      danger: true,
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _lists = _lists
          .where((current) => current.id != list.id)
          .toList(growable: false);
      _selectedIds.remove(list.id);
    });
  }

  Future<void> _deleteSelectedLists() async {
    if (_selectedIds.isEmpty) return;
    final confirmed = await showAppConfirmationDialog(
      context,
      title: context.t('mail.contacts.deleteSelectedTitle'),
      message: context.t(
        'mail.contacts.deleteSelectedMessage',
        values: {'count': _selectedIds.length},
      ),
      confirmLabel: context.t('common.delete'),
      danger: true,
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _lists = _lists
          .where((list) => !_selectedIds.contains(list.id))
          .toList(growable: false);
      _selectedIds.clear();
    });
  }

  Future<void> _showListDialog({AdminContactList? list}) async {
    final result = await showDialog<AdminContactList>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        final size = MediaQuery.sizeOf(context);
        final width = (size.width - 48).clamp(740.0, 1180.0).toDouble();
        final height = (size.height - 48).clamp(620.0, 840.0).toDouble();
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          child: SizedBox(
            width: width,
            height: height,
            child: _ContactListDialog(list: list),
          ),
        );
      },
    );

    if (result == null || !mounted) return;
    setState(() {
      final index = _lists.indexWhere((current) => current.id == result.id);
      if (index == -1) {
        _lists = [result, ..._lists];
      } else {
        _lists = [
          for (final current in _lists)
            if (current.id == result.id) result else current,
        ];
      }
      _resetListState();
    });
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
            _ContactListsTitle(
              selectedCount: _selectedIds.length,
              onDeleteSelected: _deleteSelectedLists,
            ),
            const SizedBox(height: 24),
            Expanded(
              child: _ContactListsTableCard(
                lists: _pagedLists,
                page: _page,
                pageSize: _pageSize,
                totalCount: _filteredLists.length,
                searchController: _searchController,
                searchQuery: _searchQuery,
                selectedIds: _selectedIds,
                sortState: _sortState,
                onPageSizeChanged: _changePageSize,
                onSearchChanged: _changeSearch,
                onPageChanged: _changePage,
                onToggleList: _toggleList,
                onToggleAllLists: _toggleAllLists,
                onSort: _changeSort,
                onCreate: () => _showListDialog(),
                onEdit: (list) => _showListDialog(list: list),
                onToggleSync: _toggleSync,
                onToggleActive: _toggleActive,
                onDelete: _deleteList,
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
            child: SizedBox(height: 960, child: content),
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

class _ContactListsTitle extends StatelessWidget {
  const _ContactListsTitle({
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
            context.t('mail.contacts.title'),
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
              'mail.contacts.selectedDelete',
              values: {'count': selectedCount},
            ),
            onTap: onDeleteSelected,
          ),
      ],
    );
  }
}

class _ContactListsTableCard extends StatelessWidget {
  const _ContactListsTableCard({
    required this.lists,
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
    required this.onToggleList,
    required this.onToggleAllLists,
    required this.onSort,
    required this.onCreate,
    required this.onEdit,
    required this.onToggleSync,
    required this.onToggleActive,
    required this.onDelete,
  });

  static const _minTableWidth = 1180.0;

  final List<AdminContactList> lists;
  final int page;
  final int pageSize;
  final int totalCount;
  final TextEditingController searchController;
  final String searchQuery;
  final Set<int> selectedIds;
  final TableSortState sortState;
  final ValueChanged<int?> onPageSizeChanged;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onToggleList;
  final VoidCallback onToggleAllLists;
  final ValueChanged<String> onSort;
  final VoidCallback onCreate;
  final ValueChanged<AdminContactList> onEdit;
  final ValueChanged<AdminContactList> onToggleSync;
  final ValueChanged<AdminContactList> onToggleActive;
  final ValueChanged<AdminContactList> onDelete;

  @override
  Widget build(BuildContext context) {
    final pageIds = lists.map((list) => list.id).toSet();
    final allSelected = pageIds.isNotEmpty && selectedIds.containsAll(pageIds);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ContactListsToolbar(
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
                        _ContactListTableHeader(
                          selected: allSelected,
                          sortState: sortState,
                          onToggle: onToggleAllLists,
                          onSort: onSort,
                        ),
                        Expanded(
                          child: lists.isEmpty
                              ? const _ContactListEmptyState()
                              : ListView.builder(
                                  itemCount: lists.length,
                                  itemBuilder: (context, index) {
                                    final list = lists[index];
                                    return _ContactListTableRow(
                                      list: list,
                                      selected: selectedIds.contains(list.id),
                                      onToggle: () => onToggleList(list.id),
                                      onEdit: () => onEdit(list),
                                      onToggleSync: () => onToggleSync(list),
                                      onToggleActive: () =>
                                          onToggleActive(list),
                                      onDelete: () => onDelete(list),
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
        _ContactListFooter(
          page: page,
          pageSize: pageSize,
          totalCount: totalCount,
          onPageChanged: onPageChanged,
        ),
      ],
    );
  }
}

class _ContactListsToolbar extends StatelessWidget {
  const _ContactListsToolbar({
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
                hint: context.t('mail.contacts.searchPlaceholder'),
                onChanged: onSearchChanged,
              ),
            ),
            _PrimaryActionButton(
              icon: Symbols.add,
              label: context.t('mail.contacts.newList'),
              shortcut: 'F1',
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

class _ContactListTableHeader extends StatelessWidget {
  const _ContactListTableHeader({
    required this.selected,
    required this.sortState,
    required this.onToggle,
    required this.onSort,
  });

  static const _selectWidth = 48.0;
  static const _personWidth = 118.0;
  static const _syncWidth = 116.0;
  static const _statusWidth = 116.0;
  static const _actionsWidth = 74.0;
  static const _nameFlex = 3;
  static const _descriptionFlex = 4;
  static const _dateFlex = 3;

  final bool selected;
  final TableSortState sortState;
  final VoidCallback onToggle;
  final ValueChanged<String> onSort;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.softLine)),
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
            child: _ContactListSortableHeader(
              label: 'mail.contacts.column.name',
              sortKey: 'name',
              sortState: sortState,
              onSort: onSort,
            ),
          ),
          Expanded(
            flex: _descriptionFlex,
            child: _ContactListSortableHeader(
              label: 'mail.contacts.column.description',
              sortKey: 'description',
              sortState: sortState,
              onSort: onSort,
            ),
          ),
          SizedBox(
            width: _personWidth,
            child: _ContactListSortableHeader(
              label: 'mail.contacts.column.person',
              sortKey: 'person',
              sortState: sortState,
              onSort: onSort,
            ),
          ),
          SizedBox(
            width: _syncWidth,
            child: _ContactListSortableHeader(
              label: 'mail.contacts.column.sync',
              sortKey: 'sync',
              sortState: sortState,
              onSort: onSort,
            ),
          ),
          SizedBox(
            width: _statusWidth,
            child: _ContactListSortableHeader(
              label: 'mail.contacts.column.status',
              sortKey: 'status',
              sortState: sortState,
              onSort: onSort,
            ),
          ),
          Expanded(
            flex: _dateFlex,
            child: _ContactListSortableHeader(
              label: 'mail.contacts.column.date',
              sortKey: 'date',
              sortState: sortState,
              onSort: onSort,
            ),
          ),
          SizedBox(
            width: _actionsWidth,
            child: Center(
              child: Text(
                context.t('mail.contacts.column.actions'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.inkSoft,
                  fontSize: 12,
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

class _ContactListSortableHeader extends StatelessWidget {
  const _ContactListSortableHeader({
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
      style: const TextStyle(fontSize: 12, letterSpacing: 0),
      child: SortableTableHeader(
        label: label,
        sortKey: sortKey,
        sortState: sortState,
        onSort: onSort,
      ),
    );
  }
}

class _ContactListTableRow extends StatelessWidget {
  const _ContactListTableRow({
    required this.list,
    required this.selected,
    required this.onToggle,
    required this.onEdit,
    required this.onToggleSync,
    required this.onToggleActive,
    required this.onDelete,
  });

  final AdminContactList list;
  final bool selected;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onToggleSync;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.softLine)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _ContactListTableHeader._selectWidth,
            child: Center(
              child: _ListCheckbox(selected: selected, onTap: onToggle),
            ),
          ),
          Expanded(
            flex: _ContactListTableHeader._nameFlex,
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: contactListSourceColor(
                      list.source,
                    ).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.value),
                  ),
                  child: Icon(
                    list.source.icon,
                    color: contactListSourceColor(list.source),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    list.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.deepOcean,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: _ContactListTableHeader._descriptionFlex,
            child: Text(
              list.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.inkSoft,
                fontSize: 11,
                fontWeight: FontWeight.w400,
                height: 1.25,
                letterSpacing: 0,
              ),
            ),
          ),
          SizedBox(
            width: _ContactListTableHeader._personWidth,
            child: Text(
              list.contactCount.toString(),
              style: const TextStyle(
                color: AppColors.deepOcean,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
          ),
          SizedBox(
            width: _ContactListTableHeader._syncWidth,
            child: _StatusBadge(
              label: list.syncEnabled
                  ? context.t('mail.contacts.sync.open')
                  : context.t('mail.contacts.sync.closed'),
              color: list.syncEnabled
                  ? const Color(0xFF2F80ED)
                  : AppColors.support,
              compact: true,
            ),
          ),
          SizedBox(
            width: _ContactListTableHeader._statusWidth,
            child: _StatusBadge(
              label: list.active
                  ? context.t('mail.contacts.status.active')
                  : context.t('mail.contacts.status.passive'),
              color: list.active ? const Color(0xFF198754) : AppColors.support,
              compact: true,
            ),
          ),
          Expanded(
            flex: _ContactListTableHeader._dateFlex,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatAdminFullDate(context, list.createdAt),
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
                  formatAdminTime(list.createdAt),
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
            width: _ContactListTableHeader._actionsWidth,
            child: Align(
              alignment: Alignment.center,
              child: _ContactListRowMenu(
                list: list,
                onEdit: onEdit,
                onToggleSync: onToggleSync,
                onToggleActive: onToggleActive,
                onDelete: onDelete,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactListDialog extends StatefulWidget {
  const _ContactListDialog({required this.list});

  final AdminContactList? list;

  @override
  State<_ContactListDialog> createState() => _ContactListDialogState();
}

class _ContactListDialogState extends State<_ContactListDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late AdminContactImportSource _source;
  late bool _active;
  String? _selectedFileName;
  var _readyCount = 0;
  var _nameHasError = false;

  @override
  void initState() {
    super.initState();
    final list = widget.list;
    _nameController = TextEditingController(text: list?.name ?? '');
    _descriptionController = TextEditingController(
      text: list?.description ?? '',
    );
    _source = list?.source ?? AdminContactImportSource.csv;
    _active = list?.active ?? true;
    _readyCount = list?.contactCount ?? 0;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _selectSource(AdminContactImportSource source) {
    setState(() {
      _source = source;
      _selectedFileName = null;
      _readyCount = widget.list?.source == source
          ? widget.list?.contactCount ?? 0
          : 0;
    });
  }

  void _chooseFile() {
    setState(() {
      if (_source == AdminContactImportSource.csv) {
        _selectedFileName = 'pateez_kisiler.csv';
        _readyCount = 128;
      } else {
        _selectedFileName = 'pateez_kisiler.xlsx';
        _readyCount = 96;
      }
    });
  }

  void _submit({required bool importContacts}) {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _nameHasError = true);
      return;
    }

    final existing = widget.list;
    final contactCount = importContacts
        ? (_readyCount > 0 ? _readyCount : existing?.contactCount ?? 0)
        : existing?.contactCount ?? 0;
    Navigator.of(context).pop(
      AdminContactList(
        id: existing?.id ?? DateTime.now().millisecondsSinceEpoch,
        name: name,
        description: _descriptionController.text.trim(),
        contactCount: contactCount,
        syncEnabled: existing?.syncEnabled ?? false,
        active: _active,
        createdAt: existing?.createdAt ?? DateTime.now(),
        source: _source,
      ),
    );
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
              children: [
                Expanded(
                  child: Text(
                    context.t(
                      widget.list == null
                          ? 'mail.contacts.dialog.newTitle'
                          : 'mail.contacts.dialog.editTitle',
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
                  border: Border.all(color: AppColors.line),
                  borderRadius: BorderRadius.circular(AppRadius.value),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 900;
                    final form = Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _DialogTopForm(
                          compact: compact,
                          nameController: _nameController,
                          descriptionController: _descriptionController,
                          active: _active,
                          nameHasError: _nameHasError,
                          onNameChanged: (_) {
                            if (_nameHasError) {
                              setState(() => _nameHasError = false);
                            }
                          },
                          onActiveChanged: (value) =>
                              setState(() => _active = value),
                        ),
                        const SizedBox(height: 18),
                        compact
                            ? Column(
                                children: [
                                  _ImportSourcePanel(
                                    selected: _source,
                                    onChanged: _selectSource,
                                  ),
                                  const SizedBox(height: 14),
                                  _ImportFilePanel(
                                    source: _source,
                                    selectedFileName: _selectedFileName,
                                    readyCount: _readyCount,
                                    onChooseFile: _chooseFile,
                                  ),
                                  const SizedBox(height: 14),
                                  _ImportInfoPanel(
                                    source: _source,
                                    readyCount: _readyCount,
                                    active: _active,
                                  ),
                                ],
                              )
                            : Expanded(
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    SizedBox(
                                      width: 236,
                                      child: _ImportSourcePanel(
                                        selected: _source,
                                        onChanged: _selectSource,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: _ImportFilePanel(
                                        source: _source,
                                        selectedFileName: _selectedFileName,
                                        readyCount: _readyCount,
                                        onChooseFile: _chooseFile,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    SizedBox(
                                      width: 244,
                                      child: _ImportInfoPanel(
                                        source: _source,
                                        readyCount: _readyCount,
                                        active: _active,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ],
                    );

                    if (compact) {
                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: form,
                      );
                    }

                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: form,
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
                _SecondaryActionButton(
                  icon: Symbols.save,
                  label: context.t('mail.contacts.dialog.onlySave'),
                  onPressed: () => _submit(importContacts: false),
                ),
                _PrimaryActionButton(
                  icon: Symbols.upload,
                  label: context.t('mail.contacts.dialog.saveAndImport'),
                  backgroundColor: AppColors.deepOcean,
                  onPressed: () => _submit(importContacts: true),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DialogTopForm extends StatelessWidget {
  const _DialogTopForm({
    required this.compact,
    required this.nameController,
    required this.descriptionController,
    required this.active,
    required this.nameHasError,
    required this.onNameChanged,
    required this.onActiveChanged,
  });

  final bool compact;
  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final bool active;
  final bool nameHasError;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<bool> onActiveChanged;

  @override
  Widget build(BuildContext context) {
    final name = _UnderlinedInput(
      label: context.t('mail.contacts.dialog.listName'),
      hint: context.t('mail.contacts.dialog.listNameHint'),
      controller: nameController,
      icon: Icons.badge_outlined,
      required: true,
      hasError: nameHasError,
      errorText: context.t('mail.contacts.dialog.nameRequired'),
      onChanged: onNameChanged,
    );
    final description = _UnderlinedInput(
      label: context.t('mail.contacts.dialog.description'),
      hint: context.t('mail.contacts.dialog.descriptionHint'),
      controller: descriptionController,
      icon: Symbols.short_text,
    );
    final status = _StatusRadioGroup(
      active: active,
      onChanged: onActiveChanged,
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          name,
          const SizedBox(height: 16),
          description,
          const SizedBox(height: 16),
          status,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 5, child: name),
        const SizedBox(width: 24),
        Expanded(flex: 5, child: description),
        const SizedBox(width: 24),
        SizedBox(width: 190, child: status),
      ],
    );
  }
}

class _ImportSourcePanel extends StatelessWidget {
  const _ImportSourcePanel({required this.selected, required this.onChanged});

  final AdminContactImportSource selected;
  final ValueChanged<AdminContactImportSource> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.t('mail.contacts.dialog.sourceTitle'),
            style: const TextStyle(
              color: AppColors.deepOcean,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.t('mail.contacts.dialog.sourceSubtitle'),
            style: const TextStyle(
              color: AppColors.inkSoft,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 14),
          for (final source in AdminContactImportSource.values) ...[
            _SourceOption(
              source: source,
              selected: selected == source,
              onTap: () => onChanged(source),
            ),
            if (source != AdminContactImportSource.values.last)
              const SizedBox(height: 10),
          ],
          const SizedBox(height: 16),
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.line),
              borderRadius: BorderRadius.circular(AppRadius.value),
            ),
            child: Row(
              children: [
                const SymbolIcon(
                  Symbols.check,
                  color: AppColors.deepOcean,
                  size: 17,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.t(
                      'mail.contacts.dialog.selectedSource',
                      values: {'source': context.t(selected.shortLabelKey)},
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.deepOcean,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
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

class _ImportFilePanel extends StatelessWidget {
  const _ImportFilePanel({
    required this.source,
    required this.selectedFileName,
    required this.readyCount,
    required this.onChooseFile,
  });

  final AdminContactImportSource source;
  final String? selectedFileName;
  final int readyCount;
  final VoidCallback onChooseFile;

  @override
  Widget build(BuildContext context) {
    final sourceShort = context.t(source.shortLabelKey);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: contactListSourceColor(source).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.value),
                ),
                child: Icon(
                  source.icon,
                  color: contactListSourceColor(source),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.t(
                        source == AdminContactImportSource.csv
                            ? 'mail.contacts.dialog.csvTitle'
                            : 'mail.contacts.dialog.excelTitle',
                      ),
                      style: const TextStyle(
                        color: AppColors.deepOcean,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.t(
                        source == AdminContactImportSource.csv
                            ? 'mail.contacts.dialog.csvSubtitle'
                            : 'mail.contacts.dialog.excelSubtitle',
                      ),
                      style: const TextStyle(
                        color: AppColors.inkSoft,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              _TinyBadge(label: sourceShort),
            ],
          ),
          const SizedBox(height: 14),
          _ImportSteps(source: source),
          const SizedBox(height: 96),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.value),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.value),
                  ),
                  child: const SymbolIcon(
                    Symbols.upload,
                    color: AppColors.deepOcean,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.t(
                          source == AdminContactImportSource.csv
                              ? 'mail.contacts.dialog.csvUploadTitle'
                              : 'mail.contacts.dialog.excelUploadTitle',
                        ),
                        style: const TextStyle(
                          color: AppColors.deepOcean,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        selectedFileName ??
                            context.t(
                              source == AdminContactImportSource.csv
                                  ? 'mail.contacts.dialog.csvUploadSubtitle'
                                  : 'mail.contacts.dialog.excelUploadSubtitle',
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.inkSoft,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _DarkButton(
                  icon: Symbols.folder_open,
                  label: context.t('mail.contacts.dialog.chooseFile'),
                  onPressed: onChooseFile,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (readyCount > 0)
            Align(
              alignment: Alignment.centerLeft,
              child: _StatusBadge(
                label: context.t(
                  'mail.contacts.dialog.fileReady',
                  values: {'count': readyCount},
                ),
                color: const Color(0xFF198754),
              ),
            ),
          const SizedBox(height: 10),
          const _ExampleTable(),
        ],
      ),
    );
  }
}

class _ImportInfoPanel extends StatelessWidget {
  const _ImportInfoPanel({
    required this.source,
    required this.readyCount,
    required this.active,
  });

  final AdminContactImportSource source;
  final int readyCount;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.lightbulb_outline,
                color: AppColors.deepOcean,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.t('mail.contacts.dialog.beforeStart'),
                  style: const TextStyle(
                    color: AppColors.deepOcean,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _RuleText(label: context.t('mail.contacts.dialog.ruleHeader')),
          _RuleText(label: context.t('mail.contacts.dialog.ruleEmail')),
          _RuleText(label: context.t('mail.contacts.dialog.ruleDuplicate')),
          _RuleText(label: context.t('mail.contacts.dialog.ruleUtf')),
          const SizedBox(height: 24),
          const Divider(color: AppColors.line),
          const SizedBox(height: 8),
          _MetricLine(
            label: context.t('mail.contacts.dialog.metricSource'),
            value: context.t(source.shortLabelKey),
          ),
          _MetricLine(
            label: context.t('mail.contacts.dialog.metricReady'),
            value: '$readyCount',
          ),
          _MetricLine(
            label: context.t('mail.contacts.dialog.metricMode'),
            value: active
                ? context.t('mail.contacts.status.active')
                : context.t('mail.contacts.status.passive'),
          ),
        ],
      ),
    );
  }
}

class _SourceOption extends StatelessWidget {
  const _SourceOption({
    required this.source,
    required this.selected,
    required this.onTap,
  });

  final AdminContactImportSource source;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = contactListSourceColor(source);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 58),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.value),
            border: Border.all(
              color: selected ? AppColors.deepOcean : AppColors.line,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.value),
                ),
                child: Icon(source.icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.t(
                        source == AdminContactImportSource.csv
                            ? 'mail.contacts.dialog.csvFile'
                            : 'mail.contacts.dialog.excelFile',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.deepOcean,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.t(
                        source == AdminContactImportSource.csv
                            ? 'mail.contacts.dialog.csvFileSubtitle'
                            : 'mail.contacts.dialog.excelFileSubtitle',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.inkSoft,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? AppColors.deepOcean : Colors.white,
                  border: Border.all(
                    color: selected ? AppColors.deepOcean : AppColors.support,
                  ),
                ),
                child: selected
                    ? const SymbolIcon(
                        Symbols.check,
                        color: Colors.white,
                        size: 12,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImportSteps extends StatelessWidget {
  const _ImportSteps({required this.source});

  final AdminContactImportSource source;

  @override
  Widget build(BuildContext context) {
    final stepLabels = [
      context.t('mail.contacts.dialog.source'),
      context.t('mail.contacts.dialog.file'),
      context.t('mail.contacts.dialog.saveStep'),
    ];
    return Row(
      children: [
        for (var index = 0; index < stepLabels.length; index++) ...[
          Expanded(
            child: Container(
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: index == 0 ? Colors.white : AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.value),
                border: Border.all(
                  color: index == 0
                      ? AppColors.deepOcean
                      : AppColors.line.withValues(alpha: 0.85),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: index == 0
                          ? AppColors.deepOcean
                          : AppColors.line.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: index == 0 ? Colors.white : AppColors.inkSoft,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      stepLabels[index],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.deepOcean,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (index != stepLabels.length - 1) ...[
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              color: contactListSourceColor(source),
              size: 18,
            ),
            const SizedBox(width: 8),
          ],
        ],
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
    this.required = false,
    this.hasError = false,
    this.errorText,
    this.onChanged,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final IconData icon;
  final bool required;
  final bool hasError;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final color = hasError ? AppColors.actionRed : AppColors.deepOcean;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          required ? '$label *' : label,
          style: TextStyle(
            color: required || hasError ? AppColors.actionRed : color,
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
            style: const TextStyle(
              color: AppColors.deepOcean,
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
                fontWeight: FontWeight.w500,
                letterSpacing: 0,
              ),
              errorStyle: const TextStyle(
                color: AppColors.actionRed,
                fontSize: 11,
                fontWeight: FontWeight.w500,
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
          context.t('mail.contacts.dialog.status'),
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
              label: context.t('mail.contacts.status.active'),
              selected: active,
              onTap: () => onChanged(true),
            ),
            _RadioChoice(
              label: context.t('mail.contacts.status.passive'),
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
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.deepOcean, width: 2),
              ),
              child: selected
                  ? Container(
                      decoration: const BoxDecoration(
                        color: AppColors.deepOcean,
                        shape: BoxShape.circle,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
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

class _ExampleTable extends StatelessWidget {
  const _ExampleTable();

  @override
  Widget build(BuildContext context) {
    final headers = [
      context.t('mail.contacts.example.email'),
      context.t('mail.contacts.example.firstName'),
      context.t('mail.contacts.example.lastName'),
      context.t('mail.contacts.example.phone'),
    ];
    final values = ['jane@example.com', 'Jane', 'Carter', '+1 555 0148'];
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
            height: 28,
            color: AppColors.surface,
            child: Row(
              children: [
                for (final header in headers)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        header,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.deepOcean,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 28,
            child: Row(
              children: [
                for (final value in values)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        value,
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
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactListRowMenu extends StatefulWidget {
  const _ContactListRowMenu({
    required this.list,
    required this.onEdit,
    required this.onToggleSync,
    required this.onToggleActive,
    required this.onDelete,
  });

  final AdminContactList list;
  final VoidCallback onEdit;
  final VoidCallback onToggleSync;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;

  @override
  State<_ContactListRowMenu> createState() => _ContactListRowMenuState();
}

class _ContactListRowMenuState extends State<_ContactListRowMenu> {
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
            child: _ContactListMenuCard(
              list: widget.list,
              onEdit: () => _tap(widget.onEdit),
              onToggleSync: () => _tap(widget.onToggleSync),
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
        message: context.t('mail.contacts.actions'),
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

class _ContactListMenuCard extends StatelessWidget {
  const _ContactListMenuCard({
    required this.list,
    required this.onEdit,
    required this.onToggleSync,
    required this.onToggleActive,
    required this.onDelete,
  });

  final AdminContactList list;
  final VoidCallback onEdit;
  final VoidCallback onToggleSync;
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
            _MenuItem(
              icon: Symbols.edit_square,
              label: 'mail.contacts.action.edit',
              onTap: onEdit,
            ),
            _MenuItem(
              icon: list.syncEnabled ? Icons.sync_disabled : Icons.sync,
              label: list.syncEnabled
                  ? 'mail.contacts.action.syncDisable'
                  : 'mail.contacts.action.syncEnable',
              onTap: onToggleSync,
            ),
            _MenuItem(
              icon: list.active ? Symbols.visibility_off : Symbols.visibility,
              label: list.active
                  ? 'mail.contacts.action.deactivate'
                  : 'mail.contacts.action.activate',
              onTap: onToggleActive,
            ),
            _MenuItem(
              icon: Symbols.delete,
              label: 'mail.contacts.action.delete',
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
        height: compact ? null : 26,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 5 : 0,
        ),
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
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: compact ? 10 : 12,
                  fontWeight: compact ? FontWeight.w700 : FontWeight.w800,
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

class _TinyBadge extends StatelessWidget {
  const _TinyBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.value),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.deepOcean,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _MetricLine extends StatelessWidget {
  const _MetricLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.inkSoft,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.deepOcean,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _RuleText extends StatelessWidget {
  const _RuleText({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SymbolIcon(Symbols.check, color: AppColors.deepOcean, size: 15),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.inkSoft,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                height: 1.35,
                letterSpacing: 0,
              ),
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
    return Container(
      width: 64,
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line.withValues(alpha: 0.82)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          isExpanded: true,
          icon: const SymbolIcon(
            Symbols.keyboard_arrow_down,
            color: AppColors.iconMuted,
            size: 18,
          ),
          borderRadius: BorderRadius.circular(AppRadius.value),
          items: const [10, 25, 50, 100]
              .map(
                (item) => DropdownMenuItem<int>(
                  value: item,
                  child: Text(
                    '$item',
                    style: TextStyle(
                      color: AppColors.deepOcean,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
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
    this.shortcut,
    this.backgroundColor = AppColors.actionRed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final String? shortcut;
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
            const SizedBox(width: 8),
            Flexible(child: Text(label)),
            if (shortcut != null) ...[
              const SizedBox(width: 8),
              Container(
                height: 22,
                padding: const EdgeInsets.symmetric(horizontal: 7),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppRadius.value),
                ),
                child: Text(
                  shortcut!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
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
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SymbolIcon(icon, color: AppColors.deepOcean, size: 17),
            const SizedBox(width: 8),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _DarkButton extends StatelessWidget {
  const _DarkButton({
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
          backgroundColor: AppColors.deepOcean,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.value),
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
            SymbolIcon(icon, color: Colors.white, size: 17),
            const SizedBox(width: 8),
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

class _ContactListEmptyState extends StatelessWidget {
  const _ContactListEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        context.t('mail.contacts.empty'),
        style: const TextStyle(
          color: AppColors.placeholder,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _ContactListFooter extends StatelessWidget {
  const _ContactListFooter({
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
    final totalPages = math.max(1, (totalCount / pageSize).ceil());
    final start = totalCount == 0 ? 0 : ((page - 1) * pageSize) + 1;
    final end = math.min(page * pageSize, totalCount);

    return Row(
      children: [
        Expanded(
          child: Text(
            context.t(
              'common.recordRange',
              values: {'from': start, 'to': end, 'total': totalCount},
            ),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.inkSoft,
              fontWeight: FontWeight.w500,
              letterSpacing: 0,
            ),
          ),
        ),
        _Pagination(
          page: page,
          totalPages: totalPages,
          onPageChanged: onPageChanged,
        ),
      ],
    );
  }
}

class _Pagination extends StatelessWidget {
  const _Pagination({
    required this.page,
    required this.totalPages,
    required this.onPageChanged,
  });

  final int page;
  final int totalPages;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _PagerButton(
          label: '<<',
          enabled: page > 1,
          onTap: () => onPageChanged(1),
        ),
        const SizedBox(width: 8),
        _PagerButton(
          label: '<',
          enabled: page > 1,
          onTap: () => onPageChanged(page - 1),
        ),
        const SizedBox(width: 8),
        Container(
          width: 36,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.deepOcean,
            borderRadius: BorderRadius.circular(AppRadius.value),
          ),
          child: Text(
            '$page',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ),
        const SizedBox(width: 8),
        _PagerButton(
          label: '>',
          enabled: page < totalPages,
          onTap: () => onPageChanged(page + 1),
        ),
        const SizedBox(width: 8),
        _PagerButton(
          label: '>>',
          enabled: page < totalPages,
          onTap: () => onPageChanged(totalPages),
        ),
      ],
    );
  }
}

class _PagerButton extends StatelessWidget {
  const _PagerButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 34,
      child: TextButton(
        onPressed: enabled ? onTap : null,
        style: TextButton.styleFrom(
          backgroundColor: Colors.white,
          disabledBackgroundColor: Colors.white,
          foregroundColor: AppColors.deepOcean,
          disabledForegroundColor: AppColors.placeholder,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.value),
            side: const BorderSide(color: AppColors.line),
          ),
          textStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        child: Text(label),
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
