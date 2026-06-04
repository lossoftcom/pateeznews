import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/feature_app_bar.dart';
import '../data/obituary_mock.dart';

/// Ölüm ilanları sayfası — gerçek vefat ilanı diliyle, saygılı ve sade. Sıcak
/// kırmızı yerine deepOcean tonları, yaprak motifi ve bol nefes alanı kullanılır.
class ObituariesScreen extends StatelessWidget {
  const ObituariesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.lightOverlay,
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        body: Column(
          children: [
            const FeatureAppBar(title: 'Ölüm İlanları'),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.pageHorizontal,
                  AppSpacing.xl,
                  AppSpacing.pageHorizontal,
                  AppSpacing.xxxl + bottomInset,
                ),
                children: [
                  const _Header()
                      .animate()
                      .fadeIn(duration: 380.ms, curve: Curves.easeOutCubic),
                  const SizedBox(height: AppSpacing.xl),
                  for (var i = 0; i < ObituaryMock.all.length; i++) ...[
                    if (i > 0) const SizedBox(height: AppSpacing.md),
                    _ObituaryCard(obituary: ObituaryMock.all[i])
                        .animate()
                        .fadeIn(delay: (90 * (i + 1)).ms, duration: 340.ms, curve: Curves.easeOutCubic)
                        .slideY(begin: 0.06, end: 0, delay: (90 * (i + 1)).ms, duration: 340.ms, curve: Curves.easeOutCubic),
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

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.deepOcean.withValues(alpha: 0.07),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Icon(Symbols.flower_line, size: 26, color: AppColors.deepOcean),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'HÜVELBÂKİ',
          style: AppTypography.eyebrow.copyWith(
            color: AppColors.support,
            fontSize: 11,
            letterSpacing: 2.4,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          ObituaryMock.headerNote,
          textAlign: TextAlign.center,
          style: AppTypography.body.copyWith(
            color: AppColors.inkSoft,
            height: 1.55,
          ),
        ),
      ],
    );
  }
}

class _ObituaryCard extends StatelessWidget {
  const _ObituaryCard({required this.obituary});
  final Obituary obituary;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // üst ince deepOcean şerit (saygılı vurgu)
          Container(height: 3, color: AppColors.deepOcean),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Symbols.leaf_line, size: 15, color: AppColors.deepOcean),
                    const SizedBox(width: 6),
                    Text(
                      'VEFAT İLANI',
                      style: AppTypography.eyebrow.copyWith(
                        color: AppColors.support,
                        fontSize: 10.5,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      obituary.relativeLabel,
                      style: AppTypography.meta.copyWith(color: AppColors.support),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  obituary.name,
                  style: AppTypography.titleL.copyWith(
                    color: AppColors.inkStrong,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${obituary.years}  ·  ${obituary.age} yaşında',
                  style: AppTypography.meta.copyWith(
                    color: AppColors.support,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm + 2),
                _InfoLine(
                  icon: Symbols.map_pin_line,
                  text: obituary.neighborhood,
                ),
                const SizedBox(height: AppSpacing.md),
                _FuneralBox(obituary: obituary),
                const SizedBox(height: AppSpacing.md),
                _CondolenceButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FuneralBox extends StatelessWidget {
  const _FuneralBox({required this.obituary});
  final Obituary obituary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cenaze Programı',
            style: AppTypography.eyebrow.copyWith(
              color: AppColors.inkSoft,
              fontSize: 10.5,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          _InfoLine(
            icon: Symbols.calendar_event_line,
            text: '${obituary.funeralDay} · ${obituary.prayer}',
          ),
          const SizedBox(height: AppSpacing.sm),
          _InfoLine(icon: Symbols.building_line, text: obituary.mosque),
          const SizedBox(height: AppSpacing.sm),
          _InfoLine(
            icon: Symbols.map_pin_line,
            text: "${obituary.cemetery}'ta defnedilecektir",
          ),
        ],
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.iconMuted),
        const SizedBox(width: AppSpacing.sm + 2),
        Expanded(
          child: Text(
            text,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.inkSoft,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _CondolenceButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(4),
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Symbols.heart_3_line, size: 16, color: AppColors.deepOcean),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Taziye Mesajı Gönder',
                style: AppTypography.titleS.copyWith(
                  color: AppColors.deepOcean,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
