import 'package:flutter/material.dart';

/// Discord message preview with dark theme.
class DiscordPreview extends StatelessWidget {
  const DiscordPreview({super.key, required this.caption, required this.imageUrl, required this.linkUrl, required this.linkTitle, this.profileName = 'Pateeznews'});
  final String caption, imageUrl, linkUrl, linkTitle, profileName;
  @override
  Widget build(BuildContext context) {
    return Container(decoration: BoxDecoration(color: const Color(0xFF36393F), borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.all(14), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(radius: 20, backgroundColor: const Color(0xFF5865F2), child: Text(profileName.isNotEmpty ? profileName[0] : 'P', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          // Name & timestamp
          Row(children: [
            Text(profileName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF5865F2), letterSpacing: 0)),
            Container(margin: const EdgeInsets.only(left: 6), padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), decoration: BoxDecoration(color: const Color(0xFF5865F2), borderRadius: BorderRadius.circular(3)),
              child: const Text('BOT', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0))),
            const SizedBox(width: 8),
            const Text('Bugün 14:30', style: TextStyle(fontSize: 12, color: Color(0xFF72767D), letterSpacing: 0)),
          ]),
          // Message
          if (caption.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(caption, maxLines: 6, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, color: Color(0xFFDCDDDE), height: 1.4, letterSpacing: 0))),
          // Embed card
          if (linkUrl.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Container(decoration: BoxDecoration(color: const Color(0xFF2F3136), borderRadius: BorderRadius.circular(4),
            border: const Border(left: BorderSide(color: Color(0xFF5865F2), width: 4))),
            padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('pateeznews.com', style: TextStyle(fontSize: 11, color: Color(0xFF72767D), letterSpacing: 0)),
              const SizedBox(height: 4),
              Text(linkTitle.isNotEmpty ? linkTitle : 'Pateeznews', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF00AFF4), letterSpacing: 0), maxLines: 2, overflow: TextOverflow.ellipsis),
              if (caption.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(caption, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Color(0xFFDCDDDE), height: 1.3, letterSpacing: 0))),
            ]))),
          // Image
          if (imageUrl.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: ClipRRect(borderRadius: BorderRadius.circular(6), child: ConstrainedBox(constraints: const BoxConstraints(maxHeight: 200), child: Image.network(imageUrl, fit: BoxFit.cover, width: double.infinity, errorBuilder: (_, __, ___) => Container(height: 100, color: const Color(0xFF2F3136), child: const Center(child: Icon(Icons.image_outlined, size: 40, color: Color(0xFF72767D)))))))),
          // Reactions
          Padding(padding: const EdgeInsets.only(top: 8), child: Row(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3), decoration: BoxDecoration(color: const Color(0xFF5865F2).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFF5865F2).withValues(alpha: 0.4))),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [Text('👍', style: TextStyle(fontSize: 14)), SizedBox(width: 4), Text('3', style: TextStyle(color: Color(0xFFDCDDDE), fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0))])),
            const SizedBox(width: 6),
            Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3), decoration: BoxDecoration(color: const Color(0xFF4F545C).withValues(alpha: 0.3), borderRadius: BorderRadius.circular(6)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [Text('🔥', style: TextStyle(fontSize: 14)), SizedBox(width: 4), Text('1', style: TextStyle(color: Color(0xFFDCDDDE), fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0))])),
          ])),
        ])),
      ]));
  }
}
