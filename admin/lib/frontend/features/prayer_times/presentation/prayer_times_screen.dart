import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/data_unavailable_state.dart';
import '../../../shared/widgets/feature_app_bar.dart';
import '../data/prayer_times_repository.dart';

const Color _accent = Color(0xFF12A18C);

enum _Status { passed, current, next, upcoming }

class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({
    super.key,
    this.initialData = const PrayerTimesData.empty(),
    this.repository = const PrayerTimesRepository(),
    this.onSearch,
  });

  final PrayerTimesData initialData;
  final PrayerTimesRepository repository;
  final VoidCallback? onSearch;

  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen>
    with SingleTickerProviderStateMixin {
  late PrayerTimesData _data = widget.initialData;
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();
  late final Animation<double> _introCurve = CurvedAnimation(
    parent: _intro,
    curve: Curves.easeOutCubic,
  );

  Timer? _ticker;
  DateTime _now = DateTime.now();
  var _refreshing = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _intro.dispose();
    super.dispose();
  }

  Future<void> _refresh({bool forceRefresh = true}) async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    final data = await widget.repository.fetch(forceRefresh: forceRefresh);
    if (!mounted) return;
    setState(() {
      _data = data;
      _refreshing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final day = _data.today;
    final prayers = day?.times ?? const <PrayerTime>[];
    final calc = prayers.isEmpty
        ? null
        : _PrayerCalculation.from(prayers, _now);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.lightOverlay,
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        body: Column(
          children: [
            FeatureAppBar(title: 'Namaz Vakitleri', onSearch: widget.onSearch),
            Expanded(
              child: RefreshIndicator(
                color: _accent,
                onRefresh: () => _refresh(forceRefresh: true),
                child: ListView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.pageHorizontal,
                    AppSpacing.lg,
                    AppSpacing.pageHorizontal,
                    AppSpacing.xxxl + bottomInset,
                  ),
                  children: [
                    if (prayers.isEmpty)
                      const DataUnavailableState()
                    else ...[
                      _HeaderCard(data: _data, day: day),
                      const SizedBox(height: AppSpacing.md),
                      AnimatedBuilder(
                        animation: _introCurve,
                        builder: (context, _) => _CountdownCard(
                          progress: calc!.progress * _introCurve.value,
                          remaining: calc.remaining,
                          nextName: calc.nextPrayer.name,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      const _SectionTitle('Bugünün Vakitleri'),
                      const SizedBox(height: AppSpacing.md),
                      for (var i = 0; i < prayers.length; i++) ...[
                        if (i > 0) const SizedBox(height: AppSpacing.sm),
                        _PrayerRow(
                          prayer: prayers[i],
                          status: calc!.statusFor(i),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                      const _SectionTitle('Kıble ve Güneş'),
                      const SizedBox(height: AppSpacing.md),
                      _InfoGrid(day: day),
                      const SizedBox(height: AppSpacing.xl),
                      const _SectionTitle('Günün Ayeti'),
                      const SizedBox(height: AppSpacing.md),
                      _AyahCard(ayah: _data.dailyAyah),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrayerCalculation {
  const _PrayerCalculation({
    required this.nextPrayer,
    required this.nextIndex,
    required this.currentIndex,
    required this.remaining,
    required this.progress,
    required this.times,
    required this.allPassed,
  });

  factory _PrayerCalculation.from(List<PrayerTime> prayers, DateTime now) {
    final times = [
      for (final prayer in prayers)
        DateTime(now.year, now.month, now.day, prayer.hour, prayer.minute),
    ];
    final rawNext = times.indexWhere((time) => time.isAfter(now));
    final allPassed = rawNext == -1;
    final nextIndex = allPassed ? 0 : rawNext;
    final currentIndex = allPassed ? times.length - 1 : nextIndex - 1;
    final nextTime = allPassed
        ? times[0].add(const Duration(days: 1))
        : times[nextIndex];
    final currentTime = currentIndex < 0
        ? times.last.subtract(const Duration(days: 1))
        : (allPassed ? times.last : times[currentIndex]);
    final totalSeconds = nextTime.difference(currentTime).inSeconds;
    final elapsedSeconds = now.difference(currentTime).inSeconds;
    final progress = totalSeconds <= 0
        ? 0.0
        : (elapsedSeconds / totalSeconds).clamp(0.0, 1.0);
    return _PrayerCalculation(
      nextPrayer: prayers[nextIndex],
      nextIndex: nextIndex,
      currentIndex: currentIndex,
      remaining: nextTime.difference(now),
      progress: progress,
      times: times,
      allPassed: allPassed,
    );
  }

  final PrayerTime nextPrayer;
  final int nextIndex;
  final int currentIndex;
  final Duration remaining;
  final double progress;
  final List<DateTime> times;
  final bool allPassed;

  _Status statusFor(int index) {
    if (index == nextIndex && (!allPassed || index == 0)) return _Status.next;
    if (index == currentIndex) return _Status.current;
    if (times[index].isAfter(DateTime.now())) return _Status.upcoming;
    return _Status.passed;
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.data, required this.day});

  final PrayerTimesData data;
  final PrayerDay? day;

  @override
  Widget build(BuildContext context) {
    final date = day == null
        ? data.serviceDateLabel
        : [
            if (day!.gregorianDateLabel.isNotEmpty) day!.gregorianDateLabel,
            if (day!.hijriDateLabel.isNotEmpty) day!.hijriDateLabel,
          ].join(' · ');

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: _accent.withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(5),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Symbols.moon_clear_fill,
              size: 22,
              color: _accent,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Symbols.map_pin_line,
                      size: 12,
                      color: AppColors.support,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        data.location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.meta.copyWith(
                          color: AppColors.support,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Namaz Vakitleri',
                  style: AppTypography.titleL.copyWith(
                    color: AppColors.inkStrong,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  date.isEmpty ? data.source : date,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.meta.copyWith(
                    color: AppColors.inkSoft,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CountdownCard extends StatelessWidget {
  const _CountdownCard({
    required this.progress,
    required this.remaining,
    required this.nextName,
  });

  final double progress;
  final Duration remaining;
  final String nextName;

  String get _remainingLabel {
    final safe = remaining.isNegative ? Duration.zero : remaining;
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(safe.inHours)}:${two(safe.inMinutes.remainder(60))}:${two(safe.inSeconds.remainder(60))}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 26),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: AppColors.line),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 22,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Center(
        child: SizedBox(
          width: 246,
          height: 246,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size.square(246),
                painter: _RingPainter(progress: progress, accent: _accent),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$nextName vaktine',
                    style: AppTypography.eyebrow.copyWith(
                      color: _accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _remainingLabel,
                    style: AppTypography.display.copyWith(
                      color: AppColors.inkStrong,
                      fontSize: 33,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      height: 1,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'kalan süre',
                    style: AppTypography.meta.copyWith(
                      color: AppColors.support,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress, required this.accent});

  final double progress;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    final tickPaint = Paint()..strokeCap = StrokeCap.round;
    for (var i = 0; i < 60; i++) {
      final angle = (i / 60) * 2 * math.pi - math.pi / 2;
      final isMajor = i % 5 == 0;
      final outer = radius - 2;
      final inner = radius - (isMajor ? 11 : 6);
      tickPaint
        ..color = AppColors.support.withValues(alpha: isMajor ? 0.38 : 0.16)
        ..strokeWidth = isMajor ? 2 : 1;
      final dir = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(center + dir * inner, center + dir * outer, tickPaint);
    }

    final ringRadius = radius - 24;
    final rect = Rect.fromCircle(center: center, radius: ringRadius);
    canvas.drawCircle(
      center,
      ringRadius,
      Paint()
        ..color = accent.withValues(alpha: 0.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9,
    );
    final sweep = progress.clamp(0.0, 1.0) * 2 * math.pi;
    if (sweep <= 0.0001) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..shader = SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: 3 * math.pi / 2,
          colors: [accent.withValues(alpha: 0.45), accent],
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round,
    );
    final endAngle = -math.pi / 2 + sweep;
    final end =
        center + Offset(math.cos(endAngle), math.sin(endAngle)) * ringRadius;
    canvas.drawCircle(end, 6.5, Paint()..color = accent);
    canvas.drawCircle(
      end,
      6.5,
      Paint()
        ..color = AppColors.surface
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.accent != accent;
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 18,
          margin: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(
            color: _accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Text(
          title,
          style: AppTypography.titleL.copyWith(
            color: AppColors.inkStrong,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _PrayerRow extends StatelessWidget {
  const _PrayerRow({required this.prayer, required this.status});

  final PrayerTime prayer;
  final _Status status;

  @override
  Widget build(BuildContext context) {
    final isNext = status == _Status.next;
    final muted = status == _Status.passed;
    final textColor = isNext
        ? _accent
        : muted
        ? AppColors.support
        : AppColors.inkStrong;

    return Container(
      decoration: BoxDecoration(
        color: isNext ? _accent.withValues(alpha: 0.07) : AppColors.surface,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: isNext ? _accent.withValues(alpha: 0.45) : AppColors.line,
        ),
        boxShadow: [
          BoxShadow(
            color: isNext ? _accent.withValues(alpha: 0.14) : AppColors.shadow,
            blurRadius: isNext ? 16 : 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          _StatusDot(status: status),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              prayer.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.titleM.copyWith(
                color: textColor,
                fontSize: 15.5,
                fontWeight: isNext ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
          if (isNext) ...[const _NextTag(), const SizedBox(width: 10)],
          Text(
            prayer.time,
            style: AppTypography.titleM.copyWith(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _NextTag extends StatelessWidget {
  const _NextTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _accent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'Sıradaki',
        style: AppTypography.eyebrow.copyWith(
          color: Colors.white,
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});

  final _Status status;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case _Status.next:
        return _DotFrame(
          color: _accent,
          fill: _accent.withValues(alpha: 0.16),
          child: Container(
            width: 9,
            height: 9,
            decoration: const BoxDecoration(
              color: _accent,
              shape: BoxShape.circle,
            ),
          ),
        );
      case _Status.current:
        return _DotFrame(
          color: _accent.withValues(alpha: 0.55),
          fill: _accent.withValues(alpha: 0.10),
          child: const Icon(Symbols.check, size: 12, color: _accent),
        );
      case _Status.passed:
        return _DotFrame(
          color: AppColors.line,
          fill: AppColors.surfaceInk,
          child: const Icon(Symbols.check, size: 11, color: AppColors.support),
        );
      case _Status.upcoming:
        return _DotFrame(color: AppColors.line, fill: Colors.transparent);
    }
  }
}

class _DotFrame extends StatelessWidget {
  const _DotFrame({required this.color, required this.fill, this.child});

  final Color color;
  final Color fill;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.6),
      ),
      child: child,
    );
  }
}

class _InfoGrid extends StatelessWidget {
  const _InfoGrid({required this.day});

  final PrayerDay? day;

  @override
  Widget build(BuildContext context) {
    final sunrise = day?.sunrise?.time ?? '-';
    final sunset = day?.sunset?.time ?? '-';
    final hijri = _HijriParts.fromLabel(day?.hijriDateLabel ?? '-');
    final items = [
      _Info(Symbols.compass_fill, 'Kıble Açısı', day?.qiblaAngle ?? '-'),
      _Info(Symbols.sun_fill, 'Gün Doğumu', sunrise),
      _Info(Symbols.moon_clear_fill, 'Gün Batımı', sunset),
      _Info(
        Symbols.calendar_event_line,
        'Hicri Tarih',
        hijri.main,
        secondary: hijri.year,
      ),
    ];
    return GridView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
        childAspectRatio: 2.25,
      ),
      itemBuilder: (context, index) => _InfoTile(info: items[index]),
    );
  }
}

class _Info {
  const _Info(this.icon, this.label, this.value, {this.secondary});

  final IconData icon;
  final String label;
  final String value;
  final String? secondary;
}

class _HijriParts {
  const _HijriParts({required this.main, this.year});

  factory _HijriParts.fromLabel(String value) {
    final text = value.trim();
    final match = RegExp(r'^(.+?)\s+(\d{3,4})$').firstMatch(text);
    if (match == null) return _HijriParts(main: text.isEmpty ? '-' : text);
    return _HijriParts(
      main: match.group(1)!.trim(),
      year: '${match.group(2)} Hicri',
    );
  }

  final String main;
  final String? year;
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.info});

  final _Info info;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: AppColors.line),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(5),
            ),
            alignment: Alignment.center,
            child: Icon(info.icon, size: 17, color: _accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.eyebrow.copyWith(
                    color: AppColors.support,
                    fontSize: 10.5,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  alignment: Alignment.centerLeft,
                  fit: BoxFit.scaleDown,
                  child: Text(
                    info.value,
                    maxLines: 1,
                    softWrap: false,
                    style: AppTypography.titleM.copyWith(
                      color: AppColors.inkStrong,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                if (info.secondary != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    info.secondary!,
                    maxLines: 1,
                    softWrap: false,
                    style: AppTypography.eyebrow.copyWith(
                      color: AppColors.support,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AyahCard extends StatelessWidget {
  const _AyahCard({required this.ayah});

  final DailyAyah? ayah;

  @override
  Widget build(BuildContext context) {
    final hasAyah =
        ayah != null &&
        (ayah!.arabicText.isNotEmpty || ayah!.translation.isNotEmpty);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _accent.withValues(alpha: 0.10),
            _accent.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: _accent.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Symbols.sparkling_fill,
            size: 20,
            color: _accent.withValues(alpha: 0.85),
          ),
          const SizedBox(height: 12),
          if (!hasAyah)
            Text(
              'Günün ayeti için Diyanet Kur’an API tokenı admin ayarlarından tanımlanmalı.',
              style: AppTypography.titleM.copyWith(
                color: AppColors.inkStrong,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            )
          else ...[
            if (ayah!.arabicText.isNotEmpty) ...[
              Text(
                ayah!.arabicText,
                textAlign: TextAlign.right,
                style: AppTypography.titleL.copyWith(
                  color: AppColors.inkStrong,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  height: 1.7,
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (ayah!.translation.isNotEmpty)
              Text(
                '“${ayah!.translation}”',
                style: AppTypography.titleM.copyWith(
                  color: AppColors.inkStrong,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
            const SizedBox(height: 12),
            Text(
              ayah!.reference,
              style: AppTypography.eyebrow.copyWith(
                color: _accent,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
