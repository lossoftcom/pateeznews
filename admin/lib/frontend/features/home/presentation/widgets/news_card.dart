import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/mock/home_mock_data.dart';
import '../../../../core/network/local_api_base_url.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/adaptive_headline.dart';
import '../../../../shared/widgets/cached_image.dart';
import '../../../../shared/widgets/frontend_toast.dart';
import '../../../../shared/widgets/pinch_zoom_surface.dart';
import '../../../../shared/widgets/social_action.dart';
import '../../../../shared/widgets/verified_badge.dart';
import '../../../account/data/frontend_auth_repository.dart';
import '../../data/news_comments_repository.dart';
import '../../data/post_action_repository.dart';
import '../../../shell/data/app_shell_repository.dart';
import 'news_audio_card.dart';
import 'news_video_player.dart';
import 'social_embed_stage.dart';

const int _inlineCollapsedRootCommentLimit = 2;
const int _inlineMaxRootCommentLimit = 20;
const int _inlineCommentMaxLength = 2000;
const int _inlineCommentCounterRevealLength = 1600;
const int _inlineCommentCounterWarningLength = 1900;
const String _kFrontendApiBaseUrl = String.fromEnvironment(
  'PATEEZNEWS_API_BASE_URL',
);
const String _kPublicFrontendHost = 'www.pateez.com';

/// Pateeznews sosyal post kartı.
///
/// Görsel üstü yayıncı overlay'i, görsel altı editorial başlık ve özgün
/// sosyal aksiyon diliyle haber + sosyal medya hissini tek kartta birleştirir.
class NewsCard extends StatefulWidget {
  const NewsCard({
    super.key,
    required this.article,
    required this.onTap,
    this.categoryTrail = const [],
    this.videoFeedArticles = const [],
    this.shellSettings = const AppShellSettings.empty(),
    this.commentsEnabled = true,
    this.commentApprovalEnabled = true,
    this.emojiReactionsEnabled = true,
    this.showMediaStage = true,
    this.showTitleSummary = true,
    this.showReadStats = true,
    this.showActions = true,
    this.showComments = true,
    this.showMediaHeader = true,
    this.showStructuredMediaText = true,
    this.relaxedInlineComments = false,
    this.showInlineCommentGuidance = false,
    this.resolveActualImageAspectRatio = false,
    this.authState,
    this.commentsRepository = const NewsCommentsRepository(),
    this.postActionRepository = const PostActionRepository(),
    this.onAuthRequired,
    this.onAuthorTap,
    this.onFullscreenVideoExit,
  });

  final NewsArticle article;
  final VoidCallback onTap;
  final List<String> categoryTrail;
  final List<NewsArticle> videoFeedArticles;
  final AppShellSettings shellSettings;
  final bool commentsEnabled;
  final bool commentApprovalEnabled;
  final bool emojiReactionsEnabled;
  final bool showMediaStage;
  final bool showTitleSummary;
  final bool showReadStats;
  final bool showActions;
  final bool showComments;
  final bool showMediaHeader;
  final bool showStructuredMediaText;
  final bool relaxedInlineComments;
  final bool showInlineCommentGuidance;
  final bool resolveActualImageAspectRatio;
  final FrontendAuthState? authState;
  final NewsCommentsRepository commentsRepository;
  final PostActionRepository postActionRepository;
  final VoidCallback? onAuthRequired;
  final ValueChanged<NewsAuthor>? onAuthorTap;
  final VoidCallback? onFullscreenVideoExit;

  @override
  State<NewsCard> createState() => _NewsCardState();
}

class _NewsCardState extends State<NewsCard> {
  late bool _isLiked = widget.article.userLiked;
  late bool _isDisliked = widget.article.userDisliked;
  late bool _isSaved = widget.article.userSaved;
  late int _likes = widget.article.likes;
  late int _dislikes = widget.article.dislikes;
  late int _shares = widget.article.shares;
  late int _saves = widget.article.saves;
  late int _views = widget.article.views;
  late List<NewsComment> _comments = widget.article.previewComments;
  NewsComment? _replyTo;
  bool _commentBusy = false;
  bool _commentsVisible = true;
  bool _commentsExpanded = false;
  bool _commentsLoading = false;
  bool _expandedCommentsFetched = false;
  String? _deletingCommentId;
  bool _postActionBusy = false;
  bool _viewRecorded = false;
  double? _resolvedImageAspectRatio;
  ImageStream? _pendingImageStream;
  ImageStreamListener? _pendingImageListener;

  @override
  void initState() {
    super.initState();
    _resolveImageAspectRatio(widget.article);
  }

  @override
  void didUpdateWidget(covariant NewsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.article.imageUrl != widget.article.imageUrl ||
        oldWidget.article.imageAspectRatio != widget.article.imageAspectRatio ||
        oldWidget.resolveActualImageAspectRatio !=
            widget.resolveActualImageAspectRatio) {
      _removeImageListener();
      _resolvedImageAspectRatio = null;
      _resolveImageAspectRatio(widget.article);
    }
    if (oldWidget.article.id != widget.article.id) {
      _viewRecorded = false;
      _syncPostActionStateFromArticle();
      _comments = widget.article.previewComments;
      _replyTo = null;
      _deletingCommentId = null;
      _commentsVisible = widget.commentsEnabled;
      _commentsExpanded = false;
      _commentsLoading = false;
      _expandedCommentsFetched = false;
    } else if (oldWidget.article.previewComments !=
        widget.article.previewComments) {
      _comments = widget.article.previewComments;
      _expandedCommentsFetched = false;
    }
    if (oldWidget.article.likes != widget.article.likes ||
        oldWidget.article.dislikes != widget.article.dislikes ||
        oldWidget.article.shares != widget.article.shares ||
        oldWidget.article.views != widget.article.views ||
        oldWidget.article.saves != widget.article.saves ||
        oldWidget.article.userLiked != widget.article.userLiked ||
        oldWidget.article.userDisliked != widget.article.userDisliked ||
        oldWidget.article.userSaved != widget.article.userSaved) {
      _syncPostActionStateFromArticle();
    }
    if (oldWidget.commentsEnabled != widget.commentsEnabled &&
        !widget.commentsEnabled) {
      _commentsVisible = false;
      _replyTo = null;
      _commentsExpanded = false;
      _commentsLoading = false;
    }
  }

  @override
  void dispose() {
    _removeImageListener();
    super.dispose();
  }

  void _syncPostActionStateFromArticle() {
    _likes = widget.article.likes;
    _dislikes = widget.article.dislikes;
    _shares = widget.article.shares;
    _saves = widget.article.saves;
    _views = widget.article.views;
    _isLiked = widget.article.userLiked;
    _isDisliked = widget.article.userDisliked;
    _isSaved = widget.article.userSaved;
  }

  void _applyPostActionState(PostActionState state) {
    if (!mounted) return;
    setState(() {
      _likes = state.likes;
      _dislikes = state.dislikes;
      _shares = state.shares;
      _saves = state.saves;
      _views = state.views;
      _isLiked = state.liked;
      _isDisliked = state.disliked;
      _isSaved = state.saved;
    });
  }

  bool _requireSignedIn(String message) {
    if (_authToken.isNotEmpty) return true;
    _showCommentMessage(message, tone: FrontendToastTone.error);
    widget.onAuthRequired?.call();
    return false;
  }

  Future<void> _toggleLike() async {
    if (!_hasNumericPostId || _postActionBusy) return;
    if (!_requireSignedIn('Beğenmek için kayıt olmanız gerekiyor.')) return;
    final previous = _postActionSnapshot();
    setState(() {
      _postActionBusy = true;
      if (_isLiked) {
        _isLiked = false;
        _likes = math.max(0, _likes - 1);
      } else {
        if (_isDisliked) {
          _isDisliked = false;
          _dislikes = math.max(0, _dislikes - 1);
        }
        _isLiked = true;
        _likes++;
      }
    });
    try {
      final state = await widget.postActionRepository.toggleLike(
        postId: widget.article.id,
        token: _authToken,
      );
      if (mounted) _applyPostActionState(state);
    } on PostActionException catch (error) {
      if (!mounted) return;
      _restorePostActionSnapshot(previous);
      _showCommentMessage(error.message, tone: FrontendToastTone.error);
    } catch (_) {
      if (!mounted) return;
      _restorePostActionSnapshot(previous);
      _showCommentMessage(
        'Beğeni güncellenemedi.',
        tone: FrontendToastTone.error,
      );
    } finally {
      if (mounted) setState(() => _postActionBusy = false);
    }
  }

  Future<void> _toggleDislike() async {
    if (!_hasNumericPostId || _postActionBusy) return;
    if (!_requireSignedIn('Beğenmemek için kayıt olmanız gerekiyor.')) return;
    final previous = _postActionSnapshot();
    setState(() {
      _postActionBusy = true;
      if (_isDisliked) {
        _isDisliked = false;
        _dislikes = math.max(0, _dislikes - 1);
      } else {
        if (_isLiked) {
          _isLiked = false;
          _likes = math.max(0, _likes - 1);
        }
        _isDisliked = true;
        _dislikes++;
      }
    });
    try {
      final state = await widget.postActionRepository.toggleDislike(
        postId: widget.article.id,
        token: _authToken,
      );
      if (mounted) _applyPostActionState(state);
    } on PostActionException catch (error) {
      if (!mounted) return;
      _restorePostActionSnapshot(previous);
      _showCommentMessage(error.message, tone: FrontendToastTone.error);
    } catch (_) {
      if (!mounted) return;
      _restorePostActionSnapshot(previous);
      _showCommentMessage(
        'Beğenmeme güncellenemedi.',
        tone: FrontendToastTone.error,
      );
    } finally {
      if (mounted) setState(() => _postActionBusy = false);
    }
  }

  Future<void> _toggleSave() async {
    if (!_hasNumericPostId || _postActionBusy) return;
    if (!_requireSignedIn('Kaydetmek için kayıt olmanız gerekiyor.')) return;
    final previous = _postActionSnapshot();
    setState(() {
      _postActionBusy = true;
      _isSaved = !_isSaved;
      _saves = math.max(0, _saves + (_isSaved ? 1 : -1));
    });
    try {
      final state = await widget.postActionRepository.toggleSave(
        postId: widget.article.id,
        token: _authToken,
      );
      if (mounted) _applyPostActionState(state);
    } on PostActionException catch (error) {
      if (!mounted) return;
      _restorePostActionSnapshot(previous);
      _showCommentMessage(error.message, tone: FrontendToastTone.error);
    } catch (_) {
      if (!mounted) return;
      _restorePostActionSnapshot(previous);
      _showCommentMessage(
        'Kaydetme güncellenemedi.',
        tone: FrontendToastTone.error,
      );
    } finally {
      if (mounted) setState(() => _postActionBusy = false);
    }
  }

  Future<void> _copyArticleLink(NewsArticle article) async {
    final shareUrl = _shareUrlForArticle(article);
    if (shareUrl.isEmpty) {
      _showCommentMessage(
        'Bağlantı hazırlanamadı.',
        tone: FrontendToastTone.error,
      );
      return;
    }
    try {
      await Clipboard.setData(ClipboardData(text: shareUrl));
    } catch (_) {
      if (!mounted) return;
      _showCommentMessage(
        'Bağlantı kopyalanamadı.',
        tone: FrontendToastTone.error,
      );
      return;
    }
    if (!mounted) return;
    _showCommentMessage(
      'Bağlantı kopyalandı.',
      tone: FrontendToastTone.success,
    );
  }

  Future<void> _shareArticle([NewsArticle? targetArticle]) async {
    final article = targetArticle ?? widget.article;
    final shareUrl = _shareUrlForArticle(article);
    if (shareUrl.isEmpty) return;
    final shouldTrackCardShare = article.id == widget.article.id;
    final previousShares = _shares;
    if (shouldTrackCardShare) {
      setState(() => _shares++);
      try {
        if (_hasNumericPostId) {
          final token = _authToken;
          final state = await widget.postActionRepository.share(
            postId: widget.article.id,
            token: token.isEmpty ? null : token,
            platform: 'mobile_share',
          );
          if (mounted) _applyPostActionState(state);
        }
      } catch (_) {
        if (mounted) setState(() => _shares = previousShares);
      }
    }

    if (!mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    final title = article.title.trim();
    final category = article.category.trim();
    final text = [
      if (title.isNotEmpty) title,
      if (category.isNotEmpty) category,
      shareUrl,
    ].join('\n');
    unawaited(
      SharePlus.instance.share(
        ShareParams(
          text: text,
          title: title.isEmpty ? 'Pateez' : title,
          subject: title.isEmpty ? 'Pateez' : title,
          sharePositionOrigin: origin,
        ),
      ),
    );
  }

  Future<void> _openReportSheet(NewsArticle article) async {
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.36),
      builder: (context) => _ArticleReportSheet(article: article),
    );
    if (!mounted || submitted != true) return;
    _showCommentMessage(
      'Şikayet bildirimi alındı.',
      tone: FrontendToastTone.success,
    );
  }

  void _reportArticle(NewsArticle article) {
    unawaited(_openReportSheet(article));
  }

  Future<void> _recordRead(String source) async {
    if (!_hasNumericPostId || _viewRecorded) return;
    _viewRecorded = true;
    try {
      final token = _authToken;
      final state = await widget.postActionRepository.recordView(
        postId: widget.article.id,
        token: token.isEmpty ? null : token,
        source: source,
      );
      if (mounted) _applyPostActionState(state);
    } catch (_) {
      _viewRecorded = false;
    }
  }

  void _handleCardTap() {
    unawaited(_recordRead('open_detail'));
    widget.onTap();
  }

  _PostActionSnapshot _postActionSnapshot() => _PostActionSnapshot(
    likes: _likes,
    dislikes: _dislikes,
    shares: _shares,
    saves: _saves,
    liked: _isLiked,
    disliked: _isDisliked,
    saved: _isSaved,
  );

  void _restorePostActionSnapshot(_PostActionSnapshot snapshot) {
    setState(() {
      _likes = snapshot.likes;
      _dislikes = snapshot.dislikes;
      _shares = snapshot.shares;
      _saves = snapshot.saves;
      _isLiked = snapshot.liked;
      _isDisliked = snapshot.disliked;
      _isSaved = snapshot.saved;
    });
  }

  String get _authToken => widget.authState?.session.accessToken.trim() ?? '';

  bool get _hasNumericPostId => int.tryParse(widget.article.id) != null;

  int get _expandedCommentsLimit {
    final requested = math.max(
      _inlineCollapsedRootCommentLimit,
      math.max(widget.article.comments, _comments.length),
    );
    return requested > _inlineMaxRootCommentLimit
        ? _inlineMaxRootCommentLimit
        : requested;
  }

  int get _activeCommentsLimit => _commentsExpanded
      ? _expandedCommentsLimit
      : _inlineCollapsedRootCommentLimit;

  void _showCommentMessage(
    String message, {
    FrontendToastTone tone = FrontendToastTone.success,
  }) => FrontendToast.show(context, message: message, tone: tone);

  List<NewsComment> _replaceComment(
    List<NewsComment> comments,
    String id,
    NewsComment Function(NewsComment comment) replace,
  ) {
    var changed = false;
    final next = [
      for (final comment in comments)
        if (comment.id == id)
          (() {
            changed = true;
            return replace(comment);
          })()
        else
          (() {
            final replies = _replaceComment(comment.replies, id, replace);
            if (!identical(replies, comment.replies)) {
              changed = true;
              return comment.copyWith(replies: replies);
            }
            return comment;
          })(),
    ];
    return changed ? next : comments;
  }

  Future<bool> _submitComment(_InlineCommentDraft draft) async {
    if (!widget.commentsEnabled) return false;
    if (!_hasNumericPostId) {
      _showCommentMessage(
        'Bu haber için yorum gönderilemiyor.',
        tone: FrontendToastTone.error,
      );
      return false;
    }
    if (_commentBusy || _deletingCommentId != null) return false;
    setState(() => _commentBusy = true);
    try {
      final token = _authToken;
      await widget.commentsRepository.submitComment(
        postId: widget.article.id,
        content: draft.content,
        token: token.isEmpty ? null : token,
        guestName: draft.guestName,
        guestEmail: draft.guestEmail,
        parentId: _replyTo?.id,
      );
      final freshComments = await widget.commentsRepository.fetchComments(
        postId: widget.article.id,
        token: token.isEmpty ? null : token,
        limit: _activeCommentsLimit,
      );
      if (!mounted) return false;
      setState(() {
        _comments = freshComments;
        _replyTo = null;
        _expandedCommentsFetched = _commentsExpanded;
      });
      _showCommentMessage(
        widget.commentApprovalEnabled
            ? 'Yorum onaya gönderildi.'
            : 'Yorum yayınlandı.',
      );
      return true;
    } on NewsCommentsException catch (error) {
      if (mounted) {
        _showCommentMessage(error.message, tone: FrontendToastTone.error);
      }
      return false;
    } catch (_) {
      if (mounted) {
        _showCommentMessage(
          'Yorum gönderilemedi.',
          tone: FrontendToastTone.error,
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _commentBusy = false);
    }
  }

  Future<void> _toggleCommentLike(NewsComment comment) async {
    if (!widget.commentsEnabled) return;
    if (!_hasNumericPostId ||
        comment.id.isEmpty ||
        _commentBusy ||
        _deletingCommentId != null) {
      return;
    }
    final token = _authToken;
    if (token.isEmpty) {
      _showCommentMessage(
        'Beğeni için giriş yapın.',
        tone: FrontendToastTone.info,
      );
      return;
    }
    final wasLiked = comment.userLiked;
    setState(() {
      _comments = _replaceComment(
        _comments,
        comment.id,
        (item) => item.copyWith(
          userLiked: !wasLiked,
          likes: math.max(0, item.likes + (wasLiked ? -1 : 1)),
        ),
      );
    });
    try {
      final freshComments = await widget.commentsRepository.toggleLike(
        postId: widget.article.id,
        commentId: comment.id,
        token: token,
        limit: _activeCommentsLimit,
      );
      if (mounted) {
        setState(() {
          _comments = freshComments;
          _expandedCommentsFetched = _commentsExpanded;
        });
      }
    } on NewsCommentsException catch (error) {
      if (!mounted) return;
      setState(() {
        _comments = _replaceComment(
          _comments,
          comment.id,
          (item) => item.copyWith(
            userLiked: wasLiked,
            likes: math.max(0, item.likes + (wasLiked ? 1 : -1)),
          ),
        );
      });
      _showCommentMessage(error.message, tone: FrontendToastTone.error);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _comments = _replaceComment(
          _comments,
          comment.id,
          (item) => item.copyWith(
            userLiked: wasLiked,
            likes: math.max(0, item.likes + (wasLiked ? 1 : -1)),
          ),
        );
      });
      _showCommentMessage('Yorum beğenilemedi.', tone: FrontendToastTone.error);
    }
  }

  Future<void> _deleteComment(NewsComment comment) async {
    if (!widget.commentsEnabled) return;
    if (!_hasNumericPostId ||
        comment.id.isEmpty ||
        !comment.canDelete ||
        _commentBusy ||
        _deletingCommentId != null) {
      return;
    }
    final token = _authToken;
    if (token.isEmpty) {
      _showCommentMessage(
        'Yorumu silmek için giriş yapın.',
        tone: FrontendToastTone.info,
      );
      return;
    }
    setState(() => _deletingCommentId = comment.id);
    try {
      final freshComments = await widget.commentsRepository.deleteComment(
        postId: widget.article.id,
        commentId: comment.id,
        token: token,
        limit: _activeCommentsLimit,
      );
      if (!mounted) return;
      setState(() {
        _comments = freshComments;
        _replyTo = null;
        _expandedCommentsFetched = _commentsExpanded;
      });
      _showCommentMessage('Yorum silindi.');
    } on NewsCommentsException catch (error) {
      if (mounted) {
        _showCommentMessage(error.message, tone: FrontendToastTone.error);
      }
    } catch (_) {
      if (mounted) {
        _showCommentMessage('Yorum silinemedi.', tone: FrontendToastTone.error);
      }
    } finally {
      if (mounted) setState(() => _deletingCommentId = null);
    }
  }

  Future<void> _ensureExpandedCommentsLoaded() async {
    if (!widget.commentsEnabled) return;
    if (!_hasNumericPostId || _commentsLoading || _expandedCommentsFetched) {
      return;
    }
    final limit = _expandedCommentsLimit;
    if (_comments.length >= limit &&
        widget.article.comments <= _comments.length) {
      setState(() => _expandedCommentsFetched = true);
      return;
    }
    setState(() => _commentsLoading = true);
    try {
      final token = _authToken;
      final freshComments = await widget.commentsRepository.fetchComments(
        postId: widget.article.id,
        token: token.isEmpty ? null : token,
        limit: limit,
      );
      if (!mounted) return;
      setState(() {
        _comments = freshComments;
        _expandedCommentsFetched = true;
      });
    } on NewsCommentsException catch (error) {
      if (mounted) {
        _showCommentMessage(error.message, tone: FrontendToastTone.error);
      }
    } catch (_) {
      if (mounted) {
        _showCommentMessage(
          'Yorumlar alınamadı.',
          tone: FrontendToastTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _commentsLoading = false);
    }
  }

  void _toggleCommentsFromActionBar() {
    if (!widget.commentsEnabled) return;
    if (_commentBusy || _deletingCommentId != null) return;
    if (_commentsVisible) {
      setState(() {
        _commentsVisible = false;
        _replyTo = null;
      });
      return;
    }
    setState(() {
      _commentsVisible = true;
      _commentsExpanded = true;
    });
    unawaited(_ensureExpandedCommentsLoaded());
  }

  void _toggleInlineCommentsExpanded() {
    if (!widget.commentsEnabled) return;
    if (_commentBusy || _deletingCommentId != null || _commentsLoading) return;
    if (_commentsExpanded) {
      setState(() => _commentsExpanded = false);
      return;
    }
    setState(() => _commentsExpanded = true);
    unawaited(_ensureExpandedCommentsLoaded());
  }

  void _resolveImageAspectRatio(NewsArticle article) {
    final resolveActual = widget.resolveActualImageAspectRatio;
    final knownRatio = article.imageAspectRatio;
    if (knownRatio != null && knownRatio.isFinite && knownRatio > 0) {
      _resolvedImageAspectRatio = knownRatio;
      if (!resolveActual) return;
    }

    final parsedRatio = _parseImageAspectRatioFromUrl(article.imageUrl);
    if (parsedRatio != null) {
      _resolvedImageAspectRatio = parsedRatio;
      if (!resolveActual) return;
    }

    final imageUrl = article.imageUrl.trim();
    if (imageUrl.isEmpty) return;

    final stream = CachedNetworkImageProvider(
      imageUrl,
    ).resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener((image, _) {
      _removeImageListener();
      final width = image.image.width;
      final height = image.image.height;
      if (!mounted || width <= 0 || height <= 0) return;
      final ratio = width / height;
      final current = _resolvedImageAspectRatio;
      if (current != null && (current - ratio).abs() < 0.001) return;
      setState(() => _resolvedImageAspectRatio = ratio);
    }, onError: (_, _) => _removeImageListener());
    _pendingImageStream = stream;
    _pendingImageListener = listener;
    stream.addListener(listener);
  }

  void _removeImageListener() {
    final stream = _pendingImageStream;
    final listener = _pendingImageListener;
    if (stream != null && listener != null) {
      stream.removeListener(listener);
    }
    _pendingImageStream = null;
    _pendingImageListener = null;
  }

  @override
  Widget build(BuildContext context) {
    final article = widget.article;
    final reviewData = article.reviewData;
    final pollData = article.pollData;
    final vsData = article.vsData;
    final quoteData = article.quoteData;
    final hasInlineBody =
        article.socialEmbed.trim().isNotEmpty ||
        (reviewData != null && reviewData.isValid) ||
        (pollData != null && pollData.isValid) ||
        (vsData != null && vsData.isValid) ||
        (quoteData != null && quoteData.isValid);
    return Material(
      color: AppColors.surface,
      child: InkWell(
        onTap: _handleCardTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.showMediaStage)
              _MediaStage(
                article: article,
                aspectRatio: _resolvedImageAspectRatio,
                categoryTrail: widget.categoryTrail,
                videoFeedArticles: widget.videoFeedArticles,
                shellSettings: widget.shellSettings,
                showHeader: widget.showMediaHeader,
                showStructuredMediaText: widget.showStructuredMediaText,
                authState: widget.authState,
                postActionRepository: widget.postActionRepository,
                onReadSignal: (source) => unawaited(_recordRead(source)),
                onPostActionState: _applyPostActionState,
                onAuthRequired: widget.onAuthRequired,
                onAuthorTap: widget.onAuthorTap,
                onCopyLink: (article) => unawaited(_copyArticleLink(article)),
                onShare: (article) => unawaited(_shareArticle(article)),
                onReport: _reportArticle,
                onFullscreenVideoExit: widget.onFullscreenVideoExit,
              ),
            // Sosyal medya kartlarında başlık _MediaStage içinde (embed üstünde)
            // gösterilir; özet ise gönderi embed'i metni zaten içerdiğinden
            // gösterilmez. İkisini de yalnızca normal kartlarda veririz.
            if (widget.showTitleSummary && !hasInlineBody) ...[
              _Title(title: article.title),
              _Summary(summary: article.summary),
            ],
            if (widget.showReadStats)
              _ReadStats(article: article, views: _views),
            if (widget.showActions)
              _ActionBar(
                article: article,
                isLiked: _isLiked,
                isDisliked: _isDisliked,
                isSaved: _isSaved,
                likes: _likes,
                dislikes: _dislikes,
                shares: _shares,
                saves: _saves,
                onLike: _toggleLike,
                onDislike: _toggleDislike,
                onSave: _toggleSave,
                onShare: () => unawaited(_shareArticle()),
                commentsEnabled: widget.commentsEnabled,
                commentsVisible: _commentsVisible,
                onCommentsToggle: _toggleCommentsFromActionBar,
              ),
            if (widget.commentsEnabled && widget.showComments)
              _InlineCommentPreview(
                comments: _comments,
                totalCount: article.comments,
                visible: _commentsVisible,
                expanded: _commentsExpanded,
                loadingMore: _commentsLoading,
                authState: widget.authState,
                replyTo: _replyTo,
                submitting: _commentBusy,
                deletingCommentId: _deletingCommentId,
                emojiReactionsEnabled: widget.emojiReactionsEnabled,
                relaxedLayout: widget.relaxedInlineComments,
                showGuidance: widget.showInlineCommentGuidance,
                onCancelReply: () => setState(() => _replyTo = null),
                onReply: (comment) => setState(() => _replyTo = comment),
                onLike: _toggleCommentLike,
                onDelete: _deleteComment,
                onToggleExpanded: _toggleInlineCommentsExpanded,
                onSubmit: _submitComment,
                onAuthorTap: widget.onAuthorTap,
              ),
          ],
        ),
      ),
    );
  }
}

class _PostActionSnapshot {
  const _PostActionSnapshot({
    required this.likes,
    required this.dislikes,
    required this.shares,
    required this.saves,
    required this.liked,
    required this.disliked,
    required this.saved,
  });

  final int likes;
  final int dislikes;
  final int shares;
  final int saves;
  final bool liked;
  final bool disliked;
  final bool saved;
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER
// ─────────────────────────────────────────────────────────────────────────────

enum _HeaderMenuAction { copyLink, share, report }

class _HeaderOverlay extends StatelessWidget {
  const _HeaderOverlay({
    required this.article,
    required this.categoryTrail,
    required this.onAuthorTap,
    required this.onCopyLink,
    required this.onShare,
    required this.onReport,
  });

  final NewsArticle article;
  final List<String> categoryTrail;
  final ValueChanged<NewsAuthor>? onAuthorTap;
  final ValueChanged<NewsArticle> onCopyLink;
  final ValueChanged<NewsArticle> onShare;
  final ValueChanged<NewsArticle> onReport;

  @override
  Widget build(BuildContext context) {
    final author = article.author;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 11, 6, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _AuthorTapTarget(
            author: author,
            onAuthorTap: onAuthorTap,
            child: _Avatar(author: author),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _AuthorTapTarget(
              author: author,
              onAuthorTap: onAuthorTap,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _NameLine(author: author),
                  const SizedBox(height: 3),
                  _Meta(article: article, categoryTrail: categoryTrail),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          _HeaderMoreMenu(
            color: Colors.white,
            onCopyLink: () => onCopyLink(article),
            onShare: () => onShare(article),
            onReport: () => onReport(article),
          ),
        ],
      ),
    );
  }
}

class _SocialArticleHeader extends StatelessWidget {
  const _SocialArticleHeader({
    required this.article,
    required this.categoryTrail,
    required this.onAuthorTap,
    required this.onCopyLink,
    required this.onShare,
    required this.onReport,
  });

  final NewsArticle article;
  final List<String> categoryTrail;
  final ValueChanged<NewsAuthor>? onAuthorTap;
  final ValueChanged<NewsArticle> onCopyLink;
  final ValueChanged<NewsArticle> onShare;
  final ValueChanged<NewsArticle> onReport;

  @override
  Widget build(BuildContext context) {
    final author = article.author;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.softLine)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageHorizontal,
          AppSpacing.md,
          AppSpacing.pageHorizontal - 4,
          AppSpacing.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _AuthorTapTarget(
              author: author,
              onAuthorTap: onAuthorTap,
              child: _Avatar(author: author),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _AuthorTapTarget(
                author: author,
                onAuthorTap: onAuthorTap,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SocialNameLine(author: author),
                    const SizedBox(height: 3),
                    _SocialMeta(article: article, categoryTrail: categoryTrail),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),
            _HeaderMoreMenu(
              color: AppColors.iconMuted,
              onCopyLink: () => onCopyLink(article),
              onShare: () => onShare(article),
              onReport: () => onReport(article),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthorTapTarget extends StatelessWidget {
  const _AuthorTapTarget({
    required this.author,
    required this.child,
    required this.onAuthorTap,
  });

  final NewsAuthor author;
  final Widget child;
  final ValueChanged<NewsAuthor>? onAuthorTap;

  @override
  Widget build(BuildContext context) {
    final onTap = onAuthorTap;
    if (onTap == null ||
        (author.id.trim().isEmpty && (author.handle ?? '').trim().isEmpty)) {
      return child;
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap(author),
      child: child,
    );
  }
}

class _SocialNameLine extends StatelessWidget {
  const _SocialNameLine({required this.author});

  final NewsAuthor author;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            author.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.meta.copyWith(
              fontFamily: AppTypography.primaryFamily,
              color: AppColors.inkStrong,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
              height: 1.1,
            ),
          ),
        ),
        if (author.isVerified || author.isOfficial) ...[
          const SizedBox(width: 4),
          VerifiedBadge(official: author.isOfficial, size: 13),
        ],
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            _handleFor(author),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.meta.copyWith(
              fontFamily: AppTypography.primaryFamily,
              color: AppColors.inkSoft,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
              height: 1.1,
            ),
          ),
        ),
      ],
    );
  }
}

class _SocialMeta extends StatelessWidget {
  const _SocialMeta({required this.article, required this.categoryTrail});

  final NewsArticle article;
  final List<String> categoryTrail;

  @override
  Widget build(BuildContext context) {
    final label = _categoryLabel(categoryTrail, article);
    final date = _formatCardDate(article.publishedAt);
    final time = _formatCardClock(article.publishedAt);
    final style = AppTypography.meta.copyWith(
      fontFamily: AppTypography.primaryFamily,
      color: AppColors.inkSoft,
      fontSize: 11.5,
      letterSpacing: 0,
      fontWeight: FontWeight.w600,
      height: 1.1,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: constraints.maxWidth,
          child: FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (label.isNotEmpty) ...[
                  Text(label, maxLines: 1, style: style),
                  const _SocialMetaDot(),
                ],
                Text(date, maxLines: 1, style: style),
                const SizedBox(width: 7),
                const Icon(
                  Symbols.time_fill,
                  size: 12.5,
                  color: AppColors.inkSoft,
                ),
                const SizedBox(width: 3),
                Text(time, maxLines: 1, style: style),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SocialMetaDot extends StatelessWidget {
  const _SocialMetaDot();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Container(
        width: 3,
        height: 3,
        decoration: const BoxDecoration(
          color: AppColors.support,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// Görsel üstünde yayıncı satırı: "Pateez Niğde" + onay rozeti + @kullanıcı adı.
/// Kutu yok; beyaz metin + hafif gölge ile (üstteki degrade sayesinde) her
/// görselde net okunur — Instagram Reels başlığı dilinde.
class _NameLine extends StatelessWidget {
  const _NameLine({required this.author});

  final NewsAuthor author;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            author.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.meta.copyWith(
              fontFamily: AppTypography.primaryFamily,
              color: Colors.white,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.1,
              height: 1.1,
              shadows: _mediaTextShadows,
            ),
          ),
        ),
        if (author.isVerified || author.isOfficial) ...[
          const SizedBox(width: 4),
          VerifiedBadge(official: author.isOfficial, size: 13),
        ],
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            _handleFor(author),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.meta.copyWith(
              fontFamily: AppTypography.primaryFamily,
              color: Colors.white.withValues(alpha: 0.80),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
              height: 1.1,
              shadows: _mediaTextShadows,
            ),
          ),
        ),
      ],
    );
  }
}

/// Meta satırındaki ayraç noktası (beyaz, görsel üstü).
class _MetaDot extends StatelessWidget {
  const _MetaDot();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Container(
        width: 3,
        height: 3,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.62),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// Görselin üstündeki yumuşak koyu degrade. Başlık, görsel ne kadar karışık
/// olursa olsun okunur kalsın diye eklenir (Instagram Reels üst degradesi gibi).
class _HeaderScrim extends StatelessWidget {
  const _HeaderScrim();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 104,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x75000000), Color(0x1A000000), Color(0x00000000)],
          stops: [0, 0.6, 1],
        ),
      ),
    );
  }
}

/// Avatar — çevresinde projenin marka renklerinden (amber → kırmızı → deepOcean)
/// degrade halka + ince beyaz boşluk. Instagram'daki halkanın aynısı ama
/// Pateez renklerinde; görsel ne olursa olsun avatar net "patlar".
class _Avatar extends StatelessWidget {
  const _Avatar({required this.author});

  final NewsAuthor author;

  @override
  Widget build(BuildContext context) {
    final initial = _avatarInitial(author.name);
    final fallback = Container(
      color: AppColors.surfaceInk,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: AppTypography.titleM.copyWith(
          color: AppColors.deepOcean,
          fontSize: 16,
        ),
      ),
    );
    return Container(
      width: 48,
      height: 48,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(
          colors: [
            AppColors.warmHorizon,
            AppColors.actionRed,
            AppColors.deepOcean,
            AppColors.actionRed,
            AppColors.warmHorizon,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(2.5),
        child: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: ClipOval(
              child: author.avatarUrl.trim().isEmpty
                  ? fallback
                  : CachedImage(
                      url: author.avatarUrl,
                      fit: BoxFit.cover,
                      memCacheWidth: 120,
                      placeholderColor: AppColors.surfaceInk,
                      errorWidget: fallback,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Kategori · tarih · saat tek satırda. "Saat" kelimesi yerine saat ikonu.
/// FittedBox(scaleDown) sayesinde dar ekranda küçülerek tek satırda kalır —
/// asla alt satıra inmez, asla kesilmez (full responsive).
class _Meta extends StatelessWidget {
  const _Meta({required this.article, this.categoryTrail = const []});

  final NewsArticle article;
  final List<String> categoryTrail;

  @override
  Widget build(BuildContext context) {
    final label = _categoryLabel(categoryTrail, article);
    final date = _formatCardDate(article.publishedAt);
    final time = _formatCardClock(article.publishedAt);
    final style = AppTypography.meta.copyWith(
      fontFamily: AppTypography.primaryFamily,
      color: Colors.white.withValues(alpha: 0.95),
      fontSize: 11.5,
      letterSpacing: 0.1,
      fontWeight: FontWeight.w600,
      height: 1.1,
      shadows: _mediaTextShadows,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: constraints.maxWidth,
          child: FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (label.isNotEmpty) ...[
                  Text(label, maxLines: 1, style: style),
                  const _MetaDot(),
                ],
                Text(date, maxLines: 1, style: style),
                const SizedBox(width: 7),
                Icon(
                  Symbols.time_fill,
                  size: 12.5,
                  color: Colors.white.withValues(alpha: 0.92),
                  shadows: _mediaTextShadows,
                ),
                const SizedBox(width: 3),
                Text(time, maxLines: 1, style: style),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HeaderMoreMenu extends StatelessWidget {
  const _HeaderMoreMenu({
    this.color = AppColors.iconMuted,
    required this.onCopyLink,
    required this.onShare,
    required this.onReport,
  });

  final Color color;
  final VoidCallback onCopyLink;
  final VoidCallback onShare;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_HeaderMenuAction>(
      tooltip: 'Diğer seçenekler',
      padding: EdgeInsets.zero,
      offset: const Offset(-8, 34),
      elevation: 8,
      color: AppColors.surface,
      shadowColor: AppColors.shadow,
      constraints: const BoxConstraints(minWidth: 168, maxWidth: 196),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.line),
      ),
      onSelected: (action) {
        switch (action) {
          case _HeaderMenuAction.copyLink:
            onCopyLink();
            break;
          case _HeaderMenuAction.share:
            onShare();
            break;
          case _HeaderMenuAction.report:
            onReport();
            break;
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem<_HeaderMenuAction>(
          value: _HeaderMenuAction.copyLink,
          height: 36,
          padding: EdgeInsets.zero,
          child: _HeaderMenuRow(
            icon: Symbols.open_in_new,
            label: 'Bağlantıyı kopyala',
          ),
        ),
        PopupMenuItem<_HeaderMenuAction>(
          value: _HeaderMenuAction.share,
          height: 36,
          padding: EdgeInsets.zero,
          child: _HeaderMenuRow(
            icon: Symbols.share_forward_line,
            label: 'Paylaş',
          ),
        ),
        PopupMenuItem<_HeaderMenuAction>(
          value: _HeaderMenuAction.report,
          height: 36,
          padding: EdgeInsets.zero,
          child: _HeaderMenuRow(
            icon: Symbols.flag_outlined,
            label: 'Şikayet et',
            danger: true,
          ),
        ),
      ],
      child: Semantics(
        label: 'Diğer seçenekler',
        button: true,
        child: SizedBox(
          width: 34,
          height: 34,
          child: Center(
            child: Icon(
              Symbols.more_horiz_rounded,
              size: 22,
              color: color,
              shadows: _mediaTextShadows,
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderMenuRow extends StatelessWidget {
  const _HeaderMenuRow({
    required this.icon,
    required this.label,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger
        ? AppColors.actionRed.withValues(alpha: 0.84)
        : AppColors.inkSoft;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 9),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.meta.copyWith(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _ArticleReportReason {
  const _ArticleReportReason({
    required this.label,
    required this.description,
    required this.icon,
  });

  final String label;
  final String description;
  final IconData icon;
}

const _articleReportReasons = [
  _ArticleReportReason(
    label: 'Yanıltıcı veya hatalı bilgi',
    description: 'Başlık, görsel ya da içerikte doğruluk sorunu var.',
    icon: Symbols.warning,
  ),
  _ArticleReportReason(
    label: 'Hakaret veya hedef gösterme',
    description: 'Kişileri ya da grupları inciten bir ifade içeriyor.',
    icon: Symbols.person_outline_rounded,
  ),
  _ArticleReportReason(
    label: 'Kişisel hak / telif ihlali',
    description: 'İzinsiz kullanım, özel bilgi ya da hak ihlali şüphesi var.',
    icon: Symbols.lock,
  ),
  _ArticleReportReason(
    label: 'Spam veya reklam',
    description: 'Haberle ilgisiz, yanıltıcı ya da tanıtım amaçlı görünüyor.',
    icon: Symbols.flag_outlined,
  ),
  _ArticleReportReason(
    label: 'Diğer',
    description: 'Farklı bir durumu editöre kısa notla iletmek istiyorum.',
    icon: Symbols.more_horiz_rounded,
  ),
];

class _ArticleReportSheet extends StatefulWidget {
  const _ArticleReportSheet({required this.article});

  final NewsArticle article;

  @override
  State<_ArticleReportSheet> createState() => _ArticleReportSheetState();
}

class _ArticleReportSheetState extends State<_ArticleReportSheet> {
  final _detailsController = TextEditingController();
  int? _selectedReasonIndex;

  bool get _canSubmit => _selectedReasonIndex != null;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_canSubmit) return;
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bottomInset = media.viewInsets.bottom;
    final maxHeight = media.size.height * 0.9;
    final sheetWidth = math.min(media.size.width, 520.0);
    final title = widget.article.title.trim();
    final source = widget.article.author.name.trim();
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: sheetWidth,
            maxWidth: sheetWidth,
            maxHeight: maxHeight,
          ),
          child: Material(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            clipBehavior: Clip.antiAlias,
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.line,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppColors.actionRed.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.actionRed.withValues(
                                alpha: 0.12,
                              ),
                            ),
                          ),
                          child: Icon(
                            Symbols.flag_outlined,
                            size: 19,
                            color: AppColors.actionRed.withValues(alpha: 0.86),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'İçeriği şikayet et',
                                style: AppTypography.titleM.copyWith(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  height: 1.14,
                                  color: AppColors.inkStrong,
                                  letterSpacing: 0,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Bildirimin, haberin bağlamıyla birlikte editör incelemesine alınır.',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.support,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  height: 1.34,
                                  letterSpacing: 0,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _ReportSheetCloseButton(
                          onTap: () => Navigator.of(context).pop(false),
                        ),
                      ],
                    ),
                    if (title.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _ReportArticlePreview(title: title, source: source),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      'Neden bildiriyorsun?',
                      style: AppTypography.eyebrow.copyWith(
                        color: AppColors.ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 9),
                    for (
                      var index = 0;
                      index < _articleReportReasons.length;
                      index += 1
                    ) ...[
                      _ArticleReportReasonTile(
                        reason: _articleReportReasons[index],
                        selected: _selectedReasonIndex == index,
                        onTap: () =>
                            setState(() => _selectedReasonIndex = index),
                      ),
                      if (index != _articleReportReasons.length - 1)
                        const SizedBox(height: 7),
                    ],
                    const SizedBox(height: 14),
                    Text(
                      'Kısa açıklama',
                      style: AppTypography.eyebrow.copyWith(
                        color: AppColors.ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _ReportDetailsField(controller: _detailsController),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Symbols.info_outline_rounded,
                          size: 15,
                          color: AppColors.placeholder,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            'Açıklama opsiyoneldir; net bir not incelemeyi hızlandırır.',
                            style: AppTypography.meta.copyWith(
                              color: AppColors.placeholder,
                              fontSize: 10.8,
                              fontWeight: FontWeight.w500,
                              height: 1.28,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _ReportSheetSecondaryButton(
                            label: 'Vazgeç',
                            onTap: () => Navigator.of(context).pop(false),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ReportSheetSubmitButton(
                            enabled: _canSubmit,
                            onTap: _submit,
                          ),
                        ),
                      ],
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

class _ReportSheetCloseButton extends StatelessWidget {
  const _ReportSheetCloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Kapat',
      button: true,
      child: Material(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: const SizedBox(
            width: 34,
            height: 34,
            child: Icon(
              Symbols.close_rounded,
              size: 17,
              color: AppColors.iconMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _ReportArticlePreview extends StatelessWidget {
  const _ReportArticlePreview({required this.title, required this.source});

  final String title;
  final String source;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.softLine),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          children: [
            const Icon(Symbols.article, size: 17, color: AppColors.iconMuted),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (source.isNotEmpty) ...[
                    Text(
                      source,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.meta.copyWith(
                        color: AppColors.support,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 3),
                  ],
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.ink,
                      fontSize: 12.2,
                      fontWeight: FontWeight.w700,
                      height: 1.22,
                      letterSpacing: 0,
                    ),
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

class _ArticleReportReasonTile extends StatelessWidget {
  const _ArticleReportReasonTile({
    required this.reason,
    required this.selected,
    required this.onTap,
  });

  final _ArticleReportReason reason;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = selected ? AppColors.deepOcean : AppColors.iconMuted;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.deepOcean.withValues(alpha: 0.055)
                : AppColors.surfaceSoft.withValues(alpha: 0.52),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? AppColors.deepOcean.withValues(alpha: 0.22)
                  : AppColors.softLine,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.deepOcean.withValues(alpha: 0.09)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected
                        ? AppColors.deepOcean.withValues(alpha: 0.13)
                        : AppColors.softLine,
                  ),
                ),
                child: Icon(reason.icon, size: 15.5, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reason.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.ink,
                        fontSize: 12.4,
                        fontWeight: FontWeight.w800,
                        height: 1.12,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      reason.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.meta.copyWith(
                        color: AppColors.support,
                        fontSize: 10.7,
                        fontWeight: FontWeight.w500,
                        height: 1.22,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? AppColors.deepOcean : Colors.transparent,
                  border: Border.all(
                    color: selected ? AppColors.deepOcean : AppColors.line,
                    width: selected ? 1.5 : 1.2,
                  ),
                ),
                child: selected
                    ? const Icon(
                        Symbols.check_rounded,
                        size: 12,
                        color: Colors.white,
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

class _ReportDetailsField extends StatelessWidget {
  const _ReportDetailsField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.softLine),
      ),
      child: TextField(
        controller: controller,
        cursorColor: AppColors.deepOcean,
        cursorWidth: 1.3,
        minLines: 3,
        maxLines: 5,
        maxLength: 360,
        maxLengthEnforcement: MaxLengthEnforcement.enforced,
        textInputAction: TextInputAction.newline,
        style: AppTypography.bodySmall.copyWith(
          color: AppColors.ink,
          fontSize: 12.6,
          fontWeight: FontWeight.w500,
          height: 1.34,
          letterSpacing: 0,
        ),
        buildCounter:
            (context, {required currentLength, required isFocused, maxLength}) {
              if (!isFocused && currentLength == 0) return null;
              return Padding(
                padding: const EdgeInsets.only(top: 3, right: 2),
                child: Text(
                  '$currentLength/${maxLength ?? 360}',
                  style: AppTypography.meta.copyWith(
                    color: currentLength > 320
                        ? AppColors.actionRed.withValues(alpha: 0.84)
                        : AppColors.placeholder,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    height: 1,
                    letterSpacing: 0,
                  ),
                ),
              );
            },
        decoration: InputDecoration(
          hintText: 'Kısa bir not ekleyin',
          hintStyle: AppTypography.bodySmall.copyWith(
            color: AppColors.placeholder,
            fontSize: 12.6,
            fontWeight: FontWeight.w500,
            height: 1.34,
            letterSpacing: 0,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.fromLTRB(12, 11, 12, 9),
        ),
      ),
    );
  }
}

class _ReportSheetSecondaryButton extends StatelessWidget {
  const _ReportSheetSecondaryButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceSoft,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: AppColors.softLine),
          ),
          child: Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.inkSoft,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ),
      ),
    );
  }
}

class _ReportSheetSubmitButton extends StatelessWidget {
  const _ReportSheetSubmitButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 140),
      opacity: enabled ? 1 : 0.48,
      child: Material(
        color: enabled ? AppColors.actionRed : AppColors.placeholderSoft,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(13),
          child: SizedBox(
            height: 44,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Symbols.send_rounded, size: 16, color: Colors.white),
                const SizedBox(width: 7),
                Text(
                  'Gönder',
                  style: AppTypography.bodySmall.copyWith(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TITLE & SUMMARY
// ─────────────────────────────────────────────────────────────────────────────

class _Title extends StatelessWidget {
  const _Title({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final headlineColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : const Color(0xFF101820);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        14,
        AppSpacing.pageHorizontal,
        AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 22,
            margin: const EdgeInsets.only(top: 4, right: 10),
            decoration: BoxDecoration(
              color: AppColors.actionRed,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: AdaptiveHeadline(
              text: title,
              minScale: 0.88,
              style: AppTypography.mobileNewsCardTitle.copyWith(
                color: headlineColor,
                letterSpacing: 0,
                height: 1.08,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.summary});

  final String summary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageHorizontal,
      ),
      child: Text(
        summary,
        style: AppTypography.mobileNewsCardSummary.copyWith(
          color: AppColors.inkSoft,
          height: 1.5,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// READ STATS
// ─────────────────────────────────────────────────────────────────────────────

class _ReadStats extends StatelessWidget {
  const _ReadStats({required this.article, required this.views});

  final NewsArticle article;
  final int views;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        AppSpacing.sm,
        AppSpacing.pageHorizontal,
        0,
      ),
      child: DefaultTextStyle.merge(
        style: AppTypography.meta.copyWith(
          color: AppColors.placeholderSoft,
          fontSize: 11.5,
          letterSpacing: 0.1,
          fontWeight: FontWeight.w500,
        ),
        child: FittedBox(
          alignment: Alignment.centerLeft,
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Symbols.menu_book_rounded,
                size: 13,
                color: AppColors.placeholderSoft,
              ),
              const SizedBox(width: 5),
              Text('${_safeReadMinutes(article.readMinutes)} dk okuma'),
              const SizedBox(width: 10),
              Container(
                width: 2.5,
                height: 2.5,
                decoration: const BoxDecoration(
                  color: AppColors.placeholderSoft,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              const Icon(
                Symbols.visibility_outlined,
                size: 13,
                color: AppColors.placeholderSoft,
              ),
              const SizedBox(width: 5),
              Text('${CountFormat.compact(views)} görüntüleme'),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COVER
// ─────────────────────────────────────────────────────────────────────────────

class _MediaStage extends StatelessWidget {
  const _MediaStage({
    required this.article,
    required this.aspectRatio,
    required this.categoryTrail,
    required this.videoFeedArticles,
    required this.shellSettings,
    required this.showHeader,
    required this.showStructuredMediaText,
    required this.authState,
    required this.postActionRepository,
    required this.onReadSignal,
    required this.onPostActionState,
    required this.onAuthRequired,
    required this.onAuthorTap,
    required this.onCopyLink,
    required this.onShare,
    required this.onReport,
    required this.onFullscreenVideoExit,
  });

  final NewsArticle article;
  final double? aspectRatio;
  final List<String> categoryTrail;
  final List<NewsArticle> videoFeedArticles;
  final AppShellSettings shellSettings;
  final bool showHeader;
  final bool showStructuredMediaText;
  final FrontendAuthState? authState;
  final PostActionRepository postActionRepository;
  final ValueChanged<String> onReadSignal;
  final ValueChanged<PostActionState> onPostActionState;
  final VoidCallback? onAuthRequired;
  final ValueChanged<NewsAuthor>? onAuthorTap;
  final ValueChanged<NewsArticle> onCopyLink;
  final ValueChanged<NewsArticle> onShare;
  final ValueChanged<NewsArticle> onReport;
  final VoidCallback? onFullscreenVideoExit;

  static const double _fallbackAspectRatio = 3 / 2;

  @override
  Widget build(BuildContext context) {
    final quote = article.quoteData;
    if (quote != null && quote.isValid) {
      return Column(
        key: const ValueKey<String>('news-card-cover-stage'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showHeader)
            _SocialArticleHeader(
              article: article,
              categoryTrail: categoryTrail,
              onAuthorTap: onAuthorTap,
              onCopyLink: onCopyLink,
              onShare: onShare,
              onReport: onReport,
            ),
          _Title(title: article.title),
          _QuoteView(data: quote),
        ],
      );
    }
    final review = article.reviewData;
    if (review != null && review.isValid) {
      return Column(
        key: const ValueKey<String>('news-card-cover-stage'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showHeader)
            _SocialArticleHeader(
              article: article,
              categoryTrail: categoryTrail,
              onAuthorTap: onAuthorTap,
              onCopyLink: onCopyLink,
              onShare: onShare,
              onReport: onReport,
            ),
          _ReviewView(
            data: review,
            summary: article.summary,
            fallbackImage: article.imageUrl,
          ),
        ],
      );
    }
    final poll = article.pollData;
    if (poll != null && poll.isValid) {
      return Column(
        key: const ValueKey<String>('news-card-cover-stage'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showHeader)
            _SocialArticleHeader(
              article: article,
              categoryTrail: categoryTrail,
              onAuthorTap: onAuthorTap,
              onCopyLink: onCopyLink,
              onShare: onShare,
              onReport: onReport,
            ),
          _PollView(
            data: poll,
            coverImage: article.imageUrl,
            headline: article.title,
            summary: article.summary,
            showQuestionText: showStructuredMediaText,
            onVoteRecorded: () => onReadSignal('poll_vote'),
          ),
        ],
      );
    }
    final vs = article.vsData;
    if (vs != null && vs.isValid) {
      return Column(
        key: const ValueKey<String>('news-card-cover-stage'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showHeader)
            _SocialArticleHeader(
              article: article,
              categoryTrail: categoryTrail,
              onAuthorTap: onAuthorTap,
              onCopyLink: onCopyLink,
              onShare: onShare,
              onReport: onReport,
            ),
          _VsView(
            data: vs,
            coverImage: article.imageUrl,
            headline: article.title,
            summary: article.summary,
            showQuestionText: showStructuredMediaText,
            onVoteRecorded: () => onReadSignal('vs_vote'),
          ),
        ],
      );
    }
    final flip = article.flipData;
    if (flip != null && flip.isValid) {
      // Flip kartta yayıncı satırı sosyal medya kartındaki gibi medyanın
      // ÜSTÜNDE ayrı bir şerit olarak durur; görselin üzerine binmez.
      return Column(
        key: const ValueKey<String>('news-card-cover-stage'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showHeader)
            _SocialArticleHeader(
              article: article,
              categoryTrail: categoryTrail,
              onAuthorTap: onAuthorTap,
              onCopyLink: onCopyLink,
              onShare: onShare,
              onReport: onReport,
            ),
          ClipRRect(
            child: _FlipCardView(
              flip: flip,
              onFlipRecorded: () => onReadSignal('flip_card'),
            ),
          ),
        ],
      );
    }
    final beforeAfter = article.beforeAfterData;
    if (beforeAfter != null && beforeAfter.isValid) {
      // Önce & Sonra kartında da yayıncı satırı medyanın üstünde ayrı şerit
      // olarak durur (sosyal medya kartıyla aynı dizilim).
      return Column(
        key: const ValueKey<String>('news-card-cover-stage'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showHeader)
            _SocialArticleHeader(
              article: article,
              categoryTrail: categoryTrail,
              onAuthorTap: onAuthorTap,
              onCopyLink: onCopyLink,
              onShare: onShare,
              onReport: onReport,
            ),
          ClipRRect(
            child: _BeforeAfterView(
              data: beforeAfter,
              onInteractionRecorded: () => onReadSignal('before_after'),
            ),
          ),
        ],
      );
    }
    if (article.socialEmbed.trim().isNotEmpty) {
      return Column(
        key: const ValueKey<String>('news-card-cover-stage'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showHeader)
            _SocialArticleHeader(
              article: article,
              categoryTrail: categoryTrail,
              onAuthorTap: onAuthorTap,
              onCopyLink: onCopyLink,
              onShare: onShare,
              onReport: onReport,
            ),
          // Sosyal medya kartında haber başlığı header'ın altında, embed'in
          // üstünde görünür (normal kartlarda başlık medyanın altında kalır).
          _Title(title: article.title),
          SocialEmbedStage(
            embed: article.socialEmbed,
            sourceUrl: article.socialSourceUrl,
            platform: article.socialPlatform,
          ),
        ],
      );
    }
    final primaryVideoUrl = article.primaryVideoUrl;
    if (primaryVideoUrl.isNotEmpty) {
      return ClipRRect(
        key: const ValueKey<String>('news-card-cover-stage'),
        child: NewsVideoPlayer(
          postId: article.id,
          url: primaryVideoUrl,
          poster: article.imageUrl,
          fullscreenLogoUrl: _fullscreenLogoUrl,
          fullscreenFeed: _videoFeedItems(),
          authState: authState,
          postActionRepository: postActionRepository,
          onViewStateChanged: onPostActionState,
          onAuthRequired: onAuthRequired,
          onAuthorTap: onAuthorTap,
          onFullscreenVideoExit: _handleFullscreenVideoExit,
          topOverlay: showHeader
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    const Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: IgnorePointer(child: _HeaderScrim()),
                    ),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: _HeaderOverlay(
                        article: article,
                        categoryTrail: categoryTrail,
                        onAuthorTap: onAuthorTap,
                        onCopyLink: onCopyLink,
                        onShare: onShare,
                        onReport: onReport,
                      ),
                    ),
                  ],
                )
              : null,
        ),
      );
    }
    if (article.audioUrl.trim().isNotEmpty) {
      return ClipRRect(
        key: const ValueKey<String>('news-card-cover-stage'),
        child: Stack(
          children: [
            NewsAudioCard(
              url: article.audioUrl,
              coverUrl: article.imageUrl,
              compactTop: !showHeader,
            ),
            if (showHeader) ...[
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: IgnorePointer(child: _HeaderScrim()),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _HeaderOverlay(
                  article: article,
                  categoryTrail: categoryTrail,
                  onAuthorTap: onAuthorTap,
                  onCopyLink: onCopyLink,
                  onShare: onShare,
                  onReport: onReport,
                ),
              ),
            ],
          ],
        ),
      );
    }
    return ClipRRect(
      key: const ValueKey<String>('news-card-cover-stage'),
      child: AspectRatio(
        aspectRatio: aspectRatio ?? _fallbackAspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (article.sliderImages.isNotEmpty)
              _MediaSlider(
                images: article.sliderImages,
                onExpand: (index) =>
                    _openImageFullscreen(context, article.sliderImages, index),
              )
            else
              _CoverImage(
                imageUrl: article.imageUrl,
                onExpand: () =>
                    _openImageFullscreen(context, [article.imageUrl], 0),
              ),
            if (showHeader) ...[
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: IgnorePointer(child: _HeaderScrim()),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _HeaderOverlay(
                  article: article,
                  categoryTrail: categoryTrail,
                  onAuthorTap: onAuthorTap,
                  onCopyLink: onCopyLink,
                  onShare: onShare,
                  onReport: onReport,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<NewsVideoFeedItem> _videoFeedItems() {
    final source = videoFeedArticles.isEmpty
        ? <NewsArticle>[article]
        : videoFeedArticles;
    final items = <NewsVideoFeedItem>[];
    for (final item in source) {
      final urls = item.videoFeedUrls;
      for (var index = 0; index < urls.length; index += 1) {
        final url = urls[index];
        final trail = item.id == article.id
            ? categoryTrail
            : _fallbackCategoryTrail(item);
        items.add(
          NewsVideoFeedItem(
            postId: item.id,
            url: url,
            poster: item.videoFeedPosterFor(url, index),
            slug: item.slug,
            publishedAt: item.publishedAt,
            title: item.title,
            author: item.author,
            region: item.region,
            category: item.category,
            categoryTrail: trail,
            likes: item.likes,
            dislikes: item.dislikes,
            comments: item.comments,
            shares: item.shares,
            saves: item.saves,
            userLiked: item.userLiked,
            userDisliked: item.userDisliked,
            userSaved: item.userSaved,
            fullscreenLogoUrl: _fullscreenLogoUrl,
            topOverlay: Stack(
              fit: StackFit.expand,
              children: [
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(child: _HeaderScrim()),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _HeaderOverlay(
                    article: item,
                    categoryTrail: trail,
                    onAuthorTap: onAuthorTap,
                    onCopyLink: onCopyLink,
                    onShare: onShare,
                    onReport: onReport,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }
    return items;
  }

  void _handleFullscreenVideoExit(NewsVideoFeedItem _) {
    onFullscreenVideoExit?.call();
  }

  /// Görsele (tek ya da slider) basılınca, videolarla birebir aynı siyah tam
  /// ekranı açar; alttaki yazar+başlık+aksiyon şeridi haberin kendi verisinden
  /// beslenir.
  void _openImageFullscreen(
    BuildContext context,
    List<String> images,
    int index,
  ) {
    showNewsImageFullscreen(
      context,
      images: images,
      initialIndex: index,
      item: _imageFullscreenItem(images),
      authState: authState,
      postActionRepository: postActionRepository,
      onAuthRequired: onAuthRequired,
      onAuthorTap: onAuthorTap,
    );
  }

  NewsVideoFeedItem _imageFullscreenItem(List<String> images) {
    final identity = images.isNotEmpty ? images.first : article.imageUrl;
    return NewsVideoFeedItem(
      postId: article.id,
      url: identity,
      poster: article.imageUrl,
      slug: article.slug,
      publishedAt: article.publishedAt,
      title: article.title,
      author: article.author,
      region: article.region,
      category: article.category,
      categoryTrail: categoryTrail,
      likes: article.likes,
      dislikes: article.dislikes,
      comments: article.comments,
      shares: article.shares,
      saves: article.saves,
      userLiked: article.userLiked,
      userDisliked: article.userDisliked,
      userSaved: article.userSaved,
      fullscreenLogoUrl: _fullscreenLogoUrl,
    );
  }

  List<String> _fallbackCategoryTrail(NewsArticle item) {
    final category = item.category.trim();
    return category.isEmpty ? const [] : <String>[category];
  }

  String get _fullscreenLogoUrl {
    return shellSettings.displayLogoUrl;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// QUOTE — ana sayfada "alıntı" bloğu: Astro'daki ParagraphCard dilinin mobil,
// kompakt karşılığı. Header ve haber başlığı mevcut mobil kart düzeninde kalır.
// ─────────────────────────────────────────────────────────────────────────────

class _QuoteView extends StatelessWidget {
  const _QuoteView({required this.data});

  final NewsQuoteData data;

  @override
  Widget build(BuildContext context) {
    final author = data.author.trim();
    final quoteText = data.text.trim();
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.softLine)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 16),
        child: Stack(
          children: [
            Positioned(
              top: -34,
              left: -12,
              child: IgnorePointer(
                child: Text(
                  '”',
                  style: AppTypography.display.copyWith(
                    color: AppColors.actionRed.withValues(alpha: 0.055),
                    fontSize: 154,
                    fontWeight: FontWeight.w900,
                    height: 0.8,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ),
            DecoratedBox(
              key: const ValueKey<String>('news-card-quote-card'),
              decoration: BoxDecoration(
                color: AppColors.surfaceInk.withValues(alpha: 0.30),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: AppColors.line.withValues(alpha: 0.70),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A101828),
                    blurRadius: 14,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                    child: Container(
                      width: 50,
                      height: 50,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.line.withValues(alpha: 0.74),
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x17101828),
                            blurRadius: 14,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Text(
                        '”',
                        style: AppTypography.display.copyWith(
                          color: AppColors.actionRed,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          height: 0.78,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            width: 3,
                            margin: const EdgeInsets.symmetric(vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.actionRed,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 27),
                          Expanded(
                            child: Text(
                              quoteText,
                              style: AppTypography.mobileNewsCardTitle.copyWith(
                                color: AppColors.supportCool,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                fontStyle: FontStyle.italic,
                                height: 1.32,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (author.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 2,
                            decoration: BoxDecoration(
                              color: AppColors.actionRed.withValues(
                                alpha: 0.22,
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _upperTr(author),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.meta.copyWith(
                                color: AppColors.supportCool.withValues(
                                  alpha: 0.62,
                                ),
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2.4,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ],
                      ),
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

// ─────────────────────────────────────────────────────────────────────────────
// REVIEW — ana sayfada "inceleme" bloğu: ürün/konu görseli, genel skor,
// artılar-eksiler, detay puanlar ve kısa karar metni. Header flipcard ile aynı
// ayrı yayıncı şeridini kullanır; içerik kompakt tutulur.
// ─────────────────────────────────────────────────────────────────────────────

class _ReviewView extends StatelessWidget {
  const _ReviewView({
    required this.data,
    required this.summary,
    required this.fallbackImage,
  });

  final NewsReviewData data;
  final String summary;
  final String fallbackImage;

  @override
  Widget build(BuildContext context) {
    final cleanSummary = summary.trim();
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.softLine)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ReviewIntro(data: data, summary: cleanSummary),
            const SizedBox(height: 12),
            _ReviewHero(data: data, fallbackImage: fallbackImage),
            if (data.pros.isNotEmpty || data.cons.isNotEmpty) ...[
              const SizedBox(height: 14),
              _ReviewProsCons(pros: data.pros, cons: data.cons),
            ],
            if (data.breakdown.isNotEmpty) ...[
              const SizedBox(height: 16),
              _ReviewBreakdown(items: data.breakdown),
            ],
            if (data.verdict.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              _ReviewVerdict(verdict: data.verdict),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReviewIntro extends StatelessWidget {
  const _ReviewIntro({required this.data, required this.summary});

  final NewsReviewData data;
  final String summary;

  @override
  Widget build(BuildContext context) {
    final title = data.productName.trim().isNotEmpty
        ? data.productName.trim()
        : 'İnceleme';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _ReviewBadge(),
        const SizedBox(height: 8),
        AdaptiveHeadline(
          text: title,
          minScale: 0.88,
          style: AppTypography.mobileNewsCardTitle.copyWith(
            color: AppColors.inkStrong,
            letterSpacing: 0,
            height: 1.08,
          ),
        ),
        if (summary.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            summary,
            style: AppTypography.mobileNewsCardSummary.copyWith(
              color: AppColors.inkSoft,
              height: 1.42,
            ),
          ),
        ],
      ],
    );
  }
}

class _ReviewHero extends StatelessWidget {
  const _ReviewHero({required this.data, required this.fallbackImage});

  final NewsReviewData data;
  final String fallbackImage;

  @override
  Widget build(BuildContext context) {
    final imageUrl = data.productImage.trim().isNotEmpty
        ? data.productImage.trim()
        : fallbackImage.trim();
    final imageFallback = Container(
      color: AppColors.surfaceInk,
      alignment: Alignment.center,
      child: const Icon(
        Symbols.image_outlined,
        color: AppColors.support,
        size: 34,
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: AspectRatio(
        key: const ValueKey<String>('news-card-review-image'),
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: const BoxDecoration(color: AppColors.surfaceInk),
              child: imageUrl.isEmpty
                  ? imageFallback
                  : PinchZoomSurface(
                      child: CachedImage(
                        url: imageUrl,
                        fit: BoxFit.contain,
                        memCacheWidth: _imageCacheWidth(context),
                        placeholderColor: AppColors.surfaceInk,
                        errorWidget: imageFallback,
                      ),
                    ),
            ),
            Positioned(
              right: 10,
              bottom: 10,
              child: _ReviewScoreBadge(
                key: const ValueKey<String>('news-card-review-score'),
                score: data.score,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewBadge extends StatelessWidget {
  const _ReviewBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.warmHorizon,
        borderRadius: BorderRadius.circular(5),
        boxShadow: [
          BoxShadow(
            color: AppColors.warmHorizon.withValues(alpha: 0.32),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        'İNCELEME',
        style: TextStyle(
          fontFamily: AppTypography.primaryFamily,
          color: Colors.white,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.4,
          height: 1,
        ),
      ),
    );
  }
}

class _ReviewScoreBadge extends StatefulWidget {
  const _ReviewScoreBadge({super.key, required this.score});

  final int score;

  @override
  State<_ReviewScoreBadge> createState() => _ReviewScoreBadgeState();
}

class _ReviewScoreBadgeState extends State<_ReviewScoreBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..repeat(reverse: true);
    _pulse = CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _reviewScoreColor(widget.score);
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final t = disableAnimations ? 0.0 : _pulse.value;
        return Transform.scale(
          scale: 1 + (t * 0.025),
          child: Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: _reviewScoreSurface(widget.score),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: color.withValues(alpha: 0.72),
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.13 + (t * 0.11)),
                  blurRadius: 16 + (t * 7),
                  spreadRadius: 0.5 + (t * 1.2),
                  offset: const Offset(0, 5),
                ),
                const BoxShadow(
                  color: Color(0x24000000),
                  blurRadius: 15,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.score.toString(),
                  style: TextStyle(
                    fontFamily: AppTypography.titleFamily,
                    color: color,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    height: 0.95,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'PUAN',
                  style: TextStyle(
                    fontFamily: AppTypography.primaryFamily,
                    color: AppColors.inkSoft,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.35,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ReviewProsCons extends StatelessWidget {
  const _ReviewProsCons({required this.pros, required this.cons});

  final List<String> pros;
  final List<String> cons;

  @override
  Widget build(BuildContext context) {
    final prosPanel = pros.isEmpty
        ? null
        : _ReviewListPanel(
            title: 'ARTILAR',
            items: pros,
            icon: Symbols.check,
            accent: AppColors.warmHorizon,
            surface: const Color(0xFFFFF8EC),
          );
    final consPanel = cons.isEmpty
        ? null
        : _ReviewListPanel(
            title: 'EKSİLER',
            items: cons,
            icon: Symbols.close,
            accent: AppColors.actionRed,
            surface: const Color(0xFFFFF3F1),
          );
    if (prosPanel != null && consPanel != null) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: prosPanel),
          const SizedBox(width: 10),
          Expanded(child: consPanel),
        ],
      );
    }
    return prosPanel ?? consPanel ?? const SizedBox.shrink();
  }
}

class _ReviewListPanel extends StatelessWidget {
  const _ReviewListPanel({
    required this.title,
    required this.items,
    required this.icon,
    required this.accent,
    required this.surface,
  });

  final String title;
  final List<String> items;
  final IconData icon;
  final Color accent;
  final Color surface;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 11, 11, 12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: Colors.white, size: 14),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTypography.primaryFamily,
                    color: AppColors.inkStrong,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (var index = 0; index < items.length; index++) ...[
            _ReviewBullet(text: items[index], icon: icon, color: accent),
            if (index != items.length - 1) const SizedBox(height: 7),
          ],
        ],
      ),
    );
  }
}

class _ReviewBullet extends StatelessWidget {
  const _ReviewBullet({
    required this.text,
    required this.icon,
    required this.color,
  });

  final String text;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1.5),
          child: Icon(icon, size: 13, color: color),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontFamily: AppTypography.primaryFamily,
              color: AppColors.ink,
              fontSize: 11.2,
              fontWeight: FontWeight.w700,
              height: 1.25,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _ReviewBreakdown extends StatelessWidget {
  const _ReviewBreakdown({required this.items});

  final List<NewsReviewCriterion> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _ReviewSectionTitle(
          title: 'DETAYLI PUANLAMA',
          icon: Symbols.format_list_numbered,
          color: AppColors.warmHorizon,
        ),
        const SizedBox(height: 10),
        for (final item in items) ...[
          _ReviewScoreRow(item: item),
          if (item != items.last) const SizedBox(height: 9),
        ],
      ],
    );
  }
}

class _ReviewScoreRow extends StatelessWidget {
  const _ReviewScoreRow({required this.item});

  final NewsReviewCriterion item;

  @override
  Widget build(BuildContext context) {
    final fraction = (item.score / 100).clamp(0.0, 1.0).toDouble();
    final color = _reviewScoreColor(item.score);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppTypography.primaryFamily,
                  color: AppColors.ink,
                  fontSize: 12.3,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${item.score}/100',
              style: TextStyle(
                fontFamily: AppTypography.primaryFamily,
                color: AppColors.inkStrong,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                height: 1.1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 7,
            value: fraction,
            backgroundColor: AppColors.surfaceInk,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _ReviewVerdict extends StatelessWidget {
  const _ReviewVerdict({required this.verdict});

  final String verdict;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.deepOcean, Color(0xFF0B0F14)],
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _ReviewSectionTitle(
            title: 'SONUÇ',
            icon: Symbols.verified,
            color: AppColors.warmHorizon,
            dark: true,
          ),
          const SizedBox(height: 10),
          Text(
            verdict,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppTypography.contentFamily,
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.44,
              fontStyle: FontStyle.italic,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewSectionTitle extends StatelessWidget {
  const _ReviewSectionTitle({
    required this.title,
    required this.icon,
    required this.color,
    this.dark = false,
  });

  final String title;
  final IconData icon;
  final Color color;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppTypography.primaryFamily,
              color: dark ? Colors.white : AppColors.inkStrong,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.25,
              height: 1.1,
            ),
          ),
        ),
      ],
    );
  }
}

Color _reviewScoreColor(int score) {
  if (score < 50) return AppColors.actionRed;
  if (score < 80) return AppColors.warmHorizon;
  return const Color(0xFF22A565);
}

Color _reviewScoreSurface(int score) {
  if (score < 50) return const Color(0xFFFFF3F1);
  if (score < 80) return const Color(0xFFFFF8EC);
  return const Color(0xFFEFFBF4);
}

// ─────────────────────────────────────────────────────────────────────────────
// POLL — ana sayfada "anket" bloğu: haber sahibi header'ı üstte, soru ve
// cevaplar altta. Oy verildikten sonra oranlar yerinde açılır; görselli
// cevaplarda metin görselin üstüne binmez.
// ─────────────────────────────────────────────────────────────────────────────

class _PollView extends StatefulWidget {
  const _PollView({
    required this.data,
    required this.coverImage,
    required this.headline,
    required this.summary,
    required this.showQuestionText,
    required this.onVoteRecorded,
  });

  final NewsPollData data;
  final String coverImage;
  final String headline;
  final String summary;
  final bool showQuestionText;
  final VoidCallback onVoteRecorded;

  @override
  State<_PollView> createState() => _PollViewState();
}

class _PollViewState extends State<_PollView> {
  String? _selectedOptionId;

  void _vote(NewsPollOption option) {
    if (_selectedOptionId != null) return;
    setState(() => _selectedOptionId = option.id);
    widget.onVoteRecorded();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final coverImage = widget.coverImage.trim();
    final headline = widget.headline.trim();
    final summary = widget.summary.trim();
    final hasVoted = _selectedOptionId != null;
    final totalVotes = data.resolvedTotalVotes + (hasVoted ? 1 : 0);
    final description = data.description.trim();

    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.surface),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (headline.isNotEmpty || summary.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (headline.isNotEmpty)
                    AdaptiveHeadline(
                      text: headline,
                      minScale: 0.88,
                      style: AppTypography.mobileNewsCardTitle.copyWith(
                        color: AppColors.inkStrong,
                        letterSpacing: 0,
                        height: 1.08,
                      ),
                    ),
                  if (summary.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      summary,
                      style: AppTypography.mobileNewsCardSummary.copyWith(
                        color: AppColors.inkSoft,
                        height: 1.42,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          if (coverImage.isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(
                14,
                headline.isNotEmpty || summary.isNotEmpty ? 0 : 14,
                14,
                0,
              ),
              child: _PollCover(imageUrl: coverImage),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.showQuestionText) ...[
                  AdaptiveHeadline(
                    text: data.title,
                    minScale: 0.88,
                    style: AppTypography.mobileNewsCardTitle.copyWith(
                      fontSize: 24,
                      height: 1.08,
                      letterSpacing: 0,
                    ),
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 9),
                    Text(
                      description,
                      style: AppTypography.mobileNewsCardSummary.copyWith(
                        fontSize: 13.5,
                        height: 1.48,
                        color: AppColors.inkSoft.withValues(alpha: 0.78),
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 6),
                if (data.isImagePoll)
                  _PollImageOptionsGrid(
                    data: data,
                    selectedOptionId: _selectedOptionId,
                    totalVotes: totalVotes,
                    onVote: _vote,
                  )
                else
                  _PollListOptions(
                    data: data,
                    selectedOptionId: _selectedOptionId,
                    totalVotes: totalVotes,
                    onVote: _vote,
                  ),
                const SizedBox(height: 14),
                _PollFooter(totalVotes: totalVotes, hasVoted: hasVoted),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PollCover extends StatelessWidget {
  const _PollCover({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PinchZoomSurface(
              child: CachedImage(
                url: imageUrl,
                fit: BoxFit.contain,
                memCacheWidth: _imageCacheWidth(context),
                placeholderColor: AppColors.surfaceInk,
                errorWidget: const _PollImageFallback(),
              ),
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 66,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Color(0x730B0F14), Color(0x000B0F14)],
                    ),
                  ),
                ),
              ),
            ),
            const Positioned(right: 8, bottom: 8, child: _PollMediaPill()),
          ],
        ),
      ),
    );
  }
}

class _PollMediaPill extends StatelessWidget {
  const _PollMediaPill();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(9, 5, 11, 5),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.36),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Symbols.apps_fill, color: Colors.white, size: 12),
              SizedBox(width: 6),
              Text(
                'Anket',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.1,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PollImageOptionsGrid extends StatelessWidget {
  const _PollImageOptionsGrid({
    required this.data,
    required this.selectedOptionId,
    required this.totalVotes,
    required this.onVote,
  });

  final NewsPollData data;
  final String? selectedOptionId;
  final int totalVotes;
  final ValueChanged<NewsPollOption> onVote;

  @override
  Widget build(BuildContext context) {
    final columns = data.columns == 3 ? 3 : 2;
    final spacing = columns == 3 ? 6.0 : 8.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (width <= 0) return const SizedBox.shrink();
        final itemWidth = (width - (columns - 1) * spacing) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: 8,
          children: [
            for (var index = 0; index < data.options.length; index++)
              SizedBox(
                width: itemWidth,
                child: _PollImageOption(
                  option: data.options[index],
                  index: index,
                  selected: selectedOptionId == data.options[index].id,
                  hasVoted: selectedOptionId != null,
                  totalVotes: totalVotes,
                  compact: columns == 3,
                  onTap: () => onVote(data.options[index]),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PollImageOption extends StatelessWidget {
  const _PollImageOption({
    required this.option,
    required this.index,
    required this.selected,
    required this.hasVoted,
    required this.totalVotes,
    required this.compact,
    required this.onTap,
  });

  final NewsPollOption option;
  final int index;
  final bool selected;
  final bool hasVoted;
  final int totalVotes;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final votes = option.votes + (selected && hasVoted ? 1 : 0);
    final percent = _pollPercent(votes, totalVotes);
    final muted = hasVoted && !selected;
    final imageUrl = option.imageUrl.trim();

    return Semantics(
      button: true,
      selected: selected,
      label: option.text,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 360),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0, selected ? -2 : 0, 0),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFFFF8EE) : AppColors.surface,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: selected
                  ? AppColors.warmHorizon
                  : muted
                  ? AppColors.softLine
                  : AppColors.line,
              width: selected ? 1.4 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: selected
                    ? AppColors.warmHorizon.withValues(alpha: 0.22)
                    : AppColors.shadow,
                blurRadius: selected ? 22 : 10,
                offset: Offset(0, selected ? 9 : 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Opacity(
            opacity: muted ? 0.74 : 1,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: compact ? 106 : 128,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      DecoratedBox(
                        decoration: const BoxDecoration(
                          color: AppColors.surfaceSoft,
                        ),
                        child: imageUrl.isEmpty
                            ? const _PollImageFallback()
                            : CachedImage(
                                url: imageUrl,
                                fit: BoxFit.contain,
                                memCacheWidth: _imageCacheWidth(context),
                                errorWidget: const _PollImageFallback(),
                              ),
                      ),
                      Positioned(
                        left: 9,
                        top: 9,
                        child: _PollOptionNumber(index: index),
                      ),
                      Positioned(
                        right: 6,
                        top: 6,
                        child: _PollPercentChip(
                          percent: hasVoted ? percent : 0,
                          selected: selected,
                        ),
                      ),
                      Positioned(
                        left: 7,
                        bottom: 7,
                        child: _PollRadioMark(
                          selected: selected,
                          size: 18,
                          iconSize: 11,
                          borderWidth: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    compact ? 9 : 11,
                    compact ? 10 : 11,
                    compact ? 9 : 11,
                    8,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              option.text,
                              maxLines: compact ? 6 : 5,
                              style: TextStyle(
                                fontFamily: AppTypography.contentFamily,
                                color: selected
                                    ? AppColors.inkStrong
                                    : AppColors.ink,
                                fontSize: compact ? 11.7 : 13.4,
                                fontWeight: selected
                                    ? FontWeight.w800
                                    : FontWeight.w700,
                                height: 1.14,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Align(
                        alignment: Alignment.centerRight,
                        child: _PollVoteCaption(
                          key: ValueKey<String>('votes-${option.id}-$votes'),
                          votes: votes,
                          selected: selected,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PollListOptions extends StatelessWidget {
  const _PollListOptions({
    required this.data,
    required this.selectedOptionId,
    required this.totalVotes,
    required this.onVote,
  });

  final NewsPollData data;
  final String? selectedOptionId;
  final int totalVotes;
  final ValueChanged<NewsPollOption> onVote;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < data.options.length; i++) ...[
          _PollListOption(
            option: data.options[i],
            index: i,
            selected: selectedOptionId == data.options[i].id,
            hasVoted: selectedOptionId != null,
            totalVotes: totalVotes,
            onTap: () => onVote(data.options[i]),
          ),
          if (i != data.options.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _PollListOption extends StatelessWidget {
  const _PollListOption({
    required this.option,
    required this.index,
    required this.selected,
    required this.hasVoted,
    required this.totalVotes,
    required this.onTap,
  });

  final NewsPollOption option;
  final int index;
  final bool selected;
  final bool hasVoted;
  final int totalVotes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final votes = option.votes + (selected && hasVoted ? 1 : 0);
    final percent = _pollPercent(votes, totalVotes);
    final progress = totalVotes <= 0 ? 0.0 : votes / totalVotes;

    return Semantics(
      button: true,
      selected: selected,
      label: option.text,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFFFF8EE) : AppColors.surface,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: selected
                  ? AppColors.warmHorizon
                  : hasVoted
                  ? AppColors.softLine
                  : AppColors.line,
              width: selected ? 1.4 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: selected
                    ? AppColors.warmHorizon.withValues(alpha: 0.17)
                    : AppColors.shadow,
                blurRadius: selected ? 18 : 9,
                offset: Offset(0, selected ? 8 : 3),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              if (hasVoted)
                Positioned.fill(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(
                      begin: 0,
                      end: progress.clamp(0.0, 1.0).toDouble(),
                    ),
                    duration: const Duration(milliseconds: 950),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) {
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: value,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.warmHorizon.withValues(
                                      alpha: 0.16,
                                    )
                                  : AppColors.surfaceInk,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(15, 14, 13, 14),
                child: Row(
                  children: [
                    _PollRadioMark(selected: selected),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        option.text,
                        style: TextStyle(
                          fontFamily: AppTypography.contentFamily,
                          color: selected ? AppColors.inkStrong : AppColors.ink,
                          fontSize: 15,
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w700,
                          height: 1.25,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                    if (hasVoted) ...[
                      const SizedBox(width: 12),
                      _PollResultText(
                        percent: percent,
                        votes: votes,
                        selected: selected,
                      ),
                    ] else ...[
                      const SizedBox(width: 8),
                      _PollVoteCaption(votes: votes, selected: false),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PollRadioMark extends StatelessWidget {
  const _PollRadioMark({
    required this.selected,
    this.size = 22,
    this.iconSize = 14,
    this.borderWidth = 2,
  });

  final bool selected;
  final double size;
  final double iconSize;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: selected ? AppColors.warmHorizon : AppColors.surface,
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AppColors.warmHorizon : AppColors.line,
          width: borderWidth,
        ),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: selected
            ? Icon(
                Symbols.check_rounded,
                key: const ValueKey<String>('poll-check'),
                color: Colors.white,
                size: iconSize,
              )
            : const SizedBox.shrink(key: ValueKey<String>('poll-empty')),
      ),
    );
  }
}

class _PollPercentChip extends StatelessWidget {
  const _PollPercentChip({required this.percent, required this.selected});

  final int percent;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.deepOcean.withValues(alpha: 0.92)
            : Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2A000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: _AnimatedPollPercentText(
        percent: percent,
        color: selected ? Colors.white : AppColors.inkStrong,
        fontSize: 12,
      ),
    );
  }
}

class _PollResultText extends StatelessWidget {
  const _PollResultText({
    required this.percent,
    required this.votes,
    required this.selected,
  });

  final int percent;
  final int votes;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      child: Column(
        key: ValueKey<String>('poll-result-$percent-$votes-$selected'),
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          _AnimatedPollPercentText(
            percent: percent,
            color: selected ? AppColors.deepOcean : AppColors.inkSoft,
            fontSize: 17,
          ),
          const SizedBox(height: 3),
          Text(
            '${CountFormat.compact(votes)} oy',
            style: TextStyle(
              fontFamily: AppTypography.primaryFamily,
              color: AppColors.support,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              height: 1,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedPollPercentText extends StatelessWidget {
  const _AnimatedPollPercentText({
    required this.percent,
    required this.color,
    required this.fontSize,
  });

  final int percent;
  final Color color;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: percent.toDouble()),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return Text(
          '%${value.round().clamp(0, 100)}',
          style: TextStyle(
            fontFamily: AppTypography.primaryFamily,
            color: color,
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            height: 1,
            letterSpacing: 0,
          ),
        );
      },
    );
  }
}

class _PollVoteCaption extends StatelessWidget {
  const _PollVoteCaption({
    super.key,
    required this.votes,
    required this.selected,
  });

  final int votes;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Symbols.group,
          size: 13,
          color: selected ? AppColors.deepOcean : AppColors.support,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            '${CountFormat.compact(votes)} oy',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppTypography.primaryFamily,
              color: selected ? AppColors.deepOcean : AppColors.support,
              fontSize: 10.8,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
              height: 1,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _PollOptionNumber extends StatelessWidget {
  const _PollOptionNumber({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 25,
      height: 25,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.90),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.softLine),
      ),
      child: Text(
        '${index + 1}',
        style: TextStyle(
          fontFamily: AppTypography.primaryFamily,
          color: AppColors.ink,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          height: 1,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _PollFooter extends StatelessWidget {
  const _PollFooter({required this.totalVotes, required this.hasVoted});

  final int totalVotes;
  final bool hasVoted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.softLine),
      ),
      child: Row(
        children: [
          const Icon(Symbols.group, color: AppColors.support, size: 16),
          const SizedBox(width: 7),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              child: Text(
                '${CountFormat.compact(totalVotes)} katılımcı',
                key: ValueKey<int>(totalVotes),
                style: TextStyle(
                  fontFamily: AppTypography.primaryFamily,
                  color: AppColors.support,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  height: 1,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            child: hasVoted
                ? Row(
                    key: const ValueKey<String>('poll-voted'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Symbols.check_rounded,
                        size: 14,
                        color: AppColors.warmHorizon,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Oyun alındı',
                        style: TextStyle(
                          fontFamily: AppTypography.primaryFamily,
                          color: AppColors.deepOcean,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          height: 1,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  )
                : Text(
                    'Oy ver',
                    key: const ValueKey<String>('poll-open'),
                    style: TextStyle(
                      fontFamily: AppTypography.primaryFamily,
                      color: AppColors.deepOcean,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      height: 1,
                      letterSpacing: 0,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VS / DÜELLO — ana sayfada seçili düello bloğu: anketle aynı haber başlığı
// akışını kullanır; alttaki arena Astro'daki 50/50, merkez VS ve oy sonrası
// oran animasyonunu mobil kart diline taşır.
// ─────────────────────────────────────────────────────────────────────────────

class _VsView extends StatefulWidget {
  const _VsView({
    required this.data,
    required this.coverImage,
    required this.headline,
    required this.summary,
    required this.showQuestionText,
    required this.onVoteRecorded,
  });

  final NewsVsData data;
  final String coverImage;
  final String headline;
  final String summary;
  final bool showQuestionText;
  final VoidCallback onVoteRecorded;

  @override
  State<_VsView> createState() => _VsViewState();
}

class _VsViewState extends State<_VsView> {
  String? _selectedOptionId;

  void _vote(NewsVsOption option) {
    if (_selectedOptionId != null) return;
    setState(() => _selectedOptionId = option.id);
    widget.onVoteRecorded();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final coverImage = widget.coverImage.trim();
    final headline = widget.headline.trim();
    final summary = widget.summary.trim();
    final description = data.description.trim();
    final hasVoted = _selectedOptionId != null;
    final totalVotes = data.resolvedTotalVotes + (hasVoted ? 1 : 0);

    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.surface),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (headline.isNotEmpty || summary.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (headline.isNotEmpty)
                    AdaptiveHeadline(
                      text: headline,
                      minScale: 0.88,
                      style: AppTypography.mobileNewsCardTitle.copyWith(
                        color: AppColors.inkStrong,
                        letterSpacing: 0,
                        height: 1.08,
                      ),
                    ),
                  if (summary.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      summary,
                      style: AppTypography.mobileNewsCardSummary.copyWith(
                        color: AppColors.inkSoft,
                        height: 1.42,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          if (coverImage.isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(
                14,
                headline.isNotEmpty || summary.isNotEmpty ? 0 : 14,
                14,
                0,
              ),
              child: _VsCover(imageUrl: coverImage),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.showQuestionText) ...[
                  AdaptiveHeadline(
                    text: data.title,
                    minScale: 0.88,
                    style: AppTypography.mobileNewsCardTitle.copyWith(
                      fontSize: 24,
                      height: 1.08,
                      letterSpacing: 0,
                    ),
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 9),
                    Text(
                      description,
                      style: AppTypography.mobileNewsCardSummary.copyWith(
                        fontSize: 13.5,
                        height: 1.48,
                        color: AppColors.inkSoft.withValues(alpha: 0.78),
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 10),
                _VsArena(
                  data: data,
                  selectedOptionId: _selectedOptionId,
                  totalVotes: totalVotes,
                  onVote: _vote,
                ),
                const SizedBox(height: 14),
                _VsFooter(totalVotes: totalVotes, hasVoted: hasVoted),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VsCover extends StatelessWidget {
  const _VsCover({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PinchZoomSurface(
              child: CachedImage(
                url: imageUrl,
                fit: BoxFit.contain,
                memCacheWidth: _imageCacheWidth(context),
                placeholderColor: AppColors.surfaceInk,
                errorWidget: const _PollImageFallback(),
              ),
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 66,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Color(0x730B0F14), Color(0x000B0F14)],
                    ),
                  ),
                ),
              ),
            ),
            const Positioned(right: 8, bottom: 8, child: _VsMediaPill()),
          ],
        ),
      ),
    );
  }
}

class _VsMediaPill extends StatelessWidget {
  const _VsMediaPill();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(9, 5, 11, 5),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.36),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Symbols.bolt_rounded, color: Colors.white, size: 12),
              SizedBox(width: 6),
              Text(
                'Düello',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.1,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VsArena extends StatelessWidget {
  const _VsArena({
    required this.data,
    required this.selectedOptionId,
    required this.totalVotes,
    required this.onVote,
  });

  final NewsVsData data;
  final String? selectedOptionId;
  final int totalVotes;
  final ValueChanged<NewsVsOption> onVote;

  @override
  Widget build(BuildContext context) {
    final left = data.options[0];
    final right = data.options[1];
    final hasVoted = selectedOptionId != null;
    final leftVotes = left.votes + (selectedOptionId == left.id ? 1 : 0);
    final rightVotes = right.votes + (selectedOptionId == right.id ? 1 : 0);
    final leftPercent = totalVotes <= 0
        ? 50
        : _pollPercent(leftVotes, totalVotes);
    final rightPercent = totalVotes <= 0 ? 50 : 100 - leftPercent;
    final leftFraction = (leftPercent / 100).clamp(0.0, 1.0).toDouble();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (width <= 0) return const SizedBox.shrink();
        const dividerWidth = 4.0;
        const badgeSize = 52.0;
        final height = width / 2;
        final leftWidth = width * leftFraction;
        final rightWidth = width - leftWidth;
        final dividerLeft = (leftWidth - (dividerWidth / 2))
            .clamp(0.0, width - dividerWidth)
            .toDouble();
        final badgeLeft = (leftWidth - (badgeSize / 2))
            .clamp(8.0, width - badgeSize - 8.0)
            .toDouble();
        return ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            key: const ValueKey<String>('news-card-vs-arena'),
            height: height,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 620),
                      curve: Curves.easeOutCubic,
                      width: leftWidth,
                      child: _VsOptionPane(
                        option: left,
                        side: _VsSide.left,
                        selected: selectedOptionId == left.id,
                        muted: hasVoted && selectedOptionId != left.id,
                        hasVoted: hasVoted,
                        percent: leftPercent,
                        votes: leftVotes,
                        onTap: () => onVote(left),
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 620),
                      curve: Curves.easeOutCubic,
                      width: rightWidth,
                      child: _VsOptionPane(
                        option: right,
                        side: _VsSide.right,
                        selected: selectedOptionId == right.id,
                        muted: hasVoted && selectedOptionId != right.id,
                        hasVoted: hasVoted,
                        percent: rightPercent,
                        votes: rightVotes,
                        onTap: () => onVote(right),
                      ),
                    ),
                  ],
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 620),
                  curve: Curves.easeOutCubic,
                  left: dividerLeft,
                  top: 0,
                  bottom: 0,
                  width: dividerWidth,
                  child: const _VsDivider(),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 620),
                  curve: Curves.easeOutCubic,
                  left: badgeLeft,
                  top: 0,
                  bottom: 0,
                  width: badgeSize,
                  child: const _VsCenterBadge(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

enum _VsSide { left, right }

class _VsDivider extends StatelessWidget {
  const _VsDivider();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: AppColors.actionRed.withValues(alpha: 0.35),
            blurRadius: 13,
            spreadRadius: 1,
          ),
        ],
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.10),
            Colors.white.withValues(alpha: 0.84),
            AppColors.actionRed.withValues(alpha: 0.96),
            Colors.white.withValues(alpha: 0.84),
            Colors.white.withValues(alpha: 0.10),
          ],
          stops: const [0, 0.28, 0.50, 0.72, 1],
        ),
      ),
    );
  }
}

class _VsOptionPane extends StatelessWidget {
  const _VsOptionPane({
    required this.option,
    required this.side,
    required this.selected,
    required this.muted,
    required this.hasVoted,
    required this.percent,
    required this.votes,
    required this.onTap,
  });

  final NewsVsOption option;
  final _VsSide side;
  final bool selected;
  final bool muted;
  final bool hasVoted;
  final int percent;
  final int votes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final imageUrl = option.imageUrl.trim();
    final labelAlignment = side == _VsSide.left
        ? CrossAxisAlignment.start
        : CrossAxisAlignment.end;
    final labelTextAlign = side == _VsSide.left
        ? TextAlign.left
        : TextAlign.right;

    return Semantics(
      button: true,
      selected: selected,
      label: option.text,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: hasVoted ? null : onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.deepOcean.withValues(alpha: 0.92),
              ),
              child: imageUrl.isEmpty
                  ? const _PollImageFallback()
                  : CachedImage(
                      url: imageUrl,
                      fit: BoxFit.contain,
                      memCacheWidth: _imageCacheWidth(context),
                      placeholderColor: AppColors.surfaceInk,
                      errorWidget: const _PollImageFallback(),
                    ),
            ),
            if (!hasVoted)
              Positioned(
                top: 8,
                left: side == _VsSide.left ? 8 : null,
                right: side == _VsSide.right ? 8 : null,
                child: const _VsVotePrompt(),
              ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: muted ? 0.72 : 1,
                child: Column(
                  crossAxisAlignment: labelAlignment,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _sentenceCaseTr(option.text),
                      maxLines: hasVoted ? 3 : 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: labelTextAlign,
                      style: TextStyle(
                        fontFamily: AppTypography.primaryFamily,
                        color: Colors.white,
                        fontSize: 9.3,
                        fontWeight: FontWeight.w800,
                        height: 1.14,
                        letterSpacing: 0,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.96),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.76),
                            blurRadius: 12,
                          ),
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.46),
                            blurRadius: 22,
                          ),
                        ],
                      ),
                    ),
                    if (hasVoted) ...[
                      const SizedBox(height: 8),
                      _AnimatedVsPercentText(
                        percent: percent,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 5),
                      _VsVoteChip(votes: votes, selected: selected),
                    ],
                  ],
                ),
              ),
            ),
            if (selected)
              Positioned(
                top: 9,
                right: side == _VsSide.right ? 9 : null,
                left: side == _VsSide.left ? 9 : null,
                child: const _VsSelectedMark(),
              ),
          ],
        ),
      ),
    );
  }
}

class _VsVotePrompt extends StatefulWidget {
  const _VsVotePrompt();

  @override
  State<_VsVotePrompt> createState() => _VsVotePromptState();
}

class _VsVotePromptState extends State<_VsVotePrompt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: true);
    _pulse = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final value = _pulse.value;
        return Opacity(
          opacity: 0.86 + (value * 0.14),
          child: Transform.translate(
            offset: Offset(0, -1.6 * value),
            child: Transform.scale(scale: 1 + (value * 0.035), child: child),
          ),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Symbols.cursor_hand,
            color: AppColors.actionRed,
            size: 14,
            shadows: [
              Shadow(
                color: AppColors.warmHorizon.withValues(alpha: 0.62),
                blurRadius: 7,
              ),
              Shadow(
                color: Colors.black.withValues(alpha: 0.36),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Tıkla Oy\nKullan',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTypography.primaryFamily,
              color: Colors.white,
              fontSize: 9.4,
              fontWeight: FontWeight.w900,
              height: 1.02,
              letterSpacing: 0,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.78),
                  blurRadius: 5,
                  offset: const Offset(0, 1),
                ),
                Shadow(
                  color: AppColors.actionRed.withValues(alpha: 0.68),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VsCenterBadge extends StatelessWidget {
  const _VsCenterBadge();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.34),
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Transform.rotate(
          angle: math.pi / 4,
          child: Container(
            width: 48,
            height: 48,
            padding: const EdgeInsets.all(2.4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.actionRed.withValues(alpha: 0.28),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6.5),
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.deepOcean,
                      AppColors.actionRed,
                      AppColors.warmHorizon,
                    ],
                  ),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withValues(alpha: 0.20),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.20),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: Transform.rotate(
                        angle: -math.pi / 4,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Icon(
                              Symbols.bolt_rounded,
                              color: Colors.white.withValues(alpha: 0.16),
                              size: 31,
                            ),
                            Text(
                              'VS',
                              style: TextStyle(
                                fontFamily: AppTypography.titleFamily,
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                fontStyle: FontStyle.italic,
                                height: 1,
                                letterSpacing: 0,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withValues(alpha: 0.45),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
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
          ),
        ),
      ),
    );
  }
}

class _AnimatedVsPercentText extends StatelessWidget {
  const _AnimatedVsPercentText({required this.percent, required this.color});

  final int percent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: percent.toDouble()),
      duration: const Duration(milliseconds: 950),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return Text(
          '${value.round().clamp(0, 100)}%',
          style: TextStyle(
            fontFamily: AppTypography.titleFamily,
            color: color,
            fontSize: 35,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            height: 0.95,
            letterSpacing: 0,
          ),
        );
      },
    );
  }
}

class _VsVoteChip extends StatelessWidget {
  const _VsVoteChip({required this.votes, required this.selected});

  final int votes;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: selected ? 0.20 : 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Text(
        '${CountFormat.compact(votes)} oy',
        style: TextStyle(
          fontFamily: AppTypography.primaryFamily,
          color: Colors.white.withValues(alpha: 0.86),
          fontSize: 10.3,
          fontWeight: FontWeight.w900,
          height: 1,
          letterSpacing: 0.25,
        ),
      ),
    );
  }
}

class _VsSelectedMark extends StatelessWidget {
  const _VsSelectedMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 27,
      height: 27,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.actionRed,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.actionRed.withValues(alpha: 0.30),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: const Icon(Symbols.check_rounded, color: Colors.white, size: 14),
    );
  }
}

class _VsFooter extends StatelessWidget {
  const _VsFooter({required this.totalVotes, required this.hasVoted});

  final int totalVotes;
  final bool hasVoted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.softLine),
      ),
      child: Row(
        children: [
          const Icon(Symbols.group, color: AppColors.support, size: 16),
          const SizedBox(width: 7),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              child: Text(
                '${CountFormat.compact(totalVotes)} oy verildi',
                key: ValueKey<int>(totalVotes),
                style: TextStyle(
                  fontFamily: AppTypography.primaryFamily,
                  color: AppColors.support,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  height: 1,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            child: hasVoted
                ? Row(
                    key: const ValueKey<String>('vs-voted'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Symbols.check_rounded,
                        size: 14,
                        color: AppColors.actionRed,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Oyun alındı',
                        style: TextStyle(
                          fontFamily: AppTypography.primaryFamily,
                          color: AppColors.deepOcean,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          height: 1,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  )
                : Text(
                    'Tarafını seç',
                    key: const ValueKey<String>('vs-open'),
                    style: TextStyle(
                      fontFamily: AppTypography.primaryFamily,
                      color: AppColors.deepOcean,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      height: 1,
                      letterSpacing: 0,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _PollImageFallback extends StatelessWidget {
  const _PollImageFallback();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.surfaceSoft,
      child: Center(
        child: Icon(Symbols.image_outlined, color: AppColors.support, size: 28),
      ),
    );
  }
}

int _pollPercent(int votes, int totalVotes) {
  if (totalVotes <= 0) return 0;
  return math.min(100, math.max(0, ((votes / totalVotes) * 100).round()));
}

String _sentenceCaseTr(String value) {
  final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (normalized.isEmpty) return '';
  final lower = normalized
      .replaceAll('İ', 'i')
      .replaceAll('I', 'ı')
      .toLowerCase();
  final first = lower.substring(0, 1);
  final firstUpper = first == 'i'
      ? 'İ'
      : first == 'ı'
      ? 'I'
      : first.toUpperCase();
  return '$firstUpper${lower.substring(1)}';
}

// ─────────────────────────────────────────────────────────────────────────────
// FLIP CARD — ana sayfada "flip kart" bloğu için çevrilebilir görsel.
//
// Tasarım dili: görsel ön planda, metin minimum. Tek dokunuşla ön/arka yüz
// arası 3B döner. Dokunma affordance'ı iki katmanlıdır:
//  1) Alt köşedeki cam rozet ("Çevirmek için dokun") — içindeki dönme ikonu
//     birkaç saniyede bir tur atıp accent halesiyle göz kırpar.
//  2) Zaman zaman kartın ortasında beliren kılavuz pill'i — tam ekran
//     videodaki "Yukarı kaydır" kılavuzuyla aynı cam panel dili ve tempoda
//     (açılışta uzun, sonra ara ara kısa). Kart bir kez çevrilince kalıcı
//     olarak susar; kullanıcı jesti öğrenmiştir.
// ─────────────────────────────────────────────────────────────────────────────

// Kılavuz ritmi tam ekran video kılavuzuyla aynı tempoyu kullanır.
const Duration _kFlipCoachOpenDuration = Duration(milliseconds: 3600);
const Duration _kFlipCoachPulseDuration = Duration(milliseconds: 2600);
const Duration _kFlipCoachRepeatInterval = Duration(seconds: 13);

class _FlipCardView extends StatefulWidget {
  const _FlipCardView({required this.flip, required this.onFlipRecorded});

  final NewsFlipData flip;
  final VoidCallback onFlipRecorded;

  @override
  State<_FlipCardView> createState() => _FlipCardViewState();
}

class _FlipCardViewState extends State<_FlipCardView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _coachTimer;
  Timer? _coachRepeat;
  bool _showingFront = true;
  bool _showCoach = false;
  bool _hasFlipped = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );
    // Kılavuz kart ekrana gelir gelmez belirir, sonra ara ara hatırlatır.
    _coachTimer = Timer(
      Duration.zero,
      () => _revealCoach(_kFlipCoachOpenDuration),
    );
    _coachRepeat = Timer.periodic(
      _kFlipCoachRepeatInterval,
      (_) => _revealCoach(_kFlipCoachPulseDuration),
    );
  }

  void _revealCoach(Duration visibleFor) {
    if (!mounted || _hasFlipped) return;
    setState(() => _showCoach = true);
    _coachTimer?.cancel();
    _coachTimer = Timer(visibleFor, () {
      if (mounted && _showCoach) setState(() => _showCoach = false);
    });
  }

  @override
  void dispose() {
    _coachTimer?.cancel();
    _coachRepeat?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _flip() {
    if (_controller.isAnimating) return;
    final firstFlip = !_hasFlipped;
    if (_showingFront) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    // İlk çevirmeyle birlikte kılavuz görevini tamamlar ve kalıcı susar.
    _hasFlipped = true;
    _coachTimer?.cancel();
    _coachRepeat?.cancel();
    setState(() {
      _showingFront = !_showingFront;
      _showCoach = false;
    });
    if (firstFlip) widget.onFlipRecorded();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Haber kartı, çevirmek için dokun',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _flip,
        child: AspectRatio(
          aspectRatio: 4 / 5,
          child: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final angle = _controller.value * math.pi;
                  final showFront = angle <= math.pi / 2;
                  final Widget face = showFront
                      ? _FlipFace(
                          image: widget.flip.frontImage,
                          title: widget.flip.frontTitle,
                          description: widget.flip.frontDescription,
                        )
                      : Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()..rotateY(math.pi),
                          child: _FlipFace(
                            image: widget.flip.backImage,
                            title: widget.flip.backTitle,
                            description: widget.flip.backDescription,
                          ),
                        );
                  return Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.0012)
                      ..rotateY(angle),
                    child: face,
                  );
                },
              ),
              // Zaman zaman beliren dokunma kılavuzu. IgnorePointer sayesinde
              // dokunuş karta geçer; kılavuz görünürken bile kart çevrilir.
              IgnorePointer(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 340),
                  reverseDuration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, animation) {
                    final fade = CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOut,
                    );
                    final scale = Tween<double>(begin: 0.88, end: 1).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutBack,
                      ),
                    );
                    return FadeTransition(
                      opacity: fade,
                      child: ScaleTransition(scale: scale, child: child),
                    );
                  },
                  child: _showCoach
                      ? const Align(
                          key: ValueKey('flip-coach-on'),
                          alignment: Alignment(0, -0.12),
                          child: _FlipCoachCard(),
                        )
                      : const SizedBox.shrink(key: ValueKey('flip-coach-off')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FlipFace extends StatelessWidget {
  const _FlipFace({
    required this.image,
    required this.title,
    this.description = '',
  });

  final String image;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final desc = description.trim();
    return Stack(
      fit: StackFit.expand,
      children: [
        PinchZoomSurface(
          child: CachedImage(url: image, fit: BoxFit.cover),
        ),
        // Görseli boğmayan, yalnızca alt şeridi yumuşatan ince gradyan.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.center,
              colors: [Color(0xCC0B0F14), Color(0x000B0F14)],
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 14,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const _FlipBadge(),
              const SizedBox(height: 9),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppTypography.titleFamily,
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  height: 1.12,
                  letterSpacing: 0,
                  shadows: const [
                    Shadow(color: Color(0x99000000), blurRadius: 14),
                  ],
                ),
              ),
              // Açıklama: iki satırla sınırlı, yumuşak beyaz — başlığı
              // destekler ama görseli boğmaz.
              if (desc.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  desc,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTypography.primaryFamily,
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    height: 1.32,
                    letterSpacing: 0.05,
                    shadows: const [
                      Shadow(color: Color(0x99000000), blurRadius: 12),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Alt köşedeki "Çevirmek için dokun" rozeti — canlı yayın rozetiyle aynı
/// marka dili: Güçlü Kırmızı zemin, beyaz metin. Birkaç saniyede bir kalp
/// atışı gibi çift vuruşla hafifçe büyüyüp söner; aynı anda içindeki dönme
/// ikonu tam tur atar. (Eski sağ-üst köşe ikonunun yeni, anlamlı evi.)
class _FlipBadge extends StatefulWidget {
  const _FlipBadge();

  @override
  State<_FlipBadge> createState() => _FlipBadgeState();
}

class _FlipBadgeState extends State<_FlipBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _beat;
  late final Animation<double> _scale;
  Timer? _next;

  @override
  void initState() {
    super.initState();
    _beat = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1150),
    );
    // Kalp atışı: güçlü vuruş + yumuşak ikinci vuruş, sonra dinlenme.
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 1.07,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 14,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.07,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 18,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 8),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 1.045,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 14,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.045,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 22,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 24),
    ]).animate(_beat);
    _kickBeat();
  }

  void _kickBeat() {
    if (mounted) _beat.forward(from: 0);
    _next = Timer(const Duration(milliseconds: 3400), _kickBeat);
  }

  @override
  void dispose() {
    _next?.cancel();
    _beat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        padding: const EdgeInsets.fromLTRB(9, 5.5, 13, 5.5),
        decoration: BoxDecoration(
          color: AppColors.actionRed,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.32)),
          boxShadow: [
            BoxShadow(
              color: AppColors.actionRed.withValues(alpha: 0.40),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
            const BoxShadow(
              color: Color(0x33000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _beat,
              builder: (context, _) {
                final t = Curves.easeInOutCubic.transform(_beat.value);
                return Transform.rotate(
                  angle: t * 2 * math.pi,
                  child: const Icon(
                    Symbols.refresh_line,
                    size: 12.5,
                    color: Colors.white,
                  ),
                );
              },
            ),
            const SizedBox(width: 7),
            const Text(
              'Çevirmek için dokun',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Zaman zaman beliren dokunma kılavuzu — tam ekran videodaki "Yukarı kaydır"
/// pill'iyle aynı marka camı: Derin Okyanus'tan koyuya degrade, ince beyaz
/// kenar, yumuşak derin gölge. Tüm jest kılavuzları aynı dili konuşur.
class _FlipCoachCard extends StatelessWidget {
  const _FlipCoachCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 9, 19, 9),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xD92C3E50), Color(0xF20B0F14)],
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _FlipCoachGlyph(),
          SizedBox(width: 12),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Karta dokun',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  height: 1.04,
                  letterSpacing: 0.2,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'arka yüze geç',
                style: TextStyle(
                  color: Color(0xB3FFFFFF),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  height: 1.04,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Kılavuzun canlı ikonu: marka kırmızısı nefes alan hale önünde Y ekseninde
/// 3B dönen mini kart — "bu kart çevrilir" jestini sözsüz canlandırır.
/// Tam tur (0→2π) döndüğü için döngü dikişsizdir; yarı turda arka yüz amber
/// dolguyla "açığa çıkar".
class _FlipCoachGlyph extends StatefulWidget {
  const _FlipCoachGlyph();

  @override
  State<_FlipCoachGlyph> createState() => _FlipCoachGlyphState();
}

class _FlipCoachGlyphState extends State<_FlipCoachGlyph>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2100),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      height: 30,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = const Interval(
            0.16,
            0.84,
            curve: Curves.easeInOutCubic,
          ).transform(_c.value);
          final angle = t * 2 * math.pi;
          final glow = math.sin(t * math.pi);
          final backVisible = angle > math.pi / 2 && angle < 3 * math.pi / 2;
          return Stack(
            alignment: Alignment.center,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.actionRed.withValues(alpha: 0.12 + 0.30 * glow),
                      AppColors.actionRed.withValues(alpha: 0),
                    ],
                  ),
                ),
                child: const SizedBox(width: 30, height: 30),
              ),
              Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.004)
                  ..rotateY(angle),
                child: Container(
                  width: 15,
                  height: 19,
                  decoration: BoxDecoration(
                    color: backVisible
                        ? AppColors.warmHorizon.withValues(alpha: 0.92)
                        : Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.95),
                      width: 1.4,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BEFORE & AFTER — ana sayfada "önce & sonra" bloğu: iki görsel tek karede,
// parmakla sürüklenen dikey bir sürgüyle karşılaştırılır.
//
// Tasarım dili: kutu yok, bağıran etiket yok. Tuval tamamen görsele ait; alt
// kenarda yalnızca ince bir gradyan üstünde çıplak beyaz etiketler (her biri
// kendi tarafı açıkken görünür) ve ortada cam dokunuşlu zarif bir tutamaç.
// Açılışta sürgü sağdan ortaya süzülür — jest, kılavuza gerek kalmadan
// kendini anlatır.
// ─────────────────────────────────────────────────────────────────────────────

class _BeforeAfterView extends StatefulWidget {
  const _BeforeAfterView({
    required this.data,
    required this.onInteractionRecorded,
  });

  final NewsBeforeAfterData data;
  final VoidCallback onInteractionRecorded;

  @override
  State<_BeforeAfterView> createState() => _BeforeAfterViewState();
}

class _BeforeAfterViewState extends State<_BeforeAfterView>
    with SingleTickerProviderStateMixin {
  /// Controller değeri doğrudan sürgünün yatay konumudur (0..1).
  late final AnimationController _slide;

  /// Sahnenin oranı "önce" görselinin gerçek oranından gelir: görsel dikey,
  /// kare ya da yatay olsun, genişlik tam oturur ve tamamı kadrajda kalır.
  double? _resolvedAspectRatio;
  ImageStream? _pendingImageStream;
  ImageStreamListener? _pendingImageListener;

  // Sürgü kenarlara tam yapışmaz; çizgi ve tutamaç her zaman görünür kalır.
  static const double _minEdge = 0.05;
  static const double _maxEdge = 0.95;

  // Oran henüz çözülmediyse geçici kadraj.
  static const double _fallbackAspectRatio = 4 / 5;

  @override
  void initState() {
    super.initState();
    _slide = AnimationController(vsync: this, value: 0.68);
    // Açılış mikro-jesti: sürgü kısa bir yoldan ortaya oturur.
    _slide.animateTo(
      0.5,
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
    );
    _resolveAspectRatio();
  }

  @override
  void didUpdateWidget(covariant _BeforeAfterView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data.beforeImage != widget.data.beforeImage) {
      _removeImageListener();
      _resolvedAspectRatio = null;
      _resolveAspectRatio();
    }
  }

  @override
  void dispose() {
    _removeImageListener();
    _slide.dispose();
    super.dispose();
  }

  void _resolveAspectRatio() {
    final parsedRatio = _parseImageAspectRatioFromUrl(widget.data.beforeImage);
    if (parsedRatio != null) {
      _resolvedAspectRatio = parsedRatio;
      return;
    }
    final imageUrl = widget.data.beforeImage.trim();
    if (imageUrl.isEmpty) return;
    final stream = CachedNetworkImageProvider(
      imageUrl,
    ).resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener((image, _) {
      _removeImageListener();
      final width = image.image.width;
      final height = image.image.height;
      if (!mounted || width <= 0 || height <= 0) return;
      setState(() => _resolvedAspectRatio = width / height);
    }, onError: (_, _) => _removeImageListener());
    _pendingImageStream = stream;
    _pendingImageListener = listener;
    stream.addListener(listener);
  }

  void _removeImageListener() {
    final stream = _pendingImageStream;
    final listener = _pendingImageListener;
    if (stream != null && listener != null) {
      stream.removeListener(listener);
    }
    _pendingImageStream = null;
    _pendingImageListener = null;
  }

  void _dragTo(double dx, double width) {
    if (width <= 0) return;
    widget.onInteractionRecorded();
    _slide.stop();
    _slide.value = (dx / width).clamp(_minEdge, _maxEdge);
  }

  void _glideTo(double dx, double width) {
    if (width <= 0) return;
    widget.onInteractionRecorded();
    _slide.animateTo(
      (dx / width).clamp(_minEdge, _maxEdge),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final beforeLabel = widget.data.beforeLabel.trim();
    final afterLabel = widget.data.afterLabel.trim();
    final errorFallback = Container(
      color: AppColors.surfaceInk,
      alignment: Alignment.center,
      child: const Icon(
        Symbols.image_outlined,
        color: AppColors.support,
        size: 32,
      ),
    );
    return AspectRatio(
      aspectRatio: _resolvedAspectRatio ?? _fallbackAspectRatio,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          double pendingTapX = width / 2;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => pendingTapX = d.localPosition.dx,
            // onTap kayıtlı olduğu için dokunuş kartın "habere git"
            // davranışına değil sürgüye gider; karşılaştırma alanı kendi
            // jestinin sahibidir.
            onTap: () => _glideTo(pendingTapX, width),
            onHorizontalDragStart: (d) => _dragTo(d.localPosition.dx, width),
            onHorizontalDragUpdate: (d) => _dragTo(d.localPosition.dx, width),
            child: AnimatedBuilder(
              animation: _slide,
              builder: (context, _) {
                final f = _slide.value;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedImage(
                      url: widget.data.afterImage,
                      fit: BoxFit.cover,
                      memCacheWidth: _imageCacheWidth(context),
                      errorWidget: errorFallback,
                    ),
                    ClipRect(
                      clipper: _LeftFractionClipper(f),
                      child: CachedImage(
                        url: widget.data.beforeImage,
                        fit: BoxFit.cover,
                        memCacheWidth: _imageCacheWidth(context),
                        errorWidget: errorFallback,
                      ),
                    ),
                    // Etiketlerin okunması için yalnızca alt şeridi yumuşatan
                    // kısa gradyan; görseli boğmaz.
                    const Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 84,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [Color(0x8C0B0F14), Color(0x000B0F14)],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Çıplak etiketler: kutusuz, yazıldığı gibi (büyük harf
                    // dönüşümü yok), kendi tarafı kapandığında usulca söner.
                    if (beforeLabel.isNotEmpty)
                      Positioned(
                        left: 14,
                        bottom: 13,
                        child: IgnorePointer(
                          child: AnimatedOpacity(
                            opacity: f > 0.18 ? 1 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: SizedBox(
                              width: width * 0.44,
                              child: Text(
                                beforeLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: AppTypography.primaryFamily,
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.1,
                                  height: 1.2,
                                  shadows: _mediaTextShadows,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (afterLabel.isNotEmpty)
                      Positioned(
                        right: 14,
                        bottom: 13,
                        child: IgnorePointer(
                          child: AnimatedOpacity(
                            opacity: f < 0.82 ? 1 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: SizedBox(
                              width: width * 0.44,
                              child: Text(
                                afterLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontFamily: AppTypography.primaryFamily,
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.1,
                                  height: 1.2,
                                  shadows: _mediaTextShadows,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    // Sürgü çizgisi: ince, beyaz, iki yana yumuşak gölgeli.
                    Positioned(
                      left: width * f - 1,
                      top: 0,
                      bottom: 0,
                      child: IgnorePointer(
                        child: Container(
                          width: 2,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.95),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x66000000),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Tutamaç: cam daire içinde iki yöne bakan ince oklar.
                    Positioned(
                      left: width * f - 19,
                      top: 0,
                      bottom: 0,
                      child: IgnorePointer(
                        child: Center(
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0x59000000),
                                  blurRadius: 16,
                                  offset: Offset(0, 5),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 10,
                                  sigmaY: 10,
                                ),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: const Color(0x3D000000),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.6,
                                      ),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: const CustomPaint(
                                    size: Size(38, 38),
                                    painter: _SlideChevronsPainter(),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// Önce görselini soldan [fraction] oranında gösteren dikdörtgen kırpıcı.
class _LeftFractionClipper extends CustomClipper<Rect> {
  const _LeftFractionClipper(this.fraction);

  final double fraction;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(0, 0, size.width * fraction, size.height);

  @override
  bool shouldReclip(covariant _LeftFractionClipper oldClipper) =>
      oldClipper.fraction != fraction;
}

/// Tutamacın içindeki iki yöne bakan ince ok uçları (‹ ›).
class _SlideChevronsPainter extends CustomPainter {
  const _SlideChevronsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final left = Path()
      ..moveTo(cx - 4.5, cy - 4)
      ..lineTo(cx - 8.5, cy)
      ..lineTo(cx - 4.5, cy + 4);
    final right = Path()
      ..moveTo(cx + 4.5, cy - 4)
      ..lineTo(cx + 8.5, cy)
      ..lineTo(cx + 4.5, cy + 4);
    canvas.drawPath(left, paint);
    canvas.drawPath(right, paint);
  }

  @override
  bool shouldRepaint(covariant _SlideChevronsPainter oldDelegate) => false;
}

class _CoverImage extends StatelessWidget {
  const _CoverImage({required this.imageUrl, this.onExpand});

  final String imageUrl;
  final VoidCallback? onExpand;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: AppColors.surfaceInk,
      alignment: Alignment.center,
      child: const Icon(
        Symbols.image_outlined,
        color: AppColors.support,
        size: 32,
      ),
    );
    if (imageUrl.trim().isEmpty) return fallback;
    return Stack(
      fit: StackFit.expand,
      children: [
        PinchZoomSurface(
          child: CachedImage(
            url: imageUrl,
            fit: BoxFit.contain,
            memCacheWidth: _imageCacheWidth(context),
            errorWidget: Container(
              color: AppColors.surfaceInk,
              alignment: Alignment.center,
              child: const Icon(
                Symbols.image_outlined,
                color: AppColors.support,
                size: 32,
              ),
            ),
          ),
        ),
        // Videolardaki "büyüt" düğmesinin aynısı: basınca aynı siyah tam ekran
        // önizleme açılır.
        if (onExpand != null)
          Positioned(
            right: 8,
            bottom: 10,
            child: NewsFullscreenExpandButton(onTap: onExpand!),
          ),
      ],
    );
  }
}

/// Ana sayfa kartında "slider" bloğu seçiliyse görselleri yatay, akıcı bir
/// galeride gösterir. Görseller tıpkı normal kapak gibi (BoxFit.contain) tam
/// genişlikte ve tam görünür; yükseklik kartın en-boy oranından gelir. Altta
/// animasyonlu, şık bir sayfa göstergesi (nokta) bulunur.
class _MediaSlider extends StatefulWidget {
  const _MediaSlider({required this.images, this.onExpand});

  final List<String> images;
  final ValueChanged<int>? onExpand;

  @override
  State<_MediaSlider> createState() => _MediaSliderState();
}

class _MediaSliderState extends State<_MediaSlider> {
  final PageController _controller = PageController();
  int _index = 0;

  void _goToSlide(int delta) {
    final images = widget.images;
    if (images.length < 2) return;
    final target = (_index + delta + images.length) % images.length;
    _controller.animateToPage(
      target,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.images;
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _controller,
          physics: const BouncingScrollPhysics(),
          itemCount: images.length,
          onPageChanged: (i) {
            if (mounted) setState(() => _index = i);
          },
          itemBuilder: (context, i) => PinchZoomSurface(
            child: CachedImage(
              url: images[i],
              fit: BoxFit.contain,
              memCacheWidth: _imageCacheWidth(context),
              errorWidget: Container(
                color: AppColors.surfaceInk,
                alignment: Alignment.center,
                child: const Icon(
                  Symbols.image_outlined,
                  color: AppColors.support,
                  size: 32,
                ),
              ),
            ),
          ),
        ),
        if (images.length > 1)
          Positioned(
            left: 10,
            top: 0,
            bottom: 0,
            child: Center(
              child: _SliderArrowButton(
                icon: Symbols.arrow_left_line,
                label: 'Önceki görsel',
                onTap: () => _goToSlide(-1),
              ),
            ),
          ),
        if (images.length > 1)
          Positioned(
            right: 10,
            top: 0,
            bottom: 0,
            child: Center(
              child: _SliderArrowButton(
                icon: Symbols.arrow_forward,
                label: 'Sonraki görsel',
                onTap: () => _goToSlide(1),
              ),
            ),
          ),
        if (images.length > 1)
          Positioned(
            left: 0,
            right: 0,
            bottom: 10,
            child: IgnorePointer(
              child: Center(
                child: _SliderDots(count: images.length, index: _index),
              ),
            ),
          ),
        // Videolarla aynı "büyüt" düğmesi: basınca açık olan görselden
        // başlayarak aynı siyah tam ekran slider'ı açar.
        if (widget.onExpand != null)
          Positioned(
            right: 8,
            bottom: 10,
            child: NewsFullscreenExpandButton(
              onTap: () => widget.onExpand!(_index),
            ),
          ),
      ],
    );
  }
}

class _SliderArrowButton extends StatelessWidget {
  const _SliderArrowButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.inkStrong.withValues(alpha: 0.32),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.24),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.16),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(icon, size: 15, color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SliderDots extends StatelessWidget {
  const _SliderDots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.30),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(width: 5),
            AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              width: i == index ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: i == index
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

int? _imageCacheWidth(BuildContext context) {
  final dpr = MediaQuery.devicePixelRatioOf(context);
  final width =
      MediaQuery.sizeOf(context).width - AppSpacing.pageHorizontal * 2;
  final cacheWidth = (width * dpr).round();
  return cacheWidth > 0 ? cacheWidth : null;
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTION BAR
// ─────────────────────────────────────────────────────────────────────────────

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.article,
    required this.isLiked,
    required this.isDisliked,
    required this.isSaved,
    required this.likes,
    required this.dislikes,
    required this.shares,
    required this.saves,
    required this.onLike,
    required this.onDislike,
    required this.onSave,
    required this.onShare,
    required this.commentsEnabled,
    required this.commentsVisible,
    required this.onCommentsToggle,
  });

  final NewsArticle article;
  final bool isLiked;
  final bool isDisliked;
  final bool isSaved;
  final int likes;
  final int dislikes;
  final int shares;
  final int saves;
  final VoidCallback onLike;
  final VoidCallback onDislike;
  final VoidCallback onSave;
  final VoidCallback onShare;
  final bool commentsEnabled;
  final bool commentsVisible;
  final VoidCallback onCommentsToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal - 6,
        AppSpacing.sm,
        AppSpacing.pageHorizontal - 6,
        AppSpacing.lg,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 350;
          final spacing = compact ? 2.0 : 6.0;
          return Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: spacing,
                  runSpacing: 2,
                  children: [
                    SocialAction(
                      glyph: PateezSocialGlyph.sparkUp,
                      isActive: isLiked,
                      activeColor: AppColors.deepOcean,
                      semanticLabel: 'Beğen',
                      count: likes,
                      onTap: onLike,
                      iconSize: 23,
                    ),
                    SocialAction(
                      glyph: PateezSocialGlyph.sparkDown,
                      isActive: isDisliked,
                      activeColor: AppColors.actionRed,
                      semanticLabel: 'Beğenme',
                      count: dislikes,
                      onTap: onDislike,
                      iconSize: 23,
                    ),
                    if (commentsEnabled)
                      SocialAction(
                        glyph: PateezSocialGlyph.conversation,
                        isActive: commentsVisible,
                        activeColor: AppColors.deepOcean,
                        semanticLabel: 'Yorumlar',
                        count: article.comments,
                        onTap: onCommentsToggle,
                        iconSize: 26,
                      ),
                    SocialAction(
                      glyph: PateezSocialGlyph.forwardShare,
                      isActive: false,
                      activeColor: AppColors.warmHorizon,
                      semanticLabel: 'Paylaş',
                      count: shares,
                      onTap: onShare,
                      iconSize: 26,
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SocialAction(
                    glyph: PateezSocialGlyph.ribbon,
                    isActive: isSaved,
                    activeColor: AppColors.warmHorizon,
                    semanticLabel: 'Kaydet',
                    badgeCount: saves,
                    onTap: onSave,
                    iconSize: 28,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InlineCommentDraft {
  const _InlineCommentDraft({
    required this.content,
    required this.guestName,
    required this.guestEmail,
  });

  final String content;
  final String guestName;
  final String guestEmail;
}

@immutable
class _GuestCommentIdentity {
  const _GuestCommentIdentity({required this.name, required this.email});

  static const empty = _GuestCommentIdentity(name: '', email: '');

  final String name;
  final String email;

  bool matches(_GuestCommentIdentity other) {
    return name == other.name && email == other.email;
  }
}

class _GuestCommentIdentityStore {
  const _GuestCommentIdentityStore._();

  static const _nameKey = 'pateez_guest_comment_name';
  static const _emailKey = 'pateez_guest_comment_email';
  static final notifier = ValueNotifier<_GuestCommentIdentity>(
    _GuestCommentIdentity.empty,
  );

  static Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    final identity = _GuestCommentIdentity(
      name: preferences.getString(_nameKey)?.trim() ?? '',
      email: preferences.getString(_emailKey)?.trim() ?? '',
    );
    if (!notifier.value.matches(identity)) notifier.value = identity;
  }

  static Future<void> save({
    required String name,
    required String email,
  }) async {
    final identity = _GuestCommentIdentity(
      name: name.trim(),
      email: email.trim(),
    );
    if (!notifier.value.matches(identity)) notifier.value = identity;
    final preferences = await SharedPreferences.getInstance();
    if (identity.name.isEmpty) {
      await preferences.remove(_nameKey);
    } else {
      await preferences.setString(_nameKey, identity.name);
    }
    if (identity.email.isEmpty) {
      await preferences.remove(_emailKey);
    } else {
      await preferences.setString(_emailKey, identity.email);
    }
  }
}

class _InlineCommentPreview extends StatelessWidget {
  const _InlineCommentPreview({
    required this.comments,
    required this.totalCount,
    required this.visible,
    required this.expanded,
    required this.loadingMore,
    required this.authState,
    required this.replyTo,
    required this.submitting,
    required this.deletingCommentId,
    required this.emojiReactionsEnabled,
    required this.relaxedLayout,
    required this.showGuidance,
    required this.onCancelReply,
    required this.onReply,
    required this.onLike,
    required this.onDelete,
    required this.onToggleExpanded,
    required this.onSubmit,
    required this.onAuthorTap,
  });

  final List<NewsComment> comments;
  final int totalCount;
  final bool visible;
  final bool expanded;
  final bool loadingMore;
  final FrontendAuthState? authState;
  final NewsComment? replyTo;
  final bool submitting;
  final String? deletingCommentId;
  final bool emojiReactionsEnabled;
  final bool relaxedLayout;
  final bool showGuidance;
  final VoidCallback onCancelReply;
  final ValueChanged<NewsComment> onReply;
  final ValueChanged<NewsComment> onLike;
  final ValueChanged<NewsComment> onDelete;
  final VoidCallback onToggleExpanded;
  final Future<bool> Function(_InlineCommentDraft draft) onSubmit;
  final ValueChanged<NewsAuthor>? onAuthorTap;

  @override
  Widget build(BuildContext context) {
    final visibleComments = expanded
        ? comments
        : comments.take(_inlineCollapsedRootCommentLimit).toList();
    final hasExtraComments =
        comments.length > _inlineCollapsedRootCommentLimit ||
        totalCount > comments.length ||
        totalCount > _inlineCollapsedRootCommentLimit;

    return Column(
      key: const ValueKey<String>('news-card-inline-comments'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 340),
          curve: Curves.easeInOutCubic,
          alignment: Alignment.topCenter,
          child: visible
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (visibleComments.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.pageHorizontal,
                          2,
                          AppSpacing.pageHorizontal,
                          AppSpacing.sm,
                        ),
                        child: _InlineCommentList(
                          comments: visibleComments,
                          expanded: expanded,
                          canToggleMore: hasExtraComments,
                          loadingMore: loadingMore,
                          deletingCommentId: deletingCommentId,
                          onLike: onLike,
                          onReply: onReply,
                          onDelete: onDelete,
                          onToggleExpanded: onToggleExpanded,
                          onAuthorTap: onAuthorTap,
                        ),
                      ),
                    _InlineCommentComposer(
                      authState: authState,
                      replyTo: replyTo,
                      submitting: submitting,
                      emojiReactionsEnabled: emojiReactionsEnabled,
                      relaxedLayout: relaxedLayout,
                      showGuidance: showGuidance,
                      onCancelReply: onCancelReply,
                      onSubmit: onSubmit,
                    ),
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _InlineCommentList extends StatelessWidget {
  const _InlineCommentList({
    required this.comments,
    required this.expanded,
    required this.canToggleMore,
    required this.loadingMore,
    required this.deletingCommentId,
    required this.onLike,
    required this.onReply,
    required this.onDelete,
    required this.onToggleExpanded,
    required this.onAuthorTap,
  });

  final List<NewsComment> comments;
  final bool expanded;
  final bool canToggleMore;
  final bool loadingMore;
  final String? deletingCommentId;
  final ValueChanged<NewsComment> onLike;
  final ValueChanged<NewsComment> onReply;
  final ValueChanged<NewsComment> onDelete;
  final VoidCallback onToggleExpanded;
  final ValueChanged<NewsAuthor>? onAuthorTap;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    var collapsedReplyShown = false;
    for (var index = 0; index < comments.length; index++) {
      final comment = comments[index];
      final showReply =
          expanded || (!collapsedReplyShown && comment.replies.isNotEmpty);
      if (!expanded && showReply) collapsedReplyShown = true;
      if (index > 0) {
        children.add(
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Divider(height: 1, thickness: 1, color: AppColors.softLine),
          ),
        );
      }
      children.add(
        _InlineCommentTile(
          comment: comment,
          showReply: showReply,
          deletingCommentId: deletingCommentId,
          onLike: onLike,
          onReply: onReply,
          onDelete: onDelete,
          onAuthorTap: onAuthorTap,
        ),
      );
    }
    if (canToggleMore) {
      children.add(const SizedBox(height: 6));
      children.add(
        _InlineCommentsMoreButton(
          expanded: expanded,
          loading: loadingMore,
          onTap: onToggleExpanded,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

class _InlineCommentsMoreButton extends StatelessWidget {
  const _InlineCommentsMoreButton({
    required this.expanded,
    required this.loading,
    required this.onTap,
  });

  final bool expanded;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = loading ? AppColors.placeholder : AppColors.support;
    return Align(
      alignment: Alignment.center,
      child: Semantics(
        button: true,
        label: loading
            ? 'Yorumlar yükleniyor'
            : expanded
            ? 'Daha az yorum göster'
            : 'Daha fazla yorum göster',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: const ValueKey<String>('news-card-comments-more-toggle'),
            onTap: loading ? null : onTap,
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (loading)
                    SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.4,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    )
                  else
                    Icon(
                      expanded
                          ? Symbols.arrow_up_s_fill
                          : Symbols.arrow_down_s_fill,
                      size: 13,
                      color: color,
                    ),
                  const SizedBox(width: 4),
                  Text(
                    loading
                        ? 'Yükleniyor'
                        : expanded
                        ? 'Daha az'
                        : 'Daha fazla',
                    style: AppTypography.meta.copyWith(
                      color: color,
                      fontSize: 10.8,
                      fontWeight: FontWeight.w800,
                      height: 1,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InlineCommentComposer extends StatefulWidget {
  const _InlineCommentComposer({
    required this.authState,
    required this.replyTo,
    required this.submitting,
    required this.emojiReactionsEnabled,
    required this.relaxedLayout,
    required this.showGuidance,
    required this.onCancelReply,
    required this.onSubmit,
  });

  final FrontendAuthState? authState;
  final NewsComment? replyTo;
  final bool submitting;
  final bool emojiReactionsEnabled;
  final bool relaxedLayout;
  final bool showGuidance;
  final VoidCallback onCancelReply;
  final Future<bool> Function(_InlineCommentDraft draft) onSubmit;

  @override
  State<_InlineCommentComposer> createState() => _InlineCommentComposerState();
}

class _InlineCommentComposerState extends State<_InlineCommentComposer> {
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _guestNameController = TextEditingController();
  final TextEditingController _guestEmailController = TextEditingController();
  final FocusNode _focus = FocusNode();
  Timer? _guestIdentitySaveDebounce;
  bool _syncingGuestIdentity = false;
  bool _focused = false;
  bool _canSend = false;
  bool _showEmailError = false;
  bool _emojiPanelOpen = false;

  bool get _signedIn => widget.authState != null;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_syncCanSend);
    _guestNameController.addListener(_handleGuestIdentityChanged);
    _guestEmailController.addListener(_handleGuestIdentityChanged);
    _focus.addListener(_handleFocusChanged);
    _GuestCommentIdentityStore.notifier.addListener(_applyStoredGuestIdentity);
    unawaited(_loadStoredGuestIdentity());
  }

  @override
  void didUpdateWidget(covariant _InlineCommentComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.authState != widget.authState) _syncCanSend();
    if (oldWidget.emojiReactionsEnabled != widget.emojiReactionsEnabled &&
        !widget.emojiReactionsEnabled) {
      _emojiPanelOpen = false;
    }
    if (oldWidget.replyTo?.id != widget.replyTo?.id && widget.replyTo != null) {
      _emojiPanelOpen = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    }
  }

  bool _isEmailReady(String value) {
    final email = value.trim();
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);
  }

  bool _draftReady() {
    final content = _controller.text.trim();
    if (content.isEmpty || content.length > _inlineCommentMaxLength) {
      return false;
    }
    if (_signedIn) return true;
    return _guestNameController.text.trim().length >= 2 &&
        _isEmailReady(_guestEmailController.text);
  }

  void _syncCanSend() {
    final canSend = _draftReady();
    final email = _guestEmailController.text.trim();
    final showEmailError =
        !_signedIn && email.isNotEmpty && !_isEmailReady(email);
    if (canSend != _canSend || showEmailError != _showEmailError) {
      setState(() {
        _canSend = canSend;
        _showEmailError = showEmailError;
      });
    }
  }

  Future<void> _loadStoredGuestIdentity() async {
    await _GuestCommentIdentityStore.load();
    if (mounted) _applyStoredGuestIdentity();
  }

  void _applyStoredGuestIdentity() {
    if (_signedIn) return;
    final identity = _GuestCommentIdentityStore.notifier.value;
    if (_guestNameController.text == identity.name &&
        _guestEmailController.text == identity.email) {
      return;
    }
    _syncingGuestIdentity = true;
    _guestNameController.text = identity.name;
    _guestEmailController.text = identity.email;
    _syncingGuestIdentity = false;
    _syncCanSend();
  }

  void _handleGuestIdentityChanged() {
    _syncCanSend();
    if (_syncingGuestIdentity || _signedIn) return;
    _guestIdentitySaveDebounce?.cancel();
    _guestIdentitySaveDebounce = Timer(
      const Duration(milliseconds: 280),
      () => unawaited(_saveGuestIdentityNow()),
    );
  }

  Future<void> _saveGuestIdentityNow() {
    _guestIdentitySaveDebounce?.cancel();
    _guestIdentitySaveDebounce = null;
    return _GuestCommentIdentityStore.save(
      name: _guestNameController.text,
      email: _guestEmailController.text,
    );
  }

  void _handleFocusChanged() {
    final focused = _focus.hasFocus;
    if (focused != _focused || (focused && _emojiPanelOpen)) {
      setState(() {
        _focused = focused;
        if (focused) _emojiPanelOpen = false;
      });
    }
  }

  void _toggleEmojiPanel() {
    if (!widget.emojiReactionsEnabled) return;
    final nextOpen = !_emojiPanelOpen;
    setState(() => _emojiPanelOpen = nextOpen);
    if (nextOpen) {
      _focus.unfocus();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _guestIdentitySaveDebounce?.cancel();
    _GuestCommentIdentityStore.notifier.removeListener(
      _applyStoredGuestIdentity,
    );
    _controller.removeListener(_syncCanSend);
    _guestNameController.removeListener(_handleGuestIdentityChanged);
    _guestEmailController.removeListener(_handleGuestIdentityChanged);
    _focus.removeListener(_handleFocusChanged);
    _controller.dispose();
    _guestNameController.dispose();
    _guestEmailController.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_canSend || widget.submitting) return;
    if (!_signedIn) await _saveGuestIdentityNow();
    final sent = await widget.onSubmit(
      _InlineCommentDraft(
        content: _controller.text.trim(),
        guestName: _guestNameController.text.trim(),
        guestEmail: _guestEmailController.text.trim(),
      ),
    );
    if (!mounted || !sent) return;
    _controller.clear();
    if (_emojiPanelOpen) setState(() => _emojiPanelOpen = false);
    FocusScope.of(context).unfocus();
  }

  Widget? _buildCommentCounter(
    BuildContext context, {
    required int currentLength,
    required bool isFocused,
    required int? maxLength,
  }) {
    if (!isFocused && currentLength < _inlineCommentCounterRevealLength) {
      return null;
    }
    final nearLimit = currentLength >= _inlineCommentCounterWarningLength;
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(top: 3),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          style: AppTypography.meta.copyWith(
            color: nearLimit ? AppColors.actionRed : AppColors.placeholder,
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            height: 1,
            letterSpacing: 0,
          ),
          child: Text('$currentLength/${maxLength ?? _inlineCommentMaxLength}'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final relaxedLayout = widget.relaxedLayout;
    final composerPadding = relaxedLayout
        ? const EdgeInsets.fromLTRB(
            AppSpacing.pageHorizontal,
            AppSpacing.md,
            AppSpacing.pageHorizontal,
            AppSpacing.lg,
          )
        : const EdgeInsets.fromLTRB(
            AppSpacing.pageHorizontal - 2,
            9,
            AppSpacing.pageHorizontal - 2,
            9,
          );
    final fieldGap = relaxedLayout ? 8.0 : 7.0;
    final guestToInputGap = relaxedLayout ? 10.0 : 7.0;
    final inputGap = relaxedLayout ? 9.0 : 8.0;
    final active =
        _focused ||
        _canSend ||
        widget.replyTo != null ||
        (widget.emojiReactionsEnabled && _emojiPanelOpen);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: AnimatedContainer(
        key: const ValueKey<String>('news-card-inline-comment-composer'),
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: const BorderSide(color: AppColors.softLine),
            bottom: BorderSide(
              color: active ? AppColors.line : AppColors.softLine,
            ),
          ),
        ),
        padding: composerPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.replyTo != null) ...[
              _InlineReplyTarget(
                comment: widget.replyTo!,
                onCancel: widget.onCancelReply,
              ),
              const SizedBox(height: 8),
            ],
            if (!_signedIn) ...[
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 330;
                  final fields = [
                    _InlineGuestField(
                      controller: _guestNameController,
                      hintText: 'Ad soyad',
                      icon: Symbols.person_outline_rounded,
                      textInputAction: TextInputAction.next,
                      relaxed: relaxedLayout,
                    ),
                    _InlineGuestEmailField(
                      controller: _guestEmailController,
                      showError: _showEmailError,
                      relaxed: relaxedLayout,
                    ),
                  ];
                  if (compact) {
                    return Column(
                      children: [
                        fields[0],
                        SizedBox(height: relaxedLayout ? 10 : 7),
                        fields[1],
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 9, child: fields[0]),
                      SizedBox(width: fieldGap),
                      Expanded(flex: 10, child: fields[1]),
                    ],
                  );
                },
              ),
              SizedBox(height: guestToInputGap),
            ],
            Row(
              children: [
                _InlineComposerIdentity(
                  authState: widget.authState,
                  active: active,
                ),
                SizedBox(width: inputGap),
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    constraints: BoxConstraints(
                      minHeight: relaxedLayout ? 42 : 36,
                    ),
                    decoration: BoxDecoration(
                      color: active
                          ? AppColors.surfaceSoft
                          : AppColors.surfaceSoft.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _focused ? AppColors.line : AppColors.softLine,
                      ),
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: relaxedLayout ? 12 : 10,
                      vertical: relaxedLayout ? 5 : 4,
                    ),
                    child: TextField(
                      controller: _controller,
                      focusNode: _focus,
                      cursorColor: AppColors.deepOcean,
                      cursorWidth: 1.3,
                      maxLines: 3,
                      minLines: 1,
                      maxLength: _inlineCommentMaxLength,
                      maxLengthEnforcement: MaxLengthEnforcement.enforced,
                      buildCounter: _buildCommentCounter,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.32,
                        letterSpacing: 0,
                      ),
                      decoration: InputDecoration(
                        hintText: widget.replyTo == null
                            ? 'Yorumunuzu ekleyin'
                            : 'Yanıtınızı yazın',
                        hintStyle: AppTypography.bodySmall.copyWith(
                          color: AppColors.placeholderSoft,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          height: 1.32,
                          letterSpacing: 0,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        filled: false,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: relaxedLayout ? 10 : 8),
                if (widget.emojiReactionsEnabled) ...[
                  _InlineEmojiToggleButton(
                    active: _emojiPanelOpen,
                    onTap: _toggleEmojiPanel,
                  ),
                  const SizedBox(width: 2),
                ],
                _InlineSendTextButton(
                  canSend: _canSend && !widget.submitting,
                  submitting: widget.submitting,
                  onTap: _send,
                ),
              ],
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: widget.emojiReactionsEnabled && _emojiPanelOpen
                  ? Padding(
                      key: const ValueKey<String>(
                        'news-card-inline-emoji-panel',
                      ),
                      padding: EdgeInsets.only(top: relaxedLayout ? 10 : 8),
                      child: _InlineEmojiPicker(controller: _controller),
                    )
                  : const SizedBox.shrink(),
            ),
            if (widget.showGuidance) ...[
              SizedBox(height: relaxedLayout ? 9 : 7),
              Text(
                'Pateez.com\'da paylaştığın yorumlar haber tartışmasına katkı sağlar. Farklı görüşlere saygılı kal; hakaret, hedef gösterme ve ayrımcı ifadeler kullanma.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.placeholder.withValues(alpha: 0.82),
                  fontSize: relaxedLayout ? 10.8 : 10.4,
                  fontWeight: FontWeight.w400,
                  height: 1.32,
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

class _InlineReplyTarget extends StatelessWidget {
  const _InlineReplyTarget({required this.comment, required this.onCancel});

  final NewsComment comment;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 7, 7, 7),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.softLine),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.deepOcean.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Symbols.reply_rounded,
              size: 13,
              color: AppColors.deepOcean,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${comment.author.name} yanıtlanıyor',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.meta.copyWith(
                    color: AppColors.deepOcean,
                    fontSize: 11.1,
                    fontWeight: FontWeight.w800,
                    height: 1.05,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  comment.body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.meta.copyWith(
                    color: AppColors.placeholder,
                    fontSize: 10.4,
                    fontWeight: FontWeight.w600,
                    height: 1.05,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: 'Yanıtı iptal et',
            child: InkWell(
              onTap: onCancel,
              borderRadius: BorderRadius.circular(999),
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(
                  Symbols.close_rounded,
                  size: 15,
                  color: AppColors.placeholder,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineGuestField extends StatelessWidget {
  const _InlineGuestField({
    required this.controller,
    required this.hintText,
    required this.icon,
    this.keyboardType,
    this.textInputAction,
    this.relaxed = false,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool relaxed;

  @override
  Widget build(BuildContext context) {
    final fieldHeight = relaxed ? 35.0 : 31.0;
    final minIconSize = relaxed ? 35.0 : 31.0;
    final fontSize = relaxed ? 11.4 : 11.0;
    return SizedBox(
      height: fieldHeight,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        cursorColor: AppColors.deepOcean,
        cursorWidth: 1.2,
        style: AppTypography.bodySmall.copyWith(
          color: AppColors.inkSoft,
          fontSize: fontSize,
          fontWeight: FontWeight.w500,
          height: relaxed ? 1.1 : 1,
          letterSpacing: 0,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: AppTypography.bodySmall.copyWith(
            color: AppColors.placeholderSoft,
            fontSize: fontSize,
            fontWeight: FontWeight.w500,
            height: relaxed ? 1.1 : 1,
            letterSpacing: 0,
          ),
          prefixIcon: Icon(icon, size: 13.5, color: AppColors.placeholderSoft),
          prefixIconConstraints: BoxConstraints(
            minWidth: 28,
            minHeight: minIconSize,
          ),
          filled: true,
          fillColor: AppColors.surfaceSoft,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 8,
            vertical: relaxed ? 8 : 0,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(color: AppColors.softLine),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(color: AppColors.softLine),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(color: AppColors.softLine),
          ),
        ),
      ),
    );
  }
}

class _InlineGuestEmailField extends StatelessWidget {
  const _InlineGuestEmailField({
    required this.controller,
    required this.showError,
    required this.relaxed,
  });

  final TextEditingController controller;
  final bool showError;
  final bool relaxed;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InlineGuestField(
          controller: controller,
          hintText: 'E-posta',
          icon: Symbols.alternate_email_rounded,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          relaxed: relaxed,
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 140),
          child: showError
              ? Padding(
                  key: const ValueKey<String>('guest-email-format-error'),
                  padding: const EdgeInsets.only(left: 9, top: 3),
                  child: Text(
                    'Mail adresi yanlış',
                    style: AppTypography.meta.copyWith(
                      color: AppColors.actionRed,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      height: 1,
                      letterSpacing: 0,
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _InlineComposerIdentity extends StatelessWidget {
  const _InlineComposerIdentity({
    required this.authState,
    required this.active,
  });

  final FrontendAuthState? authState;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final size = authState == null ? 31.0 : 30.0;
    final avatarUrl = authState?.avatarUrl.trim() ?? '';
    final label = authState?.initials.trim().isNotEmpty == true
        ? authState!.initials.trim()
        : 'M';
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: active ? AppColors.deepOcean : AppColors.surfaceInk,
        shape: BoxShape.circle,
        border: Border.all(
          color: active ? AppColors.deepOcean : AppColors.softLine,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: avatarUrl.isNotEmpty
          ? CachedImage(
              url: avatarUrl,
              fit: BoxFit.cover,
              memCacheWidth: (size * MediaQuery.devicePixelRatioOf(context))
                  .round(),
              placeholderColor: AppColors.surfaceInk,
              errorWidget: _InlineComposerInitial(
                label: label,
                active: active,
                size: size,
              ),
            )
          : authState == null
          ? Icon(
              Symbols.chat_3_line,
              size: 15,
              color: active ? Colors.white : AppColors.placeholder,
            )
          : _InlineComposerInitial(label: label, active: active, size: size),
    );
  }
}

class _InlineComposerInitial extends StatelessWidget {
  const _InlineComposerInitial({
    required this.label,
    required this.active,
    required this.size,
  });

  final String label;
  final bool active;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.characters.take(2).toString().toUpperCase(),
      style: AppTypography.titleS.copyWith(
        color: active ? Colors.white : AppColors.deepOcean,
        fontSize: size * 0.38,
        fontWeight: FontWeight.w800,
        height: 1,
        letterSpacing: 0,
      ),
    );
  }
}

class _InlineEmojiToggleButton extends StatelessWidget {
  const _InlineEmojiToggleButton({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: active ? 'Emoji panelini kapat' : 'Emoji seç',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 29,
            height: 29,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active
                  ? AppColors.deepOcean.withValues(alpha: 0.09)
                  : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Symbols.emotion_happy_line,
              size: 17,
              color: active ? AppColors.deepOcean : AppColors.placeholder,
            ),
          ),
        ),
      ),
    );
  }
}

class _InlineEmojiPicker extends StatelessWidget {
  const _InlineEmojiPicker({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final smallText = AppTypography.meta.copyWith(
      color: AppColors.placeholder,
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.softLine),
        ),
        child: EmojiPicker(
          textEditingController: controller,
          config: Config(
            height: 214,
            checkPlatformCompatibility: true,
            locale: const Locale('en'),
            emojiViewConfig: EmojiViewConfig(
              columns: 8,
              emojiSizeMax: 24,
              backgroundColor: AppColors.surface,
              gridPadding: const EdgeInsets.symmetric(
                horizontal: 7,
                vertical: 5,
              ),
              recentsLimit: 24,
              noRecents: Center(child: Text('Son emoji yok', style: smallText)),
              loadingIndicator: const Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.6,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.deepOcean,
                    ),
                  ),
                ),
              ),
              buttonMode: ButtonMode.MATERIAL,
            ),
            categoryViewConfig: const CategoryViewConfig(
              tabBarHeight: 36,
              initCategory: Category.SMILEYS,
              backgroundColor: AppColors.surface,
              indicatorColor: AppColors.deepOcean,
              iconColor: AppColors.placeholderSoft,
              iconColorSelected: AppColors.deepOcean,
              backspaceColor: AppColors.deepOcean,
              dividerColor: AppColors.softLine,
            ),
            bottomActionBarConfig: const BottomActionBarConfig(
              enabled: true,
              showBackspaceButton: true,
              showSearchViewButton: true,
              backgroundColor: AppColors.surfaceSoft,
              buttonColor: AppColors.deepOcean,
              buttonIconColor: Colors.white,
            ),
            searchViewConfig: SearchViewConfig(
              backgroundColor: AppColors.surface,
              buttonIconColor: AppColors.deepOcean,
              hintText: 'Emoji ara',
              inputTextStyle: AppTypography.bodySmall.copyWith(
                color: AppColors.ink,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
              hintTextStyle: AppTypography.bodySmall.copyWith(
                color: AppColors.placeholderSoft,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InlineSendTextButton extends StatelessWidget {
  const _InlineSendTextButton({
    required this.canSend,
    required this.submitting,
    required this.onTap,
  });

  final bool canSend;
  final bool submitting;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = canSend ? AppColors.deepOcean : AppColors.placeholderSoft;
    return Semantics(
      button: true,
      enabled: canSend && !submitting,
      label: submitting ? 'Yorum gönderiliyor' : 'Yorumu gönder',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: canSend && !submitting ? onTap : null,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: submitting ? 2 : 8,
              vertical: 7,
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: submitting
                  ? ConstrainedBox(
                      key: const ValueKey<String>('comment-send-loading'),
                      constraints: const BoxConstraints(maxWidth: 92),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.7,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.deepOcean,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Gönderiliyor',
                              style: AppTypography.titleS.copyWith(
                                color: AppColors.deepOcean,
                                fontSize: 11.8,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Text(
                      'Gönder',
                      key: const ValueKey<String>('comment-send-ready'),
                      style: AppTypography.titleS.copyWith(
                        color: color,
                        fontSize: 12.8,
                        fontWeight: FontWeight.w800,
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

class _InlineCommentTile extends StatelessWidget {
  const _InlineCommentTile({
    required this.comment,
    required this.showReply,
    required this.deletingCommentId,
    required this.onLike,
    required this.onReply,
    required this.onDelete,
    required this.onAuthorTap,
  });

  final NewsComment comment;
  final bool showReply;
  final String? deletingCommentId;
  final ValueChanged<NewsComment> onLike;
  final ValueChanged<NewsComment> onReply;
  final ValueChanged<NewsComment> onDelete;
  final ValueChanged<NewsAuthor>? onAuthorTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AuthorTapTarget(
          author: comment.author,
          onAuthorTap: onAuthorTap,
          child: _InlineCommentAvatar(author: comment.author, size: 29),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _AuthorTapTarget(
                author: comment.author,
                onAuthorTap: onAuthorTap,
                child: _InlineCommentAuthorLine(author: comment.author),
              ),
              const SizedBox(height: 2),
              Text(
                comment.body,
                style: AppTypography.body.copyWith(
                  color: AppColors.ink,
                  fontSize: 12.1,
                  height: 1.34,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 5),
              _InlineCommentActions(
                comment: comment,
                deleting: deletingCommentId == comment.id,
                onLike: onLike,
                onReply: onReply,
                onDelete: onDelete,
              ),
              if (showReply && comment.replies.isNotEmpty) ...[
                const SizedBox(height: 7),
                _InlineReplyTrail(
                  reply: comment.replies.first,
                  depth: 1,
                  deletingCommentId: deletingCommentId,
                  onLike: onLike,
                  onReply: onReply,
                  onDelete: onDelete,
                  onAuthorTap: onAuthorTap,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _InlineReplyTrail extends StatelessWidget {
  const _InlineReplyTrail({
    required this.reply,
    required this.depth,
    required this.deletingCommentId,
    required this.onLike,
    required this.onReply,
    required this.onDelete,
    required this.onAuthorTap,
  });

  final NewsComment reply;
  final int depth;
  final String? deletingCommentId;
  final ValueChanged<NewsComment> onLike;
  final ValueChanged<NewsComment> onReply;
  final ValueChanged<NewsComment> onDelete;
  final ValueChanged<NewsAuthor>? onAuthorTap;

  @override
  Widget build(BuildContext context) {
    final canReply = depth < 2;
    return Container(
      margin: EdgeInsets.only(
        left: depth == 1 ? 4 : 2,
        top: depth == 1 ? 0 : 7,
      ),
      padding: EdgeInsets.only(left: depth == 1 ? 12 : 10),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: AppColors.softLine, width: 2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AuthorTapTarget(
            author: reply.author,
            onAuthorTap: onAuthorTap,
            child: _InlineCommentAvatar(author: reply.author, size: 24),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _AuthorTapTarget(
                  author: reply.author,
                  onAuthorTap: onAuthorTap,
                  child: _InlineCommentAuthorLine(
                    author: reply.author,
                    compact: true,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  reply.body,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.inkSoft,
                    fontSize: 11.3,
                    height: 1.32,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                _InlineCommentActions(
                  comment: reply,
                  compact: true,
                  allowReply: canReply,
                  deleting: deletingCommentId == reply.id,
                  onLike: onLike,
                  onReply: onReply,
                  onDelete: onDelete,
                ),
                if (canReply && reply.replies.isNotEmpty)
                  _InlineReplyTrail(
                    reply: reply.replies.first,
                    depth: depth + 1,
                    deletingCommentId: deletingCommentId,
                    onLike: onLike,
                    onReply: onReply,
                    onDelete: onDelete,
                    onAuthorTap: onAuthorTap,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineCommentActions extends StatelessWidget {
  const _InlineCommentActions({
    required this.comment,
    required this.onLike,
    required this.onReply,
    required this.onDelete,
    this.compact = false,
    this.deleting = false,
    this.allowReply = true,
  });

  final NewsComment comment;
  final ValueChanged<NewsComment> onLike;
  final ValueChanged<NewsComment> onReply;
  final ValueChanged<NewsComment> onDelete;
  final bool compact;
  final bool deleting;
  final bool allowReply;

  @override
  Widget build(BuildContext context) {
    final likeLabel = comment.likes > 0
        ? '${CountFormat.compact(comment.likes)} beğeni'
        : 'Beğen';
    return Wrap(
      spacing: compact ? 8 : 10,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _InlineCommentAction(
          icon: comment.userLiked ? Symbols.heart_3_fill : Symbols.heart_3_line,
          label: likeLabel,
          compact: compact,
          active: comment.userLiked,
          onTap: () => onLike(comment),
        ),
        if (allowReply)
          _InlineCommentAction(
            icon: Symbols.reply_rounded,
            label: 'Yanıtla',
            compact: compact,
            onTap: () => onReply(comment),
          ),
        if (comment.canDelete)
          _InlineCommentAction(
            icon: Symbols.delete,
            label: deleting ? 'Siliniyor' : 'Sil',
            compact: compact,
            destructive: true,
            loading: deleting,
            onTap: () => onDelete(comment),
          ),
      ],
    );
  }
}

class _InlineCommentAction extends StatelessWidget {
  const _InlineCommentAction({
    required this.icon,
    required this.label,
    required this.compact,
    required this.onTap,
    this.active = false,
    this.destructive = false,
    this.loading = false,
  });

  final IconData icon;
  final String label;
  final bool compact;
  final VoidCallback onTap;
  final bool active;
  final bool destructive;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final color = active || destructive
        ? AppColors.actionRed
        : AppColors.support;
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: loading ? null : onTap,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 3 : 4,
              vertical: 3,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (loading)
                  SizedBox(
                    width: compact ? 10 : 11,
                    height: compact ? 10 : 11,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.45,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  )
                else
                  Icon(icon, size: compact ? 11 : 12, color: color),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: AppTypography.meta.copyWith(
                    color: color,
                    fontSize: compact ? 10 : 10.6,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InlineCommentAuthorLine extends StatelessWidget {
  const _InlineCommentAuthorLine({required this.author, this.compact = false});

  final NewsAuthor author;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: Text(
            author.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.titleS.copyWith(
              color: AppColors.inkStrong,
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ),
        if (author.isVerified || author.isOfficial) ...[
          const SizedBox(width: 4),
          VerifiedBadge(official: author.isOfficial, size: 11),
        ],
      ],
    );
  }
}

class _InlineCommentAvatar extends StatelessWidget {
  const _InlineCommentAvatar({required this.author, required this.size});

  final NewsAuthor author;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return ClipOval(
      child: Container(
        width: size,
        height: size,
        color: AppColors.surfaceInk,
        child: CachedImage(
          url: author.avatarUrl,
          fit: BoxFit.cover,
          memCacheWidth: (size * dpr).round(),
          placeholderColor: AppColors.surfaceInk,
          errorWidget: Container(
            color: AppColors.surfaceInk,
            alignment: Alignment.center,
            child: Text(
              _avatarInitial(author.name),
              style: AppTypography.titleS.copyWith(
                color: AppColors.deepOcean,
                fontSize: size * 0.42,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _titleCaseLabel(String value) {
  final lower = _lowerTr(value.trim());
  if (lower.isEmpty) return lower;

  final buffer = StringBuffer();
  var capitalizeNext = true;
  for (final rune in lower.runes) {
    final char = String.fromCharCode(rune);
    if (_isWordSeparator(char)) {
      capitalizeNext = true;
      buffer.write(char);
      continue;
    }
    buffer.write(capitalizeNext ? _upperFirstTr(char) : char);
    capitalizeNext = false;
  }
  return buffer.toString();
}

String _lowerTr(String value) {
  return value.replaceAll('I', 'ı').replaceAll('İ', 'i').toLowerCase();
}

String _upperFirstTr(String value) {
  if (value == 'i') return 'İ';
  if (value == 'ı') return 'I';
  return value.toUpperCase();
}

String _upperTr(String value) {
  return value.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();
}

int _safeReadMinutes(int value) => value < 1 ? 1 : value;

String _categoryLabel(List<String> categoryTrail, NewsArticle article) {
  final explicitArticleTrail = article.categoryTrail
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
  final source = categoryTrail.isNotEmpty
      ? categoryTrail
      : explicitArticleTrail.isNotEmpty
      ? explicitArticleTrail
      : [article.region, article.category];
  return source
      .map(_titleCaseLabel)
      .where((value) => value.trim().isNotEmpty)
      .join(' / ');
}

String _formatCardDate(DateTime value) {
  final date = value.toUtc().add(const Duration(hours: 3));
  final day = date.day;
  final month = _turkishMonths[date.month - 1];
  final year = date.year.toString().padLeft(4, '0');
  final weekday = _turkishWeekdays[date.weekday - 1];
  return '$day $month $year $weekday';
}

String _formatCardClock(DateTime value) {
  final date = value.toUtc().add(const Duration(hours: 3));
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

/// Yayıncı adının yanında gösterilecek kullanıcı adı (@pateez gibi).
/// Modelde handle varsa onu, yoksa addan türetir (ilk kelime, Türkçe duyarlı).
String _handleFor(NewsAuthor author) {
  final handle = author.handle?.trim() ?? '';
  if (handle.isNotEmpty) {
    return handle.startsWith('@') ? handle : '@$handle';
  }
  final first = author.name.trim().split(RegExp(r'\s+')).first;
  final slug = _lowerTr(first).replaceAll(RegExp(r'[^0-9a-zçğıiöşü]'), '');
  return slug.isEmpty ? '@pateez' : '@$slug';
}

double? _parseImageAspectRatioFromUrl(String url) {
  final segments = Uri.tryParse(url)?.pathSegments;
  if (segments != null && segments.length >= 2) {
    final h = int.tryParse(segments[segments.length - 1]);
    final w = int.tryParse(segments[segments.length - 2]);
    if (w != null && h != null && w > 0 && h > 0) return w / h;
  }
  return null;
}

String _shareUrlForArticle(NewsArticle article) {
  final slug = article.slug.trim();
  final pathSegment = slug.isNotEmpty ? slug : article.id.trim();
  if (pathSegment.isNotEmpty) return _publicArticleUrl(pathSegment);
  final videoUrl = article.primaryVideoUrl.trim();
  if (videoUrl.isNotEmpty) return _absoluteFrontendUrl(videoUrl);
  return _absoluteFrontendUrl(article.imageUrl);
}

String _publicArticleUrl(String pathSegment) {
  return Uri(
    scheme: 'https',
    host: _kPublicFrontendHost,
    pathSegments: ['haber', pathSegment],
  ).toString();
}

String _absoluteFrontendUrl(String value) {
  final raw = value.trim();
  if (raw.isEmpty) return '';
  final uri = Uri.tryParse(raw);
  if (uri != null && uri.hasScheme) return raw;
  return frontendApiUri(
    raw,
    configuredBaseUrl: _kFrontendApiBaseUrl,
  ).toString();
}

/// Görsel üstü beyaz yazıların arkasındaki yumuşak "siyah fon ışığı" (backlight).
/// Sert tek gölge değil; offset'siz iki katman → yazının çevresine yayılan zarif
/// karanlık hale. Görsel ne olursa olsun yazı okunur, çok modern ve abartısız
/// (Instagram/Apple'ın fotoğraf üstü beyaz yazı dili).
const _mediaTextShadows = [
  Shadow(color: Color(0x80000000), blurRadius: 6),
  Shadow(color: Color(0x4D000000), blurRadius: 16),
];

const _turkishMonths = [
  'Ocak',
  'Şubat',
  'Mart',
  'Nisan',
  'Mayıs',
  'Haziran',
  'Temmuz',
  'Ağustos',
  'Eylül',
  'Ekim',
  'Kasım',
  'Aralık',
];

const _turkishWeekdays = [
  'Pazartesi',
  'Salı',
  'Çarşamba',
  'Perşembe',
  'Cuma',
  'Cumartesi',
  'Pazar',
];

String _avatarInitial(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return 'P';
  return _upperFirstTr(trimmed.characters.first);
}

bool _isWordSeparator(String value) {
  return value == ' ' ||
      value == '\t' ||
      value == '\n' ||
      value == '/' ||
      value == '-' ||
      value == '_' ||
      value == '.';
}
