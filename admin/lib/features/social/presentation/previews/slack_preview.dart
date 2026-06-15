import 'package:flutter/material.dart';

import '../widgets/social_media_preview.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

/// Slack message preview.
class SlackPreview extends StatelessWidget {
  const SlackPreview({
    super.key,
    required this.caption,
    required this.imageUrl,
    required this.linkUrl,
    required this.linkTitle,
    this.profileName = 'Pateeznews',
    this.accountAction,
  });
  final String caption, imageUrl, linkUrl, linkTitle, profileName;
  final Widget? accountAction;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF4A154B),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                profileName.isNotEmpty ? profileName[0] : 'P',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
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
                    Text(
                      profileName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1D1C1D),
                        letterSpacing: 0,
                      ),
                    ),
                    ?accountAction,
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8E8E8),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const Text(
                        'APP',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF616061),
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '14:30',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF616061),
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
                if (caption.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      caption,
                      maxLines: 6,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF1D1C1D),
                        height: 1.5,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                // Link unfurl
                if (linkUrl.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F8F8),
                        borderRadius: BorderRadius.circular(6),
                        border: const Border(
                          left: BorderSide(color: Color(0xFF36C5F0), width: 4),
                        ),
                      ),
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4A154B),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: const Center(
                                  child: Text(
                                    'P',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'pateeznews.com',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1D1C1D),
                                  letterSpacing: 0,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            linkTitle.isNotEmpty ? linkTitle : 'Pateeznews',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1264A3),
                              letterSpacing: 0,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (caption.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                caption,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF1D1C1D),
                                  height: 1.3,
                                  letterSpacing: 0,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                // Image
                if (imageUrl.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: SocialMediaPreview(
                          url: imageUrl,
                          fit: BoxFit.contain,
                          width: double.infinity,
                          memCacheWidth: 1080,
                          errorWidget: Container(
                            height: 100,
                            color: const Color(0xFFF8F8F8),
                            child: const Center(
                              child: Icon(
                                Symbols.image_outlined,
                                size: 40,
                                color: Color(0xFFE0E0E0),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                // Reactions & thread
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F0F0),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('👍', style: TextStyle(fontSize: 13)),
                            SizedBox(width: 4),
                            Text(
                              '2',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF616061),
                                letterSpacing: 0,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F0F0),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('❤️', style: TextStyle(fontSize: 13)),
                            SizedBox(width: 4),
                            Text(
                              '1',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF616061),
                                letterSpacing: 0,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Symbols.chat_bubble_outline_rounded,
                        size: 16,
                        color: Color(0xFF1264A3),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        '3 yanıt',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1264A3),
                          letterSpacing: 0,
                        ),
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
