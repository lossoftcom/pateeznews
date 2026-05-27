import 'package:flutter/material.dart';

/// Google Business Profile post preview.
class GoogleBusinessPreview extends StatelessWidget {
  const GoogleBusinessPreview({
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
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            color: const Color(0xFFF8F9FA),
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4285F4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      profileName.isNotEmpty ? profileName[0] : 'P',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              profileName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF202124),
                                letterSpacing: 0,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.verified,
                            size: 16,
                            color: Color(0xFF1A73E8),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Text(
                            '4.8',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF202124),
                              letterSpacing: 0,
                            ),
                          ),
                          const SizedBox(width: 4),
                          ...List.generate(
                            5,
                            (i) => Icon(
                              i < 5
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              size: 14,
                              color: const Color(0xFFFBBC04),
                            ),
                          ),
                          const Text(
                            ' (234)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF5F6368),
                              letterSpacing: 0,
                            ),
                          ),
                        ],
                      ),
                      const Text(
                        'Haber Portalı',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF5F6368),
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFDADCE0)),
          // Content
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.update_rounded,
                      size: 16,
                      color: Color(0xFF1A73E8),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Güncelleme',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A73E8),
                        letterSpacing: 0,
                      ),
                    ),
                    Text(
                      ' · Şimdi',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF5F6368),
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
                if (caption.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      caption,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF202124),
                        height: 1.5,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (imageUrl.isNotEmpty)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                color: const Color(0xFFF1F3F4),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const Center(
                    child: Icon(
                      Icons.image_outlined,
                      size: 48,
                      color: Color(0xFFDADCE0),
                    ),
                  ),
                ),
              ),
            ),
          // CTA
          Padding(
            padding: const EdgeInsets.all(14),
            child: SizedBox(
              width: double.infinity,
              height: 40,
              child: OutlinedButton(
                onPressed: null,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF1A73E8)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  'Daha fazla bilgi',
                  style: TextStyle(
                    color: Color(0xFF1A73E8),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
