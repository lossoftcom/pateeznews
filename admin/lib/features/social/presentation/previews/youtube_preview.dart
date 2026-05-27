import 'package:flutter/material.dart';

/// YouTube video card preview.
class YoutubePreview extends StatelessWidget {
  const YoutubePreview({
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
        : (caption.isNotEmpty ? caption : 'Pateeznews Haber');
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Thumbnail
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    color: const Color(0xFF1A1A1A),
                    child: imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Center(
                              child: Icon(
                                Icons.play_circle_outline,
                                size: 56,
                                color: Color(0xFF666666),
                              ),
                            ),
                          )
                        : const Center(
                            child: Icon(
                              Icons.play_circle_outline,
                              size: 56,
                              color: Color(0xFF666666),
                            ),
                          ),
                  ),
                ),
                // Play button overlay
                Center(
                  child: Container(
                    width: 56,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF0000),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      size: 32,
                      color: Colors.white,
                    ),
                  ),
                ),
                // Duration
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '0:00',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Info
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFFFF0000),
                  child: Text(
                    profileName.isNotEmpty ? profileName[0] : 'P',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F0F0F),
                          height: 1.3,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$profileName • 1.2B görüntülenme • Şimdi',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF606060),
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.more_vert, size: 20, color: Color(0xFF606060)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
