import 'package:flutter/widgets.dart';

/// Bir şehir etkinliği (Niğde örnek verisi).
@immutable
class EtkinlikEvent {
  const EtkinlikEvent({
    required this.day,
    required this.month,
    required this.weekday,
    required this.category,
    required this.title,
    required this.venue,
    required this.time,
    required this.free,
  });

  final String day;
  final String month;
  final String weekday;
  final String category;
  final String title;
  final String venue;
  final String time;
  final bool free;
}

/// Niğde etkinlik programı (Haziran 2026). Backend bağlanınca gerçek programla
/// değişir; sunum katmanı bu modele bağlı kalır.
class EtkinlikMock {
  const EtkinlikMock._();

  static const cityLabel = 'Niğde · Haziran 2026';

  static const categories = <String>[
    'Tümü',
    'Festival',
    'Konser',
    'Tiyatro',
    'Spor',
    'Sergi',
  ];

  static const all = <EtkinlikEvent>[
    EtkinlikEvent(
      day: '12',
      month: 'HAZ',
      weekday: 'Cuma',
      category: 'Festival',
      title: 'Niğde Bağ Bozumu Festivali',
      venue: 'Cumhuriyet Meydanı',
      time: '18:00',
      free: true,
    ),
    EtkinlikEvent(
      day: '14',
      month: 'HAZ',
      weekday: 'Pazar',
      category: 'Konser',
      title: 'Niğde Senfoni Orkestrası · Yaz Konseri',
      venue: 'Kültür Merkezi',
      time: '20:00',
      free: false,
    ),
    EtkinlikEvent(
      day: '15',
      month: 'HAZ',
      weekday: 'Pazartesi',
      category: 'Tiyatro',
      title: 'Keşanlı Ali Destanı',
      venue: 'Sungurbey Sahnesi',
      time: '20:30',
      free: false,
    ),
    EtkinlikEvent(
      day: '16',
      month: 'HAZ',
      weekday: 'Salı',
      category: 'Spor',
      title: 'Niğde Belediyespor – Hazırlık Maçı',
      venue: 'Niğde Şehir Stadyumu',
      time: '19:00',
      free: false,
    ),
    EtkinlikEvent(
      day: '18',
      month: 'HAZ',
      weekday: 'Perşembe',
      category: 'Sergi',
      title: 'Anadolu Renkleri Resim Sergisi',
      venue: 'Şehir Sanat Galerisi',
      time: '10:00',
      free: true,
    ),
    EtkinlikEvent(
      day: '20',
      month: 'HAZ',
      weekday: 'Cumartesi',
      category: 'Konser',
      title: 'Gençlik Halk Müziği Korosu',
      venue: 'Açık Hava Tiyatrosu',
      time: '21:00',
      free: true,
    ),
  ];
}
