import 'package:flutter/material.dart';

/// Pinterest pin card preview.
class PinterestPreview extends StatelessWidget {
  const PinterestPreview({super.key, required this.caption, required this.imageUrl, required this.linkUrl, required this.linkTitle, this.profileName = 'Pateeznews'});
  final String caption, imageUrl, linkUrl, linkTitle, profileName;
  @override
  Widget build(BuildContext context) {
    final title = linkTitle.isNotEmpty ? linkTitle : (caption.isNotEmpty ? caption : 'Pateeznews');
    return Container(width: double.infinity, decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias, child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Pin image
        AspectRatio(aspectRatio: 2 / 3, child: Stack(children: [
          Positioned.fill(child: Container(decoration: BoxDecoration(color: const Color(0xFFF0F0F0), borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
            child: imageUrl.isNotEmpty ? ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _pinPlaceholder()))
              : _pinPlaceholder())),
          // Gradient overlay at bottom
          Positioned(left: 0, right: 0, bottom: 0, height: 80, child: Container(decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withValues(alpha: 0.4)])))),
          // Save button
          Positioned(top: 10, right: 10, child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: const Color(0xFFE60023), borderRadius: BorderRadius.circular(24)),
            child: const Text('Kaydet', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0)))),
          // More options
          Positioned(bottom: 10, right: 10, child: Row(children: [
            Container(width: 30, height: 30, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.85), shape: BoxShape.circle),
              child: const Icon(Icons.ios_share_rounded, size: 16, color: Color(0xFF333333))),
            const SizedBox(width: 6),
            Container(width: 30, height: 30, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.85), shape: BoxShape.circle),
              child: const Icon(Icons.more_horiz, size: 16, color: Color(0xFF333333))),
          ])),
        ])),
        // Pin info
        Container(color: Colors.white, padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (linkUrl.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 4),
            child: Row(children: [const Icon(Icons.link, size: 14, color: Color(0xFF767676)), const SizedBox(width: 4),
              const Text('pateeznews.com', style: TextStyle(fontSize: 12, color: Color(0xFF767676), letterSpacing: 0))])),
          Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF111111), height: 1.3, letterSpacing: 0)),
          const SizedBox(height: 8),
          Row(children: [
            CircleAvatar(radius: 14, backgroundColor: const Color(0xFFE60023),
              child: Text(profileName.isNotEmpty ? profileName[0] : 'P', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700))),
            const SizedBox(width: 6),
            Text(profileName.toLowerCase().replaceAll(' ', ''), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF111111), letterSpacing: 0)),
          ]),
        ])),
      ]));
  }
  Widget _pinPlaceholder() => const Center(child: Icon(Icons.photo_library_outlined, size: 48, color: Color(0xFFBDBDBD)));
}
