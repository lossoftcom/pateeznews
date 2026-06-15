import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';
import 'package:pateeznews_admin/shared/widgets/admin_toast.dart';

import '../../../core/localization/admin_language_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/widgets/symbol_icon.dart';
import '../../auth/data/admin_auth_models.dart';
import '../data/admin_security_settings_repository.dart';

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({
    super.key,
    required this.session,
    this.repository = const SupabaseAdminSecuritySettingsRepository(),
  });

  final AdminSession session;
  final AdminSecuritySettingsRepository repository;

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  final _maxLoginAttemptsController = TextEditingController();
  final _lockoutMinutesController = TextEditingController();
  final _minPasswordLengthController = TextEditingController();
  final _captchaSiteKeyController = TextEditingController();
  final _captchaSecretKeyController = TextEditingController();

  var _complexityRequired = false;
  var _captchaEnabled = false;
  var _postContentPolicy = _SecurityPolicyOptions.nofollow;
  var _interactionContentPolicy = _SecurityPolicyOptions.removeLinks;
  var _captchaProvider = _CaptchaProvider.cloudflare;
  var _settings = AdminSecuritySettingsData.defaults('tr');
  var _loadingSettings = true;
  var _savingGeneral = false;
  var _savingCaptcha = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSettings());
  }

  @override
  void dispose() {
    _maxLoginAttemptsController.dispose();
    _lockoutMinutesController.dispose();
    _minPasswordLengthController.dispose();
    _captchaSiteKeyController.dispose();
    _captchaSecretKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _loadingSettings = true;
      _error = null;
    });
    try {
      final settings = await widget.repository.fetchSettings('tr');
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _applySettings(settings);
        _loadingSettings = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _settings = AdminSecuritySettingsData.defaults('tr');
        _applySettings(_settings);
        _error = error.toString();
        _loadingSettings = false;
      });
    }
  }

  void _applySettings(AdminSecuritySettingsData settings) {
    _maxLoginAttemptsController.text = '${settings.maxLoginAttempts}';
    _lockoutMinutesController.text = '${settings.lockoutMinutes}';
    _minPasswordLengthController.text = '${settings.passwordMinLength}';
    _complexityRequired = settings.passwordComplexityRequired;
    _postContentPolicy = _postPolicyKey(settings.spamPostPolicy);
    _interactionContentPolicy = _interactionPolicyKey(
      settings.spamInteractionPolicy,
    );
    _captchaEnabled = settings.captchaEnabled;
    _captchaProvider = _captchaProviderFromApi(settings.captchaProvider);
    _captchaSiteKeyController.text = settings.captchaSiteKey;
    _captchaSecretKeyController.text = settings.captchaSecretConfigured
        ? AdminSecuritySettingsData.secretMask
        : '';
  }

  void _showSavedMessage() {
    AdminToast.show(
      context,
      message: context.t('securitySettings.saveSuccess'),
      tone: AdminToastTone.success,
    );
  }

  void _showMessage(
    String message, {
    AdminToastTone tone = AdminToastTone.info,
  }) {
    AdminToast.show(context, message: message, tone: tone);
  }

  int? _readInt(
    TextEditingController controller, {
    required int min,
    required int max,
  }) {
    final value = int.tryParse(controller.text.trim());
    if (value == null || value < min || value > max) return null;
    return value;
  }

  Future<void> _saveGeneralSettings() async {
    if (_savingGeneral || _loadingSettings) return;
    final maxAttempts = _readInt(_maxLoginAttemptsController, min: 1, max: 20);
    final lockoutMinutes = _readInt(
      _lockoutMinutesController,
      min: 1,
      max: 1440,
    );
    final passwordMinLength = _readInt(
      _minPasswordLengthController,
      min: 4,
      max: 128,
    );
    if (maxAttempts == null ||
        lockoutMinutes == null ||
        passwordMinLength == null) {
      _showMessage(
        'Güvenlik sayısal değerleri geçerli aralıkta olmalı.',
        tone: AdminToastTone.error,
      );
      return;
    }

    setState(() => _savingGeneral = true);
    try {
      final saved = await widget.repository.saveSettings(
        session: widget.session,
        includeSecretKey: false,
        settings: _settings.copyWith(
          maxLoginAttempts: maxAttempts,
          lockoutMinutes: lockoutMinutes,
          passwordMinLength: passwordMinLength,
          passwordComplexityRequired: _complexityRequired,
          spamPostPolicy: _postPolicyApi(_postContentPolicy),
          spamInteractionPolicy: _interactionPolicyApi(
            _interactionContentPolicy,
          ),
        ),
      );
      if (!mounted) return;
      setState(() {
        _settings = saved;
        _applySettings(saved);
        _savingGeneral = false;
      });
      _showSavedMessage();
    } catch (error) {
      if (!mounted) return;
      setState(() => _savingGeneral = false);
      _showMessage(
        'Güvenlik ayarları kaydedilemedi: $error',
        tone: AdminToastTone.error,
      );
    }
  }

  Future<void> _saveCaptchaSettings() async {
    if (_savingCaptcha || _loadingSettings) return;
    final secretText = _captchaSecretKeyController.text.trim();
    final includeSecretKey =
        !(_settings.captchaSecretConfigured &&
            secretText == AdminSecuritySettingsData.secretMask);

    setState(() => _savingCaptcha = true);
    try {
      final saved = await widget.repository.saveSettings(
        session: widget.session,
        includeSecretKey: includeSecretKey,
        settings: _settings.copyWith(
          captchaEnabled: _captchaEnabled,
          captchaProvider: _captchaProvider.toApiValue(),
          captchaSiteKey: _captchaSiteKeyController.text.trim(),
          captchaSecretKey: secretText,
        ),
      );
      if (!mounted) return;
      setState(() {
        _settings = saved;
        _applySettings(saved);
        _savingCaptcha = false;
      });
      _showSavedMessage();
    } catch (error) {
      if (!mounted) return;
      setState(() => _savingCaptcha = false);
      _showMessage('Captcha ayarları kaydedilemedi: $error');
    }
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
              _SecurityHeader(
                title: context.t('securitySettings.title'),
                description: context.t('securitySettings.description'),
              ),
              const SizedBox(height: 22),
              if (_loadingSettings)
                const _SecurityLoadingPanel()
              else if (_error != null)
                _SecurityErrorPanel(message: _error!, onRetry: _loadSettings)
              else
                _SecurityContentGrid(
                  generalCard: _SecurityCard(
                    title: context.t('securitySettings.general.title'),
                    child: _GeneralSecurityPanel(
                      maxLoginAttemptsController: _maxLoginAttemptsController,
                      lockoutMinutesController: _lockoutMinutesController,
                      minPasswordLengthController: _minPasswordLengthController,
                      complexityRequired: _complexityRequired,
                      postContentPolicy: _postContentPolicy,
                      interactionContentPolicy: _interactionContentPolicy,
                      saving: _savingGeneral,
                      onComplexityChanged: (value) =>
                          setState(() => _complexityRequired = value),
                      onPostPolicyChanged: (value) {
                        if (value == null) return;
                        setState(() => _postContentPolicy = value);
                      },
                      onInteractionPolicyChanged: (value) {
                        if (value == null) return;
                        setState(() => _interactionContentPolicy = value);
                      },
                      onSave: _saveGeneralSettings,
                    ),
                  ),
                  captchaCard: _SecurityCard(
                    title: context.t('securitySettings.captcha.title'),
                    child: _CaptchaSettingsPanel(
                      enabled: _captchaEnabled,
                      provider: _captchaProvider,
                      siteKeyController: _captchaSiteKeyController,
                      secretKeyController: _captchaSecretKeyController,
                      saving: _savingCaptcha,
                      onEnabledChanged: (value) =>
                          setState(() => _captchaEnabled = value),
                      onProviderChanged: (provider) =>
                          setState(() => _captchaProvider = provider),
                      onSave: _saveCaptchaSettings,
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

class _SecurityHeader extends StatelessWidget {
  const _SecurityHeader({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Column(
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
          description,
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

class _SecurityLoadingPanel extends StatelessWidget {
  const _SecurityLoadingPanel();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 220,
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.deepOcean,
          ),
        ),
      ),
    );
  }
}

class _SecurityErrorPanel extends StatelessWidget {
  const _SecurityErrorPanel({required this.message, required this.onRetry});

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
          const SizedBox(width: 12),
          TextButton(
            onPressed: onRetry,
            style:
                TextButton.styleFrom(
                  foregroundColor: AppColors.actionRed,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
            child: Text(context.t('Retry')),
          ),
        ],
      ),
    );
  }
}

class _SecurityContentGrid extends StatelessWidget {
  const _SecurityContentGrid({
    required this.generalCard,
    required this.captchaCard,
  });

  final Widget generalCard;
  final Widget captchaCard;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 980) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [generalCard, const SizedBox(height: 18), captchaCard],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: generalCard),
            const SizedBox(width: 22),
            Expanded(child: captchaCard),
          ],
        );
      },
    );
  }
}

class _SecurityCard extends StatelessWidget {
  const _SecurityCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 560),
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
          _SecurityCardTitle(title),
          const SizedBox(height: 28),
          child,
        ],
      ),
    );
  }
}

class _SecurityCardTitle extends StatelessWidget {
  const _SecurityCardTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        color: AppColors.deepOcean,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
    );
  }
}

class _GeneralSecurityPanel extends StatelessWidget {
  const _GeneralSecurityPanel({
    required this.maxLoginAttemptsController,
    required this.lockoutMinutesController,
    required this.minPasswordLengthController,
    required this.complexityRequired,
    required this.postContentPolicy,
    required this.interactionContentPolicy,
    required this.saving,
    required this.onComplexityChanged,
    required this.onPostPolicyChanged,
    required this.onInteractionPolicyChanged,
    required this.onSave,
  });

  final TextEditingController maxLoginAttemptsController;
  final TextEditingController lockoutMinutesController;
  final TextEditingController minPasswordLengthController;
  final bool complexityRequired;
  final String postContentPolicy;
  final String interactionContentPolicy;
  final bool saving;
  final ValueChanged<bool> onComplexityChanged;
  final ValueChanged<String?> onPostPolicyChanged;
  final ValueChanged<String?> onInteractionPolicyChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SecuritySection(
          title: context.t('securitySettings.login.title'),
          child: _SecurityFieldRow(
            children: [
              _SecurityTextField(
                label: 'securitySettings.login.maxAttempts',
                helper: 'securitySettings.login.maxAttemptsHelp',
                controller: maxLoginAttemptsController,
                isRequired: true,
                keyboardType: TextInputType.number,
              ),
              _SecurityTextField(
                label: 'securitySettings.login.lockoutTime',
                helper: 'securitySettings.login.lockoutTimeHelp',
                controller: lockoutMinutesController,
                isRequired: true,
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        _SecuritySection(
          title: context.t('securitySettings.password.title'),
          child: _SecurityFieldRow(
            children: [
              _SecurityTextField(
                label: 'securitySettings.password.minLength',
                helper: 'securitySettings.password.minLengthHelp',
                controller: minPasswordLengthController,
                isRequired: true,
                keyboardType: TextInputType.number,
              ),
              _ComplexityRequirementControl(
                value: complexityRequired,
                onChanged: onComplexityChanged,
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        _SecuritySection(
          title: context.t('securitySettings.spam.title'),
          description: context.t('securitySettings.spam.description'),
          child: Column(
            children: [
              _SecurityPolicySelectRow(
                label: 'securitySettings.spam.postContent',
                value: postContentPolicy,
                options: _SecurityPolicyOptions.postContentOptions,
                onChanged: onPostPolicyChanged,
              ),
              const SizedBox(height: 18),
              _SecurityPolicySelectRow(
                label: 'securitySettings.spam.publicInteraction',
                value: interactionContentPolicy,
                options: _SecurityPolicyOptions.interactionOptions,
                onChanged: onInteractionPolicyChanged,
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        _SecuritySaveRow(onPressed: onSave, saving: saving),
      ],
    );
  }
}

class _CaptchaSettingsPanel extends StatelessWidget {
  const _CaptchaSettingsPanel({
    required this.enabled,
    required this.provider,
    required this.siteKeyController,
    required this.secretKeyController,
    required this.saving,
    required this.onEnabledChanged,
    required this.onProviderChanged,
    required this.onSave,
  });

  final bool enabled;
  final _CaptchaProvider provider;
  final TextEditingController siteKeyController;
  final TextEditingController secretKeyController;
  final bool saving;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<_CaptchaProvider> onProviderChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StatusControl(value: enabled, onChanged: onEnabledChanged),
        const SizedBox(height: 22),
        _CaptchaProviderSelector(
          selected: provider,
          onChanged: onProviderChanged,
        ),
        const SizedBox(height: 22),
        _SecurityTextField(
          label: 'securitySettings.captcha.siteKey',
          controller: siteKeyController,
        ),
        const SizedBox(height: 18),
        _SecurityTextField(
          label: 'securitySettings.captcha.secretKey',
          controller: secretKeyController,
          obscureText: true,
        ),
        const SizedBox(height: 20),
        _SecuritySaveRow(onPressed: onSave, saving: saving),
        const SizedBox(height: 22),
        const _CaptchaWarningBox(),
      ],
    );
  }
}

class _SecuritySection extends StatelessWidget {
  const _SecuritySection({
    required this.title,
    required this.child,
    this.description,
  });

  final String title;
  final String? description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppColors.deepOcean,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 14),
        Divider(height: 1, color: AppColors.line.withValues(alpha: 0.86)),
        if (description != null) ...[
          const SizedBox(height: 14),
          Text(
            description!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.placeholder,
              fontWeight: FontWeight.w700,
              height: 1.45,
              letterSpacing: 0,
            ),
          ),
        ],
        const SizedBox(height: 18),
        child,
      ],
    );
  }
}

class _SecurityFieldRow extends StatelessWidget {
  const _SecurityFieldRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 620) {
          return Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(height: 18),
                children[i],
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(width: 16),
              Expanded(child: children[i]),
            ],
          ],
        );
      },
    );
  }
}

class _SecurityTextField extends StatelessWidget {
  const _SecurityTextField({
    required this.label,
    required this.controller,
    this.helper,
    this.isRequired = false,
    this.obscureText = false,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final String? helper;
  final bool isRequired;
  final bool obscureText;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SecurityFieldLabel(label: label, isRequired: isRequired),
        const SizedBox(height: 8),
        SizedBox(
          height: 42,
          child: TextFormField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            textAlignVertical: TextAlignVertical.center,
            mouseCursor: SystemMouseCursors.text,
            cursorColor: AppColors.support,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.deepOcean,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
            decoration: _securityInputDecoration(context),
          ),
        ),
        if (helper != null) ...[
          const SizedBox(height: 7),
          Text(
            context.t(helper!),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.placeholder,
              fontWeight: FontWeight.w600,
              height: 1.35,
              letterSpacing: 0,
            ),
          ),
        ],
      ],
    );
  }
}

class _SecurityFieldLabel extends StatelessWidget {
  const _SecurityFieldLabel({required this.label, this.isRequired = false});

  final String label;
  final bool isRequired;

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
        if (isRequired) ...[
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

class _ComplexityRequirementControl extends StatelessWidget {
  const _ComplexityRequirementControl({
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SecurityFieldLabel(
          label: 'securitySettings.password.complexityRequirement',
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SecurityCompactSwitch(value: value, onChanged: onChanged),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.t('securitySettings.password.complexityLabel'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.placeholder,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          context.t('securitySettings.password.complexityHelp'),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.placeholder,
            fontWeight: FontWeight.w600,
            height: 1.45,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _SecurityPolicySelectRow extends StatelessWidget {
  const _SecurityPolicySelectRow({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final labelWidget = Text(
          context.t(label),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.deepOcean,
            fontWeight: FontWeight.w700,
            height: 1.35,
            letterSpacing: 0,
          ),
        );
        final select = _SecuritySelectField(
          value: value,
          options: options,
          onChanged: onChanged,
        );

        if (constraints.maxWidth < 620) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [labelWidget, const SizedBox(height: 8), select],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: labelWidget),
            const SizedBox(width: 18),
            SizedBox(width: 340, child: select),
          ],
        );
      },
    );
  }
}

class _SecuritySelectField extends StatelessWidget {
  const _SecuritySelectField({
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
        height: 44,
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
                DropdownMenuItem(value: option, child: Text(context.t(option))),
            ],
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}

class _StatusControl extends StatelessWidget {
  const _StatusControl({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          context.t('securitySettings.captcha.status'),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.deepOcean,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(width: 18),
        _SecurityCompactSwitch(value: value, onChanged: onChanged),
        const SizedBox(width: 8),
        Text(
          context.t('securitySettings.captcha.enable'),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.placeholder,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _CaptchaProviderSelector extends StatelessWidget {
  const _CaptchaProviderSelector({
    required this.selected,
    required this.onChanged,
  });

  final _CaptchaProvider selected;
  final ValueChanged<_CaptchaProvider> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line.withValues(alpha: 0.86)),
      ),
      child: Row(
        children: [
          for (final provider in _CaptchaProvider.values)
            Expanded(
              child: _CaptchaProviderButton(
                label: provider.labelKey,
                selected: selected == provider,
                onTap: () => onChanged(provider),
              ),
            ),
        ],
      ),
    );
  }
}

class _CaptchaProviderButton extends StatelessWidget {
  const _CaptchaProviderButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
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
          duration: const Duration(milliseconds: 140),
          height: double.infinity,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.deepOcean : Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.value),
          ),
          child: Text(
            context.t(label),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: selected ? Colors.white : AppColors.deepOcean,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ),
      ),
    );
  }
}

class _SecurityCompactSwitch extends StatelessWidget {
  const _SecurityCompactSwitch({required this.value, required this.onChanged});

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
                        size: 12,
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

class _SecuritySaveRow extends StatelessWidget {
  const _SecuritySaveRow({required this.onPressed, this.saving = false});

  final VoidCallback onPressed;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        height: 38,
        child: TextButton(
          onPressed: saving ? null : onPressed,
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
              if (saving)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              else
                const SymbolIcon(Symbols.check, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text(context.t('securitySettings.saveChanges')),
            ],
          ),
        ),
      ),
    );
  }
}

class _CaptchaWarningBox extends StatelessWidget {
  const _CaptchaWarningBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.actionRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.actionRed.withValues(alpha: 0.14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.actionRed.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.value),
            ),
            child: const SymbolIcon(
              Symbols.warning,
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
                  context.t('securitySettings.warning.title'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.actionRed,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.t('securitySettings.warning.description'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.deepOcean,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

InputDecoration _securityInputDecoration(BuildContext context) {
  return InputDecoration(
    filled: true,
    fillColor: Colors.white,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
      borderSide: BorderSide(color: AppColors.deepOcean.withValues(alpha: 0.4)),
    ),
  );
}

class _SecurityPolicyOptions {
  const _SecurityPolicyOptions._();

  static const nofollow = 'securitySettings.option.nofollow';
  static const removeLinks = 'securitySettings.option.removeLinks';
  static const sanitizeHtml = 'securitySettings.option.sanitizeHtml';
  static const allowTrusted = 'securitySettings.option.allowTrusted';

  static const postContentOptions = [nofollow, sanitizeHtml, allowTrusted];
  static const interactionOptions = [removeLinks, nofollow, sanitizeHtml];
}

enum _CaptchaProvider {
  cloudflare('securitySettings.captcha.cloudflare'),
  recaptcha('securitySettings.captcha.recaptcha');

  const _CaptchaProvider(this.labelKey);

  final String labelKey;

  String toApiValue() {
    return switch (this) {
      _CaptchaProvider.cloudflare => 'cloudflare_turnstile',
      _CaptchaProvider.recaptcha => 'google_recaptcha',
    };
  }
}

String _postPolicyKey(String value) {
  return switch (value) {
    'sanitize_html' => _SecurityPolicyOptions.sanitizeHtml,
    'allow_trusted' => _SecurityPolicyOptions.allowTrusted,
    _ => _SecurityPolicyOptions.nofollow,
  };
}

String _postPolicyApi(String value) {
  return switch (value) {
    _SecurityPolicyOptions.sanitizeHtml => 'sanitize_html',
    _SecurityPolicyOptions.allowTrusted => 'allow_trusted',
    _ => 'nofollow',
  };
}

String _interactionPolicyKey(String value) {
  return switch (value) {
    'nofollow' => _SecurityPolicyOptions.nofollow,
    'sanitize_html' => _SecurityPolicyOptions.sanitizeHtml,
    _ => _SecurityPolicyOptions.removeLinks,
  };
}

String _interactionPolicyApi(String value) {
  return switch (value) {
    _SecurityPolicyOptions.nofollow => 'nofollow',
    _SecurityPolicyOptions.sanitizeHtml => 'sanitize_html',
    _ => 'remove_links',
  };
}

_CaptchaProvider _captchaProviderFromApi(String value) {
  return value == 'google_recaptcha'
      ? _CaptchaProvider.recaptcha
      : _CaptchaProvider.cloudflare;
}
