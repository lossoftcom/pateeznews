import 'package:flutter/material.dart';

import '../../../core/localization/admin_language_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/icons/symbols.dart';
import '../../../shared/widgets/symbol_icon.dart';

const navigationIconOptions = [
  'home',
  'trending_up',
  'workspace_premium',
  'movie',
  'sports_esports',
  'sports_soccer',
  'favorite',
  'microscope',
  'public',
  'smartphone',
  'location_on',
  'flag',
  'list',
  'check_circle',
  'grid_view',
  'bolt',
  'poll',
  'quiz',
  'smart_display',
  'music_note',
  'photo_camera',
  'info',
  'star',
  'palette',
  'shopping_bag',
  'coffee',
  'directions_car',
  'flight',
  'notifications',
  'shield',
  'credit_card',
  'history',
  'video_library',
  'newspaper',
  'tv',
  'local_fire_department',
  'rocket_launch',
  'monitoring',
  'mic',
  'headset',
  'monitor',
  'laptop',
  'memory',
  'database',
  'code',
  'terminal',
  'cloud',
  'wb_sunny',
  'brightness_2',
  'umbrella',
  'air',
  'restaurant',
  'local_dining',
  'local_pizza',
  'sports_bar',
  'wine_bar',
  'ghost',
  'featured_seasonal',
  'forest',
  'terrain',
  'waves',
  'directions_boat',
  'domain',
  'business_center',
  'payments',
  'account_balance_wallet',
  'person',
  'group',
  'lock',
  'key',
  'visibility',
  'mail',
  'call',
  'chat',
  'calendar_month',
  'schedule',
  'menu_book',
  'library_books',
  'school',
  'target',
  'fitness_center',
  'swords',
  'search',
];

Future<String?> showNavigationIconPicker(
  BuildContext context, {
  required String initialIcon,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _NavigationIconPicker(initialIcon: initialIcon),
  );
}

class _NavigationIconPicker extends StatefulWidget {
  const _NavigationIconPicker({required this.initialIcon});

  final String initialIcon;

  @override
  State<_NavigationIconPicker> createState() => _NavigationIconPickerState();
}

class _NavigationIconPickerState extends State<_NavigationIconPicker> {
  late final TextEditingController _searchController;
  late final TextEditingController _manualController;
  var _query = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _manualController = TextEditingController(text: widget.initialIcon);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _manualController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = navigationIconOptions
        .where((icon) => icon.contains(_query.trim().toLowerCase()))
        .toList(growable: false);
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.value),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 672, maxHeight: 640),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 28, 22, 24),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.t('navigation.iconPicker.title'),
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: AppColors.deepOcean,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          context.t('navigation.iconPicker.subtitle'),
                          style: const TextStyle(
                            color: AppColors.inkSoft,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    mouseCursor: SystemMouseCursors.click,
                    icon: const SymbolIcon(Symbols.close, size: 20),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.softLine),
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 24, 32, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _searchController,
                    mouseCursor: SystemMouseCursors.text,
                    cursorColor: AppColors.support,
                    onChanged: (value) => setState(() => _query = value),
                    decoration: InputDecoration(
                      hintText: context.t(
                        'navigation.iconPicker.searchPlaceholder',
                      ),
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(left: 14, right: 10),
                        child: SymbolIcon(
                          Symbols.search,
                          color: AppColors.iconMuted,
                          size: 18,
                        ),
                      ),
                      prefixIconConstraints: const BoxConstraints(
                        minWidth: 42,
                        minHeight: 18,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 520;
                      final manual = TextFormField(
                        controller: _manualController,
                        mouseCursor: SystemMouseCursors.text,
                        cursorColor: AppColors.support,
                        decoration: InputDecoration(
                          labelText: context.t(
                            'navigation.iconPicker.manualLabel',
                          ),
                          hintText: context.t(
                            'navigation.iconPicker.manualPlaceholder',
                          ),
                        ),
                      );
                      final allIcons = _AllIconsHint(
                        label: context.t('navigation.iconPicker.allIcons'),
                      );
                      if (compact) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            manual,
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: allIcons,
                            ),
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: manual),
                          const SizedBox(width: 14),
                          allIcons,
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 20),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 82,
                  mainAxisExtent: 76,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final iconName = filtered[index];
                  return _IconOptionButton(
                    iconName: iconName,
                    selected: _manualController.text.trim() == iconName,
                    onTap: () => Navigator.of(context).pop(iconName),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.softLine)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: Text(context.t('common.cancel')),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 40,
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(
                          context,
                        ).pop(_manualController.text.trim());
                      },
                      style:
                          TextButton.styleFrom(
                            backgroundColor: AppColors.deepOcean,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 22),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppRadius.value,
                              ),
                            ),
                          ).copyWith(
                            mouseCursor: const WidgetStatePropertyAll(
                              SystemMouseCursors.click,
                            ),
                          ),
                      child: Text(context.t('common.save')),
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

class _AllIconsHint extends StatelessWidget {
  const _AllIconsHint({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SymbolIcon(Symbols.language, color: AppColors.warmHorizon),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.warmHorizon,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _IconOptionButton extends StatelessWidget {
  const _IconOptionButton({
    required this.iconName,
    required this.selected,
    required this.onTap,
  });

  final String iconName;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected ? AppColors.deepOcean : Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.value),
            border: Border.all(
              color: selected ? AppColors.deepOcean : AppColors.line,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SymbolIcon(
                  _iconForName(iconName),
                  color: selected ? Colors.white : AppColors.inkSoft,
                  size: 24,
                ),
                const SizedBox(height: 7),
                Text(
                  iconName.replaceAll('_', ' '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? Colors.white : AppColors.inkSoft,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

IconData _iconForName(String name) {
  return switch (name) {
    'home' => Symbols.home,
    'newspaper' => Symbols.newspaper,
    'notifications' => Symbols.notifications,
    'person' => Symbols.person,
    'group' => Symbols.group,
    'lock' => Symbols.lock,
    'visibility' => Symbols.visibility,
    'search' => Symbols.search,
    'schedule' => Symbols.schedule,
    'language' || 'public' => Symbols.language,
    'code' => Symbols.code,
    'download' => Symbols.download,
    'upload' => Symbols.upload,
    'list' => Symbols.format_list_numbered,
    'menu' => Symbols.menu,
    _ => Symbols.short_text,
  };
}
