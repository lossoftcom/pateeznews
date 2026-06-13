import 'package:flutter/material.dart';

import '../../../../shared/widgets/admin_cached_image.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../social_platform_data.dart';
import '../previews/instagram_preview.dart';
import '../previews/facebook_preview.dart';
import '../previews/twitter_preview.dart';
import '../previews/linkedin_preview.dart';
import '../previews/tiktok_preview.dart';
import '../previews/youtube_preview.dart';
import '../previews/pinterest_preview.dart';
import '../previews/reddit_preview.dart';
import '../previews/threads_preview.dart';
import '../previews/bluesky_preview.dart';
import '../previews/mastodon_preview.dart';
import '../previews/google_business_preview.dart';
import '../previews/discord_preview.dart';
import '../previews/slack_preview.dart';
import 'social_brand_logo.dart';

/// Right-side preview panel with platform tab bar.
class SocialPreviewPanel extends StatefulWidget {
  const SocialPreviewPanel({
    super.key,
    required this.selectedPlatforms,
    required this.data,
  });

  final Set<SocialPlatform> selectedPlatforms;
  final SocialPublishData data;

  @override
  State<SocialPreviewPanel> createState() => _SocialPreviewPanelState();
}

class _SocialPreviewPanelState extends State<SocialPreviewPanel>
    with SingleTickerProviderStateMixin {
  SocialPlatform? _activeTab;

  @override
  void didUpdateWidget(SocialPreviewPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset tab if current is no longer selected
    if (_activeTab != null && !widget.selectedPlatforms.contains(_activeTab)) {
      _activeTab = widget.selectedPlatforms.isNotEmpty
          ? widget.selectedPlatforms.first
          : null;
    }
    // Set default tab
    if (_activeTab == null && widget.selectedPlatforms.isNotEmpty) {
      _activeTab = widget.selectedPlatforms.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final platforms = widget.selectedPlatforms.toList();

    if (platforms.isEmpty) {
      return _emptyState();
    }

    _activeTab ??= platforms.first;

    return Column(
      children: [
        // Tab bar
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border.all(color: AppColors.line),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: platforms.map((p) {
                final info = platformInfoFor(p);
                final active = p == _activeTab;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => setState(() => _activeTab = p),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: active
                              ? info.color.withValues(alpha: 0.10)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(
                            AppRadius.value * 1.5,
                          ),
                          border: active
                              ? Border.all(
                                  color: info.color.withValues(alpha: 0.3),
                                )
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SocialBrandLogo(
                              info: info,
                              size: 16,
                              iconSize: 16,
                              active: active,
                              showBackground: false,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              info.label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: active
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: active ? info.color : AppColors.inkSoft,
                                letterSpacing: 0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        // Preview content
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(8),
              ),
              border: Border(
                left: BorderSide(color: AppColors.line),
                right: BorderSide(color: AppColors.line),
                bottom: BorderSide(color: AppColors.line),
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(child: _buildPreviewWithFormat(_activeTab!)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreview(SocialPlatform platform) {
    final d = widget.data;
    final caption = d.displayCaption;
    final image = d.effectiveImage;
    final link = d.effectiveLink;
    final title = d.newsTitle;

    return switch (platform) {
      SocialPlatform.instagram => InstagramPreview(
        caption: caption,
        imageUrl: image,
        linkUrl: link,
        linkTitle: title,
      ),
      SocialPlatform.facebook => FacebookPreview(
        caption: caption,
        imageUrl: image,
        linkUrl: link,
        linkTitle: title,
      ),
      SocialPlatform.twitter => TwitterPreview(
        caption: caption,
        imageUrl: image,
        linkUrl: link,
        linkTitle: title,
      ),
      SocialPlatform.linkedin => LinkedinPreview(
        caption: caption,
        imageUrl: image,
        linkUrl: link,
        linkTitle: title,
      ),
      SocialPlatform.tiktok => TiktokPreview(
        caption: caption,
        imageUrl: image,
        linkUrl: link,
        linkTitle: title,
      ),
      SocialPlatform.youtube => YoutubePreview(
        caption: caption,
        imageUrl: image,
        linkUrl: link,
        linkTitle: title,
      ),
      SocialPlatform.pinterest => PinterestPreview(
        caption: caption,
        imageUrl: image,
        linkUrl: link,
        linkTitle: title,
      ),
      SocialPlatform.reddit => RedditPreview(
        caption: caption,
        imageUrl: image,
        linkUrl: link,
        linkTitle: title,
      ),
      SocialPlatform.threads => ThreadsPreview(
        caption: caption,
        imageUrl: image,
        linkUrl: link,
        linkTitle: title,
      ),
      SocialPlatform.bluesky => BlueskyPreview(
        caption: caption,
        imageUrl: image,
        linkUrl: link,
        linkTitle: title,
      ),
      SocialPlatform.mastodon => MastodonPreview(
        caption: caption,
        imageUrl: image,
        linkUrl: link,
        linkTitle: title,
      ),
      SocialPlatform.googleBusiness => GoogleBusinessPreview(
        caption: caption,
        imageUrl: image,
        linkUrl: link,
        linkTitle: title,
      ),
      SocialPlatform.discord => DiscordPreview(
        caption: caption,
        imageUrl: image,
        linkUrl: link,
        linkTitle: title,
      ),
      SocialPlatform.slack => SlackPreview(
        caption: caption,
        imageUrl: image,
        linkUrl: link,
        linkTitle: title,
      ),
    };
  }

  /// Wraps the preview in an appropriate frame based on post type.
  Widget _buildPreviewWithFormat(SocialPlatform platform) {
    final postType = widget.data.postType;
    final isVertical =
        postType == SocialPostType.story ||
        postType == SocialPostType.reels ||
        postType == SocialPostType.shortVideo;

    if (isVertical) {
      return _buildStoryPreview(platform, postType);
    }

    // Feed / Thread: regular preview
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        children: [
          _buildFormatBadge(postType),
          const SizedBox(height: 12),
          _buildPreview(platform),
        ],
      ),
    );
  }

  /// Badge showing current post format.
  Widget _buildFormatBadge(SocialPostType type) {
    final (label, icon) = switch (type) {
      SocialPostType.feed => ('Akış Paylaşımı', Icons.view_stream_rounded),
      SocialPostType.story => ('Hikaye', Icons.amp_stories_rounded),
      SocialPostType.reels => ('Reels', Icons.movie_filter_rounded),
      SocialPostType.thread => ('Thread', Icons.forum_rounded),
      SocialPostType.shortVideo => (
        'Kısa Video',
        Icons.slow_motion_video_rounded,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.deepOcean.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: AppColors.deepOcean.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.deepOcean.withValues(alpha: 0.7),
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }

  /// Vertical phone-frame for story/reels preview.
  Widget _buildStoryPreview(SocialPlatform platform, SocialPostType type) {
    final d = widget.data;
    final info = platformInfoFor(platform);
    final hasImage = d.effectiveImage.isNotEmpty;

    return Column(
      children: [
        _buildFormatBadge(type),
        const SizedBox(height: 12),
        // Phone frame
        Container(
          width: 260,
          height: 462, // ~9:16
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.shade800, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(21),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Background image or gradient
                if (hasImage)
                  AdminCachedImage(
                    url: d.effectiveImage,
                    fit: BoxFit.cover,
                    memCacheWidth: 1080,
                    errorWidget: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            info.color.withValues(alpha: 0.8),
                            info.color.withValues(alpha: 0.4),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          info.color.withValues(alpha: 0.8),
                          info.color.withValues(alpha: 0.3),
                        ],
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 48,
                        color: Colors.white54,
                      ),
                    ),
                  ),

                // Top bar (profile)
                Positioned(
                  top: 16,
                  left: 14,
                  right: 14,
                  child: Row(
                    children: [
                      // Avatar
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          color: info.color,
                        ),
                        child: const Center(
                          child: Text(
                            'P',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'pateeznews',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            shadows: [
                              Shadow(
                                blurRadius: 4,
                                color: Colors.black.withValues(alpha: 0.5),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.more_horiz,
                        color: Colors.white,
                        size: 20,
                      ),
                    ],
                  ),
                ),

                // Bottom overlay with caption
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 40, 14, 20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (d.displayCaption.isNotEmpty)
                          Text(
                            d.displayCaption,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              height: 1.4,
                              shadows: [
                                Shadow(
                                  blurRadius: 4,
                                  color: Colors.black.withValues(alpha: 0.5),
                                ),
                              ],
                            ),
                          ),
                        if (type == SocialPostType.reels ||
                            type == SocialPostType.shortVideo) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.music_note_rounded,
                                color: Colors.white70,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              const Expanded(
                                child: Text(
                                  'Orijinal ses — pateeznews',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Right side actions (reels / tiktok style)
                if (type == SocialPostType.reels ||
                    type == SocialPostType.shortVideo)
                  Positioned(
                    right: 10,
                    bottom: 80,
                    child: Column(
                      children: [
                        _storyAction(Icons.favorite_border_rounded, '1.2K'),
                        _storyAction(Icons.chat_bubble_outline_rounded, '234'),
                        _storyAction(Icons.send_outlined, ''),
                        _storyAction(Icons.bookmark_border_rounded, ''),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _storyAction(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 24),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.value * 2),
        border: Border.all(color: AppColors.line),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.deepOcean.withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.preview_rounded,
                  size: 28,
                  color: AppColors.iconMuted,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Önizleme',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.deepOcean,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Gönderinizin nasıl görüneceğini görmek için\nbir platform seçin',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.support,
                  height: 1.5,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
