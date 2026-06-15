import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../../core/localization/admin_language_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../shared/widgets/symbol_icon.dart';
import '../users_models.dart';

Future<RoleFormData?> showRoleFormDialog(
  BuildContext context, {
  ManagedRole? role,
}) {
  return showDialog<RoleFormData>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.34),
    builder: (context) =>
        _RoleDialogFrame(maxWidth: 520, child: _RoleFormDialog(role: role)),
  );
}

Future<List<String>?> showManagePermissionsDialog(
  BuildContext context, {
  required ManagedRole role,
  required List<AdminPermission> permissions,
}) {
  return showDialog<List<String>>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.34),
    builder: (context) => _RoleDialogFrame(
      maxWidth: 760,
      child: _ManagePermissionsDialog(role: role, permissions: permissions),
    ),
  );
}

class _RoleDialogFrame extends StatelessWidget {
  const _RoleDialogFrame({required this.maxWidth, required this.child});

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

class _RoleFormDialog extends StatefulWidget {
  const _RoleFormDialog({this.role});

  final ManagedRole? role;

  @override
  State<_RoleFormDialog> createState() => _RoleFormDialogState();
}

class _RoleFormDialogState extends State<_RoleFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _labelController;
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _colorController;

  bool get _editing => widget.role != null;

  @override
  void initState() {
    super.initState();
    final role = widget.role;
    _labelController = TextEditingController(text: role?.label ?? '');
    _nameController = TextEditingController(text: role?.name ?? '');
    _descriptionController = TextEditingController(
      text: role?.description ?? '',
    );
    _colorController = TextEditingController(text: role?.color ?? '#2C3E50');
  }

  @override
  void dispose() {
    _labelController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  void _submit() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    Navigator.of(context).pop(
      RoleFormData(
        name: _nameController.text.trim().toLowerCase(),
        label: _labelController.text.trim(),
        description: _descriptionController.text.trim(),
        color: _colorController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 26, 28, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ColoredDialogHeader(
              title: _editing ? 'Rol Düzenle' : 'Yeni Rol Tanımı',
              subtitle: _editing
                  ? 'Rol bilgilerini güncelleyin.'
                  : 'Yeni bir sistem rolü tanımlayın.',
              icon: _editing ? Symbols.edit_square : Symbols.add,
              backgroundColor: AppColors.actionRed,
            ),
            const SizedBox(height: 24),
            _DialogLineField(
              controller: _labelController,
              label: 'Rol Görünen Adı *',
              hintText: 'Örn: Kıdemli Editör',
              icon: Symbols.person,
              validator: _requiredValidator,
            ),
            const SizedBox(height: 22),
            _DialogLineField(
              controller: _nameController,
              label: 'Sistem Anahtarı (ID) *',
              hintText: 'Örn: senior_editor',
              icon: Symbols.short_text,
              validator: _roleNameValidator,
            ),
            const SizedBox(height: 22),
            _DialogLineField(
              controller: _colorController,
              label: 'Renk',
              hintText: '#2C3E50',
              icon: Symbols.verified,
              validator: _colorValidator,
            ),
            const SizedBox(height: 22),
            const _DialogSectionLabel('Rol Açıklaması'),
            const SizedBox(height: 12),
            _DescriptionTextArea(controller: _descriptionController),
            const SizedBox(height: 26),
            Align(
              alignment: Alignment.centerRight,
              child: _DialogFooter(
                primaryLabel: 'Kaydet',
                onPrimaryPressed: _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _requiredValidator(String? value) {
    return (value == null || value.trim().isEmpty)
        ? context.t('This field is required')
        : null;
  }

  String? _roleNameValidator(String? value) {
    final text = value?.trim().toLowerCase() ?? '';
    if (text.isEmpty) return context.t('This field is required');
    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(text)) {
      return context.t('Use only lowercase letters, numbers, and underscores');
    }
    return null;
  }

  String? _colorValidator(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    if (!RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(text)) {
      return context.t('Enter a valid hex color');
    }
    return null;
  }
}

class _ManagePermissionsDialog extends StatefulWidget {
  const _ManagePermissionsDialog({
    required this.role,
    required this.permissions,
  });

  final ManagedRole role;
  final List<AdminPermission> permissions;

  @override
  State<_ManagePermissionsDialog> createState() =>
      _ManagePermissionsDialogState();
}

class _ManagePermissionsDialogState extends State<_ManagePermissionsDialog> {
  late final Set<String> _enabledPermissionKeys;

  @override
  void initState() {
    super.initState();
    _enabledPermissionKeys = widget.role.permissionKeys.toSet();
  }

  int get _activeCount => _enabledPermissionKeys.length;

  void _toggle(String key) {
    if (widget.role.systemLocked) return;
    setState(() {
      if (_enabledPermissionKeys.contains(key)) {
        _enabledPermissionKeys.remove(key);
      } else {
        _enabledPermissionKeys.add(key);
      }
    });
  }

  void _submit() {
    Navigator.of(context).pop(_enabledPermissionKeys.toList(growable: false));
  }

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<AdminPermission>>{};
    for (final permission in widget.permissions) {
      grouped
          .putIfAbsent(permission.groupName, () => <AdminPermission>[])
          .add(permission);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 26, 28, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ColoredDialogHeader(
            title: context.t(
              'roles.permissionTitle',
              values: {'name': context.t(widget.role.label)},
            ),
            subtitle: context.t('Set permission and access boundaries.'),
            icon: Symbols.verified,
            backgroundColor: AppColors.inkSoft,
          ),
          if (widget.role.systemLocked) ...[
            const SizedBox(height: 18),
            const _AdminLockedNotice(),
          ],
          const SizedBox(height: 24),
          for (final entry in grouped.entries) ...[
            _PermissionGroupTitle(groupName: entry.key),
            const SizedBox(height: 10),
            _PermissionsGrid(
              permissions: entry.value,
              enabledPermissionKeys: _enabledPermissionKeys,
              locked: widget.role.systemLocked,
              onToggle: _toggle,
            ),
            const SizedBox(height: 18),
          ],
          Row(
            children: [
              Text(
                context.t(
                  'roles.permissionActiveCount',
                  values: {'count': _activeCount},
                ),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.inkSoft,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                ),
              ),
              const Spacer(),
              _DialogFooter(primaryLabel: 'Kaydet', onPrimaryPressed: _submit),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdminLockedNotice extends StatelessWidget {
  const _AdminLockedNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.actionRed.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.actionRed.withValues(alpha: 0.16)),
      ),
      child: Text(
        context.t('The Super Admin role is system locked.'),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.actionRed,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _PermissionGroupTitle extends StatelessWidget {
  const _PermissionGroupTitle({required this.groupName});

  final String groupName;

  @override
  Widget build(BuildContext context) {
    return Text(
      context.t(_groupLabel(groupName)),
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: AppColors.deepOcean,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
    );
  }
}

class _PermissionsGrid extends StatelessWidget {
  const _PermissionsGrid({
    required this.permissions,
    required this.enabledPermissionKeys,
    required this.locked,
    required this.onToggle,
  });

  final List<AdminPermission> permissions;
  final Set<String> enabledPermissionKeys;
  final bool locked;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
        final cells = [
          for (final permission in permissions)
            _PermissionCell(
              permission: permission,
              enabled: enabledPermissionKeys.contains(permission.key),
              locked: locked,
              onToggle: () => onToggle(permission.key),
            ),
        ];

        if (compact) {
          return Column(
            children: [
              for (var index = 0; index < cells.length; index++) ...[
                cells[index],
                if (index != cells.length - 1) const SizedBox(height: 10),
              ],
            ],
          );
        }

        final rows = <Widget>[];
        for (var i = 0; i < cells.length; i += 2) {
          rows.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: cells[i]),
                const SizedBox(width: 12),
                Expanded(
                  child: i + 1 < cells.length
                      ? cells[i + 1]
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          );
          if (i + 2 < cells.length) rows.add(const SizedBox(height: 10));
        }
        return Column(children: rows);
      },
    );
  }
}

class _PermissionCell extends StatelessWidget {
  const _PermissionCell({
    required this.permission,
    required this.enabled,
    required this.locked,
    required this.onToggle,
  });

  final AdminPermission permission;
  final bool enabled;
  final bool locked;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: locked ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: locked ? null : onToggle,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.value),
            border: Border.all(color: AppColors.line.withValues(alpha: 0.9)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.t(permission.label),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.deepOcean,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      context.t(permission.description),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.inkSoft,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _CompactSwitch(
                value: enabled,
                onToggle: locked ? null : onToggle,
              ),
            ],
          ),
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

class _ColoredDialogHeader extends StatelessWidget {
  const _ColoredDialogHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.backgroundColor,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(AppRadius.value),
          ),
          child: Center(child: SymbolIcon(icon, color: Colors.white, size: 20)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.t(title),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.deepOcean,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                context.t(subtitle),
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
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final IconData icon;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    final requiredField = label.contains('*');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DialogSectionLabel(
          label,
          color: requiredField ? AppColors.actionRed : AppColors.inkSoft,
        ),
        const SizedBox(height: 12),
        Container(
          constraints: const BoxConstraints(minHeight: 38),
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
                  validator: validator,
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
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DescriptionTextArea extends StatelessWidget {
  const _DescriptionTextArea({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line),
      ),
      padding: const EdgeInsets.all(12),
      child: TextField(
        controller: controller,
        minLines: 3,
        maxLines: 5,
        mouseCursor: SystemMouseCursors.text,
        cursorColor: AppColors.support,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.deepOcean,
          fontWeight: FontWeight.w500,
          letterSpacing: 0,
        ),
        decoration: InputDecoration(
          hintText: context.t(
            'Briefly describe this role\'s responsibilities...',
          ),
          hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.placeholder,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
          filled: false,
          hoverColor: Colors.transparent,
          focusColor: Colors.transparent,
        ),
      ),
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
      context.t(label),
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: color,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
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
          child: Text(context.t('Cancel')),
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
            child: Text(context.t(primaryLabel)),
          ),
        ),
      ],
    );
  }
}

String _groupLabel(String groupName) {
  return switch (groupName) {
    'sidebar' => 'Menü Erişimi',
    'content' => 'İçerik Yönetimi',
    'communication' => 'İletişim Modülleri',
    'settings' => 'Ayarlar',
    'system' => 'Sistem Araçları',
    _ => groupName,
  };
}
