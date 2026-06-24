import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pateeznews_admin/core/network/admin_api_headers.dart';

import '../../auth/data/admin_auth_models.dart';

enum GeneralSettingsLogoField {
  logoUrl('logo_url', 'pateezlogowhite.png'),
  footerLogoUrl('footer_logo_url', 'pateezlogofooter.png'),
  darkLogoUrl('dark_logo_url', 'pateezlogodark.png'),
  emailLogoUrl('email_logo_url', 'pateezlogoepost.png'),
  faviconUrl('favicon_url', 'pateezlogoicon.png'),
  ogImageUrl('og_image_url', 'pateezlogoson.png');

  const GeneralSettingsLogoField(this.column, this.uploadFilename);

  final String column;
  final String uploadFilename;

  String get uploadBaseName {
    final extensionIndex = uploadFilename.lastIndexOf('.');
    if (extensionIndex <= 0) return uploadFilename;
    return uploadFilename.substring(0, extensionIndex);
  }
}

enum SocialPasswordField {
  whatsapp('whatsapp'),
  telegram('telegram'),
  instagram('instagram'),
  facebook('facebook'),
  x('x'),
  youtube('youtube'),
  tiktok('tiktok'),
  linkedin('linkedin'),
  pinterest('pinterest'),
  discord('discord');

  const SocialPasswordField(this.key);

  final String key;

  static SocialPasswordField? fromKey(String value) {
    final normalized = value.trim().toLowerCase();
    for (final field in values) {
      if (field.key == normalized) return field;
    }
    return null;
  }
}

class SocialPasswordStatus {
  const SocialPasswordStatus(this._values);

  static const empty = SocialPasswordStatus({});

  final Map<SocialPasswordField, bool> _values;

  bool has(SocialPasswordField field) => _values[field] ?? false;

  factory SocialPasswordStatus.fromJson(Map<String, Object?> json) {
    final raw = json['hasPasswords'] ?? json['has_passwords'];
    if (raw is! Map) return SocialPasswordStatus.empty;
    final values = <SocialPasswordField, bool>{};
    for (final entry in raw.entries) {
      final field = SocialPasswordField.fromKey(entry.key.toString());
      if (field != null) values[field] = entry.value == true;
    }
    return SocialPasswordStatus(values);
  }
}

enum ContactEmailPasswordField {
  info('info'),
  support('support'),
  news('news'),
  ads('ads');

  const ContactEmailPasswordField(this.key);

  final String key;

  static ContactEmailPasswordField? fromKey(String value) {
    final normalized = value.trim().toLowerCase();
    for (final field in values) {
      if (field.key == normalized) return field;
    }
    return null;
  }
}

class ContactEmailPasswordStatus {
  const ContactEmailPasswordStatus(this._values);

  static const empty = ContactEmailPasswordStatus({});

  final Map<ContactEmailPasswordField, bool> _values;

  bool has(ContactEmailPasswordField field) => _values[field] ?? false;

  factory ContactEmailPasswordStatus.fromJson(Map<String, Object?> json) {
    final raw = json['hasPasswords'] ?? json['has_passwords'];
    if (raw is! Map) return ContactEmailPasswordStatus.empty;
    final values = <ContactEmailPasswordField, bool>{};
    for (final entry in raw.entries) {
      final field = ContactEmailPasswordField.fromKey(entry.key.toString());
      if (field != null) values[field] = entry.value == true;
    }
    return ContactEmailPasswordStatus(values);
  }
}

class GeneralSettingsData {
  const GeneralSettingsData({
    required this.languageCode,
    required this.siteName,
    required this.timezone,
    required this.footerAbout,
    required this.optionalUrlButtonName,
    required this.copyrightText,
    required this.logoUrl,
    required this.footerLogoUrl,
    required this.darkLogoUrl,
    required this.emailLogoUrl,
    required this.faviconUrl,
    required this.homeTitle,
    required this.metaDescription,
    required this.metaKeywords,
    required this.canonicalUrl,
    required this.ogImageUrl,
    required this.organizationLegalName,
    required this.organizationPhone,
    required this.organizationAddress,
    required this.contactPhone,
    required this.contactCity,
    required this.contactAddress,
    required this.contactLocationUrl,
    required this.contactWhatsappUrl,
    required this.contactTelegramUrl,
    required this.contactEmailInfo,
    required this.contactEmailSupport,
    required this.contactEmailNews,
    required this.contactEmailAds,
    required this.twitterUsername,
    required this.fbAppId,
    required this.socialWhatsappUrl,
    required this.socialTelegramUrl,
    required this.socialInstagramUrl,
    required this.socialFacebookUrl,
    required this.socialXUrl,
    required this.socialYoutubeUrl,
    required this.socialTiktokUrl,
    required this.socialLinkedinUrl,
    required this.socialPinterestUrl,
    required this.socialDiscordUrl,
    required this.googleAnalyticsId,
    required this.googleSearchConsoleCode,
    required this.bingVerificationCode,
    required this.yandexVerificationCode,
    required this.indexNowKey,
    required this.cookieBannerEnabled,
    required this.cookiePreferencesEnabled,
    required this.cookieBannerTitle,
    required this.cookieBannerDescription,
    required this.cookiePolicyUrl,
    required this.newsletterPopupEnabled,
    required this.newsletterPopupDelaySeconds,
    required this.newsletterPopupFrequencyDays,
    required this.newsletterPopupTitle,
    required this.newsletterPopupDescription,
    required this.newsletterPopupButtonLabel,
    required this.socialAuthGoogleEnabled,
    required this.socialAuthAppleEnabled,
    required this.socialAuthFacebookEnabled,
    required this.socialAuthXEnabled,
    required this.socialAuthRedirectScheme,
    required this.socialAuthRedirectHost,
    required this.robotsTxt,
    required this.headerCustomCodes,
    required this.footerCustomCodes,
  });

  factory GeneralSettingsData.empty(String languageCode) {
    return GeneralSettingsData(
      languageCode: languageCode,
      siteName: '',
      timezone: 'Europe/Istanbul',
      footerAbout: '',
      optionalUrlButtonName: '',
      copyrightText: '',
      logoUrl: '',
      footerLogoUrl: '',
      darkLogoUrl: '',
      emailLogoUrl: '',
      faviconUrl: '',
      homeTitle: '',
      metaDescription: '',
      metaKeywords: '',
      canonicalUrl: '',
      ogImageUrl: '',
      organizationLegalName: '',
      organizationPhone: '',
      organizationAddress: '',
      contactPhone: '',
      contactCity: '',
      contactAddress: '',
      contactLocationUrl: '',
      contactWhatsappUrl: '',
      contactTelegramUrl: '',
      contactEmailInfo: '',
      contactEmailSupport: '',
      contactEmailNews: '',
      contactEmailAds: '',
      twitterUsername: '',
      fbAppId: '',
      socialWhatsappUrl: '',
      socialTelegramUrl: '',
      socialInstagramUrl: '',
      socialFacebookUrl: '',
      socialXUrl: '',
      socialYoutubeUrl: '',
      socialTiktokUrl: '',
      socialLinkedinUrl: '',
      socialPinterestUrl: '',
      socialDiscordUrl: '',
      googleAnalyticsId: '',
      googleSearchConsoleCode: '',
      bingVerificationCode: '',
      yandexVerificationCode: '',
      indexNowKey: '',
      cookieBannerEnabled: true,
      cookiePreferencesEnabled: true,
      cookieBannerTitle: 'Gizliliğinize önem veriyoruz',
      cookieBannerDescription:
          'Pateez, sitenin güvenli çalışması için zorunlu çerezleri kullanır. Onayınızla ölçüm, reklam ve deneyim iyileştirme çerezleri de etkinleşir.',
      cookiePolicyUrl: '',
      newsletterPopupEnabled: true,
      newsletterPopupDelaySeconds: 3,
      newsletterPopupFrequencyDays: 14,
      newsletterPopupTitle: 'Pateez bültenine katıl',
      newsletterPopupDescription:
          'Niğde ve İç Anadolu gündeminden öne çıkanları e-postana taşıyalım.',
      newsletterPopupButtonLabel: 'Abone ol',
      socialAuthGoogleEnabled: true,
      socialAuthAppleEnabled: true,
      socialAuthFacebookEnabled: true,
      socialAuthXEnabled: true,
      socialAuthRedirectScheme: 'com.pateez.app',
      socialAuthRedirectHost: 'login-callback',
      robotsTxt: '',
      headerCustomCodes: '',
      footerCustomCodes: '',
    );
  }

  factory GeneralSettingsData.fromJson(
    Map<String, Object?> json,
    String languageCode,
  ) {
    return GeneralSettingsData(
      languageCode: _string(json['language_code'], fallback: languageCode),
      siteName: _string(json['site_name']),
      timezone: _string(json['timezone'], fallback: 'Europe/Istanbul'),
      footerAbout: _string(json['footer_about']),
      optionalUrlButtonName: _string(json['optional_url_button_name']),
      copyrightText: _string(json['copyright_text']),
      logoUrl: _string(json['logo_url']),
      footerLogoUrl: _string(json['footer_logo_url']),
      darkLogoUrl: _string(json['dark_logo_url']),
      emailLogoUrl: _string(json['email_logo_url']),
      faviconUrl: _string(json['favicon_url']),
      homeTitle: _string(json['home_title']),
      metaDescription: _string(json['meta_description']),
      metaKeywords: _string(json['meta_keywords']),
      canonicalUrl: _string(json['canonical_url']),
      ogImageUrl: _string(json['og_image_url']),
      organizationLegalName: _string(json['organization_legal_name']),
      organizationPhone: _string(json['organization_phone']),
      organizationAddress: _string(json['organization_address']),
      contactPhone: _string(json['contact_phone']),
      contactCity: _string(json['contact_city']),
      contactAddress: _string(json['contact_address']),
      contactLocationUrl: _string(json['contact_location_url']),
      contactWhatsappUrl: _string(json['contact_whatsapp_url']),
      contactTelegramUrl: _string(json['contact_telegram_url']),
      contactEmailInfo: _string(json['contact_email_info']),
      contactEmailSupport: _string(json['contact_email_support']),
      contactEmailNews: _string(json['contact_email_news']),
      contactEmailAds: _string(json['contact_email_ads']),
      twitterUsername: _string(json['twitter_username']),
      fbAppId: _string(json['fb_app_id']),
      socialWhatsappUrl: _string(json['social_whatsapp_url']),
      socialTelegramUrl: _string(json['social_telegram_url']),
      socialInstagramUrl: _string(json['social_instagram_url']),
      socialFacebookUrl: _string(json['social_facebook_url']),
      socialXUrl: _string(json['social_x_url']),
      socialYoutubeUrl: _string(json['social_youtube_url']),
      socialTiktokUrl: _string(json['social_tiktok_url']),
      socialLinkedinUrl: _string(json['social_linkedin_url']),
      socialPinterestUrl: _string(json['social_pinterest_url']),
      socialDiscordUrl: _string(json['social_discord_url']),
      googleAnalyticsId: _string(json['google_analytics_id']),
      googleSearchConsoleCode: _string(json['google_search_console_code']),
      bingVerificationCode: _string(json['bing_verification_code']),
      yandexVerificationCode: _string(json['yandex_verification_code']),
      indexNowKey: _string(json['indexnow_key']),
      cookieBannerEnabled: _bool(json['cookie_banner_enabled'], fallback: true),
      cookiePreferencesEnabled: _bool(
        json['cookie_preferences_enabled'],
        fallback: true,
      ),
      cookieBannerTitle: _string(
        json['cookie_banner_title'],
        fallback: 'Gizliliğinize önem veriyoruz',
      ),
      cookieBannerDescription: _string(
        json['cookie_banner_description'],
        fallback:
            'Pateez, sitenin güvenli çalışması için zorunlu çerezleri kullanır. Onayınızla ölçüm, reklam ve deneyim iyileştirme çerezleri de etkinleşir.',
      ),
      cookiePolicyUrl: _string(json['cookie_policy_url']),
      newsletterPopupEnabled: _bool(
        json['newsletter_popup_enabled'],
        fallback: true,
      ),
      newsletterPopupDelaySeconds: _int(
        json['newsletter_popup_delay_seconds'],
        fallback: 3,
      ),
      newsletterPopupFrequencyDays: _int(
        json['newsletter_popup_frequency_days'],
        fallback: 14,
      ),
      newsletterPopupTitle: _string(
        json['newsletter_popup_title'],
        fallback: 'Pateez bültenine katıl',
      ),
      newsletterPopupDescription: _string(
        json['newsletter_popup_description'],
        fallback:
            'Niğde ve İç Anadolu gündeminden öne çıkanları e-postana taşıyalım.',
      ),
      newsletterPopupButtonLabel: _string(
        json['newsletter_popup_button_label'],
        fallback: 'Abone ol',
      ),
      socialAuthGoogleEnabled: _bool(
        json['social_auth_google_enabled'],
        fallback: true,
      ),
      socialAuthAppleEnabled: _bool(
        json['social_auth_apple_enabled'],
        fallback: true,
      ),
      socialAuthFacebookEnabled: _bool(
        json['social_auth_facebook_enabled'],
        fallback: true,
      ),
      socialAuthXEnabled: _bool(json['social_auth_x_enabled'], fallback: true),
      socialAuthRedirectScheme: _string(
        json['social_auth_redirect_scheme'],
        fallback: 'com.pateez.app',
      ),
      socialAuthRedirectHost: _string(
        json['social_auth_redirect_host'],
        fallback: 'login-callback',
      ),
      robotsTxt: _string(json['robots_txt']),
      headerCustomCodes: _string(json['header_custom_codes']),
      footerCustomCodes: _string(json['footer_custom_codes']),
    );
  }

  final String languageCode;
  final String siteName;
  final String timezone;
  final String footerAbout;
  final String optionalUrlButtonName;
  final String copyrightText;
  final String logoUrl;
  final String footerLogoUrl;
  final String darkLogoUrl;
  final String emailLogoUrl;
  final String faviconUrl;
  final String homeTitle;
  final String metaDescription;
  final String metaKeywords;
  final String canonicalUrl;
  final String ogImageUrl;
  final String organizationLegalName;
  final String organizationPhone;
  final String organizationAddress;
  final String contactPhone;
  final String contactCity;
  final String contactAddress;
  final String contactLocationUrl;
  final String contactWhatsappUrl;
  final String contactTelegramUrl;
  final String contactEmailInfo;
  final String contactEmailSupport;
  final String contactEmailNews;
  final String contactEmailAds;
  final String twitterUsername;
  final String fbAppId;
  final String socialWhatsappUrl;
  final String socialTelegramUrl;
  final String socialInstagramUrl;
  final String socialFacebookUrl;
  final String socialXUrl;
  final String socialYoutubeUrl;
  final String socialTiktokUrl;
  final String socialLinkedinUrl;
  final String socialPinterestUrl;
  final String socialDiscordUrl;
  final String googleAnalyticsId;
  final String googleSearchConsoleCode;
  final String bingVerificationCode;
  final String yandexVerificationCode;
  final String indexNowKey;
  final bool cookieBannerEnabled;
  final bool cookiePreferencesEnabled;
  final String cookieBannerTitle;
  final String cookieBannerDescription;
  final String cookiePolicyUrl;
  final bool newsletterPopupEnabled;
  final int newsletterPopupDelaySeconds;
  final int newsletterPopupFrequencyDays;
  final String newsletterPopupTitle;
  final String newsletterPopupDescription;
  final String newsletterPopupButtonLabel;
  final bool socialAuthGoogleEnabled;
  final bool socialAuthAppleEnabled;
  final bool socialAuthFacebookEnabled;
  final bool socialAuthXEnabled;
  final String socialAuthRedirectScheme;
  final String socialAuthRedirectHost;
  final String robotsTxt;
  final String headerCustomCodes;
  final String footerCustomCodes;

  Map<String, Object?> toJson() {
    return {
      'language_code': languageCode,
      'site_name': siteName,
      'timezone': timezone,
      'footer_about': footerAbout,
      'optional_url_button_name': optionalUrlButtonName,
      'copyright_text': copyrightText,
      'logo_url': logoUrl,
      'footer_logo_url': footerLogoUrl,
      'dark_logo_url': darkLogoUrl,
      'email_logo_url': emailLogoUrl,
      'favicon_url': faviconUrl,
      'home_title': homeTitle,
      'meta_description': metaDescription,
      'meta_keywords': metaKeywords,
      'canonical_url': canonicalUrl,
      'og_image_url': ogImageUrl,
      'organization_legal_name': organizationLegalName,
      'organization_phone': organizationPhone,
      'organization_address': organizationAddress,
      'contact_phone': contactPhone,
      'contact_city': contactCity,
      'contact_address': contactAddress,
      'contact_location_url': contactLocationUrl,
      'contact_whatsapp_url': contactWhatsappUrl,
      'contact_telegram_url': contactTelegramUrl,
      'contact_email_info': contactEmailInfo,
      'contact_email_support': contactEmailSupport,
      'contact_email_news': contactEmailNews,
      'contact_email_ads': contactEmailAds,
      'twitter_username': twitterUsername,
      'fb_app_id': fbAppId,
      'social_whatsapp_url': socialWhatsappUrl,
      'social_telegram_url': socialTelegramUrl,
      'social_instagram_url': socialInstagramUrl,
      'social_facebook_url': socialFacebookUrl,
      'social_x_url': socialXUrl,
      'social_youtube_url': socialYoutubeUrl,
      'social_tiktok_url': socialTiktokUrl,
      'social_linkedin_url': socialLinkedinUrl,
      'social_pinterest_url': socialPinterestUrl,
      'social_discord_url': socialDiscordUrl,
      'google_analytics_id': googleAnalyticsId,
      'google_search_console_code': googleSearchConsoleCode,
      'bing_verification_code': bingVerificationCode,
      'yandex_verification_code': yandexVerificationCode,
      'indexnow_key': indexNowKey,
      'cookie_banner_enabled': cookieBannerEnabled,
      'cookie_preferences_enabled': cookiePreferencesEnabled,
      'cookie_banner_title': cookieBannerTitle,
      'cookie_banner_description': cookieBannerDescription,
      'cookie_policy_url': cookiePolicyUrl,
      'newsletter_popup_enabled': newsletterPopupEnabled,
      'newsletter_popup_delay_seconds': newsletterPopupDelaySeconds.clamp(
        0,
        60,
      ),
      'newsletter_popup_frequency_days': newsletterPopupFrequencyDays.clamp(
        1,
        365,
      ),
      'newsletter_popup_title': newsletterPopupTitle,
      'newsletter_popup_description': newsletterPopupDescription,
      'newsletter_popup_button_label': newsletterPopupButtonLabel,
      'social_auth_google_enabled': socialAuthGoogleEnabled,
      'social_auth_apple_enabled': socialAuthAppleEnabled,
      'social_auth_facebook_enabled': socialAuthFacebookEnabled,
      'social_auth_x_enabled': socialAuthXEnabled,
      'social_auth_redirect_scheme': socialAuthRedirectScheme.trim().isEmpty
          ? 'com.pateez.app'
          : socialAuthRedirectScheme.trim(),
      'social_auth_redirect_host': socialAuthRedirectHost.trim().isEmpty
          ? 'login-callback'
          : socialAuthRedirectHost.trim(),
      'robots_txt': robotsTxt,
      'header_custom_codes': headerCustomCodes,
      'footer_custom_codes': footerCustomCodes,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  String logoFor(GeneralSettingsLogoField field) {
    return switch (field) {
      GeneralSettingsLogoField.logoUrl => logoUrl,
      GeneralSettingsLogoField.footerLogoUrl => footerLogoUrl,
      GeneralSettingsLogoField.darkLogoUrl => darkLogoUrl,
      GeneralSettingsLogoField.emailLogoUrl => emailLogoUrl,
      GeneralSettingsLogoField.faviconUrl => faviconUrl,
      GeneralSettingsLogoField.ogImageUrl => ogImageUrl,
    };
  }

  GeneralSettingsData copyWith({
    String? languageCode,
    String? siteName,
    String? timezone,
    String? footerAbout,
    String? optionalUrlButtonName,
    String? copyrightText,
    String? logoUrl,
    String? footerLogoUrl,
    String? darkLogoUrl,
    String? emailLogoUrl,
    String? faviconUrl,
    String? homeTitle,
    String? metaDescription,
    String? metaKeywords,
    String? canonicalUrl,
    String? ogImageUrl,
    String? organizationLegalName,
    String? organizationPhone,
    String? organizationAddress,
    String? contactPhone,
    String? contactCity,
    String? contactAddress,
    String? contactLocationUrl,
    String? contactWhatsappUrl,
    String? contactTelegramUrl,
    String? contactEmailInfo,
    String? contactEmailSupport,
    String? contactEmailNews,
    String? contactEmailAds,
    String? twitterUsername,
    String? fbAppId,
    String? socialWhatsappUrl,
    String? socialTelegramUrl,
    String? socialInstagramUrl,
    String? socialFacebookUrl,
    String? socialXUrl,
    String? socialYoutubeUrl,
    String? socialTiktokUrl,
    String? socialLinkedinUrl,
    String? socialPinterestUrl,
    String? socialDiscordUrl,
    String? googleAnalyticsId,
    String? googleSearchConsoleCode,
    String? bingVerificationCode,
    String? yandexVerificationCode,
    String? indexNowKey,
    bool? cookieBannerEnabled,
    bool? cookiePreferencesEnabled,
    String? cookieBannerTitle,
    String? cookieBannerDescription,
    String? cookiePolicyUrl,
    bool? newsletterPopupEnabled,
    int? newsletterPopupDelaySeconds,
    int? newsletterPopupFrequencyDays,
    String? newsletterPopupTitle,
    String? newsletterPopupDescription,
    String? newsletterPopupButtonLabel,
    bool? socialAuthGoogleEnabled,
    bool? socialAuthAppleEnabled,
    bool? socialAuthFacebookEnabled,
    bool? socialAuthXEnabled,
    String? socialAuthRedirectScheme,
    String? socialAuthRedirectHost,
    String? robotsTxt,
    String? headerCustomCodes,
    String? footerCustomCodes,
  }) {
    return GeneralSettingsData(
      languageCode: languageCode ?? this.languageCode,
      siteName: siteName ?? this.siteName,
      timezone: timezone ?? this.timezone,
      footerAbout: footerAbout ?? this.footerAbout,
      optionalUrlButtonName:
          optionalUrlButtonName ?? this.optionalUrlButtonName,
      copyrightText: copyrightText ?? this.copyrightText,
      logoUrl: logoUrl ?? this.logoUrl,
      footerLogoUrl: footerLogoUrl ?? this.footerLogoUrl,
      darkLogoUrl: darkLogoUrl ?? this.darkLogoUrl,
      emailLogoUrl: emailLogoUrl ?? this.emailLogoUrl,
      faviconUrl: faviconUrl ?? this.faviconUrl,
      homeTitle: homeTitle ?? this.homeTitle,
      metaDescription: metaDescription ?? this.metaDescription,
      metaKeywords: metaKeywords ?? this.metaKeywords,
      canonicalUrl: canonicalUrl ?? this.canonicalUrl,
      ogImageUrl: ogImageUrl ?? this.ogImageUrl,
      organizationLegalName:
          organizationLegalName ?? this.organizationLegalName,
      organizationPhone: organizationPhone ?? this.organizationPhone,
      organizationAddress: organizationAddress ?? this.organizationAddress,
      contactPhone: contactPhone ?? this.contactPhone,
      contactCity: contactCity ?? this.contactCity,
      contactAddress: contactAddress ?? this.contactAddress,
      contactLocationUrl: contactLocationUrl ?? this.contactLocationUrl,
      contactWhatsappUrl: contactWhatsappUrl ?? this.contactWhatsappUrl,
      contactTelegramUrl: contactTelegramUrl ?? this.contactTelegramUrl,
      contactEmailInfo: contactEmailInfo ?? this.contactEmailInfo,
      contactEmailSupport: contactEmailSupport ?? this.contactEmailSupport,
      contactEmailNews: contactEmailNews ?? this.contactEmailNews,
      contactEmailAds: contactEmailAds ?? this.contactEmailAds,
      twitterUsername: twitterUsername ?? this.twitterUsername,
      fbAppId: fbAppId ?? this.fbAppId,
      socialWhatsappUrl: socialWhatsappUrl ?? this.socialWhatsappUrl,
      socialTelegramUrl: socialTelegramUrl ?? this.socialTelegramUrl,
      socialInstagramUrl: socialInstagramUrl ?? this.socialInstagramUrl,
      socialFacebookUrl: socialFacebookUrl ?? this.socialFacebookUrl,
      socialXUrl: socialXUrl ?? this.socialXUrl,
      socialYoutubeUrl: socialYoutubeUrl ?? this.socialYoutubeUrl,
      socialTiktokUrl: socialTiktokUrl ?? this.socialTiktokUrl,
      socialLinkedinUrl: socialLinkedinUrl ?? this.socialLinkedinUrl,
      socialPinterestUrl: socialPinterestUrl ?? this.socialPinterestUrl,
      socialDiscordUrl: socialDiscordUrl ?? this.socialDiscordUrl,
      googleAnalyticsId: googleAnalyticsId ?? this.googleAnalyticsId,
      googleSearchConsoleCode:
          googleSearchConsoleCode ?? this.googleSearchConsoleCode,
      bingVerificationCode: bingVerificationCode ?? this.bingVerificationCode,
      yandexVerificationCode:
          yandexVerificationCode ?? this.yandexVerificationCode,
      indexNowKey: indexNowKey ?? this.indexNowKey,
      cookieBannerEnabled: cookieBannerEnabled ?? this.cookieBannerEnabled,
      cookiePreferencesEnabled:
          cookiePreferencesEnabled ?? this.cookiePreferencesEnabled,
      cookieBannerTitle: cookieBannerTitle ?? this.cookieBannerTitle,
      cookieBannerDescription:
          cookieBannerDescription ?? this.cookieBannerDescription,
      cookiePolicyUrl: cookiePolicyUrl ?? this.cookiePolicyUrl,
      newsletterPopupEnabled:
          newsletterPopupEnabled ?? this.newsletterPopupEnabled,
      newsletterPopupDelaySeconds:
          newsletterPopupDelaySeconds ?? this.newsletterPopupDelaySeconds,
      newsletterPopupFrequencyDays:
          newsletterPopupFrequencyDays ?? this.newsletterPopupFrequencyDays,
      newsletterPopupTitle: newsletterPopupTitle ?? this.newsletterPopupTitle,
      newsletterPopupDescription:
          newsletterPopupDescription ?? this.newsletterPopupDescription,
      newsletterPopupButtonLabel:
          newsletterPopupButtonLabel ?? this.newsletterPopupButtonLabel,
      socialAuthGoogleEnabled:
          socialAuthGoogleEnabled ?? this.socialAuthGoogleEnabled,
      socialAuthAppleEnabled:
          socialAuthAppleEnabled ?? this.socialAuthAppleEnabled,
      socialAuthFacebookEnabled:
          socialAuthFacebookEnabled ?? this.socialAuthFacebookEnabled,
      socialAuthXEnabled: socialAuthXEnabled ?? this.socialAuthXEnabled,
      socialAuthRedirectScheme:
          socialAuthRedirectScheme ?? this.socialAuthRedirectScheme,
      socialAuthRedirectHost:
          socialAuthRedirectHost ?? this.socialAuthRedirectHost,
      robotsTxt: robotsTxt ?? this.robotsTxt,
      headerCustomCodes: headerCustomCodes ?? this.headerCustomCodes,
      footerCustomCodes: footerCustomCodes ?? this.footerCustomCodes,
    );
  }
}

abstract class AdminGeneralSettingsRepository {
  Future<GeneralSettingsData> fetchSettings(String languageCode);

  Future<GeneralSettingsData> saveSettings({
    required AdminSession session,
    required GeneralSettingsData settings,
  });

  Future<String> uploadLogo({
    required String languageCode,
    required GeneralSettingsLogoField field,
    required String fileName,
    required List<int> bytes,
  });

  Future<SocialPasswordStatus> fetchSocialPasswordStatus({
    required AdminSession session,
    required String languageCode,
  });

  Future<SocialPasswordStatus> saveSocialPasswords({
    required AdminSession session,
    required String languageCode,
    required Map<SocialPasswordField, String> values,
  });

  Future<String> revealSocialPassword({
    required AdminSession session,
    required String languageCode,
    required SocialPasswordField field,
    required String superAdminPassword,
  });

  Future<ContactEmailPasswordStatus> fetchContactEmailPasswordStatus({
    required AdminSession session,
    required String languageCode,
  });

  Future<ContactEmailPasswordStatus> saveContactEmailPasswords({
    required AdminSession session,
    required String languageCode,
    required Map<ContactEmailPasswordField, String> values,
  });

  Future<String> revealContactEmailPassword({
    required AdminSession session,
    required String languageCode,
    required ContactEmailPasswordField field,
    required String superAdminPassword,
  });

  String publicUrl(String value);
}

class SupabaseAdminGeneralSettingsRepository
    implements AdminGeneralSettingsRepository {
  const SupabaseAdminGeneralSettingsRepository({
    this.httpClient,
    this.apiBaseUrl,
  });

  static const _apiBaseUrl = String.fromEnvironment('PATEEZNEWS_API_BASE_URL');
  static const _requestTimeout = Duration(seconds: 18);

  final http.Client? httpClient;
  final String? apiBaseUrl;

  @override
  Future<GeneralSettingsData> fetchSettings(String languageCode) async {
    final normalizedCode = _cleanLanguageCode(languageCode);
    final result = await _postJson('/api/admin/query', {
      'table': 'site_settings',
      'method': 'select',
      'select': _settingsSelect,
      'filters': [
        {
          'type': 'comparison',
          'op': 'eq',
          'column': 'language_code',
          'value': normalizedCode,
        },
      ],
      'single': 'maybeSingle',
    });
    _throwIfApiError(result, fallbackMessage: 'Genel ayarlar alınamadı');
    final data = result['data'];
    if (data is! Map) return GeneralSettingsData.empty(normalizedCode);
    return GeneralSettingsData.fromJson(_asStringKeyMap(data), normalizedCode);
  }

  @override
  Future<GeneralSettingsData> saveSettings({
    required AdminSession session,
    required GeneralSettingsData settings,
  }) async {
    final normalizedSettings = settings.copyWith(
      languageCode: _cleanLanguageCode(settings.languageCode),
    );
    final result = await _postJson('/api/admin/query', {
      'table': 'site_settings',
      'method': 'upsert',
      'values': normalizedSettings.toJson(),
      'options': {'onConflict': 'language_code'},
      'single': 'maybeSingle',
    }, session: session);
    _throwIfApiError(result, fallbackMessage: 'Genel ayarlar kaydedilemedi');
    final data = result['data'];
    if (data is! Map) return normalizedSettings;
    return GeneralSettingsData.fromJson(
      _asStringKeyMap(data),
      normalizedSettings.languageCode,
    );
  }

  @override
  Future<String> uploadLogo({
    required String languageCode,
    required GeneralSettingsLogoField field,
    required String fileName,
    required List<int> bytes,
  }) async {
    final uploadUri = _uri('/api/storage/upload');
    final request = http.MultipartRequest('POST', uploadUri);
    if (!kIsWeb) {
      request.headers['Origin'] =
          '${uploadUri.scheme}://${uploadUri.authority}';
    }
    request.headers.addAll(await adminAuthHeaders());
    request.fields['type'] = 'logo';
    request.fields['lang'] = _cleanLanguageCode(languageCode);
    request.fields['customPath'] = _cleanLanguageCode(languageCode);
    request.fields['customFilename'] =
        '${field.uploadBaseName}-${DateTime.now().millisecondsSinceEpoch}';
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: fileName),
    );

    final uploadClient = httpClient ?? adminHttpClient;
    final streamedResponse = await uploadClient
        .send(request)
        .timeout(const Duration(seconds: 120));
    final response = await http.Response.fromStream(
      streamedResponse,
    ).timeout(_requestTimeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AdminGeneralSettingsException(
        response.body.isEmpty ? 'Logo yüklenemedi' : response.body,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const AdminGeneralSettingsException('Geçersiz yükleme yanıtı');
    }
    final src =
        decoded['publicSrc']?.toString() ?? decoded['src']?.toString() ?? '';
    if (src.isEmpty) {
      throw const AdminGeneralSettingsException('Logo URL alınamadı');
    }
    return src;
  }

  @override
  Future<SocialPasswordStatus> fetchSocialPasswordStatus({
    required AdminSession session,
    required String languageCode,
  }) async {
    final result = await _postJson('/api/admin/settings/social-passwords', {
      'action': 'status',
      'language_code': _cleanLanguageCode(languageCode),
    }, session: session);
    _throwIfApiError(result, fallbackMessage: 'Sosyal şifre durumu alınamadı');
    final data = result['data'];
    if (data is! Map) return SocialPasswordStatus.empty;
    return SocialPasswordStatus.fromJson(_asStringKeyMap(data));
  }

  @override
  Future<SocialPasswordStatus> saveSocialPasswords({
    required AdminSession session,
    required String languageCode,
    required Map<SocialPasswordField, String> values,
  }) async {
    final passwords = <String, Object?>{};
    for (final entry in values.entries) {
      final value = entry.value.trim();
      if (value.isNotEmpty) passwords[entry.key.key] = value;
    }
    if (passwords.isEmpty) {
      return fetchSocialPasswordStatus(
        session: session,
        languageCode: languageCode,
      );
    }

    final result = await _postJson('/api/admin/settings/social-passwords', {
      'action': 'save',
      'language_code': _cleanLanguageCode(languageCode),
      'passwords': passwords,
    }, session: session);
    _throwIfApiError(result, fallbackMessage: 'Sosyal şifreler kaydedilemedi');
    final data = result['data'];
    if (data is! Map) return SocialPasswordStatus.empty;
    return SocialPasswordStatus.fromJson(_asStringKeyMap(data));
  }

  @override
  Future<String> revealSocialPassword({
    required AdminSession session,
    required String languageCode,
    required SocialPasswordField field,
    required String superAdminPassword,
  }) async {
    final result = await _postJson('/api/admin/settings/social-passwords', {
      'action': 'reveal',
      'language_code': _cleanLanguageCode(languageCode),
      'field': field.key,
      'super_admin_password': superAdminPassword,
    }, session: session);
    _throwIfApiError(result, fallbackMessage: 'Sosyal şifre görüntülenemedi');
    final data = result['data'];
    if (data is! Map) return '';
    return data['value']?.toString() ?? '';
  }

  @override
  Future<ContactEmailPasswordStatus> fetchContactEmailPasswordStatus({
    required AdminSession session,
    required String languageCode,
  }) async {
    final result = await _postJson('/api/admin/settings/contact-passwords', {
      'action': 'status',
      'language_code': _cleanLanguageCode(languageCode),
    }, session: session);
    _throwIfApiError(
      result,
      fallbackMessage: 'İletişim mail şifre durumu alınamadı',
    );
    final data = result['data'];
    if (data is! Map) return ContactEmailPasswordStatus.empty;
    return ContactEmailPasswordStatus.fromJson(_asStringKeyMap(data));
  }

  @override
  Future<ContactEmailPasswordStatus> saveContactEmailPasswords({
    required AdminSession session,
    required String languageCode,
    required Map<ContactEmailPasswordField, String> values,
  }) async {
    final passwords = <String, Object?>{};
    for (final entry in values.entries) {
      final value = entry.value.trim();
      if (value.isNotEmpty) passwords[entry.key.key] = value;
    }
    if (passwords.isEmpty) {
      return fetchContactEmailPasswordStatus(
        session: session,
        languageCode: languageCode,
      );
    }

    final result = await _postJson('/api/admin/settings/contact-passwords', {
      'action': 'save',
      'language_code': _cleanLanguageCode(languageCode),
      'passwords': passwords,
    }, session: session);
    _throwIfApiError(
      result,
      fallbackMessage: 'İletişim mail şifreleri kaydedilemedi',
    );
    final data = result['data'];
    if (data is! Map) return ContactEmailPasswordStatus.empty;
    return ContactEmailPasswordStatus.fromJson(_asStringKeyMap(data));
  }

  @override
  Future<String> revealContactEmailPassword({
    required AdminSession session,
    required String languageCode,
    required ContactEmailPasswordField field,
    required String superAdminPassword,
  }) async {
    final result = await _postJson('/api/admin/settings/contact-passwords', {
      'action': 'reveal',
      'language_code': _cleanLanguageCode(languageCode),
      'field': field.key,
      'super_admin_password': superAdminPassword,
    }, session: session);
    _throwIfApiError(
      result,
      fallbackMessage: 'İletişim mail şifresi görüntülenemedi',
    );
    final data = result['data'];
    if (data is! Map) return '';
    return data['value']?.toString() ?? '';
  }

  @override
  String publicUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    final parsed = Uri.tryParse(trimmed);
    if (parsed != null && parsed.hasScheme) return trimmed;
    return _uri(trimmed).toString();
  }

  Future<Map<String, Object?>> _postJson(
    String path,
    Map<String, Object?> body, {
    AdminSession? session,
  }) async {
    final response =
        await (httpClient?.post(
                  _uri(path),
                  headers: await adminJsonHeaders(token: session?.accessToken),
                  body: jsonEncode(body),
                ) ??
                adminHttpClient.post(
                  _uri(path),
                  headers: await adminJsonHeaders(token: session?.accessToken),
                  body: jsonEncode(body),
                ))
            .timeout(_requestTimeout);

    final decoded = response.body.isEmpty
        ? <String, Object?>{}
        : jsonDecode(response.body);
    if (decoded is! Map) {
      throw const AdminGeneralSettingsException('Geçersiz sunucu yanıtı');
    }
    final result = _asStringKeyMap(decoded);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwIfApiError(result, fallbackMessage: 'Sunucu isteği başarısız');
    }
    return result;
  }

  Uri _uri(String path) {
    final baseUrl = (apiBaseUrl ?? _apiBaseUrl).trim();
    if (baseUrl.isNotEmpty && !isLocalAdminApiBaseUrl(baseUrl))
      return Uri.parse(baseUrl).resolve(path);
    return _defaultLocalApiBaseUrl().resolve(path);
  }

  Uri _defaultLocalApiBaseUrl() {
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => Uri.parse('https://pateez.com'),
      _ => Uri.parse('https://pateez.com'),
    };
  }

  void _throwIfApiError(
    Map<String, Object?> result, {
    required String fallbackMessage,
  }) {
    final error = result['error'];
    if (error == null) return;
    if (error is Map) {
      final message = error['message']?.toString();
      if (message != null && message.isNotEmpty) {
        throw AdminGeneralSettingsException(message);
      }
    }
    throw AdminGeneralSettingsException(fallbackMessage);
  }
}

class AdminGeneralSettingsException implements Exception {
  const AdminGeneralSettingsException(this.message);

  final String message;

  @override
  String toString() => message;
}

const _settingsSelect =
    'language_code,site_name,timezone,footer_about,optional_url_button_name,'
    'copyright_text,logo_url,footer_logo_url,dark_logo_url,email_logo_url,'
    'favicon_url,home_title,meta_description,meta_keywords,canonical_url,'
    'og_image_url,organization_legal_name,organization_phone,'
    'organization_address,contact_phone,contact_city,contact_address,'
    'contact_location_url,contact_whatsapp_url,contact_telegram_url,'
    'contact_email_info,contact_email_support,contact_email_news,'
    'contact_email_ads,twitter_username,fb_app_id,google_analytics_id,'
    'social_whatsapp_url,social_telegram_url,social_instagram_url,'
    'social_facebook_url,social_x_url,social_youtube_url,'
    'social_tiktok_url,social_linkedin_url,social_pinterest_url,'
    'social_discord_url,'
    'google_search_console_code,bing_verification_code,'
    'yandex_verification_code,indexnow_key,'
    'cookie_banner_enabled,cookie_preferences_enabled,cookie_banner_title,'
    'cookie_banner_description,cookie_policy_url,newsletter_popup_enabled,'
    'newsletter_popup_delay_seconds,newsletter_popup_frequency_days,'
    'newsletter_popup_title,newsletter_popup_description,'
    'newsletter_popup_button_label,'
    'social_auth_google_enabled,social_auth_apple_enabled,'
    'social_auth_facebook_enabled,social_auth_x_enabled,'
    'social_auth_redirect_scheme,social_auth_redirect_host,robots_txt,'
    'header_custom_codes,footer_custom_codes';

String _string(Object? value, {String fallback = ''}) {
  final text = value?.toString();
  if (text == null || text.isEmpty) return fallback;
  return text;
}

bool _bool(Object? value, {required bool fallback}) {
  if (value is bool) return value;
  final text = value?.toString().trim().toLowerCase();
  if (text == 'true' || text == '1') return true;
  if (text == 'false' || text == '0') return false;
  return fallback;
}

int _int(Object? value, {required int fallback}) {
  if (value is int) return value;
  if (value is num) return value.round();
  final parsed = int.tryParse(value?.toString().trim() ?? '');
  return parsed ?? fallback;
}

String _cleanLanguageCode(String value) {
  final code = value.trim().toLowerCase().replaceAll('_', '-');
  return code.isEmpty ? 'tr' : code;
}

Map<String, Object?> _asStringKeyMap(Map<dynamic, dynamic> value) {
  return value.map((key, nestedValue) => MapEntry(key.toString(), nestedValue));
}
