import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/feature_app_bar.dart';
import '../data/etkinlik_mock.dart';

/// Etkinlik uygulamasının mor (violet) kimlik rengi — Uygulamalar ızgarasındaki
/// Etkinlik tile'ı ile aynı.
const Color _violet = Color(0xFF6C5CE7);
const Color _free = Color(0xFF22A565);

/// Niğde için etkinlik (şehir programı) sayfası: kategori filtreleri + tarih
/// rozetli etkinlik kartları (kategori, yer, saat). Kullanışlı, anlaşılır,
/// profesyonel; veriler örnektir.
class EtkinlikScreen extends StatefulWidget {
  const EtkinlikScreen({super.key});

  @override
  State<EtkinlikScreen> createState() => _EtkinlikScreenState();
}

class _EtkinlikScreenState extends State<EtkinlikScreen> {
  String _filter = 'Tümü';

  List<EtkinlikEvent> get _events {
    if (_filter == 'Tümü') return EtkinlikMock.all;
    return EtkinlikMock.all
        .where((e) => e.category == _filter)
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final events = _events;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.lightOverlay,
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        body: Column(
          children: [
            const FeatureAppBar(title: 'Etkinlik'),
            Expanded(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.pageHorizontal,
                        AppSpacing.lg,
                        AppSpacing.pageHorizontal,
                        AppSpacing.xs,
                      ),
                      child: Row(
                        children: [
                          const Icon(Symbols.location_on_rounded, size: 14, color: AppColors.support),
                          const SizedBox(width: 6),
                          Text(
                            EtkinlikMock.cityLabel,
                            style: AppTypography.meta.copyWith(color: AppColors.support),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _FilterChips(
                      selected: _filter,
                      onSelect: (c) => setState(() => _filter = c),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.pageHorizontal,
                      AppSpacing.sm,
                      AppSpacing.pageHorizontal,
                      AppSpacing.xxxl + bottomInset,
                    ),
                    sliver: SliverList.separated(
                      itemCount: events.length,
                      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
                      itemBuilder: (context, i) {
                        return _EventCard(event: events[i])
                            .animate()
                            .fadeIn(delay: (50 * i).ms, duration: 300.ms, curve: Curves.easeOutCubic)
                            .slideY(begin: 0.08, end: 0, delay: (50 * i).ms, duration: 300.ms, curve: Curves.easeOutCubic);
                      },
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

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.selected, required this.onSelect});
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
        itemCount: EtkinlikMock.categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, i) {
          final c = EtkinlikMock.categories[i];
          final active = c == selected;
          return GestureDetector(
            onTap: () => onSelect(c),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: active ? _violet : AppColors.surfaceInk,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                c,
                style: AppTypography.meta.copyWith(
                  color: active ? Colors.white : AppColors.inkSoft,
                  fontSize: 12.5,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event});
  final EtkinlikEvent event;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DateBadge(day: event.day, month: event.month),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _CategoryChip(label: event.category),
                    const Spacer(),
                    if (event.free)
                      Text(
                        'Ücretsiz',
                        style: AppTypography.eyebrow.copyWith(
                          color: _free,
                          fontSize: 10.5,
                          letterSpacing: 0.3,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  event.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleM.copyWith(
                    color: AppColors.inkStrong,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm + 2),
                _InfoLine(icon: Symbols.map_pin_line, text: event.venue),
                const SizedBox(height: 5),
                _InfoLine(
                  icon: Symbols.time_fill,
                  text: '${event.weekday} · ${event.time}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DateBadge extends StatelessWidget {
  const _DateBadge({required this.day, required this.month});
  final String day;
  final String month;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: _violet.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            day,
            style: AppTypography.titleL.copyWith(
              color: _violet,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            month,
            style: AppTypography.eyebrow.copyWith(
              color: _violet,
              fontSize: 10,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _violet.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTypography.eyebrow.copyWith(
          color: _violet,
          fontSize: 10,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.iconMuted),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodySmall.copyWith(color: AppColors.inkSoft),
          ),
        ),
      ],
    );
  }
}
