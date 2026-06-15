import 'package:flutter/material.dart';

import '../widgets/social_media_preview.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

/// X (Twitter) tweet preview with authentic layout.
class TwitterPreview extends StatelessWidget {
  const TwitterPreview({
    super.key,
    required this.caption,
    required this.imageUrl,
    required this.linkUrl,
    required this.linkTitle,
    this.profileName = 'Pateeznews',
    this.profileUsername = 'pateeznews',
    this.avatarUrl = '',
    this.verified = false,
    this.accountAction,
  });

  final String caption;
  final String imageUrl;
  final String linkUrl;
  final String linkTitle;
  final String profileName;
  final String profileUsername;
  final String avatarUrl;
  final bool verified;

  /// Avatar başlığında ismin yanında gösterilecek "hesap değiştir" oku (opsiyonel).
  final Widget? accountAction;

  @override
  Widget build(BuildContext context) {
    final cleanUsername = profileUsername.trim().replaceFirst(
      RegExp(r'^@'),
      '',
    );
    final fallbackUsername = profileName.toLowerCase().replaceAll(' ', '');
    final handle =
        '@${cleanUsername.isEmpty ? fallbackUsername : cleanUsername}';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEFF3F4)),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFF0F1419),
            foregroundImage: avatarUrl.trim().isNotEmpty
                ? NetworkImage(avatarUrl.trim())
                : null,
            child: Text(
              profileName.isNotEmpty ? profileName[0] : 'P',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Name row
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        profileName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F1419),
                          letterSpacing: 0,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 2),
                    if (verified) ...[
                      const Icon(
                        Symbols.verified,
                        size: 16,
                        color: Color(0xFF1D9BF0),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Flexible(
                      child: Text(
                        handle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF536471),
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                    const Text(
                      ' · Şimdi',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF536471),
                        letterSpacing: 0,
                      ),
                    ),
                    ?accountAction,
                  ],
                ),

                // Tweet text
                if (caption.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      caption,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF0F1419),
                        height: 1.4,
                        letterSpacing: 0,
                      ),
                      maxLines: 6,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                // Image card
                if (imageUrl.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        color: const Color(0xFFF7F9F9),
                        child: SocialMediaPreview(
                          url: imageUrl,
                          width: double.infinity,
                          fit: BoxFit.fitWidth,
                          memCacheWidth: 1080,
                          errorWidget: const SizedBox(
                            height: 160,
                            child: Center(
                              child: Icon(
                                Symbols.image_outlined,
                                size: 40,
                                color: Color(0xFFCFD9DE),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Link card
                if (linkUrl.isNotEmpty && imageUrl.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFCFD9DE)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 100,
                            color: const Color(0xFFF7F9F9),
                            child: const Center(
                              child: Icon(
                                Symbols.link,
                                size: 32,
                                color: Color(0xFFCFD9DE),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(
                              border: Border(
                                top: BorderSide(color: Color(0xFFCFD9DE)),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'pateeznews.com',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF536471),
                                    letterSpacing: 0,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  linkTitle.isNotEmpty
                                      ? linkTitle
                                      : 'Pateeznews',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF0F1419),
                                    letterSpacing: 0,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Action row
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _ActionIcon(
                        icon: Symbols.chat_bubble_outline_rounded,
                        count: '2',
                        color: const Color(0xFF536471),
                      ),
                      _ActionIcon(
                        icon: Symbols.repeat_rounded,
                        count: '5',
                        color: const Color(0xFF00BA7C),
                      ),
                      _ActionIcon(
                        icon: Symbols.favorite_border_rounded,
                        count: '18',
                        color: const Color(0xFFF91880),
                      ),
                      _ActionIcon(
                        icon: Symbols.bar_chart_rounded,
                        count: '1.2K',
                        color: const Color(0xFF536471),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Symbols.bookmark_border_rounded,
                            size: 18,
                            color: const Color(0xFF536471),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Symbols.ios_share_rounded,
                            size: 18,
                            color: const Color(0xFF536471),
                          ),
                        ],
                      ),
                    ],
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

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.icon,
    required this.count,
    required this.color,
  });

  final IconData icon;
  final String count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF536471)),
        const SizedBox(width: 4),
        Text(
          count,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF536471),
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}
