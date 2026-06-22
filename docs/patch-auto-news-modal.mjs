#!/usr/bin/env node
import fs from 'node:fs';

const file = 'admin/lib/features/automatic_news/presentation/automatic_news_screen.dart';
if (!fs.existsSync(file)) process.exit(0);

let source = fs.readFileSync(file, 'utf8');
let next = source;

if (!next.includes("import 'dart:convert';")) {
  next = next.replace("import 'dart:async';\n", "import 'dart:async';\nimport 'dart:convert';\n");
}
if (!next.includes("import 'package:http/http.dart' as http;")) {
  next = next.replace("import 'package:flutter/material.dart';\n", "import 'package:flutter/material.dart';\nimport 'package:http/http.dart' as http;\n");
}
if (!next.includes("import 'package:url_launcher/url_launcher.dart';")) {
  next = next.replace("import 'package:share_plus/share_plus.dart' hide XFile;\n", "import 'package:share_plus/share_plus.dart' hide XFile;\nimport 'package:url_launcher/url_launcher.dart';\n");
}

const mediaStart = next.indexOf('class _AutomaticNewsPreviewMedia extends StatelessWidget');
const mediaEnd = next.indexOf('class _AutomaticNewsMediaFallback', mediaStart);
if (mediaStart !== -1 && mediaEnd !== -1 && !next.includes('class _AutomaticNewsPreviewMediaState extends State<_AutomaticNewsPreviewMedia>')) {
  const mediaClass = String.raw`class _AutomaticNewsPreviewMedia extends StatefulWidget {
  const _AutomaticNewsPreviewMedia({
    required this.draft,
    required this.imageRequestHeaders,
    required this.compact,
  });

  final _AutomaticNewsDraft draft;
  final Map<String, String> imageRequestHeaders;
  final bool compact;

  @override
  State<_AutomaticNewsPreviewMedia> createState() => _AutomaticNewsPreviewMediaState();
}

class _AutomaticNewsPreviewMediaState extends State<_AutomaticNewsPreviewMedia> {
  late Future<List<String>> _imagesFuture;
  var _page = 0;

  @override
  void initState() {
    super.initState();
    _imagesFuture = _loadImages();
  }

  @override
  void didUpdateWidget(covariant _AutomaticNewsPreviewMedia oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.draft.recordId != widget.draft.recordId ||
        oldWidget.draft.imageUrl != widget.draft.imageUrl) {
      _page = 0;
      _imagesFuture = _loadImages();
    }
  }

  List<String> _fallbackImages() {
    return _uniquePreviewUrls([widget.draft.imageUrl, widget.draft.mediaUrl]);
  }

  Future<List<String>> _loadImages() async {
    final fallback = _fallbackImages();
    if (widget.draft.recordId.trim().isEmpty) return fallback;
    try {
      final headers = await adminAuthHeaders();
      final uri = Uri.base
          .resolve('/api/admin/automatic-news/media')
          .replace(queryParameters: {'id': widget.draft.recordId});
      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 7));
      if (response.statusCode < 200 || response.statusCode >= 300) return fallback;
      final decoded = jsonDecode(response.body);
      final data = decoded is Map ? decoded['data'] : null;
      final rawImages = data is Map ? data['images'] : null;
      final images = rawImages is List
          ? rawImages.map((item) => item.toString()).toList(growable: false)
          : const <String>[];
      return _uniquePreviewUrls([...images, ...fallback]);
    } catch (_) {
      return fallback;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasVideo = widget.draft.videoUrl.isNotEmpty;
    return FutureBuilder<List<String>>(
      future: _imagesFuture,
      builder: (context, snapshot) {
        final images = snapshot.data ?? _fallbackImages();
        final hasImages = images.isNotEmpty;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: widget.compact ? 280 : 420,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.value),
                border: Border.all(color: AppColors.line.withValues(alpha: 0.82)),
              ),
              clipBehavior: Clip.antiAlias,
              child: hasImages
                  ? _AutomaticNewsImageSlider(
                      draft: widget.draft,
                      images: images,
                      imageRequestHeaders: widget.imageRequestHeaders,
                      compact: widget.compact,
                      hasVideo: hasVideo,
                      page: _page.clamp(0, images.length - 1).toInt(),
                      onPageChanged: (value) => setState(() => _page = value),
                    )
                  : _AutomaticNewsMediaFallback(hasVideo: hasVideo),
            ),
            if (images.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (var index = 0; index < images.length; index++) ...[
                _PreviewLinkInfoBlock(
                  label: images.length == 1 ? 'Medya Linki' : 'Resim ${index + 1} Linki',
                  value: images[index],
                ),
                if (index != images.length - 1) const SizedBox(height: 8),
              ],
            ],
            if (widget.draft.sourceUrl.isNotEmpty) ...[
              const SizedBox(height: 10),
              _PreviewLinkInfoBlock(label: 'Haberin Tam Linki', value: widget.draft.sourceUrl),
            ],
            const SizedBox(height: 10),
            _AutomaticNewsPreviewMetaGrid(draft: widget.draft),
          ],
        );
      },
    );
  }
}

class _AutomaticNewsImageSlider extends StatelessWidget {
  const _AutomaticNewsImageSlider({
    required this.draft,
    required this.images,
    required this.imageRequestHeaders,
    required this.compact,
    required this.hasVideo,
    required this.page,
    required this.onPageChanged,
  });

  final _AutomaticNewsDraft draft;
  final List<String> images;
  final Map<String, String> imageRequestHeaders;
  final bool compact;
  final bool hasVideo;
  final int page;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          itemCount: images.length,
          onPageChanged: onPageChanged,
          itemBuilder: (context, index) {
            final image = images[index];
            final usePrimaryProxy = image.replaceAll(RegExp(r'\\?.*$'), '') ==
                draft.imageUrl.replaceAll(RegExp(r'\\?.*$'), '');
            return AdminCachedImage(
              url: usePrimaryProxy
                  ? _automaticNewsImageDisplayUrl(
                      draft,
                      width: compact ? 720 : 920,
                      imageRequestHeaders: imageRequestHeaders,
                    )
                  : adminImageUrl(image, width: compact ? 720 : 920),
              httpHeaders: usePrimaryProxy ? _automaticNewsImageHttpHeaders(imageRequestHeaders) : null,
              fit: BoxFit.contain,
              memCacheWidth: compact ? 720 : 920,
              errorWidget: _AutomaticNewsMediaFallback(hasVideo: hasVideo),
            );
          },
        ),
        if (hasVideo)
          const Align(alignment: Alignment.center, child: _VideoOverlayBadge()),
        if (images.length > 1)
          Positioned(
            right: 10,
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.deepOcean.withValues(alpha: 0.84),
                borderRadius: BorderRadius.circular(AppRadius.value),
              ),
              child: Text(
                '${page + 1}/${images.length}',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
              ),
            ),
          ),
      ],
    );
  }
}

class _AutomaticNewsPreviewMetaGrid extends StatelessWidget {
  const _AutomaticNewsPreviewMetaGrid({required this.draft});
  final _AutomaticNewsDraft draft;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      _PreviewInfoBlock(label: 'Kaynak', value: draft.sourceName),
      _PreviewInfoBlock(label: 'Alındığı Yer', value: draft.origin),
      _PreviewInfoBlock(
        label: 'Gönderi Tarihi',
        value: draft.publishedAt == null ? 'Kaynakta tarih yok' : _formatDateTime(draft.publishedAt!),
      ),
      _PreviewInfoBlock(label: 'Çekim Tarihi', value: _formatDateTime(draft.capturedAt)),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 420;
        final width = twoColumns ? (constraints.maxWidth - 10) / 2 : constraints.maxWidth;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [for (final item in items) SizedBox(width: width, child: item)],
        );
      },
    );
  }
}

List<String> _uniquePreviewUrls(Iterable<String> values) {
  final out = <String>[];
  final seen = <String>{};
  for (final value in values) {
    final clean = value.trim();
    if (clean.isEmpty) continue;
    final key = clean.replaceAll(RegExp(r'\\?.*$'), '');
    if (seen.add(key)) out.add(clean);
  }
  return out;
}

class _PreviewLinkInfoBlock extends StatelessWidget {
  const _PreviewLinkInfoBlock({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line.withValues(alpha: 0.72)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.inkSoft, fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => unawaited(_openPreviewExternalUrl(value)),
              child: Text(
                _readableText(value),
                softWrap: true,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.actionRed,
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.actionRed.withValues(alpha: 0.65),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

`;
  next = `${next.slice(0, mediaStart)}${mediaClass}${next.slice(mediaEnd)}`;
}

next = next.replace(/        const SizedBox\(height: 18\),\n        _PreviewInfoBlock\(label: 'Kaynak'[\s\S]*?        _PreviewInfoBlock\(\n          label: 'Çekim Tarihi',[\s\S]*?\n        \),\n/, '');

fs.writeFileSync(file, next);
console.log('Applied automatic news modal gallery patch.');
