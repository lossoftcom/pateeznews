import 'package:flutter/material.dart';

/// Bluesky post preview.
class BlueskyPreview extends StatelessWidget {
  const BlueskyPreview({
    super.key,
    required this.caption,
    required this.imageUrl,
    required this.linkUrl,
    required this.linkTitle,
    this.profileName = 'Pateeznews',
  });
  final String caption, imageUrl, linkUrl, linkTitle, profileName;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFF0085FF),
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
                          color: Color(0xFF0F1419),
                          letterSpacing: 0,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '@${profileName.toLowerCase().replaceAll(' ', '')}.bsky.social',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF687684),
                        letterSpacing: 0,
                      ),
                    ),
                    const Text(
                      ' · Şimdi',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF687684),
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
                if (caption.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      caption,
                      maxLines: 6,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF0F1419),
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
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Center(
                              child: Icon(
                                Icons.image_outlined,
                                size: 40,
                                color: Color(0xFFCCCCCC),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (linkUrl.isNotEmpty && imageUrl.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE5E5E5)),
                      ),
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF0085FF,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.link,
                              size: 20,
                              color: Color(0xFF0085FF),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  linkTitle.isNotEmpty
                                      ? linkTitle
                                      : 'pateeznews.com',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0F1419),
                                    letterSpacing: 0,
                                  ),
                                ),
                                const Text(
                                  'pateeznews.com',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF687684),
                                    letterSpacing: 0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      _BsAction(
                        icon: Icons.chat_bubble_outline_rounded,
                        count: '3',
                      ),
                      _BsAction(icon: Icons.repeat_rounded, count: '7'),
                      _BsAction(
                        icon: Icons.favorite_border_rounded,
                        count: '24',
                      ),
                      Icon(
                        Icons.more_horiz,
                        size: 18,
                        color: Color(0xFF687684),
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

class _BsAction extends StatelessWidget {
  const _BsAction({required this.icon, required this.count});
  final IconData icon;
  final String count;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 18, color: const Color(0xFF687684)),
      const SizedBox(width: 4),
      Text(
        count,
        style: const TextStyle(
          fontSize: 13,
          color: Color(0xFF687684),
          letterSpacing: 0,
        ),
      ),
    ],
  );
}
