import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/feature_app_bar.dart';

const Color _noticeBlue = Color(0xFF2F6F9F);
const Color _noticeGreen = Color(0xFF2F8F67);
const Color _noticeAmber = Color(0xFFE59A22);

class AnnouncementsScreen extends StatelessWidget {
  const AnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.lightOverlay,
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        body: Column(
          children: [
            const FeatureAppBar(title: 'Duyurular'),
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
                  const _HeroNotice()
                      .animate()
                      .fadeIn(duration: 340.ms, curve: Curves.easeOutCubic)
                      .slideY(
                        begin: 0.05,
                        end: 0,
                        duration: 340.ms,
                        curve: Curves.easeOutCubic,
                      ),
                  const SizedBox(height: AppSpacing.xl),
                  const _SectionTitle('Bugünün duyuruları'),
                  const SizedBox(height: AppSpacing.md),
                  for (var i = 0; i < _announcements.length; i++) ...[
                    if (i > 0) const SizedBox(height: AppSpacing.md),
                    _AnnouncementCard(item: _announcements[i])
                        .animate()
                        .fadeIn(
                          delay: (80 * (i + 1)).ms,
                          duration: 300.ms,
                          curve: Curves.easeOutCubic,
                        )
                        .slideY(
                          begin: 0.05,
                          end: 0,
                          delay: (80 * (i + 1)).ms,
                          duration: 300.ms,
                          curve: Curves.easeOutCubic,
                        ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroNotice extends StatelessWidget {
  const _HeroNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepOcean.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.actionRed.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(4),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Symbols.notifications,
                  size: 24,
                  color: AppColors.actionRed,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Resmi duyurular tek ekranda',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleL.copyWith(
                        color: AppColors.inkStrong,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Valilik, belediye ve kamu kurumlarından güncel bilgiler.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.meta.copyWith(
                        color: AppColors.inkSoft,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: const [
              _Tag(label: 'Valilik', color: _noticeBlue),
              _Tag(label: 'Belediye', color: AppColors.actionRed),
              _Tag(label: 'Kamu kurumları', color: _noticeGreen),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 18,
          margin: const EdgeInsets.only(right: AppSpacing.sm + 2),
          decoration: BoxDecoration(
            color: AppColors.actionRed,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.titleL.copyWith(
              color: AppColors.inkStrong,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({required this.item});

  final _Announcement item;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: item.color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: _SourceBadge(item: item),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          item.time,
                          style: AppTypography.meta.copyWith(
                            color: AppColors.support,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      item.title,
                      style: AppTypography.titleM.copyWith(
                        color: AppColors.inkStrong,
                        fontWeight: FontWeight.w800,
                        height: 1.18,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      item.summary,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.inkSoft,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Icon(Symbols.map_pin_line, size: 14, color: item.color),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            item.place,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.meta.copyWith(
                              color: AppColors.inkSoft,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.item});

  final _Announcement item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: item.color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(item.icon, size: 13, color: item.color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              item.source,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.eyebrow.copyWith(
                color: item.color,
                fontSize: 10.5,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: AppTypography.meta.copyWith(
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _Announcement {
  const _Announcement({
    required this.source,
    required this.title,
    required this.summary,
    required this.place,
    required this.time,
    required this.color,
    required this.icon,
  });

  final String source;
  final String title;
  final String summary;
  final String place;
  final String time;
  final Color color;
  final IconData icon;
}

const _announcements = [
  _Announcement(
    source: 'VALİLİK',
    title: 'Kuvvetli rüzgar ve toz taşınımı uyarısı',
    summary:
        'İç Anadolu genelinde öğleden sonra beklenen rüzgar için vatandaşların '
        'çatı, tabela ve açık alan risklerine karşı dikkatli olması isteniyor.',
    place: 'Niğde · Merkez ve ilçeler',
    time: 'Bugün 10:30',
    color: _noticeBlue,
    icon: Symbols.verified,
  ),
  _Announcement(
    source: 'BELEDİYE',
    title: 'Mahalle su kesintisi ve çalışma programı',
    summary:
        'Altyapı yenileme çalışması nedeniyle bazı mahallelerde planlı kesinti '
        'yapılacak. Ekipler aynı gün içinde saha çalışmasını tamamlayacak.',
    place: 'Aşağı Kayabaşı · İlhanlı · Efendibey',
    time: 'Bugün 12:15',
    color: AppColors.actionRed,
    icon: Symbols.building_line,
  ),
  _Announcement(
    source: 'KAMU',
    title: 'Aile destek başvuruları için son hafta',
    summary:
        'Sosyal yardım ve danışmanlık başvuruları e-Devlet üzerinden veya ilgili '
        'kurum hizmet noktasından yapılabilecek.',
    place: 'İl Sosyal Yardımlaşma Merkezi',
    time: 'Dün 18:00',
    color: _noticeGreen,
    icon: Symbols.pending_actions,
  ),
  _Announcement(
    source: 'ETKİNLİK',
    title: 'Meydan konseri ve çocuk atölyeleri duyurusu',
    summary:
        'Hafta sonu şehir meydanında ailelerin katılabileceği açık hava programı, '
        'çocuk atölyeleri ve yerel sanatçı konserleri düzenlenecek.',
    place: 'Cumhuriyet Meydanı',
    time: 'Yarın 19:00',
    color: _noticeAmber,
    icon: Symbols.calendar_event_line,
  ),
];
