import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/feature_app_bar.dart';
import '../data/weather_mock.dart';

/// Niğde için profesyonel hava durumu sayfası: koyu "gökyüzü" hero kartı, saatlik
/// şerit, 7 günlük sıcaklık çubukları ve detay ızgarası. Tüm veriler örnektir;
/// tasarım dili uygulamayla birebir (4px radius, PateezInter, marka paleti).
class WeatherScreen extends StatelessWidget {
  const WeatherScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.lightOverlay,
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        body: Column(
          children: [
            const FeatureAppBar(title: 'Hava Durumu'),
            Expanded(
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
                  const _Hero()
                      .animate()
                      .fadeIn(duration: 360.ms, curve: Curves.easeOutCubic)
                      .slideY(begin: 0.06, end: 0, duration: 360.ms, curve: Curves.easeOutCubic),
                  const SizedBox(height: AppSpacing.xl),
                  const _SectionTitle('Saatlik tahmin'),
                  const SizedBox(height: AppSpacing.md),
                  const _HourlyStrip()
                      .animate()
                      .fadeIn(delay: 80.ms, duration: 340.ms, curve: Curves.easeOutCubic)
                      .slideY(begin: 0.06, end: 0, delay: 80.ms, duration: 340.ms, curve: Curves.easeOutCubic),
                  const SizedBox(height: AppSpacing.xl),
                  const _SectionTitle('7 günlük tahmin'),
                  const SizedBox(height: AppSpacing.md),
                  const _WeeklyCard()
                      .animate()
                      .fadeIn(delay: 140.ms, duration: 340.ms, curve: Curves.easeOutCubic)
                      .slideY(begin: 0.06, end: 0, delay: 140.ms, duration: 340.ms, curve: Curves.easeOutCubic),
                  const SizedBox(height: AppSpacing.xl),
                  const _SectionTitle('Detaylar'),
                  const SizedBox(height: AppSpacing.md),
                  const _DetailsGrid()
                      .animate()
                      .fadeIn(delay: 200.ms, duration: 340.ms, curve: Curves.easeOutCubic)
                      .slideY(begin: 0.06, end: 0, delay: 200.ms, duration: 340.ms, curve: Curves.easeOutCubic),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
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
          margin: const EdgeInsets.only(right: AppSpacing.sm + 2),
          decoration: BoxDecoration(
            color: AppColors.actionRed,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Text(
          title,
          style: AppTypography.titleL.copyWith(
            color: AppColors.inkStrong,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.deepOcean, Color(0xFF1C2A36)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepOcean.withValues(alpha: 0.30),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          // sıcak ufuk parıltısı (sağ üst)
          Positioned(
            right: -30,
            top: -40,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.warmHorizon.withValues(alpha: 0.30),
                    AppColors.warmHorizon.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Symbols.location_on_rounded, size: 16, color: Colors.white),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${WeatherMock.city} · ${WeatherMock.district}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleS.copyWith(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    WeatherMock.dateLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.meta.copyWith(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${WeatherMock.currentTemp}°',
                          style: AppTypography.display.copyWith(
                            color: Colors.white,
                            fontSize: 68,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          WeatherMock.condition,
                          style: AppTypography.titleM.copyWith(
                            color: Colors.white.withValues(alpha: 0.92),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    WeatherMock.currentKind.icon,
                    size: 76,
                    color: AppColors.warmHorizon,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              DefaultTextStyle.merge(
                style: AppTypography.meta.copyWith(
                  color: Colors.white.withValues(alpha: 0.80),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Hissedilen ${WeatherMock.feelsLike}°'),
                      const _HeroDot(),
                      Text('En yüksek ${WeatherMock.hi}°'),
                      const _HeroDot(),
                      Text('En düşük ${WeatherMock.lo}°'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroDot extends StatelessWidget {
  const _HeroDot();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3,
      height: 3,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding});
  final Widget child;
  final EdgeInsets? padding;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.line),
      ),
      child: child,
    );
  }
}

class _HourlyStrip extends StatelessWidget {
  const _HourlyStrip();
  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: SizedBox(
        height: 96,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          itemCount: WeatherMock.hours.length,
          separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xl),
          itemBuilder: (context, i) {
            final h = WeatherMock.hours[i];
            return Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  h.label,
                  style: AppTypography.meta.copyWith(
                    color: i == 0 ? AppColors.inkStrong : AppColors.support,
                    fontSize: 12,
                    fontWeight: i == 0 ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
                Icon(h.kind.icon, size: 26, color: h.kind.tint),
                Text(
                  '${h.temp}°',
                  style: AppTypography.titleS.copyWith(
                    color: AppColors.inkStrong,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _WeeklyCard extends StatelessWidget {
  const _WeeklyCard();
  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      child: Column(
        children: [
          for (var i = 0; i < WeatherMock.days.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.softLine),
            _WeeklyRow(day: WeatherMock.days[i], isToday: i == 0),
          ],
        ],
      ),
    );
  }
}

class _WeeklyRow extends StatelessWidget {
  const _WeeklyRow({required this.day, required this.isToday});
  final DayForecast day;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              day.day,
              style: AppTypography.titleS.copyWith(
                color: isToday ? AppColors.inkStrong : AppColors.ink,
                fontSize: 13.5,
                fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Icon(day.kind.icon, size: 22, color: day.kind.tint),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              day.summary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.inkSoft,
                fontSize: 12.5,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '${day.lo}°',
            style: AppTypography.meta.copyWith(
              color: AppColors.support,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _RangeBar(lo: day.lo, hi: day.hi),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '${day.hi}°',
            style: AppTypography.titleS.copyWith(
              color: AppColors.inkStrong,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _RangeBar extends StatelessWidget {
  const _RangeBar({required this.lo, required this.hi});
  final int lo;
  final int hi;

  @override
  Widget build(BuildContext context) {
    final min = WeatherMock.weekMin;
    final max = WeatherMock.weekMax;
    final span = (max - min) == 0 ? 1 : (max - min);
    final leftFrac = (lo - min) / span;
    final widthFrac = (hi - lo) / span;
    return SizedBox(
      width: 64,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          return Stack(
            children: [
              Container(
                height: 5,
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceInk,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Positioned(
                left: w * leftFrac,
                child: Container(
                  height: 5,
                  width: (w * widthFrac).clamp(8.0, w),
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.warmHorizon, AppColors.actionRed],
                    ),
                    borderRadius: BorderRadius.circular(999),
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

class _DetailsGrid extends StatelessWidget {
  const _DetailsGrid();
  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: AppSpacing.md,
      mainAxisSpacing: AppSpacing.md,
      childAspectRatio: 1.9,
      children: WeatherMock.details
          .map((d) => _DetailCard(detail: d))
          .toList(growable: false),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.detail});
  final WeatherDetail detail;

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.deepOcean.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(4),
            ),
            alignment: Alignment.center,
            child: Icon(detail.icon, size: 20, color: AppColors.deepOcean),
          ),
          const SizedBox(width: AppSpacing.sm + 2),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detail.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.eyebrow.copyWith(
                    color: AppColors.support,
                    fontSize: 10.5,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  detail.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleM.copyWith(
                    color: AppColors.inkStrong,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  detail.note,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.meta.copyWith(
                    color: AppColors.support,
                    fontSize: 10.5,
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
