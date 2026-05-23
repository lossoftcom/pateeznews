import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../shared/widgets/symbol_icon.dart';

class TopBarIconAction extends StatelessWidget {
  const TopBarIconAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.label,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final text = label;
    if (text != null) {
      return Tooltip(
        message: tooltip,
        child: SizedBox(
          height: 32,
          child: TextButton.icon(
            onPressed: onPressed,
            icon: SymbolIcon(icon, color: AppColors.iconMuted, size: 16),
            label: Text(text),
            style:
                TextButton.styleFrom(
                  foregroundColor: AppColors.deepOcean,
                  backgroundColor: AppColors.surface,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.value),
                    side: const BorderSide(color: AppColors.line),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0,
                  ),
                ).copyWith(
                  mouseCursor: const WidgetStatePropertyAll(
                    SystemMouseCursors.click,
                  ),
                ),
          ),
        ),
      );
    }

    return SizedBox.square(
      dimension: 36,
      child: IconButton(
        tooltip: tooltip,
        mouseCursor: SystemMouseCursors.click,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.value),
          ),
        ),
        icon: SymbolIcon(icon, color: AppColors.iconMuted, size: 20),
      ),
    );
  }
}
