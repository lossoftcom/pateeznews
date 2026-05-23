import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../core/localization/admin_language_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/widgets/app_confirmation_dialog.dart';
import '../../../shared/widgets/symbol_icon.dart';
import '../data/admin_navigation_repository.dart';
import 'navigation_icon_picker.dart';
import 'navigation_models.dart';

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({
    super.key,
    this.repository = const NeonAdminNavigationRepository(),
  });

  final AdminNavigationRepository repository;

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

enum _NavigationSurface { sidebar, topNavbar }

extension _NavigationSurfaceData on _NavigationSurface {
  String get code {
    return switch (this) {
      _NavigationSurface.sidebar => 'sidebar_main',
      _NavigationSurface.topNavbar => 'top_navbar',
    };
  }

  String get labelKey {
    return switch (this) {
      _NavigationSurface.sidebar => 'navigation.surface.sidebar',
      _NavigationSurface.topNavbar => 'navigation.surface.topNavbar',
    };
  }

  String get descriptionKey {
    return switch (this) {
      _NavigationSurface.sidebar => 'navigation.surface.sidebarDescription',
      _NavigationSurface.topNavbar => 'navigation.surface.topNavbarDescription',
    };
  }
}

_NavigationSurface _surfaceFromCode(String code) {
  return code == _NavigationSurface.topNavbar.code
      ? _NavigationSurface.topNavbar
      : _NavigationSurface.sidebar;
}

class _NavigationScreenState extends State<NavigationScreen> {
  var _menus = const <AdminNavigationMenu>[];
  var _items = const <AdminNavigationItem>[];
  var _languages = const <AdminNavigationLanguage>[];
  var _activeSurface = _NavigationSurface.sidebar;
  String? _activeMenuId;
  var _loading = true;
  var _saving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    unawaited(_loadInitial());
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _errorText = null;
    });
    try {
      final initial = await widget.repository.fetchInitialData();
      final activeMenu = _menuForSurface(initial.menus, _activeSurface);
      final activeMenuId = activeMenu?.id;
      final items = activeMenuId == null
          ? const <AdminNavigationItem>[]
          : await widget.repository.fetchItems(activeMenuId);
      if (!mounted) return;
      setState(() {
        _menus = initial.menus;
        _languages = initial.languages;
        _activeMenuId = activeMenuId;
        _items = items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadItems(String menuId) async {
    setState(() {
      _activeMenuId = menuId;
      _loading = true;
      _errorText = null;
    });
    try {
      final items = await widget.repository.fetchItems(menuId);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _selectSurface(_NavigationSurface surface) async {
    if (_activeSurface == surface && !_loading) return;
    setState(() {
      _activeSurface = surface;
      _activeMenuId = _menuForSurface(_menus, surface)?.id;
      _items = const [];
      _loading = true;
      _errorText = null;
    });
    try {
      var menu = _menuForSurface(_menus, surface);
      if (menu == null && surface == _NavigationSurface.topNavbar) {
        menu = await _ensureSurfaceMenu(surface);
      }
      if (!mounted) return;
      if (menu == null) {
        setState(() => _loading = false);
        return;
      }
      final items = await widget.repository.fetchItems(menu.id);
      if (!mounted) return;
      setState(() {
        _activeMenuId = menu!.id;
        _items = items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = error.toString();
        _loading = false;
      });
    }
  }

  Future<AdminNavigationMenu?> _ensureSurfaceMenu(
    _NavigationSurface surface,
  ) async {
    final existing = _menuForSurface(_menus, surface);
    if (existing != null) return existing;
    final menu = await widget.repository.ensureDefaultMenu(surface.code);
    final initial = await widget.repository.fetchInitialData();
    if (!mounted) return menu;
    setState(() => _menus = initial.menus);
    return _menuForSurface(initial.menus, surface) ?? menu;
  }

  Future<void> _openItemDialog([AdminNavigationItem? item]) async {
    final initialMenuCode = item == null
        ? _activeSurface.code
        : _menuCodeForId(item.menuId);
    final result = await showDialog<_NavigationItemDialogResult>(
      context: context,
      barrierDismissible: !_saving,
      builder: (context) => _NavigationItemDialog(
        item: item,
        languages: _languages,
        menuItemsByCode: {if (_activeMenu != null) _activeMenu!.code: _items},
        initialMenuCode: initialMenuCode ?? _activeSurface.code,
        currentLanguageCode: AdminLocalizationScope.of(context).code,
      ),
    );
    if (result == null) return;

    setState(() {
      _saving = true;
      _errorText = null;
    });
    try {
      final targetSurface = _surfaceFromCode(result.menuCode);
      final targetMenu = await _ensureSurfaceMenu(targetSurface);
      if (targetMenu == null) return;
      final targetItems = targetMenu.id == _activeMenuId
          ? _items
          : await widget.repository.fetchItems(targetMenu.id);
      final orderIndex = item == null
          ? targetItems.length
          : item.menuId == targetMenu.id
          ? item.orderIndex
          : targetItems.length;
      if (item == null) {
        await widget.repository.createItem(
          menuId: targetMenu.id,
          data: result.data,
          orderIndex: orderIndex,
        );
      } else {
        await widget.repository.updateItem(
          itemId: item.id,
          menuId: targetMenu.id,
          orderIndex: orderIndex,
          data: result.data,
        );
      }
      final activeMenuId = _activeMenuId;
      if (activeMenuId == null) {
        await _loadInitial();
      } else {
        await _loadItems(activeMenuId);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = error.toString();
        _loading = false;
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteItem(AdminNavigationItem item) async {
    final ids = _itemAndDescendantIds(item.id);
    final confirmed = await showAppConfirmationDialog(
      context,
      title: context.t('navigation.deleteTitle'),
      message: context.t(
        'navigation.deleteMessage',
        values: {'label': item.label, 'count': ids.length},
      ),
      confirmLabel: context.t('Delete'),
      danger: true,
    );
    if (!confirmed) return;

    setState(() {
      _saving = true;
      _errorText = null;
    });
    try {
      await widget.repository.deleteItems(ids.reversed.toList(growable: false));
      final activeMenuId = _activeMenuId;
      if (activeMenuId != null) await _loadItems(activeMenuId);
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorText = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _reorderItems(int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) return;
    final activeMenuId = _activeMenuId;
    if (activeMenuId == null) return;

    final reordered = [..._items];
    final item = reordered.removeAt(oldIndex);
    final normalizedIndex = newIndex.clamp(0, reordered.length);
    reordered.insert(normalizedIndex, item);
    final numbered = [
      for (var index = 0; index < reordered.length; index++)
        reordered[index].copyWith(orderIndex: index),
    ];
    setState(() => _items = numbered);

    try {
      await widget.repository.reorderItems(numbered);
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorText = error.toString());
      await _loadItems(activeMenuId);
    }
  }

  List<String> _itemAndDescendantIds(String itemId) {
    final ids = <String>[itemId];
    void collect(String parentId) {
      for (final item in _items.where((item) => item.parentId == parentId)) {
        ids.add(item.id);
        collect(item.id);
      }
    }

    collect(itemId);
    return ids;
  }

  AdminNavigationMenu? get _activeMenu {
    return _menuForSurface(_menus, _activeSurface);
  }

  AdminNavigationMenu? _menuForSurface(
    List<AdminNavigationMenu> menus,
    _NavigationSurface surface,
  ) {
    for (final menu in menus) {
      if (menu.code == surface.code) return menu;
    }
    return null;
  }

  String? _menuCodeForId(String menuId) {
    for (final menu in _menus) {
      if (menu.id == menuId) return menu.code;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 640 ? 16.0 : 28.0;
        final body = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _NavigationHeader(
              canAdd: true,
              saving: _saving,
              onAdd: () => unawaited(_openItemDialog()),
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 20),
              _NavigationErrorBanner(message: _errorText!),
            ],
            const SizedBox(height: 22),
            _NavigationWorkspace(
              activeSurface: _activeSurface,
              onSelected: (surface) => unawaited(_selectSurface(surface)),
              panel: _NavigationItemsPanel(
                items: _items,
                loading: _loading,
                activeMenu: _activeMenu,
                canAdd: true,
                onAdd: () => unawaited(_openItemDialog()),
                onEdit: (item) => unawaited(_openItemDialog(item)),
                onDelete: (item) => unawaited(_deleteItem(item)),
                onReorder: (oldIndex, newIndex) =>
                    unawaited(_reorderItems(oldIndex, newIndex)),
              ),
            ),
          ],
        );

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            28,
            horizontalPadding,
            32,
          ),
          child: body,
        );
      },
    );
  }
}

class _NavigationWorkspace extends StatelessWidget {
  const _NavigationWorkspace({
    required this.activeSurface,
    required this.onSelected,
    required this.panel,
  });

  final _NavigationSurface activeSurface;
  final ValueChanged<_NavigationSurface> onSelected;
  final Widget panel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final selector = _NavigationSurfaceTabs(
          activeSurface: activeSurface,
          onSelected: onSelected,
        );
        if (constraints.maxWidth < 860) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [selector, const SizedBox(height: 18), panel],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 284, child: selector),
            const SizedBox(width: 24),
            Expanded(child: panel),
          ],
        );
      },
    );
  }
}

class _NavigationHeader extends StatelessWidget {
  const _NavigationHeader({
    required this.canAdd,
    required this.saving,
    required this.onAdd,
  });

  final bool canAdd;
  final bool saving;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 640;
        final title = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t('navigation.title'),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.deepOcean,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.t('navigation.description'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.inkSoft,
                fontWeight: FontWeight.w500,
                letterSpacing: 0,
              ),
            ),
          ],
        );
        final addButton = _NavigationAddButton(
          enabled: canAdd && !saving,
          onPressed: onAdd,
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              title,
              const SizedBox(height: 16),
              Align(alignment: Alignment.centerLeft, child: addButton),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: title),
            const SizedBox(width: 20),
            addButton,
          ],
        );
      },
    );
  }
}

class _NavigationSurfaceTabs extends StatelessWidget {
  const _NavigationSurfaceTabs({
    required this.activeSurface,
    required this.onSelected,
  });

  final _NavigationSurface activeSurface;
  final ValueChanged<_NavigationSurface> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.t('navigation.editableMenuLabel'),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.deepOcean,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 10),
        for (final surface in _NavigationSurface.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _NavigationSurfaceTab(
              label: context.t(surface.labelKey),
              description: context.t(surface.descriptionKey),
              selected: activeSurface == surface,
              onTap: () => onSelected(surface),
            ),
          ),
      ],
    );
  }
}

class _NavigationSurfaceTab extends StatelessWidget {
  const _NavigationSurfaceTab({
    required this.label,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          constraints: const BoxConstraints(minHeight: 76),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: selected ? AppColors.deepOcean : Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.value),
            border: Border.all(
              color: selected ? AppColors.deepOcean : AppColors.line,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.deepOcean.withValues(alpha: 0.14),
                      blurRadius: 22,
                      offset: const Offset(0, 12),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? Colors.white : AppColors.deepOcean,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected
                            ? Colors.white.withValues(alpha: 0.68)
                            : AppColors.inkSoft,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        height: 1.25,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SymbolIcon(
                selected ? Symbols.check : Symbols.arrow_forward,
                color: selected ? Colors.white : AppColors.iconMuted,
                size: selected ? 16 : 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavigationItemsPanel extends StatelessWidget {
  const _NavigationItemsPanel({
    required this.items,
    required this.loading,
    required this.activeMenu,
    required this.canAdd,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onReorder,
  });

  final List<AdminNavigationItem> items;
  final bool loading;
  final AdminNavigationMenu? activeMenu;
  final bool canAdd;
  final VoidCallback onAdd;
  final ValueChanged<AdminNavigationItem> onEdit;
  final ValueChanged<AdminNavigationItem> onDelete;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 500),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line),
      ),
      child: loading
          ? const SizedBox(
              height: 260,
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.deepOcean,
                  ),
                ),
              ),
            )
          : activeMenu == null || items.isEmpty
          ? _EmptyItemsState(canAdd: canAdd, onAdd: onAdd)
          : ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              onReorderItem: onReorder,
              proxyDecorator: (child, _, animation) {
                return AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) {
                    return Material(
                      color: Colors.transparent,
                      child: Transform.scale(
                        scale: 1 + (animation.value * 0.015),
                        child: child,
                      ),
                    );
                  },
                  child: child,
                );
              },
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return _NavigationItemTile(
                  key: ValueKey(item.id),
                  item: item,
                  index: index,
                  depth: _itemDepth(item, items),
                  parent: _parentFor(item, items),
                  onEdit: () => onEdit(item),
                  onDelete: () => onDelete(item),
                );
              },
            ),
    );
  }
}

class _NavigationItemTile extends StatelessWidget {
  const _NavigationItemTile({
    super.key,
    required this.item,
    required this.index,
    required this.depth,
    required this.parent,
    required this.onEdit,
    required this.onDelete,
  });

  final AdminNavigationItem item;
  final int index;
  final int depth;
  final AdminNavigationItem? parent;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final left = (depth * 36.0).clamp(0.0, 108.0);
    return Padding(
      padding: EdgeInsets.only(left: left, bottom: 9),
      child: Container(
        constraints: const BoxConstraints(minHeight: 68),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(AppRadius.value),
          border: Border.all(color: AppColors.line.withValues(alpha: 0.88)),
        ),
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: index,
              child: const MouseRegion(
                cursor: SystemMouseCursors.grab,
                child: SizedBox(
                  width: 24,
                  child: Text(
                    '⋮⋮',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.support,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1,
                    ),
                  ),
                ),
              ),
            ),
            if (depth > 0) ...[
              const SizedBox(width: 8),
              const Text(
                '\u21B3',
                style: TextStyle(
                  color: AppColors.support,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(width: 10),
            _TypeIconBox(type: item.type),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.deepOcean,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                      if (parent != null) ...[
                        const SizedBox(width: 8),
                        _SoftPill(
                          label:
                              '${context.t('navigation.parentMenuShort')}: ${parent!.label}',
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 7,
                    runSpacing: 5,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _TypePill(label: context.t(item.typeKey)),
                      if (item.value.isNotEmpty)
                        _ValueLabel(value: _valueLabel(context, item.value)),
                      if (item.icon.isNotEmpty)
                        _SoftPill(label: item.icon.replaceAll('_', ' ')),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _IconActionButton(
              tooltip: context.t('common.edit'),
              icon: Symbols.edit_square,
              onPressed: onEdit,
            ),
            const SizedBox(width: 4),
            _IconActionButton(
              tooltip: context.t('common.delete'),
              icon: Symbols.delete,
              danger: true,
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyItemsState extends StatelessWidget {
  const _EmptyItemsState({required this.canAdd, required this.onAdd});

  final bool canAdd;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 260,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SymbolIcon(
              Symbols.format_list_numbered,
              color: AppColors.iconMuted,
              size: 28,
            ),
            const SizedBox(height: 12),
            Text(
              context.t('navigation.emptyItems'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.inkSoft,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
            if (canAdd) ...[
              const SizedBox(height: 14),
              _NavigationAddButton(enabled: true, onPressed: onAdd),
            ],
          ],
        ),
      ),
    );
  }
}

class _NavigationAddButton extends StatelessWidget {
  const _NavigationAddButton({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: TextButton(
        onPressed: enabled ? onPressed : null,
        style:
            TextButton.styleFrom(
              backgroundColor: AppColors.actionRed,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 38),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.value),
              ),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ).copyWith(
              mouseCursor: const WidgetStatePropertyAll(
                SystemMouseCursors.click,
              ),
            ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SymbolIcon(Symbols.add, color: Colors.white, size: 17),
            const SizedBox(width: 7),
            Text(context.t('navigation.addItem')),
          ],
        ),
      ),
    );
  }
}

class _NavigationErrorBanner extends StatelessWidget {
  const _NavigationErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.actionRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.actionRed.withValues(alpha: 0.18)),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.actionRed,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _TypeIconBox extends StatelessWidget {
  const _TypeIconBox({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(type);
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.value),
      ),
      child: SymbolIcon(_typeIcon(type), color: color, size: 19),
    );
  }
}

class _TypePill extends StatelessWidget {
  const _TypePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.deepOcean.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(AppRadius.value),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _SoftPill extends StatelessWidget {
  const _SoftPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.softLine.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(AppRadius.value),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.support,
            fontSize: 10,
            fontWeight: FontWeight.w500,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _ValueLabel extends StatelessWidget {
  const _ValueLabel({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.support,
            borderRadius: BorderRadius.circular(AppRadius.value),
          ),
        ),
        const SizedBox(width: 5),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.support,
              fontSize: 10,
              fontWeight: FontWeight.w400,
              height: 1,
            ),
          ),
        ),
      ],
    );
  }
}

class _IconActionButton extends StatelessWidget {
  const _IconActionButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.danger = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.actionRed : AppColors.inkSoft;
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        constraints: const BoxConstraints.tightFor(width: 34, height: 34),
        padding: EdgeInsets.zero,
        icon: SymbolIcon(icon, color: color, size: 18),
      ),
    );
  }
}

class _NavigationItemDialogResult {
  const _NavigationItemDialogResult({
    required this.menuCode,
    required this.data,
  });

  final String menuCode;
  final NavigationItemFormData data;
}

class _NavigationItemDialog extends StatefulWidget {
  const _NavigationItemDialog({
    required this.item,
    required this.languages,
    required this.menuItemsByCode,
    required this.initialMenuCode,
    required this.currentLanguageCode,
  });

  final AdminNavigationItem? item;
  final List<AdminNavigationLanguage> languages;
  final Map<String, List<AdminNavigationItem>> menuItemsByCode;
  final String initialMenuCode;
  final String currentLanguageCode;

  @override
  State<_NavigationItemDialog> createState() => _NavigationItemDialogState();
}

class _NavigationItemDialogState extends State<_NavigationItemDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _labelController;
  late final TextEditingController _valueController;
  late final TextEditingController _iconController;
  late String _type;
  late String _parentId;
  late String _languageCode;
  late String _menuCode;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _labelController = TextEditingController(text: item?.label ?? '');
    _valueController = TextEditingController(text: item?.value ?? '');
    _iconController = TextEditingController(text: item?.icon ?? '');
    _type = item?.type ?? 'link';
    _parentId = item?.parentId ?? 'root';
    _menuCode = _surfaceFromCode(widget.initialMenuCode).code;
    _languageCode =
        item?.languageCode ??
        (widget.languages.any(
              (language) => language.code == widget.currentLanguageCode,
            )
            ? widget.currentLanguageCode
            : (widget.languages.isEmpty ? 'tr' : widget.languages.first.code));
  }

  @override
  void dispose() {
    _labelController.dispose();
    _valueController.dispose();
    _iconController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.value),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DialogHeader(
                title: widget.item == null
                    ? context.t('navigation.addItem')
                    : context.t('navigation.editItem'),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 520),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _DialogSelectField(
                        label: context.t('navigation.form.language'),
                        value: _safeLanguageValue,
                        items: [
                          if (widget.languages.isEmpty)
                            const DropdownMenuItem(
                              value: 'tr',
                              child: Text('Türkçe'),
                            ),
                          for (final language in widget.languages)
                            DropdownMenuItem(
                              value: language.code,
                              child: Text(language.name),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _languageCode = value);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      _DialogSelectField(
                        label: context.t('navigation.form.location'),
                        value: _menuCode,
                        items: [
                          for (final surface in _NavigationSurface.values)
                            DropdownMenuItem(
                              value: surface.code,
                              child: Text(context.t(surface.labelKey)),
                            ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _menuCode = _surfaceFromCode(value).code;
                            _parentId = _safeParentValue;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _labelController,
                        mouseCursor: SystemMouseCursors.text,
                        cursorColor: AppColors.support,
                        style: _dialogFieldTextStyle,
                        decoration: _dialogInputDecoration(
                          context,
                          labelText: context.t('navigation.form.label'),
                          hintText: context.t(
                            'navigation.form.labelPlaceholder',
                          ),
                        ),
                        validator: (value) {
                          final label = value?.trim() ?? '';
                          return label.isEmpty
                              ? context.t('navigation.form.labelRequired')
                              : null;
                        },
                      ),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxWidth < 420;
                          final typeField = _DialogSelectField(
                            label: context.t('navigation.form.type'),
                            value: _type,
                            items: _typeOptions(context),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _type = value);
                              }
                            },
                          );
                          final parentField = _DialogSelectField(
                            label: context.t('navigation.parentMenuShort'),
                            value: _safeParentValue,
                            items: _parentOptions(context),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _parentId = value);
                              }
                            },
                          );
                          if (compact) {
                            return Column(
                              children: [
                                typeField,
                                const SizedBox(height: 12),
                                parentField,
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(child: typeField),
                              const SizedBox(width: 14),
                              Expanded(child: parentField),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      _type == 'trends'
                          ? _DialogSelectField(
                              label: context.t('navigation.form.value'),
                              value: _safeTrendValue,
                              items: _trendOptions(context),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _valueController.text = value);
                                }
                              },
                            )
                          : TextFormField(
                              controller: _valueController,
                              mouseCursor: SystemMouseCursors.text,
                              cursorColor: AppColors.support,
                              style: _dialogFieldTextStyle,
                              decoration: _dialogInputDecoration(
                                context,
                                labelText: context.t('navigation.form.value'),
                                hintText: _type == 'link'
                                    ? '/sayfa-adi'
                                    : 'kategori-kodu',
                              ),
                            ),
                      const SizedBox(height: 12),
                      _IconPickerField(
                        controller: _iconController,
                        onTap: () async {
                          final selected = await showNavigationIconPicker(
                            context,
                            initialIcon: _iconController.text.trim(),
                          );
                          if (selected == null) return;
                          setState(() => _iconController.text = selected);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              _DialogFooter(onSave: _save),
            ],
          ),
        ),
      ),
    );
  }

  String get _safeLanguageValue {
    if (widget.languages.any((language) => language.code == _languageCode)) {
      return _languageCode;
    }
    return widget.languages.isEmpty ? 'tr' : widget.languages.first.code;
  }

  String get _safeParentValue {
    return _parentOptions(context).any((item) => item.value == _parentId)
        ? _parentId
        : 'root';
  }

  String get _safeTrendValue {
    final value = _valueController.text.trim();
    return _trendValues.contains(value) ? value : '';
  }

  List<DropdownMenuItem<String>> _typeOptions(BuildContext context) {
    return [
      DropdownMenuItem(
        value: 'link',
        child: Text(context.t('navigation.type.link')),
      ),
      DropdownMenuItem(
        value: 'dropdown',
        child: Text(context.t('navigation.type.dropdown')),
      ),
      DropdownMenuItem(
        value: 'category',
        child: Text(context.t('navigation.type.category')),
      ),
      DropdownMenuItem(
        value: 'district',
        child: Text(context.t('navigation.type.district')),
      ),
      DropdownMenuItem(
        value: 'header',
        child: Text(context.t('navigation.type.header')),
      ),
      DropdownMenuItem(
        value: 'trends',
        child: Text(context.t('navigation.type.trends')),
      ),
    ];
  }

  List<DropdownMenuItem<String>> _parentOptions(BuildContext context) {
    final excluded = _excludedParentIds();
    final options = <DropdownMenuItem<String>>[
      DropdownMenuItem(
        value: 'root',
        child: Text(context.t('navigation.rootParent')),
      ),
    ];
    final items = widget.menuItemsByCode[_menuCode] ?? const [];
    final roots = items.where((item) => item.parentId == null).toList();
    for (final root in roots) {
      if (!excluded.contains(root.id)) {
        options.add(DropdownMenuItem(value: root.id, child: Text(root.label)));
      }
      final children = items.where((item) => item.parentId == root.id);
      for (final child in children) {
        if (excluded.contains(child.id)) continue;
        options.add(
          DropdownMenuItem(value: child.id, child: Text('  ↳ ${child.label}')),
        );
      }
    }
    return options;
  }

  Set<String> _excludedParentIds() {
    final item = widget.item;
    if (item == null) return const {};
    final ids = <String>{item.id};
    final items = widget.menuItemsByCode[_menuCode] ?? const [];
    void collect(String parentId) {
      for (final child in items.where((row) => row.parentId == parentId)) {
        ids.add(child.id);
        collect(child.id);
      }
    }

    collect(item.id);
    return ids;
  }

  List<DropdownMenuItem<String>> _trendOptions(BuildContext context) {
    return [
      DropdownMenuItem(
        value: '',
        child: Text(context.t('navigation.selectTrendType')),
      ),
      DropdownMenuItem(
        value: 'weekly_trends',
        child: Text(context.t('navigation.trends.general')),
      ),
      DropdownMenuItem(
        value: 'weekly_likes',
        child: Text(context.t('navigation.trends.likes')),
      ),
      DropdownMenuItem(
        value: 'weekly_comments',
        child: Text(context.t('navigation.trends.comments')),
      ),
      DropdownMenuItem(
        value: 'weekly_shares',
        child: Text(context.t('navigation.trends.shares')),
      ),
      DropdownMenuItem(
        value: 'weekly_reads',
        child: Text(context.t('navigation.trends.reads')),
      ),
    ];
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      _NavigationItemDialogResult(
        menuCode: _menuCode,
        data: NavigationItemFormData(
          label: _labelController.text.trim(),
          type: _type,
          value: _valueController.text.trim(),
          icon: _iconController.text.trim(),
          parentId: _safeParentValue == 'root' ? null : _safeParentValue,
          languageCode: _safeLanguageValue,
        ),
      ),
    );
  }
}

class _IconPickerField extends StatelessWidget {
  const _IconPickerField({required this.controller, required this.onTap});

  final TextEditingController controller;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final value = controller.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.t('navigation.form.icon'),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.inkSoft,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 6),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.value),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.value),
                      border: Border.all(color: AppColors.softLine),
                    ),
                    child: SymbolIcon(
                      _dialogIconForName(value),
                      color: AppColors.inkSoft,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      value.isEmpty
                          ? context.t('navigation.form.iconHint')
                          : value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: value.isEmpty
                            ? AppColors.placeholder
                            : AppColors.deepOcean,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  const SymbolIcon(
                    Symbols.arrow_forward,
                    color: AppColors.iconMuted,
                    size: 17,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DialogHeader extends StatelessWidget {
  const _DialogHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 14, 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.deepOcean,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const SymbolIcon(Symbols.close, size: 20),
          ),
        ],
      ),
    );
  }
}

class _DialogFooter extends StatelessWidget {
  const _DialogFooter({required this.onSave});

  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
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
            height: 38,
            child: TextButton(
              onPressed: onSave,
              style:
                  TextButton.styleFrom(
                    backgroundColor: AppColors.deepOcean,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.value),
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
    );
  }
}

class _DialogSelectField extends StatelessWidget {
  const _DialogSelectField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final safeValue = items.any((item) => item.value == value)
        ? value
        : (items.isEmpty ? null : items.first.value);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: DropdownButtonFormField<String>(
        initialValue: safeValue,
        items: items,
        onChanged: onChanged,
        dropdownColor: Colors.white,
        isDense: true,
        isExpanded: true,
        menuMaxHeight: 320,
        style: _dialogFieldTextStyle,
        borderRadius: BorderRadius.circular(AppRadius.value),
        icon: const SymbolIcon(
          Symbols.keyboard_arrow_down,
          color: AppColors.iconMuted,
          size: 17,
        ),
        decoration: _dialogInputDecoration(context, labelText: label),
      ),
    );
  }
}

const _dialogFieldTextStyle = TextStyle(
  color: AppColors.deepOcean,
  fontSize: 13,
  fontWeight: FontWeight.w600,
  letterSpacing: 0,
);

InputDecoration _dialogInputDecoration(
  BuildContext context, {
  required String labelText,
  String? hintText,
}) {
  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    labelStyle: const TextStyle(
      color: AppColors.inkSoft,
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
    ),
    floatingLabelStyle: const TextStyle(
      color: AppColors.inkSoft,
      fontSize: 12,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    ),
    hintStyle: const TextStyle(
      color: AppColors.placeholder,
      fontSize: 13,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    ),
  );
}

int _itemDepth(AdminNavigationItem item, List<AdminNavigationItem> items) {
  if (item.parentId == null) return 0;
  final parent = _parentFor(item, items);
  if (parent == null) return 0;
  return 1 + _itemDepth(parent, items);
}

AdminNavigationItem? _parentFor(
  AdminNavigationItem item,
  List<AdminNavigationItem> items,
) {
  final parentId = item.parentId;
  if (parentId == null) return null;
  for (final candidate in items) {
    if (candidate.id == parentId) return candidate;
  }
  return null;
}

IconData _typeIcon(String type) {
  return switch (type) {
    'dropdown' => Symbols.menu,
    'category' => Symbols.folder_open,
    'district' => Symbols.language,
    'header' => Symbols.short_text,
    'trends' => Symbols.visibility,
    _ => Symbols.open_in_new,
  };
}

Color _typeColor(String type) {
  return switch (type) {
    'dropdown' => AppColors.warmHorizon,
    'category' => AppColors.deepOcean,
    'district' => const Color(0xFF7C5CE8),
    'header' => AppColors.support,
    'trends' => AppColors.actionRed,
    _ => const Color(0xFF198754),
  };
}

const _trendValues = {
  '',
  'weekly_trends',
  'weekly_likes',
  'weekly_comments',
  'weekly_shares',
  'weekly_reads',
};

String _valueLabel(BuildContext context, String value) {
  return switch (value) {
    'weekly_trends' => context.t('navigation.trends.general'),
    'weekly_likes' => context.t('navigation.trends.likes'),
    'weekly_comments' => context.t('navigation.trends.comments'),
    'weekly_shares' => context.t('navigation.trends.shares'),
    'weekly_reads' => context.t('navigation.trends.reads'),
    _ => value,
  };
}

IconData _dialogIconForName(String name) {
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
