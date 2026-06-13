import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pateeznews_admin/frontend/core/mock/home_mock_data.dart';
import 'package:pateeznews_admin/frontend/features/announcements/data/announcement_content.dart';
import 'package:pateeznews_admin/frontend/features/announcements/data/announcements_repository.dart';
import 'package:pateeznews_admin/frontend/features/announcements/presentation/announcements_screen.dart';
import 'package:pateeznews_admin/frontend/features/etkinlik/data/etkinlik_mock.dart';
import 'package:pateeznews_admin/frontend/features/etkinlik/presentation/etkinlik_screen.dart';
import 'package:pateeznews_admin/frontend/features/home/data/post_action_repository.dart';
import 'package:pateeznews_admin/frontend/features/markets/presentation/markets_screen.dart';
import 'package:pateeznews_admin/frontend/features/markets/data/markets_repository.dart';
import 'package:pateeznews_admin/frontend/features/obituaries/data/death_notice_repository.dart';
import 'package:pateeznews_admin/frontend/features/obituaries/presentation/obituaries_screen.dart';
import 'package:pateeznews_admin/frontend/features/pharmacy/data/pharmacy_repository.dart';
import 'package:pateeznews_admin/frontend/features/pharmacy/presentation/pharmacy_screen.dart';
import 'package:pateeznews_admin/frontend/features/prayer_times/data/prayer_times_repository.dart';
import 'package:pateeznews_admin/frontend/features/prayer_times/presentation/prayer_times_screen.dart';
import 'package:pateeznews_admin/frontend/features/weather/data/weather_repository.dart';
import 'package:pateeznews_admin/frontend/features/weather/presentation/weather_screen.dart';

void main() {
  testWidgets('Duyurular sayfası veri yoksa boş durumu gösterir', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: AnnouncementsScreen()));
    await tester.pump();

    expect(find.text('Duyurular'), findsOneWidget);
    expect(find.text('Veri yüklenemedi'), findsOneWidget);
    expect(find.text('Duyuru Merkezi'), findsNothing);
    expect(find.text('Niğde Valiliği'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Duyurular sayfası splash verisini gösterir', (tester) async {
    tester.view.physicalSize = const Size(393, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: AnnouncementsScreen(initialData: _announcementFixture),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Duyurular'), findsOneWidget);
    expect(find.text('Duyuru Merkezi'), findsOneWidget);
    expect(find.text('Valilik · belediye · kurum'), findsOneWidget);
    expect(find.text('Niğde İl Tarım ve Orman Müdürlüğü'), findsWidgets);
    expect(
      find.text(
        'Kırsal Kalkınma Yatırım Programı ve Tasarruflu Tarımsal Sulama Sistemleri Hibe Destek Başvuruları Başladı!',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Başvuruların'), findsOneWidget);
    expect(find.textContaining('Görme Engelli'), findsNothing);
    expect(find.textContaining('Ana Sayfa'), findsNothing);
    expect(find.textContaining('Başlangıç: 29.04.2026'), findsOneWidget);
    expect(find.textContaining('Bitiş: 12.06.2026 23:59'), findsOneWidget);
    expect(find.text('Başvuru / detay linki'), findsOneWidget);
    expect(find.text('Kapsam: Niğde geneli'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Hava Durumu sayfası Niğde verisini ve bölümleri gösterir', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 1700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(home: WeatherScreen(initialData: _weatherFixture)),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Hava Durumu'), findsOneWidget);
    expect(find.text('NİĞDE'), findsOneWidget);
    expect(find.text('19°'), findsWidgets);
    expect(find.text('Açık'), findsWidgets);
    expect(find.text('Saatlik tahmin'), findsOneWidget);
    expect(find.text('7 günlük tahmin'), findsOneWidget);
    expect(find.text('Detaylar'), findsOneWidget);
    expect(find.text('Nem'), findsWidgets);
    expect(find.text('%55'), findsWidgets);
    expect(find.text('14:00'), findsOneWidget);
    expect(find.text('Open-Meteo'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Nöbetçi Eczane sayfası eczaneleri ve aksiyonları gösterir', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 1500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: PharmacyScreen(initialData: _dutyPharmacyFixture),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nöbetçi Eczane'), findsWidgets);
    expect(find.text('Deva Eczanesi'), findsOneWidget);
    expect(find.text('Merkez'), findsWidgets);
    expect(find.text('Kivanç Eczanesi'), findsNothing);
    expect(find.text('Ara'), findsWidgets);
    expect(find.text('Yol Tarifi'), findsWidgets);

    await tester.tap(find.text('Yol Tarifi'));
    await tester.pumpAndSettle();

    expect(find.text('DEVA ECZANESİ için harita açılsın mı?'), findsOneWidget);
    expect(
      find.text('Yol tarifi harita uygulamasında açılacak.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bor'));
    await tester.pumpAndSettle();

    expect(find.text('Kivanç Eczanesi'), findsOneWidget);
    expect(find.text('Deva Eczanesi'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Namaz Vakitleri sayfası canlı vakitleri ve ayeti gösterir', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 1500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: PrayerTimesScreen(initialData: _prayerTimesFixture),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Namaz Vakitleri'), findsWidgets);
    expect(find.text('Niğde'), findsOneWidget);
    expect(find.text('Bugünün Vakitleri'), findsOneWidget);
    expect(find.text('İmsak'), findsOneWidget);
    expect(find.text('03:38'), findsOneWidget);
    expect(find.text('Kıble ve Güneş'), findsOneWidget);
    expect(find.text('19 Zilhicce'), findsOneWidget);
    expect(find.text('1447 Hicri'), findsOneWidget);
    expect(find.text('Günün Ayeti'), findsOneWidget);
    expect(find.textContaining('Rahmân'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Ölüm İlanları sayfası ilanları ve cenaze programını gösterir', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 1700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: ObituariesScreen(initialData: _deathNoticeFixture),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ölüm İlanları'), findsWidgets);
    expect(find.text('ÖLÜM İLANLARI'), findsOneWidget);
    expect(find.text('Niğde · 5 Haziran 2026'), findsOneWidget);
    expect(find.text('FATMA ŞAHİNER'), findsOneWidget);
    expect(find.text('CUMA · DERBENT'), findsOneWidget);
    expect(find.text('Taziye Mesajı Yaz'), findsWidgets);

    await tester.tap(find.text('Taziye Mesajı Yaz').first);
    await tester.pumpAndSettle();

    expect(find.text('Adınız'), findsOneWidget);
    expect(find.text('E-posta'), findsOneWidget);
    expect(find.text('Taziye mesajınızı yazın...'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Döviz & Altın sayfası segment ve kurları gösterir', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(home: MarketsScreen(initialData: _marketsFixture)),
    );
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Döviz & Altın'), findsOneWidget);
    expect(find.text('Döviz'), findsOneWidget);
    expect(find.text('Altın'), findsOneWidget);
    expect(find.text('Alış'), findsOneWidget);
    expect(find.text('Satış'), findsOneWidget);
    expect(find.text('GenelPara'), findsNothing);
    expect(find.text('USD'), findsOneWidget);
    expect(find.text('EUR'), findsOneWidget);
    expect(find.text('₺46,0857'), findsOneWidget);
    expect(find.text('+0,03%'), findsWidgets);
    expect(find.text('BTC'), findsOneWidget);
    expect(find.text(r'USD $60.450,00'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('USD')).dy <
          tester.getTopLeft(find.text('EUR')).dy,
      isTrue,
    );
    expect(
      tester.getTopLeft(find.text('EUR')).dy <
          tester.getTopLeft(find.text('BTC')).dy,
      isTrue,
    );

    await tester.tap(find.text('Altın'));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Gram Altın'), findsOneWidget);
    expect(find.text('Has Altın'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('Etkinlik sayfası canlı veri yoksa boş durumu gösterir', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 1500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: EtkinlikScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Etkinlik'), findsOneWidget);
    expect(find.text('Veri yüklenemedi'), findsOneWidget);
    expect(find.text('Niğde Bağ Bozumu Festivali'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Etkinlik kartı article varsa haber detayına açılır', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 1500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final actions = _EventPostActionRepository();
    final eventDate = DateTime.now().add(const Duration(days: 1));

    await tester.pumpWidget(
      MaterialApp(
        home: EtkinlikScreen(
          events: [
            EtkinlikEvent(
              date: eventDate,
              category: EtkinlikCategory.konser,
              title: 'Karttaki Etkinlik',
              venue: 'Niğde Kültür Merkezi',
              time: '20:00',
              free: true,
              summary: 'Etkinlik kart özeti.',
              article: NewsArticle(
                id: '123',
                author: const NewsAuthor(
                  id: 'publisher-1',
                  name: 'Pateez Niğde',
                  avatarUrl: '',
                  isOfficial: true,
                ),
                region: 'Niğde',
                category: 'Etkinlik',
                title: 'Detay Haber Başlığı',
                summary: 'Etkinlik detay özeti.',
                imageUrl: '',
                publishedAt: DateTime.utc(2026, 6, 12, 10),
                readMinutes: 2,
                likes: 4,
                dislikes: 1,
                comments: 3,
                shares: 2,
                views: 9,
                saves: 1,
              ),
            ),
          ],
          postActionRepository: actions,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Karttaki Etkinlik'));
    await tester.pumpAndSettle();

    expect(find.text('Detay Haber Başlığı'), findsWidgets);
    expect(find.text('Yorumunuzu ekleyin'), findsOneWidget);
    expect(actions.recordCalls, 1);
    expect(actions.recordedSource, 'open_detail');
    expect(tester.takeException(), isNull);
  });
}

class _EventPostActionRepository extends PostActionRepository {
  int recordCalls = 0;
  String? recordedSource;

  @override
  Future<PostActionState> recordView({
    required String postId,
    String? token,
    String source = 'read',
  }) {
    recordCalls++;
    recordedSource = source;
    return Future<PostActionState>.value(
      const PostActionState(
        likes: 4,
        dislikes: 1,
        shares: 2,
        views: 10,
        saves: 1,
        liked: false,
        disliked: false,
        saved: false,
      ),
    );
  }
}

const _announcementFixture = AnnouncementData(
  city: 'Niğde',
  serviceDateLabel: '6 Haziran 2026 Cumartesi',
  updateIntervalMinutes: 30,
  announcements: [
    AnnouncementItem(
      category: AnnouncementCategory.official,
      source: 'Niğde İl Tarım ve Orman Müdürlüğü',
      title:
          'Kırsal Kalkınma Yatırım Programı ve Tasarruflu Tarımsal Sulama Sistemleri Hibe Destek Başvuruları Başladı!',
      summary: '',
      body:
          'T.C. TARIM VE ORMAN BAKANLIĞI NİĞDE İL TARIM VE ORMAN MÜDÜRLÜĞÜ Görme Engelli * Ana Sayfa KURUMSAL YAPI İl Müdürü Şube Müdürlükleri Alt Yapı ve Arazi Değerlendirme Şube Müdürlüğü Başvuruların; Başlama tarihi 29 Nisan 2026 Sona erme tarihi 12 Haziran 2026 saat 23:59\'dur. Başvuru yapmak için tıklayınız.',
      place: 'Merkez · Altunhisar · Bor · Çamardı',
      timeLabel: '30 Nisan',
      statusLabel: 'Başvuru',
      sourceUrl: 'https://nigde.tarimorman.gov.tr/duyuru/827',
      publishedAt: '2026-04-30T10:30:00',
      startsAt: '2026-04-29T00:00:00',
      endsAt: '2026-06-12T23:59:00',
    ),
  ],
  total: 1,
  fetchedAt: '2026-06-06T10:30:00.000Z',
  errorMessage: '',
);

const _dutyPharmacyFixture = DutyPharmacyData(
  city: 'Niğde',
  source: 'Niğde Eczacı Odası',
  sourceUrl: 'https://www.neo.org.tr/nobetci-eczaneler',
  serviceDateLabel: '5 Haziran 2026',
  updateIntervalMinutes: 15,
  districts: ['MERKEZ', 'BOR'],
  pharmacies: [
    DutyPharmacyItem(
      id: 'deva',
      name: 'DEVA ECZANESİ',
      district: 'MERKEZ',
      address: 'Selçuk Mah. Ethem Onbaşı Cad. Niğde',
      phone: '0388 213 53 04',
      phoneHref: '03882135304',
      mapUrl: 'https://www.google.com/maps',
      directionUrl: 'https://www.google.com/maps/dir/?api=1',
      note: '!! GECE 00:00’A KADAR NÖBETÇİDİR !!',
      isUntilMidnight: true,
    ),
    DutyPharmacyItem(
      id: 'kivanc',
      name: 'KIVANÇ ECZANESİ',
      district: 'BOR',
      address: 'Mehmetçik Mah. Doğan Varan Cad. No: 72/A',
      phone: '0388 311 22 33',
      phoneHref: '03883112233',
      mapUrl: 'https://www.google.com/maps',
      directionUrl: 'https://www.google.com/maps/dir/?api=1',
      note: '',
      isUntilMidnight: false,
    ),
  ],
  total: 2,
  fetchedAt: '2026-06-05T13:35:00.000Z',
  errorMessage: '',
);

const _deathNoticeFixture = DeathNoticeData(
  city: 'Niğde',
  source: 'Niğde Belediyesi',
  sourceUrl: 'https://nigde.bel.tr/vefat-edenler',
  serviceDateLabel: '5 Haziran 2026',
  updateIntervalMinutes: 30,
  notices: [
    DeathNoticeItem(
      id: '2026-06-05-fatma-sahiner-derbent',
      name: 'FATMA ŞAHİNER',
      deathDateLabel: '05 Haziran 2026',
      prayerTime: 'cuma',
      burialPlace: 'derbent',
      description:
          'Dışarı Camii Emekli İmam Hatibi Hikmet Şahiner’in Eşi FATMA ŞAHİNER Vefat Etmiştir.',
    ),
  ],
  total: 1,
  fetchedAt: '2026-06-05T16:41:00.000Z',
  errorMessage: '',
);

const _prayerTimesFixture = PrayerTimesData(
  enabled: true,
  source: 'Diyanet Namaz Vakitleri',
  location: 'Niğde',
  country: 'Türkiye',
  timezone: 'Europe/Istanbul',
  serviceDateLabel: '5 Haziran 2026',
  fetchedAt: '2026-06-05T19:30:00.000Z',
  refreshLeadDays: 3,
  cacheDays: 370,
  today: PrayerDay(
    date: '2026-06-05',
    gregorianDateLabel: '5 Haziran 2026',
    hijriDateLabel: '19 Zilhicce 1447',
    qiblaAngle: '147°',
    times: [
      PrayerTime(key: 'imsak', name: 'İmsak', time: '03:38'),
      PrayerTime(key: 'gunes', name: 'Güneş', time: '05:21'),
      PrayerTime(key: 'ogle', name: 'Öğle', time: '12:58'),
      PrayerTime(key: 'ikindi', name: 'İkindi', time: '16:54'),
      PrayerTime(key: 'aksam', name: 'Akşam', time: '20:22'),
      PrayerTime(key: 'yatsi', name: 'Yatsı', time: '21:58'),
    ],
  ),
  days: [],
  dailyAyah: DailyAyah(
    surahId: 1,
    surahName: 'Fâtiha',
    verseNumber: 1,
    arabicText: '',
    translation: 'Rahmân ve Rahîm olan Allah’ın adıyla.',
    source: 'Diyanet Kur’an API',
  ),
  errorMessage: '',
);

const _weatherFixture = WeatherData(
  location: 'Niğde',
  country: 'Türkiye',
  latitude: 37.96583,
  longitude: 34.67935,
  timezone: 'Europe/Istanbul',
  source: 'Open-Meteo',
  serviceDateLabel: '5 Haziran 2026 Cuma',
  fetchedAt: '2026-06-05T16:57:33.939Z',
  updateIntervalMinutes: 30,
  current: WeatherCurrent(
    temperature: 19,
    apparentTemperature: 14,
    humidity: 48,
    weatherCode: 0,
    isDay: true,
    precipitation: 0,
    rain: 0,
    showers: 0,
    snowfall: 0,
    cloudCover: 8,
    pressure: 1014,
    surfacePressure: 914,
    windSpeed: 11,
    windDirection: 280,
    windGusts: 19,
    time: '2026-06-05T19:00',
  ),
  hourly: [
    WeatherHour(
      time: '2026-06-05T19:00',
      label: 'Şimdi',
      temperature: 19,
      apparentTemperature: 14,
      humidity: 48,
      weatherCode: 0,
      isDay: true,
      precipitationProbability: 55,
      precipitation: 0,
      windSpeed: 11,
    ),
    WeatherHour(
      time: '2026-06-05T20:00',
      label: '20:00',
      temperature: 18,
      apparentTemperature: 13,
      humidity: 52,
      weatherCode: 2,
      isDay: false,
      precipitationProbability: 0,
      precipitation: 0,
      windSpeed: 9,
    ),
  ],
  daily: [
    WeatherDay(
      date: '2026-06-05',
      label: 'Bugün',
      weatherCode: 0,
      max: 29,
      min: 14,
      apparentMax: 27,
      apparentMin: 12,
      precipitationSum: 0,
      precipitationProbability: 55,
      precipitationHourLabel: '14:00',
      windSpeedMax: 18,
      sunrise: '2026-06-05T05:18',
      sunset: '2026-06-05T20:08',
      uvIndex: 7,
    ),
    WeatherDay(
      date: '2026-06-06',
      label: 'Yarın',
      weatherCode: 2,
      max: 30,
      min: 15,
      apparentMax: 28,
      apparentMin: 13,
      precipitationSum: 0,
      precipitationProbability: 10,
      windSpeedMax: 14,
      sunrise: '2026-06-06T05:18',
      sunset: '2026-06-06T20:09',
      uvIndex: 7.2,
    ),
  ],
  errorMessage: '',
);

const _marketsFixture = MarketsData(
  enabled: true,
  provider: 'genelpara',
  source: 'GenelPara',
  serviceDateLabel: '5 Haziran 2026 Cuma',
  fetchedAt: '2026-06-05T17:15:00.000Z',
  updateIntervalSeconds: 300,
  currencies: [
    MarketRate(
      id: 'currency:USD',
      symbol: 'USD',
      name: 'Amerikan Doları',
      bid: 46.0704,
      ask: 46.0857,
      changeAmount: 0.07,
      changePercent: 0.0323,
      up: true,
      currencyCode: 'TRY',
      currencySymbol: '₺',
      timestamp: '2026-06-05T17:15:00.000Z',
    ),
    MarketRate(
      id: 'currency:EUR',
      symbol: 'EUR',
      name: 'Euro',
      bid: 53.1307,
      ask: 53.1584,
      changeAmount: -0.4997,
      changePercent: -0.94,
      up: false,
      currencyCode: 'TRY',
      currencySymbol: '₺',
      timestamp: '2026-06-05T17:15:00.000Z',
    ),
    MarketRate(
      id: 'currency:BTC',
      symbol: 'BTC',
      name: 'Bitcoin',
      bid: 2781573,
      ask: 2781573,
      changeAmount: null,
      changePercent: -4.62,
      up: false,
      currencyCode: 'TRY',
      currencySymbol: '₺',
      secondaryBid: 60400,
      secondaryAsk: 60450,
      secondaryCurrencyCode: 'USD',
      secondaryCurrencySymbol: r'$',
      timestamp: '2026-06-05T17:15:00.000Z',
    ),
  ],
  gold: [
    MarketRate(
      id: 'gold:HAS',
      symbol: 'Has Altın',
      name: 'TL / gram',
      bid: 6388.75,
      ask: 6389.63,
      changeAmount: -187.22,
      changePercent: -2.93,
      up: false,
      currencyCode: 'TRY',
      currencySymbol: '₺',
      timestamp: '2026-06-05T17:15:00.000Z',
    ),
    MarketRate(
      id: 'gold:GRAM',
      symbol: 'Gram Altın',
      name: 'TL / gram',
      bid: 6426.10,
      ask: 6427.05,
      changeAmount: -2.85,
      changePercent: -0.44,
      up: false,
      currencyCode: 'TRY',
      currencySymbol: '₺',
      timestamp: '2026-06-05T17:15:00.000Z',
    ),
  ],
  errorMessage: '',
);
