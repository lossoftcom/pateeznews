import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/constants/turkey_cities.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../../core/localization/admin_language_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../shared/widgets/symbol_icon.dart';
import '../users_models.dart';

Future<UserFormData?> showUserFormDialog(
  BuildContext context, {
  required List<AdminUserRole> roles,
  ManagedUser? user,
}) {
  return showDialog<UserFormData>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.34),
    builder: (context) => _UserDialogFrame(
      maxWidth: 820,
      child: _UserFormDialog(roles: roles, user: user),
    ),
  );
}

class _UserDialogFrame extends StatelessWidget {
  const _UserDialogFrame({required this.maxWidth, required this.child});

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

class _UserFormDialog extends StatefulWidget {
  const _UserFormDialog({required this.roles, this.user});

  final List<AdminUserRole> roles;
  final ManagedUser? user;

  @override
  State<_UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<_UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullNameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmPasswordController;
  late String _role;
  late String _status;
  late String _city;
  late bool _rewardEnabled;

  bool get _editing => widget.user != null;

  @override
  void initState() {
    super.initState();
    final user = widget.user;
    _fullNameController = TextEditingController(text: user?.fullName ?? '');
    _usernameController = TextEditingController(text: user?.username ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
    _role = user?.role ?? _firstRole;
    _status = user?.status ?? 'Aktif';
    _city = normalizeTurkeyCity(user?.city ?? defaultTurkeyCity);
    _rewardEnabled = user?.rewardEnabled ?? false;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String get _firstRole {
    if (widget.roles.isEmpty) return 'member';
    return widget.roles.first.name;
  }

  void _submit() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    Navigator.of(context).pop(
      UserFormData(
        fullName: _fullNameController.text.trim(),
        username: _usernameController.text.trim(),
        email: _emailController.text.trim().toLowerCase(),
        city: _city,
        role: _role,
        status: _status,
        rewardEnabled: _rewardEnabled,
        password: _passwordController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _editing ? 'Kullanıcı Düzenle' : 'Kullanıcı Ekle';
    final subtitle = _editing
        ? 'Kullanıcı bilgilerini güncelleyin.'
        : 'Yeni bir yönetim kullanıcısı tanımlayın.';

    return Form(
      key: _formKey,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 26, 28, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DialogHeader(title: title, subtitle: subtitle),
            const SizedBox(height: 22),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 680;
                final nameField = _DialogLineField(
                  controller: _fullNameController,
                  label: 'Ad Soyad *',
                  hintText: 'Ad Soyad...',
                  icon: Symbols.person,
                  validator: _requiredValidator,
                );
                final accountFields = Column(
                  children: [
                    _DialogLineField(
                      controller: _usernameController,
                      label: 'Kullanıcı Adı *',
                      hintText: 'kullaniciadi',
                      icon: Symbols.alternate_email,
                      validator: _requiredValidator,
                    ),
                    const SizedBox(height: 22),
                    _DialogSelectLineField(
                      label: 'Rol',
                      value: _role,
                      icon: Symbols.group,
                      items: [
                        for (final role in widget.roles)
                          DropdownMenuItem(
                            value: role.name,
                            child: Text(context.t(role.label)),
                          ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _role = value);
                      },
                    ),
                    const SizedBox(height: 22),
                    _DialogLineField(
                      controller: _passwordController,
                      label: _editing ? 'Şifre' : 'Şifre *',
                      hintText: _editing
                          ? 'Değişmeyecekse boş bırakın'
                          : '********',
                      icon: Symbols.lock,
                      obscureText: true,
                      validator: _passwordValidator,
                    ),
                  ],
                );
                final statusFields = Column(
                  children: [
                    _DialogLineField(
                      controller: _emailController,
                      label: 'E-posta *',
                      hintText: 'E-posta...',
                      icon: Symbols.alternate_email,
                      keyboardType: TextInputType.emailAddress,
                      validator: _emailValidator,
                    ),
                    const SizedBox(height: 22),
                    _DialogSelectLineField(
                      label: 'Şehir',
                      value: _city,
                      icon: Symbols.location_on_rounded,
                      items: [
                        for (final city in turkeyCities)
                          DropdownMenuItem(value: city, child: Text(city)),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _city = normalizeTurkeyCity(value));
                      },
                    ),
                    const SizedBox(height: 22),
                    _DialogSelectLineField(
                      label: 'Durum',
                      value: _status,
                      icon: Symbols.verified,
                      items: [
                        DropdownMenuItem(
                          value: 'Aktif',
                          child: Text(context.t('Active')),
                        ),
                        DropdownMenuItem(
                          value: 'Beklemede',
                          child: Text(context.t('Pending')),
                        ),
                        DropdownMenuItem(
                          value: 'Engelli',
                          child: Text(context.t('Disabled')),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _status = value);
                      },
                    ),
                    const SizedBox(height: 22),
                    _DialogLineField(
                      controller: _confirmPasswordController,
                      label: _editing ? 'Onayla' : 'Onayla *',
                      hintText: _editing
                          ? 'Değişmeyecekse boş bırakın'
                          : '********',
                      icon: Symbols.lock,
                      obscureText: true,
                      validator: _confirmPasswordValidator,
                    ),
                  ],
                );

                if (compact) {
                  return Column(
                    children: [
                      nameField,
                      const SizedBox(height: 22),
                      accountFields,
                      const SizedBox(height: 22),
                      statusFields,
                    ],
                  );
                }

                return Column(
                  children: [
                    nameField,
                    const SizedBox(height: 22),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: accountFields),
                        const SizedBox(width: 24),
                        Expanded(child: statusFields),
                      ],
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            _RewardCheckboxRow(
              value: _rewardEnabled,
              onChanged: (value) =>
                  setState(() => _rewardEnabled = value ?? false),
            ),
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

  String? _emailValidator(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return context.t('This field is required');
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text)) {
      return context.t('Enter a valid email');
    }
    return null;
  }

  String? _passwordValidator(String? value) {
    final text = value ?? '';
    if (!_editing && text.isEmpty) return context.t('This field is required');
    if (text.isNotEmpty && text.length < 6) {
      return context.t('Password must be at least 6 characters');
    }
    return null;
  }

  String? _confirmPasswordValidator(String? value) {
    final text = value ?? '';
    if (!_editing && text.isEmpty) return context.t('This field is required');
    if (_passwordController.text != text) {
      return context.t('Passwords do not match');
    }
    return null;
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
                context.t(title),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.deepOcean,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 6),
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
    this.keyboardType,
    this.obscureText = false,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
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
                  keyboardType: keyboardType,
                  obscureText: obscureText,
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

class _DialogSelectLineField extends StatelessWidget {
  const _DialogSelectLineField({
    required this.label,
    required this.value,
    required this.icon,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String value;
  final IconData icon;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final safeValue = items.any((item) => item.value == value)
        ? value
        : (items.isEmpty ? null : items.first.value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DialogSectionLabel(label),
        const SizedBox(height: 12),
        Container(
          height: 38,
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.line)),
          ),
          child: Row(
            children: [
              SymbolIcon(icon, color: AppColors.placeholder, size: 19),
              const SizedBox(width: 12),
              Expanded(
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
            ],
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
      context.t(label),
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: color,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
    );
  }
}

class _RewardCheckboxRow extends StatelessWidget {
  const _RewardCheckboxRow({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: Checkbox(
                value: value,
                mouseCursor: SystemMouseCursors.click,
                activeColor: AppColors.deepOcean,
                checkColor: Colors.white,
                side: BorderSide(color: AppColors.line.withValues(alpha: 0.76)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.value),
                ),
                onChanged: onChanged,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              context.t('Enable reward system'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.inkSoft,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
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
            child: Text(context.t(primaryLabel)),
          ),
        ),
      ],
    );
  }
}
