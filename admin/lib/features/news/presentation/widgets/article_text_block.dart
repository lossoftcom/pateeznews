import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

import '../../../../core/localization/admin_language_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../shared/widgets/admin_rich_text_editor.dart'
    show adminEmptyQuillDeltaJson, adminQuillDocumentFromJson;

const _articleBlockStrongLine = Color(0xFFDDE5E8);
const _articleBlockSoftLine = Color(0xFFE8EEF1);
const _articleBlockMutedText = Color(0xFF5F6F78);

class ArticleTextBlockEntry {
  ArticleTextBlockEntry()
    : titleController = TextEditingController(),
      sourceController = TextEditingController(),
      editorController = quill.QuillController(
        document: adminQuillDocumentFromJson(adminEmptyQuillDeltaJson),
        selection: const TextSelection.collapsed(offset: 0),
      );

  final TextEditingController titleController;
  final TextEditingController sourceController;
  final quill.QuillController editorController;
  var extraSettingsExpanded = false;

  void dispose() {
    titleController.dispose();
    sourceController.dispose();
    editorController.dispose();
  }
}

class ArticleTextBlockCard extends StatelessWidget {
  const ArticleTextBlockCard({
    super.key,
    required this.blockTitleController,
    required this.editorController,
    required this.sourceController,
    required this.blockNumber,
    required this.extraSettingsExpanded,
    required this.canDelete,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onToggleExtraSettings,
  });

  final TextEditingController blockTitleController;
  final quill.QuillController editorController;
  final TextEditingController sourceController;
  final int? blockNumber;
  final bool extraSettingsExpanded;
  final bool canDelete;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onDelete;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onToggleExtraSettings;

  @override
  Widget build(BuildContext context) {
    return _ArticleSectionCard(
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
                          color: AppColors.actionRed.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(AppRadius.value),
                        ),
                        child: const Icon(
                          Icons.text_fields,
                          color: AppColors.actionRed,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          context.t('newsAdd.textBlock'),
                          style: const TextStyle(
                            color: AppColors.deepOcean,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (blockNumber != null) ...[
                          _BlockNumberBadge(blockNumber!),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: _ArticleTextInputBox(
                            controller: blockTitleController,
                            hintTextKey: 'newsAdd.blockTitleHint',
                            fontSize: 13,
                            bold: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const _ArticleFieldLabel('newsAdd.contentLabel'),
                  ArticleRichTextEditor(
                    controller: editorController,
                    placeholder: 'newsAdd.contentHint',
                    minHeight: 360,
                  ),
                  _ExtraSettingsPanel(
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
              canDelete: canDelete,
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

class _ArticleSectionCard extends StatelessWidget {
  const _ArticleSectionCard({required this.child, this.padding});

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
        border: Border.all(color: _articleBlockStrongLine),
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

class _BlockActionRail extends StatelessWidget {
  const _BlockActionRail({
    required this.canDelete,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final bool canDelete;
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
        border: Border(right: BorderSide(color: _articleBlockSoftLine)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          _RailIconButton(
            icon: Icons.keyboard_arrow_up,
            active: canMoveUp,
            onTap: onMoveUp,
          ),
          const SizedBox(height: 8),
          _RailIconButton(
            icon: Icons.keyboard_arrow_down,
            active: canMoveDown,
            onTap: onMoveDown,
          ),
          const Spacer(),
          _RailIconButton(
            icon: Icons.delete_outline,
            active: canDelete,
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

class _ExtraSettingsPanel extends StatelessWidget {
  const _ExtraSettingsPanel({
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
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _ArticleTextInputBox(
                        controller: sourceController,
                        hintTextKey: 'stories.field.sourceName',
                        fontSize: 13,
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
                        color: _articleBlockMutedText.withValues(alpha: 0.72),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      expanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 16,
                      color: _articleBlockMutedText.withValues(alpha: 0.72),
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

class _ArticleTextInputBox extends StatelessWidget {
  const _ArticleTextInputBox({
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
        border: Border.all(color: _articleBlockStrongLine),
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

class _ArticleFieldLabel extends StatelessWidget {
  const _ArticleFieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(
        context.t(text),
        style: const TextStyle(
          color: _articleBlockMutedText,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class ArticleRichTextEditor extends StatelessWidget {
  const ArticleRichTextEditor({
    super.key,
    required this.controller,
    required this.placeholder,
    this.minHeight = 360,
  });

  final quill.QuillController controller;
  final String placeholder;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.value);
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: radius),
      foregroundDecoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: _articleBlockStrongLine),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: _articleBlockSoftLine)),
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
                showListCheck: true,
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
            height: minHeight,
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
