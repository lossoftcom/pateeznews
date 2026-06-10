import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../../../core/platform/debug_platform_view_hot_restart.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/cached_image.dart';

/// Ana sayfa haber kartında "ses" bloğu seçiliyse çalınan ses oynatıcı.
///
/// Kaynaklar — video özellikleriyle aynı motor:
///   • YouTube Music bağlantısı → [youtube_player_iframe] (gizli 1×1, ses çalar)
///   • Uzak / yerel ses dosyaları → [video_player]
///
/// Tasarım: projenin koyu (deepOcean) dilinde, dönen plak + kapak görseli,
/// KIRMIZI dolan seek çubuğu, ±15 sn atlama, ses açma/kapama. Yüksekliği ölçülü,
/// tam ekranda mobil-uyumlu görünür.
class NewsAudioCard extends StatefulWidget {
  const NewsAudioCard({super.key, required this.url, required this.coverUrl});

  final String url;
  final String coverUrl;

  @override
  State<NewsAudioCard> createState() => _NewsAudioCardState();
}

class _NewsAudioCardState extends State<NewsAudioCard>
    with SingleTickerProviderStateMixin {
  late final bool _isYoutube;
  String? _videoId;

  YoutubePlayerController? _yt;
  StreamSubscription<YoutubeVideoState>? _ytStateSub;
  StreamSubscription<YoutubePlayerValue>? _ytValueSub;

  VideoPlayerController? _file;

  late final AnimationController _vinyl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 9),
  );

  bool _isPlaying = false;
  bool _muted = false;
  bool _youtubeViewReady = !kDebugMode;
  final double _volume = 1.0;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _videoId = _youtubeIdFrom(widget.url);
    _isYoutube = _videoId != null && _videoId!.isNotEmpty;
    if (_isYoutube) {
      if (kDebugMode) {
        unawaited(_prepareAndSetupYoutube());
      } else {
        _setupYoutube();
      }
    } else {
      _setupFile();
    }
  }

  Future<void> _prepareAndSetupYoutube() async {
    await prepareDebugDarwinPlatformViewsForHotRestart();
    if (!mounted) return;
    _setupYoutube();
    setState(() => _youtubeViewReady = true);
  }

  void _setupYoutube() {
    final controller = YoutubePlayerController(
      params: const YoutubePlayerParams(
        showControls: false,
        showFullscreenButton: false,
        mute: false,
        enableCaption: false,
        strictRelatedVideos: true,
        playsInline: true,
      ),
    );
    _yt = controller;
    controller.cueVideoById(videoId: _videoId!);
    _ytStateSub = controller.videoStateStream.listen((state) {
      if (!mounted) return;
      setState(() => _position = state.position);
    });
    _ytValueSub = controller.stream.listen((value) {
      if (!mounted) return;
      final duration = value.metaData.duration;
      setState(() {
        _isPlaying = value.playerState == PlayerState.playing;
        if (duration > Duration.zero) _duration = duration;
      });
      _syncVinyl();
    });
  }

  Future<void> _setupFile() async {
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.url),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _file = controller;
    controller.addListener(_onFileValue);
    try {
      await controller.setVolume(1);
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _duration = controller.value.duration);
    } catch (_) {
      // Ses açılamasa da kart bozulmaz; oynatma denemesinde sessizce başarısız olur.
    }
  }

  void _onFileValue() {
    final controller = _file;
    if (controller == null || !mounted) return;
    final value = controller.value;
    setState(() {
      _isPlaying = value.isPlaying;
      _position = value.position;
      _muted = value.volume == 0;
      if (value.duration > Duration.zero) _duration = value.duration;
    });
    _syncVinyl();
  }

  void _syncVinyl() {
    if (_isPlaying) {
      if (!_vinyl.isAnimating) _vinyl.repeat();
    } else {
      if (_vinyl.isAnimating) _vinyl.stop();
    }
  }

  void _togglePlay() {
    if (_isYoutube) {
      final controller = _yt;
      if (controller == null) return;
      if (_isPlaying) {
        controller.pauseVideo();
      } else {
        controller.playVideo();
      }
    } else {
      final controller = _file;
      if (controller == null || !controller.value.isInitialized) return;
      if (controller.value.isPlaying) {
        controller.pause();
      } else {
        controller.play();
      }
    }
  }

  void _seek(double fraction) {
    final target = _duration * fraction.clamp(0.0, 1.0);
    if (_isYoutube) {
      final controller = _yt;
      if (controller == null) return;
      controller.seekTo(
        seconds: target.inMilliseconds / 1000.0,
        allowSeekAhead: true,
      );
    } else {
      _file?.seekTo(target);
    }
    setState(() => _position = target);
  }

  void _skip(int seconds) {
    if (_duration <= Duration.zero) return;
    var next = _position + Duration(seconds: seconds);
    if (next < Duration.zero) next = Duration.zero;
    if (next > _duration) next = _duration;
    final fraction = _duration.inMilliseconds == 0
        ? 0.0
        : next.inMilliseconds / _duration.inMilliseconds;
    _seek(fraction);
  }

  void _toggleMute() {
    final muted = !_muted;
    if (_isYoutube) {
      final controller = _yt;
      if (controller == null) return;
      if (muted) {
        controller.mute();
      } else {
        controller.unMute();
      }
      setState(() => _muted = muted);
    } else {
      _file?.setVolume(muted ? 0 : (_volume == 0 ? 1 : _volume));
    }
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    // Karttan tamamen çıkınca sesi durdur (arka planda çalmaya devam etmesin).
    if (info.visibleFraction <= 0 && _isPlaying) {
      if (_isYoutube) {
        _yt?.pauseVideo();
      } else {
        _file?.pause();
      }
    }
  }

  @override
  void dispose() {
    _ytStateSub?.cancel();
    _ytValueSub?.cancel();
    _yt?.close();
    _file?.removeListener(_onFileValue);
    _file?.dispose();
    _vinyl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = _duration.inMilliseconds;
    final fraction = total > 0
        ? (_position.inMilliseconds / total).clamp(0.0, 1.0)
        : 0.0;
    final remaining = _duration > Duration.zero
        ? _duration - _position
        : Duration.zero;

    return VisibilityDetector(
      key: ValueKey('audio-${widget.url}'),
      onVisibilityChanged: _onVisibilityChanged,
      child: Stack(
        children: [
          // YouTube Music: ses için gizli 1×1 oynatıcı (görünmez, sesi çalar).
          if (_isYoutube && _yt != null && _youtubeViewReady)
            SizedBox(
              width: 1,
              height: 1,
              child: YoutubePlayer(
                controller: _yt!,
                aspectRatio: 1,
                enableFullScreenOnVerticalDrag: false,
                autoFullScreen: false,
              ),
            ),
          _AudioPanel(
            coverUrl: widget.coverUrl,
            isPlaying: _isPlaying,
            isMuted: _muted,
            fraction: fraction,
            position: _position,
            remaining: remaining,
            vinyl: _vinyl,
            onPlayPause: _togglePlay,
            onSeek: _seek,
            onSkip: _skip,
            onToggleMute: _toggleMute,
          ),
        ],
      ),
    );
  }
}

String? _youtubeIdFrom(String url) {
  final host = Uri.tryParse(url.trim())?.host.toLowerCase() ?? '';
  if (host.contains('youtube.com') ||
      host.contains('youtu.be') ||
      host.contains('music.youtube.com') ||
      host.contains('youtube-nocookie.com')) {
    return YoutubePlayerController.convertUrlToId(url.trim());
  }
  return null;
}

// ---------------------------------------------------------------------------
// Görsel panel (koyu, modern, proje renkleri)
// ---------------------------------------------------------------------------

const Color _audioTop = AppColors.deepOcean;
const Color _audioBottom = Color(0xFF1B2A37);

class _AudioPanel extends StatelessWidget {
  const _AudioPanel({
    required this.coverUrl,
    required this.isPlaying,
    required this.isMuted,
    required this.fraction,
    required this.position,
    required this.remaining,
    required this.vinyl,
    required this.onPlayPause,
    required this.onSeek,
    required this.onSkip,
    required this.onToggleMute,
  });

  final String coverUrl;
  final bool isPlaying;
  final bool isMuted;
  final double fraction;
  final Duration position;
  final Duration remaining;
  final Animation<double> vinyl;
  final VoidCallback onPlayPause;
  final ValueChanged<double> onSeek;
  final ValueChanged<int> onSkip;
  final VoidCallback onToggleMute;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_audioTop, _audioBottom],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 60, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Badge(),
            const SizedBox(height: 14),
            _CoverVinyl(coverUrl: coverUrl, isPlaying: isPlaying, vinyl: vinyl),
            const SizedBox(height: 18),
            Row(
              children: [
                Text(_clock(position), style: _timeStyle),
                const Spacer(),
                Text(_clock(remaining), style: _timeStyle),
              ],
            ),
            const SizedBox(height: 7),
            _SeekBar(fraction: fraction, onSeek: onSeek),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _SkipButton(forward: false, onTap: () => onSkip(-15)),
                const SizedBox(width: 26),
                _PlayButton(isPlaying: isPlaying, onTap: onPlayPause),
                const SizedBox(width: 26),
                _SkipButton(forward: true, onTap: () => onSkip(15)),
              ],
            ),
            const SizedBox(height: 12),
            _MuteRow(isMuted: isMuted, onToggle: onToggleMute),
          ],
        ),
      ),
    );
  }
}

const TextStyle _timeStyle = TextStyle(
  color: Color(0xCCFFFFFF),
  fontSize: 11.5,
  fontWeight: FontWeight.w700,
  fontFeatures: [FontFeature.tabularFigures()],
);

class _Badge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Symbols.podcasts_rounded,
            size: 13,
            color: AppColors.warmHorizon,
          ),
          const SizedBox(width: 6),
          Text(
            'Pateez Ses',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverVinyl extends StatelessWidget {
  const _CoverVinyl({
    required this.coverUrl,
    required this.isPlaying,
    required this.vinyl,
  });

  final String coverUrl;
  final bool isPlaying;
  final Animation<double> vinyl;

  @override
  Widget build(BuildContext context) {
    const cover = 126.0;
    const vinylSize = cover * 0.86;
    return SizedBox(
      height: cover,
      width: cover + 56,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Plak: durunca kapağın arkasında gizli; çalınca sağa kayıp döner.
          AnimatedPositioned(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            top: (cover - vinylSize) / 2,
            right: isPlaying ? 0 : 56,
            child: RotationTransition(
              turns: vinyl,
              child: Container(
                width: vinylSize,
                height: vinylSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF0D141C),
                  border: Border.all(color: Colors.black, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // pateez.com — plağın üstünde, plakla birlikte döner.
                    Align(
                      alignment: const Alignment(0, -0.5),
                      child: Text(
                        'pateez.com',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    Center(
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.actionRed,
                              AppColors.warmHorizon,
                            ],
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: _audioBottom,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Kapak görseli — resmin TAMAMI görünür (contain).
          Positioned(
            left: 0,
            top: 0,
            child: Container(
              width: cover,
              height: cover,
              decoration: BoxDecoration(
                color: const Color(0xFF24323F),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (coverUrl.trim().isNotEmpty)
                    CachedImage(
                      url: coverUrl,
                      fit: BoxFit.contain,
                      placeholderColor: const Color(0xFF24323F),
                      errorWidget: const ColoredBox(color: Color(0xFF24323F)),
                    ),
                  if (isPlaying)
                    ColoredBox(
                      color: Colors.black.withValues(alpha: 0.34),
                      child: Center(child: _Equalizer(animation: vinyl)),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Equalizer extends StatelessWidget {
  const _Equalizer({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 30,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          return CustomPaint(painter: _EqualizerPainter(t: animation.value));
        },
      ),
    );
  }
}

class _EqualizerPainter extends CustomPainter {
  _EqualizerPainter({required this.t});
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..isAntiAlias = true;
    const bars = 4;
    final barW = size.width / (bars * 2 - 1);
    final phases = [0.0, 0.35, 0.6, 0.85];
    for (var i = 0; i < bars; i++) {
      final p = (t + phases[i]) % 1.0;
      final wave = 0.35 + 0.65 * (0.5 - (p - 0.5).abs()) * 2;
      final h = size.height * wave.clamp(0.2, 1.0);
      final x = i * barW * 2;
      final rect = Rect.fromLTWH(x, size.height - h, barW, h);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(barW / 2)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _EqualizerPainter old) => old.t != t;
}

class _SeekBar extends StatelessWidget {
  const _SeekBar({required this.fraction, required this.onSeek});

  final double fraction;
  final ValueChanged<double> onSeek;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        void seekAt(double dx) {
          if (width > 0) onSeek((dx / width).clamp(0.0, 1.0));
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => seekAt(d.localPosition.dx),
          onHorizontalDragUpdate: (d) => seekAt(d.localPosition.dx),
          child: SizedBox(
            height: 18,
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: SizedBox(
                  height: 6,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ColoredBox(
                          color: Colors.white.withValues(alpha: 0.16),
                        ),
                      ),
                      FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: fraction.clamp(0.0, 1.0),
                        child: const ColoredBox(color: AppColors.actionRed),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.isPlaying, required this.onTap});

  final bool isPlaying;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 60,
          height: 60,
          child: Center(
            child: CustomPaint(
              size: const Size(26, 26),
              painter: _PlayPausePainter(
                playing: isPlaying,
                color: AppColors.deepOcean,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SkipButton extends StatelessWidget {
  const _SkipButton({required this.forward, required this.onTap});

  final bool forward;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.10),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 46,
          height: 46,
          child: Center(
            child: CustomPaint(
              size: const Size(22, 18),
              painter: _SkipPainter(forward: forward, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

class _MuteRow extends StatelessWidget {
  const _MuteRow({required this.isMuted, required this.onToggle});

  final bool isMuted;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomPaint(
            size: const Size(18, 18),
            painter: _SpeakerPainter(
              muted: isMuted,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isMuted ? 'Ses kapalı' : 'Ses açık',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Özel çizimli simgeler
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
      final total = barW * 2 + gap;
      final startX = (w - total) / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(startX, h * 0.1, startX + barW, h * 0.9),
          radius,
        ),
        fill,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(startX + barW + gap, h * 0.1, startX + total, h * 0.9),
          radius,
        ),
        fill,
      );
    } else {
      final path = Path()
        ..moveTo(w * 0.26, h * 0.16)
        ..lineTo(w * 0.26, h * 0.84)
        ..lineTo(w * 0.86, h * 0.5)
        ..close();
      final stroke = Paint()
        ..color = color
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.1
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

class _SkipPainter extends CustomPainter {
  _SkipPainter({required this.forward, required this.color});
  final bool forward;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final fill = Paint()
      ..color = color
      ..isAntiAlias = true
      ..style = PaintingStyle.fill;

    void triangle(double cx, double half) {
      final path = Path();
      if (forward) {
        path
          ..moveTo(cx - half, h * 0.12)
          ..lineTo(cx + half, h * 0.5)
          ..lineTo(cx - half, h * 0.88)
          ..close();
      } else {
        path
          ..moveTo(cx + half, h * 0.12)
          ..lineTo(cx - half, h * 0.5)
          ..lineTo(cx + half, h * 0.88)
          ..close();
      }
      canvas.drawPath(path, fill);
    }

    final half = w * 0.26;
    triangle(w * 0.30, half);
    triangle(w * 0.70, half);
  }

  @override
  bool shouldRepaint(covariant _SkipPainter old) =>
      old.forward != forward || old.color != color;
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
        Rect.fromCircle(center: Offset(w * 0.46, h * 0.5), radius: w * 0.22),
        -0.7,
        1.4,
        false,
        line,
      );
      canvas.drawArc(
        Rect.fromCircle(center: Offset(w * 0.46, h * 0.5), radius: w * 0.34),
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

String _clock(Duration value) {
  final d = value.isNegative ? Duration.zero : value;
  String two(int n) => n.toString().padLeft(2, '0');
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  if (h > 0) return '$h:${two(m)}:${two(s)}';
  return '${two(m)}:${two(s)}';
}
