import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/localization/admin_date_formatter.dart';
import '../../../core/localization/admin_language_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/icons/symbols.dart';
import '../../../shared/widgets/app_confirmation_dialog.dart';
import '../../../shared/widgets/sortable_table_header.dart';
import '../../../shared/widgets/symbol_icon.dart';
import 'mail_template_models.dart';

class MailTemplatesScreen extends StatefulWidget {
  const MailTemplatesScreen({super.key});

  @override
  State<MailTemplatesScreen> createState() => _MailTemplatesScreenState();
}

class _MailTemplatesScreenState extends State<MailTemplatesScreen> {
  var _templates = List<AdminMailTemplate>.of(sampleAdminMailTemplates);
  final _selectedTemplateIds = <int>{};
  final _searchController = TextEditingController();
  var _categoryFilter = mailTemplateFilterAll;
  var _searchQuery = '';
  var _page = 1;
  var _pageSize = 25;
  var _sortState = const TableSortState(key: 'date', ascending: false);
  AdminMailTemplate? _editorTemplate;
  var _creatingTemplate = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AdminMailTemplate> get _filteredTemplates {
    final query = _searchQuery.trim().toLowerCase();
    final filtered = _templates.where((template) {
      if (_categoryFilter != mailTemplateFilterAll &&
          template.category.value != _categoryFilter) {
        return false;
      }
      if (query.isEmpty) return true;

      final searchable = [
        context.t(template.nameKey),
        context.t(template.category.labelKey),
        context.t(template.previewText),
        template.subject,
        template.body,
      ].join(' ').toLowerCase();
      return searchable.contains(query);
    }).toList();

    filtered.sort((left, right) {
      final result = switch (_sortState.key) {
        'name' => context.t(left.nameKey).compareTo(context.t(right.nameKey)),
        'category' =>
          context
              .t(left.category.labelKey)
              .compareTo(context.t(right.category.labelKey)),
        'variable' => left.variableCount.compareTo(right.variableCount),
        'ready' => left.ready.toString().compareTo(right.ready.toString()),
        'status' => left.active.toString().compareTo(right.active.toString()),
        'date' || _ => left.updatedAt.compareTo(right.updatedAt),
      };
      return _sortState.ascending ? result : -result;
    });

    return filtered;
  }

  List<AdminMailTemplate> get _pagedTemplates {
    final filtered = _filteredTemplates;
    if (filtered.isEmpty) return const <AdminMailTemplate>[];
    final start = (_page - 1) * _pageSize;
    if (start >= filtered.length) return filtered.take(_pageSize).toList();
    final end = math.min(start + _pageSize, filtered.length);
    return filtered.sublist(start, end);
  }

  void _resetListState() {
    _page = 1;
    _selectedTemplateIds.clear();
  }

  void _changeCategory(String value) {
    setState(() {
      _categoryFilter = value;
      _resetListState();
    });
  }

  void _changePageSize(int? value) {
    if (value == null || value == _pageSize) return;
    setState(() {
      _pageSize = value;
      _resetListState();
    });
  }

  void _changeSearch(String value) {
    setState(() {
      _searchQuery = value;
      _resetListState();
    });
  }

  void _changeSort(String sortKey) {
    setState(() {
      _sortState = _sortState.toggled(sortKey);
      _resetListState();
    });
  }

  void _changePage(int page) {
    if (page == _page) return;
    setState(() {
      _page = page;
      _selectedTemplateIds.clear();
    });
  }

  void _toggleTemplate(int id) {
    setState(() {
      if (_selectedTemplateIds.contains(id)) {
        _selectedTemplateIds.remove(id);
      } else {
        _selectedTemplateIds.add(id);
      }
    });
  }

  void _toggleAllTemplates() {
    final ids = _pagedTemplates.map((template) => template.id).toSet();
    setState(() {
      if (ids.isNotEmpty && _selectedTemplateIds.containsAll(ids)) {
        _selectedTemplateIds.removeAll(ids);
      } else {
        _selectedTemplateIds
          ..clear()
          ..addAll(ids);
      }
    });
  }

  void _openEditor([AdminMailTemplate? template]) {
    setState(() {
      _editorTemplate = template;
      _creatingTemplate = template == null;
    });
  }

  void _closeEditor() {
    setState(() {
      _editorTemplate = null;
      _creatingTemplate = false;
    });
  }

  void _saveTemplate(AdminMailTemplate template) {
    setState(() {
      final index = _templates.indexWhere(
        (current) => current.id == template.id,
      );
      if (index == -1) {
        _templates = [template, ..._templates];
      } else {
        _templates = [
          for (final current in _templates)
            if (current.id == template.id) template else current,
        ];
      }
      _editorTemplate = null;
      _creatingTemplate = false;
      _resetListState();
    });
  }

  void _toggleActive(AdminMailTemplate template) {
    _replaceTemplate(template.copyWith(active: !template.active));
  }

  void _toggleReady(AdminMailTemplate template) {
    _replaceTemplate(template.copyWith(ready: !template.ready));
  }

  void _replaceTemplate(AdminMailTemplate template) {
    setState(() {
      _templates = [
        for (final current in _templates)
          if (current.id == template.id) template else current,
      ];
    });
  }

  Future<void> _deleteTemplate(AdminMailTemplate template) async {
    final confirmed = await showAppConfirmationDialog(
      context,
      title: context.t('mail.template.deleteTitle'),
      message: context.t('mail.template.deleteMessage'),
      confirmLabel: context.t('common.delete'),
      danger: true,
    );
    if (!confirmed) return;
    setState(() {
      _templates = _templates
          .where((current) => current.id != template.id)
          .toList(growable: false);
      _selectedTemplateIds.remove(template.id);
    });
  }

  Future<void> _deleteSelectedTemplates() async {
    if (_selectedTemplateIds.isEmpty) return;
    final confirmed = await showAppConfirmationDialog(
      context,
      title: context.t('mail.template.deleteSelectedTitle'),
      message: context.t(
        'mail.template.deleteSelectedMessage',
        values: {'count': _selectedTemplateIds.length},
      ),
      confirmLabel: context.t('common.delete'),
      danger: true,
    );
    if (!confirmed) return;
    setState(() {
      _templates = _templates
          .where((template) => !_selectedTemplateIds.contains(template.id))
          .toList(growable: false);
      _selectedTemplateIds.clear();
    });
  }

  void _showTemplateDetail(AdminMailTemplate template) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: context.t('common.cancel'),
      barrierColor: Colors.black.withValues(alpha: 0.48),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, animation, secondaryAnimation) {
        final width = MediaQuery.sizeOf(context).width;
        final mobile = width < 760;
        final drawerWidth = mobile ? width : math.min(780.0, width * 0.42);
        return SafeArea(
          child: Align(
            alignment: mobile ? Alignment.center : Alignment.centerRight,
            child: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: drawerWidth,
                height: double.infinity,
                child: _TemplateDetailDrawer(template: template),
              ),
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

  @override
  Widget build(BuildContext context) {
    if (_creatingTemplate || _editorTemplate != null) {
      return MailTemplateEditorView(
        template: _editorTemplate,
        onCancel: _closeEditor,
        onSaved: _saveTemplate,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 640 ? 16.0 : 28.0;
        final compact = constraints.maxWidth < 900;
        final filtered = _filteredTemplates;
        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MailTemplateTitle(
              selectedCount: _selectedTemplateIds.length,
              onDeleteSelected: _deleteSelectedTemplates,
            ),
            const SizedBox(height: 24),
            _TemplateCategoryChips(
              selectedValue: _categoryFilter,
              onChanged: _changeCategory,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _MailTemplateTableCard(
                templates: _pagedTemplates,
                page: _page,
                pageSize: _pageSize,
                totalCount: filtered.length,
                searchController: _searchController,
                searchQuery: _searchQuery,
                selectedTemplateIds: _selectedTemplateIds,
                sortState: _sortState,
                onPageSizeChanged: _changePageSize,
                onSearchChanged: _changeSearch,
                onPageChanged: _changePage,
                onToggleTemplate: _toggleTemplate,
                onToggleAllTemplates: _toggleAllTemplates,
                onSort: _changeSort,
                onCreate: () => _openEditor(),
                onEdit: _openEditor,
                onPreview: _showTemplateDetail,
                onToggleActive: _toggleActive,
                onToggleReady: _toggleReady,
                onDelete: _deleteTemplate,
              ),
            ),
          ],
        );

        if (compact) {
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              28,
              horizontalPadding,
              28,
            ),
            child: SizedBox(height: 1040, child: content),
          );
        }

        return Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            28,
            horizontalPadding,
            28,
          ),
          child: content,
        );
      },
    );
  }
}

class _MailTemplateTitle extends StatelessWidget {
  const _MailTemplateTitle({
    required this.selectedCount,
    required this.onDeleteSelected,
  });

  final int selectedCount;
  final VoidCallback onDeleteSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            context.t('mail.templates.title'),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.deepOcean,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ),
        if (selectedCount > 0)
          _TemplateDangerTextButton(
            label: context.t(
              'mail.template.selectedDelete',
              values: {'count': selectedCount},
            ),
            onTap: onDeleteSelected,
          ),
      ],
    );
  }
}

class _TemplateCategoryChips extends StatelessWidget {
  const _TemplateCategoryChips({
    required this.selectedValue,
    required this.onChanged,
  });

  final String selectedValue;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final filters = <_TemplateFilter>[
      const _TemplateFilter(
        value: mailTemplateFilterAll,
        labelKey: 'mail.template.category.all',
      ),
      for (final category in AdminMailTemplateCategory.values)
        _TemplateFilter(value: category.value, labelKey: category.labelKey),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final filter in filters)
          _TemplateFilterChip(
            label: context.t(filter.labelKey),
            selected: selectedValue == filter.value,
            onTap: () => onChanged(filter.value),
          ),
      ],
    );
  }
}

class _TemplateFilter {
  const _TemplateFilter({required this.value, required this.labelKey});

  final String value;
  final String labelKey;
}

class _TemplateFilterChip extends StatelessWidget {
  const _TemplateFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: TextButton(
        onPressed: onTap,
        style:
            TextButton.styleFrom(
              backgroundColor: selected ? AppColors.deepOcean : Colors.white,
              foregroundColor: selected ? Colors.white : AppColors.inkSoft,
              minimumSize: const Size(0, 34),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.value),
                side: BorderSide(
                  color: selected ? AppColors.deepOcean : AppColors.line,
                ),
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
        child: Text(label),
      ),
    );
  }
}

class _MailTemplateTableCard extends StatelessWidget {
  const _MailTemplateTableCard({
    required this.templates,
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.searchController,
    required this.searchQuery,
    required this.selectedTemplateIds,
    required this.sortState,
    required this.onPageSizeChanged,
    required this.onSearchChanged,
    required this.onPageChanged,
    required this.onToggleTemplate,
    required this.onToggleAllTemplates,
    required this.onSort,
    required this.onCreate,
    required this.onEdit,
    required this.onPreview,
    required this.onToggleActive,
    required this.onToggleReady,
    required this.onDelete,
  });

  static const _minTableWidth = 1180.0;

  final List<AdminMailTemplate> templates;
  final int page;
  final int pageSize;
  final int totalCount;
  final TextEditingController searchController;
  final String searchQuery;
  final Set<int> selectedTemplateIds;
  final TableSortState sortState;
  final ValueChanged<int?> onPageSizeChanged;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onToggleTemplate;
  final VoidCallback onToggleAllTemplates;
  final ValueChanged<String> onSort;
  final VoidCallback onCreate;
  final ValueChanged<AdminMailTemplate> onEdit;
  final ValueChanged<AdminMailTemplate> onPreview;
  final ValueChanged<AdminMailTemplate> onToggleActive;
  final ValueChanged<AdminMailTemplate> onToggleReady;
  final ValueChanged<AdminMailTemplate> onDelete;

  @override
  Widget build(BuildContext context) {
    final pageIds = templates.map((template) => template.id).toSet();
    final allSelected =
        pageIds.isNotEmpty && selectedTemplateIds.containsAll(pageIds);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TemplateListToolbar(
          pageSize: pageSize,
          searchController: searchController,
          searchQuery: searchQuery,
          onPageSizeChanged: onPageSizeChanged,
          onSearchChanged: onSearchChanged,
          onCreate: onCreate,
        ),
        const SizedBox(height: 18),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.line),
              borderRadius: BorderRadius.circular(AppRadius.value),
            ),
            clipBehavior: Clip.antiAlias,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = math.max(constraints.maxWidth, _minTableWidth);
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: width,
                    height: constraints.hasBoundedHeight
                        ? constraints.maxHeight
                        : null,
                    child: Column(
                      children: [
                        _TemplateTableHeader(
                          selected: allSelected,
                          sortState: sortState,
                          onToggle: onToggleAllTemplates,
                          onSort: onSort,
                        ),
                        Expanded(
                          child: templates.isEmpty
                              ? const _TemplateEmptyState()
                              : ListView.builder(
                                  itemCount: templates.length,
                                  itemBuilder: (context, index) {
                                    final template = templates[index];
                                    return _TemplateTableRow(
                                      template: template,
                                      selected: selectedTemplateIds.contains(
                                        template.id,
                                      ),
                                      sortState: sortState,
                                      onToggle: () =>
                                          onToggleTemplate(template.id),
                                      onEdit: () => onEdit(template),
                                      onPreview: () => onPreview(template),
                                      onToggleActive: () =>
                                          onToggleActive(template),
                                      onToggleReady: () =>
                                          onToggleReady(template),
                                      onDelete: () => onDelete(template),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        _TemplateFooter(
          page: page,
          pageSize: pageSize,
          totalCount: totalCount,
          onPageChanged: onPageChanged,
        ),
      ],
    );
  }
}

class _TemplateListToolbar extends StatelessWidget {
  const _TemplateListToolbar({
    required this.pageSize,
    required this.searchController,
    required this.searchQuery,
    required this.onPageSizeChanged,
    required this.onSearchChanged,
    required this.onCreate,
  });

  final int pageSize;
  final TextEditingController searchController;
  final String searchQuery;
  final ValueChanged<int?> onPageSizeChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _PageSizeSelect(value: pageSize, onChanged: onPageSizeChanged),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TemplateSearchField(
              controller: searchController,
              query: searchQuery,
              hint: context.t('mail.templates.searchPlaceholder'),
              onChanged: onSearchChanged,
            ),
            const SizedBox(width: 12),
            _TemplatePrimaryButton(
              icon: Symbols.add,
              label: context.t('mail.templates.new'),
              onTap: onCreate,
            ),
          ],
        ),
      ],
    );
  }
}

class _PageSizeSelect extends StatelessWidget {
  const _PageSizeSelect({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppRadius.value),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          isExpanded: true,
          borderRadius: BorderRadius.circular(AppRadius.value),
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
          onChanged: onChanged,
          items: const [10, 25, 50, 100]
              .map(
                (value) =>
                    DropdownMenuItem(value: value, child: Text('$value')),
              )
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _TemplateSearchField extends StatelessWidget {
  const _TemplateSearchField({
    required this.controller,
    required this.query,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String query;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      height: 38,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textAlignVertical: TextAlignVertical.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.deepOcean,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            color: AppColors.placeholder,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: 12, right: 6),
            child: SymbolIcon(
              Symbols.search,
              color: AppColors.iconMuted,
              size: 18,
            ),
          ),
          suffixIcon: query.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                  icon: const SymbolIcon(
                    Symbols.close,
                    color: AppColors.iconMuted,
                    size: 16,
                  ),
                ),
          prefixIconConstraints: const BoxConstraints(minWidth: 34),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          enabledBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(AppRadius.value)),
            borderSide: BorderSide(color: AppColors.line),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(AppRadius.value)),
            borderSide: BorderSide(color: AppColors.deepOcean),
          ),
        ),
      ),
    );
  }
}

class _TemplatePrimaryButton extends StatelessWidget {
  const _TemplatePrimaryButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: TextButton.icon(
        onPressed: onTap,
        icon: SymbolIcon(icon, color: Colors.white, size: 18),
        label: Text(label),
        style:
            TextButton.styleFrom(
              backgroundColor: AppColors.actionRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18),
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
      ),
    );
  }
}

class _TemplateTableHeader extends StatelessWidget {
  const _TemplateTableHeader({
    required this.selected,
    required this.sortState,
    required this.onToggle,
    required this.onSort,
  });

  static const _selectWidth = 48.0;
  static const _categoryWidth = 170.0;
  static const _variableWidth = 118.0;
  static const _readyWidth = 126.0;
  static const _statusWidth = 126.0;
  static const _actionsWidth = 74.0;
  static const _nameFlex = 4;
  static const _dateFlex = 3;

  final bool selected;
  final TableSortState sortState;
  final VoidCallback onToggle;
  final ValueChanged<String> onSort;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.softLine)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _selectWidth,
            child: Center(
              child: _TemplateCheckbox(selected: selected, onTap: onToggle),
            ),
          ),
          Expanded(
            flex: _nameFlex,
            child: _TemplateSortableHeader(
              label: 'mail.template.column.name',
              sortKey: 'name',
              sortState: sortState,
              onSort: onSort,
            ),
          ),
          SizedBox(
            width: _categoryWidth,
            child: _TemplateSortableHeader(
              label: 'mail.template.column.category',
              sortKey: 'category',
              sortState: sortState,
              onSort: onSort,
            ),
          ),
          SizedBox(
            width: _variableWidth,
            child: _TemplateSortableHeader(
              label: 'mail.template.column.variable',
              sortKey: 'variable',
              sortState: sortState,
              onSort: onSort,
            ),
          ),
          SizedBox(
            width: _readyWidth,
            child: _TemplateSortableHeader(
              label: 'mail.template.column.ready',
              sortKey: 'ready',
              sortState: sortState,
              onSort: onSort,
            ),
          ),
          SizedBox(
            width: _statusWidth,
            child: _TemplateSortableHeader(
              label: 'mail.template.column.status',
              sortKey: 'status',
              sortState: sortState,
              onSort: onSort,
            ),
          ),
          Expanded(
            flex: _dateFlex,
            child: _TemplateSortableHeader(
              label: 'mail.template.column.date',
              sortKey: 'date',
              sortState: sortState,
              onSort: onSort,
            ),
          ),
          SizedBox(
            width: _actionsWidth,
            child: Center(
              child: Text(
                context.t('mail.template.column.actions'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.inkSoft,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TemplateSortableHeader extends StatelessWidget {
  const _TemplateSortableHeader({
    required this.label,
    required this.sortKey,
    required this.sortState,
    required this.onSort,
  });

  final String label;
  final String sortKey;
  final TableSortState sortState;
  final ValueChanged<String> onSort;

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: 12, letterSpacing: 0),
      child: SortableTableHeader(
        label: label,
        sortKey: sortKey,
        sortState: sortState,
        onSort: onSort,
      ),
    );
  }
}

class _TemplateTableRow extends StatelessWidget {
  const _TemplateTableRow({
    required this.template,
    required this.selected,
    required this.sortState,
    required this.onToggle,
    required this.onEdit,
    required this.onPreview,
    required this.onToggleActive,
    required this.onToggleReady,
    required this.onDelete,
  });

  final AdminMailTemplate template;
  final bool selected;
  final TableSortState sortState;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onPreview;
  final VoidCallback onToggleActive;
  final VoidCallback onToggleReady;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.softLine)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _TemplateTableHeader._selectWidth,
            child: Center(
              child: _TemplateCheckbox(selected: selected, onTap: onToggle),
            ),
          ),
          Expanded(
            flex: _TemplateTableHeader._nameFlex,
            child: Text(
              context.t(template.nameKey),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.deepOcean,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                height: 1.2,
                letterSpacing: 0,
              ),
            ),
          ),
          SizedBox(
            width: _TemplateTableHeader._categoryWidth,
            child: Text(
              context.t(template.category.labelKey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.deepOcean,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
          ),
          SizedBox(
            width: _TemplateTableHeader._variableWidth,
            child: Text(
              template.variableCount.toString(),
              style: const TextStyle(
                color: AppColors.deepOcean,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
          ),
          SizedBox(
            width: _TemplateTableHeader._readyWidth,
            child: _TemplateStatusBadge(
              label: template.ready
                  ? context.t('mail.template.ready')
                  : context.t('mail.template.notReady'),
              color: template.ready
                  ? const Color(0xFF2F80ED)
                  : AppColors.support,
            ),
          ),
          SizedBox(
            width: _TemplateTableHeader._statusWidth,
            child: _TemplateStatusBadge(
              label: template.active
                  ? context.t('mail.template.active')
                  : context.t('mail.template.passive'),
              color: template.active
                  ? const Color(0xFF198754)
                  : AppColors.support,
            ),
          ),
          Expanded(
            flex: _TemplateTableHeader._dateFlex,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatAdminFullDate(context, template.updatedAt),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.deepOcean,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0,
                  ),
                ),
                Text(
                  formatAdminTime(template.updatedAt),
                  style: const TextStyle(
                    color: AppColors.iconMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: _TemplateTableHeader._actionsWidth,
            child: Align(
              alignment: Alignment.center,
              child: _TemplateRowMenu(
                template: template,
                onEdit: onEdit,
                onPreview: onPreview,
                onToggleActive: onToggleActive,
                onToggleReady: onToggleReady,
                onDelete: onDelete,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TemplateCheckbox extends StatelessWidget {
  const _TemplateCheckbox({required this.selected, required this.onTap});

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
          duration: const Duration(milliseconds: 150),
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: selected ? AppColors.deepOcean : Colors.white,
            border: Border.all(
              color: selected ? AppColors.deepOcean : AppColors.line,
            ),
            borderRadius: BorderRadius.circular(AppRadius.value),
          ),
          child: selected
              ? const SymbolIcon(Symbols.check, color: Colors.white, size: 14)
              : null,
        ),
      ),
    );
  }
}

class _TemplateStatusBadge extends StatelessWidget {
  const _TemplateStatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.value),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
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

class _TemplateRowMenu extends StatefulWidget {
  const _TemplateRowMenu({
    required this.template,
    required this.onEdit,
    required this.onPreview,
    required this.onToggleActive,
    required this.onToggleReady,
    required this.onDelete,
  });

  final AdminMailTemplate template;
  final VoidCallback onEdit;
  final VoidCallback onPreview;
  final VoidCallback onToggleActive;
  final VoidCallback onToggleReady;
  final VoidCallback onDelete;

  @override
  State<_TemplateRowMenu> createState() => _TemplateRowMenuState();
}

class _TemplateRowMenuState extends State<_TemplateRowMenu> {
  final _layerLink = LayerLink();
  OverlayEntry? _entry;

  @override
  void dispose() {
    _removeMenu();
    super.dispose();
  }

  void _toggleMenu() {
    if (_entry == null) {
      _showMenu();
    } else {
      _removeMenu();
    }
  }

  void _showMenu() {
    _entry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _removeMenu,
            ),
          ),
          CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            targetAnchor: Alignment.bottomRight,
            followerAnchor: Alignment.topRight,
            offset: const Offset(10, 8),
            child: _TemplateMenuCard(
              template: widget.template,
              onEdit: () => _tap(widget.onEdit),
              onPreview: () => _tap(widget.onPreview),
              onToggleActive: () => _tap(widget.onToggleActive),
              onToggleReady: () => _tap(widget.onToggleReady),
              onDelete: () => _tap(widget.onDelete),
            ),
          ),
        ],
      ),
    );
    Overlay.of(context).insert(_entry!);
  }

  void _tap(VoidCallback callback) {
    _removeMenu();
    callback();
  }

  void _removeMenu() {
    _entry?.remove();
    _entry = null;
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Tooltip(
        message: context.t('mail.template.actions'),
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

class _TemplateMenuCard extends StatelessWidget {
  const _TemplateMenuCard({
    required this.template,
    required this.onEdit,
    required this.onPreview,
    required this.onToggleActive,
    required this.onToggleReady,
    required this.onDelete,
  });

  final AdminMailTemplate template;
  final VoidCallback onEdit;
  final VoidCallback onPreview;
  final VoidCallback onToggleActive;
  final VoidCallback onToggleReady;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 232,
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
            _TemplateMenuItem(
              icon: Symbols.edit_square,
              label: 'mail.template.action.edit',
              onTap: onEdit,
            ),
            _TemplateMenuItem(
              icon: Symbols.visibility,
              label: 'mail.template.action.preview',
              color: AppColors.warmHorizon,
              onTap: onPreview,
            ),
            _TemplateMenuItem(
              icon: template.active
                  ? Symbols.visibility_off
                  : Symbols.visibility,
              label: template.active
                  ? 'mail.template.action.deactivate'
                  : 'mail.template.action.activate',
              onTap: onToggleActive,
            ),
            _TemplateMenuItem(
              icon: template.ready
                  ? Icons.remove_circle_outline
                  : Symbols.check,
              label: template.ready
                  ? 'mail.template.action.markNotReady'
                  : 'mail.template.action.markReady',
              onTap: onToggleReady,
            ),
            _TemplateMenuItem(
              icon: Symbols.delete,
              label: 'mail.template.action.delete',
              color: AppColors.actionRed,
              onTap: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateMenuItem extends StatelessWidget {
  const _TemplateMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = AppColors.deepOcean,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

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
            SymbolIcon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.t(label),
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

class _TemplateEmptyState extends StatelessWidget {
  const _TemplateEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        context.t('mail.templates.empty'),
        style: const TextStyle(
          color: AppColors.placeholder,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _TemplateFooter extends StatelessWidget {
  const _TemplateFooter({
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.onPageChanged,
  });

  final int page;
  final int pageSize;
  final int totalCount;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final totalPages = math.max(1, (totalCount / pageSize).ceil());
    final start = totalCount == 0 ? 0 : ((page - 1) * pageSize) + 1;
    final end = math.min(page * pageSize, totalCount);

    return Row(
      children: [
        Expanded(
          child: Text(
            context.t(
              'common.recordRange',
              values: {'from': start, 'to': end, 'total': totalCount},
            ),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.inkSoft,
              fontWeight: FontWeight.w500,
              letterSpacing: 0,
            ),
          ),
        ),
        _TemplatePagination(
          page: page,
          totalPages: totalPages,
          onPageChanged: onPageChanged,
        ),
      ],
    );
  }
}

class _TemplatePagination extends StatelessWidget {
  const _TemplatePagination({
    required this.page,
    required this.totalPages,
    required this.onPageChanged,
  });

  final int page;
  final int totalPages;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _PagerButton(
          label: '<<',
          enabled: page > 1,
          onTap: () => onPageChanged(1),
        ),
        const SizedBox(width: 8),
        _PagerButton(
          label: '<',
          enabled: page > 1,
          onTap: () => onPageChanged(page - 1),
        ),
        const SizedBox(width: 8),
        Container(
          width: 36,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.deepOcean,
            borderRadius: BorderRadius.circular(AppRadius.value),
          ),
          child: Text(
            '$page',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ),
        const SizedBox(width: 8),
        _PagerButton(
          label: '>',
          enabled: page < totalPages,
          onTap: () => onPageChanged(page + 1),
        ),
        const SizedBox(width: 8),
        _PagerButton(
          label: '>>',
          enabled: page < totalPages,
          onTap: () => onPageChanged(totalPages),
        ),
      ],
    );
  }
}

class _PagerButton extends StatelessWidget {
  const _PagerButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 34,
      child: TextButton(
        onPressed: enabled ? onTap : null,
        style: TextButton.styleFrom(
          backgroundColor: Colors.white,
          disabledBackgroundColor: Colors.white,
          foregroundColor: AppColors.deepOcean,
          disabledForegroundColor: AppColors.placeholder,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.value),
            side: const BorderSide(color: AppColors.line),
          ),
          textStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}

class _TemplateDangerTextButton extends StatelessWidget {
  const _TemplateDangerTextButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon: const SymbolIcon(
        Symbols.delete,
        color: AppColors.actionRed,
        size: 17,
      ),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.actionRed,
        textStyle: const TextStyle(
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _TemplateDetailDrawer extends StatelessWidget {
  const _TemplateDetailDrawer({required this.template});

  final AdminMailTemplate template;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 18, 16),
            child: Row(
              children: [
                const SymbolIcon(
                  Symbols.draft,
                  color: AppColors.inkSoft,
                  size: 23,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    context.t('mail.template.detailTitle'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.deepOcean,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const SymbolIcon(
                    Symbols.close,
                    color: AppColors.deepOcean,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.softLine),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppColors.line),
                  borderRadius: BorderRadius.circular(AppRadius.value),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      context.t(template.nameKey),
                      style: const TextStyle(
                        color: AppColors.deepOcean,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.t(template.category.labelKey).toUpperCase(),
                      style: TextStyle(
                        color: adminMailTemplateCategoryAccent(
                          template.category,
                        ),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _TemplatePreviewFrame(template: template, compact: true),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MailTemplateEditorView extends StatefulWidget {
  const MailTemplateEditorView({
    super.key,
    required this.template,
    required this.onCancel,
    required this.onSaved,
  });

  final AdminMailTemplate? template;
  final VoidCallback onCancel;
  final ValueChanged<AdminMailTemplate> onSaved;

  @override
  State<MailTemplateEditorView> createState() => _MailTemplateEditorViewState();
}

class _MailTemplateEditorViewState extends State<MailTemplateEditorView> {
  late final TextEditingController _subjectController;
  late final TextEditingController _previewController;
  late final TextEditingController _bodyController;
  var _selectedDevice = 'desktop';
  var _selectedBlock = 'mail.template.editor.block.text';

  @override
  void initState() {
    super.initState();
    final template = widget.template;
    _subjectController = TextEditingController(text: template?.subject ?? '');
    _previewController = TextEditingController(
      text: template?.previewText ?? 'mail.template.previewText',
    );
    _bodyController = TextEditingController(
      text:
          template?.body ??
          'Sayin {{uye_adi}}, Pateeznews uzerinden sizin icin hazirlanan duyuru.',
    );
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _previewController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _addToken(String token) {
    final current = _bodyController.text.trimRight();
    final separator = current.isEmpty ? '' : ' ';
    setState(() => _bodyController.text = '$current$separator$token');
  }

  int _variableCount() {
    final text = [
      _subjectController.text,
      _previewController.text,
      _bodyController.text,
    ].join(' ');
    final matches = RegExp(r'\{\{[^}]+\}\}').allMatches(text);
    return matches
        .map((match) => match.group(0))
        .whereType<String>()
        .toSet()
        .length;
  }

  Future<void> _save() async {
    final existing = widget.template;
    final payload = await showDialog<_TemplateSavePayload>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.34),
      builder: (context) => _TemplateSaveDialog(template: existing),
    );
    if (payload == null) return;

    final next = AdminMailTemplate(
      id: existing?.id ?? DateTime.now().millisecondsSinceEpoch,
      nameKey: payload.name,
      category: payload.category,
      variableCount: _variableCount(),
      ready: existing?.ready ?? false,
      active: existing?.active ?? true,
      updatedAt: DateTime.now(),
      subject: _subjectController.text.trim().isEmpty
          ? '{{uye_adi}}'
          : _subjectController.text.trim(),
      previewText: _previewController.text.trim().isEmpty
          ? 'mail.template.previewText'
          : _previewController.text.trim(),
      body: _bodyController.text.trim().isEmpty
          ? '{{uye_adi}}'
          : _bodyController.text.trim(),
    );
    widget.onSaved(next);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 640 ? 16.0 : 28.0;
        final minEditorWidth = 1320.0;
        final editorWidth = math.max(
          constraints.maxWidth - horizontalPadding * 2,
          minEditorWidth,
        );

        return Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            28,
            horizontalPadding,
            18,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.template == null
                          ? context.t('mail.template.editor.titleNew')
                          : context.t(widget.template!.nameKey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: AppColors.deepOcean,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                          ),
                    ),
                  ),
                  _TemplateSecondaryButton(
                    label: context.t('common.cancel'),
                    onTap: widget.onCancel,
                  ),
                  const SizedBox(width: 12),
                  _TemplatePrimaryButton(
                    icon: Symbols.save,
                    label: widget.template == null
                        ? context.t('mail.template.editor.save')
                        : context.t('mail.template.editor.update'),
                    onTap: _save,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: editorWidth,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: 280,
                          child: _TemplateVariablePanel(
                            onTokenSelected: _addToken,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _TemplateBuilderCanvas(
                            subjectController: _subjectController,
                            previewController: _previewController,
                            bodyController: _bodyController,
                            selectedDevice: _selectedDevice,
                            selectedBlock: _selectedBlock,
                            onDeviceChanged: (value) =>
                                setState(() => _selectedDevice = value),
                            onTokenDropped: _addToken,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 292,
                          child: _TemplateBlocksPanel(
                            selectedBlock: _selectedBlock,
                            onBlockSelected: (value) =>
                                setState(() => _selectedBlock = value),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TemplateVariablePanel extends StatefulWidget {
  const _TemplateVariablePanel({required this.onTokenSelected});

  final ValueChanged<String> onTokenSelected;

  @override
  State<_TemplateVariablePanel> createState() => _TemplateVariablePanelState();
}

class _TemplateVariablePanelState extends State<_TemplateVariablePanel> {
  final _controller = TextEditingController();
  var _query = '';
  var _expanded = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final variables = adminMailTemplateMemberVariables
        .where((variable) {
          final text = '${context.t(variable.labelKey)} ${variable.token}'
              .toLowerCase();
          return text.contains(_query.trim().toLowerCase());
        })
        .toList(growable: false);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppRadius.value),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.data_object_outlined,
                      size: 18,
                      color: AppColors.deepOcean,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.t('mail.template.editor.variables'),
                        style: const TextStyle(
                          color: AppColors.deepOcean,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  context.t('mail.template.editor.dragToEditor'),
                  style: const TextStyle(
                    color: AppColors.placeholder,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 12),
                _PanelSearchField(
                  controller: _controller,
                  hint: context.t('mail.template.editor.searchVariable'),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.softLine),
          _VariableGroupHeader(
            expanded: _expanded,
            count: adminMailTemplateMemberVariables.length,
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          if (_expanded)
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final variable in variables)
                        _VariableTokenChip(
                          variable: variable,
                          onTap: () => widget.onTokenSelected(variable.token),
                        ),
                    ],
                  ),
                ],
              ),
            )
          else
            const Spacer(),
        ],
      ),
    );
  }
}

class _PanelSearchField extends StatelessWidget {
  const _PanelSearchField({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(
          color: AppColors.deepOcean,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          letterSpacing: 0,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            color: AppColors.placeholder,
            fontWeight: FontWeight.w500,
            letterSpacing: 0,
          ),
          prefixIcon: const Icon(
            Icons.search,
            size: 17,
            color: AppColors.iconMuted,
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 34),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
          filled: true,
          fillColor: Colors.white,
          enabledBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(AppRadius.value)),
            borderSide: BorderSide(color: AppColors.line),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(AppRadius.value)),
            borderSide: BorderSide(color: AppColors.deepOcean),
          ),
        ),
      ),
    );
  }
}

class _VariableGroupHeader extends StatelessWidget {
  const _VariableGroupHeader({
    required this.expanded,
    required this.count,
    required this.onTap,
  });

  final bool expanded;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.softLine)),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(AppRadius.value),
                ),
                child: const Icon(
                  Icons.group_outlined,
                  size: 17,
                  color: Color(0xFF2F80ED),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.t('mail.template.editor.memberInfo'),
                  style: const TextStyle(
                    color: AppColors.deepOcean,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ),
              Container(
                height: 22,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: AppColors.iconMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              RotatedBox(
                quarterTurns: expanded ? 2 : 0,
                child: const SymbolIcon(
                  Symbols.keyboard_arrow_down,
                  color: AppColors.iconMuted,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VariableTokenChip extends StatelessWidget {
  const _VariableTokenChip({required this.variable, required this.onTap});

  final AdminMailTemplateVariable variable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final child = _VariableChipContent(variable: variable);
    return Draggable<String>(
      data: variable.token,
      feedback: Material(
        color: Colors.transparent,
        child: _VariableChipContent(variable: variable, dragging: true),
      ),
      childWhenDragging: Opacity(opacity: 0.45, child: child),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(onTap: onTap, child: child),
      ),
    );
  }
}

class _VariableChipContent extends StatelessWidget {
  const _VariableChipContent({required this.variable, this.dragging = false});

  final AdminMailTemplateVariable variable;
  final bool dragging;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 120),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: dragging ? AppColors.deepOcean : Colors.white,
        border: Border.all(
          color: dragging ? AppColors.deepOcean : AppColors.line,
        ),
        borderRadius: BorderRadius.circular(AppRadius.value),
        boxShadow: dragging
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            variable.icon,
            size: 14,
            color: dragging ? Colors.white : AppColors.iconMuted,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              context.t(variable.labelKey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: dragging ? Colors.white : AppColors.inkSoft,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TemplateBuilderCanvas extends StatelessWidget {
  const _TemplateBuilderCanvas({
    required this.subjectController,
    required this.previewController,
    required this.bodyController,
    required this.selectedDevice,
    required this.selectedBlock,
    required this.onDeviceChanged,
    required this.onTokenDropped,
  });

  final TextEditingController subjectController;
  final TextEditingController previewController;
  final TextEditingController bodyController;
  final String selectedDevice;
  final String selectedBlock;
  final ValueChanged<String> onDeviceChanged;
  final ValueChanged<String> onTokenDropped;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppRadius.value),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _BuilderToolbar(
            selectedDevice: selectedDevice,
            selectedBlock: selectedBlock,
            onDeviceChanged: onDeviceChanged,
          ),
          Expanded(
            child: DragTarget<String>(
              onAcceptWithDetails: (details) => onTokenDropped(details.data),
              builder: (context, candidate, rejected) {
                return Container(
                  color: candidate.isNotEmpty
                      ? const Color(0xFFEFF6FF)
                      : const Color(0xFFF3F6FA),
                  child: Center(
                    child: AnimatedBuilder(
                      animation: Listenable.merge([
                        subjectController,
                        previewController,
                        bodyController,
                      ]),
                      builder: (context, _) {
                        return _TemplateEmailCanvas(
                          subject: subjectController.text,
                          preview: previewController.text,
                          body: bodyController.text,
                          device: selectedDevice,
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BuilderToolbar extends StatelessWidget {
  const _BuilderToolbar({
    required this.selectedDevice,
    required this.selectedBlock,
    required this.onDeviceChanged,
  });

  final String selectedDevice;
  final String selectedBlock;
  final ValueChanged<String> onDeviceChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      color: const Color(0xFF242832),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          _ToolbarIconButton(
            selected: selectedDevice == 'desktop',
            tooltip: context.t('mail.template.editor.deviceDesktop'),
            icon: Icons.desktop_mac_outlined,
            onTap: () => onDeviceChanged('desktop'),
          ),
          _ToolbarIconButton(
            selected: selectedDevice == 'tablet',
            tooltip: context.t('mail.template.editor.deviceTablet'),
            icon: Icons.tablet_mac_outlined,
            onTap: () => onDeviceChanged('tablet'),
          ),
          _ToolbarIconButton(
            selected: selectedDevice == 'mobile',
            tooltip: context.t('mail.template.editor.deviceMobile'),
            icon: Icons.phone_iphone_outlined,
            onTap: () => onDeviceChanged('mobile'),
          ),
          const Spacer(),
          _ToolbarIconButton(
            selected: true,
            tooltip: context.t('mail.template.editor.canvas'),
            icon: Icons.crop_square_outlined,
            onTap: () {},
          ),
          _ToolbarIconButton(
            tooltip: context.t('mail.template.editor.livePreview'),
            icon: Icons.visibility_outlined,
            onTap: () {},
          ),
          _ToolbarIconButton(
            tooltip: context.t('mail.template.editor.code'),
            icon: Icons.code_outlined,
            onTap: () {},
          ),
          _ToolbarIconButton(
            tooltip: context.t('mail.template.editor.download'),
            icon: Icons.download_outlined,
            onTap: () {},
          ),
          _ToolbarIconButton(
            tooltip: context.t('mail.compose.undo'),
            icon: Icons.undo_outlined,
            onTap: () {},
          ),
          _ToolbarIconButton(
            tooltip: context.t('mail.compose.redo'),
            icon: Icons.redo_outlined,
            onTap: () {},
          ),
          const SizedBox(width: 12),
          _ToolbarLabel(text: context.t(selectedBlock)),
        ],
      ),
    );
  }
}

class _ToolbarIconButton extends StatelessWidget {
  const _ToolbarIconButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.selected = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final button = MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 30,
          height: 30,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.actionRed : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.value),
          ),
          child: Icon(
            icon,
            color: selected ? Colors.white : Colors.white70,
            size: 18,
          ),
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

class _ToolbarLabel extends StatelessWidget {
  const _ToolbarLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      constraints: const BoxConstraints(maxWidth: 160),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.value),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _TemplateEmailCanvas extends StatelessWidget {
  const _TemplateEmailCanvas({
    required this.subject,
    required this.preview,
    required this.body,
    required this.device,
  });

  final String subject;
  final String preview;
  final String body;
  final String device;

  @override
  Widget build(BuildContext context) {
    final width = switch (device) {
      'mobile' => 340.0,
      'tablet' => 470.0,
      _ => 620.0,
    };
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 26),
      child: SizedBox(
        width: width,
        child: _TemplatePreviewFrame(
          template: AdminMailTemplate(
            id: 0,
            nameKey: 'mail.template.previewTitle',
            category: AdminMailTemplateCategory.campaign,
            variableCount: 0,
            ready: true,
            active: true,
            updatedAt: DateTime.now(),
            subject: subject.isEmpty ? '{{uye_adi}}' : subject,
            previewText: preview.isEmpty
                ? 'mail.template.previewText'
                : preview,
            body: body.isEmpty ? '{{uye_adi}}' : body,
          ),
          compact: false,
        ),
      ),
    );
  }
}

class _TemplatePreviewFrame extends StatelessWidget {
  const _TemplatePreviewFrame({required this.template, required this.compact});

  final AdminMailTemplate template;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final bodyText = template.body;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        boxShadow: compact
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              vertical: compact ? 22 : 30,
              horizontal: compact ? 22 : 40,
            ),
            color: AppColors.deepOcean,
            child: Column(
              children: [
                Container(
                  width: 86,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Text(
                    'Pateez',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  context.t(template.subject),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 18 : 22,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: 58,
                  height: 3,
                  decoration: BoxDecoration(
                    color: AppColors.actionRed,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.all(compact ? 22 : 34),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.actionRed,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Text(
                    context.t('mail.template.previewBadge').toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.7,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  context.t(template.nameKey),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.deepOcean,
                    fontSize: compact ? 22 : 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.t(template.previewText),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.iconMuted,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 26),
                Container(
                  padding: EdgeInsets.all(compact ? 18 : 24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.value),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Container(
                          height: compact ? 120 : 170,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(
                              AppRadius.value,
                            ),
                          ),
                          child: Icon(
                            Icons.image_not_supported_outlined,
                            color: AppColors.placeholder.withValues(
                              alpha: 0.65,
                            ),
                            size: compact ? 64 : 82,
                          ),
                        ),
                      ),
                      const SizedBox(width: 22),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              bodyText,
                              style: const TextStyle(
                                color: AppColors.inkSoft,
                                fontWeight: FontWeight.w700,
                                height: 1.55,
                                letterSpacing: 0,
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Divider(color: AppColors.line),
                            const SizedBox(height: 14),
                            Text(
                              context.t('mail.template.previewPrice'),
                              style: const TextStyle(
                                color: AppColors.placeholder,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.6,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '{{uye_odul_puani}}',
                              style: const TextStyle(
                                color: AppColors.actionRed,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 40,
                  child: TextButton(
                    onPressed: () {},
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.deepOcean,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.value),
                      ),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                    child: Text(context.t('mail.template.previewButton')),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            color: AppColors.surface,
            child: Column(
              children: [
                Text(
                  context.t('mail.template.previewFooterTitle'),
                  style: const TextStyle(
                    color: AppColors.deepOcean,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  context.t('mail.template.previewFooter'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.placeholder,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TemplateBlocksPanel extends StatelessWidget {
  const _TemplateBlocksPanel({
    required this.selectedBlock,
    required this.onBlockSelected,
  });

  final String selectedBlock;
  final ValueChanged<String> onBlockSelected;

  @override
  Widget build(BuildContext context) {
    final blocks = [
      _TemplateBlock(
        Icons.crop_square_outlined,
        'mail.template.editor.block.oneColumn',
      ),
      _TemplateBlock(
        Icons.view_week_outlined,
        'mail.template.editor.block.twoColumn',
      ),
      _TemplateBlock(
        Icons.view_column_outlined,
        'mail.template.editor.block.threeColumn',
      ),
      _TemplateBlock(Icons.title_outlined, 'mail.template.editor.block.text'),
      _TemplateBlock(
        Icons.smart_button_outlined,
        'mail.template.editor.block.button',
      ),
      _TemplateBlock(Icons.image_outlined, 'mail.template.editor.block.image'),
      _TemplateBlock(
        Icons.format_align_left_outlined,
        'mail.template.editor.block.divider',
      ),
      _TemplateBlock(
        Icons.share_outlined,
        'mail.template.editor.block.socialGroup',
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2B2D36),
        borderRadius: BorderRadius.circular(AppRadius.value),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            color: const Color(0xFF242832),
            child: Row(
              children: [
                const Icon(
                  Icons.brush_outlined,
                  color: Colors.white70,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.t('mail.template.editor.blocks'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                const Icon(
                  Icons.grid_view_outlined,
                  color: AppColors.actionRed,
                  size: 22,
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: blocks.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.92,
              ),
              itemBuilder: (context, index) {
                final block = blocks[index];
                return _TemplateBlockTile(
                  block: block,
                  selected: selectedBlock == block.labelKey,
                  onTap: () => onBlockSelected(block.labelKey),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TemplateBlock {
  const _TemplateBlock(this.icon, this.labelKey);

  final IconData icon;
  final String labelKey;
}

class _TemplateBlockTile extends StatelessWidget {
  const _TemplateBlockTile({
    required this.block,
    required this.selected,
    required this.onTap,
  });

  final _TemplateBlock block;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: selected
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.transparent,
            border: Border.all(
              color: selected ? AppColors.actionRed : Colors.white54,
            ),
            borderRadius: BorderRadius.circular(AppRadius.value),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                block.icon,
                color: selected ? AppColors.actionRed : Colors.white54,
                size: 54,
              ),
              const SizedBox(height: 14),
              Text(
                context.t(block.labelKey),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white60,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TemplateSecondaryButton extends StatelessWidget {
  const _TemplateSecondaryButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: TextButton(
        onPressed: onTap,
        style:
            TextButton.styleFrom(
              foregroundColor: AppColors.deepOcean,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.value),
                side: const BorderSide(color: AppColors.line),
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ).copyWith(
              mouseCursor: const WidgetStatePropertyAll(
                SystemMouseCursors.click,
              ),
            ),
        child: Text(label),
      ),
    );
  }
}

class _TemplateSaveDialog extends StatefulWidget {
  const _TemplateSaveDialog({required this.template});

  final AdminMailTemplate? template;

  @override
  State<_TemplateSaveDialog> createState() => _TemplateSaveDialogState();
}

class _TemplateSaveDialogState extends State<_TemplateSaveDialog> {
  late final TextEditingController _nameController;
  late AdminMailTemplateCategory _category;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.template == null ? '' : '',
    );
    _category = widget.template?.category ?? AdminMailTemplateCategory.campaign;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.template != null && _nameController.text.isEmpty) {
      _nameController.text = context.t(widget.template!.nameKey);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    Navigator.of(
      context,
    ).pop(_TemplateSavePayload(name: name, category: _category));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      backgroundColor: Colors.transparent,
      child: Container(
        width: 520,
        padding: const EdgeInsets.fromLTRB(26, 24, 26, 22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.value),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.template == null
                        ? context.t('mail.template.editor.saveTitle')
                        : context.t('mail.template.editor.updateTitle'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.deepOcean,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const SymbolIcon(
                    Symbols.close,
                    color: AppColors.deepOcean,
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              context.t('mail.template.editor.formSubtitle'),
              style: const TextStyle(
                color: AppColors.inkSoft,
                fontWeight: FontWeight.w500,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 20),
            _DialogLabel(text: context.t('mail.template.editor.name')),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: _dialogInputDecoration(
                context.t('mail.template.editor.nameHint'),
              ),
            ),
            const SizedBox(height: 16),
            _DialogLabel(text: context.t('mail.template.editor.category')),
            const SizedBox(height: 8),
            DropdownButtonFormField<AdminMailTemplateCategory>(
              initialValue: _category,
              borderRadius: BorderRadius.circular(AppRadius.value),
              decoration: _dialogInputDecoration(''),
              icon: const SymbolIcon(
                Symbols.keyboard_arrow_down,
                color: AppColors.iconMuted,
              ),
              items: AdminMailTemplateCategory.values
                  .map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Text(context.t(category.labelKey)),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _category = value);
              },
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _TemplateSecondaryButton(
                  label: context.t('common.cancel'),
                  onTap: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 12),
                _TemplatePrimaryButton(
                  icon: Symbols.save,
                  label: context.t('mail.template.editor.save'),
                  onTap: _submit,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _dialogInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint.isEmpty ? null : hint,
      hintStyle: const TextStyle(
        color: AppColors.placeholder,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.value)),
        borderSide: BorderSide(color: AppColors.line),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.value)),
        borderSide: BorderSide(color: AppColors.deepOcean),
      ),
    );
  }
}

class _DialogLabel extends StatelessWidget {
  const _DialogLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.deepOcean,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
    );
  }
}

class _TemplateSavePayload {
  const _TemplateSavePayload({required this.name, required this.category});

  final String name;
  final AdminMailTemplateCategory category;
}
