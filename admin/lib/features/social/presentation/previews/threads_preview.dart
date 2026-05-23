import 'package:flutter/material.dart';

/// Threads post preview.
class ThreadsPreview extends StatelessWidget {
  const ThreadsPreview({super.key, required this.caption, required this.imageUrl, required this.linkUrl, required this.linkTitle, this.profileName = 'Pateeznews'});
  final String caption, imageUrl, linkUrl, linkTitle, profileName;
  @override
  Widget build(BuildContext context) {
    return Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE0E0E0))),
      padding: const EdgeInsets.all(14), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Column(children: [
          CircleAvatar(radius: 18, backgroundColor: const Color(0xFF000000), child: Text(profileName.isNotEmpty ? profileName[0] : 'P', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700))),
          Container(width: 2, height: 40, margin: const EdgeInsets.only(top: 6), decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(1))),
        ]),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Text(profileName.toLowerCase().replaceAll(' ', ''), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF000000), letterSpacing: 0)),
            const SizedBox(width: 2), const Icon(Icons.verified, size: 14, color: Color(0xFF000000)),
            const Spacer(), const Text('Şimdi', style: TextStyle(fontSize: 13, color: Color(0xFF999999), letterSpacing: 0)),
            const SizedBox(width: 8), const Icon(Icons.more_horiz, size: 18, color: Color(0xFF999999)),
          ]),
          if (caption.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(caption, maxLines: 6, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, color: Color(0xFF000000), height: 1.4, letterSpacing: 0))),
          if (imageUrl.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: ClipRRect(borderRadius: BorderRadius.circular(10), child: AspectRatio(aspectRatio: 16 / 9, child: Container(color: const Color(0xFFF5F5F5), child: Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.image_outlined, size: 40, color: Color(0xFFCCCCCC)))))))),
          Padding(padding: const EdgeInsets.only(top: 12), child: Row(children: const [
            Icon(Icons.favorite_border_rounded, size: 22, color: Color(0xFF000000)),
            SizedBox(width: 16), Icon(Icons.chat_bubble_outline_rounded, size: 20, color: Color(0xFF000000)),
            SizedBox(width: 16), Icon(Icons.repeat_rounded, size: 22, color: Color(0xFF000000)),
            SizedBox(width: 16), Icon(Icons.send_outlined, size: 20, color: Color(0xFF000000)),
          ])),
        ])),
      ]));
  }
}
