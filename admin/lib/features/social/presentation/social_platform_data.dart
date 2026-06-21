import 'package:flutter/material.dart';

/// Supported social media platforms.
enum SocialPlatform {
  instagram,
  facebook,
  twitter,
  linkedin,
  tiktok,
  youtube,
  pinterest,
  reddit,
  threads,
  bluesky,
  mastodon,
  googleBusiness,
  discord,
  slack,
}

extension SocialPlatformBundleData on SocialPlatform {
  String get bundleSocialType {
    return switch (this) {
      SocialPlatform.instagram => 'INSTAGRAM',
      SocialPlatform.facebook => 'FACEBOOK',
      SocialPlatform.twitter => 'TWITTER',
      SocialPlatform.linkedin => 'LINKEDIN',
      SocialPlatform.tiktok => 'TIKTOK',
      SocialPlatform.youtube => 'YOUTUBE',
      SocialPlatform.pinterest => 'PINTEREST',
      SocialPlatform.reddit => 'REDDIT',
      SocialPlatform.threads => 'THREADS',
      SocialPlatform.bluesky => 'BLUESKY',
      SocialPlatform.mastodon => 'MASTODON',
      SocialPlatform.googleBusiness => 'GOOGLE_BUSINESS',
      SocialPlatform.discord => 'DISCORD',
      SocialPlatform.slack => 'SLACK',
    };
  }
}

SocialPlatform socialPlatformFromBundleType(String type) {
  final normalized = type.trim().toUpperCase();
  return SocialPlatform.values.firstWhere(
    (platform) => platform.bundleSocialType == normalized,
    orElse: () => SocialPlatform.instagram,
  );
}

/// Post format types.
enum SocialPostType { feed, story, reels, thread, shortVideo }

List<String> _splitOptionList(String value) {
  return value
      .split(RegExp(r'[,;\n]'))
      .map((item) => item.trim().replaceFirst(RegExp(r'^@'), ''))
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

Map<String, Object?> _cleanPayload(Map<String, Object?> payload) {
  return {
    for (final entry in payload.entries)
      if (entry.value case final String value when value.trim().isNotEmpty)
        entry.key: value.trim()
      else if (entry.value case final List value when value.isNotEmpty)
        entry.key: value
      else if (entry.value case final Map value when value.isNotEmpty)
        entry.key: value
      else if (entry.value case final bool value)
        entry.key: value
      else if (entry.value case final num value)
        entry.key: value,
  };
}

class SocialInstagramPublishOptions {
  const SocialInstagramPublishOptions({
    this.altText = '',
    this.thumbnailUrl = '',
    this.locationId = '',
    this.collaborators = '',
    this.taggedUsers = '',
    this.thumbnailOffsetMs,
    this.shareToFeed = true,
    this.autoFitImage = false,
    this.autoCropImage = false,
  });

  final String altText;
  final String thumbnailUrl;
  final String locationId;
  final String collaborators;
  final String taggedUsers;
  final int? thumbnailOffsetMs;
  final bool shareToFeed;
  final bool autoFitImage;
  final bool autoCropImage;

  SocialInstagramPublishOptions copyWith({
    String? altText,
    String? thumbnailUrl,
    String? locationId,
    String? collaborators,
    String? taggedUsers,
    int? thumbnailOffsetMs,
    bool clearThumbnailOffset = false,
    bool? shareToFeed,
    bool? autoFitImage,
    bool? autoCropImage,
  }) {
    return SocialInstagramPublishOptions(
      altText: altText ?? this.altText,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      locationId: locationId ?? this.locationId,
      collaborators: collaborators ?? this.collaborators,
      taggedUsers: taggedUsers ?? this.taggedUsers,
      thumbnailOffsetMs: clearThumbnailOffset
          ? null
          : thumbnailOffsetMs ?? this.thumbnailOffsetMs,
      shareToFeed: shareToFeed ?? this.shareToFeed,
      autoFitImage: autoFitImage ?? this.autoFitImage,
      autoCropImage: autoCropImage ?? this.autoCropImage,
    );
  }

  Map<String, Object?> toPayload() {
    final tagged = _splitOptionList(taggedUsers)
        .map((username) => <String, Object?>{'username': username})
        .toList(growable: false);

    return _cleanPayload({
      'altText': altText,
      'thumbnail': thumbnailUrl,
      'locationId': locationId,
      'collaborators': _splitOptionList(collaborators),
      'tagged': tagged,
      'thumbnailOffset': thumbnailOffsetMs,
      if (!shareToFeed) 'shareToFeed': false,
      if (autoFitImage) 'autoFitImage': true,
      if (autoCropImage) 'autoCropImage': true,
    });
  }
}

class SocialFacebookPublishOptions {
  const SocialFacebookPublishOptions({
    this.altText = '',
    this.thumbnailUrl = '',
    this.nativeScheduleTime = '',
  });

  final String altText;
  final String thumbnailUrl;
  final String nativeScheduleTime;

  SocialFacebookPublishOptions copyWith({
    String? altText,
    String? thumbnailUrl,
    String? nativeScheduleTime,
  }) {
    return SocialFacebookPublishOptions(
      altText: altText ?? this.altText,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      nativeScheduleTime: nativeScheduleTime ?? this.nativeScheduleTime,
    );
  }

  Map<String, Object?> toPayload() {
    return _cleanPayload({
      'altText': altText,
      'thumbnail': thumbnailUrl,
      'nativeScheduleTime': nativeScheduleTime,
    });
  }
}

class SocialTiktokPublishOptions {
  const SocialTiktokPublishOptions({
    this.privacy = 'PUBLIC_TO_EVERYONE',
    this.thumbnailUrl = '',
    this.thumbnailOffsetMs,
    this.photoCoverIndex,
    this.musicSoundId = '',
    this.disableComments = false,
    this.disableDuet = false,
    this.disableStitch = false,
    this.isAiGenerated = false,
    this.isBrandContent = false,
    this.isOrganicBrandContent = false,
    this.autoAddMusic = false,
    this.autoScale = false,
    this.uploadToDraft = false,
  });

  final String privacy;
  final String thumbnailUrl;
  final int? thumbnailOffsetMs;
  final int? photoCoverIndex;
  final String musicSoundId;
  final bool disableComments;
  final bool disableDuet;
  final bool disableStitch;
  final bool isAiGenerated;
  final bool isBrandContent;
  final bool isOrganicBrandContent;
  final bool autoAddMusic;
  final bool autoScale;
  final bool uploadToDraft;

  SocialTiktokPublishOptions copyWith({
    String? privacy,
    String? thumbnailUrl,
    int? thumbnailOffsetMs,
    bool clearThumbnailOffset = false,
    int? photoCoverIndex,
    bool clearPhotoCoverIndex = false,
    String? musicSoundId,
    bool? disableComments,
    bool? disableDuet,
    bool? disableStitch,
    bool? isAiGenerated,
    bool? isBrandContent,
    bool? isOrganicBrandContent,
    bool? autoAddMusic,
    bool? autoScale,
    bool? uploadToDraft,
  }) {
    return SocialTiktokPublishOptions(
      privacy: privacy ?? this.privacy,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      thumbnailOffsetMs: clearThumbnailOffset
          ? null
          : thumbnailOffsetMs ?? this.thumbnailOffsetMs,
      photoCoverIndex: clearPhotoCoverIndex
          ? null
          : photoCoverIndex ?? this.photoCoverIndex,
      musicSoundId: musicSoundId ?? this.musicSoundId,
      disableComments: disableComments ?? this.disableComments,
      disableDuet: disableDuet ?? this.disableDuet,
      disableStitch: disableStitch ?? this.disableStitch,
      isAiGenerated: isAiGenerated ?? this.isAiGenerated,
      isBrandContent: isBrandContent ?? this.isBrandContent,
      isOrganicBrandContent:
          isOrganicBrandContent ?? this.isOrganicBrandContent,
      autoAddMusic: autoAddMusic ?? this.autoAddMusic,
      autoScale: autoScale ?? this.autoScale,
      uploadToDraft: uploadToDraft ?? this.uploadToDraft,
    );
  }

  Map<String, Object?> toPayload() {
    return _cleanPayload({
      if (privacy != 'PUBLIC_TO_EVERYONE') 'privacy': privacy,
      'thumbnail': thumbnailUrl,
      'thumbnailOffset': thumbnailOffsetMs,
      'photoCoverIndex': photoCoverIndex,
      if (musicSoundId.trim().isNotEmpty)
        'musicSoundInfo': {'musicSoundId': musicSoundId.trim()},
      if (disableComments) 'disableComments': true,
      if (disableDuet) 'disableDuet': true,
      if (disableStitch) 'disableStitch': true,
      if (isAiGenerated) 'isAiGenerated': true,
      if (isBrandContent) 'isBrandContent': true,
      if (isOrganicBrandContent) 'isOrganicBrandContent': true,
      if (autoAddMusic) 'autoAddMusic': true,
      if (autoScale) 'autoScale': true,
      if (uploadToDraft) 'uploadToDraft': true,
    });
  }
}

class SocialTwitterPublishOptions {
  const SocialTwitterPublishOptions({this.replySettings = 'EVERYONE'});

  final String replySettings;

  SocialTwitterPublishOptions copyWith({String? replySettings}) {
    return SocialTwitterPublishOptions(
      replySettings: replySettings ?? this.replySettings,
    );
  }

  Map<String, Object?> toPayload() {
    return _cleanPayload({
      if (replySettings != 'EVERYONE') 'replySettings': replySettings,
    });
  }
}

class SocialPlatformPublishOptions {
  const SocialPlatformPublishOptions({
    this.instagram = const SocialInstagramPublishOptions(),
    this.facebook = const SocialFacebookPublishOptions(),
    this.tiktok = const SocialTiktokPublishOptions(),
    this.twitter = const SocialTwitterPublishOptions(),
  });

  final SocialInstagramPublishOptions instagram;
  final SocialFacebookPublishOptions facebook;
  final SocialTiktokPublishOptions tiktok;
  final SocialTwitterPublishOptions twitter;

  SocialPlatformPublishOptions copyWith({
    SocialInstagramPublishOptions? instagram,
    SocialFacebookPublishOptions? facebook,
    SocialTiktokPublishOptions? tiktok,
    SocialTwitterPublishOptions? twitter,
  }) {
    return SocialPlatformPublishOptions(
      instagram: instagram ?? this.instagram,
      facebook: facebook ?? this.facebook,
      tiktok: tiktok ?? this.tiktok,
      twitter: twitter ?? this.twitter,
    );
  }

  Map<String, Object?> toPayload() {
    final instagramPayload = instagram.toPayload();
    final facebookPayload = facebook.toPayload();
    final tiktokPayload = tiktok.toPayload();
    final twitterPayload = twitter.toPayload();
    return {
      if (instagramPayload.isNotEmpty) 'INSTAGRAM': instagramPayload,
      if (facebookPayload.isNotEmpty) 'FACEBOOK': facebookPayload,
      if (tiktokPayload.isNotEmpty) 'TIKTOK': tiktokPayload,
      if (twitterPayload.isNotEmpty) 'TWITTER': twitterPayload,
    };
  }
}

/// Data holder for the social publish editor state.
class SocialPublishData {
  const SocialPublishData({
    this.selectedPlatforms = const {},
    this.selectedConnectedAccountIds = const {},
    this.postType = SocialPostType.feed,
    this.caption = '',
    this.hashtags = const [],
    this.newsTitle = '',
    this.newsImageUrl = '',
    this.newsLink = '',
    this.manualLink = '',
    this.campaignName = '',
    this.mediaUrls = const [],
    this.newsSummary = '',
    this.newsKeywords = '',
    this.newsCategory = '',
    this.newsType = '',
    this.platformOptions = const SocialPlatformPublishOptions(),
  });

  final Set<SocialPlatform> selectedPlatforms;
  final Map<SocialPlatform, int> selectedConnectedAccountIds;
  final SocialPostType postType;
  final String caption;
  final List<String> hashtags;
  final String newsTitle;
  final String newsImageUrl;
  final String newsLink;
  final String manualLink;
  final String campaignName;
  final List<String> mediaUrls;
  final String newsSummary;
  final String newsKeywords;
  final String newsCategory;
  final String newsType;
  final SocialPlatformPublishOptions platformOptions;

  String get effectiveLink => manualLink.isNotEmpty ? manualLink : newsLink;

  /// First available image for previews.
  String get effectiveImage {
    if (mediaUrls.isNotEmpty) return mediaUrls.first;
    return newsImageUrl;
  }

  /// All images for multi-image previews.
  List<String> get effectiveImages {
    if (mediaUrls.isNotEmpty) return mediaUrls;
    if (newsImageUrl.isNotEmpty) return [newsImageUrl];
    return const [];
  }

  String get displayCaption {
    final buf = StringBuffer(caption);
    if (hashtags.isNotEmpty) {
      buf.write('\n\n');
      buf.write(hashtags.map((t) => '#$t').join(' '));
    }
    return buf.toString();
  }

  SocialPublishData copyWith({
    Set<SocialPlatform>? selectedPlatforms,
    Map<SocialPlatform, int>? selectedConnectedAccountIds,
    SocialPostType? postType,
    String? caption,
    List<String>? hashtags,
    String? newsTitle,
    String? newsImageUrl,
    String? newsLink,
    String? manualLink,
    String? campaignName,
    List<String>? mediaUrls,
    String? newsSummary,
    String? newsKeywords,
    String? newsCategory,
    String? newsType,
    SocialPlatformPublishOptions? platformOptions,
  }) {
    return SocialPublishData(
      selectedPlatforms: selectedPlatforms ?? this.selectedPlatforms,
      selectedConnectedAccountIds:
          selectedConnectedAccountIds ?? this.selectedConnectedAccountIds,
      postType: postType ?? this.postType,
      caption: caption ?? this.caption,
      hashtags: hashtags ?? this.hashtags,
      newsTitle: newsTitle ?? this.newsTitle,
      newsImageUrl: newsImageUrl ?? this.newsImageUrl,
      newsLink: newsLink ?? this.newsLink,
      manualLink: manualLink ?? this.manualLink,
      campaignName: campaignName ?? this.campaignName,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      newsSummary: newsSummary ?? this.newsSummary,
      newsKeywords: newsKeywords ?? this.newsKeywords,
      newsCategory: newsCategory ?? this.newsCategory,
      newsType: newsType ?? this.newsType,
      platformOptions: platformOptions ?? this.platformOptions,
    );
  }
}

/// Brand colors and metadata for each platform.
class SocialPlatformInfo {
  const SocialPlatformInfo({
    required this.platform,
    required this.label,
    required this.color,
    required this.logoAsset,
    required this.charLimit,
    required this.supportedTypes,
    this.gradientColors,
  });

  final SocialPlatform platform;
  final String label;
  final Color color;
  final String logoAsset;
  final int charLimit;
  final List<SocialPostType> supportedTypes;
  final List<Color>? gradientColors;
}

/// All platform infos.
const List<SocialPlatformInfo> socialPlatforms = [
  SocialPlatformInfo(
    platform: SocialPlatform.instagram,
    label: 'Instagram',
    color: Color(0xFFE1306C),
    logoAsset: 'assets/images/social/instagram.svg',
    charLimit: 2200,
    supportedTypes: [
      SocialPostType.feed,
      SocialPostType.story,
      SocialPostType.reels,
    ],
    gradientColors: [
      Color(0xFFFCAF45),
      Color(0xFFF77737),
      Color(0xFFE1306C),
      Color(0xFFC13584),
      Color(0xFF833AB4),
    ],
  ),
  SocialPlatformInfo(
    platform: SocialPlatform.facebook,
    label: 'Facebook',
    color: Color(0xFF1877F2),
    logoAsset: 'assets/images/social/facebook.svg',
    charLimit: 63206,
    supportedTypes: [
      SocialPostType.feed,
      SocialPostType.story,
      SocialPostType.reels,
    ],
  ),
  SocialPlatformInfo(
    platform: SocialPlatform.twitter,
    label: 'X',
    color: Color(0xFF000000),
    logoAsset: 'assets/images/social/x.svg',
    charLimit: 280,
    supportedTypes: [SocialPostType.feed, SocialPostType.thread],
  ),
  SocialPlatformInfo(
    platform: SocialPlatform.linkedin,
    label: 'LinkedIn',
    color: Color(0xFF0A66C2),
    logoAsset: 'assets/images/social/linkedin.svg',
    charLimit: 3000,
    supportedTypes: [SocialPostType.feed],
  ),
  SocialPlatformInfo(
    platform: SocialPlatform.tiktok,
    label: 'TikTok',
    color: Color(0xFF000000),
    logoAsset: 'assets/images/social/tiktok.svg',
    charLimit: 2200,
    supportedTypes: [SocialPostType.shortVideo],
  ),
  SocialPlatformInfo(
    platform: SocialPlatform.youtube,
    label: 'YouTube',
    color: Color(0xFFFF0000),
    logoAsset: 'assets/images/social/youtube.svg',
    charLimit: 5000,
    supportedTypes: [SocialPostType.feed, SocialPostType.shortVideo],
  ),
  SocialPlatformInfo(
    platform: SocialPlatform.pinterest,
    label: 'Pinterest',
    color: Color(0xFFE60023),
    logoAsset: 'assets/images/social/pinterest.svg',
    charLimit: 500,
    supportedTypes: [SocialPostType.feed],
  ),
  SocialPlatformInfo(
    platform: SocialPlatform.reddit,
    label: 'Reddit',
    color: Color(0xFFFF4500),
    logoAsset: 'assets/images/social/reddit.svg',
    charLimit: 40000,
    supportedTypes: [SocialPostType.feed],
  ),
  SocialPlatformInfo(
    platform: SocialPlatform.threads,
    label: 'Threads',
    color: Color(0xFF000000),
    logoAsset: 'assets/images/social/threads.svg',
    charLimit: 500,
    supportedTypes: [SocialPostType.feed, SocialPostType.thread],
  ),
  SocialPlatformInfo(
    platform: SocialPlatform.bluesky,
    label: 'Bluesky',
    color: Color(0xFF0085FF),
    logoAsset: 'assets/images/social/bluesky.svg',
    charLimit: 300,
    supportedTypes: [SocialPostType.feed],
  ),
  SocialPlatformInfo(
    platform: SocialPlatform.mastodon,
    label: 'Mastodon',
    color: Color(0xFF6364FF),
    logoAsset: 'assets/images/social/mastodon.svg',
    charLimit: 500,
    supportedTypes: [SocialPostType.feed],
  ),
  SocialPlatformInfo(
    platform: SocialPlatform.googleBusiness,
    label: 'Google Business',
    color: Color(0xFF4285F4),
    logoAsset: 'assets/images/social/google_business.svg',
    charLimit: 1500,
    supportedTypes: [SocialPostType.feed],
  ),
  SocialPlatformInfo(
    platform: SocialPlatform.discord,
    label: 'Discord',
    color: Color(0xFF5865F2),
    logoAsset: 'assets/images/social/discord.svg',
    charLimit: 2000,
    supportedTypes: [SocialPostType.feed],
  ),
  SocialPlatformInfo(
    platform: SocialPlatform.slack,
    label: 'Slack',
    color: Color(0xFF4A154B),
    logoAsset: 'assets/images/social/slack.svg',
    charLimit: 40000,
    supportedTypes: [SocialPostType.feed],
  ),
];

/// Lookup helper.
SocialPlatformInfo platformInfoFor(SocialPlatform p) =>
    socialPlatforms.firstWhere((i) => i.platform == p);

/// Post type labels (translation keys).
String postTypeKey(SocialPostType t) => switch (t) {
  SocialPostType.feed => 'social.publish.formatFeed',
  SocialPostType.story => 'social.publish.formatStory',
  SocialPostType.reels => 'social.publish.formatReels',
  SocialPostType.thread => 'social.publish.formatThread',
  SocialPostType.shortVideo => 'social.publish.formatShortVideo',
};
