import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../../core/localization/admin_language_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../shared/widgets/symbol_icon.dart';

class RememberToggle extends StatelessWidget {
  const RememberToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: value,
      label: context.t('login.remember'),
      child: InkWell(
        mouseCursor: SystemMouseCursors.click,
        borderRadius: BorderRadius.circular(AppRadius.value),
        onTap: () => onChanged(!value),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            AnimatedContainer(
              width: 18,
              height: 18,
              alignment: Alignment.center,
              duration: const Duration(milliseconds: 170),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                color: value ? AppColors.deepOcean : Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.value),
                border: Border.all(
                  color: value ? AppColors.deepOcean : AppColors.line,
                  width: 1,
                ),
              ),
              child: AnimatedScale(
                scale: value ? 1 : 0.65,
                duration: const Duration(milliseconds: 170),
                curve: Curves.easeOutBack,
                child: AnimatedOpacity(
                  opacity: value ? 1 : 0,
                  duration: const Duration(milliseconds: 120),
                  child: const SymbolIcon(
                    Symbols.check,
                    color: Colors.white,
                    size: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                context.t('login.remember'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.deepOcean,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
