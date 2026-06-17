import 'package:flutter/material.dart';

import '../widgets/social_media_preview.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

/// Mastodon toot preview.
class MastodonPreview extends StatelessWidget {
  const MastodonPreview({
    super.key,
    required this.caption,
    required this.imageUrl,
    required this.linkUrl,
    required this.linkTitle,
    this.profileName = 'Pateez',
    this.accountAction,
  });
  final String caption, imageUrl, linkUrl, linkTitle, profileName;
  final Widget? accountAction;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE6E6E6)),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFF6364FF),
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
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        profileName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F232B),
                          letterSpacing: 0,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    ?accountAction,
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '@${profileName.toLowerCase().replaceAll(' ', '')}@mastodon.social',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF9BAEC8),
                          letterSpacing: 0,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (caption.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      caption,
                      maxLines: 6,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF1F232B),
                        height: 1.4,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                if (imageUrl.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Container(
                          color: const Color(0xFFF5F5F5),
                          child: SocialMediaPreview(
                            url: imageUrl,
                            fit: BoxFit.contain,
                            memCacheWidth: 1080,
                            errorWidget: const Center(
                              child: Icon(
                                Symbols.image_outlined,
                                size: 40,
                                color: Color(0xFFCCCCCC),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Icon(
                        Symbols.reply_rounded,
                        size: 20,
                        color: Color(0xFF9BAEC8),
                      ),
                      Icon(
                        Symbols.repeat_rounded,
                        size: 20,
                        color: Color(0xFF9BAEC8),
                      ),
                      Icon(
                        Symbols.star_border_rounded,
                        size: 20,
                        color: Color(0xFF9BAEC8),
                      ),
                      Icon(
                        Symbols.bookmark_border_rounded,
                        size: 20,
                        color: Color(0xFF9BAEC8),
                      ),
                      Icon(
                        Symbols.more_horiz,
                        size: 20,
                        color: Color(0xFF9BAEC8),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    'Şimdi',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9BAEC8),
                      letterSpacing: 0,
                    ),
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
