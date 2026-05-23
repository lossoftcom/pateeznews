import 'package:flutter/material.dart';

/// LinkedIn post preview.
class LinkedinPreview extends StatelessWidget {
  const LinkedinPreview({
    super.key, required this.caption, required this.imageUrl,
    required this.linkUrl, required this.linkTitle,
    this.profileName = 'Pateeznews',
  });
  final String caption, imageUrl, linkUrl, linkTitle, profileName;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E0E0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Padding(padding: const EdgeInsets.all(14), child: Row(children: [
          CircleAvatar(radius: 22, backgroundColor: const Color(0xFF0A66C2),
            child: Text(profileName.isNotEmpty ? profileName[0] : 'P', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(profileName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF191919), letterSpacing: 0)),
            const Text('Haber Portalı', style: TextStyle(fontSize: 12, color: Color(0xFF666666), letterSpacing: 0)),
            const Text('Şimdi • 🌐', style: TextStyle(fontSize: 12, color: Color(0xFF666666), letterSpacing: 0)),
          ])),
          const Icon(Icons.more_horiz, color: Color(0xFF666666)),
        ])),
        if (caption.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          child: Text(caption, maxLines: 4, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, color: Color(0xFF191919), height: 1.4, letterSpacing: 0))),
        if (imageUrl.isNotEmpty) AspectRatio(aspectRatio: 1.91, child: Container(color: const Color(0xFFF3F6F8),
          child: Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.image_outlined, size: 48, color: Color(0xFFCCCCCC)))))),
        if (linkUrl.isNotEmpty && imageUrl.isEmpty) Container(margin: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(color: const Color(0xFFF3F6F8), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFE0E0E0))),
          padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(linkTitle.isNotEmpty ? linkTitle : 'pateeznews.com', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF191919), letterSpacing: 0), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4), const Text('pateeznews.com', style: TextStyle(fontSize: 12, color: Color(0xFF666666), letterSpacing: 0)),
          ])),
        Padding(padding: const EdgeInsets.fromLTRB(14, 8, 14, 0), child: Row(children: [
          Container(width: 18, height: 18, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF0A66C2)),
            child: const Icon(Icons.thumb_up, size: 10, color: Colors.white)),
          Transform.translate(offset: const Offset(-3, 0), child: Container(width: 18, height: 18,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFDF704D)),
            child: const Icon(Icons.favorite, size: 10, color: Colors.white))),
          Transform.translate(offset: const Offset(-6, 0), child: Container(width: 18, height: 18,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFF5BB5C)),
            child: const Icon(Icons.lightbulb, size: 10, color: Colors.white))),
          const SizedBox(width: 2), const Text('42', style: TextStyle(fontSize: 12, color: Color(0xFF666666), letterSpacing: 0)),
        ])),
        const Divider(height: 20, indent: 14, endIndent: 14, color: Color(0xFFE0E0E0)),
        Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 12), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: const [
          _LiAction(icon: Icons.thumb_up_alt_outlined, label: 'Beğen'),
          _LiAction(icon: Icons.chat_bubble_outline_rounded, label: 'Yorum'),
          _LiAction(icon: Icons.repeat_rounded, label: 'Paylaş'),
          _LiAction(icon: Icons.send_outlined, label: 'Gönder'),
        ])),
      ]),
    );
  }
}

class _LiAction extends StatelessWidget {
  const _LiAction({required this.icon, required this.label});
  final IconData icon; final String label;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 18, color: const Color(0xFF666666)),
    const SizedBox(width: 4),
    Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF666666), letterSpacing: 0)),
  ]);
}
