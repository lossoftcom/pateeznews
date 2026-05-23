import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../core/localization/admin_language_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/widgets/symbol_icon.dart';
import '../../auth/data/admin_auth_models.dart';
import '../data/admin_general_settings_repository.dart';
import '../data/admin_language_models.dart';

class GeneralSettingsScreen extends StatefulWidget {
  const GeneralSettingsScreen({
    super.key,
    required this.session,
    this.repository = const NeonAdminGeneralSettingsRepository(),
  });

  final AdminSession session;
  final AdminGeneralSettingsRepository repository;

  @override
  State<GeneralSettingsScreen> createState() => _GeneralSettingsScreenState();
}

class _GeneralSettingsScreenState extends State<GeneralSettingsScreen> {
  final _form = _GeneralSettingsForm();
  var _selectedTab = _GeneralSettingsTab.general;
  var _settingsLanguageCode = 'tr';
  var _settings = GeneralSettingsData.empty('tr');
  var _timezone = 'Europe/Istanbul';
  var _loading = true;
  var _saving = false;
  String? _error;
  GeneralSettingsLogoField? _uploadingField;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSettings());
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  Future<void> _loadSettings({String? languageCode}) async {
    final targetCode = (languageCode ?? _settingsLanguageCode).trim();
    setState(() {
      _settingsLanguageCode = targetCode.isEmpty ? 'tr' : targetCode;
      _loading = true;
      _error = null;
    });

    try {
      final settings = await widget.repository.fetchSettings(
        _settingsLanguageCode,
      );
      if (!mounted) return;
      _applySettings(settings);
      setState(() {
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _settings = GeneralSettingsData.empty(_settingsLanguageCode);
        _timezone = 'Europe/Istanbul';
        _form.apply(_settings);
        _error = error.toString();
        _loading = false;
      });
    }
  }

  void _applySettings(GeneralSettingsData settings) {
    _settings = settings;
    _timezone = settings.timezone.trim().isEmpty
        ? 'Europe/Istanbul'
        : settings.timezone;
    _form.apply(settings);
  }

  GeneralSettingsData _currentSettings() {
    return _form
        .toSettings(_settings)
        .copyWith(languageCode: _settingsLanguageCode, timezone: _timezone);
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
      _showMessage('settings.save_success');
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage('${context.t('settings.save_error')}: $error');
    }
  }

  Future<void> _uploadLogo(GeneralSettingsLogoField field) async {
    if (_loading || _saving || _uploadingField != null) return;
    final file = await openFile(
      acceptedTypeGroups: [
        XTypeGroup(
          label: 'Images',
          extensions: field == GeneralSettingsLogoField.faviconUrl
              ? const ['png', 'jpg', 'jpeg', 'svg', 'webp', 'ico']
              : const ['png', 'jpg', 'jpeg', 'svg', 'webp'],
        ),
      ],
    );
    if (file == null) return;

    setState(() => _uploadingField = field);
    try {
      final src = await widget.repository.uploadLogo(
        languageCode: _settingsLanguageCode,
        field: field,
        fileName: file.name,
        bytes: await file.readAsBytes(),
      );
      if (!mounted) return;
      setState(() {
        _settings = _settingsWithLogo(_currentSettings(), field, src);
        _form.apply(_settings);
        _uploadingField = null;
      });
      _showMessage('settings.upload_success');
    } catch (error) {
      if (!mounted) return;
      setState(() => _uploadingField = null);
      _showMessage('${context.t('settings.upload_error')}: $error');
    }
  }

  GeneralSettingsData _settingsWithLogo(
    GeneralSettingsData settings,
    GeneralSettingsLogoField field,
    String value,
  ) {
    return switch (field) {
      GeneralSettingsLogoField.logoUrl => settings.copyWith(logoUrl: value),
      GeneralSettingsLogoField.footerLogoUrl => settings.copyWith(
        footerLogoUrl: value,
      ),
      GeneralSettingsLogoField.darkLogoUrl => settings.copyWith(
        darkLogoUrl: value,
      ),
      GeneralSettingsLogoField.emailLogoUrl => settings.copyWith(
        emailLogoUrl: value,
      ),
      GeneralSettingsLogoField.faviconUrl => settings.copyWith(
        faviconUrl: value,
      ),
      GeneralSettingsLogoField.ogImageUrl => settings.copyWith(
        ogImageUrl: value,
      ),
    };
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.t(message))));
  }

  @override
  Widget build(BuildContext context) {
    final languageController = AdminLocalizationScope.of(context);
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
                context.t('General Settings'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.deepOcean,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 18),
              _SettingsLanguageSelect(
                value: _settingsLanguageCode,
                languages: languageController.availableLanguages,
                enabled: !_loading && !_saving && _uploadingField == null,
                onChanged: (value) {
                  if (value == null || value == _settingsLanguageCode) return;
                  unawaited(_loadSettings(languageCode: value));
                },
              ),
              const SizedBox(height: 22),
              _SettingsTabs(
                selected: _selectedTab,
                onSelected: (tab) => setState(() => _selectedTab = tab),
              ),
              const SizedBox(height: 22),
              _SettingsCard(
                title: _selectedTab.title,
                child: _GeneralSettingsTabView(
                  tab: _selectedTab,
                  form: _form,
                  settings: _currentSettings(),
                  loading: _loading,
                  saving: _saving,
                  error: _error,
                  timezone: _timezone,
                  uploadingField: _uploadingField,
                  publicUrl: widget.repository.publicUrl,
                  onRetry: () => unawaited(_loadSettings()),
                  onSave: () => unawaited(_saveSettings()),
                  onTimezoneChanged: (value) {
                    if (value == null) return;
                    setState(() => _timezone = value);
                  },
                  onUploadLogo: (field) => unawaited(_uploadLogo(field)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GeneralSettingsForm {
  final siteName = TextEditingController();
  final footerAbout = TextEditingController();
  final optionalUrlButtonName = TextEditingController();
  final copyrightText = TextEditingController();
  final homeTitle = TextEditingController();
  final metaDescription = TextEditingController();
  final metaKeywords = TextEditingController();
  final canonicalUrl = TextEditingController();
  final ogImageUrl = TextEditingController();
  final organizationLegalName = TextEditingController();
  final organizationPhone = TextEditingController();
  final organizationAddress = TextEditingController();
  final twitterUsername = TextEditingController();
  final fbAppId = TextEditingController();
  final googleAnalyticsId = TextEditingController();
  final googleSearchConsoleCode = TextEditingController();
  final bingVerificationCode = TextEditingController();
  final robotsTxt = TextEditingController();
  final headerCustomCodes = TextEditingController();
  final footerCustomCodes = TextEditingController();

  void apply(GeneralSettingsData settings) {
    siteName.text = settings.siteName;
    footerAbout.text = settings.footerAbout;
    optionalUrlButtonName.text = settings.optionalUrlButtonName;
    copyrightText.text = settings.copyrightText;
    homeTitle.text = settings.homeTitle;
    metaDescription.text = settings.metaDescription;
    metaKeywords.text = settings.metaKeywords;
    canonicalUrl.text = settings.canonicalUrl;
    ogImageUrl.text = settings.ogImageUrl;
    organizationLegalName.text = settings.organizationLegalName;
    organizationPhone.text = settings.organizationPhone;
    organizationAddress.text = settings.organizationAddress;
    twitterUsername.text = settings.twitterUsername;
    fbAppId.text = settings.fbAppId;
    googleAnalyticsId.text = settings.googleAnalyticsId;
    googleSearchConsoleCode.text = settings.googleSearchConsoleCode;
    bingVerificationCode.text = settings.bingVerificationCode;
    robotsTxt.text = settings.robotsTxt;
    headerCustomCodes.text = settings.headerCustomCodes;
    footerCustomCodes.text = settings.footerCustomCodes;
  }

  GeneralSettingsData toSettings(GeneralSettingsData base) {
    return base.copyWith(
      siteName: siteName.text,
      footerAbout: footerAbout.text,
      optionalUrlButtonName: optionalUrlButtonName.text,
      copyrightText: copyrightText.text,
      homeTitle: homeTitle.text,
      metaDescription: metaDescription.text,
      metaKeywords: metaKeywords.text,
      canonicalUrl: canonicalUrl.text,
      ogImageUrl: ogImageUrl.text,
      organizationLegalName: organizationLegalName.text,
      organizationPhone: organizationPhone.text,
      organizationAddress: organizationAddress.text,
      twitterUsername: twitterUsername.text,
      fbAppId: fbAppId.text,
      googleAnalyticsId: googleAnalyticsId.text,
      googleSearchConsoleCode: googleSearchConsoleCode.text,
      bingVerificationCode: bingVerificationCode.text,
      robotsTxt: robotsTxt.text,
      headerCustomCodes: headerCustomCodes.text,
      footerCustomCodes: footerCustomCodes.text,
    );
  }

  void dispose() {
    siteName.dispose();
    footerAbout.dispose();
    optionalUrlButtonName.dispose();
    copyrightText.dispose();
    homeTitle.dispose();
    metaDescription.dispose();
    metaKeywords.dispose();
    canonicalUrl.dispose();
    ogImageUrl.dispose();
    organizationLegalName.dispose();
    organizationPhone.dispose();
    organizationAddress.dispose();
    twitterUsername.dispose();
    fbAppId.dispose();
    googleAnalyticsId.dispose();
    googleSearchConsoleCode.dispose();
    bingVerificationCode.dispose();
    robotsTxt.dispose();
    headerCustomCodes.dispose();
    footerCustomCodes.dispose();
  }
}

class _SettingsLanguageSelect extends StatelessWidget {
  const _SettingsLanguageSelect({
    required this.value,
    required this.languages,
    required this.enabled,
    required this.onChanged,
  });

  final String value;
  final List<AdminLanguage> languages;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = [
      for (final language in languages)
        DropdownMenuItem(
          value: language.code,
          child: Text(context.t(language.name)),
        ),
      if (languages.every((language) => language.code != value))
        DropdownMenuItem(value: value, child: Text(value.toUpperCase())),
    ];

    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _FieldLabel('Ayarları Dili'),
          const SizedBox(height: 8),
          MouseRegion(
            cursor: enabled
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
            child: Container(
              height: 42,
              width: 280,
              padding: const EdgeInsets.only(left: 12, right: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.value),
                border: Border.all(color: AppColors.line),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: value,
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
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                  items: items,
                  onChanged: enabled ? onChanged : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTabs extends StatelessWidget {
  const _SettingsTabs({required this.selected, required this.onSelected});

  final _GeneralSettingsTab selected;
  final ValueChanged<_GeneralSettingsTab> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final tab in _GeneralSettingsTab.values)
          _SettingsTabButton(
            label: tab.title,
            selected: selected == tab,
            onTap: () => onSelected(tab),
          ),
      ],
    );
  }
}

class _SettingsTabButton extends StatelessWidget {
  const _SettingsTabButton({
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

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.title, required this.child});

  final String title;
  final Widget child;

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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [_SectionTitle(title), const SizedBox(height: 24), child],
      ),
    );
  }
}

class _GeneralSettingsTabView extends StatelessWidget {
  const _GeneralSettingsTabView({
    required this.tab,
    required this.form,
    required this.settings,
    required this.loading,
    required this.saving,
    required this.error,
    required this.timezone,
    required this.uploadingField,
    required this.publicUrl,
    required this.onRetry,
    required this.onSave,
    required this.onTimezoneChanged,
    required this.onUploadLogo,
  });

  final _GeneralSettingsTab tab;
  final _GeneralSettingsForm form;
  final GeneralSettingsData settings;
  final bool loading;
  final bool saving;
  final String? error;
  final String timezone;
  final GeneralSettingsLogoField? uploadingField;
  final String Function(String value) publicUrl;
  final VoidCallback onRetry;
  final VoidCallback onSave;
  final ValueChanged<String?> onTimezoneChanged;
  final ValueChanged<GeneralSettingsLogoField> onUploadLogo;

  @override
  Widget build(BuildContext context) {
    if (loading) return const _SettingsLoading();
    final errorText = error;
    if (errorText != null) {
      return _SettingsError(message: errorText, onRetry: onRetry);
    }

    return switch (tab) {
      _GeneralSettingsTab.general => _GeneralLogoSettings(
        form: form,
        settings: settings,
        timezone: timezone,
        saving: saving,
        uploadingField: uploadingField,
        publicUrl: publicUrl,
        onTimezoneChanged: onTimezoneChanged,
        onUploadLogo: onUploadLogo,
        onSave: onSave,
      ),
      _GeneralSettingsTab.seo => _SeoSettings(
        form: form,
        settings: settings,
        saving: saving,
        uploadingField: uploadingField,
        publicUrl: publicUrl,
        onUploadLogo: onUploadLogo,
        onSave: onSave,
      ),
      _GeneralSettingsTab.corporate => _CorporateSettings(
        form: form,
        saving: saving,
        onSave: onSave,
      ),
      _GeneralSettingsTab.services => _ServicesSettings(
        form: form,
        saving: saving,
        onSave: onSave,
      ),
      _GeneralSettingsTab.customCode => _CustomCodeSettings(
        form: form,
        saving: saving,
        onSave: onSave,
      ),
      _GeneralSettingsTab.robots => _RobotsSettings(
        form: form,
        saving: saving,
        onSave: onSave,
      ),
    };
  }
}

class _GeneralLogoSettings extends StatelessWidget {
  const _GeneralLogoSettings({
    required this.form,
    required this.settings,
    required this.timezone,
    required this.saving,
    required this.uploadingField,
    required this.publicUrl,
    required this.onTimezoneChanged,
    required this.onUploadLogo,
    required this.onSave,
  });

  final _GeneralSettingsForm form;
  final GeneralSettingsData settings;
  final String timezone;
  final bool saving;
  final GeneralSettingsLogoField? uploadingField;
  final String Function(String value) publicUrl;
  final ValueChanged<String?> onTimezoneChanged;
  final ValueChanged<GeneralSettingsLogoField> onUploadLogo;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ResponsiveFieldRow(
          children: [
            _TextInputField(label: 'Site Adı', controller: form.siteName),
            _SelectInputField(
              label: 'Zaman Dilimi',
              value: timezone,
              options: const [
                'Europe/Istanbul',
                'UTC',
                'Europe/London',
                'America/New_York',
              ],
              onChanged: onTimezoneChanged,
            ),
          ],
        ),
        const SizedBox(height: 18),
        _TextAreaField(
          label: 'Altbilgi Hakkında Bölümü',
          minLines: 4,
          controller: form.footerAbout,
        ),
        const SizedBox(height: 18),
        _ResponsiveFieldRow(
          children: [
            _TextInputField(
              label: 'Gönderi İsteğe Bağlı URL Düğmesi Adı',
              hintText: 'Buton adı...',
              controller: form.optionalUrlButtonName,
            ),
            _TextInputField(
              label: 'Telif Hakkı',
              controller: form.copyrightText,
            ),
          ],
        ),
        const SizedBox(height: 28),
        const _SubsectionHeader('Logo Ayarları'),
        const SizedBox(height: 18),
        _LogoSettingsGrid(
          settings: settings,
          uploadingField: uploadingField,
          publicUrl: publicUrl,
          onUpload: onUploadLogo,
        ),
        const _FormDivider(),
        _SaveRow(saving: saving, onPressed: onSave),
      ],
    );
  }
}

class _SeoSettings extends StatelessWidget {
  const _SeoSettings({
    required this.form,
    required this.settings,
    required this.saving,
    required this.uploadingField,
    required this.publicUrl,
    required this.onUploadLogo,
    required this.onSave,
  });

  final _GeneralSettingsForm form;
  final GeneralSettingsData settings;
  final bool saving;
  final GeneralSettingsLogoField? uploadingField;
  final String Function(String value) publicUrl;
  final ValueChanged<GeneralSettingsLogoField> onUploadLogo;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TextInputField(
          label: 'Ana Sayfa Başlığı (SEO Title)',
          controller: form.homeTitle,
          hintText: 'Ana sayfa başlığı...',
        ),
        const SizedBox(height: 18),
        _TextAreaField(
          label: 'Site Açıklaması (Meta Description)',
          minLines: 3,
          controller: form.metaDescription,
          hintText: 'Meta açıklama...',
        ),
        const SizedBox(height: 18),
        _ResponsiveFieldRow(
          children: [
            _TextInputField(
              label: 'Anahtar Kelimeler (Meta Keywords)',
              controller: form.metaKeywords,
              hintText: 'Meta anahtar kelimeler...',
            ),
            _TextInputField(
              label: 'Canonical URL',
              controller: form.canonicalUrl,
              hintText: 'https://',
            ),
          ],
        ),
        const SizedBox(height: 18),
        _UploadInputField(
          label: 'Global Paylaşım Görseli (OG Image)',
          controller: form.ogImageUrl,
          currentUrl: settings.ogImageUrl,
          publicUrl: publicUrl,
          uploading: uploadingField == GeneralSettingsLogoField.ogImageUrl,
          onUpload: () => onUploadLogo(GeneralSettingsLogoField.ogImageUrl),
        ),
        const _FormDivider(),
        _SaveRow(saving: saving, onPressed: onSave),
      ],
    );
  }
}

class _CorporateSettings extends StatelessWidget {
  const _CorporateSettings({
    required this.form,
    required this.saving,
    required this.onSave,
  });

  final _GeneralSettingsForm form;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ResponsiveFieldRow(
          children: [
            _TextInputField(
              label: 'Resmi Kurum/Şirket Adı',
              controller: form.organizationLegalName,
            ),
            _TextInputField(
              label: 'Telefon Numarası',
              controller: form.organizationPhone,
            ),
          ],
        ),
        const SizedBox(height: 18),
        _TextAreaField(
          label: 'Resmi Adres',
          minLines: 2,
          controller: form.organizationAddress,
        ),
        const SizedBox(height: 18),
        _ResponsiveFieldRow(
          children: [
            _TextInputField(
              label: 'Twitter (X) Kullanıcı Adı',
              controller: form.twitterUsername,
              hintText: '@kullaniciadi',
            ),
            _TextInputField(label: 'Facebook App ID', controller: form.fbAppId),
          ],
        ),
        const _FormDivider(),
        _SaveRow(saving: saving, onPressed: onSave),
      ],
    );
  }
}

class _ServicesSettings extends StatelessWidget {
  const _ServicesSettings({
    required this.form,
    required this.saving,
    required this.onSave,
  });

  final _GeneralSettingsForm form;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TextInputField(
          label: 'Google Analytics (GA4) ID',
          controller: form.googleAnalyticsId,
          hintText: 'G-XXXXXXXX',
        ),
        const SizedBox(height: 18),
        _TextInputField(
          label: 'Google Search Console Doğrulama Kodu',
          controller: form.googleSearchConsoleCode,
        ),
        const SizedBox(height: 18),
        _TextInputField(
          label: 'Bing Webmaster Doğrulama Kodu',
          controller: form.bingVerificationCode,
        ),
        const _FormDivider(),
        _SaveRow(saving: saving, onPressed: onSave),
      ],
    );
  }
}

class _CustomCodeSettings extends StatelessWidget {
  const _CustomCodeSettings({
    required this.form,
    required this.saving,
    required this.onSave,
  });

  final _GeneralSettingsForm form;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TextAreaField(
          label: 'Header Özel Kodlar (<head> içine)',
          minLines: 7,
          controller: form.headerCustomCodes,
          hintText: '<script>...</script>',
          monospace: true,
        ),
        const SizedBox(height: 22),
        _TextAreaField(
          label: 'Footer Özel Kodlar (</body> öncesi)',
          minLines: 7,
          controller: form.footerCustomCodes,
          hintText: '<script>...</script>',
          monospace: true,
        ),
        const _FormDivider(),
        _SaveRow(saving: saving, onPressed: onSave),
      ],
    );
  }
}

class _RobotsSettings extends StatelessWidget {
  const _RobotsSettings({
    required this.form,
    required this.saving,
    required this.onSave,
  });

  final _GeneralSettingsForm form;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TextAreaField(
          label: 'Robots.txt İçeriği',
          minLines: 8,
          controller: form.robotsTxt,
          monospace: true,
        ),
        const _FormDivider(),
        _SaveRow(saving: saving, onPressed: onSave),
      ],
    );
  }
}

class _SettingsLoading extends StatelessWidget {
  const _SettingsLoading();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.deepOcean,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              context.t('common.loading'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.inkSoft,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsError extends StatelessWidget {
  const _SettingsError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.actionRed,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 36,
              child: OutlinedButton(
                onPressed: onRetry,
                style:
                    OutlinedButton.styleFrom(
                      foregroundColor: AppColors.deepOcean,
                      side: const BorderSide(color: AppColors.line),
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
                child: Text(context.t('Retry')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResponsiveFieldRow extends StatelessWidget {
  const _ResponsiveFieldRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 760) {
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
              if (i > 0) const SizedBox(width: 18),
              Expanded(child: children[i]),
            ],
          ],
        );
      },
    );
  }
}

class _TextInputField extends StatelessWidget {
  const _TextInputField({
    required this.label,
    required this.controller,
    this.hintText,
  });

  final String label;
  final TextEditingController controller;
  final String? hintText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: TextFormField(
            controller: controller,
            mouseCursor: SystemMouseCursors.text,
            cursorColor: AppColors.support,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.deepOcean,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
            decoration: _inputDecoration(context, hintText: hintText),
          ),
        ),
      ],
    );
  }
}

class _SelectInputField extends StatelessWidget {
  const _SelectInputField({
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
    final items = [
      for (final option in options)
        DropdownMenuItem(value: option, child: Text(context.t(option))),
      if (!options.contains(value))
        DropdownMenuItem(value: value, child: Text(value)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 8),
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

class _TextAreaField extends StatelessWidget {
  const _TextAreaField({
    required this.label,
    required this.minLines,
    required this.controller,
    this.hintText,
    this.monospace = false,
  });

  final String label;
  final int minLines;
  final TextEditingController controller;
  final String? hintText;
  final bool monospace;

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
            fontFamily: monospace ? 'monospace' : null,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
            height: 1.5,
          ),
          decoration: _inputDecoration(context, hintText: hintText),
        ),
      ],
    );
  }
}

class _UploadInputField extends StatelessWidget {
  const _UploadInputField({
    required this.label,
    required this.controller,
    required this.currentUrl,
    required this.publicUrl,
    required this.uploading,
    required this.onUpload,
  });

  final String label;
  final TextEditingController controller;
  final String currentUrl;
  final String Function(String value) publicUrl;
  final bool uploading;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final input = _TextInputField(
          label: label,
          controller: controller,
          hintText: 'Logo veya kapak görseli URL\'i',
        );
        final button = _UploadButton(uploading: uploading, onUpload: onUpload);
        final preview = currentUrl.trim().isEmpty
            ? const SizedBox.shrink()
            : _SmallImagePreview(url: currentUrl, publicUrl: publicUrl);

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              input,
              const SizedBox(height: 10),
              button,
              if (currentUrl.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                preview,
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: input),
            const SizedBox(width: 14),
            button,
            if (currentUrl.trim().isNotEmpty) ...[
              const SizedBox(width: 14),
              preview,
            ],
          ],
        );
      },
    );
  }
}

class _UploadButton extends StatelessWidget {
  const _UploadButton({required this.uploading, required this.onUpload});

  final bool uploading;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: OutlinedButton(
        onPressed: uploading ? null : onUpload,
        style:
            OutlinedButton.styleFrom(
              foregroundColor: AppColors.deepOcean,
              side: BorderSide(
                color: AppColors.actionRed.withValues(alpha: 0.45),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18),
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
            if (uploading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.deepOcean,
                ),
              )
            else
              const SymbolIcon(
                Symbols.upload,
                color: AppColors.deepOcean,
                size: 16,
              ),
            const SizedBox(width: 8),
            Text(context.t('Upload')),
          ],
        ),
      ),
    );
  }
}

class _SmallImagePreview extends StatelessWidget {
  const _SmallImagePreview({required this.url, required this.publicUrl});

  final String url;
  final String Function(String value) publicUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line),
      ),
      child: Image.network(
        publicUrl(url),
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const SymbolIcon(
          Symbols.newspaper,
          color: AppColors.inkSoft,
          size: 20,
        ),
      ),
    );
  }
}

class _LogoSettingsGrid extends StatelessWidget {
  const _LogoSettingsGrid({
    required this.settings,
    required this.uploadingField,
    required this.publicUrl,
    required this.onUpload,
  });

  final GeneralSettingsData settings;
  final GeneralSettingsLogoField? uploadingField;
  final String Function(String value) publicUrl;
  final ValueChanged<GeneralSettingsLogoField> onUpload;

  static const _items = [
    _LogoUploadItem(
      title: 'Logo',
      field: GeneralSettingsLogoField.logoUrl,
      size: '200x50 px',
    ),
    _LogoUploadItem(
      title: 'Altbilgi Logosu',
      field: GeneralSettingsLogoField.footerLogoUrl,
      size: '200x50 px',
    ),
    _LogoUploadItem(
      title: 'Dark Logosu',
      field: GeneralSettingsLogoField.darkLogoUrl,
      helper: 'Karanlık mod için logo',
      size: '200x50 px',
    ),
    _LogoUploadItem(
      title: 'E-posta Logosu',
      field: GeneralSettingsLogoField.emailLogoUrl,
      size: '200x50 px',
    ),
    _LogoUploadItem(
      title: 'Favicon',
      field: GeneralSettingsLogoField.faviconUrl,
      helper: 'Favicon için 32x32 önerilir',
      size: '16x16 px',
      compactPreview: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final columns = maxWidth >= 1180
            ? 5
            : maxWidth >= 920
            ? 4
            : maxWidth >= 680
            ? 3
            : maxWidth >= 430
            ? 2
            : 1;
        final spacing = 14.0;
        final itemWidth = (maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final item in _items)
              SizedBox(
                width: itemWidth,
                child: _LogoUploadCard(
                  item: item,
                  currentUrl: settings.logoFor(item.field),
                  publicUrl: publicUrl,
                  uploading: uploadingField == item.field,
                  onUpload: () => onUpload(item.field),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _LogoUploadCard extends StatelessWidget {
  const _LogoUploadCard({
    required this.item,
    required this.currentUrl,
    required this.publicUrl,
    required this.uploading,
    required this.onUpload,
  });

  final _LogoUploadItem item;
  final String currentUrl;
  final String Function(String value) publicUrl;
  final bool uploading;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 206),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line.withValues(alpha: 0.9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.t(item.title),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.deepOcean,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
          if (item.helper != null) ...[
            const SizedBox(height: 3),
            Text(
              context.t(item.helper!),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.inkSoft,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
          ],
          const SizedBox(height: 12),
          _LogoPreview(
            compact: item.compactPreview,
            currentUrl: currentUrl,
            publicUrl: publicUrl,
          ),
          const SizedBox(height: 12),
          _LogoChangeButton(uploading: uploading, onPressed: onUpload),
          const SizedBox(height: 10),
          Text(
            '${item.formats}\n${item.size}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.inkSoft,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoPreview extends StatelessWidget {
  const _LogoPreview({
    required this.compact,
    required this.currentUrl,
    required this.publicUrl,
  });

  final bool compact;
  final String currentUrl;
  final String Function(String value) publicUrl;

  @override
  Widget build(BuildContext context) {
    final url = currentUrl.trim();
    return Container(
      height: 76,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(
          color: AppColors.line.withValues(alpha: 0.8),
          style: BorderStyle.solid,
        ),
      ),
      child: url.isNotEmpty
          ? Padding(
              padding: EdgeInsets.all(compact ? 14 : 10),
              child: Image.network(
                publicUrl(url),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    _LogoFallback(compact: compact),
              ),
            )
          : _LogoFallback(compact: compact),
    );
  }
}

class _LogoFallback extends StatelessWidget {
  const _LogoFallback({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.inkSoft.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(AppRadius.value),
        ),
        child: const SymbolIcon(
          Symbols.newspaper,
          color: AppColors.inkSoft,
          size: 30,
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SymbolIcon(Symbols.newspaper, color: AppColors.inkSoft, size: 28),
        const SizedBox(width: 8),
        Text(
          'pateez',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: AppColors.inkSoft,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _LogoChangeButton extends StatelessWidget {
  const _LogoChangeButton({required this.uploading, required this.onPressed});

  final bool uploading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: OutlinedButton(
        onPressed: uploading ? null : onPressed,
        style:
            OutlinedButton.styleFrom(
              foregroundColor: AppColors.deepOcean,
              side: BorderSide(
                color: AppColors.actionRed.withValues(alpha: 0.45),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (uploading)
              const SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.deepOcean,
                ),
              )
            else
              const SymbolIcon(
                Symbols.upload,
                color: AppColors.deepOcean,
                size: 15,
              ),
            const SizedBox(width: 7),
            Flexible(child: Text(context.t('Change Logo'))),
          ],
        ),
      ),
    );
  }
}

class _SaveRow extends StatelessWidget {
  const _SaveRow({required this.saving, required this.onPressed});

  final bool saving;
  final VoidCallback onPressed;

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
                disabledBackgroundColor: AppColors.actionRed.withValues(
                  alpha: 0.55,
                ),
                disabledForegroundColor: Colors.white,
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
              Text(context.t('Save Changes')),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 22,
          decoration: BoxDecoration(
            color: AppColors.actionRed,
            borderRadius: BorderRadius.circular(AppRadius.value),
          ),
        ),
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
      ],
    );
  }
}

class _SubsectionHeader extends StatelessWidget {
  const _SubsectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      context.t(label),
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: AppColors.deepOcean,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
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
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: AppColors.deepOcean,
        fontWeight: FontWeight.w700,
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

InputDecoration _inputDecoration(BuildContext context, {String? hintText}) {
  return InputDecoration(
    hintText: hintText == null ? null : context.t(hintText),
    hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: AppColors.placeholder,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
    ),
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

class _LogoUploadItem {
  const _LogoUploadItem({
    required this.title,
    required this.field,
    required this.size,
    this.helper,
    this.compactPreview = false,
  });

  final String title;
  final GeneralSettingsLogoField field;
  final String size;
  final String? helper;
  final bool compactPreview;

  String get formats => field == GeneralSettingsLogoField.faviconUrl
      ? '.png, .jpg, .svg, .webp, .ico'
      : '.png, .jpg, .svg, .webp';
}

enum _GeneralSettingsTab {
  general('Genel & Logo'),
  seo('SEO Ayarları'),
  corporate('Kurumsal (EEAT)'),
  services('Google & Servisler'),
  customCode('Özel Kodlar'),
  robots('Robots & Teknik');

  const _GeneralSettingsTab(this.title);

  final String title;
}
