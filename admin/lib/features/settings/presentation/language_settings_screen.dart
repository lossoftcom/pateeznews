import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../core/localization/admin_language_controller.dart';
import '../../../core/localization/admin_translations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../features/auth/data/admin_auth_models.dart';
import '../../../features/settings/data/admin_language_models.dart';
import '../../../features/settings/data/admin_languages_repository.dart';
import '../../../shared/widgets/app_confirmation_dialog.dart';
import '../../../shared/widgets/sortable_table_header.dart';
import '../../../shared/widgets/symbol_icon.dart';
import 'widgets/language_settings_dialogs.dart';
import 'widgets/language_settings_table.dart';

class LanguageSettingsScreen extends StatefulWidget {
  const LanguageSettingsScreen({
    super.key,
    required this.session,
    required this.repository,
  });

  static const double _toolbarHeight = 38;

  final AdminSession session;
  final AdminLanguagesRepository repository;

  @override
  State<LanguageSettingsScreen> createState() => _LanguageSettingsScreenState();
}

class _LanguageSettingsScreenState extends State<LanguageSettingsScreen> {
  final _selectedCodes = <String>{};
  final _searchController = TextEditingController();

  var _languages = <AdminLanguage>[];
  var _totalCount = 0;
  var _pageSize = 25;
  var _page = 1;
  var _loading = true;
  String? _error;
  var _sortState = const TableSortState(key: 'order', ascending: true);

  @override
  void initState() {
    super.initState();
    unawaited(_loadLanguages());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLanguages() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.repository.fetchLanguages(
        search: _searchController.text,
        page: _page,
        pageSize: _pageSize,
        sortKey: _sortState.key,
        sortAscending: _sortState.ascending,
      );
      if (!mounted) return;
      setState(() {
        _languages = result.languages;
        _totalCount = result.totalCount;
        _selectedCodes.removeWhere(
          (code) => !_languages.any((language) => language.code == code),
        );
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _reloadAndRefreshController() async {
    await _loadLanguages();
    if (!mounted) return;
    final controller = AdminLocalizationScope.maybeOf(context);
    if (controller == null) return;
    await controller.refreshLanguages();
    await controller.refreshTranslations();
  }

  void _toggleCode(String code) {
    setState(() {
      if (_selectedCodes.contains(code)) {
        _selectedCodes.remove(code);
      } else {
        _selectedCodes.add(code);
      }
    });
  }

  void _toggleAllRows() {
    setState(() {
      if (_selectedCodes.length == _languages.length) {
        _selectedCodes.clear();
      } else {
        _selectedCodes
          ..clear()
          ..addAll(_languages.map((language) => language.code));
      }
    });
  }

  void _changeSort(String sortKey) {
    setState(() {
      _sortState = _sortState.toggled(sortKey);
      _page = 1;
      _selectedCodes.clear();
    });
    unawaited(_loadLanguages());
  }

  Future<void> _upsertLanguage({AdminLanguage? language}) async {
    final data = await showAddLanguageDialog(context, language: language);
    if (data == null) return;
    await _runAction(() async {
      await widget.repository.upsertLanguage(
        session: widget.session,
        data: data,
      );
      await _reloadAndRefreshController();
    });
  }

  Future<void> _deleteLanguage(AdminLanguage language) async {
    if (language.isCore || language.isDefault) {
      _showMessage(context.t('language.coreProtected'));
      return;
    }
    final confirmed = await showAppConfirmationDialog(
      context,
      title: context.t('language.deleteConfirmTitle'),
      message: context.t('language.deleteConfirmMessage'),
      confirmLabel: context.t('common.delete'),
      danger: true,
    );
    if (!confirmed) return;
    await _runAction(() async {
      await widget.repository.deleteLanguage(
        session: widget.session,
        code: language.code,
      );
      _selectedCodes.remove(language.code);
      await _reloadAndRefreshController();
    });
  }

  Future<void> _deleteSelectedLanguages() async {
    final deletable = _languages
        .where(
          (language) =>
              _selectedCodes.contains(language.code) &&
              !language.isCore &&
              !language.isDefault,
        )
        .toList(growable: false);
    if (deletable.isEmpty) {
      _showMessage(context.t('language.coreProtected'));
      return;
    }
    final confirmed = await showAppConfirmationDialog(
      context,
      title: context.t('language.deleteConfirmTitle'),
      message: context.t('language.deleteConfirmMessage'),
      confirmLabel: context.t('common.delete'),
      danger: true,
    );
    if (!confirmed) return;
    await _runAction(() async {
      for (final language in deletable) {
        await widget.repository.deleteLanguage(
          session: widget.session,
          code: language.code,
        );
      }
      _selectedCodes.clear();
      await _reloadAndRefreshController();
    });
  }

  Future<void> _toggleStatus(AdminLanguage language) async {
    if (language.isCore) {
      _showMessage(context.t('language.coreProtected'));
      return;
    }
    await _runAction(() async {
      await widget.repository.upsertLanguage(
        session: widget.session,
        data: LanguageFormData(
          code: language.code,
          name: language.name,
          direction: language.direction,
          status: language.active ? 'passive' : 'active',
          flagCode: language.flagCode,
        ),
      );
      await _reloadAndRefreshController();
    });
  }

  Future<void> _makeDefault(AdminLanguage language) async {
    await _runAction(() async {
      await widget.repository.setDefaultLanguage(
        session: widget.session,
        code: language.code,
      );
      await _reloadAndRefreshController();
    });
  }

  Future<void> _editTranslations(AdminLanguage language) async {
    await _runAction(() async {
      final translations = await widget.repository.fetchTranslations(
        language.code,
      );
      final source = defaultTranslationsFor('en');
      final normalizedTranslations = normalizeAdminTranslationMapKeys(
        translations,
      );
      final allKeys =
          <String>{...source.keys, ...normalizedTranslations.keys}.toList()
            ..sort((a, b) {
              final aPriority = a.contains('.') ? 0 : 1;
              final bPriority = b.contains('.') ? 0 : 1;
              final priority = aPriority.compareTo(bPriority);
              return priority == 0 ? a.compareTo(b) : priority;
            });
      final entries = [
        for (final key in allKeys)
          TranslationEntryData(
            key: key,
            source: source[key] ?? key,
            value: normalizedTranslations[key] ?? '',
          ),
      ];
      if (!mounted) return;
      final result = await showTranslationsDialog(
        context,
        language: language,
        entries: entries,
      );
      if (result == null) return;
      await widget.repository.saveTranslations(
        session: widget.session,
        code: language.code,
        translations: result,
      );
      if (!mounted) return;
      final controller = AdminLocalizationScope.maybeOf(context);
      if (controller?.code == language.code) {
        await controller?.refreshTranslations();
      }
      await _loadLanguages();
    });
  }

  Future<void> _exportLanguage(AdminLanguage language) async {
    await _runAction(() async {
      final jsonContent = await widget.repository.exportLanguagePack(language);
      if (!mounted) return;
      await showExportLanguageDialog(
        context,
        language: language,
        jsonContent: jsonContent,
      );
    });
  }

  Future<void> _importLanguage() async {
    final content = await showImportLanguageDialog(
      context,
      sampleJson: _sampleLanguagePackJson(),
    );
    if (content == null) return;
    await _runAction(() async {
      await widget.repository.importLanguagePack(
        session: widget.session,
        jsonContent: content,
      );
      await _reloadAndRefreshController();
    });
  }

  Future<void> _runAction(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      _showMessage(error.toString());
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.t(message))));
  }

  String _sampleLanguagePackJson() {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert({
      'meta': {
        'code': 'de',
        'name': 'Deutsch',
        'direction': 'ltr',
        'status': 'active',
        'flag_code': 'de',
      },
      'translations': defaultTranslationsFor('en'),
    });
  }

  void _onSearchChanged(String value) {
    _page = 1;
    unawaited(_loadLanguages());
  }

  void _onPageSizeChanged(int? value) {
    if (value == null) return;
    setState(() {
      _pageSize = value;
      _page = 1;
    });
    unawaited(_loadLanguages());
  }

  void _goToPage(int page) {
    final maxPage = (_totalCount / _pageSize).ceil().clamp(1, 999999).toInt();
    final nextPage = page.clamp(1, maxPage).toInt();
    if (nextPage == _page) return;
    setState(() => _page = nextPage);
    unawaited(_loadLanguages());
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 640 ? 16.0 : 28.0;

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
              const _LanguageSettingsTitle(),
              const SizedBox(height: 18),
              _LanguageSettingsToolbar(
                pageSize: _pageSize,
                selectedCount: _selectedCodes.length,
                searchController: _searchController,
                onPageSizeChanged: _onPageSizeChanged,
                onSearchChanged: _onSearchChanged,
                onDeleteSelected: _deleteSelectedLanguages,
                onImport: _importLanguage,
                onAdd: () => _upsertLanguage(),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: Stack(
                  children: [
                    LanguageSettingsTable(
                      languages: _languages,
                      selectedCodes: _selectedCodes,
                      sortState: _sortState,
                      onToggleCode: _toggleCode,
                      onToggleAll: _toggleAllRows,
                      onMakeDefault: _makeDefault,
                      onEdit: (language) => _upsertLanguage(language: language),
                      onToggleStatus: _toggleStatus,
                      onDelete: _deleteLanguage,
                      onTranslations: _editTranslations,
                      onExport: _exportLanguage,
                      onSort: _changeSort,
                    ),
                    if (_loading)
                      const Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.deepOcean,
                          ),
                        ),
                      ),
                    if (_error != null && !_loading)
                      Center(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: AppColors.actionRed,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _LanguageSettingsFooter(
                page: _page,
                pageSize: _pageSize,
                totalCount: _totalCount,
                visibleCount: _languages.length,
                onFirst: () => _goToPage(1),
                onPrevious: () => _goToPage(_page - 1),
                onNext: () => _goToPage(_page + 1),
                onLast: () => _goToPage(
                  (_totalCount / _pageSize).ceil().clamp(1, 999999).toInt(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LanguageSettingsTitle extends StatelessWidget {
  const _LanguageSettingsTitle();

  @override
  Widget build(BuildContext context) {
    return Text(
      context.t('language.title'),
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
        color: AppColors.deepOcean,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
    );
  }
}

class _LanguageSettingsToolbar extends StatelessWidget {
  const _LanguageSettingsToolbar({
    required this.pageSize,
    required this.selectedCount,
    required this.searchController,
    required this.onPageSizeChanged,
    required this.onSearchChanged,
    required this.onDeleteSelected,
    required this.onImport,
    required this.onAdd,
  });

  final int pageSize;
  final int selectedCount;
  final TextEditingController searchController;
  final ValueChanged<int?> onPageSizeChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onDeleteSelected;
  final VoidCallback onImport;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 1160;
        final pageSizeSelect = _PageSizeSelect(
          value: pageSize,
          onChanged: onPageSizeChanged,
        );
        final deleteButton = selectedCount == 0
            ? null
            : _SelectedDeleteButton(
                selectedCount: selectedCount,
                onPressed: onDeleteSelected,
              );
        final leftControls = Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            pageSizeSelect,
            if (deleteButton != null) ...[
              const SizedBox(width: 12),
              deleteButton,
            ],
          ],
        );
        final search = ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: compact ? double.infinity : 270,
            minWidth: compact ? double.infinity : 260,
          ),
          child: _LanguageSearchField(
            controller: searchController,
            onChanged: onSearchChanged,
          ),
        );
        final actions = Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: compact ? WrapAlignment.start : WrapAlignment.end,
          children: [
            _ToolbarButton(
              icon: Symbols.article,
              label: context.t('language.printList'),
              variant: _ToolbarButtonVariant.outlined,
            ),
            _ToolbarButton(
              icon: Symbols.open_in_new,
              label: context.t('language.download'),
              variant: _ToolbarButtonVariant.dark,
            ),
            _ToolbarButton(
              icon: Symbols.schedule_send,
              label: context.t('language.import'),
              variant: _ToolbarButtonVariant.warning,
              onPressed: onImport,
            ),
            _ToolbarButton(
              textIcon: '+',
              label: context.t('language.add'),
              variant: _ToolbarButtonVariant.danger,
              onPressed: onAdd,
            ),
          ],
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(alignment: Alignment.centerLeft, child: leftControls),
              const SizedBox(height: 12),
              search,
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerRight, child: actions),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            leftControls,
            const Spacer(),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [search, const SizedBox(width: 12), actions],
            ),
          ],
        );
      },
    );
  }
}

class _PageSizeSelect extends StatelessWidget {
  const _PageSizeSelect({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        height: LanguageSettingsScreen._toolbarHeight,
        padding: const EdgeInsets.only(left: 12, right: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.value),
          border: Border.all(color: AppColors.line.withValues(alpha: 0.72)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            value: value,
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
              fontWeight: FontWeight.w500,
              letterSpacing: 0,
            ),
            items: const [
              DropdownMenuItem(value: 25, child: Text('25')),
              DropdownMenuItem(value: 50, child: Text('50')),
              DropdownMenuItem(value: 100, child: Text('100')),
            ],
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}

class _SelectedDeleteButton extends StatelessWidget {
  const _SelectedDeleteButton({
    required this.selectedCount,
    required this.onPressed,
  });

  final int selectedCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: TextButton(
        onPressed: onPressed,
        style:
            TextButton.styleFrom(
              backgroundColor: AppColors.actionRed,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 34),
              maximumSize: const Size(double.infinity, 34),
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
              mouseCursor: const WidgetStatePropertyAll(
                SystemMouseCursors.click,
              ),
            ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SymbolIcon(Symbols.delete, color: Colors.white, size: 14),
            const SizedBox(width: 6),
            Text(
              context.t(
                'language.selectedDelete',
                values: {'count': selectedCount},
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageSearchField extends StatelessWidget {
  const _LanguageSearchField({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: LanguageSettingsScreen._toolbarHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line.withValues(alpha: 0.72)),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        mouseCursor: SystemMouseCursors.text,
        cursorColor: AppColors.support,
        textAlignVertical: TextAlignVertical.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.deepOcean,
          fontWeight: FontWeight.w400,
        ),
        decoration: InputDecoration(
          hintText: context.t('common.searchDots'),
          hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.placeholder,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: 12, right: 9),
            child: SymbolIcon(
              Symbols.search,
              color: AppColors.iconMuted,
              size: 18,
            ),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 39,
            minHeight: LanguageSettingsScreen._toolbarHeight,
          ),
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          contentPadding: EdgeInsets.zero,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }
}

enum _ToolbarButtonVariant { outlined, dark, warning, danger }

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.label,
    required this.variant,
    this.icon,
    this.textIcon,
    this.onPressed,
  });

  final String label;
  final _ToolbarButtonVariant variant;
  final IconData? icon;
  final String? textIcon;
  final VoidCallback? onPressed;

  Color get _background {
    return switch (variant) {
      _ToolbarButtonVariant.outlined => Colors.white,
      _ToolbarButtonVariant.dark => AppColors.deepOcean,
      _ToolbarButtonVariant.warning => AppColors.warmHorizon,
      _ToolbarButtonVariant.danger => AppColors.actionRed,
    };
  }

  Color get _foreground {
    return switch (variant) {
      _ToolbarButtonVariant.outlined => AppColors.deepOcean,
      _ToolbarButtonVariant.dark => Colors.white,
      _ToolbarButtonVariant.warning => Colors.white,
      _ToolbarButtonVariant.danger => Colors.white,
    };
  }

  Color get _border {
    return switch (variant) {
      _ToolbarButtonVariant.outlined => AppColors.line,
      _ToolbarButtonVariant.dark => AppColors.deepOcean,
      _ToolbarButtonVariant.warning => AppColors.warmHorizon,
      _ToolbarButtonVariant.danger => AppColors.actionRed,
    };
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: LanguageSettingsScreen._toolbarHeight,
      child: TextButton(
        onPressed: onPressed ?? () {},
        style:
            TextButton.styleFrom(
              backgroundColor: _background,
              foregroundColor: _foreground,
              side: BorderSide(color: _border.withValues(alpha: 0.88)),
              minimumSize: const Size(0, LanguageSettingsScreen._toolbarHeight),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.value),
              ),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
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
            if (icon != null)
              SymbolIcon(icon!, color: _foreground, size: 16)
            else
              Text(
                textIcon ?? '',
                style: TextStyle(
                  color: _foreground,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
              ),
            const SizedBox(width: 8),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _LanguageSettingsFooter extends StatelessWidget {
  const _LanguageSettingsFooter({
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.visibleCount,
    required this.onFirst,
    required this.onPrevious,
    required this.onNext,
    required this.onLast,
  });

  final int page;
  final int pageSize;
  final int totalCount;
  final int visibleCount;
  final VoidCallback onFirst;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onLast;

  @override
  Widget build(BuildContext context) {
    final from = totalCount == 0 ? 0 : ((page - 1) * pageSize) + 1;
    final to = totalCount == 0 ? 0 : from + visibleCount - 1;
    final text = Text(
      context.t(
        'language.recordRange',
        values: {'from': from, 'to': to, 'total': totalCount},
      ),
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: AppColors.inkSoft,
        fontWeight: FontWeight.w500,
      ),
    );
    final pager = _LanguagePagination(
      page: page,
      onFirst: onFirst,
      onPrevious: onPrevious,
      onNext: onNext,
      onLast: onLast,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 640;
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(height: 1, color: AppColors.line),
              const SizedBox(height: 16),
              text,
              const SizedBox(height: 14),
              pager,
            ],
          );
        }

        return Column(
          children: [
            const Divider(height: 1, color: AppColors.line),
            const SizedBox(height: 16),
            Row(children: [text, const Spacer(), pager]),
          ],
        );
      },
    );
  }
}

class _LanguagePagination extends StatelessWidget {
  const _LanguagePagination({
    required this.page,
    required this.onFirst,
    required this.onPrevious,
    required this.onNext,
    required this.onLast,
  });

  final int page;
  final VoidCallback onFirst;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onLast;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        _PageButton(label: '<<', onPressed: onFirst),
        _PageButton(label: '<', onPressed: onPrevious),
        _PageButton(label: '$page', selected: true),
        _PageButton(label: '>', onPressed: onNext),
        _PageButton(label: '>>', onPressed: onLast),
      ],
    );
  }
}

class _PageButton extends StatelessWidget {
  const _PageButton({
    required this.label,
    this.selected = false,
    this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: selected ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: selected ? null : onPressed,
        child: Container(
          width: 36,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.deepOcean : Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.value),
            border: Border.all(
              color: selected
                  ? AppColors.deepOcean
                  : AppColors.line.withValues(alpha: 0.72),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.support,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
