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

enum QuizQuestionAnswerLayout { grid2, grid3, list }

enum QuizQuestionType { personality, trivia, checklist }

const _quizQuestionBlockStrongLine = Color(0xFFDDE5E8);
const _quizQuestionBlockSoftLine = Color(0xFFE8EEF1);
const _quizQuestionBlockMutedText = Color(0xFF5F6F78);
const _quizQuestionBlockUploadInk = Color(0xFF6D7B83);
const _quizQuestionBlockVisualHeight = 236.0;
const _quizQuestionDescriptionBodyHeight = 148.0;

class QuizQuestionResultOption {
  const QuizQuestionResultOption({required this.id, required this.label});

  final String id;
  final String label;
}

class QuizQuestionAnswerEntry {
  QuizQuestionAnswerEntry()
    : answerController = TextEditingController(),
      explanationController = TextEditingController();

  final TextEditingController answerController;
  final TextEditingController explanationController;
  String? imageUrl;
  String? resultId;
  bool isCorrect = false;

  void dispose() {
    answerController.dispose();
    explanationController.dispose();
  }
}

class QuizQuestionBlockEntry {
  QuizQuestionBlockEntry({
    int answerCount = 2,
    this.layout = QuizQuestionAnswerLayout.list,
  }) : titleController = TextEditingController(),
       descriptionController = quill.QuillController(
         document: adminQuillDocumentFromJson(adminEmptyQuillDeltaJson),
         selection: const TextSelection.collapsed(offset: 0),
       ),
       answers = List.generate(answerCount, (_) => QuizQuestionAnswerEntry());

  final TextEditingController titleController;
  final quill.QuillController descriptionController;
  final List<QuizQuestionAnswerEntry> answers;
  QuizQuestionAnswerLayout layout;
  String? imageUrl;

  void ensureAnswerCount(int count) {
    while (answers.length < count) {
      answers.add(QuizQuestionAnswerEntry());
    }
  }

  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    for (final answer in answers) {
      answer.dispose();
    }
  }
}

class QuizQuestionBlockCard extends StatelessWidget {
  const QuizQuestionBlockCard({
    super.key,
    required this.titleController,
    required this.descriptionController,
    required this.answers,
    required this.blockNumber,
    required this.imageUrl,
    required this.quizType,
    required this.resultOptions,
    required this.layout,
    required this.endDateController,
    required this.allowMulti,
    required this.showResults,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onLayoutChanged,
    required this.onAllowMultiChanged,
    required this.onShowResultsChanged,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onImageChanged,
    required this.onAnswerImageChanged,
    required this.onAnswerResultChanged,
    required this.onAnswerCorrectChanged,
    required this.onRemoveAnswer,
    required this.onAddAnswer,
  });

  final TextEditingController titleController;
  final quill.QuillController descriptionController;
  final List<QuizQuestionAnswerEntry> answers;
  final int? blockNumber;
  final String? imageUrl;
  final QuizQuestionType quizType;
  final List<QuizQuestionResultOption> resultOptions;
  final QuizQuestionAnswerLayout layout;
  final TextEditingController endDateController;
  final bool allowMulti;
  final bool showResults;
  final bool canMoveUp;
  final bool canMoveDown;
  final ValueChanged<QuizQuestionAnswerLayout> onLayoutChanged;
  final ValueChanged<bool> onAllowMultiChanged;
  final ValueChanged<bool> onShowResultsChanged;
  final VoidCallback onDelete;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final ValueChanged<String?> onImageChanged;
  final void Function(QuizQuestionAnswerEntry answer, String? imageUrl)
  onAnswerImageChanged;
  final void Function(QuizQuestionAnswerEntry answer, String? resultId)
  onAnswerResultChanged;
  final void Function(QuizQuestionAnswerEntry answer, bool isCorrect)
  onAnswerCorrectChanged;
  final ValueChanged<QuizQuestionAnswerEntry> onRemoveAnswer;
  final VoidCallback onAddAnswer;

  Future<void> _pickImage(BuildContext context) async {
    final selected = await showMediaLibraryDialog(context);
    if (selected != null) onImageChanged(selected);
  }

  Future<void> _pickUrl(BuildContext context) async {
    final selected = await showUrlImageDialog(context);
    if (selected != null && selected.trim().isNotEmpty) {
      onImageChanged(selected.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return _QuizQuestionSectionCard(
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
                          Icons.checklist_outlined,
                          color: AppColors.actionRed,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          context.t('newsAdd.quiz.questionsTitle'),
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
                  const SizedBox(height: 14),
                  Container(height: 1, color: _quizQuestionBlockSoftLine),
                  const SizedBox(height: 20),
                  const _QuizQuestionFieldLabel('newsAdd.imageBlockTitle'),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (blockNumber != null) ...[
                          _BlockNumberBadge(blockNumber!),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: _QuizQuestionTextInputBox(
                            controller: titleController,
                            hintTextKey: 'newsAdd.quiz.questionTitle',
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
                      final imagePanel = _ImagePanel(
                        imageUrl: imageUrl,
                        onPickImage: () => _pickImage(context),
                        onPickUrl: () => _pickUrl(context),
                        onClear: () => onImageChanged(null),
                      );
                      final descriptionPanel = _DescriptionPanel(
                        controller: descriptionController,
                      );

                      if (compact) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            imagePanel,
                            const SizedBox(height: 16),
                            descriptionPanel,
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 5, child: imagePanel),
                          const SizedBox(width: 24),
                          Expanded(flex: 10, child: descriptionPanel),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  _AnswerLayoutSelector(
                    layout: layout,
                    onLayoutChanged: onLayoutChanged,
                  ),
                  const SizedBox(height: 18),
                  _AnswerList(
                    answers: answers,
                    quizType: quizType,
                    resultOptions: resultOptions,
                    layout: layout,
                    onImageChanged: onAnswerImageChanged,
                    onResultChanged: onAnswerResultChanged,
                    onCorrectChanged: onAnswerCorrectChanged,
                    onRemoveAnswer: onRemoveAnswer,
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 22,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _NamedToggle(
                        label: 'newsAdd.quiz.allowMulti',
                        value: allowMulti,
                        onChanged: onAllowMultiChanged,
                        activeColor: AppColors.deepOcean,
                      ),
                      _NamedToggle(
                        label: 'newsAdd.quiz.showResults',
                        value: showResults,
                        onChanged: onShowResultsChanged,
                        activeColor: AppColors.warmHorizon,
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            context.t('newsAdd.quiz.endDate'),
                            style: const TextStyle(
                              color: AppColors.inkSoft,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 170,
                            height: 34,
                            child: TextField(
                              controller: endDateController,
                              cursorColor: AppColors.deepOcean,
                              style: const TextStyle(
                                color: AppColors.deepOcean,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: InputDecoration(
                                hintText: 'gg.aa.yyyy',
                                hintStyle: const TextStyle(
                                  color: AppColors.placeholder,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                                filled: true,
                                fillColor: AppColors.surface.withValues(
                                  alpha: 0.6,
                                ),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 9,
                                ),
                                suffixIcon: const Icon(
                                  Icons.calendar_today_outlined,
                                  size: 14,
                                  color: AppColors.iconMuted,
                                ),
                                suffixIconConstraints: const BoxConstraints(
                                  minWidth: 30,
                                  minHeight: 30,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.value,
                                  ),
                                  borderSide: const BorderSide(
                                    color: AppColors.line,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.value,
                                  ),
                                  borderSide: const BorderSide(
                                    color: AppColors.line,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.value,
                                  ),
                                  borderSide: const BorderSide(
                                    color: AppColors.deepOcean,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _CompactAddButton(
                    label: 'newsAdd.quiz.addAnswer',
                    onPressed: onAddAnswer,
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

class _QuizQuestionSectionCard extends StatelessWidget {
  const _QuizQuestionSectionCard({required this.child, this.padding});

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
        border: Border.all(color: _quizQuestionBlockStrongLine),
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
        border: Border(right: BorderSide(color: _quizQuestionBlockSoftLine)),
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

class _ImagePanel extends StatelessWidget {
  const _ImagePanel({
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
        const _QuizQuestionFieldLabel('newsAdd.quiz.questionImage'),
        _DashedImageBox(
          imageUrl: imageUrl,
          onPickImage: onPickImage,
          onPickUrl: onPickUrl,
          onClear: onClear,
        ),
      ],
    );
  }
}

class _DashedImageBox extends StatelessWidget {
  const _DashedImageBox({
    required this.imageUrl,
    required this.onPickImage,
    required this.onPickUrl,
    required this.onClear,
    this.height = _quizQuestionBlockVisualHeight,
  });

  final String? imageUrl;
  final VoidCallback onPickImage;
  final VoidCallback onPickUrl;
  final VoidCallback onClear;
  final double height;

  String _resolvedImageUrl(String value) {
    if (value.startsWith('http')) return value;
    return MediaService().resolveImageUrl(value, width: 720, quality: 90);
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(
        color: _quizQuestionBlockStrongLine,
        radius: AppRadius.value,
      ),
      child: Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(AppRadius.value),
        ),
        child: imageUrl == null
            ? _EmptyImagePicker(onPickImage: onPickImage, onPickUrl: onPickUrl)
            : Stack(
                fit: StackFit.expand,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: AdminCachedImage(
                      url: _resolvedImageUrl(imageUrl!),
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      memCacheWidth: 720,
                      useOldImageOnUrlChange: true,
                      errorWidget: _EmptyImagePicker(
                        onPickImage: onPickImage,
                        onPickUrl: onPickUrl,
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
              ),
      ),
    );
  }
}

class _EmptyImagePicker extends StatelessWidget {
  const _EmptyImagePicker({required this.onPickImage, required this.onPickUrl});

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
                color: _quizQuestionBlockUploadInk,
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                context.t('newsAdd.imageSelect'),
                style: const TextStyle(
                  color: _quizQuestionBlockUploadInk,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 12),
              _UrlUploadButton(onTap: onPickUrl),
            ],
          ),
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
            border: Border.all(color: _quizQuestionBlockStrongLine),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.public, size: 13, color: AppColors.deepOcean),
              const SizedBox(width: 6),
              Text(
                context.t('newsAdd.addUrl'),
                style: const TextStyle(
                  color: AppColors.deepOcean,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
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
            border: Border.all(color: _quizQuestionBlockStrongLine),
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

class _DescriptionPanel extends StatelessWidget {
  const _DescriptionPanel({required this.controller});

  final quill.QuillController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _QuizQuestionFieldLabel('newsAdd.quiz.questionDescription'),
        _QuizQuestionDescriptionEditor(
          controller: controller,
          placeholder: 'newsAdd.quiz.questionDescriptionHint',
        ),
      ],
    );
  }
}

class _QuizQuestionDescriptionEditor extends StatelessWidget {
  const _QuizQuestionDescriptionEditor({
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
        border: Border.all(color: _quizQuestionBlockStrongLine),
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
                showFontSize: false,
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
                showLink: true,
                showSubscript: true,
                showSuperscript: true,
                showUndo: false,
                showRedo: false,
                showSearchButton: false,
                showAlignmentButtons: false,
                showIndent: false,
                showClearFormat: false,
                showDirection: false,
              ),
            ),
          ),
          SizedBox(
            height: _quizQuestionDescriptionBodyHeight,
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

class _AnswerLayoutSelector extends StatelessWidget {
  const _AnswerLayoutSelector({
    required this.layout,
    required this.onLayoutChanged,
  });

  final QuizQuestionAnswerLayout layout;
  final ValueChanged<QuizQuestionAnswerLayout> onLayoutChanged;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.t('newsAdd.quiz.answerFormat'),
            style: const TextStyle(
              color: AppColors.inkSoft,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.value),
              border: Border.all(color: AppColors.line),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _LayoutOption(
                  icon: Icons.grid_view_outlined,
                  selected: layout == QuizQuestionAnswerLayout.grid2,
                  onTap: () => onLayoutChanged(QuizQuestionAnswerLayout.grid2),
                ),
                _LayoutOption(
                  icon: Icons.window_outlined,
                  selected: layout == QuizQuestionAnswerLayout.grid3,
                  onTap: () => onLayoutChanged(QuizQuestionAnswerLayout.grid3),
                ),
                _LayoutOption(
                  icon: Icons.view_list_outlined,
                  selected: layout == QuizQuestionAnswerLayout.list,
                  onTap: () => onLayoutChanged(QuizQuestionAnswerLayout.list),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LayoutOption extends StatelessWidget {
  const _LayoutOption({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.deepOcean : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.value),
          ),
          child: Icon(
            icon,
            size: 16,
            color: selected ? Colors.white : AppColors.inkSoft,
          ),
        ),
      ),
    );
  }
}

class _AnswerList extends StatelessWidget {
  const _AnswerList({
    required this.answers,
    required this.quizType,
    required this.resultOptions,
    required this.layout,
    required this.onImageChanged,
    required this.onResultChanged,
    required this.onCorrectChanged,
    required this.onRemoveAnswer,
  });

  final List<QuizQuestionAnswerEntry> answers;
  final QuizQuestionType quizType;
  final List<QuizQuestionResultOption> resultOptions;
  final QuizQuestionAnswerLayout layout;
  final void Function(QuizQuestionAnswerEntry answer, String? imageUrl)
  onImageChanged;
  final void Function(QuizQuestionAnswerEntry answer, String? resultId)
  onResultChanged;
  final void Function(QuizQuestionAnswerEntry answer, bool isCorrect)
  onCorrectChanged;
  final ValueChanged<QuizQuestionAnswerEntry> onRemoveAnswer;

  @override
  Widget build(BuildContext context) {
    if (answers.isEmpty) return const SizedBox.shrink();

    if (layout == QuizQuestionAnswerLayout.list) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < answers.length; i++) ...[
            _QuizAnswerCard(
              index: i + 1,
              entry: answers[i],
              quizType: quizType,
              resultOptions: resultOptions,
              showImage: false,
              canRemove: answers.length > 1,
              onImageChanged: (imageUrl) =>
                  onImageChanged(answers[i], imageUrl),
              onResultChanged: (resultId) =>
                  onResultChanged(answers[i], resultId),
              onCorrectChanged: (isCorrect) =>
                  onCorrectChanged(answers[i], isCorrect),
              onRemove: () => onRemoveAnswer(answers[i]),
            ),
            if (i != answers.length - 1) const SizedBox(height: 10),
          ],
        ],
      );
    }

    final columnCount = layout == QuizQuestionAnswerLayout.grid3 ? 3 : 2;
    final rows = <Widget>[];
    for (var start = 0; start < answers.length; start += columnCount) {
      final end = (start + columnCount).clamp(0, answers.length);
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = start; i < end; i++) ...[
              Expanded(
                child: _QuizAnswerCard(
                  index: i + 1,
                  entry: answers[i],
                  quizType: quizType,
                  resultOptions: resultOptions,
                  showImage: true,
                  canRemove: answers.length > 1,
                  onImageChanged: (imageUrl) =>
                      onImageChanged(answers[i], imageUrl),
                  onResultChanged: (resultId) =>
                      onResultChanged(answers[i], resultId),
                  onCorrectChanged: (isCorrect) =>
                      onCorrectChanged(answers[i], isCorrect),
                  onRemove: () => onRemoveAnswer(answers[i]),
                ),
              ),
              if (i != end - 1) const SizedBox(width: 10),
            ],
            for (var i = end; i < start + columnCount; i++) ...[
              if (end > start) const SizedBox(width: 10),
              const Expanded(child: SizedBox.shrink()),
            ],
          ],
        ),
      );
      if (start + columnCount < answers.length) {
        rows.add(const SizedBox(height: 10));
      }
    }

    return Column(children: rows);
  }
}

class _QuizAnswerCard extends StatefulWidget {
  const _QuizAnswerCard({
    required this.index,
    required this.entry,
    required this.quizType,
    required this.resultOptions,
    required this.showImage,
    required this.canRemove,
    required this.onImageChanged,
    required this.onResultChanged,
    required this.onCorrectChanged,
    required this.onRemove,
  });

  final int index;
  final QuizQuestionAnswerEntry entry;
  final QuizQuestionType quizType;
  final List<QuizQuestionResultOption> resultOptions;
  final bool showImage;
  final bool canRemove;
  final ValueChanged<String?> onImageChanged;
  final ValueChanged<String?> onResultChanged;
  final ValueChanged<bool> onCorrectChanged;
  final VoidCallback onRemove;

  @override
  State<_QuizAnswerCard> createState() => _QuizAnswerCardState();
}

class _QuizAnswerCardState extends State<_QuizAnswerCard> {
  var _isHovered = false;

  Future<void> _pickImage(BuildContext context) async {
    final selected = await showMediaLibraryDialog(context);
    if (selected != null) widget.onImageChanged(selected);
  }

  Future<void> _pickUrl(BuildContext context) async {
    final selected = await showUrlImageDialog(context);
    if (selected != null && selected.trim().isNotEmpty) {
      widget.onImageChanged(selected.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget? control = switch (widget.quizType) {
      QuizQuestionType.personality => _ResultPickerRow(
        value: widget.entry.resultId,
        options: widget.resultOptions,
        onChanged: widget.onResultChanged,
      ),
      QuizQuestionType.trivia => _CorrectAnswerRow(
        value: widget.entry.isCorrect,
        onChanged: widget.onCorrectChanged,
      ),
      QuizQuestionType.checklist => null,
    };
    final Widget? inlineControl = switch (widget.quizType) {
      QuizQuestionType.personality => _InlineResultPicker(
        value: widget.entry.resultId,
        options: widget.resultOptions,
        onChanged: widget.onResultChanged,
      ),
      QuizQuestionType.trivia => _InlineCorrectButton(
        value: widget.entry.isCorrect,
        onChanged: widget.onCorrectChanged,
      ),
      QuizQuestionType.checklist => null,
    };
    final showCorrectExplanation =
        widget.quizType == QuizQuestionType.trivia &&
        (widget.entry.isCorrect ||
            widget.entry.explanationController.text.trim().isNotEmpty);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.value),
              border: Border.all(color: _quizQuestionBlockStrongLine),
              boxShadow: [
                BoxShadow(
                  color: AppColors.deepOcean.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.showImage)
                  ClipRRect(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(AppRadius.value),
                      topRight: Radius.circular(AppRadius.value),
                    ),
                    child: _DashedImageBox(
                      imageUrl: widget.entry.imageUrl,
                      onPickImage: () => _pickImage(context),
                      onPickUrl: () => _pickUrl(context),
                      onClear: () => widget.onImageChanged(null),
                      height: 160,
                    ),
                  ),
                _AnswerTextRow(
                  index: widget.index,
                  controller: widget.entry.answerController,
                  showTopBorder: widget.showImage,
                  trailing: widget.showImage
                      ? null
                      : _AnswerInlineActions(
                          control: inlineControl,
                          canRemove: widget.canRemove && _isHovered,
                          onRemove: widget.onRemove,
                        ),
                ),
                if (showCorrectExplanation)
                  _CorrectExplanationRow(
                    controller: widget.entry.explanationController,
                  ),
                if (widget.showImage && control != null) control,
              ],
            ),
          ),
          if (widget.showImage && widget.canRemove && _isHovered)
            Positioned(
              top: -9,
              right: -9,
              child: _AnswerDeleteButton(onPressed: widget.onRemove),
            ),
        ],
      ),
    );
  }
}

class _CorrectExplanationRow extends StatelessWidget {
  const _CorrectExplanationRow({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: const BoxDecoration(
        color: Color(0xFFFBFDFE),
        border: Border(top: BorderSide(color: _quizQuestionBlockStrongLine)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 7, left: 2),
            child: Text(
              context.t('newsAdd.quiz.correctAnswerExplanation'),
              style: const TextStyle(
                color: _quizQuestionBlockMutedText,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.1,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.value),
              border: Border.all(color: _quizQuestionBlockStrongLine),
            ),
            child: TextField(
              controller: controller,
              minLines: 2,
              maxLines: 3,
              cursorColor: AppColors.deepOcean,
              style: const TextStyle(
                color: AppColors.deepOcean,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                height: 1.35,
                letterSpacing: 0,
              ),
              decoration: InputDecoration(
                hintText: context.t(
                  'newsAdd.quiz.correctAnswerExplanationHint',
                ),
                hintStyle: const TextStyle(
                  color: AppColors.placeholder,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w400,
                  height: 1.35,
                  letterSpacing: 0,
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
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

class _AnswerTextRow extends StatelessWidget {
  const _AnswerTextRow({
    required this.index,
    required this.controller,
    required this.showTopBorder,
    this.trailing,
  });

  final int index;
  final TextEditingController controller;
  final bool showTopBorder;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        border: Border(
          top: showTopBorder
              ? const BorderSide(color: _quizQuestionBlockStrongLine)
              : BorderSide.none,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: double.infinity,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFF3F6F8),
              border: Border(
                right: BorderSide(color: _quizQuestionBlockStrongLine),
              ),
            ),
            child: Text(
              '#$index',
              style: const TextStyle(
                color: AppColors.deepOcean,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextField(
                controller: controller,
                cursorColor: AppColors.deepOcean,
                style: const TextStyle(
                  color: AppColors.deepOcean,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: context.t('newsAdd.quiz.answerHint'),
                  hintStyle: const TextStyle(
                    color: AppColors.placeholder,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
          ),
          if (trailing != null)
            Padding(padding: const EdgeInsets.only(right: 8), child: trailing),
        ],
      ),
    );
  }
}

class _ResultPickerRow extends StatelessWidget {
  const _ResultPickerRow({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String? value;
  final List<QuizQuestionResultOption> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final resolvedValue = options.any((option) => option.id == value)
        ? value
        : null;

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _quizQuestionBlockStrongLine)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: resolvedValue,
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down,
            size: 16,
            color: AppColors.iconMuted,
          ),
          hint: Text(
            context.t('newsAdd.quiz.pickResult'),
            style: const TextStyle(
              color: AppColors.deepOcean,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: const TextStyle(
            color: AppColors.deepOcean,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
          items: [
            for (final option in options)
              DropdownMenuItem(value: option.id, child: Text(option.label)),
          ],
          onChanged: options.isEmpty ? null : onChanged,
        ),
      ),
    );
  }
}

class _InlineResultPicker extends StatelessWidget {
  const _InlineResultPicker({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String? value;
  final List<QuizQuestionResultOption> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final resolvedValue = options.any((option) => option.id == value)
        ? value
        : null;

    return Container(
      width: 128,
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: resolvedValue,
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down,
            size: 14,
            color: AppColors.iconMuted,
          ),
          hint: Text(
            context.t('newsAdd.quiz.pickResult'),
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.deepOcean,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          style: const TextStyle(
            color: AppColors.deepOcean,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
          items: [
            for (final option in options)
              DropdownMenuItem(value: option.id, child: Text(option.label)),
          ],
          onChanged: options.isEmpty ? null : onChanged,
        ),
      ),
    );
  }
}

class _CorrectAnswerRow extends StatelessWidget {
  const _CorrectAnswerRow({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: _quizQuestionBlockStrongLine)),
        ),
        child: Row(
          children: [
            _CorrectCircle(value: value),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.t('newsAdd.quiz.correctAnswer'),
                style: const TextStyle(
                  color: AppColors.deepOcean,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineCorrectButton extends StatelessWidget {
  const _InlineCorrectButton({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: context.t('newsAdd.quiz.correctAnswer'),
      waitDuration: const Duration(milliseconds: 350),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: _CorrectCircle(value: value),
        ),
      ),
    );
  }
}

class _CorrectCircle extends StatelessWidget {
  const _CorrectCircle({required this.value});

  final bool value;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: value ? AppColors.deepOcean : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: value ? AppColors.deepOcean : AppColors.line,
          width: 1.2,
        ),
      ),
      child: value
          ? const Icon(Icons.check, size: 12, color: Colors.white)
          : null,
    );
  }
}

class _AnswerInlineActions extends StatelessWidget {
  const _AnswerInlineActions({
    required this.control,
    required this.canRemove,
    required this.onRemove,
  });

  final Widget? control;
  final bool canRemove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    if (control == null && !canRemove) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ?control,
        if (canRemove) ...[
          if (control != null) const SizedBox(width: 6),
          _AnswerDeleteButton(onPressed: onRemove),
        ],
      ],
    );
  }
}

class _AnswerDeleteButton extends StatelessWidget {
  const _AnswerDeleteButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Tooltip(
        message: MaterialLocalizations.of(context).deleteButtonTooltip,
        waitDuration: const Duration(milliseconds: 350),
        child: InkWell(
          onTap: onPressed,
          mouseCursor: SystemMouseCursors.click,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.actionRed,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.actionRed.withValues(alpha: 0.18),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.close, size: 14, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _NamedToggle extends StatelessWidget {
  const _NamedToggle({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.activeColor,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          context.t(label),
          style: const TextStyle(
            color: AppColors.inkSoft,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(width: 8),
        _MiniSwitch(
          value: value,
          activeColor: activeColor,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _MiniSwitch extends StatelessWidget {
  const _MiniSwitch({
    required this.value,
    required this.activeColor,
    required this.onChanged,
  });

  final bool value;
  final Color activeColor;
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
          width: 38,
          height: 20,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: value ? activeColor : AppColors.softLine,
            borderRadius: BorderRadius.circular(999),
          ),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 16,
            height: 16,
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

class _CompactAddButton extends StatelessWidget {
  const _CompactAddButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: CustomPaint(
            painter: _DashedBorderPainter(
              color: AppColors.actionRed.withValues(alpha: 0.22),
              radius: AppRadius.value,
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.actionRed.withValues(alpha: 0.045),
                borderRadius: BorderRadius.circular(AppRadius.value),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.add_rounded,
                    color: AppColors.actionRed,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    context.t(label),
                    style: const TextStyle(
                      color: AppColors.actionRed,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuizQuestionTextInputBox extends StatelessWidget {
  const _QuizQuestionTextInputBox({
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
        border: Border.all(color: _quizQuestionBlockStrongLine),
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

class _QuizQuestionFieldLabel extends StatelessWidget {
  const _QuizQuestionFieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(
        context.t(text),
        style: const TextStyle(
          color: _quizQuestionBlockMutedText,
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
