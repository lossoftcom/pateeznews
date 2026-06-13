import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

import '../../../../core/localization/admin_language_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../shared/data/media_service.dart';
import '../../../../shared/widgets/admin_cached_image.dart';
import '../../../../shared/widgets/admin_rich_text_editor.dart'
    show adminEmptyQuillDeltaJson, adminQuillDocumentFromJson;
import '../../../../shared/widgets/media_library_dialog.dart';

const _beforeAfterBlockStrongLine = Color(0xFFDDE5E8);
const _beforeAfterBlockSoftLine = Color(0xFFE8EEF1);
const _beforeAfterBlockMutedText = Color(0xFF5F6F78);
const _beforeAfterBlockUploadInk = Color(0xFF6D7B83);
const _beforeAfterBlockBeforeAccent = AppColors.deepOcean;
const _beforeAfterBlockAfterAccent = AppColors.warmHorizon;
const _beforeAfterBlockImageHeight = 220.0;

class ArticleBeforeAfterBlockEntry {
  ArticleBeforeAfterBlockEntry({
    required String beforeLabel,
    required String afterLabel,
  }) : titleController = TextEditingController(),
       beforeLabelController = TextEditingController(text: beforeLabel),
       afterLabelController = TextEditingController(text: afterLabel),
       sourceController = TextEditingController(),
       descriptionController = quill.QuillController(
         document: adminQuillDocumentFromJson(adminEmptyQuillDeltaJson),
         selection: const TextSelection.collapsed(offset: 0),
       );

  final TextEditingController titleController;
  final TextEditingController beforeLabelController;
  final TextEditingController afterLabelController;
  final TextEditingController sourceController;
  final quill.QuillController descriptionController;
  String? beforeImageUrl;
  String? afterImageUrl;
  var showOnHomepage = false;
  var extraSettingsExpanded = false;

  void dispose() {
    titleController.dispose();
    beforeLabelController.dispose();
    afterLabelController.dispose();
    sourceController.dispose();
    descriptionController.dispose();
  }
}

class ArticleBeforeAfterBlockCard extends StatefulWidget {
  const ArticleBeforeAfterBlockCard({
    super.key,
    required this.blockTitleController,
    required this.beforeLabelController,
    required this.afterLabelController,
    required this.sourceController,
    required this.descriptionController,
    required this.beforeImageUrl,
    required this.afterImageUrl,
    required this.blockNumber,
    required this.showOnHomepage,
    required this.extraSettingsExpanded,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onBeforeImageChanged,
    required this.onAfterImageChanged,
    required this.onShowOnHomepageChanged,
    required this.onToggleExtraSettings,
  });

  final TextEditingController blockTitleController;
  final TextEditingController beforeLabelController;
  final TextEditingController afterLabelController;
  final TextEditingController sourceController;
  final quill.QuillController descriptionController;
  final String? beforeImageUrl;
  final String? afterImageUrl;
  final int? blockNumber;
  final bool showOnHomepage;
  final bool extraSettingsExpanded;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onDelete;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final ValueChanged<String?> onBeforeImageChanged;
  final ValueChanged<String?> onAfterImageChanged;
  final ValueChanged<bool> onShowOnHomepageChanged;
  final VoidCallback onToggleExtraSettings;

  @override
  State<ArticleBeforeAfterBlockCard> createState() =>
      _ArticleBeforeAfterBlockCardState();
}

class _ArticleBeforeAfterBlockCardState
    extends State<ArticleBeforeAfterBlockCard> {
  var _sliderPosition = 50.0;

  @override
  void initState() {
    super.initState();
    _addListeners(widget);
  }

  @override
  void didUpdateWidget(covariant ArticleBeforeAfterBlockCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _removeListeners(oldWidget);
    _addListeners(widget);
  }

  @override
  void dispose() {
    _removeListeners(widget);
    super.dispose();
  }

  void _addListeners(ArticleBeforeAfterBlockCard target) {
    target.beforeLabelController.addListener(_handlePreviewChanged);
    target.afterLabelController.addListener(_handlePreviewChanged);
    target.descriptionController.addListener(_handlePreviewChanged);
  }

  void _removeListeners(ArticleBeforeAfterBlockCard target) {
    target.beforeLabelController.removeListener(_handlePreviewChanged);
    target.afterLabelController.removeListener(_handlePreviewChanged);
    target.descriptionController.removeListener(_handlePreviewChanged);
  }

  void _handlePreviewChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _pickImage({
    required BuildContext context,
    required bool before,
  }) async {
    final selected = await showMediaLibraryDialog(context);
    final normalized = selected?.trim();
    if (normalized == null || normalized.isEmpty) return;
    if (before) {
      widget.onBeforeImageChanged(normalized);
    } else {
      widget.onAfterImageChanged(normalized);
    }
  }

  Future<void> _pickUrl({
    required BuildContext context,
    required bool before,
  }) async {
    final selected = await showUrlImageDialog(context);
    final normalized = selected?.trim();
    if (normalized == null || normalized.isEmpty) return;
    if (before) {
      widget.onBeforeImageChanged(normalized);
    } else {
      widget.onAfterImageChanged(normalized);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _BeforeAfterSectionCard(
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
                          color: _beforeAfterBlockAfterAccent.withValues(
                            alpha: 0.08,
                          ),
                          borderRadius: BorderRadius.circular(AppRadius.value),
                          border: Border.all(
                            color: _beforeAfterBlockAfterAccent.withValues(
                              alpha: 0.18,
                            ),
                          ),
                        ),
                        child: const Icon(
                          Icons.compare_arrows_rounded,
                          color: _beforeAfterBlockAfterAccent,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.t('newsAdd.beforeAfterBlock'),
                              style: const TextStyle(
                                color: AppColors.deepOcean,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              context.t('newsAdd.beforeAfterSubtitle'),
                              style: TextStyle(
                                color: _beforeAfterBlockMutedText.withValues(
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
                        value: widget.showOnHomepage,
                        onChanged: widget.onShowOnHomepageChanged,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(height: 1, color: _beforeAfterBlockSoftLine),
                  const SizedBox(height: 20),
                  const _BeforeAfterFieldLabel('newsAdd.imageBlockTitle'),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (widget.blockNumber != null) ...[
                          _BlockNumberBadge(widget.blockNumber!),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: _BeforeAfterTextInputBox(
                            controller: widget.blockTitleController,
                            hintTextKey: 'newsAdd.blockTitleHint',
                            fontSize: 13,
                            bold: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 860;
                      final beforePanel = _BeforeAfterSidePanel(
                        badgeText: '1',
                        accent: _beforeAfterBlockBeforeAccent,
                        titleKey: 'newsAdd.beforeAfterBeforeSettings',
                        imageLabelKey: 'newsAdd.beforeAfterBeforeImage',
                        labelKey: 'newsAdd.beforeAfterBeforeLabel',
                        labelHintKey: 'newsAdd.beforeAfterBeforeLabelHint',
                        imageUrl: widget.beforeImageUrl,
                        labelController: widget.beforeLabelController,
                        onPickImage: () =>
                            _pickImage(context: context, before: true),
                        onPickUrl: () =>
                            _pickUrl(context: context, before: true),
                        onClearImage: () => widget.onBeforeImageChanged(null),
                      );
                      final afterPanel = _BeforeAfterSidePanel(
                        badgeText: '2',
                        accent: _beforeAfterBlockAfterAccent,
                        titleKey: 'newsAdd.beforeAfterAfterSettings',
                        imageLabelKey: 'newsAdd.beforeAfterAfterImage',
                        labelKey: 'newsAdd.beforeAfterAfterLabel',
                        labelHintKey: 'newsAdd.beforeAfterAfterLabelHint',
                        imageUrl: widget.afterImageUrl,
                        labelController: widget.afterLabelController,
                        onPickImage: () =>
                            _pickImage(context: context, before: false),
                        onPickUrl: () =>
                            _pickUrl(context: context, before: false),
                        onClearImage: () => widget.onAfterImageChanged(null),
                      );

                      if (compact) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            beforePanel,
                            const SizedBox(height: 16),
                            afterPanel,
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: beforePanel),
                          const SizedBox(width: 24),
                          Expanded(child: afterPanel),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 22),
                  _BeforeAfterLivePreview(
                    beforeImageUrl: widget.beforeImageUrl,
                    afterImageUrl: widget.afterImageUrl,
                    beforeLabel: widget.beforeLabelController.text,
                    afterLabel: widget.afterLabelController.text,
                    description: _plainText(widget.descriptionController),
                    sliderPosition: _sliderPosition,
                    onSliderChanged: (value) {
                      setState(() => _sliderPosition = value);
                    },
                  ),
                  _BeforeAfterExtraSettingsPanel(
                    expanded: widget.extraSettingsExpanded,
                    sourceController: widget.sourceController,
                    descriptionController: widget.descriptionController,
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

  String _plainText(quill.QuillController controller) {
    return controller.document.toPlainText().trim();
  }
}

class _BeforeAfterSidePanel extends StatelessWidget {
  const _BeforeAfterSidePanel({
    required this.badgeText,
    required this.accent,
    required this.titleKey,
    required this.imageLabelKey,
    required this.labelKey,
    required this.labelHintKey,
    required this.imageUrl,
    required this.labelController,
    required this.onPickImage,
    required this.onPickUrl,
    required this.onClearImage,
  });

  final String badgeText;
  final Color accent;
  final String titleKey;
  final String imageLabelKey;
  final String labelKey;
  final String labelHintKey;
  final String? imageUrl;
  final TextEditingController labelController;
  final VoidCallback onPickImage;
  final VoidCallback onPickUrl;
  final VoidCallback onClearImage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: _beforeAfterBlockSoftLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(AppRadius.value),
                ),
                child: Text(
                  badgeText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.t(titleKey),
                  style: const TextStyle(
                    color: AppColors.deepOcean,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _BeforeAfterImagePicker(
            imageUrl: imageUrl,
            labelKey: imageLabelKey,
            onPickImage: onPickImage,
            onPickUrl: onPickUrl,
            onClear: onClearImage,
          ),
          const SizedBox(height: 16),
          _BeforeAfterFieldLabel(labelKey, icon: Icons.title),
          _BeforeAfterTextInputBox(
            controller: labelController,
            hintTextKey: labelHintKey,
            fontSize: 13,
            bold: true,
          ),
        ],
      ),
    );
  }
}

class _BeforeAfterImagePicker extends StatelessWidget {
  const _BeforeAfterImagePicker({
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
        color: _beforeAfterBlockStrongLine,
        radius: AppRadius.value,
      ),
      child: Container(
        height: _beforeAfterBlockImageHeight,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.value),
        ),
        child: imageUrl == null
            ? _EmptyBeforeAfterImagePicker(
                labelKey: labelKey,
                onPickImage: onPickImage,
                onPickUrl: onPickUrl,
              )
            : _SelectedBeforeAfterImage(
                imageUrl: imageUrl!,
                onPickImage: onPickImage,
                onClear: onClear,
              ),
      ),
    );
  }
}

class _EmptyBeforeAfterImagePicker extends StatelessWidget {
  const _EmptyBeforeAfterImagePicker({
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
              const Icon(
                Icons.add,
                color: _beforeAfterBlockUploadInk,
                size: 36,
              ),
              const SizedBox(height: 8),
              Text(
                context.t(labelKey),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.deepOcean,
                  fontSize: 13,
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

class _SelectedBeforeAfterImage extends StatelessWidget {
  const _SelectedBeforeAfterImage({
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
                context.t('newsAdd.beforeAfterImageError'),
                style: const TextStyle(
                  color: _beforeAfterBlockMutedText,
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
                icon: Icons.edit_outlined,
                color: AppColors.deepOcean,
                onTap: onPickImage,
              ),
              const SizedBox(width: 8),
              _ImageActionButton(
                icon: Icons.delete_outline,
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

class _BeforeAfterLivePreview extends StatelessWidget {
  const _BeforeAfterLivePreview({
    required this.beforeImageUrl,
    required this.afterImageUrl,
    required this.beforeLabel,
    required this.afterLabel,
    required this.description,
    required this.sliderPosition,
    required this.onSliderChanged,
  });

  final String? beforeImageUrl;
  final String? afterImageUrl;
  final String beforeLabel;
  final String afterLabel;
  final String description;
  final double sliderPosition;
  final ValueChanged<double> onSliderChanged;

  @override
  Widget build(BuildContext context) {
    final resolvedBeforeLabel = beforeLabel.trim().isEmpty
        ? context.t('newsAdd.beforeAfterBeforeDefault')
        : beforeLabel.trim();
    final resolvedAfterLabel = afterLabel.trim().isEmpty
        ? context.t('newsAdd.beforeAfterAfterDefault')
        : afterLabel.trim();

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 1, color: _beforeAfterBlockSoftLine),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: _beforeAfterBlockAfterAccent,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 13,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                context.t('newsAdd.beforeAfterLivePreview'),
                style: const TextStyle(
                  color: AppColors.deepOcean,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(AppRadius.value),
              border: Border.all(color: _beforeAfterBlockSoftLine),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 670),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (description.trim().isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 16),
                        child: Text(
                          context.t('newsAdd.beforeAfterPreviewEmpty'),
                          style: TextStyle(
                            color: _beforeAfterBlockMutedText.withValues(
                              alpha: 0.82,
                            ),
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0,
                          ),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 16),
                        child: Text(
                          description.trim(),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.deepOcean.withValues(alpha: 0.74),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            height: 1.45,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final width = math.min(constraints.maxWidth, 670.0);
                        final height = width < 520 ? 320.0 : 448.0;
                        final safeSliderPosition = sliderPosition
                            .clamp(0.0, 100.0)
                            .toDouble();
                        final lineX = width * safeSliderPosition / 100;
                        final dividerLeft = (lineX - 1)
                            .clamp(0.0, math.max(0.0, width - 2))
                            .toDouble();
                        final handleLeft = (lineX - 20)
                            .clamp(0.0, math.max(0.0, width - 40))
                            .toDouble();

                        void updateSlider(Offset localPosition) {
                          final next = (localPosition.dx / width * 100)
                              .clamp(0.0, 100.0)
                              .toDouble();
                          onSliderChanged(next);
                        }

                        return Center(
                          child: SizedBox(
                            width: width,
                            height: height,
                            child: MouseRegion(
                              cursor: SystemMouseCursors.resizeLeftRight,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTapDown: (details) =>
                                    updateSlider(details.localPosition),
                                onHorizontalDragUpdate: (details) =>
                                    updateSlider(details.localPosition),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.value,
                                  ),
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      border: Border.all(
                                        color: _beforeAfterBlockSoftLine,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.deepOcean.withValues(
                                            alpha: 0.12,
                                          ),
                                          blurRadius: 24,
                                          offset: const Offset(0, 12),
                                        ),
                                      ],
                                    ),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        _PreviewImageLayer(
                                          imageUrl: afterImageUrl,
                                          placeholderIcon: Icons.image_outlined,
                                        ),
                                        if ((beforeImageUrl ?? '')
                                            .trim()
                                            .isNotEmpty)
                                          ClipPath(
                                            clipper: _BeforeAfterClipper(
                                              fraction:
                                                  safeSliderPosition / 100,
                                            ),
                                            child: _PreviewImageLayer(
                                              imageUrl: beforeImageUrl,
                                              placeholderIcon:
                                                  Icons.image_outlined,
                                            ),
                                          ),
                                        Positioned(
                                          left: dividerLeft,
                                          top: 0,
                                          bottom: 0,
                                          child: Container(
                                            width: 2,
                                            color: Colors.white.withValues(
                                              alpha: 0.88,
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          left: handleLeft,
                                          top: (height / 2) - 20,
                                          child: Container(
                                            width: 40,
                                            height: 40,
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.26),
                                                  blurRadius: 16,
                                                  offset: const Offset(0, 6),
                                                ),
                                              ],
                                            ),
                                            child: const Icon(
                                              Icons.compare_arrows_rounded,
                                              color:
                                                  _beforeAfterBlockAfterAccent,
                                              size: 18,
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          top: 24,
                                          left: 0,
                                          right: 0,
                                          child: Center(
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 7,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(
                                                  alpha: 0.30,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      AppRadius.value,
                                                    ),
                                                border: Border.all(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.10),
                                                ),
                                              ),
                                              child: Text(
                                                context.t(
                                                  'newsAdd.beforeAfterCompareHint',
                                                ),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: 0,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        _PreviewLabelBadge(
                                          label: resolvedBeforeLabel,
                                          left: true,
                                          visible: safeSliderPosition >= 10,
                                        ),
                                        _PreviewLabelBadge(
                                          label: resolvedAfterLabel,
                                          left: false,
                                          visible: safeSliderPosition <= 90,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
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

class _PreviewImageLayer extends StatelessWidget {
  const _PreviewImageLayer({
    required this.imageUrl,
    required this.placeholderIcon,
  });

  final String? imageUrl;
  final IconData placeholderIcon;

  @override
  Widget build(BuildContext context) {
    final normalized = imageUrl?.trim();
    if (normalized == null || normalized.isEmpty) {
      return ColoredBox(
        color: const Color(0xFFF3F6F8),
        child: Icon(placeholderIcon, color: const Color(0xFFC3CDD2), size: 58),
      );
    }

    return AdminCachedImage(
      url: _resolvedImageUrl(normalized, width: 1100),
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
      memCacheWidth: 1100,
      useOldImageOnUrlChange: true,
      errorWidget: ColoredBox(
        color: const Color(0xFFF3F6F8),
        child: Icon(placeholderIcon, color: const Color(0xFFC3CDD2), size: 58),
      ),
    );
  }
}

class _BeforeAfterClipper extends CustomClipper<Path> {
  const _BeforeAfterClipper({required this.fraction});

  final double fraction;

  @override
  Path getClip(Size size) {
    final safeFraction = fraction.clamp(0.0, 1.0).toDouble();
    return Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width * safeFraction, size.height));
  }

  @override
  bool shouldReclip(covariant _BeforeAfterClipper oldClipper) =>
      oldClipper.fraction != fraction;
}

class _PreviewLabelBadge extends StatelessWidget {
  const _PreviewLabelBadge({
    required this.label,
    required this.left,
    required this.visible,
  });

  final String label;
  final bool left;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 24,
      left: left ? 24 : null,
      right: left ? null : 24,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 160),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: left
                ? Colors.black.withValues(alpha: 0.42)
                : Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(AppRadius.value),
            border: Border.all(
              color: left
                  ? Colors.white.withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.46),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (left) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.62),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: TextStyle(
                  color: left ? Colors.white : AppColors.deepOcean,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              if (!left) ...[
                const SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: _beforeAfterBlockAfterAccent,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BeforeAfterExtraSettingsPanel extends StatelessWidget {
  const _BeforeAfterExtraSettingsPanel({
    required this.expanded,
    required this.sourceController,
    required this.descriptionController,
    required this.onToggle,
  });

  final bool expanded;
  final TextEditingController sourceController;
  final quill.QuillController descriptionController;
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
                      padding: const EdgeInsets.only(top: 18, bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _BeforeAfterFieldLabel(
                            'newsAdd.beforeAfterSource',
                          ),
                          _BeforeAfterTextInputBox(
                            controller: sourceController,
                            hintTextKey: 'newsAdd.beforeAfterSourceHint',
                            fontSize: 13,
                          ),
                          const SizedBox(height: 16),
                          const _BeforeAfterFieldLabel(
                            'newsAdd.beforeAfterDescription',
                          ),
                          _BeforeAfterRichTextEditor(
                            controller: descriptionController,
                            placeholder: 'newsAdd.beforeAfterDescriptionHint',
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
                        color: _beforeAfterBlockMutedText.withValues(
                          alpha: 0.72,
                        ),
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
                      color: _beforeAfterBlockMutedText.withValues(alpha: 0.72),
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

class _BeforeAfterRichTextEditor extends StatelessWidget {
  const _BeforeAfterRichTextEditor({
    required this.controller,
    required this.placeholder,
  });

  final quill.QuillController controller;
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.value);
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: radius),
      foregroundDecoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: _beforeAfterBlockStrongLine),
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
            height: 138,
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

class _BeforeAfterSectionCard extends StatelessWidget {
  const _BeforeAfterSectionCard({required this.child, this.padding});

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
        border: Border.all(color: _beforeAfterBlockStrongLine),
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
        border: Border(right: BorderSide(color: _beforeAfterBlockSoftLine)),
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.value),
            border: Border.all(color: _beforeAfterBlockStrongLine),
            boxShadow: [
              BoxShadow(
                color: AppColors.deepOcean.withValues(alpha: 0.04),
                blurRadius: 8,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.public, size: 13, color: AppColors.deepOcean),
              const SizedBox(width: 7),
              Text(
                context.t('newsAdd.beforeAfterUrlOrUpload'),
                style: const TextStyle(
                  color: AppColors.deepOcean,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
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
            border: Border.all(color: _beforeAfterBlockStrongLine),
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

class _BeforeAfterTextInputBox extends StatelessWidget {
  const _BeforeAfterTextInputBox({
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
        border: Border.all(color: _beforeAfterBlockStrongLine),
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

class _BeforeAfterFieldLabel extends StatelessWidget {
  const _BeforeAfterFieldLabel(this.text, {this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: _beforeAfterBlockMutedText),
            const SizedBox(width: 6),
          ],
          Text(
            context.t(text),
            style: const TextStyle(
              color: _beforeAfterBlockMutedText,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ],
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
      ..strokeWidth = 1.25
      ..style = PaintingStyle.stroke;
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rect);
    final dashed = _dashPath(path, 7, 4);
    canvas.drawPath(dashed, paint);
  }

  Path _dashPath(Path source, double dashLen, double spaceLen) {
    final dest = Path();
    for (final metric in source.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dashLen;
        dest.addPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          Offset.zero,
        );
        distance = next + spaceLen;
      }
    }
    return dest;
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

String _resolvedImageUrl(String value, {required int width}) {
  if (value.startsWith('http')) return value;
  return MediaService().resolveImageUrl(value, width: width, quality: 90);
}
