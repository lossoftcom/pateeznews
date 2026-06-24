import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

import '../../../../core/localization/admin_language_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../shared/data/media_service.dart';
import '../../../../shared/widgets/admin_cached_image.dart';
import '../../../../shared/widgets/admin_rich_text_editor.dart'
    show adminEmptyQuillDeltaJson, adminQuillDocumentFromJson;
import '../../../../shared/widgets/media_image_download_button.dart';
import '../../../../shared/widgets/media_library_dialog.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

const _reviewBlockStrongLine = Color(0xFFDDE5E8);
const _reviewBlockSoftLine = Color(0xFFE8EEF1);
const _reviewBlockMutedText = Color(0xFF5F6F78);
const _reviewBlockUploadInk = Color(0xFF6D7B83);
const _reviewBlockAccent = AppColors.warmHorizon;
const _reviewBlockImageHeight = 240.0;
const _reviewBlockVerdictHeight = 164.0;

class ArticleReviewTextEntry {
  ArticleReviewTextEntry([String text = ''])
    : controller = TextEditingController(text: text);

  final TextEditingController controller;

  void dispose() {
    controller.dispose();
  }
}

class ArticleReviewCriterionEntry {
  ArticleReviewCriterionEntry({required String label, int score = 80})
    : labelController = TextEditingController(text: label),
      score = score.clamp(0, 100).toInt();

  final TextEditingController labelController;
  int score;

  void dispose() {
    labelController.dispose();
  }
}

class ArticleReviewBlockEntry {
  ArticleReviewBlockEntry({
    required String designLabel,
    required String performanceLabel,
  }) : productNameController = TextEditingController(),
       sourceController = TextEditingController(),
       verdictController = quill.QuillController(
         document: adminQuillDocumentFromJson(adminEmptyQuillDeltaJson),
         selection: const TextSelection.collapsed(offset: 0),
       ),
       pros = [ArticleReviewTextEntry()],
       cons = [ArticleReviewTextEntry()],
       criteria = [
         ArticleReviewCriterionEntry(label: designLabel),
         ArticleReviewCriterionEntry(label: performanceLabel),
       ];

  final TextEditingController productNameController;
  final TextEditingController sourceController;
  final quill.QuillController verdictController;
  final List<ArticleReviewTextEntry> pros;
  final List<ArticleReviewTextEntry> cons;
  final List<ArticleReviewCriterionEntry> criteria;
  String? imageUrl;
  var showOnHomepage = false;
  var extraSettingsExpanded = false;

  int get score {
    if (criteria.isEmpty) return 0;
    final total = criteria.fold<int>(0, (sum, item) => sum + item.score);
    return (total / criteria.length).round().clamp(0, 100).toInt();
  }

  void dispose() {
    productNameController.dispose();
    sourceController.dispose();
    verdictController.dispose();
    for (final item in pros) {
      item.dispose();
    }
    for (final item in cons) {
      item.dispose();
    }
    for (final item in criteria) {
      item.dispose();
    }
  }
}

class ArticleReviewBlockCard extends StatelessWidget {
  const ArticleReviewBlockCard({
    super.key,
    required this.productNameController,
    required this.sourceController,
    required this.verdictController,
    required this.pros,
    required this.cons,
    required this.criteria,
    required this.imageUrl,
    required this.score,
    required this.blockNumber,
    required this.showOnHomepage,
    required this.extraSettingsExpanded,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onImageChanged,
    required this.onShowOnHomepageChanged,
    required this.onToggleExtraSettings,
    required this.onProsAdd,
    required this.onProsRemove,
    required this.onConsAdd,
    required this.onConsRemove,
    required this.onCriterionAdd,
    required this.onCriterionRemove,
    required this.onCriterionScoreChanged,
  });

  final TextEditingController productNameController;
  final TextEditingController sourceController;
  final quill.QuillController verdictController;
  final List<ArticleReviewTextEntry> pros;
  final List<ArticleReviewTextEntry> cons;
  final List<ArticleReviewCriterionEntry> criteria;
  final String? imageUrl;
  final int score;
  final int? blockNumber;
  final bool showOnHomepage;
  final bool extraSettingsExpanded;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onDelete;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final ValueChanged<String?> onImageChanged;
  final ValueChanged<bool> onShowOnHomepageChanged;
  final VoidCallback onToggleExtraSettings;
  final VoidCallback onProsAdd;
  final ValueChanged<int> onProsRemove;
  final VoidCallback onConsAdd;
  final ValueChanged<int> onConsRemove;
  final VoidCallback onCriterionAdd;
  final ValueChanged<int> onCriterionRemove;
  final void Function(int index, int score) onCriterionScoreChanged;

  Future<void> _pickImage(BuildContext context) async {
    final selected = await showMediaLibraryDialog(context);
    final normalized = selected?.trim();
    if (normalized == null || normalized.isEmpty) return;
    onImageChanged(normalized);
  }

  Future<void> _pickUrl(BuildContext context) async {
    final selected = await showUrlImageDialog(context);
    final normalized = selected?.trim();
    if (normalized == null || normalized.isEmpty) return;
    onImageChanged(normalized);
  }

  @override
  Widget build(BuildContext context) {
    return _ReviewSectionCard(
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
                          color: _reviewBlockAccent.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(AppRadius.value),
                          border: Border.all(
                            color: _reviewBlockAccent.withValues(alpha: 0.18),
                          ),
                        ),
                        child: const Icon(
                          Symbols.star_outline,
                          color: _reviewBlockAccent,
                          size: 19,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.t('newsAdd.reviewBlock'),
                              style: const TextStyle(
                                color: AppColors.deepOcean,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              context.t('newsAdd.reviewSubtitle'),
                              style: TextStyle(
                                color: _reviewBlockMutedText.withValues(
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
                  Container(height: 1, color: _reviewBlockSoftLine),
                  const SizedBox(height: 20),
                  _ReviewTitleAndScoreRow(
                    productNameController: productNameController,
                    blockNumber: blockNumber,
                    score: score,
                  ),
                  const SizedBox(height: 18),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 860;
                      final imagePanel = _ReviewImagePanel(
                        imageUrl: imageUrl,
                        onPickImage: () => _pickImage(context),
                        onPickUrl: () => _pickUrl(context),
                        onClear: () => onImageChanged(null),
                      );
                      final verdictPanel = _ReviewVerdictPanel(
                        controller: verdictController,
                      );

                      if (compact) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            imagePanel,
                            const SizedBox(height: 16),
                            verdictPanel,
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 5, child: imagePanel),
                          const SizedBox(width: 24),
                          Expanded(flex: 10, child: verdictPanel),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 760;
                      final prosCard = _ReviewListCard(
                        titleKey: 'newsAdd.reviewPros',
                        hintKey: 'newsAdd.reviewProsHint',
                        entries: pros,
                        accent: _reviewBlockAccent,
                        icon: Symbols.check,
                        onAdd: onProsAdd,
                        onRemove: onProsRemove,
                      );
                      final consCard = _ReviewListCard(
                        titleKey: 'newsAdd.reviewCons',
                        hintKey: 'newsAdd.reviewConsHint',
                        entries: cons,
                        accent: AppColors.actionRed,
                        icon: Symbols.close,
                        onAdd: onConsAdd,
                        onRemove: onConsRemove,
                      );

                      if (compact) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            prosCard,
                            const SizedBox(height: 14),
                            consCard,
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: prosCard),
                          const SizedBox(width: 24),
                          Expanded(child: consCard),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Container(height: 1, color: _reviewBlockSoftLine),
                  const SizedBox(height: 22),
                  _ReviewScoreSection(
                    criteria: criteria,
                    onAdd: onCriterionAdd,
                    onRemove: onCriterionRemove,
                    onScoreChanged: onCriterionScoreChanged,
                  ),
                  _ReviewExtraSettingsPanel(
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

class _ReviewTitleAndScoreRow extends StatelessWidget {
  const _ReviewTitleAndScoreRow({
    required this.productNameController,
    required this.blockNumber,
    required this.score,
  });

  final TextEditingController productNameController;
  final int? blockNumber;
  final int score;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        final titleField = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _ReviewFieldLabel('newsAdd.reviewProductTitle'),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (blockNumber != null) ...[
                    _BlockNumberBadge(blockNumber!),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: _ReviewTextInputBox(
                      controller: productNameController,
                      hintTextKey: 'newsAdd.reviewProductHint',
                      fontSize: 13,
                      bold: true,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
        final scoreBox = _ReviewScoreBadge(score: score);

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [titleField, const SizedBox(height: 14), scoreBox],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: titleField),
            const SizedBox(width: 18),
            SizedBox(width: 120, child: scoreBox),
          ],
        );
      },
    );
  }
}

class _ReviewScoreBadge extends StatelessWidget {
  const _ReviewScoreBadge({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final clampedScore = score.clamp(0, 100).toInt();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 2),
          child: Text(
            context.t('newsAdd.reviewTotalScore'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _reviewBlockMutedText,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ),
        Container(
          height: 38,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.deepOcean,
            borderRadius: BorderRadius.circular(AppRadius.value),
            boxShadow: [
              BoxShadow(
                color: AppColors.deepOcean.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: clampedScore / 100,
                  child: Container(
                    height: 4,
                    color: Colors.white.withValues(alpha: 0.26),
                  ),
                ),
              ),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Symbols.star, color: Colors.white, size: 13),
                    const SizedBox(width: 8),
                    Text(
                      '$clampedScore',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '/100',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.62),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReviewImagePanel extends StatelessWidget {
  const _ReviewImagePanel({
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
        const _ReviewFieldLabel('newsAdd.reviewImage'),
        _ReviewImagePicker(
          imageUrl: imageUrl,
          onPickImage: onPickImage,
          onPickUrl: onPickUrl,
          onClear: onClear,
        ),
      ],
    );
  }
}

class _ReviewImagePicker extends StatelessWidget {
  const _ReviewImagePicker({
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
    return CustomPaint(
      painter: _DashedBorderPainter(
        color: _reviewBlockStrongLine,
        radius: AppRadius.value,
      ),
      child: Container(
        height: _reviewBlockImageHeight,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(AppRadius.value),
        ),
        child: imageUrl == null
            ? _EmptyReviewImagePicker(
                onPickImage: onPickImage,
                onPickUrl: onPickUrl,
              )
            : _SelectedReviewImage(
                imageUrl: imageUrl!,
                onPickImage: onPickImage,
                onClear: onClear,
              ),
      ),
    );
  }
}

class _EmptyReviewImagePicker extends StatelessWidget {
  const _EmptyReviewImagePicker({
    required this.onPickImage,
    required this.onPickUrl,
  });

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
              const Icon(Symbols.add, color: _reviewBlockUploadInk, size: 36),
              const SizedBox(height: 8),
              Text(
                context.t('newsAdd.reviewPickImage'),
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

class _SelectedReviewImage extends StatelessWidget {
  const _SelectedReviewImage({
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
                context.t('newsAdd.reviewImageError'),
                style: const TextStyle(
                  color: _reviewBlockMutedText,
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
        Positioned(
          right: 8,
          bottom: 8,
          child: MediaImageDownloadButton(
            imageUrl: imageUrl,
            borderColor: _reviewBlockStrongLine,
          ),
        ),
      ],
    );
  }
}

class _ReviewVerdictPanel extends StatelessWidget {
  const _ReviewVerdictPanel({required this.controller});

  final quill.QuillController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Symbols.description_outlined,
              size: 13,
              color: AppColors.deepOcean,
            ),
            const SizedBox(width: 6),
            const _ReviewFieldLabel('newsAdd.reviewVerdict', bottom: 8),
          ],
        ),
        _ReviewRichTextEditor(
          controller: controller,
          placeholder: 'newsAdd.reviewVerdictHint',
        ),
      ],
    );
  }
}

class _ReviewListCard extends StatelessWidget {
  const _ReviewListCard({
    required this.titleKey,
    required this.hintKey,
    required this.entries,
    required this.accent,
    required this.icon,
    required this.onAdd,
    required this.onRemove,
  });

  final String titleKey;
  final String hintKey;
  final List<ArticleReviewTextEntry> entries;
  final Color accent;
  final IconData icon;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: accent.withValues(alpha: 0.32)),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -8,
            top: -18,
            child: Icon(icon, size: 78, color: accent.withValues(alpha: 0.035)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Icon(icon, color: Colors.white, size: 14),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context.t(titleKey),
                      style: const TextStyle(
                        color: AppColors.deepOcean,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  _TinyIconButton(
                    icon: Symbols.add,
                    color: accent,
                    onTap: onAdd,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              for (var i = 0; i < entries.length; i++) ...[
                _ReviewListInputRow(
                  controller: entries[i].controller,
                  hintKey: hintKey,
                  borderColor: accent.withValues(alpha: 0.26),
                  onRemove: () => onRemove(i),
                ),
                if (i != entries.length - 1) const SizedBox(height: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ReviewListInputRow extends StatelessWidget {
  const _ReviewListInputRow({
    required this.controller,
    required this.hintKey,
    required this.borderColor,
    required this.onRemove,
  });

  final TextEditingController controller;
  final String hintKey;
  final Color borderColor;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ReviewTextInputBox(
            controller: controller,
            hintTextKey: hintKey,
            borderColor: borderColor,
            fontSize: 12,
            bold: true,
          ),
        ),
        const SizedBox(width: 10),
        _TinyIconButton(
          icon: Symbols.close,
          color: AppColors.actionRed,
          onTap: onRemove,
        ),
      ],
    );
  }
}

class _ReviewScoreSection extends StatelessWidget {
  const _ReviewScoreSection({
    required this.criteria,
    required this.onAdd,
    required this.onRemove,
    required this.onScoreChanged,
  });

  final List<ArticleReviewCriterionEntry> criteria;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final void Function(int index, int score) onScoreChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(
              Symbols.bar_chart_outlined,
              size: 16,
              color: _reviewBlockAccent,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t('newsAdd.reviewDetailedScoring'),
                    style: const TextStyle(
                      color: AppColors.deepOcean,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.t('newsAdd.reviewScoreHelp'),
                    style: const TextStyle(
                      color: AppColors.deepOcean,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
            _CriterionAddButton(onTap: onAdd),
          ],
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 760;
            if (compact) {
              return Column(
                children: [
                  for (var i = 0; i < criteria.length; i++) ...[
                    _CriterionCard(
                      criterion: criteria[i],
                      onRemove: () => onRemove(i),
                      onScoreChanged: (score) => onScoreChanged(i, score),
                    ),
                    if (i != criteria.length - 1) const SizedBox(height: 12),
                  ],
                ],
              );
            }

            return Wrap(
              spacing: 18,
              runSpacing: 14,
              children: [
                for (var i = 0; i < criteria.length; i++)
                  SizedBox(
                    width: (constraints.maxWidth - 18) / 2,
                    child: _CriterionCard(
                      criterion: criteria[i],
                      onRemove: () => onRemove(i),
                      onScoreChanged: (score) => onScoreChanged(i, score),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _CriterionCard extends StatelessWidget {
  const _CriterionCard({
    required this.criterion,
    required this.onRemove,
    required this.onScoreChanged,
  });

  final ArticleReviewCriterionEntry criterion;
  final VoidCallback onRemove;
  final ValueChanged<int> onScoreChanged;

  @override
  Widget build(BuildContext context) {
    final score = criterion.score.clamp(0, 100).toInt();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: _reviewBlockStrongLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: criterion.labelController,
                  maxLines: 1,
                  cursorColor: AppColors.deepOcean,
                  style: const TextStyle(
                    color: AppColors.deepOcean,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                  decoration: InputDecoration(
                    hintText: context.t('newsAdd.reviewCriterionHint'),
                    hintStyle: const TextStyle(
                      color: AppColors.placeholder,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0,
                    ),
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                  ),
                ),
              ),
              _TinyIconButton(
                icon: Symbols.close,
                color: AppColors.actionRed,
                onTap: onRemove,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    activeTrackColor: _reviewBlockAccent,
                    inactiveTrackColor: _reviewBlockStrongLine,
                    thumbColor: Colors.white,
                    overlayColor: _reviewBlockAccent.withValues(alpha: 0.12),
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 7,
                      elevation: 1,
                      pressedElevation: 2,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 16,
                    ),
                  ),
                  child: Slider(
                    value: score.toDouble(),
                    min: 0,
                    max: 100,
                    divisions: 100,
                    onChanged: (value) => onScoreChanged(value.round()),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 42,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _reviewBlockAccent,
                  borderRadius: BorderRadius.circular(AppRadius.value),
                  boxShadow: [
                    BoxShadow(
                      color: _reviewBlockAccent.withValues(alpha: 0.16),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Text(
                  '$score',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReviewExtraSettingsPanel extends StatelessWidget {
  const _ReviewExtraSettingsPanel({
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
      padding: const EdgeInsets.only(top: 16),
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
                          const _ReviewFieldLabel('newsAdd.reviewSource'),
                          _ReviewTextInputBox(
                            controller: sourceController,
                            hintTextKey: 'newsAdd.reviewSourceHint',
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
                        color: _reviewBlockMutedText.withValues(alpha: 0.72),
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
                      color: _reviewBlockMutedText.withValues(alpha: 0.72),
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

class _ReviewRichTextEditor extends StatelessWidget {
  const _ReviewRichTextEditor({
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
        border: Border.all(color: _reviewBlockStrongLine),
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
                showSubscript: true,
                showSuperscript: true,
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
            height: _reviewBlockVerdictHeight,
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

class _ReviewTextInputBox extends StatelessWidget {
  const _ReviewTextInputBox({
    required this.controller,
    required this.hintTextKey,
    this.borderColor = _reviewBlockStrongLine,
    this.bold = false,
    this.fontSize = 14,
  });

  final TextEditingController controller;
  final String hintTextKey;
  final Color borderColor;
  final bool bold;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: borderColor),
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

class _CriterionAddButton extends StatelessWidget {
  const _CriterionAddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.value),
            border: Border.all(color: _reviewBlockStrongLine),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Symbols.add, size: 15, color: _reviewBlockAccent),
              const SizedBox(width: 8),
              Text(
                context.t('newsAdd.reviewAddCriterion'),
                style: const TextStyle(
                  color: _reviewBlockAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
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

class _TinyIconButton extends StatelessWidget {
  const _TinyIconButton({
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
        child: SizedBox(
          width: 28,
          height: 28,
          child: Icon(icon, size: 15, color: color),
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.value),
            border: Border.all(color: _reviewBlockStrongLine),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Symbols.public, size: 13, color: AppColors.deepOcean),
              const SizedBox(width: 6),
              Text(
                context.t('newsAdd.reviewUrlOrUpload'),
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
            border: Border.all(color: _reviewBlockStrongLine),
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

class _ReviewSectionCard extends StatelessWidget {
  const _ReviewSectionCard({required this.child, this.padding});

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
        border: Border.all(color: _reviewBlockStrongLine),
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
        border: Border(right: BorderSide(color: _reviewBlockSoftLine)),
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

class _ReviewFieldLabel extends StatelessWidget {
  const _ReviewFieldLabel(this.text, {this.bottom = 8});

  final String text;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottom, left: 2),
      child: Text(
        context.t(text),
        style: const TextStyle(
          color: _reviewBlockMutedText,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
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
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rect);
    final dashed = Path();
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        dashed.addPath(metric.extractPath(distance, distance + 6), Offset.zero);
        distance += 12;
      }
    }
    canvas.drawPath(dashed, paint);
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}

String _resolvedImageUrl(String value, {int width = 720}) {
  if (value.startsWith('http')) return value;
  return MediaService().resolveImageUrl(value, width: width, quality: 90);
}
