import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

import '../../../../core/localization/admin_language_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../shared/data/media_service.dart';
import '../../../../shared/widgets/admin_cached_image.dart';
import '../../../../shared/widgets/admin_rich_text_editor.dart'
    show adminEmptyQuillDeltaJson, adminQuillDocumentFromJson;
import '../../../../shared/widgets/media_library_dialog.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

const _vsBlockStrongLine = Color(0xFFDDE5E8);
const _vsBlockSoftLine = Color(0xFFE8EEF1);
const _vsBlockMutedText = Color(0xFF5F6F78);
const _vsBlockUploadInk = Color(0xFF6D7B83);
const _vsBlockAccent = AppColors.actionRed;
const _vsBlockImageHeight = 220.0;

class ArticleVsOptionEntry {
  ArticleVsOptionEntry({required String text})
    : textController = TextEditingController(text: text),
      votesController = TextEditingController(text: '0');

  final TextEditingController textController;
  final TextEditingController votesController;
  String? imageUrl;

  void dispose() {
    textController.dispose();
    votesController.dispose();
  }
}

class ArticleVsBlockEntry {
  ArticleVsBlockEntry({required String leftLabel, required String rightLabel})
    : titleController = TextEditingController(),
      sourceController = TextEditingController(),
      descriptionController = quill.QuillController(
        document: adminQuillDocumentFromJson(adminEmptyQuillDeltaJson),
        selection: const TextSelection.collapsed(offset: 0),
      ),
      options = [
        ArticleVsOptionEntry(text: leftLabel),
        ArticleVsOptionEntry(text: rightLabel),
      ];

  final TextEditingController titleController;
  final TextEditingController sourceController;
  final quill.QuillController descriptionController;
  final List<ArticleVsOptionEntry> options;
  String? mainImageUrl;
  var showOnHomepage = false;
  var extraSettingsExpanded = false;

  void dispose() {
    titleController.dispose();
    sourceController.dispose();
    descriptionController.dispose();
    for (final option in options) {
      option.dispose();
    }
  }
}

class ArticleVsBlockCard extends StatelessWidget {
  const ArticleVsBlockCard({
    super.key,
    required this.blockTitleController,
    required this.sourceController,
    required this.descriptionController,
    required this.options,
    required this.mainImageUrl,
    required this.blockNumber,
    required this.showOnHomepage,
    required this.extraSettingsExpanded,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onMainImageChanged,
    required this.onOptionImageChanged,
    required this.onShowOnHomepageChanged,
    required this.onToggleExtraSettings,
  });

  final TextEditingController blockTitleController;
  final TextEditingController sourceController;
  final quill.QuillController descriptionController;
  final List<ArticleVsOptionEntry> options;
  final String? mainImageUrl;
  final int? blockNumber;
  final bool showOnHomepage;
  final bool extraSettingsExpanded;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onDelete;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final ValueChanged<String?> onMainImageChanged;
  final void Function(int index, String? imageUrl) onOptionImageChanged;
  final ValueChanged<bool> onShowOnHomepageChanged;
  final VoidCallback onToggleExtraSettings;

  Future<void> _pickMainImage(BuildContext context) async {
    final selected = await showMediaLibraryDialog(context);
    final normalized = selected?.trim();
    if (normalized == null || normalized.isEmpty) return;
    onMainImageChanged(normalized);
  }

  Future<void> _pickMainUrl(BuildContext context) async {
    final selected = await showUrlImageDialog(context);
    final normalized = selected?.trim();
    if (normalized == null || normalized.isEmpty) return;
    onMainImageChanged(normalized);
  }

  Future<void> _pickOptionImage(BuildContext context, int index) async {
    final selected = await showMediaLibraryDialog(context);
    final normalized = selected?.trim();
    if (normalized == null || normalized.isEmpty) return;
    onOptionImageChanged(index, normalized);
  }

  Future<void> _pickOptionUrl(BuildContext context, int index) async {
    final selected = await showUrlImageDialog(context);
    final normalized = selected?.trim();
    if (normalized == null || normalized.isEmpty) return;
    onOptionImageChanged(index, normalized);
  }

  @override
  Widget build(BuildContext context) {
    return _VsSectionCard(
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
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _vsBlockAccent.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(AppRadius.value),
                          border: Border.all(
                            color: _vsBlockAccent.withValues(alpha: 0.18),
                          ),
                        ),
                        child: const Icon(
                          Symbols.flash_on_outlined,
                          color: _vsBlockAccent,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.t('newsAdd.vsBlock'),
                              style: const TextStyle(
                                color: AppColors.deepOcean,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              context.t('newsAdd.vsSubtitle'),
                              style: TextStyle(
                                color: _vsBlockMutedText.withValues(
                                  alpha: 0.76,
                                ),
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
                  ),
                  const SizedBox(height: 14),
                  Container(height: 1, color: _vsBlockSoftLine),
                  const SizedBox(height: 20),
                  const _VsFieldLabel('newsAdd.vsQuestionTitle'),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (blockNumber != null) ...[
                          _BlockNumberBadge(blockNumber!),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: _VsTextInputBox(
                            controller: blockTitleController,
                            hintTextKey: 'newsAdd.vsQuestionHint',
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
                      final compact = constraints.maxWidth < 860;
                      final mainPanel = _VsMainImagePanel(
                        imageUrl: mainImageUrl,
                        onPickImage: () => _pickMainImage(context),
                        onPickUrl: () => _pickMainUrl(context),
                        onClear: () => onMainImageChanged(null),
                      );
                      final descriptionPanel = _VsDescriptionPanel(
                        controller: descriptionController,
                      );

                      if (compact) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            mainPanel,
                            const SizedBox(height: 16),
                            descriptionPanel,
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 5, child: mainPanel),
                          const SizedBox(width: 24),
                          Expanded(flex: 10, child: descriptionPanel),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  Container(height: 1, color: _vsBlockSoftLine),
                  const SizedBox(height: 18),
                  Center(
                    child: Text(
                      context.t('newsAdd.vsOptions'),
                      style: const TextStyle(
                        color: AppColors.deepOcean,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 780;
                      final leftCard = _VsOptionCard(
                        sideLabelKey: 'newsAdd.vsLeftLabel',
                        option: options[0],
                        imageUrl: options[0].imageUrl,
                        onPickImage: () => _pickOptionImage(context, 0),
                        onPickUrl: () => _pickOptionUrl(context, 0),
                        onClearImage: () => onOptionImageChanged(0, null),
                      );
                      final rightCard = _VsOptionCard(
                        sideLabelKey: 'newsAdd.vsRightLabel',
                        option: options[1],
                        imageUrl: options[1].imageUrl,
                        onPickImage: () => _pickOptionImage(context, 1),
                        onPickUrl: () => _pickOptionUrl(context, 1),
                        onClearImage: () => onOptionImageChanged(1, null),
                      );

                      if (compact) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            leftCard,
                            const SizedBox(height: 14),
                            const Center(child: _VsBadge()),
                            const SizedBox(height: 14),
                            rightCard,
                          ],
                        );
                      }

                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: leftCard),
                              const SizedBox(width: 32),
                              Expanded(child: rightCard),
                            ],
                          ),
                          const Positioned(top: 96, child: _VsBadge()),
                        ],
                      );
                    },
                  ),
                  _VsExtraSettingsPanel(
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

class _VsMainImagePanel extends StatelessWidget {
  const _VsMainImagePanel({
    required this.imageUrl,
    required this.onPickImage,
    required this.onPickUrl,
    required this.onClear,
  });

  final String? imageUrl;
  final VoidCallback onPickImage;
  final VoidCallback onPickUrl;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _VsFieldLabel('newsAdd.vsMainImage'),
        _VsImagePicker(
          imageUrl: imageUrl,
          labelKey: 'newsAdd.vsPickImage',
          onPickImage: onPickImage,
          onPickUrl: onPickUrl,
          onClear: onClear,
        ),
      ],
    );
  }
}

class _VsDescriptionPanel extends StatelessWidget {
  const _VsDescriptionPanel({required this.controller});

  final quill.QuillController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _VsFieldLabel('newsAdd.vsDescription'),
        _VsRichTextEditor(
          controller: controller,
          placeholder: 'newsAdd.vsDescriptionHint',
          bodyHeight: 148,
        ),
      ],
    );
  }
}

class _VsOptionCard extends StatelessWidget {
  const _VsOptionCard({
    required this.sideLabelKey,
    required this.option,
    required this.imageUrl,
    required this.onPickImage,
    required this.onPickUrl,
    required this.onClearImage,
  });

  final String sideLabelKey;
  final ArticleVsOptionEntry option;
  final String? imageUrl;
  final VoidCallback onPickImage;
  final VoidCallback onPickUrl;
  final VoidCallback onClearImage;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: _vsBlockStrongLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _VsImagePicker(
            imageUrl: imageUrl,
            labelKey: 'newsAdd.vsPickImage',
            onPickImage: onPickImage,
            onPickUrl: onPickUrl,
            onClear: onClearImage,
          ),
          Container(height: 1, color: _vsBlockStrongLine),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      context.t(sideLabelKey),
                      style: TextStyle(
                        color: AppColors.deepOcean.withValues(alpha: 0.72),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: option.textController,
                        maxLines: 1,
                        cursorColor: AppColors.deepOcean,
                        style: const TextStyle(
                          color: AppColors.deepOcean,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                        ),
                        decoration: InputDecoration(
                          hintText: context.t('newsAdd.vsOptionHint'),
                          hintStyle: const TextStyle(
                            color: AppColors.placeholder,
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0,
                          ),
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(height: 1, color: _vsBlockSoftLine),
                const SizedBox(height: 10),
                SizedBox(
                  width: 96,
                  child: _VsVotesInput(controller: option.votesController),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VsImagePicker extends StatelessWidget {
  const _VsImagePicker({
    required this.imageUrl,
    required this.labelKey,
    required this.onPickImage,
    required this.onPickUrl,
    required this.onClear,
  });

  final String? imageUrl;
  final String labelKey;
  final VoidCallback onPickImage;
  final VoidCallback onPickUrl;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(
        color: _vsBlockStrongLine,
        radius: AppRadius.value,
      ),
      child: Container(
        height: _vsBlockImageHeight,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.34),
          borderRadius: BorderRadius.circular(AppRadius.value),
        ),
        child: imageUrl == null
            ? _EmptyVsImagePicker(
                labelKey: labelKey,
                onPickImage: onPickImage,
                onPickUrl: onPickUrl,
              )
            : _SelectedVsImage(
                imageUrl: imageUrl!,
                onPickImage: onPickImage,
                onClear: onClear,
              ),
      ),
    );
  }
}

class _EmptyVsImagePicker extends StatelessWidget {
  const _EmptyVsImagePicker({
    required this.labelKey,
    required this.onPickImage,
    required this.onPickUrl,
  });

  final String labelKey;
  final VoidCallback onPickImage;
  final VoidCallback onPickUrl;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPickImage,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Symbols.add, color: _vsBlockUploadInk, size: 36),
              const SizedBox(height: 8),
              Text(
                context.t(labelKey),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.deepOcean,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 24),
              _UrlUploadButton(onTap: onPickUrl),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedVsImage extends StatelessWidget {
  const _SelectedVsImage({
    required this.imageUrl,
    required this.onPickImage,
    required this.onClear,
  });

  final String imageUrl;
  final VoidCallback onPickImage;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: AdminCachedImage(
            url: _resolvedImageUrl(imageUrl, width: 720),
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            memCacheWidth: 720,
            useOldImageOnUrlChange: true,
            errorWidget: Center(
              child: Text(
                context.t('newsAdd.vsImageError'),
                style: const TextStyle(
                  color: _vsBlockMutedText,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Row(
            children: [
              _ImageActionButton(
                icon: Symbols.edit_outlined,
                color: AppColors.deepOcean,
                onTap: onPickImage,
              ),
              const SizedBox(width: 8),
              _ImageActionButton(
                icon: Symbols.delete_outline,
                color: AppColors.actionRed,
                onTap: onClear,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VsVotesInput extends StatelessWidget {
  const _VsVotesInput({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: _vsBlockStrongLine),
      ),
      child: Row(
        children: [
          const SizedBox(width: 10),
          Icon(
            Symbols.group_outlined,
            size: 13,
            color: _vsBlockMutedText.withValues(alpha: 0.62),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: 1,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              cursorColor: AppColors.deepOcean,
              style: const TextStyle(
                color: AppColors.deepOcean,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
              decoration: InputDecoration(
                hintText: context.t('newsAdd.vsVotesHint'),
                hintStyle: const TextStyle(
                  color: AppColors.placeholder,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                ),
                isDense: true,
                contentPadding: const EdgeInsets.only(right: 10, bottom: 1),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VsBadge extends StatelessWidget {
  const _VsBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: _vsBlockStrongLine),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepOcean.withValues(alpha: 0.14),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Container(
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: AppColors.deepOcean,
          shape: BoxShape.circle,
        ),
        child: const Text(
          'VS',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _VsExtraSettingsPanel extends StatelessWidget {
  const _VsExtraSettingsPanel({
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
      padding: const EdgeInsets.only(top: 24),
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
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _VsFieldLabel(
                            'newsAdd.vsSource',
                            icon: Symbols.settings_outlined,
                          ),
                          _VsTextInputBox(
                            controller: sourceController,
                            hintTextKey: 'newsAdd.vsSourceHint',
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
                        color: _vsBlockMutedText.withValues(alpha: 0.72),
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
                      color: _vsBlockMutedText.withValues(alpha: 0.72),
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

class _VsRichTextEditor extends StatelessWidget {
  const _VsRichTextEditor({
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
        border: Border.all(color: _vsBlockStrongLine),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFFBF7F1),
              border: Border(
                bottom: BorderSide(
                  color: const Color(0xFF8C6D53).withValues(alpha: 0.16),
                ),
              ),
            ),
            child: quill.QuillSimpleToolbar(
              controller: controller,
              config: const quill.QuillSimpleToolbarConfig(
                toolbarSize: 30,
                toolbarIconAlignment: WrapAlignment.start,
                toolbarIconCrossAlignment: WrapCrossAlignment.center,
                toolbarSectionSpacing: 4,
                toolbarRunSpacing: 2,
                sectionDividerSpace: 8,
                iconTheme: quill.QuillIconTheme(
                  iconButtonUnselectedData: quill.IconButtonData(
                    iconSize: 17,
                    padding: EdgeInsets.all(2),
                    visualDensity: VisualDensity.compact,
                    constraints: BoxConstraints.tightFor(width: 26, height: 26),
                    color: Color(0xFF8C7A6A),
                  ),
                  iconButtonSelectedData: quill.IconButtonData(
                    iconSize: 17,
                    padding: EdgeInsets.all(2),
                    visualDensity: VisualDensity.compact,
                    constraints: BoxConstraints.tightFor(width: 26, height: 26),
                    color: AppColors.deepOcean,
                  ),
                ),
                multiRowsDisplay: true,
                showFontFamily: false,
                showFontSize: true,
                showBoldButton: true,
                showItalicButton: true,
                showUnderLineButton: true,
                showStrikeThrough: true,
                showColorButton: true,
                showBackgroundColorButton: true,
                showHeaderStyle: true,
                showListNumbers: true,
                showListBullets: true,
                showListCheck: false,
                showQuote: true,
                showCodeBlock: true,
                showInlineCode: true,
                showLink: true,
                showSubscript: false,
                showSuperscript: false,
                showUndo: false,
                showRedo: false,
                showSearchButton: false,
                showAlignmentButtons: false,
                showIndent: false,
                showClearFormat: true,
                showDirection: false,
              ),
            ),
          ),
          SizedBox(
            height: bodyHeight,
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: quill.QuillEditor.basic(
                controller: controller,
                config: quill.QuillEditorConfig(
                  placeholder: context.t(placeholder),
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VsSectionCard extends StatelessWidget {
  const _VsSectionCard({required this.child, this.padding});

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
        border: Border.all(color: _vsBlockStrongLine),
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
        border: Border(right: BorderSide(color: _vsBlockSoftLine)),
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

class _VsTextInputBox extends StatelessWidget {
  const _VsTextInputBox({
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
        border: Border.all(color: _vsBlockStrongLine),
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

class _VsFieldLabel extends StatelessWidget {
  const _VsFieldLabel(this.text, {this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: _vsBlockMutedText),
            const SizedBox(width: 6),
          ],
          Text(
            context.t(text),
            style: const TextStyle(
              color: _vsBlockMutedText,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _UrlUploadButton extends StatelessWidget {
  const _UrlUploadButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.value),
            border: Border.all(color: _vsBlockStrongLine),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Symbols.public, size: 13, color: AppColors.deepOcean),
              const SizedBox(width: 6),
              Text(
                context.t('newsAdd.vsUrlOrUpload'),
                style: const TextStyle(
                  color: AppColors.deepOcean,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImageActionButton extends StatelessWidget {
  const _ImageActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.value),
            border: Border.all(color: _vsBlockStrongLine),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 6,
              ),
            ],
          ),
          child: Icon(icon, size: 15, color: color),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );
    const dashWidth = 6.0;
    const dashSpace = 5.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}

String _resolvedImageUrl(String value, {required int width}) {
  if (value.startsWith('http')) return value;
  return MediaService().resolveImageUrl(value, width: width, quality: 90);
}
