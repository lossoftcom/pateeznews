import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pateeznews_admin/core/network/admin_api_headers.dart';

import '../../auth/data/admin_auth_models.dart';

class ContentGeneralSettingsData {
  const ContentGeneralSettingsData({
    required this.languageCode,
    required this.showFeaturedSection,
    required this.commentSystem,
    required this.commentApprovalSystem,
    required this.emojiReactions,
    required this.homePageSize,
  });

  factory ContentGeneralSettingsData.defaults(String languageCode) {
    return ContentGeneralSettingsData(
      languageCode: _cleanLanguageCode(languageCode),
      showFeaturedSection: true,
      commentSystem: true,
      commentApprovalSystem: true,
      emojiReactions: true,
      homePageSize: 16,
    );
  }

  factory ContentGeneralSettingsData.fromJson(
    Map<String, Object?> json,
    String languageCode,
  ) {
    final fallback = ContentGeneralSettingsData.defaults(languageCode);
    return ContentGeneralSettingsData(
      languageCode: _string(
        json['language_code'],
        fallback: fallback.languageCode,
      ),
      showFeaturedSection: _bool(
        json['content_show_featured_section'],
        fallback: fallback.showFeaturedSection,
      ),
      commentSystem: _bool(
        json['content_comment_system_enabled'],
        fallback: fallback.commentSystem,
      ),
      commentApprovalSystem: _bool(
        json['content_comment_approval_enabled'],
        fallback: fallback.commentApprovalSystem,
      ),
      emojiReactions: _bool(
        json['content_emoji_reactions_enabled'],
        fallback: fallback.emojiReactions,
      ),
      homePageSize: _pageSize(
        json['content_home_page_size'],
        fallback: fallback.homePageSize,
      ),
    );
  }

  final String languageCode;
  final bool showFeaturedSection;
  final bool commentSystem;
  final bool commentApprovalSystem;
  final bool emojiReactions;
  final int homePageSize;

  Map<String, Object?> toJson() {
    return {
      'language_code': _cleanLanguageCode(languageCode),
      'content_show_featured_section': showFeaturedSection,
      'content_comment_system_enabled': commentSystem,
      'content_comment_approval_enabled': commentApprovalSystem,
      'content_emoji_reactions_enabled': emojiReactions,
      'content_home_page_size': _clampPageSize(homePageSize),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  ContentGeneralSettingsData copyWith({
    String? languageCode,
    bool? showFeaturedSection,
    bool? commentSystem,
    bool? commentApprovalSystem,
    bool? emojiReactions,
    int? homePageSize,
  }) {
    return ContentGeneralSettingsData(
      languageCode: languageCode ?? this.languageCode,
      showFeaturedSection: showFeaturedSection ?? this.showFeaturedSection,
      commentSystem: commentSystem ?? this.commentSystem,
      commentApprovalSystem:
          commentApprovalSystem ?? this.commentApprovalSystem,
      emojiReactions: emojiReactions ?? this.emojiReactions,
      homePageSize: homePageSize ?? this.homePageSize,
    );
  }
}

class ContentPostFormatSettingsData {
  const ContentPostFormatSettingsData({
    required this.languageCode,
    required this.enabledFormats,
  });

  factory ContentPostFormatSettingsData.defaults(String languageCode) {
    return ContentPostFormatSettingsData(
      languageCode: _cleanLanguageCode(languageCode),
      enabledFormats: const {...contentPostFormatKeys},
    );
  }

  factory ContentPostFormatSettingsData.fromJson(
    Map<String, Object?> json,
    String languageCode,
  ) {
    final fallback = ContentPostFormatSettingsData.defaults(languageCode);
    return ContentPostFormatSettingsData(
      languageCode: _string(
        json['language_code'],
        fallback: fallback.languageCode,
      ),
      enabledFormats: _formatSet(
        json['content_enabled_post_formats'],
        fallback: fallback.enabledFormats,
      ),
    );
  }

  final String languageCode;
  final Set<String> enabledFormats;

  Map<String, Object?> toJson() {
    return {
      'language_code': _cleanLanguageCode(languageCode),
      'content_enabled_post_formats': _normalizedFormatList(enabledFormats),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  ContentPostFormatSettingsData copyWith({
    String? languageCode,
    Set<String>? enabledFormats,
  }) {
    return ContentPostFormatSettingsData(
      languageCode: languageCode ?? this.languageCode,
      enabledFormats: enabledFormats ?? this.enabledFormats,
    );
  }
}

class ContentUploadSettingsData {
  const ContentUploadSettingsData({
    required this.languageCode,
    required this.imageFileFormat,
    required this.allowedExtensions,
    required this.maxImageSizeMb,
    required this.maxVideoSizeMb,
    required this.maxAudioSizeMb,
    required this.maxFileSizeMb,
  });

  factory ContentUploadSettingsData.defaults(String languageCode) {
    return ContentUploadSettingsData(
      languageCode: _cleanLanguageCode(languageCode),
      imageFileFormat: 'WEBP',
      allowedExtensions: const {...contentUploadDefaultExtensions},
      maxImageSizeMb: 20,
      maxVideoSizeMb: 50,
      maxAudioSizeMb: 20,
      maxFileSizeMb: 50,
    );
  }

  factory ContentUploadSettingsData.fromJson(
    Map<String, Object?> json,
    String languageCode,
  ) {
    final fallback = ContentUploadSettingsData.defaults(languageCode);
    return ContentUploadSettingsData(
      languageCode: _string(
        json['language_code'],
        fallback: fallback.languageCode,
      ),
      imageFileFormat: _imageFormat(
        json['content_upload_image_format'],
        fallback: fallback.imageFileFormat,
      ),
      allowedExtensions: _extensionSet(
        json['content_upload_allowed_extensions'],
        fallback: fallback.allowedExtensions,
      ),
      maxImageSizeMb: _megabyteLimit(
        json['content_upload_max_image_mb'],
        fallback: fallback.maxImageSizeMb,
      ),
      maxVideoSizeMb: _megabyteLimit(
        json['content_upload_max_video_mb'],
        fallback: fallback.maxVideoSizeMb,
      ),
      maxAudioSizeMb: _megabyteLimit(
        json['content_upload_max_audio_mb'],
        fallback: fallback.maxAudioSizeMb,
      ),
      maxFileSizeMb: _megabyteLimit(
        json['content_upload_max_file_mb'],
        fallback: fallback.maxFileSizeMb,
      ),
    );
  }

  final String languageCode;
  final String imageFileFormat;
  final Set<String> allowedExtensions;
  final int maxImageSizeMb;
  final int maxVideoSizeMb;
  final int maxAudioSizeMb;
  final int maxFileSizeMb;

  Map<String, Object?> toJson() {
    return {
      'language_code': _cleanLanguageCode(languageCode),
      'content_upload_image_format': _imageFormat(imageFileFormat),
      'content_upload_allowed_extensions': _normalizedExtensionList(
        allowedExtensions,
      ),
      'content_upload_max_image_mb': _clampMegabyteLimit(maxImageSizeMb),
      'content_upload_max_video_mb': _clampMegabyteLimit(maxVideoSizeMb),
      'content_upload_max_audio_mb': _clampMegabyteLimit(maxAudioSizeMb),
      'content_upload_max_file_mb': _clampMegabyteLimit(maxFileSizeMb),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  ContentUploadSettingsData copyWith({
    String? languageCode,
    String? imageFileFormat,
    Set<String>? allowedExtensions,
    int? maxImageSizeMb,
    int? maxVideoSizeMb,
    int? maxAudioSizeMb,
    int? maxFileSizeMb,
  }) {
    return ContentUploadSettingsData(
      languageCode: languageCode ?? this.languageCode,
      imageFileFormat: imageFileFormat ?? this.imageFileFormat,
      allowedExtensions: allowedExtensions ?? this.allowedExtensions,
      maxImageSizeMb: maxImageSizeMb ?? this.maxImageSizeMb,
      maxVideoSizeMb: maxVideoSizeMb ?? this.maxVideoSizeMb,
      maxAudioSizeMb: maxAudioSizeMb ?? this.maxAudioSizeMb,
      maxFileSizeMb: maxFileSizeMb ?? this.maxFileSizeMb,
    );
  }
}

class ContentFeaturedSettingsData {
  const ContentFeaturedSettingsData({
    required this.languageCode,
    required this.contentSource,
    required this.sortingLogic,
    required this.displayLimit,
    required this.showNewsInfo,
  });

  factory ContentFeaturedSettingsData.defaults(String languageCode) {
    return ContentFeaturedSettingsData(
      languageCode: _cleanLanguageCode(languageCode),
      contentSource: 'manual',
      sortingLogic: 'slider_order',
      displayLimit: 15,
      showNewsInfo: false,
    );
  }

  factory ContentFeaturedSettingsData.fromJson(
    Map<String, Object?> json,
    String languageCode,
  ) {
    final fallback = ContentFeaturedSettingsData.defaults(languageCode);
    return ContentFeaturedSettingsData(
      languageCode: _string(
        json['language_code'],
        fallback: fallback.languageCode,
      ),
      contentSource: _featuredSource(
        json['content_featured_source'],
        fallback: fallback.contentSource,
      ),
      sortingLogic: _featuredSorting(
        json['content_featured_sorting'],
        fallback: fallback.sortingLogic,
      ),
      displayLimit: _featuredLimit(
        json['content_featured_limit'],
        fallback: fallback.displayLimit,
      ),
      showNewsInfo: _bool(
        json['content_featured_show_news_info'],
        fallback: fallback.showNewsInfo,
      ),
    );
  }

  final String languageCode;
  final String contentSource;
  final String sortingLogic;
  final int displayLimit;
  final bool showNewsInfo;

  Map<String, Object?> toJson() {
    return {
      'language_code': _cleanLanguageCode(languageCode),
      'content_featured_source': _featuredSource(contentSource),
      'content_featured_sorting': _featuredSorting(sortingLogic),
      'content_featured_limit': _clampFeaturedLimit(displayLimit),
      'content_featured_show_news_info': showNewsInfo,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  ContentFeaturedSettingsData copyWith({
    String? languageCode,
    String? contentSource,
    String? sortingLogic,
    int? displayLimit,
    bool? showNewsInfo,
  }) {
    return ContentFeaturedSettingsData(
      languageCode: languageCode ?? this.languageCode,
      contentSource: contentSource ?? this.contentSource,
      sortingLogic: sortingLogic ?? this.sortingLogic,
      displayLimit: displayLimit ?? this.displayLimit,
      showNewsInfo: showNewsInfo ?? this.showNewsInfo,
    );
  }
}

class ContentPostSettingsData {
  const ContentPostSettingsData({
    required this.languageCode,
    required this.postUrlStructure,
    required this.bulkPostUpload,
    required this.deleteMediaWithPost,
    required this.audioDownloadButton,
    required this.showPostAuthor,
    required this.showPostDate,
    required this.showPostViewCount,
    required this.requireNewPostApproval,
    required this.requireEditedPostApproval,
    required this.redirectRssPosts,
    required this.popularPostLimit,
    required this.relatedPostLimit,
  });

  factory ContentPostSettingsData.defaults(String languageCode) {
    return ContentPostSettingsData(
      languageCode: _cleanLanguageCode(languageCode),
      postUrlStructure: 'slug',
      bulkPostUpload: true,
      deleteMediaWithPost: false,
      audioDownloadButton: true,
      showPostAuthor: true,
      showPostDate: true,
      showPostViewCount: true,
      requireNewPostApproval: true,
      requireEditedPostApproval: true,
      redirectRssPosts: false,
      popularPostLimit: 5,
      relatedPostLimit: 6,
    );
  }

  factory ContentPostSettingsData.fromJson(
    Map<String, Object?> json,
    String languageCode,
  ) {
    final fallback = ContentPostSettingsData.defaults(languageCode);
    return ContentPostSettingsData(
      languageCode: _string(
        json['language_code'],
        fallback: fallback.languageCode,
      ),
      postUrlStructure: _postUrlStructure(
        json['content_post_url_structure'],
        fallback: fallback.postUrlStructure,
      ),
      bulkPostUpload: _bool(
        json['content_bulk_post_upload_enabled'],
        fallback: fallback.bulkPostUpload,
      ),
      deleteMediaWithPost: _bool(
        json['content_delete_media_with_post_enabled'],
        fallback: fallback.deleteMediaWithPost,
      ),
      audioDownloadButton: _bool(
        json['content_audio_download_enabled'],
        fallback: fallback.audioDownloadButton,
      ),
      showPostAuthor: _bool(
        json['content_show_post_author'],
        fallback: fallback.showPostAuthor,
      ),
      showPostDate: _bool(
        json['content_show_post_date'],
        fallback: fallback.showPostDate,
      ),
      showPostViewCount: _bool(
        json['content_show_post_view_count'],
        fallback: fallback.showPostViewCount,
      ),
      requireNewPostApproval: _bool(
        json['content_require_new_post_approval'],
        fallback: fallback.requireNewPostApproval,
      ),
      requireEditedPostApproval: _bool(
        json['content_require_edited_post_approval'],
        fallback: fallback.requireEditedPostApproval,
      ),
      redirectRssPosts: _bool(
        json['content_redirect_rss_posts'],
        fallback: fallback.redirectRssPosts,
      ),
      popularPostLimit: _contentLimit(
        json['content_popular_post_limit'],
        fallback: fallback.popularPostLimit,
      ),
      relatedPostLimit: _contentLimit(
        json['content_related_post_limit'],
        fallback: fallback.relatedPostLimit,
      ),
    );
  }

  final String languageCode;
  final String postUrlStructure;
  final bool bulkPostUpload;
  final bool deleteMediaWithPost;
  final bool audioDownloadButton;
  final bool showPostAuthor;
  final bool showPostDate;
  final bool showPostViewCount;
  final bool requireNewPostApproval;
  final bool requireEditedPostApproval;
  final bool redirectRssPosts;
  final int popularPostLimit;
  final int relatedPostLimit;

  Map<String, Object?> toJson() {
    return {
      'language_code': _cleanLanguageCode(languageCode),
      'content_post_url_structure': _postUrlStructure(postUrlStructure),
      'content_bulk_post_upload_enabled': bulkPostUpload,
      'content_delete_media_with_post_enabled': deleteMediaWithPost,
      'content_audio_download_enabled': audioDownloadButton,
      'content_show_post_author': showPostAuthor,
      'content_show_post_date': showPostDate,
      'content_show_post_view_count': showPostViewCount,
      'content_require_new_post_approval': requireNewPostApproval,
      'content_require_edited_post_approval': requireEditedPostApproval,
      'content_redirect_rss_posts': redirectRssPosts,
      'content_popular_post_limit': _clampContentLimit(popularPostLimit),
      'content_related_post_limit': _clampContentLimit(relatedPostLimit),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  ContentPostSettingsData copyWith({
    String? languageCode,
    String? postUrlStructure,
    bool? bulkPostUpload,
    bool? deleteMediaWithPost,
    bool? audioDownloadButton,
    bool? showPostAuthor,
    bool? showPostDate,
    bool? showPostViewCount,
    bool? requireNewPostApproval,
    bool? requireEditedPostApproval,
    bool? redirectRssPosts,
    int? popularPostLimit,
    int? relatedPostLimit,
  }) {
    return ContentPostSettingsData(
      languageCode: languageCode ?? this.languageCode,
      postUrlStructure: postUrlStructure ?? this.postUrlStructure,
      bulkPostUpload: bulkPostUpload ?? this.bulkPostUpload,
      deleteMediaWithPost: deleteMediaWithPost ?? this.deleteMediaWithPost,
      audioDownloadButton: audioDownloadButton ?? this.audioDownloadButton,
      showPostAuthor: showPostAuthor ?? this.showPostAuthor,
      showPostDate: showPostDate ?? this.showPostDate,
      showPostViewCount: showPostViewCount ?? this.showPostViewCount,
      requireNewPostApproval:
          requireNewPostApproval ?? this.requireNewPostApproval,
      requireEditedPostApproval:
          requireEditedPostApproval ?? this.requireEditedPostApproval,
      redirectRssPosts: redirectRssPosts ?? this.redirectRssPosts,
      popularPostLimit: popularPostLimit ?? this.popularPostLimit,
      relatedPostLimit: relatedPostLimit ?? this.relatedPostLimit,
    );
  }
}

class ContentTrashCleanupSettingsData {
  const ContentTrashCleanupSettingsData({
    required this.languageCode,
    required this.enabled,
    required this.days,
    required this.scope,
  });

  factory ContentTrashCleanupSettingsData.defaults(String languageCode) {
    return ContentTrashCleanupSettingsData(
      languageCode: _cleanLanguageCode(languageCode),
      enabled: false,
      days: 30,
      scope: 'all',
    );
  }

  factory ContentTrashCleanupSettingsData.fromJson(
    Map<String, Object?> json,
    String languageCode,
  ) {
    final fallback = ContentTrashCleanupSettingsData.defaults(languageCode);
    return ContentTrashCleanupSettingsData(
      languageCode: _string(
        json['language_code'],
        fallback: fallback.languageCode,
      ),
      enabled: _bool(
        json['content_trash_auto_delete_enabled'],
        fallback: fallback.enabled,
      ),
      days: _trashDays(
        json['content_trash_auto_delete_days'],
        fallback: fallback.days,
      ),
      scope: _trashScope(
        json['content_trash_auto_delete_scope'],
        fallback: fallback.scope,
      ),
    );
  }

  final String languageCode;
  final bool enabled;
  final int days;
  final String scope;

  Map<String, Object?> toJson() {
    return {
      'language_code': _cleanLanguageCode(languageCode),
      'content_trash_auto_delete_enabled': enabled,
      'content_trash_auto_delete_days': _clampTrashDays(days),
      'content_trash_auto_delete_scope': _trashScope(scope),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  ContentTrashCleanupSettingsData copyWith({
    String? languageCode,
    bool? enabled,
    int? days,
    String? scope,
  }) {
    return ContentTrashCleanupSettingsData(
      languageCode: languageCode ?? this.languageCode,
      enabled: enabled ?? this.enabled,
      days: days ?? this.days,
      scope: scope ?? this.scope,
    );
  }
}

class ContentSettingsSnapshot {
  const ContentSettingsSnapshot({
    required this.languageCode,
    required this.general,
    required this.posts,
    required this.postFormats,
    required this.upload,
    required this.featured,
    required this.trashCleanup,
  });

  factory ContentSettingsSnapshot.defaults(String languageCode) {
    final normalizedCode = _cleanLanguageCode(languageCode);
    return ContentSettingsSnapshot(
      languageCode: normalizedCode,
      general: ContentGeneralSettingsData.defaults(normalizedCode),
      posts: ContentPostSettingsData.defaults(normalizedCode),
      postFormats: ContentPostFormatSettingsData.defaults(normalizedCode),
      upload: ContentUploadSettingsData.defaults(normalizedCode),
      featured: ContentFeaturedSettingsData.defaults(normalizedCode),
      trashCleanup: ContentTrashCleanupSettingsData.defaults(normalizedCode),
    );
  }

  final String languageCode;
  final ContentGeneralSettingsData general;
  final ContentPostSettingsData posts;
  final ContentPostFormatSettingsData postFormats;
  final ContentUploadSettingsData upload;
  final ContentFeaturedSettingsData featured;
  final ContentTrashCleanupSettingsData trashCleanup;

  ContentSettingsSnapshot copyWith({
    ContentGeneralSettingsData? general,
    ContentPostSettingsData? posts,
    ContentPostFormatSettingsData? postFormats,
    ContentUploadSettingsData? upload,
    ContentFeaturedSettingsData? featured,
    ContentTrashCleanupSettingsData? trashCleanup,
  }) {
    return ContentSettingsSnapshot(
      languageCode: languageCode,
      general: general ?? this.general,
      posts: posts ?? this.posts,
      postFormats: postFormats ?? this.postFormats,
      upload: upload ?? this.upload,
      featured: featured ?? this.featured,
      trashCleanup: trashCleanup ?? this.trashCleanup,
    );
  }
}

abstract class AdminContentSettingsRepository {
  Future<ContentSettingsSnapshot> fetchAllSettings(String languageCode);

  Future<ContentGeneralSettingsData> fetchGeneralSettings(String languageCode);

  Future<ContentGeneralSettingsData> saveGeneralSettings({
    required AdminSession session,
    required ContentGeneralSettingsData settings,
  });

  Future<ContentPostSettingsData> fetchPostSettings(String languageCode);

  Future<ContentPostSettingsData> savePostSettings({
    required AdminSession session,
    required ContentPostSettingsData settings,
  });

  Future<ContentPostFormatSettingsData> fetchPostFormatSettings(
    String languageCode,
  );

  Future<ContentPostFormatSettingsData> savePostFormatSettings({
    required AdminSession session,
    required ContentPostFormatSettingsData settings,
  });

  Future<ContentUploadSettingsData> fetchUploadSettings(String languageCode);

  Future<ContentUploadSettingsData> saveUploadSettings({
    required AdminSession session,
    required ContentUploadSettingsData settings,
  });

  Future<ContentFeaturedSettingsData> fetchFeaturedSettings(
    String languageCode,
  );

  Future<ContentFeaturedSettingsData> saveFeaturedSettings({
    required AdminSession session,
    required ContentFeaturedSettingsData settings,
  });

  Future<ContentTrashCleanupSettingsData> fetchTrashCleanupSettings(
    String languageCode,
  );

  Future<ContentTrashCleanupSettingsData> saveTrashCleanupSettings({
    required AdminSession session,
    required ContentTrashCleanupSettingsData settings,
  });
}

class SupabaseAdminContentSettingsRepository
    implements AdminContentSettingsRepository {
  const SupabaseAdminContentSettingsRepository({
    this.httpClient,
    this.apiBaseUrl,
  });

  static const _apiBaseUrl = String.fromEnvironment('PATEEZNEWS_API_BASE_URL');
  static const _requestTimeout = Duration(seconds: 18);

  final http.Client? httpClient;
  final String? apiBaseUrl;

  @override
  Future<ContentSettingsSnapshot> fetchAllSettings(String languageCode) async {
    final normalizedCode = _cleanLanguageCode(languageCode);
    final results = await Future.wait<Object>([
      fetchGeneralSettings(normalizedCode),
      fetchPostSettings(normalizedCode),
      fetchPostFormatSettings(normalizedCode),
      fetchUploadSettings(normalizedCode),
      fetchFeaturedSettings(normalizedCode),
      fetchTrashCleanupSettings(normalizedCode),
    ]);
    return ContentSettingsSnapshot(
      languageCode: normalizedCode,
      general: results[0] as ContentGeneralSettingsData,
      posts: results[1] as ContentPostSettingsData,
      postFormats: results[2] as ContentPostFormatSettingsData,
      upload: results[3] as ContentUploadSettingsData,
      featured: results[4] as ContentFeaturedSettingsData,
      trashCleanup: results[5] as ContentTrashCleanupSettingsData,
    );
  }

  @override
  Future<ContentGeneralSettingsData> fetchGeneralSettings(
    String languageCode,
  ) async {
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
    _throwIfApiError(result, fallbackMessage: 'Icerik ayarlari alinamadi');
    final data = result['data'];
    if (data is! Map) {
      return ContentGeneralSettingsData.defaults(normalizedCode);
    }
    return ContentGeneralSettingsData.fromJson(
      _asStringKeyMap(data),
      normalizedCode,
    );
  }

  @override
  Future<ContentGeneralSettingsData> saveGeneralSettings({
    required AdminSession session,
    required ContentGeneralSettingsData settings,
  }) async {
    final normalizedSettings = settings.copyWith(
      languageCode: _cleanLanguageCode(settings.languageCode),
      homePageSize: _clampPageSize(settings.homePageSize),
    );
    final result = await _postJson('/api/admin/query', {
      'table': 'site_settings',
      'method': 'upsert',
      'select': _settingsSelect,
      'values': normalizedSettings.toJson(),
      'options': {'onConflict': 'language_code'},
      'single': 'maybeSingle',
    });
    _throwIfApiError(result, fallbackMessage: 'Icerik ayarlari kaydedilemedi');
    final data = result['data'];
    if (data is! Map) return normalizedSettings;
    return ContentGeneralSettingsData.fromJson(
      _asStringKeyMap(data),
      normalizedSettings.languageCode,
    );
  }

  @override
  Future<ContentPostSettingsData> fetchPostSettings(String languageCode) async {
    final normalizedCode = _cleanLanguageCode(languageCode);
    final result = await _postJson('/api/admin/query', {
      'table': 'site_settings',
      'method': 'select',
      'select': _postSettingsSelect,
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
    _throwIfApiError(result, fallbackMessage: 'Gonderi ayarlari alinamadi');
    final data = result['data'];
    if (data is! Map) return ContentPostSettingsData.defaults(normalizedCode);
    return ContentPostSettingsData.fromJson(
      _asStringKeyMap(data),
      normalizedCode,
    );
  }

  @override
  Future<ContentPostSettingsData> savePostSettings({
    required AdminSession session,
    required ContentPostSettingsData settings,
  }) async {
    final normalizedSettings = settings.copyWith(
      languageCode: _cleanLanguageCode(settings.languageCode),
      postUrlStructure: _postUrlStructure(settings.postUrlStructure),
      popularPostLimit: _clampContentLimit(settings.popularPostLimit),
      relatedPostLimit: _clampContentLimit(settings.relatedPostLimit),
    );
    final result = await _postJson('/api/admin/query', {
      'table': 'site_settings',
      'method': 'upsert',
      'select': _postSettingsSelect,
      'values': normalizedSettings.toJson(),
      'options': {'onConflict': 'language_code'},
      'single': 'maybeSingle',
    });
    _throwIfApiError(result, fallbackMessage: 'Gonderi ayarlari kaydedilemedi');
    final data = result['data'];
    if (data is! Map) return normalizedSettings;
    return ContentPostSettingsData.fromJson(
      _asStringKeyMap(data),
      normalizedSettings.languageCode,
    );
  }

  @override
  Future<ContentPostFormatSettingsData> fetchPostFormatSettings(
    String languageCode,
  ) async {
    final normalizedCode = _cleanLanguageCode(languageCode);
    final result = await _postJson('/api/admin/query', {
      'table': 'site_settings',
      'method': 'select',
      'select': _postFormatSettingsSelect,
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
    _throwIfApiError(
      result,
      fallbackMessage: 'Gonderi format ayarlari alinamadi',
    );
    final data = result['data'];
    if (data is! Map) {
      return ContentPostFormatSettingsData.defaults(normalizedCode);
    }
    return ContentPostFormatSettingsData.fromJson(
      _asStringKeyMap(data),
      normalizedCode,
    );
  }

  @override
  Future<ContentPostFormatSettingsData> savePostFormatSettings({
    required AdminSession session,
    required ContentPostFormatSettingsData settings,
  }) async {
    final normalizedSettings = settings.copyWith(
      languageCode: _cleanLanguageCode(settings.languageCode),
      enabledFormats: _formatSet(settings.enabledFormats),
    );
    final result = await _postJson('/api/admin/query', {
      'table': 'site_settings',
      'method': 'upsert',
      'select': _postFormatSettingsSelect,
      'values': normalizedSettings.toJson(),
      'options': {'onConflict': 'language_code'},
      'single': 'maybeSingle',
    });
    _throwIfApiError(
      result,
      fallbackMessage: 'Gonderi format ayarlari kaydedilemedi',
    );
    final data = result['data'];
    if (data is! Map) return normalizedSettings;
    return ContentPostFormatSettingsData.fromJson(
      _asStringKeyMap(data),
      normalizedSettings.languageCode,
    );
  }

  @override
  Future<ContentUploadSettingsData> fetchUploadSettings(
    String languageCode,
  ) async {
    final normalizedCode = _cleanLanguageCode(languageCode);
    final result = await _postJson('/api/admin/query', {
      'table': 'site_settings',
      'method': 'select',
      'select': _uploadSettingsSelect,
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
    _throwIfApiError(
      result,
      fallbackMessage: 'Dosya yukleme ayarlari alinamadi',
    );
    final data = result['data'];
    if (data is! Map) return ContentUploadSettingsData.defaults(normalizedCode);
    return ContentUploadSettingsData.fromJson(
      _asStringKeyMap(data),
      normalizedCode,
    );
  }

  @override
  Future<ContentUploadSettingsData> saveUploadSettings({
    required AdminSession session,
    required ContentUploadSettingsData settings,
  }) async {
    final normalizedSettings = settings.copyWith(
      languageCode: _cleanLanguageCode(settings.languageCode),
      imageFileFormat: _imageFormat(settings.imageFileFormat),
      allowedExtensions: _extensionSet(settings.allowedExtensions),
      maxImageSizeMb: _clampMegabyteLimit(settings.maxImageSizeMb),
      maxVideoSizeMb: _clampMegabyteLimit(settings.maxVideoSizeMb),
      maxAudioSizeMb: _clampMegabyteLimit(settings.maxAudioSizeMb),
      maxFileSizeMb: _clampMegabyteLimit(settings.maxFileSizeMb),
    );
    final result = await _postJson('/api/admin/query', {
      'table': 'site_settings',
      'method': 'upsert',
      'select': _uploadSettingsSelect,
      'values': normalizedSettings.toJson(),
      'options': {'onConflict': 'language_code'},
      'single': 'maybeSingle',
    });
    _throwIfApiError(
      result,
      fallbackMessage: 'Dosya yukleme ayarlari kaydedilemedi',
    );
    final data = result['data'];
    if (data is! Map) return normalizedSettings;
    return ContentUploadSettingsData.fromJson(
      _asStringKeyMap(data),
      normalizedSettings.languageCode,
    );
  }

  @override
  Future<ContentFeaturedSettingsData> fetchFeaturedSettings(
    String languageCode,
  ) async {
    final normalizedCode = _cleanLanguageCode(languageCode);
    final result = await _postJson('/api/admin/query', {
      'table': 'site_settings',
      'method': 'select',
      'select': _featuredSettingsSelect,
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
    _throwIfApiError(result, fallbackMessage: 'Manset ayarlari alinamadi');
    final data = result['data'];
    if (data is! Map) {
      return ContentFeaturedSettingsData.defaults(normalizedCode);
    }
    return ContentFeaturedSettingsData.fromJson(
      _asStringKeyMap(data),
      normalizedCode,
    );
  }

  @override
  Future<ContentFeaturedSettingsData> saveFeaturedSettings({
    required AdminSession session,
    required ContentFeaturedSettingsData settings,
  }) async {
    final normalizedSettings = settings.copyWith(
      languageCode: _cleanLanguageCode(settings.languageCode),
      contentSource: _featuredSource(settings.contentSource),
      sortingLogic: _featuredSorting(settings.sortingLogic),
      displayLimit: _clampFeaturedLimit(settings.displayLimit),
      showNewsInfo: settings.showNewsInfo,
    );
    final result = await _postJson('/api/admin/query', {
      'table': 'site_settings',
      'method': 'upsert',
      'select': _featuredSettingsSelect,
      'values': normalizedSettings.toJson(),
      'options': {'onConflict': 'language_code'},
      'single': 'maybeSingle',
    });
    _throwIfApiError(result, fallbackMessage: 'Manset ayarlari kaydedilemedi');
    final data = result['data'];
    if (data is! Map) return normalizedSettings;
    return ContentFeaturedSettingsData.fromJson(
      _asStringKeyMap(data),
      normalizedSettings.languageCode,
    );
  }

  @override
  Future<ContentTrashCleanupSettingsData> fetchTrashCleanupSettings(
    String languageCode,
  ) async {
    final normalizedCode = _cleanLanguageCode(languageCode);
    final result = await _postJson('/api/admin/query', {
      'table': 'site_settings',
      'method': 'select',
      'select': _trashCleanupSettingsSelect,
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
    _throwIfApiError(
      result,
      fallbackMessage: 'Cop kutusu temizleme ayarlari alinamadi',
    );
    final data = result['data'];
    if (data is! Map) {
      return ContentTrashCleanupSettingsData.defaults(normalizedCode);
    }
    return ContentTrashCleanupSettingsData.fromJson(
      _asStringKeyMap(data),
      normalizedCode,
    );
  }

  @override
  Future<ContentTrashCleanupSettingsData> saveTrashCleanupSettings({
    required AdminSession session,
    required ContentTrashCleanupSettingsData settings,
  }) async {
    final normalizedSettings = settings.copyWith(
      languageCode: _cleanLanguageCode(settings.languageCode),
      days: _clampTrashDays(settings.days),
      scope: _trashScope(settings.scope),
    );
    final result = await _postJson('/api/admin/query', {
      'table': 'site_settings',
      'method': 'upsert',
      'select': _trashCleanupSettingsSelect,
      'values': normalizedSettings.toJson(),
      'options': {'onConflict': 'language_code'},
      'single': 'maybeSingle',
    });
    _throwIfApiError(
      result,
      fallbackMessage: 'Cop kutusu temizleme ayarlari kaydedilemedi',
    );
    final data = result['data'];
    if (data is! Map) return normalizedSettings;
    return ContentTrashCleanupSettingsData.fromJson(
      _asStringKeyMap(data),
      normalizedSettings.languageCode,
    );
  }

  Future<Map<String, Object?>> _postJson(
    String path,
    Map<String, Object?> body,
  ) async {
    final response =
        await (httpClient?.post(
                  _uri(path),
                  headers: await adminJsonHeaders(),
                  body: jsonEncode(body),
                ) ??
                adminHttpClient.post(
                  _uri(path),
                  headers: await adminJsonHeaders(),
                  body: jsonEncode(body),
                ))
            .timeout(_requestTimeout);

    final decoded = response.body.isEmpty
        ? <String, Object?>{}
        : jsonDecode(response.body);
    if (decoded is! Map) {
      throw const AdminContentSettingsException('Gecersiz sunucu yaniti');
    }
    final result = _asStringKeyMap(decoded);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwIfApiError(result, fallbackMessage: 'Sunucu istegi basarisiz');
    }
    return result;
  }

  Uri _uri(String path) {
    final baseUrl = (apiBaseUrl ?? _apiBaseUrl).trim();
    if (baseUrl.isNotEmpty) return Uri.parse(baseUrl).resolve(path);
    if (!kIsWeb) return _defaultLocalApiBaseUrl().resolve(path);
    return Uri.base.resolve(path);
  }

  Uri _defaultLocalApiBaseUrl() {
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => Uri.parse('http://10.0.2.2:4321'),
      _ => Uri.parse('http://127.0.0.1:4321'),
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
        throw AdminContentSettingsException(message);
      }
    }
    throw AdminContentSettingsException(fallbackMessage);
  }
}

class AdminContentSettingsException implements Exception {
  const AdminContentSettingsException(this.message);

  final String message;

  @override
  String toString() => message;
}

const _settingsSelect =
    'language_code,content_show_featured_section,'
    'content_comment_system_enabled,content_comment_approval_enabled,'
    'content_emoji_reactions_enabled,content_home_page_size';

const _postSettingsSelect =
    'language_code,content_post_url_structure,'
    'content_bulk_post_upload_enabled,content_delete_media_with_post_enabled,'
    'content_audio_download_enabled,content_show_post_author,'
    'content_show_post_date,content_show_post_view_count,'
    'content_require_new_post_approval,'
    'content_require_edited_post_approval,content_redirect_rss_posts,'
    'content_popular_post_limit,content_related_post_limit';

const _postFormatSettingsSelect = 'language_code,content_enabled_post_formats';

const _uploadSettingsSelect =
    'language_code,content_upload_image_format,'
    'content_upload_allowed_extensions,content_upload_max_image_mb,'
    'content_upload_max_video_mb,content_upload_max_audio_mb,'
    'content_upload_max_file_mb';

const _featuredSettingsSelect =
    'language_code,content_featured_source,content_featured_sorting,'
    'content_featured_limit,content_featured_show_news_info';

const _trashCleanupSettingsSelect =
    'language_code,content_trash_auto_delete_enabled,'
    'content_trash_auto_delete_days,content_trash_auto_delete_scope';

const contentPostFormatKeys = [
  'article',
  'opinion',
  'quiz',
  'poll',
  'video',
  'contents',
  'recipe',
  'event',
];

const contentUploadDefaultExtensions = [
  'jpg',
  'jpeg',
  'webp',
  'png',
  'gif',
  'avif',
  'heic',
  'svg',
  'mp4',
  'm4v',
  'webm',
  'mov',
  'avi',
  'mkv',
  '3gp',
  'mp3',
  'wav',
  'ogg',
  'm4a',
  'aac',
  'flac',
  'opus',
  'pdf',
  'doc',
  'docx',
  'ppt',
  'pptx',
  'xls',
  'xlsx',
  'txt',
  'csv',
  'zip',
  'rar',
];

String _string(Object? value, {String fallback = ''}) {
  final text = value?.toString();
  if (text == null || text.isEmpty) return fallback;
  return text;
}

bool _bool(Object? value, {required bool fallback}) {
  if (value is bool) return value;
  final text = value?.toString().trim().toLowerCase();
  if (text == 'true' || text == '1' || text == 'yes') return true;
  if (text == 'false' || text == '0' || text == 'no') return false;
  return fallback;
}

int _pageSize(Object? value, {required int fallback}) {
  if (value is num) return _clampPageSize(value.round());
  return _clampPageSize(int.tryParse(value?.toString() ?? '') ?? fallback);
}

int _clampPageSize(int value) {
  return value.clamp(1, 50).toInt();
}

String _postUrlStructure(Object? value, {String fallback = 'slug'}) {
  final normalized = value?.toString().trim().toLowerCase();
  if (normalized == 'id') return 'id';
  if (normalized == 'slug') return 'slug';
  return fallback;
}

Set<String> _formatSet(
  Object? value, {
  Set<String> fallback = const {...contentPostFormatKeys},
}) {
  final parsed = _stringSet(
    value,
  ).where(contentPostFormatKeys.contains).toSet();
  return parsed.isEmpty ? {...fallback} : parsed;
}

List<String> _normalizedFormatList(Set<String> values) {
  return [
    for (final key in contentPostFormatKeys)
      if (values.contains(key)) key,
  ];
}

Set<String> _extensionSet(
  Object? value, {
  Set<String> fallback = const {...contentUploadDefaultExtensions},
}) {
  final parsed = _stringSet(
    value,
  ).map(_cleanExtension).where((value) => value.isNotEmpty);
  final unique = <String>{};
  for (final item in parsed) {
    unique.add(item);
  }
  return unique.isEmpty ? {...fallback} : unique;
}

List<String> _normalizedExtensionList(Set<String> values) {
  return values
      .map(_cleanExtension)
      .where((value) => value.isNotEmpty)
      .toSet()
      .toList()
    ..sort();
}

Set<String> _stringSet(Object? value) {
  if (value is Iterable) {
    return value
        .map((item) => item.toString().trim().toLowerCase())
        .where((item) => item.isNotEmpty)
        .toSet();
  }
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return const {};
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Iterable) return _stringSet(decoded);
    } catch (_) {
      return trimmed
          .split(RegExp(r'[\s,;]+'))
          .map((item) => item.trim().toLowerCase())
          .where((item) => item.isNotEmpty)
          .toSet();
    }
  }
  return const {};
}

String _cleanExtension(String value) {
  return value.trim().toLowerCase().replaceFirst(RegExp(r'^\.+'), '');
}

String _imageFormat(Object? value, {String fallback = 'WEBP'}) {
  final normalized = value?.toString().trim().toUpperCase();
  if (normalized == 'JPG') return 'JPEG';
  if (normalized == 'JPEG' || normalized == 'PNG' || normalized == 'WEBP') {
    return normalized!;
  }
  return fallback;
}

int _megabyteLimit(Object? value, {required int fallback}) {
  if (value is num) return _clampMegabyteLimit(value.round());
  return _clampMegabyteLimit(int.tryParse(value?.toString() ?? '') ?? fallback);
}

int _clampMegabyteLimit(int value) {
  return value.clamp(1, 1024).toInt();
}

String _featuredSource(Object? value, {String fallback = 'manual'}) {
  final normalized = value?.toString().trim().toLowerCase();
  if (normalized == 'latest') return 'latest';
  if (normalized == 'manual') return 'manual';
  return fallback;
}

String _featuredSorting(Object? value, {String fallback = 'slider_order'}) {
  final normalized = value?.toString().trim().toLowerCase();
  if (normalized == 'publish_date') return 'publish_date';
  if (normalized == 'slider_order') return 'slider_order';
  return fallback;
}

int _featuredLimit(Object? value, {required int fallback}) {
  if (value is num) return _clampFeaturedLimit(value.round());
  return _clampFeaturedLimit(int.tryParse(value?.toString() ?? '') ?? fallback);
}

int _clampFeaturedLimit(int value) {
  return value.clamp(1, 50).toInt();
}

int _contentLimit(Object? value, {required int fallback}) {
  if (value is num) return _clampContentLimit(value.round());
  return _clampContentLimit(int.tryParse(value?.toString() ?? '') ?? fallback);
}

int _clampContentLimit(int value) {
  return value.clamp(1, 50).toInt();
}

int _trashDays(Object? value, {required int fallback}) {
  if (value is num) return _clampTrashDays(value.round());
  return _clampTrashDays(int.tryParse(value?.toString() ?? '') ?? fallback);
}

int _clampTrashDays(int value) {
  return value.clamp(1, 365).toInt();
}

String _trashScope(Object? value, {String fallback = 'all'}) {
  final normalized = value?.toString().trim().toLowerCase();
  if (normalized == 'draft') return 'draft';
  if (normalized == 'all') return 'all';
  return fallback;
}

String _cleanLanguageCode(String value) {
  final code = value.trim().toLowerCase().replaceAll('_', '-');
  return code.isEmpty ? 'tr' : code;
}

Map<String, Object?> _asStringKeyMap(Map<dynamic, dynamic> value) {
  return value.map((key, nestedValue) => MapEntry(key.toString(), nestedValue));
}
