import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/localization/admin_language_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/widgets/app_confirmation_dialog.dart';
import '../../../shared/widgets/sortable_table_header.dart';
import '../data/admin_news_repository.dart';
import 'news_models.dart';
import 'widgets/news_link_opener.dart';
import 'widgets/news_table_card.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({
    super.key,
    this.repository = const SupabaseAdminNewsRepository(),
    this.onAddPost,
    this.onEditPost,
  });

  final AdminNewsRepository repository;
  final VoidCallback? onAddPost;
  final ValueChanged<String>? onEditPost;

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  static const _all = 'Tümü';

  final Set<String> _selectedPostIds = {};
  Timer? _searchDebounce;
  Timer? _refreshTimer;

  var _posts = const <AdminNewsPost>[];
  var _filterOptions = const AdminNewsFilterOptions(
    languages: [],
    categories: [],
    types: [],
    publishers: [],
  );
  var _loading = true;
  String? _errorText;
  var _page = 1;
  var _pageSize = 25;
  var _totalCount = 0;
  var _searchQuery = '';
  var _languageFilter = _all;
  var _categoryFilter = _all;
  var _typeFilter = _all;
  var _statusFilter = _all;
  var _publisherFilter = _all;
  var _sortState = const TableSortState(key: 'date', ascending: false);

  @override
  void initState() {
    super.initState();
    unawaited(_loadAll());
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      unawaited(_loadPosts());
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _errorText = null;
    });

    try {
      final filtersFuture = widget.repository.fetchFilterOptions();
      final postsFuture = _fetchPosts();
      final filterOptions = await filtersFuture;
      final posts = await postsFuture;
      if (!mounted) return;
      setState(() {
        _filterOptions = filterOptions;
        _posts = posts.posts;
        _totalCount = posts.totalCount;
        _selectedPostIds.removeWhere(
          (id) => !_posts.any((post) => post.id == id),
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

  Future<void> _loadPosts() async {
    setState(() {
      _loading = true;
      _errorText = null;
    });

    try {
      final result = await _fetchPosts();
      if (!mounted) return;
      setState(() {
        _posts = result.posts;
        _totalCount = result.totalCount;
        _selectedPostIds.removeWhere(
          (id) => !_posts.any((post) => post.id == id),
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

  Future<AdminNewsPageResult> _fetchPosts() {
    return widget.repository.fetchPosts(
      search: _searchQuery,
      language: _languageFilter,
      category: _categoryFilter,
      type: _typeFilter,
      status: _statusFilter,
      publisher: _publisherFilter,
      page: _page,
      pageSize: _pageSize,
      sortKey: _sortState.key,
      sortAscending: _sortState.ascending,
    );
  }

  void _togglePost(String postId) {
    setState(() {
      if (_selectedPostIds.contains(postId)) {
        _selectedPostIds.remove(postId);
      } else {
        _selectedPostIds.add(postId);
      }
    });
  }

  void _toggleAllPosts() {
    setState(() {
      if (_posts.isNotEmpty && _selectedPostIds.length == _posts.length) {
        _selectedPostIds.clear();
      } else {
        _selectedPostIds
          ..clear()
          ..addAll(_posts.map((post) => post.id));
      }
    });
  }

  void _changePageSize(int? value) {
    if (value == null || value == _pageSize) return;
    setState(() {
      _pageSize = value;
      _page = 1;
      _selectedPostIds.clear();
    });
    unawaited(_loadPosts());
  }

  void _changeSearch(String value) {
    setState(() => _searchQuery = value);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _page = 1;
        _selectedPostIds.clear();
      });
      unawaited(_loadPosts());
    });
  }

  void _changeFilter({
    String? language,
    String? category,
    String? type,
    String? status,
    String? publisher,
  }) {
    setState(() {
      if (language != null) _languageFilter = language;
      if (category != null) _categoryFilter = category;
      if (type != null) _typeFilter = type;
      if (status != null) _statusFilter = status;
      if (publisher != null) _publisherFilter = publisher;
      _page = 1;
      _selectedPostIds.clear();
    });
    unawaited(_loadPosts());
  }

  void _changePage(int page) {
    if (page == _page) return;
    setState(() {
      _page = page;
      _selectedPostIds.clear();
    });
    unawaited(_loadPosts());
  }

  void _changeSort(String sortKey) {
    setState(() {
      _sortState = _sortState.toggled(sortKey);
      _page = 1;
      _selectedPostIds.clear();
    });
    unawaited(_loadPosts());
  }

  Future<void> _toggleStatus(AdminNewsPost post) async {
    await _runMutation(() => widget.repository.toggleStatus(post));
  }

  Future<void> _togglePinned(AdminNewsPost post) async {
    await _runMutation(() => widget.repository.togglePinned(post));
  }

  Future<void> _deletePost(AdminNewsPost post) async {
    final confirmed = await showAppConfirmationDialog(
      context,
      title: context.t('Delete post?'),
      message: context.t(
        'news.deleteMessage',
        values: {'title': post.displayTitle},
      ),
      confirmLabel: context.t('Delete'),
      danger: true,
    );
    if (!confirmed) return;
    await _runMutation(() => widget.repository.deletePost(post.id));
  }

  Future<void> _deleteSelected() async {
    final ids = _selectedPostIds.toList(growable: false);
    if (ids.isEmpty) return;
    final confirmed = await showAppConfirmationDialog(
      context,
      title: context.t('Delete selected posts?'),
      message: context.t(
        'news.deleteSelectedMessage',
        values: {'count': ids.length},
      ),
      confirmLabel: context.t('Delete'),
      danger: true,
    );
    if (!confirmed) return;
    await _runMutation(() => widget.repository.deletePosts(ids));
  }

  Future<void> _runMutation(Future<void> Function() action) async {
    setState(() {
      _loading = true;
      _errorText = null;
    });
    try {
      await action();
      if (!mounted) return;
      _selectedPostIds.clear();
      await _loadAll();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = error.toString();
        _loading = false;
      });
    }
  }

  void _openPostEditor([String? postId]) {
    if (postId == null) {
      final callback = widget.onAddPost;
      if (callback != null) {
        callback();
        return;
      }
    } else {
      final callback = widget.onEditPost;
      if (callback != null) {
        callback(postId);
        return;
      }
    }
    final path = postId == null
        ? '/admin/posts'
        : '/admin/haberler/${Uri.encodeComponent(postId)}';
    unawaited(openNewsLink(_siteBaseUri().resolve(path).toString()));
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
            const _NewsTitle(),
            if (_errorText != null) ...[
              const SizedBox(height: 22),
              _NewsErrorBanner(message: _errorText!),
            ],
            SizedBox(height: mobile ? 12 : 24),
            Expanded(
              child: NewsTableCard(
                posts: _posts,
                filterOptions: _filterOptions,
                loading: _loading,
                page: _page,
                pageSize: _pageSize,
                totalCount: _totalCount,
                searchQuery: _searchQuery,
                languageFilter: _languageFilter,
                categoryFilter: _categoryFilter,
                typeFilter: _typeFilter,
                statusFilter: _statusFilter,
                publisherFilter: _publisherFilter,
                selectedPostIds: _selectedPostIds,
                sortState: _sortState,
                onPageSizeChanged: _changePageSize,
                onSearchChanged: _changeSearch,
                onLanguageChanged: (value) => _changeFilter(language: value),
                onCategoryChanged: (value) => _changeFilter(category: value),
                onTypeChanged: (value) => _changeFilter(type: value),
                onStatusChanged: (value) => _changeFilter(status: value),
                onPublisherChanged: (value) => _changeFilter(publisher: value),
                onPageChanged: _changePage,
                onTogglePost: _togglePost,
                onToggleAllPosts: _toggleAllPosts,
                onSort: _changeSort,
                onAddPost: () => _openPostEditor(),
                onEditPost: (post) => _openPostEditor(post.id),
                onToggleStatus: (post) => unawaited(_toggleStatus(post)),
                onTogglePinned: (post) => unawaited(_togglePinned(post)),
                onDeletePost: (post) => unawaited(_deletePost(post)),
                onDeleteSelected: () => unawaited(_deleteSelected()),
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

class _NewsTitle extends StatelessWidget {
  const _NewsTitle();

  @override
  Widget build(BuildContext context) {
    return Text(
      context.t('News'),
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
        color: AppColors.deepOcean,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
    );
  }
}

class _NewsErrorBanner extends StatelessWidget {
  const _NewsErrorBanner({required this.message});

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

Uri _siteBaseUri() {
  if (!kIsWeb) {
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => Uri.parse('http://10.0.2.2:4321'),
      _ => Uri.parse('http://localhost:4321'),
    };
  }
  return Uri.base;
}
