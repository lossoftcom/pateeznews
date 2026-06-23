import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../core/localization/admin_language_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/widgets/symbol_icon.dart';

const double settingsMobileBreakpoint = 640;
const double settingsDialogMobileBreakpoint = 700;

EdgeInsets settingsPagePadding(double width, {double desktopBottom = 28}) {
  final mobile = width < settingsMobileBreakpoint;
  return EdgeInsets.fromLTRB(
    mobile ? 16 : 28,
    mobile ? 18 : 28,
    mobile ? 16 : 28,
    mobile ? 28 : desktopBottom,
  );
}

class SettingsTabItem<T> {
  const SettingsTabItem({required this.value, required this.label});

  final T value;
  final String label;
}

class SettingsResponsiveTabs<T> extends StatelessWidget {
  const SettingsResponsiveTabs({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelected,
  });

  final List<SettingsTabItem<T>> items;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 390;
        if (compact && items.length > 1) {
          return Row(
            children: [
              for (var index = 0; index < items.length; index++) ...[
                Expanded(
                  child: _SettingsTabButton<T>(
                    item: items[index],
                    selected: items[index].value == selected,
                    compact: true,
                    onSelected: onSelected,
                  ),
                ),
                if (index != items.length - 1) const SizedBox(width: 6),
              ],
            ],
          );
        }

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in items)
              _SettingsTabButton<T>(
                item: item,
                selected: item.value == selected,
                compact: false,
                onSelected: onSelected,
              ),
          ],
        );
      },
    );
  }
}

class _SettingsTabButton<T> extends StatelessWidget {
  const _SettingsTabButton({
    required this.item,
    required this.selected,
    required this.compact,
    required this.onSelected,
  });

  final SettingsTabItem<T> item;
  final bool selected;
  final bool compact;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: TextButton(
        onPressed: () => onSelected(item.value),
        style:
            TextButton.styleFrom(
              backgroundColor: selected ? AppColors.actionRed : Colors.white,
              foregroundColor: selected ? Colors.white : AppColors.deepOcean,
              side: BorderSide(
                color: selected
                    ? AppColors.actionRed
                    : AppColors.line.withValues(alpha: 0.88),
              ),
              padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 16),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.value),
              ),
              textStyle: TextStyle(
                fontSize: compact ? 12 : 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ).copyWith(
              mouseCursor: const WidgetStatePropertyAll(
                SystemMouseCursors.click,
              ),
            ),
        child: Text(
          context.t(item.label),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

Future<T?> showSettingsSideDialog<T>(
  BuildContext context, {
  required Widget Function(bool mobile) builder,
  String barrierLabel = 'SettingsDialog',
  Color? desktopBarrierColor,
  Color? mobileBarrierColor,
}) {
  final mobile =
      MediaQuery.sizeOf(context).width < settingsDialogMobileBreakpoint;
  if (!mobile) {
    return showDialog<T>(
      context: context,
      barrierColor: desktopBarrierColor ?? Colors.black.withValues(alpha: 0.34),
      builder: (context) => builder(false),
    );
  }

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: barrierLabel,
    barrierColor: mobileBarrierColor ?? Colors.black.withValues(alpha: 0.5),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondaryAnimation) {
      return SafeArea(
        child: Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: Colors.transparent,
            child: SettingsMobileDrawerFrame(child: builder(true)),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
        child: child,
      );
    },
  );
}

class SettingsMobileDrawerFrame extends StatelessWidget {
  const SettingsMobileDrawerFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Container(
      width: size.width,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            spreadRadius: 2,
            blurRadius: 14,
          ),
        ],
      ),
      child: child,
    );
  }
}

class SettingsMobileDialogFooter extends StatelessWidget {
  const SettingsMobileDialogFooter({
    super.key,
    required this.onSave,
    this.primaryLabel = 'Kaydet',
  });

  final VoidCallback onSave;
  final String primaryLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 38,
            child: TextButton.icon(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const SymbolIcon(
                Symbols.close,
                color: AppColors.deepOcean,
                size: 16,
              ),
              label: Text(context.t('Cancel')),
              style:
                  TextButton.styleFrom(
                    foregroundColor: AppColors.deepOcean,
                    backgroundColor: Colors.white,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.value),
                      side: const BorderSide(color: AppColors.line),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ).copyWith(
                    mouseCursor: const WidgetStatePropertyAll(
                      SystemMouseCursors.click,
                    ),
                  ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 38,
            child: TextButton.icon(
              onPressed: onSave,
              icon: const SymbolIcon(
                Symbols.save,
                color: Colors.white,
                size: 16,
              ),
              label: Text(context.t(primaryLabel)),
              style:
                  TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: AppColors.actionRed,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.value),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ).copyWith(
                    mouseCursor: const WidgetStatePropertyAll(
                      SystemMouseCursors.click,
                    ),
                  ),
            ),
          ),
        ),
      ],
    );
  }
}
