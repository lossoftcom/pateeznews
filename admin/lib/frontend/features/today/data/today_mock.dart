import 'package:flutter/widgets.dart';

/// Tek bir namaz vakti.
@immutable
class PrayerTime {
  const PrayerTime(this.name, this.time);
  final String name;
  final String time;
}

/// "Niğde'de Bugün" için örnek günlük veri. Hava / nöbetçi eczane / etkinlik
/// bilgileri mevcut mock'lardan (WeatherMock, PharmacyMock, EtkinlikMock)
/// okunur; burada yalnızca tarih ve namaz vakitleri tutulur. Backend bağlanınca
/// günün gerçek verisiyle değişir.
class TodayMock {
  const TodayMock._();

  static const weekday = 'Perşembe';
  static const dateLabel = '4 Haziran 2026';
  static const greeting = 'Niğde\'de bugün öne çıkanlar';

  static const prayerTimes = <PrayerTime>[
    PrayerTime('İmsak', '03:18'),
    PrayerTime('Güneş', '05:18'),
    PrayerTime('Öğle', '12:52'),
    PrayerTime('İkindi', '16:45'),
    PrayerTime('Akşam', '20:08'),
    PrayerTime('Yatsı', '22:00'),
  ];

  /// Sıradaki namaz (şu an akşam üzeri → Akşam).
  static const nextPrayerIndex = 4;

  static PrayerTime get nextPrayer => prayerTimes[nextPrayerIndex];
}
