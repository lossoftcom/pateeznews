import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';
import 'package:pateeznews_admin/shared/widgets/admin_toast.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/localization/admin_language_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/branding/admin_branding.dart';
import '../../../shared/widgets/admin_cached_image.dart';
import '../../../shared/widgets/symbol_icon.dart';
import '../../auth/data/admin_auth_models.dart';
import '../data/admin_general_settings_repository.dart';
import '../data/admin_language_models.dart';

class GeneralSettingsScreen extends StatefulWidget {
  const GeneralSettingsScreen({
    super.key,
    required this.session,
    this.profile,
    this.repository = const SupabaseAdminGeneralSettingsRepository(),
  });

  final AdminSession session;
  final AdminProfile? profile;
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
  var _socialPasswordStatus = SocialPasswordStatus.empty;
  final _visibleSocialPasswordFields = <SocialPasswordField>{};
  SocialPasswordField? _revealingSocialPasswordField;
  var _contactEmailPasswordStatus = ContactEmailPasswordStatus.empty;
  final _visibleContactEmailPasswordFields = <ContactEmailPasswordField>{};
  ContactEmailPasswordField? _revealingContactEmailPasswordField;

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
      final socialPasswordStatus = _canManageSocialPasswords
          ? await widget.repository.fetchSocialPasswordStatus(
              session: widget.session,
              languageCode: _settingsLanguageCode,
            )
          : SocialPasswordStatus.empty;
      final contactEmailPasswordStatus = _canManageContactEmailPasswords
          ? await widget.repository.fetchContactEmailPasswordStatus(
              session: widget.session,
              languageCode: _settingsLanguageCode,
            )
          : ContactEmailPasswordStatus.empty;
      if (!mounted) return;
      _applySettings(settings);
      setState(() {
        _socialPasswordStatus = socialPasswordStatus;
        _contactEmailPasswordStatus = contactEmailPasswordStatus;
        _form.clearSocialPasswordValues();
        _form.clearContactEmailPasswordValues();
        _visibleSocialPasswordFields.clear();
        _visibleContactEmailPasswordFields.clear();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _settings = GeneralSettingsData.empty(_settingsLanguageCode);
        _timezone = 'Europe/Istanbul';
        _form.apply(_settings);
        _form.clearSocialPasswordValues();
        _form.clearContactEmailPasswordValues();
        _socialPasswordStatus = SocialPasswordStatus.empty;
        _contactEmailPasswordStatus = ContactEmailPasswordStatus.empty;
        _visibleSocialPasswordFields.clear();
        _visibleContactEmailPasswordFields.clear();
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
    final socialPasswordValues = _canManageSocialPasswords
        ? _form.socialPasswordValues()
        : <SocialPasswordField, String>{};
    final contactEmailPasswordValues = _canManageContactEmailPasswords
        ? _form.contactEmailPasswordValues()
        : <ContactEmailPasswordField, String>{};
    setState(() => _saving = true);
    try {
      final saved = await widget.repository.saveSettings(
        session: widget.session,
        settings: _currentSettings(),
      );
      final socialPasswordStatus = socialPasswordValues.isEmpty
          ? _socialPasswordStatus
          : await widget.repository.saveSocialPasswords(
              session: widget.session,
              languageCode: _settingsLanguageCode,
              values: socialPasswordValues,
            );
      final contactEmailPasswordStatus = contactEmailPasswordValues.isEmpty
          ? _contactEmailPasswordStatus
          : await widget.repository.saveContactEmailPasswords(
              session: widget.session,
              languageCode: _settingsLanguageCode,
              values: contactEmailPasswordValues,
            );
      if (!mounted) return;
      setState(() {
        _applySettings(saved);
        _socialPasswordStatus = socialPasswordStatus;
        _contactEmailPasswordStatus = contactEmailPasswordStatus;
        _form.clearSocialPasswordValues();
        _form.clearContactEmailPasswordValues();
        _visibleSocialPasswordFields.clear();
        _visibleContactEmailPasswordFields.clear();
        _saving = false;
      });
      unawaited(_updateAdminBranding(saved));
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
      final nextSettings = _settingsWithLogo(_currentSettings(), field, src);
      final saved = await widget.repository.saveSettings(
        session: widget.session,
        settings: nextSettings,
      );
      if (!mounted) return;
      setState(() {
        _applySettings(saved);
        _uploadingField = null;
      });
      unawaited(_updateAdminBranding(saved));
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

  Future<void> _updateAdminBranding(GeneralSettingsData settings) {
    return AdminBrandingStore.update(
      AdminBrandingData(
        siteName: settings.siteName,
        logoUrl: widget.repository.publicUrl(settings.logoUrl),
        emailLogoUrl: widget.repository.publicUrl(settings.emailLogoUrl),
        faviconUrl: widget.repository.publicUrl(settings.faviconUrl),
      ),
    );
  }

  String get _roleName {
    final profileRole = widget.profile?.role?.trim();
    if (profileRole != null && profileRole.isNotEmpty) return profileRole;
    final metadataRole = widget.session.user.userMetadata['role']
        ?.toString()
        .trim();
    if (metadataRole != null && metadataRole.isNotEmpty) return metadataRole;
    return '';
  }

  bool get _canManageSocialPasswords {
    final role = _roleName.toLowerCase();
    return role == 'admin' || role == 'super_admin';
  }

  bool get _canManageContactEmailPasswords => _canManageSocialPasswords;

  Future<void> _revealSocialPassword(SocialPasswordField field) async {
    if (!_canManageSocialPasswords || _saving || _loading) return;
    if (_visibleSocialPasswordFields.contains(field)) {
      setState(() => _visibleSocialPasswordFields.remove(field));
      return;
    }

    final superAdminPassword = await showDialog<String>(
      context: context,
      builder: (context) => const _SuperAdminPasswordDialog(),
    );
    if (superAdminPassword == null || superAdminPassword.trim().isEmpty) {
      return;
    }

    final controller = _form.socialPasswordController(field);
    final typedValue = controller.text;
    setState(() => _revealingSocialPasswordField = field);
    try {
      final revealed = await widget.repository.revealSocialPassword(
        session: widget.session,
        languageCode: _settingsLanguageCode,
        field: field,
        superAdminPassword: superAdminPassword,
      );
      if (!mounted) return;
      setState(() {
        if (typedValue.trim().isEmpty) controller.text = revealed;
        _visibleSocialPasswordFields.add(field);
        _revealingSocialPasswordField = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _revealingSocialPasswordField = null);
      _showMessage('Sosyal şifre görüntülenemedi: $error');
    }
  }

  Future<void> _revealContactEmailPassword(
    ContactEmailPasswordField field,
  ) async {
    if (!_canManageContactEmailPasswords || _saving || _loading) return;
    if (_visibleContactEmailPasswordFields.contains(field)) {
      setState(() => _visibleContactEmailPasswordFields.remove(field));
      return;
    }

    final superAdminPassword = await showDialog<String>(
      context: context,
      builder: (context) => const _SuperAdminPasswordDialog(),
    );
    if (superAdminPassword == null || superAdminPassword.trim().isEmpty) {
      return;
    }

    final controller = _form.contactEmailPasswordController(field);
    final typedValue = controller.text;
    setState(() => _revealingContactEmailPasswordField = field);
    try {
      final revealed = await widget.repository.revealContactEmailPassword(
        session: widget.session,
        languageCode: _settingsLanguageCode,
        field: field,
        superAdminPassword: superAdminPassword,
      );
      if (!mounted) return;
      setState(() {
        if (typedValue.trim().isEmpty) controller.text = revealed;
        _visibleContactEmailPasswordFields.add(field);
        _revealingContactEmailPasswordField = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _revealingContactEmailPasswordField = null);
      _showMessage('İletişim mail şifresi görüntülenemedi: $error');
    }
  }

  void _showMessage(
    String message, {
    AdminToastTone tone = AdminToastTone.info,
  }) {
    AdminToast.show(context, message: context.t(message), tone: tone);
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
                  canManageSocialPasswords: _canManageSocialPasswords,
                  socialPasswordStatus: _socialPasswordStatus,
                  visibleSocialPasswordFields: _visibleSocialPasswordFields,
                  revealingSocialPasswordField: _revealingSocialPasswordField,
                  canManageContactEmailPasswords:
                      _canManageContactEmailPasswords,
                  contactEmailPasswordStatus: _contactEmailPasswordStatus,
                  visibleContactEmailPasswordFields:
                      _visibleContactEmailPasswordFields,
                  revealingContactEmailPasswordField:
                      _revealingContactEmailPasswordField,
                  onRetry: () => unawaited(_loadSettings()),
                  onSave: () => unawaited(_saveSettings()),
                  onRevealSocialPassword: (field) =>
                      unawaited(_revealSocialPassword(field)),
                  onRevealContactEmailPassword: (field) =>
                      unawaited(_revealContactEmailPassword(field)),
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
  final contactPhone = TextEditingController();
  final contactCity = TextEditingController();
  final contactAddress = TextEditingController();
  final contactLocationUrl = TextEditingController();
  final contactWhatsappUrl = TextEditingController();
  final contactTelegramUrl = TextEditingController();
  final contactEmailInfo = TextEditingController();
  final contactEmailSupport = TextEditingController();
  final contactEmailNews = TextEditingController();
  final contactEmailAds = TextEditingController();
  final twitterUsername = TextEditingController();
  final fbAppId = TextEditingController();
  final socialWhatsappUrl = TextEditingController();
  final socialTelegramUrl = TextEditingController();
  final socialInstagramUrl = TextEditingController();
  final socialFacebookUrl = TextEditingController();
  final socialXUrl = TextEditingController();
  final socialYoutubeUrl = TextEditingController();
  final socialTiktokUrl = TextEditingController();
  final socialLinkedinUrl = TextEditingController();
  final socialPinterestUrl = TextEditingController();
  final socialDiscordUrl = TextEditingController();
  final _socialPasswordControllers =
      <SocialPasswordField, TextEditingController>{
        for (final field in SocialPasswordField.values)
          field: TextEditingController(),
      };
  final _contactEmailPasswordControllers =
      <ContactEmailPasswordField, TextEditingController>{
        for (final field in ContactEmailPasswordField.values)
          field: TextEditingController(),
      };
  final googleAnalyticsId = TextEditingController();
  final googleSearchConsoleCode = TextEditingController();
  final bingVerificationCode = TextEditingController();
  final yandexVerificationCode = TextEditingController();
  final indexNowKey = TextEditingController();
  final cookieBannerTitle = TextEditingController();
  final cookieBannerDescription = TextEditingController();
  final cookiePolicyUrl = TextEditingController();
  final newsletterPopupDelaySeconds = TextEditingController();
  final newsletterPopupFrequencyDays = TextEditingController();
  final newsletterPopupTitle = TextEditingController();
  final newsletterPopupDescription = TextEditingController();
  final newsletterPopupButtonLabel = TextEditingController();
  final socialAuthRedirectScheme = TextEditingController();
  final socialAuthRedirectHost = TextEditingController();
  final robotsTxt = TextEditingController();
  final headerCustomCodes = TextEditingController();
  final footerCustomCodes = TextEditingController();
  var cookieBannerEnabled = true;
  var cookiePreferencesEnabled = true;
  var newsletterPopupEnabled = true;
  var socialAuthGoogleEnabled = true;
  var socialAuthAppleEnabled = true;
  var socialAuthFacebookEnabled = true;
  var socialAuthXEnabled = true;

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
    contactPhone.text = settings.contactPhone;
    contactCity.text = settings.contactCity;
    contactAddress.text = settings.contactAddress;
    contactLocationUrl.text = settings.contactLocationUrl;
    contactWhatsappUrl.text = settings.contactWhatsappUrl;
    contactTelegramUrl.text = settings.contactTelegramUrl;
    contactEmailInfo.text = settings.contactEmailInfo;
    contactEmailSupport.text = settings.contactEmailSupport;
    contactEmailNews.text = settings.contactEmailNews;
    contactEmailAds.text = settings.contactEmailAds;
    twitterUsername.text = settings.twitterUsername;
    fbAppId.text = settings.fbAppId;
    socialWhatsappUrl.text = settings.socialWhatsappUrl;
    socialTelegramUrl.text = settings.socialTelegramUrl;
    socialInstagramUrl.text = settings.socialInstagramUrl;
    socialFacebookUrl.text = settings.socialFacebookUrl;
    socialXUrl.text = settings.socialXUrl;
    socialYoutubeUrl.text = settings.socialYoutubeUrl;
    socialTiktokUrl.text = settings.socialTiktokUrl;
    socialLinkedinUrl.text = settings.socialLinkedinUrl;
    socialPinterestUrl.text = settings.socialPinterestUrl;
    socialDiscordUrl.text = settings.socialDiscordUrl;
    googleAnalyticsId.text = settings.googleAnalyticsId;
    googleSearchConsoleCode.text = settings.googleSearchConsoleCode;
    bingVerificationCode.text = settings.bingVerificationCode;
    yandexVerificationCode.text = settings.yandexVerificationCode;
    indexNowKey.text = settings.indexNowKey;
    cookieBannerEnabled = settings.cookieBannerEnabled;
    cookiePreferencesEnabled = settings.cookiePreferencesEnabled;
    cookieBannerTitle.text = settings.cookieBannerTitle;
    cookieBannerDescription.text = settings.cookieBannerDescription;
    cookiePolicyUrl.text = settings.cookiePolicyUrl;
    newsletterPopupEnabled = settings.newsletterPopupEnabled;
    newsletterPopupDelaySeconds.text = settings.newsletterPopupDelaySeconds
        .toString();
    newsletterPopupFrequencyDays.text = settings.newsletterPopupFrequencyDays
        .toString();
    newsletterPopupTitle.text = settings.newsletterPopupTitle;
    newsletterPopupDescription.text = settings.newsletterPopupDescription;
    newsletterPopupButtonLabel.text = settings.newsletterPopupButtonLabel;
    socialAuthGoogleEnabled = settings.socialAuthGoogleEnabled;
    socialAuthAppleEnabled = settings.socialAuthAppleEnabled;
    socialAuthFacebookEnabled = settings.socialAuthFacebookEnabled;
    socialAuthXEnabled = settings.socialAuthXEnabled;
    socialAuthRedirectScheme.text = settings.socialAuthRedirectScheme;
    socialAuthRedirectHost.text = settings.socialAuthRedirectHost;
    robotsTxt.text = settings.robotsTxt;
    headerCustomCodes.text = settings.headerCustomCodes;
    footerCustomCodes.text = settings.footerCustomCodes;
  }

  TextEditingController socialPasswordController(SocialPasswordField field) {
    return _socialPasswordControllers[field]!;
  }

  Map<SocialPasswordField, String> socialPasswordValues() {
    return {
      for (final entry in _socialPasswordControllers.entries)
        if (entry.value.text.trim().isNotEmpty) entry.key: entry.value.text,
    };
  }

  void clearSocialPasswordValues() {
    for (final controller in _socialPasswordControllers.values) {
      controller.clear();
    }
  }

  TextEditingController contactEmailPasswordController(
    ContactEmailPasswordField field,
  ) {
    return _contactEmailPasswordControllers[field]!;
  }

  Map<ContactEmailPasswordField, String> contactEmailPasswordValues() {
    return {
      for (final entry in _contactEmailPasswordControllers.entries)
        if (entry.value.text.trim().isNotEmpty) entry.key: entry.value.text,
    };
  }

  void clearContactEmailPasswordValues() {
    for (final controller in _contactEmailPasswordControllers.values) {
      controller.clear();
    }
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
      contactPhone: contactPhone.text,
      contactCity: contactCity.text,
      contactAddress: contactAddress.text,
      contactLocationUrl: contactLocationUrl.text,
      contactWhatsappUrl: contactWhatsappUrl.text,
      contactTelegramUrl: contactTelegramUrl.text,
      contactEmailInfo: contactEmailInfo.text,
      contactEmailSupport: contactEmailSupport.text,
      contactEmailNews: contactEmailNews.text,
      contactEmailAds: contactEmailAds.text,
      twitterUsername: twitterUsername.text,
      fbAppId: fbAppId.text,
      socialWhatsappUrl: socialWhatsappUrl.text,
      socialTelegramUrl: socialTelegramUrl.text,
      socialInstagramUrl: socialInstagramUrl.text,
      socialFacebookUrl: socialFacebookUrl.text,
      socialXUrl: socialXUrl.text,
      socialYoutubeUrl: socialYoutubeUrl.text,
      socialTiktokUrl: socialTiktokUrl.text,
      socialLinkedinUrl: socialLinkedinUrl.text,
      socialPinterestUrl: socialPinterestUrl.text,
      socialDiscordUrl: socialDiscordUrl.text,
      googleAnalyticsId: googleAnalyticsId.text,
      googleSearchConsoleCode: googleSearchConsoleCode.text,
      bingVerificationCode: bingVerificationCode.text,
      yandexVerificationCode: yandexVerificationCode.text,
      indexNowKey: indexNowKey.text,
      cookieBannerEnabled: cookieBannerEnabled,
      cookiePreferencesEnabled: cookiePreferencesEnabled,
      cookieBannerTitle: cookieBannerTitle.text,
      cookieBannerDescription: cookieBannerDescription.text,
      cookiePolicyUrl: cookiePolicyUrl.text,
      newsletterPopupEnabled: newsletterPopupEnabled,
      newsletterPopupDelaySeconds: _boundedInt(
        newsletterPopupDelaySeconds.text,
        fallback: base.newsletterPopupDelaySeconds,
        min: 0,
        max: 60,
      ),
      newsletterPopupFrequencyDays: _boundedInt(
        newsletterPopupFrequencyDays.text,
        fallback: base.newsletterPopupFrequencyDays,
        min: 1,
        max: 365,
      ),
      newsletterPopupTitle: newsletterPopupTitle.text,
      newsletterPopupDescription: newsletterPopupDescription.text,
      newsletterPopupButtonLabel: newsletterPopupButtonLabel.text,
      socialAuthGoogleEnabled: socialAuthGoogleEnabled,
      socialAuthAppleEnabled: socialAuthAppleEnabled,
      socialAuthFacebookEnabled: socialAuthFacebookEnabled,
      socialAuthXEnabled: socialAuthXEnabled,
      socialAuthRedirectScheme: socialAuthRedirectScheme.text,
      socialAuthRedirectHost: socialAuthRedirectHost.text,
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
    contactPhone.dispose();
    contactCity.dispose();
    contactAddress.dispose();
    contactLocationUrl.dispose();
    contactWhatsappUrl.dispose();
    contactTelegramUrl.dispose();
    contactEmailInfo.dispose();
    contactEmailSupport.dispose();
    contactEmailNews.dispose();
    contactEmailAds.dispose();
    twitterUsername.dispose();
    fbAppId.dispose();
    socialWhatsappUrl.dispose();
    socialTelegramUrl.dispose();
    socialInstagramUrl.dispose();
    socialFacebookUrl.dispose();
    socialXUrl.dispose();
    socialYoutubeUrl.dispose();
    socialTiktokUrl.dispose();
    socialLinkedinUrl.dispose();
    socialPinterestUrl.dispose();
    socialDiscordUrl.dispose();
    for (final controller in _socialPasswordControllers.values) {
      controller.dispose();
    }
    for (final controller in _contactEmailPasswordControllers.values) {
      controller.dispose();
    }
    googleAnalyticsId.dispose();
    googleSearchConsoleCode.dispose();
    bingVerificationCode.dispose();
    yandexVerificationCode.dispose();
    indexNowKey.dispose();
    cookieBannerTitle.dispose();
    cookieBannerDescription.dispose();
    cookiePolicyUrl.dispose();
    newsletterPopupDelaySeconds.dispose();
    newsletterPopupFrequencyDays.dispose();
    newsletterPopupTitle.dispose();
    newsletterPopupDescription.dispose();
    newsletterPopupButtonLabel.dispose();
    socialAuthRedirectScheme.dispose();
    socialAuthRedirectHost.dispose();
    robotsTxt.dispose();
    headerCustomCodes.dispose();
    footerCustomCodes.dispose();
  }
}

int _boundedInt(
  String value, {
  required int fallback,
  required int min,
  required int max,
}) {
  final parsed = int.tryParse(value.trim()) ?? fallback;
  return parsed.clamp(min, max).toInt();
}

Future<void> _openPublicSitemap() async {
  final uri = Uri.base.resolve('/sitemap.xml');
  await launchUrl(
    uri,
    mode: LaunchMode.externalApplication,
    webOnlyWindowName: '_blank',
  );
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
    required this.canManageSocialPasswords,
    required this.socialPasswordStatus,
    required this.visibleSocialPasswordFields,
    required this.revealingSocialPasswordField,
    required this.canManageContactEmailPasswords,
    required this.contactEmailPasswordStatus,
    required this.visibleContactEmailPasswordFields,
    required this.revealingContactEmailPasswordField,
    required this.onRetry,
    required this.onSave,
    required this.onRevealSocialPassword,
    required this.onRevealContactEmailPassword,
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
  final bool canManageSocialPasswords;
  final SocialPasswordStatus socialPasswordStatus;
  final Set<SocialPasswordField> visibleSocialPasswordFields;
  final SocialPasswordField? revealingSocialPasswordField;
  final bool canManageContactEmailPasswords;
  final ContactEmailPasswordStatus contactEmailPasswordStatus;
  final Set<ContactEmailPasswordField> visibleContactEmailPasswordFields;
  final ContactEmailPasswordField? revealingContactEmailPasswordField;
  final VoidCallback onRetry;
  final VoidCallback onSave;
  final ValueChanged<SocialPasswordField> onRevealSocialPassword;
  final ValueChanged<ContactEmailPasswordField> onRevealContactEmailPassword;
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
      _GeneralSettingsTab.socialAddresses => _SocialAddressSettings(
        form: form,
        saving: saving,
        canManageSocialPasswords: canManageSocialPasswords,
        socialPasswordStatus: socialPasswordStatus,
        visibleSocialPasswordFields: visibleSocialPasswordFields,
        revealingSocialPasswordField: revealingSocialPasswordField,
        onRevealSocialPassword: onRevealSocialPassword,
        onSave: onSave,
      ),
      _GeneralSettingsTab.services => _ServicesSettings(
        form: form,
        saving: saving,
        onSave: onSave,
      ),
      _GeneralSettingsTab.privacy => _PrivacyNewsletterSettings(
        form: form,
        saving: saving,
        onSave: onSave,
      ),
      _GeneralSettingsTab.socialAuth => _SocialAuthSettings(
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
      _GeneralSettingsTab.contact => _ContactSettings(
        form: form,
        saving: saving,
        canManageContactEmailPasswords: canManageContactEmailPasswords,
        contactEmailPasswordStatus: contactEmailPasswordStatus,
        visibleContactEmailPasswordFields: visibleContactEmailPasswordFields,
        revealingContactEmailPasswordField: revealingContactEmailPasswordField,
        onRevealContactEmailPassword: onRevealContactEmailPassword,
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
        const SizedBox(height: 26),
        const _SitemapSettingsSection(),
        const _FormDivider(),
        _SaveRow(saving: saving, onPressed: onSave),
      ],
    );
  }
}

class _SitemapSettingsSection extends StatefulWidget {
  const _SitemapSettingsSection();

  @override
  State<_SitemapSettingsSection> createState() =>
      _SitemapSettingsSectionState();
}

class _SitemapSettingsSectionState extends State<_SitemapSettingsSection> {
  var _frequencyAuto = true;
  var _lastModificationAuto = true;
  var _priorityAuto = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line.withValues(alpha: 0.86)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SubsectionHeader('generalSettings.seo.sitemap.title'),
          const SizedBox(height: 22),
          _SitemapRadioGroup(
            label: 'generalSettings.seo.sitemap.frequency',
            helper: 'generalSettings.seo.sitemap.frequencyHelp',
            value: _frequencyAuto,
            onChanged: (value) => setState(() => _frequencyAuto = value),
          ),
          const SizedBox(height: 22),
          _SitemapRadioGroup(
            label: 'generalSettings.seo.sitemap.lastModification',
            helper: 'generalSettings.seo.sitemap.lastModificationHelp',
            value: _lastModificationAuto,
            onChanged: (value) => setState(() => _lastModificationAuto = value),
          ),
          const SizedBox(height: 22),
          _SitemapRadioGroup(
            label: 'generalSettings.seo.sitemap.priority',
            helper: 'generalSettings.seo.sitemap.priorityHelp',
            value: _priorityAuto,
            onChanged: (value) => setState(() => _priorityAuto = value),
          ),
          const SizedBox(height: 20),
          const Align(
            alignment: Alignment.centerRight,
            child: _SitemapActionButton(),
          ),
          const SizedBox(height: 28),
          const _SubsectionHeader('generalSettings.seo.sitemap.generatedTitle'),
          const SizedBox(height: 14),
          const _SitemapGeneratedFile(),
          const SizedBox(height: 18),
          const _SitemapInfoBox(),
        ],
      ),
    );
  }
}

class _SitemapRadioGroup extends StatelessWidget {
  const _SitemapRadioGroup({
    required this.label,
    required this.helper,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String helper;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RequiredLabel(label),
        const SizedBox(height: 4),
        Text(
          context.t(helper),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.inkSoft,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 10),
        RadioGroup<bool>(
          groupValue: value,
          onChanged: (nextValue) {
            if (nextValue != null) onChanged(nextValue);
          },
          child: Wrap(
            spacing: 24,
            runSpacing: 10,
            children: [
              _SitemapRadioOption(
                label: 'generalSettings.seo.sitemap.automaticallyCalculated',
                optionValue: true,
                onChanged: onChanged,
              ),
              _SitemapRadioOption(
                label: 'generalSettings.seo.sitemap.none',
                optionValue: false,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SitemapRadioOption extends StatelessWidget {
  const _SitemapRadioOption({
    required this.label,
    required this.optionValue,
    required this.onChanged,
  });

  final String label;
  final bool optionValue;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(optionValue),
      borderRadius: BorderRadius.circular(AppRadius.value),
      mouseCursor: SystemMouseCursors.click,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Radio<bool>(
            value: optionValue,
            activeColor: AppColors.actionRed,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 4),
          Text(
            context.t(label),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.deepOcean,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _RequiredLabel extends StatelessWidget {
  const _RequiredLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: AppColors.deepOcean,
      fontWeight: FontWeight.w700,
      letterSpacing: 0,
    );
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

class _SitemapActionButton extends StatelessWidget {
  const _SitemapActionButton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: TextButton(
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
        onPressed: () => unawaited(_openPublicSitemap()),
        child: Text(context.t('generalSettings.seo.sitemap.generate')),
      ),
    );
  }
}

class _SitemapGeneratedFile extends StatelessWidget {
  const _SitemapGeneratedFile();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.line.withValues(alpha: 0.9)),
        ),
      ),
      child: Row(
        children: [
          const SymbolIcon(
            Symbols.open_in_new,
            color: AppColors.iconMuted,
            size: 16,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.t('generalSettings.seo.sitemap.fileName'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.actionRed,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(width: 12),
          _SitemapIconButton(
            icon: Symbols.download,
            color: Color(0xFF16A34A),
            background: Color(0xFFE9FBEF),
            onPressed: _openPublicSitemap,
          ),
        ],
      ),
    );
  }
}

class _SitemapIconButton extends StatelessWidget {
  const _SitemapIconButton({
    required this.icon,
    required this.color,
    required this.background,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 28,
      child: TextButton(
        onPressed: () => unawaited(onPressed()),
        style:
            TextButton.styleFrom(
              backgroundColor: background,
              foregroundColor: color,
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.value),
              ),
            ).copyWith(
              mouseCursor: const WidgetStatePropertyAll(
                SystemMouseCursors.click,
              ),
            ),
        child: SymbolIcon(icon, color: color, size: 15),
      ),
    );
  }
}

class _SitemapInfoBox extends StatelessWidget {
  const _SitemapInfoBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.actionRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.value),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.actionRed.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.value),
            ),
            child: const SymbolIcon(
              Symbols.notifications,
              color: AppColors.actionRed,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t('generalSettings.seo.sitemap.infoTitle'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.actionRed,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.t('generalSettings.seo.sitemap.infoDescription'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.deepOcean,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.t('generalSettings.seo.sitemap.cronUrl'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.deepOcean,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                    height: 1.45,
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
        const SizedBox(height: 18),
        _TextInputField(
          label: 'Yandex Webmaster Doğrulama Kodu',
          controller: form.yandexVerificationCode,
        ),
        const SizedBox(height: 18),
        _TextInputField(
          label: 'IndexNow Anahtarı',
          controller: form.indexNowKey,
        ),
        const _FormDivider(),
        _SaveRow(saving: saving, onPressed: onSave),
      ],
    );
  }
}

class _PrivacyNewsletterSettings extends StatefulWidget {
  const _PrivacyNewsletterSettings({
    required this.form,
    required this.saving,
    required this.onSave,
  });

  final _GeneralSettingsForm form;
  final bool saving;
  final VoidCallback onSave;

  @override
  State<_PrivacyNewsletterSettings> createState() =>
      _PrivacyNewsletterSettingsState();
}

class _PrivacyNewsletterSettingsState
    extends State<_PrivacyNewsletterSettings> {
  @override
  Widget build(BuildContext context) {
    final form = widget.form;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SubsectionHeader('Çerez bilgilendirmesi'),
        const SizedBox(height: 14),
        _PrivacyToggleRow(
          items: [
            _PrivacyToggleItem(
              label: 'Çerez barı',
              helper: 'Zorunlu dışı izinleri kullanıcı seçimine bağlar.',
              value: form.cookieBannerEnabled,
              onChanged: (value) =>
                  setState(() => form.cookieBannerEnabled = value),
            ),
            _PrivacyToggleItem(
              label: 'Tercih paneli',
              helper: 'Analitik, reklam ve deneyim izinlerini ayrı gösterir.',
              value: form.cookiePreferencesEnabled,
              onChanged: (value) =>
                  setState(() => form.cookiePreferencesEnabled = value),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _TextInputField(
          label: 'Çerez Başlığı',
          controller: form.cookieBannerTitle,
        ),
        const SizedBox(height: 18),
        _TextAreaField(
          label: 'Çerez Açıklaması',
          minLines: 3,
          controller: form.cookieBannerDescription,
        ),
        const SizedBox(height: 18),
        _TextInputField(
          label: 'Çerez / Gizlilik Politikası URL',
          controller: form.cookiePolicyUrl,
          hintText: '/kurumsal/gizlilik-politikasi',
        ),
        const SizedBox(height: 28),
        const _SubsectionHeader('İlk açılış bülten modalı'),
        const SizedBox(height: 14),
        _PrivacyToggleRow(
          items: [
            _PrivacyToggleItem(
              label: 'Bülten modalı',
              helper: 'İlk açılışta abonelik formunu gösterir.',
              value: form.newsletterPopupEnabled,
              onChanged: (value) =>
                  setState(() => form.newsletterPopupEnabled = value),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _ResponsiveFieldRow(
          children: [
            _TextInputField(
              label: 'Gecikme (saniye)',
              controller: form.newsletterPopupDelaySeconds,
              hintText: '3',
            ),
            _TextInputField(
              label: 'Tekrar Gösterme Aralığı (gün)',
              controller: form.newsletterPopupFrequencyDays,
              hintText: '14',
            ),
          ],
        ),
        const SizedBox(height: 18),
        _ResponsiveFieldRow(
          children: [
            _TextInputField(
              label: 'Modal Başlığı',
              controller: form.newsletterPopupTitle,
            ),
            _TextInputField(
              label: 'Buton Metni',
              controller: form.newsletterPopupButtonLabel,
            ),
          ],
        ),
        const SizedBox(height: 18),
        _TextAreaField(
          label: 'Modal Açıklaması',
          minLines: 3,
          controller: form.newsletterPopupDescription,
        ),
        const _FormDivider(),
        _SaveRow(saving: widget.saving, onPressed: widget.onSave),
      ],
    );
  }
}

class _PrivacyToggleRow extends StatelessWidget {
  const _PrivacyToggleRow({required this.items});

  final List<_PrivacyToggleItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 780 ? 2 : 1;
        const spacing = 14.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final item in items) SizedBox(width: width, child: item),
          ],
        );
      },
    );
  }
}

class _PrivacyToggleItem extends StatelessWidget {
  const _PrivacyToggleItem({
    required this.label,
    required this.helper,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String helper;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 76),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line.withValues(alpha: 0.86)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.t(label),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.deepOcean,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  context.t(helper),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.inkSoft,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _CompactToggle(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _SocialAddressSettings extends StatelessWidget {
  const _SocialAddressSettings({
    required this.form,
    required this.saving,
    required this.canManageSocialPasswords,
    required this.socialPasswordStatus,
    required this.visibleSocialPasswordFields,
    required this.revealingSocialPasswordField,
    required this.onRevealSocialPassword,
    required this.onSave,
  });

  final _GeneralSettingsForm form;
  final bool saving;
  final bool canManageSocialPasswords;
  final SocialPasswordStatus socialPasswordStatus;
  final Set<SocialPasswordField> visibleSocialPasswordFields;
  final SocialPasswordField? revealingSocialPasswordField;
  final ValueChanged<SocialPasswordField> onRevealSocialPassword;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SubsectionHeader('İletişim ve sosyal medya adresleri'),
        const SizedBox(height: 14),
        _ResponsiveFieldRow(
          children: [
            _SocialCredentialInput(
              label: 'WhatsApp',
              urlController: form.socialWhatsappUrl,
              hintText: 'https://wa.me/905xxxxxxxxx',
              passwordController: form.socialPasswordController(
                SocialPasswordField.whatsapp,
              ),
              passwordField: SocialPasswordField.whatsapp,
              showPasswordInput: canManageSocialPasswords,
              hasPassword: socialPasswordStatus.has(
                SocialPasswordField.whatsapp,
              ),
              passwordVisible: visibleSocialPasswordFields.contains(
                SocialPasswordField.whatsapp,
              ),
              revealing:
                  revealingSocialPasswordField == SocialPasswordField.whatsapp,
              onTogglePassword: onRevealSocialPassword,
            ),
            _SocialCredentialInput(
              label: 'Telegram',
              urlController: form.socialTelegramUrl,
              hintText: 'https://t.me/kullaniciadi',
              passwordController: form.socialPasswordController(
                SocialPasswordField.telegram,
              ),
              passwordField: SocialPasswordField.telegram,
              showPasswordInput: canManageSocialPasswords,
              hasPassword: socialPasswordStatus.has(
                SocialPasswordField.telegram,
              ),
              passwordVisible: visibleSocialPasswordFields.contains(
                SocialPasswordField.telegram,
              ),
              revealing:
                  revealingSocialPasswordField == SocialPasswordField.telegram,
              onTogglePassword: onRevealSocialPassword,
            ),
          ],
        ),
        const SizedBox(height: 18),
        _ResponsiveFieldRow(
          children: [
            _SocialCredentialInput(
              label: 'Instagram',
              urlController: form.socialInstagramUrl,
              hintText: 'https://instagram.com/kullaniciadi',
              passwordController: form.socialPasswordController(
                SocialPasswordField.instagram,
              ),
              passwordField: SocialPasswordField.instagram,
              showPasswordInput: canManageSocialPasswords,
              hasPassword: socialPasswordStatus.has(
                SocialPasswordField.instagram,
              ),
              passwordVisible: visibleSocialPasswordFields.contains(
                SocialPasswordField.instagram,
              ),
              revealing:
                  revealingSocialPasswordField == SocialPasswordField.instagram,
              onTogglePassword: onRevealSocialPassword,
            ),
            _SocialCredentialInput(
              label: 'Facebook',
              urlController: form.socialFacebookUrl,
              hintText: 'https://facebook.com/sayfa',
              passwordController: form.socialPasswordController(
                SocialPasswordField.facebook,
              ),
              passwordField: SocialPasswordField.facebook,
              showPasswordInput: canManageSocialPasswords,
              hasPassword: socialPasswordStatus.has(
                SocialPasswordField.facebook,
              ),
              passwordVisible: visibleSocialPasswordFields.contains(
                SocialPasswordField.facebook,
              ),
              revealing:
                  revealingSocialPasswordField == SocialPasswordField.facebook,
              onTogglePassword: onRevealSocialPassword,
            ),
          ],
        ),
        const SizedBox(height: 18),
        _ResponsiveFieldRow(
          children: [
            _SocialCredentialInput(
              label: 'X (Twitter)',
              urlController: form.socialXUrl,
              hintText: 'https://x.com/kullaniciadi',
              passwordController: form.socialPasswordController(
                SocialPasswordField.x,
              ),
              passwordField: SocialPasswordField.x,
              showPasswordInput: canManageSocialPasswords,
              hasPassword: socialPasswordStatus.has(SocialPasswordField.x),
              passwordVisible: visibleSocialPasswordFields.contains(
                SocialPasswordField.x,
              ),
              revealing: revealingSocialPasswordField == SocialPasswordField.x,
              onTogglePassword: onRevealSocialPassword,
            ),
            _SocialCredentialInput(
              label: 'YouTube',
              urlController: form.socialYoutubeUrl,
              hintText: 'https://youtube.com/@kanal',
              passwordController: form.socialPasswordController(
                SocialPasswordField.youtube,
              ),
              passwordField: SocialPasswordField.youtube,
              showPasswordInput: canManageSocialPasswords,
              hasPassword: socialPasswordStatus.has(
                SocialPasswordField.youtube,
              ),
              passwordVisible: visibleSocialPasswordFields.contains(
                SocialPasswordField.youtube,
              ),
              revealing:
                  revealingSocialPasswordField == SocialPasswordField.youtube,
              onTogglePassword: onRevealSocialPassword,
            ),
          ],
        ),
        const SizedBox(height: 18),
        _ResponsiveFieldRow(
          children: [
            _SocialCredentialInput(
              label: 'TikTok',
              urlController: form.socialTiktokUrl,
              hintText: 'https://tiktok.com/@kullaniciadi',
              passwordController: form.socialPasswordController(
                SocialPasswordField.tiktok,
              ),
              passwordField: SocialPasswordField.tiktok,
              showPasswordInput: canManageSocialPasswords,
              hasPassword: socialPasswordStatus.has(SocialPasswordField.tiktok),
              passwordVisible: visibleSocialPasswordFields.contains(
                SocialPasswordField.tiktok,
              ),
              revealing:
                  revealingSocialPasswordField == SocialPasswordField.tiktok,
              onTogglePassword: onRevealSocialPassword,
            ),
            _SocialCredentialInput(
              label: 'LinkedIn',
              urlController: form.socialLinkedinUrl,
              hintText: 'https://linkedin.com/company/sayfa',
              passwordController: form.socialPasswordController(
                SocialPasswordField.linkedin,
              ),
              passwordField: SocialPasswordField.linkedin,
              showPasswordInput: canManageSocialPasswords,
              hasPassword: socialPasswordStatus.has(
                SocialPasswordField.linkedin,
              ),
              passwordVisible: visibleSocialPasswordFields.contains(
                SocialPasswordField.linkedin,
              ),
              revealing:
                  revealingSocialPasswordField == SocialPasswordField.linkedin,
              onTogglePassword: onRevealSocialPassword,
            ),
          ],
        ),
        const SizedBox(height: 18),
        _ResponsiveFieldRow(
          children: [
            _SocialCredentialInput(
              label: 'Pinterest',
              urlController: form.socialPinterestUrl,
              hintText: 'https://pinterest.com/kullaniciadi',
              passwordController: form.socialPasswordController(
                SocialPasswordField.pinterest,
              ),
              passwordField: SocialPasswordField.pinterest,
              showPasswordInput: canManageSocialPasswords,
              hasPassword: socialPasswordStatus.has(
                SocialPasswordField.pinterest,
              ),
              passwordVisible: visibleSocialPasswordFields.contains(
                SocialPasswordField.pinterest,
              ),
              revealing:
                  revealingSocialPasswordField == SocialPasswordField.pinterest,
              onTogglePassword: onRevealSocialPassword,
            ),
            _SocialCredentialInput(
              label: 'Discord',
              urlController: form.socialDiscordUrl,
              hintText: 'https://discord.gg/davet',
              passwordController: form.socialPasswordController(
                SocialPasswordField.discord,
              ),
              passwordField: SocialPasswordField.discord,
              showPasswordInput: canManageSocialPasswords,
              hasPassword: socialPasswordStatus.has(
                SocialPasswordField.discord,
              ),
              passwordVisible: visibleSocialPasswordFields.contains(
                SocialPasswordField.discord,
              ),
              revealing:
                  revealingSocialPasswordField == SocialPasswordField.discord,
              onTogglePassword: onRevealSocialPassword,
            ),
          ],
        ),
        const _FormDivider(),
        _SaveRow(saving: saving, onPressed: onSave),
      ],
    );
  }
}

class _ContactSettings extends StatelessWidget {
  const _ContactSettings({
    required this.form,
    required this.saving,
    required this.canManageContactEmailPasswords,
    required this.contactEmailPasswordStatus,
    required this.visibleContactEmailPasswordFields,
    required this.revealingContactEmailPasswordField,
    required this.onRevealContactEmailPassword,
    required this.onSave,
  });

  final _GeneralSettingsForm form;
  final bool saving;
  final bool canManageContactEmailPasswords;
  final ContactEmailPasswordStatus contactEmailPasswordStatus;
  final Set<ContactEmailPasswordField> visibleContactEmailPasswordFields;
  final ContactEmailPasswordField? revealingContactEmailPasswordField;
  final ValueChanged<ContactEmailPasswordField> onRevealContactEmailPassword;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SubsectionHeader('Genel iletişim bilgileri'),
        const SizedBox(height: 14),
        _ResponsiveFieldRow(
          children: [
            _TextInputField(label: 'Telefon', controller: form.contactPhone),
            _TextInputField(label: 'Şehir', controller: form.contactCity),
          ],
        ),
        const SizedBox(height: 18),
        _TextAreaField(
          label: 'Adres',
          minLines: 3,
          controller: form.contactAddress,
        ),
        const SizedBox(height: 18),
        _TextInputField(
          label: 'Adres konum linki',
          hintText: 'https://maps.google.com/...',
          controller: form.contactLocationUrl,
        ),
        const SizedBox(height: 28),
        const _SubsectionHeader('Mesajlaşma adresleri'),
        const SizedBox(height: 14),
        _ResponsiveFieldRow(
          children: [
            _TextInputField(
              label: 'WhatsApp Adresi',
              hintText: 'https://wa.me/905xxxxxxxxx',
              controller: form.contactWhatsappUrl,
            ),
            _TextInputField(
              label: 'Telegram Adresi',
              hintText: 'https://t.me/kullaniciadi',
              controller: form.contactTelegramUrl,
            ),
          ],
        ),
        const SizedBox(height: 28),
        const _SubsectionHeader('E-posta adresleri'),
        const SizedBox(height: 14),
        _ResponsiveFieldRow(
          children: [
            _ContactEmailCredentialInput(
              label: 'Genel Bilgi',
              emailController: form.contactEmailInfo,
              hintText: 'info@pateez.com',
              passwordController: form.contactEmailPasswordController(
                ContactEmailPasswordField.info,
              ),
              passwordField: ContactEmailPasswordField.info,
              showPasswordInput: canManageContactEmailPasswords,
              hasPassword: contactEmailPasswordStatus.has(
                ContactEmailPasswordField.info,
              ),
              passwordVisible: visibleContactEmailPasswordFields.contains(
                ContactEmailPasswordField.info,
              ),
              revealing:
                  revealingContactEmailPasswordField ==
                  ContactEmailPasswordField.info,
              onTogglePassword: onRevealContactEmailPassword,
            ),
            _ContactEmailCredentialInput(
              label: 'Destek',
              emailController: form.contactEmailSupport,
              hintText: 'destek@pateez.com',
              passwordController: form.contactEmailPasswordController(
                ContactEmailPasswordField.support,
              ),
              passwordField: ContactEmailPasswordField.support,
              showPasswordInput: canManageContactEmailPasswords,
              hasPassword: contactEmailPasswordStatus.has(
                ContactEmailPasswordField.support,
              ),
              passwordVisible: visibleContactEmailPasswordFields.contains(
                ContactEmailPasswordField.support,
              ),
              revealing:
                  revealingContactEmailPasswordField ==
                  ContactEmailPasswordField.support,
              onTogglePassword: onRevealContactEmailPassword,
            ),
          ],
        ),
        const SizedBox(height: 18),
        _ResponsiveFieldRow(
          children: [
            _ContactEmailCredentialInput(
              label: 'Haber',
              emailController: form.contactEmailNews,
              hintText: 'haber@pateez.com',
              passwordController: form.contactEmailPasswordController(
                ContactEmailPasswordField.news,
              ),
              passwordField: ContactEmailPasswordField.news,
              showPasswordInput: canManageContactEmailPasswords,
              hasPassword: contactEmailPasswordStatus.has(
                ContactEmailPasswordField.news,
              ),
              passwordVisible: visibleContactEmailPasswordFields.contains(
                ContactEmailPasswordField.news,
              ),
              revealing:
                  revealingContactEmailPasswordField ==
                  ContactEmailPasswordField.news,
              onTogglePassword: onRevealContactEmailPassword,
            ),
            _ContactEmailCredentialInput(
              label: 'Reklam',
              emailController: form.contactEmailAds,
              hintText: 'reklam@pateez.com',
              passwordController: form.contactEmailPasswordController(
                ContactEmailPasswordField.ads,
              ),
              passwordField: ContactEmailPasswordField.ads,
              showPasswordInput: canManageContactEmailPasswords,
              hasPassword: contactEmailPasswordStatus.has(
                ContactEmailPasswordField.ads,
              ),
              passwordVisible: visibleContactEmailPasswordFields.contains(
                ContactEmailPasswordField.ads,
              ),
              revealing:
                  revealingContactEmailPasswordField ==
                  ContactEmailPasswordField.ads,
              onTogglePassword: onRevealContactEmailPassword,
            ),
          ],
        ),
        const _FormDivider(),
        _SaveRow(saving: saving, onPressed: onSave),
      ],
    );
  }
}

class _SocialCredentialInput extends StatelessWidget {
  const _SocialCredentialInput({
    required this.label,
    required this.urlController,
    required this.hintText,
    required this.passwordController,
    required this.passwordField,
    required this.showPasswordInput,
    required this.hasPassword,
    required this.passwordVisible,
    required this.revealing,
    required this.onTogglePassword,
  });

  final String label;
  final TextEditingController urlController;
  final String hintText;
  final TextEditingController passwordController;
  final SocialPasswordField passwordField;
  final bool showPasswordInput;
  final bool hasPassword;
  final bool passwordVisible;
  final bool revealing;
  final ValueChanged<SocialPasswordField> onTogglePassword;

  @override
  Widget build(BuildContext context) {
    final urlField = _TextInputField(
      label: label,
      controller: urlController,
      hintText: hintText,
    );
    if (!showPasswordInput) return urlField;

    final passwordFieldWidget = _SocialPasswordInputField(
      controller: passwordController,
      hasPassword: hasPassword,
      visible: passwordVisible,
      revealing: revealing,
      onToggleVisibility: () => onTogglePassword(passwordField),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 520) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              urlField,
              const SizedBox(height: 12),
              passwordFieldWidget,
            ],
          );
        }

        final passwordWidth = (constraints.maxWidth * 0.32).clamp(180.0, 240.0);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: urlField),
            const SizedBox(width: 12),
            SizedBox(width: passwordWidth, child: passwordFieldWidget),
          ],
        );
      },
    );
  }
}

class _ContactEmailCredentialInput extends StatelessWidget {
  const _ContactEmailCredentialInput({
    required this.label,
    required this.emailController,
    required this.hintText,
    required this.passwordController,
    required this.passwordField,
    required this.showPasswordInput,
    required this.hasPassword,
    required this.passwordVisible,
    required this.revealing,
    required this.onTogglePassword,
  });

  final String label;
  final TextEditingController emailController;
  final String hintText;
  final TextEditingController passwordController;
  final ContactEmailPasswordField passwordField;
  final bool showPasswordInput;
  final bool hasPassword;
  final bool passwordVisible;
  final bool revealing;
  final ValueChanged<ContactEmailPasswordField> onTogglePassword;

  @override
  Widget build(BuildContext context) {
    final emailField = _TextInputField(
      label: label,
      controller: emailController,
      hintText: hintText,
    );
    if (!showPasswordInput) return emailField;

    final passwordFieldWidget = _SocialPasswordInputField(
      controller: passwordController,
      hasPassword: hasPassword,
      visible: passwordVisible,
      revealing: revealing,
      onToggleVisibility: () => onTogglePassword(passwordField),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 520) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              emailField,
              const SizedBox(height: 12),
              passwordFieldWidget,
            ],
          );
        }

        final passwordWidth = (constraints.maxWidth * 0.32).clamp(180.0, 240.0);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: emailField),
            const SizedBox(width: 12),
            SizedBox(width: passwordWidth, child: passwordFieldWidget),
          ],
        );
      },
    );
  }
}

class _SocialPasswordInputField extends StatelessWidget {
  const _SocialPasswordInputField({
    required this.controller,
    required this.hasPassword,
    required this.visible,
    required this.revealing,
    required this.onToggleVisibility,
  });

  final TextEditingController controller;
  final bool hasPassword;
  final bool visible;
  final bool revealing;
  final VoidCallback onToggleVisibility;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _FieldLabel('Şifre'),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: TextFormField(
            controller: controller,
            obscureText: !visible,
            enableSuggestions: false,
            autocorrect: false,
            mouseCursor: SystemMouseCursors.text,
            cursorColor: AppColors.support,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.deepOcean,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
            decoration: _inputDecoration(
              context,
              hintText: hasPassword ? 'Kayıtlı şifre var' : 'Şifre',
              suffixIcon: IconButton(
                tooltip: visible ? 'Gizle' : 'Göster',
                onPressed: revealing ? null : onToggleVisibility,
                icon: revealing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : SymbolIcon(
                        visible ? Symbols.visibility_off : Symbols.visibility,
                        color: AppColors.iconMuted,
                        size: 18,
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SuperAdminPasswordDialog extends StatefulWidget {
  const _SuperAdminPasswordDialog();

  @override
  State<_SuperAdminPasswordDialog> createState() =>
      _SuperAdminPasswordDialogState();
}

class _SuperAdminPasswordDialogState extends State<_SuperAdminPasswordDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text;
    if (value.trim().isEmpty) return;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.value),
      ),
      title: Text(
        'Süper yönetici şifresi',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: AppColors.deepOcean,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
      content: SizedBox(
        width: 360,
        child: TextField(
          controller: _controller,
          obscureText: true,
          enableSuggestions: false,
          autocorrect: false,
          autofocus: true,
          onSubmitted: (_) => _submit(),
          decoration: _inputDecoration(context, hintText: 'Şifre'),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('İptal'),
        ),
        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.actionRed,
            foregroundColor: Colors.white,
          ),
          child: const Text('Göster'),
        ),
      ],
    );
  }
}

class _SocialAuthSettings extends StatefulWidget {
  const _SocialAuthSettings({
    required this.form,
    required this.saving,
    required this.onSave,
  });

  final _GeneralSettingsForm form;
  final bool saving;
  final VoidCallback onSave;

  @override
  State<_SocialAuthSettings> createState() => _SocialAuthSettingsState();
}

class _SocialAuthSettingsState extends State<_SocialAuthSettings> {
  @override
  Widget build(BuildContext context) {
    final form = widget.form;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ResponsiveFieldRow(
          children: [
            _TextInputField(
              label: 'Mobil yönlendirme şeması',
              controller: form.socialAuthRedirectScheme,
              hintText: 'com.pateez.app',
            ),
            _TextInputField(
              label: 'Mobil yönlendirme hostu',
              controller: form.socialAuthRedirectHost,
              hintText: 'login-callback',
            ),
          ],
        ),
        const SizedBox(height: 22),
        const _SubsectionHeader('Sosyal giriş sağlayıcıları'),
        const SizedBox(height: 14),
        _SocialProviderGrid(
          items: [
            _SocialProviderItem(
              label: 'Google',
              value: form.socialAuthGoogleEnabled,
              onChanged: (value) =>
                  setState(() => form.socialAuthGoogleEnabled = value),
            ),
            _SocialProviderItem(
              label: 'Apple',
              value: form.socialAuthAppleEnabled,
              onChanged: (value) =>
                  setState(() => form.socialAuthAppleEnabled = value),
            ),
            _SocialProviderItem(
              label: 'Facebook',
              value: form.socialAuthFacebookEnabled,
              onChanged: (value) =>
                  setState(() => form.socialAuthFacebookEnabled = value),
            ),
            _SocialProviderItem(
              label: 'X / Twitter',
              value: form.socialAuthXEnabled,
              onChanged: (value) =>
                  setState(() => form.socialAuthXEnabled = value),
            ),
          ],
        ),
        const _FormDivider(),
        _SaveRow(saving: widget.saving, onPressed: widget.onSave),
      ],
    );
  }
}

class _SocialProviderGrid extends StatelessWidget {
  const _SocialProviderGrid({required this.items});

  final List<_SocialProviderItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 980
            ? 4
            : constraints.maxWidth >= 620
            ? 2
            : 1;
        const spacing = 14.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final item in items) SizedBox(width: width, child: item),
          ],
        );
      },
    );
  }
}

class _SocialProviderItem extends StatelessWidget {
  const _SocialProviderItem({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line.withValues(alpha: 0.86)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.t(label),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.deepOcean,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(width: 12),
          _CompactToggle(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _CompactToggle extends StatelessWidget {
  const _CompactToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    const width = 42.0;
    const height = 24.0;
    const padding = 3.0;
    const knobSize = 18.0;

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
            width: width,
            height: height,
            padding: const EdgeInsets.all(padding),
            decoration: BoxDecoration(
              color: value ? AppColors.actionRed : AppColors.softLine,
              borderRadius: BorderRadius.circular(height / 2),
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
                width: knobSize,
                height: knobSize,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: value
                    ? const SymbolIcon(
                        Symbols.check,
                        color: AppColors.actionRed,
                        size: 12,
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
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
      child: AdminCachedImage(
        url: publicUrl(url),
        fit: BoxFit.contain,
        memCacheWidth: 200,
        errorWidget: const SymbolIcon(
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
              child: AdminCachedImage(
                url: publicUrl(url),
                fit: BoxFit.contain,
                memCacheWidth: 400,
                errorWidget: _LogoFallback(compact: compact),
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

InputDecoration _inputDecoration(
  BuildContext context, {
  String? hintText,
  Widget? suffixIcon,
}) {
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
    suffixIcon: suffixIcon,
    suffixIconConstraints: suffixIcon == null
        ? null
        : const BoxConstraints(minWidth: 40, minHeight: 40),
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
  socialAddresses('Sosyal Adresler'),
  services('Google & Servisler'),
  privacy('Çerez & Bülten'),
  socialAuth('Sosyal Giriş'),
  customCode('Özel Kodlar'),
  robots('Robots & Teknik'),
  contact('İletişim');

  const _GeneralSettingsTab(this.title);

  final String title;
}
