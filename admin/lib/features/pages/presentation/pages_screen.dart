import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:pateeznews_admin/shared/widgets/admin_toast.dart';

import '../../../core/localization/admin_date_formatter.dart';
import '../../../core/localization/admin_language_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/icons/symbols.dart';
import '../../../shared/widgets/admin_mobile_list.dart';
import '../../../shared/widgets/admin_rich_text_editor.dart';
import '../../../shared/widgets/admin_table_chrome.dart';
import '../../../shared/widgets/app_confirmation_dialog.dart';
import '../../../shared/widgets/highlighted_text.dart';
import '../../../shared/widgets/symbol_icon.dart';
import '../../news/presentation/widgets/article_text_block.dart';
import '../data/admin_pages_repository.dart';
import 'pages_models.dart';

/// Aktif arama sorgusunu satır hücrelerine taşır (highlight için).
class _PagesSearchScope extends InheritedWidget {
  const _PagesSearchScope({required this.query, required super.child});

  final String query;

  static String of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_PagesSearchScope>()?.query ??
      '';

  @override
  bool updateShouldNotify(_PagesSearchScope oldWidget) =>
      oldWidget.query != query;
}

class PagesScreen extends StatefulWidget {
  const PagesScreen({
    super.key,
    this.repository = const SupabaseAdminPagesRepository(),
  });

  final AdminPagesRepository repository;

  @override
  State<PagesScreen> createState() => _PagesScreenState();
}

class _PagesScreenState extends State<PagesScreen> {
  final _searchController = TextEditingController();
  var _pages = const <AdminPage>[];
  var _options = const AdminPagesFilterOptions(
    languages: [],
    categories: [],
    types: ['custom'],
    parents: [],
  );
  var _loading = true;
  var _saving = false;
  String? _error;
  var _pageSize = 25;
  var _page = 1;
  var _totalCount = 0;
  var _category = 'Tümü';
  var _type = 'Tümü';
  var _status = 'Tümü';
  var _sortKey = 'createdAt';
  var _sortAscending = false;
  var _showForm = false;
  AdminPage? _editingPage;
  Timer? _searchDebounce;
  var _searchSeq = 0;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    unawaited(_loadInitial());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final options = await widget.repository.fetchFilterOptions();
      final result = await _fetchPages();
      if (!mounted) return;
      setState(() {
        _options = options;
        _pages = result.pages;
        _totalCount = result.totalCount;
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

  Future<AdminPagesPageResult> _fetchPages() {
    return widget.repository.fetchPages(
      search: _searchController.text,
      category: _category,
      type: _type,
      status: _status,
      page: _page,
      pageSize: _pageSize,
      sortKey: _sortKey,
      sortAscending: _sortAscending,
    );
  }

  void _reloadFirstPage() {
    _page = 1;
    unawaited(_reloadPages());
  }

  Future<void> _reloadPages() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _fetchPages();
      if (!mounted) return;
      setState(() {
        _pages = result.pages;
        _totalCount = result.totalCount;
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

  /// Arama yazılırken: anlık istemci filtresi (_visiblePages) + spinner'sız
  /// (sessiz) sunucu yenileme. Filtre dropdownları eski yolla (_reloadFirstPage).
  void _onSearchChanged() {
    setState(() => _page = 1);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      unawaited(_refreshPagesSilently());
    });
  }

  Future<void> _refreshPagesSilently() async {
    final seq = ++_searchSeq;
    try {
      final result = await _fetchPages();
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _pages = result.pages;
        _totalCount = result.totalCount;
        _error = null;
      });
    } catch (_) {
      // Sessiz yenileme; mevcut veri ekranda kalır.
    }
  }

  /// Anlık (0ms) istemci filtresi — Haberler ile aynı Türkçe-duyarsız eşleşme.
  List<AdminPage> _visiblePages() {
    final query = _searchController.text.trim();
    if (query.isEmpty) return _pages;
    return _pages
        .where((page) => searchMatchesAll(_pageHaystack(page), query))
        .toList(growable: false);
  }

  String _pageHaystack(AdminPage page) {
    return [
      page.id,
      page.title,
      page.slug,
      page.pageGroup,
      page.category,
      page.type,
      page.status,
      page.languageCode,
      page.location,
      page.metaTitle,
    ].join(' ');
  }

  Future<void> _savePage(AdminPageFormData data) async {
    setState(() => _saving = true);
    try {
      await widget.repository.savePage(id: _editingPage?.id, data: data);
      if (!mounted) return;
      setState(() {
        _showForm = false;
        _editingPage = null;
        _saving = false;
      });
      await _loadInitial();
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage(error.toString());
    }
  }

  Future<void> _toggleStatus(AdminPage page) async {
    await _runMutation(() => widget.repository.toggleStatus(page));
  }

  Future<void> _deletePage(AdminPage page) async {
    final confirmed = await showAppConfirmationDialog(
      context,
      title: context.t('pages.deleteTitle'),
      message: context.t('pages.deleteMessage', values: {'title': page.title}),
      confirmLabel: context.t('common.delete'),
      danger: true,
    );
    if (!confirmed) return;
    await _runMutation(() => widget.repository.deletePage(page.id));
  }

  Future<void> _runMutation(Future<void> Function() action) async {
    setState(() => _loading = true);
    try {
      await action();
      await _reloadPages();
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage(error.toString());
    }
  }

  void _showMessage(String message) {
    AdminToast.show(context, message: message, tone: AdminToastTone.error);
  }

  void _sort(String key) {
    setState(() {
      if (_sortKey == key) {
        _sortAscending = !_sortAscending;
      } else {
        _sortKey = key;
        _sortAscending = true;
      }
    });
    unawaited(_reloadPages());
  }

  @override
  Widget build(BuildContext context) {
    if (_showForm) {
      final selectedLanguageCode =
          AdminLocalizationScope.maybeOf(context)?.code ?? 'tr';
      return PageFormView(
        page: _editingPage,
        options: _options,
        initialLanguageCode: selectedLanguageCode,
        saving: _saving,
        onBack: () {
          setState(() {
            _showForm = false;
            _editingPage = null;
          });
        },
        onSave: (data) => unawaited(_savePage(data)),
      );
    }

    return _PagesSearchScope(
      query: _searchController.text,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth < 640 ? 16.0 : 28.0;

          if (constraints.maxWidth < AdminMobile.breakpoint) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                18,
                horizontalPadding,
                28,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.t('pages.title'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.deepOcean,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _PagesMobileView(
                      pages: _visiblePages(),
                      loading: _loading,
                      page: _page,
                      pageSize: _pageSize,
                      totalCount: _totalCount,
                      searchController: _searchController,
                      category: _category,
                      type: _type,
                      status: _status,
                      options: _options,
                      error: _error,
                      onCategoryChanged: (value) {
                        setState(() => _category = value);
                        _reloadFirstPage();
                      },
                      onTypeChanged: (value) {
                        setState(() => _type = value);
                        _reloadFirstPage();
                      },
                      onStatusChanged: (value) {
                        setState(() => _status = value);
                        _reloadFirstPage();
                      },
                      onAdd: () {
                        setState(() {
                          _editingPage = null;
                          _showForm = true;
                        });
                      },
                      onEdit: (page) {
                        setState(() {
                          _editingPage = page;
                          _showForm = true;
                        });
                      },
                      onToggleStatus: (page) => unawaited(_toggleStatus(page)),
                      onDelete: (page) => unawaited(_deletePage(page)),
                      onPageChanged: (page) {
                        setState(() => _page = page);
                        unawaited(_reloadPages());
                      },
                    ),
                  ),
                ],
              ),
            );
          }

          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.t('pages.title'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.deepOcean,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _FilterRow(
                      category: _category,
                      type: _type,
                      status: _status,
                      options: _options,
                      onCategoryChanged: (value) {
                        setState(() => _category = value);
                        _reloadFirstPage();
                      },
                      onTypeChanged: (value) {
                        setState(() => _type = value);
                        _reloadFirstPage();
                      },
                      onStatusChanged: (value) {
                        setState(() => _status = value);
                        _reloadFirstPage();
                      },
                    ),
                    const SizedBox(height: 28),
                    _Toolbar(
                      pageSize: _pageSize,
                      searchController: _searchController,
                      onPageSizeChanged: (value) {
                        setState(() {
                          _pageSize = value;
                          _page = 1;
                        });
                        unawaited(_reloadPages());
                      },
                      onAdd: () {
                        setState(() {
                          _editingPage = null;
                          _showForm = true;
                        });
                      },
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: _error != null
                          ? Center(child: Text(_error!, style: _errorStyle))
                          : _PagesTable(
                              pages: _visiblePages(),
                              loading: _loading,
                              sortKey: _sortKey,
                              sortAscending: _sortAscending,
                              onSort: _sort,
                              onEdit: (page) {
                                setState(() {
                                  _editingPage = page;
                                  _showForm = true;
                                });
                              },
                              onToggleStatus: (page) =>
                                  unawaited(_toggleStatus(page)),
                              onDelete: (page) => unawaited(_deletePage(page)),
                            ),
                    ),
                    const SizedBox(height: 16),
                    _PagesFooter(
                      page: _page,
                      pageSize: _pageSize,
                      totalCount: _totalCount,
                      onPageChanged: (page) {
                        setState(() => _page = page);
                        unawaited(_reloadPages());
                      },
                    ),
                  ],
                ),
              ),
            ],
          );

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
      ),
    );
  }

  TextStyle get _errorStyle =>
      const TextStyle(color: AppColors.actionRed, fontWeight: FontWeight.w700);
}

class PageFormView extends StatefulWidget {
  const PageFormView({
    super.key,
    required this.page,
    required this.options,
    required this.initialLanguageCode,
    required this.saving,
    required this.onBack,
    required this.onSave,
  });

  final AdminPage? page;
  final AdminPagesFilterOptions options;
  final String initialLanguageCode;
  final bool saving;
  final VoidCallback onBack;
  final ValueChanged<AdminPageFormData> onSave;

  @override
  State<PageFormView> createState() => _PageFormViewState();
}

class _PageFormViewState extends State<PageFormView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _slugController;
  late final TextEditingController _groupController;
  late final TextEditingController _menuOrderController;
  late final TextEditingController _metaTitleController;
  late final TextEditingController _metaKeywordsController;
  late final TextEditingController _metaDescriptionController;
  late final TextEditingController _canonicalController;
  late final quill.QuillController _contentController;
  late String _languageCode;
  late String _mainCategoryId;
  late String _subCategoryId;
  late String _leafCategoryId;
  late String _type;
  late String _location;
  late String _parentPageId;
  late bool _showTitle;
  late bool _showBreadcrumb;
  late bool _showSidebar;
  late bool _active;

  @override
  void initState() {
    super.initState();
    final page = widget.page;
    _titleController = TextEditingController(text: page?.title ?? '');
    _slugController = TextEditingController(text: page?.slug ?? '');
    _groupController = TextEditingController(
      text: page?.pageGroup.trim().isNotEmpty == true
          ? page!.pageGroup
          : 'Kurumsal',
    );
    _menuOrderController = TextEditingController(
      text: (page?.menuOrder ?? 1).toString(),
    );
    _metaTitleController = TextEditingController(text: page?.metaTitle ?? '');
    _metaKeywordsController = TextEditingController(
      text: page?.metaKeywords ?? '',
    );
    _metaDescriptionController = TextEditingController(
      text: page?.metaDescription ?? '',
    );
    _canonicalController = TextEditingController(
      text: page?.canonicalUrl ?? '',
    );
    _contentController = quill.QuillController(
      document: adminQuillDocumentFromJson(
        page?.contentDeltaJson ?? adminEmptyQuillDeltaJson,
      ),
      selection: const TextSelection.collapsed(offset: 0),
    );
    _languageCode = _safeLanguageCode(
      page?.languageCode ?? widget.initialLanguageCode,
    );
    _applyCategoryPath(page?.categoryId ?? '');
    _type = page?.type ?? 'custom';
    _location = page?.location ?? 'none';
    _parentPageId = _safeParentPageId(page?.parentPageId ?? '', _languageCode);
    _showTitle = page?.showTitle ?? true;
    _showBreadcrumb = page?.showBreadcrumb ?? true;
    _showSidebar = page?.showSidebar ?? true;
    _active = page?.active ?? true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _slugController.dispose();
    _groupController.dispose();
    _menuOrderController.dispose();
    _metaTitleController.dispose();
    _metaKeywordsController.dispose();
    _metaDescriptionController.dispose();
    _canonicalController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  String get _firstLanguage {
    if (widget.options.languages.isEmpty) return 'tr';
    return widget.options.languages.first.code;
  }

  String _safeLanguageCode(String code) {
    final trimmed = code.trim();
    if (widget.options.languages.any((language) => language.code == trimmed)) {
      return trimmed;
    }
    return _firstLanguage;
  }

  List<AdminPageCategory> get _languageCategories {
    return widget.options.categories
        .where((category) => category.languageCode == _languageCode)
        .toList(growable: false);
  }

  List<AdminPageCategory> get _rootCategories {
    return _languageCategories
        .where((category) => (category.parentId ?? '').trim().isEmpty)
        .toList(growable: false);
  }

  String get _selectedCategoryId {
    if (_leafCategoryId.isNotEmpty) return _leafCategoryId;
    if (_subCategoryId.isNotEmpty) return _subCategoryId;
    return _mainCategoryId;
  }

  AdminPageCategory? get _selectedCategory {
    final selectedId = _selectedCategoryId;
    if (selectedId.isEmpty) return null;
    for (final category in _languageCategories) {
      if (category.id == selectedId) return category;
    }
    return null;
  }

  String _safeCategoryId(String categoryId, String languageCode) {
    final trimmed = categoryId.trim();
    if (trimmed.isEmpty) return '';
    final exists = widget.options.categories.any(
      (category) =>
          category.id == trimmed && category.languageCode == languageCode,
    );
    return exists ? trimmed : '';
  }

  void _applyCategoryPath(String categoryId) {
    final path = _categoryPath(categoryId);
    _mainCategoryId = path.isNotEmpty ? path.first.id : '';
    _subCategoryId = path.length > 1 ? path[1].id : '';
    _leafCategoryId = path.length > 2 ? path[2].id : '';
  }

  List<AdminPageCategory> _categoryPath(String categoryId) {
    final safeId = _safeCategoryId(categoryId, _languageCode);
    if (safeId.isEmpty) return const [];
    final byId = {
      for (final category in _languageCategories) category.id: category,
    };
    final path = <AdminPageCategory>[];
    var current = byId[safeId];
    final visited = <String>{};
    while (current != null && visited.add(current.id)) {
      path.insert(0, current);
      final parentId = current.parentId?.trim() ?? '';
      current = parentId.isEmpty ? null : byId[parentId];
    }
    return path;
  }

  List<AdminPageCategory> _childCategories(String parentId) {
    final safeParentId = parentId.trim();
    if (safeParentId.isEmpty) return const [];
    return _languageCategories
        .where((category) => (category.parentId ?? '').trim() == safeParentId)
        .toList(growable: false);
  }

  String _safeParentPageId(String parentPageId, String languageCode) {
    final trimmed = parentPageId.trim();
    if (trimmed.isEmpty) return '';
    final exists = widget.options.parents.any(
      (page) =>
          page.id == trimmed &&
          page.id != widget.page?.id &&
          page.languageCode == languageCode,
    );
    return exists ? trimmed : '';
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final category = _selectedCategory;
    widget.onSave(
      AdminPageFormData(
        title: _titleController.text,
        slug: _slugController.text,
        pageGroup: _groupController.text,
        languageCode: _languageCode,
        categoryId: _selectedCategoryId,
        category: category?.label ?? widget.page?.category ?? '',
        type: _type,
        status: _active ? 'active' : 'passive',
        location: _location,
        parentPageId: _parentPageId,
        showTitle: _showTitle,
        showBreadcrumb: _showBreadcrumb,
        showSidebar: _showSidebar,
        registeredOnly: widget.page?.registeredOnly ?? false,
        menuOrder: int.tryParse(_menuOrderController.text.trim()) ?? 1,
        contentDeltaJson: adminQuillDeltaJson(_contentController),
        contentPlainText: adminQuillPlainText(_contentController),
        metaTitle: _metaTitleController.text,
        metaKeywords: _metaKeywordsController.text,
        metaDescription: _metaDescriptionController.text,
        canonicalUrl: _canonicalController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleKey = widget.page == null
        ? 'pages.form.addTitle'
        : 'pages.form.editTitle';
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 640 ? 16.0 : 28.0;
        return Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              28,
              horizontalPadding,
              30,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      context.t(titleKey),
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: AppColors.deepOcean,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                          ),
                    ),
                    const Spacer(),
                    _OutlineActionButton(
                      icon: Symbols.format_list_numbered,
                      label: 'pages.backToList',
                      onTap: widget.onBack,
                    ),
                    const SizedBox(width: 10),
                    _PrimaryActionButton(
                      icon: Symbols.check,
                      label: widget.saving ? 'pages.saving' : 'common.save',
                      onTap: widget.saving ? null : _submit,
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Builder(
                  builder: (context) {
                    final compactForm = constraints.maxWidth < 980;
                    final settingsColumn = SizedBox(
                      width: compactForm ? double.infinity : 324,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _SettingsCard(
                            title: 'pages.form.categorySettings',
                            children: _categorySettingsFields(context),
                          ),
                          const SizedBox(height: 20),
                          _SettingsCard(
                            title: 'pages.form.settings',
                            children: [
                              _SwitchLine(
                                label: 'pages.field.showTitle',
                                value: _showTitle,
                                onChanged: (value) =>
                                    setState(() => _showTitle = value),
                              ),
                              _SwitchLine(
                                label: 'pages.field.showBreadcrumb',
                                value: _showBreadcrumb,
                                onChanged: (value) =>
                                    setState(() => _showBreadcrumb = value),
                              ),
                              _SwitchLine(
                                label: 'pages.field.showSidebar',
                                value: _showSidebar,
                                onChanged: (value) =>
                                    setState(() => _showSidebar = value),
                              ),
                              _NumberStepperField(
                                label: 'pages.field.menuOrder',
                                controller: _menuOrderController,
                              ),
                              _SwitchLine(
                                label: 'pages.field.status',
                                value: _active,
                                valueLabel: _active
                                    ? 'pages.status.active'
                                    : 'pages.status.passive',
                                onChanged: (value) =>
                                    setState(() => _active = value),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                    final mainContent = Column(
                      children: [
                        _SettingsCard(
                          title: 'pages.form.general',
                          children: [
                            _TextField(
                              label: 'pages.field.title',
                              controller: _titleController,
                              isRequired: true,
                            ),
                            _TextField(
                              label: 'pages.field.slug',
                              controller: _slugController,
                              helper: 'pages.hint.slug',
                            ),
                            _TextField(
                              label: 'pages.field.group',
                              controller: _groupController,
                              helper: 'pages.hint.group',
                            ),
                            _SelectField(
                              label: 'pages.field.type',
                              value: _type,
                              items: _typeItems(context, widget.options),
                              onChanged: (value) => setState(() {
                                _type = value ?? 'custom';
                              }),
                            ),
                            ArticleRichTextEditor(
                              controller: _contentController,
                              placeholder: 'newsAdd.contentHint',
                            ),
                          ],
                        ),
                      ],
                    );
                    if (compactForm) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          settingsColumn,
                          const SizedBox(height: 20),
                          mainContent,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        settingsColumn,
                        const SizedBox(width: 32),
                        Expanded(child: mainContent),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _categorySettingsFields(BuildContext context) {
    final subCategories = _childCategories(_mainCategoryId);
    final leafCategories = _childCategories(_subCategoryId);
    return [
      _SelectField(
        label: 'pages.field.newsLanguage',
        value: _languageCode,
        items: [
          for (final lang in widget.options.languages)
            DropdownMenuItem(value: lang.code, child: Text(lang.name)),
        ],
        onChanged: (value) => setState(() {
          _languageCode = _safeLanguageCode(value ?? _firstLanguage);
          _applyCategoryPath(_selectedCategoryId);
          _parentPageId = _safeParentPageId(_parentPageId, _languageCode);
        }),
      ),
      _SelectField(
        label: 'pages.field.mainCategory',
        value: _mainCategoryId,
        items: [
          DropdownMenuItem(value: '', child: Text(context.t('pages.none'))),
          for (final category in _rootCategories)
            DropdownMenuItem(value: category.id, child: Text(category.label)),
        ],
        onChanged: (value) => setState(() {
          _mainCategoryId = _safeCategoryId(value ?? '', _languageCode);
          _subCategoryId = '';
          _leafCategoryId = '';
        }),
      ),
      if (subCategories.isNotEmpty)
        _SelectField(
          label: 'pages.field.subCategory',
          value: _subCategoryId,
          items: [
            DropdownMenuItem(
              value: '',
              child: Text(context.t('pages.placeholder.subCategory')),
            ),
            for (final category in subCategories)
              DropdownMenuItem(value: category.id, child: Text(category.label)),
          ],
          onChanged: (value) => setState(() {
            _subCategoryId = _safeCategoryId(value ?? '', _languageCode);
            _leafCategoryId = '';
          }),
        ),
      if (leafCategories.isNotEmpty)
        _SelectField(
          label: 'pages.field.leafCategory',
          value: _leafCategoryId,
          items: [
            DropdownMenuItem(
              value: '',
              child: Text(context.t('pages.placeholder.leafCategory')),
            ),
            for (final category in leafCategories)
              DropdownMenuItem(value: category.id, child: Text(category.label)),
          ],
          onChanged: (value) => setState(() {
            _leafCategoryId = _safeCategoryId(value ?? '', _languageCode);
          }),
        ),
    ];
  }

  List<DropdownMenuItem<String>> _typeItems(
    BuildContext context,
    AdminPagesFilterOptions options,
  ) {
    final values = {'custom', 'default', 'legal', 'landing', ...options.types};
    return [
      for (final value in values)
        DropdownMenuItem(
          value: value,
          child: Text(context.t('pages.type.$value')),
        ),
    ];
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.category,
    required this.type,
    required this.status,
    required this.options,
    required this.onCategoryChanged,
    required this.onTypeChanged,
    required this.onStatusChanged,
  });

  final String category;
  final String type;
  final String status;
  final AdminPagesFilterOptions options;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<String> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 900;
        final filters = [
          _FilterSelect(
            label: 'pages.column.category',
            value: category,
            items: [
              DropdownMenuItem(value: 'Tümü', child: Text(context.t('All'))),
              for (final item in options.categories)
                DropdownMenuItem(
                  value: item.id,
                  child: Text(item.displayLabel),
                ),
            ],
            onChanged: (value) => onCategoryChanged(value ?? 'Tümü'),
          ),
          _FilterSelect(
            label: 'pages.column.type',
            value: type,
            items: [
              DropdownMenuItem(value: 'Tümü', child: Text(context.t('All'))),
              for (final item in {
                'custom',
                'default',
                'legal',
                'landing',
                ...options.types,
              })
                DropdownMenuItem(
                  value: item,
                  child: Text(context.t('pages.type.$item')),
                ),
            ],
            onChanged: (value) => onTypeChanged(value ?? 'Tümü'),
          ),
          _FilterSelect(
            label: 'pages.column.status',
            value: status,
            items: [
              DropdownMenuItem(value: 'Tümü', child: Text(context.t('All'))),
              DropdownMenuItem(
                value: 'active',
                child: Text(context.t('pages.status.active')),
              ),
              DropdownMenuItem(
                value: 'passive',
                child: Text(context.t('pages.status.passive')),
              ),
            ],
            onChanged: (value) => onStatusChanged(value ?? 'Tümü'),
          ),
        ];

        if (compact) {
          return Wrap(
            spacing: 16,
            runSpacing: 14,
            children: [
              for (final filter in filters)
                SizedBox(
                  width: constraints.maxWidth < 560
                      ? constraints.maxWidth
                      : (constraints.maxWidth - 16) / 2,
                  child: filter,
                ),
            ],
          );
        }

        return Row(
          children: [
            for (var index = 0; index < filters.length; index++) ...[
              Expanded(child: filters[index]),
              if (index != filters.length - 1) const SizedBox(width: 16),
            ],
          ],
        );
      },
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.pageSize,
    required this.searchController,
    required this.onPageSizeChanged,
    required this.onAdd,
  });

  final int pageSize;
  final TextEditingController searchController;
  final ValueChanged<int> onPageSizeChanged;
  final VoidCallback onAdd;

  static const double _toolbarHeight = 38;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final pageSizeSelect = MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            width: 64,
            height: _toolbarHeight,
            padding: const EdgeInsets.only(left: 12, right: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.value),
              border: Border.all(color: AppColors.line.withValues(alpha: 0.72)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: pageSize,
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
                items: const [
                  DropdownMenuItem(value: 10, child: Text('10')),
                  DropdownMenuItem(value: 25, child: Text('25')),
                  DropdownMenuItem(value: 50, child: Text('50')),
                  DropdownMenuItem(value: 100, child: Text('100')),
                ],
                onChanged: (value) {
                  if (value != null) onPageSizeChanged(value);
                },
              ),
            ),
          ),
        );

        final search = ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: compact ? double.infinity : 260,
            maxWidth: compact ? double.infinity : 280,
          ),
          child: Container(
            height: _toolbarHeight,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.value),
              border: Border.all(color: AppColors.line.withValues(alpha: 0.72)),
            ),
            child: TextField(
              controller: searchController,
              mouseCursor: SystemMouseCursors.text,
              cursorColor: AppColors.support,
              textAlignVertical: TextAlignVertical.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.deepOcean,
                fontWeight: FontWeight.w400,
              ),
              decoration: InputDecoration(
                hintText: context.t('pages.searchPlaceholder'),
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
                  minHeight: _toolbarHeight,
                ),
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: searchController,
                  builder: (context, value, _) {
                    if (value.text.isEmpty) return const SizedBox.shrink();
                    return IconButton(
                      mouseCursor: SystemMouseCursors.click,
                      onPressed: searchController.clear,
                      icon: const SymbolIcon(
                        Symbols.close,
                        color: AppColors.iconMuted,
                        size: 16,
                      ),
                    );
                  },
                ),
                suffixIconConstraints: const BoxConstraints(
                  minWidth: 38,
                  minHeight: _toolbarHeight,
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
          ),
        );

        final addButton = SizedBox(
          height: _toolbarHeight,
          child: TextButton(
            onPressed: onAdd,
            style:
                TextButton.styleFrom(
                  backgroundColor: AppColors.actionRed,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, _toolbarHeight),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
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
                Text(context.t('pages.addButton')),
              ],
            ),
          ),
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

class _PagesTable extends StatelessWidget {
  const _PagesTable({
    required this.pages,
    required this.loading,
    required this.sortKey,
    required this.sortAscending,
    required this.onSort,
    required this.onEdit,
    required this.onToggleStatus,
    required this.onDelete,
  });

  final List<AdminPage> pages;
  final bool loading;
  final String sortKey;
  final bool sortAscending;
  final ValueChanged<String> onSort;
  final ValueChanged<AdminPage> onEdit;
  final ValueChanged<AdminPage> onToggleStatus;
  final ValueChanged<AdminPage> onDelete;

  static const double _minWidth = 1080;
  static const double _horizontalPadding = 32;
  static const double _tableBorderWidth = 2;
  static const double _titleWidth = 300;
  static const double _groupWidth = 120;
  static const double _categoryWidth = 140;
  static const double _typeWidth = 120;
  static const double _statusWidth = 112;
  static const double _createdWidth = 160;
  static const double _actionsWidth = 76;
  static const double _minContentWidth =
      _titleWidth +
      _groupWidth +
      _categoryWidth +
      _typeWidth +
      _statusWidth +
      _createdWidth +
      _actionsWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth = constraints.maxWidth < _minWidth
            ? _minWidth
            : constraints.maxWidth;
        final widths = _PagesTableWidths.forWidth(tableWidth);
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
                  _TableHeader(
                    widths: widths,
                    sortKey: sortKey,
                    sortAscending: sortAscending,
                    onSort: onSort,
                  ),
                  Expanded(
                    child: loading && pages.isEmpty
                        ? const Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.deepOcean,
                              ),
                            ),
                          )
                        : pages.isEmpty
                        ? Center(
                            child: Text(
                              context.t('pages.empty'),
                              style: const TextStyle(
                                color: AppColors.support,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        : SingleChildScrollView(
                            child: Column(
                              children: [
                                for (final page in pages)
                                  _PageRow(
                                    page: page,
                                    widths: widths,
                                    onEdit: onEdit,
                                    onToggleStatus: onToggleStatus,
                                    onDelete: onDelete,
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

class _PagesTableWidths {
  const _PagesTableWidths({
    required this.title,
    required this.group,
    required this.category,
    required this.type,
    required this.status,
    required this.created,
    required this.actions,
  });

  final double title;
  final double group;
  final double category;
  final double type;
  final double status;
  final double created;
  final double actions;

  static _PagesTableWidths forWidth(double tableWidth) {
    final contentWidth =
        (tableWidth -
                _PagesTable._horizontalPadding -
                _PagesTable._tableBorderWidth)
            .clamp(_PagesTable._minContentWidth, double.infinity);
    final scale = contentWidth / _PagesTable._minContentWidth;
    return _PagesTableWidths(
      title: _PagesTable._titleWidth * scale,
      group: _PagesTable._groupWidth * scale,
      category: _PagesTable._categoryWidth * scale,
      type: _PagesTable._typeWidth * scale,
      status: _PagesTable._statusWidth * scale,
      created: _PagesTable._createdWidth * scale,
      actions: _PagesTable._actionsWidth * scale,
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader({
    required this.widths,
    required this.sortKey,
    required this.sortAscending,
    required this.onSort,
  });

  final _PagesTableWidths widths;
  final String sortKey;
  final bool sortAscending;
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
          _HeaderCell(
            'pages.column.title',
            'title',
            widths.title,
            sortKey,
            sortAscending,
            onSort,
          ),
          _HeaderCell(
            'pages.column.group',
            'group',
            widths.group,
            sortKey,
            sortAscending,
            onSort,
          ),
          _HeaderCell(
            'pages.column.category',
            'category',
            widths.category,
            sortKey,
            sortAscending,
            onSort,
          ),
          _HeaderCell(
            'pages.column.type',
            'type',
            widths.type,
            sortKey,
            sortAscending,
            onSort,
          ),
          _HeaderCell(
            'pages.column.status',
            'status',
            widths.status,
            sortKey,
            sortAscending,
            onSort,
          ),
          _HeaderCell(
            'pages.column.createdAt',
            'createdAt',
            widths.created,
            sortKey,
            sortAscending,
            onSort,
          ),
          SizedBox(
            width: widths.actions,
            child: Text(
              context.t('pages.column.actions'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.inkSoft,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(
    this.label,
    this.keyName,
    this.width,
    this.sortKey,
    this.sortAscending,
    this.onSort,
  );

  final String label;
  final String keyName;
  final double width;
  final String sortKey;
  final bool sortAscending;
  final ValueChanged<String> onSort;

  @override
  Widget build(BuildContext context) {
    final selected = sortKey == keyName;
    final icon = SymbolIcon(
      Symbols.keyboard_arrow_down,
      color: selected ? AppColors.deepOcean : AppColors.support,
      size: 14,
    );

    return SizedBox(
      width: width,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onSort(keyName),
          child: Row(
            children: [
              Flexible(
                fit: FlexFit.loose,
                child: Text(
                  context.t(label),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? AppColors.deepOcean : AppColors.inkSoft,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              selected && sortAscending
                  ? RotatedBox(quarterTurns: 2, child: icon)
                  : icon,
            ],
          ),
        ),
      ),
    );
  }
}

class _PageRow extends StatelessWidget {
  const _PageRow({
    required this.page,
    required this.widths,
    required this.onEdit,
    required this.onToggleStatus,
    required this.onDelete,
  });

  final AdminPage page;
  final _PagesTableWidths widths;
  final ValueChanged<AdminPage> onEdit;
  final ValueChanged<AdminPage> onToggleStatus;
  final ValueChanged<AdminPage> onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 92),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AppColors.softLine.withValues(alpha: 0.86)),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: widths.title,
            child: _PageTitleCell(page: page),
          ),
          SizedBox(
            width: widths.group,
            child: _PageGroupCell(page: page),
          ),
          SizedBox(
            width: widths.category,
            child: _PageCategoryCell(page: page),
          ),
          SizedBox(
            width: widths.type,
            child: _TypeBadge(type: page.displayType),
          ),
          SizedBox(
            width: widths.status,
            child: _StatusBadge(active: page.active),
          ),
          SizedBox(
            width: widths.created,
            child: _DateCell(value: page.createdAt),
          ),
          SizedBox(
            width: widths.actions,
            child: Center(
              child: _PagesRowMenu(
                tooltip: context.t('pages.actions.tooltip'),
                active: page.active,
                onEdit: () => onEdit(page),
                onToggleStatus: () => onToggleStatus(page),
                onDelete: () => onDelete(page),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PagesRowMenu extends StatefulWidget {
  const _PagesRowMenu({
    required this.tooltip,
    required this.active,
    required this.onEdit,
    required this.onToggleStatus,
    required this.onDelete,
  });

  final String tooltip;
  final bool active;
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;
  final VoidCallback onDelete;

  @override
  State<_PagesRowMenu> createState() => _PagesRowMenuState();
}

class _PagesRowMenuState extends State<_PagesRowMenu> {
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
              child: _PagesMenuCard(
                active: widget.active,
                onEdit: () => _runAndClose(widget.onEdit),
                onToggleStatus: () => _runAndClose(widget.onToggleStatus),
                onDelete: () => _runAndClose(widget.onDelete),
              ),
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
        message: widget.tooltip,
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

class _PagesMenuCard extends StatelessWidget {
  const _PagesMenuCard({
    required this.active,
    required this.onEdit,
    required this.onToggleStatus,
    required this.onDelete,
  });

  final bool active;
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;
  final VoidCallback onDelete;

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
            _PagesMenuItem(
              icon: Symbols.edit_square,
              label: context.t('common.edit'),
              onTap: onEdit,
            ),
            _PagesMenuItem(
              icon: active ? Symbols.visibility_off : Symbols.check,
              label: context.t(
                active ? 'pages.actions.deactivate' : 'pages.actions.activate',
              ),
              onTap: onToggleStatus,
            ),
            _PagesMenuItem(
              icon: Symbols.delete,
              label: context.t('common.delete'),
              onTap: onDelete,
              danger: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _PagesMenuItem extends StatelessWidget {
  const _PagesMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.actionRed : AppColors.deepOcean;

    return InkWell(
      mouseCursor: SystemMouseCursors.click,
      borderRadius: BorderRadius.circular(AppRadius.value),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          children: [
            SymbolIcon(icon, size: 20, color: color),
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

class _PageTitleCell extends StatelessWidget {
  const _PageTitleCell({required this.page});

  final AdminPage page;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HighlightedText(
          context.t(page.displayTitle),
          query: _PagesSearchScope.of(context),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.deepOcean,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            height: 1.22,
          ),
        ),
        const SizedBox(height: 6),
        HighlightedText(
          '${page.slug.isEmpty ? '-' : page.slug} • ${page.displayLanguage}',
          query: _PagesSearchScope.of(context),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.support,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _PageGroupCell extends StatelessWidget {
  const _PageGroupCell({required this.page});

  final AdminPage page;

  @override
  Widget build(BuildContext context) {
    return HighlightedText(
      page.displayGroup,
      query: _PagesSearchScope.of(context),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: _smallStrong,
    );
  }
}

class _PageCategoryCell extends StatelessWidget {
  const _PageCategoryCell({required this.page});

  final AdminPage page;

  @override
  Widget build(BuildContext context) {
    final parent = page.parentCategory?.trim();
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (parent != null && parent.isNotEmpty) ...[
          HighlightedText(
            parent,
            query: _PagesSearchScope.of(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _smallStrong,
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '\u21B3',
                style: TextStyle(color: AppColors.support, fontSize: 12),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: HighlightedText(
                  page.displayCategory,
                  query: _PagesSearchScope.of(context),
                  style: _smallStrong,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ] else
          HighlightedText(
            page.displayCategory,
            query: _PagesSearchScope.of(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _smallStrong,
          ),
      ],
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.deepOcean.withValues(alpha: 0.74),
          borderRadius: BorderRadius.circular(AppRadius.value),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: Text(
            context.t('pages.type.$type'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF198754) : AppColors.support;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.value),
          border: Border.all(color: AppColors.softLine.withValues(alpha: 0.9)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(AppRadius.value),
              ),
            ),
            const SizedBox(width: 5),
            Text(
              context.t(
                active ? 'pages.status.active' : 'pages.status.passive',
              ),
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateCell extends StatelessWidget {
  const _DateCell({required this.value});

  final DateTime? value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          formatAdminFullDate(context, value),
          style: const TextStyle(
            color: AppColors.deepOcean,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          formatAdminTime(value),
          style: const TextStyle(
            color: AppColors.support,
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t(title),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.deepOcean,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 24),
          for (final child in children) ...[child, const SizedBox(height: 18)],
        ],
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  const _TextField({
    required this.label,
    required this.controller,
    this.isRequired = false,
    this.helper,
  });

  final String label;
  final TextEditingController controller;
  final bool isRequired;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.t(label),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: isRequired ? AppColors.actionRed : AppColors.deepOcean,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(minHeight: 38),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isRequired
                    ? AppColors.actionRed.withValues(alpha: 0.84)
                    : AppColors.line,
              ),
            ),
          ),
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
              hintText: helper == null ? null : context.t(helper!),
              hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.placeholder,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
              errorStyle: const TextStyle(
                color: AppColors.actionRed,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.only(bottom: 2),
              filled: false,
              hoverColor: Colors.transparent,
              focusColor: Colors.transparent,
            ),
            validator: isRequired
                ? (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return context.t('pages.validation.required');
                    }
                    return null;
                  }
                : null,
          ),
        ),
      ],
    );
  }
}

class _NumberStepperField extends StatelessWidget {
  const _NumberStepperField({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;
  static const _minValue = 0;

  int get _currentValue {
    final value = int.tryParse(controller.text.trim()) ?? _minValue;
    return value < _minValue ? _minValue : value;
  }

  void _changeBy(int delta) {
    final next = (_currentValue + delta).clamp(_minValue, 999999);
    controller.text = next.toString();
    controller.selection = TextSelection.collapsed(
      offset: controller.text.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.t(label),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.deepOcean,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.value),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            children: [
              _StepperButton(icon: Symbols.remove, onTap: () => _changeBy(-1)),
              Expanded(
                child: TextFormField(
                  controller: controller,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  mouseCursor: SystemMouseCursors.text,
                  cursorColor: AppColors.support,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.deepOcean,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.only(bottom: 2),
                  ),
                ),
              ),
              _StepperButton(icon: Symbols.add, onTap: () => _changeBy(1)),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 42,
          child: Icon(icon, size: 18, color: AppColors.support),
        ),
      ),
    );
  }
}

class _SelectField extends StatelessWidget {
  const _SelectField({
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.t(label),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.deepOcean,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 8),
        MouseRegion(
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
                isExpanded: true,
                value: safeValue,
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
                items: items,
                onChanged: onChanged,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterSelect extends StatelessWidget {
  const _FilterSelect({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  static const double _filterHeight = 38;

  @override
  Widget build(BuildContext context) {
    final safeValue = items.any((item) => item.value == value)
        ? value
        : (items.isEmpty ? null : items.first.value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.t(label),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.deepOcean,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 8),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            height: _filterHeight,
            padding: const EdgeInsets.only(left: 12, right: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.value),
              border: Border.all(color: AppColors.line.withValues(alpha: 0.72)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: safeValue,
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
                items: items,
                onChanged: onChanged,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SwitchLine extends StatelessWidget {
  const _SwitchLine({
    required this.label,
    required this.value,
    required this.onChanged,
    this.valueLabel,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? valueLabel;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: Row(
          children: [
            Expanded(
              child: Text(
                context.t(label),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.deepOcean,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ),
            if (valueLabel != null) ...[
              Text(
                context.t(valueLabel!),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: value ? AppColors.actionRed : AppColors.support,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(width: 10),
            ],
            _CompactSwitch(value: value, onToggle: () => onChanged(!value)),
          ],
        ),
      ),
    );
  }
}

class _CompactSwitch extends StatelessWidget {
  const _CompactSwitch({required this.value, required this.onToggle});

  final bool value;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: onToggle == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onToggle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 42,
          height: 24,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: value ? AppColors.actionRed : AppColors.softLine,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: value
                  ? AppColors.actionRed
                  : AppColors.line.withValues(alpha: 0.9),
            ),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 18,
              height: 18,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: value
                  ? const SymbolIcon(
                      Symbols.check,
                      color: AppColors.actionRed,
                      size: 12,
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: TextButton(
        onPressed: onTap,
        style:
            TextButton.styleFrom(
              backgroundColor: AppColors.actionRed,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 38),
              padding: const EdgeInsets.symmetric(horizontal: 16),
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
            SymbolIcon(icon, color: Colors.white, size: 17),
            const SizedBox(width: 7),
            Text(context.t(label)),
          ],
        ),
      ),
    );
  }
}

class _OutlineActionButton extends StatelessWidget {
  const _OutlineActionButton({
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
      child: TextButton(
        onPressed: onTap,
        style:
            TextButton.styleFrom(
              foregroundColor: AppColors.deepOcean,
              minimumSize: const Size(0, 38),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              side: BorderSide(color: AppColors.line.withValues(alpha: 0.88)),
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
            SymbolIcon(icon, size: 17, color: AppColors.deepOcean),
            const SizedBox(width: 7),
            Text(context.t(label)),
          ],
        ),
      ),
    );
  }
}

class _PagesFooter extends StatelessWidget {
  const _PagesFooter({
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
    final from = totalCount == 0 ? 0 : ((page - 1) * pageSize) + 1;
    final to = (page * pageSize).clamp(0, totalCount);
    final totalPages = (totalCount / pageSize).ceil().clamp(1, 999999);
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
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.inkSoft,
            fontWeight: FontWeight.w500,
            letterSpacing: 0,
          ),
        );
        final pager = _PagesPagination(
          page: page,
          totalPages: totalPages,
          onPageChanged: onPageChanged,
        );

        if (mobile) {
          final hasPrevious = page > 1;
          final hasNext = to < totalCount;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              IconButton(
                onPressed: hasPrevious ? () => onPageChanged(page - 1) : null,
                icon: const Icon(Symbols.chevron_left),
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
                icon: const Icon(Symbols.chevron_right),
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

class _PagesPagination extends StatelessWidget {
  const _PagesPagination({
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

const _smallStrong = TextStyle(
  color: AppColors.deepOcean,
  fontWeight: FontWeight.w600,
  fontSize: 11.5,
);

class _PagesMobileView extends StatelessWidget {
  const _PagesMobileView({
    required this.pages,
    required this.loading,
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.searchController,
    required this.category,
    required this.type,
    required this.status,
    required this.options,
    required this.error,
    required this.onCategoryChanged,
    required this.onTypeChanged,
    required this.onStatusChanged,
    required this.onAdd,
    required this.onEdit,
    required this.onToggleStatus,
    required this.onDelete,
    required this.onPageChanged,
  });

  final List<AdminPage> pages;
  final bool loading;
  final int page;
  final int pageSize;
  final int totalCount;
  final TextEditingController searchController;
  final String category;
  final String type;
  final String status;
  final AdminPagesFilterOptions options;
  final String? error;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onAdd;
  final ValueChanged<AdminPage> onEdit;
  final ValueChanged<AdminPage> onToggleStatus;
  final ValueChanged<AdminPage> onDelete;
  final ValueChanged<int> onPageChanged;

  int get _activeFilterCount {
    var count = 0;
    if (category != 'Tümü') count++;
    if (type != 'Tümü') count++;
    if (status != 'Tümü') count++;
    return count;
  }

  void _openFilters(BuildContext context) {
    showAdminMobileFilterSheet(
      context: context,
      onClear: () {
        onCategoryChanged('Tümü');
        onTypeChanged('Tümü');
        onStatusChanged('Tümü');
      },
      contentBuilder: (context, setSheetState) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AdminMobileFilterField(
              label: context.t('pages.column.category'),
              value: category,
              items: [
                DropdownMenuItem(value: 'Tümü', child: Text(context.t('All'))),
                for (final item in options.categories)
                  DropdownMenuItem(
                    value: item.id,
                    child: Text(item.displayLabel),
                  ),
              ],
              onChanged: (value) {
                onCategoryChanged(value ?? 'Tümü');
                setSheetState(() {});
              },
            ),
            AdminMobileFilterField(
              label: context.t('pages.column.type'),
              value: type,
              items: [
                DropdownMenuItem(value: 'Tümü', child: Text(context.t('All'))),
                for (final item in {
                  'custom',
                  'default',
                  'legal',
                  'landing',
                  ...options.types,
                })
                  DropdownMenuItem(
                    value: item,
                    child: Text(context.t('pages.type.$item')),
                  ),
              ],
              onChanged: (value) {
                onTypeChanged(value ?? 'Tümü');
                setSheetState(() {});
              },
            ),
            AdminMobileFilterField(
              label: context.t('pages.column.status'),
              value: status,
              items: [
                DropdownMenuItem(value: 'Tümü', child: Text(context.t('All'))),
                DropdownMenuItem(
                  value: 'active',
                  child: Text(context.t('pages.status.active')),
                ),
                DropdownMenuItem(
                  value: 'passive',
                  child: Text(context.t('pages.status.passive')),
                ),
              ],
              onChanged: (value) {
                onStatusChanged(value ?? 'Tümü');
                setSheetState(() {});
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final lastPage = totalCount == 0 ? 1 : ((totalCount - 1) ~/ pageSize) + 1;
    final from = totalCount == 0 ? 0 : ((page - 1) * pageSize) + 1;
    final to = totalCount == 0
        ? 0
        : (page * pageSize > totalCount ? totalCount : page * pageSize);
    final rangeText = context.t(
      'common.recordRange',
      values: {'from': from, 'to': to, 'total': totalCount},
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminMobileToolbar(
          controller: searchController,
          query: searchController.text,
          hintText: context.t('pages.searchPlaceholder'),
          onSearchChanged: (_) {},
          activeFilterCount: _activeFilterCount,
          onOpenFilters: () => _openFilters(context),
          showFilters: false,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: AdminMobileFiltersButton(
                label: context.t('Filtreler'),
                count: _activeFilterCount,
                active: _activeFilterCount > 0,
                fullWidth: true,
                onPressed: () => _openFilters(context),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AdminMobilePrimaryButton(
                icon: Symbols.add,
                label: context.t('pages.addButton'),
                fullWidth: true,
                onPressed: onAdd,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Expanded(
          child: error != null
              ? Center(
                  child: Text(
                    error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.actionRed,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              : AdminMobileListView(
                  loading: loading,
                  itemCount: pages.length,
                  emptyLabel: context.t('pages.empty'),
                  itemBuilder: (context, index) {
                    final item = pages[index];
                    return _PagesMobileCard(
                      page: item,
                      onEdit: onEdit,
                      onToggleStatus: onToggleStatus,
                      onDelete: onDelete,
                    );
                  },
                ),
        ),
        const SizedBox(height: 12),
        AdminMobilePager(
          page: page,
          lastPage: lastPage,
          rangeText: rangeText,
          loading: loading,
          onPageChanged: onPageChanged,
        ),
      ],
    );
  }
}

class _PagesMobileCard extends StatelessWidget {
  const _PagesMobileCard({
    required this.page,
    required this.onEdit,
    required this.onToggleStatus,
    required this.onDelete,
  });

  final AdminPage page;
  final ValueChanged<AdminPage> onEdit;
  final ValueChanged<AdminPage> onToggleStatus;
  final ValueChanged<AdminPage> onDelete;

  @override
  Widget build(BuildContext context) {
    final slug = page.slug.trim().isEmpty ? '-' : page.slug.trim();
    final statusColor = page.active
        ? const Color(0xFF198754)
        : AppColors.support;

    return AdminMobileCard(
      onTap: () => onEdit(page),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AdminMobileThumb(fallbackIcon: Symbols.article),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HighlightedText(
                      context.t(page.displayTitle),
                      query: _PagesSearchScope.of(context),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.deepOcean,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$slug • ${page.displayLanguage}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.support,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              AdminMobileMenuButton(
                tooltip: context.t('pages.actions.tooltip'),
                actions: [
                  AdminMobileMenuAction(
                    icon: Symbols.edit_square,
                    label: context.t('common.edit'),
                    onTap: () => onEdit(page),
                  ),
                  AdminMobileMenuAction(
                    icon: page.active ? Symbols.visibility_off : Symbols.check,
                    label: context.t(
                      page.active
                          ? 'pages.actions.deactivate'
                          : 'pages.actions.activate',
                    ),
                    onTap: () => onToggleStatus(page),
                  ),
                  AdminMobileMenuAction(
                    icon: Symbols.delete,
                    label: context.t('common.delete'),
                    danger: true,
                    onTap: () => onDelete(page),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _TypeBadge(type: page.displayType),
              if (page.displayGroup.trim().isNotEmpty)
                AdminMobileChip(
                  label: page.displayGroup,
                  color: AppColors.deepOcean,
                ),
              if (page.displayCategory.trim().isNotEmpty)
                AdminMobileChip(
                  label: page.displayCategory,
                  color: AppColors.support,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: AppColors.softLine.withValues(alpha: 0.9)),
          const SizedBox(height: 10),
          Row(
            children: [
              AdminMobileStatusPill(
                label: context.t(
                  page.active ? 'pages.status.active' : 'pages.status.passive',
                ),
                color: statusColor,
              ),
              const Spacer(),
              Text(
                formatAdminFullDate(context, page.createdAt),
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.support,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
