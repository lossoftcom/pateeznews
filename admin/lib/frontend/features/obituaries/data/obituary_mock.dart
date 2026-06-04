import 'package:flutter/widgets.dart';

/// Vefat ilanı kaydı (Niğde örnek verisi).
@immutable
class Obituary {
  const Obituary({
    required this.name,
    required this.years,
    required this.age,
    required this.neighborhood,
    required this.funeralDay,
    required this.prayer,
    required this.mosque,
    required this.cemetery,
    required this.relativeLabel,
  });

  final String name;
  final String years; // "1948 – 2026"
  final int age;
  final String neighborhood;
  final String funeralDay; // "4 Haziran Perşembe"
  final String prayer; // "Öğle namazını müteakip"
  final String mosque;
  final String cemetery;
  final String relativeLabel; // "Bugün" / "Dün"
}

/// Niğde için örnek vefat ilanları. Backend bağlanınca gerçek ilanlarla değişir.
class ObituaryMock {
  const ObituaryMock._();

  static const headerNote =
      'Vefat edenlerimizi saygı ve rahmetle anıyoruz. Ailelerine başsağlığı dileriz.';

  static const all = <Obituary>[
    Obituary(
      name: 'Mehmet Yıldız',
      years: '1948 – 2026',
      age: 78,
      neighborhood: 'Efendibey Mah., Niğde',
      funeralDay: '4 Haziran Perşembe',
      prayer: 'Öğle namazını müteakip',
      mosque: 'Dışarı Camii',
      cemetery: 'Asri Mezarlık',
      relativeLabel: 'Bugün',
    ),
    Obituary(
      name: 'Ayşe Demir',
      years: '1955 – 2026',
      age: 71,
      neighborhood: 'Saruhan Mah., Niğde',
      funeralDay: '3 Haziran Çarşamba',
      prayer: 'İkindi namazını müteakip',
      mosque: 'Sungurbey Camii',
      cemetery: 'Nalbantlı Mezarlığı',
      relativeLabel: 'Bugün',
    ),
    Obituary(
      name: 'Hasan Kaya',
      years: '1939 – 2026',
      age: 87,
      neighborhood: 'Yenice Mah., Niğde',
      funeralDay: '2 Haziran Salı',
      prayer: 'Öğle namazını müteakip',
      mosque: 'Hıdırlık Camii',
      cemetery: 'Asri Mezarlık',
      relativeLabel: 'Dün',
    ),
  ];
}
