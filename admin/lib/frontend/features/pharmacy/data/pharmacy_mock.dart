import 'package:flutter/widgets.dart';

/// Nöbetçi eczane kaydı (Niğde örnek verisi).
@immutable
class Pharmacy {
  const Pharmacy({
    required this.name,
    required this.address,
    required this.phone,
    required this.hours,
    required this.distance,
    this.open24 = false,
  });

  final String name;
  final String address;
  final String phone;
  final String hours;
  final String distance;
  final bool open24;
}

/// Niğde Merkez için örnek nöbetçi eczane listesi. Backend bağlanınca günün
/// gerçek nöbet listesiyle değişir.
class PharmacyMock {
  const PharmacyMock._();

  static const city = 'Niğde';
  static const district = 'Merkez';
  static const dateLabel = '3 Haziran 2026, Çarşamba';

  static const all = <Pharmacy>[
    Pharmacy(
      name: 'Yeni Eczane',
      address: 'Bor Caddesi No:42, Efendibey Mah.',
      phone: '0388 213 24 18',
      hours: '18:30 – 08:30 (ertesi gün)',
      distance: '1,2 km',
    ),
    Pharmacy(
      name: 'Sağlık Eczanesi',
      address: 'İstasyon Caddesi No:7, Saruhan Mah.',
      phone: '0388 232 11 06',
      hours: '24 saat açık',
      distance: '0,8 km',
      open24: true,
    ),
    Pharmacy(
      name: 'Hayat Eczanesi',
      address: 'Atatürk Bulvarı No:115, Yenice Mah.',
      phone: '0388 233 47 90',
      hours: '18:30 – 08:30 (ertesi gün)',
      distance: '2,4 km',
    ),
  ];
}
