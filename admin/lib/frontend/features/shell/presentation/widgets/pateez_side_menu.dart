import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../../core/brand/default_brand_assets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/app_shell_repository.dart';
import 'pateez_bottom_nav.dart';

class PateezSideMenu extends StatefulWidget {
  const PateezSideMenu({
    super.key,
    required this.width,
    required this.items,
    required this.shellData,
    required this.activeIndex,
    required this.darkModeSelected,
    required this.onClose,
    required this.onSelected,
    required this.onNavigationItemSelected,
    required this.onModeChanged,
  });

  final double width;
  final List<PateezNavItem> items;
  final AppShellData shellData;
  final int activeIndex;
  final bool darkModeSelected;
  final VoidCallback onClose;
  final ValueChanged<int> onSelected;
  final ValueChanged<AppShellNavigationItem> onNavigationItemSelected;
  final ValueChanged<bool> onModeChanged;

  @override
  State<PateezSideMenu> createState() => _PateezSideMenuState();
}

class _PateezSideMenuState extends State<PateezSideMenu> {
  var _defaultRootApplied = false;
  final _openRootIds = <String>{};

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.viewPaddingOf(context).top;
    final topItems = _topMenuItems(widget.shellData);
    final sidebarItems = widget.shellData.sidebarNavigationItems;

    return SizedBox(
      width: widget.width,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(right: BorderSide(color: AppColors.softLine)),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, topInset + 10, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _MenuHeader(
                settings: widget.shellData.siteSettings,
                onClose: widget.onClose,
              ),
              const SizedBox(height: AppSpacing.xl),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ...(topItems.isEmpty
                          ? _quickRows(widget.items)
                          : topItems.map(_navigationRow)),
                      if (sidebarItems.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xl),
                        ..._sidebarRows(sidebarItems),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Align(
                alignment: Alignment.centerRight,
                child: _ModeToggle(
                  darkModeSelected: widget.darkModeSelected,
                  onModeChanged: widget.onModeChanged,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _quickRows(List<PateezNavItem> items, {int startIndex = 0}) {
    return List.generate(items.length, (offset) {
      final index = startIndex + offset;
      return _QuickMenuRow(
        item: items[offset],
        selected: index == widget.activeIndex,
        onTap: () => widget.onSelected(index),
      );
    });
  }

  Widget _navigationRow(AppShellNavigationItem item) {
    return _NavigationMenuRow(
      item: item,
      selected: _isNavigationSelected(item),
      onTap: () => widget.onNavigationItemSelected(item),
    );
  }

  List<AppShellNavigationItem> _topMenuItems(AppShellData shellData) {
    final topItems = shellData.topNavigationItems;
    final promotedCategories = shellData.sidebarNavigationItems
        .where(
          (item) =>
              item.parentId != null &&
              _isCategoryNavigationType(item.type) &&
              !_isHomeNavigationItem(item),
        )
        .toList(growable: false);
    if (promotedCategories.isEmpty) return topItems;

    final seen = <String>{};
    final result = <AppShellNavigationItem>[];
    for (final item in [...topItems, ...promotedCategories]) {
      final key = _navigationDedupKey(item);
      if (!seen.add(key)) continue;
      result.add(item);
    }
    return result;
  }

  List<Widget> _sidebarRows(List<AppShellNavigationItem> items) {
    final roots = items
        .where((item) => item.parentId == null || item.parentId == 'root')
        .toList(growable: false);
    if (roots.isEmpty) {
      return items.map(_navigationRow).toList(growable: false);
    }
    if (!_defaultRootApplied) {
      _openRootIds.add(roots.first.id);
      _defaultRootApplied = true;
    }

    return roots
        .expand((root) {
          final children =
              items
                  .where((item) => item.parentId == root.id)
                  .toList(growable: false)
                ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
          final hasChildren = children.isNotEmpty;
          final isOpen = _openRootIds.contains(root.id);

          return [
            _NavigationMenuRow(
              item: root,
              selected: widget.activeIndex == 0,
              trailing: hasChildren
                  ? AnimatedRotation(
                      turns: isOpen ? 0.5 : 0,
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOutCubic,
                      child: const Icon(
                        Symbols.keyboard_arrow_down_rounded,
                        size: 16,
                        color: AppColors.iconMuted,
                      ),
                    )
                  : null,
              onTap: () {
                if (!hasChildren) {
                  widget.onNavigationItemSelected(root);
                  return;
                }
                setState(() {
                  if (isOpen) {
                    _openRootIds.remove(root.id);
                  } else {
                    _openRootIds.add(root.id);
                  }
                });
              },
            ),
            if (hasChildren && isOpen) ..._groupedChildRows(children),
          ];
        })
        .toList(growable: false);
  }

  List<Widget> _groupedChildRows(List<AppShellNavigationItem> children) {
    final districts = children.where((item) => item.type == 'district');
    final trends = children.where((item) => item.type == 'trends');
    final other = children.where(
      (item) =>
          item.type != 'district' &&
          !_isCategoryNavigationType(item.type) &&
          item.type != 'trends',
    );

    return [
      if (districts.isNotEmpty) ...[
        const _GroupHeader('İlçeler'),
        ..._childRows(districts),
      ],
      if (trends.isNotEmpty) ...[
        const SizedBox(height: 6),
        const _GroupHeader('Trendler'),
        ..._childRows(trends),
      ],
      if (other.isNotEmpty) ...[
        const SizedBox(height: 6),
        ..._childRows(other),
      ],
    ];
  }

  bool _isCategoryNavigationType(String type) {
    final normalized = type.trim().toLowerCase();
    return normalized == 'category' ||
        normalized == 'dropdown' ||
        normalized == 'link';
  }

  bool _isHomeNavigationItem(AppShellNavigationItem item) {
    final key = '${item.label} ${item.value}'.trim().toLowerCase();
    return item.value == '/' ||
        key.contains('ana sayfa') ||
        key.contains('anasayfa') ||
        key.contains('home');
  }

  String _navigationDedupKey(AppShellNavigationItem item) {
    final value = item.value.trim().toLowerCase();
    final label = item.label.trim().toLowerCase();
    final key = value.isNotEmpty ? value : label;
    return '${item.type.trim().toLowerCase()}:$key';
  }

  List<Widget> _childRows(Iterable<AppShellNavigationItem> items) {
    return items
        .map(
          (item) => _NavigationMenuRow(
            item: item,
            dense: true,
            selected: _isNavigationSelected(item),
            onTap: () => widget.onNavigationItemSelected(item),
          ),
        )
        .toList(growable: false);
  }

  bool _isNavigationSelected(AppShellNavigationItem item) {
    final key = '${item.label} ${item.value} ${item.type}'.toLowerCase();
    if (widget.activeIndex == 0) {
      return item.value == '/' ||
          key.contains('ana sayfa') ||
          key.contains('home');
    }
    if (widget.activeIndex == 1) return key.contains('video');
    if (widget.activeIndex == 2) {
      return item.type == 'category' && !key.contains('video');
    }
    if (widget.activeIndex == 3) {
      return key.contains('arama') || key.contains('search');
    }
    return false;
  }
}

class _MenuHeader extends StatelessWidget {
  const _MenuHeader({required this.settings, required this.onClose});

  final AppShellSettings settings;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          Expanded(child: _SideMenuBrand(settings: settings)),
          _PlainIconButton(
            icon: Symbols.close_rounded,
            tooltip: 'Kapat',
            semanticLabel: 'Menüyü kapat',
            onTap: onClose,
          ),
        ],
      ),
    );
  }
}

class _SideMenuBrand extends StatelessWidget {
  const _SideMenuBrand({required this.settings});

  final AppShellSettings settings;

  @override
  Widget build(BuildContext context) {
    final logoUrl = settings.lightSurfaceLogoUrl;
    final fallbackLogo = Image.asset(
      DefaultBrandAssets.logo,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      semanticLabel: settings.siteName.isEmpty
          ? 'Pateeznews'
          : settings.siteName,
      errorBuilder: (_, _, _) => _SideMenuWordmark(siteName: settings.siteName),
    );
    if (logoUrl.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(height: 32, child: fallbackLogo),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        height: 32,
        child: Image.network(
          logoUrl,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          semanticLabel: settings.siteName.isEmpty
              ? 'Pateeznews'
              : settings.siteName,
          errorBuilder: (context, error, stackTrace) {
            return fallbackLogo;
          },
        ),
      ),
    );
  }
}

class _SideMenuWordmark extends StatelessWidget {
  const _SideMenuWordmark({required this.siteName});

  final String siteName;

  @override
  Widget build(BuildContext context) {
    final normalized = siteName.toLowerCase().replaceAll(' ', '');
    if (normalized.isNotEmpty && !normalized.contains('pateez')) {
      return Text(
        siteName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontFamily: 'PateezInter',
          color: AppColors.inkStrong,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
          height: 1,
        ),
      );
    }

    return const Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'pateez',
            style: TextStyle(
              fontFamily: 'PateezInter',
              color: AppColors.inkStrong,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
              height: 1,
            ),
          ),
          TextSpan(
            text: 'news',
            style: TextStyle(
              fontFamily: 'PateezInter',
              color: AppColors.accentAction,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
              height: 1,
            ),
          ),
          TextSpan(
            text: '.',
            style: TextStyle(
              fontFamily: 'PateezInter',
              color: AppColors.warmHorizon,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 3, top: 6, bottom: 5),
      child: Text(
        label,
        textAlign: TextAlign.left,
        style: AppTypography.eyebrow.copyWith(
          color: AppColors.placeholder,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
          decoration: TextDecoration.none,
          decorationColor: Colors.transparent,
        ),
      ),
    );
  }
}

class _QuickMenuRow extends StatelessWidget {
  const _QuickMenuRow({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final PateezNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _MenuRowShell(
      label: item.label,
      icon: selected ? item.activeIcon : item.icon,
      selected: selected,
      onTap: onTap,
    );
  }
}

class _NavigationMenuRow extends StatelessWidget {
  const _NavigationMenuRow({
    required this.item,
    required this.selected,
    required this.onTap,
    this.trailing,
    this.dense = false,
  });

  final AppShellNavigationItem item;
  final bool selected;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return _MenuRowShell(
      label: item.label,
      icon: _iconFor(item.icon, type: item.type, selected: selected),
      selected: selected,
      dense: dense,
      trailing: trailing,
      onTap: onTap,
    );
  }
}

class _MenuRowShell extends StatelessWidget {
  const _MenuRowShell({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.trailing,
    this.dense = false,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AppColors.inkStrong : AppColors.inkSoft;
    final iconColor = selected ? AppColors.actionRed : AppColors.iconMuted;

    return Semantics(
      label: label,
      selected: selected,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          mouseCursor: SystemMouseCursors.click,
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: dense ? 34 : 38,
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: dense ? 13 : 15,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.actionRed : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                SizedBox(width: dense ? AppSpacing.md : AppSpacing.lg),
                Icon(icon, size: dense ? 16 : 18, color: iconColor),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.navLabel.copyWith(
                      color: foreground,
                      fontSize: dense ? 12.8 : 13.8,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({
    required this.darkModeSelected,
    required this.onModeChanged,
  });

  final bool darkModeSelected;
  final ValueChanged<bool> onModeChanged;

  @override
  Widget build(BuildContext context) {
    final icon = darkModeSelected ? Symbols.moon_rounded : Symbols.sun_rounded;
    final label = darkModeSelected ? 'Dark mod' : 'Normal mod';
    final color = darkModeSelected ? AppColors.deepOcean : AppColors.actionRed;

    return _PlainIconButton(
      icon: icon,
      tooltip: label,
      semanticLabel: label,
      color: color,
      onTap: () => onModeChanged(!darkModeSelected),
    );
  }
}

class _PlainIconButton extends StatelessWidget {
  const _PlainIconButton({
    required this.icon,
    required this.tooltip,
    required this.semanticLabel,
    required this.onTap,
    this.color = AppColors.iconStrong,
  });

  final IconData icon;
  final String tooltip;
  final String semanticLabel;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        label: semanticLabel,
        button: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            mouseCursor: SystemMouseCursors.click,
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(icon, size: 21, color: color),
            ),
          ),
        ),
      ),
    );
  }
}

IconData _iconFor(String name, {required String type, required bool selected}) {
  final key = name.trim().toLowerCase();
  final normalizedType = type.trim().toLowerCase();
  if (key == 'home' || key == 'house') {
    return selected ? Symbols.home_rounded : Symbols.home_outlined;
  }
  if (key.contains('video') || key == 'smart_display') {
    return selected
        ? Symbols.play_circle_rounded
        : Symbols.play_circle_outline_rounded;
  }
  if (key == 'poll' || key == 'quiz') return Symbols.apps;
  if (key == 'calendar_month' || key == 'event') return Symbols.schedule;
  if (key == 'location_on' ||
      key == 'where_to_vote' ||
      normalizedType == 'district') {
    return Symbols.location_on_rounded;
  }
  if (key == 'trending_up' || normalizedType == 'trends') {
    return Symbols.trending_up_rounded;
  }
  if (key == 'auto_stories') return Symbols.menu_book_rounded;
  if (key == 'forum') return Symbols.forum_outlined;
  if (key == 'favorite') return Symbols.favorite_outline_rounded;
  if (key == 'share') return Symbols.ios_share_rounded;
  if (key == 'account_balance') return Symbols.newspaper;
  if (key == 'spa') return Symbols.sparkling_fill;
  if (normalizedType == 'category') return Symbols.grid_view_outlined;
  return Symbols.grid_view_outlined;
}
