import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/data_unavailable_state.dart';
import '../../../shared/widgets/feature_app_bar.dart';
import '../data/weather_repository.dart';

const Color _weatherTan = Color(0xFFB7A27A);
const Color _weatherCream = Color(0xFFFFFBF5);
const Color _weatherLine = Color(0xFFEFE8DB);
const Color _weatherSun = Color(0xFFFFA313);
const Color _weatherCloud = Color(0xFFFFB21A);

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({
    super.key,
    this.initialData = const WeatherData.empty(),
    this.repository = const WeatherRepository(),
    this.onSearch,
  });

  final WeatherData initialData;
  final WeatherRepository repository;
  final VoidCallback? onSearch;

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  late WeatherData _data;
  var _refreshing = false;

  @override
  void initState() {
    super.initState();
    _data = widget.initialData;
  }

  @override
  void didUpdateWidget(covariant WeatherScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_data.hasWeather || !widget.initialData.hasWeather) return;
    _data = widget.initialData;
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    final data = await widget.repository.fetch(forceRefresh: true);
    if (!mounted) return;
    setState(() {
      _data = data;
      _refreshing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.lightOverlay,
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        body: Column(
          children: [
            FeatureAppBar(title: 'Hava Durumu', onSearch: widget.onSearch),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.actionRed,
                backgroundColor: AppColors.surface,
                displacement: 32,
                onRefresh: _refresh,
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
                    if (!_data.hasWeather)
                      const DataUnavailableState()
                    else ...[
                      _CurrentWeatherCard(data: _data, loading: false)
                          .animate()
                          .fadeIn(duration: 340.ms, curve: Curves.easeOutCubic)
                          .slideY(
                            begin: 0.04,
                            end: 0,
                            duration: 340.ms,
                            curve: Curves.easeOutCubic,
                          ),
                      const SizedBox(height: AppSpacing.xl),
                      const _SectionTitle('Saatlik tahmin'),
                      const SizedBox(height: AppSpacing.md),
                      _HourlyStrip(hours: _data.hourly)
                          .animate()
                          .fadeIn(
                            delay: 80.ms,
                            duration: 300.ms,
                            curve: Curves.easeOutCubic,
                          )
                          .slideY(
                            begin: 0.04,
                            end: 0,
                            delay: 80.ms,
                            duration: 300.ms,
                            curve: Curves.easeOutCubic,
                          ),
                      const SizedBox(height: AppSpacing.xl),
                      const _SectionTitle('7 günlük tahmin'),
                      const SizedBox(height: AppSpacing.md),
                      _WeeklyCard(data: _data)
                          .animate()
                          .fadeIn(
                            delay: 130.ms,
                            duration: 300.ms,
                            curve: Curves.easeOutCubic,
                          )
                          .slideY(
                            begin: 0.04,
                            end: 0,
                            delay: 130.ms,
                            duration: 300.ms,
                            curve: Curves.easeOutCubic,
                          ),
                      const SizedBox(height: AppSpacing.xl),
                      const _SectionTitle('Detaylar'),
                      const SizedBox(height: AppSpacing.md),
                      _DetailsGrid(data: _data).animate().fadeIn(
                        delay: 180.ms,
                        duration: 300.ms,
                        curve: Curves.easeOutCubic,
                      ),
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

class _CurrentWeatherCard extends StatelessWidget {
  const _CurrentWeatherCard({required this.data, required this.loading});

  final WeatherData data;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final current = data.current;
    final today = data.today;
    final precipitationProbability =
        today?.precipitationProbability ??
        (data.hourly.isNotEmpty
            ? data.hourly.first.precipitationProbability
            : 0);
    final condition = data.hasWeather
        ? data.conditionLabel
        : 'Canlı veri bekleniyor';
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: _weatherLine),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 22,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Symbols.map_pin_line, size: 15, color: _weatherTan),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  _upperCaseTr(data.location),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.eyebrow.copyWith(
                    color: _weatherTan,
                    fontSize: 11,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      data.hasWeather ? '${current.temperature}°' : '--°',
                      style: AppTypography.display.copyWith(
                        color: AppColors.ink,
                        fontSize: 56,
                        fontWeight: FontWeight.w300,
                        height: 1,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            condition,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.titleS.copyWith(
                              color: _weatherTan,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            data.hasWeather
                                ? 'Hissedilen: ${current.apparentTemperature}°'
                                : loading
                                ? 'Canlı veri alınıyor'
                                : 'Sayfayı aşağı çekerek yenile',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.meta.copyWith(
                              color: _weatherTan.withValues(alpha: 0.58),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: _weatherCream,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: _weatherLine),
                ),
                alignment: Alignment.center,
                child: data.hasWeather
                    ? WeatherMotionIcon(
                        code: current.weatherCode,
                        isDay: current.isDay,
                        label: condition,
                        size: 54,
                      )
                    : const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _HeroMetric(
                label: 'Nem',
                value: data.hasWeather ? '%${current.humidity}' : '--',
              ),
              _HeroDivider(),
              _HeroMetric(
                label: 'Rüzgar',
                value: data.hasWeather ? '${current.windSpeed} km/s' : '--',
              ),
              _HeroDivider(),
              _HeroMetric(
                label: weatherPrecipitationLabel(
                  current.weatherCode,
                  current.isDay,
                ),
                value: data.hasWeather ? '%$precipitationProbability' : '--',
              ),
              _HeroDivider(),
              _HeroMetric(
                label: 'Min / Maks',
                value: today == null ? '--' : '${today.min}° / ${today.max}°',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.meta.copyWith(
              color: _weatherTan.withValues(alpha: 0.6),
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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

class _HeroDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 30,
      margin: const EdgeInsets.symmetric(horizontal: 7),
      color: _weatherLine,
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
          margin: const EdgeInsets.only(right: 10),
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

class _SoftCard extends StatelessWidget {
  const _SoftCard({required this.child, this.padding});
  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: AppColors.line),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _HourlyStrip extends StatelessWidget {
  const _HourlyStrip({required this.hours});
  final List<WeatherHour> hours;

  @override
  Widget build(BuildContext context) {
    final visible = hours.take(12).toList(growable: false);
    return _SoftCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: SizedBox(
        height: 112,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          itemCount: visible.length,
          separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xl),
          itemBuilder: (context, i) {
            final hour = visible[i];
            return SizedBox(
              width: 48,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    hour.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.meta.copyWith(
                      color: i == 0 ? AppColors.inkStrong : AppColors.support,
                      fontSize: 12,
                      fontWeight: i == 0 ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                  Icon(
                    weatherIcon(hour.weatherCode, hour.isDay),
                    size: 25,
                    color: weatherTint(hour.weatherCode, hour.isDay),
                  ),
                  _PrecipChance(
                    probability: hour.precipitationProbability,
                    code: hour.weatherCode,
                    isDay: hour.isDay,
                  ),
                  Text(
                    '${hour.temperature}°',
                    style: AppTypography.titleS.copyWith(
                      color: AppColors.inkStrong,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PrecipChance extends StatelessWidget {
  const _PrecipChance({
    required this.probability,
    required this.code,
    required this.isDay,
    this.hourLabel = '',
  });

  final int probability;
  final int code;
  final bool isDay;
  final String hourLabel;

  @override
  Widget build(BuildContext context) {
    final tint = weatherTint(code, isDay);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Symbols.drop_fill, size: 10, color: tint.withValues(alpha: 0.72)),
        const SizedBox(width: 2),
        Text(
          '%$probability',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.meta.copyWith(
            color: AppColors.support,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        if (hourLabel.isNotEmpty) ...[
          const SizedBox(width: 4),
          Text(
            hourLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.meta.copyWith(
              color: AppColors.support,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ],
    );
  }
}

class _WeeklyCard extends StatelessWidget {
  const _WeeklyCard({required this.data});
  final WeatherData data;

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: 6,
      ),
      child: Column(
        children: [
          for (var i = 0; i < data.daily.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.softLine),
            _WeeklyRow(day: data.daily[i], isToday: i == 0, data: data),
          ],
        ],
      ),
    );
  }
}

class _WeeklyRow extends StatelessWidget {
  const _WeeklyRow({
    required this.day,
    required this.isToday,
    required this.data,
  });

  final WeatherDay day;
  final bool isToday;
  final WeatherData data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Text(
              day.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.titleS.copyWith(
                color: isToday ? AppColors.inkStrong : AppColors.ink,
                fontSize: 13,
                fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            weatherIcon(day.weatherCode, true),
            size: 21,
            color: weatherTint(day.weatherCode, true),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  weatherConditionLabel(day.weatherCode),
                  maxLines: 2,
                  overflow: TextOverflow.visible,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.inkSoft,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 3),
                _PrecipChance(
                  probability: day.precipitationProbability,
                  code: day.weatherCode,
                  isDay: true,
                  hourLabel: day.precipitationHourLabel,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${day.min}°',
            style: AppTypography.meta.copyWith(
              color: AppColors.support,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          _RangeBar(
            lo: day.min,
            hi: day.max,
            min: data.weekMin,
            max: data.weekMax,
          ),
          const SizedBox(width: 8),
          Text(
            '${day.max}°',
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
  const _RangeBar({
    required this.lo,
    required this.hi,
    required this.min,
    required this.max,
  });

  final int lo;
  final int hi;
  final int min;
  final int max;

  @override
  Widget build(BuildContext context) {
    final span = (max - min) == 0 ? 1 : (max - min);
    final leftFrac = ((lo - min) / span).clamp(0.0, 1.0);
    final widthFrac = ((hi - lo) / span).clamp(0.08, 1.0);
    return SizedBox(
      width: 58,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
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
                left: width * leftFrac,
                child: Container(
                  height: 5,
                  width: (width * widthFrac).clamp(8.0, width),
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
  const _DetailsGrid({required this.data});
  final WeatherData data;

  @override
  Widget build(BuildContext context) {
    final current = data.current;
    final today = data.today;
    final details = [
      _WeatherDetail(
        Symbols.temp_hot_fill,
        'Hissedilen',
        '${current.apparentTemperature}°',
      ),
      _WeatherDetail(Symbols.water_percent_fill, 'Nem', '%${current.humidity}'),
      _WeatherDetail(Symbols.windy_fill, 'Rüzgar', '${current.windSpeed} km/s'),
      _WeatherDetail(Symbols.compass_fill, 'Basınç', '${current.pressure} hPa'),
      _WeatherDetail(
        Symbols.drop_fill,
        weatherPrecipitationLabel(current.weatherCode, current.isDay),
        today == null ? '--' : '%${today.precipitationProbability}',
      ),
      _WeatherDetail(Symbols.cloudy_fill, 'Bulut', '%${current.cloudCover}'),
      _WeatherDetail(
        Symbols.sun_fill,
        'UV',
        today == null ? '--' : today.uvIndex.toStringAsFixed(1),
      ),
      _WeatherDetail(
        Symbols.moon_clear_fill,
        'Gün batımı',
        _timeOnly(today?.sunset ?? ''),
      ),
    ];

    return GridView.builder(
      padding: EdgeInsets.zero,
      itemCount: details.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
        childAspectRatio: 2.25,
      ),
      itemBuilder: (context, index) => _DetailCard(detail: details[index]),
    );
  }
}

class _WeatherDetail {
  const _WeatherDetail(this.icon, this.label, this.value);

  final IconData icon;
  final String label;
  final String value;
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.detail});
  final _WeatherDetail detail;

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _weatherCream,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: _weatherLine),
            ),
            alignment: Alignment.center,
            child: Icon(detail.icon, size: 18, color: AppColors.deepOcean),
          ),
          const SizedBox(width: 10),
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
                const SizedBox(height: 2),
                Text(
                  detail.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleM.copyWith(
                    color: AppColors.inkStrong,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
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

class WeatherMotionIcon extends StatefulWidget {
  const WeatherMotionIcon({
    super.key,
    required this.code,
    required this.isDay,
    required this.label,
    this.size = 56,
  });

  final int code;
  final bool isDay;
  final String label;
  final double size;

  @override
  State<WeatherMotionIcon> createState() => _WeatherMotionIconState();
}

class _WeatherMotionIconState extends State<WeatherMotionIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kind = weatherMotionKind(widget.code, widget.isDay);
    return Semantics(
      label: widget.label,
      child: RepaintBoundary(
        child: SizedBox.square(
          dimension: widget.size,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _controller.value;
              final drift = math.sin(t * math.pi * 2) * 2.6;
              final pulse = 0.94 + (math.sin(t * math.pi * 2) + 1) * 0.035;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  if (kind == WeatherMotionKind.clearDay ||
                      kind == WeatherMotionKind.cloudy)
                    Positioned(
                      right: kind == WeatherMotionKind.cloudy ? 5 : 12,
                      top: kind == WeatherMotionKind.cloudy ? 5 : 10,
                      child: Transform.rotate(
                        angle: t * math.pi * 2,
                        child: _SunShape(
                          size: widget.size * 0.46,
                          rays: kind == WeatherMotionKind.clearDay,
                        ),
                      ),
                    ),
                  if (kind == WeatherMotionKind.clearNight)
                    Positioned(
                      right: 14,
                      top: 12,
                      child: Transform.scale(
                        scale: pulse,
                        child: Icon(
                          Symbols.moon_clear_fill,
                          size: widget.size * 0.52,
                          color: AppColors.deepOcean,
                        ),
                      ),
                    ),
                  if (kind != WeatherMotionKind.clearDay &&
                      kind != WeatherMotionKind.clearNight)
                    Positioned(
                      left: 5 + drift,
                      bottom: kind == WeatherMotionKind.fog ? 12 : 9,
                      child: _CloudShape(size: widget.size * 0.72, kind: kind),
                    ),
                  if (kind == WeatherMotionKind.rain ||
                      kind == WeatherMotionKind.storm)
                    ..._drops(widget.size, t),
                  if (kind == WeatherMotionKind.fog) ..._fog(widget.size, t),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _drops(double size, double t) {
    return List.generate(3, (index) {
      final phase = (t + index * 0.22) % 1;
      return Positioned(
        left: size * (0.30 + index * 0.15),
        top: size * (0.60 + phase * 0.17),
        child: Opacity(
          opacity: 1 - phase,
          child: Container(
            width: 3,
            height: 9,
            decoration: BoxDecoration(
              color: AppColors.deepOcean.withValues(alpha: 0.54),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      );
    });
  }

  List<Widget> _fog(double size, double t) {
    return List.generate(3, (index) {
      final offset = math.sin((t + index * 0.2) * math.pi * 2) * 4;
      return Positioned(
        left: size * 0.18 + offset,
        top: size * (0.60 + index * 0.11),
        child: Container(
          width: size * 0.56,
          height: 3,
          decoration: BoxDecoration(
            color: AppColors.support.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      );
    });
  }
}

class _SunShape extends StatelessWidget {
  const _SunShape({required this.size, required this.rays});

  final double size;
  final bool rays;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (rays)
            for (var i = 0; i < 8; i++)
              Transform.rotate(
                angle: i * math.pi / 4,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    width: 3,
                    height: size * 0.15,
                    decoration: BoxDecoration(
                      color: _weatherSun.withValues(alpha: 0.58),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
          Container(
            width: size * 0.62,
            height: size * 0.62,
            decoration: const BoxDecoration(
              color: _weatherSun,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

class _CloudShape extends StatelessWidget {
  const _CloudShape({required this.size, required this.kind});

  final double size;
  final WeatherMotionKind kind;

  @override
  Widget build(BuildContext context) {
    final color = switch (kind) {
      WeatherMotionKind.rain || WeatherMotionKind.storm => AppColors.deepOcean,
      WeatherMotionKind.fog || WeatherMotionKind.snow => AppColors.support,
      _ => _weatherCloud,
    };
    return SizedBox(
      width: size,
      height: size * 0.58,
      child: Stack(
        children: [
          Positioned(
            left: size * 0.08,
            bottom: 0,
            child: Container(
              width: size * 0.80,
              height: size * 0.36,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(size),
              ),
            ),
          ),
          Positioned(
            left: size * 0.18,
            bottom: size * 0.15,
            child: Container(
              width: size * 0.34,
              height: size * 0.34,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
          Positioned(
            left: size * 0.42,
            bottom: size * 0.12,
            child: Container(
              width: size * 0.42,
              height: size * 0.42,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
        ],
      ),
    );
  }
}

String _timeOnly(String value) {
  if (value.length >= 16) return value.substring(11, 16);
  return '--';
}

String _upperCaseTr(String value) {
  return value.trim().replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();
}
