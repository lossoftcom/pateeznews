import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/localization/admin_language_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/widgets/app_confirmation_dialog.dart';
import '../../../shared/data/admin_memory_cache.dart';
import '../../../shared/widgets/admin_toast.dart';
import '../../../shared/widgets/highlighted_text.dart';
import '../../../shared/widgets/sortable_table_header.dart';
import '../data/admin_news_repository.dart';
import 'news_models.dart';
import 'widgets/news_link_opener.dart';
import 'widgets/news_table_card.dart';

/// Oturum-içi kısa ömürlü cache'ler: News ekranına her dönüşte son veri anında
/// gösterilir, ardından arka planda sessizce tazelenir (stale-while-revalidate).
/// Üst düzeyde tutulur ki ekran kapanıp açılınca (geçişlerde) korunsun.
final AdminMemoryCache<AdminNewsFilterOptions> _newsFilterCache =
    AdminMemoryCache<AdminNewsFilterOptions>(ttl: const Duration(seconds: 60));
final AdminMemoryCache<AdminNewsPageResult> _newsPageCache =
    AdminMemoryCache<AdminNewsPageResult>(ttl: const Duration(seconds: 30));

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
  var _loadingMessageKey = 'news.loading.listing';
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
  var _trashMode = false;
  var _videoOnly = false;
  var _searching = false;
  var _searchSeq = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_loadAll());
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      unawaited(_refreshPostsSilently());
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  String _postsCacheKey() =>
      '${_trashMode ? 1 : 0}|${_videoOnly ? 1 : 0}|$_searchQuery|$_languageFilter|$_categoryFilter|'
      '$_typeFilter|$_statusFilter|$_publisherFilter|$_page|$_pageSize|'
      '${_sortState.key}|${_sortState.ascending}';

  Future<void> _loadAll({
    bool preferCache = true,
    String loadingMessageKey = 'news.loading.listing',
  }) async {
    // Cache-öncelik: son veri varsa anında göster, sonra sessizce tazele.
    final cachedFilters = _newsFilterCache.get('filters');
    final cachedPage = _newsPageCache.get(_postsCacheKey());
    if (preferCache && cachedFilters != null && cachedPage != null) {
      setState(() {
        _filterOptions = cachedFilters;
        _posts = cachedPage.posts;
        _totalCount = cachedPage.totalCount;
        _selectedPostIds.removeWhere(
          (id) => !_posts.any((post) => post.id == id),
        );
        _loading = false;
        _errorText = null;
      });
      unawaited(_refreshPostsSilently());
      return;
    }

    setState(() {
      _loadingMessageKey = loadingMessageKey;
      _loading = true;
      _errorText = null;
    });

    try {
      final filtersFuture = widget.repository.fetchFilterOptions();
      final postsFuture = _fetchPosts();
      final filterOptions = await filtersFuture;
      final posts = await postsFuture;
      if (!mounted) return;
      _newsFilterCache.set('filters', filterOptions);
      _newsPageCache.set(_postsCacheKey(), posts);
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

  Future<void> _loadPosts({
    bool preferCache = true,
    String loadingMessageKey = 'news.loading.listing',
  }) async {
    final cachedPage = _newsPageCache.get(_postsCacheKey());
    if (preferCache && cachedPage != null) {
      setState(() {
        _posts = cachedPage.posts;
        _totalCount = cachedPage.totalCount;
        _selectedPostIds.removeWhere(
          (id) => !_posts.any((post) => post.id == id),
        );
        _loading = false;
        _errorText = null;
      });
      unawaited(_refreshPostsSilently());
      return;
    }

    setState(() {
      _loadingMessageKey = loadingMessageKey;
      _loading = true;
      _errorText = null;
    });

    try {
      final result = await _fetchPosts();
      if (!mounted) return;
      _newsPageCache.set(_postsCacheKey(), result);
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

  /// Arka plan (periyodik) yenileme: listeyi spinner'a düşürmeden, sessizce
  /// günceller. Hata olursa mevcut liste korunur — kullanıcı kesintiye uğramaz.
  ///
  /// [isSearch] true olduğunda (kullanıcı yazarken) "Aranıyor…" göstergesi için
  /// bayrak set edilir; sıra (seq) koruması ile yalnızca en güncel yanıt uygulanır.
  Future<void> _refreshPostsSilently({bool isSearch = false}) async {
    final seq = ++_searchSeq;
    if (isSearch && mounted && !_searching) {
      setState(() => _searching = true);
    }
    try {
      final result = await _fetchPosts();
      if (!mounted || seq != _searchSeq) return;
      _newsPageCache.set(_postsCacheKey(), result);
      setState(() {
        _posts = result.posts;
        _totalCount = result.totalCount;
        _selectedPostIds.removeWhere(
          (id) => !_posts.any((post) => post.id == id),
        );
        _errorText = null;
        _searching = false;
      });
    } catch (_) {
      // Sessiz yenileme; mevcut veri ekranda kalır.
      if (mounted && seq == _searchSeq && _searching) {
        setState(() => _searching = false);
      }
    }
  }

  /// Anlık (0ms) istemci filtresi: yüklü satırlar arasında, sunucuyla aynı
  /// Türkçe normalizasyonla eşleşenleri hemen gösterir (ışık hızında his).
  /// Sunucu yanıtı gelince [_posts] otoriter sonuçla tazelenir.
  List<AdminNewsPost> _visiblePosts() {
    final query = _searchQuery.trim();
    if (query.isEmpty) return _posts;
    return _posts
        .where((post) => searchMatchesAll(_postHaystack(post), query))
        .toList(growable: false);
  }

  String _postHaystack(AdminNewsPost post) {
    return [
      post.id,
      post.title,
      post.category,
      post.parentCategory ?? '',
      ...post.categoryPath,
      post.type,
      post.status,
      post.languageCode,
      post.publisherName,
      post.publisherUsername,
      post.publisherEmail,
      for (final video in post.videos) video.title,
    ].join(' ');
  }

  Future<AdminNewsPageResult> _fetchPosts() {
    // Video modunda TÜM videolu haberleri tek seferde çekeriz (sayfalama yok);
    // arama istemci tarafında Video Kütüphanesi'nde yapılır (video başlığına da
    // bakar), o yüzden sunucuya arama gönderilmez.
    final videoMode = _videoOnly;
    return widget.repository.fetchPosts(
      search: videoMode ? '' : _searchQuery,
      language: _languageFilter,
      category: _categoryFilter,
      type: _typeFilter,
      status: _statusFilter,
      publisher: _publisherFilter,
      trash: _trashMode,
      videoOnly: _videoOnly,
      page: videoMode ? 1 : _page,
      pageSize: videoMode ? 500 : _pageSize,
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
    // Anlık his: yazar yazmaz görünür satırlar istemci tarafında filtrelenir
    // (_visiblePosts) ve highlight uygulanır — sunucu yanıtı beklenmez.
    setState(() {
      _searchQuery = value;
      _page = 1;
      _selectedPostIds.clear();
    });
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      // Spinner'sız (sessiz) sunucu sorgusu: içerik/SEO/diğer sayfalardaki
      // eşleşmeleri de getirip listeyi otoriter sonuçla tamamlar.
      unawaited(_refreshPostsSilently(isSearch: true));
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

  void _toggleTrashMode() {
    setState(() {
      _trashMode = !_trashMode;
      _page = 1;
      _statusFilter = _all;
      _selectedPostIds.clear();
    });
    unawaited(_loadPosts());
  }

  void _toggleVideoOnly() {
    setState(() {
      _videoOnly = !_videoOnly;
      _page = 1;
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
    final permanently = _trashMode;
    final confirmed = await showAppConfirmationDialog(
      context,
      title: context.t(
        permanently ? 'news.deletePermanentTitle' : 'Delete post?',
      ),
      message: context.t(
        permanently ? 'news.deletePermanentMessage' : 'news.deleteMessage',
        values: {'title': post.displayTitle},
      ),
      confirmLabel: context.t(
        permanently ? 'news.deletePermanently' : 'news.moveToTrash',
      ),
      danger: true,
    );
    if (!confirmed) return;
    await _runMutation(
      () => permanently
          ? widget.repository.deletePosts([post.id], permanently: true)
          : widget.repository.deletePost(post.id),
      loadingMessageKey: 'news.loading.deleting',
      successMessageKey: permanently
          ? 'news.toast.deletedSelected'
          : 'news.toast.movedSelectedToTrash',
      successValues: const {'count': 1},
    );
  }

  Future<void> _deleteSelected() async {
    final ids = _selectedPostIds.toList(growable: false);
    if (ids.isEmpty) return;
    final permanently = _trashMode;
    final confirmed = await showAppConfirmationDialog(
      context,
      title: context.t(
        permanently
            ? 'news.deleteSelectedPermanentTitle'
            : 'Delete selected posts?',
      ),
      message: context.t(
        permanently
            ? 'news.deleteSelectedPermanentMessage'
            : 'news.deleteSelectedMessage',
        values: {'count': ids.length},
      ),
      confirmLabel: context.t(
        permanently ? 'news.deletePermanently' : 'news.moveToTrash',
      ),
      danger: true,
    );
    if (!confirmed) return;
    await _runMutation(
      () => widget.repository.deletePosts(ids, permanently: permanently),
      loadingMessageKey: 'news.loading.deleting',
      successMessageKey: permanently
          ? 'news.toast.deletedSelected'
          : 'news.toast.movedSelectedToTrash',
      successValues: {'count': ids.length},
    );
  }

  Future<void> _runMutation(
    Future<void> Function() action, {
    String loadingMessageKey = 'news.loading.processing',
    String? successMessageKey,
    Map<String, Object?> successValues = const {},
  }) async {
    setState(() {
      _loadingMessageKey = loadingMessageKey;
      _loading = true;
      _errorText = null;
    });
    try {
      await action();
      if (!mounted) return;
      _selectedPostIds.clear();
      _newsPageCache.clear();
      await _loadAll(preferCache: false, loadingMessageKey: loadingMessageKey);
      if (!mounted) return;
      if (successMessageKey != null) {
        AdminToast.show(
          context,
          message: context.t(successMessageKey, values: successValues),
          tone: AdminToastTone.success,
        );
      }
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
                posts: _videoOnly ? _posts : _visiblePosts(),
                filterOptions: _filterOptions,
                loading: _loading,
                loadingLabel: context.t(_loadingMessageKey),
                searching: _searching && _searchQuery.trim().isNotEmpty,
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
                trashMode: _trashMode,
                videoOnly: _videoOnly,
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
                onToggleTrashMode: _toggleTrashMode,
                onToggleVideoOnly: _toggleVideoOnly,
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
              0,
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
      TargetPlatform.android => Uri.parse('https://pateez.com'),
      _ => Uri.parse('https://pateez.com'),
    };
  }
  return Uri.base;
}
