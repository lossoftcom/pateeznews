import 'package:flutter/material.dart';

import '../../../../shared/widgets/admin_cached_image.dart';

/// Reddit post preview.
class RedditPreview extends StatelessWidget {
  const RedditPreview({
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
    final title = linkTitle.isNotEmpty
        ? linkTitle
        : (caption.isNotEmpty
              ? (caption.length > 80
                    ? '${caption.substring(0, 80)}...'
                    : caption)
              : 'Pateeznews Haber');
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCCCCCC)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Vote column
          Container(
            width: 40,
            decoration: const BoxDecoration(
              color: Color(0xFFF8F9FA),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(7),
                bottomLeft: Radius.circular(7),
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              children: [
                const Icon(
                  Icons.arrow_upward_rounded,
                  size: 20,
                  color: Color(0xFFFF4500),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    '42',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1B),
                      letterSpacing: 0,
                    ),
                  ),
                ),
                const Icon(
                  Icons.arrow_downward_rounded,
                  size: 20,
                  color: Color(0xFF878A8C),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 10,
                        backgroundColor: const Color(0xFFFF4500),
                        child: Text(
                          'r/',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'r/pateeznews',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A1B),
                          letterSpacing: 0,
                        ),
                      ),
                      const Text(
                        ' • ',
                        style: TextStyle(
                          color: Color(0xFF878A8C),
                          fontSize: 12,
                        ),
                      ),
                      const Text(
                        'u/pateeznews',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF878A8C),
                          letterSpacing: 0,
                        ),
                      ),
                      const Text(
                        ' • Şimdi',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF878A8C),
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1B),
                        height: 1.3,
                        letterSpacing: 0,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (caption.isNotEmpty && linkTitle.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        caption,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF1A1A1B),
                          height: 1.4,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  if (imageUrl.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Container(
                            color: const Color(0xFFF6F7F8),
                            child: AdminCachedImage(
                              url: imageUrl,
                              fit: BoxFit.cover,
                              memCacheWidth: 1080,
                              errorWidget: const Center(
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
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(
                      children: const [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 18,
                          color: Color(0xFF878A8C),
                        ),
                        SizedBox(width: 4),
                        Text(
                          '12 Yorum',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF878A8C),
                            letterSpacing: 0,
                          ),
                        ),
                        SizedBox(width: 14),
                        Icon(
                          Icons.share_outlined,
                          size: 18,
                          color: Color(0xFF878A8C),
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Paylaş',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF878A8C),
                            letterSpacing: 0,
                          ),
                        ),
                        SizedBox(width: 14),
                        Icon(
                          Icons.bookmark_border_rounded,
                          size: 18,
                          color: Color(0xFF878A8C),
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Kaydet',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF878A8C),
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
        ],
      ),
    );
  }
}
