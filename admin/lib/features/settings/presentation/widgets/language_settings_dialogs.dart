import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../../core/localization/admin_language_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../features/settings/data/admin_language_models.dart';
import '../../../../shared/widgets/symbol_icon.dart';

Future<LanguageFormData?> showAddLanguageDialog(
  BuildContext context, {
  AdminLanguage? language,
}) {
  return showDialog<LanguageFormData>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.34),
    builder: (context) => _LanguageDialogFrame(
      maxWidth: 820,
      child: _LanguageFormDialog(language: language),
    ),
  );
}

Future<String?> showImportLanguageDialog(
  BuildContext context, {
  required String sampleJson,
}) {
  return showDialog<String>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.34),
    builder: (context) => _LanguageDialogFrame(
      maxWidth: 820,
      child: _ImportLanguageDialog(sampleJson: sampleJson),
    ),
  );
}

Future<Map<String, String>?> showTranslationsDialog(
  BuildContext context, {
  required AdminLanguage language,
  required List<TranslationEntryData> entries,
}) {
  return showDialog<Map<String, String>>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.34),
    builder: (context) => _LanguageDialogFrame(
      maxWidth: 820,
      child: _TranslationsDialog(language: language, entries: entries),
    ),
  );
}

Future<void> showExportLanguageDialog(
  BuildContext context, {
  required AdminLanguage language,
  required String jsonContent,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.34),
    builder: (context) => _LanguageDialogFrame(
      maxWidth: 820,
      child: _ExportLanguageDialog(
        language: language,
        jsonContent: jsonContent,
      ),
    ),
  );
}

class _LanguageDialogFrame extends StatelessWidget {
  const _LanguageDialogFrame({required this.maxWidth, required this.child});

  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: height - 48),
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

class _LanguageFormDialog extends StatefulWidget {
  const _LanguageFormDialog({this.language});

  final AdminLanguage? language;

  @override
  State<_LanguageFormDialog> createState() => _LanguageFormDialogState();
}

class _LanguageFormDialogState extends State<_LanguageFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  late final TextEditingController _flagController;
  late final TextEditingController _orderController;
  late String _direction;
  late String _status;

  bool get _editing => widget.language != null;

  bool get _core => widget.language?.isCore ?? false;

  @override
  void initState() {
    super.initState();
    final language = widget.language;
    _nameController = TextEditingController(text: language?.name ?? '');
    _codeController = TextEditingController(text: language?.code ?? '');
    _flagController = TextEditingController(
      text: language?.flagCode ?? language?.code ?? '',
    );
    _orderController = TextEditingController(
      text: language == null ? '' : language.rowNumber.toString(),
    );
    _direction = language?.direction ?? 'ltr';
    _status = language?.status ?? 'active';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _flagController.dispose();
    _orderController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      LanguageFormData(
        code: _codeController.text.trim().toLowerCase(),
        name: _nameController.text.trim(),
        direction: _direction,
        status: _core ? 'active' : _status,
        flagCode: _flagController.text.trim().toLowerCase(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 26, 28, 22),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DialogHeader(
              title: _editing
                  ? context.t('language.edit')
                  : context.t('language.add'),
              subtitle: context.t('language.addSubtitle'),
            ),
            const SizedBox(height: 22),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 680;
                final left = Column(
                  children: [
                    _DialogLineField(
                      controller: _nameController,
                      label: context.t('language.name'),
                      hintText: context.t('language.nameHint'),
                      icon: Symbols.language,
                      requiredField: true,
                      validator: _requiredValidator,
                    ),
                    const SizedBox(height: 22),
                    _DialogLineField(
                      controller: _flagController,
                      label: context.t('language.flagCode'),
                      hintText: context.t('language.flagCodeHint'),
                      icon: Symbols.short_text,
                      requiredField: true,
                      validator: _codeValidator,
                    ),
                    const SizedBox(height: 22),
                    _DialogLineField(
                      controller: _orderController,
                      label: context.t('language.orderNo'),
                      hintText: context.t('language.orderHint'),
                      icon: Symbols.format_list_numbered,
                      keyboardType: TextInputType.number,
                      enabled: false,
                    ),
                  ],
                );
                final right = Column(
                  children: [
                    _DialogLineField(
                      controller: _codeController,
                      label: context.t('language.code'),
                      hintText: context.t('language.codeHint'),
                      icon: Symbols.code,
                      requiredField: true,
                      enabled: !_editing,
                      validator: _codeValidator,
                    ),
                    const SizedBox(height: 22),
                    _DialogSelectLineField(
                      label: context.t('language.editorLocale'),
                      hintText: context.t('language.editorLocaleHint'),
                      icon: Symbols.translate,
                    ),
                  ],
                );

                final options = _AddLanguageOptions(
                  direction: _direction,
                  status: _status,
                  statusLocked: _core,
                  onDirectionChanged: (value) =>
                      setState(() => _direction = value),
                  onStatusChanged: (value) => setState(() => _status = value),
                );

                if (compact) {
                  return Column(
                    children: [
                      left,
                      const SizedBox(height: 22),
                      right,
                      const SizedBox(height: 24),
                      options,
                    ],
                  );
                }

                return Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: left),
                        const SizedBox(width: 24),
                        Expanded(child: right),
                      ],
                    ),
                    const SizedBox(height: 24),
                    options,
                  ],
                );
              },
            ),
            const SizedBox(height: 26),
            Align(
              alignment: Alignment.centerRight,
              child: _DialogFooter(
                primaryLabel: context.t('common.save'),
                onPrimaryPressed: _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _requiredValidator(String? value) {
    return (value ?? '').trim().isEmpty ? context.t('language.name') : null;
  }

  String? _codeValidator(String? value) {
    final code = (value ?? '').trim().toLowerCase();
    if (code.isEmpty) return context.t('language.code');
    if (!RegExp(r'^[a-z]{2,3}(-[a-z0-9]{2,8})?$').hasMatch(code)) {
      return context.t('language.codeHint');
    }
    return null;
  }
}

class _AddLanguageOptions extends StatelessWidget {
  const _AddLanguageOptions({
    required this.direction,
    required this.status,
    required this.statusLocked,
    required this.onDirectionChanged,
    required this.onStatusChanged,
  });

  final String direction;
  final String status;
  final bool statusLocked;
  final ValueChanged<String> onDirectionChanged;
  final ValueChanged<String> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final writingDirection = _DialogRadioGroup(
      title: context.t('language.writingDirection'),
      value: direction,
      onChanged: onDirectionChanged,
      items: [
        _DialogRadioItem(value: 'ltr', label: context.t('language.ltr')),
        _DialogRadioItem(value: 'rtl', label: context.t('language.rtl')),
      ],
    );
    final languageStatus = _DialogRadioGroup(
      title: context.t('language.status'),
      value: statusLocked ? 'active' : status,
      onChanged: statusLocked ? null : onStatusChanged,
      items: [
        _DialogRadioItem(value: 'active', label: context.t('common.active')),
        _DialogRadioItem(value: 'passive', label: context.t('common.passive')),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 680) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              writingDirection,
              const SizedBox(height: 18),
              languageStatus,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: writingDirection),
            const SizedBox(width: 24),
            Expanded(child: languageStatus),
          ],
        );
      },
    );
  }
}

class _ImportLanguageDialog extends StatefulWidget {
  const _ImportLanguageDialog({required this.sampleJson});

  final String sampleJson;

  @override
  State<_ImportLanguageDialog> createState() => _ImportLanguageDialogState();
}

class _ImportLanguageDialogState extends State<_ImportLanguageDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final file = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(
          label: 'JSON',
          extensions: ['json'],
          mimeTypes: ['application/json'],
        ),
      ],
    );
    if (file == null) return;
    _controller.text = await file.readAsString();
  }

  void _useSampleJson() {
    _controller.text = widget.sampleJson;
  }

  void _submit() {
    final content = _controller.text.trim();
    try {
      jsonDecode(content);
    } catch (_) {
      setState(() => _error = context.t('language.invalidJson'));
      return;
    }
    Navigator.of(context).pop(content);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 26, 28, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DialogHeader(
            title: context.t('language.importJson'),
            subtitle: context.t('language.importSubtitle'),
          ),
          const SizedBox(height: 20),
          _DialogSectionLabel(context.t('language.jsonContent')),
          const SizedBox(height: 12),
          _JsonContentBox(controller: _controller),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: AppColors.actionRed)),
          ],
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 650;
              final fileActions = Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _DialogOutlinedAction(
                    icon: Symbols.folder_open,
                    label: context.t('language.selectFile'),
                    onPressed: _pickFile,
                  ),
                  _DialogOutlinedAction(
                    icon: Symbols.download,
                    label: context.t('language.sampleJson'),
                    onPressed: _useSampleJson,
                  ),
                ],
              );
              final submit = _DialogFooter(
                primaryLabel: context.t('language.upload'),
                onPrimaryPressed: _submit,
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [fileActions, const SizedBox(height: 18), submit],
                );
              }

              return Row(
                children: [
                  Expanded(child: fileActions),
                  submit,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TranslationsDialog extends StatefulWidget {
  const _TranslationsDialog({required this.language, required this.entries});

  final AdminLanguage language;
  final List<TranslationEntryData> entries;

  @override
  State<_TranslationsDialog> createState() => _TranslationsDialogState();
}

class _TranslationsDialogState extends State<_TranslationsDialog> {
  late final List<_EditableTranslationEntry> _entries;

  @override
  void initState() {
    super.initState();
    _entries = widget.entries
        .map(
          (entry) => _EditableTranslationEntry(
            keyController: TextEditingController(text: entry.key),
            source: entry.source,
            valueController: TextEditingController(text: entry.value),
            keyReadOnly: true,
          ),
        )
        .toList();
  }

  @override
  void dispose() {
    for (final entry in _entries) {
      entry.dispose();
    }
    super.dispose();
  }

  void _addRow() {
    setState(() {
      _entries.add(
        _EditableTranslationEntry(
          keyController: TextEditingController(),
          source: '',
          valueController: TextEditingController(),
          keyReadOnly: false,
        ),
      );
    });
  }

  void _removeRow(int index) {
    setState(() {
      _entries.removeAt(index).dispose();
    });
  }

  void _submit() {
    final translations = <String, String>{};
    for (final entry in _entries) {
      final key = entry.keyController.text.trim();
      if (key.isEmpty) continue;
      translations[key] = entry.valueController.text;
    }
    Navigator.of(context).pop(translations);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 26, 28, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DialogHeader(
            title: context.t('language.translations'),
            subtitle: context.t('language.translationsSubtitle'),
          ),
          const SizedBox(height: 10),
          Text(
            '${widget.language.name} (${widget.language.code})',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.deepOcean,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 24),
          const _TranslationColumnHeader(),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 566),
            child: _TranslationRows(entries: _entries, onRemove: _removeRow),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _AddTranslationRowButton(onPressed: _addRow),
              const Spacer(),
              _DialogFooter(
                primaryLabel: context.t('common.save'),
                onPrimaryPressed: _submit,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExportLanguageDialog extends StatelessWidget {
  const _ExportLanguageDialog({
    required this.language,
    required this.jsonContent,
  });

  final AdminLanguage language;
  final String jsonContent;

  Future<void> _saveToFile() async {
    final fileName = '${language.code}_language_pack.json';
    final location = await getSaveLocation(
      suggestedName: fileName,
      acceptedTypeGroups: [
        const XTypeGroup(
          label: 'JSON',
          extensions: ['json'],
          mimeTypes: ['application/json'],
        ),
      ],
    );
    if (location == null) return;
    final bytes = utf8.encode(jsonContent);
    await XFile.fromData(
      bytes,
      mimeType: 'application/json',
      name: fileName,
    ).saveTo(location.path);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 26, 28, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DialogHeader(
            title: context.t('language.export'),
            subtitle: '${language.name} (${language.code})',
          ),
          const SizedBox(height: 18),
          _JsonContentBox(
            controller: TextEditingController(text: jsonContent),
            readOnly: true,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _DialogOutlinedAction(
                icon: Symbols.article,
                label: context.t('common.copy'),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: jsonContent));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(context.t('common.copied'))),
                    );
                  }
                },
              ),
              const SizedBox(width: 10),
              _DialogOutlinedAction(
                icon: Symbols.download,
                label: context.t('language.export'),
                onPressed: _saveToFile,
              ),
              const Spacer(),
              _DialogFooter(
                primaryLabel: context.t('common.cancel'),
                onPrimaryPressed: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DialogHeader extends StatelessWidget {
  const _DialogHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.deepOcean,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.inkSoft,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        const _DialogCloseButton(),
      ],
    );
  }
}

class _DialogCloseButton extends StatelessWidget {
  const _DialogCloseButton();

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
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
    this.keyboardType,
    this.validator,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final IconData icon;
  final bool requiredField;
  final TextInputType? keyboardType;
  final FormFieldValidator<String>? validator;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DialogSectionLabel(
          label,
          color: requiredField ? AppColors.actionRed : AppColors.inkSoft,
        ),
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
                  enabled: enabled,
                  keyboardType: keyboardType,
                  validator: validator,
                  mouseCursor: SystemMouseCursors.text,
                  cursorColor: AppColors.support,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.deepOcean,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0,
                  ),
                  decoration: InputDecoration(
                    hintText: hintText,
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

class _DialogSelectLineField extends StatelessWidget {
  const _DialogSelectLineField({
    required this.label,
    required this.hintText,
    required this.icon,
  });

  final String label;
  final String hintText;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DialogSectionLabel(label),
        const SizedBox(height: 12),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            height: 38,
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.line)),
            ),
            child: Row(
              children: [
                SymbolIcon(icon, color: AppColors.placeholder, size: 19),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    hintText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.placeholder,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                const SymbolIcon(
                  Symbols.keyboard_arrow_down,
                  color: AppColors.iconMuted,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DialogSectionLabel extends StatelessWidget {
  const _DialogSectionLabel(this.label, {this.color = AppColors.inkSoft});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: color,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
    );
  }
}

class _DialogRadioGroup extends StatelessWidget {
  const _DialogRadioGroup({
    required this.title,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String title;
  final String value;
  final List<_DialogRadioItem> items;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DialogSectionLabel(title),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 10,
          children: [
            for (final item in items)
              MouseRegion(
                cursor: enabled
                    ? SystemMouseCursors.click
                    : SystemMouseCursors.basic,
                child: GestureDetector(
                  onTap: enabled ? () => onChanged?.call(item.value) : null,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _DialogRadioMark(selected: item.value == value),
                      const SizedBox(width: 6),
                      Text(
                        item.label,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: enabled
                              ? AppColors.deepOcean
                              : AppColors.placeholder,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _DialogRadioMark extends StatelessWidget {
  const _DialogRadioMark({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AppColors.deepOcean : AppColors.inkSoft,
          width: 2,
        ),
      ),
      child: selected
          ? Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.deepOcean,
                shape: BoxShape.circle,
              ),
            )
          : null,
    );
  }
}

class _DialogRadioItem {
  const _DialogRadioItem({required this.value, required this.label});

  final String value;
  final String label;
}

class _JsonContentBox extends StatelessWidget {
  const _JsonContentBox({required this.controller, this.readOnly = false});

  final TextEditingController controller;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line),
      ),
      child: Stack(
        children: [
          TextField(
            controller: controller,
            readOnly: readOnly,
            expands: true,
            maxLines: null,
            minLines: null,
            mouseCursor: SystemMouseCursors.text,
            cursorColor: AppColors.support,
            textAlignVertical: TextAlignVertical.top,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.deepOcean,
              fontWeight: FontWeight.w500,
              letterSpacing: 0,
            ),
            decoration: InputDecoration(
              hintText: context.t('language.jsonHint'),
              hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.placeholder,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.fromLTRB(44, 14, 16, 14),
              filled: false,
              hoverColor: Colors.transparent,
              focusColor: Colors.transparent,
            ),
          ),
          Positioned(
            left: 14,
            top: 128,
            child: Text(
              '{}',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.placeholder,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
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
          width: 114,
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

class _DialogOutlinedAction extends StatelessWidget {
  const _DialogOutlinedAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: OutlinedButton(
        onPressed: onPressed,
        style:
            OutlinedButton.styleFrom(
              foregroundColor: AppColors.deepOcean,
              side: BorderSide(color: AppColors.line.withValues(alpha: 0.92)),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.value),
              ),
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SymbolIcon(icon, color: AppColors.deepOcean, size: 18),
            const SizedBox(width: 9),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _TranslationColumnHeader extends StatelessWidget {
  const _TranslationColumnHeader();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: AppColors.inkSoft,
      fontWeight: FontWeight.w700,
      letterSpacing: 0,
    );

    return Row(
      children: [
        Expanded(
          child: Text(context.t('language.translationsKey'), style: style),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Text(context.t('language.translationsTarget'), style: style),
        ),
        const SizedBox(width: 34),
      ],
    );
  }
}

class _TranslationRows extends StatelessWidget {
  const _TranslationRows({required this.entries, required this.onRemove});

  final List<_EditableTranslationEntry> entries;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line.withValues(alpha: 0.9)),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: entries.length,
        itemExtent: 64,
        itemBuilder: (context, index) {
          final entry = entries[index];
          return _TranslationRow(entry: entry, onRemove: () => onRemove(index));
        },
      ),
    );
  }
}

class _TranslationRow extends StatelessWidget {
  const _TranslationRow({required this.entry, required this.onRemove});

  final _EditableTranslationEntry entry;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(child: _TranslationSourceField(entry: entry)),
          const SizedBox(width: 24),
          Expanded(child: _TranslationValueField(entry: entry)),
          const SizedBox(width: 14),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onRemove,
              child: const Padding(
                padding: EdgeInsets.all(5),
                child: SymbolIcon(
                  Symbols.close,
                  color: AppColors.inkSoft,
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TranslationSourceField extends StatelessWidget {
  const _TranslationSourceField({required this.entry});

  final _EditableTranslationEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.line.withValues(alpha: 0.9)),
        ),
      ),
      child: Row(
        children: [
          const SymbolIcon(
            Symbols.language,
            color: AppColors.placeholder,
            size: 19,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: entry.keyController,
              readOnly: entry.keyReadOnly,
              mouseCursor: SystemMouseCursors.text,
              cursorColor: AppColors.support,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.deepOcean,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
              decoration: InputDecoration(
                hintText: entry.source.isEmpty ? 'custom.key' : entry.source,
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
    );
  }
}

class _TranslationValueField extends StatelessWidget {
  const _TranslationValueField({required this.entry});

  final _EditableTranslationEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.line.withValues(alpha: 0.9)),
        ),
      ),
      child: Row(
        children: [
          const SymbolIcon(
            Symbols.translate,
            color: AppColors.placeholder,
            size: 19,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: entry.valueController,
              mouseCursor: SystemMouseCursors.text,
              cursorColor: AppColors.support,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.deepOcean,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
              decoration: InputDecoration(
                hintText: context.t('language.translationsHint'),
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
    );
  }
}

class _AddTranslationRowButton extends StatelessWidget {
  const _AddTranslationRowButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
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
            mouseCursor: const WidgetStatePropertyAll(SystemMouseCursors.click),
          ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SymbolIcon(Symbols.add, color: AppColors.deepOcean, size: 18),
          const SizedBox(width: 8),
          Text(context.t('language.translationsAddRow')),
        ],
      ),
    );
  }
}

class _EditableTranslationEntry {
  _EditableTranslationEntry({
    required this.keyController,
    required this.source,
    required this.valueController,
    required this.keyReadOnly,
  });

  final TextEditingController keyController;
  final String source;
  final TextEditingController valueController;
  final bool keyReadOnly;

  void dispose() {
    keyController.dispose();
    valueController.dispose();
  }
}
