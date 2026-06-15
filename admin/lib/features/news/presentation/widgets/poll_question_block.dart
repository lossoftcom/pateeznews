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

enum PollQuestionAnswerLayout { grid2, grid3, list }

const _pollBlockStrongLine = Color(0xFFDDE5E8);
const _pollBlockSoftLine = Color(0xFFE8EEF1);
const _pollBlockMutedText = Color(0xFF5F6F78);
const _pollBlockUploadInk = Color(0xFF6D7B83);
const _pollBlockVisualHeight = 220.0;
const _pollDescriptionBodyHeight = 148.0;

class PollQuestionAnswerEntry {
  PollQuestionAnswerEntry()
    : answerController = TextEditingController(),
      votesController = TextEditingController(text: '0');

  final TextEditingController answerController;
  final TextEditingController votesController;
  String? imageUrl;

  void dispose() {
    answerController.dispose();
    votesController.dispose();
  }
}

class PollQuestionBlockEntry {
  PollQuestionBlockEntry({int answerCount = 2})
    : titleController = TextEditingController(),
      sourceController = TextEditingController(),
      descriptionController = quill.QuillController(
        document: adminQuillDocumentFromJson(adminEmptyQuillDeltaJson),
        selection: const TextSelection.collapsed(offset: 0),
      ),
      answers = List.generate(answerCount, (_) => PollQuestionAnswerEntry());

  final TextEditingController titleController;
  final TextEditingController sourceController;
  final quill.QuillController descriptionController;
  final List<PollQuestionAnswerEntry> answers;
  PollQuestionAnswerLayout layout = PollQuestionAnswerLayout.grid2;
  String? imageUrl;
  var showOnHomepage = false;
  var extraSettingsExpanded = false;

  void ensureAnswerCount(int count) {
    while (answers.length < count) {
      answers.add(PollQuestionAnswerEntry());
    }
  }

  void dispose() {
    titleController.dispose();
    sourceController.dispose();
    descriptionController.dispose();
    for (final answer in answers) {
      answer.dispose();
    }
  }
}

class PollQuestionBlockCard extends StatelessWidget {
  const PollQuestionBlockCard({
    super.key,
    required this.titleController,
    required this.descriptionController,
    required this.sourceController,
    required this.answers,
    required this.blockNumber,
    required this.imageUrl,
    required this.layout,
    required this.showOnHomepage,
    required this.extraSettingsExpanded,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onLayoutChanged,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onImageChanged,
    required this.onShowOnHomepageChanged,
    required this.onToggleExtraSettings,
    required this.onAnswerImageChanged,
    required this.onRemoveAnswer,
    required this.onAddAnswer,
  });

  final TextEditingController titleController;
  final quill.QuillController descriptionController;
  final TextEditingController sourceController;
  final List<PollQuestionAnswerEntry> answers;
  final int? blockNumber;
  final String? imageUrl;
  final PollQuestionAnswerLayout layout;
  final bool showOnHomepage;
  final bool extraSettingsExpanded;
  final bool canMoveUp;
  final bool canMoveDown;
  final ValueChanged<PollQuestionAnswerLayout> onLayoutChanged;
  final VoidCallback onDelete;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final ValueChanged<String?> onImageChanged;
  final ValueChanged<bool> onShowOnHomepageChanged;
  final VoidCallback onToggleExtraSettings;
  final void Function(PollQuestionAnswerEntry answer, String? imageUrl)
  onAnswerImageChanged;
  final ValueChanged<PollQuestionAnswerEntry> onRemoveAnswer;
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
    return _PollSectionCard(
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
                          Symbols.bar_chart_outlined,
                          color: AppColors.deepOcean,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.t('newsAdd.poll.blockTitle'),
                              style: const TextStyle(
                                color: AppColors.deepOcean,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              context.t('newsAdd.poll.blockDescription'),
                              style: const TextStyle(
                                color: _pollBlockMutedText,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
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
                  Container(height: 1, color: _pollBlockSoftLine),
                  const SizedBox(height: 20),
                  const _PollFieldLabel('newsAdd.poll.questionTitle'),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (blockNumber != null) ...[
                          _BlockNumberBadge(blockNumber!),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: _PollTextInputBox(
                            controller: titleController,
                            hintTextKey: 'newsAdd.poll.questionTitleHint',
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
                    layout: layout,
                    onImageChanged: onAnswerImageChanged,
                    onRemoveAnswer: onRemoveAnswer,
                  ),
                  const SizedBox(height: 18),
                  _PollCompactAddButton(
                    label: 'newsAdd.poll.addAnswer',
                    onPressed: onAddAnswer,
                  ),
                  const SizedBox(height: 6),
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

class PollQuestionAddButton extends StatelessWidget {
  const PollQuestionAddButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return _PollCompactAddButton(
      label: 'newsAdd.poll.addQuestion',
      onPressed: onPressed,
    );
  }
}

class _PollSectionCard extends StatelessWidget {
  const _PollSectionCard({required this.child, this.padding});

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
        border: Border.all(color: _pollBlockStrongLine),
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
        border: Border(right: BorderSide(color: _pollBlockSoftLine)),
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
        const _PollFieldLabel('newsAdd.poll.mainImage'),
        _DashedImageBox(
          imageUrl: imageUrl,
          onPickImage: onPickImage,
          onPickUrl: onPickUrl,
          onClear: onClear,
          height: _pollBlockVisualHeight,
        ),
      ],
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
        const _PollFieldLabel('newsAdd.poll.description'),
        _PollRichTextEditor(
          controller: controller,
          placeholder: 'newsAdd.poll.descriptionHint',
          bodyHeight: _pollDescriptionBodyHeight,
        ),
      ],
    );
  }
}

class _PollRichTextEditor extends StatelessWidget {
  const _PollRichTextEditor({
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
        border: Border.all(color: _pollBlockStrongLine),
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

class _AnswerLayoutSelector extends StatelessWidget {
  const _AnswerLayoutSelector({
    required this.layout,
    required this.onLayoutChanged,
  });

  final PollQuestionAnswerLayout layout;
  final ValueChanged<PollQuestionAnswerLayout> onLayoutChanged;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.t('newsAdd.poll.answerFormat'),
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
                  icon: Symbols.grid_view_outlined,
                  selected: layout == PollQuestionAnswerLayout.grid2,
                  onTap: () => onLayoutChanged(PollQuestionAnswerLayout.grid2),
                ),
                _LayoutOption(
                  icon: Symbols.window_outlined,
                  selected: layout == PollQuestionAnswerLayout.grid3,
                  onTap: () => onLayoutChanged(PollQuestionAnswerLayout.grid3),
                ),
                _LayoutOption(
                  icon: Symbols.view_list_outlined,
                  selected: layout == PollQuestionAnswerLayout.list,
                  onTap: () => onLayoutChanged(PollQuestionAnswerLayout.list),
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
    required this.layout,
    required this.onImageChanged,
    required this.onRemoveAnswer,
  });

  final List<PollQuestionAnswerEntry> answers;
  final PollQuestionAnswerLayout layout;
  final void Function(PollQuestionAnswerEntry answer, String? imageUrl)
  onImageChanged;
  final ValueChanged<PollQuestionAnswerEntry> onRemoveAnswer;

  @override
  Widget build(BuildContext context) {
    if (answers.isEmpty) return const SizedBox.shrink();

    if (layout == PollQuestionAnswerLayout.list) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < answers.length; i++) ...[
            _PollAnswerCard(
              index: i + 1,
              entry: answers[i],
              showImage: false,
              canRemove: answers.length > 1,
              onImageChanged: (imageUrl) =>
                  onImageChanged(answers[i], imageUrl),
              onRemove: () => onRemoveAnswer(answers[i]),
            ),
            if (i != answers.length - 1) const SizedBox(height: 10),
          ],
        ],
      );
    }

    final columnCount = layout == PollQuestionAnswerLayout.grid3 ? 3 : 2;
    final rows = <Widget>[];
    for (var start = 0; start < answers.length; start += columnCount) {
      final end = (start + columnCount).clamp(0, answers.length);
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = start; i < end; i++) ...[
              Expanded(
                child: _PollAnswerCard(
                  index: i + 1,
                  entry: answers[i],
                  showImage: true,
                  canRemove: answers.length > 1,
                  onImageChanged: (imageUrl) =>
                      onImageChanged(answers[i], imageUrl),
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

class _PollAnswerCard extends StatefulWidget {
  const _PollAnswerCard({
    required this.index,
    required this.entry,
    required this.showImage,
    required this.canRemove,
    required this.onImageChanged,
    required this.onRemove,
  });

  final int index;
  final PollQuestionAnswerEntry entry;
  final bool showImage;
  final bool canRemove;
  final ValueChanged<String?> onImageChanged;
  final VoidCallback onRemove;

  @override
  State<_PollAnswerCard> createState() => _PollAnswerCardState();
}

class _PollAnswerCardState extends State<_PollAnswerCard> {
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
              border: Border.all(color: _pollBlockStrongLine),
              boxShadow: [
                BoxShadow(
                  color: AppColors.deepOcean.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: widget.showImage
                ? _buildImageAnswer(context)
                : _buildListAnswer(context),
          ),
          if (widget.canRemove && _isHovered)
            Positioned(
              top: widget.showImage ? -9 : 15,
              right: widget.showImage ? -9 : 10,
              child: _AnswerDeleteButton(onPressed: widget.onRemove),
            ),
        ],
      ),
    );
  }

  Widget _buildImageAnswer(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
          showTopBorder: true,
        ),
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: _pollBlockStrongLine)),
          ),
          alignment: Alignment.centerLeft,
          child: _VoteInput(
            controller: widget.entry.votesController,
            width: 96,
          ),
        ),
      ],
    );
  }

  Widget _buildListAnswer(BuildContext context) {
    return SizedBox(
      height: 54,
      child: Row(
        children: [
          Container(
            width: 44,
            height: double.infinity,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFF3F6F8),
              border: Border(right: BorderSide(color: _pollBlockStrongLine)),
            ),
            child: Text(
              '#${widget.index}',
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
                controller: widget.entry.answerController,
                cursorColor: AppColors.deepOcean,
                style: const TextStyle(
                  color: AppColors.deepOcean,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: context.t('newsAdd.poll.answerHintLong'),
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
          _VoteInput(controller: widget.entry.votesController, width: 90),
          SizedBox(width: widget.canRemove ? 44 : 14),
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
  });

  final int index;
  final TextEditingController controller;
  final bool showTopBorder;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        border: Border(
          top: showTopBorder
              ? const BorderSide(color: _pollBlockStrongLine)
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
              border: Border(right: BorderSide(color: _pollBlockStrongLine)),
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
                  hintText: context.t('newsAdd.poll.answerHintShort'),
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
        ],
      ),
    );
  }
}

class _VoteInput extends StatelessWidget {
  const _VoteInput({required this.controller, required this.width});

  final TextEditingController controller;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 34,
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          const SizedBox(width: 10),
          const Icon(
            Symbols.group_outlined,
            size: 13,
            color: AppColors.iconMuted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              cursorColor: AppColors.deepOcean,
              style: const TextStyle(
                color: AppColors.deepOcean,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _DashedImageBox extends StatelessWidget {
  const _DashedImageBox({
    required this.imageUrl,
    required this.onPickImage,
    required this.onPickUrl,
    required this.onClear,
    required this.height,
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
        color: _pollBlockStrongLine,
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
              const Icon(Symbols.add, color: _pollBlockUploadInk, size: 32),
              const SizedBox(height: 8),
              Text(
                context.t('newsAdd.imageSelect'),
                style: const TextStyle(
                  color: _pollBlockUploadInk,
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
            border: Border.all(color: _pollBlockStrongLine),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Symbols.public, size: 13, color: AppColors.deepOcean),
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
            border: Border.all(color: _pollBlockStrongLine),
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
                      padding: const EdgeInsets.only(top: 12, bottom: 12),
                      child: _PollTextInputBox(
                        controller: sourceController,
                        hintTextKey: 'newsAdd.imageCreditHint',
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
                        color: _pollBlockMutedText.withValues(alpha: 0.72),
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
                      color: _pollBlockMutedText.withValues(alpha: 0.72),
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

class _PollTextInputBox extends StatelessWidget {
  const _PollTextInputBox({
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
        border: Border.all(color: _pollBlockStrongLine),
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

class _PollFieldLabel extends StatelessWidget {
  const _PollFieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(
        context.t(text),
        style: const TextStyle(
          color: _pollBlockMutedText,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _PollCompactAddButton extends StatelessWidget {
  const _PollCompactAddButton({required this.label, required this.onPressed});

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
                    Symbols.add_rounded,
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
            child: const Icon(Symbols.close, size: 14, color: Colors.white),
          ),
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
