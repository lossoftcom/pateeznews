import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../../core/localization/admin_language_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../features/settings/data/admin_language_models.dart';
import '../../../../shared/widgets/sortable_table_header.dart';
import '../../../../shared/widgets/symbol_icon.dart';

class LanguageSettingsTable extends StatelessWidget {
  const LanguageSettingsTable({
    super.key,
    required this.languages,
    required this.selectedCodes,
    required this.sortState,
    required this.onToggleCode,
    required this.onToggleAll,
    required this.onMakeDefault,
    required this.onEdit,
    required this.onToggleStatus,
    required this.onDelete,
    required this.onTranslations,
    required this.onExport,
    required this.onSort,
  });

  final List<AdminLanguage> languages;
  final Set<String> selectedCodes;
  final TableSortState sortState;
  final ValueChanged<String> onToggleCode;
  final VoidCallback onToggleAll;
  final ValueChanged<AdminLanguage> onMakeDefault;
  final ValueChanged<AdminLanguage> onEdit;
  final ValueChanged<AdminLanguage> onToggleStatus;
  final ValueChanged<AdminLanguage> onDelete;
  final ValueChanged<AdminLanguage> onTranslations;
  final ValueChanged<AdminLanguage> onExport;
  final ValueChanged<String> onSort;

  static const _activeGreen = Color(0xFF198754);
  static const _passiveGray = Color(0xFF6C757D);
  static const double _minWidth = 1040;
  static const double _selectWidth = 42;
  static const double _orderWidth = 90;
  static const double _defaultWidth = 170;
  static const double _actionsWidth = 320;
  static const double _statusWidth = 130;
  static const double _menuWidth = 88;
  static const double _columnGap = 12;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (languages.isEmpty) {
          return _EmptyLanguagesTable(onToggleAll: onToggleAll);
        }
        if (constraints.maxWidth < 800) {
          return _LanguageSettingsCardList(
            languages: languages,
            selectedCodes: selectedCodes,
            onToggleCode: onToggleCode,
            onEdit: onEdit,
            onToggleStatus: onToggleStatus,
            onDelete: onDelete,
            onMakeDefault: onMakeDefault,
            onTranslations: onTranslations,
            onExport: onExport,
          );
        }

        final tableWidth = constraints.maxWidth < _minWidth
            ? _minWidth
            : constraints.maxWidth;
        final languageWidth =
            tableWidth -
            _selectWidth -
            _orderWidth -
            _defaultWidth -
            _actionsWidth -
            _statusWidth -
            _menuWidth -
            _columnGap -
            36;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: tableWidth,
            height: constraints.hasBoundedHeight ? constraints.maxHeight : null,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.value),
                border: Border.all(
                  color: AppColors.line.withValues(alpha: 0.72),
                ),
              ),
              child: Column(
                children: [
                  _LanguageHeader(
                    languageWidth: languageWidth,
                    selectedCount: selectedCodes.length,
                    totalCount: languages.length,
                    sortState: sortState,
                    onToggleAllRows: onToggleAll,
                    onSort: onSort,
                  ),
                  for (final language in languages)
                    _LanguageTableRow(
                      language: language,
                      languageWidth: languageWidth,
                      selected: selectedCodes.contains(language.code),
                      onToggle: () => onToggleCode(language.code),
                      onMakeDefault: () => onMakeDefault(language),
                      onEdit: () => onEdit(language),
                      onToggleStatus: () => onToggleStatus(language),
                      onDelete: () => onDelete(language),
                      onTranslations: () => onTranslations(language),
                      onExport: () => onExport(language),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EmptyLanguagesTable extends StatelessWidget {
  const _EmptyLanguagesTable({required this.onToggleAll});

  final VoidCallback onToggleAll;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line.withValues(alpha: 0.72)),
      ),
      child: Text(
        context.t('language.noRows'),
        style: const TextStyle(
          color: AppColors.inkSoft,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _LanguageHeader extends StatelessWidget {
  const _LanguageHeader({
    required this.languageWidth,
    required this.selectedCount,
    required this.totalCount,
    required this.sortState,
    required this.onToggleAllRows,
    required this.onSort,
  });

  final double languageWidth;
  final int selectedCount;
  final int totalCount;
  final TableSortState sortState;
  final VoidCallback onToggleAllRows;
  final ValueChanged<String> onSort;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.softLine.withValues(alpha: 0.86)),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: LanguageSettingsTable._selectWidth,
            child: _LanguageCheckbox(
              value: selectedCount == 0
                  ? false
                  : selectedCount == totalCount
                  ? true
                  : null,
              tristate: true,
              onChanged: (_) => onToggleAllRows(),
            ),
          ),
          SizedBox(
            width: LanguageSettingsTable._orderWidth,
            child: SortableTableHeader(
              label: 'language.orderNo',
              sortKey: 'order',
              sortState: sortState,
              onSort: onSort,
            ),
          ),
          SizedBox(
            width: languageWidth,
            child: SortableTableHeader(
              label: 'language.tableName',
              sortKey: 'name',
              sortState: sortState,
              onSort: onSort,
            ),
          ),
          SizedBox(
            width: LanguageSettingsTable._defaultWidth,
            child: SortableTableHeader(
              label: 'language.default',
              sortKey: 'default',
              sortState: sortState,
              onSort: onSort,
            ),
          ),
          const SizedBox(width: LanguageSettingsTable._columnGap),
          SizedBox(
            width: LanguageSettingsTable._actionsWidth,
            child: _HeaderText(context.t('language.tableActions')),
          ),
          SizedBox(
            width: LanguageSettingsTable._statusWidth,
            child: SortableTableHeader(
              label: 'language.status',
              sortKey: 'status',
              sortState: sortState,
              onSort: onSort,
            ),
          ),
          SizedBox(
            width: LanguageSettingsTable._menuWidth,
            child: _HeaderText(context.t('language.tableAction')),
          ),
        ],
      ),
    );
  }
}

class _LanguageTableRow extends StatelessWidget {
  const _LanguageTableRow({
    required this.language,
    required this.languageWidth,
    required this.selected,
    required this.onToggle,
    required this.onMakeDefault,
    required this.onEdit,
    required this.onToggleStatus,
    required this.onDelete,
    required this.onTranslations,
    required this.onExport,
  });

  final AdminLanguage language;
  final double languageWidth;
  final bool selected;
  final VoidCallback onToggle;
  final VoidCallback onMakeDefault;
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;
  final VoidCallback onDelete;
  final VoidCallback onTranslations;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 62),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: selected ? AppColors.surface : Colors.white,
        border: Border(
          bottom: BorderSide(color: AppColors.softLine.withValues(alpha: 0.86)),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: LanguageSettingsTable._selectWidth,
            child: _LanguageCheckbox(
              value: selected,
              onChanged: (_) => onToggle(),
            ),
          ),
          SizedBox(
            width: LanguageSettingsTable._orderWidth,
            child: _RowSelectTapTarget(
              onTap: onToggle,
              child: Text(
                language.rowNumber.toString(),
                style: const TextStyle(
                  color: AppColors.deepOcean,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          SizedBox(
            width: languageWidth,
            child: _RowSelectTapTarget(
              onTap: onToggle,
              child: _LanguageIdentity(language: language),
            ),
          ),
          SizedBox(
            width: LanguageSettingsTable._defaultWidth,
            child: language.isDefault
                ? _StatusBadge(label: context.t('language.default'))
                : _SmallActionButton(
                    label: context.t('language.defaultMake'),
                    onPressed: language.active ? onMakeDefault : null,
                  ),
          ),
          const SizedBox(width: LanguageSettingsTable._columnGap),
          SizedBox(
            width: LanguageSettingsTable._actionsWidth,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SmallActionButton(
                  label: context.t('language.translations'),
                  onPressed: onTranslations,
                ),
                _SmallActionButton(
                  label: context.t('language.export'),
                  color: AppColors.warmHorizon,
                  onPressed: onExport,
                ),
              ],
            ),
          ),
          SizedBox(
            width: LanguageSettingsTable._statusWidth,
            child: _StatusBadge(
              label: language.active
                  ? context.t('common.active')
                  : context.t('common.passive'),
              color: language.active
                  ? LanguageSettingsTable._activeGreen
                  : LanguageSettingsTable._passiveGray,
              dot: true,
            ),
          ),
          SizedBox(
            width: LanguageSettingsTable._menuWidth,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _LanguageRowMenu(
                language: language,
                onEdit: onEdit,
                onToggleStatus: onToggleStatus,
                onDelete: onDelete,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageIdentity extends StatelessWidget {
  const _LanguageIdentity({required this.language});

  final AdminLanguage language;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.softLine,
            borderRadius: BorderRadius.circular(17),
          ),
          child: Text(
            language.initial,
            style: const TextStyle(
              color: AppColors.deepOcean,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                language.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.deepOcean,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                language.code,
                style: const TextStyle(
                  color: AppColors.support,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LanguageCheckbox extends StatelessWidget {
  const _LanguageCheckbox({
    required this.value,
    required this.onChanged,
    this.tristate = false,
  });

  final bool? value;
  final ValueChanged<bool?> onChanged;
  final bool tristate;

  @override
  Widget build(BuildContext context) {
    return Checkbox(
      value: value,
      tristate: tristate,
      mouseCursor: SystemMouseCursors.click,
      activeColor: AppColors.deepOcean,
      checkColor: Colors.white,
      side: BorderSide(color: AppColors.line.withValues(alpha: 0.76)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.value),
      ),
      onChanged: onChanged,
    );
  }
}

class _RowSelectTapTarget extends StatelessWidget {
  const _RowSelectTapTarget({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: child,
      ),
    );
  }
}

class _HeaderText extends StatelessWidget {
  const _HeaderText(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: AppColors.inkSoft,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _LanguageRowMenu extends StatefulWidget {
  const _LanguageRowMenu({
    required this.language,
    required this.onEdit,
    required this.onToggleStatus,
    required this.onDelete,
  });

  final AdminLanguage language;
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;
  final VoidCallback onDelete;

  @override
  State<_LanguageRowMenu> createState() => _LanguageRowMenuState();
}

class _LanguageRowMenuState extends State<_LanguageRowMenu> {
  final _layerLink = LayerLink();
  OverlayEntry? _menuEntry;

  @override
  void dispose() {
    _closeMenu();
    super.dispose();
  }

  void _openMenu() {
    if (_menuEntry != null) return;

    _menuEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _closeMenu,
                child: const SizedBox.expand(),
              ),
            ),
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              targetAnchor: Alignment.bottomRight,
              followerAnchor: Alignment.topRight,
              offset: const Offset(0, 8),
              child: _LanguageMenuCard(
                language: widget.language,
                onEdit: () {
                  _closeMenu();
                  widget.onEdit();
                },
                onToggleStatus: () {
                  _closeMenu();
                  widget.onToggleStatus();
                },
                onDelete: () {
                  _closeMenu();
                  widget.onDelete();
                },
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(_menuEntry!);
  }

  void _closeMenu() {
    _menuEntry?.remove();
    _menuEntry = null;
  }

  void _toggleMenu() {
    if (_menuEntry == null) {
      _openMenu();
    } else {
      _closeMenu();
    }
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggleMenu,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Text(
              '...',
              style: TextStyle(
                color: AppColors.support.withValues(alpha: 0.92),
                fontSize: 18,
                fontWeight: FontWeight.w500,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageMenuCard extends StatelessWidget {
  const _LanguageMenuCard({
    required this.language,
    required this.onEdit,
    required this.onToggleStatus,
    required this.onDelete,
  });

  final AdminLanguage language;
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final statusAllowed = !language.isCore;
    final deleteAllowed = !language.isCore && !language.isDefault;
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 188,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.value),
          border: Border.all(color: AppColors.line),
          boxShadow: [
            BoxShadow(
              color: AppColors.deepOcean.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LanguageMenuItem(
              icon: Symbols.edit_square,
              label: context.t('common.edit'),
              onTap: onEdit,
            ),
            _LanguageMenuItem(
              icon: Symbols.visibility_off,
              label: language.active
                  ? context.t('language.passivate')
                  : context.t('language.activate'),
              onTap: statusAllowed ? onToggleStatus : null,
            ),
            _LanguageMenuItem(
              icon: Symbols.draft,
              label: context.t('common.delete'),
              onTap: deleteAllowed ? onDelete : null,
              danger: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageMenuItem extends StatelessWidget {
  const _LanguageMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final color = enabled
        ? danger
              ? AppColors.actionRed
              : AppColors.deepOcean
        : AppColors.placeholder;

    return InkWell(
      mouseCursor: enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      borderRadius: BorderRadius.circular(AppRadius.value),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          children: [
            SymbolIcon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    this.color = AppColors.deepOcean,
    this.dot = false,
  });

  final String label;
  final Color color;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        height: 28,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.value),
            border: Border.all(
              color: AppColors.softLine.withValues(alpha: 0.9),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dot) ...[
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(AppRadius.value),
                  ),
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallActionButton extends StatelessWidget {
  const _SmallActionButton({
    required this.label,
    this.color = AppColors.deepOcean,
    this.onPressed,
  });

  final String label;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return SizedBox(
      height: 28,
      child: OutlinedButton(
        onPressed: onPressed,
        style:
            OutlinedButton.styleFrom(
              foregroundColor: enabled ? color : AppColors.placeholder,
              side: BorderSide(
                color: (enabled ? color : AppColors.line).withValues(
                  alpha: 0.82,
                ),
              ),
              minimumSize: const Size(0, 28),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.value),
              ),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ).copyWith(
              mouseCursor: WidgetStatePropertyAll(
                enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
              ),
            ),
        child: Text(label),
      ),
    );
  }
}

class _LanguageSettingsCardList extends StatelessWidget {
  const _LanguageSettingsCardList({
    required this.languages,
    required this.selectedCodes,
    required this.onToggleCode,
    required this.onEdit,
    required this.onToggleStatus,
    required this.onDelete,
    required this.onMakeDefault,
    required this.onTranslations,
    required this.onExport,
  });

  final List<AdminLanguage> languages;
  final Set<String> selectedCodes;
  final ValueChanged<String> onToggleCode;
  final ValueChanged<AdminLanguage> onEdit;
  final ValueChanged<AdminLanguage> onToggleStatus;
  final ValueChanged<AdminLanguage> onDelete;
  final ValueChanged<AdminLanguage> onMakeDefault;
  final ValueChanged<AdminLanguage> onTranslations;
  final ValueChanged<AdminLanguage> onExport;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: languages.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final language = languages[index];
        final selected = selectedCodes.contains(language.code);

        return _LanguageMobileCard(
          language: language,
          selected: selected,
          onToggle: () => onToggleCode(language.code),
          onMakeDefault: () => onMakeDefault(language),
          onEdit: () => onEdit(language),
          onToggleStatus: () => onToggleStatus(language),
          onDelete: () => onDelete(language),
          onTranslations: () => onTranslations(language),
          onExport: () => onExport(language),
        );
      },
    );
  }
}

class _LanguageMobileCard extends StatelessWidget {
  const _LanguageMobileCard({
    required this.language,
    required this.selected,
    required this.onToggle,
    required this.onMakeDefault,
    required this.onEdit,
    required this.onToggleStatus,
    required this.onDelete,
    required this.onTranslations,
    required this.onExport,
  });

  final AdminLanguage language;
  final bool selected;
  final VoidCallback onToggle;
  final VoidCallback onMakeDefault;
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;
  final VoidCallback onDelete;
  final VoidCallback onTranslations;
  final VoidCallback onExport;

  static const _accent = Color(0xFF2C3E50);
  static const _activeBg = Color(0xFFE6F4EA);
  static const _activeText = Color(0xFF1E7E34);
  static const _passiveBg = Color(0xFFF5F5F5);
  static const _passiveText = Color(0xFF757575);
  static const _defaultBg = Color(0xFFE8F4FF);
  static const _defaultText = Color(0xFF0B5FBF);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: selected ? _accent.withValues(alpha: 0.04) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected
              ? _accent.withValues(alpha: 0.3)
              : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: selected
                ? _accent.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: selected ? 12 : 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: selected,
                  onChanged: (_) => onToggle(),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  side: const BorderSide(color: Color(0xFFD1D1D1)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _RowSelectTapTarget(
                  onTap: onToggle,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        language.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        language.code,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _LanguageRowMenu(
                language: language,
                onEdit: onEdit,
                onToggleStatus: onToggleStatus,
                onDelete: onDelete,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: language.active ? _activeBg : _passiveBg,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  language.active
                      ? context.t('common.active')
                      : context.t('common.passive'),
                  style: TextStyle(
                    color: language.active ? _activeText : _passiveText,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
              Flexible(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _SmallActionButton(
                      label: context.t('language.translations'),
                      onPressed: onTranslations,
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (language.isDefault)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _defaultBg,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              context.t('language.default'),
                              style: const TextStyle(
                                color: _defaultText,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          )
                        else
                          _SmallActionButton(
                            label: context.t('language.defaultMake'),
                            onPressed: language.active ? onMakeDefault : null,
                          ),
                        const SizedBox(height: 6),
                        _SmallActionButton(
                          label: context.t('language.exportShort'),
                          color: AppColors.warmHorizon,
                          onPressed: onExport,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
