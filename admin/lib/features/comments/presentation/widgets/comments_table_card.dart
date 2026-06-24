import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../../core/localization/admin_date_formatter.dart';
import '../../../../core/localization/admin_language_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../shared/data/admin_image_url.dart';
import '../../../../shared/widgets/admin_cached_image.dart';
import '../../../../shared/widgets/admin_mobile_list.dart';
import '../../../../shared/widgets/admin_table_chrome.dart';
import '../../../../shared/widgets/highlighted_text.dart';
import '../../../../shared/widgets/sortable_table_header.dart';
import '../../../../shared/widgets/symbol_icon.dart';
import '../comments_models.dart';
import 'comment_link_opener.dart';

/// Aktif arama sorgusunu satır hücrelerine (yorum/kullanıcı/haber/ID) taşır;
/// böylece highlight için her hücreye tek tek parametre geçmeye gerek kalmaz.
class _CommentsSearchScope extends InheritedWidget {
  const _CommentsSearchScope({required this.query, required super.child});

  final String query;

  static String of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_CommentsSearchScope>()
          ?.query ??
      '';

  @override
  bool updateShouldNotify(_CommentsSearchScope oldWidget) =>
      oldWidget.query != query;
}

class CommentsTableCard extends StatelessWidget {
  const CommentsTableCard({
    super.key,
    required this.comments,
    required this.filterOptions,
    required this.loading,
    this.searching = false,
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.searchQuery,
    required this.statusFilter,
    required this.postFilter,
    required this.userFilter,
    required this.selectedCommentIds,
    required this.sortState,
    required this.onPageSizeChanged,
    required this.onSearchChanged,
    required this.onStatusChanged,
    required this.onPostChanged,
    required this.onUserChanged,
    required this.onPageChanged,
    required this.onToggleComment,
    required this.onToggleAllComments,
    required this.onSort,
    required this.onApproveComment,
    required this.onRejectComment,
    required this.onTogglePinned,
    required this.onReplyComment,
    required this.onDeleteComment,
    required this.onDeleteSelected,
    required this.onApproveSelected,
    required this.onRejectSelected,
  });

  final List<AdminComment> comments;
  final AdminCommentFilterOptions filterOptions;
  final bool loading;
  final bool searching;
  final int page;
  final int pageSize;
  final int totalCount;
  final String searchQuery;
  final String statusFilter;
  final String postFilter;
  final String userFilter;
  final Set<String> selectedCommentIds;
  final TableSortState sortState;
  final ValueChanged<int?> onPageSizeChanged;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onPostChanged;
  final ValueChanged<String?> onUserChanged;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<String> onToggleComment;
  final VoidCallback onToggleAllComments;
  final ValueChanged<String> onSort;
  final ValueChanged<AdminComment> onApproveComment;
  final ValueChanged<AdminComment> onRejectComment;
  final ValueChanged<AdminComment> onTogglePinned;
  final ValueChanged<AdminComment> onReplyComment;
  final ValueChanged<AdminComment> onDeleteComment;
  final VoidCallback onDeleteSelected;
  final VoidCallback onApproveSelected;
  final VoidCallback onRejectSelected;

  static const double toolbarHeight = 38;

  @override
  Widget build(BuildContext context) {
    return _CommentsSearchScope(
      query: searchQuery,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < AdminMobile.breakpoint) {
            return _CommentsMobileView(
              comments: comments,
              filterOptions: filterOptions,
              loading: loading,
              page: page,
              pageSize: pageSize,
              totalCount: totalCount,
              searchQuery: searchQuery,
              statusFilter: statusFilter,
              postFilter: postFilter,
              userFilter: userFilter,
              selectedCommentIds: selectedCommentIds,
              onPageSizeChanged: onPageSizeChanged,
              onSearchChanged: onSearchChanged,
              onStatusChanged: onStatusChanged,
              onPostChanged: onPostChanged,
              onUserChanged: onUserChanged,
              onPageChanged: onPageChanged,
              onToggleComment: onToggleComment,
              onApproveComment: onApproveComment,
              onRejectComment: onRejectComment,
              onTogglePinned: onTogglePinned,
              onReplyComment: onReplyComment,
              onDeleteComment: onDeleteComment,
              onDeleteSelected: onDeleteSelected,
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CommentsFilters(
                filterOptions: filterOptions,
                statusFilter: statusFilter,
                postFilter: postFilter,
                userFilter: userFilter,
                onStatusChanged: onStatusChanged,
                onPostChanged: onPostChanged,
                onUserChanged: onUserChanged,
              ),
              const SizedBox(height: 28),
              _CommentsToolbar(
                pageSize: pageSize,
                searchQuery: searchQuery,
                selectedCount: selectedCommentIds.length,
                onPageSizeChanged: onPageSizeChanged,
                onSearchChanged: onSearchChanged,
                onDeleteSelected: onDeleteSelected,
                onApproveSelected: onApproveSelected,
                onRejectSelected: onRejectSelected,
              ),
              const SizedBox(height: 18),
              Expanded(
                child: _CommentsDataTable(
                  comments: comments,
                  loading: loading,
                  searching: searching,
                  selectedCommentIds: selectedCommentIds,
                  sortState: sortState,
                  onToggleComment: onToggleComment,
                  onToggleAllComments: onToggleAllComments,
                  onSort: onSort,
                  onApproveComment: onApproveComment,
                  onRejectComment: onRejectComment,
                  onTogglePinned: onTogglePinned,
                  onReplyComment: onReplyComment,
                  onDeleteComment: onDeleteComment,
                ),
              ),
              const SizedBox(height: 16),
              _CommentsFooter(
                page: page,
                pageSize: pageSize,
                totalCount: totalCount,
                loading: loading,
                onPageChanged: onPageChanged,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CommentsMobileView extends StatefulWidget {
  const _CommentsMobileView({
    required this.comments,
    required this.filterOptions,
    required this.loading,
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.searchQuery,
    required this.statusFilter,
    required this.postFilter,
    required this.userFilter,
    required this.selectedCommentIds,
    required this.onPageSizeChanged,
    required this.onSearchChanged,
    required this.onStatusChanged,
    required this.onPostChanged,
    required this.onUserChanged,
    required this.onPageChanged,
    required this.onToggleComment,
    required this.onApproveComment,
    required this.onRejectComment,
    required this.onTogglePinned,
    required this.onReplyComment,
    required this.onDeleteComment,
    required this.onDeleteSelected,
  });

  final List<AdminComment> comments;
  final AdminCommentFilterOptions filterOptions;
  final bool loading;
  final int page;
  final int pageSize;
  final int totalCount;
  final String searchQuery;
  final String statusFilter;
  final String postFilter;
  final String userFilter;
  final Set<String> selectedCommentIds;
  final ValueChanged<int?> onPageSizeChanged;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onPostChanged;
  final ValueChanged<String?> onUserChanged;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<String> onToggleComment;
  final ValueChanged<AdminComment> onApproveComment;
  final ValueChanged<AdminComment> onRejectComment;
  final ValueChanged<AdminComment> onTogglePinned;
  final ValueChanged<AdminComment> onReplyComment;
  final ValueChanged<AdminComment> onDeleteComment;
  final VoidCallback onDeleteSelected;

  @override
  State<_CommentsMobileView> createState() => _CommentsMobileViewState();
}

class _CommentsMobileViewState extends State<_CommentsMobileView> {
  late final TextEditingController _searchController;
  var _filtersExpanded = false;

  int get _activeFilterCount {
    var count = 0;
    if (widget.statusFilter != 'Tümü') count++;
    if (widget.postFilter != 'Tümü') count++;
    if (widget.userFilter != 'Tümü') count++;
    return count;
  }

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.searchQuery);
  }

  @override
  void didUpdateWidget(covariant _CommentsMobileView oldWidget) {
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

  void _toggleFilters() {
    setState(() => _filtersExpanded = !_filtersExpanded);
    FocusScope.of(context).unfocus();
  }

  void _clearFilters() {
    widget.onStatusChanged('Tümü');
    widget.onPostChanged('Tümü');
    widget.onUserChanged('Tümü');
  }

  List<DropdownMenuItem<String>> _statusItems(BuildContext context) {
    return [
      DropdownMenuItem(value: 'Tümü', child: Text(context.t('All'))),
      DropdownMenuItem(value: 'approved', child: Text(context.t('Approved'))),
      DropdownMenuItem(value: 'pending', child: Text(context.t('Pending'))),
      DropdownMenuItem(value: 'rejected', child: Text(context.t('Rejected'))),
      DropdownMenuItem(value: 'Reported', child: Text(context.t('Reported'))),
    ];
  }

  List<DropdownMenuItem<String>> _postItems(BuildContext context) {
    return [
      DropdownMenuItem(value: 'Tümü', child: Text(context.t('All'))),
      for (final post in widget.filterOptions.posts)
        DropdownMenuItem(value: post.id, child: Text(post.label)),
    ];
  }

  List<DropdownMenuItem<String>> _userItems(BuildContext context) {
    return [
      DropdownMenuItem(value: 'Tümü', child: Text(context.t('All'))),
      for (final user in widget.filterOptions.users)
        DropdownMenuItem(value: user.id, child: Text(user.label)),
    ];
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
    final hasSelection = widget.selectedCommentIds.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CommentsMobileFilterPanel(
          searchController: _searchController,
          hintText: context.t('Search comments...'),
          onSearchChanged: widget.onSearchChanged,
          isExpanded: _filtersExpanded,
          onToggleExpanded: _toggleFilters,
          activeFilterCount: _activeFilterCount,
          recordCount: widget.totalCount,
          pageSize: widget.pageSize,
          statusFilter: widget.statusFilter,
          postFilter: widget.postFilter,
          userFilter: widget.userFilter,
          statusItems: _statusItems(context),
          postItems: _postItems(context),
          userItems: _userItems(context),
          onPageSizeChanged: widget.onPageSizeChanged,
          onStatusChanged: widget.onStatusChanged,
          onPostChanged: widget.onPostChanged,
          onUserChanged: widget.onUserChanged,
          onClearFilters: _activeFilterCount == 0 ? null : _clearFilters,
        ),
        if (hasSelection) ...[
          const SizedBox(height: 8),
          AdminMobileSelectionBar(
            selectedCount: widget.selectedCommentIds.length,
            label: context.t(
              'comments.selectedDelete',
              values: {'count': widget.selectedCommentIds.length},
            ),
            onClear: () {
              for (final id in widget.selectedCommentIds.toList()) {
                widget.onToggleComment(id);
              }
            },
            onDelete: widget.onDeleteSelected,
          ),
        ],
        const SizedBox(height: 14),
        Expanded(
          child: AdminMobileListView(
            loading: widget.loading,
            itemCount: widget.comments.length,
            emptyLabel: context.t('No comments found'),
            itemBuilder: (context, index) {
              final comment = widget.comments[index];
              return _CommentsMobileCard(
                comment: comment,
                selected: widget.selectedCommentIds.contains(comment.id),
                onToggle: () => widget.onToggleComment(comment.id),
                onApproveComment: widget.onApproveComment,
                onRejectComment: widget.onRejectComment,
                onTogglePinned: widget.onTogglePinned,
                onReplyComment: widget.onReplyComment,
                onDeleteComment: widget.onDeleteComment,
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        AdminMobilePager(
          page: widget.page,
          lastPage: lastPage,
          rangeText: rangeText,
          loading: widget.loading,
          onPageChanged: widget.onPageChanged,
        ),
      ],
    );
  }
}

class _CommentsMobileFilterPanel extends StatelessWidget {
  const _CommentsMobileFilterPanel({
    required this.searchController,
    required this.hintText,
    required this.onSearchChanged,
    required this.isExpanded,
    required this.onToggleExpanded,
    required this.activeFilterCount,
    required this.recordCount,
    required this.pageSize,
    required this.statusFilter,
    required this.postFilter,
    required this.userFilter,
    required this.statusItems,
    required this.postItems,
    required this.userItems,
    required this.onPageSizeChanged,
    required this.onStatusChanged,
    required this.onPostChanged,
    required this.onUserChanged,
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
  final String statusFilter;
  final String postFilter;
  final String userFilter;
  final List<DropdownMenuItem<String>> statusItems;
  final List<DropdownMenuItem<String>> postItems;
  final List<DropdownMenuItem<String>> userItems;
  final ValueChanged<int?> onPageSizeChanged;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onPostChanged;
  final ValueChanged<String?> onUserChanged;
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
                      _CommentsMobilePageSizeDropdown(
                        value: pageSize,
                        onChanged: onPageSizeChanged,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _CommentsMobileFilterDropdown(
                          icon: Symbols.visibility,
                          label: context.t('Status'),
                          value: statusFilter,
                          items: statusItems,
                          onChanged: onStatusChanged,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _CommentsMobileFilterDropdown(
                          icon: Symbols.article,
                          label: context.t('Post'),
                          value: postFilter,
                          items: postItems,
                          onChanged: onPostChanged,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _CommentsMobileFilterDropdown(
                          icon: Symbols.person,
                          label: context.t('User'),
                          value: userFilter,
                          items: userItems,
                          onChanged: onUserChanged,
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

class _CommentsMobilePageSizeDropdown extends StatelessWidget {
  const _CommentsMobilePageSizeDropdown({
    required this.value,
    required this.onChanged,
  });

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

class _CommentsMobileFilterDropdown extends StatelessWidget {
  const _CommentsMobileFilterDropdown({
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
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: safeValue,
          isExpanded: true,
          borderRadius: BorderRadius.circular(10),
          icon: const SymbolIcon(
            Symbols.keyboard_arrow_down,
            color: Color(0xFF6F7780),
            size: 16,
          ),
          hint: Row(
            children: [
              SymbolIcon(icon, color: const Color(0xFF6F7780), size: 15),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          selectedItemBuilder: (context) {
            return items.map((item) {
              return Row(
                children: [
                  SymbolIcon(icon, color: const Color(0xFF6F7780), size: 15),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item.child is Text
                          ? ((item.child as Text).data ?? '')
                          : (item.value ?? ''),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              );
            }).toList();
          },
          style: const TextStyle(
            color: Color(0xFF2F4053),
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _CommentsMobileCard extends StatelessWidget {
  const _CommentsMobileCard({
    required this.comment,
    required this.selected,
    required this.onToggle,
    required this.onApproveComment,
    required this.onRejectComment,
    required this.onTogglePinned,
    required this.onReplyComment,
    required this.onDeleteComment,
  });

  final AdminComment comment;
  final bool selected;
  final VoidCallback onToggle;
  final ValueChanged<AdminComment> onApproveComment;
  final ValueChanged<AdminComment> onRejectComment;
  final ValueChanged<AdminComment> onTogglePinned;
  final ValueChanged<AdminComment> onReplyComment;
  final ValueChanged<AdminComment> onDeleteComment;

  @override
  Widget build(BuildContext context) {
    final label = switch (comment.status) {
      'approved' => 'Approved',
      'rejected' => 'Rejected',
      _ => 'Pending',
    };
    final color = switch (comment.status) {
      'approved' => const Color(0xFF198754),
      'rejected' => AppColors.actionRed,
      _ => AppColors.warmHorizon,
    };
    final avatar = comment.userAvatar.trim();
    final hasPost = comment.postId.trim().isNotEmpty;

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
              AdminMobileAvatar(
                label: context.t(comment.displayUser),
                imageUrl: avatar.isEmpty
                    ? null
                    : adminImageUrl(avatar, width: 96),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (comment.isPinned) ...[
                          const SymbolIcon(
                            Symbols.verified,
                            color: AppColors.warmHorizon,
                            size: 15,
                          ),
                          const SizedBox(width: 5),
                        ],
                        Expanded(
                          child: _CommentAuthorDetails(
                            comment: comment,
                            compact: true,
                          ),
                        ),
                        if (comment.hasReports) ...[
                          const SizedBox(width: 8),
                          AdminMobileChip(
                            label: context.t(
                              'comments.reportCount',
                              values: {'count': comment.reportsCount},
                            ),
                            color: AppColors.actionRed,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    HighlightedText(
                      comment.content,
                      query: _CommentsSearchScope.of(context),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.32,
                        color: AppColors.inkSoft,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              AdminMobileMenuButton(
                tooltip: context.t('Comment actions'),
                actions: [
                  AdminMobileMenuAction(
                    icon: Symbols.check,
                    label: context.t('Approve'),
                    onTap: () => onApproveComment(comment),
                  ),
                  AdminMobileMenuAction(
                    icon: Symbols.close,
                    label: context.t('Reject'),
                    onTap: () => onRejectComment(comment),
                  ),
                  AdminMobileMenuAction(
                    icon: comment.isPinned
                        ? Symbols.visibility_off
                        : Symbols.verified,
                    label: context.t(comment.isPinned ? 'Unpin' : 'Pin'),
                    onTap: () => onTogglePinned(comment),
                  ),
                  AdminMobileMenuAction(
                    icon: Symbols.short_text,
                    label: context.t('Reply'),
                    onTap: () => onReplyComment(comment),
                  ),
                  AdminMobileMenuAction(
                    icon: Symbols.delete,
                    label: context.t('Delete'),
                    danger: true,
                    onTap: () => onDeleteComment(comment),
                  ),
                ],
              ),
            ],
          ),
          if (hasPost) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Row(
                children: [
                  const SymbolIcon(
                    Symbols.article,
                    color: AppColors.iconMuted,
                    size: 15,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: _PostCell(comment: comment)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Divider(height: 1, color: AppColors.softLine.withValues(alpha: 0.9)),
          const SizedBox(height: 10),
          Row(
            children: [
              AdminMobileStatusPill(label: context.t(label), color: color),
              const Spacer(),
              AdminMobileMeta(
                icon: Symbols.short_text,
                value: '${comment.repliesCount}',
              ),
              const SizedBox(width: 12),
              Text(
                formatAdminFullDate(context, comment.createdAt),
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

class _CommentsFilters extends StatelessWidget {
  const _CommentsFilters({
    required this.filterOptions,
    required this.statusFilter,
    required this.postFilter,
    required this.userFilter,
    required this.onStatusChanged,
    required this.onPostChanged,
    required this.onUserChanged,
  });

  final AdminCommentFilterOptions filterOptions;
  final String statusFilter;
  final String postFilter;
  final String userFilter;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onPostChanged;
  final ValueChanged<String?> onUserChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 820;
        final filters = [
          _FilterSelect(
            label: 'Status',
            value: statusFilter,
            items: [
              DropdownMenuItem(value: 'Tümü', child: Text(context.t('All'))),
              DropdownMenuItem(
                value: 'approved',
                child: Text(context.t('Approved')),
              ),
              DropdownMenuItem(
                value: 'pending',
                child: Text(context.t('Pending')),
              ),
              DropdownMenuItem(
                value: 'rejected',
                child: Text(context.t('Rejected')),
              ),
              DropdownMenuItem(
                value: 'Reported',
                child: Text(context.t('Reported')),
              ),
            ],
            onChanged: onStatusChanged,
          ),
          _FilterSelect(
            label: 'Post',
            value: postFilter,
            items: [
              DropdownMenuItem(value: 'Tümü', child: Text(context.t('All'))),
              for (final post in filterOptions.posts)
                DropdownMenuItem(value: post.id, child: Text(post.label)),
            ],
            onChanged: onPostChanged,
          ),
          _FilterSelect(
            label: 'User',
            value: userFilter,
            items: [
              DropdownMenuItem(value: 'Tümü', child: Text(context.t('All'))),
              for (final user in filterOptions.users)
                DropdownMenuItem(value: user.id, child: Text(user.label)),
            ],
            onChanged: onUserChanged,
          ),
        ];

        if (compact) {
          return Column(
            children: [
              for (var index = 0; index < filters.length; index++) ...[
                filters[index],
                if (index != filters.length - 1) const SizedBox(height: 14),
              ],
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
            height: CommentsTableCard.toolbarHeight,
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

class _CommentsToolbar extends StatelessWidget {
  const _CommentsToolbar({
    required this.pageSize,
    required this.searchQuery,
    required this.selectedCount,
    required this.onPageSizeChanged,
    required this.onSearchChanged,
    required this.onDeleteSelected,
    required this.onApproveSelected,
    required this.onRejectSelected,
  });

  final int pageSize;
  final String searchQuery;
  final int selectedCount;
  final ValueChanged<int?> onPageSizeChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onDeleteSelected;
  final VoidCallback onApproveSelected;
  final VoidCallback onRejectSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 940;
        final pageSizeSelect = _PageSizeSelect(
          value: pageSize,
          onChanged: onPageSizeChanged,
        );
        final search = ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: compact ? double.infinity : 260,
            maxWidth: compact ? double.infinity : 280,
          ),
          child: _CommentSearchField(
            value: searchQuery,
            onChanged: onSearchChanged,
          ),
        );
        final deleteButton = selectedCount == 0
            ? null
            : _BulkDeleteButton(
                selectedCount: selectedCount,
                onPressed: onDeleteSelected,
              );
        final approveButton = selectedCount == 0
            ? null
            : _BulkStatusButton(
                icon: Symbols.check,
                label: 'Approve',
                color: const Color(0xFF198754),
                filled: true,
                onPressed: onApproveSelected,
              );
        final rejectButton = selectedCount == 0
            ? null
            : _BulkStatusButton(
                icon: Symbols.close,
                label: 'Reject',
                color: AppColors.actionRed,
                filled: false,
                onPressed: onRejectSelected,
              );
        final actionButtons = <Widget>[
          ?deleteButton,
          ?approveButton,
          ?rejectButton,
        ];

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(alignment: Alignment.centerLeft, child: pageSizeSelect),
              if (actionButtons.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: actionButtons),
              ],
              const SizedBox(height: 14),
              search,
            ],
          );
        }

        return Row(
          children: [
            pageSizeSelect,
            if (actionButtons.isNotEmpty) ...[
              const SizedBox(width: 12),
              ...[
                for (var index = 0; index < actionButtons.length; index++) ...[
                  if (index > 0) const SizedBox(width: 8),
                  actionButtons[index],
                ],
              ],
            ],
            const Spacer(),
            search,
          ],
        );
      },
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
      message: context.t('comments.search.clear'),
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

class _PageSizeSelect extends StatelessWidget {
  const _PageSizeSelect({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        height: CommentsTableCard.toolbarHeight,
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

class _CommentSearchField extends StatefulWidget {
  const _CommentSearchField({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_CommentSearchField> createState() => _CommentSearchFieldState();
}

class _CommentSearchFieldState extends State<_CommentSearchField> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _CommentSearchField oldWidget) {
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
      height: CommentsTableCard.toolbarHeight,
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
          hintText: context.t('Search comments...'),
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
            minHeight: CommentsTableCard.toolbarHeight,
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
            minHeight: CommentsTableCard.toolbarHeight,
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
                'comments.selectedDelete',
                values: {'count': selectedCount},
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BulkStatusButton extends StatelessWidget {
  const _BulkStatusButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.filled,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool filled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final foreground = filled ? Colors.white : color;

    return SizedBox(
      height: 34,
      child: TextButton(
        onPressed: onPressed,
        style:
            TextButton.styleFrom(
              backgroundColor: filled ? color : Colors.white,
              foregroundColor: foreground,
              side: filled
                  ? BorderSide.none
                  : BorderSide(color: color.withValues(alpha: 0.28)),
              minimumSize: const Size(0, 34),
              maximumSize: const Size(double.infinity, 34),
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
              overlayColor: WidgetStatePropertyAll(
                color.withValues(alpha: filled ? 0.18 : 0.08),
              ),
              mouseCursor: const WidgetStatePropertyAll(
                SystemMouseCursors.click,
              ),
            ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SymbolIcon(icon, color: foreground, size: 14),
            const SizedBox(width: 6),
            Text(context.t(label)),
          ],
        ),
      ),
    );
  }
}

class _CommentsDataTable extends StatelessWidget {
  const _CommentsDataTable({
    required this.comments,
    required this.loading,
    this.searching = false,
    required this.selectedCommentIds,
    required this.sortState,
    required this.onToggleComment,
    required this.onToggleAllComments,
    required this.onSort,
    required this.onApproveComment,
    required this.onRejectComment,
    required this.onTogglePinned,
    required this.onReplyComment,
    required this.onDeleteComment,
  });

  final List<AdminComment> comments;
  final bool loading;
  final bool searching;
  final Set<String> selectedCommentIds;
  final TableSortState sortState;
  final ValueChanged<String> onToggleComment;
  final VoidCallback onToggleAllComments;
  final ValueChanged<String> onSort;
  final ValueChanged<AdminComment> onApproveComment;
  final ValueChanged<AdminComment> onRejectComment;
  final ValueChanged<AdminComment> onTogglePinned;
  final ValueChanged<AdminComment> onReplyComment;
  final ValueChanged<AdminComment> onDeleteComment;

  static const double _minWidth = 1320;
  static const double _selectWidth = 42;
  static const double _idWidth = 64;
  static const double _postWidth = 238;
  static const double _statusWidth = 132;
  static const double _likesWidth = 92;
  static const double _repliesWidth = 92;
  static const double _createdWidth = 236;
  static const double _menuWidth = 70;
  static const double _contentSpacing = 36;
  static const double _rowMinHeight = 86;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth = AdminTableChrome.desktopTableWidth(
          constraints: constraints,
          preferredMinWidth: _minWidth,
        );
        final layout = _CommentsTableColumnLayout.forWidth(tableWidth);

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
                  _CommentsHeader(
                    layout: layout,
                    selectedCount: selectedCommentIds.length,
                    totalCount: comments.length,
                    sortState: sortState,
                    onToggleAllComments: onToggleAllComments,
                    onSort: onSort,
                  ),
                  Expanded(
                    child: (loading || searching) && comments.isEmpty
                        ? const _CommentsLoading()
                        : comments.isEmpty
                        ? const _CommentsEmpty()
                        : SingleChildScrollView(
                            child: Column(
                              children: [
                                for (final comment in comments)
                                  _CommentsRow(
                                    comment: comment,
                                    layout: layout,
                                    selected: selectedCommentIds.contains(
                                      comment.id,
                                    ),
                                    onToggle: () => onToggleComment(comment.id),
                                    onApproveComment: onApproveComment,
                                    onRejectComment: onRejectComment,
                                    onTogglePinned: onTogglePinned,
                                    onReplyComment: onReplyComment,
                                    onDeleteComment: onDeleteComment,
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

class _CommentsTableColumnLayout {
  const _CommentsTableColumnLayout({
    required this.selectWidth,
    required this.idWidth,
    required this.commentWidth,
    required this.postWidth,
    required this.statusWidth,
    required this.likesWidth,
    required this.repliesWidth,
    required this.createdWidth,
    required this.menuWidth,
  });

  final double selectWidth;
  final double idWidth;
  final double commentWidth;
  final double postWidth;
  final double statusWidth;
  final double likesWidth;
  final double repliesWidth;
  final double createdWidth;
  final double menuWidth;

  static double get _baseCommentWidth {
    return _CommentsDataTable._minWidth -
        _CommentsDataTable._selectWidth -
        _CommentsDataTable._idWidth -
        _CommentsDataTable._postWidth -
        _CommentsDataTable._statusWidth -
        _CommentsDataTable._likesWidth -
        _CommentsDataTable._repliesWidth -
        _CommentsDataTable._createdWidth -
        _CommentsDataTable._menuWidth -
        _CommentsDataTable._contentSpacing;
  }

  factory _CommentsTableColumnLayout.forWidth(double tableWidth) {
    final scale = AdminTableChrome.compactScale(
      tableWidth: tableWidth,
      preferredMinWidth: _CommentsDataTable._minWidth,
    );
    final extraWidth = (tableWidth - _CommentsDataTable._minWidth)
        .clamp(0.0, double.infinity)
        .toDouble();
    final selectWidth = AdminTableChrome.scaledColumn(
      _CommentsDataTable._selectWidth,
      scale,
      minWidth: 38,
    );
    final idWidth = AdminTableChrome.scaledColumn(
      _CommentsDataTable._idWidth,
      scale,
      minWidth: 48,
    );
    final postWidth = AdminTableChrome.scaledColumn(
      _CommentsDataTable._postWidth,
      scale,
      minWidth: 150,
    );
    final statusWidth = AdminTableChrome.scaledColumn(
      _CommentsDataTable._statusWidth,
      scale,
      minWidth: 84,
    );
    final likesWidth = AdminTableChrome.scaledColumn(
      _CommentsDataTable._likesWidth,
      scale,
      minWidth: 58,
    );
    final repliesWidth = AdminTableChrome.scaledColumn(
      _CommentsDataTable._repliesWidth,
      scale,
      minWidth: 58,
    );
    final createdWidth = AdminTableChrome.scaledColumn(
      _CommentsDataTable._createdWidth,
      scale,
      minWidth: 126,
    );
    final menuWidth = AdminTableChrome.scaledColumn(
      _CommentsDataTable._menuWidth,
      scale,
      minWidth: 54,
    );
    const contentSpacing = _CommentsDataTable._contentSpacing;
    final fixedWidth =
        selectWidth +
        idWidth +
        postWidth +
        statusWidth +
        likesWidth +
        repliesWidth +
        createdWidth +
        menuWidth +
        contentSpacing;

    final commentWidth = extraWidth > 0
        ? _baseCommentWidth + (extraWidth * 0.36)
        : (tableWidth - fixedWidth).clamp(128.0, double.infinity).toDouble();

    return _CommentsTableColumnLayout(
      selectWidth: selectWidth,
      idWidth: idWidth,
      commentWidth: commentWidth,
      postWidth: postWidth + (extraWidth * 0.10),
      statusWidth: statusWidth + (extraWidth * 0.08),
      likesWidth: likesWidth + (extraWidth * 0.08),
      repliesWidth: repliesWidth + (extraWidth * 0.08),
      createdWidth: createdWidth + (extraWidth * 0.30),
      menuWidth: menuWidth,
    );
  }
}

class _CommentsHeader extends StatelessWidget {
  const _CommentsHeader({
    required this.layout,
    required this.selectedCount,
    required this.totalCount,
    required this.sortState,
    required this.onToggleAllComments,
    required this.onSort,
  });

  final _CommentsTableColumnLayout layout;
  final int selectedCount;
  final int totalCount;
  final TableSortState sortState;
  final VoidCallback onToggleAllComments;
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
            child: _CommentCheckbox(
              value: selectedCount == 0 || totalCount == 0
                  ? false
                  : selectedCount == totalCount
                  ? true
                  : null,
              tristate: true,
              onChanged: (_) => onToggleAllComments(),
            ),
          ),
          _SortableColumnHeader(
            width: layout.idWidth,
            label: 'ID',
            sortKey: 'id',
            sortState: sortState,
            onSort: onSort,
          ),
          _SortableColumnHeader(
            width: layout.commentWidth,
            label: 'Comment',
            sortKey: 'comment',
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
            width: layout.statusWidth,
            label: 'Status',
            sortKey: 'status',
            sortState: sortState,
            onSort: onSort,
          ),
          _SortableColumnHeader(
            width: layout.likesWidth,
            label: 'Likes',
            sortKey: 'likes',
            sortState: sortState,
            onSort: onSort,
            centered: true,
          ),
          _SortableColumnHeader(
            width: layout.repliesWidth,
            label: 'Replies',
            sortKey: 'replies',
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
          SizedBox(width: layout.menuWidth, child: const _HeaderText('Action')),
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
    final header = SortableTableHeader(
      label: label,
      sortKey: sortKey,
      sortState: sortState,
      onSort: onSort,
    );

    return SizedBox(
      width: width,
      child: centered ? Center(child: IntrinsicWidth(child: header)) : header,
    );
  }
}

class _CommentsRow extends StatelessWidget {
  const _CommentsRow({
    required this.comment,
    required this.layout,
    required this.selected,
    required this.onToggle,
    required this.onApproveComment,
    required this.onRejectComment,
    required this.onTogglePinned,
    required this.onReplyComment,
    required this.onDeleteComment,
  });

  final AdminComment comment;
  final _CommentsTableColumnLayout layout;
  final bool selected;
  final VoidCallback onToggle;
  final ValueChanged<AdminComment> onApproveComment;
  final ValueChanged<AdminComment> onRejectComment;
  final ValueChanged<AdminComment> onTogglePinned;
  final ValueChanged<AdminComment> onReplyComment;
  final ValueChanged<AdminComment> onDeleteComment;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(
        minHeight: _CommentsDataTable._rowMinHeight,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: selected ? AppColors.surface : Colors.white,
        border: Border(
          bottom: BorderSide(color: AppColors.softLine.withValues(alpha: 0.86)),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: layout.selectWidth,
            child: _CommentCheckbox(
              value: selected,
              onChanged: (_) => onToggle(),
            ),
          ),
          SizedBox(
            width: layout.idWidth,
            child: _RowSelectTapTarget(
              onTap: onToggle,
              child: Text(
                comment.rowNumber.toString(),
                style: const TextStyle(
                  color: AppColors.deepOcean,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          SizedBox(
            width: layout.commentWidth,
            child: _RowSelectTapTarget(
              onTap: onToggle,
              child: _CommentIdentity(comment: comment),
            ),
          ),
          SizedBox(
            width: layout.postWidth,
            child: _PostCell(comment: comment),
          ),
          SizedBox(
            width: layout.statusWidth,
            child: _StatusBadge(comment: comment),
          ),
          SizedBox(
            width: layout.likesWidth,
            child: _NumberCell(value: comment.likesCount),
          ),
          SizedBox(
            width: layout.repliesWidth,
            child: _NumberCell(value: comment.repliesCount),
          ),
          SizedBox(
            width: layout.createdWidth,
            child: _DateCell(dateTime: comment.createdAt),
          ),
          SizedBox(
            width: layout.menuWidth,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _CommentRowMenu(
                comment: comment,
                onApproveComment: onApproveComment,
                onRejectComment: onRejectComment,
                onTogglePinned: onTogglePinned,
                onReplyComment: onReplyComment,
                onDeleteComment: onDeleteComment,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentCheckbox extends StatelessWidget {
  const _CommentCheckbox({
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
  const _HeaderText(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      context.t(label),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: AppColors.inkSoft,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _CommentIdentity extends StatelessWidget {
  const _CommentIdentity({required this.comment});

  final AdminComment comment;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _CommentAvatar(comment: comment),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (comment.isPinned) ...[
                    Tooltip(
                      message: context.t('Pinned'),
                      child: const SymbolIcon(
                        Symbols.verified,
                        color: AppColors.warmHorizon,
                        size: 15,
                      ),
                    ),
                    const SizedBox(width: 5),
                  ],
                  Expanded(
                    child: HighlightedText(
                      comment.content,
                      query: _CommentsSearchScope.of(context),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.deepOcean,
                        fontSize: 15,
                        height: 1.18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _CommentAuthorDetails(
                      comment: comment,
                      compact: false,
                    ),
                  ),
                  if (comment.hasReports) ...[
                    const SizedBox(width: 8),
                    _ReportBadge(count: comment.reportsCount),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CommentAuthorDetails extends StatefulWidget {
  const _CommentAuthorDetails({required this.comment, required this.compact});

  final AdminComment comment;
  final bool compact;

  @override
  State<_CommentAuthorDetails> createState() => _CommentAuthorDetailsState();
}

class _CommentAuthorDetailsState extends State<_CommentAuthorDetails> {
  var _hovering = false;

  @override
  Widget build(BuildContext context) {
    final comment = widget.comment;
    final isProfile = comment.isRegisteredUser;
    final profileSlug = comment.profileSlug;
    final linkable = isProfile && profileSlug.isNotEmpty;
    final name = isProfile
        ? comment.profileDisplayName
        : context.t(comment.displayUser);
    final email = isProfile ? comment.profileEmail : '';
    final handle = isProfile ? comment.profileHandle : '';
    final compact = widget.compact;
    final nameStyle = TextStyle(
      color: linkable && _hovering ? AppColors.actionRed : AppColors.deepOcean,
      fontSize: compact ? 11.5 : 11.2,
      fontWeight: FontWeight.w600,
      decoration: linkable && _hovering ? TextDecoration.underline : null,
      decorationColor: AppColors.actionRed,
      letterSpacing: 0,
      height: 1.16,
    );
    final secondaryStyle = TextStyle(
      color: AppColors.support.withValues(alpha: 0.94),
      fontSize: compact ? 10.1 : 9.8,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
      height: 1.18,
    );
    final handleStyle = TextStyle(
      color: linkable && _hovering ? AppColors.actionRed : AppColors.support,
      fontSize: compact ? 10.2 : 9.9,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      height: 1.18,
    );

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HighlightedText(
          name.isEmpty ? context.t('Anonymous User') : name,
          query: _CommentsSearchScope.of(context),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: nameStyle,
        ),
        if (email.isNotEmpty) ...[
          SizedBox(height: compact ? 2 : 2),
          HighlightedText(
            email,
            query: _CommentsSearchScope.of(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: secondaryStyle,
          ),
        ],
        if (handle.isNotEmpty) ...[
          SizedBox(height: compact ? 2 : 2),
          HighlightedText(
            handle,
            query: _CommentsSearchScope.of(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: handleStyle,
          ),
        ],
      ],
    );

    if (!linkable) return content;

    return Tooltip(
      message: context.t('comments.openProfile'),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => unawaited(_openExternalUrl(_profileUrl(comment))),
          child: content,
        ),
      ),
    );
  }
}

class _CommentAvatar extends StatelessWidget {
  const _CommentAvatar({required this.comment});

  final AdminComment comment;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = comment.userAvatar.trim();

    return Container(
      width: 38,
      height: 38,
      foregroundDecoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.support),
      ),
      child: ClipOval(
        child: ColoredBox(
          color: AppColors.softLine,
          child: avatarUrl.isEmpty
              ? Center(child: _CommentAvatarFallback(comment: comment))
              : AdminCachedImage(
                  url: adminImageUrl(avatarUrl, width: 96),
                  width: 38,
                  height: 38,
                  fit: BoxFit.cover,
                  memCacheWidth: 96,
                  errorWidget: Center(
                    child: _CommentAvatarFallback(comment: comment),
                  ),
                ),
        ),
      ),
    );
  }
}

class _CommentAvatarFallback extends StatelessWidget {
  const _CommentAvatarFallback({required this.comment});

  final AdminComment comment;

  @override
  Widget build(BuildContext context) {
    return Text(
      comment.initials,
      maxLines: 1,
      overflow: TextOverflow.clip,
      style: const TextStyle(
        color: AppColors.deepOcean,
        fontSize: 11.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
    );
  }
}

class _ReportBadge extends StatelessWidget {
  const _ReportBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: AppColors.actionRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.actionRed.withValues(alpha: 0.18)),
      ),
      alignment: Alignment.center,
      child: Text(
        context.t('comments.reportCount', values: {'count': count}),
        style: const TextStyle(
          color: AppColors.actionRed,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PostCell extends StatefulWidget {
  const _PostCell({required this.comment});

  final AdminComment comment;

  @override
  State<_PostCell> createState() => _PostCellState();
}

class _PostCellState extends State<_PostCell> {
  var _hovering = false;

  @override
  Widget build(BuildContext context) {
    final hasPost = widget.comment.postId.trim().isNotEmpty;
    final title = context.t(widget.comment.displayPost);

    return MouseRegion(
      cursor: hasPost ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: hasPost ? (_) => setState(() => _hovering = true) : null,
      onExit: hasPost ? (_) => setState(() => _hovering = false) : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: hasPost
            ? () => unawaited(_openExternalUrl(_postUrl(widget.comment)))
            : null,
        child: HighlightedText(
          title,
          query: _CommentsSearchScope.of(context),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: hasPost && _hovering
                ? AppColors.actionRed
                : AppColors.deepOcean,
            fontWeight: FontWeight.w500,
            fontSize: 12.5,
            height: 1.25,
            decoration: hasPost && _hovering ? TextDecoration.underline : null,
            decorationColor: AppColors.actionRed,
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.comment});

  final AdminComment comment;

  @override
  Widget build(BuildContext context) {
    final label = switch (comment.status) {
      'approved' => 'Approved',
      'rejected' => 'Rejected',
      _ => 'Pending',
    };
    final color = switch (comment.status) {
      'approved' => const Color(0xFF198754),
      'rejected' => AppColors.actionRed,
      _ => AppColors.warmHorizon,
    };

    return Align(
      alignment: Alignment.centerLeft,
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
          fontWeight: FontWeight.w600,
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
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          formatAdminTime(dateTime),
          style: const TextStyle(
            color: AppColors.support,
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _CommentRowMenu extends StatefulWidget {
  const _CommentRowMenu({
    required this.comment,
    required this.onApproveComment,
    required this.onRejectComment,
    required this.onTogglePinned,
    required this.onReplyComment,
    required this.onDeleteComment,
  });

  final AdminComment comment;
  final ValueChanged<AdminComment> onApproveComment;
  final ValueChanged<AdminComment> onRejectComment;
  final ValueChanged<AdminComment> onTogglePinned;
  final ValueChanged<AdminComment> onReplyComment;
  final ValueChanged<AdminComment> onDeleteComment;

  @override
  State<_CommentRowMenu> createState() => _CommentRowMenuState();
}

class _CommentRowMenuState extends State<_CommentRowMenu> {
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
              child: _CommentMenuCard(
                comment: widget.comment,
                onApprove: () =>
                    _runAndClose(() => widget.onApproveComment(widget.comment)),
                onReject: () =>
                    _runAndClose(() => widget.onRejectComment(widget.comment)),
                onTogglePinned: () =>
                    _runAndClose(() => widget.onTogglePinned(widget.comment)),
                onReply: () =>
                    _runAndClose(() => widget.onReplyComment(widget.comment)),
                onDelete: () =>
                    _runAndClose(() => widget.onDeleteComment(widget.comment)),
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
        message: context.t('Comment actions'),
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

class _CommentMenuCard extends StatelessWidget {
  const _CommentMenuCard({
    required this.comment,
    required this.onApprove,
    required this.onReject,
    required this.onTogglePinned,
    required this.onReply,
    required this.onDelete,
  });

  final AdminComment comment;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onTogglePinned;
  final VoidCallback onReply;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 212,
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
            _CommentMenuItem(
              icon: Symbols.check,
              label: 'Approve',
              onTap: onApprove,
            ),
            _CommentMenuItem(
              icon: Symbols.close,
              label: 'Reject',
              onTap: onReject,
            ),
            _CommentMenuItem(
              icon: comment.isPinned
                  ? Symbols.visibility_off
                  : Symbols.verified,
              label: comment.isPinned ? 'Unpin' : 'Pin',
              onTap: onTogglePinned,
            ),
            _CommentMenuItem(
              icon: Symbols.short_text,
              label: 'Reply',
              onTap: onReply,
            ),
            _CommentMenuItem(
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

class _CommentMenuItem extends StatelessWidget {
  const _CommentMenuItem({
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

class _CommentsLoading extends StatelessWidget {
  const _CommentsLoading();

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

class _CommentsEmpty extends StatelessWidget {
  const _CommentsEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        context.t('No comments found'),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.inkSoft,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _CommentsFooter extends StatelessWidget {
  const _CommentsFooter({
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
        final pager = _CommentsPagination(
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

class _CommentsPagination extends StatelessWidget {
  const _CommentsPagination({
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

String _postUrl(AdminComment comment) {
  return _siteBaseUri()
      .resolve('/haber/${Uri.encodeComponent(comment.postId)}')
      .toString();
}

String _profileUrl(AdminComment comment) {
  final slug = comment.profileSlug;
  if (slug.isEmpty) return '';
  return _siteBaseUri()
      .resolve('/profil/${Uri.encodeComponent(slug)}')
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

Future<void> _openExternalUrl(String url) async {
  await openCommentLink(url);
}
