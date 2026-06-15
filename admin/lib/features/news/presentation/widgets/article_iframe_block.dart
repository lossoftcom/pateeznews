import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../core/localization/admin_language_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

const _iframeBlockStrongLine = Color(0xFFDDE5E8);
const _iframeBlockSoftLine = Color(0xFFE8EEF1);
const _iframeBlockMutedText = Color(0xFF5F6F78);

class ArticleIframeBlockEntry {
  ArticleIframeBlockEntry()
    : titleController = TextEditingController(),
      embedController = TextEditingController(),
      sourceController = TextEditingController();

  final TextEditingController titleController;
  final TextEditingController embedController;
  final TextEditingController sourceController;
  var showOnHomepage = false;
  var extraSettingsExpanded = false;

  void dispose() {
    titleController.dispose();
    embedController.dispose();
    sourceController.dispose();
  }
}

class ArticleIframeBlockCard extends StatelessWidget {
  const ArticleIframeBlockCard({
    super.key,
    required this.titleController,
    required this.embedController,
    required this.sourceController,
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

  final TextEditingController titleController;
  final TextEditingController embedController;
  final TextEditingController sourceController;
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
  Widget build(BuildContext context) {
    return _IframeSectionCard(
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
                  _IframeHeader(
                    showOnHomepage: showOnHomepage,
                    onShowOnHomepageChanged: onShowOnHomepageChanged,
                  ),
                  const SizedBox(height: 14),
                  Container(height: 1, color: _iframeBlockSoftLine),
                  const SizedBox(height: 20),
                  const _IframeFieldLabel('newsAdd.iframeTitle'),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (blockNumber != null) ...[
                          _BlockNumberBadge(blockNumber!),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: _IframeTextInputBox(
                            controller: titleController,
                            hintTextKey: 'newsAdd.iframeTitleHint',
                            fontSize: 13,
                            bold: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const _IframeCodeAreaLabel(),
                  _IframeCodeInput(controller: embedController),
                  const SizedBox(height: 12),
                  Text(
                    context.t('newsAdd.iframeHelp'),
                    style: const TextStyle(
                      color: AppColors.deepOcean,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      fontStyle: FontStyle.italic,
                      letterSpacing: 0,
                    ),
                  ),
                  _IframePreviewPanel(embedController: embedController),
                  _IframeExtraSettingsPanel(
                    expanded: extraSettingsExpanded,
                    sourceController: sourceController,
                    onToggle: onToggleExtraSettings,
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
              canMoveUp: canMoveUp,
              canMoveDown: canMoveDown,
              onDelete: onDelete,
              onMoveUp: onMoveUp,
              onMoveDown: onMoveDown,
            ),
          ),
        ],
      ),
    );
  }
}

class _IframeHeader extends StatelessWidget {
  const _IframeHeader({
    required this.showOnHomepage,
    required this.onShowOnHomepageChanged,
  });

  final bool showOnHomepage;
  final ValueChanged<bool> onShowOnHomepageChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(AppRadius.value),
            border: Border.all(color: _iframeBlockStrongLine),
            boxShadow: [
              BoxShadow(
                color: AppColors.deepOcean.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: const Icon(
            Symbols.code_rounded,
            color: AppColors.deepOcean,
            size: 19,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.t('newsAdd.iframeBlock'),
                style: const TextStyle(
                  color: AppColors.deepOcean,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                context.t('newsAdd.iframeSubtitle'),
                style: TextStyle(
                  color: _iframeBlockMutedText.withValues(alpha: 0.76),
                  fontSize: 11.2,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
        _HomepageToggle(
          value: showOnHomepage,
          onChanged: onShowOnHomepageChanged,
        ),
      ],
    );
  }
}

class _IframeCodeAreaLabel extends StatelessWidget {
  const _IframeCodeAreaLabel();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 2),
      child: Row(
        children: [
          const Icon(Symbols.public, size: 14, color: AppColors.deepOcean),
          const SizedBox(width: 10),
          Text(
            context.t('newsAdd.iframeCode'),
            style: const TextStyle(
              color: AppColors.deepOcean,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _IframeCodeInput extends StatelessWidget {
  const _IframeCodeInput({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: _iframeBlockStrongLine),
      ),
      child: Stack(
        children: [
          TextField(
            controller: controller,
            maxLines: null,
            expands: true,
            cursorColor: AppColors.deepOcean,
            style: const TextStyle(
              color: AppColors.deepOcean,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              fontFamily: 'monospace',
              letterSpacing: 0,
            ),
            decoration: InputDecoration(
              hintText: context.t('newsAdd.iframeCodeHint'),
              hintStyle: const TextStyle(
                color: AppColors.placeholder,
                fontSize: 12.5,
                fontWeight: FontWeight.w400,
                letterSpacing: 0,
              ),
              contentPadding: const EdgeInsets.fromLTRB(14, 14, 36, 14),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: Icon(
              Symbols.code_rounded,
              color: _iframeBlockMutedText.withValues(alpha: 0.12),
              size: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _IframePreviewPanel extends StatefulWidget {
  const _IframePreviewPanel({required this.embedController});

  final TextEditingController embedController;

  @override
  State<_IframePreviewPanel> createState() => _IframePreviewPanelState();
}

class _IframePreviewPanelState extends State<_IframePreviewPanel> {
  late WebViewController _webViewController;
  var _lastHtml = '';

  @override
  void initState() {
    super.initState();
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted);
    widget.embedController.addListener(_syncPreview);
    _syncPreview();
  }

  @override
  void didUpdateWidget(covariant _IframePreviewPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.embedController != widget.embedController) {
      oldWidget.embedController.removeListener(_syncPreview);
      widget.embedController.addListener(_syncPreview);
      _syncPreview();
    }
  }

  @override
  void dispose() {
    widget.embedController.removeListener(_syncPreview);
    super.dispose();
  }

  void _syncPreview() {
    final html = widget.embedController.text.trim();
    if (html == _lastHtml) return;
    _lastHtml = html;
    if (html.toLowerCase().contains('<iframe')) {
      _webViewController.loadHtmlString(_iframePreviewHtml(html));
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_lastHtml.toLowerCase().contains('<iframe')) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _IframeFieldLabel('newsAdd.iframePreview'),
          Container(
            height: 220,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.value),
              border: Border.all(color: _iframeBlockStrongLine),
            ),
            child: WebViewWidget(controller: _webViewController),
          ),
        ],
      ),
    );
  }
}

class _IframeExtraSettingsPanel extends StatelessWidget {
  const _IframeExtraSettingsPanel({
    required this.expanded,
    required this.sourceController,
    required this.onToggle,
  });

  final bool expanded;
  final TextEditingController sourceController;
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
                      padding: const EdgeInsets.only(top: 12, bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _IframeTextInputBox(
                            controller: sourceController,
                            hintTextKey: 'newsAdd.iframeSourceHint',
                            fontSize: 13,
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
                        color: _iframeBlockMutedText.withValues(alpha: 0.72),
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
                      color: _iframeBlockMutedText.withValues(alpha: 0.72),
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

String _iframePreviewHtml(String embedHtml) {
  return '''
<!doctype html>
<html>
  <head>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
      html, body {
        margin: 0;
        padding: 0;
        width: 100%;
        min-height: 100%;
        background: #ffffff;
        overflow: auto;
      }
      body {
        display: flex;
        justify-content: center;
        align-items: flex-start;
      }
      iframe {
        max-width: 100%;
      }
    </style>
  </head>
  <body>
    $embedHtml
  </body>
</html>
''';
}

class _IframeTextInputBox extends StatelessWidget {
  const _IframeTextInputBox({
    required this.controller,
    required this.hintTextKey,
    this.bold = false,
    this.fontSize = 14,
  });

  final TextEditingController controller;
  final String hintTextKey;
  final bool bold;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: _iframeBlockStrongLine),
      ),
      child: TextField(
        controller: controller,
        maxLines: 1,
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
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
        ),
      ),
    );
  }
}

class _IframeSectionCard extends StatelessWidget {
  const _IframeSectionCard({required this.child, this.padding});

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
        border: Border.all(color: _iframeBlockStrongLine),
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
        border: Border(right: BorderSide(color: _iframeBlockSoftLine)),
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

class _IframeFieldLabel extends StatelessWidget {
  const _IframeFieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(
        context.t(text),
        style: const TextStyle(
          color: _iframeBlockMutedText,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
