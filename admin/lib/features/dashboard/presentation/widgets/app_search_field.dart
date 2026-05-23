import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/localization/admin_language_controller.dart';
import '../../../../shared/widgets/symbol_icon.dart';

class AppSearchField extends StatelessWidget {
  const AppSearchField({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: TextField(
        mouseCursor: SystemMouseCursors.text,
        cursorColor: AppColors.support,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.inkSoft,
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
        ),
        decoration: InputDecoration(
          hintText: context.t('common.search'),
          hintStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.placeholder.withValues(alpha: 0.72),
            fontWeight: FontWeight.w300,
            letterSpacing: 0,
          ),
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: 11, right: 7),
            child: SymbolIcon(
              Symbols.search,
              color: AppColors.iconMuted,
              size: 18,
            ),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 38,
            minHeight: 18,
          ),
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.value),
            borderSide: const BorderSide(color: AppColors.line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.value),
            borderSide: const BorderSide(color: AppColors.softLine),
          ),
        ),
      ),
    );
  }
}
