import 'package:flutter/widgets.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../core/theme/app_colors.dart';

/// Hava durumu tipi — ikon ve vurgu tonunu da taşır.
enum WeatherKind {
  clearDay,
  clearNight,
  partlyDay,
  partlyNight,
  cloudy,
  rain,
  drizzle,
}

extension WeatherKindX on WeatherKind {
  IconData get icon => switch (this) {
    WeatherKind.clearDay => Symbols.sun_fill,
    WeatherKind.clearNight => Symbols.moon_clear_fill,
    WeatherKind.partlyDay => Symbols.sun_cloudy_fill,
    WeatherKind.partlyNight => Symbols.moon_cloudy_fill,
    WeatherKind.cloudy => Symbols.cloudy_fill,
    WeatherKind.rain => Symbols.rainy_fill,
    WeatherKind.drizzle => Symbols.drizzle_fill,
  };

  Color get tint => switch (this) {
    WeatherKind.clearDay || WeatherKind.partlyDay => AppColors.warmHorizon,
    WeatherKind.rain || WeatherKind.drizzle => AppColors.deepOcean,
    WeatherKind.clearNight || WeatherKind.partlyNight => AppColors.deepOcean,
    WeatherKind.cloudy => AppColors.support,
  };
}

@immutable
class HourForecast {
  const HourForecast(this.label, this.kind, this.temp);
  final String label;
  final WeatherKind kind;
  final int temp;
}

@immutable
class DayForecast {
  const DayForecast(this.day, this.kind, this.summary, this.hi, this.lo);
  final String day;
  final WeatherKind kind;
  final String summary;
  final int hi;
  final int lo;
}

@immutable
class WeatherDetail {
  const WeatherDetail(this.icon, this.label, this.value, this.note);
  final IconData icon;
  final String label;
  final String value;
  final String note;
}

/// Niğde için örnek hava durumu verisi (Haziran). Backend bağlanınca repository
/// ile değişir; sunum katmanı bu modele bağlı kalır.
class WeatherMock {
  const WeatherMock._();

  static const city = 'Niğde';
  static const district = 'Merkez';
  static const dateLabel = '3 Haziran 2026, Çarşamba';
  static const condition = 'Parçalı Bulutlu';
  static const currentKind = WeatherKind.partlyDay;
  static const currentTemp = 26;
  static const feelsLike = 27;
  static const hi = 29;
  static const lo = 14;

  static const hours = <HourForecast>[
    HourForecast('Şimdi', WeatherKind.partlyDay, 26),
    HourForecast('16:00', WeatherKind.partlyDay, 27),
    HourForecast('17:00', WeatherKind.clearDay, 27),
    HourForecast('18:00', WeatherKind.clearDay, 25),
    HourForecast('19:00', WeatherKind.clearDay, 22),
    HourForecast('20:00', WeatherKind.clearNight, 19),
    HourForecast('21:00', WeatherKind.clearNight, 17),
    HourForecast('22:00', WeatherKind.clearNight, 16),
    HourForecast('23:00', WeatherKind.partlyNight, 15),
  ];

  static const days = <DayForecast>[
    DayForecast('Bugün', WeatherKind.partlyDay, 'Parçalı bulutlu', 29, 14),
    DayForecast('Yarın', WeatherKind.clearDay, 'Güneşli', 30, 15),
    DayForecast('Cum', WeatherKind.clearDay, 'Güneşli', 31, 16),
    DayForecast('Cmt', WeatherKind.partlyDay, 'Parçalı bulutlu', 28, 15),
    DayForecast('Paz', WeatherKind.rain, 'Sağanak yağışlı', 24, 13),
    DayForecast('Pzt', WeatherKind.drizzle, 'Hafif yağmurlu', 23, 12),
    DayForecast('Sal', WeatherKind.partlyDay, 'Parçalı bulutlu', 26, 13),
  ];

  static const details = <WeatherDetail>[
    WeatherDetail(Symbols.temp_hot_fill, 'Hissedilen', '27°', 'Gerçeğe yakın'),
    WeatherDetail(Symbols.water_percent_fill, 'Nem', '%38', 'Konforlu'),
    WeatherDetail(Symbols.windy_fill, 'Rüzgar', '12 km/s', 'Kuzeybatı'),
    WeatherDetail(Symbols.sun_fill, 'UV İndeksi', '7', 'Yüksek'),
    WeatherDetail(Symbols.eye_fill, 'Görüş', '16 km', 'Açık'),
    WeatherDetail(Symbols.compass_fill, 'Basınç', '1014 hPa', 'Sabit'),
    WeatherDetail(Symbols.sun_cloudy_fill, 'Gün doğumu', '05:18', 'Şafak'),
    WeatherDetail(Symbols.moon_clear_fill, 'Gün batımı', '20:08', 'Akşam'),
  ];

  /// 7 günlük min/max — sıcaklık çubuğu ölçeği için.
  static int get weekMin =>
      days.map((d) => d.lo).reduce((a, b) => a < b ? a : b);
  static int get weekMax =>
      days.map((d) => d.hi).reduce((a, b) => a > b ? a : b);
}
