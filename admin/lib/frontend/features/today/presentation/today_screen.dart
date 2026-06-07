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
import '../../weather/data/weather_mock.dart';
import '../../weather/presentation/weather_screen.dart';
import '../data/today_mock.dart';

const Color _eczaneRed = Color(0xFFE30613);
const Color _violet = Color(0xFF6C5CE7);

/// "Niğde'de Bugün" sayfası — şehirde bugün öne çıkanları tek ekranda, herkesin
/// kolayca anlayacağı netlikte toplar: hava, nöbetçi eczane, namaz vakitleri ve
/// günün etkinliği. Kartlara dokununca ilgili tam sayfaya gidilir.
class TodayScreen extends StatelessWidget {
  const TodayScreen({
    super.key,
    this.dutyPharmacyData = const DutyPharmacyData.empty(),
  });

  final DutyPharmacyData dutyPharmacyData;

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
    final event = EtkinlikMock.all.first;

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
                      accent: AppColors.warmHorizon,
                      icon: Symbols.sun_cloudy_fill,
                      eyebrow: 'HAVA DURUMU',
                      title:
                          '${WeatherMock.currentTemp}° · ${WeatherMock.condition}',
                      subtitle:
                          'En yüksek ${WeatherMock.hi}° · En düşük ${WeatherMock.lo}°',
                      onTap: () => _push(context, const WeatherScreen()),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _Stagger(
                    index: 1,
                    child: _InfoCard(
                      accent: _eczaneRed,
                      icon: Symbols.capsule_fill,
                      eyebrow: 'NÖBETÇİ ECZANE',
                      title: pharmacy?.name ?? 'Nöbetçi eczane listesi',
                      subtitle: pharmacy?.address.isNotEmpty == true
                          ? pharmacy!.address
                          : 'Canlı listeyi görüntüle',
                      onTap: () => _push(
                        context,
                        PharmacyScreen(initialData: dutyPharmacyData),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _Stagger(index: 2, child: const _PrayerCard()),
                  const SizedBox(height: AppSpacing.md),
                  _Stagger(
                    index: 3,
                    child: _EventCard(
                      event: event,
                      onTap: () => _push(context, const EtkinlikScreen()),
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

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${TodayMock.weekday}, ${TodayMock.dateLabel}',
          style: AppTypography.display.copyWith(
            color: AppColors.inkStrong,
            fontSize: 24,
            height: 1.1,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          TodayMock.greeting,
          style: AppTypography.body.copyWith(color: AppColors.inkSoft),
        ),
      ],
    );
  }
}

/// Hava / eczane gibi tek satırlık, dokununca tam sayfaya giden bilgi kartı.
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
            const Icon(
              Symbols.arrow_forward_rounded,
              size: 18,
              color: AppColors.support,
            ),
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
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _violet.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  event.day,
                  style: AppTypography.titleS.copyWith(
                    color: _violet,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                Text(
                  event.month,
                  style: AppTypography.eyebrow.copyWith(
                    color: _violet,
                    fontSize: 9,
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
          const Icon(
            Symbols.arrow_forward_rounded,
            size: 18,
            color: AppColors.support,
          ),
        ],
      ),
    );
  }
}

class _PrayerCard extends StatelessWidget {
  const _PrayerCard();

  @override
  Widget build(BuildContext context) {
    final next = TodayMock.nextPrayer;
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
              Text(
                'Sıradaki: ${next.name} ${next.time}',
                style: AppTypography.meta.copyWith(
                  color: AppColors.deepOcean,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              for (var i = 0; i < TodayMock.prayerTimes.length; i++)
                _PrayerCell(
                  prayer: TodayMock.prayerTimes[i],
                  isNext: i == TodayMock.nextPrayerIndex,
                ),
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
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: isNext
            ? BoxDecoration(
                color: AppColors.deepOcean.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(4),
              )
            : null,
        child: Column(
          children: [
            Text(
              prayer.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.meta.copyWith(
                color: isNext ? AppColors.deepOcean : AppColors.support,
                fontSize: 10,
                fontWeight: isNext ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              prayer.time,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.titleS.copyWith(
                color: isNext ? AppColors.deepOcean : AppColors.ink,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.line),
      ),
      child: child,
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
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
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 24, color: accent),
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
          style: AppTypography.titleM.copyWith(
            color: AppColors.inkStrong,
            fontSize: 15.5,
            fontWeight: FontWeight.w800,
          ),
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
