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

/// Post format types.
enum SocialPostType {
  feed,
  story,
  reels,
  thread,
  shortVideo,
}

/// Data holder for the social publish editor state.
class SocialPublishData {
  const SocialPublishData({
    this.selectedPlatforms = const {},
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
  });

  final Set<SocialPlatform> selectedPlatforms;
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

  String get effectiveLink =>
      manualLink.isNotEmpty ? manualLink : newsLink;

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
  }) {
    return SocialPublishData(
      selectedPlatforms: selectedPlatforms ?? this.selectedPlatforms,
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
    );
  }
}

/// Brand colors and metadata for each platform.
class SocialPlatformInfo {
  const SocialPlatformInfo({
    required this.platform,
    required this.label,
    required this.color,
    required this.icon,
    required this.charLimit,
    required this.supportedTypes,
    this.gradientColors,
  });

  final SocialPlatform platform;
  final String label;
  final Color color;
  final IconData icon;
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
    icon: Icons.camera_alt_rounded,
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
    icon: Icons.facebook_rounded,
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
    icon: Icons.alternate_email,
    charLimit: 280,
    supportedTypes: [
      SocialPostType.feed,
      SocialPostType.thread,
    ],
  ),
  SocialPlatformInfo(
    platform: SocialPlatform.linkedin,
    label: 'LinkedIn',
    color: Color(0xFF0A66C2),
    icon: Icons.work_rounded,
    charLimit: 3000,
    supportedTypes: [SocialPostType.feed],
  ),
  SocialPlatformInfo(
    platform: SocialPlatform.tiktok,
    label: 'TikTok',
    color: Color(0xFF000000),
    icon: Icons.music_note_rounded,
    charLimit: 2200,
    supportedTypes: [SocialPostType.shortVideo],
  ),
  SocialPlatformInfo(
    platform: SocialPlatform.youtube,
    label: 'YouTube',
    color: Color(0xFFFF0000),
    icon: Icons.play_circle_filled_rounded,
    charLimit: 5000,
    supportedTypes: [
      SocialPostType.feed,
      SocialPostType.shortVideo,
    ],
  ),
  SocialPlatformInfo(
    platform: SocialPlatform.pinterest,
    label: 'Pinterest',
    color: Color(0xFFE60023),
    icon: Icons.push_pin_rounded,
    charLimit: 500,
    supportedTypes: [SocialPostType.feed],
  ),
  SocialPlatformInfo(
    platform: SocialPlatform.reddit,
    label: 'Reddit',
    color: Color(0xFFFF4500),
    icon: Icons.reddit,
    charLimit: 40000,
    supportedTypes: [SocialPostType.feed],
  ),
  SocialPlatformInfo(
    platform: SocialPlatform.threads,
    label: 'Threads',
    color: Color(0xFF000000),
    icon: Icons.tag_rounded,
    charLimit: 500,
    supportedTypes: [
      SocialPostType.feed,
      SocialPostType.thread,
    ],
  ),
  SocialPlatformInfo(
    platform: SocialPlatform.bluesky,
    label: 'Bluesky',
    color: Color(0xFF0085FF),
    icon: Icons.cloud_rounded,
    charLimit: 300,
    supportedTypes: [SocialPostType.feed],
  ),
  SocialPlatformInfo(
    platform: SocialPlatform.mastodon,
    label: 'Mastodon',
    color: Color(0xFF6364FF),
    icon: Icons.public_rounded,
    charLimit: 500,
    supportedTypes: [SocialPostType.feed],
  ),
  SocialPlatformInfo(
    platform: SocialPlatform.googleBusiness,
    label: 'Google Business',
    color: Color(0xFF4285F4),
    icon: Icons.store_rounded,
    charLimit: 1500,
    supportedTypes: [SocialPostType.feed],
  ),
  SocialPlatformInfo(
    platform: SocialPlatform.discord,
    label: 'Discord',
    color: Color(0xFF5865F2),
    icon: Icons.forum_rounded,
    charLimit: 2000,
    supportedTypes: [SocialPostType.feed],
  ),
  SocialPlatformInfo(
    platform: SocialPlatform.slack,
    label: 'Slack',
    color: Color(0xFF4A154B),
    icon: Icons.tag_rounded,
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
  SocialPostType.reels => 'social.publish.formatShortVideo',
  SocialPostType.thread => 'social.publish.formatThread',
  SocialPostType.shortVideo => 'social.publish.formatShortVideo',
};
