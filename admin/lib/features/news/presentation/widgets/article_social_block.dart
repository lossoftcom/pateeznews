import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../core/localization/admin_language_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../shared/widgets/admin_rich_text_editor.dart'
    show adminEmptyQuillDeltaJson, adminQuillDocumentFromJson;
import 'package:pateeznews_admin/shared/icons/symbols.dart';

const _socialBlockStrongLine = Color(0xFFDDE5E8);
const _socialBlockSoftLine = Color(0xFFE8EEF1);
const _socialBlockMutedText = Color(0xFF5F6F78);
const _socialEmbedPreviewHeight = 620.0;
const _socialEmbedMaxWidth = 552;

class ArticleSocialBlockEntry {
  ArticleSocialBlockEntry()
    : titleController = TextEditingController(),
      embedController = TextEditingController(),
      sourceController = TextEditingController(),
      contentController = quill.QuillController(
        document: adminQuillDocumentFromJson(adminEmptyQuillDeltaJson),
        selection: const TextSelection.collapsed(offset: 0),
      );

  final TextEditingController titleController;
  final TextEditingController embedController;
  final TextEditingController sourceController;
  final quill.QuillController contentController;
  var showOnHomepage = false;
  var extraSettingsExpanded = false;

  void dispose() {
    titleController.dispose();
    embedController.dispose();
    sourceController.dispose();
    contentController.dispose();
  }
}

class ArticleSocialBlockCard extends StatefulWidget {
  const ArticleSocialBlockCard({
    super.key,
    required this.blockTitleController,
    required this.embedController,
    required this.sourceController,
    required this.contentController,
    required this.blockNumber,
    required this.showOnHomepage,
    required this.extraSettingsExpanded,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onShowOnHomepageChanged,
    required this.onToggleExtraSettings,
  });

  final TextEditingController blockTitleController;
  final TextEditingController embedController;
  final TextEditingController sourceController;
  final quill.QuillController contentController;
  final int? blockNumber;
  final bool showOnHomepage;
  final bool extraSettingsExpanded;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onDelete;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final ValueChanged<bool> onShowOnHomepageChanged;
  final VoidCallback onToggleExtraSettings;

  @override
  State<ArticleSocialBlockCard> createState() => _ArticleSocialBlockCardState();
}

class _ArticleSocialBlockCardState extends State<ArticleSocialBlockCard> {
  @override
  void initState() {
    super.initState();
    widget.embedController.addListener(_handleEmbedChanged);
  }

  @override
  void didUpdateWidget(covariant ArticleSocialBlockCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.embedController != widget.embedController) {
      oldWidget.embedController.removeListener(_handleEmbedChanged);
      widget.embedController.addListener(_handleEmbedChanged);
    }
  }

  @override
  void dispose() {
    widget.embedController.removeListener(_handleEmbedChanged);
    super.dispose();
  }

  void _handleEmbedChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return _SocialSectionCard(
      padding: EdgeInsets.zero,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 58),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.deepOcean.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(AppRadius.value),
                        ),
                        child: const Icon(
                          Symbols.share_outlined,
                          color: AppColors.deepOcean,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          context.t('newsAdd.socialBlock'),
                          style: const TextStyle(
                            color: AppColors.deepOcean,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      _HomepageToggle(
                        value: widget.showOnHomepage,
                        onChanged: widget.onShowOnHomepageChanged,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (widget.blockNumber != null) ...[
                          _BlockNumberBadge(widget.blockNumber!),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: _SocialTextInputBox(
                            controller: widget.blockTitleController,
                            hintTextKey: 'newsAdd.blockTitleHint',
                            fontSize: 13,
                            bold: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 760;
                      final embedInput = _EmbedInputPanel(
                        controller: widget.embedController,
                      );
                      final preview = _SocialPreviewPanel(
                        embedValue: widget.embedController.text,
                      );

                      if (compact) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            embedInput,
                            const SizedBox(height: 16),
                            preview,
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: embedInput),
                          const SizedBox(width: 24),
                          Expanded(child: preview),
                        ],
                      );
                    },
                  ),
                  _ExtraSettingsPanel(
                    expanded: widget.extraSettingsExpanded,
                    sourceController: widget.sourceController,
                    contentController: widget.contentController,
                    onToggle: widget.onToggleExtraSettings,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: _BlockActionRail(
              canMoveUp: widget.canMoveUp,
              canMoveDown: widget.canMoveDown,
              onDelete: widget.onDelete,
              onMoveUp: widget.onMoveUp,
              onMoveDown: widget.onMoveDown,
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialSectionCard extends StatelessWidget {
  const _SocialSectionCard({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.fromLTRB(24, 22, 24, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: _socialBlockStrongLine),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepOcean.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _HomepageToggle extends StatelessWidget {
  const _HomepageToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MiniSwitch(value: value, onChanged: onChanged),
        const SizedBox(width: 10),
        Text(
          context.t('newsAdd.showOnHomepage'),
          style: const TextStyle(
            color: AppColors.deepOcean,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

class _MiniSwitch extends StatelessWidget {
  const _MiniSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 34,
          height: 18,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: value ? AppColors.deepOcean : AppColors.softLine,
            borderRadius: BorderRadius.circular(999),
          ),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BlockActionRail extends StatelessWidget {
  const _BlockActionRail({
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onDelete;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: _socialBlockSoftLine)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          _RailIconButton(
            icon: Symbols.keyboard_arrow_up,
            active: canMoveUp,
            onTap: onMoveUp,
          ),
          const SizedBox(height: 8),
          _RailIconButton(
            icon: Symbols.keyboard_arrow_down,
            active: canMoveDown,
            onTap: onMoveDown,
          ),
          const Spacer(),
          _RailIconButton(
            icon: Symbols.delete_outline,
            active: true,
            activeColor: AppColors.actionRed,
            onTap: onDelete,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _RailIconButton extends StatelessWidget {
  const _RailIconButton({
    required this.icon,
    required this.active,
    required this.onTap,
    this.activeColor = AppColors.deepOcean,
  });

  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    final color = active
        ? activeColor
        : AppColors.iconMuted.withValues(alpha: 0.38);
    return MouseRegion(
      cursor: active ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: active ? onTap : null,
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active
                ? activeColor.withValues(alpha: 0.06)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.value),
            border: Border.all(
              color: active
                  ? activeColor.withValues(alpha: 0.16)
                  : Colors.transparent,
            ),
          ),
          child: Icon(icon, size: 22, color: color),
        ),
      ),
    );
  }
}

class _BlockNumberBadge extends StatelessWidget {
  const _BlockNumberBadge(this.number);

  final int number;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.deepOcean,
        borderRadius: BorderRadius.circular(AppRadius.value),
      ),
      child: Text(
        '$number',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _EmbedInputPanel extends StatelessWidget {
  const _EmbedInputPanel({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _socialEmbedPreviewHeight,
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: _socialBlockStrongLine),
      ),
      child: TextField(
        controller: controller,
        expands: true,
        maxLines: null,
        minLines: null,
        textAlignVertical: TextAlignVertical.top,
        cursorColor: AppColors.deepOcean,
        style: const TextStyle(
          color: AppColors.deepOcean,
          fontFamily: 'monospace',
          fontSize: 12,
          height: 1.45,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        decoration: InputDecoration(
          hintText: context.t('newsAdd.socialPlaceholder'),
          hintStyle: TextStyle(
            color: AppColors.placeholder.withValues(alpha: 0.74),
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }
}

class _SocialPreviewPanel extends StatelessWidget {
  const _SocialPreviewPanel({required this.embedValue});

  final String embedValue;

  @override
  Widget build(BuildContext context) {
    final info = _detectSocialEmbed(embedValue);
    final canRenderHtml =
        info != null &&
        _supportsInlineSocialWebView &&
        _canRenderSocialEmbedHtml(embedValue);
    return CustomPaint(
      painter: _DotPatternPainter(),
      child: Container(
        height: _socialEmbedPreviewHeight,
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(AppRadius.value),
          border: Border.all(color: _socialBlockStrongLine),
        ),
        child: info == null
            ? const _EmptySocialPreview()
            : canRenderHtml
            ? _SocialEmbedWebPreview(embedValue: embedValue)
            : _DetectedSocialPreview(info: info),
      ),
    );
  }
}

class _SocialEmbedWebPreview extends StatefulWidget {
  const _SocialEmbedWebPreview({required this.embedValue});

  final String embedValue;

  @override
  State<_SocialEmbedWebPreview> createState() => _SocialEmbedWebPreviewState();
}

class _SocialEmbedWebPreviewState extends State<_SocialEmbedWebPreview> {
  late final WebViewController _controller;
  var _loading = true;
  var _configured = false;
  Timer? _loadingFallbackTimer;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController();
    _configureAndLoad();
  }

  @override
  void didUpdateWidget(covariant _SocialEmbedWebPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.embedValue != widget.embedValue) {
      _loadCurrentEmbed();
    }
  }

  @override
  void dispose() {
    _loadingFallbackTimer?.cancel();
    super.dispose();
  }

  Future<void> _configureAndLoad() async {
    try {
      await _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await _controller.setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            _loadingFallbackTimer?.cancel();
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (_) {
            _loadingFallbackTimer?.cancel();
            if (mounted) setState(() => _loading = false);
          },
        ),
      );
      _configured = true;
      await _loadCurrentEmbed();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadCurrentEmbed() async {
    if (!_configured) return;
    _loadingFallbackTimer?.cancel();
    if (mounted) setState(() => _loading = true);
    _loadingFallbackTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _loading = false);
    });
    try {
      await _controller.loadHtmlString(
        _buildSocialEmbedHtml(widget.embedValue),
      );
    } catch (_) {
      _loadingFallbackTimer?.cancel();
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.value),
      child: Stack(
        children: [
          Positioned.fill(child: WebViewWidget(controller: _controller)),
          if (_loading)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.72),
                ),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.deepOcean.withValues(alpha: 0.72),
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

class _EmptySocialPreview extends StatelessWidget {
  const _EmptySocialPreview();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Symbols.public_rounded,
            color: AppColors.deepOcean.withValues(alpha: 0.34),
            size: 48,
          ),
          const SizedBox(height: 8),
          Text(
            context.t('newsAdd.socialPreview'),
            style: TextStyle(
              color: AppColors.deepOcean.withValues(alpha: 0.34),
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetectedSocialPreview extends StatelessWidget {
  const _DetectedSocialPreview({required this.info});

  final _SocialEmbedInfo info;

  @override
  Widget build(BuildContext context) {
    final previewText = info.previewText.trim();
    final displayText = previewText.isNotEmpty ? previewText : info.sourceUrl;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.value),
            border: Border.all(color: _socialBlockStrongLine),
            boxShadow: [
              BoxShadow(
                color: AppColors.deepOcean.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Text(
            displayText,
            maxLines: 10,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.deepOcean,
              fontSize: 14,
              height: 1.42,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
        ),
      ),
    );
  }
}

class _ExtraSettingsPanel extends StatelessWidget {
  const _ExtraSettingsPanel({
    required this.expanded,
    required this.sourceController,
    required this.contentController,
    required this.onToggle,
  });

  final bool expanded;
  final TextEditingController sourceController;
  final quill.QuillController contentController;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRect(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: expanded
                  ? Padding(
                      padding: const EdgeInsets.only(top: 14, bottom: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _SocialTextInputBox(
                            controller: sourceController,
                            hintTextKey: 'stories.field.sourceName',
                            fontSize: 13,
                          ),
                          const SizedBox(height: 12),
                          _SocialRichTextEditor(
                            controller: contentController,
                            placeholder: 'newsAdd.socialContentHint',
                            bodyHeight: 180,
                          ),
                        ],
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onToggle,
              child: SizedBox(
                height: 24,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.t(
                        expanded
                            ? 'newsAdd.lessDetails'
                            : 'newsAdd.moreDetails',
                      ),
                      style: TextStyle(
                        color: _socialBlockMutedText.withValues(alpha: 0.72),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      expanded
                          ? Symbols.keyboard_arrow_up
                          : Symbols.keyboard_arrow_down,
                      size: 16,
                      color: _socialBlockMutedText.withValues(alpha: 0.72),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialRichTextEditor extends StatelessWidget {
  const _SocialRichTextEditor({
    required this.controller,
    required this.placeholder,
    required this.bodyHeight,
  });

  final quill.QuillController controller;
  final String placeholder;
  final double bodyHeight;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.value);
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: radius),
      foregroundDecoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: _socialBlockStrongLine),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: _socialBlockSoftLine)),
            ),
            child: quill.QuillSimpleToolbar(
              controller: controller,
              config: const quill.QuillSimpleToolbarConfig(
                toolbarIconAlignment: WrapAlignment.start,
                toolbarIconCrossAlignment: WrapCrossAlignment.center,
                multiRowsDisplay: true,
                showFontFamily: true,
                showFontSize: true,
                showBoldButton: true,
                showItalicButton: true,
                showSmallButton: true,
                showUnderLineButton: true,
                showLineHeightButton: true,
                showStrikeThrough: true,
                showInlineCode: true,
                showColorButton: true,
                showBackgroundColorButton: true,
                showClearFormat: true,
                showHeaderStyle: true,
                showAlignmentButtons: true,
                showLeftAlignment: true,
                showCenterAlignment: true,
                showRightAlignment: true,
                showJustifyAlignment: true,
                showListNumbers: true,
                showListBullets: true,
                showListCheck: false,
                showCodeBlock: true,
                showQuote: true,
                showIndent: true,
                showLink: true,
                showUndo: true,
                showRedo: true,
                showDirection: true,
                showSearchButton: true,
                showSubscript: true,
                showSuperscript: true,
              ),
            ),
          ),
          SizedBox(
            height: bodyHeight,
            child: ColoredBox(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: quill.QuillEditor.basic(
                  controller: controller,
                  config: quill.QuillEditorConfig(
                    placeholder: context.t(placeholder),
                    padding: EdgeInsets.zero,
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

class _SocialTextInputBox extends StatelessWidget {
  const _SocialTextInputBox({
    required this.controller,
    required this.hintTextKey,
    required this.fontSize,
    this.bold = false,
  });

  final TextEditingController controller;
  final String hintTextKey;
  final double fontSize;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: _socialBlockStrongLine),
      ),
      alignment: Alignment.center,
      child: TextField(
        controller: controller,
        cursorColor: AppColors.deepOcean,
        style: TextStyle(
          color: AppColors.deepOcean,
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          letterSpacing: 0,
        ),
        decoration: InputDecoration(
          hintText: context.t(hintTextKey),
          hintStyle: TextStyle(
            color: AppColors.placeholder,
            fontSize: fontSize,
            fontWeight: bold ? FontWeight.w500 : FontWeight.w400,
            letterSpacing: 0,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          filled: false,
        ),
      ),
    );
  }
}

class _DotPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.support.withValues(alpha: 0.24)
      ..style = PaintingStyle.fill;
    for (var x = 8.0; x < size.width; x += 16) {
      for (var y = 8.0; y < size.height; y += 16) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

enum _SocialPlatform {
  x,
  instagram,
  tiktok,
  facebook,
  pinterest,
  nsosyal,
  iframe,
  link,
  embed,
}

class _SocialEmbedInfo {
  const _SocialEmbedInfo({
    required this.platform,
    required this.sourceUrl,
    required this.modeKey,
    required this.previewText,
  });

  final _SocialPlatform platform;
  final String sourceUrl;
  final String modeKey;
  final String previewText;

  String get hostLabel {
    final uri = Uri.tryParse(sourceUrl);
    final host = uri?.host;
    if (host == null || host.isEmpty) return platformLabel;
    return host.replaceFirst(RegExp(r'^www\.'), '');
  }

  String get platformLabel {
    return switch (platform) {
      _SocialPlatform.x => 'X (Twitter)',
      _SocialPlatform.instagram => 'Instagram',
      _SocialPlatform.tiktok => 'TikTok',
      _SocialPlatform.facebook => 'Facebook',
      _SocialPlatform.pinterest => 'Pinterest',
      _SocialPlatform.nsosyal => 'nSosyal',
      _SocialPlatform.iframe => 'Iframe',
      _SocialPlatform.link => 'Link',
      _SocialPlatform.embed => 'Embed',
    };
  }

  IconData get icon {
    return switch (platform) {
      _SocialPlatform.x => Symbols.close_rounded,
      _SocialPlatform.instagram => Symbols.camera_alt_outlined,
      _SocialPlatform.tiktok => Symbols.music_note_outlined,
      _SocialPlatform.facebook => Symbols.facebook_rounded,
      _SocialPlatform.pinterest => Symbols.push_pin_outlined,
      _SocialPlatform.nsosyal => Symbols.forum_outlined,
      _SocialPlatform.iframe => Symbols.code_rounded,
      _SocialPlatform.link => Symbols.open_in_new_rounded,
      _SocialPlatform.embed => Symbols.public_rounded,
    };
  }

  Color get color {
    return switch (platform) {
      _SocialPlatform.x => Colors.black,
      _SocialPlatform.instagram => const Color(0xFFE1306C),
      _SocialPlatform.tiktok => const Color(0xFF00A6B8),
      _SocialPlatform.facebook => const Color(0xFF1877F2),
      _SocialPlatform.pinterest => const Color(0xFFE60023),
      _SocialPlatform.nsosyal => const Color(0xFF16A085),
      _SocialPlatform.iframe => const Color(0xFF3F51B5),
      _SocialPlatform.link => AppColors.deepOcean,
      _SocialPlatform.embed => AppColors.support,
    };
  }
}

_SocialEmbedInfo? _detectSocialEmbed(String value) {
  final raw = value.trim();
  if (raw.isEmpty) return null;
  final lower = raw.toLowerCase();
  final sourceUrl = _extractSourceUrl(raw);
  final previewText = _extractEmbedPreviewText(raw);
  final modeKey = raw.startsWith('<')
      ? (lower.contains('<iframe')
            ? 'newsAdd.socialModeIframe'
            : 'newsAdd.socialModeEmbed')
      : 'newsAdd.socialModeLink';

  if (lower.contains('twitter.com') ||
      lower.contains('x.com') ||
      lower.contains('twitter-tweet')) {
    return _SocialEmbedInfo(
      platform: _SocialPlatform.x,
      sourceUrl: sourceUrl,
      modeKey: modeKey,
      previewText: previewText,
    );
  }
  if (lower.contains('instagram.com') || lower.contains('instagram-media')) {
    return _SocialEmbedInfo(
      platform: _SocialPlatform.instagram,
      sourceUrl: sourceUrl,
      modeKey: modeKey,
      previewText: previewText,
    );
  }
  if (lower.contains('tiktok.com') || lower.contains('tiktok-embed')) {
    return _SocialEmbedInfo(
      platform: _SocialPlatform.tiktok,
      sourceUrl: sourceUrl,
      modeKey: modeKey,
      previewText: previewText,
    );
  }
  if (lower.contains('facebook.com') || lower.contains('fb-post')) {
    return _SocialEmbedInfo(
      platform: _SocialPlatform.facebook,
      sourceUrl: sourceUrl,
      modeKey: modeKey,
      previewText: previewText,
    );
  }
  if (lower.contains('pinterest.com') ||
      lower.contains('pin.it') ||
      lower.contains('assets.pinterest.com') ||
      lower.contains('data-pin-do')) {
    return _SocialEmbedInfo(
      platform: _SocialPlatform.pinterest,
      sourceUrl: sourceUrl,
      modeKey: modeKey,
      previewText: previewText,
    );
  }
  if (lower.contains('nsosyal.com')) {
    return _SocialEmbedInfo(
      platform: _SocialPlatform.nsosyal,
      sourceUrl: sourceUrl,
      modeKey: modeKey,
      previewText: previewText,
    );
  }
  if (lower.contains('<iframe')) {
    return _SocialEmbedInfo(
      platform: _SocialPlatform.iframe,
      sourceUrl: sourceUrl,
      modeKey: modeKey,
      previewText: previewText,
    );
  }
  final parsedRaw = Uri.tryParse(raw);
  if ((parsedRaw != null && parsedRaw.hasScheme && parsedRaw.host.isNotEmpty) ||
      sourceUrl.isNotEmpty) {
    return _SocialEmbedInfo(
      platform: _SocialPlatform.link,
      sourceUrl: sourceUrl.isNotEmpty ? sourceUrl : raw,
      modeKey: modeKey,
      previewText: previewText,
    );
  }
  if (raw.startsWith('<')) {
    return _SocialEmbedInfo(
      platform: _SocialPlatform.embed,
      sourceUrl: sourceUrl,
      modeKey: modeKey,
      previewText: previewText,
    );
  }
  return _SocialEmbedInfo(
    platform: _SocialPlatform.embed,
    sourceUrl: sourceUrl,
    modeKey: modeKey,
    previewText: previewText,
  );
}

String _extractSourceUrl(String value) {
  final raw = value.trim();
  if (raw.isEmpty) return '';

  final instagram = RegExp(
    r'''data-instgrm-permalink=["']([^"']+)["']''',
    caseSensitive: false,
  ).firstMatch(raw);
  if (instagram != null) return _safeDecode(instagram.group(1) ?? '');

  final href = RegExp(
    r'''href=["'](https?:\/\/[^"'<>]+)["']''',
    caseSensitive: false,
  ).firstMatch(raw);
  if (href != null) return _decodeFacebookPluginUrl(href.group(1) ?? '');

  final src = RegExp(
    r'''src=["'](https?:\/\/[^"'<>]+)["']''',
    caseSensitive: false,
  ).firstMatch(raw);
  if (src != null) return _decodeFacebookPluginUrl(src.group(1) ?? '');

  final url = RegExp(
    r'https?:\/\/[^\s"<>]+',
    caseSensitive: false,
  ).firstMatch(raw);
  if (url != null) return _decodeFacebookPluginUrl(url.group(0) ?? '');

  final parsed = Uri.tryParse(raw);
  if (parsed != null && parsed.hasScheme && parsed.host.isNotEmpty) {
    return raw;
  }

  return '';
}

String _extractEmbedPreviewText(String value) {
  var text = value.trim();
  if (text.isEmpty || !text.contains('<')) return '';

  text = text.replaceAll(
    RegExp(r'<script\b[^>]*>[\s\S]*?<\/script>', caseSensitive: false),
    ' ',
  );
  text = text.replaceAll(
    RegExp(r'<style\b[^>]*>[\s\S]*?<\/style>', caseSensitive: false),
    ' ',
  );
  text = text.replaceAll(RegExp(r'<br\s*\/?>', caseSensitive: false), '\n');
  text = text.replaceAll(
    RegExp(r'<\/(p|div|blockquote|li|h\d)>', caseSensitive: false),
    '\n',
  );
  text = text.replaceAll(RegExp(r'<[^>]+>'), ' ');
  text = _decodeHtmlEntities(text);
  text = text.replaceAll(RegExp(r'[ \t\r\f]+'), ' ');
  text = text.replaceAll(RegExp(r'\n\s+'), '\n');
  text = text.replaceAll(RegExp(r'\n{2,}'), '\n');
  return text.trim();
}

String _decodeHtmlEntities(String value) {
  final named = value
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');

  return named
      .replaceAllMapped(RegExp(r'&#(\d+);'), (match) {
        final code = int.tryParse(match.group(1) ?? '');
        if (code == null) return match.group(0) ?? '';
        return String.fromCharCode(code);
      })
      .replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (match) {
        final code = int.tryParse(match.group(1) ?? '', radix: 16);
        if (code == null) return match.group(0) ?? '';
        return String.fromCharCode(code);
      });
}

String _decodeFacebookPluginUrl(String value) {
  final cleaned = _safeDecode(value).replaceAll('&amp;', '&');
  final uri = Uri.tryParse(cleaned);
  if (uri == null || !uri.host.toLowerCase().contains('facebook.com')) {
    return cleaned;
  }
  if (!uri.path.contains('/plugins/')) return cleaned;
  final href = uri.queryParameters['href'];
  return href == null || href.trim().isEmpty ? cleaned : href.trim();
}

String _safeDecode(String value) {
  try {
    return Uri.decodeComponent(value);
  } catch (_) {
    return value;
  }
}

bool get _supportsInlineSocialWebView {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
}

bool _canRenderSocialEmbedHtml(String value) {
  final raw = value.trim();
  if (raw.isEmpty) return false;
  if (raw.contains('<')) return true;
  final uri = Uri.tryParse(raw);
  return uri != null &&
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.host.isNotEmpty;
}

String _buildSocialEmbedHtml(String value) {
  final markup = _processSocialEmbedMarkup(value);
  return '''
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
  <style>
    html, body {
      margin: 0;
      padding: 0;
      width: 100%;
      height: 100%;
      background: transparent;
      overflow: hidden;
      color-scheme: light;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    }
    * {
      box-sizing: border-box;
    }
    body {
      min-height: 0;
    }
    .preview-stage {
      width: 100vw;
      height: 100vh;
      display: flex;
      justify-content: center;
      align-items: flex-start;
      overflow: hidden;
      padding: 4px 0;
      box-sizing: border-box;
    }
    .embed-root {
      width: ${_socialEmbedMaxWidth}px;
      max-width: ${_socialEmbedMaxWidth}px;
      min-height: 0;
      box-sizing: border-box;
      transform: scale(0.72);
      transform-origin: top center;
    }
    .embed-root > * {
      max-width: 100% !important;
      margin-left: auto !important;
      margin-right: auto !important;
    }
    iframe,
    blockquote,
    .twitter-tweet,
    .instagram-media,
    .tiktok-embed {
      max-width: 100% !important;
      margin-left: auto !important;
      margin-right: auto !important;
    }
    iframe {
      border: 0;
    }
  </style>
</head>
<body>
  <div class="preview-stage">
    <div class="embed-root">$markup</div>
  </div>
  <script>
    (function () {
      function fitPreview() {
        var root = document.querySelector('.embed-root');
        if (!root) return;
        root.style.transform = 'scale(1)';
        var width = Math.max(root.scrollWidth, root.getBoundingClientRect().width, 1);
        var height = Math.max(root.scrollHeight, root.getBoundingClientRect().height, 1);
        var availableWidth = Math.max(window.innerWidth - 8, 1);
        var availableHeight = Math.max(window.innerHeight - 8, 1);
        var scale = Math.min(0.82, availableWidth / width, availableHeight / height);
        scale = Math.max(0.42, scale);
        root.style.transform = 'scale(' + scale + ')';
      }
      function processEmbeds() {
        try { if (window.twttr && window.twttr.widgets) window.twttr.widgets.load(); } catch (e) {}
        try { if (window.instgrm && window.instgrm.Embeds) window.instgrm.Embeds.process(); } catch (e) {}
        try { if (window.FB && window.FB.XFBML) window.FB.XFBML.parse(); } catch (e) {}
        try { if (window.PinUtils && window.PinUtils.build) window.PinUtils.build(); } catch (e) {}
        fitPreview();
      }
      window.addEventListener('load', processEmbeds);
      window.addEventListener('resize', fitPreview);
      setTimeout(fitPreview, 50);
      setTimeout(processEmbeds, 150);
      setTimeout(fitPreview, 450);
      setTimeout(processEmbeds, 800);
      setTimeout(fitPreview, 1200);
      setTimeout(processEmbeds, 1800);
      setTimeout(fitPreview, 2600);
      setTimeout(fitPreview, 4200);
    })();
  </script>
</body>
</html>
''';
}

String _processSocialEmbedMarkup(String value) {
  final raw = value.trim();
  if (raw.isEmpty) return '';

  final rawUri = Uri.tryParse(raw);
  final isRawUrl =
      rawUri != null &&
      (rawUri.scheme == 'http' || rawUri.scheme == 'https') &&
      rawUri.host.isNotEmpty &&
      !raw.contains('<');
  if (isRawUrl) return _embedMarkupFromUrl(raw);

  var processed = raw.replaceAll('src="//', 'src="https://');
  processed = processed.replaceAll("src='//", "src='https://");
  processed = processed.replaceAll('href="//', 'href="https://');
  processed = processed.replaceAll("href='//", "href='https://");

  final lower = processed.toLowerCase();
  if (lower.contains('twitter-tweet') &&
      !lower.contains('platform.twitter.com/widgets.js')) {
    processed +=
        '<script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>';
  }
  if (lower.contains('instagram-media') &&
      !lower.contains('instagram.com/embed.js')) {
    processed +=
        '<script async src="https://www.instagram.com/embed.js"></script>';
  }
  if (lower.contains('tiktok-embed') &&
      !lower.contains('tiktok.com/embed.js')) {
    processed +=
        '<script async src="https://www.tiktok.com/embed.js"></script>';
  }
  if (lower.contains('data-pin-do') &&
      !lower.contains('assets.pinterest.com/js/pinit.js')) {
    processed +=
        '<script async defer src="https://assets.pinterest.com/js/pinit.js"></script>';
  }
  if (lower.contains('fb-post') &&
      !lower.contains('connect.facebook.net') &&
      !lower.contains('facebook.com/plugins/post.php')) {
    processed =
        '<div id="fb-root"></div><script async defer crossorigin="anonymous" src="https://connect.facebook.net/en_US/sdk.js#xfbml=1&version=v24.0"></script>$processed';
  }
  if (lower.contains('nsosyal.com') &&
      !lower.contains('nsosyal.com/embed.js')) {
    processed += '<script async src="https://nsosyal.com/embed.js"></script>';
  }
  return _normalizeIframeEmbedSizing(processed);
}

String _normalizeIframeEmbedSizing(String html) {
  return html.replaceAllMapped(
    RegExp(r'<iframe\b[^>]*>', caseSensitive: false),
    (match) {
      var tag = match.group(0) ?? '';
      if (!RegExp(r'\swidth\s*=', caseSensitive: false).hasMatch(tag)) {
        tag = tag.replaceFirst(
          RegExp(r'<iframe\b', caseSensitive: false),
          '<iframe width="$_socialEmbedMaxWidth"',
        );
      } else {
        tag = tag.replaceAllMapped(
          RegExp(r'''\swidth=(["'])[^"']*\1''', caseSensitive: false),
          (_) => ' width="$_socialEmbedMaxWidth"',
        );
      }
      if (!RegExp(r'\sheight\s*=', caseSensitive: false).hasMatch(tag)) {
        tag = tag.replaceFirst(
          RegExp(r'<iframe\b', caseSensitive: false),
          '<iframe height="600"',
        );
      }
      return tag;
    },
  );
}

String _embedMarkupFromUrl(String url) {
  final escaped = _escapeHtmlAttribute(url);
  final lower = url.toLowerCase();

  if (lower.contains('nsosyal.com')) {
    final baseUrl = url.split('?').first.replaceFirst(RegExp(r'/$'), '');
    final embedUrl = baseUrl.endsWith('/embed') ? baseUrl : '$baseUrl/embed';
    return '''
<iframe src="${_escapeHtmlAttribute(embedUrl)}" width="550" height="600" style="max-width:100%;border:0;border-radius:3px;overflow:hidden;" allowfullscreen="true"></iframe>
<script async src="https://nsosyal.com/embed.js"></script>
''';
  }

  if (lower.contains('twitter.com') || lower.contains('x.com')) {
    return '''
<blockquote class="twitter-tweet" data-width="$_socialEmbedMaxWidth"><a href="$escaped"></a></blockquote>
<script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>
''';
  }

  if (lower.contains('instagram.com')) {
    return '''
<blockquote class="instagram-media" data-instgrm-permalink="$escaped" data-instgrm-version="14" style="background:#fff;border:1px solid #dbdbdb;border-radius:3px;margin:1px;max-width:${_socialEmbedMaxWidth}px;min-width:326px;padding:0;width:calc(100% - 2px);"></blockquote>
<script async src="https://www.instagram.com/embed.js"></script>
''';
  }

  if (lower.contains('tiktok.com')) {
    final videoId = RegExp(
      r'/video/(\d+)',
      caseSensitive: false,
    ).firstMatch(url)?.group(1);
    final userId = RegExp(
      r'tiktok\.com/@([^/?#]+)',
      caseSensitive: false,
    ).firstMatch(url)?.group(1);
    if (videoId != null) {
      return '''
<blockquote class="tiktok-embed" cite="$escaped" data-video-id="${_escapeHtmlAttribute(videoId)}" style="max-width:605px;min-width:325px;"><section><a target="_blank" href="$escaped"></a></section></blockquote>
<script async src="https://www.tiktok.com/embed.js"></script>
''';
    }
    if (userId != null) {
      return '''
<blockquote class="tiktok-embed" cite="$escaped" data-unique-id="${_escapeHtmlAttribute(userId)}" data-embed-type="creator" style="max-width:720px;min-width:288px;"><section><a target="_blank" href="$escaped">@${_escapeHtml(userId)}</a></section></blockquote>
<script async src="https://www.tiktok.com/embed.js"></script>
''';
    }
  }

  if (lower.contains('facebook.com') || lower.contains('fb.watch')) {
    return '''
<div id="fb-root"></div>
<script async defer crossorigin="anonymous" src="https://connect.facebook.net/en_US/sdk.js#xfbml=1&version=v24.0"></script>
<div class="fb-post" data-href="$escaped" data-width="500" data-show-text="true"></div>
''';
  }

  if (lower.contains('pin.it') || lower.contains('pinterest.com')) {
    return '''
<a href="$escaped" data-pin-do="embedPin" data-pin-width="large"></a>
<script async defer src="https://assets.pinterest.com/js/pinit.js"></script>
''';
  }

  return '''
<div style="box-sizing:border-box;width:100%;max-width:360px;padding:18px;border:1px solid #dde5e8;border-radius:4px;background:#fff;text-align:center;">
  <a href="$escaped" target="_blank" rel="noopener noreferrer" style="color:#26394b;font:600 13px -apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;text-decoration:none;word-break:break-all;">$escaped</a>
</div>
''';
}

String _escapeHtml(String value) => const HtmlEscape().convert(value);

String _escapeHtmlAttribute(String value) =>
    const HtmlEscape(HtmlEscapeMode.attribute).convert(value);
