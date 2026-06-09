import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// Bölüm başlığı.
///
/// Sol tarafta başlık (opsiyonel italik vurgu kelimesiyle), sağ tarafta
/// duruma göre:
///   - `trailing` Widget'ı verildiyse o widget,
///   - aksi halde varsayılan "Tümü →" linki gösterilir.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.accent,
    this.actionLabel = 'Tümü',
    this.onAction,
    this.trailing,
  });

  final String title;
  final String? accent;
  final String actionLabel;
  final VoidCallback? onAction;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        AppSpacing.xl,
        AppSpacing.pageHorizontal,
        AppSpacing.md + 2,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: title, style: AppTypography.titleL),
                      if (accent != null) ...[
                        const TextSpan(text: ' '),
                        TextSpan(
                          text: accent,
                          style: AppTypography.titleL.copyWith(
                            color: AppColors.support,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                  maxLines: 1,
                  softWrap: false,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (trailing != null)
            trailing!
          else
            _DefaultAction(label: actionLabel, onTap: onAction),
        ],
      ),
    );
  }
}

class _DefaultAction extends StatelessWidget {
  const _DefaultAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              Text(
                label,
                style: AppTypography.meta.copyWith(
                  color: AppColors.deepOcean,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(
                Symbols.arrow_forward_rounded,
                size: 14,
                color: AppColors.deepOcean,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
