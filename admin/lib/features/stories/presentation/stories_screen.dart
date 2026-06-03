import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../core/localization/admin_date_formatter.dart';
import '../../../core/localization/admin_language_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/widgets/admin_mobile_list.dart';
import '../../../shared/widgets/app_confirmation_dialog.dart';
import '../../../shared/widgets/sortable_table_header.dart';
import '../../../shared/widgets/symbol_icon.dart';
import '../../auth/data/admin_auth_models.dart';
import '../../news/presentation/widgets/news_link_opener.dart';
import '../data/admin_stories_repository.dart';
import 'stories_models.dart';

class StoriesScreen extends StatefulWidget {
  const StoriesScreen({
    super.key,
    required this.session,
    this.repository = const SupabaseAdminStoriesRepository(),
  });

  final AdminSession session;
  final AdminStoriesRepository repository;

  @override
  State<StoriesScreen> createState() => _StoriesScreenState();
}

class _StoriesScreenState extends State<StoriesScreen> {
  final Set<String> _selectedStoryIds = {};
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
    super.dispose();
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

  Future<AdminStoriesPageResult> _fetchStories() {
    return widget.repository.fetchStories(
      search: _searchQuery,
      page: _page,
      pageSize: _pageSize,
      sortKey: _sortState.key,
      sortAscending: _sortState.ascending,
    );
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
    setState(() {
      if (_stories.isNotEmpty && _selectedStoryIds.length == _stories.length) {
        _selectedStoryIds.clear();
      } else {
        _selectedStoryIds
          ..clear()
          ..addAll(_stories.map((story) => story.id));
      }
    });
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

  Future<void> _showStoryDialog([AdminStory? story]) async {
    final result = await showDialog<StoryFormData>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _StoryFormDialog(story: story),
    );
    if (result == null) return;
    await _runMutation(
      () => widget.repository.upsertStory(
        session: widget.session,
        data: result,
        storyId: story?.id,
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

  void _openMedia(AdminStory story) {
    final mediaUrl = story.mediaUrl.trim();
    if (mediaUrl.isEmpty) return;
    unawaited(openNewsLink(_publicUrl(mediaUrl)));
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
            const _StoriesTitle(),
            if (_errorText != null) ...[
              const SizedBox(height: 22),
              _StoriesErrorBanner(message: _errorText!),
            ],
            SizedBox(height: mobile ? 12 : 24),
            Expanded(
              child: _StoriesTableCard(
                stories: _stories,
                loading: _loading,
                page: _page,
                pageSize: _pageSize,
                totalCount: _totalCount,
                searchQuery: _searchQuery,
                selectedStoryIds: _selectedStoryIds,
                sortState: _sortState,
                onPageSizeChanged: _changePageSize,
                onSearchChanged: _changeSearch,
                onPageChanged: _changePage,
                onToggleStory: _toggleStory,
                onToggleAllStories: _toggleAllStories,
                onSort: _changeSort,
                onAddStory: () => unawaited(_showStoryDialog()),
                onEditStory: (story) => unawaited(_showStoryDialog(story)),
                onToggleStatus: (story) => unawaited(_toggleStatus(story)),
                onOpenMedia: _openMedia,
                onDeleteStory: (story) => unawaited(_deleteStory(story)),
                onDeleteSelected: () => unawaited(_deleteSelected()),
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
            child: SizedBox(height: 880, child: content),
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
    required this.searchQuery,
    required this.selectedStoryIds,
    required this.sortState,
    required this.onPageSizeChanged,
    required this.onSearchChanged,
    required this.onPageChanged,
    required this.onToggleStory,
    required this.onToggleAllStories,
    required this.onSort,
    required this.onAddStory,
    required this.onEditStory,
    required this.onToggleStatus,
    required this.onOpenMedia,
    required this.onDeleteStory,
    required this.onDeleteSelected,
  });

  final List<AdminStory> stories;
  final bool loading;
  final int page;
  final int pageSize;
  final int totalCount;
  final String searchQuery;
  final Set<String> selectedStoryIds;
  final TableSortState sortState;
  final ValueChanged<int?> onPageSizeChanged;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<String> onToggleStory;
  final VoidCallback onToggleAllStories;
  final ValueChanged<String> onSort;
  final VoidCallback onAddStory;
  final ValueChanged<AdminStory> onEditStory;
  final ValueChanged<AdminStory> onToggleStatus;
  final ValueChanged<AdminStory> onOpenMedia;
  final ValueChanged<AdminStory> onDeleteStory;
  final VoidCallback onDeleteSelected;

  static const double toolbarHeight = 38;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < AdminMobile.breakpoint) {
          return _StoriesMobileView(
            stories: stories,
            loading: loading,
            page: page,
            pageSize: pageSize,
            totalCount: totalCount,
            searchQuery: searchQuery,
            selectedStoryIds: selectedStoryIds,
            onSearchChanged: onSearchChanged,
            onPageChanged: onPageChanged,
            onToggleStory: onToggleStory,
            onAddStory: onAddStory,
            onEditStory: onEditStory,
            onToggleStatus: onToggleStatus,
            onOpenMedia: onOpenMedia,
            onDeleteStory: onDeleteStory,
            onDeleteSelected: onDeleteSelected,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StoriesToolbar(
              pageSize: pageSize,
              searchQuery: searchQuery,
              selectedCount: selectedStoryIds.length,
              onPageSizeChanged: onPageSizeChanged,
              onSearchChanged: onSearchChanged,
              onAddStory: onAddStory,
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
                onEditStory: onEditStory,
                onToggleStatus: onToggleStatus,
                onOpenMedia: onOpenMedia,
                onDeleteStory: onDeleteStory,
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
      },
    );
  }
}

class _StoriesMobileView extends StatelessWidget {
  const _StoriesMobileView({
    required this.stories,
    required this.loading,
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.searchQuery,
    required this.selectedStoryIds,
    required this.onSearchChanged,
    required this.onPageChanged,
    required this.onToggleStory,
    required this.onAddStory,
    required this.onEditStory,
    required this.onToggleStatus,
    required this.onOpenMedia,
    required this.onDeleteStory,
    required this.onDeleteSelected,
  });

  final List<AdminStory> stories;
  final bool loading;
  final int page;
  final int pageSize;
  final int totalCount;
  final String searchQuery;
  final Set<String> selectedStoryIds;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<String> onToggleStory;
  final VoidCallback onAddStory;
  final ValueChanged<AdminStory> onEditStory;
  final ValueChanged<AdminStory> onToggleStatus;
  final ValueChanged<AdminStory> onOpenMedia;
  final ValueChanged<AdminStory> onDeleteStory;
  final VoidCallback onDeleteSelected;

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
    final hasSelection = selectedStoryIds.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminMobileToolbar(
          query: searchQuery,
          hintText: context.t('stories.searchPlaceholder'),
          onSearchChanged: onSearchChanged,
          activeFilterCount: 0,
          onOpenFilters: () {},
          showFilters: false,
        ),
        const SizedBox(height: 12),
        hasSelection
            ? AdminMobileSelectionBar(
                selectedCount: selectedStoryIds.length,
                label: context.t(
                  'stories.selectedDelete',
                  values: {'count': selectedStoryIds.length},
                ),
                onClear: () {
                  for (final id in selectedStoryIds.toList()) {
                    onToggleStory(id);
                  }
                },
                onDelete: onDeleteSelected,
              )
            : AdminMobilePrimaryButton(
                icon: Symbols.add,
                label: context.t('stories.addButton'),
                fullWidth: true,
                onPressed: onAddStory,
              ),
        const SizedBox(height: 14),
        Expanded(
          child: AdminMobileListView(
            loading: loading,
            itemCount: stories.length,
            emptyLabel: context.t('stories.empty'),
            itemBuilder: (context, index) {
              final story = stories[index];
              return _StoriesMobileCard(
                story: story,
                selected: selectedStoryIds.contains(story.id),
                onToggle: () => onToggleStory(story.id),
                onEditStory: onEditStory,
                onToggleStatus: onToggleStatus,
                onOpenMedia: onOpenMedia,
                onDeleteStory: onDeleteStory,
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        AdminMobilePager(
          page: page,
          lastPage: lastPage,
          rangeText: rangeText,
          loading: loading,
          onPageChanged: onPageChanged,
        ),
      ],
    );
  }
}

class _StoriesMobileCard extends StatelessWidget {
  const _StoriesMobileCard({
    required this.story,
    required this.selected,
    required this.onToggle,
    required this.onEditStory,
    required this.onToggleStatus,
    required this.onOpenMedia,
    required this.onDeleteStory,
  });

  final AdminStory story;
  final bool selected;
  final VoidCallback onToggle;
  final ValueChanged<AdminStory> onEditStory;
  final ValueChanged<AdminStory> onToggleStatus;
  final ValueChanged<AdminStory> onOpenMedia;
  final ValueChanged<AdminStory> onDeleteStory;

  @override
  Widget build(BuildContext context) {
    final media = story.mediaUrl.trim();
    final statusColor = story.isActive
        ? const Color(0xFF198754)
        : AppColors.actionRed;

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
              AdminMobileThumb(
                imageUrl: media.isEmpty ? null : _publicUrl(media),
                fallbackIcon: Symbols.photo_camera,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      story.displayTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.deepOcean,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 14,
                      runSpacing: 6,
                      children: [
                        AdminMobileMeta(
                          icon: Symbols.visibility,
                          value: '${story.viewCount}',
                        ),
                        if (story.expiresAt != null)
                          AdminMobileMeta(
                            icon: Symbols.schedule,
                            value: formatAdminFullDate(
                              context,
                              story.expiresAt,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              AdminMobileMenuButton(
                tooltip: context.t('stories.actions.tooltip'),
                actions: [
                  AdminMobileMenuAction(
                    icon: Symbols.edit_square,
                    label: context.t('Edit'),
                    onTap: () => onEditStory(story),
                  ),
                  AdminMobileMenuAction(
                    icon: story.isActive
                        ? Symbols.visibility_off
                        : Symbols.check,
                    label: context.t(
                      story.isActive
                          ? 'stories.actions.deactivate'
                          : 'stories.actions.activate',
                    ),
                    onTap: () => onToggleStatus(story),
                  ),
                  AdminMobileMenuAction(
                    icon: Symbols.open_in_new,
                    label: context.t('stories.actions.viewMedia'),
                    onTap: () => onOpenMedia(story),
                  ),
                  AdminMobileMenuAction(
                    icon: Symbols.delete,
                    label: context.t('common.delete'),
                    danger: true,
                    onTap: () => onDeleteStory(story),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: AppColors.softLine.withValues(alpha: 0.9)),
          const SizedBox(height: 10),
          Row(
            children: [
              AdminMobileStatusPill(
                label: context.t(
                  story.isActive
                      ? 'stories.status.live'
                      : 'stories.status.passive',
                ),
                color: statusColor,
              ),
              const Spacer(),
              Text(
                formatAdminFullDate(context, story.createdAt),
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

class _StoriesToolbar extends StatelessWidget {
  const _StoriesToolbar({
    required this.pageSize,
    required this.searchQuery,
    required this.selectedCount,
    required this.onPageSizeChanged,
    required this.onSearchChanged,
    required this.onAddStory,
    required this.onDeleteSelected,
  });

  final int pageSize;
  final String searchQuery;
  final int selectedCount;
  final ValueChanged<int?> onPageSizeChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onAddStory;
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
          child: _StoriesSearchField(
            value: searchQuery,
            onChanged: onSearchChanged,
          ),
        );
        final addButton = _AddStoryButton(onPressed: onAddStory);
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

class _StoriesSearchField extends StatefulWidget {
  const _StoriesSearchField({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_StoriesSearchField> createState() => _StoriesSearchFieldState();
}

class _StoriesSearchFieldState extends State<_StoriesSearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _StoriesSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _StoriesTableCard.toolbarHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line.withValues(alpha: 0.72)),
      ),
      child: TextField(
        controller: _controller,
        mouseCursor: SystemMouseCursors.text,
        cursorColor: AppColors.support,
        textAlignVertical: TextAlignVertical.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.deepOcean,
          fontWeight: FontWeight.w400,
        ),
        decoration: InputDecoration(
          hintText: context.t('stories.searchPlaceholder'),
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
        onChanged: widget.onChanged,
      ),
    );
  }
}

class _AddStoryButton extends StatelessWidget {
  const _AddStoryButton({required this.onPressed});

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
            const SymbolIcon(Symbols.add, color: Colors.white, size: 17),
            const SizedBox(width: 7),
            Text(context.t('stories.addButton')),
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
              maximumSize: const Size(double.infinity, 34),
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
    required this.onEditStory,
    required this.onToggleStatus,
    required this.onOpenMedia,
    required this.onDeleteStory,
  });

  final List<AdminStory> stories;
  final bool loading;
  final Set<String> selectedStoryIds;
  final TableSortState sortState;
  final ValueChanged<String> onToggleStory;
  final VoidCallback onToggleAllStories;
  final ValueChanged<String> onSort;
  final ValueChanged<AdminStory> onEditStory;
  final ValueChanged<AdminStory> onToggleStatus;
  final ValueChanged<AdminStory> onOpenMedia;
  final ValueChanged<AdminStory> onDeleteStory;

  static const double _minWidth = 900;
  static const double _selectWidth = 42;
  static const double _idWidth = 62;
  static const double _storyMinWidth = 260;
  static const double _viewsWidth = 82;
  static const double _expiresWidth = 160;
  static const double _statusWidth = 112;
  static const double _menuWidth = 70;
  static const double _horizontalPadding = 32;
  static const double _tableBorderWidth = 2;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth = constraints.maxWidth < _minWidth
            ? _minWidth
            : constraints.maxWidth;
        final fixedWidth =
            _horizontalPadding +
            _tableBorderWidth +
            _selectWidth +
            _idWidth +
            _viewsWidth +
            _expiresWidth +
            _statusWidth +
            _menuWidth;
        final storyWidth = (tableWidth - fixedWidth) < _storyMinWidth
            ? _storyMinWidth
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
                        : SingleChildScrollView(
                            child: Column(
                              children: [
                                for (final story in stories)
                                  _StoriesRow(
                                    story: story,
                                    storyWidth: storyWidth,
                                    selected: selectedStoryIds.contains(
                                      story.id,
                                    ),
                                    onToggle: () => onToggleStory(story.id),
                                    onEditStory: onEditStory,
                                    onToggleStatus: onToggleStatus,
                                    onOpenMedia: onOpenMedia,
                                    onDeleteStory: onDeleteStory,
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

class _StoriesRow extends StatelessWidget {
  const _StoriesRow({
    required this.story,
    required this.storyWidth,
    required this.selected,
    required this.onToggle,
    required this.onEditStory,
    required this.onToggleStatus,
    required this.onOpenMedia,
    required this.onDeleteStory,
  });

  final AdminStory story;
  final double storyWidth;
  final bool selected;
  final VoidCallback onToggle;
  final ValueChanged<AdminStory> onEditStory;
  final ValueChanged<AdminStory> onToggleStatus;
  final ValueChanged<AdminStory> onOpenMedia;
  final ValueChanged<AdminStory> onDeleteStory;

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
            child: _StoriesCheckbox(
              value: selected,
              onChanged: (_) => onToggle(),
            ),
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
          SizedBox(
            width: storyWidth,
            child: _StoryIdentity(story: story),
          ),
          SizedBox(
            width: _StoriesDataTable._viewsWidth,
            child: _ViewsCell(value: story.viewCount),
          ),
          SizedBox(
            width: _StoriesDataTable._expiresWidth,
            child: _ExpiresCell(dateTime: story.expiresAt),
          ),
          SizedBox(
            width: _StoriesDataTable._statusWidth,
            child: _StoryStatusBadge(story: story),
          ),
          SizedBox(
            width: _StoriesDataTable._menuWidth,
            child: Align(
              alignment: Alignment.center,
              child: _StoriesRowMenu(
                story: story,
                onEditStory: onEditStory,
                onToggleStatus: onToggleStatus,
                onOpenMedia: onOpenMedia,
                onDeleteStory: onDeleteStory,
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
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  _MediaTypeBadge(mediaType: story.displayMediaType),
                  _StoryMeta(story: story),
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
    final mediaType = story.displayMediaType;
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
        children: [
          Positioned.fill(
            child: url.isEmpty
                ? const Center(
                    child: SymbolIcon(
                      Symbols.photo_camera,
                      color: AppColors.iconMuted,
                      size: 20,
                    ),
                  )
                : Image.network(
                    _publicUrl(url),
                    width: 48,
                    height: 64,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (context, _, _) {
                      return const Center(
                        child: SymbolIcon(
                          Symbols.photo_camera,
                          color: AppColors.iconMuted,
                          size: 20,
                        ),
                      );
                    },
                  ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(AppRadius.value),
                border: Border.all(
                  color: AppColors.line.withValues(alpha: 0.55),
                ),
              ),
              child: Icon(
                mediaType == 'video'
                    ? Icons.videocam_outlined
                    : Icons.image_outlined,
                size: 12,
                color: AppColors.deepOcean,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaTypeBadge extends StatelessWidget {
  const _MediaTypeBadge({required this.mediaType});

  final String mediaType;

  @override
  Widget build(BuildContext context) {
    final key = mediaType == 'video'
        ? 'stories.media.video'
        : 'stories.media.image';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.deepOcean.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(AppRadius.value),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          context.t(key),
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

class _StoryMeta extends StatelessWidget {
  const _StoryMeta({required this.story});

  final AdminStory story;

  @override
  Widget build(BuildContext context) {
    return Text(
      [
        formatAdminFullDate(context, story.createdAt),
        if (story.displaySource != '-') story.displaySource,
      ].join(' - '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: AppColors.support,
        fontWeight: FontWeight.w500,
        fontSize: 10.5,
      ),
    );
  }
}

class _ViewsCell extends StatelessWidget {
  const _ViewsCell({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SymbolIcon(
            Symbols.visibility,
            color: AppColors.iconMuted,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            value.toString(),
            style: const TextStyle(
              color: AppColors.deepOcean,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpiresCell extends StatelessWidget {
  const _ExpiresCell({required this.dateTime});

  final DateTime? dateTime;

  @override
  Widget build(BuildContext context) {
    final value = dateTime;
    if (value == null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text(
          context.t('stories.noExpiry'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.support,
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
        ),
      );
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          formatAdminFullDate(context, value),
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
          formatAdminTime(value),
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
    final color = story.isActive
        ? const Color(0xFF198754)
        : AppColors.actionRed;
    final label = story.isActive
        ? 'stories.status.live'
        : 'stories.status.passive';

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
            Flexible(
              child: Text(
                context.t(label),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoriesRowMenu extends StatefulWidget {
  const _StoriesRowMenu({
    required this.story,
    required this.onEditStory,
    required this.onToggleStatus,
    required this.onOpenMedia,
    required this.onDeleteStory,
  });

  final AdminStory story;
  final ValueChanged<AdminStory> onEditStory;
  final ValueChanged<AdminStory> onToggleStatus;
  final ValueChanged<AdminStory> onOpenMedia;
  final ValueChanged<AdminStory> onDeleteStory;

  @override
  State<_StoriesRowMenu> createState() => _StoriesRowMenuState();
}

class _StoriesRowMenuState extends State<_StoriesRowMenu> {
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
              child: _StoriesMenuCard(
                story: widget.story,
                onEdit: () =>
                    _runAndClose(() => widget.onEditStory(widget.story)),
                onToggleStatus: () =>
                    _runAndClose(() => widget.onToggleStatus(widget.story)),
                onOpenMedia: () =>
                    _runAndClose(() => widget.onOpenMedia(widget.story)),
                onDelete: () =>
                    _runAndClose(() => widget.onDeleteStory(widget.story)),
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

class _StoriesMenuCard extends StatelessWidget {
  const _StoriesMenuCard({
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
            _StoriesMenuItem(
              icon: Symbols.edit_square,
              label: 'Edit',
              onTap: onEdit,
            ),
            _StoriesMenuItem(
              icon: story.isActive ? Symbols.visibility_off : Symbols.check,
              label: story.isActive
                  ? 'stories.actions.deactivate'
                  : 'stories.actions.activate',
              onTap: onToggleStatus,
            ),
            _StoriesMenuItem(
              icon: Symbols.open_in_new,
              label: 'stories.actions.viewMedia',
              onTap: onOpenMedia,
            ),
            _StoriesMenuItem(
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

class _StoriesMenuItem extends StatelessWidget {
  const _StoriesMenuItem({
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
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _mediaUrlController;
  late final TextEditingController _sourceController;
  late final TextEditingController _expiresController;
  late String _mediaType;
  late bool _active;

  @override
  void initState() {
    super.initState();
    final initial = widget.story == null
        ? StoryFormData.empty()
        : StoryFormData.fromStory(widget.story!);
    _titleController = TextEditingController(text: initial.title);
    _mediaUrlController = TextEditingController(text: initial.mediaUrl);
    _sourceController = TextEditingController(text: initial.sourceName);
    _expiresController = TextEditingController(
      text: _formatInputDate(initial.expiresAt),
    );
    _mediaType = initial.mediaType == 'video' ? 'video' : 'image';
    _active = initial.isActive;
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
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      StoryFormData(
        title: _titleController.text.trim(),
        mediaUrl: _mediaUrlController.text.trim(),
        mediaType: _mediaType,
        sourceName: _sourceController.text.trim(),
        expiresAt: _parseInputDate(_expiresController.text),
        isActive: _active,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.story != null;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                          const SizedBox(height: 8),
                          Text(
                            context.t('stories.dialog.subtitle'),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: AppColors.inkSoft,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0,
                                ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const SymbolIcon(
                        Symbols.close,
                        color: AppColors.deepOcean,
                        size: 20,
                      ),
                      tooltip: context.t('common.cancel'),
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 640;
                    final fields = [
                      _DialogTextField(
                        controller: _titleController,
                        label: context.t('stories.field.title'),
                        hint: context.t('stories.hint.title'),
                        icon: Symbols.photo_camera,
                        requiredField: true,
                      ),
                      _DialogTextField(
                        controller: _mediaUrlController,
                        label: context.t('stories.field.mediaUrl'),
                        hint: context.t('stories.hint.mediaUrl'),
                        icon: Symbols.open_in_new,
                        requiredField: true,
                      ),
                      _DialogSelectField(
                        label: context.t('stories.field.mediaType'),
                        value: _mediaType,
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _mediaType = value);
                        },
                      ),
                      _DialogTextField(
                        controller: _sourceController,
                        label: context.t('stories.field.sourceName'),
                        hint: context.t('stories.hint.sourceName'),
                        icon: Symbols.open_in_new,
                      ),
                      _DialogTextField(
                        controller: _expiresController,
                        label: context.t('stories.field.expiresAt'),
                        hint: context.t('stories.hint.expiresAt'),
                        icon: Symbols.schedule,
                        dateField: true,
                      ),
                    ];
                    if (compact) {
                      return Column(
                        children: [
                          for (final field in fields) ...[
                            field,
                            const SizedBox(height: 18),
                          ],
                        ],
                      );
                    }
                    return Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: fields[0]),
                            const SizedBox(width: 24),
                            Expanded(child: fields[1]),
                          ],
                        ),
                        const SizedBox(height: 22),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: fields[2]),
                            const SizedBox(width: 24),
                            Expanded(child: fields[3]),
                          ],
                        ),
                        const SizedBox(height: 22),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: fields[4]),
                            const SizedBox(width: 24),
                            Expanded(
                              child: _DialogStatusField(
                                active: _active,
                                onChanged: (value) {
                                  setState(() => _active = value);
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 26),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.deepOcean,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                        ),
                      ),
                      child: Text(context.t('common.cancel')),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 36,
                      child: TextButton(
                        onPressed: _submit,
                        style: TextButton.styleFrom(
                          backgroundColor: AppColors.deepOcean,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 30),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppRadius.value,
                            ),
                          ),
                          textStyle: const TextStyle(
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
    required this.icon,
    this.requiredField = false,
    this.dateField = false,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool requiredField;
  final bool dateField;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          requiredField ? '$label *' : label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: requiredField ? AppColors.actionRed : AppColors.deepOcean,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 9),
        TextFormField(
          controller: controller,
          cursorColor: AppColors.support,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.deepOcean,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.placeholder,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 4, right: 2),
              child: SymbolIcon(icon, color: AppColors.iconMuted, size: 18),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 31),
            filled: true,
            fillColor: Colors.white,
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.line),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.actionRed),
            ),
            errorBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.actionRed),
            ),
            focusedErrorBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.actionRed),
            ),
          ),
          validator: (value) {
            final trimmed = value?.trim() ?? '';
            if (requiredField && trimmed.isEmpty) {
              return context.t('stories.validation.required');
            }
            if (dateField &&
                trimmed.isNotEmpty &&
                _parseInputDate(trimmed) == null) {
              return context.t('stories.validation.date');
            }
            return null;
          },
        ),
      ],
    );
  }
}

class _DialogSelectField extends StatelessWidget {
  const _DialogSelectField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.deepOcean,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 9),
        DropdownButtonFormField<String>(
          initialValue: value,
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
          icon: const SymbolIcon(
            Symbols.keyboard_arrow_down,
            color: AppColors.iconMuted,
            size: 18,
          ),
          decoration: const InputDecoration(
            filled: true,
            fillColor: Colors.white,
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.line),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.actionRed),
            ),
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _DialogStatusField extends StatelessWidget {
  const _DialogStatusField({required this.active, required this.onChanged});

  final bool active;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.t('stories.field.status'),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.deepOcean,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 13),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            _DialogRadioOption(
              label: context.t('stories.status.live'),
              selected: active,
              onTap: () => onChanged(true),
            ),
            _DialogRadioOption(
              label: context.t('stories.status.passive'),
              selected: !active,
              onTap: () => onChanged(false),
            ),
          ],
        ),
      ],
    );
  }
}

class _DialogRadioOption extends StatelessWidget {
  const _DialogRadioOption({
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
                border: Border.all(color: AppColors.deepOcean, width: 2),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.deepOcean,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 7),
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

String _publicUrl(String value) {
  if (value.startsWith('http://') ||
      value.startsWith('https://') ||
      value.startsWith('data:')) {
    return value;
  }
  final base = !kIsWeb
      ? switch (defaultTargetPlatform) {
          TargetPlatform.android => Uri.parse('http://10.0.2.2:4321'),
          _ => Uri.parse('http://localhost:4321'),
        }
      : Uri.base;
  return base.resolve(value).toString();
}

DateTime? _parseInputDate(String value) {
  final raw = value.trim();
  if (raw.isEmpty) return null;
  return DateTime.tryParse(raw.replaceFirst(' ', 'T'));
}

String _formatInputDate(DateTime? value) {
  if (value == null) return '';
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')} '
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
}
