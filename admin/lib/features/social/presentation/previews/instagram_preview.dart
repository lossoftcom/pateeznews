import 'package:flutter/material.dart';

import '../widgets/social_media_preview.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

/// Instagram feed post preview with authentic layout.
class InstagramPreview extends StatelessWidget {
  const InstagramPreview({
    super.key,
    required this.caption,
    required this.imageUrl,
    required this.linkUrl,
    required this.linkTitle,
    this.profileName = 'Pateeznews',
    this.profileUsername = 'pateeznews',
    this.avatarUrl = '',
    this.accountAction,
  });

  final String caption;
  final String imageUrl;
  final String linkUrl;
  final String linkTitle;
  final String profileName;
  final String profileUsername;
  final String avatarUrl;

  /// Avatar başlığında ismin yanında gösterilecek "hesap değiştir" oku (opsiyonel).
  final Widget? accountAction;

  @override
  Widget build(BuildContext context) {
    final cleanUsername = profileUsername.trim().replaceFirst(
      RegExp(r'^@'),
      '',
    );
    final username = cleanUsername.isEmpty
        ? profileName.toLowerCase().replaceAll(' ', '')
        : cleanUsername;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDBDBDB)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // Avatar with gradient border
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFFFCAF45),
                        Color(0xFFF77737),
                        Color(0xFFE1306C),
                        Color(0xFFC13584),
                        Color(0xFF833AB4),
                      ],
                      begin: Alignment.bottomLeft,
                      end: Alignment.topRight,
                    ),
                  ),
                  padding: const EdgeInsets.all(2),
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    padding: const EdgeInsets.all(1.5),
                    child: CircleAvatar(
                      radius: 13,
                      backgroundColor: const Color(0xFFE1306C),
                      foregroundImage: avatarUrl.trim().isNotEmpty
                          ? NetworkImage(avatarUrl.trim())
                          : null,
                      child: Text(
                        profileName.isNotEmpty ? profileName[0] : 'P',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          username,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF262626),
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                      ?accountAction,
                    ],
                  ),
                ),
                const Icon(
                  Symbols.more_horiz,
                  size: 20,
                  color: Color(0xFF262626),
                ),
              ],
            ),
          ),

          // Image
          Container(
            color: const Color(0xFFFAFAFA),
            child: imageUrl.isNotEmpty
                ? SocialMediaPreview(
                    url: imageUrl,
                    width: double.infinity,
                    fit: BoxFit.fitWidth,
                    memCacheWidth: 1080,
                    errorWidget: SizedBox(
                      height: 320,
                      child: _imagePlaceholder(),
                    ),
                  )
                : AspectRatio(aspectRatio: 1, child: _imagePlaceholder()),
          ),

          // Actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                const Icon(
                  Symbols.favorite_border_rounded,
                  size: 24,
                  color: Color(0xFF262626),
                ),
                const SizedBox(width: 14),
                const Icon(
                  Symbols.chat_bubble_outline_rounded,
                  size: 22,
                  color: Color(0xFF262626),
                ),
                const SizedBox(width: 14),
                const Icon(
                  Symbols.send_outlined,
                  size: 22,
                  color: Color(0xFF262626),
                ),
                const Spacer(),
                const Icon(
                  Symbols.bookmark_border_rounded,
                  size: 24,
                  color: Color(0xFF262626),
                ),
              ],
            ),
          ),

          // Likes
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '1.234 beğenme',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF262626),
                letterSpacing: 0,
              ),
            ),
          ),

          // Caption
          if (caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              child: RichText(
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF262626),
                    height: 1.4,
                    letterSpacing: 0,
                  ),
                  children: [
                    TextSpan(
                      text: '$username ',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    TextSpan(text: caption),
                  ],
                ),
              ),
            ),

          // Time
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 6, 12, 12),
            child: Text(
              'Şimdi',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF8E8E8E),
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      color: const Color(0xFFF0F0F0),
      child: const Center(
        child: Icon(
          Symbols.camera_alt_outlined,
          size: 48,
          color: Color(0xFFBDBDBD),
        ),
      ),
    );
  }
}
