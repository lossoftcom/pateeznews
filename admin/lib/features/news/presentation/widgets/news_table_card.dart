import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart' as youtube;

import '../../../../core/localization/admin_date_formatter.dart';
import '../../../../core/localization/admin_language_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../frontend/core/mock/home_mock_data.dart';
import '../../../../frontend/features/news_detail/presentation/news_detail_screen.dart';
import '../../../../frontend/features/search/data/search_repository.dart';
import '../../../../shared/data/admin_image_url.dart';
import '../../../../shared/widgets/admin_cached_image.dart';
import '../../../../shared/widgets/admin_mobile_list.dart';
import '../../../../shared/widgets/admin_table_chrome.dart';
import '../../../../shared/widgets/highlighted_text.dart';
import '../../../../shared/widgets/sortable_table_header.dart';
import '../../../../shared/widgets/symbol_icon.dart';
import '../news_models.dart';
import 'news_link_opener.dart';

class _NewsVideoDetailColumns {
  const _NewsVideoDetailColumns({
    required this.platform,
    required this.date,
    required this.size,
    required this.views,
  });

  factory _NewsVideoDetailColumns.forWidth(double width) {
    final safeWidth = width.isFinite ? width : 1180.0;
    return _NewsVideoDetailColumns(
      platform: (safeWidth * 0.105).clamp(146.0, 184.0).toDouble(),
      date: (safeWidth * 0.155).clamp(198.0, 258.0).toDouble(),
      size: (safeWidth * 0.082).clamp(104.0, 132.0).toDouble(),
      views: (safeWidth * 0.058).clamp(82.0, 96.0).toDouble(),
    );
  }

  final double platform;
  final double date;
  final double size;
  final double views;
}

/// Aktif arama sorgusunu satır hücrelerine (başlık/kategori/yazar/ID) taşır;
/// böylece highlight için her hücreye tek tek parametre geçmeye gerek kalmaz.
class _NewsSearchScope extends InheritedWidget {
  const _NewsSearchScope({required this.query, required super.child});

  final String query;

  static String of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_NewsSearchScope>()?.query ??
      '';

  @override
  bool updateShouldNotify(_NewsSearchScope oldWidget) =>
      oldWidget.query != query;
}

class NewsTableCard extends StatelessWidget {
  const NewsTableCard({
    super.key,
    required this.posts,
    required this.filterOptions,
    required this.loading,
    required this.loadingLabel,
    this.searching = false,
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
    required this.trashMode,
    required this.videoOnly,
    required this.canManagePublication,
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
    required this.onSharePost,
    required this.onNotifyPost,
    required this.onToggleStatus,
    required this.onTogglePinned,
    required this.onDeletePost,
    required this.onDeleteSelected,
    required this.onToggleTrashMode,
    required this.onToggleVideoOnly,
  });

  final List<AdminNewsPost> posts;
  final AdminNewsFilterOptions filterOptions;
  final bool loading;
  final String loadingLabel;
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
  final bool trashMode;
  final bool videoOnly;
  final bool canManagePublication;
  final bool searching;
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
  final ValueChanged<AdminNewsPost> onSharePost;
  final ValueChanged<AdminNewsPost> onNotifyPost;
  final ValueChanged<AdminNewsPost> onToggleStatus;
  final ValueChanged<AdminNewsPost> onTogglePinned;
  final ValueChanged<AdminNewsPost> onDeletePost;
  final VoidCallback onDeleteSelected;
  final VoidCallback onToggleTrashMode;
  final VoidCallback onToggleVideoOnly;

  static const double toolbarHeight = 38;

  @override
  Widget build(BuildContext context) {
    return _NewsSearchScope(
      query: searchQuery,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final mobile = constraints.maxWidth < 800;

          if (mobile) {
            return _NewsMobileView(
              posts: posts,
              filterOptions: filterOptions,
              loading: loading,
              loadingLabel: loadingLabel,
              page: page,
              pageSize: pageSize,
              totalCount: totalCount,
              searchQuery: searchQuery,
              languageFilter: languageFilter,
              categoryFilter: categoryFilter,
              typeFilter: typeFilter,
              statusFilter: statusFilter,
              publisherFilter: publisherFilter,
              selectedPostIds: selectedPostIds,
              trashMode: trashMode,
              videoOnly: videoOnly,
              canManagePublication: canManagePublication,
              onPageSizeChanged: onPageSizeChanged,
              onSearchChanged: onSearchChanged,
              onLanguageChanged: onLanguageChanged,
              onCategoryChanged: onCategoryChanged,
              onTypeChanged: onTypeChanged,
              onStatusChanged: onStatusChanged,
              onPublisherChanged: onPublisherChanged,
              onPageChanged: onPageChanged,
              onTogglePost: onTogglePost,
              onAddPost: onAddPost,
              onEditPost: onEditPost,
              onSharePost: onSharePost,
              onNotifyPost: onNotifyPost,
              onToggleStatus: onToggleStatus,
              onTogglePinned: onTogglePinned,
              onDeletePost: onDeletePost,
              onDeleteSelected: onDeleteSelected,
              onToggleTrashMode: onToggleTrashMode,
              onToggleVideoOnly: onToggleVideoOnly,
            );
          }

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
                trashMode: trashMode,
                videoOnly: videoOnly,
                onPageSizeChanged: onPageSizeChanged,
                onSearchChanged: onSearchChanged,
                onAddPost: onAddPost,
                onDeleteSelected: onDeleteSelected,
                onToggleTrashMode: onToggleTrashMode,
                onToggleVideoOnly: onToggleVideoOnly,
              ),
              const SizedBox(height: 18),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: videoOnly
                          ? _NewsVideoLibrary(
                              posts: posts,
                              loading: loading,
                              loadingLabel: loadingLabel,
                              searching: false,
                              searchQuery: searchQuery,
                              onEditPost: onEditPost,
                            )
                          : _NewsDataTable(
                              posts: posts,
                              loading: loading,
                              loadingLabel: loadingLabel,
                              searching: searching,
                              selectedPostIds: selectedPostIds,
                              sortState: sortState,
                              trashMode: trashMode,
                              canManagePublication: canManagePublication,
                              onTogglePost: onTogglePost,
                              onToggleAllPosts: onToggleAllPosts,
                              onSort: onSort,
                              onEditPost: onEditPost,
                              onSharePost: onSharePost,
                              onNotifyPost: onNotifyPost,
                              onToggleStatus: onToggleStatus,
                              onTogglePinned: onTogglePinned,
                              onDeletePost: onDeletePost,
                            ),
                    ),
                    if (loading && posts.isNotEmpty)
                      Positioned.fill(
                        child: _NewsLoadingOverlay(label: loadingLabel),
                      ),
                  ],
                ),
              ),
              if (!videoOnly) ...[
                const SizedBox(height: 16),
                _NewsFooter(
                  page: page,
                  pageSize: pageSize,
                  totalCount: totalCount,
                  loading: loading,
                  onPageChanged: onPageChanged,
                ),
              ],
            ],
          );
        },
      ),
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
    required this.trashMode,
    required this.videoOnly,
    required this.onPageSizeChanged,
    required this.onSearchChanged,
    required this.onAddPost,
    required this.onDeleteSelected,
    required this.onToggleTrashMode,
    required this.onToggleVideoOnly,
  });

  final int pageSize;
  final String searchQuery;
  final int selectedCount;
  final bool trashMode;
  final bool videoOnly;
  final ValueChanged<int?> onPageSizeChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onAddPost;
  final VoidCallback onDeleteSelected;
  final VoidCallback onToggleTrashMode;
  final VoidCallback onToggleVideoOnly;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final pageSizeSelect = videoOnly
            ? const SizedBox.shrink()
            : _PageSizeSelect(value: pageSize, onChanged: onPageSizeChanged);
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
        final trashButton = _TrashToggleButton(
          active: trashMode,
          onPressed: onToggleTrashMode,
        );
        final videoButton = _VideoToggleButton(
          active: videoOnly,
          onPressed: onToggleVideoOnly,
        );
        final deleteButton = selectedCount == 0
            ? null
            : _BulkDeleteButton(
                selectedCount: selectedCount,
                permanent: trashMode,
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
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [trashButton, videoButton, addButton],
              ),
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
            trashButton,
            const SizedBox(width: 10),
            videoButton,
            const SizedBox(width: 10),
            addButton,
          ],
        );
      },
    );
  }
}

class _TrashToggleButton extends StatelessWidget {
  const _TrashToggleButton({required this.active, required this.onPressed});

  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: NewsTableCard.toolbarHeight,
      child: Tooltip(
        message: context.t(active ? 'news.activePosts' : 'news.trash'),
        child: TextButton(
          onPressed: onPressed,
          style:
              TextButton.styleFrom(
                backgroundColor: active ? AppColors.deepOcean : Colors.white,
                foregroundColor: active ? Colors.white : AppColors.deepOcean,
                side: BorderSide(
                  color: active
                      ? AppColors.deepOcean
                      : AppColors.line.withValues(alpha: 0.82),
                ),
                minimumSize: const Size(0, NewsTableCard.toolbarHeight),
                padding: const EdgeInsets.symmetric(horizontal: 13),
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
              SymbolIcon(
                active ? Symbols.newspaper : Symbols.delete,
                color: active ? Colors.white : AppColors.deepOcean,
                size: 17,
              ),
              const SizedBox(width: 7),
              Text(context.t(active ? 'news.activePosts' : 'news.trash')),
            ],
          ),
        ),
      ),
    );
  }
}

class _VideoToggleButton extends StatelessWidget {
  const _VideoToggleButton({required this.active, required this.onPressed});

  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final foreground = active ? Colors.white : AppColors.deepOcean;
    return SizedBox(
      height: NewsTableCard.toolbarHeight,
      child: Tooltip(
        message: context.t('news.videos.filter'),
        child: TextButton(
          onPressed: onPressed,
          style:
              TextButton.styleFrom(
                backgroundColor: active ? AppColors.deepOcean : Colors.white,
                foregroundColor: foreground,
                side: BorderSide(
                  color: active
                      ? AppColors.deepOcean
                      : AppColors.line.withValues(alpha: 0.82),
                ),
                minimumSize: const Size(0, NewsTableCard.toolbarHeight),
                padding: const EdgeInsets.symmetric(horizontal: 13),
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
              SymbolIcon(
                active
                    ? Symbols.play_circle_rounded
                    : Symbols.play_circle_outline_rounded,
                color: foreground,
                size: 17,
              ),
              const SizedBox(width: 7),
              Text(context.t('news.videos.filter')),
            ],
          ),
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
  final FocusNode _focusNode = FocusNode();

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
    _focusNode.dispose();
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
        focusNode: _focusNode,
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
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _controller,
            builder: (context, value, _) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return _SearchClearButton(
                onTap: () {
                  _controller.clear();
                  widget.onChanged('');
                  _focusNode.requestFocus();
                },
              );
            },
          ),
          suffixIconConstraints: const BoxConstraints(
            minWidth: 38,
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

class _SearchClearButton extends StatefulWidget {
  const _SearchClearButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_SearchClearButton> createState() => _SearchClearButtonState();
}

class _SearchClearButtonState extends State<_SearchClearButton> {
  var _hovering = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: context.t('news.search.clear'),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.only(left: 4, right: 8),
            child: Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _hovering
                    ? AppColors.line.withValues(alpha: 0.55)
                    : AppColors.surface,
                shape: BoxShape.circle,
              ),
              child: SymbolIcon(
                Symbols.close,
                color: _hovering ? AppColors.deepOcean : AppColors.iconMuted,
                size: 13,
              ),
            ),
          ),
        ),
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
    required this.permanent,
    required this.onPressed,
  });

  final int selectedCount;
  final bool permanent;
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
                permanent
                    ? 'news.selectedPermanentDelete'
                    : 'news.selectedDelete',
                values: {'count': selectedCount},
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewsDataTable extends StatefulWidget {
  const _NewsDataTable({
    required this.posts,
    required this.loading,
    required this.loadingLabel,
    this.searching = false,
    required this.selectedPostIds,
    required this.sortState,
    required this.trashMode,
    required this.canManagePublication,
    required this.onTogglePost,
    required this.onToggleAllPosts,
    required this.onSort,
    required this.onEditPost,
    required this.onSharePost,
    required this.onNotifyPost,
    required this.onToggleStatus,
    required this.onTogglePinned,
    required this.onDeletePost,
  });

  final List<AdminNewsPost> posts;
  final bool loading;
  final String loadingLabel;
  final bool searching;
  final Set<String> selectedPostIds;
  final TableSortState sortState;
  final bool trashMode;
  final bool canManagePublication;
  final ValueChanged<String> onTogglePost;
  final VoidCallback onToggleAllPosts;
  final ValueChanged<String> onSort;
  final ValueChanged<AdminNewsPost> onEditPost;
  final ValueChanged<AdminNewsPost> onSharePost;
  final ValueChanged<AdminNewsPost> onNotifyPost;
  final ValueChanged<AdminNewsPost> onToggleStatus;
  final ValueChanged<AdminNewsPost> onTogglePinned;
  final ValueChanged<AdminNewsPost> onDeletePost;

  static const double _selectWidth = 42;
  static const double _expandWidth = 34;
  static const double _idWidth = 62;
  static const double _postMinWidth = 240;
  static const double _categoryWidth = 120;
  static const double _statusWidth = 112;
  static const double _languageWidth = 84;
  static const double _authorWidth = 130;
  static const double _viewsWidth = 92;
  static const double _commentsWidth = 84;
  static const double _createdWidth = 168;
  static const double _menuWidth = 70;
  static const double _horizontalPadding = 32;
  static const double _tableBorderWidth = 2;

  @override
  State<_NewsDataTable> createState() => _NewsDataTableState();
}

class _NewsDataTableState extends State<_NewsDataTable> {
  final _expandedPostIds = <String>{};

  @override
  void didUpdateWidget(covariant _NewsDataTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    final visibleIds = widget.posts.map((post) => post.id).toSet();
    _expandedPostIds.removeWhere((id) => !visibleIds.contains(id));
  }

  void _toggleExpanded(AdminNewsPost post) {
    if (post.videos.isEmpty) return;
    setState(() {
      if (!_expandedPostIds.remove(post.id)) {
        _expandedPostIds.add(post.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final preferredMinWidth =
            _NewsDataTable._horizontalPadding +
            _NewsDataTable._tableBorderWidth +
            _NewsDataTable._selectWidth +
            _NewsDataTable._expandWidth +
            _NewsDataTable._idWidth +
            _NewsDataTable._postMinWidth +
            _NewsDataTable._categoryWidth +
            _NewsDataTable._statusWidth +
            _NewsDataTable._languageWidth +
            _NewsDataTable._authorWidth +
            _NewsDataTable._viewsWidth +
            _NewsDataTable._commentsWidth +
            _NewsDataTable._createdWidth +
            _NewsDataTable._menuWidth;
        final tableWidth = AdminTableChrome.desktopTableWidth(
          constraints: constraints,
          preferredMinWidth: preferredMinWidth,
        );
        final layout = _NewsTableColumnLayout.forWidth(
          tableWidth,
          preferredMinWidth,
        );
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
                    selectedCount: widget.selectedPostIds.length,
                    totalCount: widget.posts.length,
                    layout: layout,
                    sortState: widget.sortState,
                    onToggleAllPosts: widget.onToggleAllPosts,
                    onSort: widget.onSort,
                  ),
                  Expanded(
                    child:
                        (widget.loading || widget.searching) &&
                            widget.posts.isEmpty
                        ? _NewsLoading(label: widget.loadingLabel)
                        : widget.posts.isEmpty
                        ? const _NewsEmpty()
                        : SingleChildScrollView(
                            child: Column(
                              children: [
                                for (final post in widget.posts)
                                  _NewsRow(
                                    post: post,
                                    layout: layout,
                                    selected: widget.selectedPostIds.contains(
                                      post.id,
                                    ),
                                    expanded: _expandedPostIds.contains(
                                      post.id,
                                    ),
                                    onToggle: () =>
                                        widget.onTogglePost(post.id),
                                    onToggleExpanded: () =>
                                        _toggleExpanded(post),
                                    trashMode: widget.trashMode,
                                    canManagePublication:
                                        widget.canManagePublication,
                                    onEditPost: widget.onEditPost,
                                    onSharePost: widget.onSharePost,
                                    onNotifyPost: widget.onNotifyPost,
                                    onToggleStatus: widget.onToggleStatus,
                                    onTogglePinned: widget.onTogglePinned,
                                    onDeletePost: widget.onDeletePost,
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

class _NewsTableColumnLayout {
  const _NewsTableColumnLayout({
    required this.selectWidth,
    required this.expandWidth,
    required this.idWidth,
    required this.postWidth,
    required this.categoryWidth,
    required this.statusWidth,
    required this.languageWidth,
    required this.authorWidth,
    required this.viewsWidth,
    required this.commentsWidth,
    required this.createdWidth,
    required this.menuWidth,
  });

  final double selectWidth;
  final double expandWidth;
  final double idWidth;
  final double postWidth;
  final double categoryWidth;
  final double statusWidth;
  final double languageWidth;
  final double authorWidth;
  final double viewsWidth;
  final double commentsWidth;
  final double createdWidth;
  final double menuWidth;

  factory _NewsTableColumnLayout.forWidth(
    double tableWidth,
    double preferredMinWidth,
  ) {
    final scale = AdminTableChrome.compactScale(
      tableWidth: tableWidth,
      preferredMinWidth: preferredMinWidth,
      minScale: 0.62,
    );
    final extraWidth = (tableWidth - preferredMinWidth)
        .clamp(0.0, double.infinity)
        .toDouble();
    final selectWidth = AdminTableChrome.scaledColumn(
      _NewsDataTable._selectWidth,
      scale,
      minWidth: 38,
    );
    final expandWidth = AdminTableChrome.scaledColumn(
      _NewsDataTable._expandWidth,
      scale,
      minWidth: 30,
    );
    final idWidth = AdminTableChrome.scaledColumn(
      _NewsDataTable._idWidth,
      scale,
      minWidth: 48,
    );
    final categoryWidth = AdminTableChrome.scaledColumn(
      _NewsDataTable._categoryWidth,
      scale,
      minWidth: 78,
    );
    final statusWidth = AdminTableChrome.scaledColumn(
      _NewsDataTable._statusWidth,
      scale,
      minWidth: 78,
    );
    final languageWidth = AdminTableChrome.scaledColumn(
      _NewsDataTable._languageWidth,
      scale,
      minWidth: 58,
    );
    final authorWidth = AdminTableChrome.scaledColumn(
      _NewsDataTable._authorWidth,
      scale,
      minWidth: 74,
    );
    final viewsWidth = AdminTableChrome.scaledColumn(
      _NewsDataTable._viewsWidth,
      scale,
      minWidth: 54,
    );
    final commentsWidth = AdminTableChrome.scaledColumn(
      _NewsDataTable._commentsWidth,
      scale,
      minWidth: 54,
    );
    final createdWidth = AdminTableChrome.scaledColumn(
      _NewsDataTable._createdWidth,
      scale,
      minWidth: 104,
    );
    final menuWidth = AdminTableChrome.scaledColumn(
      _NewsDataTable._menuWidth,
      scale,
      minWidth: 54,
    );
    const contentSpacing =
        _NewsDataTable._horizontalPadding + _NewsDataTable._tableBorderWidth;
    final fixedWidth =
        selectWidth +
        expandWidth +
        idWidth +
        categoryWidth +
        statusWidth +
        languageWidth +
        authorWidth +
        viewsWidth +
        commentsWidth +
        createdWidth +
        menuWidth +
        contentSpacing;

    return _NewsTableColumnLayout(
      selectWidth: selectWidth,
      expandWidth: expandWidth,
      idWidth: idWidth,
      postWidth: extraWidth > 0
          ? _NewsDataTable._postMinWidth + extraWidth
          : (tableWidth - fixedWidth).clamp(86.0, double.infinity).toDouble(),
      categoryWidth: categoryWidth,
      statusWidth: statusWidth,
      languageWidth: languageWidth,
      authorWidth: authorWidth,
      viewsWidth: viewsWidth,
      commentsWidth: commentsWidth,
      createdWidth: createdWidth,
      menuWidth: menuWidth,
    );
  }
}

class _NewsHeader extends StatelessWidget {
  const _NewsHeader({
    required this.selectedCount,
    required this.totalCount,
    required this.layout,
    required this.sortState,
    required this.onToggleAllPosts,
    required this.onSort,
  });

  final int selectedCount;
  final int totalCount;
  final _NewsTableColumnLayout layout;
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
            width: layout.selectWidth,
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
          SizedBox(width: layout.expandWidth),
          _SortableColumnHeader(
            width: layout.idWidth,
            label: 'ID',
            sortKey: 'id',
            sortState: sortState,
            onSort: onSort,
          ),
          _SortableColumnHeader(
            width: layout.postWidth,
            label: 'Post',
            sortKey: 'post',
            sortState: sortState,
            onSort: onSort,
          ),
          _SortableColumnHeader(
            width: layout.categoryWidth,
            label: 'Category',
            sortKey: 'category',
            sortState: sortState,
            onSort: onSort,
            centered: true,
          ),
          _SortableColumnHeader(
            width: layout.statusWidth,
            label: 'Status',
            sortKey: 'status',
            sortState: sortState,
            onSort: onSort,
            centered: true,
          ),
          _SortableColumnHeader(
            width: layout.languageWidth,
            label: 'Language',
            sortKey: 'language',
            sortState: sortState,
            onSort: onSort,
            centered: true,
          ),
          _SortableColumnHeader(
            width: layout.authorWidth,
            label: 'Author',
            sortKey: 'author',
            sortState: sortState,
            onSort: onSort,
          ),
          _SortableColumnHeader(
            width: layout.viewsWidth,
            label: 'news.column.reads',
            sortKey: 'views',
            sortState: sortState,
            onSort: onSort,
            centered: true,
          ),
          _SortableColumnHeader(
            width: layout.commentsWidth,
            label: 'Comment',
            sortKey: 'comments',
            sortState: sortState,
            onSort: onSort,
            centered: true,
          ),
          _SortableColumnHeader(
            width: layout.createdWidth,
            label: 'Date',
            sortKey: 'date',
            sortState: sortState,
            onSort: onSort,
          ),
          SizedBox(
            width: layout.menuWidth,
            child: const _HeaderText('Action', centered: true),
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
    required this.layout,
    required this.selected,
    required this.expanded,
    required this.onToggle,
    required this.onToggleExpanded,
    required this.trashMode,
    required this.canManagePublication,
    required this.onEditPost,
    required this.onSharePost,
    required this.onNotifyPost,
    required this.onToggleStatus,
    required this.onTogglePinned,
    required this.onDeletePost,
  });

  final AdminNewsPost post;
  final _NewsTableColumnLayout layout;
  final bool selected;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onToggleExpanded;
  final bool trashMode;
  final bool canManagePublication;
  final ValueChanged<AdminNewsPost> onEditPost;
  final ValueChanged<AdminNewsPost> onSharePost;
  final ValueChanged<AdminNewsPost> onNotifyPost;
  final ValueChanged<AdminNewsPost> onToggleStatus;
  final ValueChanged<AdminNewsPost> onTogglePinned;
  final ValueChanged<AdminNewsPost> onDeletePost;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          constraints: const BoxConstraints(minHeight: 92),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: selected ? AppColors.surface : Colors.white,
            border: Border(
              bottom: BorderSide(
                color: AppColors.softLine.withValues(alpha: 0.86),
              ),
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: layout.selectWidth,
                child: _NewsCheckbox(
                  value: selected,
                  onChanged: (_) => onToggle(),
                ),
              ),
              SizedBox(
                width: layout.expandWidth,
                child: _RowExpandButton(
                  enabled: post.videos.isNotEmpty,
                  expanded: expanded,
                  onTap: onToggleExpanded,
                ),
              ),
              SizedBox(
                width: layout.idWidth,
                child: _RowSelectTapTarget(
                  onTap: onToggle,
                  child: HighlightedText(
                    post.id,
                    query: _NewsSearchScope.of(context),
                    style: const TextStyle(
                      color: AppColors.deepOcean,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: layout.postWidth,
                child: _PostIdentity(post: post),
              ),
              SizedBox(
                width: layout.categoryWidth,
                child: _CategoryCell(post: post),
              ),
              SizedBox(
                width: layout.statusWidth,
                child: _NewsStatusBadge(post: post),
              ),
              SizedBox(
                width: layout.languageWidth,
                child: Center(
                  child: _LanguageBadge(value: post.displayLanguage),
                ),
              ),
              SizedBox(
                width: layout.authorWidth,
                child: _AuthorCell(post: post),
              ),
              SizedBox(
                width: layout.viewsWidth,
                child: _NumberCell(value: post.viewsCount),
              ),
              SizedBox(
                width: layout.commentsWidth,
                child: _NumberCell(value: post.commentsCount),
              ),
              SizedBox(
                width: layout.createdWidth,
                child: _DateCell(dateTime: post.createdAt),
              ),
              SizedBox(
                width: layout.menuWidth,
                child: Align(
                  alignment: Alignment.center,
                  child: trashMode
                      ? const SymbolIcon(
                          Symbols.delete,
                          color: AppColors.iconMuted,
                          size: 18,
                        )
                      : _NewsRowMenu(
                          post: post,
                          canManagePublication: canManagePublication,
                          onEditPost: onEditPost,
                          onSharePost: onSharePost,
                          onNotifyPost: onNotifyPost,
                          onToggleStatus: onToggleStatus,
                          onTogglePinned: onTogglePinned,
                          onDeletePost: onDeletePost,
                        ),
                ),
              ),
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: expanded
              ? _NewsVideoExpansion(post: post)
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _RowExpandButton extends StatelessWidget {
  const _RowExpandButton({
    required this.enabled,
    required this.expanded,
    required this.onTap,
  });

  final bool enabled;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return const SizedBox.shrink();
    return Tooltip(
      message: context.t(
        expanded ? 'news.videos.collapse' : 'news.videos.expand',
      ),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            height: 34,
            child: Center(
              child: AnimatedRotation(
                turns: expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOutCubic,
                child: const SymbolIcon(
                  Symbols.keyboard_arrow_down,
                  color: AppColors.deepOcean,
                  size: 18,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NewsVideoExpansion extends StatelessWidget {
  const _NewsVideoExpansion({required this.post});

  final AdminNewsPost post;

  @override
  Widget build(BuildContext context) {
    final videos = post.videos;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        left:
            16 +
            _NewsDataTable._selectWidth +
            _NewsDataTable._expandWidth +
            _NewsDataTable._idWidth,
        right: 16,
        top: 14,
        bottom: 20,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F8FA),
        border: Border(
          top: BorderSide(
            color: const Color(0xFFDDECEF).withValues(alpha: 0.9),
          ),
          bottom: BorderSide(
            color: const Color(0xFFDDECEF).withValues(alpha: 0.9),
          ),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFFFFF), Color(0xFFF9FCFC)],
          ),
          borderRadius: BorderRadius.circular(AppRadius.value),
          border: Border.all(color: const Color(0xFFD7E8EC)),
          boxShadow: [
            BoxShadow(
              color: AppColors.deepOcean.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(width: 4, color: AppColors.actionRed),
              ),
            ),
            Column(
              children: [
                _NewsVideoExpansionHeader(count: videos.length),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = _NewsVideoDetailColumns.forWidth(
                      constraints.maxWidth,
                    );
                    return Column(
                      children: [
                        Container(
                          height: 38,
                          padding: const EdgeInsets.only(left: 18, right: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF6F7),
                            border: Border(
                              top: BorderSide(
                                color: const Color(
                                  0xFFDCECEF,
                                ).withValues(alpha: 0.9),
                              ),
                              bottom: BorderSide(
                                color: const Color(
                                  0xFFDCECEF,
                                ).withValues(alpha: 0.9),
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _VideoHeaderText(
                                  context.t('news.videos.video'),
                                ),
                              ),
                              SizedBox(
                                width: columns.platform,
                                child: _VideoHeaderText(
                                  context.t('news.videos.platform'),
                                  centered: true,
                                ),
                              ),
                              SizedBox(
                                width: columns.date,
                                child: _VideoHeaderText(
                                  context.t('news.videos.addedDate'),
                                  centered: true,
                                ),
                              ),
                              SizedBox(
                                width: columns.size,
                                child: _VideoHeaderText(
                                  context.t('news.videos.size'),
                                  centered: true,
                                ),
                              ),
                              SizedBox(
                                width: columns.views,
                                child: _VideoHeaderText(
                                  context.t('news.videos.views'),
                                  centered: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                        for (var index = 0; index < videos.length; index++)
                          _NewsVideoDetailRow(
                            video: videos[index],
                            index: index,
                            last: index == videos.length - 1,
                            columns: columns,
                            onTap: () =>
                                _openNewsVideoPreview(context, videos[index]),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NewsVideoExpansionHeader extends StatelessWidget {
  const _NewsVideoExpansionHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 12, 13),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.actionRed.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.value),
              border: Border.all(
                color: AppColors.actionRed.withValues(alpha: 0.16),
              ),
            ),
            child: const SymbolIcon(
              Symbols.play_circle_outline_rounded,
              color: AppColors.actionRed,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.t('news.videos.title'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.deepOcean,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
          Container(
            height: 24,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 9),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4F2),
              borderRadius: BorderRadius.circular(AppRadius.value),
              border: Border.all(
                color: AppColors.actionRed.withValues(alpha: 0.15),
              ),
            ),
            child: Text(
              context.t('news.videos.count', values: {'count': count}),
              style: const TextStyle(
                color: AppColors.actionRed,
                fontSize: 11,
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

class _VideoHeaderText extends StatelessWidget {
  const _VideoHeaderText(this.text, {this.centered = false});

  final String text;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: centered ? TextAlign.center : TextAlign.start,
      style: const TextStyle(
        color: AppColors.inkSoft,
        fontSize: 11.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
    );
  }
}

class _NewsVideoDetailRow extends StatefulWidget {
  const _NewsVideoDetailRow({
    required this.video,
    required this.index,
    required this.last,
    required this.columns,
    required this.onTap,
  });

  final AdminNewsVideo video;
  final int index;
  final bool last;
  final _NewsVideoDetailColumns columns;
  final VoidCallback onTap;

  @override
  State<_NewsVideoDetailRow> createState() => _NewsVideoDetailRowState();
}

class _NewsVideoDetailRowState extends State<_NewsVideoDetailRow> {
  var _hovering = false;

  @override
  Widget build(BuildContext context) {
    final title = widget.video.title.trim().isEmpty
        ? '${context.t('news.videos.video')} ${widget.index + 1}'
        : widget.video.displayTitle;
    return Tooltip(
      message: context.t('news.videos.play'),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            constraints: const BoxConstraints(minHeight: 86),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: _hovering
                  ? const Color(0xFFFFF8F6)
                  : Colors.white.withValues(alpha: 0),
              border: widget.last
                  ? null
                  : Border(
                      bottom: BorderSide(
                        color: const Color(0xFFE8F0F2).withValues(alpha: 0.92),
                      ),
                    ),
            ),
            child: Row(
              children: [
                _VideoThumb(video: widget.video, active: _hovering),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            fit: FlexFit.loose,
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _hovering
                                    ? AppColors.actionRed
                                    : AppColors.deepOcean,
                                fontSize: 12.8,
                                fontWeight: FontWeight.w800,
                                height: 1.15,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          _VideoPlayChip(active: _hovering),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _compactVideoUrl(widget.video.displayUrl),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.support,
                          fontSize: 10.8,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: widget.columns.platform,
                  child: _VideoPlatformCell(
                    label: widget.video.displayPlatform,
                    maxWidth: widget.columns.platform - 18,
                  ),
                ),
                SizedBox(
                  width: widget.columns.date,
                  child: _VideoPublishedDateCell(
                    dateTime: widget.video.publishedAt,
                  ),
                ),
                SizedBox(
                  width: widget.columns.size,
                  child: Center(
                    child: Text(
                      widget.video.sizeLabel.trim().isEmpty
                          ? '-'
                          : widget.video.sizeLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.inkSoft,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: widget.columns.views,
                  child: _NumberCell(value: widget.video.viewsCount),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VideoPlatformCell extends StatelessWidget {
  const _VideoPlatformCell({required this.label, required this.maxWidth});

  final String label;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final value = label.trim().isEmpty ? '-' : label.trim();
    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F8F9),
          borderRadius: BorderRadius.circular(AppRadius.value),
          border: Border.all(color: const Color(0xFFDCECEF)),
        ),
        child: Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.deepOcean,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _VideoPublishedDateCell extends StatelessWidget {
  const _VideoPublishedDateCell({required this.dateTime});

  final DateTime? dateTime;

  @override
  Widget build(BuildContext context) {
    final value = dateTime;
    if (value == null) {
      return const Center(
        child: Text(
          '-',
          style: TextStyle(
            color: AppColors.inkSoft,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatAdminFullDate(context, value),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.deepOcean,
              fontSize: 11.2,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.t(
              'news.videos.dayCount',
              values: {'count': _videoAgeInDays(value)},
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.support,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoThumb extends StatelessWidget {
  const _VideoThumb({required this.video, required this.active});

  final AdminNewsVideo video;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final thumb = video.thumbnailUrl.trim();
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutCubic,
      width: 84,
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F7F8),
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(
          color: active
              ? AppColors.actionRed.withValues(alpha: 0.34)
              : const Color(0xFFDDE8EB),
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: AppColors.actionRed.withValues(alpha: 0.12),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: thumb.isEmpty
          ? const _VideoThumbFallback()
          : Stack(
              fit: StackFit.expand,
              children: [
                AdminCachedImage(
                  url: adminImageUrl(thumb, width: 360),
                  fit: BoxFit.cover,
                  memCacheWidth: 360,
                  errorWidget: const _VideoThumbFallback(),
                ),
                Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: active ? 28 : 24,
                    height: active ? 28 : 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: active
                          ? AppColors.actionRed.withValues(alpha: 0.9)
                          : Colors.black.withValues(alpha: 0.42),
                      borderRadius: BorderRadius.circular(AppRadius.value),
                    ),
                    child: const SymbolIcon(
                      Symbols.play_circle_rounded,
                      color: Colors.white,
                      size: 15,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _VideoPlayChip extends StatelessWidget {
  const _VideoPlayChip({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: active ? AppColors.actionRed : const Color(0xFFF1F6F7),
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(
          color: active
              ? AppColors.actionRed
              : const Color(0xFFDDE8EB).withValues(alpha: 0.9),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SymbolIcon(
            Symbols.play_circle_rounded,
            color: active ? Colors.white : AppColors.deepOcean,
            size: 13,
          ),
          const SizedBox(width: 4),
          Text(
            context.t('news.videos.play'),
            style: TextStyle(
              color: active ? Colors.white : AppColors.deepOcean,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoThumbFallback extends StatelessWidget {
  const _VideoThumbFallback();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SymbolIcon(
        Symbols.play_circle_outline_rounded,
        color: AppColors.iconMuted,
        size: 22,
      ),
    );
  }
}

/// Bir videonun (URL'ye göre tekil) hangi haberlerde kullanıldığını toplayan kayıt.
class _VideoUsage {
  _VideoUsage(this.video);

  final AdminNewsVideo video;
  final List<AdminNewsPost> posts = <AdminNewsPost>[];
  int totalViews = 0;
}

String _youtubeIdFromUrl(String url) {
  final raw = url.trim();
  if (raw.isEmpty) return '';
  if (RegExp(r'^[_\-a-zA-Z0-9]{11}$').hasMatch(raw)) return raw;
  final uri = Uri.tryParse(raw.contains('://') ? raw : 'https://$raw');
  if (uri == null) return '';
  final host = uri.host.toLowerCase();
  if (!host.contains('youtube.com') &&
      !host.contains('youtu.be') &&
      !host.contains('youtube-nocookie.com')) {
    return '';
  }
  String clean(String value) =>
      RegExp(r'[_\-a-zA-Z0-9]{11}').firstMatch(value)?.group(0) ?? '';
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (host.contains('youtu.be')) {
    return segments.isEmpty ? '' : clean(segments.first);
  }
  final query = uri.queryParameters['v'];
  if (query != null && query.isNotEmpty) return clean(query);
  for (var i = 0; i < segments.length - 1; i++) {
    final segment = segments[i].toLowerCase();
    if (segment == 'shorts' || segment == 'embed' || segment == 'live') {
      return clean(segments[i + 1]);
    }
  }
  return '';
}

/// Sunucudaki canonicalVideoKey ile aynı mantık: aynı video farklı haberlerde
/// olsa da tek satırda toplanır (YouTube ID'si bilinçli).
String _videoCanonicalKey(String url) {
  final raw = url.trim();
  if (raw.isEmpty) return '';
  final youtube = _youtubeIdFromUrl(raw);
  if (youtube.isNotEmpty) return 'youtube:$youtube';
  final uri = Uri.tryParse(raw.contains('://') ? raw : 'https://$raw');
  if (uri == null || uri.host.isEmpty) return 'raw:${raw.toLowerCase()}';
  final host = uri.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
  var path = uri.path;
  if (path.length > 1 && path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  return 'url:$host$path';
}

/// "Videolar" modunda gösterilen Video Kütüphanesi: tüm videolar düz tablo
/// halinde (haber satırı YOK), her videonun altında kullanıldığı haber(ler) +
/// Haberi düzenle / Habere git butonları.
class _NewsVideoLibrary extends StatelessWidget {
  const _NewsVideoLibrary({
    required this.posts,
    required this.loading,
    required this.loadingLabel,
    required this.searching,
    required this.searchQuery,
    required this.onEditPost,
  });

  final List<AdminNewsPost> posts;
  final bool loading;
  final String loadingLabel;
  final bool searching;
  final String searchQuery;
  final ValueChanged<AdminNewsPost> onEditPost;

  List<_VideoUsage> _aggregate() {
    final byKey = <String, _VideoUsage>{};
    final order = <String>[];
    for (final post in posts) {
      for (final video in post.videos) {
        final key = _videoCanonicalKey(video.url);
        if (key.isEmpty) continue;
        final usage = byKey.putIfAbsent(key, () {
          order.add(key);
          return _VideoUsage(video);
        });
        if (!usage.posts.any((p) => p.id == post.id)) {
          usage.posts.add(post);
        }
        usage.totalViews += video.viewsCount;
      }
    }
    return [for (final key in order) byKey[key]!];
  }

  bool _matches(_VideoUsage usage, String query) {
    final haystack = StringBuffer()
      ..write(usage.video.title)
      ..write(' ')
      ..write(usage.video.url)
      ..write(' ')
      ..write(usage.video.platformLabel);
    for (final post in usage.posts) {
      haystack
        ..write(' ')
        ..write(post.title)
        ..write(' ')
        ..write(post.id)
        ..write(' ')
        ..write(post.category);
    }
    return searchMatchesAll(haystack.toString(), query);
  }

  @override
  Widget build(BuildContext context) {
    final query = searchQuery.trim();
    final all = _aggregate();
    final videos = query.isEmpty
        ? all
        : all.where((usage) => _matches(usage, query)).toList(growable: false);

    if (videos.isEmpty) {
      if ((loading || searching)) return _NewsLoading(label: loadingLabel);
      return _NewsVideoLibraryEmpty(filtered: query.isNotEmpty);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 4),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFFFFF), Color(0xFFF9FCFC)],
          ),
          borderRadius: BorderRadius.circular(AppRadius.value),
          border: Border.all(color: const Color(0xFFD7E8EC)),
          boxShadow: [
            BoxShadow(
              color: AppColors.deepOcean.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(width: 4, color: AppColors.actionRed),
              ),
            ),
            Column(
              children: [
                _NewsVideoExpansionHeader(count: videos.length),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 720;
                    final columns = _NewsVideoDetailColumns.forWidth(
                      constraints.maxWidth,
                    );
                    return Column(
                      children: [
                        if (wide) _VideoLibraryColumnsHeader(columns: columns),
                        for (var index = 0; index < videos.length; index++)
                          _NewsVideoLibraryRow(
                            usage: videos[index],
                            columns: columns,
                            wide: wide,
                            last: index == videos.length - 1,
                            query: searchQuery,
                            onEditPost: onEditPost,
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoLibraryColumnsHeader extends StatelessWidget {
  const _VideoLibraryColumnsHeader({required this.columns});

  final _NewsVideoDetailColumns columns;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.only(left: 18, right: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF6F7),
        border: Border(
          top: BorderSide(
            color: const Color(0xFFDCECEF).withValues(alpha: 0.9),
          ),
          bottom: BorderSide(
            color: const Color(0xFFDCECEF).withValues(alpha: 0.9),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(child: _VideoHeaderText(context.t('news.videos.video'))),
          SizedBox(
            width: columns.platform,
            child: _VideoHeaderText(
              context.t('news.videos.platform'),
              centered: true,
            ),
          ),
          SizedBox(
            width: columns.date,
            child: _VideoHeaderText(
              context.t('news.videos.addedDate'),
              centered: true,
            ),
          ),
          SizedBox(
            width: columns.size,
            child: _VideoHeaderText(
              context.t('news.videos.size'),
              centered: true,
            ),
          ),
          SizedBox(
            width: columns.views,
            child: _VideoHeaderText(
              context.t('news.videos.views'),
              centered: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _NewsVideoLibraryRow extends StatefulWidget {
  const _NewsVideoLibraryRow({
    required this.usage,
    required this.columns,
    required this.wide,
    required this.last,
    required this.query,
    required this.onEditPost,
  });

  final _VideoUsage usage;
  final _NewsVideoDetailColumns columns;
  final bool wide;
  final bool last;
  final String query;
  final ValueChanged<AdminNewsPost> onEditPost;

  @override
  State<_NewsVideoLibraryRow> createState() => _NewsVideoLibraryRowState();
}

class _NewsVideoLibraryRowState extends State<_NewsVideoLibraryRow> {
  var _hovering = false;

  @override
  Widget build(BuildContext context) {
    final video = widget.usage.video;
    final sizeLabel = video.sizeLabel.trim().isEmpty ? '-' : video.sizeLabel;
    return Container(
      decoration: BoxDecoration(
        border: widget.last
            ? null
            : Border(
                bottom: BorderSide(
                  color: const Color(0xFFE8F0F2).withValues(alpha: 0.92),
                ),
              ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Tooltip(
            message: context.t('news.videos.play'),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setState(() => _hovering = true),
              onExit: (_) => setState(() => _hovering = false),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _openNewsVideoPreview(context, video),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.fromLTRB(14, 13, 14, 11),
                  color: _hovering
                      ? const Color(0xFFFFF8F6)
                      : Colors.white.withValues(alpha: 0),
                  child: widget.wide
                      ? _wideRow(context, sizeLabel)
                      : _narrowRow(context, sizeLabel),
                ),
              ),
            ),
          ),
          _UsedInPostsBlock(
            posts: widget.usage.posts,
            query: widget.query,
            wide: widget.wide,
            onEditPost: widget.onEditPost,
          ),
        ],
      ),
    );
  }

  Widget _titleAndUrl(BuildContext context) {
    final video = widget.usage.video;
    final title = video.title.trim().isEmpty
        ? context.t('news.videos.video')
        : video.displayTitle;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              fit: FlexFit.loose,
              child: HighlightedText(
                title,
                query: widget.query,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _hovering ? AppColors.actionRed : AppColors.deepOcean,
                  fontSize: 12.8,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                  letterSpacing: 0,
                ),
              ),
            ),
            const SizedBox(width: 10),
            _VideoPlayChip(active: _hovering),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          _compactVideoUrl(video.displayUrl),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.support,
            fontSize: 10.8,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }

  Widget _wideRow(BuildContext context, String sizeLabel) {
    return Row(
      children: [
        _VideoThumb(video: widget.usage.video, active: _hovering),
        const SizedBox(width: 14),
        Expanded(child: _titleAndUrl(context)),
        SizedBox(
          width: widget.columns.platform,
          child: _VideoPlatformCell(
            label: widget.usage.video.displayPlatform,
            maxWidth: widget.columns.platform - 18,
          ),
        ),
        SizedBox(
          width: widget.columns.date,
          child: _VideoPublishedDateCell(
            dateTime: widget.usage.video.publishedAt,
          ),
        ),
        SizedBox(
          width: widget.columns.size,
          child: Center(
            child: Text(
              sizeLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.inkSoft,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        SizedBox(
          width: widget.columns.views,
          child: _NumberCell(value: widget.usage.totalViews),
        ),
      ],
    );
  }

  Widget _narrowRow(BuildContext context, String sizeLabel) {
    final video = widget.usage.video;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _VideoThumb(video: video, active: _hovering),
            const SizedBox(width: 12),
            Expanded(child: _titleAndUrl(context)),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _VideoMetaChip(
              icon: Symbols.play_circle_rounded,
              label: video.displayPlatform,
            ),
            if (video.publishedAt != null)
              _VideoMetaChip(
                icon: Symbols.calendar_event_line,
                label: formatAdminFullDate(context, video.publishedAt),
              ),
            _VideoMetaChip(icon: Symbols.memory_rounded, label: sizeLabel),
            _VideoMetaChip(
              icon: Symbols.visibility,
              label: '${widget.usage.totalViews}',
            ),
          ],
        ),
      ],
    );
  }
}

class _VideoMetaChip extends StatelessWidget {
  const _VideoMetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F8F9),
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: const Color(0xFFDCECEF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SymbolIcon(icon, color: AppColors.support, size: 13),
          const SizedBox(width: 5),
          Text(
            label.trim().isEmpty ? '-' : label,
            style: const TextStyle(
              color: AppColors.deepOcean,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _UsedInPostsBlock extends StatelessWidget {
  const _UsedInPostsBlock({
    required this.posts,
    required this.query,
    required this.wide,
    required this.onEditPost,
  });

  final List<AdminNewsPost> posts;
  final String query;
  final bool wide;
  final ValueChanged<AdminNewsPost> onEditPost;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F9FA),
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: const Color(0xFFE2EEF1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SymbolIcon(
                Symbols.newspaper,
                color: AppColors.support,
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                context.t('news.videos.usedIn'),
                style: const TextStyle(
                  color: AppColors.inkSoft,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.deepOcean.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.value),
                ),
                child: Text(
                  '${posts.length}',
                  style: const TextStyle(
                    color: AppColors.deepOcean,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (var index = 0; index < posts.length; index++) ...[
            if (index > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: const Color(0xFFE2EEF1).withValues(alpha: 0.85),
                ),
              ),
            _UsedInPostLine(
              post: posts[index],
              query: query,
              wide: wide,
              onEditPost: onEditPost,
            ),
          ],
        ],
      ),
    );
  }
}

class _UsedInPostLine extends StatelessWidget {
  const _UsedInPostLine({
    required this.post,
    required this.query,
    required this.wide,
    required this.onEditPost,
  });

  final AdminNewsPost post;
  final String query;
  final bool wide;
  final ValueChanged<AdminNewsPost> onEditPost;

  @override
  Widget build(BuildContext context) {
    final thumb = post.thumbnailUrl.trim();
    final info = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 40,
          height: 30,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.value),
            border: Border.all(color: const Color(0xFFDDE8EB)),
          ),
          clipBehavior: Clip.antiAlias,
          child: thumb.isEmpty
              ? const SymbolIcon(
                  Symbols.newspaper,
                  color: AppColors.iconMuted,
                  size: 15,
                )
              : AdminCachedImage(
                  url: adminImageUrl(thumb, width: 120),
                  fit: BoxFit.cover,
                  memCacheWidth: 120,
                  errorWidget: const SymbolIcon(
                    Symbols.newspaper,
                    color: AppColors.iconMuted,
                    size: 15,
                  ),
                ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HighlightedText(
                post.displayTitle,
                query: query,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.deepOcean,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  HighlightedText(
                    '#${post.id}',
                    query: query,
                    style: const TextStyle(
                      color: AppColors.support,
                      fontSize: 10.8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (post.displayCategory.trim().isNotEmpty &&
                      post.displayCategory != '-') ...[
                    const Text(
                      '  ·  ',
                      style: TextStyle(
                        color: AppColors.support,
                        fontSize: 10.8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Flexible(
                      child: HighlightedText(
                        post.displayCategory,
                        query: query,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.support,
                          fontSize: 10.8,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );

    final buttons = [
      _LibraryActionButton(
        icon: Symbols.edit_square,
        label: context.t('news.videos.editPost'),
        onTap: () => onEditPost(post),
      ),
      _LibraryActionButton(
        icon: Symbols.open_in_new,
        label: context.t('news.videos.goToPost'),
        filled: true,
        onTap: () => unawaited(openNewsLink(_postUrl(post))),
      ),
    ];

    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: info),
          const SizedBox(width: 12),
          buttons[0],
          const SizedBox(width: 8),
          buttons[1],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        info,
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: buttons[0]),
            const SizedBox(width: 8),
            Expanded(child: buttons[1]),
          ],
        ),
      ],
    );
  }
}

class _LibraryActionButton extends StatelessWidget {
  const _LibraryActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final foreground = filled ? Colors.white : AppColors.deepOcean;
    return SizedBox(
      height: 30,
      child: TextButton(
        onPressed: onTap,
        style:
            TextButton.styleFrom(
              backgroundColor: filled ? AppColors.deepOcean : Colors.white,
              foregroundColor: foreground,
              side: BorderSide(
                color: filled
                    ? AppColors.deepOcean
                    : AppColors.line.withValues(alpha: 0.82),
              ),
              minimumSize: const Size(0, 30),
              padding: const EdgeInsets.symmetric(horizontal: 11),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.value),
              ),
              textStyle: const TextStyle(
                fontSize: 12,
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SymbolIcon(icon, color: foreground, size: 14),
            const SizedBox(width: 6),
            Flexible(
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewsVideoLibraryEmpty extends StatelessWidget {
  const _NewsVideoLibraryEmpty({required this.filtered});

  final bool filtered;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SymbolIcon(
            Symbols.play_circle_outline_rounded,
            color: AppColors.iconMuted,
            size: 34,
          ),
          const SizedBox(height: 12),
          Text(
            context.t('news.videos.empty'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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

String _compactVideoUrl(String value) {
  final raw = value.trim();
  if (raw.isEmpty) return '-';
  final uri = Uri.tryParse(raw);
  if (uri == null || uri.host.isEmpty) return raw;
  final path = uri.path.isEmpty ? '' : uri.path;
  return '${uri.host}$path';
}

int _videoAgeInDays(DateTime value) {
  final local = value.toLocal();
  final date = DateTime(local.year, local.month, local.day);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final days = today.difference(date).inDays;
  return days < 0 ? 0 : days;
}

void _openNewsVideoPreview(BuildContext context, AdminNewsVideo video) {
  showDialog<void>(
    context: context,
    barrierColor: const Color(0xB20D1B24),
    builder: (_) => _NewsVideoPreviewDialog(video: video),
  );
}

class _NewsVideoPreviewDialog extends StatelessWidget {
  const _NewsVideoPreviewDialog({required this.video});

  final AdminNewsVideo video;

  @override
  Widget build(BuildContext context) {
    final title = video.displayTitle;
    final url = video.displayUrl;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth < 960
              ? constraints.maxWidth
              : 960.0;
          final maxHeight = constraints.maxHeight < 760
              ? constraints.maxHeight
              : 760.0;
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxWidth,
                maxHeight: maxHeight,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF10212B),
                  borderRadius: BorderRadius.circular(AppRadius.value),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 34,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _NewsVideoPreviewHeader(title: title, url: url),
                    Flexible(
                      child: Container(
                        width: double.infinity,
                        color: Colors.black,
                        child: AspectRatio(
                          aspectRatio: _isShortsVideoUrl(url) ? 9 / 16 : 16 / 9,
                          child: _NewsVideoModalPlayer(video: video),
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

class _NewsVideoPreviewHeader extends StatelessWidget {
  const _NewsVideoPreviewHeader({required this.title, required this.url});

  final String title;
  final String url;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 12, 13),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF112B37), Color(0xFF172C34)],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.actionRed.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AppRadius.value),
              border: Border.all(
                color: AppColors.actionRed.withValues(alpha: 0.24),
              ),
            ),
            child: const SymbolIcon(
              Symbols.play_circle_rounded,
              color: AppColors.actionRed,
              size: 19,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _compactVideoUrl(url),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.58),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Tooltip(
            message: context.t('news.videos.close'),
            child: IconButton(
              mouseCursor: SystemMouseCursors.click,
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Symbols.close_rounded),
              color: Colors.white,
              iconSize: 20,
              splashRadius: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _NewsVideoModalPlayer extends StatelessWidget {
  const _NewsVideoModalPlayer({required this.video});

  final AdminNewsVideo video;

  @override
  Widget build(BuildContext context) {
    final url = video.displayUrl;
    final youtubeId = _youtubeVideoId(url);
    if (youtubeId != null) {
      return _NewsYoutubeModalPlayer(videoId: youtubeId);
    }
    return _NewsDirectModalPlayer(url: url);
  }
}

class _NewsYoutubeModalPlayer extends StatefulWidget {
  const _NewsYoutubeModalPlayer({required this.videoId});

  final String videoId;

  @override
  State<_NewsYoutubeModalPlayer> createState() =>
      _NewsYoutubeModalPlayerState();
}

class _NewsYoutubeModalPlayerState extends State<_NewsYoutubeModalPlayer> {
  late youtube.YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = _createController(widget.videoId);
  }

  @override
  void didUpdateWidget(covariant _NewsYoutubeModalPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoId != widget.videoId) {
      _controller.close();
      _controller = _createController(widget.videoId);
    }
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  youtube.YoutubePlayerController _createController(String id) {
    return youtube.YoutubePlayerController.fromVideoId(
      videoId: id,
      autoPlay: true,
      params: const youtube.YoutubePlayerParams(
        mute: false,
        showControls: true,
        showFullscreenButton: true,
        strictRelatedVideos: true,
        playsInline: true,
        enableCaption: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return youtube.YoutubePlayer(controller: _controller);
  }
}

class _NewsDirectModalPlayer extends StatefulWidget {
  const _NewsDirectModalPlayer({required this.url});

  final String url;

  @override
  State<_NewsDirectModalPlayer> createState() => _NewsDirectModalPlayerState();
}

class _NewsDirectModalPlayerState extends State<_NewsDirectModalPlayer> {
  VideoPlayerController? _controller;
  var _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _NewsDirectModalPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _disposeController();
      _failed = false;
      _load();
    }
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  void _disposeController() {
    final controller = _controller;
    _controller = null;
    controller?.removeListener(_refresh);
    controller?.dispose();
  }

  Future<void> _load() async {
    final resolved = adminImageUrl(widget.url.trim());
    final uri = Uri.tryParse(resolved);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      if (mounted) setState(() => _failed = true);
      return;
    }

    final controller = VideoPlayerController.networkUrl(uri);
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setVolume(1);
      controller.addListener(_refresh);
      if (!mounted || _controller != controller) return;
      setState(() {});
      await controller.play();
    } catch (_) {
      if (!mounted || _controller != controller) return;
      await controller.dispose();
      _controller = null;
      setState(() => _failed = true);
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_failed) {
      return _NewsVideoStatusSurface(
        icon: Symbols.error_outline_rounded,
        title: context.t('news.videos.playbackError'),
        subtitle: _compactVideoUrl(widget.url),
      );
    }
    if (controller == null || !controller.value.isInitialized) {
      return _NewsVideoStatusSurface(
        icon: Symbols.hourglass_top_rounded,
        title: context.t('news.videos.loading'),
        subtitle: _compactVideoUrl(widget.url),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        _NewsDirectVideoFrame(controller: controller),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _NewsDirectVideoControls(controller: controller),
        ),
      ],
    );
  }
}

class _NewsDirectVideoFrame extends StatelessWidget {
  const _NewsDirectVideoFrame({required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    final size = controller.value.size;
    if (size.width <= 0 || size.height <= 0) {
      return VideoPlayer(controller);
    }
    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: VideoPlayer(controller),
      ),
    );
  }
}

class _NewsDirectVideoControls extends StatelessWidget {
  const _NewsDirectVideoControls({required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    final value = controller.value;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 18, 10, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.72)],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () {
              value.isPlaying ? controller.pause() : controller.play();
            },
            icon: Icon(
              value.isPlaying
                  ? Symbols.pause_rounded
                  : Symbols.play_arrow_rounded,
              color: Colors.white,
            ),
          ),
          Expanded(
            child: VideoProgressIndicator(
              controller,
              allowScrubbing: true,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              colors: const VideoProgressColors(
                playedColor: AppColors.actionRed,
                bufferedColor: Color(0x80FFFFFF),
                backgroundColor: Color(0x33FFFFFF),
              ),
            ),
          ),
          Text(
            _formatVideoPosition(value.position, value.duration),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => controller.setVolume(value.volume > 0 ? 0 : 1),
            icon: Icon(
              value.volume > 0
                  ? Symbols.volume_up_rounded
                  : Symbols.volume_off_rounded,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _NewsVideoStatusSurface extends StatelessWidget {
  const _NewsVideoStatusSurface({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.value),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 26),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.56),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

bool _isShortsVideoUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  return uri?.pathSegments.any(
        (segment) => segment.toLowerCase() == 'shorts',
      ) ??
      false;
}

String? _youtubeVideoId(String value) {
  final raw = value.trim();
  if (RegExp(r'^[_\-a-zA-Z0-9]{11}$').hasMatch(raw)) return raw;
  var uri = Uri.tryParse(raw);
  if (uri != null && !uri.hasScheme && raw.contains('youtube')) {
    uri = Uri.tryParse('https://$raw');
  }
  if (uri == null || uri.host.isEmpty) return null;
  final host = uri.host.toLowerCase().replaceFirst('www.', '');
  if (host == 'youtu.be' && uri.pathSegments.isNotEmpty) {
    return _cleanYoutubeId(uri.pathSegments.first);
  }
  if (!host.endsWith('youtube.com') && host != 'youtube-nocookie.com') {
    return null;
  }
  final directId = _cleanYoutubeId(uri.queryParameters['v']);
  if (directId != null) return directId;
  final segments = uri.pathSegments;
  for (var index = 0; index < segments.length - 1; index += 1) {
    if (const {'shorts', 'embed', 'live'}.contains(segments[index])) {
      return _cleanYoutubeId(segments[index + 1]);
    }
  }
  return null;
}

String? _cleanYoutubeId(String? value) {
  final match = RegExp(r'[_\-a-zA-Z0-9]{11}').firstMatch(value ?? '');
  return match?.group(0);
}

String _formatVideoPosition(Duration position, Duration duration) {
  String format(Duration value) {
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  return '${format(position)} / ${format(duration)}';
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
          : AdminCachedImage(
              url: adminImageUrl(url, width: 180),
              width: 60,
              height: 60,
              fit: BoxFit.contain,
              memCacheWidth: 180,
              errorWidget: const Center(
                child: SymbolIcon(
                  Symbols.visibility,
                  color: AppColors.iconMuted,
                  size: 22,
                ),
              ),
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
        child: HighlightedText(
          widget.post.displayTitle,
          query: _NewsSearchScope.of(context),
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
    final path = post.categoryPath.isNotEmpty
        ? post.categoryPath
        : [
            if (parent != null && parent.isNotEmpty) parent,
            post.displayCategory,
          ];
    final normalizedPath = path
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (var index = 0; index < normalizedPath.length; index++) ...[
          if (index > 0) const SizedBox(height: 3),
          if (index == 0)
            HighlightedText(
              normalizedPath[index],
              query: _NewsSearchScope.of(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.deepOcean,
                fontWeight: FontWeight.w600,
                fontSize: normalizedPath.length > 1 ? 10.5 : 11.5,
              ),
            )
          else
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
                Flexible(
                  child: HighlightedText(
                    normalizedPath[index],
                    query: _NewsSearchScope.of(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.deepOcean,
                      fontWeight: FontWeight.w600,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ],
            ),
        ],
        if (normalizedPath.isEmpty)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  post.displayCategory,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.deepOcean,
                    fontWeight: FontWeight.w600,
                    fontSize: 11.5,
                  ),
                ),
              ),
            ],
          ),
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
        HighlightedText(
          post.displayPublisher,
          query: _NewsSearchScope.of(context),
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
          HighlightedText(
            username,
            query: _NewsSearchScope.of(context),
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
          HighlightedText(
            email,
            query: _NewsSearchScope.of(context),
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
    required this.canManagePublication,
    required this.onEditPost,
    required this.onSharePost,
    required this.onNotifyPost,
    required this.onToggleStatus,
    required this.onTogglePinned,
    required this.onDeletePost,
  });

  final AdminNewsPost post;
  final bool canManagePublication;
  final ValueChanged<AdminNewsPost> onEditPost;
  final ValueChanged<AdminNewsPost> onSharePost;
  final ValueChanged<AdminNewsPost> onNotifyPost;
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
                canManagePublication: widget.canManagePublication,
                onEdit: () =>
                    _runAndClose(() => widget.onEditPost(widget.post)),
                onShare: () =>
                    _runAndClose(() => widget.onSharePost(widget.post)),
                onNotify: () =>
                    _runAndClose(() => widget.onNotifyPost(widget.post)),
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
    required this.canManagePublication,
    required this.onEdit,
    required this.onShare,
    required this.onNotify,
    required this.onToggleStatus,
    required this.onTogglePinned,
    required this.onDelete,
  });

  final AdminNewsPost post;
  final bool canManagePublication;
  final VoidCallback onEdit;
  final VoidCallback onShare;
  final VoidCallback onNotify;
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
            if (canManagePublication)
              _NewsMenuItem(
                icon: post.published ? Symbols.visibility_off : Symbols.check,
                label: post.published ? 'Unpublish' : 'Publish',
                onTap: onToggleStatus,
              ),
            if (canManagePublication) ...[
              _NewsMenuItem(
                icon: Symbols.share_outlined,
                label: 'Share',
                onTap: onShare,
              ),
              _NewsMenuItem(
                icon: Symbols.notifications,
                label: 'Send notification',
                onTap: onNotify,
              ),
            ],
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
  const _NewsLoading({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.8,
              color: AppColors.actionRed,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.actionRed,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _NewsLoadingOverlay extends StatelessWidget {
  const _NewsLoadingOverlay({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      child: DecoratedBox(
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.78)),
        child: _NewsLoading(label: label),
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
          ),
        );
        final pager = _NewsPagination(
          page: page,
          lastPage: lastPage,
          loading: loading,
          onPageChanged: onPageChanged,
        );

        if (mobile) {
          final hasPrevious = page > 1 && !loading;
          final hasNext = page < lastPage && !loading;
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
    return AdminTablePagination(
      page: page,
      pageCount: lastPage,
      enabled: !loading,
      onPageChanged: onPageChanged,
    );
  }
}

class _NewsMobileView extends StatefulWidget {
  const _NewsMobileView({
    required this.posts,
    required this.filterOptions,
    required this.loading,
    required this.loadingLabel,
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
    required this.trashMode,
    required this.videoOnly,
    required this.canManagePublication,
    required this.onPageSizeChanged,
    required this.onSearchChanged,
    required this.onLanguageChanged,
    required this.onCategoryChanged,
    required this.onTypeChanged,
    required this.onStatusChanged,
    required this.onPublisherChanged,
    required this.onPageChanged,
    required this.onTogglePost,
    required this.onAddPost,
    required this.onEditPost,
    required this.onSharePost,
    required this.onNotifyPost,
    required this.onToggleStatus,
    required this.onTogglePinned,
    required this.onDeletePost,
    required this.onDeleteSelected,
    required this.onToggleTrashMode,
    required this.onToggleVideoOnly,
  });

  final List<AdminNewsPost> posts;
  final AdminNewsFilterOptions filterOptions;
  final bool loading;
  final String loadingLabel;
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
  final bool trashMode;
  final bool videoOnly;
  final bool canManagePublication;
  final ValueChanged<int?> onPageSizeChanged;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onLanguageChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String?> onTypeChanged;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onPublisherChanged;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<String> onTogglePost;
  final VoidCallback onAddPost;
  final ValueChanged<AdminNewsPost> onEditPost;
  final ValueChanged<AdminNewsPost> onSharePost;
  final ValueChanged<AdminNewsPost> onNotifyPost;
  final ValueChanged<AdminNewsPost> onToggleStatus;
  final ValueChanged<AdminNewsPost> onTogglePinned;
  final ValueChanged<AdminNewsPost> onDeletePost;
  final VoidCallback onDeleteSelected;
  final VoidCallback onToggleTrashMode;
  final VoidCallback onToggleVideoOnly;

  @override
  State<_NewsMobileView> createState() => _NewsMobileViewState();
}

class _NewsMobileViewState extends State<_NewsMobileView> {
  late final TextEditingController _searchController;
  var _filtersExpanded = false;

  int get _activeFilterCount {
    var count = 0;
    if (widget.languageFilter != 'Tümü') count++;
    if (widget.categoryFilter != 'Tümü') count++;
    if (widget.typeFilter != 'Tümü') count++;
    if (widget.statusFilter != 'Tümü') count++;
    if (widget.publisherFilter != 'Tümü') count++;
    return count;
  }

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.searchQuery);
  }

  @override
  void didUpdateWidget(covariant _NewsMobileView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery != _searchController.text) {
      _searchController.value = TextEditingValue(
        text: widget.searchQuery,
        selection: TextSelection.collapsed(offset: widget.searchQuery.length),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearFilters() {
    widget.onLanguageChanged('Tümü');
    widget.onCategoryChanged('Tümü');
    widget.onTypeChanged('Tümü');
    widget.onStatusChanged('Tümü');
    widget.onPublisherChanged('Tümü');
  }

  void _toggleFilters() {
    setState(() => _filtersExpanded = !_filtersExpanded);
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final lastPage = widget.totalCount == 0
        ? 1
        : ((widget.totalCount - 1) ~/ widget.pageSize) + 1;
    final from = widget.totalCount == 0
        ? 0
        : ((widget.page - 1) * widget.pageSize) + 1;
    final to = widget.totalCount == 0
        ? 0
        : (widget.page * widget.pageSize > widget.totalCount
              ? widget.totalCount
              : widget.page * widget.pageSize);
    final rangeText = context.t(
      'common.recordRange',
      values: {'from': from, 'to': to, 'total': widget.totalCount},
    );
    final hasSelection = widget.selectedPostIds.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LosposNewsFilterPanel(
          searchController: _searchController,
          hintText: context.t('Search posts...'),
          onSearchChanged: widget.onSearchChanged,
          isExpanded: _filtersExpanded,
          onToggleExpanded: _toggleFilters,
          activeFilterCount: _activeFilterCount,
          recordCount: widget.totalCount,
          pageSize: widget.pageSize,
          filterOptions: widget.filterOptions,
          languageFilter: widget.languageFilter,
          categoryFilter: widget.categoryFilter,
          typeFilter: widget.typeFilter,
          statusFilter: widget.statusFilter,
          publisherFilter: widget.publisherFilter,
          onPageSizeChanged: widget.onPageSizeChanged,
          onLanguageChanged: widget.onLanguageChanged,
          onCategoryChanged: widget.onCategoryChanged,
          onTypeChanged: widget.onTypeChanged,
          onStatusChanged: widget.onStatusChanged,
          onPublisherChanged: widget.onPublisherChanged,
          onClearFilters: _activeFilterCount == 0 ? null : _clearFilters,
        ),
        const SizedBox(height: 8),
        hasSelection
            ? AdminMobileSelectionBar(
                selectedCount: widget.selectedPostIds.length,
                label: context.t(
                  widget.trashMode
                      ? 'news.selectedPermanentDelete'
                      : 'news.selectedDelete',
                  values: {'count': widget.selectedPostIds.length},
                ),
                onClear: () {
                  for (final id in widget.selectedPostIds.toList()) {
                    widget.onTogglePost(id);
                  }
                },
                onDelete: widget.onDeleteSelected,
              )
            : _LosposNewsActionRow(
                trashMode: widget.trashMode,
                videoOnly: widget.videoOnly,
                onToggleTrashMode: widget.onToggleTrashMode,
                onToggleVideoOnly: widget.onToggleVideoOnly,
                onAddPost: widget.onAddPost,
              ),
        const SizedBox(height: 14),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: widget.videoOnly
                    ? _NewsVideoLibrary(
                        posts: widget.posts,
                        loading: widget.loading,
                        loadingLabel: widget.loadingLabel,
                        searching: false,
                        searchQuery: widget.searchQuery,
                        onEditPost: widget.onEditPost,
                      )
                    : widget.loading && widget.posts.isEmpty
                    ? _NewsLoading(label: widget.loadingLabel)
                    : AdminMobileListView(
                        loading: false,
                        itemCount: widget.posts.length,
                        emptyLabel: context.t('No posts found'),
                        itemBuilder: (context, index) {
                          final post = widget.posts[index];
                          return _NewsMobileCard(
                            post: post,
                            selected: widget.selectedPostIds.contains(post.id),
                            onToggle: () => widget.onTogglePost(post.id),
                            trashMode: widget.trashMode,
                            canManagePublication: widget.canManagePublication,
                            onEditPost: widget.onEditPost,
                            onSharePost: widget.onSharePost,
                            onNotifyPost: widget.onNotifyPost,
                            onToggleStatus: widget.onToggleStatus,
                            onTogglePinned: widget.onTogglePinned,
                            onDeletePost: widget.onDeletePost,
                          );
                        },
                      ),
              ),
              if (widget.loading && widget.posts.isNotEmpty)
                Positioned.fill(
                  child: _NewsLoadingOverlay(label: widget.loadingLabel),
                ),
            ],
          ),
        ),
        if (!widget.videoOnly) ...[
          const SizedBox(height: 4),
          _NewsMobileBottomPager(
            page: widget.page,
            lastPage: lastPage,
            rangeText: rangeText,
            loading: widget.loading,
            onPageChanged: widget.onPageChanged,
          ),
        ],
      ],
    );
  }
}

class _NewsMobileBottomPager extends StatelessWidget {
  const _NewsMobileBottomPager({
    required this.page,
    required this.lastPage,
    required this.rangeText,
    required this.loading,
    required this.onPageChanged,
  });

  final int page;
  final int lastPage;
  final String rangeText;
  final bool loading;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final hasPrevious = page > 1 && !loading;
    final hasNext = page < lastPage && !loading;
    return Transform.translate(
      offset: const Offset(0, 14),
      child: SizedBox(
        height: 28,
        child: Row(
          children: [
            _NewsMobileBottomPagerArrow(
              icon: Symbols.chevron_left_rounded,
              enabled: hasPrevious,
              onPressed: () => onPageChanged(page - 1),
            ),
            Expanded(
              child: Text(
                rangeText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFB8BDC3),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                ),
              ),
            ),
            _NewsMobileBottomPagerArrow(
              icon: Symbols.chevron_right,
              enabled: hasNext,
              onPressed: () => onPageChanged(page + 1),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewsMobileBottomPagerArrow extends StatelessWidget {
  const _NewsMobileBottomPagerArrow({
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: enabled ? onPressed : null,
      icon: Icon(
        icon,
        color: enabled ? AppColors.deepOcean : const Color(0xFFC5CAD0),
        size: 18,
      ),
      constraints: const BoxConstraints.tightFor(width: 30, height: 28),
      padding: EdgeInsets.zero,
      splashRadius: 16,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _LosposNewsFilterPanel extends StatelessWidget {
  const _LosposNewsFilterPanel({
    required this.searchController,
    required this.hintText,
    required this.onSearchChanged,
    required this.isExpanded,
    required this.onToggleExpanded,
    required this.activeFilterCount,
    required this.recordCount,
    required this.pageSize,
    required this.filterOptions,
    required this.languageFilter,
    required this.categoryFilter,
    required this.typeFilter,
    required this.statusFilter,
    required this.publisherFilter,
    required this.onPageSizeChanged,
    required this.onLanguageChanged,
    required this.onCategoryChanged,
    required this.onTypeChanged,
    required this.onStatusChanged,
    required this.onPublisherChanged,
    required this.onClearFilters,
  });

  static const _borderColor = Color(0xFFE6EAF0);
  static const _muted = Color(0xFF9AA3AA);
  static const _navy = Color(0xFF2F4053);

  final TextEditingController searchController;
  final String hintText;
  final ValueChanged<String> onSearchChanged;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;
  final int activeFilterCount;
  final int recordCount;
  final int pageSize;
  final AdminNewsFilterOptions filterOptions;
  final String languageFilter;
  final String categoryFilter;
  final String typeFilter;
  final String statusFilter;
  final String publisherFilter;
  final ValueChanged<int?> onPageSizeChanged;
  final ValueChanged<String?> onLanguageChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String?> onTypeChanged;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onPublisherChanged;
  final VoidCallback? onClearFilters;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 72,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 12, 9),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const SymbolIcon(
                          Symbols.search,
                          color: _muted,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TextField(
                                controller: searchController,
                                onChanged: onSearchChanged,
                                textAlignVertical: TextAlignVertical.center,
                                cursorColor: _navy,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  color: _navy,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: InputDecoration(
                                  hintText: hintText,
                                  hintStyle: const TextStyle(
                                    color: _muted,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                ),
                              ),
                              Container(
                                height: 1,
                                color: const Color(0xFFB9BEC4),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: onToggleExpanded,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                isExpanded ? 'Gizle' : 'Göster',
                                style: const TextStyle(
                                  color: _navy,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  height: 1,
                                ),
                              ),
                              const SizedBox(width: 4),
                              RotatedBox(
                                quarterTurns: isExpanded ? 2 : 0,
                                child: const SymbolIcon(
                                  Symbols.keyboard_arrow_down,
                                  color: _navy,
                                  size: 17,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '$recordCount kayıt',
                            style: const TextStyle(
                              color: _navy,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            activeFilterCount == 0
                                ? 'Filtre yok'
                                : '$activeFilterCount filtre',
                            style: const TextStyle(
                              color: _muted,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              height: 1,
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
          if (isExpanded) ...[
            const Divider(height: 1, color: _borderColor),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      _LosposPageSizeDropdown(
                        value: pageSize,
                        onChanged: onPageSizeChanged,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _LosposInlineFilterDropdown(
                          icon: Symbols.language,
                          label: context.t('Language'),
                          value: languageFilter,
                          items: [
                            DropdownMenuItem(
                              value: 'Tümü',
                              child: Text(context.t('All')),
                            ),
                            for (final language in filterOptions.languages)
                              DropdownMenuItem(
                                value: language.id,
                                child: Text(language.label),
                              ),
                          ],
                          onChanged: onLanguageChanged,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _LosposInlineFilterDropdown(
                          icon: Symbols.folder_open,
                          label: context.t('Category'),
                          value: categoryFilter,
                          items: [
                            DropdownMenuItem(
                              value: 'Tümü',
                              child: Text(context.t('All')),
                            ),
                            for (final category in filterOptions.categories)
                              DropdownMenuItem(
                                value: category.id,
                                child: Text(category.displayLabel),
                              ),
                          ],
                          onChanged: onCategoryChanged,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _LosposInlineFilterDropdown(
                          icon: Symbols.article,
                          label: context.t('Type'),
                          value: typeFilter,
                          items: [
                            DropdownMenuItem(
                              value: 'Tümü',
                              child: Text(context.t('All')),
                            ),
                            for (final type in filterOptions.types)
                              DropdownMenuItem(
                                value: type.id,
                                child: Text(context.t(_typeLabel(type.label))),
                              ),
                          ],
                          onChanged: onTypeChanged,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _LosposInlineFilterDropdown(
                          icon: Symbols.visibility,
                          label: context.t('Status'),
                          value: statusFilter,
                          items: [
                            DropdownMenuItem(
                              value: 'Tümü',
                              child: Text(context.t('All')),
                            ),
                            DropdownMenuItem(
                              value: 'published',
                              child: Text(context.t('Published')),
                            ),
                            DropdownMenuItem(
                              value: 'draft',
                              child: Text(context.t('Draft')),
                            ),
                          ],
                          onChanged: onStatusChanged,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _LosposInlineFilterDropdown(
                          icon: Symbols.person,
                          label: context.t('Publisher'),
                          value: publisherFilter,
                          items: [
                            DropdownMenuItem(
                              value: 'Tümü',
                              child: Text(context.t('All')),
                            ),
                            for (final publisher in filterOptions.publishers)
                              DropdownMenuItem(
                                value: publisher.id,
                                child: Text(publisher.label),
                              ),
                          ],
                          onChanged: onPublisherChanged,
                        ),
                      ),
                    ],
                  ),
                  if (onClearFilters != null) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: onClearFilters,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.actionRed,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(0, 32),
                        ),
                        child: const Text(
                          'Temizle',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LosposPageSizeDropdown extends StatelessWidget {
  const _LosposPageSizeDropdown({required this.value, required this.onChanged});

  static const _values = ['25', '50', '100'];

  final int value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = _values.contains(value.toString())
        ? value.toString()
        : '25';
    return Container(
      width: 66,
      height: 42,
      padding: const EdgeInsets.only(left: 10, right: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE6EAF0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selected,
          isDense: true,
          isExpanded: true,
          borderRadius: BorderRadius.circular(10),
          icon: const SymbolIcon(
            Symbols.keyboard_arrow_down,
            color: Color(0xFF6F7780),
            size: 16,
          ),
          style: const TextStyle(
            color: Color(0xFF2F4053),
            fontSize: 14.5,
            fontWeight: FontWeight.w500,
          ),
          items: const [
            DropdownMenuItem(value: '25', child: Text('25')),
            DropdownMenuItem(value: '50', child: Text('50')),
            DropdownMenuItem(value: '100', child: Text('100')),
          ],
          onChanged: (value) => onChanged(int.tryParse(value ?? '')),
        ),
      ),
    );
  }
}

class _LosposInlineFilterDropdown extends StatelessWidget {
  const _LosposInlineFilterDropdown({
    required this.icon,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final String value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final safeValue = items.any((item) => item.value == value)
        ? value
        : (items.isEmpty ? null : items.first.value);

    return Container(
      height: 42,
      padding: const EdgeInsets.only(left: 10, right: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE6EAF0)),
      ),
      child: Row(
        children: [
          SymbolIcon(icon, color: const Color(0xFF7C858D), size: 17),
          const SizedBox(width: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF6B7076),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: safeValue,
                isDense: true,
                isExpanded: true,
                alignment: Alignment.centerRight,
                borderRadius: BorderRadius.circular(10),
                dropdownColor: Colors.white,
                icon: const SymbolIcon(
                  Symbols.keyboard_arrow_down,
                  color: Color(0xFFB0B8BE),
                  size: 16,
                ),
                style: const TextStyle(
                  color: Color(0xFF2F4053),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
                items: items,
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LosposNewsActionRow extends StatelessWidget {
  const _LosposNewsActionRow({
    required this.trashMode,
    required this.videoOnly,
    required this.onToggleTrashMode,
    required this.onToggleVideoOnly,
    required this.onAddPost,
  });

  static const _navy = Color(0xFF2F4053);
  static const _red = Color(0xFFF44336);

  final bool trashMode;
  final bool videoOnly;
  final VoidCallback onToggleTrashMode;
  final VoidCallback onToggleVideoOnly;
  final VoidCallback onAddPost;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _LosposNewsActionButton(
            icon: trashMode ? Symbols.newspaper : Symbols.delete,
            label: context.t(trashMode ? 'news.activePosts' : 'news.trash'),
            backgroundColor: Colors.white,
            foregroundColor: trashMode ? _navy : const Color(0xFF8C9298),
            borderColor: const Color(0xFFE6EAF0),
            onPressed: onToggleTrashMode,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _LosposNewsActionButton(
            icon: Symbols.add,
            label: context.t('Add Post'),
            backgroundColor: _red,
            foregroundColor: Colors.white,
            onPressed: onAddPost,
          ),
        ),
        const SizedBox(width: 8),
        _LosposNewsActionButton(
          width: 40,
          icon: videoOnly
              ? Symbols.play_circle_rounded
              : Symbols.play_circle_outline_rounded,
          backgroundColor: _navy,
          foregroundColor: Colors.white,
          onPressed: onToggleVideoOnly,
        ),
      ],
    );
  }
}

class _LosposNewsActionButton extends StatelessWidget {
  const _LosposNewsActionButton({
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onPressed,
    this.label,
    this.width,
    this.borderColor,
  });

  final IconData icon;
  final String? label;
  final double? width;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color? borderColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 40,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          padding: EdgeInsets.symmetric(horizontal: label == null ? 0 : 10),
          minimumSize: const Size(0, 40),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: borderColor ?? backgroundColor),
          ),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            SymbolIcon(icon, color: foregroundColor, size: 17),
            if (label != null) ...[
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NewsMobileCard extends StatelessWidget {
  const _NewsMobileCard({
    required this.post,
    required this.selected,
    required this.onToggle,
    required this.trashMode,
    required this.canManagePublication,
    required this.onEditPost,
    required this.onSharePost,
    required this.onNotifyPost,
    required this.onToggleStatus,
    required this.onTogglePinned,
    required this.onDeletePost,
  });

  final AdminNewsPost post;
  final bool selected;
  final VoidCallback onToggle;
  final bool trashMode;
  final bool canManagePublication;
  final ValueChanged<AdminNewsPost> onEditPost;
  final ValueChanged<AdminNewsPost> onSharePost;
  final ValueChanged<AdminNewsPost> onNotifyPost;
  final ValueChanged<AdminNewsPost> onToggleStatus;
  final ValueChanged<AdminNewsPost> onTogglePinned;
  final ValueChanged<AdminNewsPost> onDeletePost;

  @override
  Widget build(BuildContext context) {
    final statusColor = post.published
        ? const Color(0xFF198754)
        : const Color(0xFFFF9800);
    final statusLabel = context.t(post.published ? 'Published' : 'Draft');
    final typeLabel = context.t(_typeLabel(post.displayType));

    return AdminMobileCard(
      selected: selected,
      onTap: trashMode
          ? onToggle
          : () => unawaited(_openPostDetail(context, post)),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: AdminMobileCheckbox(
                  value: selected,
                  onChanged: (_) => onToggle(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (post.isPinned) ...[
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: SymbolIcon(
                              Symbols.push_pin,
                              color: Color(0xFFFF9800),
                              size: 15,
                            ),
                          ),
                          const SizedBox(width: 5),
                        ],
                        Expanded(
                          child: HighlightedText(
                            post.displayTitle,
                            query: _NewsSearchScope.of(context),
                            style: const TextStyle(
                              color: Color(0xFF2F4053),
                              fontWeight: FontWeight.w700,
                              fontSize: 14.2,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    HighlightedText(
                      '${post.id} • ${post.displayCategory} • $typeLabel',
                      query: _NewsSearchScope.of(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF7A7F85),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (trashMode)
                const Padding(
                  padding: EdgeInsets.only(top: 3),
                  child: SymbolIcon(
                    Symbols.delete,
                    color: Color(0xFF9AA3AA),
                    size: 18,
                  ),
                )
              else
                Transform.scale(
                  scale: 0.88,
                  alignment: Alignment.topRight,
                  child: AdminMobileMenuButton(
                    tooltip: context.t('Post actions'),
                    actions: [
                      AdminMobileMenuAction(
                        icon: Symbols.edit_square,
                        label: context.t('Edit'),
                        onTap: () => onEditPost(post),
                      ),
                      if (canManagePublication)
                        AdminMobileMenuAction(
                          icon: post.published
                              ? Symbols.visibility_off
                              : Symbols.check,
                          label: context.t(
                            post.published ? 'Unpublish' : 'Publish',
                          ),
                          onTap: () => onToggleStatus(post),
                        ),
                      if (canManagePublication)
                        AdminMobileMenuAction(
                          icon: Symbols.share_outlined,
                          label: context.t('Share'),
                          onTap: () => onSharePost(post),
                        ),
                      if (canManagePublication)
                        AdminMobileMenuAction(
                          icon: Symbols.notifications,
                          label: context.t('Send notification'),
                          onTap: () => onNotifyPost(post),
                        ),
                      AdminMobileMenuAction(
                        icon: post.isPinned
                            ? Symbols.visibility_off
                            : Symbols.verified,
                        label: context.t(post.isPinned ? 'Unpin' : 'Pin'),
                        onTap: () => onTogglePinned(post),
                      ),
                      AdminMobileMenuAction(
                        icon: Symbols.delete,
                        label: context.t('Delete'),
                        danger: true,
                        onTap: () => onDeletePost(post),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 13),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _LosposNewsStatusBadge(label: statusLabel, color: statusColor),
              _LosposNewsMetricChip(
                icon: Symbols.visibility,
                label: '${post.viewsCount} görüntüleme',
              ),
              _LosposNewsMetricChip(
                icon: Symbols.chat_bubble_outline,
                label: '${post.commentsCount} yorum',
              ),
              _LosposNewsMetricChip(
                icon: Symbols.favorite_outline_rounded,
                label: '${post.likesCount} beğeni',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openPostDetail(BuildContext context, AdminNewsPost post) async {
    final resolved = await _resolveFrontendArticle(post);
    if (!context.mounted) return;
    if (resolved == null) {
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.hideCurrentSnackBar();
      messenger?.showSnackBar(
        const SnackBar(content: Text('Haber içeriği alınamadı.')),
      );
      return;
    }

    Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 240),
        pageBuilder: (_, _, _) => NewsDetailScreen(
          articles: resolved.articles,
          initialIndex: resolved.initialIndex,
        ),
        transitionsBuilder: (context, animation, secondary, child) {
          final fade = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          final slide = Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(fade);
          return FadeTransition(
            opacity: fade,
            child: SlideTransition(position: slide, child: child),
          );
        },
      ),
    );
  }
}

class _LosposNewsStatusBadge extends StatelessWidget {
  const _LosposNewsStatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}

class _LosposNewsMetricChip extends StatelessWidget {
  const _LosposNewsMetricChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SymbolIcon(icon, color: const Color(0xFF9AA3AA), size: 13),
        const SizedBox(width: 3),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF7A7F85),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
      ],
    );
  }
}

String _typeLabel(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) return 'standard';
  final key = 'admin.post.tab.$normalized';
  return key;
}

class _ResolvedFrontendArticle {
  const _ResolvedFrontendArticle({
    required this.articles,
    required this.initialIndex,
  });

  final List<NewsArticle> articles;
  final int initialIndex;
}

Future<_ResolvedFrontendArticle?> _resolveFrontendArticle(
  AdminNewsPost post,
) async {
  const repository = SearchRepository();
  for (final key in _frontendArticleSearchKeys(post)) {
    final data = await repository.search(
      query: key,
      lang: post.displayLanguage,
    );
    final index = _frontendArticleIndex(data.posts, post);
    if (index >= 0) {
      return _ResolvedFrontendArticle(
        articles: data.posts,
        initialIndex: index,
      );
    }
  }
  return null;
}

List<String> _frontendArticleSearchKeys(AdminNewsPost post) {
  final keys = <String>[];
  final seen = <String>{};

  void add(String value) {
    final clean = value.trim();
    if (clean.length < 2) return;
    final normalized = clean.toLowerCase();
    if (seen.add(normalized)) keys.add(clean);
  }

  add(post.slug);
  add(post.displayTitle);
  add(post.id);
  return keys;
}

int _frontendArticleIndex(List<NewsArticle> articles, AdminNewsPost post) {
  final id = post.id.trim().toLowerCase();
  final slug = post.slug.trim().toLowerCase();
  final title = post.displayTitle.trim().toLowerCase();

  for (var i = 0; i < articles.length; i++) {
    final article = articles[i];
    if (id.isNotEmpty && article.id.trim().toLowerCase() == id) return i;
    if (slug.isNotEmpty && article.slug.trim().toLowerCase() == slug) return i;
  }

  for (var i = 0; i < articles.length; i++) {
    if (title.isNotEmpty && articles[i].title.trim().toLowerCase() == title) {
      return i;
    }
  }

  return -1;
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
      TargetPlatform.android => Uri.parse('https://pateez.com'),
      _ => Uri.parse('https://pateez.com'),
    };
  }
  return Uri.base;
}
