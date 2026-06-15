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
import 'package:pateeznews_admin/shared/icons/symbols.dart';

const _flipBlockStrongLine = Color(0xFFDDE5E8);
const _flipBlockSoftLine = Color(0xFFE8EEF1);
const _flipBlockMutedText = Color(0xFF5F6F78);
const _flipBlockUploadInk = Color(0xFF6D7B83);
const _flipBlockFrontAccent = AppColors.actionRed;
const _flipBlockBackAccent = AppColors.warmHorizon;
const _flipBlockImageHeight = 220.0;

class ArticleFlipcardBlockEntry {
  ArticleFlipcardBlockEntry()
    : titleController = TextEditingController(),
      frontTitleController = TextEditingController(),
      frontLinkController = TextEditingController(),
      backTitleController = TextEditingController(),
      backLinkController = TextEditingController(),
      sourceController = TextEditingController(),
      frontDescriptionController = quill.QuillController(
        document: adminQuillDocumentFromJson(adminEmptyQuillDeltaJson),
        selection: const TextSelection.collapsed(offset: 0),
      ),
      backDescriptionController = quill.QuillController(
        document: adminQuillDocumentFromJson(adminEmptyQuillDeltaJson),
        selection: const TextSelection.collapsed(offset: 0),
      ),
      descriptionController = quill.QuillController(
        document: adminQuillDocumentFromJson(adminEmptyQuillDeltaJson),
        selection: const TextSelection.collapsed(offset: 0),
      );

  final TextEditingController titleController;
  final TextEditingController frontTitleController;
  final TextEditingController frontLinkController;
  final TextEditingController backTitleController;
  final TextEditingController backLinkController;
  final TextEditingController sourceController;
  final quill.QuillController frontDescriptionController;
  final quill.QuillController backDescriptionController;
  final quill.QuillController descriptionController;
  String? frontImageUrl;
  String? backImageUrl;
  var showOnHomepage = false;
  var extraSettingsExpanded = false;

  void dispose() {
    titleController.dispose();
    frontTitleController.dispose();
    frontLinkController.dispose();
    backTitleController.dispose();
    backLinkController.dispose();
    sourceController.dispose();
    frontDescriptionController.dispose();
    backDescriptionController.dispose();
    descriptionController.dispose();
  }
}

class ArticleFlipcardBlockCard extends StatefulWidget {
  const ArticleFlipcardBlockCard({
    super.key,
    required this.blockTitleController,
    required this.frontTitleController,
    required this.frontLinkController,
    required this.frontDescriptionController,
    required this.backTitleController,
    required this.backLinkController,
    required this.backDescriptionController,
    required this.sourceController,
    required this.descriptionController,
    required this.frontImageUrl,
    required this.backImageUrl,
    required this.blockNumber,
    required this.showOnHomepage,
    required this.extraSettingsExpanded,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onFrontImageChanged,
    required this.onBackImageChanged,
    required this.onShowOnHomepageChanged,
    required this.onToggleExtraSettings,
  });

  final TextEditingController blockTitleController;
  final TextEditingController frontTitleController;
  final TextEditingController frontLinkController;
  final quill.QuillController frontDescriptionController;
  final TextEditingController backTitleController;
  final TextEditingController backLinkController;
  final quill.QuillController backDescriptionController;
  final TextEditingController sourceController;
  final quill.QuillController descriptionController;
  final String? frontImageUrl;
  final String? backImageUrl;
  final int? blockNumber;
  final bool showOnHomepage;
  final bool extraSettingsExpanded;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onDelete;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final ValueChanged<String?> onFrontImageChanged;
  final ValueChanged<String?> onBackImageChanged;
  final ValueChanged<bool> onShowOnHomepageChanged;
  final VoidCallback onToggleExtraSettings;

  @override
  State<ArticleFlipcardBlockCard> createState() =>
      _ArticleFlipcardBlockCardState();
}

class _ArticleFlipcardBlockCardState extends State<ArticleFlipcardBlockCard> {
  var _previewBack = false;

  @override
  void initState() {
    super.initState();
    _addListeners(widget);
  }

  @override
  void didUpdateWidget(covariant ArticleFlipcardBlockCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _removeListeners(oldWidget);
    _addListeners(widget);
  }

  @override
  void dispose() {
    _removeListeners(widget);
    super.dispose();
  }

  void _addListeners(ArticleFlipcardBlockCard target) {
    target.frontTitleController.addListener(_handlePreviewChanged);
    target.frontLinkController.addListener(_handlePreviewChanged);
    target.backTitleController.addListener(_handlePreviewChanged);
    target.backLinkController.addListener(_handlePreviewChanged);
    target.frontDescriptionController.addListener(_handlePreviewChanged);
    target.backDescriptionController.addListener(_handlePreviewChanged);
  }

  void _removeListeners(ArticleFlipcardBlockCard target) {
    target.frontTitleController.removeListener(_handlePreviewChanged);
    target.frontLinkController.removeListener(_handlePreviewChanged);
    target.backTitleController.removeListener(_handlePreviewChanged);
    target.backLinkController.removeListener(_handlePreviewChanged);
    target.frontDescriptionController.removeListener(_handlePreviewChanged);
    target.backDescriptionController.removeListener(_handlePreviewChanged);
  }

  void _handlePreviewChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _pickImage({
    required BuildContext context,
    required bool front,
  }) async {
    final selected = await showMediaLibraryDialog(context);
    final normalized = selected?.trim();
    if (normalized == null || normalized.isEmpty) return;
    if (front) {
      widget.onFrontImageChanged(normalized);
    } else {
      widget.onBackImageChanged(normalized);
    }
  }

  Future<void> _pickUrl({
    required BuildContext context,
    required bool front,
  }) async {
    final selected = await showUrlImageDialog(context);
    final normalized = selected?.trim();
    if (normalized == null || normalized.isEmpty) return;
    if (front) {
      widget.onFrontImageChanged(normalized);
    } else {
      widget.onBackImageChanged(normalized);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _FlipSectionCard(
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
                          color: _flipBlockBackAccent.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(AppRadius.value),
                          border: Border.all(
                            color: _flipBlockBackAccent.withValues(alpha: 0.18),
                          ),
                        ),
                        child: const Icon(
                          Symbols.sync_rounded,
                          color: _flipBlockBackAccent,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.t('newsAdd.flipcardBlock'),
                              style: const TextStyle(
                                color: AppColors.deepOcean,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              context.t('newsAdd.flipcardSubtitle'),
                              style: TextStyle(
                                color: _flipBlockMutedText.withValues(
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
                  Container(height: 1, color: _flipBlockSoftLine),
                  const SizedBox(height: 20),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (widget.blockNumber != null) ...[
                          _BlockNumberBadge(widget.blockNumber!),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: _FlipTextInputBox(
                            controller: widget.blockTitleController,
                            hintTextKey: 'newsAdd.imageBlockTitleHint',
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
                      final frontPanel = _FlipSidePanel(
                        badgeText: '1',
                        accent: _flipBlockFrontAccent,
                        titleKey: 'newsAdd.flipcardFrontSettings',
                        imageLabelKey: 'newsAdd.flipcardFrontImage',
                        imageUrl: widget.frontImageUrl,
                        titleController: widget.frontTitleController,
                        linkController: widget.frontLinkController,
                        descriptionController:
                            widget.frontDescriptionController,
                        titleHintKey: 'newsAdd.flipcardFrontTitleHint',
                        descriptionHintKey:
                            'newsAdd.flipcardFrontDescriptionHint',
                        onPickImage: () =>
                            _pickImage(context: context, front: true),
                        onPickUrl: () =>
                            _pickUrl(context: context, front: true),
                        onClearImage: () => widget.onFrontImageChanged(null),
                      );
                      final backPanel = _FlipSidePanel(
                        badgeText: '2',
                        accent: _flipBlockBackAccent,
                        titleKey: 'newsAdd.flipcardBackSettings',
                        imageLabelKey: 'newsAdd.flipcardBackImage',
                        imageUrl: widget.backImageUrl,
                        titleController: widget.backTitleController,
                        linkController: widget.backLinkController,
                        descriptionController: widget.backDescriptionController,
                        titleHintKey: 'newsAdd.flipcardBackTitleHint',
                        descriptionHintKey:
                            'newsAdd.flipcardBackDescriptionHint',
                        onPickImage: () =>
                            _pickImage(context: context, front: false),
                        onPickUrl: () =>
                            _pickUrl(context: context, front: false),
                        onClearImage: () => widget.onBackImageChanged(null),
                      );

                      if (compact) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            frontPanel,
                            const SizedBox(height: 16),
                            _FlipConnector(compact: true),
                            const SizedBox(height: 16),
                            backPanel,
                          ],
                        );
                      }

                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: frontPanel),
                              const SizedBox(width: 24),
                              Expanded(child: backPanel),
                            ],
                          ),
                          const _FlipConnector(compact: false),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 22),
                  _LivePreviewSection(
                    isBack: _previewBack,
                    onTap: () => setState(() => _previewBack = !_previewBack),
                    frontImageUrl: widget.frontImageUrl,
                    backImageUrl: widget.backImageUrl,
                    frontTitle: widget.frontTitleController.text,
                    backTitle: widget.backTitleController.text,
                    frontDescription: _plainText(
                      widget.frontDescriptionController,
                    ),
                    backDescription: _plainText(
                      widget.backDescriptionController,
                    ),
                  ),
                  _FlipExtraSettingsPanel(
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

class _FlipSidePanel extends StatelessWidget {
  const _FlipSidePanel({
    required this.badgeText,
    required this.accent,
    required this.titleKey,
    required this.imageLabelKey,
    required this.imageUrl,
    required this.titleController,
    required this.linkController,
    required this.descriptionController,
    required this.titleHintKey,
    required this.descriptionHintKey,
    required this.onPickImage,
    required this.onPickUrl,
    required this.onClearImage,
  });

  final String badgeText;
  final Color accent;
  final String titleKey;
  final String imageLabelKey;
  final String? imageUrl;
  final TextEditingController titleController;
  final TextEditingController linkController;
  final quill.QuillController descriptionController;
  final String titleHintKey;
  final String descriptionHintKey;
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
        border: Border.all(color: _flipBlockSoftLine),
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
              Text(
                context.t(titleKey),
                style: const TextStyle(
                  color: AppColors.deepOcean,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _FlipImagePicker(
            imageUrl: imageUrl,
            labelKey: imageLabelKey,
            onPickImage: onPickImage,
            onPickUrl: onPickUrl,
            onClear: onClearImage,
          ),
          const SizedBox(height: 16),
          _FlipTextInputBox(
            controller: titleController,
            hintTextKey: titleHintKey,
            fontSize: 13,
            bold: true,
          ),
          const SizedBox(height: 14),
          _FlipTextInputBox(
            controller: linkController,
            hintTextKey: 'newsAdd.flipcardLinkHint',
            fontSize: 13,
          ),
          const SizedBox(height: 14),
          _FlipRichTextEditor(
            controller: descriptionController,
            placeholder: descriptionHintKey,
            bodyHeight: 140,
            restricted: true,
          ),
        ],
      ),
    );
  }
}

class _FlipImagePicker extends StatelessWidget {
  const _FlipImagePicker({
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
    final selectedUrl = imageUrl?.trim();
    return CustomPaint(
      painter: _DashedBorderPainter(
        color: _flipBlockStrongLine,
        radius: AppRadius.value,
      ),
      child: Container(
        height: _flipBlockImageHeight,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.value),
        ),
        child: selectedUrl == null || selectedUrl.isEmpty
            ? _EmptyFlipImagePicker(
                labelKey: labelKey,
                onPickImage: onPickImage,
                onPickUrl: onPickUrl,
              )
            : _SelectedFlipImage(
                imageUrl: selectedUrl,
                onPickImage: onPickImage,
                onClear: onClear,
              ),
      ),
    );
  }
}

class _EmptyFlipImagePicker extends StatelessWidget {
  const _EmptyFlipImagePicker({
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
            children: [
              const Icon(Symbols.add, color: _flipBlockUploadInk, size: 42),
              const SizedBox(height: 8),
              Text(
                context.t(labelKey),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.deepOcean,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 18),
              _UrlUploadButton(onTap: onPickUrl),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedFlipImage extends StatelessWidget {
  const _SelectedFlipImage({
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
            errorWidget: const Center(
              child: Icon(
                Symbols.broken_image_outlined,
                color: AppColors.iconMuted,
                size: 34,
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

class _LivePreviewSection extends StatelessWidget {
  const _LivePreviewSection({
    required this.isBack,
    required this.onTap,
    required this.frontImageUrl,
    required this.backImageUrl,
    required this.frontTitle,
    required this.backTitle,
    required this.frontDescription,
    required this.backDescription,
  });

  final bool isBack;
  final VoidCallback onTap;
  final String? frontImageUrl;
  final String? backImageUrl;
  final String frontTitle;
  final String backTitle;
  final String frontDescription;
  final String backDescription;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 1, color: _flipBlockSoftLine),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: _flipBlockBackAccent,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Symbols.auto_awesome,
                  color: Colors.white,
                  size: 13,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                context.t('newsAdd.flipcardLivePreview'),
                style: const TextStyle(
                  color: AppColors.deepOcean,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
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
              border: Border.all(color: _flipBlockSoftLine),
            ),
            child: Center(
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onTap,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(
                      begin: isBack ? math.pi : 0,
                      end: isBack ? math.pi : 0,
                    ),
                    duration: const Duration(milliseconds: 420),
                    curve: Curves.easeInOutCubic,
                    builder: (context, angle, child) {
                      final showingBack = angle > math.pi / 2;
                      final displayAngle = showingBack
                          ? angle - math.pi
                          : angle;
                      return Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.001)
                          ..rotateY(displayAngle),
                        child: _FlipPreviewFace(
                          imageUrl: showingBack ? backImageUrl : frontImageUrl,
                          title: showingBack ? backTitle : frontTitle,
                          description: showingBack
                              ? backDescription
                              : frontDescription,
                          titleFallbackKey: showingBack
                              ? 'newsAdd.flipcardBackTitleDefault'
                              : 'newsAdd.flipcardFrontTitleDefault',
                          actionKey: showingBack
                              ? 'newsAdd.flipcardGoBack'
                              : 'newsAdd.flipcardClickToFlip',
                          accent: showingBack
                              ? _flipBlockBackAccent
                              : _flipBlockFrontAccent,
                        ),
                      );
                    },
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

class _FlipPreviewFace extends StatelessWidget {
  const _FlipPreviewFace({
    required this.imageUrl,
    required this.title,
    required this.description,
    required this.titleFallbackKey,
    required this.actionKey,
    required this.accent,
  });

  final String? imageUrl;
  final String title;
  final String description;
  final String titleFallbackKey;
  final String actionKey;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final normalizedImage = imageUrl?.trim();
    final hasImage = normalizedImage != null && normalizedImage.isNotEmpty;
    final resolvedTitle = title.trim().isEmpty
        ? context.t(titleFallbackKey)
        : title.trim();
    final resolvedDescription = description.trim();

    return Container(
      width: 340,
      height: 460,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.deepOcean,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepOcean.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasImage)
            AdminCachedImage(
              url: _resolvedImageUrl(normalizedImage, width: 900),
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              memCacheWidth: 900,
              useOldImageOnUrlChange: true,
              errorWidget: const SizedBox.shrink(),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: hasImage
                    ? [
                        Colors.black.withValues(alpha: 0.14),
                        Colors.black.withValues(alpha: 0.58),
                        Colors.black.withValues(alpha: 0.86),
                      ]
                    : [
                        AppColors.deepOcean,
                        AppColors.deepOcean,
                        const Color(0xFF233241),
                      ],
              ),
            ),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.20),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: const Icon(
                Symbols.sync_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(26, 32, 26, 34),
            child: Column(
              mainAxisAlignment: hasImage
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  resolvedTitle,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    height: 1.12,
                    letterSpacing: 0,
                  ),
                ),
                if (resolvedDescription.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    resolvedDescription,
                    textAlign: TextAlign.center,
                    maxLines: hasImage ? 3 : 6,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.84),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.42,
                      letterSpacing: 0,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Symbols.sync_rounded,
                        size: 13,
                        color: AppColors.deepOcean,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        context.t(actionKey),
                        style: const TextStyle(
                          color: AppColors.deepOcean,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FlipExtraSettingsPanel extends StatelessWidget {
  const _FlipExtraSettingsPanel({
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
                      padding: const EdgeInsets.only(top: 12, bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _FlipTextInputBox(
                            controller: sourceController,
                            hintTextKey: 'newsAdd.flipcardSourceHint',
                            fontSize: 13,
                          ),
                          const SizedBox(height: 12),
                          _FlipRichTextEditor(
                            controller: descriptionController,
                            placeholder: 'newsAdd.flipcardDescriptionHint',
                            bodyHeight: 138,
                            restricted: false,
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
                        color: _flipBlockMutedText.withValues(alpha: 0.72),
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
                      color: _flipBlockMutedText.withValues(alpha: 0.72),
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

class _FlipSectionCard extends StatelessWidget {
  const _FlipSectionCard({required this.child, this.padding});

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
        border: Border.all(color: _flipBlockStrongLine),
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
        border: Border(right: BorderSide(color: _flipBlockSoftLine)),
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

class _FlipConnector extends StatelessWidget {
  const _FlipConnector({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: compact ? 36 : 42,
        height: compact ? 36 : 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: _flipBlockStrongLine),
          boxShadow: [
            BoxShadow(
              color: AppColors.deepOcean.withValues(alpha: 0.08),
              blurRadius: 10,
            ),
          ],
        ),
        child: Icon(
          compact ? Symbols.swap_vert : Symbols.swap_horiz,
          color: AppColors.iconMuted,
          size: 18,
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
            border: Border.all(color: _flipBlockStrongLine),
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
              const Icon(Symbols.public, size: 13, color: AppColors.deepOcean),
              const SizedBox(width: 7),
              Text(
                context.t('newsAdd.flipcardUrlOrUpload'),
                style: const TextStyle(
                  color: AppColors.deepOcean,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3,
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
            border: Border.all(color: _flipBlockStrongLine),
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

class _FlipRichTextEditor extends StatelessWidget {
  const _FlipRichTextEditor({
    required this.controller,
    required this.placeholder,
    required this.bodyHeight,
    required this.restricted,
  });

  final quill.QuillController controller;
  final String placeholder;
  final double bodyHeight;
  final bool restricted;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.value);
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: radius),
      foregroundDecoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: _flipBlockStrongLine),
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
              config: quill.QuillSimpleToolbarConfig(
                toolbarSize: 30,
                toolbarIconAlignment: WrapAlignment.start,
                toolbarIconCrossAlignment: WrapCrossAlignment.center,
                toolbarSectionSpacing: 4,
                toolbarRunSpacing: 2,
                sectionDividerSpace: 8,
                iconTheme: const quill.QuillIconTheme(
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
                showQuote: !restricted,
                showCodeBlock: !restricted,
                showInlineCode: !restricted,
                showLink: !restricted,
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

class _FlipTextInputBox extends StatelessWidget {
  const _FlipTextInputBox({
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
        border: Border.all(color: _flipBlockStrongLine),
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
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      const dash = 6.0;
      const gap = 5.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + dash), paint);
        distance += dash + gap;
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
