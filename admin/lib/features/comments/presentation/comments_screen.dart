import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../core/localization/admin_language_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/data/admin_memory_cache.dart';
import '../../../shared/widgets/admin_mobile_list.dart';
import '../../../shared/widgets/highlighted_text.dart';
import '../../../shared/widgets/app_confirmation_dialog.dart';
import '../../../shared/widgets/sortable_table_header.dart';
import '../../auth/data/admin_auth_models.dart';
import '../../users/presentation/users_models.dart';
import '../../users/presentation/widgets/users_summary_grid.dart';
import '../data/admin_comments_repository.dart';
import 'comments_models.dart';
import 'widgets/comments_table_card.dart';

/// Oturum-içi kısa ömürlü cache'ler: Comments ekranına her dönüşte son veri
/// anında gösterilir, ardından arka planda sessizce tazelenir.
final AdminMemoryCache<AdminCommentMetricData> _commentsMetricsCache =
    AdminMemoryCache<AdminCommentMetricData>(ttl: const Duration(seconds: 30));
final AdminMemoryCache<AdminCommentFilterOptions> _commentsFilterCache =
    AdminMemoryCache<AdminCommentFilterOptions>(
      ttl: const Duration(seconds: 60),
    );
final AdminMemoryCache<AdminCommentsPageResult> _commentsPageCache =
    AdminMemoryCache<AdminCommentsPageResult>(ttl: const Duration(seconds: 30));

class CommentsScreen extends StatefulWidget {
  const CommentsScreen({
    super.key,
    required this.session,
    this.repository = const SupabaseAdminCommentsRepository(),
  });

  final AdminSession session;
  final AdminCommentsRepository repository;

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  static const _all = 'Tümü';

  final Set<String> _selectedCommentIds = {};
  Timer? _searchDebounce;

  var _comments = const <AdminComment>[];
  var _filterOptions = const AdminCommentFilterOptions(posts: [], users: []);
  var _metrics = const AdminCommentMetricData(
    total: 0,
    approved: 0,
    pending: 0,
    rejected: 0,
    totalChange: '+0%',
    approvedChange: '+0%',
    pendingChange: '+0%',
    rejectedChange: '+0%',
  );
  var _loading = true;
  String? _errorText;
  var _page = 1;
  var _pageSize = 25;
  var _totalCount = 0;
  var _searchQuery = '';
  var _statusFilter = _all;
  var _postFilter = _all;
  var _userFilter = _all;
  var _sortState = const TableSortState(key: 'date', ascending: false);
  var _searching = false;
  var _searchSeq = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_loadAll());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  String _commentsPageKey() =>
      '$_searchQuery|$_statusFilter|$_postFilter|$_userFilter|$_page|'
      '$_pageSize|${_sortState.key}|${_sortState.ascending}';

  Future<void> _loadAll() async {
    // Cache-öncelik: son veri varsa anında göster, sonra sessizce tazele.
    final cachedMetrics = _commentsMetricsCache.get('metrics');
    final cachedFilters = _commentsFilterCache.get('filters');
    final cachedComments = _commentsPageCache.get(_commentsPageKey());
    if (cachedMetrics != null &&
        cachedFilters != null &&
        cachedComments != null) {
      setState(() {
        _metrics = cachedMetrics;
        _filterOptions = cachedFilters;
        _comments = cachedComments.comments;
        _totalCount = cachedComments.totalCount;
        _selectedCommentIds.removeWhere(
          (id) => !_comments.any((comment) => comment.id == id),
        );
        _loading = false;
        _errorText = null;
      });
      unawaited(_refreshCommentsSilently());
      return;
    }

    setState(() {
      _loading = true;
      _errorText = null;
    });

    try {
      final metricsFuture = widget.repository.fetchMetrics();
      final filtersFuture = widget.repository.fetchFilterOptions();
      final commentsFuture = _fetchComments();
      final metrics = await metricsFuture;
      final filterOptions = await filtersFuture;
      final comments = await commentsFuture;
      if (!mounted) return;
      _commentsMetricsCache.set('metrics', metrics);
      _commentsFilterCache.set('filters', filterOptions);
      _commentsPageCache.set(_commentsPageKey(), comments);
      setState(() {
        _metrics = metrics;
        _filterOptions = filterOptions;
        _comments = comments.comments;
        _totalCount = comments.totalCount;
        _selectedCommentIds.removeWhere(
          (id) => !_comments.any((comment) => comment.id == id),
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

  /// Arka plan yenileme: listeyi spinner'a düşürmeden sessizce günceller.
  ///
  /// [isSearch] true olduğunda (kullanıcı yazarken) "Aranıyor…" göstergesi için
  /// bayrak set edilir; sıra (seq) koruması ile yalnızca en güncel yanıt uygulanır.
  Future<void> _refreshCommentsSilently({bool isSearch = false}) async {
    final seq = ++_searchSeq;
    if (isSearch && mounted && !_searching) {
      setState(() => _searching = true);
    }
    try {
      final result = await _fetchComments();
      if (!mounted || seq != _searchSeq) return;
      _commentsPageCache.set(_commentsPageKey(), result);
      setState(() {
        _comments = result.comments;
        _totalCount = result.totalCount;
        _selectedCommentIds.removeWhere(
          (id) => !_comments.any((comment) => comment.id == id),
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

  /// Anlık (0ms) istemci filtresi — Haberler ile aynı: yüklü yorumlar arasında
  /// sunucuyla aynı Türkçe normalizasyonla eşleşenleri hemen gösterir.
  /// Sunucu yanıtı gelince [_comments] otoriter sonuçla tazelenir.
  List<AdminComment> _visibleComments() {
    final query = _searchQuery.trim();
    if (query.isEmpty) return _comments;
    return _comments
        .where((comment) => searchMatchesAll(_commentHaystack(comment), query))
        .toList(growable: false);
  }

  String _commentHaystack(AdminComment comment) {
    return [
      comment.id,
      comment.content,
      comment.displayUser,
      comment.userName,
      comment.guestName,
      comment.guestEmail,
      comment.postTitle,
      comment.status,
    ].join(' ');
  }

  Future<void> _loadComments() async {
    setState(() {
      _loading = true;
      _errorText = null;
    });

    try {
      final result = await _fetchComments();
      if (!mounted) return;
      _commentsPageCache.set(_commentsPageKey(), result);
      setState(() {
        _comments = result.comments;
        _totalCount = result.totalCount;
        _selectedCommentIds.removeWhere(
          (id) => !_comments.any((comment) => comment.id == id),
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

  Future<AdminCommentsPageResult> _fetchComments() {
    return widget.repository.fetchComments(
      search: _searchQuery,
      status: _statusFilter,
      postId: _postFilter,
      userId: _userFilter,
      page: _page,
      pageSize: _pageSize,
      sortKey: _sortState.key,
      sortAscending: _sortState.ascending,
    );
  }

  void _toggleComment(String commentId) {
    setState(() {
      if (_selectedCommentIds.contains(commentId)) {
        _selectedCommentIds.remove(commentId);
      } else {
        _selectedCommentIds.add(commentId);
      }
    });
  }

  void _toggleAllComments() {
    setState(() {
      if (_comments.isNotEmpty &&
          _selectedCommentIds.length == _comments.length) {
        _selectedCommentIds.clear();
      } else {
        _selectedCommentIds
          ..clear()
          ..addAll(_comments.map((comment) => comment.id));
      }
    });
  }

  void _changePageSize(int? value) {
    if (value == null || value == _pageSize) return;
    setState(() {
      _pageSize = value;
      _page = 1;
      _selectedCommentIds.clear();
    });
    unawaited(_loadComments());
  }

  void _changeSearch(String value) {
    // Anlık his: yazar yazmaz görünür yorumlar istemci tarafında filtrelenir
    // (_visibleComments) ve highlight uygulanır — sunucu yanıtı beklenmez.
    setState(() {
      _searchQuery = value;
      _page = 1;
      _selectedCommentIds.clear();
    });
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      // Spinner'sız (sessiz) sunucu sorgusu otoriter sonuçla tamamlar.
      unawaited(_refreshCommentsSilently(isSearch: true));
    });
  }

  void _changeStatus(String? value) => _changeFilter(status: value);

  void _changePost(String? value) => _changeFilter(post: value);

  void _changeUser(String? value) => _changeFilter(user: value);

  void _changeFilter({String? status, String? post, String? user}) {
    setState(() {
      if (status != null) _statusFilter = status;
      if (post != null) _postFilter = post;
      if (user != null) _userFilter = user;
      _page = 1;
      _selectedCommentIds.clear();
    });
    unawaited(_loadComments());
  }

  void _changePage(int page) {
    if (page == _page) return;
    setState(() {
      _page = page;
      _selectedCommentIds.clear();
    });
    unawaited(_loadComments());
  }

  void _changeSort(String sortKey) {
    setState(() {
      _sortState = _sortState.toggled(sortKey);
      _page = 1;
      _selectedCommentIds.clear();
    });
    unawaited(_loadComments());
  }

  Future<void> _approveComment(AdminComment comment) async {
    await _runMutation(() => widget.repository.approveComment(comment.id));
  }

  Future<void> _rejectComment(AdminComment comment) async {
    await _runMutation(() => widget.repository.rejectComment(comment.id));
  }

  Future<void> _approveSelected() async {
    final ids = _selectedCommentIds.toList(growable: false);
    if (ids.isEmpty) return;
    await _runMutation(() => widget.repository.approveComments(ids));
  }

  Future<void> _rejectSelected() async {
    final ids = _selectedCommentIds.toList(growable: false);
    if (ids.isEmpty) return;
    await _runMutation(() => widget.repository.rejectComments(ids));
  }

  Future<void> _togglePinned(AdminComment comment) async {
    await _runMutation(
      () => widget.repository.togglePinned(
        commentId: comment.id,
        pinned: !comment.isPinned,
      ),
    );
  }

  Future<void> _deleteComment(AdminComment comment) async {
    final confirmed = await showAppConfirmationDialog(
      context,
      title: context.t('Delete comment?'),
      message: context.t('comments.deleteMessage'),
      confirmLabel: context.t('Delete'),
      danger: true,
    );
    if (!confirmed) return;

    await _runMutation(() => widget.repository.deleteComment(comment.id));
  }

  Future<void> _deleteSelected() async {
    final ids = _selectedCommentIds.toList(growable: false);
    if (ids.isEmpty) return;
    final confirmed = await showAppConfirmationDialog(
      context,
      title: context.t('Delete selected comments?'),
      message: context.t(
        'comments.deleteSelectedMessage',
        values: {'count': ids.length},
      ),
      confirmLabel: context.t('Delete'),
      danger: true,
    );
    if (!confirmed) return;

    await _runMutation(() => widget.repository.deleteComments(ids));
  }

  Future<void> _replyToComment(AdminComment comment) async {
    final reply = await showCommentReplyDialog(context, comment: comment);
    if (reply == null || reply.trim().isEmpty) return;
    await _runMutation(
      () => widget.repository.replyToComment(
        session: widget.session,
        comment: comment,
        content: reply,
      ),
    );
  }

  Future<void> _runMutation(Future<void> Function() action) async {
    setState(() {
      _loading = true;
      _errorText = null;
    });
    try {
      await action();
      if (!mounted) return;
      _selectedCommentIds.clear();
      await _loadAll();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = error.toString();
        _loading = false;
      });
    }
  }

  List<UserMetric> get _metricCards {
    return [
      UserMetric(
        title: context.t('Total Comments'),
        value: _metrics.total.toString(),
        change: '(${_metrics.totalChange})',
        description: context.t('All Time'),
        icon: Symbols.short_text,
        iconColor: AppColors.actionRed,
      ),
      UserMetric(
        title: context.t('Approved Comments'),
        value: _metrics.approved.toString(),
        change: '(${_metrics.approvedChange})',
        description: context.t('Weekly Analysis'),
        icon: Symbols.check,
        iconColor: const Color(0xFF198754),
      ),
      UserMetric(
        title: context.t('Pending Comments'),
        value: _metrics.pending.toString(),
        change: '(${_metrics.pendingChange})',
        description: context.t('Awaiting comment approval'),
        icon: Symbols.schedule,
        iconColor: AppColors.warmHorizon,
      ),
      UserMetric(
        title: context.t('Rejected Comments'),
        value: _metrics.rejected.toString(),
        change: '(${_metrics.rejectedChange})',
        description: context.t('Weekly Analysis'),
        icon: Symbols.close,
        iconColor: AppColors.actionRed,
      ),
    ];
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
            const _CommentsTitle(),
            const SizedBox(height: 16),
            mobile
                ? _CommentsMobileSummaryGrid(metrics: _metricCards)
                : UsersSummaryGrid(metrics: _metricCards, compact: true),
            if (_errorText != null) ...[
              const SizedBox(height: 16),
              _CommentsErrorBanner(message: _errorText!),
            ],
            SizedBox(height: mobile ? 12 : 16),
            Expanded(
              child: CommentsTableCard(
                comments: _visibleComments(),
                filterOptions: _filterOptions,
                loading: _loading,
                searching: _searching && _searchQuery.trim().isNotEmpty,
                page: _page,
                pageSize: _pageSize,
                totalCount: _totalCount,
                searchQuery: _searchQuery,
                statusFilter: _statusFilter,
                postFilter: _postFilter,
                userFilter: _userFilter,
                selectedCommentIds: _selectedCommentIds,
                sortState: _sortState,
                onPageSizeChanged: _changePageSize,
                onSearchChanged: _changeSearch,
                onStatusChanged: _changeStatus,
                onPostChanged: _changePost,
                onUserChanged: _changeUser,
                onPageChanged: _changePage,
                onToggleComment: _toggleComment,
                onToggleAllComments: _toggleAllComments,
                onSort: _changeSort,
                onApproveComment: (comment) =>
                    unawaited(_approveComment(comment)),
                onRejectComment: (comment) =>
                    unawaited(_rejectComment(comment)),
                onTogglePinned: (comment) => unawaited(_togglePinned(comment)),
                onReplyComment: (comment) =>
                    unawaited(_replyToComment(comment)),
                onDeleteComment: (comment) =>
                    unawaited(_deleteComment(comment)),
                onDeleteSelected: () => unawaited(_deleteSelected()),
                onApproveSelected: () => unawaited(_approveSelected()),
                onRejectSelected: () => unawaited(_rejectSelected()),
              ),
            ),
          ],
        );

        if (mobile) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              topPadding,
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
              topPadding,
              horizontalPadding,
              28,
            ),
            child: SizedBox(height: 980, child: content),
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

Future<String?> showCommentReplyDialog(
  BuildContext context, {
  required AdminComment comment,
}) {
  return showDialog<String>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.34),
    builder: (context) => _CommentReplyDialog(comment: comment),
  );
}

class _CommentReplyDialog extends StatefulWidget {
  const _CommentReplyDialog({required this.comment});

  final AdminComment comment;

  @override
  State<_CommentReplyDialog> createState() => _CommentReplyDialogState();
}

class _CommentReplyDialogState extends State<_CommentReplyDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.value),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        context.t('Reply to comment'),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppColors.deepOcean,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      tooltip: context.t('Cancel'),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Symbols.close, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.value),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Text(
                    widget.comment.content,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.inkSoft,
                      fontWeight: FontWeight.w600,
                      height: 1.45,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _controller,
                  minLines: 4,
                  maxLines: 4,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: context.t('Type your reply...'),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(context.t('Cancel')),
                    ),
                    const SizedBox(width: 14),
                    SizedBox(
                      height: 36,
                      child: TextButton(
                        onPressed: _controller.text.trim().isEmpty
                            ? null
                            : () => Navigator.of(context).pop(_controller.text),
                        style:
                            TextButton.styleFrom(
                              backgroundColor: AppColors.deepOcean,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: AppColors.softLine,
                              disabledForegroundColor: AppColors.support,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.value,
                                ),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0,
                              ),
                            ).copyWith(
                              mouseCursor: const WidgetStatePropertyAll(
                                SystemMouseCursors.click,
                              ),
                            ),
                        child: Text(context.t('Send Reply')),
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

class _CommentsTitle extends StatelessWidget {
  const _CommentsTitle();

  @override
  Widget build(BuildContext context) {
    return Text(
      context.t('Comments'),
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
        color: AppColors.deepOcean,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
    );
  }
}

class _CommentsMobileSummaryGrid extends StatelessWidget {
  const _CommentsMobileSummaryGrid({required this.metrics});

  final List<UserMetric> metrics;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 0; index < metrics.length; index++) ...[
          Expanded(child: _CommentsMobileMetricCard(metric: metrics[index])),
          if (index != metrics.length - 1) const SizedBox(width: 6),
        ],
      ],
    );
  }
}

class _CommentsMobileMetricCard extends StatelessWidget {
  const _CommentsMobileMetricCard({required this.metric});

  final UserMetric metric;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: AppColors.line.withValues(alpha: 0.72)),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepOcean.withValues(alpha: 0.035),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            metric.title,
            maxLines: 2,
            style: const TextStyle(
              color: AppColors.deepOcean,
              fontSize: 8.6,
              fontWeight: FontWeight.w800,
              height: 1.05,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    metric.value,
                    maxLines: 1,
                    style: const TextStyle(
                      color: AppColors.deepOcean,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      height: 1,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 3),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  metric.change,
                  maxLines: 1,
                  style: const TextStyle(
                    color: AppColors.warmHorizon,
                    fontSize: 7.8,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            metric.description,
            maxLines: 2,
            style: const TextStyle(
              color: AppColors.deepOcean,
              fontSize: 7.7,
              fontWeight: FontWeight.w700,
              height: 1.05,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentsErrorBanner extends StatelessWidget {
  const _CommentsErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.actionRed.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.actionRed.withValues(alpha: 0.22)),
      ),
      child: Text(
        context.t(message),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.actionRed,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
