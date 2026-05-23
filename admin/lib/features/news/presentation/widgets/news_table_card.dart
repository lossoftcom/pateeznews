import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../../core/localization/admin_date_formatter.dart';
import '../../../../core/localization/admin_language_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../shared/widgets/sortable_table_header.dart';
import '../../../../shared/widgets/symbol_icon.dart';
import '../news_models.dart';
import 'news_link_opener.dart';

class NewsTableCard extends StatelessWidget {
  const NewsTableCard({
    super.key,
    required this.posts,
    required this.filterOptions,
    required this.loading,
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.searchQuery,
    required this.languageFilter,
    required this.categoryFilter,
    required this.typeFilter,
    required this.statusFilter,
    required this.publisherFilter,
    required this.selectedPostIds,
    required this.sortState,
    required this.onPageSizeChanged,
    required this.onSearchChanged,
    required this.onLanguageChanged,
    required this.onCategoryChanged,
    required this.onTypeChanged,
    required this.onStatusChanged,
    required this.onPublisherChanged,
    required this.onPageChanged,
    required this.onTogglePost,
    required this.onToggleAllPosts,
    required this.onSort,
    required this.onAddPost,
    required this.onEditPost,
    required this.onToggleStatus,
    required this.onTogglePinned,
    required this.onDeletePost,
    required this.onDeleteSelected,
  });

  final List<AdminNewsPost> posts;
  final AdminNewsFilterOptions filterOptions;
  final bool loading;
  final int page;
  final int pageSize;
  final int totalCount;
  final String searchQuery;
  final String languageFilter;
  final String categoryFilter;
  final String typeFilter;
  final String statusFilter;
  final String publisherFilter;
  final Set<String> selectedPostIds;
  final TableSortState sortState;
  final ValueChanged<int?> onPageSizeChanged;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onLanguageChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String?> onTypeChanged;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onPublisherChanged;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<String> onTogglePost;
  final VoidCallback onToggleAllPosts;
  final ValueChanged<String> onSort;
  final VoidCallback onAddPost;
  final ValueChanged<AdminNewsPost> onEditPost;
  final ValueChanged<AdminNewsPost> onToggleStatus;
  final ValueChanged<AdminNewsPost> onTogglePinned;
  final ValueChanged<AdminNewsPost> onDeletePost;
  final VoidCallback onDeleteSelected;

  static const double toolbarHeight = 38;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _NewsFilters(
          filterOptions: filterOptions,
          languageFilter: languageFilter,
          categoryFilter: categoryFilter,
          typeFilter: typeFilter,
          statusFilter: statusFilter,
          publisherFilter: publisherFilter,
          onLanguageChanged: onLanguageChanged,
          onCategoryChanged: onCategoryChanged,
          onTypeChanged: onTypeChanged,
          onStatusChanged: onStatusChanged,
          onPublisherChanged: onPublisherChanged,
        ),
        const SizedBox(height: 28),
        _NewsToolbar(
          pageSize: pageSize,
          searchQuery: searchQuery,
          selectedCount: selectedPostIds.length,
          onPageSizeChanged: onPageSizeChanged,
          onSearchChanged: onSearchChanged,
          onAddPost: onAddPost,
          onDeleteSelected: onDeleteSelected,
        ),
        const SizedBox(height: 18),
        Expanded(
          child: _NewsDataTable(
            posts: posts,
            loading: loading,
            selectedPostIds: selectedPostIds,
            sortState: sortState,
            onTogglePost: onTogglePost,
            onToggleAllPosts: onToggleAllPosts,
            onSort: onSort,
            onEditPost: onEditPost,
            onToggleStatus: onToggleStatus,
            onTogglePinned: onTogglePinned,
            onDeletePost: onDeletePost,
          ),
        ),
        const SizedBox(height: 16),
        _NewsFooter(
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

class _NewsFilters extends StatelessWidget {
  const _NewsFilters({
    required this.filterOptions,
    required this.languageFilter,
    required this.categoryFilter,
    required this.typeFilter,
    required this.statusFilter,
    required this.publisherFilter,
    required this.onLanguageChanged,
    required this.onCategoryChanged,
    required this.onTypeChanged,
    required this.onStatusChanged,
    required this.onPublisherChanged,
  });

  final AdminNewsFilterOptions filterOptions;
  final String languageFilter;
  final String categoryFilter;
  final String typeFilter;
  final String statusFilter;
  final String publisherFilter;
  final ValueChanged<String?> onLanguageChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String?> onTypeChanged;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onPublisherChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 1040;
        final filters = [
          _FilterSelect(
            label: 'Language',
            value: languageFilter,
            items: [
              DropdownMenuItem(value: 'Tümü', child: Text(context.t('All'))),
              for (final language in filterOptions.languages)
                DropdownMenuItem(
                  value: language.id,
                  child: Text(language.label),
                ),
            ],
            onChanged: onLanguageChanged,
          ),
          _FilterSelect(
            label: 'Category',
            value: categoryFilter,
            items: [
              DropdownMenuItem(value: 'Tümü', child: Text(context.t('All'))),
              for (final category in filterOptions.categories)
                DropdownMenuItem(
                  value: category.id,
                  child: Text(category.displayLabel),
                ),
            ],
            onChanged: onCategoryChanged,
          ),
          _FilterSelect(
            label: 'Type',
            value: typeFilter,
            items: [
              DropdownMenuItem(value: 'Tümü', child: Text(context.t('All'))),
              for (final type in filterOptions.types)
                DropdownMenuItem(
                  value: type.id,
                  child: Text(context.t(_typeLabel(type.label))),
                ),
            ],
            onChanged: onTypeChanged,
          ),
          _FilterSelect(
            label: 'Status',
            value: statusFilter,
            items: [
              DropdownMenuItem(value: 'Tümü', child: Text(context.t('All'))),
              DropdownMenuItem(
                value: 'published',
                child: Text(context.t('Published')),
              ),
              DropdownMenuItem(value: 'draft', child: Text(context.t('Draft'))),
            ],
            onChanged: onStatusChanged,
          ),
          _FilterSelect(
            label: 'Publisher',
            value: publisherFilter,
            items: [
              DropdownMenuItem(value: 'Tümü', child: Text(context.t('All'))),
              for (final publisher in filterOptions.publishers)
                DropdownMenuItem(
                  value: publisher.id,
                  child: Text(publisher.label),
                ),
            ],
            onChanged: onPublisherChanged,
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
        Text(
          context.t(label),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.deepOcean,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 8),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            height: NewsTableCard.toolbarHeight,
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

class _NewsToolbar extends StatelessWidget {
  const _NewsToolbar({
    required this.pageSize,
    required this.searchQuery,
    required this.selectedCount,
    required this.onPageSizeChanged,
    required this.onSearchChanged,
    required this.onAddPost,
    required this.onDeleteSelected,
  });

  final int pageSize;
  final String searchQuery;
  final int selectedCount;
  final ValueChanged<int?> onPageSizeChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onAddPost;
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
          child: _NewsSearchField(
            value: searchQuery,
            onChanged: onSearchChanged,
          ),
        );
        final addButton = _AddPostButton(onPressed: onAddPost);
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
        height: NewsTableCard.toolbarHeight,
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

class _NewsSearchField extends StatefulWidget {
  const _NewsSearchField({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_NewsSearchField> createState() => _NewsSearchFieldState();
}

class _NewsSearchFieldState extends State<_NewsSearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _NewsSearchField oldWidget) {
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
      height: NewsTableCard.toolbarHeight,
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
          hintText: context.t('Search posts...'),
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
            minHeight: NewsTableCard.toolbarHeight,
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

class _AddPostButton extends StatelessWidget {
  const _AddPostButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: NewsTableCard.toolbarHeight,
      child: TextButton(
        onPressed: onPressed,
        style:
            TextButton.styleFrom(
              backgroundColor: AppColors.actionRed,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, NewsTableCard.toolbarHeight),
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
            Text(context.t('Add Post')),
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
                'news.selectedDelete',
                values: {'count': selectedCount},
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewsDataTable extends StatelessWidget {
  const _NewsDataTable({
    required this.posts,
    required this.loading,
    required this.selectedPostIds,
    required this.sortState,
    required this.onTogglePost,
    required this.onToggleAllPosts,
    required this.onSort,
    required this.onEditPost,
    required this.onToggleStatus,
    required this.onTogglePinned,
    required this.onDeletePost,
  });

  final List<AdminNewsPost> posts;
  final bool loading;
  final Set<String> selectedPostIds;
  final TableSortState sortState;
  final ValueChanged<String> onTogglePost;
  final VoidCallback onToggleAllPosts;
  final ValueChanged<String> onSort;
  final ValueChanged<AdminNewsPost> onEditPost;
  final ValueChanged<AdminNewsPost> onToggleStatus;
  final ValueChanged<AdminNewsPost> onTogglePinned;
  final ValueChanged<AdminNewsPost> onDeletePost;

  static const double _minWidth = 1520;
  static const double _selectWidth = 42;
  static const double _idWidth = 70;
  static const double _postMinWidth = 500;
  static const double _categoryWidth = 130;
  static const double _statusWidth = 128;
  static const double _languageWidth = 70;
  static const double _authorWidth = 166;
  static const double _viewsWidth = 82;
  static const double _commentsWidth = 82;
  static const double _createdWidth = 210;
  static const double _menuWidth = 76;
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
            _categoryWidth +
            _statusWidth +
            _languageWidth +
            _authorWidth +
            _viewsWidth +
            _commentsWidth +
            _createdWidth +
            _menuWidth;
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
                  _NewsHeader(
                    selectedCount: selectedPostIds.length,
                    totalCount: posts.length,
                    postWidth: postWidth,
                    sortState: sortState,
                    onToggleAllPosts: onToggleAllPosts,
                    onSort: onSort,
                  ),
                  Expanded(
                    child: loading && posts.isEmpty
                        ? const _NewsLoading()
                        : posts.isEmpty
                        ? const _NewsEmpty()
                        : SingleChildScrollView(
                            child: Column(
                              children: [
                                for (final post in posts)
                                  _NewsRow(
                                    post: post,
                                    postWidth: postWidth,
                                    selected: selectedPostIds.contains(post.id),
                                    onToggle: () => onTogglePost(post.id),
                                    onEditPost: onEditPost,
                                    onToggleStatus: onToggleStatus,
                                    onTogglePinned: onTogglePinned,
                                    onDeletePost: onDeletePost,
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

class _NewsHeader extends StatelessWidget {
  const _NewsHeader({
    required this.selectedCount,
    required this.totalCount,
    required this.postWidth,
    required this.sortState,
    required this.onToggleAllPosts,
    required this.onSort,
  });

  final int selectedCount;
  final int totalCount;
  final double postWidth;
  final TableSortState sortState;
  final VoidCallback onToggleAllPosts;
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
            width: _NewsDataTable._selectWidth,
            child: _NewsCheckbox(
              value: selectedCount == 0 || totalCount == 0
                  ? false
                  : selectedCount == totalCount
                  ? true
                  : null,
              tristate: true,
              onChanged: (_) => onToggleAllPosts(),
            ),
          ),
          _SortableColumnHeader(
            width: _NewsDataTable._idWidth,
            label: 'ID',
            sortKey: 'id',
            sortState: sortState,
            onSort: onSort,
          ),
          _SortableColumnHeader(
            width: postWidth,
            label: 'Post',
            sortKey: 'post',
            sortState: sortState,
            onSort: onSort,
          ),
          _SortableColumnHeader(
            width: _NewsDataTable._categoryWidth,
            label: 'Category',
            sortKey: 'category',
            sortState: sortState,
            onSort: onSort,
            centered: true,
          ),
          _SortableColumnHeader(
            width: _NewsDataTable._statusWidth,
            label: 'Status',
            sortKey: 'status',
            sortState: sortState,
            onSort: onSort,
            centered: true,
          ),
          _SortableColumnHeader(
            width: _NewsDataTable._languageWidth,
            label: 'Language',
            sortKey: 'language',
            sortState: sortState,
            onSort: onSort,
            centered: true,
          ),
          _SortableColumnHeader(
            width: _NewsDataTable._authorWidth,
            label: 'Author',
            sortKey: 'author',
            sortState: sortState,
            onSort: onSort,
          ),
          _SortableColumnHeader(
            width: _NewsDataTable._viewsWidth,
            label: 'Views',
            sortKey: 'views',
            sortState: sortState,
            onSort: onSort,
            centered: true,
          ),
          _SortableColumnHeader(
            width: _NewsDataTable._commentsWidth,
            label: 'Comment',
            sortKey: 'comments',
            sortState: sortState,
            onSort: onSort,
            centered: true,
          ),
          _SortableColumnHeader(
            width: _NewsDataTable._createdWidth,
            label: 'Date',
            sortKey: 'date',
            sortState: sortState,
            onSort: onSort,
          ),
          const SizedBox(
            width: _NewsDataTable._menuWidth,
            child: _HeaderText('Action', centered: true),
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

class _NewsRow extends StatelessWidget {
  const _NewsRow({
    required this.post,
    required this.postWidth,
    required this.selected,
    required this.onToggle,
    required this.onEditPost,
    required this.onToggleStatus,
    required this.onTogglePinned,
    required this.onDeletePost,
  });

  final AdminNewsPost post;
  final double postWidth;
  final bool selected;
  final VoidCallback onToggle;
  final ValueChanged<AdminNewsPost> onEditPost;
  final ValueChanged<AdminNewsPost> onToggleStatus;
  final ValueChanged<AdminNewsPost> onTogglePinned;
  final ValueChanged<AdminNewsPost> onDeletePost;

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
            width: _NewsDataTable._selectWidth,
            child: _NewsCheckbox(value: selected, onChanged: (_) => onToggle()),
          ),
          SizedBox(
            width: _NewsDataTable._idWidth,
            child: _RowSelectTapTarget(
              onTap: onToggle,
              child: Text(
                post.id,
                style: const TextStyle(
                  color: AppColors.deepOcean,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          SizedBox(
            width: postWidth,
            child: _PostIdentity(post: post),
          ),
          SizedBox(
            width: _NewsDataTable._categoryWidth,
            child: _CategoryCell(post: post),
          ),
          SizedBox(
            width: _NewsDataTable._statusWidth,
            child: _NewsStatusBadge(post: post),
          ),
          SizedBox(
            width: _NewsDataTable._languageWidth,
            child: Center(child: _LanguageBadge(value: post.displayLanguage)),
          ),
          SizedBox(
            width: _NewsDataTable._authorWidth,
            child: _AuthorCell(post: post),
          ),
          SizedBox(
            width: _NewsDataTable._viewsWidth,
            child: _NumberCell(value: post.likesCount),
          ),
          SizedBox(
            width: _NewsDataTable._commentsWidth,
            child: _NumberCell(value: post.commentsCount),
          ),
          SizedBox(
            width: _NewsDataTable._createdWidth,
            child: _DateCell(dateTime: post.createdAt),
          ),
          SizedBox(
            width: _NewsDataTable._menuWidth,
            child: Align(
              alignment: Alignment.center,
              child: _NewsRowMenu(
                post: post,
                onEditPost: onEditPost,
                onToggleStatus: onToggleStatus,
                onTogglePinned: onTogglePinned,
                onDeletePost: onDeletePost,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NewsCheckbox extends StatelessWidget {
  const _NewsCheckbox({
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

class _PostIdentity extends StatelessWidget {
  const _PostIdentity({required this.post});

  final AdminNewsPost post;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _PostThumbnail(post: post),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (post.isPinned) ...[
                    Tooltip(
                      message: context.t('Pinned'),
                      child: const SymbolIcon(
                        Symbols.push_pin,
                        color: AppColors.warmHorizon,
                        size: 15,
                      ),
                    ),
                    const SizedBox(width: 5),
                  ],
                  Expanded(child: _PostTitleLink(post: post)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Flexible(
                    child: _TypeBadge(
                      label: context.t(_typeLabel(post.displayType)),
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

class _PostThumbnail extends StatelessWidget {
  const _PostThumbnail({required this.post});

  final AdminNewsPost post;

  @override
  Widget build(BuildContext context) {
    final url = post.thumbnailUrl.trim();
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line.withValues(alpha: 0.72)),
      ),
      clipBehavior: Clip.antiAlias,
      child: url.isEmpty
          ? const Center(
              child: SymbolIcon(
                Symbols.visibility,
                color: AppColors.iconMuted,
                size: 22,
              ),
            )
          : Image.network(
              _publicUrl(url),
              width: 60,
              height: 60,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
              errorBuilder: (context, _, _) {
                return const Center(
                  child: SymbolIcon(
                    Symbols.visibility,
                    color: AppColors.iconMuted,
                    size: 22,
                  ),
                );
              },
            ),
    );
  }
}

class _PostTitleLink extends StatefulWidget {
  const _PostTitleLink({required this.post});

  final AdminNewsPost post;

  @override
  State<_PostTitleLink> createState() => _PostTitleLinkState();
}

class _PostTitleLinkState extends State<_PostTitleLink> {
  var _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => unawaited(openNewsLink(_postUrl(widget.post))),
        child: Text(
          widget.post.displayTitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: _hovering ? AppColors.actionRed : AppColors.deepOcean,
            fontWeight: FontWeight.w600,
            fontSize: 13,
            height: 1.22,
            decoration: _hovering ? TextDecoration.underline : null,
            decorationColor: AppColors.actionRed,
          ),
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.label});

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

class _CategoryCell extends StatelessWidget {
  const _CategoryCell({required this.post});

  final AdminNewsPost post;

  @override
  Widget build(BuildContext context) {
    final parent = post.parentCategory?.trim();
    final child = Text(
      post.displayCategory,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: AppColors.deepOcean,
        fontWeight: FontWeight.w600,
        fontSize: 11.5,
      ),
    );

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (parent != null && parent.isNotEmpty) ...[
          Text(
            parent,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.deepOcean,
              fontWeight: FontWeight.w600,
              fontSize: 10.5,
            ),
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '\u21B3',
                style: TextStyle(
                  color: AppColors.support,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                  height: 1,
                ),
              ),
              const SizedBox(width: 4),
              Flexible(child: child),
            ],
          ),
        ] else ...[
          child,
        ],
      ],
    );
  }
}

class _NewsStatusBadge extends StatelessWidget {
  const _NewsStatusBadge({required this.post});

  final AdminNewsPost post;

  @override
  Widget build(BuildContext context) {
    final color = post.published ? const Color(0xFF198754) : AppColors.support;
    final label = post.published ? 'Published' : 'Draft';

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

class _LanguageBadge extends StatelessWidget {
  const _LanguageBadge({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final label = _languageLabel(value);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.support.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppRadius.value),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            height: 1,
          ),
        ),
      ),
    );
  }
}

String _languageLabel(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return 'Tr';
  return trimmed[0].toUpperCase() + trimmed.substring(1).toLowerCase();
}

class _AuthorCell extends StatelessWidget {
  const _AuthorCell({required this.post});

  final AdminNewsPost post;

  @override
  Widget build(BuildContext context) {
    final username = post.displayPublisherUsername;
    final email = post.displayPublisherEmail;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          post.displayPublisher,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.inkSoft,
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
        ),
        if (username.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            username,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.support,
              fontWeight: FontWeight.w500,
              fontSize: 10,
            ),
          ),
        ],
        if (email.isNotEmpty) ...[
          const SizedBox(height: 1),
          Text(
            email,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.support,
              fontWeight: FontWeight.w400,
              fontSize: 10,
            ),
          ),
        ],
      ],
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
  const _DateCell({required this.dateTime});

  final DateTime? dateTime;

  @override
  Widget build(BuildContext context) {
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

class _NewsRowMenu extends StatefulWidget {
  const _NewsRowMenu({
    required this.post,
    required this.onEditPost,
    required this.onToggleStatus,
    required this.onTogglePinned,
    required this.onDeletePost,
  });

  final AdminNewsPost post;
  final ValueChanged<AdminNewsPost> onEditPost;
  final ValueChanged<AdminNewsPost> onToggleStatus;
  final ValueChanged<AdminNewsPost> onTogglePinned;
  final ValueChanged<AdminNewsPost> onDeletePost;

  @override
  State<_NewsRowMenu> createState() => _NewsRowMenuState();
}

class _NewsRowMenuState extends State<_NewsRowMenu> {
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
              child: _NewsMenuCard(
                post: widget.post,
                onEdit: () =>
                    _runAndClose(() => widget.onEditPost(widget.post)),
                onToggleStatus: () =>
                    _runAndClose(() => widget.onToggleStatus(widget.post)),
                onTogglePinned: () =>
                    _runAndClose(() => widget.onTogglePinned(widget.post)),
                onDelete: () =>
                    _runAndClose(() => widget.onDeletePost(widget.post)),
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
        message: context.t('Post actions'),
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

class _NewsMenuCard extends StatelessWidget {
  const _NewsMenuCard({
    required this.post,
    required this.onEdit,
    required this.onToggleStatus,
    required this.onTogglePinned,
    required this.onDelete,
  });

  final AdminNewsPost post;
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;
  final VoidCallback onTogglePinned;
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
            _NewsMenuItem(
              icon: Symbols.edit_square,
              label: 'Edit',
              onTap: onEdit,
            ),
            _NewsMenuItem(
              icon: post.published ? Symbols.visibility_off : Symbols.check,
              label: post.published ? 'Unpublish' : 'Publish',
              onTap: onToggleStatus,
            ),
            _NewsMenuItem(
              icon: post.isPinned ? Symbols.visibility_off : Symbols.verified,
              label: post.isPinned ? 'Unpin' : 'Pin',
              onTap: onTogglePinned,
            ),
            _NewsMenuItem(
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

class _NewsMenuItem extends StatelessWidget {
  const _NewsMenuItem({
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

class _NewsLoading extends StatelessWidget {
  const _NewsLoading();

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

class _NewsEmpty extends StatelessWidget {
  const _NewsEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        context.t('No posts found'),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.inkSoft,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _NewsFooter extends StatelessWidget {
  const _NewsFooter({
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
        final pager = _NewsPagination(
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

class _NewsPagination extends StatelessWidget {
  const _NewsPagination({
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

String _typeLabel(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) return 'standard';
  final key = 'admin.post.tab.$normalized';
  return key;
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

String _postUrl(AdminNewsPost post) {
  final slugOrId = post.slug.trim().isEmpty ? post.id : post.slug.trim();
  return _siteBaseUri()
      .resolve('/haber/${Uri.encodeComponent(slugOrId)}')
      .toString();
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
