import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';
import 'package:pateeznews_admin/shared/widgets/admin_toast.dart';

import '../../../core/localization/admin_language_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/widgets/app_confirmation_dialog.dart';
import '../../../shared/widgets/symbol_icon.dart';
import '../data/admin_storage_settings_repository.dart';

class StorageSettingsScreen extends StatefulWidget {
  const StorageSettingsScreen({
    super.key,
    this.repository = const SupabaseAdminStorageSettingsRepository(),
  });

  final AdminStorageSettingsRepository repository;

  @override
  State<StorageSettingsScreen> createState() => _StorageSettingsScreenState();
}

class _StorageSettingsScreenState extends State<StorageSettingsScreen> {
  final _accessKeyController = TextEditingController();
  final _secretKeyController = TextEditingController();
  final _bucketController = TextEditingController();
  final _regionController = TextEditingController();
  final _pathPrefixController = TextEditingController();

  var _activeStorage = 'storageSettings.option.localStorage';
  var _loadedActiveStorage = 'storageSettings.option.localStorage';
  var _selectedProvider = _StorageProvider.awsS3;
  var _providerValues = <String, Map<String, String>>{};
  var _localBackupEnabled = false;
  var _localMediaCount = 0;
  var _loading = true;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _accessKeyController.dispose();
    _secretKeyController.dispose();
    _bucketController.dispose();
    _regionController.dispose();
    _pathPrefixController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await widget.repository.fetchSettings();
      if (!mounted) return;
      setState(() {
        _activeStorage = settings.activeStorageKey;
        _loadedActiveStorage = settings.activeStorageKey;
        _selectedProvider = _StorageProvider.fromId(
          settings.selectedProviderId,
        );
        _providerValues = {
          for (final entry in settings.providers.entries)
            entry.key: Map<String, String>.of(entry.value),
        };
        _localBackupEnabled = settings.localBackupEnabled;
        _localMediaCount = settings.localMediaCount;
        _applyProviderValues(_selectedProvider);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _saveSettings() async {
    if (_saving) return;
    _rememberProviderValues(_selectedProvider);
    final migrateLocalMedia = await _confirmLocalMediaMigrationIfNeeded();
    if (!mounted) return;
    setState(() => _saving = true);
    try {
      final saved = await widget.repository.saveSettings(
        AdminStorageSettingsData(
          activeStorageKey: _activeStorage,
          selectedProviderId: _selectedProvider.id,
          providers: _providerValues,
          localBackupEnabled: _localBackupEnabled,
        ),
        migrateLocalMedia: migrateLocalMedia,
      );
      if (!mounted) return;
      setState(() {
        _activeStorage = saved.activeStorageKey;
        _loadedActiveStorage = saved.activeStorageKey;
        _selectedProvider = _StorageProvider.fromId(saved.selectedProviderId);
        _providerValues = {
          for (final entry in saved.providers.entries)
            entry.key: Map<String, String>.of(entry.value),
        };
        _localBackupEnabled = saved.localBackupEnabled;
        _localMediaCount = saved.localMediaCount;
        _applyProviderValues(_selectedProvider);
        _saving = false;
      });
      _showSavedMessage();
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      AdminToast.show(
        context,
        message: error.toString(),
        tone: AdminToastTone.error,
      );
    }
  }

  Future<bool> _confirmLocalMediaMigrationIfNeeded() async {
    final switchedFromLocal =
        _loadedActiveStorage == 'storageSettings.option.localStorage' &&
        _activeStorage != 'storageSettings.option.localStorage';
    if (!switchedFromLocal || _localMediaCount <= 0) return false;
    return showAppConfirmationDialog(
      context,
      title: 'storageSettings.migrationConfirm.title',
      message: 'storageSettings.migrationConfirm.message',
      cancelLabel: 'storageSettings.migrationConfirm.skip',
      confirmLabel: 'storageSettings.migrationConfirm.confirm',
      danger: true,
    );
  }

  void _showSavedMessage() {
    AdminToast.show(
      context,
      message: context.t('storageSettings.saveSuccess'),
      tone: AdminToastTone.success,
    );
  }

  void _rememberProviderValues(_StorageProvider provider) {
    final keys = provider.settingKeys;
    _providerValues = {
      ..._providerValues,
      provider.id: {
        keys[0]: _accessKeyController.text.trim(),
        keys[1]: _secretKeyController.text.trim(),
        keys[2]: _bucketController.text.trim(),
        keys[3]: _regionController.text.trim(),
        if (keys.length > 4) keys[4]: _pathPrefixController.text.trim(),
      },
    };
  }

  void _applyProviderValues(_StorageProvider provider) {
    final keys = provider.settingKeys;
    final values = _providerValues[provider.id] ?? const <String, String>{};
    _accessKeyController.text = values[keys[0]] ?? '';
    _secretKeyController.text = values[keys[1]] ?? '';
    _bucketController.text = values[keys[2]] ?? '';
    _regionController.text = values[keys[3]] ?? '';
    _pathPrefixController.text = keys.length > 4
        ? values[keys[4]] ?? 'pateez'
        : '';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 640 ? 16.0 : 28.0;

        if (_loading) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.actionRed),
          );
        }

        return SingleChildScrollView(
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
                context.t('storageSettings.title'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.deepOcean,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 22),
              _StorageLayout(
                left: _ActiveStorageCard(
                  value: _activeStorage,
                  localBackupEnabled: _localBackupEnabled,
                  onChanged: (value) {
                    if (value == null) return;
                    _rememberProviderValues(_selectedProvider);
                    final provider = _StorageProvider.fromStorageOptionKey(
                      value,
                    );
                    setState(() {
                      _activeStorage = value;
                      if (provider != null) {
                        _selectedProvider = provider;
                        _applyProviderValues(provider);
                      }
                    });
                  },
                  onLocalBackupChanged: (value) {
                    setState(() => _localBackupEnabled = value);
                  },
                ),
                right: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ProviderSettingsCard(
                      selectedProvider: _selectedProvider,
                      onProviderChanged: (provider) {
                        _rememberProviderValues(_selectedProvider);
                        setState(() {
                          _selectedProvider = provider;
                          _applyProviderValues(provider);
                        });
                      },
                      accessKeyController: _accessKeyController,
                      secretKeyController: _secretKeyController,
                      bucketController: _bucketController,
                      regionController: _regionController,
                      pathPrefixController: _pathPrefixController,
                    ),
                    const SizedBox(height: 26),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _PrimaryButton(
                        label: 'storageSettings.saveChanges',
                        icon: Symbols.check,
                        onPressed: _saving ? () {} : () => _saveSettings(),
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

class _StorageLayout extends StatelessWidget {
  const _StorageLayout({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 980) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [left, const SizedBox(height: 20), right],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 286, child: left),
            const SizedBox(width: 24),
            Expanded(child: right),
          ],
        );
      },
    );
  }
}

class _ActiveStorageCard extends StatelessWidget {
  const _ActiveStorageCard({
    required this.value,
    required this.localBackupEnabled,
    required this.onChanged,
    required this.onLocalBackupChanged,
  });

  final String value;
  final bool localBackupEnabled;
  final ValueChanged<String?> onChanged;
  final ValueChanged<bool> onLocalBackupChanged;

  static const _options = [
    'storageSettings.option.localStorage',
    'storageSettings.option.awsS3',
    'storageSettings.option.cloudflareR2',
    'storageSettings.option.backblazeB2',
    'storageSettings.option.bunnyNet',
    'storageSettings.option.googleDrive',
  ];

  @override
  Widget build(BuildContext context) {
    final showLocalBackup = value != 'storageSettings.option.localStorage';

    return _StorageCard(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardTitle('storageSettings.activeStorage.title'),
          const SizedBox(height: 32),
          _FullSelectField(
            label: 'storageSettings.field.storage',
            value: value,
            options: _options,
            onChanged: onChanged,
            isRequired: true,
          ),
          if (showLocalBackup) ...[
            const SizedBox(height: 20),
            _BackupSwitchRow(
              value: localBackupEnabled,
              onChanged: onLocalBackupChanged,
            ),
          ],
        ],
      ),
    );
  }
}

class _BackupSwitchRow extends StatelessWidget {
  const _BackupSwitchRow({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.t('storageSettings.localBackup.title'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.deepOcean,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.t('storageSettings.localBackup.description'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.inkSoft,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        _CompactCheckSwitch(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _ProviderSettingsCard extends StatelessWidget {
  const _ProviderSettingsCard({
    required this.selectedProvider,
    required this.onProviderChanged,
    required this.accessKeyController,
    required this.secretKeyController,
    required this.bucketController,
    required this.regionController,
    required this.pathPrefixController,
  });

  final _StorageProvider selectedProvider;
  final ValueChanged<_StorageProvider> onProviderChanged;
  final TextEditingController accessKeyController;
  final TextEditingController secretKeyController;
  final TextEditingController bucketController;
  final TextEditingController regionController;
  final TextEditingController pathPrefixController;

  @override
  Widget build(BuildContext context) {
    final fields = selectedProvider.fields(
      accessKeyController: accessKeyController,
      secretKeyController: secretKeyController,
      bucketController: bucketController,
      regionController: regionController,
      pathPrefixController: pathPrefixController,
    );

    return _StorageCard(
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StorageTabs(
            selected: selectedProvider,
            onSelected: onProviderChanged,
          ),
          const SizedBox(height: 30),
          for (final field in fields) ...[
            _FullTextField(
              label: field.label,
              hint: field.hint,
              controller: field.controller,
            ),
            if (field != fields.last) const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }
}

class _StorageTabs extends StatelessWidget {
  const _StorageTabs({required this.selected, required this.onSelected});

  final _StorageProvider selected;
  final ValueChanged<_StorageProvider> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final provider in _StorageProvider.values)
          _StorageTabButton(
            label: provider.labelKey,
            selected: provider == selected,
            onTap: () => onSelected(provider),
          ),
      ],
    );
  }
}

class _StorageTabButton extends StatelessWidget {
  const _StorageTabButton({
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
      height: 38,
      child: TextButton(
        onPressed: onTap,
        style:
            TextButton.styleFrom(
              backgroundColor: selected ? AppColors.actionRed : Colors.white,
              foregroundColor: selected ? Colors.white : AppColors.deepOcean,
              side: BorderSide(
                color: selected
                    ? AppColors.actionRed
                    : AppColors.line.withValues(alpha: 0.88),
              ),
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
        child: Text(context.t(label)),
      ),
    );
  }
}

class _StorageCard extends StatelessWidget {
  const _StorageCard({
    required this.child,
    this.padding = const EdgeInsets.all(24),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
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
      child: child,
    );
  }
}

class _CompactCheckSwitch extends StatelessWidget {
  const _CompactCheckSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: value,
      child: MouseRegion(
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
                        size: 13,
                      )
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      context.t(label),
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: AppColors.deepOcean,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
    );
  }
}

class _FullTextField extends StatelessWidget {
  const _FullTextField({
    required this.label,
    required this.hint,
    required this.controller,
  });

  final String label;
  final String hint;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 8),
        _TextInput(controller: controller, hint: hint),
      ],
    );
  }
}

class _FullSelectField extends StatelessWidget {
  const _FullSelectField({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.isRequired = false,
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String?> onChanged;
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FieldLabel(label, isRequired: isRequired),
        const SizedBox(height: 8),
        _SelectInput(value: value, options: options, onChanged: onChanged),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label, {this.isRequired = false});

  final String label;
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: AppColors.deepOcean,
      fontWeight: FontWeight.w700,
      letterSpacing: 0,
    );
    if (!isRequired) {
      return Text(
        context.t(label),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }

    return RichText(
      text: TextSpan(
        style: style,
        children: [
          TextSpan(text: context.t(label)),
          TextSpan(
            text: ' *',
            style: style?.copyWith(color: AppColors.actionRed),
          ),
        ],
      ),
    );
  }
}

class _TextInput extends StatelessWidget {
  const _TextInput({required this.controller, required this.hint});

  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: TextFormField(
        controller: controller,
        textAlignVertical: TextAlignVertical.center,
        mouseCursor: SystemMouseCursors.text,
        cursorColor: AppColors.support,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.deepOcean,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
        decoration: _inputDecoration(
          context,
        ).copyWith(hintText: context.t(hint)),
      ),
    );
  }
}

class _SelectInput extends StatelessWidget {
  const _SelectInput({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String value;
  final List<String> options;
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
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
            items: [
              for (final option in options)
                DropdownMenuItem(
                  value: option,
                  child: Text(
                    context.t(option),
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

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
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
            SymbolIcon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                context.t(label),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

InputDecoration _inputDecoration(BuildContext context) {
  return InputDecoration(
    isDense: true,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
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
      borderSide: const BorderSide(color: AppColors.actionRed),
    ),
    hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: AppColors.placeholder,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    ),
  );
}

class _StorageField {
  const _StorageField({
    required this.label,
    required this.hint,
    required this.controller,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
}

enum _StorageProvider {
  awsS3('awsS3', 'storageSettings.provider.awsS3'),
  cloudflareR2('cloudflareR2', 'storageSettings.provider.cloudflareR2'),
  backblazeB2('backblazeB2', 'storageSettings.provider.backblazeB2'),
  bunnyNet('bunnyNet', 'storageSettings.provider.bunnyNet'),
  googleDrive('googleDrive', 'storageSettings.provider.googleDrive');

  const _StorageProvider(this.id, this.labelKey);

  final String id;
  final String labelKey;

  static _StorageProvider fromId(String id) {
    return _StorageProvider.values.firstWhere(
      (provider) => provider.id == id,
      orElse: () => _StorageProvider.awsS3,
    );
  }

  static _StorageProvider? fromStorageOptionKey(String key) {
    return switch (key) {
      'storageSettings.option.awsS3' => _StorageProvider.awsS3,
      'storageSettings.option.cloudflareR2' => _StorageProvider.cloudflareR2,
      'storageSettings.option.backblazeB2' => _StorageProvider.backblazeB2,
      'storageSettings.option.bunnyNet' => _StorageProvider.bunnyNet,
      'storageSettings.option.googleDrive' => _StorageProvider.googleDrive,
      _ => null,
    };
  }

  List<String> get settingKeys {
    return switch (this) {
      _StorageProvider.awsS3 => [
        'accessKey',
        'secretKey',
        'bucketName',
        'region',
        'pathPrefix',
      ],
      _StorageProvider.cloudflareR2 => [
        'accountId',
        'accessKey',
        'secretKey',
        'bucketName',
        'pathPrefix',
      ],
      _StorageProvider.backblazeB2 => [
        'keyId',
        'applicationKey',
        'bucketName',
        'endpoint',
        'pathPrefix',
      ],
      _StorageProvider.bunnyNet => [
        'storageZoneName',
        'accessKey',
        'hostname',
        'pullZoneUrl',
      ],
      _StorageProvider.googleDrive => [
        'clientId',
        'clientSecret',
        'refreshToken',
        'folderId',
      ],
    };
  }

  List<_StorageField> fields({
    required TextEditingController accessKeyController,
    required TextEditingController secretKeyController,
    required TextEditingController bucketController,
    required TextEditingController regionController,
    required TextEditingController pathPrefixController,
  }) {
    return switch (this) {
      _StorageProvider.awsS3 => [
        _StorageField(
          label: 'storageSettings.field.accessKey',
          hint: 'storageSettings.hint.accessKey',
          controller: accessKeyController,
        ),
        _StorageField(
          label: 'storageSettings.field.secretKey',
          hint: 'storageSettings.hint.secretKey',
          controller: secretKeyController,
        ),
        _StorageField(
          label: 'storageSettings.field.bucketName',
          hint: 'storageSettings.hint.bucketName',
          controller: bucketController,
        ),
        _StorageField(
          label: 'storageSettings.field.region',
          hint: 'storageSettings.hint.region',
          controller: regionController,
        ),
        _StorageField(
          label: 'storageSettings.field.pathPrefix',
          hint: 'storageSettings.hint.pathPrefix',
          controller: pathPrefixController,
        ),
      ],
      _StorageProvider.cloudflareR2 => [
        _StorageField(
          label: 'storageSettings.field.accountId',
          hint: 'storageSettings.hint.accountId',
          controller: accessKeyController,
        ),
        _StorageField(
          label: 'storageSettings.field.accessKey',
          hint: 'storageSettings.hint.accessKey',
          controller: secretKeyController,
        ),
        _StorageField(
          label: 'storageSettings.field.secretKey',
          hint: 'storageSettings.hint.secretKey',
          controller: bucketController,
        ),
        _StorageField(
          label: 'storageSettings.field.bucketName',
          hint: 'storageSettings.hint.bucketName',
          controller: regionController,
        ),
        _StorageField(
          label: 'storageSettings.field.pathPrefix',
          hint: 'storageSettings.hint.pathPrefix',
          controller: pathPrefixController,
        ),
      ],
      _StorageProvider.backblazeB2 => [
        _StorageField(
          label: 'storageSettings.field.keyId',
          hint: 'storageSettings.hint.keyId',
          controller: accessKeyController,
        ),
        _StorageField(
          label: 'storageSettings.field.applicationKey',
          hint: 'storageSettings.hint.applicationKey',
          controller: secretKeyController,
        ),
        _StorageField(
          label: 'storageSettings.field.bucketName',
          hint: 'storageSettings.hint.bucketName',
          controller: bucketController,
        ),
        _StorageField(
          label: 'storageSettings.field.endpoint',
          hint: 'storageSettings.hint.endpoint',
          controller: regionController,
        ),
        _StorageField(
          label: 'storageSettings.field.pathPrefix',
          hint: 'storageSettings.hint.pathPrefix',
          controller: pathPrefixController,
        ),
      ],
      _StorageProvider.bunnyNet => [
        _StorageField(
          label: 'storageSettings.field.storageZoneName',
          hint: 'storageSettings.hint.storageZoneName',
          controller: accessKeyController,
        ),
        _StorageField(
          label: 'storageSettings.field.accessKey',
          hint: 'storageSettings.hint.accessKey',
          controller: secretKeyController,
        ),
        _StorageField(
          label: 'storageSettings.field.hostname',
          hint: 'storageSettings.hint.hostname',
          controller: bucketController,
        ),
        _StorageField(
          label: 'storageSettings.field.pullZoneUrl',
          hint: 'storageSettings.hint.pullZoneUrl',
          controller: regionController,
        ),
      ],
      _StorageProvider.googleDrive => [
        _StorageField(
          label: 'storageSettings.field.clientId',
          hint: 'storageSettings.hint.clientId',
          controller: accessKeyController,
        ),
        _StorageField(
          label: 'storageSettings.field.clientSecret',
          hint: 'storageSettings.hint.clientSecret',
          controller: secretKeyController,
        ),
        _StorageField(
          label: 'storageSettings.field.refreshToken',
          hint: 'storageSettings.hint.refreshToken',
          controller: bucketController,
        ),
        _StorageField(
          label: 'storageSettings.field.folderId',
          hint: 'storageSettings.hint.folderId',
          controller: regionController,
        ),
      ],
    };
  }
}
