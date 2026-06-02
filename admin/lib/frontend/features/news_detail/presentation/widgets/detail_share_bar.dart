import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// Sade, tek aksiyonlu paylaşım bloğu.
///
/// Tasarım dili:
///   - Editorial başlık + kırmızı vurgu çubuğu.
///   - Altında tam genişlik, yüksek temasına sahip "Haberi Paylaş" CTA.
///   - Hiçbir dağıtıcı yan ikon yok; tek elle kullanım için optimize.
class DetailShareBar extends StatelessWidget {
  const DetailShareBar({super.key, required this.onShare});

  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        AppSpacing.xl,
        AppSpacing.pageHorizontal,
        AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Header(),
          const SizedBox(height: AppSpacing.md + 2),
          _PrimaryShareCta(onTap: onShare),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 3,
          height: 18,
          margin: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(
            color: AppColors.deepOcean,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Expanded(
          child: Text(
            'Bu haberi paylaş',
            style: AppTypography.titleM.copyWith(
              color: AppColors.inkStrong,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ],
    );
  }
}

class _PrimaryShareCta extends StatefulWidget {
  const _PrimaryShareCta({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_PrimaryShareCta> createState() => _PrimaryShareCtaState();
}

class _PrimaryShareCtaState extends State<_PrimaryShareCta> {
  bool _pressed = false;

  void _onDown(_) => setState(() => _pressed = true);
  void _onUp(_) => setState(() => _pressed = false);
  void _onCancel() => setState(() => _pressed = false);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onDown,
      onTapUp: _onUp,
      onTapCancel: _onCancel,
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.actionRed, Color(0xFFD8341F)],
            ),
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: AppColors.actionRed.withValues(
                  alpha: _pressed ? 0.18 : 0.30,
                ),
                blurRadius: _pressed ? 12 : 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Symbols.ios_share_rounded,
                size: 17,
                color: Colors.white,
              ),
              const SizedBox(width: 10),
              Text(
                'HABERİ PAYLAŞ',
                style: AppTypography.eyebrow.copyWith(
                  color: Colors.white,
                  fontSize: 12.5,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
