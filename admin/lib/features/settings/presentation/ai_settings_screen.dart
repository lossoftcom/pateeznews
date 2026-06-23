import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';
import 'package:pateeznews_admin/shared/widgets/admin_toast.dart';

import '../../../core/localization/admin_language_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/widgets/symbol_icon.dart';
import '../../auth/data/admin_auth_models.dart';
import '../data/admin_ai_settings_repository.dart';
import 'settings_mobile_chrome.dart';

class AiSettingsScreen extends StatefulWidget {
  const AiSettingsScreen({
    super.key,
    required this.session,
    this.repository = const SupabaseAdminAiSettingsRepository(),
  });

  final AdminSession session;
  final AdminAiSettingsRepository repository;

  @override
  State<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends State<AiSettingsScreen> {
  final _apiKeyController = TextEditingController();
  var _selectedTab = _AiSettingsTab.google;
  var _settingsLanguageCode = 'tr';
  var _settings = AdminAiSettingsData.empty('tr');
  var _models = <String>[];
  var _databasePrompts = <AdminAiPrompt>[];
  var _showFreeModelsOnly = false;
  var _loadingSettings = true;
  var _loadingPrompts = false;
  var _savingGoogle = false;
  var _testingApi = false;
  var _savingPrompt = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSettings());
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings({String? languageCode}) async {
    final targetCode = _cleanLanguageCode(
      languageCode ?? _settingsLanguageCode,
    );
    setState(() {
      _settingsLanguageCode = targetCode;
      _loadingSettings = true;
      _error = null;
      _models = _fallbackModelsFor(_settings.googleAiModel);
    });

    try {
      final settings = await widget.repository.fetchSettings(targetCode);
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _apiKeyController.text = settings.googleAiApiKey;
        _models = _fallbackModelsFor(settings.googleAiModel);
        _loadingSettings = false;
      });
      if (_selectedTab == _AiSettingsTab.formats) {
        await _loadPrompts(languageCode: targetCode);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _settings = AdminAiSettingsData.empty(targetCode);
        _apiKeyController.clear();
        _models = const [];
        _error = error.toString();
        _loadingSettings = false;
      });
    }
  }

  Future<void> _loadPrompts({String? languageCode}) async {
    final targetCode = _cleanLanguageCode(
      languageCode ?? _settingsLanguageCode,
    );
    setState(() => _loadingPrompts = true);
    try {
      final prompts = await widget.repository.fetchPrompts(targetCode);
      final nextPrompts = await _ensureDefaultNewsPrompt(
        languageCode: targetCode,
        prompts: prompts,
      );
      if (!mounted) return;
      setState(() {
        _databasePrompts = nextPrompts;
        _loadingPrompts = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadingPrompts = false);
      _showMessage('${context.t('AI prompts could not be loaded')}: $error');
    }
  }

  Future<List<AdminAiPrompt>> _ensureDefaultNewsPrompt({
    required String languageCode,
    required List<AdminAiPrompt> prompts,
  }) async {
    final defaults = prompts.isEmpty
        ? adminAiDefaultPromptDataList
        : const [
            adminQuizAiDefaultPromptData,
            adminPollAiDefaultPromptData,
            adminVideoAiDefaultPromptData,
            adminContentsAiDefaultPromptData,
            adminRecipeAiDefaultPromptData,
            adminEventAiDefaultPromptData,
            adminMediaSeoAiDefaultPromptData,
          ];
    final normalizedTitles = {
      for (final prompt in prompts) _normalizePromptTitle(prompt.title),
    };
    final savedDefaults = <AdminAiPrompt>[];
    for (final data in defaults) {
      final titleKey = _normalizePromptTitle(data.title);
      if (normalizedTitles.contains(titleKey)) continue;
      final saved = await widget.repository.savePrompt(
        session: widget.session,
        languageCode: languageCode,
        data: data,
      );
      savedDefaults.add(saved);
      normalizedTitles.add(titleKey);
    }
    return [...savedDefaults, ...prompts];
  }

  Future<void> _saveGoogleSettings() async {
    if (_savingGoogle || _loadingSettings) return;
    setState(() => _savingGoogle = true);
    try {
      final saved = await widget.repository.saveSettings(
        session: widget.session,
        settings: _settings.copyWith(
          languageCode: _settingsLanguageCode,
          googleAiApiKey: _apiKeyController.text,
        ),
      );
      if (!mounted) return;
      final nextModels = _models.isEmpty
          ? _fallbackModelsFor(saved.googleAiModel)
          : _models;
      setState(() {
        _settings = saved;
        _apiKeyController.text = saved.googleAiApiKey;
        _models = nextModels;
        _savingGoogle = false;
      });
      _showMessage('AI settings saved successfully');
    } catch (error) {
      if (!mounted) return;
      setState(() => _savingGoogle = false);
      _showMessage('${context.t('Error saving AI Settings')}: $error');
    }
  }

  Future<void> _testApiConnection() async {
    if (_testingApi || _apiKeyController.text.trim().isEmpty) {
      _showMessage('API Connection Error: Please check your key.');
      return;
    }
    setState(() => _testingApi = true);
    try {
      final models = await widget.repository.fetchGeminiModels(
        _apiKeyController.text,
      );
      if (!mounted) return;
      final selectableModels = _selectableModelsFor(
        selectedModel: _settings.googleAiModel,
        fetchedModels: models,
        freeOnly: _showFreeModelsOnly,
      );
      final selectedModel = _selectModelAfterFetch(
        current: _settings.googleAiModel,
        models: selectableModels,
      );
      setState(() {
        _models = models;
        _settings = _settings.copyWith(googleAiModel: selectedModel);
        _testingApi = false;
      });
      _showMessage(
        models.isEmpty
            ? 'No available models found.'
            : 'API Connection Successful! Models updated.',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _testingApi = false);
      _showMessage(
        '${context.t('API Connection Error: Please check your key.')}: $error',
      );
    }
  }

  Future<void> _openPromptDialog({AdminAiPrompt? prompt}) async {
    if (prompt?.isBuiltin == true) return;
    final result = await _showAiPromptDialog(context, item: prompt);
    if (!mounted || result == null) return;
    setState(() => _savingPrompt = true);
    try {
      final saved = await widget.repository.savePrompt(
        session: widget.session,
        languageCode: _settingsLanguageCode,
        data: result,
        id: prompt?.id,
      );
      if (!mounted) return;
      setState(() {
        final index = _databasePrompts.indexWhere(
          (item) => item.id == saved.id,
        );
        if (index == -1) {
          _databasePrompts = [saved, ..._databasePrompts];
        } else {
          final next = [..._databasePrompts];
          next[index] = saved;
          _databasePrompts = next;
        }
        _savingPrompt = false;
      });
      _showMessage('Prompt saved successfully.');
    } catch (error) {
      if (!mounted) return;
      setState(() => _savingPrompt = false);
      _showMessage('${context.t('Could not save prompt')}: $error');
    }
  }

  Future<void> _deletePrompt(AdminAiPrompt prompt) async {
    if (_savingPrompt || !prompt.canMutate) return;
    setState(() => _savingPrompt = true);
    try {
      await widget.repository.deletePrompt(
        session: widget.session,
        id: prompt.id,
      );
      if (!mounted) return;
      setState(() {
        _databasePrompts = _databasePrompts
            .where((item) => item.id != prompt.id)
            .toList(growable: false);
        _savingPrompt = false;
      });
      _showMessage('Prompt deleted successfully.');
    } catch (error) {
      if (!mounted) return;
      setState(() => _savingPrompt = false);
      _showMessage('${context.t('Could not delete prompt')}: $error');
    }
  }

  void _showMessage(
    String message, {
    AdminToastTone tone = AdminToastTone.info,
  }) {
    AdminToast.show(context, message: context.t(message), tone: tone);
  }

  void _selectTab(_AiSettingsTab tab) {
    if (_selectedTab == tab) return;
    setState(() => _selectedTab = tab);
    if (tab == _AiSettingsTab.formats && _databasePrompts.isEmpty) {
      unawaited(_loadPrompts());
    }
  }

  void _setShowFreeModelsOnly(bool value) {
    if (_showFreeModelsOnly == value) return;
    final selectableModels = _selectableModelsFor(
      selectedModel: _settings.googleAiModel,
      fetchedModels: _models,
      freeOnly: value,
    );
    final selectedModel = _selectModelAfterFetch(
      current: _settings.googleAiModel,
      models: selectableModels,
    );
    setState(() {
      _showFreeModelsOnly = value;
      if (selectedModel.trim().isNotEmpty &&
          selectedModel != _settings.googleAiModel) {
        _settings = _settings.copyWith(googleAiModel: selectedModel);
      }
    });
  }

  List<AdminAiPrompt> get _visiblePrompts => _databasePrompts;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: settingsPagePadding(constraints.maxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _AiPageHeader(),
              const SizedBox(height: 22),
              _AiTabs(selected: _selectedTab, onSelected: _selectTab),
              const SizedBox(height: 22),
              if (_loadingSettings)
                const _AiLoadingBox()
              else if (_error != null)
                _AiErrorBox(message: _error!, onRetry: () => _loadSettings())
              else
                _AiSettingsCard(
                  title: _selectedTab.title,
                  icon: _selectedTab.icon,
                  trailing: _selectedTab == _AiSettingsTab.formats
                      ? _NewPromptButton(
                          enabled: !_savingPrompt,
                          onPressed: () => _openPromptDialog(),
                        )
                      : null,
                  child: _selectedTab == _AiSettingsTab.google
                      ? _GoogleAiSettings(
                          settings: _settings,
                          apiKeyController: _apiKeyController,
                          models: _models,
                          freeModelsOnly: _showFreeModelsOnly,
                          testing: _testingApi,
                          saving: _savingGoogle,
                          onActiveChanged: (value) {
                            setState(
                              () => _settings = _settings.copyWith(
                                googleAiActive: value,
                              ),
                            );
                          },
                          onModelChanged: (value) {
                            if (value == null) return;
                            setState(
                              () => _settings = _settings.copyWith(
                                googleAiModel: value,
                              ),
                            );
                          },
                          onFreeModelsOnlyChanged: _setShowFreeModelsOnly,
                          onTest: _testApiConnection,
                          onSave: _saveGoogleSettings,
                        )
                      : _AiPromptSettings(
                          items: _visiblePrompts,
                          loading: _loadingPrompts,
                          saving: _savingPrompt,
                          onEdit: (prompt) => _openPromptDialog(prompt: prompt),
                          onDelete: _deletePrompt,
                        ),
                ),
            ],
          ),
        );
      },
    );
  }
}

Future<AiPromptFormData?> _showAiPromptDialog(
  BuildContext context, {
  AdminAiPrompt? item,
}) {
  return showSettingsSideDialog<AiPromptFormData>(
    context,
    barrierLabel: 'AiPromptDialog',
    builder: (mobile) => _AiDialogFrame(
      mobileDrawer: mobile,
      child: _AiPromptDialog(item: item),
    ),
  );
}

class _AiPageHeader extends StatelessWidget {
  const _AiPageHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.t('AI Settings'),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: AppColors.deepOcean,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          context.t('Configure AI models and API keys here.'),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.inkSoft,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _AiTabs extends StatelessWidget {
  const _AiTabs({required this.selected, required this.onSelected});

  final _AiSettingsTab selected;
  final ValueChanged<_AiSettingsTab> onSelected;

  @override
  Widget build(BuildContext context) {
    return SettingsResponsiveTabs<_AiSettingsTab>(
      selected: selected,
      onSelected: onSelected,
      items: [
        for (final tab in _AiSettingsTab.values)
          SettingsTabItem(value: tab, label: tab.title),
      ],
    );
  }
}

class _AiSettingsCard extends StatelessWidget {
  const _AiSettingsCard({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
            child: Row(
              children: [
                SymbolIcon(icon, color: AppColors.actionRed, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.t(title),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.deepOcean,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 16), trailing!],
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.line.withValues(alpha: 0.9)),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _GoogleAiSettings extends StatelessWidget {
  const _GoogleAiSettings({
    required this.settings,
    required this.apiKeyController,
    required this.models,
    required this.freeModelsOnly,
    required this.testing,
    required this.saving,
    required this.onActiveChanged,
    required this.onModelChanged,
    required this.onFreeModelsOnlyChanged,
    required this.onTest,
    required this.onSave,
  });

  final AdminAiSettingsData settings;
  final TextEditingController apiKeyController;
  final List<String> models;
  final bool freeModelsOnly;
  final bool testing;
  final bool saving;
  final ValueChanged<bool> onActiveChanged;
  final ValueChanged<String?> onModelChanged;
  final ValueChanged<bool> onFreeModelsOnlyChanged;
  final VoidCallback onTest;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AiStatusBox(
          enabled: settings.googleAiActive,
          onChanged: saving ? (_) {} : onActiveChanged,
        ),
        const SizedBox(height: 22),
        const _FieldLabel('Google AI API Key'),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final keyField = _ApiKeyField(controller: apiKeyController);
            final testButton = _TestConnectionButton(
              testing: testing,
              enabled: !saving,
              onPressed: onTest,
            );
            if (constraints.maxWidth < 760) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [keyField, const SizedBox(height: 10), testButton],
              );
            }
            return Row(
              children: [
                Expanded(child: keyField),
                const SizedBox(width: 10),
                testButton,
              ],
            );
          },
        ),
        const SizedBox(height: 22),
        _ModelSelect(
          value: settings.googleAiModel,
          models: models,
          freeOnly: freeModelsOnly,
          onChanged: saving ? (_) {} : onModelChanged,
          onFreeOnlyChanged: saving ? (_) {} : onFreeModelsOnlyChanged,
        ),
        const _FormDivider(),
        _SaveRow(enabled: !saving && !testing, saving: saving, onSave: onSave),
      ],
    );
  }
}

class _AiStatusBox extends StatelessWidget {
  const _AiStatusBox({required this.enabled, required this.onChanged});

  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line.withValues(alpha: 0.9)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.value),
              border: Border.all(color: AppColors.line),
            ),
            child: SymbolIcon(
              enabled ? Symbols.check : Symbols.visibility_off,
              color: AppColors.actionRed,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t('Google AI Active'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.deepOcean,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  context.t('Enable Google AI services.'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.inkSoft,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          _CompactCheckSwitch(value: enabled, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _CompactCheckSwitch extends StatelessWidget {
  const _CompactCheckSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
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

const double _aiApiControlHeight = 40;

class _ApiKeyField extends StatefulWidget {
  const _ApiKeyField({required this.controller});

  final TextEditingController controller;

  @override
  State<_ApiKeyField> createState() => _ApiKeyFieldState();
}

class _ApiKeyFieldState extends State<_ApiKeyField> {
  var _obscureApiKey = true;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _aiApiControlHeight,
      child: TextFormField(
        controller: widget.controller,
        obscureText: _obscureApiKey,
        textAlignVertical: TextAlignVertical.center,
        mouseCursor: SystemMouseCursors.text,
        cursorColor: AppColors.support,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.deepOcean,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
        decoration:
            _inputDecoration(
              context,
              prefixIcon: Symbols.lock,
              hintText: 'Google AI API Key...',
            ).copyWith(
              suffixIcon: IconButton(
                tooltip: _obscureApiKey
                    ? 'API anahtarını göster'
                    : 'API anahtarını gizle',
                onPressed: () =>
                    setState(() => _obscureApiKey = !_obscureApiKey),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 40,
                  height: _aiApiControlHeight,
                ),
                visualDensity: VisualDensity.compact,
                icon: SymbolIcon(
                  _obscureApiKey ? Symbols.visibility : Symbols.visibility_off,
                  color: AppColors.iconMuted,
                  size: 18,
                ),
              ),
              suffixIconConstraints: const BoxConstraints.tightFor(
                width: 42,
                height: _aiApiControlHeight,
              ),
            ),
      ),
    );
  }
}

class _TestConnectionButton extends StatelessWidget {
  const _TestConnectionButton({
    required this.testing,
    required this.enabled,
    required this.onPressed,
  });

  final bool testing;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _aiApiControlHeight,
      child: OutlinedButton(
        onPressed: enabled && !testing ? onPressed : null,
        style:
            OutlinedButton.styleFrom(
              foregroundColor: AppColors.deepOcean,
              side: BorderSide(color: AppColors.line.withValues(alpha: 0.9)),
              minimumSize: const Size(0, _aiApiControlHeight),
              padding: const EdgeInsets.symmetric(horizontal: 14),
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
              mouseCursor: WidgetStatePropertyAll(
                enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
              ),
            ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            testing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.deepOcean,
                    ),
                  )
                : const SymbolIcon(
                    Symbols.science_rounded,
                    color: AppColors.deepOcean,
                    size: 16,
                  ),
            const SizedBox(width: 8),
            Text(context.t(testing ? 'Testing...' : 'Test API Connection')),
          ],
        ),
      ),
    );
  }
}

class _ModelSelect extends StatelessWidget {
  const _ModelSelect({
    required this.value,
    required this.models,
    required this.freeOnly,
    required this.onChanged,
    required this.onFreeOnlyChanged,
  });

  final String value;
  final List<String> models;
  final bool freeOnly;
  final ValueChanged<String?> onChanged;
  final ValueChanged<bool> onFreeOnlyChanged;

  @override
  Widget build(BuildContext context) {
    final options = _selectableModelsFor(
      selectedModel: value,
      fetchedModels: models,
      freeOnly: freeOnly,
    );
    final safeValue = value.trim().isNotEmpty && options.contains(value.trim())
        ? value.trim()
        : options.firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final toggle = _FreeModelsToggle(
              value: freeOnly,
              onChanged: onFreeOnlyChanged,
            );
            if (constraints.maxWidth < 420) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _FieldLabel('Google AI Model'),
                  const SizedBox(height: 8),
                  toggle,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Expanded(child: _FieldLabel('Google AI Model')),
                const SizedBox(width: 12),
                toggle,
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        if (options.isEmpty)
          _EmptyModelBox()
        else
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Container(
              height: 40,
              padding: const EdgeInsets.only(left: 12, right: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.value),
                border: Border.all(color: AppColors.line),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: safeValue,
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
                    for (final model in options)
                      DropdownMenuItem(value: model, child: Text(model)),
                  ],
                  onChanged: onChanged,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _FreeModelsToggle extends StatelessWidget {
  const _FreeModelsToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          context.t('Show free models only'),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: AppColors.inkSoft,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(width: 8),
        _CompactCheckSwitch(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _EmptyModelBox extends StatelessWidget {
  const _EmptyModelBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.softLine),
      ),
      child: Text(
        context.t('No available models found.'),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.inkSoft,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _AiPromptSettings extends StatelessWidget {
  const _AiPromptSettings({
    required this.items,
    required this.loading,
    required this.saving,
    required this.onEdit,
    required this.onDelete,
  });

  final List<AdminAiPrompt> items;
  final bool loading;
  final bool saving;
  final ValueChanged<AdminAiPrompt> onEdit;
  final ValueChanged<AdminAiPrompt> onDelete;

  @override
  Widget build(BuildContext context) {
    if (loading) return const _AiLoadingBox();
    if (items.isEmpty) return const _EmptyPromptBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _AiPromptCard(
            item: items[i],
            saving: saving,
            onEdit: () => onEdit(items[i]),
            onDelete: () => onDelete(items[i]),
          ),
        ],
      ],
    );
  }
}

class _AiPromptCard extends StatelessWidget {
  const _AiPromptCard({
    required this.item,
    required this.saving,
    required this.onEdit,
    required this.onDelete,
  });

  final AdminAiPrompt item;
  final bool saving;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line.withValues(alpha: 0.9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.deepOcean,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                    if (item.isBuiltin) const _AiPromptBadge(),
                  ],
                ),
              ),
              if (item.canMutate) ...[
                const SizedBox(width: 12),
                _PromptActions(
                  enabled: !saving,
                  onEdit: onEdit,
                  onDelete: onDelete,
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            item.prompt,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.inkSoft,
              fontWeight: FontWeight.w500,
              letterSpacing: 0,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _AiPromptBadge extends StatelessWidget {
  const _AiPromptBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.softLine),
      ),
      child: Text(
        context.t('System'),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.inkSoft,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _PromptActions extends StatelessWidget {
  const _PromptActions({
    required this.enabled,
    required this.onEdit,
    required this.onDelete,
  });

  final bool enabled;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PromptActionButton(
          tooltip: 'Edit prompt',
          icon: Symbols.edit_square,
          color: AppColors.deepOcean,
          enabled: enabled,
          onTap: onEdit,
        ),
        const SizedBox(width: 6),
        _PromptActionButton(
          tooltip: 'Delete prompt',
          icon: Symbols.delete,
          color: AppColors.actionRed,
          enabled: enabled,
          onTap: onDelete,
        ),
      ],
    );
  }
}

class _PromptActionButton extends StatelessWidget {
  const _PromptActionButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: context.t(tooltip),
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? onTap : null,
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.value),
              border: Border.all(color: AppColors.line),
            ),
            child: SymbolIcon(icon, color: color, size: 18),
          ),
        ),
      ),
    );
  }
}

class _EmptyPromptBox extends StatelessWidget {
  const _EmptyPromptBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.softLine),
      ),
      child: Text(
        context.t('No saved AI prompts.'),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.inkSoft,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _NewPromptButton extends StatelessWidget {
  const _NewPromptButton({required this.enabled, required this.onPressed});

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
              disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
              padding: const EdgeInsets.symmetric(horizontal: 16),
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
              mouseCursor: WidgetStatePropertyAll(
                enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
              ),
            ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SymbolIcon(Symbols.add, color: Colors.white, size: 17),
            const SizedBox(width: 8),
            Text(context.t('Add New Prompt')),
          ],
        ),
      ),
    );
  }
}

class _AiDialogFrame extends StatelessWidget {
  const _AiDialogFrame({required this.child, required this.mobileDrawer});

  final Widget child;
  final bool mobileDrawer;

  @override
  Widget build(BuildContext context) {
    if (mobileDrawer) {
      return ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: SingleChildScrollView(child: child),
      );
    }

    final height = MediaQuery.sizeOf(context).height;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 720, maxHeight: height - 48),
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

class _AiPromptDialog extends StatefulWidget {
  const _AiPromptDialog({this.item});

  final AdminAiPrompt? item;

  @override
  State<_AiPromptDialog> createState() => _AiPromptDialogState();
}

class _AiPromptDialogState extends State<_AiPromptDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _promptController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.item?.title ?? '');
    _promptController = TextEditingController(text: widget.item?.prompt ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  void _save() {
    final title = _titleController.text.trim();
    final prompt = _promptController.text.trim();
    if (title.isEmpty || prompt.isEmpty) return;
    Navigator.of(context).pop(AiPromptFormData(title: title, prompt: prompt));
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.item != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 26, 28, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DialogHeader(title: editing ? 'Edit Prompt' : 'Add New Prompt'),
          const SizedBox(height: 24),
          _TextInputField(
            controller: _titleController,
            label: 'Prompt Title',
            hintText: 'Prepare News, Create Summary, etc...',
          ),
          const SizedBox(height: 22),
          _TextAreaField(
            controller: _promptController,
            label: 'System Command (Prompt)',
            hintText: 'System instructions to send to the AI...',
            minLines: 8,
          ),
          const SizedBox(height: 10),
          Text(
            context.t(
              '* This command will be added as the system instruction when the AI assistant runs.',
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.inkSoft,
              fontWeight: FontWeight.w500,
              letterSpacing: 0,
            ),
          ),
          const _FormDivider(),
          _DialogFooter(onSave: _save),
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
            context.t(title),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
                color: AppColors.inkSoft,
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DialogFooter extends StatelessWidget {
  const _DialogFooter({required this.onSave});

  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Row(
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
            child: Text(context.t('Cancel')),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 114,
            height: 36,
            child: TextButton(
              onPressed: onSave,
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
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ).copyWith(
                    mouseCursor: const WidgetStatePropertyAll(
                      SystemMouseCursors.click,
                    ),
                  ),
              child: Text(context.t('Save')),
            ),
          ),
        ],
      ),
    );
  }
}

class _TextInputField extends StatelessWidget {
  const _TextInputField({required this.label, this.controller, this.hintText});

  final String label;
  final TextEditingController? controller;
  final String? hintText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 8),
        SizedBox(
          height: 42,
          child: TextFormField(
            controller: controller,
            mouseCursor: SystemMouseCursors.text,
            cursorColor: AppColors.support,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.deepOcean,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
            decoration: _inputDecoration(
              context,
              hintText: hintText,
              modal: true,
            ),
          ),
        ),
      ],
    );
  }
}

class _TextAreaField extends StatelessWidget {
  const _TextAreaField({
    required this.label,
    required this.minLines,
    this.controller,
    this.hintText,
  });

  final String label;
  final int minLines;
  final TextEditingController? controller;
  final String? hintText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          minLines: minLines,
          maxLines: minLines + 2,
          mouseCursor: SystemMouseCursors.text,
          cursorColor: AppColors.support,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.deepOcean,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
            height: 1.5,
          ),
          decoration: _inputDecoration(
            context,
            hintText: hintText,
            modal: true,
          ),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      context.t(label),
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: AppColors.deepOcean,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
    );
  }
}

class _FormDivider extends StatelessWidget {
  const _FormDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 46,
      thickness: 1,
      color: AppColors.line.withValues(alpha: 0.9),
    );
  }
}

class _SaveRow extends StatelessWidget {
  const _SaveRow({
    required this.enabled,
    required this.saving,
    required this.onSave,
  });

  final bool enabled;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        height: 38,
        child: TextButton(
          onPressed: enabled ? onSave : null,
          style:
              TextButton.styleFrom(
                backgroundColor: AppColors.actionRed,
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
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
                mouseCursor: WidgetStatePropertyAll(
                  enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
                ),
              ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (saving)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              else
                const SymbolIcon(Symbols.check, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text(context.t(saving ? 'Saving...' : 'Save Changes')),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiLoadingBox extends StatelessWidget {
  const _AiLoadingBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.all(28),
      child: const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.deepOcean,
        ),
      ),
    );
  }
}

class _AiErrorBox extends StatelessWidget {
  const _AiErrorBox({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.deepOcean,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(width: 16),
          OutlinedButton(onPressed: onRetry, child: Text(context.t('Retry'))),
        ],
      ),
    );
  }
}

InputDecoration _inputDecoration(
  BuildContext context, {
  String? hintText,
  IconData? prefixIcon,
  bool modal = false,
}) {
  return InputDecoration(
    hintText: hintText == null ? null : context.t(hintText),
    hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: AppColors.placeholder,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    ),
    prefixIcon: prefixIcon == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(left: 12, right: 8),
            child: SymbolIcon(prefixIcon, color: AppColors.iconMuted, size: 18),
          ),
    prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 20),
    filled: !modal,
    fillColor: modal ? Colors.transparent : Colors.white,
    hoverColor: Colors.transparent,
    focusColor: Colors.transparent,
    isDense: true,
    contentPadding: EdgeInsets.symmetric(
      horizontal: 12,
      vertical: modal ? 10 : 12,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.value),
      borderSide: const BorderSide(color: AppColors.line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.value),
      borderSide: const BorderSide(color: AppColors.line),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.value),
      borderSide: BorderSide(
        color: modal
            ? AppColors.support
            : AppColors.deepOcean.withValues(alpha: 0.4),
      ),
    ),
  );
}

List<String> _fallbackModelsFor(String selectedModel) {
  final models = <String>[
    'gemini-3.5-flash',
    'gemini-3.1-flash-lite',
    'gemini-3-flash-preview',
    'gemini-2.5-flash',
    'gemini-2.5-flash-lite',
    'gemini-2.5-pro',
  ];
  final cleanSelected = selectedModel.trim();
  if (cleanSelected.isNotEmpty && !models.contains(cleanSelected)) {
    models.insert(0, cleanSelected);
  }
  return models;
}

List<String> _selectableModelsFor({
  required String selectedModel,
  required List<String> fetchedModels,
  required bool freeOnly,
}) {
  final sourceModels = fetchedModels.isEmpty
      ? _fallbackModelsFor(selectedModel)
      : filterGeminiTextGenerationModels(fetchedModels);
  final models = freeOnly
      ? sourceModels
            .where(isFreeGeminiTextGenerationModel)
            .toList(growable: false)
      : sourceModels;
  final cleanSelected = selectedModel.trim();
  if (cleanSelected.isEmpty || models.contains(cleanSelected)) {
    return models;
  }
  if (freeOnly && !isFreeGeminiTextGenerationModel(cleanSelected)) {
    return models;
  }
  return [cleanSelected, ...models];
}

String _selectModelAfterFetch({
  required String current,
  required List<String> models,
}) {
  if (current.trim().isNotEmpty && models.contains(current.trim())) {
    return current.trim();
  }
  return models
          .where((model) => model.toLowerCase().contains('-flash'))
          .firstOrNull ??
      models.firstOrNull ??
      current;
}

String _normalizePromptTitle(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

String _cleanLanguageCode(String value) {
  final code = value.trim().toLowerCase().replaceAll('_', '-');
  return code.isEmpty ? 'tr' : code;
}

enum _AiSettingsTab {
  google('Google AI (Gemini)', Symbols.pending_actions),
  formats('AI Ready Prompts', Symbols.draft);

  const _AiSettingsTab(this.title, this.icon);

  final String title;
  final IconData icon;
}
