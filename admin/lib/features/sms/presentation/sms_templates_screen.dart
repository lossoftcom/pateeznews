import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/widgets/admin_table_chrome.dart';
import 'package:pateeznews_admin/shared/widgets/admin_toast.dart';

import '../../../core/localization/admin_date_formatter.dart';
import '../../../core/localization/admin_language_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/icons/symbols.dart';
import '../../../shared/widgets/admin_mobile_list.dart';
import '../../../shared/widgets/app_confirmation_dialog.dart';
import '../../../shared/widgets/sortable_table_header.dart';
import '../../../shared/widgets/symbol_icon.dart';
import '../../auth/data/admin_auth_models.dart';
import '../data/admin_sms_repository.dart';
import 'sms_message_preview.dart';
import 'sms_template_models.dart';

class SmsTemplatesScreen extends StatefulWidget {
  const SmsTemplatesScreen({
    super.key,
    required this.session,
    this.repository = const SupabaseAdminSmsRepository(),
  });

  final AdminSession session;
  final AdminSmsRepository repository;

  @override
  State<SmsTemplatesScreen> createState() => _SmsTemplatesScreenState();
}

class _SmsTemplatesScreenState extends State<SmsTemplatesScreen> {
  var _templates = <AdminSmsTemplate>[];
  final _selectedTemplateIds = <int>{};
  final _searchController = TextEditingController();
  var _categoryFilter = smsTemplateFilterAll;
  var _searchQuery = '';
  var _page = 1;
  var _pageSize = 25;
  var _sortState = const TableSortState(key: 'date', ascending: false);
  AdminSmsTemplate? _editorTemplate;
  var _creatingTemplate = false;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadTemplates());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTemplates() async {
    setState(() => _loading = true);
    try {
      final templates = await widget.repository.fetchTemplates(widget.session);
      if (!mounted) return;
      setState(() {
        _templates = templates;
        _loading = false;
        _resetListState();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showSmsError(error);
    }
  }

  void _showSmsError(Object error) {
    AdminToast.show(
      context,
      message: error.toString(),
      tone: AdminToastTone.error,
    );
  }

  List<AdminSmsTemplate> get _filteredTemplates {
    final query = _searchQuery.trim().toLowerCase();
    final filtered = _templates.where((template) {
      if (_categoryFilter != smsTemplateFilterAll &&
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

  List<AdminSmsTemplate> get _pagedTemplates {
    final filtered = _filteredTemplates;
    if (filtered.isEmpty) return const <AdminSmsTemplate>[];
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

  void _openEditor([AdminSmsTemplate? template]) {
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

  Future<void> _saveTemplate(AdminSmsTemplate template) async {
    late final AdminSmsTemplate saved;
    try {
      saved = await widget.repository.saveTemplate(
        widget.session,
        id: _editorTemplate?.id,
        template: template,
      );
    } catch (error) {
      if (mounted) _showSmsError(error);
      return;
    }
    if (!mounted) return;
    setState(() {
      final index = _templates.indexWhere((current) => current.id == saved.id);
      if (index == -1) {
        _templates = [saved, ..._templates];
      } else {
        _templates = [
          for (final current in _templates)
            if (current.id == saved.id) saved else current,
        ];
      }
      _editorTemplate = null;
      _creatingTemplate = false;
      _resetListState();
    });
  }

  Future<void> _toggleActive(AdminSmsTemplate template) async {
    try {
      final updated = await widget.repository.updateTemplate(
        widget.session,
        template,
        {'is_active': !template.active},
      );
      if (mounted) _replaceTemplate(updated);
    } catch (error) {
      if (mounted) _showSmsError(error);
    }
  }

  Future<void> _toggleReady(AdminSmsTemplate template) async {
    try {
      final updated = await widget.repository.updateTemplate(
        widget.session,
        template,
        {'is_ready': !template.ready},
      );
      if (mounted) _replaceTemplate(updated);
    } catch (error) {
      if (mounted) _showSmsError(error);
    }
  }

  void _replaceTemplate(AdminSmsTemplate template) {
    setState(() {
      _templates = [
        for (final current in _templates)
          if (current.id == template.id) template else current,
      ];
    });
  }

  Future<void> _deleteTemplate(AdminSmsTemplate template) async {
    final confirmed = await showAppConfirmationDialog(
      context,
      title: context.t('sms.template.deleteTitle'),
      message: context.t('sms.template.deleteMessage'),
      confirmLabel: context.t('common.delete'),
      danger: true,
    );
    if (!confirmed) return;
    try {
      await widget.repository.deleteTemplates(widget.session, [template.id]);
      if (!mounted) return;
      setState(() {
        _templates = _templates
            .where((current) => current.id != template.id)
            .toList(growable: false);
        _selectedTemplateIds.remove(template.id);
      });
    } catch (error) {
      if (mounted) _showSmsError(error);
    }
  }

  Future<void> _deleteSelectedTemplates() async {
    if (_selectedTemplateIds.isEmpty) return;
    final confirmed = await showAppConfirmationDialog(
      context,
      title: context.t('sms.template.deleteSelectedTitle'),
      message: context.t(
        'sms.template.deleteSelectedMessage',
        values: {'count': _selectedTemplateIds.length},
      ),
      confirmLabel: context.t('common.delete'),
      danger: true,
    );
    if (!confirmed) return;
    try {
      final ids = _selectedTemplateIds.toList(growable: false);
      await widget.repository.deleteTemplates(widget.session, ids);
      if (!mounted) return;
      setState(() {
        _templates = _templates
            .where((template) => !ids.contains(template.id))
            .toList(growable: false);
        _selectedTemplateIds.clear();
      });
    } catch (error) {
      if (mounted) _showSmsError(error);
    }
  }

  void _showTemplateDetail(AdminSmsTemplate template) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: context.t('common.cancel'),
      barrierColor: Colors.black.withValues(alpha: 0.48),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, animation, secondaryAnimation) {
        final width = MediaQuery.sizeOf(context).width;
        final mobile = width < 620;
        final drawerWidth = mobile ? width : math.min(440.0, width * 0.32);
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
      return SmsTemplateEditorView(
        template: _editorTemplate,
        onCancel: _closeEditor,
        onSaved: _saveTemplate,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 640 ? 16.0 : 28.0;
        final mobile = constraints.maxWidth < AdminMobile.breakpoint;
        final compact = constraints.maxWidth < 900;
        final topPadding = mobile ? 18.0 : 28.0;
        final filtered = _filteredTemplates;
        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SmsTemplateTitle(
              selectedCount: _selectedTemplateIds.length,
              onDeleteSelected: _deleteSelectedTemplates,
            ),
            SizedBox(height: mobile ? 12 : 24),
            _TemplateCategoryChips(
              selectedValue: _categoryFilter,
              onChanged: _changeCategory,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _SmsTemplateTableCard(
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
            if (_loading) const LinearProgressIndicator(minHeight: 2),
          ],
        );

        if (compact) {
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              topPadding,
              horizontalPadding,
              28,
            ),
            child: SizedBox(height: 1040, child: content),
          );
        }

        return Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            topPadding,
            horizontalPadding,
            28,
          ),
          child: content,
        );
      },
    );
  }
}

class _SmsTemplateTitle extends StatelessWidget {
  const _SmsTemplateTitle({
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
            context.t('sms.templates.title'),
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
              'sms.template.selectedDelete',
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
        value: smsTemplateFilterAll,
        labelKey: 'sms.template.category.all',
      ),
      for (final category in AdminSmsTemplateCategory.values)
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

class _SmsTemplateTableCard extends StatelessWidget {
  const _SmsTemplateTableCard({
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

  static const _minTableWidth = 900.0;

  final List<AdminSmsTemplate> templates;
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
  final ValueChanged<AdminSmsTemplate> onEdit;
  final ValueChanged<AdminSmsTemplate> onPreview;
  final ValueChanged<AdminSmsTemplate> onToggleActive;
  final ValueChanged<AdminSmsTemplate> onToggleReady;
  final ValueChanged<AdminSmsTemplate> onDelete;

  @override
  Widget build(BuildContext context) {
    final pageIds = templates.map((template) => template.id).toSet();
    final allSelected =
        pageIds.isNotEmpty && selectedTemplateIds.containsAll(pageIds);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < AdminMobile.breakpoint) {
          return _SmsTemplateMobileView(
            templates: templates,
            page: page,
            pageSize: pageSize,
            totalCount: totalCount,
            searchController: searchController,
            searchQuery: searchQuery,
            selectedTemplateIds: selectedTemplateIds,
            onSearchChanged: onSearchChanged,
            onPageChanged: onPageChanged,
            onToggleTemplate: onToggleTemplate,
            onCreate: onCreate,
            onEdit: onEdit,
            onPreview: onPreview,
            onToggleActive: onToggleActive,
            onToggleReady: onToggleReady,
            onDelete: onDelete,
          );
        }
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
                    final width = math.max(
                      constraints.maxWidth,
                      _minTableWidth,
                    );
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
                                          selected: selectedTemplateIds
                                              .contains(template.id),
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
      },
    );
  }
}

class _SmsTemplateMobileView extends StatelessWidget {
  const _SmsTemplateMobileView({
    required this.templates,
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.searchController,
    required this.searchQuery,
    required this.selectedTemplateIds,
    required this.onSearchChanged,
    required this.onPageChanged,
    required this.onToggleTemplate,
    required this.onCreate,
    required this.onEdit,
    required this.onPreview,
    required this.onToggleActive,
    required this.onToggleReady,
    required this.onDelete,
  });

  final List<AdminSmsTemplate> templates;
  final int page;
  final int pageSize;
  final int totalCount;
  final TextEditingController searchController;
  final String searchQuery;
  final Set<int> selectedTemplateIds;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onToggleTemplate;
  final VoidCallback onCreate;
  final ValueChanged<AdminSmsTemplate> onEdit;
  final ValueChanged<AdminSmsTemplate> onPreview;
  final ValueChanged<AdminSmsTemplate> onToggleActive;
  final ValueChanged<AdminSmsTemplate> onToggleReady;
  final ValueChanged<AdminSmsTemplate> onDelete;

  @override
  Widget build(BuildContext context) {
    final lastPage = totalCount == 0 ? 1 : ((totalCount - 1) ~/ pageSize) + 1;
    final from = totalCount == 0 ? 0 : ((page - 1) * pageSize) + 1;
    final to = totalCount == 0
        ? 0
        : (page * pageSize > totalCount ? totalCount : page * pageSize);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminMobileToolbar(
          controller: searchController,
          query: searchQuery,
          hintText: context.t('sms.templates.searchPlaceholder'),
          onSearchChanged: onSearchChanged,
          activeFilterCount: 0,
          onOpenFilters: () {},
          showFilters: false,
        ),
        const SizedBox(height: 12),
        AdminMobilePrimaryButton(
          icon: Symbols.add,
          label: context.t('sms.templates.new'),
          fullWidth: true,
          onPressed: onCreate,
        ),
        const SizedBox(height: 14),
        Expanded(
          child: AdminMobileListView(
            loading: false,
            itemCount: templates.length,
            emptyLabel: context.t('sms.templates.empty'),
            itemBuilder: (context, index) {
              final template = templates[index];
              return _SmsTemplateMobileCard(
                template: template,
                selected: selectedTemplateIds.contains(template.id),
                onToggle: () => onToggleTemplate(template.id),
                onEdit: () => onEdit(template),
                onPreview: () => onPreview(template),
                onToggleActive: () => onToggleActive(template),
                onToggleReady: () => onToggleReady(template),
                onDelete: () => onDelete(template),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        AdminMobilePager(
          page: page,
          lastPage: lastPage,
          rangeText: context.t(
            'common.recordRange',
            values: {'from': from, 'to': to, 'total': totalCount},
          ),
          loading: false,
          onPageChanged: onPageChanged,
        ),
      ],
    );
  }
}

class _SmsTemplateMobileCard extends StatelessWidget {
  const _SmsTemplateMobileCard({
    required this.template,
    required this.selected,
    required this.onToggle,
    required this.onEdit,
    required this.onPreview,
    required this.onToggleActive,
    required this.onToggleReady,
    required this.onDelete,
  });

  final AdminSmsTemplate template;
  final bool selected;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onPreview;
  final VoidCallback onToggleActive;
  final VoidCallback onToggleReady;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final subject = template.subject.trim();

    return AdminMobileCard(
      selected: selected,
      onTap: onToggle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AdminMobileCheckbox(
                value: selected,
                onChanged: (_) => onToggle(),
              ),
              const SizedBox(width: 12),
              const AdminMobileThumb(fallbackIcon: Symbols.article),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.t(template.nameKey),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.deepOcean,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      context.t(template.category.labelKey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.support,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              AdminMobileMenuButton(
                tooltip: context.t('sms.template.actions'),
                actions: [
                  AdminMobileMenuAction(
                    icon: Symbols.edit_square,
                    label: context.t('sms.template.action.edit'),
                    onTap: onEdit,
                  ),
                  AdminMobileMenuAction(
                    icon: Symbols.visibility,
                    label: context.t('sms.template.action.preview'),
                    onTap: onPreview,
                  ),
                  AdminMobileMenuAction(
                    icon: template.active
                        ? Symbols.visibility_off
                        : Symbols.visibility,
                    label: context.t(
                      template.active
                          ? 'sms.template.action.deactivate'
                          : 'sms.template.action.activate',
                    ),
                    onTap: onToggleActive,
                  ),
                  AdminMobileMenuAction(
                    icon: template.ready
                        ? Symbols.remove_circle_outline
                        : Symbols.check,
                    label: context.t(
                      template.ready
                          ? 'sms.template.action.markNotReady'
                          : 'sms.template.action.markReady',
                    ),
                    onTap: onToggleReady,
                  ),
                  AdminMobileMenuAction(
                    icon: Symbols.delete,
                    label: context.t('sms.template.action.delete'),
                    danger: true,
                    onTap: onDelete,
                  ),
                ],
              ),
            ],
          ),
          if (subject.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              subject,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.32,
                color: AppColors.inkSoft,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Divider(height: 1, color: AppColors.softLine.withValues(alpha: 0.9)),
          const SizedBox(height: 10),
          Row(
            children: [
              AdminMobileStatusPill(
                label: template.ready
                    ? context.t('sms.template.ready')
                    : context.t('sms.template.notReady'),
                color: template.ready
                    ? const Color(0xFF2F80ED)
                    : AppColors.support,
              ),
              const SizedBox(width: 8),
              AdminMobileStatusPill(
                label: template.active
                    ? context.t('sms.template.active')
                    : context.t('sms.template.passive'),
                color: template.active
                    ? const Color(0xFF198754)
                    : AppColors.support,
              ),
              const Spacer(),
              AdminMobileMeta(
                icon: Symbols.code,
                value: '${template.variableCount}',
              ),
            ],
          ),
        ],
      ),
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
              hint: context.t('sms.templates.searchPlaceholder'),
              onChanged: onSearchChanged,
            ),
            const SizedBox(width: 12),
            _TemplatePrimaryButton(
              icon: Symbols.add,
              label: context.t('sms.templates.new'),
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
    return AdminTablePageSizeSelect(value: value, onChanged: onChanged);
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
      width: 280,
      child: AdminTableSearchField(
        controller: controller,
        query: query,
        hintText: hint,
        showClearButton: true,
        onChanged: onChanged,
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
    return AdminTablePrimaryActionButton(
      icon: icon,
      label: label,
      onPressed: onTap,
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

  static const _selectWidth = 42.0;
  static const _categoryWidth = 170.0;
  static const _variableWidth = 118.0;
  static const _readyWidth = 126.0;
  static const _statusWidth = 126.0;
  static const _actionsWidth = 76.0;
  static const _nameFlex = 4;
  static const _dateFlex = 3;

  final bool selected;
  final TableSortState sortState;
  final VoidCallback onToggle;
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
            width: _selectWidth,
            child: Center(
              child: _TemplateCheckbox(selected: selected, onTap: onToggle),
            ),
          ),
          Expanded(
            flex: _nameFlex,
            child: _TemplateSortableHeader(
              label: 'sms.template.column.name',
              sortKey: 'name',
              sortState: sortState,
              onSort: onSort,
            ),
          ),
          SizedBox(
            width: _categoryWidth,
            child: _TemplateSortableHeader(
              label: 'sms.template.column.category',
              sortKey: 'category',
              sortState: sortState,
              onSort: onSort,
            ),
          ),
          SizedBox(
            width: _variableWidth,
            child: _TemplateSortableHeader(
              label: 'sms.template.column.variable',
              sortKey: 'variable',
              sortState: sortState,
              onSort: onSort,
            ),
          ),
          SizedBox(
            width: _readyWidth,
            child: _TemplateSortableHeader(
              label: 'sms.template.column.ready',
              sortKey: 'ready',
              sortState: sortState,
              onSort: onSort,
            ),
          ),
          SizedBox(
            width: _statusWidth,
            child: _TemplateSortableHeader(
              label: 'sms.template.column.status',
              sortKey: 'status',
              sortState: sortState,
              onSort: onSort,
            ),
          ),
          Expanded(
            flex: _dateFlex,
            child: _TemplateSortableHeader(
              label: 'sms.template.column.date',
              sortKey: 'date',
              sortState: sortState,
              onSort: onSort,
            ),
          ),
          SizedBox(
            width: _actionsWidth,
            child: Center(
              child: Text(
                context.t('sms.template.column.actions'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.inkSoft,
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
      style: const TextStyle(letterSpacing: 0),
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

  final AdminSmsTemplate template;
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.softLine.withValues(alpha: 0.86)),
        ),
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
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.22,
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
                  ? context.t('sms.template.ready')
                  : context.t('sms.template.notReady'),
              color: template.ready
                  ? const Color(0xFF2F80ED)
                  : AppColors.support,
            ),
          ),
          SizedBox(
            width: _TemplateTableHeader._statusWidth,
            child: _TemplateStatusBadge(
              label: template.active
                  ? context.t('sms.template.active')
                  : context.t('sms.template.passive'),
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

  final AdminSmsTemplate template;
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
        message: context.t('sms.template.actions'),
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

  final AdminSmsTemplate template;
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
              label: 'sms.template.action.edit',
              onTap: onEdit,
            ),
            _TemplateMenuItem(
              icon: Symbols.visibility,
              label: 'sms.template.action.preview',
              color: AppColors.warmHorizon,
              onTap: onPreview,
            ),
            _TemplateMenuItem(
              icon: template.active
                  ? Symbols.visibility_off
                  : Symbols.visibility,
              label: template.active
                  ? 'sms.template.action.deactivate'
                  : 'sms.template.action.activate',
              onTap: onToggleActive,
            ),
            _TemplateMenuItem(
              icon: template.ready
                  ? Symbols.remove_circle_outline
                  : Symbols.check,
              label: template.ready
                  ? 'sms.template.action.markNotReady'
                  : 'sms.template.action.markReady',
              onTap: onToggleReady,
            ),
            _TemplateMenuItem(
              icon: Symbols.delete,
              label: 'sms.template.action.delete',
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
        context.t('sms.templates.empty'),
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
    return AdminTablePagination(
      page: page,
      pageCount: totalPages,
      onPageChanged: onPageChanged,
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

  final AdminSmsTemplate template;

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
                    context.t('sms.template.detailTitle'),
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
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 348),
                  child: Container(
                    padding: const EdgeInsets.all(12),
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
                            color: adminSmsTemplateCategoryAccent(
                              template.category,
                            ),
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _TemplatePreviewFrame(
                          template: template,
                          compact: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SmsTemplateEditorView extends StatefulWidget {
  const SmsTemplateEditorView({
    super.key,
    required this.template,
    required this.onCancel,
    required this.onSaved,
  });

  final AdminSmsTemplate? template;
  final VoidCallback onCancel;
  final ValueChanged<AdminSmsTemplate> onSaved;

  @override
  State<SmsTemplateEditorView> createState() => _SmsTemplateEditorViewState();
}

const _maxTemplateActions = 10;
const _maxSurveyOptions = 10;

class _SmsButtonDraft {
  _SmsButtonDraft({String label = '', String url = '', String phone = ''})
    : labelController = TextEditingController(text: label),
      urlController = TextEditingController(text: url),
      phoneController = TextEditingController(text: phone);

  final TextEditingController labelController;
  final TextEditingController urlController;
  final TextEditingController phoneController;

  List<Listenable> get listenables => [
    labelController,
    urlController,
    phoneController,
  ];

  _SmsButtonPreviewData toPreviewData() {
    return _SmsButtonPreviewData(
      label: labelController.text,
      url: urlController.text,
      phone: phoneController.text,
    );
  }

  void dispose() {
    labelController.dispose();
    urlController.dispose();
    phoneController.dispose();
  }
}

class _SmsButtonPreviewData {
  const _SmsButtonPreviewData({
    required this.label,
    required this.url,
    required this.phone,
  });

  final String label;
  final String url;
  final String phone;

  bool get hasLabel => label.trim().isNotEmpty;
  bool get hasUrl => url.trim().isNotEmpty;
  bool get hasPhone => phone.trim().isNotEmpty;
}

class _SmsTemplateEditorViewState extends State<SmsTemplateEditorView> {
  late final TextEditingController _nameController;
  late final TextEditingController _headerController;
  late final TextEditingController _bodyController;
  late final TextEditingController _footerController;
  late final TextEditingController _pollQuestionController;
  final List<_SmsButtonDraft> _buttonDrafts = [];
  final List<TextEditingController> _pollOptionControllers = [];
  var _nameHydrated = false;
  var _selectedMedia = _SmsMediaType.none;
  var _mediaLabel = '';
  final _selectedTab = _ComposerTab.content;
  var _surveyShowResults = true;
  var _surveyShowRespondents = true;
  var _surveyAllowMultipleAnswers = false;
  late AdminSmsTemplateCategory _category;

  @override
  void initState() {
    super.initState();
    final template = widget.template;
    _nameController = TextEditingController();
    _headerController = TextEditingController(
      text: template?.subject ?? '{{haber_basligi}}',
    );
    _bodyController = TextEditingController(
      text:
          template?.body ??
          'Merhaba {{uye_adi}}, Pateez uzerinden sizin icin secilen haber yayinda.\n\n{{haber_ozeti}}\n\nDetaylari okumak icin butona dokunun.',
    );
    _footerController = TextEditingController();
    _pollQuestionController = TextEditingController(
      text: 'Bu haberle ilgili ne yapmak istersiniz?',
    );
    _pollOptionControllers.addAll([
      TextEditingController(text: 'Detay gönder'),
      TextEditingController(text: 'Benzer haberler'),
      TextEditingController(text: 'Abonelikten çık'),
    ]);
    _category = template?.category ?? AdminSmsTemplateCategory.campaign;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_nameHydrated) return;
    _nameController.text = widget.template == null
        ? context.t('sms.template.composer.defaultName')
        : context.t(widget.template!.nameKey);
    _footerController.text = widget.template == null
        ? context.t('sms.template.composer.footerDefault')
        : context.t(widget.template!.previewText);
    _nameHydrated = true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _headerController.dispose();
    _bodyController.dispose();
    _footerController.dispose();
    _pollQuestionController.dispose();
    for (final button in _buttonDrafts) {
      button.dispose();
    }
    for (final option in _pollOptionControllers) {
      option.dispose();
    }
    super.dispose();
  }

  void _addToken(String token) {
    _insertBodyText(token);
  }

  void _insertBodyText(String text) {
    final current = _bodyController.text.trimRight();
    final selection = _bodyController.selection;
    if (selection.isValid) {
      final next = _bodyController.text.replaceRange(
        selection.start,
        selection.end,
        text,
      );
      final offset = selection.start + text.length;
      setState(() {
        _bodyController.text = next;
        _bodyController.selection = TextSelection.collapsed(offset: offset);
      });
      return;
    }

    final separator = current.isEmpty ? '' : ' ';
    setState(() => _bodyController.text = '$current$separator$text');
  }

  void _wrapBodySelection(String prefix, String suffix) {
    final selection = _bodyController.selection;
    final text = _bodyController.text;
    if (!selection.isValid || selection.isCollapsed) {
      final insert = '$prefix$suffix';
      _insertBodyText(insert);
      final caret = _bodyController.selection.baseOffset - suffix.length;
      if (caret >= 0) {
        _bodyController.selection = TextSelection.collapsed(offset: caret);
      }
      return;
    }

    final selected = text.substring(selection.start, selection.end);
    final replacement = '$prefix$selected$suffix';
    final next = text.replaceRange(selection.start, selection.end, replacement);
    setState(() {
      _bodyController.text = next;
      _bodyController.selection = TextSelection(
        baseOffset: selection.start + prefix.length,
        extentOffset: selection.start + prefix.length + selected.length,
      );
    });
  }

  int _variableCount() {
    final text = [
      _headerController.text,
      _bodyController.text,
      _footerController.text,
      _pollQuestionController.text,
      for (final button in _buttonDrafts) ...[
        button.labelController.text,
        button.urlController.text,
        button.phoneController.text,
      ],
      for (final option in _pollOptionControllers) option.text,
    ].join(' ');
    final matches = RegExp(r'\{\{[^}]+\}\}').allMatches(text);
    return matches
        .map((match) => match.group(0))
        .whereType<String>()
        .toSet()
        .length;
  }

  void _addButtonDraft() {
    if (_buttonDrafts.length >= _maxTemplateActions) return;
    setState(() {
      _buttonDrafts.add(_SmsButtonDraft(label: 'Yeni buton'));
    });
  }

  void _removeButtonDraft(int index) {
    if (index < 0 || index >= _buttonDrafts.length) return;
    setState(() {
      final removed = _buttonDrafts.removeAt(index);
      removed.dispose();
    });
  }

  void _addSurveyOption() {
    if (_pollOptionControllers.length >= _maxSurveyOptions) return;
    setState(() {
      _pollOptionControllers.add(TextEditingController(text: 'Yeni seçenek'));
    });
  }

  void _removeSurveyOption(int index) {
    if (index < 0 || index >= _pollOptionControllers.length) return;
    setState(() {
      final removed = _pollOptionControllers.removeAt(index);
      removed.dispose();
    });
  }

  List<Listenable> _previewListenables() {
    return [
      _nameController,
      _headerController,
      _bodyController,
      _footerController,
      _pollQuestionController,
      for (final button in _buttonDrafts) ...button.listenables,
      ..._pollOptionControllers,
    ];
  }

  List<_SmsButtonPreviewData> _previewButtons() {
    return _buttonDrafts
        .map((button) => button.toPreviewData())
        .where((button) => button.hasLabel)
        .toList(growable: false);
  }

  List<String> _previewSurveyOptions() {
    return _pollOptionControllers
        .map((option) => option.text)
        .where((option) => option.trim().isNotEmpty)
        .toList(growable: false);
  }

  void _changeSurveyShowResults(bool value) {
    setState(() => _surveyShowResults = value);
  }

  void _changeSurveyShowRespondents(bool value) {
    setState(() => _surveyShowRespondents = value);
  }

  void _changeSurveyAllowMultipleAnswers(bool value) {
    setState(() => _surveyAllowMultipleAnswers = value);
  }

  void _changeMedia(_SmsMediaType media) {
    setState(() {
      _selectedMedia = media;
      _mediaLabel = switch (media) {
        _SmsMediaType.none => context.t('sms.template.composer.noMedia'),
        _SmsMediaType.image => 'pateez-haber-gorsel.jpg',
        _SmsMediaType.video => 'pateez-video-ozet.mp4',
        _SmsMediaType.audio => 'pateez-sesli-ozet.ogg',
        _SmsMediaType.document => 'pateez-bulten.pdf',
      };
    });
  }

  void _save() {
    final existing = widget.template;
    final name = _nameController.text.trim().isEmpty
        ? context.t('sms.template.composer.defaultName')
        : _nameController.text.trim();

    final next = AdminSmsTemplate(
      id: existing?.id ?? DateTime.now().millisecondsSinceEpoch,
      nameKey: name,
      category: _category,
      variableCount: _variableCount(),
      ready: existing?.ready ?? false,
      active: existing?.active ?? true,
      updatedAt: DateTime.now(),
      subject: _headerController.text.trim().isEmpty
          ? '{{uye_adi}}'
          : _headerController.text.trim(),
      previewText: _footerController.text.trim().isEmpty
          ? context.t('sms.template.composer.footerDefault')
          : _footerController.text.trim(),
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
        final minEditorWidth = 1240.0;
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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.line)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF25D366).withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(
                          AppRadius.value * 2,
                        ),
                      ),
                      child: const Icon(
                        Symbols.description_rounded,
                        size: 18,
                        color: Color(0xFF25D366),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.template == null
                                ? context.t('sms.template.editor.titleNew')
                                : context.t(widget.template!.nameKey),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.deepOcean,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            context.t('sms.template.composer.subtitle'),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.support,
                              letterSpacing: 0,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: widget.onCancel,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.deepOcean,
                        side: const BorderSide(color: AppColors.line),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        minimumSize: const Size(0, 36),
                        maximumSize: const Size(double.infinity, 36),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppRadius.value * 2,
                          ),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'PateezSans',
                          letterSpacing: 0,
                        ),
                      ),
                      child: Text(context.t('common.cancel')),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Symbols.save_rounded, size: 16),
                      label: Text(
                        widget.template == null
                            ? context.t('sms.template.editor.save')
                            : context.t('sms.template.editor.update'),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.actionRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        minimumSize: const Size(0, 36),
                        maximumSize: const Size(double.infinity, 36),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppRadius.value * 2,
                          ),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'PateezSans',
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ],
                ),
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
                          width: 306,
                          child: _TemplateVariablePanel(
                            onTokenSelected: _addToken,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _SmsTemplateComposerCard(
                            nameController: _nameController,
                            headerController: _headerController,
                            bodyController: _bodyController,
                            buttonDrafts: _buttonDrafts,
                            pollQuestionController: _pollQuestionController,
                            pollOptionControllers: _pollOptionControllers,
                            showResults: _surveyShowResults,
                            showRespondents: _surveyShowRespondents,
                            allowMultipleAnswers: _surveyAllowMultipleAnswers,
                            category: _category,
                            selectedTab: _selectedTab,
                            selectedMedia: _selectedMedia,
                            mediaLabel: _mediaLabel,
                            onCategoryChanged: (value) =>
                                setState(() => _category = value),
                            onMediaChanged: _changeMedia,
                            onTokenSelected: _addToken,
                            onInsertText: _insertBodyText,
                            onWrapText: _wrapBodySelection,
                            onAddButton: _addButtonDraft,
                            onRemoveButton: _removeButtonDraft,
                            onAddSurveyOption: _addSurveyOption,
                            onRemoveSurveyOption: _removeSurveyOption,
                            onShowResultsChanged: _changeSurveyShowResults,
                            onShowRespondentsChanged:
                                _changeSurveyShowRespondents,
                            onAllowMultipleAnswersChanged:
                                _changeSurveyAllowMultipleAnswers,
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 356,
                          child: AnimatedBuilder(
                            animation: Listenable.merge(_previewListenables()),
                            builder: (context, _) {
                              return _SmsTemplateLivePreview(
                                templateName: _nameController.text,
                                header: _headerController.text,
                                body: _bodyController.text,
                                footer: _footerController.text,
                                buttons: _previewButtons(),
                                pollQuestion: _pollQuestionController.text,
                                pollOptions: _previewSurveyOptions(),
                                showSurveyResults: _surveyShowResults,
                                showSurveyRespondents: _surveyShowRespondents,
                                allowMultipleAnswers:
                                    _surveyAllowMultipleAnswers,
                                mediaType: _selectedMedia,
                                mediaLabel: _mediaLabel,
                                showSurvey: false,
                                category: _category,
                                variableCount: _variableCount(),
                              );
                            },
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

enum _SmsMediaType { none, image, video, audio, document }

enum _ComposerTab { content }

extension _SmsMediaTypeData on _SmsMediaType {
  String get labelKey {
    return switch (this) {
      _SmsMediaType.none => 'sms.template.composer.media.none',
      _SmsMediaType.image => 'sms.template.composer.media.image',
      _SmsMediaType.video => 'sms.template.composer.media.video',
      _SmsMediaType.audio => 'sms.template.composer.media.audio',
      _SmsMediaType.document => 'sms.template.composer.media.document',
    };
  }

  String get helperKey {
    return switch (this) {
      _SmsMediaType.none => 'sms.template.composer.mediaHelp.none',
      _SmsMediaType.image => 'sms.template.composer.mediaHelp.image',
      _SmsMediaType.video => 'sms.template.composer.mediaHelp.video',
      _SmsMediaType.audio => 'sms.template.composer.mediaHelp.audio',
      _SmsMediaType.document => 'sms.template.composer.mediaHelp.document',
    };
  }

  IconData get icon {
    return switch (this) {
      _SmsMediaType.none => Symbols.chat_bubble_outline,
      _SmsMediaType.image => Symbols.image_outlined,
      _SmsMediaType.video => Symbols.play_circle_outline,
      _SmsMediaType.audio => Symbols.graphic_eq_outlined,
      _SmsMediaType.document => Symbols.picture_as_pdf_outlined,
    };
  }
}

class _SmsNewsItem {
  const _SmsNewsItem({
    required this.title,
    required this.summary,
    required this.location,
    required this.tag,
    required this.mediaType,
    required this.mediaName,
  });

  final String title;
  final String summary;
  final String location;
  final String tag;
  final _SmsMediaType mediaType;
  final String mediaName;
}

const _composerNewsItems = <_SmsNewsItem>[
  _SmsNewsItem(
    title: 'Belediyeden yeni ulasim duzenlemesi',
    summary: 'Yeni hat saatleri ve kapali yollar tek mesajla duyurulacak.',
    location: 'Merkez',
    tag: 'Gundem',
    mediaType: _SmsMediaType.image,
    mediaName: 'ulasim-duzenlemesi.jpg',
  ),
  _SmsNewsItem(
    title: 'Son dakika: kuvvetli yagis uyarisi',
    summary: 'Meteoroloji uyarisi, guvenli gecis bilgileriyle birlikte hazir.',
    location: 'Bolge',
    tag: 'Son dakika',
    mediaType: _SmsMediaType.video,
    mediaName: 'yagis-uyarisi.mp4',
  ),
  _SmsNewsItem(
    title: 'Haftanin haber ozeti yayinda',
    summary: 'Okurlar icin haftanin en cok okunan haberlerinden kisa ozet.',
    location: 'Pateez',
    tag: 'Bulten',
    mediaType: _SmsMediaType.audio,
    mediaName: 'haftalik-ozet.ogg',
  ),
];

class _SmsComposerSourcePanel extends StatefulWidget {
  const _SmsComposerSourcePanel({
    required this.onTokenSelected,
    required this.onNewsSelected,
  });

  final ValueChanged<String> onTokenSelected;
  final ValueChanged<_SmsNewsItem> onNewsSelected;

  @override
  State<_SmsComposerSourcePanel> createState() =>
      _SmsComposerSourcePanelState();
}

class _SmsComposerSourcePanelState extends State<_SmsComposerSourcePanel> {
  final _controller = TextEditingController();
  var _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final newsItems = _composerNewsItems
        .where(
          (item) =>
              query.isEmpty ||
              '${item.title} ${item.summary} ${item.tag}'
                  .toLowerCase()
                  .contains(query),
        )
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
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ComposerPanelTitle(
                  icon: Symbols.article,
                  title: context.t('sms.template.composer.newsTitle'),
                  subtitle: context.t('sms.template.composer.newsSubtitle'),
                ),
                const SizedBox(height: 12),
                _PanelSearchField(
                  controller: _controller,
                  hint: context.t('sms.template.composer.newsSearch'),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              children: [
                for (final item in newsItems) ...[
                  _ComposerNewsCard(
                    item: item,
                    onTap: () => widget.onNewsSelected(item),
                  ),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 6),
                _ComposerPanelTitle(
                  icon: Symbols.code,
                  title: context.t('sms.template.editor.variables'),
                  subtitle: context.t('sms.template.composer.variableSubtitle'),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final variable in adminSmsTemplateMemberVariables)
                      _VariableTokenChip(
                        variable: variable,
                        onTap: () => widget.onTokenSelected(variable.token),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ComposerPanelTitle extends StatelessWidget {
  const _ComposerPanelTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.value),
          ),
          child: SymbolIcon(icon, color: AppColors.deepOcean, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.deepOcean,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.placeholder,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ComposerNewsCard extends StatelessWidget {
  const _ComposerNewsCard({required this.item, required this.onTap});

  final _SmsNewsItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.softLine),
            borderRadius: BorderRadius.circular(AppRadius.value),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: AppColors.line),
                      borderRadius: BorderRadius.circular(AppRadius.value),
                    ),
                    child: Icon(
                      item.mediaType.icon,
                      size: 18,
                      color: AppColors.actionRed,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.tag,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.actionRed,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  const SymbolIcon(
                    Symbols.add,
                    color: AppColors.deepOcean,
                    size: 18,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.deepOcean,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                item.summary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.inkSoft,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
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

class _SmsTemplateComposerCard extends StatelessWidget {
  const _SmsTemplateComposerCard({
    required this.nameController,
    required this.headerController,
    required this.bodyController,
    required this.buttonDrafts,
    required this.pollQuestionController,
    required this.pollOptionControllers,
    required this.showResults,
    required this.showRespondents,
    required this.allowMultipleAnswers,
    required this.category,
    required this.selectedTab,
    required this.selectedMedia,
    required this.mediaLabel,
    required this.onCategoryChanged,
    required this.onMediaChanged,
    required this.onTokenSelected,
    required this.onInsertText,
    required this.onWrapText,
    required this.onAddButton,
    required this.onRemoveButton,
    required this.onAddSurveyOption,
    required this.onRemoveSurveyOption,
    required this.onShowResultsChanged,
    required this.onShowRespondentsChanged,
    required this.onAllowMultipleAnswersChanged,
  });

  final TextEditingController nameController;
  final TextEditingController headerController;
  final TextEditingController bodyController;
  final List<_SmsButtonDraft> buttonDrafts;
  final TextEditingController pollQuestionController;
  final List<TextEditingController> pollOptionControllers;
  final bool showResults;
  final bool showRespondents;
  final bool allowMultipleAnswers;
  final AdminSmsTemplateCategory category;
  final _ComposerTab selectedTab;
  final _SmsMediaType selectedMedia;
  final String mediaLabel;
  final ValueChanged<AdminSmsTemplateCategory> onCategoryChanged;
  final ValueChanged<_SmsMediaType> onMediaChanged;
  final ValueChanged<String> onTokenSelected;
  final ValueChanged<String> onInsertText;
  final void Function(String prefix, String suffix) onWrapText;
  final VoidCallback onAddButton;
  final ValueChanged<int> onRemoveButton;
  final VoidCallback onAddSurveyOption;
  final ValueChanged<int> onRemoveSurveyOption;
  final ValueChanged<bool> onShowResultsChanged;
  final ValueChanged<bool> onShowRespondentsChanged;
  final ValueChanged<bool> onAllowMultipleAnswersChanged;

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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _ComposerTextField(
                        controller: nameController,
                        label: context.t('sms.template.editor.name'),
                        hint: context.t('sms.template.editor.nameHint'),
                        dense: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child:
                            DropdownButtonFormField<AdminSmsTemplateCategory>(
                              initialValue: category,
                              borderRadius: BorderRadius.circular(
                                AppRadius.value,
                              ),
                              decoration: _composerInputDecoration(
                                context.t('sms.template.editor.category'),
                                '',
                              ),
                              icon: const SymbolIcon(
                                Symbols.keyboard_arrow_down,
                                color: AppColors.iconMuted,
                              ),
                              items: AdminSmsTemplateCategory.values
                                  .map(
                                    (value) => DropdownMenuItem(
                                      value: value,
                                      child: Text(context.t(value.labelKey)),
                                    ),
                                  )
                                  .toList(growable: false),
                              onChanged: (value) {
                                if (value != null) onCategoryChanged(value);
                              },
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                AnimatedBuilder(
                  animation: bodyController,
                  builder: (context, _) {
                    return Row(
                      children: [
                        Expanded(
                          child: SmsStatsRow(
                            message:
                                '${headerController.text}\n${bodyController.text}',
                            alignment: WrapAlignment.start,
                            compact: true,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.softLine),
          Expanded(
            child: IndexedStack(
              index: selectedTab.index,
              children: [
                _ComposerContentTab(
                  headerController: headerController,
                  bodyController: bodyController,
                  onTokenSelected: onTokenSelected,
                  onInsertText: onInsertText,
                  onWrapText: onWrapText,
                ),
                _ComposerMediaTab(
                  selectedMedia: selectedMedia,
                  mediaLabel: mediaLabel,
                  onMediaChanged: onMediaChanged,
                ),
                _ComposerButtonsTab(
                  buttonDrafts: buttonDrafts,
                  onAddButton: onAddButton,
                  onRemoveButton: onRemoveButton,
                ),
                _ComposerSurveyTab(
                  pollQuestionController: pollQuestionController,
                  pollOptionControllers: pollOptionControllers,
                  showResults: showResults,
                  showRespondents: showRespondents,
                  allowMultipleAnswers: allowMultipleAnswers,
                  onAddOption: onAddSurveyOption,
                  onRemoveOption: onRemoveSurveyOption,
                  onShowResultsChanged: onShowResultsChanged,
                  onShowRespondentsChanged: onShowRespondentsChanged,
                  onAllowMultipleAnswersChanged: onAllowMultipleAnswersChanged,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ComposerContentTab extends StatelessWidget {
  const _ComposerContentTab({
    required this.headerController,
    required this.bodyController,
    required this.onTokenSelected,
    required this.onInsertText,
    required this.onWrapText,
  });

  final TextEditingController headerController;
  final TextEditingController bodyController;
  final ValueChanged<String> onTokenSelected;
  final ValueChanged<String> onInsertText;
  final void Function(String prefix, String suffix) onWrapText;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _ComposerStepHeader(
          step: '1',
          title: context.t('sms.template.composer.messageTitle'),
          subtitle: context.t('sms.template.composer.messageSubtitle'),
        ),
        const SizedBox(height: 12),
        _SmsMessageEditor(
          headerController: headerController,
          bodyController: bodyController,
          onInsertText: onInsertText,
          onWrapText: onWrapText,
        ),
        const SizedBox(height: 12),
        _ComposerQuickTokens(onTokenSelected: onTokenSelected),
      ],
    );
  }
}

class _SmsMessageEditor extends StatelessWidget {
  const _SmsMessageEditor({
    required this.headerController,
    required this.bodyController,
    required this.onInsertText,
    required this.onWrapText,
  });

  final TextEditingController headerController;
  final TextEditingController bodyController;
  final ValueChanged<String> onInsertText;
  final void Function(String prefix, String suffix) onWrapText;

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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            color: const Color(0xFF282B33),
            child: Row(
              children: [
                Text(
                  context.t('sms.template.composer.editorTitle'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(width: 18),
                _ComposerToolbarButton(
                  label: 'B',
                  onTap: () => onWrapText('*', '*'),
                ),
                _ComposerToolbarButton(
                  label: 'I',
                  italic: true,
                  onTap: () => onWrapText('_', '_'),
                ),
                _ComposerToolbarButton(
                  label: '~',
                  onTap: () => onWrapText('~', '~'),
                ),
                _ComposerToolbarButton(
                  label: '🙂',
                  onTap: () => onInsertText(' 🙂'),
                ),
                _ComposerToolbarButton(
                  label: '#',
                  onTap: () => onInsertText(' #gundem'),
                ),
                const Spacer(),
                AnimatedBuilder(
                  animation: Listenable.merge([
                    headerController,
                    bodyController,
                  ]),
                  builder: (context, _) {
                    final charCount = bodyController.text.length;
                    final variables = RegExp(r'\{\{[^}]+\}\}')
                        .allMatches(
                          '${headerController.text} ${bodyController.text}',
                        )
                        .length;
                    return Row(
                      children: [
                        _ComposerToolbarCounter(
                          label: context.t(
                            'sms.template.composer.editorVariables',
                            values: {'count': variables},
                          ),
                        ),
                        const SizedBox(width: 8),
                        _ComposerToolbarCounter(
                          label: context.t(
                            'sms.template.composer.editorCharacters',
                            values: {'count': charCount},
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: _ComposerTextField(
              controller: headerController,
              label: context.t('sms.template.composer.headerLabel'),
              hint: context.t('sms.template.composer.headerHint'),
              dense: true,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: TextField(
              controller: bodyController,
              minLines: 13,
              maxLines: 15,
              style: const TextStyle(
                color: AppColors.deepOcean,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.48,
                letterSpacing: 0,
              ),
              decoration: InputDecoration(
                hintText: context.t('sms.template.composer.bodyHint'),
                hintStyle: const TextStyle(
                  color: AppColors.placeholder,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
                filled: true,
                fillColor: Colors.white,
                hoverColor: Colors.white,
                contentPadding: const EdgeInsets.all(16),
                enabledBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(
                    Radius.circular(AppRadius.value),
                  ),
                  borderSide: BorderSide(color: AppColors.line),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(
                    Radius.circular(AppRadius.value),
                  ),
                  borderSide: BorderSide(color: AppColors.deepOcean),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Text(
              context.t('sms.template.composer.bodyHelper'),
              style: const TextStyle(
                color: AppColors.placeholder,
                fontSize: 11,
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

class _ComposerToolbarButton extends StatelessWidget {
  const _ComposerToolbarButton({
    required this.label,
    required this.onTap,
    this.italic = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool italic;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          margin: const EdgeInsets.only(right: 4),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            borderRadius: BorderRadius.circular(AppRadius.value),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontStyle: italic ? FontStyle.italic : FontStyle.normal,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ),
      ),
    );
  }
}

class _ComposerToolbarCounter extends StatelessWidget {
  const _ComposerToolbarCounter({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        borderRadius: BorderRadius.circular(AppRadius.value),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _ComposerMediaTab extends StatelessWidget {
  const _ComposerMediaTab({
    required this.selectedMedia,
    required this.mediaLabel,
    required this.onMediaChanged,
  });

  final _SmsMediaType selectedMedia;
  final String mediaLabel;
  final ValueChanged<_SmsMediaType> onMediaChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _ComposerStepHeader(
          step: '2',
          title: context.t('sms.template.composer.mediaTitle'),
          subtitle: context.t('sms.template.composer.mediaSubtitle'),
        ),
        const SizedBox(height: 12),
        _ComposerMediaSelector(
          selectedMedia: selectedMedia,
          onChanged: onMediaChanged,
        ),
        const SizedBox(height: 10),
        _ComposerMediaDropzone(
          selectedMedia: selectedMedia,
          mediaLabel: mediaLabel,
        ),
        const SizedBox(height: 12),
        _ComposerInfoBox(
          title: context.t('sms.template.composer.mediaRuleTitle'),
          body: context.t('sms.template.composer.mediaRuleBody'),
        ),
      ],
    );
  }
}

class _ComposerButtonsTab extends StatelessWidget {
  const _ComposerButtonsTab({
    required this.buttonDrafts,
    required this.onAddButton,
    required this.onRemoveButton,
  });

  final List<_SmsButtonDraft> buttonDrafts;
  final VoidCallback onAddButton;
  final ValueChanged<int> onRemoveButton;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _ComposerStepHeader(
          step: '3',
          title: context.t('sms.template.composer.buttonsTitle'),
          subtitle: context.t('sms.template.composer.buttonsSubtitle'),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final twoColumns = constraints.maxWidth >= 720;
            final cardWidth = twoColumns
                ? (constraints.maxWidth - 12) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (var index = 0; index < buttonDrafts.length; index++)
                  SizedBox(
                    width: cardWidth,
                    child: _ComposerButtonDraftRow(
                      index: index,
                      draft: buttonDrafts[index],
                      onRemove: () => onRemoveButton(index),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        _ComposerAddButton(
          label: context.t('sms.template.composer.addButton'),
          enabled: buttonDrafts.length < _maxTemplateActions,
          onTap: onAddButton,
        ),
        const SizedBox(height: 12),
        _ComposerInfoBox(
          title: context.t('sms.template.composer.buttonRuleTitle'),
          body: context.t('sms.template.composer.buttonAutoRule'),
        ),
      ],
    );
  }
}

class _ComposerButtonDraftRow extends StatelessWidget {
  const _ComposerButtonDraftRow({
    required this.index,
    required this.draft,
    required this.onRemove,
  });

  final int index;
  final _SmsButtonDraft draft;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.softLine),
        borderRadius: BorderRadius.circular(AppRadius.value),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.t(
                    'sms.template.composer.buttonRowTitle',
                    values: {'index': index + 1},
                  ),
                  style: const TextStyle(
                    color: AppColors.deepOcean,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
              _ComposerIconButton(
                label: context.t('sms.template.composer.removeButton'),
                icon: Symbols.delete,
                onTap: onRemove,
              ),
            ],
          ),
          const SizedBox(height: 10),
          _ComposerTextField(
            controller: draft.labelController,
            label: context.t('sms.template.composer.buttonLabel'),
            hint: context.t('sms.template.composer.primaryHint'),
            dense: true,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ComposerTextField(
                  controller: draft.urlController,
                  label: context.t('sms.template.composer.urlAddress'),
                  hint: 'https://pateeznews.com/haber',
                  dense: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ComposerTextField(
                  controller: draft.phoneController,
                  label: context.t('sms.template.composer.phoneNumber'),
                  hint: '+90 5xx xxx xx xx',
                  dense: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ComposerSurveyTab extends StatelessWidget {
  const _ComposerSurveyTab({
    required this.pollQuestionController,
    required this.pollOptionControllers,
    required this.showResults,
    required this.showRespondents,
    required this.allowMultipleAnswers,
    required this.onAddOption,
    required this.onRemoveOption,
    required this.onShowResultsChanged,
    required this.onShowRespondentsChanged,
    required this.onAllowMultipleAnswersChanged,
  });

  final TextEditingController pollQuestionController;
  final List<TextEditingController> pollOptionControllers;
  final bool showResults;
  final bool showRespondents;
  final bool allowMultipleAnswers;
  final VoidCallback onAddOption;
  final ValueChanged<int> onRemoveOption;
  final ValueChanged<bool> onShowResultsChanged;
  final ValueChanged<bool> onShowRespondentsChanged;
  final ValueChanged<bool> onAllowMultipleAnswersChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _ComposerStepHeader(
          step: '4',
          title: context.t('sms.template.composer.surveyTitle'),
          subtitle: context.t('sms.template.composer.surveySubtitle'),
        ),
        const SizedBox(height: 12),
        _ComposerTextField(
          controller: pollQuestionController,
          label: context.t('sms.template.composer.surveyQuestion'),
          hint: context.t('sms.template.composer.surveyQuestionHint'),
          dense: true,
        ),
        const SizedBox(height: 12),
        for (var index = 0; index < pollOptionControllers.length; index++) ...[
          _ComposerSurveyOptionRow(
            index: index,
            controller: pollOptionControllers[index],
            onRemove: () => onRemoveOption(index),
          ),
          const SizedBox(height: 10),
        ],
        _ComposerAddButton(
          label: context.t('sms.template.composer.addSurveyOption'),
          enabled: pollOptionControllers.length < _maxSurveyOptions,
          onTap: onAddOption,
        ),
        const SizedBox(height: 12),
        _SurveySettingsPanel(
          showResults: showResults,
          showRespondents: showRespondents,
          allowMultipleAnswers: allowMultipleAnswers,
          onShowResultsChanged: onShowResultsChanged,
          onShowRespondentsChanged: onShowRespondentsChanged,
          onAllowMultipleAnswersChanged: onAllowMultipleAnswersChanged,
        ),
        const SizedBox(height: 12),
        _ComposerInfoBox(
          title: context.t('sms.template.composer.surveyRuleTitle'),
          body: context.t('sms.template.composer.surveyRuleBody'),
        ),
      ],
    );
  }
}

class _SurveySettingsPanel extends StatelessWidget {
  const _SurveySettingsPanel({
    required this.showResults,
    required this.showRespondents,
    required this.allowMultipleAnswers,
    required this.onShowResultsChanged,
    required this.onShowRespondentsChanged,
    required this.onAllowMultipleAnswersChanged,
  });

  final bool showResults;
  final bool showRespondents;
  final bool allowMultipleAnswers;
  final ValueChanged<bool> onShowResultsChanged;
  final ValueChanged<bool> onShowRespondentsChanged;
  final ValueChanged<bool> onAllowMultipleAnswersChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.softLine),
        borderRadius: BorderRadius.circular(AppRadius.value),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.t('sms.template.composer.surveySettingsTitle'),
            style: const TextStyle(
              color: AppColors.deepOcean,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _SurveySettingCheckbox(
                  label: context.t('sms.template.composer.surveyShowResults'),
                  value: showResults,
                  onChanged: onShowResultsChanged,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SurveySettingCheckbox(
                  label: context.t(
                    'sms.template.composer.surveyShowRespondents',
                  ),
                  value: showRespondents,
                  onChanged: onShowRespondentsChanged,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SurveySettingCheckbox(
                  label: context.t('sms.template.composer.surveyAllowMultiple'),
                  value: allowMultipleAnswers,
                  onChanged: onAllowMultipleAnswersChanged,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SurveySettingCheckbox extends StatelessWidget {
  const _SurveySettingCheckbox({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(AppRadius.value),
          ),
          child: Row(
            children: [
              Checkbox(
                value: value,
                onChanged: (next) => onChanged(next ?? false),
                activeColor: AppColors.actionRed,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.deepOcean,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComposerSurveyOptionRow extends StatelessWidget {
  const _ComposerSurveyOptionRow({
    required this.index,
    required this.controller,
    required this.onRemove,
  });

  final int index;
  final TextEditingController controller;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ComposerTextField(
            controller: controller,
            label: context.t(
              'sms.template.composer.surveyOptionIndexed',
              values: {'index': index + 1},
            ),
            hint: context.t('sms.template.composer.surveyOptionHint'),
            dense: true,
          ),
        ),
        const SizedBox(width: 10),
        _ComposerIconButton(
          label: context.t('sms.template.composer.removeSurveyOption'),
          icon: Symbols.delete,
          onTap: onRemove,
        ),
      ],
    );
  }
}

class _ComposerAddButton extends StatelessWidget {
  const _ComposerAddButton({
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
      height: 40,
      child: OutlinedButton.icon(
        onPressed: enabled ? onTap : null,
        icon: const SymbolIcon(Symbols.add, size: 18),
        label: Text(label),
        style:
            OutlinedButton.styleFrom(
              foregroundColor: AppColors.deepOcean,
              side: const BorderSide(color: AppColors.line),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.value),
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ).copyWith(
              mouseCursor: WidgetStatePropertyAll(
                enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
              ),
            ),
      ),
    );
  }
}

class _ComposerIconButton extends StatelessWidget {
  const _ComposerIconButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: SizedBox(
        width: 40,
        height: 40,
        child: IconButton(
          onPressed: onTap,
          icon: SymbolIcon(icon, size: 18),
          color: AppColors.inkSoft,
          style:
              IconButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.value),
                  side: const BorderSide(color: AppColors.line),
                ),
              ).copyWith(
                mouseCursor: const WidgetStatePropertyAll(
                  SystemMouseCursors.click,
                ),
              ),
        ),
      ),
    );
  }
}

class _ComposerInfoBox extends StatelessWidget {
  const _ComposerInfoBox({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.softLine),
        borderRadius: BorderRadius.circular(AppRadius.value),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.deepOcean,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            body,
            style: const TextStyle(
              color: AppColors.inkSoft,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 1.35,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _ComposerStepHeader extends StatelessWidget {
  const _ComposerStepHeader({
    required this.step,
    required this.title,
    required this.subtitle,
  });

  final String step;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.deepOcean,
            borderRadius: BorderRadius.circular(AppRadius.value),
          ),
          child: Text(
            step,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.deepOcean,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.inkSoft,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ComposerTextField extends StatelessWidget {
  const _ComposerTextField({
    required this.controller,
    required this.label,
    required this.hint,
    this.dense = false,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(
        color: AppColors.deepOcean,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        height: 1.45,
        letterSpacing: 0,
      ),
      decoration: _composerInputDecoration(label, hint, dense: dense),
    );
  }
}

InputDecoration _composerInputDecoration(
  String label,
  String hint, {
  bool dense = false,
}) {
  return InputDecoration(
    isDense: false,
    labelText: label,
    hintText: hint.isEmpty ? null : hint,
    labelStyle: const TextStyle(
      color: AppColors.placeholder,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
    ),
    hintStyle: const TextStyle(
      color: AppColors.placeholder,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
    ),
    filled: true,
    fillColor: Colors.white,
    hoverColor: Colors.white,
    contentPadding: EdgeInsets.symmetric(
      horizontal: 14,
      vertical: dense ? 14 : 16,
    ),
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

class _ComposerMediaSelector extends StatelessWidget {
  const _ComposerMediaSelector({
    required this.selectedMedia,
    required this.onChanged,
  });

  final _SmsMediaType selectedMedia;
  final ValueChanged<_SmsMediaType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final media in _SmsMediaType.values)
          _ComposerMediaPill(
            media: media,
            selected: selectedMedia == media,
            onTap: () => onChanged(media),
          ),
      ],
    );
  }
}

class _ComposerMediaPill extends StatelessWidget {
  const _ComposerMediaPill({
    required this.media,
    required this.selected,
    required this.onTap,
  });

  final _SmsMediaType media;
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
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.actionRed : Colors.white,
            border: Border.all(
              color: selected ? AppColors.actionRed : AppColors.line,
            ),
            borderRadius: BorderRadius.circular(AppRadius.value),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                media.icon,
                size: 17,
                color: selected ? Colors.white : AppColors.iconMuted,
              ),
              const SizedBox(width: 7),
              Text(
                context.t(media.labelKey),
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.inkSoft,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
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

class _ComposerMediaDropzone extends StatelessWidget {
  const _ComposerMediaDropzone({
    required this.selectedMedia,
    required this.mediaLabel,
  });

  final _SmsMediaType selectedMedia;
  final String mediaLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.softLine),
        borderRadius: BorderRadius.circular(AppRadius.value),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.line),
              borderRadius: BorderRadius.circular(AppRadius.value),
            ),
            child: Icon(
              selectedMedia.icon,
              color: AppColors.actionRed,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mediaLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.deepOcean,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.t(selectedMedia.helperKey),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.inkSoft,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 34,
            child: OutlinedButton.icon(
              onPressed: () {},
              icon: const SymbolIcon(
                Symbols.upload,
                color: AppColors.deepOcean,
                size: 17,
              ),
              label: Text(context.t('sms.template.composer.chooseMedia')),
              style:
                  OutlinedButton.styleFrom(
                    foregroundColor: AppColors.deepOcean,
                    side: const BorderSide(color: AppColors.line),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.value),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12,
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
        ],
      ),
    );
  }
}

class _ComposerQuickTokens extends StatelessWidget {
  const _ComposerQuickTokens({required this.onTokenSelected});

  final ValueChanged<String> onTokenSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = [
      '{{uye_adi}}',
      '{{haber_basligi}}',
      '{{haber_ozeti}}',
      '{{haber_linki}}',
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final token in tokens)
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTokenSelected(token),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.line),
                  borderRadius: BorderRadius.circular(AppRadius.value),
                ),
                child: Text(
                  token,
                  style: const TextStyle(
                    color: AppColors.inkSoft,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SmsTemplateLivePreview extends StatelessWidget {
  const _SmsTemplateLivePreview({
    required this.templateName,
    required this.header,
    required this.body,
    required this.footer,
    required this.buttons,
    required this.pollQuestion,
    required this.pollOptions,
    required this.showSurveyResults,
    required this.showSurveyRespondents,
    required this.allowMultipleAnswers,
    required this.mediaType,
    required this.mediaLabel,
    required this.showSurvey,
    required this.category,
    required this.variableCount,
  });

  final String templateName;
  final String header;
  final String body;
  final String footer;
  final List<_SmsButtonPreviewData> buttons;
  final String pollQuestion;
  final List<String> pollOptions;
  final bool showSurveyResults;
  final bool showSurveyRespondents;
  final bool allowMultipleAnswers;
  final _SmsMediaType mediaType;
  final String mediaLabel;
  final bool showSurvey;
  final AdminSmsTemplateCategory category;
  final int variableCount;

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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.softLine)),
            ),
            child: _ComposerPanelTitle(
              icon: Symbols.visibility,
              title: context.t('sms.template.composer.previewTitle'),
              subtitle: context.t('sms.template.composer.previewSubtitle'),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SmsPhoneFrame(
                  templateName: templateName,
                  header: header,
                  body: body,
                  footer: footer,
                  buttons: buttons,
                  pollQuestion: pollQuestion,
                  pollOptions: pollOptions,
                  showSurveyResults: showSurveyResults,
                  showSurveyRespondents: showSurveyRespondents,
                  allowMultipleAnswers: allowMultipleAnswers,
                  mediaType: mediaType,
                  mediaLabel: mediaLabel,
                  showSurvey: showSurvey,
                ),
                const SizedBox(height: 14),
                SmsStatsRow(
                  message: '$header\n$body',
                  alignment: WrapAlignment.center,
                  compact: true,
                ),
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SmsVariableChip(
                      label: context.t(category.labelKey),
                      verified: true,
                    ),
                    SmsMetricPill(
                      label: context.t(
                        'sms.template.composer.variableCount',
                        values: {'count': variableCount},
                      ),
                      compact: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SmsPhoneFrame extends StatelessWidget {
  const _SmsPhoneFrame({
    required this.templateName,
    required this.header,
    required this.body,
    required this.footer,
    required this.buttons,
    required this.pollQuestion,
    required this.pollOptions,
    required this.showSurveyResults,
    required this.showSurveyRespondents,
    required this.allowMultipleAnswers,
    required this.mediaType,
    required this.mediaLabel,
    required this.showSurvey,
    this.width = 320,
    this.height = 354,
  });

  final String templateName;
  final String header;
  final String body;
  final String footer;
  final List<_SmsButtonPreviewData> buttons;
  final String pollQuestion;
  final List<String> pollOptions;
  final bool showSurveyResults;
  final bool showSurveyRespondents;
  final bool allowMultipleAnswers;
  final _SmsMediaType mediaType;
  final String mediaLabel;
  final bool showSurvey;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final safeName = templateName.trim().isEmpty
        ? context.t('sms.template.composer.defaultName')
        : templateName.trim();
    final rawHeader = header.trim().isEmpty ? '{{haber_basligi}}' : header;
    final rawBody = body.trim().isEmpty
        ? context.t('sms.template.composer.bodyHint')
        : body;
    final rawFooter = footer.trim().isEmpty
        ? context.t('sms.template.composer.footerDefault')
        : footer;
    final extras = [
      for (final button in buttons)
        if (button.hasLabel) button.label,
      if (showSurvey && pollQuestion.trim().isNotEmpty) pollQuestion.trim(),
      if (showSurvey)
        ...pollOptions.where((option) => option.trim().isNotEmpty),
      if (mediaType != _SmsMediaType.none && mediaLabel.trim().isNotEmpty)
        mediaLabel.trim(),
      if (showSurveyResults)
        context.t('sms.template.composer.surveyResultsPreview'),
      if (showSurveyRespondents)
        context.t(
          'sms.template.composer.surveyRespondentsPreview',
          values: {'names': 'Jane'},
        ),
      if (allowMultipleAnswers)
        context.t('sms.template.composer.surveyMultiplePreview'),
    ];
    final message = [
      rawHeader,
      rawBody,
      rawFooter,
      ...extras,
    ].where((part) => part.trim().isNotEmpty).join('\n');

    return Center(
      child: SmsImessagePreview(
        message: message,
        contactName: 'Jane',
        avatarInitial: safeName.characters.take(1).toString(),
        width: width,
        height: height,
        maxBubbleLines: 9,
      ),
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
    final variables = adminSmsTemplateMemberVariables
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
                      Symbols.data_object_outlined,
                      size: 18,
                      color: AppColors.deepOcean,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.t('sms.template.editor.variables'),
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
                  context.t('sms.template.editor.dragToEditor'),
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
                  hint: context.t('sms.template.editor.searchVariable'),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.softLine),
          _VariableGroupHeader(
            expanded: _expanded,
            count: adminSmsTemplateMemberVariables.length,
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
            Symbols.search,
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
                  Symbols.group_outlined,
                  size: 17,
                  color: Color(0xFF2F80ED),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.t('sms.template.editor.memberInfo'),
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

  final AdminSmsTemplateVariable variable;
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

  final AdminSmsTemplateVariable variable;
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

class _TemplatePreviewFrame extends StatelessWidget {
  const _TemplatePreviewFrame({required this.template, required this.compact});

  final AdminSmsTemplate template;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final phoneWidth = 320.0;
    final phoneHeight = 354.0;

    final phoneWidget = _SmsPhoneFrame(
      templateName: context.t(template.nameKey),
      header: context.t(template.subject),
      body: template.body,
      footer: context.t('sms.template.previewFooterTitle'),
      buttons: const [],
      pollQuestion: '',
      pollOptions: const [],
      showSurveyResults: false,
      showSurveyRespondents: false,
      allowMultipleAnswers: false,
      mediaType: _SmsMediaType.none,
      mediaLabel: '',
      showSurvey: false,
      width: phoneWidth,
      height: phoneHeight,
    );

    if (compact) {
      return Center(child: phoneWidget);
    }

    return Center(
      child: Container(
        width: phoneWidth + 32.0,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(AppRadius.value),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: phoneWidget,
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

  final AdminSmsTemplate? template;

  @override
  State<_TemplateSaveDialog> createState() => _TemplateSaveDialogState();
}

class _TemplateSaveDialogState extends State<_TemplateSaveDialog> {
  late final TextEditingController _nameController;
  late AdminSmsTemplateCategory _category;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.template == null ? '' : '',
    );
    _category = widget.template?.category ?? AdminSmsTemplateCategory.campaign;
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
                        ? context.t('sms.template.editor.saveTitle')
                        : context.t('sms.template.editor.updateTitle'),
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
              context.t('sms.template.editor.formSubtitle'),
              style: const TextStyle(
                color: AppColors.inkSoft,
                fontWeight: FontWeight.w500,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 20),
            _DialogLabel(text: context.t('sms.template.editor.name')),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: _dialogInputDecoration(
                context.t('sms.template.editor.nameHint'),
              ),
            ),
            const SizedBox(height: 16),
            _DialogLabel(text: context.t('sms.template.editor.category')),
            const SizedBox(height: 8),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: DropdownButtonFormField<AdminSmsTemplateCategory>(
                initialValue: _category,
                borderRadius: BorderRadius.circular(AppRadius.value),
                decoration: _dialogInputDecoration(''),
                icon: const SymbolIcon(
                  Symbols.keyboard_arrow_down,
                  color: AppColors.iconMuted,
                ),
                items: AdminSmsTemplateCategory.values
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
                  label: context.t('sms.template.editor.save'),
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
  final AdminSmsTemplateCategory category;
}
