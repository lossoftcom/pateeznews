import 'package:flutter/widgets.dart';

/// Bir piyasa kalemi (döviz veya altın).
@immutable
class MarketRate {
  const MarketRate({
    required this.code,
    required this.name,
    required this.price,
    required this.changePct,
    required this.up,
    required this.spark,
  });

  final String code;
  final String name;
  final String price;
  final String changePct;
  final bool up;
  final List<double> spark;
}

/// Serbest piyasa örnek verisi (Haziran 2026). Backend bağlanınca canlı kurla
/// değişir; sunum katmanı bu modele bağlı kalır.
class MarketsMock {
  const MarketsMock._();

  static const updatedLabel = 'Serbest piyasa · 15:00 itibarıyla';

  static const currencies = <MarketRate>[
    MarketRate(
      code: 'USD',
      name: 'Amerikan Doları',
      price: '48,2040',
      changePct: '+0,12%',
      up: true,
      spark: [3, 3.2, 3.1, 3.4, 3.3, 3.6, 3.8],
    ),
    MarketRate(
      code: 'EUR',
      name: 'Euro',
      price: '53,4500',
      changePct: '+0,06%',
      up: true,
      spark: [4, 4.1, 4.05, 4.2, 4.15, 4.25, 4.3],
    ),
    MarketRate(
      code: 'GBP',
      name: 'İngiliz Sterlini',
      price: '61,8860',
      changePct: '+0,02%',
      up: true,
      spark: [5, 4.9, 5.05, 5.0, 5.1, 5.08, 5.12],
    ),
    MarketRate(
      code: 'CHF',
      name: 'İsviçre Frangı',
      price: '57,3120',
      changePct: '-0,18%',
      up: false,
      spark: [5.2, 5.25, 5.1, 5.15, 5.0, 5.05, 4.95],
    ),
  ];

  static const gold = <MarketRate>[
    MarketRate(
      code: 'Gram Altın',
      name: 'TL / gram',
      price: '6.593,80',
      changePct: '-0,53%',
      up: false,
      spark: [6, 6.2, 6.1, 5.9, 6.0, 5.8, 5.7],
    ),
    MarketRate(
      code: 'Çeyrek Altın',
      name: 'TL / adet',
      price: '10.747,41',
      changePct: '-0,74%',
      up: false,
      spark: [6.4, 6.3, 6.35, 6.1, 6.2, 6.0, 5.9],
    ),
    MarketRate(
      code: 'Yarım Altın',
      name: 'TL / adet',
      price: '21.494,82',
      changePct: '-0,74%',
      up: false,
      spark: [6.4, 6.45, 6.2, 6.3, 6.1, 6.05, 5.95],
    ),
    MarketRate(
      code: 'Tam Altın',
      name: 'Cumhuriyet · TL',
      price: '42.989,00',
      changePct: '-0,70%',
      up: false,
      spark: [6.3, 6.35, 6.2, 6.25, 6.1, 6.0, 5.92],
    ),
    MarketRate(
      code: 'Ons Altın',
      name: 'USD / ons',
      price: '3.380,50',
      changePct: '-0,40%',
      up: false,
      spark: [5.9, 6.0, 5.95, 5.85, 5.9, 5.8, 5.78],
    ),
  ];
}
