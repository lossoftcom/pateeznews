import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/mock/home_mock_data.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
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
  const DetailReactionsStrip({super.key, required this.stats});

  final NewsReactionStats stats;

  @override
  State<DetailReactionsStrip> createState() => _DetailReactionsStripState();
}

class _DetailReactionsStripState extends State<DetailReactionsStrip> {
  NewsReaction? _selected;
  late Map<NewsReaction, int> _counts;

  @override
  void initState() {
    super.initState();
    _counts = Map.of(widget.stats.counts);
  }

  @override
  void didUpdateWidget(covariant DetailReactionsStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stats != widget.stats) {
      _counts = Map.of(widget.stats.counts);
      _selected = null;
    }
  }

  void _tap(NewsReaction r) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selected == r) {
        _counts[r] = (_counts[r] ?? 1) - 1;
        _selected = null;
      } else {
        if (_selected != null) {
          _counts[_selected!] = (_counts[_selected!] ?? 1) - 1;
        }
        _counts[r] = (_counts[r] ?? 0) + 1;
        _selected = r;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final total = _counts.values.fold<int>(0, (a, b) => a + b);
    final maxCount = _counts.values.fold<int>(0, math.max);
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      color: AppColors.surface,
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
              const spacing = 6.0;
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
                        isActive: _selected == items[i],
                        onTap: () => _tap(items[i]),
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

Color _reactionAccent(NewsReaction reaction) {
  switch (reaction) {
    case NewsReaction.like:
      return AppColors.actionRed;
    case NewsReaction.illuminating:
      return AppColors.warmHorizon;
    case NewsReaction.thoughtful:
      return AppColors.deepOcean;
    case NewsReaction.surprised:
      return const Color(0xFFE89B3D);
    case NewsReaction.saddened:
      return AppColors.supportCool;
    case NewsReaction.angering:
      return const Color(0xFFC0392B);
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
            color: AppColors.warmHorizon.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: AppColors.warmHorizon.withValues(alpha: 0.32),
              width: 1,
            ),
          ),
          child: const Text(
            '✦',
            style: TextStyle(
              color: AppColors.warmHorizon,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'EMOJİYLE TEPKİ VER',
                style: AppTypography.eyebrow.copyWith(
                  color: AppColors.inkStrong,
                  fontSize: 11.5,
                  letterSpacing: 1.3,
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
                  Icons.people_alt_outlined,
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
                        emoji: widget.reaction.emoji,
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
            Text(
              widget.reaction.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTypography.meta.copyWith(
                color: isActive ? accent : AppColors.support,
                fontSize: 9.5,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                letterSpacing: 0.4,
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
    required this.emoji,
    required this.accent,
    required this.isActive,
    required this.progress,
    required this.ripple,
  });

  final String emoji;
  final Color accent;
  final bool isActive;
  final double progress;
  final double ripple;

  static const double _diskSize = 48;

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
                    color: accent.withValues(alpha: (1 - ripple) * 0.55),
                    width: 1.5,
                  ),
                  color: accent.withValues(alpha: (1 - ripple) * 0.10),
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
                        Color.lerp(accent, Colors.white, 0.18)!,
                        accent,
                        Color.lerp(accent, Colors.black, 0.18)!,
                      ]
                    : [
                        Colors.white,
                        accent.withValues(alpha: 0.22),
                        Color.lerp(
                          AppColors.deepOcean,
                          accent,
                          0.36,
                        )!.withValues(alpha: 0.14),
                      ],
                stops: const [0, 0.55, 1],
              ),
              border: Border.all(
                color: isActive
                    ? Colors.transparent
                    : accent.withValues(alpha: 0.26),
                width: 1,
              ),
              boxShadow: [
                if (isActive)
                  BoxShadow(
                    color: accent.withValues(alpha: 0.42),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  )
                else
                  BoxShadow(
                    color: Color.lerp(
                      AppColors.deepOcean,
                      accent,
                      0.3,
                    )!.withValues(alpha: 0.10),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(emoji, style: const TextStyle(fontSize: 26, height: 1)),
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
                child: Icon(Icons.check_rounded, size: 10, color: accent),
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
