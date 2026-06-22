import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';
import 'package:pateeznews_admin/shared/widgets/admin_toast.dart';

import '../../../core/localization/admin_language_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/widgets/admin_table_chrome.dart';
import '../../../shared/widgets/sortable_table_header.dart';
import '../../../shared/widgets/symbol_icon.dart';
import '../../auth/data/admin_auth_models.dart';
import '../data/admin_font_settings_repository.dart';
import '../data/admin_language_models.dart';

class FontSettingsScreen extends StatefulWidget {
  const FontSettingsScreen({
    super.key,
    required this.session,
    this.repository = const SupabaseAdminFontSettingsRepository(),
  });

  final AdminSession session;
  final AdminFontSettingsRepository repository;

  @override
  State<FontSettingsScreen> createState() => _FontSettingsScreenState();
}

class _FontSettingsScreenState extends State<FontSettingsScreen> {
  late final Map<String, TextEditingController> _sizeControllers;
  late final Map<String, TextEditingController> _weightControllers;
  late final TextEditingController _searchController;

  var _initialized = false;
  var _loading = true;
  var _saving = false;
  var _adding = false;
  var _editing = false;
  var _language = 'tr';
  var _primaryFont = 'PateezInter';
  var _secondaryFont = 'PateezInter';
  var _contentFont = 'PateezInter';
  var _mobilePrimaryFont = 'PateezInter';
  var _mobileSecondaryFont = 'PateezInter';
  var _mobileContentFont = 'PateezInter';
  var _pageSize = 25;
  var _page = 1;
  var _searchQuery = '';
  var _sortState = const TableSortState(key: 'id', ascending: false);
  var _activeTarget = _FontSettingsTarget.web;
  var _expandedSection = _FontSizeSection.layoutSpecial;
  var _expandedMobileSection = _MobileFontSizeSection.featured;
  var _expandedWeightSection = _FontSizeSection.layoutSpecial;
  var _expandedMobileWeightSection = _MobileFontSizeSection.featured;
  var _fonts = fallbackSiteFonts;
  String? _error;

  @override
  void initState() {
    super.initState();
    _sizeControllers = {
      for (final item in _FontSizeItem.all)
        item.key: TextEditingController(text: item.initialValue),
      for (final item in _MobileFontSizeItem.all)
        item.key: TextEditingController(text: item.initialValue),
    };
    _weightControllers = {
      for (final item in _FontSizeItem.all)
        item.key: TextEditingController(text: item.initialWeight),
      for (final item in _MobileFontSizeItem.all)
        item.key: TextEditingController(text: item.initialWeight),
    };
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    for (final controller in _sizeControllers.values) {
      controller.dispose();
    }
    for (final controller in _weightControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final controller = AdminLocalizationScope.of(context);
    final defaultLanguage =
        controller.availableLanguages
            .where((language) => language.isDefault)
            .map((language) => language.code)
            .firstOrNull ??
        controller.code;
    _language = defaultLanguage;
    unawaited(_loadSettings(defaultLanguage));
  }

  Future<void> _loadSettings(String languageCode) async {
    setState(() {
      _language = languageCode;
      _loading = true;
      _error = null;
    });
    try {
      final bundle = await widget.repository.fetchSettings(languageCode);
      if (!mounted) return;
      setState(() {
        _fonts = bundle.fonts;
        _applySettings(bundle.settings);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _fonts = fallbackSiteFonts;
        _applySettings(AdminFontSettingsData.empty(languageCode));
        _error = error.toString();
        _loading = false;
      });
    }
  }

  void _applySettings(AdminFontSettingsData settings) {
    _language = settings.languageCode;
    _primaryFont = settings.primaryFont;
    _secondaryFont = settings.titleFont;
    _contentFont = settings.contentFont;
    _mobilePrimaryFont = settings.mobilePrimaryFont;
    _mobileSecondaryFont = settings.mobileTitleFont;
    _mobileContentFont = settings.mobileContentFont;
    for (final item in _FontSizeItem.all) {
      final value =
          settings.fontSizes[item.key] ?? int.parse(item.initialValue);
      _sizeControllers[item.key]?.text = value.toString();
      final weight =
          settings.fontWeights[item.key] ?? int.parse(item.initialWeight);
      _weightControllers[item.key]?.text = weight.toString();
    }
    for (final item in _MobileFontSizeItem.all) {
      final value =
          settings.mobileFontSizes[item.key] ?? int.parse(item.initialValue);
      _sizeControllers[item.key]?.text = value.toString();
      final weight =
          settings.mobileFontWeights[item.key] ?? int.parse(item.initialWeight);
      _weightControllers[item.key]?.text = weight.toString();
    }
  }

  AdminFontSettingsData _currentSettings() {
    return AdminFontSettingsData(
      languageCode: _language,
      primaryFont: _primaryFont,
      titleFont: _secondaryFont,
      contentFont: _contentFont,
      mobilePrimaryFont: _mobilePrimaryFont,
      mobileTitleFont: _mobileSecondaryFont,
      mobileContentFont: _mobileContentFont,
      fontSizes: {
        for (final item in _FontSizeItem.all)
          item.key:
              int.tryParse(_sizeControllers[item.key]?.text.trim() ?? '') ??
              int.parse(item.initialValue),
      },
      mobileFontSizes: {
        for (final item in _MobileFontSizeItem.all)
          item.key:
              int.tryParse(_sizeControllers[item.key]?.text.trim() ?? '') ??
              int.parse(item.initialValue),
      },
      fontWeights: {
        for (final item in _FontSizeItem.all)
          item.key:
              int.tryParse(_weightControllers[item.key]?.text.trim() ?? '') ??
              int.parse(item.initialWeight),
      },
      mobileFontWeights: {
        for (final item in _MobileFontSizeItem.all)
          item.key:
              int.tryParse(_weightControllers[item.key]?.text.trim() ?? '') ??
              int.parse(item.initialWeight),
      },
    );
  }

  Future<void> _saveSettings() async {
    if (_saving || _loading) return;
    setState(() => _saving = true);
    try {
      final saved = await widget.repository.saveSettings(
        session: widget.session,
        settings: _currentSettings(),
      );
      if (!mounted) return;
      setState(() {
        _applySettings(saved);
        _saving = false;
      });
      _showMessage('fontSettings.saveSuccess');
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage('${context.t('settings.save_error')}: $error');
    }
  }

  Future<void> _openAddFontDialog() async {
    if (_adding || _loading) return;
    final data = await showDialog<AdminFontFormData>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.34),
      builder: (context) => const _FontDialogFrame(child: _AddFontDialog()),
    );
    if (data == null) return;
    setState(() => _adding = true);
    try {
      await widget.repository.addFont(session: widget.session, data: data);
      if (!mounted) return;
      await _loadSettings(_language);
      if (!mounted) return;
      setState(() => _adding = false);
      _showMessage('fontSettings.addSuccess');
    } catch (error) {
      if (!mounted) return;
      setState(() => _adding = false);
      _showMessage('${context.t('fontSettings.addError')}: $error');
    }
  }

  Future<void> _openEditFontDialog(AdminFontRow font) async {
    if (_editing || _loading) return;
    final data = await showDialog<AdminFontFormData>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.34),
      builder: (context) =>
          _FontDialogFrame(child: _EditFontDialog(font: font)),
    );
    if (data == null) return;
    setState(() => _editing = true);
    try {
      await widget.repository.updateFont(
        session: widget.session,
        font: font,
        data: data,
      );
      if (!mounted) return;
      await _loadSettings(_language);
      if (!mounted) return;
      setState(() => _editing = false);
      _showMessage('fontSettings.editSuccess');
    } catch (error) {
      if (!mounted) return;
      setState(() => _editing = false);
      _showMessage('${context.t('fontSettings.editError')}: $error');
    }
  }

  void _showMessage(String message) {
    AdminToast.show(
      context,
      message: context.t(message),
      tone: message.contains('Error') || message.contains('error')
          ? AdminToastTone.error
          : AdminToastTone.success,
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

  List<AdminFontRow> get _filteredFonts {
    final query = _searchQuery.trim().toLowerCase();
    final filtered = query.isEmpty
        ? List<AdminFontRow>.of(_fonts)
        : _fonts.where((font) {
            return font.name.toLowerCase().contains(query) ||
                font.family.toLowerCase().contains(query) ||
                font.labelSourceKey.toLowerCase().contains(query);
          }).toList();

    filtered.sort((a, b) {
      final result = switch (_sortState.key) {
        'name' => a.name.compareTo(b.name),
        'source' => a.labelSourceKey.compareTo(b.labelSourceKey),
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
        final contentWidth = constraints.maxWidth - (horizontalPadding * 2);
        final stacked = contentWidth < 980;
        final leftColumnWidth = contentWidth < 1280 ? 360.0 : 400.0;
        final columnGap = contentWidth < 1280 ? 22.0 : 28.0;
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
        final languageController = AdminLocalizationScope.of(context);
        final fontOptions = _fontOptionsFor(_fonts, [
          _primaryFont,
          _secondaryFont,
          _contentFont,
          _mobilePrimaryFont,
          _mobileSecondaryFont,
          _mobileContentFont,
        ]);
        final canEdit = !_loading && !_saving && !_adding && !_editing;

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
              if (_error != null) ...[
                _FontInlineStatus(
                  message: _error!,
                  isError: true,
                  onRetry: () => unawaited(_loadSettings(_language)),
                ),
                const SizedBox(height: 14),
              ],
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
                              mobilePrimaryFont: _mobilePrimaryFont,
                              mobileSecondaryFont: _mobileSecondaryFont,
                              mobileContentFont: _mobileContentFont,
                              languages: languageController.availableLanguages,
                              fontOptions: fontOptions,
                              enabled: canEdit,
                              saving: _saving,
                              activeTarget: _activeTarget,
                              expandedSection: _expandedSection,
                              expandedMobileSection: _expandedMobileSection,
                              expandedWeightSection: _expandedWeightSection,
                              expandedMobileWeightSection:
                                  _expandedMobileWeightSection,
                              sizeControllers: _sizeControllers,
                              weightControllers: _weightControllers,
                              onTargetChanged: (target) =>
                                  setState(() => _activeTarget = target),
                              onLanguageChanged: (value) {
                                if (value == null) return;
                                unawaited(_loadSettings(value));
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
                              onMobilePrimaryFontChanged: (value) {
                                if (value == null) return;
                                setState(() => _mobilePrimaryFont = value);
                              },
                              onMobileSecondaryFontChanged: (value) {
                                if (value == null) return;
                                setState(() => _mobileSecondaryFont = value);
                              },
                              onMobileContentFontChanged: (value) {
                                if (value == null) return;
                                setState(() => _mobileContentFont = value);
                              },
                              onSectionChanged: (section) =>
                                  setState(() => _expandedSection = section),
                              onMobileSectionChanged: (section) => setState(
                                () => _expandedMobileSection = section,
                              ),
                              onWeightSectionChanged: (section) => setState(
                                () => _expandedWeightSection = section,
                              ),
                              onMobileWeightSectionChanged: (section) =>
                                  setState(
                                    () =>
                                        _expandedMobileWeightSection = section,
                                  ),
                              onSave: () => unawaited(_saveSettings()),
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
                                onEditFont: (font) =>
                                    unawaited(_openEditFontDialog(font)),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: leftColumnWidth,
                            child: SingleChildScrollView(
                              child: _LeftFontSettingsColumn(
                                language: _language,
                                primaryFont: _primaryFont,
                                secondaryFont: _secondaryFont,
                                contentFont: _contentFont,
                                mobilePrimaryFont: _mobilePrimaryFont,
                                mobileSecondaryFont: _mobileSecondaryFont,
                                mobileContentFont: _mobileContentFont,
                                languages:
                                    languageController.availableLanguages,
                                fontOptions: fontOptions,
                                enabled: canEdit,
                                saving: _saving,
                                activeTarget: _activeTarget,
                                expandedSection: _expandedSection,
                                expandedMobileSection: _expandedMobileSection,
                                expandedWeightSection: _expandedWeightSection,
                                expandedMobileWeightSection:
                                    _expandedMobileWeightSection,
                                sizeControllers: _sizeControllers,
                                weightControllers: _weightControllers,
                                onTargetChanged: (target) =>
                                    setState(() => _activeTarget = target),
                                onLanguageChanged: (value) {
                                  if (value == null) return;
                                  unawaited(_loadSettings(value));
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
                                onMobilePrimaryFontChanged: (value) {
                                  if (value == null) return;
                                  setState(() => _mobilePrimaryFont = value);
                                },
                                onMobileSecondaryFontChanged: (value) {
                                  if (value == null) return;
                                  setState(() => _mobileSecondaryFont = value);
                                },
                                onMobileContentFontChanged: (value) {
                                  if (value == null) return;
                                  setState(() => _mobileContentFont = value);
                                },
                                onSectionChanged: (section) =>
                                    setState(() => _expandedSection = section),
                                onMobileSectionChanged: (section) => setState(
                                  () => _expandedMobileSection = section,
                                ),
                                onWeightSectionChanged: (section) => setState(
                                  () => _expandedWeightSection = section,
                                ),
                                onMobileWeightSectionChanged: (section) =>
                                    setState(
                                      () => _expandedMobileWeightSection =
                                          section,
                                    ),
                                onSave: () => unawaited(_saveSettings()),
                              ),
                            ),
                          ),
                          SizedBox(width: columnGap),
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
                              onEditFont: (font) =>
                                  unawaited(_openEditFontDialog(font)),
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
    required this.mobilePrimaryFont,
    required this.mobileSecondaryFont,
    required this.mobileContentFont,
    required this.languages,
    required this.fontOptions,
    required this.enabled,
    required this.saving,
    required this.activeTarget,
    required this.expandedSection,
    required this.expandedMobileSection,
    required this.expandedWeightSection,
    required this.expandedMobileWeightSection,
    required this.sizeControllers,
    required this.weightControllers,
    required this.onTargetChanged,
    required this.onLanguageChanged,
    required this.onPrimaryFontChanged,
    required this.onSecondaryFontChanged,
    required this.onContentFontChanged,
    required this.onMobilePrimaryFontChanged,
    required this.onMobileSecondaryFontChanged,
    required this.onMobileContentFontChanged,
    required this.onSectionChanged,
    required this.onMobileSectionChanged,
    required this.onWeightSectionChanged,
    required this.onMobileWeightSectionChanged,
    required this.onSave,
  });

  final String language;
  final String primaryFont;
  final String secondaryFont;
  final String contentFont;
  final String mobilePrimaryFont;
  final String mobileSecondaryFont;
  final String mobileContentFont;
  final List<AdminLanguage> languages;
  final List<_SelectOption> fontOptions;
  final bool enabled;
  final bool saving;
  final _FontSettingsTarget activeTarget;
  final _FontSizeSection expandedSection;
  final _MobileFontSizeSection expandedMobileSection;
  final _FontSizeSection expandedWeightSection;
  final _MobileFontSizeSection expandedMobileWeightSection;
  final Map<String, TextEditingController> sizeControllers;
  final Map<String, TextEditingController> weightControllers;
  final ValueChanged<_FontSettingsTarget> onTargetChanged;
  final ValueChanged<String?> onLanguageChanged;
  final ValueChanged<String?> onPrimaryFontChanged;
  final ValueChanged<String?> onSecondaryFontChanged;
  final ValueChanged<String?> onContentFontChanged;
  final ValueChanged<String?> onMobilePrimaryFontChanged;
  final ValueChanged<String?> onMobileSecondaryFontChanged;
  final ValueChanged<String?> onMobileContentFontChanged;
  final ValueChanged<_FontSizeSection> onSectionChanged;
  final ValueChanged<_MobileFontSizeSection> onMobileSectionChanged;
  final ValueChanged<_FontSizeSection> onWeightSectionChanged;
  final ValueChanged<_MobileFontSizeSection> onMobileWeightSectionChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FontTargetSwitch(
          value: activeTarget,
          enabled: enabled,
          onChanged: onTargetChanged,
        ),
        const SizedBox(height: 18),
        _SettingsCard(
          title: 'fontSettings.siteFont.title',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SelectField(
                label: 'fontSettings.siteFont.language',
                value: language,
                options: _languageOptionsFor(languages, language),
                onChanged: onLanguageChanged,
                enabled: enabled,
              ),
              const SizedBox(height: 18),
              if (activeTarget == _FontSettingsTarget.web) ...[
                _SelectField(
                  label: 'fontSettings.siteFont.webPrimary',
                  value: primaryFont,
                  options: fontOptions,
                  onChanged: onPrimaryFontChanged,
                  requiredField: true,
                  enabled: enabled,
                ),
                const SizedBox(height: 18),
                _SelectField(
                  label: 'fontSettings.siteFont.webTitle',
                  value: secondaryFont,
                  options: fontOptions,
                  onChanged: onSecondaryFontChanged,
                  requiredField: true,
                  enabled: enabled,
                ),
                const SizedBox(height: 18),
                _SelectField(
                  label: 'fontSettings.siteFont.webContent',
                  value: contentFont,
                  options: fontOptions,
                  onChanged: onContentFontChanged,
                  requiredField: true,
                  enabled: enabled,
                ),
              ] else ...[
                _SelectField(
                  label: 'fontSettings.siteFont.mobilePrimary',
                  value: mobilePrimaryFont,
                  options: fontOptions,
                  onChanged: onMobilePrimaryFontChanged,
                  requiredField: true,
                  enabled: enabled,
                ),
                const SizedBox(height: 18),
                _SelectField(
                  label: 'fontSettings.siteFont.mobileTitle',
                  value: mobileSecondaryFont,
                  options: fontOptions,
                  onChanged: onMobileSecondaryFontChanged,
                  requiredField: true,
                  enabled: enabled,
                ),
                const SizedBox(height: 18),
                _SelectField(
                  label: 'fontSettings.siteFont.mobileContent',
                  value: mobileContentFont,
                  options: fontOptions,
                  onChanged: onMobileContentFontChanged,
                  requiredField: true,
                  enabled: enabled,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        _SettingsCard(
          title: 'fontSettings.fontSize.title',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (activeTarget == _FontSettingsTarget.web)
                for (final section in _FontSizeSection.values)
                  _FontSizePanel(
                    section: section,
                    expanded: expandedSection == section,
                    controllers: sizeControllers,
                    enabled: enabled,
                    onToggle: () => onSectionChanged(section),
                  )
              else
                for (final section in _MobileFontSizeSection.values)
                  _MobileFontSizePanel(
                    section: section,
                    expanded: expandedMobileSection == section,
                    controllers: sizeControllers,
                    enabled: enabled,
                    onToggle: () => onMobileSectionChanged(section),
                  ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _SettingsCard(
          title: 'fontSettings.fontWeight.title',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (activeTarget == _FontSettingsTarget.web)
                for (final section in _FontSizeSection.values)
                  _FontWeightPanel(
                    section: section,
                    expanded: expandedWeightSection == section,
                    controllers: weightControllers,
                    enabled: enabled,
                    onToggle: () => onWeightSectionChanged(section),
                  )
              else
                for (final section in _MobileFontSizeSection.values)
                  _MobileFontWeightPanel(
                    section: section,
                    expanded: expandedMobileWeightSection == section,
                    controllers: weightControllers,
                    enabled: enabled,
                    onToggle: () => onMobileWeightSectionChanged(section),
                  ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerRight,
          child: _SaveButton(onPressed: enabled ? onSave : null, busy: saving),
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

class _FontInlineStatus extends StatelessWidget {
  const _FontInlineStatus({
    required this.message,
    required this.isError,
    required this.onRetry,
  });

  final String message;
  final bool isError;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isError
            ? AppColors.actionRed.withValues(alpha: 0.08)
            : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(
          color: isError
              ? AppColors.actionRed.withValues(alpha: 0.22)
              : AppColors.line,
        ),
      ),
      child: Row(
        children: [
          SymbolIcon(
            isError ? Symbols.warning : Symbols.check,
            color: isError ? AppColors.actionRed : const Color(0xFF16A34A),
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.deepOcean,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
          ),
          if (isError) ...[
            const SizedBox(width: 12),
            TextButton(
              onPressed: onRetry,
              style:
                  TextButton.styleFrom(
                    foregroundColor: AppColors.deepOcean,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ).copyWith(
                    mouseCursor: const WidgetStatePropertyAll(
                      SystemMouseCursors.click,
                    ),
                  ),
              child: Text(context.t('Retry')),
            ),
          ],
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
    this.enabled = true,
  });

  final String label;
  final String value;
  final List<_SelectOption> options;
  final ValueChanged<String?> onChanged;
  final bool requiredField;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FieldLabel(label: label, requiredField: requiredField),
        const SizedBox(height: 8),
        _SelectBox(
          value: value,
          options: options,
          enabled: enabled,
          onChanged: onChanged,
        ),
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
    required this.enabled,
    required this.onChanged,
  });

  final String value;
  final List<_SelectOption> options;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
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
            mouseCursor: enabled
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
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
            onChanged: enabled ? onChanged : null,
          ),
        ),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.onPressed, required this.busy});

  final VoidCallback? onPressed;
  final bool busy;

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
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                return AppColors.actionRed.withValues(
                  alpha: states.contains(WidgetState.disabled) ? 0.72 : 1,
                );
              }),
              foregroundColor: const WidgetStatePropertyAll(Colors.white),
              mouseCursor: const WidgetStatePropertyAll(
                SystemMouseCursors.click,
              ),
            ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            busy
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const SymbolIcon(
                    Symbols.check,
                    color: Colors.white,
                    size: 16,
                  ),
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

enum _FontSettingsTarget {
  web('fontSettings.target.web'),
  mobile('fontSettings.target.mobile');

  const _FontSettingsTarget(this.labelKey);

  final String labelKey;
}

class _FontTargetSwitch extends StatelessWidget {
  const _FontTargetSwitch({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final _FontSettingsTarget value;
  final bool enabled;
  final ValueChanged<_FontSettingsTarget> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          for (final target in _FontSettingsTarget.values)
            Expanded(
              child: _FontTargetButton(
                target: target,
                selected: value == target,
                enabled: enabled,
                onTap: () => onChanged(target),
              ),
            ),
        ],
      ),
    );
  }
}

class _FontTargetButton extends StatelessWidget {
  const _FontTargetButton({
    required this.target,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final _FontSettingsTarget target;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : AppColors.deepOcean;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.deepOcean : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.value - 1),
          ),
          child: Text(
            context.t(target.labelKey),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
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
    required this.enabled,
    required this.onToggle,
  });

  final _FontSizeSection section;
  final bool expanded;
  final Map<String, TextEditingController> controllers;
  final bool enabled;
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
              cursor: enabled
                  ? SystemMouseCursors.click
                  : SystemMouseCursors.basic,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: enabled ? onToggle : null,
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
                        enabled: enabled,
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

class _MobileFontSizePanel extends StatelessWidget {
  const _MobileFontSizePanel({
    required this.section,
    required this.expanded,
    required this.controllers,
    required this.enabled,
    required this.onToggle,
  });

  final _MobileFontSizeSection section;
  final bool expanded;
  final Map<String, TextEditingController> controllers;
  final bool enabled;
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
              cursor: enabled
                  ? SystemMouseCursors.click
                  : SystemMouseCursors.basic,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: enabled ? onToggle : null,
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
                                  color:
                                      section == _MobileFontSizeSection.featured
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
                      _MobileFontSizeRow(
                        item: item,
                        controller: controllers[item.key]!,
                        enabled: enabled,
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

class _FontWeightPanel extends StatelessWidget {
  const _FontWeightPanel({
    required this.section,
    required this.expanded,
    required this.controllers,
    required this.enabled,
    required this.onToggle,
  });

  final _FontSizeSection section;
  final bool expanded;
  final Map<String, TextEditingController> controllers;
  final bool enabled;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return _FontAccordionPanel(
      labelKey: section.labelKey,
      highlighted: section == _FontSizeSection.titles,
      expanded: expanded,
      enabled: enabled,
      onToggle: onToggle,
      child: Column(
        children: [
          for (final item in section.items)
            _FontWeightRow(
              item: item,
              controller: controllers[item.key]!,
              enabled: enabled,
            ),
        ],
      ),
    );
  }
}

class _MobileFontWeightPanel extends StatelessWidget {
  const _MobileFontWeightPanel({
    required this.section,
    required this.expanded,
    required this.controllers,
    required this.enabled,
    required this.onToggle,
  });

  final _MobileFontSizeSection section;
  final bool expanded;
  final Map<String, TextEditingController> controllers;
  final bool enabled;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return _FontAccordionPanel(
      labelKey: section.labelKey,
      highlighted: section == _MobileFontSizeSection.featured,
      expanded: expanded,
      enabled: enabled,
      onToggle: onToggle,
      child: Column(
        children: [
          for (final item in section.items)
            _MobileFontWeightRow(
              item: item,
              controller: controllers[item.key]!,
              enabled: enabled,
            ),
        ],
      ),
    );
  }
}

class _FontAccordionPanel extends StatelessWidget {
  const _FontAccordionPanel({
    required this.labelKey,
    required this.highlighted,
    required this.expanded,
    required this.enabled,
    required this.onToggle,
    required this.child,
  });

  final String labelKey;
  final bool highlighted;
  final bool expanded;
  final bool enabled;
  final VoidCallback onToggle;
  final Widget child;

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
              cursor: enabled
                  ? SystemMouseCursors.click
                  : SystemMouseCursors.basic,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: enabled ? onToggle : null,
                child: SizedBox(
                  height: 54,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.t(labelKey),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: highlighted
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
                child: child,
              ),
          ],
        ),
      ),
    );
  }
}

class _FontSizeRow extends StatelessWidget {
  const _FontSizeRow({
    required this.item,
    required this.controller,
    required this.enabled,
  });

  final _FontSizeItem item;
  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: _FontSizeLabel(item: item)),
          const SizedBox(width: 10),
          SizedBox(
            width: 96,
            child: _UnitTextField(
              controller: controller,
              enabled: enabled,
              unitKey: 'fontSettings.unitPx',
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileFontSizeRow extends StatelessWidget {
  const _MobileFontSizeRow({
    required this.item,
    required this.controller,
    required this.enabled,
  });

  final _MobileFontSizeItem item;
  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: _MobileFontSizeLabel(item: item)),
          const SizedBox(width: 10),
          SizedBox(
            width: 96,
            child: _UnitTextField(
              controller: controller,
              enabled: enabled,
              unitKey: 'fontSettings.unitPx',
            ),
          ),
        ],
      ),
    );
  }
}

class _FontWeightRow extends StatelessWidget {
  const _FontWeightRow({
    required this.item,
    required this.controller,
    required this.enabled,
  });

  final _FontSizeItem item;
  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: _FontSizeLabel(item: item)),
          const SizedBox(width: 10),
          SizedBox(
            width: 104,
            child: _UnitTextField(
              controller: controller,
              enabled: enabled,
              unitKey: 'fontSettings.unitWeight',
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileFontWeightRow extends StatelessWidget {
  const _MobileFontWeightRow({
    required this.item,
    required this.controller,
    required this.enabled,
  });

  final _MobileFontSizeItem item;
  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: _MobileFontSizeLabel(item: item)),
          const SizedBox(width: 10),
          SizedBox(
            width: 104,
            child: _UnitTextField(
              controller: controller,
              enabled: enabled,
              unitKey: 'fontSettings.unitWeight',
            ),
          ),
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
    final titleStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: AppColors.deepOcean,
      fontWeight: FontWeight.w800,
      letterSpacing: 0,
    );
    final descriptionStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: AppColors.inkSoft,
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.t(item.labelKey),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: titleStyle,
        ),
        const SizedBox(height: 3),
        Text(
          context.t(item.descriptionKey),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: descriptionStyle,
        ),
      ],
    );
  }
}

class _MobileFontSizeLabel extends StatelessWidget {
  const _MobileFontSizeLabel({required this.item});

  final _MobileFontSizeItem item;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.t(item.labelKey),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.deepOcean,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          context.t(item.descriptionKey),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.inkSoft,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _UnitTextField extends StatelessWidget {
  const _UnitTextField({
    required this.controller,
    required this.enabled,
    required this.unitKey,
  });

  final TextEditingController controller;
  final bool enabled;
  final String unitKey;

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
              enabled: enabled,
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
              context.t(unitKey),
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
    required this.onEditFont,
  });

  final TextEditingController searchController;
  final int pageSize;
  final int page;
  final int totalCount;
  final String searchQuery;
  final TableSortState sortState;
  final List<AdminFontRow> fonts;
  final ValueChanged<int?> onPageSizeChanged;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<String> onSort;
  final VoidCallback onAddFont;
  final ValueChanged<AdminFontRow> onEditFont;

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
            onEdit: onEditFont,
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
    required this.onEdit,
  });

  final List<AdminFontRow> fonts;
  final TableSortState sortState;
  final ValueChanged<String> onSort;
  final ValueChanged<AdminFontRow> onEdit;

  static const double _minWidth = 620;
  static const double _tableBorderWidth = 2;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth = constraints.maxWidth < _minWidth
            ? _minWidth
            : constraints.maxWidth;
        final layout = _FontsTableColumnLayout.forWidth(tableWidth);

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
                    layout: layout,
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
                                    layout: layout,
                                    onEdit: () => onEdit(font),
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

class _FontsTableColumnLayout {
  const _FontsTableColumnLayout({
    required this.idWidth,
    required this.nameWidth,
    required this.sourceWidth,
    required this.optionsWidth,
    required this.horizontalInset,
  });

  final double idWidth;
  final double nameWidth;
  final double sourceWidth;
  final double optionsWidth;
  final double horizontalInset;

  factory _FontsTableColumnLayout.forWidth(double tableWidth) {
    final compact = tableWidth < 900;
    final idWidth = compact ? 68.0 : 92.0;
    final sourceWidth = compact ? 150.0 : 220.0;
    final optionsWidth = compact ? 88.0 : 124.0;
    final horizontalInset = compact ? 12.0 : 16.0;
    final nameWidth =
        tableWidth -
        (horizontalInset * 2) -
        _FontsTable._tableBorderWidth -
        idWidth -
        sourceWidth -
        optionsWidth;

    return _FontsTableColumnLayout(
      idWidth: idWidth,
      nameWidth: nameWidth,
      sourceWidth: sourceWidth,
      optionsWidth: optionsWidth,
      horizontalInset: horizontalInset,
    );
  }
}

class _FontsHeader extends StatelessWidget {
  const _FontsHeader({
    required this.layout,
    required this.sortState,
    required this.onSort,
  });

  final _FontsTableColumnLayout layout;
  final TableSortState sortState;
  final ValueChanged<String> onSort;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: EdgeInsets.symmetric(horizontal: layout.horizontalInset),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.softLine.withValues(alpha: 0.86)),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: layout.idWidth,
            child: SortableTableHeader(
              label: 'ID',
              sortKey: 'id',
              sortState: sortState,
              onSort: onSort,
            ),
          ),
          SizedBox(
            width: layout.nameWidth,
            child: SortableTableHeader(
              label: 'fontSettings.table.name',
              sortKey: 'name',
              sortState: sortState,
              onSort: onSort,
            ),
          ),
          SizedBox(
            width: layout.sourceWidth,
            child: SortableTableHeader(
              label: 'fontSettings.table.source',
              sortKey: 'source',
              sortState: sortState,
              onSort: onSort,
            ),
          ),
          SizedBox(
            width: layout.optionsWidth,
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
    required this.layout,
    required this.onEdit,
  });

  final AdminFontRow font;
  final _FontsTableColumnLayout layout;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: EdgeInsets.symmetric(horizontal: layout.horizontalInset),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.softLine.withValues(alpha: 0.86)),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: layout.idWidth,
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
            width: layout.nameWidth,
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
            width: layout.sourceWidth,
            child: Text(
              context.t(font.labelSourceKey),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.inkSoft,
                fontWeight: FontWeight.w500,
                letterSpacing: 0,
              ),
            ),
          ),
          SizedBox(
            width: layout.optionsWidth,
            child: Align(
              alignment: Alignment.center,
              child: _FontEditAction(onEdit: onEdit),
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

class _FontEditAction extends StatelessWidget {
  const _FontEditAction({required this.onEdit});

  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return _FontRowMenu(onEdit: onEdit);
  }
}

class _FontRowMenu extends StatefulWidget {
  const _FontRowMenu({required this.onEdit});

  final VoidCallback onEdit;

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
              child: _FontMenuCard(onEdit: () => _runAndClose(widget.onEdit)),
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
    return AdminTablePagination(
      page: page,
      pageCount: lastPage,
      onPageChanged: onPageChanged,
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
  final _files = <int, XFile>{};
  var _fontType = 'sans_serif';
  var _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _selectFile(int weight) async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Fonts', extensions: ['ttf', 'otf', 'woff', 'woff2']),
      ],
    );
    if (file == null) return;
    setState(() => _files[weight] = file);
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final name = _nameController.text.trim();
    if (name.isEmpty || !_files.containsKey(400)) {
      AdminToast.show(
        context,
        message: context.t('fontSettings.dialog.required'),
        tone: AdminToastTone.error,
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final files = <int, AdminFontUploadFile>{};
      for (final entry in _files.entries) {
        files[entry.key] = AdminFontUploadFile(
          fileName: entry.value.name,
          bytes: await entry.value.readAsBytes(),
        );
      }
      if (!mounted) return;
      Navigator.of(
        context,
      ).pop(AdminFontFormData(name: name, type: _fontType, files: files));
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      AdminToast.show(
        context,
        message: '${context.t('fontSettings.addError')}: $error',
        tone: AdminToastTone.error,
      );
    }
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
                _FontUploadBox(
                  title: 'fontSettings.dialog.weight400',
                  requiredField: true,
                  fileName: _files[400]?.name,
                  onSelect: () => unawaited(_selectFile(400)),
                ),
                _FontUploadBox(
                  title: 'fontSettings.dialog.weight600',
                  fileName: _files[600]?.name,
                  onSelect: () => unawaited(_selectFile(600)),
                ),
                _FontUploadBox(
                  title: 'fontSettings.dialog.weight700',
                  fileName: _files[700]?.name,
                  onSelect: () => unawaited(_selectFile(700)),
                ),
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
              busy: _submitting,
              onPrimaryPressed: () => unawaited(_submit()),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditFontDialog extends StatefulWidget {
  const _EditFontDialog({required this.font});

  final AdminFontRow font;

  @override
  State<_EditFontDialog> createState() => _EditFontDialogState();
}

class _EditFontDialogState extends State<_EditFontDialog> {
  late final TextEditingController _nameController;
  final _files = <int, XFile>{};
  late var _fontType = _dialogFontType(widget.font.type);
  var _submitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.font.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _selectFile(int weight) async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Fonts', extensions: ['ttf', 'otf', 'woff', 'woff2']),
      ],
    );
    if (file == null) return;
    setState(() => _files[weight] = file);
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      AdminToast.show(
        context,
        message: context.t('fontSettings.dialog.editRequired'),
        tone: AdminToastTone.error,
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final files = <int, AdminFontUploadFile>{};
      for (final entry in _files.entries) {
        files[entry.key] = AdminFontUploadFile(
          fileName: entry.value.name,
          bytes: await entry.value.readAsBytes(),
        );
      }
      if (!mounted) return;
      Navigator.of(
        context,
      ).pop(AdminFontFormData(name: name, type: _fontType, files: files));
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      AdminToast.show(
        context,
        message: '${context.t('fontSettings.editError')}: $error',
        tone: AdminToastTone.error,
      );
    }
  }

  String? _fileNameForWeight(int weight) {
    return _files[weight]?.name ??
        _fontFileDisplayName(
          widget.font.fontFiles[weight.toString()] ??
              (weight == 400 ? widget.font.webFontPath : null),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 26, 28, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DialogHeader(title: context.t('fontSettings.dialog.editTitle')),
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
          if (widget.font.isLocal) ...[
            const SizedBox(height: 22),
            _DialogSectionLabel(context.t('fontSettings.dialog.fontFile')),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 540;
                final boxes = [
                  _FontUploadBox(
                    title: 'fontSettings.dialog.weight400',
                    fileName: _fileNameForWeight(400),
                    onSelect: () => unawaited(_selectFile(400)),
                  ),
                  _FontUploadBox(
                    title: 'fontSettings.dialog.weight600',
                    fileName: _fileNameForWeight(600),
                    onSelect: () => unawaited(_selectFile(600)),
                  ),
                  _FontUploadBox(
                    title: 'fontSettings.dialog.weight700',
                    fileName: _fileNameForWeight(700),
                    onSelect: () => unawaited(_selectFile(700)),
                  ),
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
          ],
          const SizedBox(height: 34),
          Align(
            alignment: Alignment.centerRight,
            child: _DialogFooter(
              primaryLabel: context.t('fontSettings.dialog.updateAction'),
              busy: _submitting,
              onPrimaryPressed: () => unawaited(_submit()),
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
  const _FontUploadBox({
    required this.title,
    required this.onSelect,
    this.fileName,
    this.requiredField = false,
  });

  final String title;
  final VoidCallback onSelect;
  final String? fileName;
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
                onPressed: onSelect,
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
                    Flexible(
                      child: Text(
                        fileName ?? context.t('fontSettings.dialog.selectFile'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
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
    required this.busy,
    required this.onPrimaryPressed,
  });

  final String primaryLabel;
  final bool busy;
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
            onPressed: busy ? null : onPrimaryPressed,
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
            child: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(primaryLabel),
          ),
        ),
      ],
    );
  }
}

enum _FontSizeSection {
  layoutSpecial('fontSettings.webSection.navigationFeatured'),
  general('fontSettings.webSection.newsCard'),
  category('fontSettings.webSection.categoryCards'),
  titles('fontSettings.webSection.detail');

  const _FontSizeSection(this.labelKey);

  final String labelKey;

  List<_FontSizeItem> get items {
    return switch (this) {
      _FontSizeSection.layoutSpecial => _FontSizeItem.layoutSpecial,
      _FontSizeSection.general => _FontSizeItem.general,
      _FontSizeSection.category => _FontSizeItem.category,
      _FontSizeSection.titles => _FontSizeItem.titles,
    };
  }
}

class _FontSizeItem {
  const _FontSizeItem({
    required this.key,
    required this.labelKey,
    required this.descriptionKey,
    required this.initialValue,
    required this.initialWeight,
  });

  final String key;
  final String labelKey;
  final String descriptionKey;
  final String initialValue;
  final String initialWeight;

  static const layoutSpecial = [
    _FontSizeItem(
      key: 'web-nav-label',
      labelKey: 'fontSettings.webSize.navLabel',
      descriptionKey: 'fontSettings.webSize.navLabelHelp',
      initialValue: '14',
      initialWeight: '700',
    ),
    _FontSizeItem(
      key: 'web-featured-title',
      labelKey: 'fontSettings.webSize.featuredTitle',
      descriptionKey: 'fontSettings.webSize.featuredTitleHelp',
      initialValue: '36',
      initialWeight: '800',
    ),
    _FontSizeItem(
      key: 'web-featured-summary',
      labelKey: 'fontSettings.webSize.featuredSummary',
      descriptionKey: 'fontSettings.webSize.featuredSummaryHelp',
      initialValue: '16',
      initialWeight: '500',
    ),
  ];

  static const general = [
    _FontSizeItem(
      key: 'web-card-title',
      labelKey: 'fontSettings.webSize.cardTitle',
      descriptionKey: 'fontSettings.webSize.cardTitleHelp',
      initialValue: '38',
      initialWeight: '800',
    ),
    _FontSizeItem(
      key: 'web-card-summary',
      labelKey: 'fontSettings.webSize.cardSummary',
      descriptionKey: 'fontSettings.webSize.cardSummaryHelp',
      initialValue: '16',
      initialWeight: '500',
    ),
  ];

  static const category = [
    _FontSizeItem(
      key: 'web-category-slider-title',
      labelKey: 'fontSettings.webSize.categorySliderTitle',
      descriptionKey: 'fontSettings.webSize.categorySliderTitleHelp',
      initialValue: '22',
      initialWeight: '700',
    ),
    _FontSizeItem(
      key: 'web-category-slider-summary',
      labelKey: 'fontSettings.webSize.categorySliderSummary',
      descriptionKey: 'fontSettings.webSize.categorySliderSummaryHelp',
      initialValue: '14',
      initialWeight: '400',
    ),
    _FontSizeItem(
      key: 'web-category-card-title',
      labelKey: 'fontSettings.webSize.categoryCardTitle',
      descriptionKey: 'fontSettings.webSize.categoryCardTitleHelp',
      initialValue: '19',
      initialWeight: '700',
    ),
    _FontSizeItem(
      key: 'web-category-card-summary',
      labelKey: 'fontSettings.webSize.categoryCardSummary',
      descriptionKey: 'fontSettings.webSize.categoryCardSummaryHelp',
      initialValue: '13',
      initialWeight: '400',
    ),
  ];

  static const titles = [
    _FontSizeItem(
      key: 'web-detail-title',
      labelKey: 'fontSettings.webSize.detailTitle',
      descriptionKey: 'fontSettings.webSize.detailTitleHelp',
      initialValue: '48',
      initialWeight: '800',
    ),
    _FontSizeItem(
      key: 'web-detail-summary',
      labelKey: 'fontSettings.webSize.detailSummary',
      descriptionKey: 'fontSettings.webSize.detailSummaryHelp',
      initialValue: '18',
      initialWeight: '500',
    ),
    _FontSizeItem(
      key: 'web-detail-body',
      labelKey: 'fontSettings.webSize.detailBody',
      descriptionKey: 'fontSettings.webSize.detailBodyHelp',
      initialValue: '17',
      initialWeight: '400',
    ),
  ];

  static const all = [...layoutSpecial, ...general, ...category, ...titles];
}

enum _MobileFontSizeSection {
  navigation('fontSettings.mobileSection.navigation'),
  featured('fontSettings.mobileSection.featured'),
  newsCard('fontSettings.mobileSection.newsCard'),
  detail('fontSettings.mobileSection.detail');

  const _MobileFontSizeSection(this.labelKey);

  final String labelKey;

  List<_MobileFontSizeItem> get items {
    return switch (this) {
      _MobileFontSizeSection.navigation => _MobileFontSizeItem.navigation,
      _MobileFontSizeSection.featured => _MobileFontSizeItem.featured,
      _MobileFontSizeSection.newsCard => _MobileFontSizeItem.newsCard,
      _MobileFontSizeSection.detail => _MobileFontSizeItem.detail,
    };
  }
}

class _MobileFontSizeItem {
  const _MobileFontSizeItem({
    required this.key,
    required this.labelKey,
    required this.descriptionKey,
    required this.initialValue,
    required this.initialWeight,
  });

  final String key;
  final String labelKey;
  final String descriptionKey;
  final String initialValue;
  final String initialWeight;

  static const navigation = [
    _MobileFontSizeItem(
      key: 'mobile-nav-label',
      labelKey: 'fontSettings.mobileSize.navLabel',
      descriptionKey: 'fontSettings.mobileSize.navLabelHelp',
      initialValue: '14',
      initialWeight: '600',
    ),
  ];

  static const featured = [
    _MobileFontSizeItem(
      key: 'mobile-featured-title',
      labelKey: 'fontSettings.mobileSize.featuredTitle',
      descriptionKey: 'fontSettings.mobileSize.featuredTitleHelp',
      initialValue: '28',
      initialWeight: '800',
    ),
    _MobileFontSizeItem(
      key: 'mobile-featured-summary',
      labelKey: 'fontSettings.mobileSize.featuredSummary',
      descriptionKey: 'fontSettings.mobileSize.featuredSummaryHelp',
      initialValue: '15',
      initialWeight: '400',
    ),
  ];

  static const newsCard = [
    _MobileFontSizeItem(
      key: 'mobile-card-title',
      labelKey: 'fontSettings.mobileSize.cardTitle',
      descriptionKey: 'fontSettings.mobileSize.cardTitleHelp',
      initialValue: '28',
      initialWeight: '800',
    ),
    _MobileFontSizeItem(
      key: 'mobile-card-summary',
      labelKey: 'fontSettings.mobileSize.cardSummary',
      descriptionKey: 'fontSettings.mobileSize.cardSummaryHelp',
      initialValue: '15',
      initialWeight: '400',
    ),
  ];

  static const detail = [
    _MobileFontSizeItem(
      key: 'mobile-detail-title',
      labelKey: 'fontSettings.mobileSize.detailTitle',
      descriptionKey: 'fontSettings.mobileSize.detailTitleHelp',
      initialValue: '32',
      initialWeight: '800',
    ),
    _MobileFontSizeItem(
      key: 'mobile-detail-summary',
      labelKey: 'fontSettings.mobileSize.detailSummary',
      descriptionKey: 'fontSettings.mobileSize.detailSummaryHelp',
      initialValue: '18',
      initialWeight: '500',
    ),
    _MobileFontSizeItem(
      key: 'mobile-detail-body',
      labelKey: 'fontSettings.mobileSize.detailBody',
      descriptionKey: 'fontSettings.mobileSize.detailBodyHelp',
      initialValue: '17',
      initialWeight: '400',
    ),
  ];

  static const all = [...navigation, ...featured, ...newsCard, ...detail];
}

class _SelectOption {
  const _SelectOption(this.value, [this.labelKey]);

  final String value;
  final String? labelKey;
}

List<_SelectOption> _languageOptionsFor(
  List<AdminLanguage> languages,
  String selected,
) {
  final options = [
    for (final language in languages)
      _SelectOption(language.code, _languageNameKey(language)),
  ];
  if (options.every((option) => option.value != selected)) {
    options.add(_SelectOption(selected));
  }
  return options;
}

String? _languageNameKey(AdminLanguage language) {
  return switch (language.code) {
    'tr' => 'language.name.tr',
    'en' => 'language.name.en',
    'ar' => 'language.name.ar',
    _ => null,
  };
}

List<_SelectOption> _fontOptionsFor(
  List<AdminFontRow> fonts,
  List<String> selected,
) {
  final options = [
    for (final font in fonts) _SelectOption(font.family, font.name),
  ];
  for (final family in selected) {
    if (options.every((option) => option.value != family)) {
      options.add(_SelectOption(family));
    }
  }
  return options;
}

String _dialogFontType(String value) {
  final normalized = value.trim();
  return _fontTypeOptions.any((option) => option.value == normalized)
      ? normalized
      : 'sans_serif';
}

String? _fontFileDisplayName(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return null;
  final uri = Uri.tryParse(text);
  final segments = uri?.pathSegments;
  if (segments != null && segments.isNotEmpty) {
    return Uri.decodeComponent(segments.last);
  }
  final slashIndex = text.lastIndexOf('/');
  return slashIndex >= 0 ? text.substring(slashIndex + 1) : text;
}

const _fontTypeOptions = [
  _SelectOption('sans_serif', 'fontSettings.dialog.type.sansSerif'),
  _SelectOption('serif', 'fontSettings.dialog.type.serif'),
  _SelectOption('monospace', 'fontSettings.dialog.type.monospace'),
  _SelectOption('cursive', 'fontSettings.dialog.type.cursive'),
  _SelectOption('fantasy', 'fontSettings.dialog.type.fantasy'),
  _SelectOption('system_ui', 'fontSettings.dialog.type.systemUi'),
];
