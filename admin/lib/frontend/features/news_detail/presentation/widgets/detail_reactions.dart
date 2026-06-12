import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../../core/mock/home_mock_data.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/frontend_toast.dart';
import '../../../account/data/frontend_auth_repository.dart';
import '../../../home/data/post_action_repository.dart';
import '../../data/news_detail_mock.dart';

/// Habere emoji ile tepki şeridi.
///
/// Tasarım dili: editorial haber + sosyal medya enerjisi. Onedio'da yer alan
/// "dairesel emoji + alt sayım" kalıbından ilham alınmış; ancak markaya özgü
/// soft radial gradient diskleri, glow shadow, scale+wiggle+ripple üçlüsü,
/// haptic feedback ve count tween'leri ile 2026 modern hissi taşır.
///
/// Eylem hattı:
///   - Dokun: haptic + bounce + wiggle + ripple, sayı yumuşak slide ile
///     güncellenir.
///   - Aktif seçim: disk daha doymuş radial gradient'a çıkar, accent glow
///     shadow eklenir, üst köşeye küçük tick dot, sayı accent renge tween eder.
///   - Grafik katmanı: her emoji diskinin çevresinde oran halkası, mevcut
///     yerleşimi bozmadan tepki yoğunluğunu gösterir.
///   - Yeniden dokun: seçim temizlenir.
class DetailReactionsStrip extends StatefulWidget {
  const DetailReactionsStrip({
    super.key,
    this.stats = const NewsReactionStats(counts: {}),
    this.postId = '',
    this.authState,
    this.postActionRepository = const PostActionRepository(),
  });

  final NewsReactionStats stats;
  final String postId;
  final FrontendAuthState? authState;
  final PostActionRepository postActionRepository;

  @override
  State<DetailReactionsStrip> createState() => _DetailReactionsStripState();
}

class _DetailReactionsStripState extends State<DetailReactionsStrip> {
  static const int _maxSelectedReactions = 3;

  final Set<NewsReaction> _selected = <NewsReaction>{};
  late Map<NewsReaction, int> _counts;
  NewsReaction? _busyReaction;
  bool _didPrecacheAssets = false;

  @override
  void initState() {
    super.initState();
    _counts = Map.of(widget.stats.counts);
    _fetchLiveState();
  }

  @override
  void didUpdateWidget(covariant DetailReactionsStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stats != widget.stats || oldWidget.postId != widget.postId) {
      _counts = Map.of(widget.stats.counts);
      _selected.clear();
      _busyReaction = null;
      _fetchLiveState();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didPrecacheAssets) return;
    _didPrecacheAssets = true;
    for (final reaction in NewsReaction.values) {
      precacheImage(AssetImage(reaction.assetPath), context);
    }
  }

  String get _authToken => widget.authState?.session.accessToken.trim() ?? '';

  bool get _hasNumericPostId => int.tryParse(widget.postId) != null;

  Future<void> _fetchLiveState() async {
    if (!_hasNumericPostId) return;
    try {
      final token = _authToken;
      final state = await widget.postActionRepository.fetchState(
        postId: widget.postId,
        token: token.isEmpty ? null : token,
      );
      if (!mounted) return;
      setState(() => _applyState(state));
    } catch (_) {
      // Detail kartı yine okunabilir kalmalı; canlı tepki state'i geçici
      // alınamazsa mevcut başlangıç sayıları bozulmaz.
    }
  }

  void _applyState(PostActionState state) {
    _counts = _countsFromReactionMap(state.reactions);
    _selected
      ..clear()
      ..addAll(_selectedFromIds(state.userReactions));
  }

  Future<void> _tap(NewsReaction r) async {
    if (!_hasNumericPostId || _busyReaction != null) return;
    final token = _authToken;
    if (!_selected.contains(r) && _selected.length >= _maxSelectedReactions) {
      _showMessage(
        'En fazla $_maxSelectedReactions emoji tepkisi seçebilirsiniz.',
        tone: FrontendToastTone.info,
      );
      return;
    }

    HapticFeedback.selectionClick();
    final previousCounts = Map<NewsReaction, int>.of(_counts);
    final previousSelected = Set<NewsReaction>.of(_selected);
    setState(() {
      _busyReaction = r;
      if (_selected.contains(r)) {
        _counts[r] = (_counts[r] ?? 1) - 1;
        _selected.remove(r);
      } else {
        _counts[r] = (_counts[r] ?? 0) + 1;
        _selected.add(r);
      }
    });

    try {
      final state = await widget.postActionRepository.toggleReaction(
        postId: widget.postId,
        token: token.isEmpty ? null : token,
        reaction: _reactionId(r),
      );
      if (!mounted) return;
      setState(() {
        _applyState(state);
        _busyReaction = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _counts = previousCounts;
        _selected
          ..clear()
          ..addAll(previousSelected);
        _busyReaction = null;
      });
      _showMessage(
        error is PostActionException
            ? error.message
            : 'Emoji tepkisi güncellenemedi.',
        tone: FrontendToastTone.error,
      );
    }
  }

  Map<NewsReaction, int> _countsFromReactionMap(Map<String, int> reactions) {
    return {
      for (final reaction in NewsReaction.values)
        reaction: reactions[_reactionId(reaction)] ?? 0,
    };
  }

  Iterable<NewsReaction> _selectedFromIds(List<String> ids) {
    final idSet = ids
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    return NewsReaction.values.where(
      (reaction) => idSet.contains(_reactionId(reaction)),
    );
  }

  void _showMessage(
    String message, {
    FrontendToastTone tone = FrontendToastTone.success,
  }) => FrontendToast.show(context, message: message, tone: tone);

  @override
  Widget build(BuildContext context) {
    final total = _counts.values.fold<int>(0, (a, b) => a + b);
    final maxCount = _counts.values.fold<int>(0, math.max);
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.softLine)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        AppSpacing.xl,
        AppSpacing.pageHorizontal,
        AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(total: total),
          const SizedBox(height: AppSpacing.xl),
          LayoutBuilder(
            builder: (context, c) {
              const items = NewsReaction.values;
              const spacing = 4.0;
              final cellWidth =
                  (c.maxWidth - spacing * (items.length - 1)) / items.length;
              return Row(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0) const SizedBox(width: spacing),
                    SizedBox(
                      width: cellWidth,
                      child: _ReactionCell(
                        reaction: items[i],
                        count: _counts[items[i]] ?? 0,
                        maxCount: maxCount,
                        isActive: _selected.contains(items[i]),
                        onTap: () => unawaited(_tap(items[i])),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

String _reactionId(NewsReaction reaction) {
  switch (reaction) {
    case NewsReaction.like:
      return 'love';
    case NewsReaction.illuminating:
      return 'great';
    case NewsReaction.thoughtful:
      return 'bravo';
    case NewsReaction.surprised:
      return 'laugh';
    case NewsReaction.saddened:
      return 'sad';
    case NewsReaction.angering:
      return 'angry';
  }
}

Color _reactionAccent(NewsReaction reaction) {
  switch (reaction) {
    case NewsReaction.like:
      return const Color(0xFFE35D73);
    case NewsReaction.illuminating:
      return const Color(0xFFD98A34);
    case NewsReaction.thoughtful:
      return const Color(0xFF66789A);
    case NewsReaction.surprised:
      return const Color(0xFF36AFA2);
    case NewsReaction.saddened:
      return const Color(0xFF5B8FC8);
    case NewsReaction.angering:
      return const Color(0xFFD7634C);
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.deepOcean.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: AppColors.deepOcean.withValues(alpha: 0.18),
              width: 1,
            ),
          ),
          child: const Icon(
            Symbols.questionnaire_line,
            color: AppColors.deepOcean,
            size: 15,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Emojiyle Tepki Ver',
                style: AppTypography.eyebrow.copyWith(
                  color: AppColors.inkStrong,
                  fontSize: 11.5,
                  letterSpacing: 0.2,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Bu haber sana ne hissettirdi?',
                style: AppTypography.meta.copyWith(
                  color: AppColors.support,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.4),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          ),
          child: Container(
            key: ValueKey<int>(total),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceInk,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Symbols.people_alt_outlined,
                  size: 12,
                  color: AppColors.inkSoft,
                ),
                const SizedBox(width: 4),
                Text(
                  CountFormat.compact(total),
                  style: AppTypography.meta.copyWith(
                    color: AppColors.inkSoft,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ReactionCell extends StatefulWidget {
  const _ReactionCell({
    required this.reaction,
    required this.count,
    required this.maxCount,
    required this.isActive,
    required this.onTap,
  });

  final NewsReaction reaction;
  final int count;
  final int maxCount;
  final bool isActive;
  final VoidCallback onTap;

  @override
  State<_ReactionCell> createState() => _ReactionCellState();
}

class _ReactionCellState extends State<_ReactionCell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _bounce;
  late final Animation<double> _wiggle;
  late final Animation<double> _ripple;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 540),
    );
    _bounce = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 1.28,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.28,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 65,
      ),
    ]).animate(_ctrl);
    _wiggle = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0, end: -0.10), weight: 1),
      TweenSequenceItem(
        tween: Tween<double>(begin: -0.10, end: 0.10),
        weight: 2,
      ),
      TweenSequenceItem(tween: Tween<double>(begin: 0.10, end: 0), weight: 1),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ripple = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _handleTap() {
    _ctrl.forward(from: 0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final isActive = widget.isActive;
    final accent = _reactionAccent(widget.reaction);
    final progress = widget.maxCount <= 0
        ? 0.0
        : widget.count / widget.maxCount;

    return Semantics(
      button: true,
      selected: isActive,
      label: '${widget.reaction.label}, ${widget.count} tepki',
      child: GestureDetector(
        onTap: _handleTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RepaintBoundary(
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (context, _) {
                  return Transform.scale(
                    scale: _bounce.value,
                    child: Transform.rotate(
                      angle: _wiggle.value,
                      child: _Disk(
                        assetPath: widget.reaction.assetPath,
                        accent: accent,
                        isActive: isActive,
                        progress: progress,
                        ripple: _ripple.value,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, anim) {
                return ClipRect(
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.6),
                      end: Offset.zero,
                    ).animate(anim),
                    child: FadeTransition(opacity: anim, child: child),
                  ),
                );
              },
              child: Text(
                CountFormat.compact(widget.count),
                key: ValueKey<int>(widget.count),
                style: AppTypography.titleS.copyWith(
                  color: isActive ? accent : AppColors.inkSoft,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ),
            const SizedBox(height: 3),
            SizedBox(
              width: double.infinity,
              height: 13,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: Text(
                  widget.reaction.label,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: AppTypography.meta.copyWith(
                    color: isActive ? accent : AppColors.support,
                    fontSize: 9.2,
                    fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                    letterSpacing: 0,
                    height: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Disk extends StatelessWidget {
  const _Disk({
    required this.assetPath,
    required this.accent,
    required this.isActive,
    required this.progress,
    required this.ripple,
  });

  final String assetPath;
  final Color accent;
  final bool isActive;
  final double progress;
  final double ripple;

  static const double _diskSize = 48;
  static const double _assetSize = 42;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutCubic,
              tween: Tween<double>(end: progress.clamp(0.0, 1.0).toDouble()),
              builder: (context, value, _) {
                return CustomPaint(
                  painter: _ReactionRingPainter(
                    accent: accent,
                    progress: value,
                    isActive: isActive,
                  ),
                );
              },
            ),
          ),
          // Ripple — büyür ve solar.
          if (ripple > 0 && ripple < 1)
            IgnorePointer(
              child: Container(
                width: _diskSize * (1 + ripple * 0.85),
                height: _diskSize * (1 + ripple * 0.85),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: accent.withValues(alpha: (1 - ripple) * 0.42),
                    width: 1.5,
                  ),
                  color: accent.withValues(alpha: (1 - ripple) * 0.07),
                ),
              ),
            ),
          // Disk
          AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            width: _diskSize,
            height: _diskSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.25, -0.45),
                radius: 1.1,
                colors: isActive
                    ? [
                        Color.lerp(accent, Colors.white, 0.28)!,
                        Color.lerp(accent, Colors.white, 0.08)!,
                        Color.lerp(accent, Colors.black, 0.12)!,
                      ]
                    : [
                        Color.lerp(accent, Colors.white, 0.90)!,
                        Color.lerp(accent, Colors.white, 0.76)!,
                        Color.lerp(AppColors.surface, accent, 0.24)!,
                      ],
                stops: const [0, 0.55, 1],
              ),
              border: Border.all(
                color: isActive
                    ? Colors.transparent
                    : accent.withValues(alpha: 0.20),
                width: 1,
              ),
              boxShadow: [
                if (isActive)
                  BoxShadow(
                    color: accent.withValues(alpha: 0.34),
                    blurRadius: 14,
                    offset: const Offset(0, 7),
                  )
                else
                  BoxShadow(
                    color: Color.lerp(
                      AppColors.deepOcean,
                      accent,
                      0.3,
                    )!.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
              ],
            ),
            alignment: Alignment.center,
            child: Image.asset(
              assetPath,
              width: _assetSize,
              height: _assetSize,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              gaplessPlayback: true,
              excludeFromSemantics: true,
            ),
          ),
          // Aktif rozeti — küçük tick noktası
          AnimatedPositioned(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutBack,
            top: isActive ? -2 : 4,
            right: isActive ? -2 : 6,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 240),
              opacity: isActive ? 1 : 0,
              child: Container(
                width: 16,
                height: 16,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: accent, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.3),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Icon(Symbols.check_rounded, size: 10, color: accent),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReactionRingPainter extends CustomPainter {
  const _ReactionRingPainter({
    required this.accent,
    required this.progress,
    required this.isActive,
  });

  final Color accent;
  final double progress;
  final bool isActive;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 2.2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final stroke = isActive ? 3.2 : 2.4;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = AppColors.deepOcean.withValues(alpha: isActive ? 0.24 : 0.13),
    );

    if (progress <= 0) return;

    final visibleProgress = progress.clamp(0.08, 1.0).toDouble();
    final sweep = visibleProgress * math.pi * 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: math.pi * 1.5,
        colors: [
          Color.lerp(AppColors.deepOcean, accent, 0.58)!,
          accent,
          Color.lerp(AppColors.warmHorizon, accent, 0.45)!,
        ],
      ).createShader(rect);

    canvas.drawArc(rect, -math.pi / 2, sweep, false, paint);
  }

  @override
  bool shouldRepaint(covariant _ReactionRingPainter oldDelegate) {
    return oldDelegate.accent != accent ||
        oldDelegate.progress != progress ||
        oldDelegate.isActive != isActive;
  }
}
