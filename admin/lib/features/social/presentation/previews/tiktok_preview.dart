import 'package:flutter/material.dart';

/// TikTok vertical video preview.
class TiktokPreview extends StatelessWidget {
  const TiktokPreview({super.key, required this.caption, required this.imageUrl, required this.linkUrl, required this.linkTitle, this.profileName = 'Pateeznews'});
  final String caption, imageUrl, linkUrl, linkTitle, profileName;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 9 / 14,
      child: Container(
        decoration: BoxDecoration(color: const Color(0xFF121212), borderRadius: BorderRadius.circular(14)),
        clipBehavior: Clip.antiAlias,
        child: Stack(children: [
          if (imageUrl.isNotEmpty) Positioned.fill(child: Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink())),
          // Right side icons
          Positioned(right: 10, bottom: 100, child: Column(mainAxisSize: MainAxisSize.min, children: [
            _TkIcon(icon: Icons.favorite_rounded, label: '1.2K', color: Colors.white),
            const SizedBox(height: 18),
            _TkIcon(icon: Icons.chat_bubble_rounded, label: '84', color: Colors.white),
            const SizedBox(height: 18),
            _TkIcon(icon: Icons.bookmark_rounded, label: '256', color: Colors.white),
            const SizedBox(height: 18),
            _TkIcon(icon: Icons.reply_rounded, label: 'Paylaş', color: Colors.white),
            const SizedBox(height: 18),
            Container(width: 34, height: 34, decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white, width: 2), color: const Color(0xFF25F4EE)),
              child: const Icon(Icons.music_note, size: 18, color: Colors.white)),
          ])),
          // Bottom info
          Positioned(left: 12, right: 56, bottom: 16, child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('@${profileName.toLowerCase().replaceAll(' ', '')}', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0)),
            if (caption.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6),
              child: Text(caption, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.3, letterSpacing: 0))),
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.music_note_rounded, size: 14, color: Colors.white),
              const SizedBox(width: 6),
              Expanded(child: Text('Orijinal ses - ${profileName.toLowerCase().replaceAll(' ', '')}',
                style: const TextStyle(color: Colors.white, fontSize: 12, letterSpacing: 0), overflow: TextOverflow.ellipsis)),
            ]),
          ])),
          // Profile avatar
          Positioned(right: 10, bottom: 310, child: Column(children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2), color: const Color(0xFFE1306C)),
              child: Center(child: Text(profileName.isNotEmpty ? profileName[0] : 'P', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)))),
            Transform.translate(offset: const Offset(0, -6), child: Container(width: 20, height: 20, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFEE1D52)),
              child: const Icon(Icons.add, size: 14, color: Colors.white))),
          ])),
        ]),
      ),
    );
  }
}

class _TkIcon extends StatelessWidget {
  const _TkIcon({required this.icon, required this.label, required this.color});
  final IconData icon; final String label; final Color color;
  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 28, color: color),
    const SizedBox(height: 4),
    Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0)),
  ]);
}
