import 'dart:async';
import 'dart:math' as math;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/widgets/admin_table_chrome.dart';
import 'package:pateeznews_admin/shared/widgets/admin_toast.dart';

import '../../../core/localization/admin_date_formatter.dart';
import '../../../core/localization/admin_language_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/icons/symbols.dart';
import '../../../shared/widgets/admin_mobile_list.dart';
import '../../../shared/widgets/app_confirmation_dialog.dart';
import '../../../shared/widgets/sortable_table_header.dart';
import '../../../shared/widgets/symbol_icon.dart';
import '../../auth/data/admin_auth_models.dart';
import '../../subscribers/data/admin_subscribers_repository.dart';
import '../../subscribers/presentation/subscribers_models.dart';
import '../data/admin_mail_repository.dart';
import 'contact_import_parser.dart';
import 'contact_list_contacts_dialog.dart';
import 'contact_list_models.dart';

class ContactListsScreen extends StatefulWidget {
  const ContactListsScreen({
    super.key,
    required this.session,
    this.repository = const SupabaseAdminMailRepository(),
    this.subscribersRepository = const SupabaseAdminSubscribersRepository(),
  });

  final AdminSession session;
  final AdminMailRepository repository;
  final AdminSubscribersRepository subscribersRepository;

  @override
  State<ContactListsScreen> createState() => _ContactListsScreenState();
}

class _ContactListsScreenState extends State<ContactListsScreen> {
  final _searchController = TextEditingController();
  final _selectedIds = <int>{};
  var _lists = <AdminContactList>[];
  var _searchQuery = '';
  var _page = 1;
  var _pageSize = 25;
  var _sortState = const TableSortState(key: 'date', ascending: false);
  var _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadLists());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLists() async {
    setState(() => _loading = true);
    try {
      final lists = await widget.repository.fetchContactLists(widget.session);
      if (!mounted) return;
      setState(() {
        _lists = lists;
        _loading = false;
        _resetListState();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMailError(error);
    }
  }

  void _showMailError(Object error) {
    AdminToast.show(
      context,
      message: error.toString(),
      tone: AdminToastTone.error,
    );
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

  Future<void> _toggleActive(AdminContactList list) async {
    try {
      final updated = await widget.repository.updateContactList(
        widget.session,
        list,
        {'is_active': !list.active},
      );
      if (mounted) _replaceList(updated);
    } catch (error) {
      if (mounted) _showMailError(error);
    }
  }

  Future<void> _toggleSync(AdminContactList list) async {
    try {
      final updated = await widget.repository.updateContactList(
        widget.session,
        list,
        {'auto_sync': !list.syncEnabled},
      );
      if (mounted) _replaceList(updated);
    } catch (error) {
      if (mounted) _showMailError(error);
    }
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
    try {
      await widget.repository.deleteContactLists(widget.session, [list.id]);
      if (!mounted) return;
      setState(() {
        _lists = _lists
            .where((current) => current.id != list.id)
            .toList(growable: false);
        _selectedIds.remove(list.id);
      });
    } catch (error) {
      if (mounted) _showMailError(error);
    }
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
    try {
      final ids = _selectedIds.toList(growable: false);
      await widget.repository.deleteContactLists(widget.session, ids);
      if (!mounted) return;
      setState(() {
        _lists = _lists
            .where((list) => !ids.contains(list.id))
            .toList(growable: false);
        _selectedIds.clear();
      });
    } catch (error) {
      if (mounted) _showMailError(error);
    }
  }

  Future<void> _showListDialog({AdminContactList? list}) async {
    final result = await showDialog<_ContactListDialogResult>(
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
            child: _ContactListDialog(
              list: list,
              subscribersRepository: widget.subscribersRepository,
            ),
          ),
        );
      },
    );

    if (result == null || !mounted) return;
    late AdminContactList saved;
    try {
      saved = await widget.repository.saveContactList(
        widget.session,
        id: list?.id,
        list: result.list,
      );
      final importRows = result.importRows;
      if (result.importContacts &&
          importRows != null &&
          importRows.isNotEmpty) {
        saved = await widget.repository.importContacts(
          widget.session,
          saved,
          importRows,
        );
      }
    } catch (error) {
      if (mounted) _showMailError(error);
      return;
    }
    if (!mounted) return;
    setState(() {
      final index = _lists.indexWhere((current) => current.id == saved.id);
      if (index == -1) {
        _lists = [saved, ..._lists];
      } else {
        _lists = [
          for (final current in _lists)
            if (current.id == saved.id) saved else current,
        ];
      }
      _resetListState();
    });
  }

  Future<void> _showContacts(AdminContactList list) async {
    final size = MediaQuery.sizeOf(context);
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: SizedBox(
          width: (size.width - 48).clamp(640.0, 980.0).toDouble(),
          height: (size.height - 48).clamp(520.0, 760.0).toDouble(),
          child: ContactListContactsDialog(
            session: widget.session,
            repository: widget.repository,
            list: list,
          ),
        ),
      ),
    );
    if (mounted) await _loadLists();
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
            _ContactListsTitle(
              selectedCount: _selectedIds.length,
              onDeleteSelected: _deleteSelectedLists,
            ),
            SizedBox(height: mobile ? 12 : 24),
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
                onContacts: _showContacts,
                onToggleSync: (list) => unawaited(_toggleSync(list)),
                onToggleActive: (list) => unawaited(_toggleActive(list)),
                onDelete: _deleteList,
              ),
            ),
            if (_loading) const LinearProgressIndicator(minHeight: 2),
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
            child: SizedBox(height: 960, child: content),
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
    required this.onContacts,
    required this.onToggleSync,
    required this.onToggleActive,
    required this.onDelete,
  });

  static const _minTableWidth = 860.0;

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
  final ValueChanged<AdminContactList> onContacts;
  final ValueChanged<AdminContactList> onToggleSync;
  final ValueChanged<AdminContactList> onToggleActive;
  final ValueChanged<AdminContactList> onDelete;

  @override
  Widget build(BuildContext context) {
    final pageIds = lists.map((list) => list.id).toSet();
    final allSelected = pageIds.isNotEmpty && selectedIds.containsAll(pageIds);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < AdminMobile.breakpoint) {
          return _ContactListsMobileView(
            lists: lists,
            page: page,
            pageSize: pageSize,
            totalCount: totalCount,
            searchController: searchController,
            searchQuery: searchQuery,
            selectedIds: selectedIds,
            onSearchChanged: onSearchChanged,
            onPageChanged: onPageChanged,
            onToggleList: onToggleList,
            onCreate: onCreate,
            onEdit: onEdit,
            onContacts: onContacts,
            onToggleSync: onToggleSync,
            onToggleActive: onToggleActive,
            onDelete: onDelete,
          );
        }
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
                    final width = math.max(
                      constraints.maxWidth,
                      _minTableWidth,
                    );
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
                                          selected: selectedIds.contains(
                                            list.id,
                                          ),
                                          onToggle: () => onToggleList(list.id),
                                          onEdit: () => onEdit(list),
                                          onContacts: () => onContacts(list),
                                          onToggleSync: () =>
                                              onToggleSync(list),
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
      },
    );
  }
}

class _ContactListsMobileView extends StatelessWidget {
  const _ContactListsMobileView({
    required this.lists,
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.searchController,
    required this.searchQuery,
    required this.selectedIds,
    required this.onSearchChanged,
    required this.onPageChanged,
    required this.onToggleList,
    required this.onCreate,
    required this.onEdit,
    required this.onContacts,
    required this.onToggleSync,
    required this.onToggleActive,
    required this.onDelete,
  });

  final List<AdminContactList> lists;
  final int page;
  final int pageSize;
  final int totalCount;
  final TextEditingController searchController;
  final String searchQuery;
  final Set<int> selectedIds;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onToggleList;
  final VoidCallback onCreate;
  final ValueChanged<AdminContactList> onEdit;
  final ValueChanged<AdminContactList> onContacts;
  final ValueChanged<AdminContactList> onToggleSync;
  final ValueChanged<AdminContactList> onToggleActive;
  final ValueChanged<AdminContactList> onDelete;

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
          query: searchQuery,
          hintText: context.t('mail.contacts.searchPlaceholder'),
          onSearchChanged: onSearchChanged,
          activeFilterCount: 0,
          onOpenFilters: () {},
          showFilters: false,
        ),
        const SizedBox(height: 12),
        AdminMobilePrimaryButton(
          icon: Symbols.add,
          label: context.t('mail.contacts.newList'),
          fullWidth: true,
          onPressed: onCreate,
        ),
        const SizedBox(height: 14),
        Expanded(
          child: AdminMobileListView(
            loading: false,
            itemCount: lists.length,
            emptyLabel: context.t('mail.contacts.empty'),
            itemBuilder: (context, index) {
              final list = lists[index];
              return _ContactListsMobileCard(
                list: list,
                selected: selectedIds.contains(list.id),
                onToggle: () => onToggleList(list.id),
                onEdit: () => onEdit(list),
                onContacts: () => onContacts(list),
                onToggleSync: () => onToggleSync(list),
                onToggleActive: () => onToggleActive(list),
                onDelete: () => onDelete(list),
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

class _ContactListsMobileCard extends StatelessWidget {
  const _ContactListsMobileCard({
    required this.list,
    required this.selected,
    required this.onToggle,
    required this.onEdit,
    required this.onContacts,
    required this.onToggleSync,
    required this.onToggleActive,
    required this.onDelete,
  });

  final AdminContactList list;
  final bool selected;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onContacts;
  final VoidCallback onToggleSync;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final sourceColor = contactListSourceColor(list.source);

    return AdminMobileCard(
      selected: selected,
      onTap: onToggle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AdminMobileCheckbox(
                value: selected,
                onChanged: (_) => onToggle(),
              ),
              const SizedBox(width: 12),
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: sourceColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(list.source.icon, color: sourceColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      list.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.deepOcean,
                        height: 1.25,
                      ),
                    ),
                    if (list.description.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        list.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: AppColors.support,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              AdminMobileMenuButton(
                actions: [
                  AdminMobileMenuAction(
                    icon: Symbols.group,
                    label: context.t('mail.contacts.action.people'),
                    onTap: onContacts,
                  ),
                  AdminMobileMenuAction(
                    icon: Symbols.edit_square,
                    label: context.t('mail.contacts.action.edit'),
                    onTap: onEdit,
                  ),
                  AdminMobileMenuAction(
                    icon: list.syncEnabled
                        ? Symbols.sync_disabled
                        : Symbols.sync,
                    label: context.t(
                      list.syncEnabled
                          ? 'mail.contacts.action.syncDisable'
                          : 'mail.contacts.action.syncEnable',
                    ),
                    onTap: onToggleSync,
                  ),
                  AdminMobileMenuAction(
                    icon: list.active
                        ? Symbols.visibility_off
                        : Symbols.visibility,
                    label: context.t(
                      list.active
                          ? 'mail.contacts.action.deactivate'
                          : 'mail.contacts.action.activate',
                    ),
                    onTap: onToggleActive,
                  ),
                  AdminMobileMenuAction(
                    icon: Symbols.delete,
                    label: context.t('mail.contacts.action.delete'),
                    danger: true,
                    onTap: onDelete,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              AdminMobileMeta(
                icon: Symbols.group,
                value: '${list.contactCount}',
              ),
              const SizedBox(width: 10),
              AdminMobileChip(
                label: list.syncEnabled
                    ? context.t('mail.contacts.sync.open')
                    : context.t('mail.contacts.sync.closed'),
                color: list.syncEnabled
                    ? AppColors.deepOcean
                    : AppColors.support,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: AppColors.softLine.withValues(alpha: 0.9)),
          const SizedBox(height: 10),
          Row(
            children: [
              AdminMobileStatusPill(
                label: list.active
                    ? context.t('mail.contacts.status.active')
                    : context.t('mail.contacts.status.passive'),
                color: list.active
                    ? const Color(0xFF198754)
                    : AppColors.support,
              ),
              const Spacer(),
              Text(
                formatAdminFullDate(context, list.createdAt),
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
              width: compact ? constraints.maxWidth : 280,
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

  static const _selectWidth = 42.0;
  static const _personWidth = 118.0;
  static const _syncWidth = 116.0;
  static const _statusWidth = 116.0;
  static const _actionsWidth = 76.0;
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

class _ContactListTableRow extends StatelessWidget {
  const _ContactListTableRow({
    required this.list,
    required this.selected,
    required this.onToggle,
    required this.onEdit,
    required this.onContacts,
    required this.onToggleSync,
    required this.onToggleActive,
    required this.onDelete,
  });

  final AdminContactList list;
  final bool selected;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onContacts;
  final VoidCallback onToggleSync;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.softLine.withValues(alpha: 0.86)),
        ),
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
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.22,
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
                onContacts: onContacts,
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
  const _ContactListDialog({
    required this.list,
    required this.subscribersRepository,
  });

  final AdminContactList? list;
  final AdminSubscribersRepository subscribersRepository;

  @override
  State<_ContactListDialog> createState() => _ContactListDialogState();
}

class _ContactListDialogResult {
  const _ContactListDialogResult({
    required this.list,
    required this.importContacts,
    this.importRows,
  });

  final AdminContactList list;
  final bool importContacts;
  final List<AdminContactImportRow>? importRows;
}

class _ContactListDialogState extends State<_ContactListDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _importSearchController;
  late AdminContactImportSource _source;
  late bool _active;
  String? _selectedFileName;
  List<AdminContactImportRow>? _importRows;
  var _readyCount = 0;
  var _nameHasError = false;
  var _importSearchQuery = '';

  List<AdminContactImportRow> get _filteredImportRows {
    final rows = _importRows ?? const <AdminContactImportRow>[];
    final query = _importSearchQuery.trim().toLowerCase();
    if (query.isEmpty) return rows;
    return rows
        .where((row) {
          final haystack =
              '${row.email} ${row.firstName} ${row.lastName} ${row.phone}'
                  .toLowerCase();
          return haystack.contains(query);
        })
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    final list = widget.list;
    _nameController = TextEditingController(text: list?.name ?? '');
    _descriptionController = TextEditingController(
      text: list?.description ?? '',
    );
    _importSearchController = TextEditingController();
    _source = list?.source ?? AdminContactImportSource.csv;
    _active = list?.active ?? true;
    _readyCount = list?.contactCount ?? 0;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _importSearchController.dispose();
    super.dispose();
  }

  void _resetImportSearch() {
    _importSearchController.clear();
    _importSearchQuery = '';
  }

  void _selectSource(AdminContactImportSource source) {
    setState(() {
      _source = source;
      _selectedFileName = null;
      _importRows = null;
      _readyCount = widget.list?.source == source
          ? widget.list?.contactCount ?? 0
          : 0;
      _resetImportSearch();
    });
  }

  Future<void> _chooseFile() async {
    if (_source == AdminContactImportSource.subscribers) {
      await _chooseSubscribers();
      return;
    }
    try {
      final file = await openFile(
        acceptedTypeGroups: [
          XTypeGroup(
            label: _source == AdminContactImportSource.csv
                ? 'Delimited contacts'
                : 'Excel contacts',
            extensions: _source == AdminContactImportSource.csv
                ? const ['csv', 'txt', 'tsv']
                : const ['xlsx'],
          ),
        ],
      );
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      final rows = _source == AdminContactImportSource.csv
          ? AdminContactImportParser.parseCsv(bytes)
          : AdminContactImportParser.parseXlsx(bytes);
      if (!mounted) return;
      setState(() {
        _selectedFileName = file.name;
        _importRows = rows;
        _readyCount = rows.length;
        _resetImportSearch();
      });
    } catch (error) {
      if (!mounted) return;
      AdminToast.show(
        context,
        message: error.toString(),
        tone: AdminToastTone.error,
      );
    }
  }

  Future<void> _downloadSample(AdminContactImportSource source) async {
    if (source == AdminContactImportSource.subscribers) return;
    final csvSource = source == AdminContactImportSource.csv;
    final fileName = csvSource
        ? 'pateez-kisi-listesi-ornegi.csv'
        : 'pateez-kisi-listesi-ornegi.xlsx';
    final bytes = csvSource
        ? AdminContactImportParser.sampleCsvBytes()
        : AdminContactImportParser.sampleXlsxBytes();
    final mimeType = csvSource
        ? 'text/csv'
        : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    try {
      final location = await getSaveLocation(
        suggestedName: fileName,
        acceptedTypeGroups: [
          XTypeGroup(
            label: csvSource ? 'CSV' : 'Excel',
            extensions: [csvSource ? 'csv' : 'xlsx'],
            mimeTypes: [mimeType],
          ),
        ],
      );
      if (location == null) return;
      await XFile.fromData(
        bytes,
        mimeType: mimeType,
        name: fileName,
      ).saveTo(location.path);
      if (!mounted) return;
      AdminToast.show(
        context,
        message: context.t('mail.contacts.dialog.sampleDownloaded'),
        tone: AdminToastTone.success,
      );
    } catch (error) {
      if (!mounted) return;
      AdminToast.show(
        context,
        message: error.toString(),
        tone: AdminToastTone.error,
      );
    }
  }

  Future<void> _chooseSubscribers() async {
    final size = MediaQuery.sizeOf(context);
    final rows = await showDialog<List<AdminContactImportRow>>(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: SizedBox(
          width: (size.width - 48).clamp(640.0, 980.0).toDouble(),
          height: (size.height - 48).clamp(560.0, 760.0).toDouble(),
          child: _SubscriberPickerDialog(
            repository: widget.subscribersRepository,
          ),
        ),
      ),
    );
    if (rows == null || !mounted) return;
    setState(() {
      _importRows = rows;
      _readyCount = rows.length;
      _selectedFileName = context.t(
        'mail.contacts.dialog.subscribersSelectedCount',
        values: {'count': rows.length},
      );
      _resetImportSearch();
    });
  }

  void _onImportSearchChanged(String value) {
    setState(() => _importSearchQuery = value);
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
      _ContactListDialogResult(
        importContacts: importContacts && (_importRows?.isNotEmpty ?? false),
        importRows: _importRows,
        list: AdminContactList(
          id: existing?.id ?? DateTime.now().millisecondsSinceEpoch,
          name: name,
          description: _descriptionController.text.trim(),
          contactCount: contactCount,
          syncEnabled: existing?.syncEnabled ?? false,
          active: _active,
          createdAt: existing?.createdAt ?? DateTime.now(),
          source: _source,
        ),
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
                                    rows: _filteredImportRows,
                                    previewRowsLoaded: _importRows != null,
                                    searchController: _importSearchController,
                                    onSearchChanged: _onImportSearchChanged,
                                    onChooseFile: _chooseFile,
                                    onDownloadSample: _downloadSample,
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
                                        rows: _filteredImportRows,
                                        previewRowsLoaded: _importRows != null,
                                        searchController:
                                            _importSearchController,
                                        onSearchChanged: _onImportSearchChanged,
                                        onChooseFile: _chooseFile,
                                        onDownloadSample: _downloadSample,
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
      icon: Symbols.badge_outlined,
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
    required this.rows,
    required this.previewRowsLoaded,
    required this.searchController,
    required this.onSearchChanged,
    required this.onChooseFile,
    required this.onDownloadSample,
  });

  final AdminContactImportSource source;
  final String? selectedFileName;
  final int readyCount;
  final List<AdminContactImportRow> rows;
  final bool previewRowsLoaded;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onChooseFile;
  final ValueChanged<AdminContactImportSource> onDownloadSample;

  @override
  Widget build(BuildContext context) {
    final sourceShort = context.t(source.shortLabelKey);
    final subscribers = source == AdminContactImportSource.subscribers;
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
                      context.t(switch (source) {
                        AdminContactImportSource.csv =>
                          'mail.contacts.dialog.csvTitle',
                        AdminContactImportSource.excel =>
                          'mail.contacts.dialog.excelTitle',
                        AdminContactImportSource.subscribers =>
                          'mail.contacts.dialog.subscribersTitle',
                      }),
                      style: const TextStyle(
                        color: AppColors.deepOcean,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.t(switch (source) {
                        AdminContactImportSource.csv =>
                          'mail.contacts.dialog.csvSubtitle',
                        AdminContactImportSource.excel =>
                          'mail.contacts.dialog.excelSubtitle',
                        AdminContactImportSource.subscribers =>
                          'mail.contacts.dialog.subscribersSubtitle',
                      }),
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
          const SizedBox(height: 18),
          if (!subscribers)
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _SoftActionButton(
                  icon: Symbols.download,
                  label: context.t('mail.contacts.dialog.downloadCsvSample'),
                  selected: source == AdminContactImportSource.csv,
                  onPressed: () =>
                      onDownloadSample(AdminContactImportSource.csv),
                ),
                _SoftActionButton(
                  icon: Symbols.download,
                  label: context.t('mail.contacts.dialog.downloadExcelSample'),
                  selected: source == AdminContactImportSource.excel,
                  onPressed: () =>
                      onDownloadSample(AdminContactImportSource.excel),
                ),
              ],
            ),
          SizedBox(height: subscribers ? 82 : 58),
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
                  child: SymbolIcon(
                    subscribers ? Symbols.groups_outlined : Symbols.upload,
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
                        context.t(switch (source) {
                          AdminContactImportSource.csv =>
                            'mail.contacts.dialog.csvUploadTitle',
                          AdminContactImportSource.excel =>
                            'mail.contacts.dialog.excelUploadTitle',
                          AdminContactImportSource.subscribers =>
                            'mail.contacts.dialog.subscribersSelectTitle',
                        }),
                        style: const TextStyle(
                          color: AppColors.deepOcean,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        selectedFileName ??
                            context.t(switch (source) {
                              AdminContactImportSource.csv =>
                                'mail.contacts.dialog.csvUploadSubtitle',
                              AdminContactImportSource.excel =>
                                'mail.contacts.dialog.excelUploadSubtitle',
                              AdminContactImportSource.subscribers =>
                                'mail.contacts.dialog.subscribersSelectSubtitle',
                            }),
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
                  icon: subscribers
                      ? Symbols.group_outlined
                      : Symbols.folder_open,
                  label: context.t(
                    subscribers
                        ? 'mail.contacts.dialog.chooseSubscribers'
                        : 'mail.contacts.dialog.chooseFile',
                  ),
                  onPressed: onChooseFile,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (readyCount > 0)
            Row(
              children: [
                _StatusBadge(
                  label: context.t(
                    'mail.contacts.dialog.fileReady',
                    values: {'count': readyCount},
                  ),
                  color: const Color(0xFF198754),
                ),
                if (previewRowsLoaded) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ImportSearchField(
                      controller: searchController,
                      onChanged: onSearchChanged,
                    ),
                  ),
                ],
              ],
            ),
          const SizedBox(height: 10),
          _ExampleTable(
            rows: rows,
            readyCount: readyCount,
            previewRowsLoaded: previewRowsLoaded,
          ),
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
    final subscribers = source == AdminContactImportSource.subscribers;
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
                Symbols.lightbulb_outline,
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
          if (subscribers) ...[
            _RuleText(
              label: context.t('mail.contacts.dialog.ruleSubscribersActive'),
            ),
            _RuleText(
              label: context.t('mail.contacts.dialog.ruleSubscribersSelect'),
            ),
            _RuleText(label: context.t('mail.contacts.dialog.ruleDuplicate')),
            _RuleText(
              label: context.t('mail.contacts.dialog.ruleSubscribersCopy'),
            ),
          ] else ...[
            _RuleText(label: context.t('mail.contacts.dialog.ruleHeader')),
            _RuleText(label: context.t('mail.contacts.dialog.ruleEmail')),
            _RuleText(label: context.t('mail.contacts.dialog.ruleDuplicate')),
            _RuleText(label: context.t('mail.contacts.dialog.ruleUtf')),
          ],
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
                      context.t(switch (source) {
                        AdminContactImportSource.csv =>
                          'mail.contacts.dialog.csvFile',
                        AdminContactImportSource.excel =>
                          'mail.contacts.dialog.excelFile',
                        AdminContactImportSource.subscribers =>
                          'mail.contacts.dialog.subscribersFile',
                      }),
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
                      context.t(switch (source) {
                        AdminContactImportSource.csv =>
                          'mail.contacts.dialog.csvFileSubtitle',
                        AdminContactImportSource.excel =>
                          'mail.contacts.dialog.excelFileSubtitle',
                        AdminContactImportSource.subscribers =>
                          'mail.contacts.dialog.subscribersFileSubtitle',
                      }),
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
      context.t(
        source == AdminContactImportSource.subscribers
            ? 'mail.contacts.dialog.subscribersStep'
            : 'mail.contacts.dialog.file',
      ),
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
              Symbols.chevron_right,
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

class _ImportSearchField extends StatelessWidget {
  const _ImportSearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          final hasText = value.text.trim().isNotEmpty;
          return TextField(
            controller: controller,
            onChanged: onChanged,
            mouseCursor: SystemMouseCursors.text,
            cursorColor: AppColors.support,
            textAlignVertical: TextAlignVertical.center,
            style: const TextStyle(
              color: AppColors.deepOcean,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 0,
            ),
            decoration: InputDecoration(
              hintText: context.t('mail.contacts.searchPlaceholder'),
              hintStyle: const TextStyle(
                color: AppColors.placeholder,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 0,
              ),
              filled: true,
              fillColor: Colors.white,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
              prefixIcon: const Padding(
                padding: EdgeInsets.only(left: 9, right: 7),
                child: SymbolIcon(
                  Symbols.search,
                  color: AppColors.iconMuted,
                  size: 16,
                ),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 32),
              suffixIcon: hasText
                  ? IconButton(
                      tooltip: context.t('common.close'),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        controller.clear();
                        onChanged('');
                      },
                      icon: const SymbolIcon(
                        Symbols.close,
                        color: AppColors.iconMuted,
                        size: 15,
                      ),
                    )
                  : null,
              suffixIconConstraints: const BoxConstraints(
                minWidth: 30,
                minHeight: 30,
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
        },
      ),
    );
  }
}

class _ExampleTable extends StatefulWidget {
  const _ExampleTable({
    required this.rows,
    required this.readyCount,
    required this.previewRowsLoaded,
  });

  final List<AdminContactImportRow> rows;
  final int readyCount;
  final bool previewRowsLoaded;

  @override
  State<_ExampleTable> createState() => _ExampleTableState();
}

class _ExampleTableState extends State<_ExampleTable> {
  static const _rowHeight = 36.0;
  static const _bodyHeight = 152.0;

  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final headers = [
      context.t('mail.contacts.example.email'),
      context.t('mail.contacts.example.firstName'),
      context.t('mail.contacts.example.lastName'),
      context.t('mail.contacts.example.phone'),
    ];
    final showPreviewRows = widget.previewRowsLoaded && widget.readyCount > 0;
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
          if (showPreviewRows)
            SizedBox(
              height: _bodyHeight,
              child: widget.rows.isEmpty
                  ? Center(
                      child: Text(
                        context.t('mail.contacts.people.empty'),
                        style: const TextStyle(
                          color: AppColors.inkSoft,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                        ),
                      ),
                    )
                  : Scrollbar(
                      controller: _scrollController,
                      thumbVisibility:
                          widget.rows.length * _rowHeight > _bodyHeight,
                      child: ListView.separated(
                        controller: _scrollController,
                        padding: EdgeInsets.zero,
                        itemCount: widget.rows.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1, color: AppColors.line),
                        itemBuilder: (context, index) =>
                            _ExampleTableRow(row: widget.rows[index]),
                      ),
                    ),
            ),
        ],
      ),
    );
  }
}

class _ExampleTableRow extends StatelessWidget {
  const _ExampleTableRow({required this.row});

  final AdminContactImportRow row;

  String _value(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? '-' : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _ExampleTableState._rowHeight,
      child: Row(
        children: [
          _ExampleTableCell(text: _value(row.email)),
          _ExampleTableCell(text: _value(row.firstName)),
          _ExampleTableCell(text: _value(row.lastName)),
          _ExampleTableCell(text: _value(row.phone)),
        ],
      ),
    );
  }
}

class _ExampleTableCell extends StatelessWidget {
  const _ExampleTableCell({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Text(
          text,
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
    );
  }
}

class _SubscriberPickerDialog extends StatefulWidget {
  const _SubscriberPickerDialog({required this.repository});

  final AdminSubscribersRepository repository;

  @override
  State<_SubscriberPickerDialog> createState() =>
      _SubscriberPickerDialogState();
}

class _SubscriberPickerDialogState extends State<_SubscriberPickerDialog> {
  static const _subscriberFetchPageSize = 500;

  final _searchController = TextEditingController();
  final _selectedIds = <String>{};
  var _subscribers = const <AdminSubscriber>[];
  var _query = '';
  var _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSubscribers());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSubscribers() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final subscribers = <AdminSubscriber>[];
      var page = 1;
      while (mounted) {
        final result = await widget.repository.fetchSubscribers(
          search: '',
          page: page,
          pageSize: _subscriberFetchPageSize,
          sortKey: 'date',
          sortAscending: false,
        );
        subscribers.addAll(result.subscribers);
        if (result.subscribers.length < _subscriberFetchPageSize ||
            subscribers.length >= result.totalCount) {
          break;
        }
        page += 1;
      }
      if (!mounted) return;
      setState(() {
        _subscribers = subscribers;
        _selectedIds
          ..clear()
          ..addAll(
            subscribers
                .where((subscriber) => subscriber.active)
                .map((subscriber) => subscriber.id),
          );
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  List<AdminSubscriber> get _visibleSubscribers {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _subscribers;
    return _subscribers
        .where((subscriber) {
          final haystack = [
            subscriber.fullName,
            subscriber.email,
            subscriber.phone,
            subscriber.city,
            subscriber.source,
          ].join(' ').toLowerCase();
          return haystack.contains(query);
        })
        .toList(growable: false);
  }

  Set<String> get _activeVisibleIds => _visibleSubscribers
      .where((subscriber) => subscriber.active)
      .map((subscriber) => subscriber.id)
      .toSet();

  void _changeSearch(String value) {
    setState(() => _query = value);
  }

  void _toggleSubscriber(AdminSubscriber subscriber) {
    if (!subscriber.active) return;
    setState(() {
      if (_selectedIds.contains(subscriber.id)) {
        _selectedIds.remove(subscriber.id);
      } else {
        _selectedIds.add(subscriber.id);
      }
    });
  }

  void _toggleAllVisible() {
    final ids = _activeVisibleIds;
    if (ids.isEmpty) return;
    setState(() {
      if (_selectedIds.containsAll(ids)) {
        _selectedIds.removeAll(ids);
      } else {
        _selectedIds.addAll(ids);
      }
    });
  }

  void _submit() {
    final rows = _subscribers
        .where(
          (subscriber) =>
              subscriber.active && _selectedIds.contains(subscriber.id),
        )
        .map(_rowFromSubscriber)
        .toList(growable: false);
    Navigator.of(context).pop(rows);
  }

  AdminContactImportRow _rowFromSubscriber(AdminSubscriber subscriber) {
    final parts = subscriber.fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    return AdminContactImportRow(
      email: subscriber.email.trim().toLowerCase(),
      firstName: parts.isEmpty ? '' : parts.first,
      lastName: parts.length < 2 ? '' : parts.skip(1).join(' '),
      phone: subscriber.phone.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleSubscribers;
    final activeVisibleIds = _activeVisibleIds;
    final allVisibleSelected =
        activeVisibleIds.isNotEmpty &&
        _selectedIds.containsAll(activeVisibleIds);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.value),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.value),
                  ),
                  child: const SymbolIcon(
                    Symbols.groups_outlined,
                    color: Color(0xFF2563EB),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.t('mail.contacts.subscribersPicker.title'),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppColors.deepOcean,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        context.t('mail.contacts.subscribersPicker.subtitle'),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
            child: Row(
              children: [
                Expanded(
                  child: _SearchField(
                    controller: _searchController,
                    query: _query,
                    hint: context.t('mail.contacts.subscribersPicker.search'),
                    onChanged: _changeSearch,
                  ),
                ),
                const SizedBox(width: 12),
                _SecondaryActionButton(
                  icon: allVisibleSelected ? Symbols.close : Symbols.check,
                  label: context.t(
                    allVisibleSelected
                        ? 'mail.contacts.subscribersPicker.clearVisible'
                        : 'mail.contacts.subscribersPicker.selectAll',
                  ),
                  onPressed: _toggleAllVisible,
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.line),
                  borderRadius: BorderRadius.circular(AppRadius.value),
                ),
                clipBehavior: Clip.antiAlias,
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                    ? _SubscriberPickerError(
                        message: _error!,
                        onRetry: _loadSubscribers,
                      )
                    : visible.isEmpty
                    ? Center(
                        child: Text(
                          context.t('mail.contacts.subscribersPicker.empty'),
                          style: const TextStyle(
                            color: AppColors.support,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: visible.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1, color: AppColors.line),
                        itemBuilder: (context, index) {
                          final subscriber = visible[index];
                          return _SubscriberPickerRow(
                            subscriber: subscriber,
                            selected: _selectedIds.contains(subscriber.id),
                            onTap: () => _toggleSubscriber(subscriber),
                          );
                        },
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.t(
                      'mail.contacts.subscribersPicker.selectedCount',
                      values: {'count': _selectedIds.length},
                    ),
                    style: const TextStyle(
                      color: AppColors.deepOcean,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                _TextOnlyButton(
                  label: context.t('common.cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 10),
                _PrimaryActionButton(
                  icon: Symbols.check,
                  label: context.t('mail.contacts.subscribersPicker.confirm'),
                  backgroundColor: AppColors.deepOcean,
                  onPressed: _selectedIds.isEmpty ? null : _submit,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SubscriberPickerRow extends StatelessWidget {
  const _SubscriberPickerRow({
    required this.subscriber,
    required this.selected,
    required this.onTap,
  });

  final AdminSubscriber subscriber;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = subscriber.active;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: Container(
          color: selected
              ? AppColors.deepOcean.withValues(alpha: 0.04)
              : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              _SelectionBox(selected: selected, enabled: enabled),
              const SizedBox(width: 14),
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.value),
                ),
                child: Text(
                  subscriber.initials,
                  style: const TextStyle(
                    color: AppColors.deepOcean,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 4,
                child: Text(
                  subscriber.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: enabled ? AppColors.deepOcean : AppColors.support,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ),
              Expanded(
                flex: 5,
                child: Text(
                  subscriber.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.inkSoft,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (subscriber.phone.trim().isNotEmpty)
                Expanded(
                  flex: 3,
                  child: Text(
                    subscriber.phone,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.inkSoft,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0,
                    ),
                  ),
                )
              else
                const Spacer(flex: 3),
              const SizedBox(width: 12),
              _StatusBadge(
                label: context.t(
                  enabled
                      ? 'mail.contacts.status.active'
                      : 'mail.contacts.status.passive',
                ),
                color: enabled ? const Color(0xFF198754) : AppColors.support,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionBox extends StatelessWidget {
  const _SelectionBox({required this.selected, required this.enabled});

  final bool selected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: selected ? AppColors.deepOcean : Colors.white,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: selected
              ? AppColors.deepOcean
              : enabled
              ? AppColors.line
              : AppColors.softLine,
        ),
      ),
      child: selected
          ? const SymbolIcon(Symbols.check, color: Colors.white, size: 14)
          : null,
    );
  }
}

class _SubscriberPickerError extends StatelessWidget {
  const _SubscriberPickerError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.actionRed,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 12),
            _SecondaryActionButton(
              icon: Symbols.refresh,
              label: context.t('common.retry'),
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactListRowMenu extends StatefulWidget {
  const _ContactListRowMenu({
    required this.list,
    required this.onEdit,
    required this.onContacts,
    required this.onToggleSync,
    required this.onToggleActive,
    required this.onDelete,
  });

  final AdminContactList list;
  final VoidCallback onEdit;
  final VoidCallback onContacts;
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
              onContacts: () => _tap(widget.onContacts),
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
    required this.onContacts,
    required this.onToggleSync,
    required this.onToggleActive,
    required this.onDelete,
  });

  final AdminContactList list;
  final VoidCallback onEdit;
  final VoidCallback onContacts;
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
              icon: Symbols.group,
              label: 'mail.contacts.action.people',
              onTap: onContacts,
            ),
            _MenuItem(
              icon: Symbols.edit_square,
              label: 'mail.contacts.action.edit',
              onTap: onEdit,
            ),
            _MenuItem(
              icon: list.syncEnabled ? Symbols.sync_disabled : Symbols.sync,
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

class _SoftActionButton extends StatelessWidget {
  const _SoftActionButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: selected
              ? AppColors.deepOcean.withValues(alpha: 0.08)
              : AppColors.surface,
          foregroundColor: AppColors.deepOcean,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.value),
            side: BorderSide(
              color: selected ? AppColors.deepOcean : AppColors.line,
            ),
          ),
          textStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SymbolIcon(icon, color: AppColors.deepOcean, size: 16),
            const SizedBox(width: 7),
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
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
    this.backgroundColor = AppColors.actionRed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: TextButton(
        onPressed: onPressed,
        style:
            TextButton.styleFrom(
              backgroundColor: onPressed == null
                  ? AppColors.softLine
                  : backgroundColor,
              foregroundColor: onPressed == null
                  ? AppColors.support
                  : Colors.white,
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

    final rangeText = context.t(
      'common.recordRange',
      values: {'from': start, 'to': end, 'total': totalCount},
    );

    return LayoutBuilder(
      builder: (context, constraints) {
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
          page: page,
          totalPages: totalPages,
          onPageChanged: onPageChanged,
        );

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
    required this.page,
    required this.totalPages,
    required this.onPageChanged,
  });

  final int page;
  final int totalPages;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return AdminTablePagination(
      page: page,
      pageCount: totalPages,
      onPageChanged: onPageChanged,
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
