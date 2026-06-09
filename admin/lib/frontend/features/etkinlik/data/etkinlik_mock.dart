import 'package:flutter/widgets.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

/// Etkinlik kategorileri. Her kategori bir renk + ikon ile temsil edilir; böylece
/// az okuyan / zor anlayan kullanıcı bile bakar bakmaz türünü tanır (yeşil + top
/// = spor, mor + mikrofon = konser ...). Backend bağlanınca aynı modele yazılır.
enum EtkinlikCategory { festival, konser, tiyatro, spor, sergi, soylesi, cocuk }

extension EtkinlikCategoryInfo on EtkinlikCategory {
  static EtkinlikCategory fromApi(Object? value) {
    final category = value?.toString().trim().toLowerCase();
    return switch (category) {
      'konser' => EtkinlikCategory.konser,
      'tiyatro' => EtkinlikCategory.tiyatro,
      'spor' => EtkinlikCategory.spor,
      'sergi' => EtkinlikCategory.sergi,
      'soylesi' || 'söyleşi' => EtkinlikCategory.soylesi,
      'cocuk' || 'çocuk' => EtkinlikCategory.cocuk,
      _ => EtkinlikCategory.festival,
    };
  }

  /// Filtre çipinde görünen kısa etiket.
  String get label => switch (this) {
    EtkinlikCategory.festival => 'Festival',
    EtkinlikCategory.konser => 'Konser',
    EtkinlikCategory.tiyatro => 'Tiyatro',
    EtkinlikCategory.spor => 'Spor',
    EtkinlikCategory.sergi => 'Sergi',
    EtkinlikCategory.soylesi => 'Söyleşi',
    EtkinlikCategory.cocuk => 'Çocuk',
  };

  /// Kart/afiş üzerindeki uzun etiket.
  String get longLabel => switch (this) {
    EtkinlikCategory.festival => 'Festival',
    EtkinlikCategory.konser => 'Konser',
    EtkinlikCategory.tiyatro => 'Tiyatro Oyunu',
    EtkinlikCategory.spor => 'Spor Etkinliği',
    EtkinlikCategory.sergi => 'Sergi',
    EtkinlikCategory.soylesi => 'Söyleşi',
    EtkinlikCategory.cocuk => 'Çocuk Etkinliği',
  };

  /// Kategoriyi temsil eden accent rengi (sol şerit, rozet, tarih kutusu, afiş).
  Color get color => switch (this) {
    EtkinlikCategory.festival => const Color(0xFFE84393),
    EtkinlikCategory.konser => const Color(0xFF6C5CE7),
    EtkinlikCategory.tiyatro => const Color(0xFFD9822B),
    EtkinlikCategory.spor => const Color(0xFF1FA971),
    EtkinlikCategory.sergi => const Color(0xFF2F80ED),
    EtkinlikCategory.soylesi => const Color(0xFF12A18C),
    EtkinlikCategory.cocuk => const Color(0xFFEB5757),
  };

  IconData get icon => switch (this) {
    EtkinlikCategory.festival => Symbols.sparkling_fill,
    EtkinlikCategory.konser => Symbols.podcasts_rounded,
    EtkinlikCategory.tiyatro => Symbols.theater_comedy_rounded,
    EtkinlikCategory.spor => Symbols.sports_soccer_rounded,
    EtkinlikCategory.sergi => Symbols.image_outlined,
    EtkinlikCategory.soylesi => Symbols.forum_outlined,
    EtkinlikCategory.cocuk => Symbols.group,
  };
}

const _trMonthShort = <String>[
  'OCA',
  'ŞUB',
  'MAR',
  'NİS',
  'MAY',
  'HAZ',
  'TEM',
  'AĞU',
  'EYL',
  'EKİ',
  'KAS',
  'ARA',
];
const _trWeekdayLong = <String>[
  'Pazartesi',
  'Salı',
  'Çarşamba',
  'Perşembe',
  'Cuma',
  'Cumartesi',
  'Pazar',
];
const _trWeekdayShort = <String>['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

/// Bir şehir etkinliği (Niğde örnek verisi).
///
/// [date] etkinliğin gerçek tarih+saatidir; gün/ay/haftagünü etiketleri ondan
/// türetilir. Böylece "kaç gün kaldı", sıralama ve takvim şeridi otomatik çalışır.
@immutable
class EtkinlikEvent {
  const EtkinlikEvent({
    required this.date,
    required this.category,
    required this.title,
    required this.venue,
    required this.time,
    required this.free,
    this.priceLabel = '',
    this.summary = '',
    this.organizer = '',
    this.address = '',
    this.imageUrl = '',
  });

  final DateTime date;
  final EtkinlikCategory category;
  final String title;
  final String venue;
  final String time;
  final bool free;

  /// Ücretliyse gösterilecek fiyat etiketi (örn. "60 ₺"). Boşsa "Biletli".
  final String priceLabel;
  final String summary;
  final String organizer;
  final String address;

  /// Etkinlik afişi/görseli. Boşsa kategori renginde ikon poster gösterilir
  /// (Duyurular kartındaki ile aynı dil). Backend bağlanınca otomatik dolar.
  final String imageUrl;

  // --- today_screen ile uyumluluk için korunan türetilmiş alanlar ---
  String get day => date.day.toString();
  String get month => _trMonthShort[date.month - 1];
  String get weekday => _trWeekdayLong[date.weekday - 1];
  String get weekdayShort => _trWeekdayShort[date.weekday - 1];

  Color get color => category.color;
  IconData get icon => category.icon;
  bool get hasImage => imageUrl.trim().isNotEmpty;
  String get priceText =>
      free ? 'Ücretsiz' : (priceLabel.trim().isEmpty ? 'Biletli' : priceLabel);
}

/// Niğde etkinlik programı (Haziran 2026) — örnek veri. Tarihler "bugünden"
/// itibaren üretilir ki ekran her zaman dolu ve "yaklaşan" görünsün. Backend
/// bağlanınca sunum katmanı aynı modele bağlı kalır.
class EtkinlikMock {
  const EtkinlikMock._();

  static const cityLabel = 'Niğde · Haziran 2026';

  static final DateTime _today = _todayMidnight();

  static DateTime _todayMidnight() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static DateTime _at(int addDays, int hour, int minute) =>
      DateTime(_today.year, _today.month, _today.day + addDays, hour, minute);

  static final List<EtkinlikEvent> all = <EtkinlikEvent>[
    EtkinlikEvent(
      date: _at(0, 18, 0),
      category: EtkinlikCategory.festival,
      title: 'Niğde Yaz Şenliği Açılışı',
      venue: 'Cumhuriyet Meydanı',
      time: '18:00',
      free: true,
      summary:
          'Konser, halk oyunları ve ücretsiz ikramlarla yaz şenliği başlıyor. '
          'Tüm aileyi bekliyoruz.',
      organizer: 'Niğde Belediyesi',
    ),
    EtkinlikEvent(
      date: _at(0, 14, 0),
      category: EtkinlikCategory.cocuk,
      title: 'Çocuk Tiyatrosu: Uçan Balon',
      venue: '100. Yıl Parkı',
      time: '14:00',
      free: true,
      summary: 'Minikler için ücretsiz açık hava gösterisi.',
      organizer: 'Niğde Belediyesi',
    ),
    EtkinlikEvent(
      date: _at(1, 20, 0),
      category: EtkinlikCategory.konser,
      title: 'Türk Halk Müziği Gecesi',
      venue: 'Niğde Kültür Merkezi',
      time: '20:00',
      free: true,
      summary: 'Yöre sanatçılarından türküler ve halk müziği dinletisi.',
      organizer: 'İl Kültür Müdürlüğü',
    ),
    EtkinlikEvent(
      date: _at(2, 19, 0),
      category: EtkinlikCategory.spor,
      title: 'Niğde Belediyespor Hazırlık Maçı',
      venue: 'Niğde Şehir Stadyumu',
      time: '19:00',
      free: false,
      priceLabel: '40 ₺',
      organizer: 'Niğde Belediyespor',
    ),
    EtkinlikEvent(
      date: _at(3, 20, 30),
      category: EtkinlikCategory.tiyatro,
      title: 'Keşanlı Ali Destanı',
      venue: 'Sungurbey Kültür Merkezi',
      time: '20:30',
      free: false,
      priceLabel: '60 ₺',
      organizer: 'Şehir Tiyatrosu',
    ),
    EtkinlikEvent(
      date: _at(4, 10, 0),
      category: EtkinlikCategory.sergi,
      title: 'Anadolu Renkleri Resim Sergisi',
      venue: 'Şehir Sanat Galerisi',
      time: '10:00',
      free: true,
      summary: 'Yerel ressamların eserlerinden oluşan sergi gün boyu açık.',
      organizer: 'Sanat Galerisi',
    ),
    EtkinlikEvent(
      date: _at(5, 17, 0),
      category: EtkinlikCategory.soylesi,
      title: 'Yazarla Buluşma ve Kitap Söyleşisi',
      venue: 'Belediye Konferans Salonu',
      time: '17:00',
      free: true,
      summary: 'Söyleşi sonrası imza ve ikram.',
      organizer: 'Niğde Belediyesi',
    ),
    EtkinlikEvent(
      date: _at(6, 21, 0),
      category: EtkinlikCategory.konser,
      title: 'Gençlik Senfoni Orkestrası · Yaz Konseri',
      venue: 'Açık Hava Tiyatrosu',
      time: '21:00',
      free: false,
      priceLabel: '75 ₺',
      organizer: 'Niğde Belediyesi',
    ),
    EtkinlikEvent(
      date: _at(8, 16, 0),
      category: EtkinlikCategory.festival,
      title: 'Bağ Bozumu Festivali',
      venue: 'Cumhuriyet Meydanı',
      time: '16:00',
      free: true,
      summary: 'Üzüm hasadı şenliği, stantlar ve canlı müzik.',
      organizer: 'Niğde Belediyesi',
    ),
    EtkinlikEvent(
      date: _at(9, 8, 0),
      category: EtkinlikCategory.spor,
      title: 'Niğde Yarı Maratonu',
      venue: '100. Yıl Parkı',
      time: '08:00',
      free: true,
      summary: 'Herkese açık koşu; kayıt parkurda yapılır.',
      organizer: 'Gençlik ve Spor İl Müdürlüğü',
    ),
    EtkinlikEvent(
      date: _at(11, 9, 30),
      category: EtkinlikCategory.sergi,
      title: 'Geleneksel El Sanatları Sergisi',
      venue: 'Niğde Müzesi',
      time: '09:30',
      free: true,
      organizer: 'İl Kültür Müdürlüğü',
    ),
    EtkinlikEvent(
      date: _at(13, 13, 0),
      category: EtkinlikCategory.cocuk,
      title: 'Çocuk Müzikali: Pamuk Prenses',
      venue: 'Niğde Kültür Merkezi',
      time: '13:00',
      free: false,
      priceLabel: '50 ₺',
      organizer: 'Şehir Tiyatrosu',
    ),
  ];
}
