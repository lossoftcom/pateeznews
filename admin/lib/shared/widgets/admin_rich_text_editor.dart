import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart';

import '../../core/localization/admin_language_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';

const adminEmptyQuillDeltaJson = '[{"insert":"\\n"}]';

quill.Document adminQuillDocumentFromJson(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return quill.Document();
  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is List) return quill.Document.fromJson(decoded);
  } catch (_) {
    return quill.Document()..insert(0, trimmed);
  }
  return quill.Document();
}

String adminQuillDeltaJson(quill.QuillController controller) {
  return jsonEncode(controller.document.toDelta().toJson());
}

String adminQuillPlainText(quill.QuillController controller) {
  return controller.document.toPlainText().trim();
}

quill.Document adminQuillDocumentFromStoredHtml(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return adminQuillDocumentFromJson(adminEmptyQuillDeltaJson);
  }
  if (trimmed.startsWith('[')) return adminQuillDocumentFromJson(trimmed);
  try {
    final delta = HtmlToDelta().convert(trimmed);
    return quill.Document.fromDelta(delta);
  } catch (_) {
    return quill.Document()..insert(0, _stripHtmlForQuill(trimmed));
  }
}

void adminSetQuillHtml(quill.QuillController controller, String value) {
  controller.document = adminQuillDocumentFromStoredHtml(value);
  controller.updateSelection(
    const TextSelection.collapsed(offset: 0),
    quill.ChangeSource.local,
  );
}

String adminQuillHtml(quill.QuillController controller) {
  final text = controller.document.toPlainText().trim();
  if (text.isEmpty) return '';
  final ops = controller.document.toDelta().toJson();
  final lines = <_QuillHtmlLine>[];
  final current = StringBuffer();
  Map<String, Object?> lineAttributes = const {};

  void flushLine() {
    lines.add(_QuillHtmlLine(current.toString(), lineAttributes));
    current.clear();
    lineAttributes = const {};
  }

  for (final rawOp in ops) {
    final insert = rawOp['insert'];
    final attributes = _asStringObjectMap(rawOp['attributes']);
    if (insert is Map) {
      final image = insert['image']?.toString().trim();
      if (image != null && image.isNotEmpty) {
        current.write(
          '<img src="${_escapeAttr(image)}" alt="" style="max-width:100%;height:auto;">',
        );
      }
      continue;
    }
    if (insert is! String) continue;
    final parts = insert.split('\n');
    for (var index = 0; index < parts.length; index++) {
      if (parts[index].isNotEmpty) {
        current.write(_inlineHtml(parts[index], attributes));
      }
      if (index != parts.length - 1) {
        lineAttributes = attributes;
        flushLine();
      }
    }
  }
  if (current.isNotEmpty) flushLine();

  final html = StringBuffer();
  String? openListTag;
  String openListStyle = '';

  void closeOpenList() {
    if (openListTag == null) return;
    html.write('</$openListTag>');
    openListTag = null;
    openListStyle = '';
  }

  for (final line in lines) {
    final content = line.content.trim().isEmpty ? '<br>' : line.content;
    final header = line.attributes['header'];
    final list = line.attributes['list']?.toString();
    final blockquote = line.attributes['blockquote'] == true;
    final codeBlock = line.attributes['code-block'] == true;
    final align = line.attributes['align']?.toString();
    final style = align == null || align.isEmpty
        ? ''
        : ' style="text-align:${_escapeAttr(align)}"';

    if (list == 'ordered' || list == 'bullet') {
      final tag = list == 'ordered' ? 'ol' : 'ul';
      if (openListTag != tag || openListStyle != style) {
        closeOpenList();
        html.write('<$tag$style>');
        openListTag = tag;
        openListStyle = style;
      }
      html.write('<li>$content</li>');
    } else if (header == 1 || header == 2 || header == 3) {
      closeOpenList();
      html.write('<h$header$style>$content</h$header>');
    } else if (blockquote) {
      closeOpenList();
      html.write('<blockquote$style>$content</blockquote>');
    } else if (codeBlock) {
      closeOpenList();
      html.write('<pre$style><code>$content</code></pre>');
    } else {
      closeOpenList();
      html.write('<p$style>$content</p>');
    }
  }
  closeOpenList();
  return html.toString();
}

Map<String, Object?> _asStringObjectMap(Object? value) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) {
    return value.map(
      (key, nestedValue) => MapEntry(key.toString(), nestedValue),
    );
  }
  return const {};
}

String _inlineHtml(String value, Map<String, Object?> attributes) {
  var html = _escapeHtml(value);
  if (attributes['code'] == true) html = '<code>$html</code>';
  if (attributes['bold'] == true) html = '<strong>$html</strong>';
  if (attributes['italic'] == true) html = '<em>$html</em>';
  if (attributes['underline'] == true) html = '<u>$html</u>';
  if (attributes['strike'] == true) html = '<s>$html</s>';
  final link = attributes['link']?.toString();
  if (link != null && link.trim().isNotEmpty) {
    html = '<a href="${_escapeAttr(link.trim())}">$html</a>';
  }
  final color = attributes['color']?.toString();
  final background = attributes['background']?.toString();
  final styleParts = <String>[
    if (color != null && color.trim().isNotEmpty)
      'color:${_escapeAttr(color.trim())}',
    if (background != null && background.trim().isNotEmpty)
      'background-color:${_escapeAttr(background.trim())}',
  ];
  if (styleParts.isNotEmpty) {
    html = '<span style="${styleParts.join(';')}">$html</span>';
  }
  return html;
}

String _stripHtmlForQuill(String value) {
  return value
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String _escapeHtml(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}

String _escapeAttr(String value) {
  return _escapeHtml(value).replaceAll('"', '&quot;');
}

const adminQuillEmbedBuilders = <quill.EmbedBuilder>[
  _AdminQuillImageEmbedBuilder(),
];

const adminQuillUnknownEmbedBuilder = _AdminQuillUnknownEmbedBuilder();

class _AdminQuillImageEmbedBuilder extends quill.EmbedBuilder {
  const _AdminQuillImageEmbedBuilder();

  @override
  String get key => 'image';

  @override
  String toPlainText(quill.Embed node) => '[image]';

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    final source = embedContext.node.value.data?.toString().trim() ?? '';
    if (source.isEmpty) return const SizedBox.shrink();

    Widget image;
    if (source.startsWith('data:image/')) {
      try {
        image = Image.memory(
          UriData.parse(source).contentAsBytes(),
          fit: BoxFit.contain,
        );
      } catch (_) {
        image = _AdminQuillEmbedFallback(label: source);
      }
    } else {
      image = Image.network(
        source,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => _AdminQuillEmbedFallback(label: source),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Align(
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 220),
          child: image,
        ),
      ),
    );
  }
}

class _AdminQuillUnknownEmbedBuilder extends quill.EmbedBuilder {
  const _AdminQuillUnknownEmbedBuilder();

  @override
  String get key => 'unknown';

  @override
  String toPlainText(quill.Embed node) => '[${node.value.type}]';

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    return _AdminQuillEmbedFallback(
      label:
          embedContext.node.value.data?.toString() ??
          embedContext.node.value.type,
    );
  }
}

class _AdminQuillEmbedFallback extends StatelessWidget {
  const _AdminQuillEmbedFallback({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.softLine),
      ),
      child: Text(
        label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.support,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _QuillHtmlLine {
  const _QuillHtmlLine(this.content, this.attributes);

  final String content;
  final Map<String, Object?> attributes;
}

class AdminRichTextEditor extends StatefulWidget {
  const AdminRichTextEditor({
    super.key,
    required this.controller,
    required this.editorLabel,
    required this.previewLabel,
    required this.placeholder,
    this.minHeight = 300,
    this.showPreview = true,
  });

  final quill.QuillController controller;
  final String editorLabel;
  final String previewLabel;
  final String placeholder;
  final double minHeight;
  final bool showPreview;

  @override
  State<AdminRichTextEditor> createState() => _AdminRichTextEditorState();
}

class _AdminRichTextEditorState extends State<AdminRichTextEditor> {
  late quill.QuillController _previewController;

  @override
  void initState() {
    super.initState();
    _previewController = _createPreviewController();
    widget.controller.addListener(_syncPreview);
  }

  @override
  void didUpdateWidget(covariant AdminRichTextEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_syncPreview);
      widget.controller.addListener(_syncPreview);
      _previewController.dispose();
      _previewController = _createPreviewController();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncPreview);
    _previewController.dispose();
    super.dispose();
  }

  quill.QuillController _createPreviewController() {
    final controller = quill.QuillController(
      document: quill.Document.fromJson(
        widget.controller.document.toDelta().toJson(),
      ),
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: true,
    );
    return controller;
  }

  void _syncPreview() {
    _previewController.document = quill.Document.fromJson(
      widget.controller.document.toDelta().toJson(),
    );
    _previewController.updateSelection(
      const TextSelection.collapsed(offset: 0),
      quill.ChangeSource.local,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _EditorLabel(widget.editorLabel),
          DecoratedBox(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: AppColors.softLine)),
            ),
            child: quill.QuillSimpleToolbar(
              controller: widget.controller,
              config: const quill.QuillSimpleToolbarConfig(
                multiRowsDisplay: false,
                showFontFamily: false,
                showFontSize: false,
                showInlineCode: false,
                showCodeBlock: false,
                showSubscript: false,
                showSuperscript: false,
                showSearchButton: false,
                showBackgroundColorButton: false,
                showHeaderStyle: true,
                showAlignmentButtons: true,
                showListCheck: false,
              ),
            ),
          ),
          SizedBox(
            height: widget.minHeight,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: quill.QuillEditor.basic(
                controller: widget.controller,
                config: quill.QuillEditorConfig(
                  placeholder: context.t(widget.placeholder),
                  padding: EdgeInsets.zero,
                  embedBuilders: adminQuillEmbedBuilders,
                  unknownEmbedBuilder: adminQuillUnknownEmbedBuilder,
                ),
              ),
            ),
          ),
          if (widget.showPreview) ...[
            Container(height: 1, color: AppColors.softLine),
            _EditorLabel(widget.previewLabel),
            SizedBox(
              height: 170,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: quill.QuillEditor.basic(
                  controller: _previewController,
                  config: const quill.QuillEditorConfig(
                    padding: EdgeInsets.zero,
                    embedBuilders: adminQuillEmbedBuilders,
                    unknownEmbedBuilder: adminQuillUnknownEmbedBuilder,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EditorLabel extends StatelessWidget {
  const _EditorLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Text(
        context.t(label),
        style: const TextStyle(
          color: AppColors.deepOcean,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
