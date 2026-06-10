import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show FontFeature, ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../../../core/brand/default_brand_assets.dart';
import '../../../../core/mock/home_mock_data.dart';
import '../../../../core/network/local_api_base_url.dart';
import '../../../../core/platform/debug_platform_view_hot_restart.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/cached_image.dart';
import '../../../../shared/widgets/frontend_toast.dart';
import '../../../../shared/widgets/verified_badge.dart';
import '../../../account/data/frontend_auth_repository.dart';
import '../../data/post_action_repository.dart';

/// Ana sayfa haber kartında "video" bloğu seçiliyse oynatılan video.
///
/// Tek bir API; dört kaynağı da eksiksiz oynatır:
///   • Yerel (sunucuya yüklenmiş) ve uzak video dosyaları → [video_player]
///   • YouTube ve YouTube Shorts bağlantıları → [youtube_player_iframe]
///
/// Davranış (tüm kaynaklar için aynı):
///   • Yatay video TAM olarak ekranda görünürse otomatik oynar; zerresi bile
///     kaybolursa anında durur ([visibility_detector], eşik %99).
///   • Dikey video tam sığmayacağı için ortadaki play alanı görünür kaldığı
///     sürece otomatik oynar; o alan kırpılmaya başlayınca durur.
///   • Ortada şık play/pause, altta kalınca KIRMIZI dolan ilerleme çubuğu, sağda
///     videonun süresinden GERİYE sayan sayaç, sağ üstte sessize alma.
///   • Görünüm resim gibidir: tam genişlik, yükseklik videonun oranına göre.
class NewsVideoPlayer extends StatelessWidget {
  const NewsVideoPlayer({
    super.key,
    required this.url,
    this.poster = '',
    this.topOverlay,
    this.fullscreenFeed = const [],
    this.fullscreenLogoUrl = '',
    this.visibilityScope = '',
    this.autoPlayWhenReady = false,
    this.showFullscreenButton = true,
    this.authState,
    this.postActionRepository = const PostActionRepository(),
    this.onAuthRequired,
    this.onFullscreenVideoExit,
    this.onAspectRatioResolved,
  });

  final String url;
  final String poster;
  final Widget? topOverlay;
  final List<NewsVideoFeedItem> fullscreenFeed;
  final String fullscreenLogoUrl;
  final String visibilityScope;
  final bool autoPlayWhenReady;
  final bool showFullscreenButton;
  final FrontendAuthState? authState;
  final PostActionRepository postActionRepository;
  final VoidCallback? onAuthRequired;
  final ValueChanged<NewsVideoFeedItem>? onFullscreenVideoExit;
  final ValueChanged<double>? onAspectRatioResolved;

  @override
  Widget build(BuildContext context) {
    final feed = _fullscreenItemsFor(
      url: url,
      poster: poster,
      topOverlay: topOverlay,
      fullscreenLogoUrl: fullscreenLogoUrl,
      items: fullscreenFeed,
    );
    final youtubeId = _youtubeIdFrom(url);
    if (youtubeId != null && youtubeId.isNotEmpty) {
      return _YoutubeVideoView(
        key: ValueKey('yt-$youtubeId'),
        videoId: youtubeId,
        isShorts: _isShortsUrl(url),
        url: url,
        poster: poster,
        topOverlay: topOverlay,
        fullscreenFeed: feed,
        fullscreenLogoUrl: fullscreenLogoUrl,
        visibilityScope: visibilityScope,
        autoPlayWhenReady: autoPlayWhenReady,
        showFullscreenButton: showFullscreenButton,
        authState: authState,
        postActionRepository: postActionRepository,
        onAuthRequired: onAuthRequired,
        onFullscreenVideoExit: onFullscreenVideoExit,
        onAspectRatioResolved: onAspectRatioResolved,
      );
    }
    return _FileVideoView(
      key: ValueKey('vid-$url'),
      url: url,
      poster: poster,
      topOverlay: topOverlay,
      fullscreenFeed: feed,
      fullscreenLogoUrl: fullscreenLogoUrl,
      visibilityScope: visibilityScope,
      autoPlayWhenReady: autoPlayWhenReady,
      showFullscreenButton: showFullscreenButton,
      authState: authState,
      postActionRepository: postActionRepository,
      onAuthRequired: onAuthRequired,
      onFullscreenVideoExit: onFullscreenVideoExit,
      onAspectRatioResolved: onAspectRatioResolved,
    );
  }
}

@immutable
class NewsVideoFeedItem {
  const NewsVideoFeedItem({
    this.postId = '',
    required this.url,
    required this.poster,
    required this.publishedAt,
    this.slug = '',
    this.title = '',
    this.author,
    this.region = '',
    this.category = '',
    this.categoryTrail = const [],
    this.likes = 0,
    this.dislikes = 0,
    this.comments = 0,
    this.shares = 0,
    this.saves = 0,
    this.userLiked = false,
    this.userDisliked = false,
    this.userSaved = false,
    this.fullscreenLogoUrl = '',
    this.topOverlay,
  });

  final String postId;
  final String url;
  final String poster;
  final DateTime publishedAt;
  final String slug;
  final String title;
  final NewsAuthor? author;
  final String region;
  final String category;
  final List<String> categoryTrail;
  final int likes;
  final int dislikes;
  final int comments;
  final int shares;
  final int saves;
  final bool userLiked;
  final bool userDisliked;
  final bool userSaved;
  final String fullscreenLogoUrl;
  final Widget? topOverlay;

  bool get hasArticleInfo => title.trim().isNotEmpty || author != null;
}

class NewsFullscreenVideoFeedPage extends StatefulWidget {
  const NewsFullscreenVideoFeedPage({
    super.key,
    required this.items,
    this.initialIndex = 0,
    this.authState,
    this.postActionRepository = const PostActionRepository(),
    this.onAuthRequired,
  });

  final List<NewsVideoFeedItem> items;
  final int initialIndex;
  final FrontendAuthState? authState;
  final PostActionRepository postActionRepository;
  final VoidCallback? onAuthRequired;

  @override
  State<NewsFullscreenVideoFeedPage> createState() =>
      _NewsFullscreenVideoFeedPageState();
}

class _NewsFullscreenVideoFeedPageState
    extends State<NewsFullscreenVideoFeedPage> {
  late int _activeIndex;

  @override
  void initState() {
    super.initState();
    _activeIndex = _clampedInitialIndex();
  }

  int _clampedInitialIndex() {
    if (widget.items.isEmpty) return 0;
    return widget.initialIndex.clamp(0, widget.items.length - 1).toInt();
  }

  void _exit() => Navigator.of(context).pop(_activeIndex);

  void _exitWithIndex(int index) => Navigator.of(context).pop(index);

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return Material(
        color: Colors.black,
        child: SafeArea(
          child: _FullscreenTopBar(logoUrl: '', onExit: _exit),
        ),
      );
    }

    final initialIndex = _clampedInitialIndex();
    return _FullscreenVideoPager(
      items: widget.items,
      initialIndex: initialIndex,
      currentUrl: '',
      onExit: _exitWithIndex,
      onPageChanged: (index) => _activeIndex = index,
      currentPageBuilder: ({bool showTopBar = true}) => const SizedBox.shrink(),
      authState: widget.authState,
      postActionRepository: widget.postActionRepository,
      onAuthRequired: widget.onAuthRequired,
    );
  }
}

// Görünürlük eşiği: bu oranın altına düşen (yani bir parçası bile kaybolan) video
// anında durur. 0.99 = sub-pixel yuvarlamaya tolerans tanıyan "tamamen görünür".
const double _kVisibleThreshold = 0.99;
const double _kCenterButtonDiameter = 66;
const double _kVisibilityEpsilon = 1;
const double _kFullscreenTopBarHeight = 58;
const String _kFrontendApiBaseUrl = String.fromEnvironment(
  'PATEEZNEWS_API_BASE_URL',
);
const Duration _kDoubleTapSeekForward = Duration(seconds: 10);
const Duration _kDoubleTapSeekBackward = Duration(seconds: -10);
const Duration _kDoubleTapSeekFeedbackDuration = Duration(milliseconds: 980);
const List<double> _kPlaybackSpeeds = [1.0, 1.5, 2.0];
const IconData _kReplyAllLineIcon = IconData(
  0xf078,
  fontFamily: 'RemixIcon',
  matchTextDirection: true,
);

// Tam ekran dikey kaydırma kılavuzu: açılışta uzun, sayfa değişiminde kısa görünür.
const Duration _kCoachOpenDuration = Duration(milliseconds: 3600);
const Duration _kCoachPulseDuration = Duration(milliseconds: 2600);
const Duration _kCoachRepeatInterval = Duration(seconds: 13);

// Marka vurgusu: "Güçlü Kırmızı" (AppColors.actionRed) jest kılavuzlarında
// enerji rengi olarak kullanılır.
const Color _kCoachAccent = Color(0xFFEA4335);

bool _lastVideoMuted = false;

class _PlaybackSnapshot {
  const _PlaybackSnapshot({required this.shouldPlay, required this.position});

  final bool shouldPlay;
  final Duration position;
}

NewsVideoFeedItem _fullscreenItemForUrl(
  List<NewsVideoFeedItem> items,
  String url,
) {
  final currentUrl = url.trim();
  for (final item in items) {
    if (item.url.trim() == currentUrl) return item;
  }
  return NewsVideoFeedItem(
    url: currentUrl,
    poster: '',
    publishedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );
}

double _nextPlaybackSpeed(double current) {
  final index = _kPlaybackSpeeds.indexWhere(
    (speed) => (speed - current).abs() < 0.01,
  );
  if (index < 0 || index == _kPlaybackSpeeds.length - 1) {
    return _kPlaybackSpeeds.first;
  }
  return _kPlaybackSpeeds[index + 1];
}

String _formatPlaybackSpeed(double speed) {
  if ((speed - speed.roundToDouble()).abs() < 0.01) {
    return '${speed.round()}x';
  }
  return '${speed.toStringAsFixed(1)}x';
}

bool _visTuned = false;
void _tuneVisibility() {
  if (_visTuned) return;
  _visTuned = true;
  // Varsayılan 500 ms gecikmesini düşür → görünür/kayboldu kararı "ışık hızında".
  VisibilityDetectorController.instance.updateInterval = const Duration(
    milliseconds: 60,
  );
}

String? _youtubeIdFrom(String url) {
  final raw = url.trim();
  if (RegExp(r'^[_\-a-zA-Z0-9]{11}$').hasMatch(raw)) return raw;

  var uri = Uri.tryParse(raw);
  if (uri != null && !uri.hasScheme && raw.contains('youtube')) {
    uri = Uri.tryParse('https://$raw');
  }
  final host = uri?.host.toLowerCase() ?? '';
  if (!host.contains('youtube.com') &&
      !host.contains('youtu.be') &&
      !host.contains('youtube-nocookie.com')) {
    return null;
  }

  final fromPackage = YoutubePlayerController.convertUrlToId(raw);
  if (fromPackage != null && fromPackage.isNotEmpty) return fromPackage;

  if (host.contains('youtu.be')) {
    return _cleanYoutubeId(uri?.pathSegments.first);
  }
  final segments = uri?.pathSegments ?? const <String>[];
  for (var i = 0; i < segments.length - 1; i++) {
    final segment = segments[i].toLowerCase();
    if (segment == 'shorts' || segment == 'embed' || segment == 'live') {
      return _cleanYoutubeId(segments[i + 1]);
    }
  }
  return _cleanYoutubeId(uri?.queryParameters['v']);
}

bool _isShortsUrl(String url) => url.toLowerCase().contains('/shorts/');

String? _cleanYoutubeId(String? value) {
  final raw = value?.trim();
  if (raw == null || raw.isEmpty) return null;
  final match = RegExp(r'[_\-a-zA-Z0-9]{11}').firstMatch(raw);
  return match?.group(0);
}

Duration _clampSeekPosition(Duration position, Duration duration) {
  if (position.isNegative) return Duration.zero;
  if (duration > Duration.zero && position > duration) return duration;
  return position;
}

List<NewsVideoFeedItem> _fullscreenItemsFor({
  required String url,
  required String poster,
  required Widget? topOverlay,
  required String fullscreenLogoUrl,
  required List<NewsVideoFeedItem> items,
}) {
  final currentUrl = url.trim();
  final byUrl = <String, NewsVideoFeedItem>{};
  for (final item in items) {
    final itemUrl = item.url.trim();
    if (itemUrl.isEmpty) continue;
    byUrl.putIfAbsent(itemUrl, () => item);
  }
  if (currentUrl.isNotEmpty) {
    byUrl.putIfAbsent(
      currentUrl,
      () => NewsVideoFeedItem(
        url: currentUrl,
        poster: poster,
        publishedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        fullscreenLogoUrl: fullscreenLogoUrl,
        topOverlay: topOverlay,
      ),
    );
  }
  final resolved = byUrl.values.toList()
    ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
  return List<NewsVideoFeedItem>.unmodifiable(resolved);
}

int _initialFullscreenFeedIndex(
  List<NewsVideoFeedItem> items,
  String currentUrl,
) {
  final target = currentUrl.trim();
  final index = items.indexWhere((item) => item.url.trim() == target);
  return index < 0 ? 0 : index;
}

bool _shouldAutoPlayForVisibility(
  VisibilityInfo info, {
  required double aspectRatio,
}) {
  final size = info.size;
  final visible = info.visibleBounds;
  if (size.isEmpty || visible.isEmpty) return false;

  final verticalVideo = aspectRatio > 0 && aspectRatio < 1;
  if (!verticalVideo) return info.visibleFraction >= _kVisibleThreshold;

  final centerX = size.width / 2;
  final centerButtonHeight = size.height < _kCenterButtonDiameter
      ? size.height
      : _kCenterButtonDiameter;
  final centerTop = (size.height - centerButtonHeight) / 2;
  final centerBottom = centerTop + centerButtonHeight;

  return visible.left <= centerX + _kVisibilityEpsilon &&
      visible.right >= centerX - _kVisibilityEpsilon &&
      visible.top <= centerTop + _kVisibilityEpsilon &&
      visible.bottom >= centerBottom - _kVisibilityEpsilon;
}

Key _videoVisibilityKey({
  required String source,
  required String identity,
  required String scope,
}) {
  final cleanScope = scope.trim();
  final prefix = cleanScope.isEmpty
      ? (source == 'file' ? '' : '$source-')
      : '$source-$cleanScope-';
  return ValueKey<String>('vis-$prefix$identity');
}

// ---------------------------------------------------------------------------
// Yerel / uzak video (video_player)
// ---------------------------------------------------------------------------

class _FileVideoView extends StatefulWidget {
  const _FileVideoView({
    super.key,
    required this.url,
    required this.poster,
    required this.topOverlay,
    required this.fullscreenFeed,
    required this.fullscreenLogoUrl,
    required this.visibilityScope,
    required this.autoPlayWhenReady,
    required this.showFullscreenButton,
    required this.authState,
    required this.postActionRepository,
    required this.onAuthRequired,
    required this.onFullscreenVideoExit,
    required this.onAspectRatioResolved,
  });

  final String url;
  final String poster;
  final Widget? topOverlay;
  final List<NewsVideoFeedItem> fullscreenFeed;
  final String fullscreenLogoUrl;
  final String visibilityScope;
  final bool autoPlayWhenReady;
  final bool showFullscreenButton;
  final FrontendAuthState? authState;
  final PostActionRepository postActionRepository;
  final VoidCallback? onAuthRequired;
  final ValueChanged<NewsVideoFeedItem>? onFullscreenVideoExit;
  final ValueChanged<double>? onAspectRatioResolved;

  @override
  State<_FileVideoView> createState() => _FileVideoViewState();
}

class _FileVideoViewState extends State<_FileVideoView> {
  VideoPlayerController? _controller;
  bool _initFailed = false;
  bool _autoPlayableVisible = false;
  bool _userPaused = false;
  bool _fullscreenActive = false;
  OverlayEntry? _fullscreenOverlay;
  int _surfaceMoveSerial = 0;
  double _playbackSpeed = 1.0;

  bool get _shouldAutoPlay => widget.autoPlayWhenReady || _autoPlayableVisible;

  @override
  void initState() {
    super.initState();
    _tuneVisibility();
    _autoPlayableVisible = widget.autoPlayWhenReady;
    _setup();
  }

  Future<void> _setup() async {
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.url),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _controller = controller;
    try {
      await controller.setLooping(true);
      await controller.setVolume(_lastVideoMuted ? 0 : 1);
      await controller.initialize();
      await controller.setPlaybackSpeed(_playbackSpeed);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      _notifyAspectRatioResolved(controller.value.aspectRatio);
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) VisibilityDetectorController.instance.notifyNow();
      });
      _applyPlayback();
    } catch (_) {
      if (!mounted) return;
      setState(() => _initFailed = true);
    }
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    final controller = _controller;
    final ratio =
        controller != null &&
            controller.value.isInitialized &&
            controller.value.aspectRatio > 0
        ? controller.value.aspectRatio
        : 16 / 9;
    final visible = _shouldAutoPlayForVisibility(info, aspectRatio: ratio);
    if (visible == _autoPlayableVisible) return;
    _autoPlayableVisible = visible;
    _applyPlayback();
  }

  void _applyPlayback() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (_fullscreenActive) return;
    if (_shouldAutoPlay && !_userPaused) {
      controller.play();
    } else {
      controller.pause();
    }
  }

  void _togglePlay() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isPlaying) {
      _userPaused = true;
      controller.pause();
    } else {
      _userPaused = false;
      controller.play();
    }
  }

  void _toggleMute() {
    final controller = _controller;
    if (controller == null) return;
    final muted = controller.value.volume != 0;
    _lastVideoMuted = muted;
    controller.setVolume(muted ? 0.0 : 1.0);
  }

  void _togglePlaybackSpeed() {
    final next = _nextPlaybackSpeed(_playbackSpeed);
    setState(() => _playbackSpeed = next);
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    unawaited(controller.setPlaybackSpeed(next));
  }

  void _seek(double fraction) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final ms = (controller.value.duration.inMilliseconds * fraction).round();
    controller.seekTo(Duration(milliseconds: ms < 0 ? 0 : ms));
  }

  void _seekRelative(Duration offset) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final value = controller.value;
    final target = _clampSeekPosition(value.position + offset, value.duration);
    unawaited(controller.seekTo(target));
  }

  void _toggleFullscreen() {
    if (_fullscreenActive) {
      _closeFullscreenOverlay(
        selectedIndex: _initialFullscreenFeedIndex(
          widget.fullscreenFeed,
          widget.url,
        ),
      );
      return;
    }
    _openFullscreenOverlay();
  }

  void _openFullscreenOverlay() {
    if (_fullscreenOverlay != null) return;
    final snapshot = _playbackSnapshot();
    final serial = ++_surfaceMoveSerial;
    setState(() => _fullscreenActive = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          serial != _surfaceMoveSerial ||
          !_fullscreenActive ||
          _fullscreenOverlay != null) {
        return;
      }
      _fullscreenOverlay = OverlayEntry(builder: _buildFullscreenOverlay);
      Overlay.of(context, rootOverlay: true).insert(_fullscreenOverlay!);
      _restorePlaybackAfterSurfaceMove(snapshot, serial);
    });
  }

  void _closeFullscreenOverlay({int? selectedIndex}) {
    final overlay = _fullscreenOverlay;
    if (overlay == null) {
      if (selectedIndex != null) _notifyFullscreenVideoExit(selectedIndex);
      if (mounted) setState(() => _fullscreenActive = false);
      return;
    }
    final snapshot = _playbackSnapshot();
    final serial = ++_surfaceMoveSerial;
    overlay.remove();
    _fullscreenOverlay = null;
    if (selectedIndex != null) _notifyFullscreenVideoExit(selectedIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || serial != _surfaceMoveSerial) return;
      setState(() => _fullscreenActive = false);
      VisibilityDetectorController.instance.notifyNow();
      _applyPlayback();
      _restorePlaybackAfterSurfaceMove(snapshot, serial);
    });
  }

  void _notifyFullscreenVideoExit(int selectedIndex) {
    final items = widget.fullscreenFeed;
    if (items.isEmpty) return;
    final index = selectedIndex.clamp(0, items.length - 1).toInt();
    widget.onFullscreenVideoExit?.call(items[index]);
  }

  void _notifyAspectRatioResolved(double ratio) {
    if (!ratio.isFinite || ratio <= 0) return;
    widget.onAspectRatioResolved?.call(ratio);
  }

  _PlaybackSnapshot _playbackSnapshot() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const _PlaybackSnapshot(
        shouldPlay: false,
        position: Duration.zero,
      );
    }
    return _PlaybackSnapshot(
      shouldPlay:
          controller.value.isPlaying || (_shouldAutoPlay && !_userPaused),
      position: controller.value.position,
    );
  }

  void _restorePlaybackAfterSurfaceMove(
    _PlaybackSnapshot snapshot,
    int serial,
  ) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || serial != _surfaceMoveSerial) return;
      unawaited(_syncPlaybackToSnapshot(snapshot, serial));
    });
  }

  Future<void> _syncPlaybackToSnapshot(
    _PlaybackSnapshot snapshot,
    int serial,
  ) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (!mounted || serial != _surfaceMoveSerial) return;

    final duration = controller.value.duration;
    var position = snapshot.position.isNegative
        ? Duration.zero
        : snapshot.position;
    if (duration > Duration.zero && position > duration) {
      position = duration;
    }

    final currentMs = controller.value.position.inMilliseconds;
    final targetMs = position.inMilliseconds;
    if ((currentMs - targetMs).abs() > 250) {
      await controller.seekTo(position);
      if (!mounted || serial != _surfaceMoveSerial) return;
    }

    if (snapshot.shouldPlay) {
      _userPaused = false;
      await controller.setPlaybackSpeed(_playbackSpeed);
      await controller.play();
    } else {
      await controller.pause();
    }
  }

  void _handleFullscreenPageChanged(int index) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final initialIndex = _initialFullscreenFeedIndex(
      widget.fullscreenFeed,
      widget.url,
    );
    if (index == initialIndex) {
      if (!_userPaused) unawaited(controller.play());
    } else {
      unawaited(controller.pause());
    }
  }

  Widget _buildCurrentFullscreenPage({
    bool showTopBar = true,
    VoidCallback? onExit,
  }) {
    final controller = _controller;
    final initialized = controller?.value.isInitialized ?? false;
    final ratio = initialized && controller!.value.aspectRatio > 0
        ? controller.value.aspectRatio
        : 16 / 9;
    final item = _fullscreenItemForUrl(widget.fullscreenFeed, widget.url);

    return _FullscreenScaffold(
      aspectRatio: ratio,
      item: item,
      onExit: onExit ?? _toggleFullscreen,
      showTopBar: showTopBar,
      authState: widget.authState,
      postActionRepository: widget.postActionRepository,
      onAuthRequired: widget.onAuthRequired,
      child: ColoredBox(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (!initialized) _PosterOrPlaceholder(poster: widget.poster),
            if (initialized) VideoPlayer(controller!),
            if (initialized)
              ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: controller!,
                builder: (context, value, _) => Stack(
                  fit: StackFit.expand,
                  children: [
                    if (!value.isPlaying || value.isBuffering)
                      _PosterOrPlaceholder(poster: widget.poster),
                    _VideoControls(
                      isPlaying: value.isPlaying,
                      isMuted: value.volume == 0,
                      isBuffering: value.isBuffering,
                      position: value.position,
                      duration: value.duration,
                      topOverlay: null,
                      showCenterWhilePlaying: true,
                      fullscreen: true,
                      playbackSpeed: _playbackSpeed,
                      showFullscreenButton: false,
                      onTogglePlay: _togglePlay,
                      onToggleMute: _toggleMute,
                      onToggleSpeed: _togglePlaybackSpeed,
                      onToggleFullscreen: _toggleFullscreen,
                      onSeek: _seek,
                      onSeekRelative: _seekRelative,
                    ),
                  ],
                ),
              )
            else
              _VideoControls(
                isPlaying: false,
                isMuted: _lastVideoMuted,
                isBuffering: !_initFailed,
                position: Duration.zero,
                duration: Duration.zero,
                topOverlay: null,
                showCenterWhilePlaying: true,
                fullscreen: true,
                playbackSpeed: _playbackSpeed,
                showFullscreenButton: false,
                onTogglePlay: _togglePlay,
                onToggleMute: _toggleMute,
                onToggleSpeed: _togglePlaybackSpeed,
                onToggleFullscreen: _toggleFullscreen,
                onSeek: _seek,
                onSeekRelative: _seekRelative,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullscreenOverlay(BuildContext context) {
    final items = widget.fullscreenFeed;
    if (items.length <= 1) {
      return Material(
        color: Colors.black,
        child: SafeArea(
          child: _buildCurrentFullscreenPage(
            onExit: () => _closeFullscreenOverlay(selectedIndex: 0),
          ),
        ),
      );
    }

    final initialIndex = _initialFullscreenFeedIndex(items, widget.url);
    return _FullscreenVideoPager(
      items: items,
      initialIndex: initialIndex,
      currentUrl: widget.url,
      onExit: (index) => _closeFullscreenOverlay(selectedIndex: index),
      onPageChanged: _handleFullscreenPageChanged,
      currentPageBuilder: _buildCurrentFullscreenPage,
      authState: widget.authState,
      postActionRepository: widget.postActionRepository,
      onAuthRequired: widget.onAuthRequired,
    );
  }

  @override
  void dispose() {
    _fullscreenOverlay?.remove();
    _fullscreenOverlay = null;
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final initialized = controller?.value.isInitialized ?? false;
    final ratio = initialized && controller!.value.aspectRatio > 0
        ? controller.value.aspectRatio
        : 16 / 9;

    return VisibilityDetector(
      key: _videoVisibilityKey(
        source: 'file',
        identity: widget.url,
        scope: widget.visibilityScope,
      ),
      onVisibilityChanged: _onVisibilityChanged,
      child: AspectRatio(
        aspectRatio: ratio,
        child: ColoredBox(
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_fullscreenActive || !initialized)
                _PosterOrPlaceholder(poster: widget.poster),
              if (!_fullscreenActive && initialized) VideoPlayer(controller!),
              if (!_fullscreenActive && initialized)
                ValueListenableBuilder<VideoPlayerValue>(
                  valueListenable: controller!,
                  builder: (context, value, _) => Stack(
                    fit: StackFit.expand,
                    children: [
                      if (!value.isPlaying || value.isBuffering)
                        _PosterOrPlaceholder(poster: widget.poster),
                      _VideoControls(
                        isPlaying: value.isPlaying,
                        isMuted: value.volume == 0,
                        isBuffering: value.isBuffering,
                        position: value.position,
                        duration: value.duration,
                        topOverlay: widget.topOverlay,
                        showCenterWhilePlaying: true,
                        fullscreen: false,
                        playbackSpeed: _playbackSpeed,
                        showFullscreenButton: widget.showFullscreenButton,
                        onTogglePlay: _togglePlay,
                        onToggleMute: _toggleMute,
                        onToggleSpeed: _togglePlaybackSpeed,
                        onToggleFullscreen: _toggleFullscreen,
                        onSeek: _seek,
                        onSeekRelative: _seekRelative,
                      ),
                    ],
                  ),
                )
              else if (!_fullscreenActive)
                _VideoControls(
                  isPlaying: false,
                  isMuted: _lastVideoMuted,
                  isBuffering: !_initFailed,
                  position: Duration.zero,
                  duration: Duration.zero,
                  topOverlay: widget.topOverlay,
                  showCenterWhilePlaying: true,
                  fullscreen: false,
                  playbackSpeed: _playbackSpeed,
                  showFullscreenButton: widget.showFullscreenButton,
                  onTogglePlay: _togglePlay,
                  onToggleMute: _toggleMute,
                  onToggleSpeed: _togglePlaybackSpeed,
                  onToggleFullscreen: _toggleFullscreen,
                  onSeek: _seek,
                  onSeekRelative: _seekRelative,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// YouTube / YouTube Shorts (youtube_player_iframe)
// ---------------------------------------------------------------------------

class _YoutubeVideoView extends StatefulWidget {
  const _YoutubeVideoView({
    super.key,
    required this.videoId,
    required this.isShorts,
    required this.url,
    required this.poster,
    required this.topOverlay,
    required this.fullscreenFeed,
    required this.fullscreenLogoUrl,
    required this.visibilityScope,
    required this.autoPlayWhenReady,
    required this.showFullscreenButton,
    required this.authState,
    required this.postActionRepository,
    required this.onAuthRequired,
    required this.onFullscreenVideoExit,
    required this.onAspectRatioResolved,
  });

  final String videoId;
  final bool isShorts;
  final String url;
  final String poster;
  final Widget? topOverlay;
  final List<NewsVideoFeedItem> fullscreenFeed;
  final String fullscreenLogoUrl;
  final String visibilityScope;
  final bool autoPlayWhenReady;
  final bool showFullscreenButton;
  final FrontendAuthState? authState;
  final PostActionRepository postActionRepository;
  final VoidCallback? onAuthRequired;
  final ValueChanged<NewsVideoFeedItem>? onFullscreenVideoExit;
  final ValueChanged<double>? onAspectRatioResolved;

  @override
  State<_YoutubeVideoView> createState() => _YoutubeVideoViewState();
}

class _YoutubeVideoViewState extends State<_YoutubeVideoView> {
  late final YoutubePlayerController _controller;
  StreamSubscription<YoutubeVideoState>? _stateSub;
  StreamSubscription<YoutubePlayerValue>? _valueSub;

  late final ValueNotifier<_VideoUi> _ui;

  bool _autoPlayableVisible = false;
  bool _userPaused = false;
  bool _playerReady = false;
  bool _webViewReady = !kDebugMode;
  bool _hasRenderedVideoFrame = false;
  bool _hasLoadedVideo = false;
  bool _fullscreenActive = false;
  OverlayEntry? _fullscreenOverlay;
  late bool _youtubeMuted;
  int _playSerial = 0;
  int _surfaceMoveSerial = 0;
  double _playbackSpeed = 1.0;

  bool get _shouldAutoPlay => widget.autoPlayWhenReady || _autoPlayableVisible;

  @override
  void initState() {
    super.initState();
    _tuneVisibility();
    _autoPlayableVisible = widget.autoPlayWhenReady;
    _youtubeMuted = _initialYoutubeMuted();
    _ui = ValueNotifier<_VideoUi>(_VideoUi(muted: _youtubeMuted));
    _controller = YoutubePlayerController(
      key: widget.videoId,
      params: _youtubeParams(),
    );
    _stateSub = _controller.videoStateStream.listen((state) {
      if (!mounted) return;
      _ui.value = _ui.value.copyWith(position: state.position);
    });
    _valueSub = _controller.stream.listen((value) {
      if (!mounted) return;
      final duration = value.metaData.duration;
      final hasFrame =
          _hasRenderedVideoFrame ||
          value.playerState == PlayerState.playing ||
          value.playerState == PlayerState.paused ||
          value.playerState == PlayerState.ended;
      if (hasFrame != _hasRenderedVideoFrame && mounted) {
        setState(() => _hasRenderedVideoFrame = hasFrame);
      }
      _ui.value = _ui.value.copyWith(
        isPlaying: value.playerState == PlayerState.playing,
        isBuffering:
            value.playerState == PlayerState.buffering ||
            value.playerState == PlayerState.unknown ||
            value.playerState == PlayerState.unStarted,
        duration: duration > Duration.zero ? duration : null,
      );
    });
    if (kDebugMode) unawaited(_prepareWebViewSurface());
    unawaited(_setup());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onAspectRatioResolved?.call(widget.isShorts ? 9 / 16 : 16 / 9);
    });
  }

  Future<void> _prepareWebViewSurface() async {
    await prepareDebugDarwinPlatformViewsForHotRestart();
    await _nextFrame();
    await _nextFrame();
    if (!mounted) return;
    setState(() => _webViewReady = true);
  }

  Future<void> _nextFrame() {
    final completer = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) => completer.complete());
    return completer.future;
  }

  YoutubePlayerParams _youtubeParams() {
    return YoutubePlayerParams(
      pointerEvents: PointerEvents.none,
      showControls: false,
      showFullscreenButton: false,
      mute: _youtubeMuted,
      loop: true,
      enableCaption: false,
      strictRelatedVideos: true,
      playsInline: true,
    );
  }

  bool _initialYoutubeMuted() => _lastVideoMuted;

  Future<void> _setup() async {
    try {
      await _controller.initWithParams(params: _youtubeParams());
      if (!mounted) return;
      if (!widget.isShorts && !widget.autoPlayWhenReady) {
        await _guardYoutubeCommand(
          () => _controller.cueVideoById(videoId: widget.videoId),
        );
      }
      if (!mounted) return;
      _playerReady = true;
      _applyMutePreference();
      unawaited(_applyPlaybackSpeed());
      _applyPlayback();
    } catch (_) {
      if (!mounted) return;
      _ui.value = _ui.value.copyWith(isBuffering: false);
    }
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    final ratio = widget.isShorts ? 9 / 16 : 16 / 9;
    final visible = _shouldAutoPlayForVisibility(info, aspectRatio: ratio);
    if (visible == _autoPlayableVisible) return;
    _autoPlayableVisible = visible;
    if (mounted) setState(() {});
    _applyPlayback();
  }

  void _applyPlayback() {
    if (_fullscreenActive) return;
    if (_shouldAutoPlay && !_userPaused) {
      unawaited(_startPlayback());
    } else {
      _playSerial++;
      if (_playerReady) {
        unawaited(_guardYoutubeCommand(_controller.pauseVideo));
      }
    }
  }

  Future<void> _startPlayback({
    Duration? startAt,
    bool allowSurfaceMove = false,
  }) async {
    if (!_playerReady || !mounted) return;
    await _guardYoutubeCommand(() async {
      final serial = ++_playSerial;
      _applyMutePreference();
      bool canContinue() =>
          mounted &&
          serial == _playSerial &&
          (allowSurfaceMove || _fullscreenActive || _shouldAutoPlay) &&
          !_userPaused;
      final startSeconds = _youtubeSeconds(startAt);
      if (!_hasLoadedVideo) {
        await _controller.loadVideoById(
          videoId: widget.videoId,
          startSeconds: startSeconds,
        );
        _hasLoadedVideo = true;
        await _applyPlaybackSpeed();
        if (canContinue()) {
          await _controller.playVideo();
        }
      } else {
        if (startSeconds != null) {
          await _controller.seekTo(seconds: startSeconds, allowSeekAhead: true);
          if (!canContinue()) {
            await _controller.pauseVideo();
            return;
          }
        }
        await _applyPlaybackSpeed();
        await _controller.playVideo();
      }
      if (!canContinue()) {
        await _controller.pauseVideo();
        return;
      }
      _applyMutePreference();
    });
  }

  Future<void> _applyPlaybackSpeed() async {
    if (!_playerReady || !mounted) return;
    await _guardYoutubeCommand(
      () => _controller.setPlaybackRate(_playbackSpeed),
    );
  }

  Future<void> _guardYoutubeCommand(FutureOr<void> Function() command) async {
    try {
      await Future<void>.sync(command);
    } catch (_) {
      if (!mounted) return;
      _playSerial++;
      _ui.value = _ui.value.copyWith(isPlaying: false, isBuffering: false);
    }
  }

  void _applyMutePreference() {
    if (_ui.value.muted != _youtubeMuted) {
      _ui.value = _ui.value.copyWith(muted: _youtubeMuted);
    }
    if (!_playerReady || !mounted) return;
    unawaited(
      _guardYoutubeCommand(
        () => _youtubeMuted ? _controller.mute() : _controller.unMute(),
      ),
    );
  }

  void _togglePlay() {
    if (_ui.value.isPlaying) {
      _userPaused = true;
      _playSerial++;
      if (_playerReady) {
        unawaited(_guardYoutubeCommand(_controller.pauseVideo));
      }
    } else {
      _userPaused = false;
      unawaited(_startPlayback());
    }
  }

  void _toggleMute() {
    final muted = !_youtubeMuted;
    _youtubeMuted = muted;
    _lastVideoMuted = muted;
    _applyMutePreference();
  }

  void _togglePlaybackSpeed() {
    final next = _nextPlaybackSpeed(_playbackSpeed);
    setState(() => _playbackSpeed = next);
    if (_playerReady) unawaited(_applyPlaybackSpeed());
  }

  void _toggleFullscreen() {
    if (_fullscreenActive) {
      _closeFullscreenOverlay(
        selectedIndex: _initialFullscreenFeedIndex(
          widget.fullscreenFeed,
          widget.url,
        ),
      );
      return;
    }
    _openFullscreenOverlay();
  }

  void _openFullscreenOverlay() {
    if (_fullscreenOverlay != null) return;
    final snapshot = _playbackSnapshot();
    final serial = ++_surfaceMoveSerial;
    setState(() => _fullscreenActive = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          serial != _surfaceMoveSerial ||
          !_fullscreenActive ||
          _fullscreenOverlay != null) {
        return;
      }
      _fullscreenOverlay = OverlayEntry(builder: _buildFullscreenOverlay);
      Overlay.of(context, rootOverlay: true).insert(_fullscreenOverlay!);
      _restorePlaybackAfterSurfaceMove(snapshot, serial);
    });
  }

  void _closeFullscreenOverlay({int? selectedIndex}) {
    final overlay = _fullscreenOverlay;
    if (overlay == null) {
      if (selectedIndex != null) _notifyFullscreenVideoExit(selectedIndex);
      if (mounted) setState(() => _fullscreenActive = false);
      return;
    }
    final snapshot = _playbackSnapshot();
    final serial = ++_surfaceMoveSerial;
    overlay.remove();
    _fullscreenOverlay = null;
    if (selectedIndex != null) _notifyFullscreenVideoExit(selectedIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || serial != _surfaceMoveSerial) return;
      setState(() => _fullscreenActive = false);
      VisibilityDetectorController.instance.notifyNow();
      _applyPlayback();
      _restorePlaybackAfterSurfaceMove(snapshot, serial);
    });
  }

  void _notifyFullscreenVideoExit(int selectedIndex) {
    final items = widget.fullscreenFeed;
    if (items.isEmpty) return;
    final index = selectedIndex.clamp(0, items.length - 1).toInt();
    widget.onFullscreenVideoExit?.call(items[index]);
  }

  _PlaybackSnapshot _playbackSnapshot() {
    final ui = _ui.value;
    return _PlaybackSnapshot(
      shouldPlay: ui.isPlaying || (_shouldAutoPlay && !_userPaused),
      position: ui.position,
    );
  }

  void _restorePlaybackAfterSurfaceMove(
    _PlaybackSnapshot snapshot,
    int serial,
  ) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || serial != _surfaceMoveSerial) return;
      unawaited(_syncPlaybackToSnapshot(snapshot, serial));
    });
  }

  Future<void> _syncPlaybackToSnapshot(
    _PlaybackSnapshot snapshot,
    int serial,
  ) async {
    if (!_playerReady || !mounted || serial != _surfaceMoveSerial) return;

    if (snapshot.shouldPlay) {
      _userPaused = false;
      await _startPlayback(startAt: snapshot.position, allowSurfaceMove: true);
      return;
    }

    _playSerial++;
    final seconds = _youtubeSeconds(snapshot.position);
    if (_hasLoadedVideo && seconds != null) {
      await _guardYoutubeCommand(
        () => _controller.seekTo(seconds: seconds, allowSeekAhead: true),
      );
      if (!mounted || serial != _surfaceMoveSerial) return;
    }
    await _guardYoutubeCommand(_controller.pauseVideo);
  }

  double? _youtubeSeconds(Duration? position) {
    if (position == null || position <= Duration.zero) return null;
    final seconds = position.inMilliseconds / 1000.0;
    return seconds.isFinite && seconds > 0 ? seconds : null;
  }

  double? _youtubeSeekSeconds(Duration position) {
    final seconds = position.inMilliseconds / 1000.0;
    return seconds.isFinite && seconds >= 0 ? seconds : null;
  }

  void _handleFullscreenPageChanged(int index) {
    final initialIndex = _initialFullscreenFeedIndex(
      widget.fullscreenFeed,
      widget.url,
    );
    if (index == initialIndex) {
      if (!_userPaused) {
        unawaited(_startPlayback(allowSurfaceMove: true));
      }
      return;
    }
    _playSerial++;
    if (_playerReady) {
      unawaited(_guardYoutubeCommand(_controller.pauseVideo));
    }
  }

  Widget _buildCurrentFullscreenPage({
    bool showTopBar = true,
    VoidCallback? onExit,
  }) {
    final ratio = widget.isShorts ? 9 / 16 : 16 / 9;
    final item = _fullscreenItemForUrl(widget.fullscreenFeed, widget.url);
    return _FullscreenScaffold(
      aspectRatio: ratio,
      item: item,
      onExit: onExit ?? _toggleFullscreen,
      showTopBar: showTopBar,
      authState: widget.authState,
      postActionRepository: widget.postActionRepository,
      onAuthRequired: widget.onAuthRequired,
      child: ClipRect(
        child: ColoredBox(
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_webViewReady)
                WebViewWidget(controller: _controller.webViewController),
              ValueListenableBuilder<_VideoUi>(
                valueListenable: _ui,
                builder: (context, ui, _) {
                  final showPoster =
                      !ui.isPlaying ||
                      ui.isBuffering ||
                      !_hasRenderedVideoFrame;
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      if (showPoster)
                        _PosterOrPlaceholder(poster: widget.poster),
                      _VideoControls(
                        isPlaying: ui.isPlaying,
                        isMuted: ui.muted,
                        isBuffering: ui.isBuffering,
                        position: ui.position,
                        duration: ui.duration,
                        topOverlay: null,
                        showCenterWhilePlaying: false,
                        fullscreen: true,
                        playbackSpeed: _playbackSpeed,
                        showFullscreenButton: false,
                        onTogglePlay: _togglePlay,
                        onToggleMute: _toggleMute,
                        onToggleSpeed: _togglePlaybackSpeed,
                        onToggleFullscreen: _toggleFullscreen,
                        onSeek: _seek,
                        onSeekRelative: _seekRelative,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFullscreenOverlay(BuildContext context) {
    final items = widget.fullscreenFeed;
    if (items.length <= 1) {
      return Material(
        color: Colors.black,
        child: SafeArea(
          child: _buildCurrentFullscreenPage(
            onExit: () => _closeFullscreenOverlay(selectedIndex: 0),
          ),
        ),
      );
    }

    final initialIndex = _initialFullscreenFeedIndex(items, widget.url);
    return _FullscreenVideoPager(
      items: items,
      initialIndex: initialIndex,
      currentUrl: widget.url,
      onExit: (index) => _closeFullscreenOverlay(selectedIndex: index),
      onPageChanged: _handleFullscreenPageChanged,
      currentPageBuilder: _buildCurrentFullscreenPage,
      authState: widget.authState,
      postActionRepository: widget.postActionRepository,
      onAuthRequired: widget.onAuthRequired,
    );
  }

  void _seek(double fraction) {
    final target = _clampSeekPosition(
      Duration(
        milliseconds: (_ui.value.duration.inMilliseconds * fraction).round(),
      ),
      _ui.value.duration,
    );
    final seconds = _youtubeSeekSeconds(target);
    if (seconds != null) {
      unawaited(
        _guardYoutubeCommand(
          () => _controller.seekTo(seconds: seconds, allowSeekAhead: true),
        ),
      );
    }
  }

  void _seekRelative(Duration offset) {
    if (!_playerReady) return;
    final ui = _ui.value;
    final target = _clampSeekPosition(ui.position + offset, ui.duration);
    final seconds = _youtubeSeekSeconds(target);
    if (seconds == null) return;

    _ui.value = ui.copyWith(position: target);
    if (!_hasLoadedVideo) {
      if (_shouldAutoPlay && !_userPaused) {
        unawaited(_startPlayback(startAt: target));
      }
      return;
    }
    unawaited(
      _guardYoutubeCommand(
        () => _controller.seekTo(seconds: seconds, allowSeekAhead: true),
      ),
    );
  }

  @override
  void dispose() {
    _playSerial++;
    _playerReady = false;
    _webViewReady = false;
    _fullscreenOverlay?.remove();
    _fullscreenOverlay = null;
    _stateSub?.cancel();
    _valueSub?.cancel();
    _ui.dispose();
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ratio = widget.isShorts ? 9 / 16 : 16 / 9;
    final attachInlineWebView = !_fullscreenActive && _webViewReady;
    return VisibilityDetector(
      key: _videoVisibilityKey(
        source: 'yt',
        identity: widget.videoId,
        scope: widget.visibilityScope,
      ),
      onVisibilityChanged: _onVisibilityChanged,
      child: AspectRatio(
        aspectRatio: ratio,
        child: ClipRect(
          child: ColoredBox(
            color: Colors.black,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_fullscreenActive)
                  _PosterOrPlaceholder(poster: widget.poster),
                if (attachInlineWebView)
                  WebViewWidget(controller: _controller.webViewController),
                if (!_fullscreenActive)
                  ValueListenableBuilder<_VideoUi>(
                    valueListenable: _ui,
                    builder: (context, ui, _) {
                      final showPoster =
                          !ui.isPlaying ||
                          ui.isBuffering ||
                          !_hasRenderedVideoFrame;
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          if (showPoster)
                            _PosterOrPlaceholder(poster: widget.poster),
                          _VideoControls(
                            isPlaying: ui.isPlaying,
                            isMuted: ui.muted,
                            isBuffering: ui.isBuffering,
                            position: ui.position,
                            duration: ui.duration,
                            topOverlay: widget.topOverlay,
                            showCenterWhilePlaying: false,
                            fullscreen: false,
                            playbackSpeed: _playbackSpeed,
                            showFullscreenButton: widget.showFullscreenButton,
                            onTogglePlay: _togglePlay,
                            onToggleMute: _toggleMute,
                            onToggleSpeed: _togglePlaybackSpeed,
                            onToggleFullscreen: _toggleFullscreen,
                            onSeek: _seek,
                            onSeekRelative: _seekRelative,
                          ),
                        ],
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// YouTube WebView kart içinde kalır; oynatıcı durumunu Flutter kontrollerine
/// reaktif taşıyan küçük değişmez taşıyıcı.
class _VideoUi {
  const _VideoUi({
    this.isPlaying = false,
    this.muted = true,
    this.isBuffering = true,
    this.position = Duration.zero,
    this.duration = Duration.zero,
  });

  final bool isPlaying;
  final bool muted;
  final bool isBuffering;
  final Duration position;
  final Duration duration;

  _VideoUi copyWith({
    bool? isPlaying,
    bool? muted,
    bool? isBuffering,
    Duration? position,
    Duration? duration,
  }) {
    return _VideoUi(
      isPlaying: isPlaying ?? this.isPlaying,
      muted: muted ?? this.muted,
      isBuffering: isBuffering ?? this.isBuffering,
      position: position ?? this.position,
      duration: duration ?? this.duration,
    );
  }
}

class _FullscreenVideoPager extends StatefulWidget {
  const _FullscreenVideoPager({
    required this.items,
    required this.initialIndex,
    required this.currentUrl,
    required this.onExit,
    required this.onPageChanged,
    required this.currentPageBuilder,
    required this.authState,
    required this.postActionRepository,
    required this.onAuthRequired,
  });

  final List<NewsVideoFeedItem> items;
  final int initialIndex;
  final String currentUrl;
  final ValueChanged<int> onExit;
  final ValueChanged<int> onPageChanged;
  final Widget Function({bool showTopBar}) currentPageBuilder;
  final FrontendAuthState? authState;
  final PostActionRepository postActionRepository;
  final VoidCallback? onAuthRequired;

  @override
  State<_FullscreenVideoPager> createState() => _FullscreenVideoPagerState();
}

class _FullscreenVideoPagerState extends State<_FullscreenVideoPager> {
  late final PageController _pageController;
  Timer? _hintTimer;
  Timer? _hintRepeat;
  late int _activeIndex;
  late final Widget _topBar;
  bool _showHint = false;

  bool get _multi => widget.items.length > 1;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
    _activeIndex = widget.initialIndex;
    _topBar = _FullscreenTopBar(logoUrl: _initialLogoUrl(), onExit: _exit);
    // Kaydırma kılavuzu açılışta uzunca görünür; sonra videolarda gezerken ara
    // arada kısa süre yeniden belirir (kırsal kullanıcı jesti unutmasın diye).
    if (_multi) {
      _showHint = true;
      _hintTimer = Timer(_kCoachOpenDuration, _hideHint);
      _hintRepeat = Timer.periodic(_kCoachRepeatInterval, (_) => _pulseHint());
    }
  }

  void _hideHint() {
    if (mounted && _showHint) setState(() => _showHint = false);
  }

  void _pulseHint() {
    if (!mounted || !_multi) return;
    setState(() => _showHint = true);
    _hintTimer?.cancel();
    _hintTimer = Timer(_kCoachPulseDuration, _hideHint);
  }

  void _exit() => widget.onExit(_activeIndex);

  String _initialLogoUrl() {
    if (widget.items.isEmpty) return '';
    final currentUrl = widget.currentUrl.trim();
    if (currentUrl.isNotEmpty) {
      for (final item in widget.items) {
        if (item.url.trim() == currentUrl) return item.fullscreenLogoUrl.trim();
      }
    }
    final index = widget.initialIndex.clamp(0, widget.items.length - 1).toInt();
    final initialLogo = widget.items[index].fullscreenLogoUrl.trim();
    if (initialLogo.isNotEmpty) return initialLogo;
    for (final item in widget.items) {
      final logo = item.fullscreenLogoUrl.trim();
      if (logo.isNotEmpty) return logo;
    }
    return '';
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _hintRepeat?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUrl = widget.currentUrl.trim();
    return Material(
      color: Colors.black,
      child: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              top: _kFullscreenTopBarHeight,
              child: PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                physics: const PageScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                itemCount: widget.items.length,
                onPageChanged: (index) {
                  setState(() => _activeIndex = index);
                  widget.onPageChanged(index);
                  _pulseHint(); // yeni videoya geçince kılavuzu kısa süre göster
                },
                itemBuilder: (context, index) {
                  final item = widget.items[index];
                  if (item.url.trim() == currentUrl) {
                    return widget.currentPageBuilder(showTopBar: false);
                  }
                  return _FullscreenFeedVideoPage(
                    key: ValueKey('fullscreen-feed-${item.url}'),
                    item: item,
                    onExit: () => widget.onExit(index),
                    active: index == _activeIndex,
                    authState: widget.authState,
                    postActionRepository: widget.postActionRepository,
                    onAuthRequired: widget.onAuthRequired,
                  );
                },
              ),
            ),
            Positioned(left: 0, right: 0, top: 0, child: _topBar),
            // Kaydırma kılavuzu ÜSTTE (kullanıcı isteği): üst bardan biraz aşağıda,
            // ortalanmış, yumuşak iniş animasyonuyla.
            Positioned(
              left: 0,
              right: 0,
              top: _kFullscreenTopBarHeight,
              child: IgnorePointer(
                child: _CoachReveal(
                  visible: _showHint,
                  child: const Center(child: _FullscreenSwipeHint()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FullscreenFeedVideoPage extends StatefulWidget {
  const _FullscreenFeedVideoPage({
    super.key,
    required this.item,
    required this.onExit,
    required this.active,
    required this.authState,
    required this.postActionRepository,
    required this.onAuthRequired,
  });

  final NewsVideoFeedItem item;
  final VoidCallback onExit;
  final bool active;
  final FrontendAuthState? authState;
  final PostActionRepository postActionRepository;
  final VoidCallback? onAuthRequired;

  @override
  State<_FullscreenFeedVideoPage> createState() =>
      _FullscreenFeedVideoPageState();
}

class _FullscreenFeedVideoPageState extends State<_FullscreenFeedVideoPage> {
  double? _resolvedAspectRatio;

  void _handleAspectRatioResolved(double ratio) {
    if (!ratio.isFinite || ratio <= 0) return;
    final current = _resolvedAspectRatio;
    if (current != null && (current - ratio).abs() < 0.001) return;
    setState(() => _resolvedAspectRatio = ratio);
  }

  double get _fallbackAspectRatio =>
      _isShortsUrl(widget.item.url) ? 9 / 16 : 16 / 9;

  @override
  Widget build(BuildContext context) {
    final ratio = _resolvedAspectRatio ?? _fallbackAspectRatio;
    return _FullscreenScaffold(
      aspectRatio: ratio,
      item: widget.item,
      onExit: widget.onExit,
      showTopBar: false,
      authState: widget.authState,
      postActionRepository: widget.postActionRepository,
      onAuthRequired: widget.onAuthRequired,
      child: widget.active
          ? NewsVideoPlayer(
              url: widget.item.url,
              poster: widget.item.poster,
              fullscreenLogoUrl: widget.item.fullscreenLogoUrl,
              visibilityScope: 'fullscreen-feed',
              autoPlayWhenReady: true,
              showFullscreenButton: false,
              authState: widget.authState,
              postActionRepository: widget.postActionRepository,
              onAuthRequired: widget.onAuthRequired,
              onAspectRatioResolved: _handleAspectRatioResolved,
            )
          : _FullscreenFeedPoster(item: widget.item, aspectRatio: ratio),
    );
  }
}

class _FullscreenFeedPoster extends StatelessWidget {
  const _FullscreenFeedPoster({required this.item, required this.aspectRatio});

  final NewsVideoFeedItem item;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _PosterOrPlaceholder(poster: item.poster),
          const ColoredBox(color: Color(0x52000000)),
          const Center(child: _CenterButton(playing: false, buffering: false)),
        ],
      ),
    );
  }
}

/// Tam ekran feed'de "yukarı kaydır → sonraki video" kılavuzu.
///
/// Kırsal kullanıcı soyut oku anlamadığı için açık Türkçe metinle birlikte,
/// yukarı akan çift chevron animasyonuyla net bir afford­ance sunar.
class _FullscreenSwipeHint extends StatelessWidget {
  const _FullscreenSwipeHint();

  @override
  Widget build(BuildContext context) {
    return const _GlassPanel(
      radius: 999,
      padding: EdgeInsets.fromLTRB(11, 8, 18, 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SwipeChevrons(),
          SizedBox(width: 12),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Yukarı kaydır',
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
                'sonraki videoya geç',
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

/// Yukarı doğru akıp sönen çift chevron — "kaydır" jestini canlandırır.
class _SwipeChevrons extends StatefulWidget {
  const _SwipeChevrons();

  @override
  State<_SwipeChevrons> createState() => _SwipeChevronsState();
}

class _SwipeChevronsState extends State<_SwipeChevrons>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1150),
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
      width: 28,
      height: 30,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = (math.sin(_c.value * 2 * math.pi) + 1) / 2; // 0..1..0
          final dy = -3.0 * t;
          return Stack(
            alignment: Alignment.center,
            children: [
              // Marka kırmızısı nefes alan enerji parıltısı.
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _kCoachAccent.withValues(alpha: 0.10 + 0.28 * t),
                      _kCoachAccent.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
              Transform.translate(
                offset: Offset(0, dy - 5),
                child: Opacity(
                  opacity: 0.5 + 0.5 * t,
                  child: const Icon(
                    Symbols.arrow_up_s_fill,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              Transform.translate(
                offset: Offset(0, dy + 5),
                child: Opacity(
                  opacity: 0.85 - 0.35 * t,
                  child: const Icon(
                    Symbols.arrow_up_s_fill,
                    color: Colors.white,
                    size: 20,
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

class _FullscreenScaffold extends StatelessWidget {
  const _FullscreenScaffold({
    required this.aspectRatio,
    required this.item,
    required this.onExit,
    required this.child,
    required this.authState,
    required this.postActionRepository,
    required this.onAuthRequired,
    this.showTopBar = true,
  });

  final double aspectRatio;
  final NewsVideoFeedItem item;
  final VoidCallback onExit;
  final Widget child;
  final FrontendAuthState? authState;
  final PostActionRepository postActionRepository;
  final VoidCallback? onAuthRequired;
  final bool showTopBar;

  @override
  Widget build(BuildContext context) {
    final compact = aspectRatio > 0 && aspectRatio < 1;
    final infoHeight = item.hasArticleInfo ? (compact ? 168.0 : 178.0) : 0.0;
    return Column(
      children: [
        if (showTopBar)
          _FullscreenTopBar(logoUrl: item.fullscreenLogoUrl, onExit: onExit),
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                bottom: infoHeight,
                child: Center(
                  child: AspectRatio(aspectRatio: aspectRatio, child: child),
                ),
              ),
              if (item.hasArticleInfo)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _FullscreenArticleInfo(
                    item: item,
                    authState: authState,
                    postActionRepository: postActionRepository,
                    onAuthRequired: onAuthRequired,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FullscreenTopBar extends StatelessWidget {
  const _FullscreenTopBar({required this.logoUrl, required this.onExit});

  final String logoUrl;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: Colors.black),
      child: SizedBox(
        height: _kFullscreenTopBarHeight,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: 18,
              top: 7,
              bottom: 7,
              child: _FullscreenTopIconButton(
                icon: Symbols.search_rounded,
                semantics: 'Ara',
                onTap: () {},
              ),
            ),
            _FullscreenBrandMark(logoUrl: logoUrl),
            Positioned(
              right: 18,
              top: 7,
              bottom: 7,
              child: _FullscreenExitButton(onTap: onExit),
            ),
          ],
        ),
      ),
    );
  }
}

class _FullscreenBrandMark extends StatelessWidget {
  const _FullscreenBrandMark({required this.logoUrl});

  final String logoUrl;

  @override
  Widget build(BuildContext context) {
    final cleanUrl = logoUrl.trim();
    final fallback = Image.asset(
      DefaultBrandAssets.logo,
      height: 34,
      fit: BoxFit.contain,
      color: Colors.white,
      colorBlendMode: BlendMode.srcIn,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
    if (cleanUrl.isEmpty) return fallback;
    return Image.network(
      cleanUrl,
      height: 34,
      fit: BoxFit.contain,
      color: Colors.white,
      colorBlendMode: BlendMode.srcIn,
      filterQuality: FilterQuality.high,
      gaplessPlayback: true,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : fallback,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}

class _FullscreenTopIconButton extends StatelessWidget {
  const _FullscreenTopIconButton({
    required this.icon,
    required this.semantics,
    required this.onTap,
  });

  final IconData icon;
  final String semantics;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semantics,
      button: true,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox.square(
            dimension: 34,
            child: Center(
              child: Icon(
                icon,
                size: 19,
                color: Colors.white.withValues(alpha: 0.88),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FullscreenArticleInfo extends StatelessWidget {
  const _FullscreenArticleInfo({
    required this.item,
    required this.authState,
    required this.postActionRepository,
    required this.onAuthRequired,
  });

  final NewsVideoFeedItem item;
  final FrontendAuthState? authState;
  final PostActionRepository postActionRepository;
  final VoidCallback? onAuthRequired;

  @override
  Widget build(BuildContext context) {
    final title = item.title.trim();
    return DecoratedBox(
      decoration: const BoxDecoration(color: Colors.black),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.author != null) _FullscreenAuthorLine(item: item),
            if (title.isNotEmpty) ...[
              if (item.author != null) const SizedBox(height: 8),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.mobileNewsCardTitle.copyWith(
                  color: Colors.white,
                  fontSize: 18,
                  height: 1.12,
                  letterSpacing: 0,
                ),
              ),
            ],
            const SizedBox(height: 12),
            _FullscreenActionRow(
              item: item,
              authState: authState,
              postActionRepository: postActionRepository,
              onAuthRequired: onAuthRequired,
            ),
          ],
        ),
      ),
    );
  }
}

class _FullscreenAuthorLine extends StatelessWidget {
  const _FullscreenAuthorLine({required this.item});

  final NewsVideoFeedItem item;

  @override
  Widget build(BuildContext context) {
    final author = item.author;
    if (author == null) return const SizedBox.shrink();
    final meta = _fullscreenMetaFor(item);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _FullscreenAvatar(author: author),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      author.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.meta.copyWith(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                  ),
                  if (author.isVerified || author.isOfficial) ...[
                    const SizedBox(width: 5),
                    VerifiedBadge(official: author.isOfficial, size: 14),
                  ],
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      _authorHandle(author),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.meta.copyWith(
                        color: Colors.white.withValues(alpha: 0.66),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        height: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
              if (meta.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.meta.copyWith(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    height: 1.12,
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

class _FullscreenAvatar extends StatelessWidget {
  const _FullscreenAvatar({required this.author});

  final NewsAuthor author;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: AppColors.surfaceInk,
      alignment: Alignment.center,
      child: Text(
        _avatarInitial(author.name),
        style: AppTypography.titleS.copyWith(
          color: AppColors.deepOcean,
          fontSize: 15,
        ),
      ),
    );
    return Container(
      width: 44,
      height: 44,
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
                  memCacheWidth: 96,
                  placeholderColor: AppColors.surfaceInk,
                  errorWidget: fallback,
                ),
        ),
      ),
    );
  }
}

class _FullscreenActionRow extends StatefulWidget {
  const _FullscreenActionRow({
    required this.item,
    required this.authState,
    required this.postActionRepository,
    required this.onAuthRequired,
  });

  final NewsVideoFeedItem item;
  final FrontendAuthState? authState;
  final PostActionRepository postActionRepository;
  final VoidCallback? onAuthRequired;

  @override
  State<_FullscreenActionRow> createState() => _FullscreenActionRowState();
}

class _FullscreenActionRowState extends State<_FullscreenActionRow> {
  late int _likes = widget.item.likes;
  late int _dislikes = widget.item.dislikes;
  late int _shares = widget.item.shares;
  late int _saves = widget.item.saves;
  late bool _liked = widget.item.userLiked;
  late bool _disliked = widget.item.userDisliked;
  late bool _saved = widget.item.userSaved;
  bool _busy = false;

  String get _authToken => widget.authState?.session.accessToken.trim() ?? '';

  bool get _hasNumericPostId => int.tryParse(widget.item.postId) != null;

  @override
  void didUpdateWidget(covariant _FullscreenActionRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.postId != widget.item.postId ||
        oldWidget.item.likes != widget.item.likes ||
        oldWidget.item.dislikes != widget.item.dislikes ||
        oldWidget.item.shares != widget.item.shares ||
        oldWidget.item.saves != widget.item.saves ||
        oldWidget.item.userLiked != widget.item.userLiked ||
        oldWidget.item.userDisliked != widget.item.userDisliked ||
        oldWidget.item.userSaved != widget.item.userSaved) {
      _syncFromItem();
    }
  }

  void _syncFromItem() {
    _likes = widget.item.likes;
    _dislikes = widget.item.dislikes;
    _shares = widget.item.shares;
    _saves = widget.item.saves;
    _liked = widget.item.userLiked;
    _disliked = widget.item.userDisliked;
    _saved = widget.item.userSaved;
  }

  bool _requireSignedIn(String message) {
    if (_authToken.isNotEmpty) return true;
    FrontendToast.show(
      context,
      message: message,
      tone: FrontendToastTone.error,
    );
    widget.onAuthRequired?.call();
    return false;
  }

  _FullscreenPostActionSnapshot _snapshot() => _FullscreenPostActionSnapshot(
    likes: _likes,
    dislikes: _dislikes,
    shares: _shares,
    saves: _saves,
    liked: _liked,
    disliked: _disliked,
    saved: _saved,
  );

  void _restore(_FullscreenPostActionSnapshot snapshot) {
    setState(() {
      _likes = snapshot.likes;
      _dislikes = snapshot.dislikes;
      _shares = snapshot.shares;
      _saves = snapshot.saves;
      _liked = snapshot.liked;
      _disliked = snapshot.disliked;
      _saved = snapshot.saved;
    });
  }

  void _apply(PostActionState state) {
    setState(() {
      _likes = state.likes;
      _dislikes = state.dislikes;
      _shares = state.shares;
      _saves = state.saves;
      _liked = state.liked;
      _disliked = state.disliked;
      _saved = state.saved;
    });
  }

  Future<void> _toggleLike() async {
    if (!_hasNumericPostId || _busy) return;
    if (!_requireSignedIn('Beğenmek için kayıt olmanız gerekiyor.')) return;
    final previous = _snapshot();
    setState(() {
      _busy = true;
      if (_liked) {
        _liked = false;
        _likes = math.max(0, _likes - 1);
      } else {
        if (_disliked) {
          _disliked = false;
          _dislikes = math.max(0, _dislikes - 1);
        }
        _liked = true;
        _likes++;
      }
    });
    try {
      final state = await widget.postActionRepository.toggleLike(
        postId: widget.item.postId,
        token: _authToken,
      );
      if (mounted) _apply(state);
    } catch (_) {
      if (mounted) _restore(previous);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleDislike() async {
    if (!_hasNumericPostId || _busy) return;
    if (!_requireSignedIn('Beğenmemek için kayıt olmanız gerekiyor.')) return;
    final previous = _snapshot();
    setState(() {
      _busy = true;
      if (_disliked) {
        _disliked = false;
        _dislikes = math.max(0, _dislikes - 1);
      } else {
        if (_liked) {
          _liked = false;
          _likes = math.max(0, _likes - 1);
        }
        _disliked = true;
        _dislikes++;
      }
    });
    try {
      final state = await widget.postActionRepository.toggleDislike(
        postId: widget.item.postId,
        token: _authToken,
      );
      if (mounted) _apply(state);
    } catch (_) {
      if (mounted) _restore(previous);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleSave() async {
    if (!_hasNumericPostId || _busy) return;
    if (!_requireSignedIn('Kaydetmek için kayıt olmanız gerekiyor.')) return;
    final previous = _snapshot();
    setState(() {
      _busy = true;
      _saved = !_saved;
      _saves = math.max(0, _saves + (_saved ? 1 : -1));
    });
    try {
      final state = await widget.postActionRepository.toggleSave(
        postId: widget.item.postId,
        token: _authToken,
      );
      if (mounted) _apply(state);
    } catch (_) {
      if (mounted) _restore(previous);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    final previousShares = _shares;
    setState(() => _shares++);
    try {
      if (_hasNumericPostId) {
        final token = _authToken;
        final state = await widget.postActionRepository.share(
          postId: widget.item.postId,
          token: token.isEmpty ? null : token,
          platform: 'mobile_video_share',
        );
        if (mounted) _apply(state);
      }
    } catch (_) {
      if (mounted) setState(() => _shares = previousShares);
    }
    if (!mounted) return;
    _shareFullscreenItem(context, widget.item);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _FullscreenActionPill(
          icon: Symbols.thumb_up_line,
          activeIcon: Symbols.thumb_up_fill,
          active: _liked,
          activeColor: AppColors.warmHorizon,
          count: _likes,
          semantics: 'Beğen',
          onTap: (_) => unawaited(_toggleLike()),
        ),
        const SizedBox(width: 10),
        _FullscreenActionPill(
          icon: Symbols.thumb_down_line,
          activeIcon: Symbols.thumb_down_fill,
          active: _disliked,
          activeColor: AppColors.actionRed,
          count: _dislikes,
          semantics: 'Beğenme',
          onTap: (_) => unawaited(_toggleDislike()),
        ),
        const SizedBox(width: 10),
        _FullscreenActionPill(
          icon: Symbols.chat_3_line,
          count: widget.item.comments,
          semantics: 'Yorumlar',
        ),
        const Spacer(),
        _FullscreenActionPill(
          icon: Symbols.bookmark_line,
          activeIcon: Symbols.bookmark_fill,
          active: _saved,
          activeColor: AppColors.warmHorizon,
          count: 0,
          semantics: 'Kaydet',
          showZero: false,
          badgeCount: _saves,
          onTap: (_) => unawaited(_toggleSave()),
        ),
        const SizedBox(width: 8),
        _FullscreenActionPill(
          icon: Symbols.share_forward_line,
          count: _shares,
          semantics: 'Paylaş',
          showZero: false,
          onTap: (_) => unawaited(_share()),
        ),
      ],
    );
  }
}

class _FullscreenPostActionSnapshot {
  const _FullscreenPostActionSnapshot({
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

class _FullscreenActionPill extends StatelessWidget {
  const _FullscreenActionPill({
    required this.icon,
    required this.count,
    required this.semantics,
    this.activeIcon,
    this.active = false,
    this.activeColor = AppColors.warmHorizon,
    this.badgeCount,
    this.showZero = true,
    this.onTap,
  });

  final IconData icon;
  final int count;
  final String semantics;
  final IconData? activeIcon;
  final bool active;
  final Color activeColor;
  final int? badgeCount;
  final bool showZero;
  final void Function(BuildContext context)? onTap;

  @override
  Widget build(BuildContext context) {
    final label = CountFormat.compact(count);
    final showLabel = showZero || count > 0;
    final iconColor = active
        ? activeColor
        : Colors.white.withValues(alpha: 0.88);
    final resolvedIcon = active ? activeIcon ?? icon : icon;
    final resolvedBadgeCount = badgeCount ?? 0;
    return Semantics(
      label: semantics,
      button: true,
      selected: active,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onTap?.call(context),
          child: SizedBox(
            height: 32,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.only(
                    left: showLabel ? 2 : 7,
                    right: showLabel ? 0 : 7,
                  ),
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey<String>('$semantics-$active-$count'),
                    tween: Tween<double>(begin: 0.82, end: 1),
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutBack,
                    builder: (context, scale, child) {
                      return Transform.scale(scale: scale, child: child);
                    },
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(resolvedIcon, size: 19, color: iconColor),
                        if (resolvedBadgeCount > 0)
                          Positioned(
                            right: -8,
                            top: -8,
                            child: _FullscreenActionBadge(
                              count: resolvedBadgeCount,
                              color: activeColor,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (showLabel) ...[
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: AppTypography.meta.copyWith(
                      color: Colors.white.withValues(alpha: 0.70),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 2),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FullscreenActionBadge extends StatelessWidget {
  const _FullscreenActionBadge({required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black, width: 1.3),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.36),
            blurRadius: 9,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        child: Text(
          CountFormat.compact(count),
          style: AppTypography.meta.copyWith(
            color: Colors.white,
            fontSize: 9.5,
            fontWeight: FontWeight.w900,
            height: 1,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

void _shareFullscreenItem(BuildContext context, NewsVideoFeedItem item) {
  unawaited(_shareFullscreenItemAsync(context, item));
}

Future<void> _shareFullscreenItemAsync(
  BuildContext context,
  NewsVideoFeedItem item,
) async {
  final url = _fullscreenShareUrl(item);
  if (url.isEmpty) return;

  final title = item.title.trim();
  final category = _categoryLabelForVideoItem(item);
  final text = [
    if (title.isNotEmpty) title,
    if (category.isNotEmpty) category,
    url,
  ].join('\n');

  final box = context.findRenderObject() as RenderBox?;
  final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;

  await SharePlus.instance.share(
    ShareParams(
      text: text,
      title: title.isEmpty ? 'Pateez' : title,
      subject: title.isEmpty ? 'Pateez' : title,
      sharePositionOrigin: origin,
    ),
  );
}

String _fullscreenShareUrl(NewsVideoFeedItem item) {
  final slug = item.slug.trim();
  if (slug.isNotEmpty) {
    return frontendApiUri(
      '/haber/${Uri.encodeComponent(slug)}',
      configuredBaseUrl: _kFrontendApiBaseUrl,
    ).toString();
  }
  return _absoluteFrontendUrl(item.url);
}

String _absoluteFrontendUrl(String value) {
  final raw = value.trim();
  if (raw.isEmpty) return '';
  final uri = Uri.tryParse(raw);
  if (uri != null && uri.hasScheme) return raw;
  if (raw.startsWith('/')) {
    return frontendApiUri(
      raw,
      configuredBaseUrl: _kFrontendApiBaseUrl,
    ).toString();
  }
  if (raw.contains('.')) return 'https://$raw';
  return raw;
}

class _FullscreenExitButton extends StatelessWidget {
  const _FullscreenExitButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Tam ekrandan çık',
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: SizedBox.square(
            dimension: 36,
            child: Center(
              child: Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
                child: const Icon(
                  Symbols.arrow_left_line,
                  size: 18,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _fullscreenMetaFor(NewsVideoFeedItem item) {
  final parts = <String>[
    _categoryLabelForVideoItem(item),
    _formatPublishedDate(item.publishedAt),
    _formatPublishedClock(item.publishedAt),
  ].where((value) => value.trim().isNotEmpty).toList(growable: false);
  return parts.join(' • ');
}

String _categoryLabelForVideoItem(NewsVideoFeedItem item) {
  final source = item.categoryTrail.isNotEmpty
      ? item.categoryTrail
      : [item.region, item.category];
  return source
      .map(_titleCaseLabel)
      .where((value) => value.trim().isNotEmpty)
      .join(' / ');
}

String _formatPublishedDate(DateTime value) {
  if (value.millisecondsSinceEpoch == 0) return '';
  final date = value.toUtc().add(const Duration(hours: 3));
  final day = date.day;
  final month = _turkishMonths[date.month - 1];
  final year = date.year.toString().padLeft(4, '0');
  final weekday = _turkishWeekdays[date.weekday - 1];
  return '$day $month $year $weekday';
}

String _formatPublishedClock(DateTime value) {
  if (value.millisecondsSinceEpoch == 0) return '';
  final date = value.toUtc().add(const Duration(hours: 3));
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _authorHandle(NewsAuthor author) {
  final handle = author.handle?.trim() ?? '';
  if (handle.isNotEmpty) return handle.startsWith('@') ? handle : '@$handle';
  final first = author.name.trim().split(RegExp(r'\s+')).first;
  final slug = _lowerTr(first).replaceAll(RegExp(r'[^0-9a-zçğıiöşü]'), '');
  return slug.isEmpty ? '@pateez' : '@$slug';
}

String _avatarInitial(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return 'P';
  return _upperFirstTr(trimmed.characters.first);
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

bool _isWordSeparator(String value) {
  return value == ' ' ||
      value == '\t' ||
      value == '\n' ||
      value == '/' ||
      value == '-' ||
      value == '_' ||
      value == '.';
}

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

// ---------------------------------------------------------------------------
// Ortak kontrol katmanı (tüm videolar için aynı)
// ---------------------------------------------------------------------------

class _VideoControls extends StatefulWidget {
  const _VideoControls({
    required this.isPlaying,
    required this.isMuted,
    required this.isBuffering,
    required this.position,
    required this.duration,
    required this.topOverlay,
    required this.showCenterWhilePlaying,
    required this.fullscreen,
    required this.playbackSpeed,
    this.showFullscreenButton = true,
    required this.onTogglePlay,
    required this.onToggleMute,
    required this.onToggleSpeed,
    required this.onToggleFullscreen,
    required this.onSeek,
    required this.onSeekRelative,
  });

  final bool isPlaying;
  final bool isMuted;
  final bool isBuffering;
  final Duration position;
  final Duration duration;
  final Widget? topOverlay;
  final bool showCenterWhilePlaying;
  final bool fullscreen;
  final double playbackSpeed;
  final bool showFullscreenButton;
  final VoidCallback onTogglePlay;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleSpeed;
  final VoidCallback onToggleFullscreen;

  /// 0..1 oranıyla ileri/geri sarma (seek).
  final ValueChanged<double> onSeek;
  final ValueChanged<Duration> onSeekRelative;

  @override
  State<_VideoControls> createState() => _VideoControlsState();
}

class _VideoControlsState extends State<_VideoControls> {
  bool _show = true;
  double? _dragFraction; // tıkla/sürükle ile seek sırasında anlık oran
  Offset? _doubleTapPosition;
  int _seekFeedbackSeconds = 0;
  bool _seekHintDismissed = false; // duraklatılan videoda tek seferlik gizleme
  Timer? _hideTimer;
  Timer? _seekFeedbackTimer;

  bool get _shouldShowSeekHint =>
      widget.fullscreen &&
      !widget.isPlaying &&
      !widget.isBuffering &&
      widget.duration > Duration.zero &&
      !_seekHintDismissed;

  @override
  void initState() {
    super.initState();
    _scheduleHide();
  }

  @override
  void didUpdateWidget(covariant _VideoControls old) {
    super.didUpdateWidget(old);
    if (old.isPlaying != widget.isPlaying) {
      _show = true;
      _scheduleHide();
      if (!widget.isPlaying) _seekHintDismissed = false;
    }
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (widget.isPlaying) {
      _hideTimer = Timer(const Duration(milliseconds: 1800), () {
        if (mounted) setState(() => _show = false);
      });
    }
  }

  void _tap() {
    if (_shouldShowSeekHint) _seekHintDismissed = true;
    widget.onTogglePlay();
    setState(() => _show = true);
    _scheduleHide();
  }

  void _doubleTap(double width) {
    final position = _doubleTapPosition;
    if (position == null || width <= 0) return;

    if (_shouldShowSeekHint) _seekHintDismissed = true;
    final forward = position.dx >= width / 2;
    widget.onSeekRelative(
      forward ? _kDoubleTapSeekForward : _kDoubleTapSeekBackward,
    );
    _showSeekFeedback(forward);
    _doubleTapPosition = null;
  }

  void _showSeekFeedback(bool forward) {
    final direction = forward ? 1 : -1;
    final base = _seekFeedbackSeconds.sign == direction
        ? _seekFeedbackSeconds.abs()
        : 0;

    _seekFeedbackTimer?.cancel();
    setState(() => _seekFeedbackSeconds = direction * (base + 10));
    _seekFeedbackTimer = Timer(_kDoubleTapSeekFeedbackDuration, () {
      if (mounted) setState(() => _seekFeedbackSeconds = 0);
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _seekFeedbackTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final centerVisible =
        widget.isBuffering ||
        !widget.isPlaying ||
        (widget.showCenterWhilePlaying && _show);
    final total = widget.duration.inMilliseconds;
    final actualFraction = total > 0
        ? (widget.position.inMilliseconds / total).clamp(0.0, 1.0)
        : 0.0;
    // Sürüklerken parmağı takip eden anlık oran; bırakınca gerçek konuma döner.
    final shownFraction = _dragFraction ?? actualFraction;
    final remaining = widget.duration > Duration.zero
        ? widget.duration * (1 - shownFraction)
        : Duration.zero;

    return LayoutBuilder(
      builder: (context, constraints) {
        final videoWidth = constraints.maxWidth;
        return Stack(
          fit: StackFit.expand,
          children: [
            // 1) Tüm yüzey: tek dokunuş oynat/duraklat, çift dokunuş sağ/sol seek.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _tap,
                onDoubleTapDown: (details) =>
                    _doubleTapPosition = details.localPosition,
                onDoubleTap: () => _doubleTap(videoWidth),
                onDoubleTapCancel: () => _doubleTapPosition = null,
              ),
            ),

            if (widget.topOverlay != null) widget.topOverlay!,

            // 2) Ortadaki play/pause
            Center(
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: centerVisible ? 1 : 0,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  child: _CenterButton(
                    playing: widget.isPlaying,
                    buffering: widget.isBuffering,
                  ),
                ),
              ),
            ),

            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 130),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    final scale = Tween<double>(begin: 0.92, end: 1).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      ),
                    );
                    return FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(scale: scale, child: child),
                    );
                  },
                  child: _seekFeedbackSeconds == 0
                      ? const SizedBox.shrink(key: ValueKey('seek-empty'))
                      : _DoubleTapSeekFeedback(
                          key: ValueKey<int>(_seekFeedbackSeconds),
                          seconds: _seekFeedbackSeconds,
                        ),
                ),
              ),
            ),

            // 2.b) Çift-dokunma kılavuzu: yalnız tam ekranda video dururken görünür.
            Positioned.fill(
              child: IgnorePointer(
                child: _CoachReveal(
                  visible: _shouldShowSeekHint,
                  child: const _DoubleTapHint(),
                ),
              ),
            ),

            // 3) Ses aç/kapa. Üstte overlay olmayan (tam ekran / feed) videolarda
            // sağ üst köşeye yaslanır; ana kartta üst etiketle çakışmasın diye iner.
            Positioned(
              top: (widget.fullscreen || widget.topOverlay == null) ? 8 : 50,
              right: 8,
              child: _RoundGlassButton(
                size: 32,
                onTap: widget.onToggleMute,
                child: CustomPaint(
                  size: const Size(18, 18),
                  painter: _SpeakerPainter(
                    muted: widget.isMuted,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            // 4) Büyüt/kapat: ses butonunun altında aynı cam ritminde.
            if (widget.showFullscreenButton)
              Positioned(
                top: 88,
                right: 8,
                child: _RoundGlassButton(
                  size: 32,
                  onTap: widget.onToggleFullscreen,
                  child: CustomPaint(
                    size: const Size(18, 18),
                    painter: _FullscreenPainter(
                      active: widget.fullscreen,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

            // 5) Altta sayaç + KIRMIZI, tıkla/sürükle ile geri-ileri sarılabilen çubuk
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 54,
              child: IgnorePointer(child: _BottomControlsScrim()),
            ),
            Positioned(
              right: 8,
              bottom: 8,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PlaybackSpeedPill(
                    speed: widget.playbackSpeed,
                    onTap: widget.onToggleSpeed,
                  ),
                  const SizedBox(width: 6),
                  IgnorePointer(child: _CountdownPill(remaining: remaining)),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 18,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  void preview(double dx) {
                    if (width <= 0) return;
                    setState(
                      () => _dragFraction = (dx / width).clamp(0.0, 1.0),
                    );
                  }

                  void commit() {
                    final f = _dragFraction;
                    if (f != null) widget.onSeek(f);
                    setState(() => _dragFraction = null);
                  }

                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (d) => preview(d.localPosition.dx),
                    onTapUp: (_) => commit(),
                    onTapCancel: () => setState(() => _dragFraction = null),
                    onHorizontalDragStart: (d) => preview(d.localPosition.dx),
                    onHorizontalDragUpdate: (d) => preview(d.localPosition.dx),
                    onHorizontalDragEnd: (_) => commit(),
                    child: Container(
                      color: Colors.transparent,
                      alignment: Alignment.bottomCenter,
                      child: _ProgressBar(fraction: shownFraction),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Çift dokununca beliren ileri/geri sarma geri bildirimi.
class _DoubleTapSeekFeedback extends StatelessWidget {
  const _DoubleTapSeekFeedback({super.key, required this.seconds});

  final int seconds;

  @override
  Widget build(BuildContext context) {
    final forward = seconds > 0;
    final value = seconds.abs();
    return Align(
      alignment: forward ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _SeekFeedbackPill(forward: forward, value: value),
      ),
    );
  }
}

class _SeekFeedbackPill extends StatelessWidget {
  const _SeekFeedbackPill({required this.forward, required this.value});

  final bool forward;
  final int value;

  @override
  Widget build(BuildContext context) {
    final icon = Transform.scale(
      scaleX: forward ? -1 : 1,
      child: Icon(
        _kReplyAllLineIcon,
        color: Colors.white.withValues(alpha: 0.88),
        size: 20,
      ),
    );
    final label = Text(
      '$value sn',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.w800,
        height: 1,
        letterSpacing: 0,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF0B0F14).withValues(alpha: 0.34),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: forward
                ? [label, const SizedBox(width: 5), icon]
                : [icon, const SizedBox(width: 5), label],
          ),
        ),
      ),
    );
  }
}

/// Tam ekranda video dururken görünen küçük çift-dokunma kılavuzu.
class _DoubleTapHint extends StatelessWidget {
  const _DoubleTapHint();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      children: [
        Align(
          alignment: Alignment(-0.72, 0.46),
          child: _DoubleTapHintSide(forward: false),
        ),
        Align(
          alignment: Alignment(0.72, 0.46),
          child: _DoubleTapHintSide(forward: true),
        ),
      ],
    );
  }
}

class _DoubleTapHintSide extends StatelessWidget {
  const _DoubleTapHintSide({required this.forward});

  final bool forward;

  @override
  Widget build(BuildContext context) {
    final shadow = [
      Shadow(
        color: Colors.black.withValues(alpha: 0.72),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ];
    final icon = Transform.scale(
      scaleX: forward ? -1 : 1,
      child: Icon(
        _kReplyAllLineIcon,
        color: Colors.white.withValues(alpha: 0.76),
        size: 16,
        shadows: shadow,
      ),
    );
    final label = Text(
      forward ? '10 sn ileri' : '10 sn geri',
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.76),
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        height: 1.1,
        letterSpacing: 0,
        shadows: shadow,
      ),
    );
    return Opacity(
      opacity: 0.88,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: forward
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Text(
            'Çift dokun',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.84),
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              height: 1.04,
              letterSpacing: 0,
              shadows: shadow,
            ),
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: forward
                ? [label, const SizedBox(width: 4), icon]
                : [icon, const SizedBox(width: 4), label],
          ),
        ],
      ),
    );
  }
}

/// Marka camı: "Derin Okyanus" tonundan koyuya inen degrade, ince beyaz kenar,
/// yumuşak gölge. Tüm jest kılavuzları aynı görsel dili konuşur.
class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.child,
    this.radius = 22,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xD92C3E50), Color(0xF20B0F14)],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Kılavuzların yumuşak giriş/çıkışı: opaklık + hafif "pop" ölçek.
class _CoachReveal extends StatelessWidget {
  const _CoachReveal({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: Duration(milliseconds: visible ? 300 : 220),
      curve: Curves.easeOut,
      child: AnimatedScale(
        scale: visible ? 1 : 0.9,
        duration: Duration(milliseconds: visible ? 380 : 220),
        curve: visible ? Curves.easeOutBack : Curves.easeIn,
        child: child,
      ),
    );
  }
}

class _BottomControlsScrim extends StatelessWidget {
  const _BottomControlsScrim();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0x78000000), Color(0x30000000), Color(0x00000000)],
          stops: [0, 0.46, 1],
        ),
      ),
    );
  }
}

class _CenterButton extends StatelessWidget {
  const _CenterButton({required this.playing, required this.buffering});

  final bool playing;
  final bool buffering;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 66,
      height: 66,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.36),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: buffering
          ? const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : CustomPaint(
              size: const Size(28, 28),
              painter: _PlayPausePainter(playing: playing, color: Colors.white),
            ),
    );
  }
}

class _RoundGlassButton extends StatelessWidget {
  const _RoundGlassButton({
    required this.size,
    required this.onTap,
    required this.child,
  });

  final double size;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.36),
      shape: CircleBorder(
        side: BorderSide(color: Colors.white.withValues(alpha: 0.20)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _PlaybackSpeedPill extends StatelessWidget {
  const _PlaybackSpeedPill({required this.speed, required this.onTap});

  final double speed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Oynatma hızı',
      button: true,
      child: Material(
        color: Colors.black.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(4),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 23,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _formatPlaybackSpeed(speed),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
                height: 1,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CountdownPill extends StatelessWidget {
  const _CountdownPill({required this.remaining});

  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Text(
        _formatClock(remaining),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
          height: 1,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    // Garantili KIRMIZI ilerleme: koyu zemin üstünde projenin kırmızısıyla dolar.
    return LinearProgressIndicator(
      value: fraction.clamp(0.0, 1.0),
      minHeight: 4,
      backgroundColor: Colors.black.withValues(alpha: 0.38),
      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.actionRed),
    );
  }
}

class _PosterOrPlaceholder extends StatelessWidget {
  const _PosterOrPlaceholder({required this.poster});

  final String poster;

  @override
  Widget build(BuildContext context) {
    if (poster.trim().isEmpty) {
      return const ColoredBox(color: Colors.black);
    }
    return CachedImage(
      url: poster,
      fit: BoxFit.cover,
      placeholderColor: Colors.black,
      errorWidget: const ColoredBox(color: Colors.black),
    );
  }
}

String _formatClock(Duration value) {
  final d = value.isNegative ? Duration.zero : value;
  String two(int n) => n.toString().padLeft(2, '0');
  final hours = d.inHours;
  final minutes = d.inMinutes.remainder(60);
  final seconds = d.inSeconds.remainder(60);
  if (hours > 0) return '$hours:${two(minutes)}:${two(seconds)}';
  return '${two(minutes)}:${two(seconds)}';
}

// ---------------------------------------------------------------------------
// Özel çizimli simgeler (ikon paketinde pause/ses yok — markaya uygun çizildi)
// ---------------------------------------------------------------------------

class _PlayPausePainter extends CustomPainter {
  _PlayPausePainter({required this.playing, required this.color});

  final bool playing;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final fill = Paint()
      ..color = color
      ..isAntiAlias = true
      ..style = PaintingStyle.fill;

    if (playing) {
      final barW = w * 0.26;
      final gap = w * 0.16;
      final radius = Radius.circular(barW * 0.5);
      final totalW = barW * 2 + gap;
      final startX = (w - totalW) / 2;
      final top = h * 0.10;
      final bottom = h * 0.90;
      final left = Rect.fromLTRB(startX, top, startX + barW, bottom);
      final right = Rect.fromLTRB(
        startX + barW + gap,
        top,
        startX + totalW,
        bottom,
      );
      canvas.drawRRect(RRect.fromRectAndRadius(left, radius), fill);
      canvas.drawRRect(RRect.fromRectAndRadius(right, radius), fill);
    } else {
      final path = Path()
        ..moveTo(w * 0.26, h * 0.16)
        ..lineTo(w * 0.26, h * 0.84)
        ..lineTo(w * 0.84, h * 0.50)
        ..close();
      // Köşeleri yuvarlatmak için aynı renkte yuvarlak birleşimli stroke.
      final stroke = Paint()
        ..color = color
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.10
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(path, fill);
      canvas.drawPath(path, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _PlayPausePainter old) =>
      old.playing != playing || old.color != color;
}

class _SpeakerPainter extends CustomPainter {
  _SpeakerPainter({required this.muted, required this.color});

  final bool muted;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final body = Paint()
      ..color = color
      ..isAntiAlias = true
      ..style = PaintingStyle.fill;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.06, h * 0.38, w * 0.16, h * 0.24),
          Radius.circular(w * 0.03),
        ),
      )
      ..moveTo(w * 0.22, h * 0.38)
      ..lineTo(w * 0.48, h * 0.16)
      ..lineTo(w * 0.48, h * 0.84)
      ..lineTo(w * 0.22, h * 0.62)
      ..close();
    canvas.drawPath(path, body);

    final line = Paint()
      ..color = color
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.07
      ..strokeCap = StrokeCap.round;

    if (muted) {
      canvas.drawLine(
        Offset(w * 0.58, h * 0.30),
        Offset(w * 0.90, h * 0.70),
        line,
      );
    } else {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(w * 0.46, h * 0.50), radius: w * 0.22),
        -0.7,
        1.4,
        false,
        line,
      );
      canvas.drawArc(
        Rect.fromCircle(center: Offset(w * 0.46, h * 0.50), radius: w * 0.34),
        -0.7,
        1.4,
        false,
        line,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpeakerPainter old) =>
      old.muted != muted || old.color != color;
}

class _FullscreenPainter extends CustomPainter {
  _FullscreenPainter({required this.active, required this.color});

  final bool active;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final p = Paint()
      ..color = color
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.10
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    Path corner(
      double x1,
      double y1,
      double x2,
      double y2,
      double x3,
      double y3,
    ) {
      return Path()
        ..moveTo(x1, y1)
        ..lineTo(x2, y2)
        ..lineTo(x3, y3);
    }

    if (active) {
      canvas.drawPath(
        corner(w * 0.14, h * 0.36, w * 0.36, h * 0.36, w * 0.36, h * 0.14),
        p,
      );
      canvas.drawPath(
        corner(w * 0.86, h * 0.36, w * 0.64, h * 0.36, w * 0.64, h * 0.14),
        p,
      );
      canvas.drawPath(
        corner(w * 0.14, h * 0.64, w * 0.36, h * 0.64, w * 0.36, h * 0.86),
        p,
      );
      canvas.drawPath(
        corner(w * 0.86, h * 0.64, w * 0.64, h * 0.64, w * 0.64, h * 0.86),
        p,
      );
      return;
    }

    canvas.drawPath(
      corner(w * 0.16, h * 0.40, w * 0.16, h * 0.16, w * 0.40, h * 0.16),
      p,
    );
    canvas.drawPath(
      corner(w * 0.60, h * 0.16, w * 0.84, h * 0.16, w * 0.84, h * 0.40),
      p,
    );
    canvas.drawPath(
      corner(w * 0.16, h * 0.60, w * 0.16, h * 0.84, w * 0.40, h * 0.84),
      p,
    );
    canvas.drawPath(
      corner(w * 0.60, h * 0.84, w * 0.84, h * 0.84, w * 0.84, h * 0.60),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant _FullscreenPainter old) =>
      old.active != active || old.color != color;
}
