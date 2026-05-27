import 'package:flutter/material.dart';

/// Facebook post preview with authentic layout.
class FacebookPreview extends StatelessWidget {
  const FacebookPreview({
    super.key,
    required this.caption,
    required this.imageUrl,
    required this.linkUrl,
    required this.linkTitle,
    this.profileName = 'Pateeznews',
  });

  final String caption;
  final String imageUrl;
  final String linkUrl;
  final String linkTitle;
  final String profileName;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: const Color(0xFF1877F2),
                  child: Text(
                    profileName.isNotEmpty ? profileName[0] : 'P',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
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
                        profileName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF050505),
                          letterSpacing: 0,
                        ),
                      ),
                      const Row(
                        children: [
                          Text(
                            'Şimdi',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF65676B),
                              letterSpacing: 0,
                            ),
                          ),
                          SizedBox(width: 4),
                          Text(
                            '•',
                            style: TextStyle(
                              color: Color(0xFF65676B),
                              fontSize: 12,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.public,
                            size: 12,
                            color: Color(0xFF65676B),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.more_horiz,
                  color: Color(0xFF65676B),
                  size: 22,
                ),
              ],
            ),
          ),

          // Caption
          if (caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Text(
                caption,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF050505),
                  height: 1.4,
                  letterSpacing: 0,
                ),
              ),
            ),

          // Image
          if (imageUrl.isNotEmpty || linkUrl.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  color: const Color(0xFFF0F2F5),
                  child: imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _imagePlaceholder(),
                        )
                      : _imagePlaceholder(),
                ),
              ),
            ),

          // Link preview
          if (linkUrl.isNotEmpty && imageUrl.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F2F5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFDADDE1)),
                ),
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE4E6EB),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.link,
                        size: 20,
                        color: Color(0xFF65676B),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            linkTitle.isNotEmpty ? linkTitle : 'pateeznews.com',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF050505),
                              letterSpacing: 0,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'pateeznews.com',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF65676B),
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

          // Reactions
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Row(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF1877F2),
                  ),
                  child: const Icon(
                    Icons.thumb_up,
                    size: 10,
                    color: Colors.white,
                  ),
                ),
                Transform.translate(
                  offset: const Offset(-4, 0),
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFED4956),
                    ),
                    child: const Icon(
                      Icons.favorite,
                      size: 10,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                const Text(
                  '24',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF65676B),
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),

          // Divider
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Divider(height: 20, color: Color(0xFFCED0D4)),
          ),

          // Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _ActionButton(
                  icon: Icons.thumb_up_alt_outlined,
                  label: 'Beğen',
                ),
                _ActionButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'Yorum',
                ),
                _ActionButton(icon: Icons.reply_rounded, label: 'Paylaş'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      color: const Color(0xFFF0F2F5),
      child: const Center(
        child: Icon(Icons.image_outlined, size: 48, color: Color(0xFFBCC0C4)),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF65676B)),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF65676B),
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}
