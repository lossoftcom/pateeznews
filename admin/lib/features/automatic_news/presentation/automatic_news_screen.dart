import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pateeznews_admin/features/automatic_news/data/admin_automatic_news_repository.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/data/admin_image_url.dart';
import '../../../shared/widgets/admin_cached_image.dart';
import '../../../shared/widgets/app_confirmation_dialog.dart';
import '../../../shared/widgets/admin_table_chrome.dart';
import '../../../shared/widgets/sortable_table_header.dart';
import '../../../shared/widgets/symbol_icon.dart';

class AutomaticNewsScreen extends StatefulWidget {
  const AutomaticNewsScreen({
    super.key,
    this.repository = const SupabaseAdminAutomaticNewsRepository(),
  });

  final AdminAutomaticNewsRepository repository;

  @override
  State<AutomaticNewsScreen> createState() => _AutomaticNewsScreenState();
}

class _AutomaticNewsScreenState extends State<AutomaticNewsScreen> {
  static const _all = 'Tümü';

  final _searchController = TextEditingController();
  final _selectedDraftIds = <int>{};

  var _drafts = const <_AutomaticNewsDraft>[];
  var _sources = const <AutomaticNewsSource>[];
  var _totalCount = 0;
  var _loading = true;
  var _errorMessage = '';
  var _platformFilter = _all;
  var _categoryFilter = _all;
  var _statusFilter = _all;
  var _languageFilter = _all;
  var _page = 1;
  var _pageSize = 25;
  var _searchQuery = '';
  var _sortState = const TableSortState(key: 'date', ascending: false);

  @override
  void initState() {
    super.initState();
    unawaited(_loadInitial());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_AutomaticNewsDraft> get _pagedDrafts => _drafts;

  int get _pageCount {
    final total = _totalCount;
    if (total == 0) return 1;
    return ((total - 1) ~/ _pageSize) + 1;
  }

  Future<void> _loadInitial() async {
    await Future.wait([_loadSources(), _loadItems(showLoading: true)]);
  }

  Future<void> _loadSources() async {
    try {
      final sources = await widget.repository.fetchSources();
      if (!mounted) return;
      setState(() {
        _sources = sources;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.toString());
    }
  }

  Future<void> _loadItems({bool showLoading = false}) async {
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _errorMessage = '';
      });
    }
    try {
      final result = await widget.repository.fetchItems(
        search: _searchQuery,
        platform: _platformFilter,
        category: _categoryFilter,
        status: _statusFilter,
        language: _languageFilter,
        page: _page,
        pageSize: _pageSize,
        sortKey: _sortState.key,
        sortAscending: _sortState.ascending,
      );
      if (!mounted) return;
      setState(() {
        _drafts = [
          for (final item in result.items) _AutomaticNewsDraft.fromItem(item),
        ];
        _totalCount = result.totalCount;
        _loading = false;
        _errorMessage = '';
        _selectedDraftIds.clear();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = error.toString();
      });
    }
  }

  void _resetPageAndSelection() {
    _page = 1;
    _selectedDraftIds.clear();
  }

  void _changeSearch(String value) {
    setState(() {
      _searchQuery = value;
      _resetPageAndSelection();
    });
    unawaited(_loadItems());
  }

  void _changeFilter({
    String? platform,
    String? category,
    String? status,
    String? language,
  }) {
    setState(() {
      if (platform != null) _platformFilter = platform;
      if (category != null) _categoryFilter = category;
      if (status != null) _statusFilter = status;
      if (language != null) _languageFilter = language;
      _resetPageAndSelection();
    });
    unawaited(_loadItems());
  }

  void _changePageSize(int? value) {
    if (value == null || value == _pageSize) return;
    setState(() {
      _pageSize = value;
      _resetPageAndSelection();
    });
    unawaited(_loadItems(showLoading: true));
  }

  void _changePage(int page) {
    if (page == _page || page < 1 || page > _pageCount) return;
    setState(() {
      _page = page;
      _selectedDraftIds.clear();
    });
    unawaited(_loadItems(showLoading: true));
  }

  void _changeSort(String sortKey) {
    setState(() {
      _sortState = _sortState.toggled(sortKey);
      _selectedDraftIds.clear();
    });
    unawaited(_loadItems(showLoading: true));
  }

  void _toggleDraft(int id) {
    setState(() {
      if (!_selectedDraftIds.remove(id)) {
        _selectedDraftIds.add(id);
      }
    });
  }

  void _toggleVisibleDrafts() {
    final rows = _pagedDrafts;
    final visibleIds = rows.map((draft) => draft.id).toSet();
    setState(() {
      if (visibleIds.isNotEmpty && _selectedDraftIds.containsAll(visibleIds)) {
        _selectedDraftIds.removeAll(visibleIds);
      } else {
        _selectedDraftIds.addAll(visibleIds);
      }
    });
  }

  Future<void> _deleteDrafts(List<_AutomaticNewsDraft> drafts) async {
    if (drafts.isEmpty) return;
    final count = drafts.length;
    final confirmed = await showAppConfirmationDialog(
      context,
      title: count == 1 ? 'Haber silinsin mi?' : 'Seçili haberler silinsin mi?',
      message: count == 1
          ? 'Bu otomatik haber silinecek.'
          : '$count otomatik haber silinecek.',
      confirmLabel: 'Sil',
      danger: true,
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _loading = true;
      _errorMessage = '';
    });
    try {
      await widget.repository.deleteItems(
        drafts.map((draft) => draft.recordId).toList(growable: false),
      );
      if (!mounted) return;
      _selectedDraftIds.removeAll(drafts.map((draft) => draft.id));
      if (drafts.length >= _pagedDrafts.length && _page > 1) {
        _page -= 1;
      }
      await _loadItems();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = error.toString();
      });
    }
  }

  Future<void> _deleteSelectedDrafts() async {
    final selected = _pagedDrafts
        .where((draft) => _selectedDraftIds.contains(draft.id))
        .toList(growable: false);
    await _deleteDrafts(selected);
  }

  Future<void> _deleteDraft(_AutomaticNewsDraft draft) async {
    await _deleteDrafts([draft]);
  }

  Future<void> _openSourceDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => _AutomaticNewsSourceDialog(
        initialSources: _sources,
        onSaveSources: (urls) async {
          final saved = await widget.repository.saveSources(urls);
          await _loadSources();
          return saved;
        },
        onTestSources: () async {
          final result = await widget.repository.testSources();
          final sources = await widget.repository.fetchSources();
          if (mounted) {
            setState(() {
              _sources = sources;
            });
          }
          await _loadItems();
          return _AutomaticNewsSourceTestPayload(
            result: result,
            sources: sources,
          );
        },
        onToggleSource: (source, value) async {
          final updated = await widget.repository.setSourceActive(
            id: source.id,
            isActive: value,
          );
          await _loadSources();
          return updated;
        },
      ),
    );
    unawaited(_loadSources());
  }

  void _showDraftPreview(_AutomaticNewsDraft draft) {
    showDialog<void>(
      context: context,
      barrierColor: const Color(0xB20D1B24),
      builder: (context) => _AutomaticNewsPreviewDialog(draft: draft),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 640 ? 16.0 : 28.0;
        final mobile = constraints.maxWidth < 800;
        final compact = constraints.maxWidth < 900;

        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _AutomaticNewsTitle(),
            SizedBox(height: mobile ? 14 : 20),
            if (_errorMessage.isNotEmpty) ...[
              _AutomaticNewsErrorBanner(message: _errorMessage),
              const SizedBox(height: 14),
            ],
            Expanded(
              child: _AutomaticNewsTableCard(
                drafts: _pagedDrafts,
                totalCount: _totalCount,
                page: _page,
                pageCount: _pageCount,
                pageSize: _pageSize,
                loading: _loading,
                refreshing: _loading,
                searchController: _searchController,
                searchQuery: _searchQuery,
                selectedDraftIds: _selectedDraftIds,
                platformFilter: _platformFilter,
                categoryFilter: _categoryFilter,
                statusFilter: _statusFilter,
                languageFilter: _languageFilter,
                sortState: _sortState,
                onPageSizeChanged: _changePageSize,
                onSearchChanged: _changeSearch,
                onPlatformChanged: (value) => _changeFilter(platform: value),
                onCategoryChanged: (value) => _changeFilter(category: value),
                onStatusChanged: (value) => _changeFilter(status: value),
                onLanguageChanged: (value) => _changeFilter(language: value),
                onPageChanged: _changePage,
                onSort: _changeSort,
                onToggleDraft: _toggleDraft,
                onToggleVisibleDrafts: _toggleVisibleDrafts,
                onDeleteSelected: () => unawaited(_deleteSelectedDrafts()),
                onRefresh: () => unawaited(_loadItems(showLoading: true)),
                onOpenSources: _openSourceDialog,
                onViewDraft: _showDraftPreview,
                onDeleteDraft: (draft) => unawaited(_deleteDraft(draft)),
              ),
            ),
          ],
        );

        if (mobile) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              18,
              horizontalPadding,
              28,
            ),
            child: content,
          );
        }

        if (compact) {
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              28,
              horizontalPadding,
              28,
            ),
            child: SizedBox(height: 980, child: content),
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

class _AutomaticNewsTitle extends StatelessWidget {
  const _AutomaticNewsTitle();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Otomatik Haber',
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
        color: AppColors.deepOcean,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
    );
  }
}

class _AutomaticNewsErrorBanner extends StatelessWidget {
  const _AutomaticNewsErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.actionRed.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.actionRed.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          const SymbolIcon(
            Symbols.error_outline,
            color: AppColors.actionRed,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.deepOcean,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactSwitch extends StatelessWidget {
  const _CompactSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: value,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(!value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: 42,
            height: 24,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: value ? AppColors.actionRed : AppColors.softLine,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: value
                    ? AppColors.actionRed
                    : AppColors.line.withValues(alpha: 0.9),
              ),
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOut,
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.deepOcean.withValues(alpha: 0.12),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ControlLabel extends StatelessWidget {
  const _ControlLabel(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: AppColors.deepOcean,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
    );
  }
}

class _AutomaticNewsTableCard extends StatelessWidget {
  const _AutomaticNewsTableCard({
    required this.drafts,
    required this.totalCount,
    required this.page,
    required this.pageCount,
    required this.pageSize,
    required this.loading,
    required this.refreshing,
    required this.searchController,
    required this.searchQuery,
    required this.selectedDraftIds,
    required this.platformFilter,
    required this.categoryFilter,
    required this.statusFilter,
    required this.languageFilter,
    required this.sortState,
    required this.onPageSizeChanged,
    required this.onSearchChanged,
    required this.onPlatformChanged,
    required this.onCategoryChanged,
    required this.onStatusChanged,
    required this.onLanguageChanged,
    required this.onPageChanged,
    required this.onSort,
    required this.onToggleDraft,
    required this.onToggleVisibleDrafts,
    required this.onDeleteSelected,
    required this.onRefresh,
    required this.onOpenSources,
    required this.onViewDraft,
    required this.onDeleteDraft,
  });

  final List<_AutomaticNewsDraft> drafts;
  final int totalCount;
  final int page;
  final int pageCount;
  final int pageSize;
  final bool loading;
  final bool refreshing;
  final TextEditingController searchController;
  final String searchQuery;
  final Set<int> selectedDraftIds;
  final String platformFilter;
  final String categoryFilter;
  final String statusFilter;
  final String languageFilter;
  final TableSortState sortState;
  final ValueChanged<int?> onPageSizeChanged;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onPlatformChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onLanguageChanged;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<String> onSort;
  final ValueChanged<int> onToggleDraft;
  final VoidCallback onToggleVisibleDrafts;
  final VoidCallback onDeleteSelected;
  final VoidCallback onRefresh;
  final VoidCallback onOpenSources;
  final ValueChanged<_AutomaticNewsDraft> onViewDraft;
  final ValueChanged<_AutomaticNewsDraft> onDeleteDraft;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AutomaticNewsFilters(
              platformFilter: platformFilter,
              categoryFilter: categoryFilter,
              statusFilter: statusFilter,
              languageFilter: languageFilter,
              onPlatformChanged: onPlatformChanged,
              onCategoryChanged: onCategoryChanged,
              onStatusChanged: onStatusChanged,
              onLanguageChanged: onLanguageChanged,
            ),
            const SizedBox(height: 28),
            _AutomaticNewsToolbar(
              compact: compact,
              pageSize: pageSize,
              searchController: searchController,
              searchQuery: searchQuery,
              selectedCount: selectedDraftIds.length,
              refreshing: refreshing,
              onPageSizeChanged: onPageSizeChanged,
              onSearchChanged: onSearchChanged,
              onDeleteSelected: onDeleteSelected,
              onRefresh: onRefresh,
              onOpenSources: onOpenSources,
            ),
            const SizedBox(height: 18),
            Expanded(
              child: _AutomaticNewsDataTable(
                drafts: drafts,
                loading: loading,
                selectedDraftIds: selectedDraftIds,
                sortState: sortState,
                onSort: onSort,
                onToggleDraft: onToggleDraft,
                onToggleVisibleDrafts: onToggleVisibleDrafts,
                onViewDraft: onViewDraft,
                onDeleteDraft: onDeleteDraft,
              ),
            ),
            const SizedBox(height: 16),
            _AutomaticNewsFooter(
              page: page,
              pageSize: pageSize,
              totalCount: totalCount,
              pageCount: pageCount,
              onPageChanged: onPageChanged,
            ),
          ],
        );
      },
    );
  }
}

class _AutomaticNewsFilters extends StatelessWidget {
  const _AutomaticNewsFilters({
    required this.platformFilter,
    required this.categoryFilter,
    required this.statusFilter,
    required this.languageFilter,
    required this.onPlatformChanged,
    required this.onCategoryChanged,
    required this.onStatusChanged,
    required this.onLanguageChanged,
  });

  final String platformFilter;
  final String categoryFilter;
  final String statusFilter;
  final String languageFilter;
  final ValueChanged<String?> onPlatformChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onLanguageChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 1040;
        final filters = [
          _FilterSelect(
            label: 'Platform',
            value: platformFilter,
            items: _filterItems(_platforms),
            onChanged: onPlatformChanged,
          ),
          _FilterSelect(
            label: 'Kategori',
            value: categoryFilter,
            items: _filterItems(_categories),
            onChanged: onCategoryChanged,
          ),
          _FilterSelect(
            label: 'Durum',
            value: statusFilter,
            items: _filterItems(_statuses),
            onChanged: onStatusChanged,
          ),
          _FilterSelect(
            label: 'Dil',
            value: languageFilter,
            items: _filterItems(_languages),
            onChanged: onLanguageChanged,
          ),
        ];

        if (compact) {
          return Wrap(
            spacing: 16,
            runSpacing: 14,
            children: [
              for (final filter in filters)
                SizedBox(
                  width: constraints.maxWidth < 560
                      ? constraints.maxWidth
                      : (constraints.maxWidth - 16) / 2,
                  child: filter,
                ),
            ],
          );
        }

        return Row(
          children: [
            for (var index = 0; index < filters.length; index++) ...[
              Expanded(child: filters[index]),
              if (index != filters.length - 1) const SizedBox(width: 16),
            ],
          ],
        );
      },
    );
  }

  List<DropdownMenuItem<String>> _filterItems(List<String> values) {
    return [
      const DropdownMenuItem(value: 'Tümü', child: Text('Tümü')),
      for (final value in values)
        DropdownMenuItem(value: value, child: Text(value)),
    ];
  }
}

class _FilterSelect extends StatelessWidget {
  const _FilterSelect({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final safeValue = items.any((item) => item.value == value)
        ? value
        : (items.isEmpty ? null : items.first.value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ControlLabel(label),
        const SizedBox(height: 8),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            height: AdminTableChrome.toolbarHeight,
            padding: const EdgeInsets.only(left: 12, right: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.value),
              border: Border.all(color: AppColors.line.withValues(alpha: 0.72)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: safeValue,
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
                items: items,
                onChanged: onChanged,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AutomaticNewsToolbar extends StatelessWidget {
  const _AutomaticNewsToolbar({
    required this.compact,
    required this.pageSize,
    required this.searchController,
    required this.searchQuery,
    required this.selectedCount,
    required this.refreshing,
    required this.onPageSizeChanged,
    required this.onSearchChanged,
    required this.onDeleteSelected,
    required this.onRefresh,
    required this.onOpenSources,
  });

  final bool compact;
  final int pageSize;
  final TextEditingController searchController;
  final String searchQuery;
  final int selectedCount;
  final bool refreshing;
  final ValueChanged<int?> onPageSizeChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onDeleteSelected;
  final VoidCallback onRefresh;
  final VoidCallback onOpenSources;

  @override
  Widget build(BuildContext context) {
    final pageSizeSelect = AdminTablePageSizeSelect(
      value: pageSize,
      onChanged: onPageSizeChanged,
    );
    final deleteButton = selectedCount == 0
        ? null
        : AdminTablePrimaryActionButton(
            icon: Symbols.delete,
            label: 'Seçili $selectedCount haberi sil',
            onPressed: onDeleteSelected,
          );
    final search = ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: compact ? double.infinity : 260,
        maxWidth: compact ? double.infinity : 280,
      ),
      child: AdminTableSearchField(
        controller: searchController,
        hintText: 'Search...',
        query: searchQuery,
        showClearButton: true,
        onChanged: onSearchChanged,
      ),
    );
    final refreshButton = AdminTableSecondaryActionButton(
      icon: Symbols.refresh_line,
      label: refreshing ? 'Yenileniyor...' : 'Yenile',
      onPressed: refreshing ? () {} : onRefresh,
    );
    final addressButton = AdminTablePrimaryActionButton(
      icon: Symbols.add,
      label: 'Adres Ekle',
      onPressed: onOpenSources,
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(alignment: Alignment.centerLeft, child: pageSizeSelect),
          if (deleteButton != null) ...[
            const SizedBox(height: 10),
            Align(alignment: Alignment.centerLeft, child: deleteButton),
          ],
          const SizedBox(height: 14),
          search,
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [refreshButton, addressButton],
          ),
        ],
      );
    }

    return Row(
      children: [
        pageSizeSelect,
        if (deleteButton != null) ...[const SizedBox(width: 12), deleteButton],
        const Spacer(),
        search,
        const SizedBox(width: 14),
        refreshButton,
        const SizedBox(width: 10),
        addressButton,
      ],
    );
  }
}

class _AutomaticNewsDataTable extends StatelessWidget {
  const _AutomaticNewsDataTable({
    required this.drafts,
    required this.loading,
    required this.selectedDraftIds,
    required this.sortState,
    required this.onSort,
    required this.onToggleDraft,
    required this.onToggleVisibleDrafts,
    required this.onViewDraft,
    required this.onDeleteDraft,
  });

  final List<_AutomaticNewsDraft> drafts;
  final bool loading;
  final Set<int> selectedDraftIds;
  final TableSortState sortState;
  final ValueChanged<String> onSort;
  final ValueChanged<int> onToggleDraft;
  final VoidCallback onToggleVisibleDrafts;
  final ValueChanged<_AutomaticNewsDraft> onViewDraft;
  final ValueChanged<_AutomaticNewsDraft> onDeleteDraft;

  static const double _selectWidth = 42;
  static const double _idWidth = 62;
  static const double _postMinWidth = 330;
  static const double _sourceWidth = 150;
  static const double _statusWidth = 118;
  static const double _languageWidth = 84;
  static const double _originWidth = 210;
  static const double _qualityWidth = 94;
  static const double _dateWidth = 150;
  static const double _menuWidth = 70;
  static const double _horizontalPadding = 32;
  static const double _tableBorderWidth = 2;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fixedWidth =
            _horizontalPadding +
            _tableBorderWidth +
            _selectWidth +
            _idWidth +
            _sourceWidth +
            _statusWidth +
            _languageWidth +
            _originWidth +
            _qualityWidth +
            _dateWidth +
            _menuWidth;
        final requiredMinWidth = fixedWidth + _postMinWidth;
        final tableWidth = constraints.maxWidth < requiredMinWidth
            ? requiredMinWidth
            : constraints.maxWidth;
        final postWidth = (tableWidth - fixedWidth) < _postMinWidth
            ? _postMinWidth
            : tableWidth - fixedWidth;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: tableWidth,
            height: constraints.hasBoundedHeight ? constraints.maxHeight : null,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.value),
                border: Border.all(
                  color: AppColors.line.withValues(alpha: 0.72),
                ),
              ),
              child: Column(
                children: [
                  _AutomaticNewsHeader(
                    selectedCount: selectedDraftIds.length,
                    totalCount: drafts.length,
                    postWidth: postWidth,
                    sortState: sortState,
                    onToggleVisibleDrafts: onToggleVisibleDrafts,
                    onSort: onSort,
                  ),
                  Expanded(
                    child: loading
                        ? const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: AppColors.actionRed,
                              ),
                            ),
                          )
                        : drafts.isEmpty
                        ? const _AutomaticNewsEmpty()
                        : SingleChildScrollView(
                            child: Column(
                              children: [
                                for (final draft in drafts)
                                  _AutomaticNewsRow(
                                    draft: draft,
                                    postWidth: postWidth,
                                    selected: selectedDraftIds.contains(
                                      draft.id,
                                    ),
                                    onToggle: () => onToggleDraft(draft.id),
                                    onView: () => onViewDraft(draft),
                                    onDelete: () => onDeleteDraft(draft),
                                  ),
                              ],
                            ),
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

class _AutomaticNewsHeader extends StatelessWidget {
  const _AutomaticNewsHeader({
    required this.selectedCount,
    required this.totalCount,
    required this.postWidth,
    required this.sortState,
    required this.onToggleVisibleDrafts,
    required this.onSort,
  });

  final int selectedCount;
  final int totalCount;
  final double postWidth;
  final TableSortState sortState;
  final VoidCallback onToggleVisibleDrafts;
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
            width: _AutomaticNewsDataTable._selectWidth,
            child: _AutoNewsCheckbox(
              value: selectedCount == 0 || totalCount == 0
                  ? false
                  : selectedCount == totalCount
                  ? true
                  : null,
              tristate: true,
              onChanged: (_) => onToggleVisibleDrafts(),
            ),
          ),
          _SortableColumnHeader(
            width: _AutomaticNewsDataTable._idWidth,
            label: 'ID',
            sortKey: 'id',
            sortState: sortState,
            onSort: onSort,
          ),
          _SortableColumnHeader(
            width: postWidth,
            label: 'Haber',
            sortKey: 'post',
            sortState: sortState,
            onSort: onSort,
          ),
          _SortableColumnHeader(
            width: _AutomaticNewsDataTable._sourceWidth,
            label: 'Kaynak',
            sortKey: 'source',
            sortState: sortState,
            onSort: onSort,
          ),
          _SortableColumnHeader(
            width: _AutomaticNewsDataTable._statusWidth,
            label: 'Durum',
            sortKey: 'status',
            sortState: sortState,
            onSort: onSort,
            centered: true,
          ),
          _SortableColumnHeader(
            width: _AutomaticNewsDataTable._languageWidth,
            label: 'Dil',
            sortKey: 'language',
            sortState: sortState,
            onSort: onSort,
            centered: true,
          ),
          _SortableColumnHeader(
            width: _AutomaticNewsDataTable._originWidth,
            label: 'Alındığı Yer',
            sortKey: 'origin',
            sortState: sortState,
            onSort: onSort,
          ),
          const SizedBox(
            width: _AutomaticNewsDataTable._qualityWidth,
            child: _HeaderText('Güven', centered: true),
          ),
          _SortableColumnHeader(
            width: _AutomaticNewsDataTable._dateWidth,
            label: 'Tarih',
            sortKey: 'date',
            sortState: sortState,
            onSort: onSort,
          ),
          const SizedBox(
            width: _AutomaticNewsDataTable._menuWidth,
            child: _HeaderText('İşlem', centered: true),
          ),
        ],
      ),
    );
  }
}

class _SortableColumnHeader extends StatelessWidget {
  const _SortableColumnHeader({
    required this.width,
    required this.label,
    required this.sortKey,
    required this.sortState,
    required this.onSort,
    this.centered = false,
  });

  final double width;
  final String label;
  final String sortKey;
  final TableSortState sortState;
  final ValueChanged<String> onSort;
  final bool centered;

  @override
  Widget build(BuildContext context) {
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
          child: Align(
            alignment: centered ? Alignment.center : Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  fit: FlexFit.loose,
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? AppColors.deepOcean : AppColors.inkSoft,
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
      ),
    );
  }
}

class _AutomaticNewsRow extends StatelessWidget {
  const _AutomaticNewsRow({
    required this.draft,
    required this.postWidth,
    required this.selected,
    required this.onToggle,
    required this.onView,
    required this.onDelete,
  });

  final _AutomaticNewsDraft draft;
  final double postWidth;
  final bool selected;
  final VoidCallback onToggle;
  final VoidCallback onView;
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
            width: _AutomaticNewsDataTable._selectWidth,
            child: _AutoNewsCheckbox(
              value: selected,
              onChanged: (_) => onToggle(),
            ),
          ),
          SizedBox(
            width: _AutomaticNewsDataTable._idWidth,
            child: _RowTapTarget(
              onTap: onToggle,
              child: Text(
                draft.id.toString(),
                style: const TextStyle(
                  color: AppColors.deepOcean,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
          SizedBox(
            width: postWidth,
            child: _DraftIdentity(draft: draft),
          ),
          SizedBox(
            width: _AutomaticNewsDataTable._sourceWidth,
            child: _SourceCell(draft: draft),
          ),
          SizedBox(
            width: _AutomaticNewsDataTable._statusWidth,
            child: Center(child: _StatusBadge(value: draft.status)),
          ),
          SizedBox(
            width: _AutomaticNewsDataTable._languageWidth,
            child: Center(child: _LanguageBadge(value: draft.language)),
          ),
          SizedBox(
            width: _AutomaticNewsDataTable._originWidth,
            child: _OriginCell(draft: draft),
          ),
          SizedBox(
            width: _AutomaticNewsDataTable._qualityWidth,
            child: Center(child: _QualityBadge(value: draft.quality)),
          ),
          SizedBox(
            width: _AutomaticNewsDataTable._dateWidth,
            child: _DateCell(dateTime: draft.capturedAt),
          ),
          SizedBox(
            width: _AutomaticNewsDataTable._menuWidth,
            child: Align(
              alignment: Alignment.center,
              child: _AutomaticNewsRowMenu(onView: onView, onDelete: onDelete),
            ),
          ),
        ],
      ),
    );
  }
}

class _DraftIdentity extends StatelessWidget {
  const _DraftIdentity({required this.draft});

  final _AutomaticNewsDraft draft;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _DraftPreview(draft: draft),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                draft.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.deepOcean,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  _MiniTag(draft.category),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      draft.summary,
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
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DraftPreview extends StatelessWidget {
  const _DraftPreview({required this.draft});

  final _AutomaticNewsDraft draft;

  @override
  Widget build(BuildContext context) {
    final color = _platformColor(draft.platform);
    final mediaUrl = draft.imageUrl;
    final hasVideo = draft.videoUrl.isNotEmpty;

    return Container(
      width: 54,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      clipBehavior: Clip.antiAlias,
      child: mediaUrl.isEmpty
          ? _DraftPreviewFallback(platform: draft.platform, hasVideo: hasVideo)
          : Stack(
              fit: StackFit.expand,
              children: [
                AdminCachedImage(
                  url: adminImageUrl(mediaUrl, width: 140),
                  fit: BoxFit.cover,
                  memCacheWidth: 140,
                  fadeIn: false,
                  errorWidget: _DraftPreviewFallback(
                    platform: draft.platform,
                    hasVideo: hasVideo,
                  ),
                ),
                if (hasVideo)
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Container(
                      width: 18,
                      height: 18,
                      margin: const EdgeInsets.all(4),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.deepOcean.withValues(alpha: 0.86),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const SymbolIcon(
                        Symbols.videocam_outlined,
                        color: Colors.white,
                        size: 12,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _DraftPreviewFallback extends StatelessWidget {
  const _DraftPreviewFallback({required this.platform, required this.hasVideo});

  final String platform;
  final bool hasVideo;

  @override
  Widget build(BuildContext context) {
    final color = _platformColor(platform);
    final icon = hasVideo ? Symbols.videocam_outlined : _platformIcon(platform);
    return Center(child: SymbolIcon(icon, color: color, size: 22));
  }
}

IconData _platformIcon(String platform) {
  return switch (platform) {
    'Instagram' => Symbols.instagram_fill,
    'Facebook' => Symbols.facebook_fill,
    'X' => Symbols.twitter_x_fill,
    'RSS' => Symbols.rss_feed_outlined,
    _ => Symbols.link,
  };
}

Color _platformColor(String platform) {
  return switch (platform) {
    'Instagram' => const Color(0xFFE4405F),
    'Facebook' => const Color(0xFF1877F2),
    'X' => AppColors.deepOcean,
    'RSS' => AppColors.warmHorizon,
    _ => AppColors.iconMuted,
  };
}

String _compactUrl(String value) {
  final raw = value.trim();
  if (raw.isEmpty) return '-';
  final uri = Uri.tryParse(raw);
  if (uri == null || uri.host.isEmpty) return raw;
  final path = uri.path.isEmpty ? '' : uri.path;
  return '${uri.host}$path';
}

String _readableText(String value, {String fallback = '-'}) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? fallback : trimmed;
}

class _AutomaticNewsRowMenu extends StatefulWidget {
  const _AutomaticNewsRowMenu({required this.onView, required this.onDelete});

  final VoidCallback onView;
  final VoidCallback onDelete;

  @override
  State<_AutomaticNewsRowMenu> createState() => _AutomaticNewsRowMenuState();
}

class _AutomaticNewsRowMenuState extends State<_AutomaticNewsRowMenu> {
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
              child: _AutomaticNewsMenuCard(
                onView: () => _runAndClose(widget.onView),
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
        message: 'İşlemler',
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

class _AutomaticNewsMenuCard extends StatelessWidget {
  const _AutomaticNewsMenuCard({required this.onView, required this.onDelete});

  final VoidCallback onView;
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
            _AutomaticNewsMenuItem(
              icon: Symbols.visibility,
              label: 'Haberi Görüntüle',
              onTap: onView,
            ),
            _AutomaticNewsMenuItem(
              icon: Symbols.delete,
              label: 'Sil',
              onTap: onDelete,
              danger: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _AutomaticNewsMenuItem extends StatelessWidget {
  const _AutomaticNewsMenuItem({
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
                label,
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

class _SourceCell extends StatelessWidget {
  const _SourceCell({required this.draft});

  final _AutomaticNewsDraft draft;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          draft.platform,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.deepOcean,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          draft.sourceName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.inkSoft,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _OriginCell extends StatelessWidget {
  const _OriginCell({required this.draft});

  final _AutomaticNewsDraft draft;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          draft.origin,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.deepOcean,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          draft.sourceUrl,
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
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final ready = value == 'Hazır';
    final review = value == 'İncele';
    final color = ready
        ? const Color(0xFF12825F)
        : review
        ? AppColors.warmHorizon
        : AppColors.inkSoft;
    final background = ready
        ? const Color(0xFFEAF7F1)
        : review
        ? const Color(0xFFFFF6E7)
        : AppColors.surface;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: color.withValues(alpha: 0.08)),
      ),
      child: Text(
        value,
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

class _LanguageBadge extends StatelessWidget {
  const _LanguageBadge({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 29,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.softLine,
        borderRadius: BorderRadius.circular(AppRadius.value),
      ),
      child: Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _QualityBadge extends StatelessWidget {
  const _QualityBadge({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    final color = value >= 90
        ? const Color(0xFF12825F)
        : value >= 80
        ? AppColors.warmHorizon
        : AppColors.inkSoft;
    return Text(
      '%$value',
      style: TextStyle(
        color: color,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
    );
  }
}

class _DateCell extends StatelessWidget {
  const _DateCell({required this.dateTime});

  final DateTime dateTime;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _formatDate(dateTime),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.deepOcean,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _formatTime(dateTime),
          style: const TextStyle(
            color: AppColors.placeholder,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.inkSoft,
        borderRadius: BorderRadius.circular(AppRadius.value),
      ),
      child: Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
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
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.inkSoft,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _AutoNewsCheckbox extends StatelessWidget {
  const _AutoNewsCheckbox({
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
      onChanged: onChanged,
      checkColor: Colors.white,
      activeColor: AppColors.deepOcean,
      side: BorderSide(color: AppColors.line.withValues(alpha: 0.92)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.value / 2),
      ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
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
        child: SizedBox(
          height: 52,
          child: Align(alignment: Alignment.centerLeft, child: child),
        ),
      ),
    );
  }
}

class _AutomaticNewsEmpty extends StatelessWidget {
  const _AutomaticNewsEmpty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Çekilmiş haber bulunamadı',
        style: TextStyle(
          color: AppColors.inkSoft,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _AutomaticNewsPreviewDialog extends StatelessWidget {
  const _AutomaticNewsPreviewDialog({required this.draft});

  final _AutomaticNewsDraft draft;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth < 1040
              ? constraints.maxWidth
              : 1040.0;
          final maxHeight = constraints.maxHeight < 760
              ? constraints.maxHeight
              : 760.0;
          final compact = maxWidth < 780;

          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxWidth,
                maxHeight: maxHeight,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.value),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.deepOcean.withValues(alpha: 0.18),
                      blurRadius: 32,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    _AutomaticNewsPreviewHeader(
                      draft: draft,
                      onClose: () => Navigator.of(context).pop(),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: compact
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _AutomaticNewsPreviewMedia(
                                    draft: draft,
                                    compact: true,
                                  ),
                                  const SizedBox(height: 20),
                                  _AutomaticNewsPreviewDetails(draft: draft),
                                ],
                              )
                            : Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 5,
                                    child: _AutomaticNewsPreviewMedia(
                                      draft: draft,
                                      compact: false,
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  Expanded(
                                    flex: 4,
                                    child: _AutomaticNewsPreviewDetails(
                                      draft: draft,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AutomaticNewsPreviewHeader extends StatelessWidget {
  const _AutomaticNewsPreviewHeader({
    required this.draft,
    required this.onClose,
  });

  final _AutomaticNewsDraft draft;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final color = _platformColor(draft.platform);
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.softLine.withValues(alpha: 0.86)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadius.value),
            ),
            child: SymbolIcon(_platformIcon(draft.platform), color: color),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Haberi Görüntüle',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.deepOcean,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${draft.platform} · ${draft.sourceName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.inkSoft,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Kapat',
            onPressed: onClose,
            icon: const SymbolIcon(
              Symbols.close,
              color: AppColors.iconMuted,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _AutomaticNewsPreviewMedia extends StatelessWidget {
  const _AutomaticNewsPreviewMedia({
    required this.draft,
    required this.compact,
  });

  final _AutomaticNewsDraft draft;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final mediaUrl = draft.mediaUrl;
    final hasImage = draft.imageUrl.isNotEmpty;
    final hasVideo = draft.videoUrl.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: compact ? 280 : 420,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.value),
            border: Border.all(color: AppColors.line.withValues(alpha: 0.82)),
          ),
          clipBehavior: Clip.antiAlias,
          child: hasImage
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    AdminCachedImage(
                      url: adminImageUrl(
                        draft.imageUrl,
                        width: compact ? 720 : 920,
                      ),
                      fit: BoxFit.cover,
                      memCacheWidth: compact ? 720 : 920,
                      errorWidget: _AutomaticNewsMediaFallback(
                        hasVideo: hasVideo,
                      ),
                    ),
                    if (hasVideo)
                      const Align(
                        alignment: Alignment.center,
                        child: _VideoOverlayBadge(),
                      ),
                  ],
                )
              : _AutomaticNewsMediaFallback(hasVideo: hasVideo),
        ),
        if (mediaUrl.isNotEmpty) ...[
          const SizedBox(height: 10),
          _PreviewInfoBlock(
            label: hasVideo ? 'Medya / Video Linki' : 'Medya Linki',
            value: mediaUrl,
            compactValue: _compactUrl(mediaUrl),
          ),
        ],
      ],
    );
  }
}

class _AutomaticNewsMediaFallback extends StatelessWidget {
  const _AutomaticNewsMediaFallback({required this.hasVideo});

  final bool hasVideo;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SymbolIcon(
            hasVideo ? Symbols.videocam_outlined : Symbols.image_outlined,
            color: AppColors.iconMuted,
            size: 42,
          ),
          const SizedBox(height: 10),
          Text(
            hasVideo ? 'Video bağlantısı alındı' : 'Medya görseli bulunamadı',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.inkSoft,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoOverlayBadge extends StatelessWidget {
  const _VideoOverlayBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.deepOcean.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(27),
        border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
      ),
      child: const SymbolIcon(
        Symbols.videocam_outlined,
        color: Colors.white,
        size: 24,
      ),
    );
  }
}

class _AutomaticNewsPreviewDetails extends StatelessWidget {
  const _AutomaticNewsPreviewDetails({required this.draft});

  final _AutomaticNewsDraft draft;

  @override
  Widget build(BuildContext context) {
    final content = draft.contentText.trim().isNotEmpty
        ? draft.contentText
        : draft.summary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          draft.title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppColors.deepOcean,
            fontWeight: FontWeight.w800,
            height: 1.18,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _PreviewBadge(draft.category),
            _PreviewBadge(draft.status, success: draft.status == 'Hazır'),
            _PreviewBadge('${draft.language} dil'),
            _PreviewBadge('%${draft.quality} güven'),
          ],
        ),
        const SizedBox(height: 18),
        _PreviewSection(title: 'Kısa Özet', body: draft.summary),
        const SizedBox(height: 16),
        _PreviewSection(title: 'Tam Metin', body: content),
        const SizedBox(height: 18),
        _PreviewInfoBlock(label: 'Kaynak', value: draft.sourceName),
        const SizedBox(height: 10),
        _PreviewInfoBlock(label: 'Alındığı Yer', value: draft.origin),
        const SizedBox(height: 10),
        _PreviewInfoBlock(
          label: 'Haber Linki',
          value: draft.sourceUrl,
          compactValue: _compactUrl(draft.sourceUrl),
        ),
        const SizedBox(height: 10),
        _PreviewInfoBlock(
          label: 'Gönderi Tarihi',
          value: draft.publishedAt == null
              ? 'Kaynakta tarih yok'
              : _formatDateTime(draft.publishedAt!),
        ),
        const SizedBox(height: 10),
        _PreviewInfoBlock(
          label: 'Çekim Tarihi',
          value: _formatDateTime(draft.capturedAt),
        ),
      ],
    );
  }
}

class _PreviewBadge extends StatelessWidget {
  const _PreviewBadge(this.label, {this.success = false});

  final String label;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final color = success ? const Color(0xFF12825F) : AppColors.inkSoft;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: success ? const Color(0xFFEAF7F1) : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: color.withValues(alpha: 0.10)),
      ),
      child: Text(
        label,
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

class _PreviewSection extends StatelessWidget {
  const _PreviewSection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.inkSoft,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 7),
        SelectableText(
          _readableText(body),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.deepOcean,
            fontWeight: FontWeight.w600,
            height: 1.45,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _PreviewInfoBlock extends StatelessWidget {
  const _PreviewInfoBlock({
    required this.label,
    required this.value,
    this.compactValue,
  });

  final String label;
  final String value;
  final String? compactValue;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line.withValues(alpha: 0.72)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.inkSoft,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 5),
          SelectableText(
            _readableText(compactValue ?? value),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
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

class _AutomaticNewsFooter extends StatelessWidget {
  const _AutomaticNewsFooter({
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.pageCount,
    required this.onPageChanged,
  });

  final int page;
  final int pageSize;
  final int totalCount;
  final int pageCount;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final start = totalCount == 0 ? 0 : ((page - 1) * pageSize) + 1;
    final end = totalCount == 0
        ? 0
        : (page * pageSize).clamp(0, totalCount).toInt();
    return Row(
      children: [
        Expanded(
          child: Text(
            '$start - $end / $totalCount kayıt gösteriliyor',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.inkSoft,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ),
        Wrap(
          spacing: 8,
          children: [
            AdminTablePageButton(
              label: '<<',
              enabled: page > 1,
              onPressed: () => onPageChanged(1),
            ),
            AdminTablePageButton(
              label: '<',
              enabled: page > 1,
              onPressed: () => onPageChanged(page - 1),
            ),
            AdminTablePageButton(label: '$page', selected: true),
            AdminTablePageButton(
              label: '>',
              enabled: page < pageCount,
              onPressed: () => onPageChanged(page + 1),
            ),
            AdminTablePageButton(
              label: '>>',
              enabled: page < pageCount,
              onPressed: () => onPageChanged(pageCount),
            ),
          ],
        ),
      ],
    );
  }
}

class _AutomaticNewsSourceDialog extends StatefulWidget {
  const _AutomaticNewsSourceDialog({
    required this.initialSources,
    required this.onSaveSources,
    required this.onTestSources,
    required this.onToggleSource,
  });

  final List<AutomaticNewsSource> initialSources;
  final Future<List<AutomaticNewsSource>> Function(List<String> urls)
  onSaveSources;
  final Future<_AutomaticNewsSourceTestPayload> Function() onTestSources;
  final Future<AutomaticNewsSource?> Function(
    AutomaticNewsSource source,
    bool value,
  )
  onToggleSource;

  @override
  State<_AutomaticNewsSourceDialog> createState() =>
      _AutomaticNewsSourceDialogState();
}

class _AutomaticNewsSourceDialogState
    extends State<_AutomaticNewsSourceDialog> {
  final _addressController = TextEditingController();

  late List<AutomaticNewsSource> _sources;
  var _saving = false;
  var _testing = false;
  var _busySourceId = '';
  var _error = '';
  AutomaticNewsRefreshResult? _testResult;
  var _latestBySourceId = const <String, AutomaticNewsSourcePreview>{};

  @override
  void initState() {
    super.initState();
    _sources = [...widget.initialSources];
    _addressController.text = _sourceAddressText(_sources);
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  List<String> get _addresses {
    return _addressController.text
        .split(RegExp(r'[\s,]+'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> _save() async {
    final addresses = _addresses;
    if (addresses.isEmpty || _saving) return;
    setState(() {
      _saving = true;
      _error = '';
    });
    try {
      final saved = await widget.onSaveSources(addresses);
      if (!mounted) return;
      setState(() {
        _sources = saved.toList()
          ..sort((a, b) => a.displayName.compareTo(b.displayName));
        _addressController.text = _sourceAddressText(_sources);
        _testResult = null;
        _latestBySourceId = const {};
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _testSources() async {
    if (_testing || _saving) return;
    setState(() {
      _testing = true;
      _error = '';
    });
    try {
      final payload = await widget.onTestSources();
      if (!mounted) return;
      setState(() {
        _sources = payload.sources.toList()
          ..sort((a, b) => a.displayName.compareTo(b.displayName));
        _addressController.text = _sourceAddressText(_sources);
        _testResult = payload.result;
        _latestBySourceId = {
          for (final preview in payload.result.previews)
            preview.sourceId: preview,
        };
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _toggle(AutomaticNewsSource source, bool value) async {
    if (_busySourceId.isNotEmpty) return;
    setState(() {
      _busySourceId = source.id;
      _error = '';
    });
    try {
      final updated = await widget.onToggleSource(source, value);
      if (!mounted || updated == null) return;
      setState(() {
        _sources = [
          for (final item in _sources) item.id == updated.id ? updated : item,
        ];
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busySourceId = '');
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    final dialogWidth = viewport.width < 1120 ? viewport.width - 32 : 980.0;
    final dialogHeight = viewport.height < 760 ? viewport.height - 48 : 700.0;

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      backgroundColor: Colors.transparent,
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.value),
          boxShadow: [
            BoxShadow(
              color: AppColors.deepOcean.withValues(alpha: 0.18),
              blurRadius: 32,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: Column(
          children: [
            _SourceDialogHeader(onClose: () => Navigator.of(context).pop()),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 18),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 760;
                    final left = _SourceAddressEditor(
                      controller: _addressController,
                      error: _error,
                      sourceCount: _sources.length,
                      activeSourceCount: _sources
                          .where((source) => source.isActive)
                          .length,
                      testResult: _testResult,
                    );
                    final right = _SourceListPanel(
                      sources: _sources,
                      busySourceId: _busySourceId,
                      latestBySourceId: _latestBySourceId,
                      onToggle: _toggle,
                    );
                    if (compact) {
                      return ListView(
                        children: [
                          left,
                          const SizedBox(height: 18),
                          SizedBox(height: 320, child: right),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 6, child: left),
                        const SizedBox(width: 22),
                        Expanded(flex: 4, child: right),
                      ],
                    );
                  },
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(28, 16, 28, 18),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: AppColors.softLine.withValues(alpha: 0.86),
                  ),
                ),
              ),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 10,
                runSpacing: 10,
                children: [
                  AdminTableSecondaryActionButton(
                    icon: Symbols.close,
                    label: 'Kapat',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  AdminTableSecondaryActionButton(
                    icon: Symbols.refresh_line,
                    label: _testing ? 'Test Ediliyor...' : 'Kaynakları Test Et',
                    onPressed: _testing ? () {} : _testSources,
                  ),
                  AdminTablePrimaryActionButton(
                    icon: Symbols.add,
                    label: _saving ? 'Kaydediliyor...' : 'Adresleri Güncelle',
                    onPressed: _saving ? () {} : _save,
                    backgroundColor: AppColors.deepOcean,
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

class _AutomaticNewsSourceTestPayload {
  const _AutomaticNewsSourceTestPayload({
    required this.result,
    required this.sources,
  });

  final AutomaticNewsRefreshResult result;
  final List<AutomaticNewsSource> sources;
}

String _sourceAddressText(List<AutomaticNewsSource> sources) {
  final sorted = sources.toList()
    ..sort((a, b) {
      final type = a.sourceType.compareTo(b.sourceType);
      if (type != 0) return type;
      return a.displayName.compareTo(b.displayName);
    });
  return sorted
      .where((source) => source.isActive)
      .map((source) => source.url)
      .join('\n');
}

class _SourceDialogHeader extends StatelessWidget {
  const _SourceDialogHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.softLine.withValues(alpha: 0.86)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.actionRed.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadius.value),
            ),
            child: const SymbolIcon(
              Symbols.rss_feed_outlined,
              color: AppColors.actionRed,
              size: 18,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              'Otomatik Haber Kaynakları',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.deepOcean,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
          _SourceDialogBadge('5 dk otomasyon'),
          const SizedBox(width: 12),
          IconButton(
            tooltip: 'Kapat',
            onPressed: onClose,
            icon: const SymbolIcon(
              Symbols.close,
              color: AppColors.iconMuted,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceDialogBadge extends StatelessWidget {
  const _SourceDialogBadge(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7F1),
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(
          color: const Color(0xFF12825F).withValues(alpha: 0.18),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF12825F),
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _SourceAddressEditor extends StatelessWidget {
  const _SourceAddressEditor({
    required this.controller,
    required this.error,
    required this.sourceCount,
    required this.activeSourceCount,
    required this.testResult,
  });

  final TextEditingController controller;
  final String error;
  final int sourceCount;
  final int activeSourceCount;
  final AutomaticNewsRefreshResult? testResult;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: _ControlLabel('Adresler')),
            _SourceDialogBadge('$activeSourceCount aktif / $sourceCount adres'),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: TextField(
            controller: controller,
            expands: true,
            maxLines: null,
            minLines: null,
            textAlignVertical: TextAlignVertical.top,
            cursorColor: AppColors.support,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.deepOcean,
              fontWeight: FontWeight.w600,
              height: 1.45,
              letterSpacing: 0,
            ),
            decoration: InputDecoration(
              hintText:
                  'https://www.instagram.com/haberhesabi/\nhttps://site.com/rss.xml',
              hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.placeholder,
                fontWeight: FontWeight.w500,
                letterSpacing: 0,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.all(14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.value),
                borderSide: BorderSide(
                  color: AppColors.line.withValues(alpha: 0.72),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.value),
                borderSide: BorderSide(
                  color: AppColors.line.withValues(alpha: 0.72),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.value),
                borderSide: BorderSide(
                  color: AppColors.deepOcean.withValues(alpha: 0.42),
                ),
              ),
            ),
          ),
        ),
        if (testResult != null) ...[
          const SizedBox(height: 10),
          _SourceTestResultStrip(result: testResult!),
        ],
        if (error.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            error,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.actionRed,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ],
      ],
    );
  }
}

class _SourceTestResultStrip extends StatelessWidget {
  const _SourceTestResultStrip({required this.result});

  final AutomaticNewsRefreshResult result;

  @override
  Widget build(BuildContext context) {
    final hasError = result.errorCount > 0;
    final color = hasError ? AppColors.warmHorizon : const Color(0xFF12825F);
    final background = hasError
        ? const Color(0xFFFFF6E7)
        : const Color(0xFFEAF7F1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          SymbolIcon(
            hasError ? Symbols.warning : Symbols.check_circle,
            color: color,
            size: 17,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${result.checkedSources} kaynak test edildi · ${result.insertedCount} yeni · ${result.skippedDuplicateCount} aynı başlık · ${result.errorCount} hata',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.deepOcean,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceListPanel extends StatelessWidget {
  const _SourceListPanel({
    required this.sources,
    required this.busySourceId,
    required this.latestBySourceId,
    required this.onToggle,
  });

  final List<AutomaticNewsSource> sources;
  final String busySourceId;
  final Map<String, AutomaticNewsSourcePreview> latestBySourceId;
  final Future<void> Function(AutomaticNewsSource source, bool value) onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line.withValues(alpha: 0.72)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const SymbolIcon(
                Symbols.link,
                color: AppColors.iconMuted,
                size: 17,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Kayıtlı Kaynaklar',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.deepOcean,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ),
              _SourceDialogBadge('${sources.length} adres'),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: sources.isEmpty
                ? const Center(
                    child: Text(
                      'Kayıtlı adres yok',
                      style: TextStyle(
                        color: AppColors.inkSoft,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: sources.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      color: AppColors.softLine.withValues(alpha: 0.86),
                    ),
                    itemBuilder: (context, index) {
                      final source = sources[index];
                      return _SourceListRow(
                        source: source,
                        latest: latestBySourceId[source.id],
                        busy: busySourceId == source.id,
                        onToggle: (value) => onToggle(source, value),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SourceListRow extends StatelessWidget {
  const _SourceListRow({
    required this.source,
    required this.latest,
    required this.busy,
    required this.onToggle,
  });

  final AutomaticNewsSource source;
  final AutomaticNewsSourcePreview? latest;
  final bool busy;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final platform = switch (source.sourceType) {
      'instagram' => 'Instagram',
      'rss' => 'RSS',
      _ => 'Web',
    };
    final status = source.lastError.isNotEmpty
        ? source.lastError
        : latest != null
        ? '${latest!.inserted ? 'Yeni alındı' : 'Aynı başlık'} · ${latest!.title}'
        : source.lastSuccessAt == null
        ? 'Hazır'
        : '${_formatDate(source.lastSuccessAt!)} ${_formatTime(source.lastSuccessAt!)}';
    final statusColor = source.lastError.isNotEmpty
        ? AppColors.actionRed
        : AppColors.inkSoft;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          _SourcePlatformPreview(platform: platform),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  source.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.deepOcean,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  source.url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.inkSoft,
                    fontWeight: FontWeight.w500,
                    fontSize: 11,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.actionRed,
                  ),
                )
              : _CompactSwitch(value: source.isActive, onChanged: onToggle),
        ],
      ),
    );
  }
}

class _SourcePlatformPreview extends StatelessWidget {
  const _SourcePlatformPreview({required this.platform});

  final String platform;

  @override
  Widget build(BuildContext context) {
    final color = _platformColor(platform);
    return Container(
      width: 54,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: SymbolIcon(_platformIcon(platform), color: color, size: 22),
    );
  }
}

class _AutomaticNewsDraft {
  const _AutomaticNewsDraft({
    required this.recordId,
    required this.id,
    required this.title,
    required this.summary,
    required this.contentText,
    required this.platform,
    required this.sourceName,
    required this.sourceUrl,
    required this.imageUrl,
    required this.videoUrl,
    required this.origin,
    required this.category,
    required this.status,
    required this.language,
    required this.quality,
    required this.publishedAt,
    required this.capturedAt,
  });

  factory _AutomaticNewsDraft.fromItem(AutomaticNewsItem item) {
    final platform = switch (item.sourceType) {
      'instagram' => 'Instagram',
      'rss' => 'RSS',
      'website' => 'Web',
      _ => 'Web',
    };
    final sourceUrl = item.canonicalUrl.trim().isNotEmpty
        ? item.canonicalUrl.trim()
        : item.sourceUrl.trim();
    return _AutomaticNewsDraft(
      recordId: item.id,
      id: item.displayId,
      title: item.title,
      summary: item.summary.isEmpty ? item.contentText : item.summary,
      contentText: item.contentText,
      platform: platform,
      sourceName: item.sourceName,
      sourceUrl: sourceUrl,
      imageUrl: item.imageUrl.trim(),
      videoUrl: item.videoUrl.trim(),
      origin: item.originLabel.isEmpty ? 'Kaynak adresi' : item.originLabel,
      category: item.category,
      status: item.status,
      language: item.languageCode.toLowerCase() == 'tr'
          ? 'Tr'
          : item.languageCode,
      quality: item.qualityScore,
      publishedAt: item.publishedAt,
      capturedAt: item.capturedAt,
    );
  }

  final String recordId;
  final int id;
  final String title;
  final String summary;
  final String contentText;
  final String platform;
  final String sourceName;
  final String sourceUrl;
  final String imageUrl;
  final String videoUrl;
  final String origin;
  final String category;
  final String status;
  final String language;
  final int quality;
  final DateTime? publishedAt;
  final DateTime capturedAt;

  String get mediaUrl => imageUrl.isNotEmpty ? imageUrl : videoUrl;
}

const _platforms = ['Instagram', 'Web', 'RSS'];
const _categories = [
  'Niğde',
  'Gündem',
  'Yaşam',
  'Ekonomi',
  'Spor',
  'Eğitim',
  'Sağlık',
];
const _statuses = ['Hazır', 'İncele', 'Kaynak Bekliyor'];
const _languages = ['Tr', 'En'];

String _formatDate(DateTime value) {
  return '${value.day} ${_monthName(value.month)} ${value.year}';
}

String _formatTime(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _formatDateTime(DateTime value) =>
    '${_formatDate(value)} ${_formatTime(value)}';

String _monthName(int value) {
  return switch (value) {
    1 => 'Ocak',
    2 => 'Şubat',
    3 => 'Mart',
    4 => 'Nisan',
    5 => 'Mayıs',
    6 => 'Haziran',
    7 => 'Temmuz',
    8 => 'Ağustos',
    9 => 'Eylül',
    10 => 'Ekim',
    11 => 'Kasım',
    12 => 'Aralık',
    _ => '',
  };
}
