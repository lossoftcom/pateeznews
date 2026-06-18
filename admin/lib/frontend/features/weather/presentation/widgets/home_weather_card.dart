import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/weather_repository.dart';

/// Ana sayfada bir haberin ardından duran "Hava Durumu" bölümü.
///
/// Tasarım: kutu yok — piyasa şeridiyle aynı ritimde, açık bir başlık ve onun
/// altında yatay kayan içerik. Açılışta **o günkü** hava görünür; kullanıcı
/// parmağıyla sağa kaydırınca saat-saat tahmin ve (varsa) yağış olasılığı
/// yüzdesi akar. Kendiliğinden hareket etmez.
///
/// Veri [WeatherData]'dan gelir; boşsa sunum amaçlı örneğe düşer.
class HomeWeatherCard extends StatelessWidget {
  const HomeWeatherCard({
    super.key,
    this.weatherData = const WeatherData.empty(),
    this.onOpen,
  });

  final WeatherData weatherData;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final view = _WxView.resolve(weatherData);
    final tint = _tint(view.code, view.isDay);

    return DecoratedBox(
      // "Kutu" değil: üstte ve altta tam olarak zemin rengine erir (kenar
      // görünmez), yalnızca ortada yumuşacık, sıcak bir ışık kalır.
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.canvas,
            Color.alphaBlend(
              const Color(0xFFF39C12).withValues(alpha: 0.11),
              AppColors.canvas,
            ),
            AppColors.canvas,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(view: view, tint: tint, onOpen: onOpen),
          SizedBox(
            height: 118,
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Bugün paneli ekranı doldurur; sağ kenarda saatlik hücreler
                // göz kırpar ki kaydırma daveti net olsun.
                final nowWidth =
                    constraints.maxWidth - AppSpacing.pageHorizontal - 52;
                return ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.pageHorizontal,
                  ),
                  clipBehavior: Clip.none,
                  children: [
                    SizedBox(
                      width: nowWidth,
                      child: _NowPanel(view: view, tint: tint),
                    ),
                    const _HoursDivider(),
                    for (final hour in view.hours) _HourTile(hour: hour),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.view, required this.tint, this.onOpen});

  final _WxView view;
  final Color tint;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        2,
        AppSpacing.pageHorizontal,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          Icon(weatherIcon(view.code, view.isDay), size: 19, color: tint),
          const SizedBox(width: 8),
          Text(view.location, style: AppTypography.titleL),
          const SizedBox(width: 7),
          Padding(
            padding: const EdgeInsets.only(bottom: 1),
            child: Text(
              'Bugün',
              style: AppTypography.titleL.copyWith(
                color: AppColors.support,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Spacer(),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onOpen,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  children: [
                    Text(
                      'Hava Durumu',
                      style: AppTypography.meta.copyWith(
                        color: AppColors.deepOcean,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Symbols.arrow_forward_rounded,
                      size: 14,
                      color: AppColors.deepOcean,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bugün paneli — kutusuz; büyük sıcaklık, durum ve minimal istatistikler.
class _NowPanel extends StatelessWidget {
  const _NowPanel({required this.view, required this.tint});

  final _WxView view;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${view.temp}',
                          style: AppTypography.display.copyWith(
                            fontSize: 40,
                            fontWeight: FontWeight.w800,
                            height: 1,
                            color: AppColors.inkStrong,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 3, left: 1),
                          child: Text(
                            '°',
                            style: AppTypography.display.copyWith(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: AppColors.support,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      view.condition,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleS.copyWith(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Hissedilen ${view.feelsLike}°',
                      style: AppTypography.meta.copyWith(
                        fontSize: 11.5,
                        color: AppColors.support,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              _HeroGlyph(view: view, tint: tint),
            ],
          ),
          const SizedBox(height: 12),
          _MiniStats(view: view),
        ],
      ),
    );
  }
}

/// Sade hava ikonu — küçük, yumuşak tonlu, kutu hissi vermeyen.
class _HeroGlyph extends StatelessWidget {
  const _HeroGlyph({required this.view, required this.tint});

  final _WxView view;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(15),
      ),
      alignment: Alignment.center,
      child: Icon(weatherIcon(view.code, view.isDay), size: 27, color: tint),
    );
  }
}

/// Minimal istatistik satırı — etiket yok, yalnızca renkli ikon + değer.
class _MiniStats extends StatelessWidget {
  const _MiniStats({required this.view});

  final _WxView view;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _MiniStat(
          icon: Symbols.drop_fill,
          color: const Color(0xFF3B82F6),
          value: '%${view.humidity}',
        ),
        _MiniStat(
          icon: Symbols.windy_fill,
          color: const Color(0xFF64748B),
          value: '${view.wind}',
        ),
        _MiniStat(
          icon: Symbols.water_percent_fill,
          color: const Color(0xFF0EA5E9),
          value: '%${view.precipChance}',
        ),
        _MiniStat(
          icon: Symbols.temp_hot_fill,
          color: const Color(0xFFF59E0B),
          value: '${view.lo}°/${view.hi}°',
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.icon, required this.color, required this.value});

  final IconData icon;
  final Color color;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(
          value,
          style: AppTypography.titleS.copyWith(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// Bugün paneli ile saatlik hücreleri ayıran ince dikey çizgi (kutu değil).
class _HoursDivider extends StatelessWidget {
  const _HoursDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      margin: const EdgeInsets.fromLTRB(0, 20, 14, 20),
      color: AppColors.line,
    );
  }
}

class _HourTile extends StatelessWidget {
  const _HourTile({required this.hour});

  final _WxHour hour;

  @override
  Widget build(BuildContext context) {
    final tint = _tint(hour.code, hour.isDay);
    final hasRain = hour.precip > 0;
    return SizedBox(
      width: 52,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            hour.label,
            maxLines: 1,
            style: AppTypography.meta.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: hour.isNow ? AppColors.ink : AppColors.support,
            ),
          ),
          const SizedBox(height: 8),
          Icon(weatherIcon(hour.code, hour.isDay), size: 20, color: tint),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Symbols.drop_fill,
                size: 9,
                color: hasRain
                    ? const Color(0xFF3B82F6)
                    : AppColors.placeholderSoft,
              ),
              const SizedBox(width: 1),
              Text(
                hasRain ? '%${hour.precip}' : '—',
                style: AppTypography.meta.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: hasRain
                      ? const Color(0xFF3B82F6)
                      : AppColors.placeholderSoft,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${hour.temp}°',
            style: AppTypography.titleS.copyWith(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: AppColors.inkStrong,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Hava tipine göre sade vurgu rengi.
Color _tint(int code, bool isDay) {
  return switch (weatherMotionKind(code, isDay)) {
    WeatherMotionKind.clearDay => const Color(0xFFF59E0B), // amber
    WeatherMotionKind.clearNight => const Color(0xFF4F46E5), // indigo
    WeatherMotionKind.cloudy => const Color(0xFF64748B), // slate
    WeatherMotionKind.fog => const Color(0xFF94A3B8),
    WeatherMotionKind.rain => const Color(0xFF3B82F6), // blue
    WeatherMotionKind.snow => const Color(0xFF38BDF8), // cyan
    WeatherMotionKind.storm => const Color(0xFF6366F1),
  };
}

// ---------------------------------------------------------------------------
// Sunum modelleri
// ---------------------------------------------------------------------------

@immutable
class _WxHour {
  const _WxHour({
    required this.label,
    required this.code,
    required this.isDay,
    required this.temp,
    required this.precip,
    this.isNow = false,
  });

  final String label;
  final int code;
  final bool isDay;
  final int temp;
  final int precip;
  final bool isNow;
}

@immutable
class _WxView {
  const _WxView({
    required this.location,
    required this.temp,
    required this.condition,
    required this.feelsLike,
    required this.hi,
    required this.lo,
    required this.humidity,
    required this.wind,
    required this.precipChance,
    required this.code,
    required this.isDay,
    required this.hours,
  });

  final String location;
  final int temp;
  final String condition;
  final int feelsLike;
  final int hi;
  final int lo;
  final int humidity;
  final int wind;
  final int precipChance;
  final int code;
  final bool isDay;
  final List<_WxHour> hours;

  /// Gerçek [WeatherData]'dan üret; veri yoksa örneğe düş.
  static _WxView resolve(WeatherData data) {
    if (!data.hasWeather) return sample;

    final current = data.current;
    final today = data.today;
    final hours = <_WxHour>[
      for (var i = 0; i < data.hourly.length && i < 12; i++)
        _WxHour(
          label: i == 0 ? 'Şimdi' : data.hourly[i].label,
          code: data.hourly[i].weatherCode,
          isDay: data.hourly[i].isDay,
          temp: data.hourly[i].temperature,
          precip: data.hourly[i].precipitationProbability,
          isNow: i == 0,
        ),
    ];

    return _WxView(
      location: data.location,
      temp: current.temperature,
      condition: data.conditionLabel,
      feelsLike: current.apparentTemperature,
      hi: today?.max ?? data.weekMax,
      lo: today?.min ?? data.weekMin,
      humidity: current.humidity,
      wind: current.windSpeed,
      precipChance: today?.precipitationProbability ?? 0,
      code: current.weatherCode,
      isDay: current.isDay,
      hours: hours.isEmpty ? sample.hours : hours,
    );
  }

  /// Sunum amaçlı örnek (Niğde, açık bir Haziran günü).
  static const sample = _WxView(
    location: 'Niğde',
    temp: 25,
    condition: 'Açık',
    feelsLike: 23,
    hi: 28,
    lo: 17,
    humidity: 29,
    wind: 22,
    precipChance: 18,
    code: 0,
    isDay: true,
    hours: <_WxHour>[
      _WxHour(label: 'Şimdi', code: 0, isDay: true, temp: 25, precip: 0, isNow: true),
      _WxHour(label: '12:00', code: 0, isDay: true, temp: 26, precip: 0),
      _WxHour(label: '13:00', code: 2, isDay: true, temp: 27, precip: 0),
      _WxHour(label: '14:00', code: 2, isDay: true, temp: 27, precip: 3),
      _WxHour(label: '15:00', code: 2, isDay: true, temp: 28, precip: 3),
      _WxHour(label: '16:00', code: 3, isDay: true, temp: 27, precip: 12),
      _WxHour(label: '17:00', code: 80, isDay: true, temp: 25, precip: 38),
      _WxHour(label: '18:00', code: 80, isDay: true, temp: 23, precip: 45),
      _WxHour(label: '19:00', code: 61, isDay: true, temp: 21, precip: 60),
      _WxHour(label: '20:00', code: 2, isDay: false, temp: 19, precip: 20),
      _WxHour(label: '21:00', code: 0, isDay: false, temp: 18, precip: 0),
      _WxHour(label: '22:00', code: 0, isDay: false, temp: 17, precip: 0),
    ],
  );
}
