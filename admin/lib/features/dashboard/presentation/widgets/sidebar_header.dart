import 'package:flutter/material.dart';

import '../../../../core/localization/admin_language_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/branding/admin_branding.dart';
import '../../../../shared/widgets/admin_brand_mark.dart';

class SidebarHeader extends StatelessWidget {
  const SidebarHeader({
    super.key,
    this.expanded = true,
    this.pinControlVisible = false,
    this.pinned = false,
    this.onPinnedChanged,
  });

  final bool expanded;
  final bool pinControlVisible;
  final bool pinned;
  final ValueChanged<bool>? onPinnedChanged;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AdminBrandingData>(
      valueListenable: adminBranding,
      builder: (context, branding, _) {
        final logo = AdminBrandMark(branding: branding, size: 38);
        final pinSwitch = pinControlVisible
            ? _SidebarPinSwitch(value: pinned, onChanged: onPinnedChanged)
            : null;

        return Padding(
          padding: EdgeInsets.fromLTRB(
            expanded ? 22 : 8,
            22,
            expanded ? 14 : 8,
            18,
          ),
          child: SizedBox(
            height: 40,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned(left: 0, top: 1, child: logo),
                if (expanded)
                  Positioned(
                    left: 50,
                    right: pinSwitch == null ? 0 : 42,
                    top: 0,
                    bottom: 0,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          branding.hasSiteName
                              ? branding.siteName
                              : context.t('brand.name'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: AppColors.deepOcean,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0,
                              ),
                        ),
                        Text(
                          context.t('brand.subtitle'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.support,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (pinSwitch != null)
                  Positioned(right: 0, top: 10, child: pinSwitch),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SidebarPinSwitch extends StatelessWidget {
  const _SidebarPinSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final label = value
        ? context.t('nav.sidebar.unpin')
        : context.t('nav.sidebar.pin');
    final enabled = onChanged != null;

    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        toggled: value,
        label: label,
        child: MouseRegion(
          cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
          child: GestureDetector(
            key: const ValueKey('admin-sidebar-pin-switch'),
            behavior: HitTestBehavior.opaque,
            onTap: enabled ? () => onChanged!(!value) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 34,
              height: 20,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: value ? AppColors.deepOcean : AppColors.softLine,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: value ? AppColors.deepOcean : AppColors.line,
                ),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOutCubic,
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.14),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
