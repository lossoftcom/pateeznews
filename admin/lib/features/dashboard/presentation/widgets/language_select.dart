import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../../core/localization/admin_language_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../shared/widgets/symbol_icon.dart';

class LanguageSelect extends StatelessWidget {
  const LanguageSelect({super.key});

  String _codeLabel(String code) {
    return code.trim().toUpperCase();
  }

  String _languageName(BuildContext context, String code, String fallback) {
    final key = 'language.name.${code.trim().toLowerCase()}';
    final translated = context.t(key);
    if (translated != key) return translated;
    final fallbackTranslated = context.t(fallback);
    return fallbackTranslated == fallback ? fallback : fallbackTranslated;
  }

  @override
  Widget build(BuildContext context) {
    final controller = AdminLocalizationScope.of(context);
    final languages = controller.availableLanguages;
    final selectedCode =
        languages.any((language) => language.code == controller.code)
        ? controller.code
        : 'tr';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        height: 32,
        constraints: const BoxConstraints(minWidth: 86),
        padding: const EdgeInsets.only(left: 10, right: 6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.value),
          border: Border.all(color: AppColors.line),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: selectedCode,
            borderRadius: BorderRadius.circular(AppRadius.value),
            mouseCursor: SystemMouseCursors.click,
            dropdownMenuItemMouseCursor: SystemMouseCursors.click,
            dropdownColor: Colors.white,
            focusColor: Colors.transparent,
            icon: const SymbolIcon(
              Symbols.keyboard_arrow_down,
              color: AppColors.iconMuted,
              size: 16,
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.deepOcean,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0,
            ),
            items: [
              for (final language in languages)
                DropdownMenuItem(
                  value: language.code,
                  child: Text(
                    '${_codeLabel(language.code)} - '
                    '${_languageName(context, language.code, language.name)}',
                  ),
                ),
            ],
            selectedItemBuilder: (context) {
              return [
                for (final language in languages)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _languageName(context, language.code, language.name),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ];
            },
            onChanged: (value) {
              if (value == null) return;
              unawaited(controller.setLanguage(value));
            },
          ),
        ),
      ),
    );
  }
}
