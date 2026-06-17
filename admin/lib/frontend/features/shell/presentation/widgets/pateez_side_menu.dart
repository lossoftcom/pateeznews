import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/navigation_icon_resolver.dart';
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
    required this.onPagesSelected,
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
  final ValueChanged<AppShellNavigationItem?> onPagesSelected;
  final ValueChanged<bool> onModeChanged;

  @override
  State<PateezSideMenu> createState() => _PateezSideMenuState();
}

class _PateezSideMenuState extends State<PateezSideMenu> {
  final _scrollController = ScrollController();
  final _closedRootIds = <String>{};
  String? _selectedRootId;
  var _rootPickerOpen = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.viewPaddingOf(context).top;
    final sidebarItems = widget.shellData.sidebarNavigationItems;
    final topItems = widget.shellData.topNavigationItems;
    final selectedRoot = _currentRoot(sidebarItems);

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
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (sidebarItems.isNotEmpty)
                        ..._sidebarRows(sidebarItems),
                      if (sidebarItems.isEmpty)
                        ...(topItems.isEmpty
                            ? _quickRows(widget.items)
                            : topItems.map(_navigationRow)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  if (widget.shellData.pages.isNotEmpty)
                    _AboutMenuLink(
                      onTap: () => widget.onPagesSelected(selectedRoot),
                    ),
                  const Spacer(),
                  _ModeToggle(
                    darkModeSelected: widget.darkModeSelected,
                    onModeChanged: widget.onModeChanged,
                  ),
                ],
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

  AppShellNavigationItem? _currentRoot(List<AppShellNavigationItem> items) {
    final roots = items
        .where((item) => item.parentId == null || item.parentId == 'root')
        .toList(growable: false);
    if (roots.isEmpty) return null;
    final currentId = _selectedRootId;
    if (currentId == null) return roots.first;
    return roots.firstWhere(
      (root) => root.id == currentId,
      orElse: () => roots.first,
    );
  }

  List<Widget> _sidebarRows(List<AppShellNavigationItem> items) {
    final roots = items
        .where((item) => item.parentId == null || item.parentId == 'root')
        .toList(growable: false);
    if (roots.isEmpty) {
      return items.map(_navigationRow).toList(growable: false);
    }
    final selectedRoot = _selectedRoot(roots);
    final children =
        items
            .where((item) => item.parentId == selectedRoot.id)
            .toList(growable: false)
          ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    final hasChildren = children.isNotEmpty;
    final childrenOpen = !_closedRootIds.contains(selectedRoot.id);

    return [
      _NavigationMenuRow(
        item: selectedRoot,
        selected: widget.activeIndex == 0,
        trailing: hasChildren
            ? AnimatedRotation(
                turns: childrenOpen ? 0.5 : 0,
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOutCubic,
                child: const Icon(
                  Symbols.keyboard_arrow_down_rounded,
                  size: 16,
                  color: AppColors.iconMuted,
                ),
              )
            : null,
        onTrailingTap: hasChildren
            ? () {
                setState(() {
                  _rootPickerOpen = false;
                  if (childrenOpen) {
                    _closedRootIds.add(selectedRoot.id);
                  } else {
                    _closedRootIds.remove(selectedRoot.id);
                  }
                });
                _scrollMenuToTop();
              }
            : null,
        onTap: () {
          if (roots.length <= 1) {
            if (!hasChildren) {
              widget.onNavigationItemSelected(selectedRoot);
              return;
            }
            setState(() {
              if (childrenOpen) {
                _closedRootIds.add(selectedRoot.id);
              } else {
                _closedRootIds.remove(selectedRoot.id);
              }
            });
          } else {
            setState(() => _rootPickerOpen = !_rootPickerOpen);
          }
          _scrollMenuToTop();
        },
      ),
      if (_rootPickerOpen) ..._rootPickerRows(roots, selectedRoot),
      if (!_rootPickerOpen && childrenOpen) ..._groupedChildRows(children),
    ];
  }

  AppShellNavigationItem _selectedRoot(List<AppShellNavigationItem> roots) {
    final currentId = _selectedRootId;
    final selected = currentId == null
        ? roots.first
        : roots.firstWhere(
            (root) => root.id == currentId,
            orElse: () => roots.first,
          );
    _selectedRootId = selected.id;
    return selected;
  }

  List<Widget> _rootPickerRows(
    List<AppShellNavigationItem> roots,
    AppShellNavigationItem selectedRoot,
  ) {
    return roots
        .where((root) => root.id != selectedRoot.id)
        .map(
          (root) => _NavigationMenuRow(
            item: root,
            dense: true,
            selected: false,
            onTap: () {
              setState(() {
                _selectedRootId = root.id;
                _rootPickerOpen = false;
                _closedRootIds.remove(root.id);
              });
              _scrollMenuToTop();
            },
          ),
        )
        .toList(growable: false);
  }

  void _scrollMenuToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      );
    });
  }

  List<Widget> _groupedChildRows(List<AppShellNavigationItem> children) {
    final districts = children.where((item) => item.type == 'district');
    final categories = children.where(
      (item) => _isCategoryNavigationType(item.type),
    );
    final trends = children.where((item) => item.type == 'trends');
    final other = children.where(
      (item) =>
          item.type != 'district' &&
          !_isCategoryNavigationType(item.type) &&
          item.type != 'trends',
    );
    final menuItems = categories.toList(growable: false);

    return [
      if (menuItems.isNotEmpty) ..._childRows(menuItems),
      if (districts.isNotEmpty) ...[
        if (menuItems.isNotEmpty) const SizedBox(height: 6),
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
          ? 'Pateez'
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
        child: Semantics(
          image: true,
          label: settings.siteName.isEmpty ? 'Pateez' : settings.siteName,
          child: CachedNetworkImage(
            imageUrl: logoUrl,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            fadeInDuration: Duration.zero,
            placeholderFadeInDuration: Duration.zero,
            errorWidget: (context, url, error) => fallbackLogo,
          ),
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
    this.onTrailingTap,
    this.dense = false,
  });

  final AppShellNavigationItem item;
  final bool selected;
  final VoidCallback onTap;
  final Widget? trailing;
  final VoidCallback? onTrailingTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return _MenuRowShell(
      label: item.label,
      icon: _iconFor(item.icon, type: item.type, selected: selected),
      selected: selected,
      dense: dense,
      trailing: trailing,
      onTrailingTap: onTrailingTap,
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
    this.onTrailingTap,
    this.dense = false,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final Widget? trailing;
  final VoidCallback? onTrailingTap;
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
                if (trailing != null)
                  _MenuTrailingControl(onTap: onTrailingTap, child: trailing!),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuTrailingControl extends StatelessWidget {
  const _MenuTrailingControl({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (onTap == null) return child;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.square(dimension: 32, child: Center(child: child)),
      ),
    );
  }
}

class _AboutMenuLink extends StatelessWidget {
  const _AboutMenuLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        mouseCursor: SystemMouseCursors.click,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(
            'Hakkımızda',
            style: AppTypography.navLabel.copyWith(
              color: AppColors.support,
              fontSize: 12.2,
              fontWeight: FontWeight.w500,
              decoration: TextDecoration.none,
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
  return resolveNavigationIcon(
    name,
    type: type,
    selected: selected,
    fallback: Symbols.grid_view_outlined,
  );
}
