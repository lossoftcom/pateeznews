import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/localization/admin_date_formatter.dart';
import '../../../core/localization/admin_language_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../features/auth/data/admin_auth_models.dart';
import '../../../shared/icons/symbols.dart';
import '../../../shared/widgets/app_confirmation_dialog.dart';
import '../../../shared/widgets/sortable_table_header.dart';
import '../../../shared/widgets/symbol_icon.dart';
import '../../news/presentation/widgets/news_link_opener.dart';
import '../data/admin_stories_repository.dart';
import 'stories_models.dart';

class StoriesScreen extends StatefulWidget {
  const StoriesScreen({
    super.key,
    required this.session,
    this.repository = const NeonAdminStoriesRepository(),
  });

  final AdminSession session;
  final AdminStoriesRepository repository;

  @override
  State<StoriesScreen> createState() => _StoriesScreenState();
}

class _StoriesScreenState extends State<StoriesScreen> {
  final _selectedStoryIds = <String>{};
  final _searchController = TextEditingController();
  Timer? _searchDebounce;

  var _stories = const <AdminStory>[];
  var _loading = true;
  String? _errorText;
  var _page = 1;
  var _pageSize = 25;
  var _totalCount = 0;
  var _searchQuery = '';
  var _sortState = const TableSortState(key: 'date', ascending: false);

  @override
  void initState() {
    super.initState();
    unawaited(_loadStories());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<AdminStoriesPageResult> _fetchStories() {
    return widget.repository.fetchStories(
      search: _searchQuery,
      page: _page,
      pageSize: _pageSize,
      sortKey: _sortState.key,
      sortAscending: _sortState.ascending,
    );
  }

  Future<void> _loadStories() async {
    setState(() {
      _loading = true;
      _errorText = null;
    });

    try {
      final result = await _fetchStories();
      if (!mounted) return;
      setState(() {
        _stories = result.stories;
        _totalCount = result.totalCount;
        _selectedStoryIds.removeWhere(
          (id) => !_stories.any((story) => story.id == id),
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
      _page = 1;
      _selectedStoryIds.clear();
    });
    unawaited(_loadStories());
  }

  void _changeSearch(String value) {
    setState(() => _searchQuery = value);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _page = 1;
        _selectedStoryIds.clear();
      });
      unawaited(_loadStories());
    });
  }

  void _changePage(int page) {
    if (page == _page) return;
    setState(() {
      _page = page;
      _selectedStoryIds.clear();
    });
    unawaited(_loadStories());
  }

  void _changeSort(String sortKey) {
    setState(() {
      _sortState = _sortState.toggled(sortKey);
      _page = 1;
      _selectedStoryIds.clear();
    });
    unawaited(_loadStories());
  }

  void _toggleStory(String storyId) {
    setState(() {
      if (_selectedStoryIds.contains(storyId)) {
        _selectedStoryIds.remove(storyId);
      } else {
        _selectedStoryIds.add(storyId);
      }
    });
  }

  void _toggleAllStories() {
    final ids = _stories.map((story) => story.id).toSet();
    setState(() {
      if (ids.isNotEmpty && _selectedStoryIds.containsAll(ids)) {
        _selectedStoryIds.removeAll(ids);
      } else {
        _selectedStoryIds
          ..clear()
          ..addAll(ids);
      }
    });
  }

  Future<void> _runMutation(Future<void> Function() action) async {
    setState(() {
      _loading = true;
      _errorText = null;
    });
    try {
      await action();
      if (!mounted) return;
      _selectedStoryIds.clear();
      await _loadStories();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _showStoryDialog([AdminStory? story]) async {
    final result = await showDialog<StoryFormData>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.34),
      builder: (context) => _StoryFormDialog(story: story),
    );
    if (result == null) return;
    await _runMutation(
      () => widget.repository.upsertStory(
        session: widget.session,
        storyId: story?.id,
        data: result,
      ),
    );
  }

  Future<void> _toggleStatus(AdminStory story) async {
    await _runMutation(() => widget.repository.toggleStatus(story));
  }

  Future<void> _deleteStory(AdminStory story) async {
    final confirmed = await showAppConfirmationDialog(
      context,
      title: context.t('stories.deleteTitle'),
      message: context.t(
        'stories.deleteMessage',
        values: {'title': story.displayTitle},
      ),
      confirmLabel: context.t('common.delete'),
      danger: true,
    );
    if (!confirmed) return;
    await _runMutation(() => widget.repository.deleteStory(story.id));
  }

  Future<void> _deleteSelected() async {
    final ids = _selectedStoryIds.toList(growable: false);
    if (ids.isEmpty) return;
    final confirmed = await showAppConfirmationDialog(
      context,
      title: context.t('stories.deleteSelectedTitle'),
      message: context.t(
        'stories.deleteSelectedMessage',
        values: {'count': ids.length},
      ),
      confirmLabel: context.t('common.delete'),
      danger: true,
    );
    if (!confirmed) return;
    await _runMutation(() => widget.repository.deleteStories(ids));
  }

  void _openMedia(AdminStory story) {
    final url = story.mediaUrl.trim();
    if (url.isEmpty) return;
    unawaited(openNewsLink(_publicUrl(url)));
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
            const _StoriesTitle(),
            if (_errorText != null) ...[
              const SizedBox(height: 22),
              _StoriesErrorBanner(message: _errorText!),
            ],
            const SizedBox(height: 24),
            Expanded(
              child: _StoriesTableCard(
                stories: _stories,
                loading: _loading,
                page: _page,
                pageSize: _pageSize,
                totalCount: _totalCount,
                searchController: _searchController,
                searchQuery: _searchQuery,
                selectedStoryIds: _selectedStoryIds,
                sortState: _sortState,
                onPageSizeChanged: _changePageSize,
                onSearchChanged: _changeSearch,
                onPageChanged: _changePage,
                onToggleStory: _toggleStory,
                onToggleAllStories: _toggleAllStories,
                onSort: _changeSort,
                onCreate: () => unawaited(_showStoryDialog()),
                onEdit: (story) => unawaited(_showStoryDialog(story)),
                onToggleStatus: (story) => unawaited(_toggleStatus(story)),
                onOpenMedia: _openMedia,
                onDelete: (story) => unawaited(_deleteStory(story)),
                onDeleteSelected: () => unawaited(_deleteSelected()),
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
            child: SizedBox(height: 820, child: content),
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

class _StoriesTitle extends StatelessWidget {
  const _StoriesTitle();

  @override
  Widget build(BuildContext context) {
    return Text(
      context.t('Stories'),
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
        color: AppColors.deepOcean,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
    );
  }
}

class _StoriesErrorBanner extends StatelessWidget {
  const _StoriesErrorBanner({required this.message});

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

class _StoriesTableCard extends StatelessWidget {
  const _StoriesTableCard({
    required this.stories,
    required this.loading,
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.searchController,
    required this.searchQuery,
    required this.selectedStoryIds,
    required this.sortState,
    required this.onPageSizeChanged,
    required this.onSearchChanged,
    required this.onPageChanged,
    required this.onToggleStory,
    required this.onToggleAllStories,
    required this.onSort,
    required this.onCreate,
    required this.onEdit,
    required this.onToggleStatus,
    required this.onOpenMedia,
    required this.onDelete,
    required this.onDeleteSelected,
  });

  static const toolbarHeight = 38.0;

  final List<AdminStory> stories;
  final bool loading;
  final int page;
  final int pageSize;
  final int totalCount;
  final TextEditingController searchController;
  final String searchQuery;
  final Set<String> selectedStoryIds;
  final TableSortState sortState;
  final ValueChanged<int?> onPageSizeChanged;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<String> onToggleStory;
  final VoidCallback onToggleAllStories;
  final ValueChanged<String> onSort;
  final VoidCallback onCreate;
  final ValueChanged<AdminStory> onEdit;
  final ValueChanged<AdminStory> onToggleStatus;
  final ValueChanged<AdminStory> onOpenMedia;
  final ValueChanged<AdminStory> onDelete;
  final VoidCallback onDeleteSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StoriesToolbar(
          pageSize: pageSize,
          searchController: searchController,
          searchQuery: searchQuery,
          selectedCount: selectedStoryIds.length,
          onPageSizeChanged: onPageSizeChanged,
          onSearchChanged: onSearchChanged,
          onCreate: onCreate,
          onDeleteSelected: onDeleteSelected,
        ),
        const SizedBox(height: 18),
        Expanded(
          child: _StoriesDataTable(
            stories: stories,
            loading: loading,
            selectedStoryIds: selectedStoryIds,
            sortState: sortState,
            onToggleStory: onToggleStory,
            onToggleAllStories: onToggleAllStories,
            onSort: onSort,
            onEdit: onEdit,
            onToggleStatus: onToggleStatus,
            onOpenMedia: onOpenMedia,
            onDelete: onDelete,
          ),
        ),
        const SizedBox(height: 16),
        _StoriesFooter(
          page: page,
          pageSize: pageSize,
          totalCount: totalCount,
          loading: loading,
          onPageChanged: onPageChanged,
        ),
      ],
    );
  }
}

class _StoriesToolbar extends StatelessWidget {
  const _StoriesToolbar({
    required this.pageSize,
    required this.searchController,
    required this.searchQuery,
    required this.selectedCount,
    required this.onPageSizeChanged,
    required this.onSearchChanged,
    required this.onCreate,
    required this.onDeleteSelected,
  });

  final int pageSize;
  final TextEditingController searchController;
  final String searchQuery;
  final int selectedCount;
  final ValueChanged<int?> onPageSizeChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onCreate;
  final VoidCallback onDeleteSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final pageSizeSelect = _PageSizeSelect(
          value: pageSize,
          onChanged: onPageSizeChanged,
        );
        final search = ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: compact ? double.infinity : 260,
            maxWidth: compact ? double.infinity : 280,
          ),
          child: _SearchField(
            controller: searchController,
            query: searchQuery,
            hint: context.t('stories.searchPlaceholder'),
            onChanged: onSearchChanged,
          ),
        );
        final addButton = _PrimaryActionButton(
          icon: Symbols.add,
          label: context.t('stories.addButton'),
          onPressed: onCreate,
        );
        final deleteButton = selectedCount == 0
            ? null
            : _BulkDeleteButton(
                selectedCount: selectedCount,
                onPressed: onDeleteSelected,
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
              Align(alignment: Alignment.centerLeft, child: addButton),
            ],
          );
        }

        return Row(
          children: [
            pageSizeSelect,
            if (deleteButton != null) ...[
              const SizedBox(width: 12),
              deleteButton,
            ],
            const Spacer(),
            search,
            const SizedBox(width: 14),
            addButton,
          ],
        );
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
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        height: _StoriesTableCard.toolbarHeight,
        padding: const EdgeInsets.only(left: 12, right: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.value),
          border: Border.all(color: AppColors.line.withValues(alpha: 0.72)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            value: value,
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
            items: const [
              DropdownMenuItem(value: 25, child: Text('25')),
              DropdownMenuItem(value: 50, child: Text('50')),
              DropdownMenuItem(value: 100, child: Text('100')),
            ],
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
    if (controller.text != query) {
      controller.value = TextEditingValue(
        text: query,
        selection: TextSelection.collapsed(offset: query.length),
      );
    }

    return Container(
      height: _StoriesTableCard.toolbarHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line.withValues(alpha: 0.72)),
      ),
      child: TextField(
        controller: controller,
        mouseCursor: SystemMouseCursors.text,
        cursorColor: AppColors.support,
        textAlignVertical: TextAlignVertical.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.deepOcean,
          fontWeight: FontWeight.w400,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.placeholder,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: 12, right: 9),
            child: SymbolIcon(
              Symbols.search,
              color: AppColors.iconMuted,
              size: 18,
            ),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 39,
            minHeight: _StoriesTableCard.toolbarHeight,
          ),
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          contentPadding: EdgeInsets.zero,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
        onChanged: onChanged,
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
      height: _StoriesTableCard.toolbarHeight,
      child: TextButton(
        onPressed: onPressed,
        style:
            TextButton.styleFrom(
              backgroundColor: AppColors.actionRed,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, _StoriesTableCard.toolbarHeight),
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
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _BulkDeleteButton extends StatelessWidget {
  const _BulkDeleteButton({
    required this.selectedCount,
    required this.onPressed,
  });

  final int selectedCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: TextButton(
        onPressed: onPressed,
        style:
            TextButton.styleFrom(
              backgroundColor: AppColors.actionRed,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 34),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.value),
              ),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
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
            const SymbolIcon(Symbols.delete, color: Colors.white, size: 14),
            const SizedBox(width: 6),
            Text(
              context.t(
                'stories.selectedDelete',
                values: {'count': selectedCount},
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoriesDataTable extends StatelessWidget {
  const _StoriesDataTable({
    required this.stories,
    required this.loading,
    required this.selectedStoryIds,
    required this.sortState,
    required this.onToggleStory,
    required this.onToggleAllStories,
    required this.onSort,
    required this.onEdit,
    required this.onToggleStatus,
    required this.onOpenMedia,
    required this.onDelete,
  });

  final List<AdminStory> stories;
  final bool loading;
  final Set<String> selectedStoryIds;
  final TableSortState sortState;
  final ValueChanged<String> onToggleStory;
  final VoidCallback onToggleAllStories;
  final ValueChanged<String> onSort;
  final ValueChanged<AdminStory> onEdit;
  final ValueChanged<AdminStory> onToggleStatus;
  final ValueChanged<AdminStory> onOpenMedia;
  final ValueChanged<AdminStory> onDelete;

  static const _minWidth = 1120.0;
  static const _selectWidth = 42.0;
  static const _idWidth = 70.0;
  static const _storyMinWidth = 420.0;
  static const _viewsWidth = 110.0;
  static const _expiresWidth = 190.0;
  static const _statusWidth = 128.0;
  static const _menuWidth = 76.0;
  static const _horizontalPadding = 32.0;
  static const _tableBorderWidth = 2.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth = math.max(constraints.maxWidth, _minWidth);
        final fixedWidth =
            _horizontalPadding +
            _tableBorderWidth +
            _selectWidth +
            _idWidth +
            _viewsWidth +
            _expiresWidth +
            _statusWidth +
            _menuWidth;
        final storyWidth = math.max(_storyMinWidth, tableWidth - fixedWidth);
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
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _StoriesHeader(
                    selectedCount: selectedStoryIds.length,
                    totalCount: stories.length,
                    storyWidth: storyWidth,
                    sortState: sortState,
                    onToggleAllStories: onToggleAllStories,
                    onSort: onSort,
                  ),
                  Expanded(
                    child: loading && stories.isEmpty
                        ? const _StoriesLoading()
                        : stories.isEmpty
                        ? const _StoriesEmpty()
                        : ListView.builder(
                            itemCount: stories.length,
                            itemBuilder: (context, index) {
                              final story = stories[index];
                              return _StoryRow(
                                story: story,
                                storyWidth: storyWidth,
                                selected: selectedStoryIds.contains(story.id),
                                onToggle: () => onToggleStory(story.id),
                                onEdit: onEdit,
                                onToggleStatus: onToggleStatus,
                                onOpenMedia: onOpenMedia,
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

class _StoriesHeader extends StatelessWidget {
  const _StoriesHeader({
    required this.selectedCount,
    required this.totalCount,
    required this.storyWidth,
    required this.sortState,
    required this.onToggleAllStories,
    required this.onSort,
  });

  final int selectedCount;
  final int totalCount;
  final double storyWidth;
  final TableSortState sortState;
  final VoidCallback onToggleAllStories;
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
            width: _StoriesDataTable._selectWidth,
            child: _StoriesCheckbox(
              value: selectedCount == 0 || totalCount == 0
                  ? false
                  : selectedCount == totalCount
                  ? true
                  : null,
              tristate: true,
              onChanged: (_) => onToggleAllStories(),
            ),
          ),
          _SortableColumnHeader(
            width: _StoriesDataTable._idWidth,
            label: 'ID',
            sortKey: 'id',
            sortState: sortState,
            onSort: onSort,
          ),
          _SortableColumnHeader(
            width: storyWidth,
            label: 'stories.column.story',
            sortKey: 'story',
            sortState: sortState,
            onSort: onSort,
          ),
          _SortableColumnHeader(
            width: _StoriesDataTable._viewsWidth,
            label: 'stories.column.views',
            sortKey: 'views',
            sortState: sortState,
            onSort: onSort,
            centered: true,
          ),
          _SortableColumnHeader(
            width: _StoriesDataTable._expiresWidth,
            label: 'stories.column.expires',
            sortKey: 'expires',
            sortState: sortState,
            onSort: onSort,
          ),
          _SortableColumnHeader(
            width: _StoriesDataTable._statusWidth,
            label: 'stories.column.status',
            sortKey: 'status',
            sortState: sortState,
            onSort: onSort,
            centered: true,
          ),
          SizedBox(
            width: _StoriesDataTable._menuWidth,
            child: _HeaderText('stories.column.action', centered: true),
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
                    context.t(label),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? AppColors.deepOcean : AppColors.inkSoft,
                      fontWeight: FontWeight.w600,
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

class _StoryRow extends StatelessWidget {
  const _StoryRow({
    required this.story,
    required this.storyWidth,
    required this.selected,
    required this.onToggle,
    required this.onEdit,
    required this.onToggleStatus,
    required this.onOpenMedia,
    required this.onDelete,
  });

  final AdminStory story;
  final double storyWidth;
  final bool selected;
  final VoidCallback onToggle;
  final ValueChanged<AdminStory> onEdit;
  final ValueChanged<AdminStory> onToggleStatus;
  final ValueChanged<AdminStory> onOpenMedia;
  final ValueChanged<AdminStory> onDelete;

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
            width: _StoriesDataTable._selectWidth,
            child: _StoriesCheckbox(value: selected, onChanged: (_) => onToggle()),
          ),
          SizedBox(
            width: _StoriesDataTable._idWidth,
            child: _RowSelectTapTarget(
              onTap: onToggle,
              child: Text(
                story.rowNumber.toString(),
                style: const TextStyle(
                  color: AppColors.deepOcean,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          SizedBox(width: storyWidth, child: _StoryIdentity(story: story)),
          SizedBox(
            width: _StoriesDataTable._viewsWidth,
            child: _NumberCell(value: story.viewCount),
          ),
          SizedBox(
            width: _StoriesDataTable._expiresWidth,
            child: _DateCell(dateTime: story.expiresAt, emptyKey: 'stories.noExpiry'),
          ),
          SizedBox(
            width: _StoriesDataTable._statusWidth,
            child: _StoryStatusBadge(story: story),
          ),
          SizedBox(
            width: _StoriesDataTable._menuWidth,
            child: Align(
              alignment: Alignment.center,
              child: _StoryRowMenu(
                story: story,
                onEdit: onEdit,
                onToggleStatus: onToggleStatus,
                onOpenMedia: onOpenMedia,
                onDelete: onDelete,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StoriesCheckbox extends StatelessWidget {
  const _StoriesCheckbox({
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.value),
      ),
      onChanged: onChanged,
    );
  }
}

class _RowSelectTapTarget extends StatelessWidget {
  const _RowSelectTapTarget({required this.onTap, required this.child});

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
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _StoryIdentity extends StatelessWidget {
  const _StoryIdentity({required this.story});

  final AdminStory story;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StoryThumbnail(story: story),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                story.displayTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.deepOcean,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  height: 1.22,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 5,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _MediaTypeBadge(
                    label: context.t('stories.media.${story.displayMediaType}'),
                  ),
                  Text(
                    story.createdAt == null
                        ? '-'
                        : formatAdminFullDate(context, story.createdAt),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.support,
                      fontWeight: FontWeight.w500,
                      fontSize: 10.5,
                    ),
                  ),
                  if (story.sourceName.trim().isNotEmpty)
                    Text(
                      story.displaySource,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.support,
                        fontWeight: FontWeight.w500,
                        fontSize: 10.5,
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

class _StoryThumbnail extends StatelessWidget {
  const _StoryThumbnail({required this.story});

  final AdminStory story;

  @override
  Widget build(BuildContext context) {
    final url = story.mediaUrl.trim();
    return Container(
      width: 48,
      height: 64,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line.withValues(alpha: 0.72)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (url.isEmpty)
            const Center(
              child: SymbolIcon(
                Symbols.photo_camera,
                color: AppColors.iconMuted,
                size: 22,
              ),
            )
          else
            Image.network(
              _publicUrl(url),
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
              errorBuilder: (context, _, _) {
                return const Center(
                  child: SymbolIcon(
                    Symbols.photo_camera,
                    color: AppColors.iconMuted,
                    size: 22,
                  ),
                );
              },
            ),
          Positioned(
            top: 4,
            right: 4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(AppRadius.value),
              ),
              child: const Padding(
                padding: EdgeInsets.all(3),
                child: SymbolIcon(
                  Symbols.visibility,
                  color: AppColors.deepOcean,
                  size: 10,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaTypeBadge extends StatelessWidget {
  const _MediaTypeBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.deepOcean.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(AppRadius.value),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _NumberCell extends StatelessWidget {
  const _NumberCell({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        value.toString(),
        style: const TextStyle(
          color: AppColors.deepOcean,
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _DateCell extends StatelessWidget {
  const _DateCell({required this.dateTime, required this.emptyKey});

  final DateTime? dateTime;
  final String emptyKey;

  @override
  Widget build(BuildContext context) {
    if (dateTime == null) {
      return Text(
        context.t(emptyKey),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.support,
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          formatAdminFullDate(context, dateTime),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.deepOcean,
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          formatAdminTime(dateTime),
          style: const TextStyle(
            color: AppColors.support,
            fontWeight: FontWeight.w400,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _StoryStatusBadge extends StatelessWidget {
  const _StoryStatusBadge({required this.story});

  final AdminStory story;

  @override
  Widget build(BuildContext context) {
    final color = story.isActive ? const Color(0xFF198754) : AppColors.support;
    final label = story.isActive ? 'stories.status.live' : 'stories.status.passive';

    return Align(
      alignment: Alignment.center,
      child: Container(
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
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(AppRadius.value),
              ),
            ),
            const SizedBox(width: 5),
            Text(
              context.t(label),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryRowMenu extends StatefulWidget {
  const _StoryRowMenu({
    required this.story,
    required this.onEdit,
    required this.onToggleStatus,
    required this.onOpenMedia,
    required this.onDelete,
  });

  final AdminStory story;
  final ValueChanged<AdminStory> onEdit;
  final ValueChanged<AdminStory> onToggleStatus;
  final ValueChanged<AdminStory> onOpenMedia;
  final ValueChanged<AdminStory> onDelete;

  @override
  State<_StoryRowMenu> createState() => _StoryRowMenuState();
}

class _StoryRowMenuState extends State<_StoryRowMenu> {
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
              child: _StoryMenuCard(
                story: widget.story,
                onEdit: () => _runAndClose(() => widget.onEdit(widget.story)),
                onToggleStatus: () =>
                    _runAndClose(() => widget.onToggleStatus(widget.story)),
                onOpenMedia: () =>
                    _runAndClose(() => widget.onOpenMedia(widget.story)),
                onDelete: () =>
                    _runAndClose(() => widget.onDelete(widget.story)),
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
        message: context.t('stories.actions.tooltip'),
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

class _StoryMenuCard extends StatelessWidget {
  const _StoryMenuCard({
    required this.story,
    required this.onEdit,
    required this.onToggleStatus,
    required this.onOpenMedia,
    required this.onDelete,
  });

  final AdminStory story;
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;
  final VoidCallback onOpenMedia;
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
            _StoryMenuItem(
              icon: Symbols.edit_square,
              label: 'Edit',
              onTap: onEdit,
            ),
            _StoryMenuItem(
              icon: story.isActive ? Symbols.visibility_off : Symbols.check,
              label: story.isActive
                  ? 'stories.actions.deactivate'
                  : 'stories.actions.activate',
              onTap: onToggleStatus,
            ),
            _StoryMenuItem(
              icon: Symbols.open_in_new,
              label: 'stories.actions.viewMedia',
              onTap: onOpenMedia,
            ),
            _StoryMenuItem(
              icon: Symbols.delete,
              label: 'Delete',
              onTap: onDelete,
              danger: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryMenuItem extends StatelessWidget {
  const _StoryMenuItem({
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

class _StoriesLoading extends StatelessWidget {
  const _StoriesLoading();

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

class _StoriesEmpty extends StatelessWidget {
  const _StoriesEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        context.t('stories.empty'),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.inkSoft,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _StoriesFooter extends StatelessWidget {
  const _StoriesFooter({
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.loading,
    required this.onPageChanged,
  });

  final int page;
  final int pageSize;
  final int totalCount;
  final bool loading;
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
        final summary = Text(
          context.t(
            'common.recordRange',
            values: {'from': from, 'to': to, 'total': totalCount},
          ),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.inkSoft,
            fontWeight: FontWeight.w500,
          ),
        );
        final pager = _StoriesPagination(
          page: page,
          lastPage: lastPage,
          loading: loading,
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

class _StoriesPagination extends StatelessWidget {
  const _StoriesPagination({
    required this.page,
    required this.lastPage,
    required this.loading,
    required this.onPageChanged,
  });

  final int page;
  final int lastPage;
  final bool loading;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        _PageButton(
          label: '<<',
          enabled: page > 1 && !loading,
          onPressed: () => onPageChanged(1),
        ),
        _PageButton(
          label: '<',
          enabled: page > 1 && !loading,
          onPressed: () => onPageChanged(page - 1),
        ),
        _PageButton(label: page.toString(), selected: true),
        _PageButton(
          label: '>',
          enabled: page < lastPage && !loading,
          onPressed: () => onPageChanged(page + 1),
        ),
        _PageButton(
          label: '>>',
          enabled: page < lastPage && !loading,
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

class _StoryFormDialog extends StatefulWidget {
  const _StoryFormDialog({this.story});

  final AdminStory? story;

  @override
  State<_StoryFormDialog> createState() => _StoryFormDialogState();
}

class _StoryFormDialogState extends State<_StoryFormDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _mediaUrlController;
  late final TextEditingController _sourceController;
  late final TextEditingController _expiresController;
  final _formKey = GlobalKey<FormState>();
  var _mediaType = 'image';
  var _isActive = true;

  @override
  void initState() {
    super.initState();
    final story = widget.story;
    _titleController = TextEditingController(text: story?.title ?? '');
    _mediaUrlController = TextEditingController(text: story?.mediaUrl ?? '');
    _sourceController = TextEditingController(text: story?.sourceName ?? '');
    _expiresController = TextEditingController(
      text: _formatInputDate(story?.expiresAt),
    );
    _mediaType = story?.displayMediaType ?? 'image';
    _isActive = story?.isActive ?? true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _mediaUrlController.dispose();
    _sourceController.dispose();
    _expiresController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final expiresAt = _parseInputDate(_expiresController.text);
    Navigator.of(context).pop(
      StoryFormData(
        title: _titleController.text,
        mediaUrl: _mediaUrlController.text,
        mediaType: _mediaType,
        sourceName: _sourceController.text,
        expiresAt: expiresAt,
        isActive: _isActive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.story != null;
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.value),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 26, 28, 22),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.t(
                              editing
                                  ? 'stories.dialog.editTitle'
                                  : 'stories.dialog.addTitle',
                            ),
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: AppColors.deepOcean,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            context.t('stories.dialog.subtitle'),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: AppColors.inkSoft,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: context.t('common.cancel'),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const SymbolIcon(Symbols.close),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 680;
                    final title = _DialogTextField(
                      controller: _titleController,
                      label: context.t('stories.field.title'),
                      hint: context.t('stories.hint.title'),
                      required: true,
                    );
                    final mediaUrl = _DialogTextField(
                      controller: _mediaUrlController,
                      label: context.t('stories.field.mediaUrl'),
                      hint: context.t('stories.hint.mediaUrl'),
                      required: true,
                    );
                    final mediaType = _DialogSelectField(
                      value: _mediaType,
                      label: context.t('stories.field.mediaType'),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _mediaType = value);
                      },
                    );
                    final source = _DialogTextField(
                      controller: _sourceController,
                      label: context.t('stories.field.sourceName'),
                      hint: context.t('stories.hint.sourceName'),
                    );
                    final expires = _DialogTextField(
                      controller: _expiresController,
                      label: context.t('stories.field.expiresAt'),
                      hint: context.t('stories.hint.expiresAt'),
                      validator: (value) {
                        final raw = value?.trim() ?? '';
                        if (raw.isEmpty) return null;
                        if (_parseInputDate(raw) == null) {
                          return context.t('stories.validation.date');
                        }
                        return null;
                      },
                    );

                    if (compact) {
                      return Column(
                        children: [
                          title,
                          const SizedBox(height: 18),
                          mediaUrl,
                          const SizedBox(height: 18),
                          mediaType,
                          const SizedBox(height: 18),
                          source,
                          const SizedBox(height: 18),
                          expires,
                        ],
                      );
                    }

                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: title),
                            const SizedBox(width: 24),
                            Expanded(child: mediaUrl),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(child: mediaType),
                            const SizedBox(width: 24),
                            Expanded(child: source),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(child: expires),
                            const SizedBox(width: 24),
                            Expanded(
                              child: _DialogStatusField(
                                value: _isActive,
                                onChanged: (value) =>
                                    setState(() => _isActive = value),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(context.t('common.cancel')),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      height: 36,
                      child: FilledButton(
                        onPressed: _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.deepOcean,
                          minimumSize: const Size(114, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          textStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
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

class _DialogTextField extends StatelessWidget {
  const _DialogTextField({
    required this.controller,
    required this.label,
    required this.hint,
    this.required = false,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final bool required;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      mouseCursor: SystemMouseCursors.text,
      cursorColor: AppColors.support,
      style: const TextStyle(
        color: AppColors.deepOcean,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(labelText: label, hintText: hint),
      validator: (value) {
        final raw = value?.trim() ?? '';
        if (required && raw.isEmpty) {
          return context.t('stories.validation.required');
        }
        return validator?.call(value);
      },
    );
  }
}

class _DialogSelectField extends StatelessWidget {
  const _DialogSelectField({
    required this.value,
    required this.label,
    required this.onChanged,
  });

  final String value;
  final String label;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      borderRadius: BorderRadius.circular(AppRadius.value),
      dropdownColor: Colors.white,
      focusColor: Colors.transparent,
      mouseCursor: SystemMouseCursors.click,
      decoration: InputDecoration(labelText: label),
      icon: const SymbolIcon(
        Symbols.keyboard_arrow_down,
        color: AppColors.iconMuted,
        size: 18,
      ),
      items: [
        DropdownMenuItem(
          value: 'image',
          child: Text(context.t('stories.media.image')),
        ),
        DropdownMenuItem(
          value: 'video',
          child: Text(context.t('stories.media.video')),
        ),
      ],
      onChanged: onChanged,
    );
  }
}

class _DialogStatusField extends StatelessWidget {
  const _DialogStatusField({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 10),
          child: Text(
            context.t('stories.field.status'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.inkSoft,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Row(
          children: [
            _StatusRadio(
              selected: value,
              label: context.t('stories.status.live'),
              onTap: () => onChanged(true),
            ),
            const SizedBox(width: 18),
            _StatusRadio(
              selected: !value,
              label: context.t('stories.status.passive'),
              onTap: () => onChanged(false),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatusRadio extends StatelessWidget {
  const _StatusRadio({
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      mouseCursor: SystemMouseCursors.click,
      borderRadius: BorderRadius.circular(AppRadius.value),
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.value),
              border: Border.all(color: AppColors.deepOcean, width: 2),
            ),
            child: selected
                ? Center(
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.deepOcean,
                        borderRadius: BorderRadius.circular(AppRadius.value),
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
            ),
          ),
        ],
      ),
    );
  }
}

String _formatInputDate(DateTime? value) {
  if (value == null) return '';
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

DateTime? _parseInputDate(String value) {
  final raw = value.trim();
  if (raw.isEmpty) return null;
  final normalized = raw.replaceFirst(' ', 'T');
  return DateTime.tryParse(normalized);
}

String _publicUrl(String value) {
  final trimmed = value.trim();
  if (trimmed.startsWith('http://') ||
      trimmed.startsWith('https://') ||
      trimmed.startsWith('data:') ||
      trimmed.startsWith('blob:')) {
    return trimmed;
  }
  return _siteBaseUri().resolve(trimmed).toString();
}

Uri _siteBaseUri() {
  if (!kIsWeb) {
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => Uri.parse('http://10.0.2.2:4321'),
      _ => Uri.parse('http://localhost:4321'),
    };
  }
  return Uri.base;
}
