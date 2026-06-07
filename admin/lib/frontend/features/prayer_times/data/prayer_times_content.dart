import 'package:flutter/widgets.dart';

/// Tek bir namaz vakti (ad + "HH:mm").
@immutable
class PrayerTime {
  const PrayerTime(this.name, this.time);

  final String name;
  final String time;

  int get hour => int.parse(time.split(':')[0]);
  int get minute => int.parse(time.split(':')[1]);
}

/// Niğde için örnek günlük vakitler. Geri sayım cihaz saatine göre canlı
/// hesaplanır; vakitlerin kendisi şimdilik sabittir (gerçek Diyanet API'sine
/// bağlanmaya hazır yapıdadır). Şehir/ülke seçimi bilinçli olarak yoktur.
const prayerTimesMock = <PrayerTime>[
  PrayerTime('İmsak', '03:38'),
  PrayerTime('Güneş', '05:21'),
  PrayerTime('Öğle', '12:58'),
  PrayerTime('İkindi', '16:54'),
  PrayerTime('Akşam', '20:22'),
  PrayerTime('Yatsı', '21:58'),
];

const prayerCity = 'Niğde';
const prayerGregorianDate = '5 Haziran 2026';
const prayerHijriDate = '19 Zilhicce 1447';
const prayerQiblaAngle = '147°';

/// Günün hadisi — en bilinen, kaynağı net rivayet.
const prayerHadith =
    'Ameller ancak niyetlere göredir; herkese niyet ettiği şey vardır.';
const prayerHadithSource = 'Buhârî · Müslim';
