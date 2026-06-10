import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/feature_app_bar.dart';
import '../../etkinlik/data/etkinlik_mock.dart';
import '../../etkinlik/presentation/etkinlik_screen.dart';
import '../../pharmacy/data/pharmacy_repository.dart';
import '../../pharmacy/presentation/pharmacy_screen.dart';
import '../../prayer_times/data/prayer_times_repository.dart';
import '../../weather/data/weather_repository.dart';
import '../../weather/presentation/weather_screen.dart';

const Color _eczaneRed = Color(0xFFE30613);
const Color _violet = Color(0xFF6C5CE7);

/// Tüm başlık/değer metinleri projenin DÜZ fontuyla (primaryFamily — nav/etiket
/// fontu) yazılır; serif "başlık fontu" (titleFamily) burada kullanılmaz.
/// Böylece "Niğde'de Bugün" sade, modern ve her gözün rahat okuyacağı durur.
TextStyle _plain({
  required double size,
  required Color color,
  FontWeight weight = FontWeight.w800,
  double height = 1.15,
  double letterSpacing = 0,
}) {
  return TextStyle(
    fontFamily: AppTypography.primaryFamily,
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );
}

/// "Niğde'de Bugün" sayfası — şehirde bugün öne çıkanları tek ekranda, herkesin
/// kolayca anlayacağı netlikte toplar: hava, nöbetçi eczane, namaz vakitleri ve
/// günün etkinliği. Kartlara dokununca ilgili tam sayfaya gidilir.
class TodayScreen extends StatelessWidget {
  const TodayScreen({
    super.key,
    this.dutyPharmacyData = const DutyPharmacyData.empty(),
    this.weatherData = const WeatherData.empty(),
    this.prayerTimesData = const PrayerTimesData.empty(),
    this.events = const [],
  });

  final DutyPharmacyData dutyPharmacyData;
  final WeatherData weatherData;
  final PrayerTimesData prayerTimesData;
  final List<EtkinlikEvent> events;

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 360),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (_, _, _) => page,
        transitionsBuilder: (context, animation, secondary, child) {
          final fade = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          final slide = Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(fade);
          return FadeTransition(
            opacity: fade,
            child: SlideTransition(position: slide, child: child),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final pharmacy = dutyPharmacyData.primaryPharmacy;
    final event = _firstUpcomingEvent(events);
    final hasPharmacy = pharmacy != null;
    final hasWeather = weatherData.hasWeather;
    final weatherToday = weatherData.today;
    final weatherCurrent = weatherData.current;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.lightOverlay,
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        body: Column(
          children: [
            const FeatureAppBar(title: 'Niğde\'de Bugün'),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.pageHorizontal,
                  AppSpacing.lg,
                  AppSpacing.pageHorizontal,
                  AppSpacing.xxxl + bottomInset,
                ),
                children: [
                  _Header().animate().fadeIn(
                    duration: 340.ms,
                    curve: Curves.easeOutCubic,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _Stagger(
                    index: 0,
                    child: _InfoCard(
                      accent: hasWeather
                          ? weatherTint(
                              weatherCurrent.weatherCode,
                              weatherCurrent.isDay,
                            )
                          : AppColors.deepOcean,
                      icon: hasWeather
                          ? weatherIcon(
                              weatherCurrent.weatherCode,
                              weatherCurrent.isDay,
                            )
                          : Symbols.sun_cloudy_fill,
                      eyebrow: 'HAVA DURUMU',
                      title: hasWeather
                          ? '${weatherCurrent.temperature}° · ${weatherData.conditionLabel}'
                          : 'Hava durumu',
                      subtitle: hasWeather
                          ? 'En yüksek ${weatherToday?.max ?? weatherData.weekMax}° · En düşük ${weatherToday?.min ?? weatherData.weekMin}°'
                          : 'Canlı hava bilgisini gör',
                      onTap: () => _push(
                        context,
                        WeatherScreen(initialData: weatherData),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _Stagger(
                    index: 1,
                    child: _InfoCard(
                      accent: _eczaneRed,
                      icon: Symbols.capsule_fill,
                      eyebrow: 'NÖBETÇİ ECZANE',
                      title: hasPharmacy
                          ? _titleCaseTr(pharmacy.name)
                          : 'Nöbetçi eczane listesi',
                      subtitle: hasPharmacy && pharmacy.address.isNotEmpty
                          ? _titleCaseTr(pharmacy.address)
                          : 'Bugün açık eczaneleri gör',
                      onTap: () => _push(
                        context,
                        PharmacyScreen(initialData: dutyPharmacyData),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _Stagger(index: 2, child: _PrayerCard(data: prayerTimesData)),
                  const SizedBox(height: AppSpacing.md),
                  _Stagger(
                    index: 3,
                    child: event == null
                        ? _InfoCard(
                            accent: _violet,
                            icon: Symbols.calendar_event_line,
                            eyebrow: 'ETKİNLİKLER',
                            title: 'Yaklaşan etkinlik yok',
                            subtitle:
                                'Yeni etkinlikler eklendiğinde burada görünür',
                            onTap: () => _push(
                              context,
                              events.isEmpty
                                  ? const EtkinlikScreen()
                                  : EtkinlikScreen(events: events),
                            ),
                          )
                        : _EventCard(
                            event: event,
                            onTap: () =>
                                _push(context, EtkinlikScreen(events: events)),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stagger extends StatelessWidget {
  const _Stagger({required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return child
        .animate()
        .fadeIn(
          delay: (70 * (index + 1)).ms,
          duration: 320.ms,
          curve: Curves.easeOutCubic,
        )
        .slideY(
          begin: 0.08,
          end: 0,
          delay: (70 * (index + 1)).ms,
          duration: 320.ms,
          curve: Curves.easeOutCubic,
        );
  }
}

// ---------------------------------------------------------------------------
// Başlık — konum + büyük tarih + selam (hepsi düz font)
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Symbols.location_on_rounded,
              size: 14,
              color: AppColors.deepOcean,
            ),
            const SizedBox(width: 5),
            Text(
              'Niğde',
              style: _plain(
                size: 12.5,
                color: AppColors.inkSoft,
                weight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${_weekdayLabel(now)}, ${_dateLabel(now)}',
          style: _plain(
            size: 23,
            color: AppColors.inkStrong,
            height: 1.12,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          _greeting(now),
          style: AppTypography.body.copyWith(
            color: AppColors.inkSoft,
            fontSize: 14.5,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tek satırlık bilgi kartı (hava / eczane) — dokununca tam sayfa
// ---------------------------------------------------------------------------

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.accent,
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final Color accent;
  final IconData icon;
  final String eyebrow;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      onTap: onTap,
      child: Row(
        children: [
          _IconSquare(icon: icon, accent: accent),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _Texts(eyebrow: eyebrow, title: title, subtitle: subtitle),
          ),
          if (onTap != null) ...[
            const SizedBox(width: AppSpacing.sm),
            const _GoArrow(),
          ],
        ],
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event, required this.onTap});
  final EtkinlikEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _violet.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  event.day,
                  style: _plain(size: 18, color: _violet, height: 1),
                ),
                Text(
                  event.month,
                  style: _plain(
                    size: 9,
                    color: _violet,
                    weight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _Texts(
              eyebrow: 'GÜNÜN ETKİNLİĞİ',
              title: event.title,
              subtitle: '${event.venue} · ${event.time}',
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          const _GoArrow(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Namaz vakitleri kartı
// ---------------------------------------------------------------------------

class _PrayerCard extends StatelessWidget {
  const _PrayerCard({required this.data});

  final PrayerTimesData data;

  @override
  Widget build(BuildContext context) {
    final prayers = data.today?.times ?? const <PrayerTime>[];
    final nextIndex = _nextPrayerIndex(prayers);
    final next = nextIndex == null ? null : prayers[nextIndex];
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'NAMAZ VAKİTLERİ',
                style: AppTypography.eyebrow.copyWith(
                  color: AppColors.support,
                  fontSize: 10.5,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              if (next != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.deepOcean.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    'Sıradaki: ${next.name} ${next.time}',
                    style: _plain(
                      size: 11.5,
                      color: AppColors.deepOcean,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (prayers.isEmpty)
            Text(
              'Canlı namaz vakitleri yüklenemedi',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.inkSoft,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            Row(
              children: [
                for (var i = 0; i < prayers.length; i++)
                  _PrayerCell(prayer: prayers[i], isNext: i == nextIndex),
              ],
            ),
        ],
      ),
    );
  }
}

class _PrayerCell extends StatelessWidget {
  const _PrayerCell({required this.prayer, required this.isNext});
  final PrayerTime prayer;
  final bool isNext;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: isNext
            ? BoxDecoration(
                color: AppColors.deepOcean.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.deepOcean.withValues(alpha: 0.16),
                ),
              )
            : null,
        child: Column(
          children: [
            Text(
              prayer.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _plain(
                size: 10,
                color: isNext ? AppColors.deepOcean : AppColors.support,
                weight: isNext ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              prayer.time,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _plain(
                size: 12.5,
                color: isNext ? AppColors.deepOcean : AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Ortak parçalar
// ---------------------------------------------------------------------------

class _CardShell extends StatelessWidget {
  const _CardShell({required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 14,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: child,
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: content,
      ),
    );
  }
}

class _IconSquare extends StatelessWidget {
  const _IconSquare({required this.icon, required this.accent});
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 25, color: accent),
    );
  }
}

class _GoArrow extends StatelessWidget {
  const _GoArrow();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: const BoxDecoration(
        color: AppColors.surfaceSoft,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: const Icon(
        Symbols.arrow_forward_rounded,
        size: 16,
        color: AppColors.deepOcean,
      ),
    );
  }
}

class _Texts extends StatelessWidget {
  const _Texts({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });
  final String eyebrow;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          eyebrow,
          style: AppTypography.eyebrow.copyWith(
            color: AppColors.support,
            fontSize: 10,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _plain(size: 16, color: AppColors.inkStrong, height: 1.15),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.bodySmall.copyWith(color: AppColors.inkSoft),
        ),
      ],
    );
  }
}

const _monthsTr = <String>[
  'Ocak',
  'Şubat',
  'Mart',
  'Nisan',
  'Mayıs',
  'Haziran',
  'Temmuz',
  'Ağustos',
  'Eylül',
  'Ekim',
  'Kasım',
  'Aralık',
];

const _weekdaysTr = <String>[
  'Pazartesi',
  'Salı',
  'Çarşamba',
  'Perşembe',
  'Cuma',
  'Cumartesi',
  'Pazar',
];

String _dateLabel(DateTime date) =>
    '${date.day} ${_monthsTr[date.month - 1]} ${date.year}';

String _weekdayLabel(DateTime date) => _weekdaysTr[date.weekday - 1];

String _greeting(DateTime date) {
  final hour = date.hour;
  if (hour < 12) return 'Günaydın, şehirde bugün öne çıkanlar burada.';
  if (hour < 18) return 'İyi günler, şehirde bugün öne çıkanlar burada.';
  return 'İyi akşamlar, şehirde bugün öne çıkanlar burada.';
}

int? _nextPrayerIndex(List<PrayerTime> prayers) {
  if (prayers.isEmpty) return null;
  final now = DateTime.now();
  for (var i = 0; i < prayers.length; i++) {
    final prayer = prayers[i];
    final time = DateTime(
      now.year,
      now.month,
      now.day,
      prayer.hour,
      prayer.minute,
    );
    if (time.isAfter(now)) return i;
  }
  return 0;
}

EtkinlikEvent? _firstUpcomingEvent(List<EtkinlikEvent> events) {
  if (events.isEmpty) return null;
  final today = DateTime.now();
  final base = DateTime(today.year, today.month, today.day);
  final upcoming = [
    for (final event in events)
      if (!DateTime(
        event.date.year,
        event.date.month,
        event.date.day,
      ).isBefore(base))
        event,
  ]..sort((a, b) => a.date.compareTo(b.date));
  return upcoming.isEmpty ? null : upcoming.first;
}

/// Türkçe-duyarlı "Sadece Baş Harf" biçimi. Veri BÜYÜK HARF gelse de
/// ("CAN ECZANESI") okunur biçime çevrilir ("Can Eczanesi").
String _titleCaseTr(String input) {
  final words = input.trim().split(RegExp(r'\s+'));
  for (var i = 0; i < words.length; i++) {
    final word = words[i];
    if (word.isEmpty) continue;
    final lower = word.replaceAll('İ', 'i').toLowerCase();
    final first = lower[0] == 'i' ? 'İ' : lower[0].toUpperCase();
    words[i] = first + lower.substring(1);
  }
  return words.join(' ');
}
