import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../core/localization/admin_language_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/widgets/admin_table_chrome.dart';
import '../../../shared/widgets/sortable_table_header.dart';
import '../../../shared/widgets/symbol_icon.dart';

class FontSettingsScreen extends StatefulWidget {
  const FontSettingsScreen({super.key});

  @override
  State<FontSettingsScreen> createState() => _FontSettingsScreenState();
}

class _FontSettingsScreenState extends State<FontSettingsScreen> {
  late final Map<String, TextEditingController> _sizeControllers;
  late final TextEditingController _searchController;

  var _language = 'en';
  var _primaryFont = 'Open Sans';
  var _secondaryFont = 'Plus Jakarta Sans';
  var _contentFont = 'Inter';
  var _pageSize = 25;
  var _page = 1;
  var _searchQuery = '';
  var _sortState = const TableSortState(key: 'id', ascending: false);
  var _expandedSection = _FontSizeSection.layoutSpecial;

  @override
  void initState() {
    super.initState();
    _sizeControllers = {
      for (final item in _FontSizeItem.all)
        item.key: TextEditingController(text: item.initialValue),
    };
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    for (final controller in _sizeControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _showSavedMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.t('fontSettings.saveSuccess'))),
    );
  }

  Future<void> _openAddFontDialog() async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.34),
      builder: (context) => const _FontDialogFrame(child: _AddFontDialog()),
    );
  }

  void _selectFont(String fontName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.t('fontSettings.fontSelected', values: {'font': fontName}),
        ),
      ),
    );
  }

  void _changePageSize(int? value) {
    if (value == null) return;
    setState(() {
      _pageSize = value;
      _page = 1;
    });
  }

  void _changeSearch(String value) {
    setState(() {
      _searchQuery = value;
      _page = 1;
    });
  }

  void _changeSort(String key) {
    setState(() {
      _sortState = _sortState.toggled(key);
      _page = 1;
    });
  }

  void _changePage(int page) {
    setState(() => _page = page);
  }

  List<_FontRow> get _filteredFonts {
    final query = _searchQuery.trim().toLowerCase();
    final filtered = query.isEmpty
        ? List<_FontRow>.of(_fontRows)
        : _fontRows.where((font) {
            return font.name.toLowerCase().contains(query) ||
                font.sourceLabelKey.toLowerCase().contains(query);
          }).toList();

    filtered.sort((a, b) {
      final result = switch (_sortState.key) {
        'name' => a.name.compareTo(b.name),
        'source' => a.sourceLabelKey.compareTo(b.sourceLabelKey),
        _ => a.id.compareTo(b.id),
      };
      return _sortState.ascending ? result : -result;
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 640 ? 16.0 : 28.0;
        final stacked = constraints.maxWidth < 1120;
        final filteredFonts = _filteredFonts;
        final pageCount = filteredFonts.isEmpty
            ? 1
            : ((filteredFonts.length - 1) ~/ _pageSize) + 1;
        final safePage = _page.clamp(1, pageCount);
        final start = filteredFonts.isEmpty ? 0 : (safePage - 1) * _pageSize;
        final visibleFonts = filteredFonts
            .skip(start)
            .take(_pageSize)
            .toList(growable: false);

        return Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            28,
            horizontalPadding,
            28,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.t('fontSettings.title'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.deepOcean,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 22),
              Expanded(
                child: stacked
                    ? SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _LeftFontSettingsColumn(
                              language: _language,
                              primaryFont: _primaryFont,
                              secondaryFont: _secondaryFont,
                              contentFont: _contentFont,
                              expandedSection: _expandedSection,
                              sizeControllers: _sizeControllers,
                              onLanguageChanged: (value) {
                                if (value == null) return;
                                setState(() => _language = value);
                              },
                              onPrimaryFontChanged: (value) {
                                if (value == null) return;
                                setState(() => _primaryFont = value);
                              },
                              onSecondaryFontChanged: (value) {
                                if (value == null) return;
                                setState(() => _secondaryFont = value);
                              },
                              onContentFontChanged: (value) {
                                if (value == null) return;
                                setState(() => _contentFont = value);
                              },
                              onSectionChanged: (section) =>
                                  setState(() => _expandedSection = section),
                              onSave: _showSavedMessage,
                            ),
                            const SizedBox(height: 18),
                            SizedBox(
                              height: 720,
                              child: _FontListCard(
                                searchController: _searchController,
                                pageSize: _pageSize,
                                page: safePage,
                                totalCount: filteredFonts.length,
                                searchQuery: _searchQuery,
                                sortState: _sortState,
                                fonts: visibleFonts,
                                onPageSizeChanged: _changePageSize,
                                onSearchChanged: _changeSearch,
                                onPageChanged: _changePage,
                                onSort: _changeSort,
                                onAddFont: _openAddFontDialog,
                                onSelectFont: _selectFont,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: 276,
                            child: SingleChildScrollView(
                              child: _LeftFontSettingsColumn(
                                language: _language,
                                primaryFont: _primaryFont,
                                secondaryFont: _secondaryFont,
                                contentFont: _contentFont,
                                expandedSection: _expandedSection,
                                sizeControllers: _sizeControllers,
                                onLanguageChanged: (value) {
                                  if (value == null) return;
                                  setState(() => _language = value);
                                },
                                onPrimaryFontChanged: (value) {
                                  if (value == null) return;
                                  setState(() => _primaryFont = value);
                                },
                                onSecondaryFontChanged: (value) {
                                  if (value == null) return;
                                  setState(() => _secondaryFont = value);
                                },
                                onContentFontChanged: (value) {
                                  if (value == null) return;
                                  setState(() => _contentFont = value);
                                },
                                onSectionChanged: (section) =>
                                    setState(() => _expandedSection = section),
                                onSave: _showSavedMessage,
                              ),
                            ),
                          ),
                          const SizedBox(width: 28),
                          Expanded(
                            child: _FontListCard(
                              searchController: _searchController,
                              pageSize: _pageSize,
                              page: safePage,
                              totalCount: filteredFonts.length,
                              searchQuery: _searchQuery,
                              sortState: _sortState,
                              fonts: visibleFonts,
                              onPageSizeChanged: _changePageSize,
                              onSearchChanged: _changeSearch,
                              onPageChanged: _changePage,
                              onSort: _changeSort,
                              onAddFont: _openAddFontDialog,
                              onSelectFont: _selectFont,
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LeftFontSettingsColumn extends StatelessWidget {
  const _LeftFontSettingsColumn({
    required this.language,
    required this.primaryFont,
    required this.secondaryFont,
    required this.contentFont,
    required this.expandedSection,
    required this.sizeControllers,
    required this.onLanguageChanged,
    required this.onPrimaryFontChanged,
    required this.onSecondaryFontChanged,
    required this.onContentFontChanged,
    required this.onSectionChanged,
    required this.onSave,
  });

  final String language;
  final String primaryFont;
  final String secondaryFont;
  final String contentFont;
  final _FontSizeSection expandedSection;
  final Map<String, TextEditingController> sizeControllers;
  final ValueChanged<String?> onLanguageChanged;
  final ValueChanged<String?> onPrimaryFontChanged;
  final ValueChanged<String?> onSecondaryFontChanged;
  final ValueChanged<String?> onContentFontChanged;
  final ValueChanged<_FontSizeSection> onSectionChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SettingsCard(
          title: 'fontSettings.siteFont.title',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SelectField(
                label: 'fontSettings.siteFont.language',
                value: language,
                options: _languageOptions,
                onChanged: onLanguageChanged,
              ),
              const SizedBox(height: 18),
              _SelectField(
                label: 'fontSettings.siteFont.primary',
                value: primaryFont,
                options: _fontSelectOptions,
                onChanged: onPrimaryFontChanged,
                requiredField: true,
              ),
              const SizedBox(height: 18),
              _SelectField(
                label: 'fontSettings.siteFont.secondary',
                value: secondaryFont,
                options: _fontSelectOptions,
                onChanged: onSecondaryFontChanged,
                requiredField: true,
              ),
              const SizedBox(height: 18),
              _SelectField(
                label: 'fontSettings.siteFont.content',
                value: contentFont,
                options: _fontSelectOptions,
                onChanged: onContentFontChanged,
                requiredField: true,
              ),
              const SizedBox(height: 22),
              Align(
                alignment: Alignment.centerRight,
                child: _SaveButton(onPressed: onSave),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _SettingsCard(
          title: 'fontSettings.fontSize.title',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final section in _FontSizeSection.values)
                _FontSizePanel(
                  section: section,
                  expanded: expandedSection == section,
                  controllers: sizeControllers,
                  onToggle: () => onSectionChanged(section),
                ),
              const SizedBox(height: 22),
              Align(
                alignment: Alignment.centerRight,
                child: _SaveButton(onPressed: onSave),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line.withValues(alpha: 0.86)),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepOcean.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.t(title),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.deepOcean,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 26),
          child,
        ],
      ),
    );
  }
}

class _SelectField extends StatelessWidget {
  const _SelectField({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.requiredField = false,
  });

  final String label;
  final String value;
  final List<_SelectOption> options;
  final ValueChanged<String?> onChanged;
  final bool requiredField;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FieldLabel(label: label, requiredField: requiredField),
        const SizedBox(height: 8),
        _SelectBox(value: value, options: options, onChanged: onChanged),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label, this.requiredField = false});

  final String label;
  final bool requiredField;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            context.t(label),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.deepOcean,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ),
        if (requiredField) ...[
          const SizedBox(width: 4),
          Text(
            '*',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.actionRed,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ],
      ],
    );
  }
}

class _SelectBox extends StatelessWidget {
  const _SelectBox({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String value;
  final List<_SelectOption> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        height: 42,
        padding: const EdgeInsets.only(left: 12, right: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.value),
          border: Border.all(color: AppColors.line),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            borderRadius: BorderRadius.circular(AppRadius.value),
            dropdownColor: Colors.white,
            focusColor: Colors.transparent,
            mouseCursor: SystemMouseCursors.click,
            dropdownMenuItemMouseCursor: SystemMouseCursors.click,
            icon: const SymbolIcon(
              Symbols.keyboard_arrow_down,
              color: AppColors.iconMuted,
              size: 18,
            ),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.deepOcean,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
            items: [
              for (final option in options)
                DropdownMenuItem(
                  value: option.value,
                  child: Text(
                    option.labelKey == null
                        ? option.value
                        : context.t(option.labelKey!),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: TextButton(
        onPressed: onPressed,
        style:
            TextButton.styleFrom(
              backgroundColor: AppColors.actionRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18),
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SymbolIcon(Symbols.check, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                context.t('fontSettings.saveChanges'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FontSizePanel extends StatelessWidget {
  const _FontSizePanel({
    required this.section,
    required this.expanded,
    required this.controllers,
    required this.onToggle,
  });

  final _FontSizeSection section;
  final bool expanded;
  final Map<String, TextEditingController> controllers;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.value),
          border: Border.all(color: AppColors.softLine),
          boxShadow: [
            BoxShadow(
              color: AppColors.deepOcean.withValues(alpha: 0.025),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onToggle,
                child: SizedBox(
                  height: 54,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.t(section.labelKey),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: section == _FontSizeSection.titles
                                      ? AppColors.actionRed
                                      : AppColors.deepOcean,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0,
                                ),
                          ),
                        ),
                        SymbolIcon(
                          Symbols.keyboard_arrow_down,
                          color: expanded
                              ? AppColors.actionRed
                              : AppColors.iconMuted,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (expanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  children: [
                    for (final item in section.items)
                      _FontSizeRow(
                        item: item,
                        controller: controllers[item.key]!,
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

class _FontSizeRow extends StatelessWidget {
  const _FontSizeRow({required this.item, required this.controller});

  final _FontSizeItem item;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: _FontSizeLabel(item: item)),
          const SizedBox(width: 10),
          SizedBox(width: 96, child: _UnitTextField(controller: controller)),
        ],
      ),
    );
  }
}

class _FontSizeLabel extends StatelessWidget {
  const _FontSizeLabel({required this.item});

  final _FontSizeItem item;

  @override
  Widget build(BuildContext context) {
    if (item.highlightKey == null) {
      return Text(
        context.t(item.labelKey),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.deepOcean,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      );
    }

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: context.t(item.labelKey)),
          const TextSpan(text: ' '),
          TextSpan(
            text: context.t(item.highlightKey!),
            style: const TextStyle(color: Color(0xFF16A34A)),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: AppColors.deepOcean,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
    );
  }
}

class _UnitTextField extends StatelessWidget {
  const _UnitTextField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              mouseCursor: SystemMouseCursors.text,
              cursorColor: AppColors.support,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.deepOcean,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          Container(
            width: 30,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(left: BorderSide(color: AppColors.line)),
            ),
            child: Text(
              context.t('fontSettings.unitPx'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.placeholder,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FontListCard extends StatelessWidget {
  const _FontListCard({
    required this.searchController,
    required this.pageSize,
    required this.page,
    required this.totalCount,
    required this.searchQuery,
    required this.sortState,
    required this.fonts,
    required this.onPageSizeChanged,
    required this.onSearchChanged,
    required this.onPageChanged,
    required this.onSort,
    required this.onAddFont,
    required this.onSelectFont,
  });

  final TextEditingController searchController;
  final int pageSize;
  final int page;
  final int totalCount;
  final String searchQuery;
  final TableSortState sortState;
  final List<_FontRow> fonts;
  final ValueChanged<int?> onPageSizeChanged;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<String> onSort;
  final VoidCallback onAddFont;
  final ValueChanged<String> onSelectFont;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FontToolbar(
          searchController: searchController,
          pageSize: pageSize,
          searchQuery: searchQuery,
          onPageSizeChanged: onPageSizeChanged,
          onSearchChanged: onSearchChanged,
          onAddFont: onAddFont,
        ),
        const SizedBox(height: 18),
        Expanded(
          child: _FontsTable(
            fonts: fonts,
            sortState: sortState,
            onSort: onSort,
            onSelect: onSelectFont,
          ),
        ),
        const SizedBox(height: 16),
        _FontFooter(
          page: page,
          pageSize: pageSize,
          visibleCount: fonts.length,
          totalCount: totalCount,
          onPageChanged: onPageChanged,
        ),
      ],
    );
  }
}

class _FontToolbar extends StatelessWidget {
  const _FontToolbar({
    required this.searchController,
    required this.pageSize,
    required this.searchQuery,
    required this.onPageSizeChanged,
    required this.onSearchChanged,
    required this.onAddFont,
  });

  final TextEditingController searchController;
  final int pageSize;
  final String searchQuery;
  final ValueChanged<int?> onPageSizeChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onAddFont;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final pageSizeSelect = AdminTablePageSizeSelect(
          value: pageSize,
          onChanged: onPageSizeChanged,
        );
        final search = ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: compact ? double.infinity : 260,
            maxWidth: compact ? double.infinity : 280,
          ),
          child: AdminTableSearchField(
            controller: searchController,
            query: searchQuery,
            hintText: context.t('common.search'),
            onChanged: onSearchChanged,
          ),
        );
        final addButton = AdminTablePrimaryActionButton(
          icon: Symbols.add,
          label: context.t('fontSettings.addFont'),
          onPressed: onAddFont,
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(alignment: Alignment.centerLeft, child: pageSizeSelect),
              const SizedBox(height: 14),
              search,
              const SizedBox(height: 10),
              Align(alignment: Alignment.centerLeft, child: addButton),
            ],
          );
        }

        return Row(
          children: [
            pageSizeSelect,
            const Spacer(),
            search,
            const SizedBox(width: 14),
            addButton,
          ],
        );
      },
    );
  }
}

class _FontsTable extends StatelessWidget {
  const _FontsTable({
    required this.fonts,
    required this.sortState,
    required this.onSort,
    required this.onSelect,
  });

  final List<_FontRow> fonts;
  final TableSortState sortState;
  final ValueChanged<String> onSort;
  final ValueChanged<String> onSelect;

  static const double _minWidth = 1040;
  static const double _idWidth = 92;
  static const double _sourceWidth = 220;
  static const double _optionsWidth = 124;
  static const double _horizontalPadding = 32;
  static const double _tableBorderWidth = 2;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth = constraints.maxWidth < _minWidth
            ? _minWidth
            : constraints.maxWidth;
        final nameWidth =
            tableWidth -
            _horizontalPadding -
            _tableBorderWidth -
            _idWidth -
            _sourceWidth -
            _optionsWidth;

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
                  _FontsHeader(
                    nameWidth: nameWidth,
                    sortState: sortState,
                    onSort: onSort,
                  ),
                  Expanded(
                    child: fonts.isEmpty
                        ? Center(
                            child: AdminTableEmptyText(
                              label: 'fontSettings.table.empty',
                            ),
                          )
                        : SingleChildScrollView(
                            child: Column(
                              children: [
                                for (final font in fonts)
                                  _FontTableRow(
                                    font: font,
                                    nameWidth: nameWidth,
                                    onSelect: () => onSelect(font.name),
                                  ),
                              ],
                            ),
                          ),
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

class _FontsHeader extends StatelessWidget {
  const _FontsHeader({
    required this.nameWidth,
    required this.sortState,
    required this.onSort,
  });

  final double nameWidth;
  final TableSortState sortState;
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
            width: _FontsTable._idWidth,
            child: SortableTableHeader(
              label: 'ID',
              sortKey: 'id',
              sortState: sortState,
              onSort: onSort,
            ),
          ),
          SizedBox(
            width: nameWidth,
            child: SortableTableHeader(
              label: 'fontSettings.table.name',
              sortKey: 'name',
              sortState: sortState,
              onSort: onSort,
            ),
          ),
          SizedBox(
            width: _FontsTable._sourceWidth,
            child: SortableTableHeader(
              label: 'fontSettings.table.source',
              sortKey: 'source',
              sortState: sortState,
              onSort: onSort,
            ),
          ),
          SizedBox(
            width: _FontsTable._optionsWidth,
            child: _HeaderText(
              context.t('fontSettings.table.options'),
              centered: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _FontTableRow extends StatelessWidget {
  const _FontTableRow({
    required this.font,
    required this.nameWidth,
    required this.onSelect,
  });

  final _FontRow font;
  final double nameWidth;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.softLine.withValues(alpha: 0.86)),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _FontsTable._idWidth,
            child: Text(
              font.id.toString(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.deepOcean,
                fontWeight: FontWeight.w500,
                letterSpacing: 0,
              ),
            ),
          ),
          SizedBox(
            width: nameWidth,
            child: Text(
              font.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.deepOcean,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
          ),
          SizedBox(
            width: _FontsTable._sourceWidth,
            child: Text(
              context.t(font.sourceLabelKey),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.inkSoft,
                fontWeight: FontWeight.w500,
                letterSpacing: 0,
              ),
            ),
          ),
          SizedBox(
            width: _FontsTable._optionsWidth,
            child: Align(
              alignment: Alignment.center,
              child: _FontSelectAction(onSelect: onSelect),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderText extends StatelessWidget {
  const _HeaderText(this.label, {this.centered = false});

  final String label;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: centered ? Alignment.center : Alignment.centerLeft,
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: centered ? TextAlign.center : TextAlign.start,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.inkSoft,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _FontSelectAction extends StatelessWidget {
  const _FontSelectAction({required this.onSelect});

  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return _FontRowMenu(onSelect: onSelect);
  }
}

class _FontRowMenu extends StatefulWidget {
  const _FontRowMenu({required this.onSelect});

  final VoidCallback onSelect;

  @override
  State<_FontRowMenu> createState() => _FontRowMenuState();
}

class _FontRowMenuState extends State<_FontRowMenu> {
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
              child: _FontMenuCard(onEdit: () => _runAndClose(widget.onSelect)),
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(_menuEntry!);
  }

  void _runAndClose(VoidCallback action) {
    _closeMenu();
    action();
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
      child: Tooltip(
        message: context.t('fontSettings.table.options'),
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
      ),
    );
  }
}

class _FontMenuCard extends StatelessWidget {
  const _FontMenuCard({required this.onEdit});

  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 230,
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
            _FontMenuItem(
              icon: Symbols.edit_square,
              label: 'fontSettings.table.edit',
              onTap: onEdit,
            ),
          ],
        ),
      ),
    );
  }
}

class _FontMenuItem extends StatelessWidget {
  const _FontMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      mouseCursor: SystemMouseCursors.click,
      borderRadius: BorderRadius.circular(AppRadius.value),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          children: [
            SymbolIcon(icon, color: AppColors.deepOcean, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.t(label),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.deepOcean,
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

class _FontFooter extends StatelessWidget {
  const _FontFooter({
    required this.page,
    required this.pageSize,
    required this.visibleCount,
    required this.totalCount,
    required this.onPageChanged,
  });

  final int page;
  final int pageSize;
  final int visibleCount;
  final int totalCount;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final lastPage = totalCount == 0 ? 1 : ((totalCount - 1) ~/ pageSize) + 1;
    final from = totalCount == 0 ? 0 : ((page - 1) * pageSize) + 1;
    final to = totalCount == 0 ? 0 : from + visibleCount - 1;
    final rangeText = context.t(
      'common.recordRange',
      values: {'from': from, 'to': to, 'total': totalCount},
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 800;
        final compact = constraints.maxWidth < 640;
        final summary = Text(
          rangeText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.inkSoft,
            fontWeight: FontWeight.w500,
            letterSpacing: 0,
          ),
        );
        final pager = _FontPagination(
          page: page,
          lastPage: lastPage,
          onPageChanged: onPageChanged,
        );

        if (mobile) {
          final hasPrevious = page > 1;
          final hasNext = page < lastPage;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              IconButton(
                onPressed: hasPrevious ? () => onPageChanged(page - 1) : null,
                icon: const Icon(Icons.chevron_left),
                constraints: const BoxConstraints.tightFor(
                  width: 32,
                  height: 32,
                ),
                padding: EdgeInsets.zero,
                splashRadius: 18,
                visualDensity: VisualDensity.compact,
              ),
              Expanded(
                child: Text(
                  rangeText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
              IconButton(
                onPressed: hasNext ? () => onPageChanged(page + 1) : null,
                icon: const Icon(Icons.chevron_right),
                constraints: const BoxConstraints.tightFor(
                  width: 32,
                  height: 32,
                ),
                padding: EdgeInsets.zero,
                splashRadius: 18,
                visualDensity: VisualDensity.compact,
              ),
            ],
          );
        }

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(height: 1, color: AppColors.line),
              const SizedBox(height: 16),
              summary,
              const SizedBox(height: 14),
              pager,
            ],
          );
        }

        return Column(
          children: [
            const Divider(height: 1, color: AppColors.line),
            const SizedBox(height: 16),
            Row(children: [summary, const Spacer(), pager]),
          ],
        );
      },
    );
  }
}

class _FontPagination extends StatelessWidget {
  const _FontPagination({
    required this.page,
    required this.lastPage,
    required this.onPageChanged,
  });

  final int page;
  final int lastPage;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        AdminTablePageButton(
          label: '<<',
          enabled: page > 1,
          onPressed: () => onPageChanged(1),
        ),
        AdminTablePageButton(
          label: '<',
          enabled: page > 1,
          onPressed: () => onPageChanged(page - 1),
        ),
        AdminTablePageButton(label: page.toString(), selected: true),
        AdminTablePageButton(
          label: '>',
          enabled: page < lastPage,
          onPressed: () => onPageChanged(page + 1),
        ),
        AdminTablePageButton(
          label: '>>',
          enabled: page < lastPage,
          onPressed: () => onPageChanged(lastPage),
        ),
      ],
    );
  }
}

class _FontDialogFrame extends StatelessWidget {
  const _FontDialogFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 620, maxHeight: height - 48),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.value),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(child: child),
        ),
      ),
    );
  }
}

class _AddFontDialog extends StatefulWidget {
  const _AddFontDialog();

  @override
  State<_AddFontDialog> createState() => _AddFontDialogState();
}

class _AddFontDialogState extends State<_AddFontDialog> {
  final _nameController = TextEditingController();
  var _fontType = 'monospace';

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 26, 28, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DialogHeader(title: context.t('fontSettings.dialog.addTitle')),
          const SizedBox(height: 24),
          _DialogLineField(
            controller: _nameController,
            label: 'fontSettings.dialog.name',
            hintText: 'fontSettings.dialog.nameHint',
            icon: Symbols.short_text,
            requiredField: true,
          ),
          const SizedBox(height: 22),
          _DialogSelectField(
            label: 'fontSettings.dialog.fontType',
            value: _fontType,
            options: _fontTypeOptions,
            icon: Symbols.short_text,
            requiredField: true,
            onChanged: (value) {
              if (value == null) return;
              setState(() => _fontType = value);
            },
          ),
          const SizedBox(height: 22),
          _DialogSectionLabel(
            context.t('fontSettings.dialog.fontFile'),
            requiredField: true,
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 540;
              final boxes = [
                const _FontUploadBox(
                  title: 'fontSettings.dialog.weight400',
                  requiredField: true,
                ),
                const _FontUploadBox(title: 'fontSettings.dialog.weight600'),
                const _FontUploadBox(title: 'fontSettings.dialog.weight700'),
              ];

              if (compact) {
                return Column(
                  children: [
                    for (var index = 0; index < boxes.length; index++) ...[
                      if (index > 0) const SizedBox(height: 12),
                      boxes[index],
                    ],
                  ],
                );
              }

              return Row(
                children: [
                  for (var index = 0; index < boxes.length; index++) ...[
                    if (index > 0) const SizedBox(width: 12),
                    Expanded(child: boxes[index]),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 34),
          Align(
            alignment: Alignment.centerRight,
            child: _DialogFooter(
              primaryLabel: context.t('fontSettings.dialog.addAction'),
              onPrimaryPressed: _submit,
            ),
          ),
        ],
      ),
    );
  }
}

class _DialogHeader extends StatelessWidget {
  const _DialogHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.deepOcean,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ),
        const SizedBox(width: 12),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).maybePop(),
            child: const Padding(
              padding: EdgeInsets.all(3),
              child: SymbolIcon(
                Symbols.close,
                color: AppColors.deepOcean,
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DialogLineField extends StatelessWidget {
  const _DialogLineField({
    required this.controller,
    required this.label,
    required this.hintText,
    required this.icon,
    this.requiredField = false,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final IconData icon;
  final bool requiredField;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DialogSectionLabel(context.t(label), requiredField: requiredField),
        const SizedBox(height: 12),
        Container(
          height: 38,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: requiredField
                    ? AppColors.actionRed.withValues(alpha: 0.84)
                    : AppColors.line,
              ),
            ),
          ),
          child: Row(
            children: [
              SymbolIcon(icon, color: AppColors.placeholder, size: 19),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: controller,
                  mouseCursor: SystemMouseCursors.text,
                  cursorColor: AppColors.support,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.deepOcean,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0,
                  ),
                  decoration: InputDecoration(
                    hintText: context.t(hintText),
                    hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.placeholder,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.only(bottom: 2),
                    filled: false,
                    hoverColor: Colors.transparent,
                    focusColor: Colors.transparent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DialogSelectField extends StatelessWidget {
  const _DialogSelectField({
    required this.label,
    required this.value,
    required this.options,
    required this.icon,
    required this.onChanged,
    this.requiredField = false,
  });

  final String label;
  final String value;
  final List<_SelectOption> options;
  final IconData icon;
  final ValueChanged<String?> onChanged;
  final bool requiredField;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DialogSectionLabel(context.t(label), requiredField: requiredField),
        const SizedBox(height: 12),
        Container(
          height: 38,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: requiredField
                    ? AppColors.actionRed.withValues(alpha: 0.84)
                    : AppColors.line,
              ),
            ),
          ),
          child: Row(
            children: [
              SymbolIcon(icon, color: AppColors.placeholder, size: 19),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: value,
                    isExpanded: true,
                    borderRadius: BorderRadius.circular(AppRadius.value),
                    dropdownColor: Colors.white,
                    focusColor: Colors.transparent,
                    mouseCursor: SystemMouseCursors.click,
                    dropdownMenuItemMouseCursor: SystemMouseCursors.click,
                    icon: const SymbolIcon(
                      Symbols.keyboard_arrow_down,
                      color: AppColors.iconMuted,
                      size: 18,
                    ),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.deepOcean,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                    items: [
                      for (final option in options)
                        DropdownMenuItem(
                          value: option.value,
                          child: Text(context.t(option.labelKey!)),
                        ),
                    ],
                    onChanged: onChanged,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DialogSectionLabel extends StatelessWidget {
  const _DialogSectionLabel(this.label, {this.requiredField = false});

  final String label;
  final bool requiredField;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        text: label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: requiredField ? AppColors.actionRed : AppColors.inkSoft,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
        children: requiredField ? const [TextSpan(text: ' *')] : const [],
      ),
    );
  }
}

class _FontUploadBox extends StatelessWidget {
  const _FontUploadBox({required this.title, this.requiredField = false});

  final String title;
  final bool requiredField;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(
        color: AppColors.line,
        radius: AppRadius.value,
      ),
      child: Container(
        height: 112,
        padding: const EdgeInsets.all(12),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DialogSectionLabel(context.t(title), requiredField: requiredField),
            const SizedBox(height: 12),
            SizedBox(
              height: 30,
              child: TextButton(
                onPressed: () {},
                style:
                    TextButton.styleFrom(
                      backgroundColor: AppColors.surface,
                      foregroundColor: AppColors.deepOcean,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.value),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 12,
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
                    const SymbolIcon(
                      Symbols.folder_open,
                      color: AppColors.deepOcean,
                      size: 15,
                    ),
                    const SizedBox(width: 6),
                    Text(context.t('fontSettings.dialog.selectFile')),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rect);

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + 5;
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + 4;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return color != oldDelegate.color || radius != oldDelegate.radius;
  }
}

class _DialogFooter extends StatelessWidget {
  const _DialogFooter({
    required this.primaryLabel,
    required this.onPrimaryPressed,
  });

  final String primaryLabel;
  final VoidCallback onPrimaryPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          style:
              TextButton.styleFrom(
                foregroundColor: AppColors.deepOcean,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ).copyWith(
                mouseCursor: const WidgetStatePropertyAll(
                  SystemMouseCursors.click,
                ),
              ),
          child: Text(context.t('common.cancel')),
        ),
        const SizedBox(width: 16),
        SizedBox(
          height: 36,
          child: TextButton(
            onPressed: onPrimaryPressed,
            style:
                TextButton.styleFrom(
                  backgroundColor: AppColors.deepOcean,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.value),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ).copyWith(
                  mouseCursor: const WidgetStatePropertyAll(
                    SystemMouseCursors.click,
                  ),
                ),
            child: Text(primaryLabel),
          ),
        ),
      ],
    );
  }
}

enum _FontSizeSection {
  layoutSpecial('fontSettings.fontSize.layoutSpecial'),
  general('fontSettings.fontSize.general'),
  titles('fontSettings.fontSize.titles');

  const _FontSizeSection(this.labelKey);

  final String labelKey;

  List<_FontSizeItem> get items {
    return switch (this) {
      _FontSizeSection.layoutSpecial => _FontSizeItem.layoutSpecial,
      _FontSizeSection.general => _FontSizeItem.general,
      _FontSizeSection.titles => _FontSizeItem.titles,
    };
  }
}

class _FontSizeItem {
  const _FontSizeItem({
    required this.key,
    required this.labelKey,
    required this.initialValue,
    this.highlightKey,
  });

  final String key;
  final String labelKey;
  final String initialValue;
  final String? highlightKey;

  static const layoutSpecial = [
    _FontSizeItem(
      key: 'fs-base',
      labelKey: 'fontSettings.size.fsBase',
      highlightKey: 'fontSettings.size.main',
      initialValue: '15',
    ),
    _FontSizeItem(
      key: 'fs-post-title',
      labelKey: 'fontSettings.size.fsPostTitle',
      initialValue: '36',
    ),
    _FontSizeItem(
      key: 'fs-post-summary',
      labelKey: 'fontSettings.size.fsPostSummary',
      initialValue: '18',
    ),
    _FontSizeItem(
      key: 'fs-content',
      labelKey: 'fontSettings.size.fsContent',
      initialValue: '17',
    ),
    _FontSizeItem(
      key: 'fs-main-nav',
      labelKey: 'fontSettings.size.fsMainNav',
      initialValue: '15',
    ),
  ];

  static const general = [
    _FontSizeItem(
      key: 'fs-tiny',
      labelKey: 'fontSettings.size.fsTiny',
      initialValue: '11',
    ),
    _FontSizeItem(
      key: 'fs-xs',
      labelKey: 'fontSettings.size.fsXs',
      initialValue: '12',
    ),
    _FontSizeItem(
      key: 'fs-sm',
      labelKey: 'fontSettings.size.fsSm',
      initialValue: '13',
    ),
    _FontSizeItem(
      key: 'fs-md',
      labelKey: 'fontSettings.size.fsMd',
      initialValue: '14',
    ),
    _FontSizeItem(
      key: 'fs-lg',
      labelKey: 'fontSettings.size.fsLg',
      initialValue: '16',
    ),
    _FontSizeItem(
      key: 'fs-xl',
      labelKey: 'fontSettings.size.fsXl',
      initialValue: '18',
    ),
  ];

  static const titles = [
    _FontSizeItem(
      key: 'fs-title-xs',
      labelKey: 'fontSettings.size.fsTitleXs',
      initialValue: '15',
    ),
    _FontSizeItem(
      key: 'fs-title-sm',
      labelKey: 'fontSettings.size.fsTitleSm',
      initialValue: '16',
    ),
    _FontSizeItem(
      key: 'fs-title-md',
      labelKey: 'fontSettings.size.fsTitleMd',
      initialValue: '18',
    ),
    _FontSizeItem(
      key: 'fs-title-lg',
      labelKey: 'fontSettings.size.fsTitleLg',
      initialValue: '20',
    ),
    _FontSizeItem(
      key: 'fs-title-xl',
      labelKey: 'fontSettings.size.fsTitleXl',
      initialValue: '22',
    ),
    _FontSizeItem(
      key: 'fs-title-2xl',
      labelKey: 'fontSettings.size.fsTitle2xl',
      initialValue: '24',
    ),
    _FontSizeItem(
      key: 'fs-title-3xl',
      labelKey: 'fontSettings.size.fsTitle3xl',
      initialValue: '26',
    ),
    _FontSizeItem(
      key: 'fs-title-4xl',
      labelKey: 'fontSettings.size.fsTitle4xl',
      initialValue: '30',
    ),
    _FontSizeItem(
      key: 'fs-title-5xl',
      labelKey: 'fontSettings.size.fsTitle5xl',
      initialValue: '32',
    ),
  ];

  static const all = [...layoutSpecial, ...general, ...titles];
}

class _FontRow {
  const _FontRow({
    required this.id,
    required this.name,
    required this.sourceLabelKey,
  });

  final int id;
  final String name;
  final String sourceLabelKey;
}

class _SelectOption {
  const _SelectOption(this.value, [this.labelKey]);

  final String value;
  final String? labelKey;
}

const _languageOptions = [
  _SelectOption('tr', 'language.name.tr'),
  _SelectOption('en', 'language.name.en'),
  _SelectOption('ar', 'language.name.ar'),
];

const _fontSelectOptions = [
  _SelectOption('Open Sans'),
  _SelectOption('Plus Jakarta Sans'),
  _SelectOption('Inter'),
  _SelectOption('PateezSans'),
  _SelectOption('Roboto'),
  _SelectOption('Poppins'),
  _SelectOption('Montserrat'),
  _SelectOption('Work Sans'),
];

const _fontTypeOptions = [
  _SelectOption('sansSerif', 'fontSettings.dialog.type.sansSerif'),
  _SelectOption('serif', 'fontSettings.dialog.type.serif'),
  _SelectOption('monospace', 'fontSettings.dialog.type.monospace'),
  _SelectOption('cursive', 'fontSettings.dialog.type.cursive'),
  _SelectOption('fantasy', 'fontSettings.dialog.type.fantasy'),
  _SelectOption('systemUi', 'fontSettings.dialog.type.systemUi'),
];

const _fontRows = [
  _FontRow(
    id: 22,
    name: 'Work Sans',
    sourceLabelKey: 'fontSettings.source.local',
  ),
  _FontRow(
    id: 21,
    name: 'Verdana',
    sourceLabelKey: 'fontSettings.source.system',
  ),
  _FontRow(
    id: 20,
    name: 'Trebuchet MS',
    sourceLabelKey: 'fontSettings.source.system',
  ),
  _FontRow(
    id: 19,
    name: 'Times New Roman',
    sourceLabelKey: 'fontSettings.source.system',
  ),
  _FontRow(
    id: 18,
    name: 'Tahoma',
    sourceLabelKey: 'fontSettings.source.system',
  ),
  _FontRow(
    id: 17,
    name: 'Source Sans 3',
    sourceLabelKey: 'fontSettings.source.local',
  ),
  _FontRow(id: 16, name: 'Roboto', sourceLabelKey: 'fontSettings.source.local'),
  _FontRow(
    id: 15,
    name: 'Poppins',
    sourceLabelKey: 'fontSettings.source.local',
  ),
  _FontRow(
    id: 14,
    name: 'Plus Jakarta Sans',
    sourceLabelKey: 'fontSettings.source.local',
  ),
  _FontRow(
    id: 13,
    name: 'Open Sans',
    sourceLabelKey: 'fontSettings.source.local',
  ),
  _FontRow(
    id: 12,
    name: 'Noto Serif',
    sourceLabelKey: 'fontSettings.source.local',
  ),
  _FontRow(
    id: 11,
    name: 'Montserrat',
    sourceLabelKey: 'fontSettings.source.local',
  ),
  _FontRow(
    id: 10,
    name: 'Merriweather',
    sourceLabelKey: 'fontSettings.source.local',
  ),
  _FontRow(
    id: 9,
    name: 'Libre Baskerville',
    sourceLabelKey: 'fontSettings.source.local',
  ),
  _FontRow(id: 8, name: 'Jost', sourceLabelKey: 'fontSettings.source.local'),
  _FontRow(id: 7, name: 'Inter', sourceLabelKey: 'fontSettings.source.local'),
  _FontRow(
    id: 6,
    name: 'IBM Plex Sans',
    sourceLabelKey: 'fontSettings.source.local',
  ),
  _FontRow(
    id: 5,
    name: 'Helvetica Neue',
    sourceLabelKey: 'fontSettings.source.system',
  ),
  _FontRow(
    id: 4,
    name: 'Georgia',
    sourceLabelKey: 'fontSettings.source.system',
  ),
  _FontRow(id: 3, name: 'DM Sans', sourceLabelKey: 'fontSettings.source.local'),
  _FontRow(id: 2, name: 'Arial', sourceLabelKey: 'fontSettings.source.system'),
  _FontRow(
    id: 1,
    name: 'PateezSans',
    sourceLabelKey: 'fontSettings.source.local',
  ),
];
