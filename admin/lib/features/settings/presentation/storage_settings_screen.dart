import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../core/localization/admin_language_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/widgets/symbol_icon.dart';

class StorageSettingsScreen extends StatefulWidget {
  const StorageSettingsScreen({super.key});

  @override
  State<StorageSettingsScreen> createState() => _StorageSettingsScreenState();
}

class _StorageSettingsScreenState extends State<StorageSettingsScreen> {
  final _accessKeyController = TextEditingController();
  final _secretKeyController = TextEditingController();
  final _bucketController = TextEditingController();
  final _regionController = TextEditingController();

  var _activeStorage = 'storageSettings.option.localStorage';
  var _selectedProvider = _StorageProvider.awsS3;

  @override
  void dispose() {
    _accessKeyController.dispose();
    _secretKeyController.dispose();
    _bucketController.dispose();
    _regionController.dispose();
    super.dispose();
  }

  void _showSavedMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.t('storageSettings.saveSuccess'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 640 ? 16.0 : 28.0;

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
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _activeStorage = value);
                  },
                ),
                right: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ProviderSettingsCard(
                      selectedProvider: _selectedProvider,
                      onProviderChanged: (provider) {
                        setState(() => _selectedProvider = provider);
                      },
                      accessKeyController: _accessKeyController,
                      secretKeyController: _secretKeyController,
                      bucketController: _bucketController,
                      regionController: _regionController,
                    ),
                    const SizedBox(height: 26),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _PrimaryButton(
                        label: 'Save Changes',
                        icon: Symbols.check,
                        onPressed: _showSavedMessage,
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
  const _ActiveStorageCard({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String?> onChanged;

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
        ],
      ),
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
  });

  final _StorageProvider selectedProvider;
  final ValueChanged<_StorageProvider> onProviderChanged;
  final TextEditingController accessKeyController;
  final TextEditingController secretKeyController;
  final TextEditingController bucketController;
  final TextEditingController regionController;

  @override
  Widget build(BuildContext context) {
    final fields = selectedProvider.fields(
      accessKeyController: accessKeyController,
      secretKeyController: secretKeyController,
      bucketController: bucketController,
      regionController: regionController,
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
  awsS3('storageSettings.provider.awsS3'),
  cloudflareR2('storageSettings.provider.cloudflareR2'),
  backblazeB2('storageSettings.provider.backblazeB2'),
  bunnyNet('storageSettings.provider.bunnyNet'),
  googleDrive('storageSettings.provider.googleDrive');

  const _StorageProvider(this.labelKey);

  final String labelKey;

  List<_StorageField> fields({
    required TextEditingController accessKeyController,
    required TextEditingController secretKeyController,
    required TextEditingController bucketController,
    required TextEditingController regionController,
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
