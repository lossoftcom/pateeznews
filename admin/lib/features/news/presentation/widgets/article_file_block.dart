import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

import '../../../../core/localization/admin_language_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../shared/data/media_service.dart';
import '../../../../shared/widgets/admin_rich_text_editor.dart'
    show adminEmptyQuillDeltaJson, adminQuillDocumentFromJson;
import '../../../../shared/widgets/media_library_dialog.dart';
import 'news_link_opener.dart';

const _fileBlockStrongLine = Color(0xFFDDE5E8);
const _fileBlockSoftLine = Color(0xFFE8EEF1);
const _fileBlockMutedText = Color(0xFF5F6F78);
const _fileBlockUploadInk = Color(0xFF6D7B83);

class ArticleFileBlockEntry {
  ArticleFileBlockEntry()
    : titleController = TextEditingController(),
      sourceController = TextEditingController(),
      descriptionController = quill.QuillController(
        document: adminQuillDocumentFromJson(adminEmptyQuillDeltaJson),
        selection: const TextSelection.collapsed(offset: 0),
      );

  final TextEditingController titleController;
  final TextEditingController sourceController;
  final quill.QuillController descriptionController;
  String? mediaUrl;
  var showOnHomepage = false;
  var extraSettingsExpanded = false;

  void dispose() {
    titleController.dispose();
    sourceController.dispose();
    descriptionController.dispose();
  }
}

class ArticleFileBlockCard extends StatelessWidget {
  const ArticleFileBlockCard({
    super.key,
    required this.blockTitleController,
    required this.sourceController,
    required this.descriptionController,
    required this.mediaUrl,
    required this.blockNumber,
    required this.showOnHomepage,
    required this.extraSettingsExpanded,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onFileChanged,
    required this.onShowOnHomepageChanged,
    required this.onToggleExtraSettings,
  });

  final TextEditingController blockTitleController;
  final TextEditingController sourceController;
  final quill.QuillController descriptionController;
  final String? mediaUrl;
  final int? blockNumber;
  final bool showOnHomepage;
  final bool extraSettingsExpanded;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onDelete;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final ValueChanged<String?> onFileChanged;
  final ValueChanged<bool> onShowOnHomepageChanged;
  final VoidCallback onToggleExtraSettings;

  Future<void> _pickFile(BuildContext context) async {
    final selected = await showMediaLibraryDialog(context, type: 'file');
    final normalized = selected?.trim();
    if (normalized == null || normalized.isEmpty) return;
    onFileChanged(normalized);
  }

  Future<void> _pickFileUrl(BuildContext context) async {
    final selected = await showUrlFileDialog(context);
    final normalized = selected?.trim();
    if (normalized == null || normalized.isEmpty) return;
    onFileChanged(normalized);
  }

  @override
  Widget build(BuildContext context) {
    return _FileSectionCard(
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
                          Icons.attach_file_rounded,
                          color: AppColors.deepOcean,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          context.t('newsAdd.fileBlock'),
                          style: const TextStyle(
                            color: AppColors.deepOcean,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      _HomepageToggle(
                        value: showOnHomepage,
                        onChanged: onShowOnHomepageChanged,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(height: 1, color: _fileBlockSoftLine),
                  const SizedBox(height: 20),
                  const _FileFieldLabel('newsAdd.imageBlockTitle'),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (blockNumber != null) ...[
                          _BlockNumberBadge(blockNumber!),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: _FileTextInputBox(
                            controller: blockTitleController,
                            hintTextKey: 'newsAdd.imageBlockTitleHint',
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
                      final filePanel = _FilePanel(
                        mediaUrl: mediaUrl,
                        onPickFile: () => _pickFile(context),
                        onPickUrl: () => _pickFileUrl(context),
                        onClear: () => onFileChanged(null),
                      );
                      final descriptionPanel = _DescriptionPanel(
                        controller: descriptionController,
                      );

                      if (compact) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            filePanel,
                            const SizedBox(height: 16),
                            descriptionPanel,
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 7, child: filePanel),
                          const SizedBox(width: 24),
                          Expanded(flex: 10, child: descriptionPanel),
                        ],
                      );
                    },
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

class _FileSectionCard extends StatelessWidget {
  const _FileSectionCard({required this.child, this.padding});

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
        border: Border.all(color: _fileBlockStrongLine),
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
        border: Border(right: BorderSide(color: _fileBlockSoftLine)),
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

class _FilePanel extends StatelessWidget {
  const _FilePanel({
    required this.mediaUrl,
    required this.onPickFile,
    required this.onPickUrl,
    required this.onClear,
  });

  final String? mediaUrl;
  final VoidCallback onPickFile;
  final VoidCallback onPickUrl;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final selectedUrl = mediaUrl?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FileFieldLabel('newsAdd.filePanel'),
        CustomPaint(
          painter: _DashedBorderPainter(
            color: _fileBlockStrongLine,
            radius: AppRadius.value,
          ),
          child: Container(
            height: 252,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(AppRadius.value),
            ),
            child: selectedUrl == null || selectedUrl.isEmpty
                ? _EmptyFilePicker(onPickFile: onPickFile, onPickUrl: onPickUrl)
                : _SelectedFilePreview(
                    mediaUrl: selectedUrl,
                    onPickFile: onPickFile,
                    onClear: onClear,
                  ),
          ),
        ),
      ],
    );
  }
}

class _EmptyFilePicker extends StatelessWidget {
  const _EmptyFilePicker({required this.onPickFile, required this.onPickUrl});

  final VoidCallback onPickFile;
  final VoidCallback onPickUrl;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPickFile,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 62,
                height: 62,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.deepOcean.withValues(alpha: 0.04),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add,
                  color: _fileBlockUploadInk,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                context.t('newsAdd.filePickUpload'),
                style: const TextStyle(
                  color: AppColors.deepOcean,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 18),
              const Wrap(
                spacing: 6,
                runSpacing: 5,
                alignment: WrapAlignment.center,
                children: [
                  _FileFormatChip('PDF'),
                  _FileFormatChip('DOCX'),
                  _FileFormatChip('XLSX'),
                  _FileFormatChip('PPTX'),
                ],
              ),
              const SizedBox(height: 18),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onPickUrl,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.value),
                      border: Border.all(color: _fileBlockStrongLine),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.deepOcean.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.link_rounded,
                          size: 13,
                          color: AppColors.deepOcean,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          context.t('newsAdd.fileUrlUpload'),
                          style: const TextStyle(
                            color: AppColors.deepOcean,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FileFormatChip extends StatelessWidget {
  const _FileFormatChip(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: _fileBlockStrongLine),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: _fileBlockMutedText.withValues(alpha: 0.52),
          fontSize: 8.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _SelectedFilePreview extends StatefulWidget {
  const _SelectedFilePreview({
    required this.mediaUrl,
    required this.onPickFile,
    required this.onClear,
  });

  final String mediaUrl;
  final VoidCallback onPickFile;
  final VoidCallback onClear;

  @override
  State<_SelectedFilePreview> createState() => _SelectedFilePreviewState();
}

class _SelectedFilePreviewState extends State<_SelectedFilePreview> {
  var _hover = false;

  void _openFile() {
    unawaited(openNewsLink(_displayFileUrl(widget.mediaUrl)));
  }

  @override
  Widget build(BuildContext context) {
    final fileName = _fileNameFromUrl(widget.mediaUrl);
    final extension = _extensionFromUrl(widget.mediaUrl).toUpperCase();
    final accent = _fileAccent(extension);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 270),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _FileIconTile(extension: extension, accent: accent),
                    const SizedBox(height: 14),
                    Text(
                      fileName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.deepOcean,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$extension ${context.t('media.assetLabel')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _fileBlockMutedText.withValues(alpha: 0.58),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(child: _FileViewButton(onTap: _openFile)),
                        const SizedBox(width: 8),
                        _FileSquareActionButton(
                          icon: Icons.delete_outline,
                          color: AppColors.actionRed,
                          onTap: widget.onClear,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IgnorePointer(
                ignoring: !_hover,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 120),
                  opacity: _hover ? 1 : 0,
                  child: _FileSquareActionButton(
                    icon: Icons.edit_outlined,
                    onTap: widget.onPickFile,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FileIconTile extends StatelessWidget {
  const _FileIconTile({required this.extension, required this.accent});

  final String extension;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 78,
          height: 78,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _fileBlockStrongLine),
            boxShadow: [
              BoxShadow(
                color: AppColors.deepOcean.withValues(alpha: 0.10),
                blurRadius: 16,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Icon(_fileIcon(extension), color: accent, size: 38),
        ),
        Positioned(
          right: -7,
          bottom: -7,
          child: Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.deepOcean,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.deepOcean.withValues(alpha: 0.18),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.download_rounded,
              color: Colors.white,
              size: 14,
            ),
          ),
        ),
      ],
    );
  }
}

class _FileViewButton extends StatelessWidget {
  const _FileViewButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.value),
            border: Border.all(color: _fileBlockStrongLine),
            boxShadow: [
              BoxShadow(
                color: AppColors.deepOcean.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.open_in_new_rounded,
                color: AppColors.deepOcean,
                size: 13,
              ),
              const SizedBox(width: 7),
              Text(
                context.t('newsAdd.fileView').toUpperCase(),
                style: const TextStyle(
                  color: AppColors.deepOcean,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
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

class _FileSquareActionButton extends StatelessWidget {
  const _FileSquareActionButton({
    required this.icon,
    required this.onTap,
    this.color = AppColors.deepOcean,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(
              alpha: color == AppColors.actionRed ? 0.08 : 0.06,
            ),
            borderRadius: BorderRadius.circular(AppRadius.value),
            border: Border.all(color: color.withValues(alpha: 0.12)),
          ),
          child: Icon(icon, size: 17, color: color),
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
        const _FileFieldLabel('newsAdd.fileDescription'),
        _FileRichTextEditor(
          controller: controller,
          placeholder: 'newsAdd.fileDescriptionHint',
          bodyHeight: 172,
        ),
      ],
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
                      child: _FileTextInputBox(
                        controller: sourceController,
                        hintTextKey: 'newsAdd.fileCreditHint',
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
                        color: _fileBlockMutedText.withValues(alpha: 0.72),
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
                      color: _fileBlockMutedText.withValues(alpha: 0.72),
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

class _FileRichTextEditor extends StatelessWidget {
  const _FileRichTextEditor({
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
        border: Border.all(color: _fileBlockStrongLine),
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

class _FileTextInputBox extends StatelessWidget {
  const _FileTextInputBox({
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
        border: Border.all(color: _fileBlockStrongLine),
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

class _FileFieldLabel extends StatelessWidget {
  const _FileFieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(
        context.t(text),
        style: const TextStyle(
          color: _fileBlockMutedText,
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
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      const dashWidth = 6.0;
      const dashSpace = 4.0;
      while (distance < metric.length) {
        final next = (distance + dashWidth).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

String _displayFileUrl(String value) {
  final trimmed = value.trim();
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return trimmed;
  }
  return MediaService().resolveUrl(trimmed);
}

String _fileNameFromUrl(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';
  final uri = Uri.tryParse(trimmed);
  final rawPath = uri != null && uri.path.trim().isNotEmpty
      ? uri.path
      : trimmed;
  final segments = rawPath.split('/').where((part) => part.isNotEmpty).toList();
  final rawName = segments.isNotEmpty
      ? segments.last
      : (uri != null && uri.host.isNotEmpty ? uri.host : trimmed);
  return _safeDecode(rawName.split('?').first);
}

String _extensionFromUrl(String value) {
  final fileName = _fileNameFromUrl(value);
  final dot = fileName.lastIndexOf('.');
  if (dot < 0 || dot == fileName.length - 1) return 'FILE';
  return fileName.substring(dot + 1);
}

String _safeDecode(String value) {
  try {
    return Uri.decodeComponent(value);
  } catch (_) {
    return value;
  }
}

IconData _fileIcon(String extension) {
  switch (extension.toLowerCase()) {
    case 'pdf':
      return Icons.description_outlined;
    case 'doc':
    case 'docx':
      return Icons.text_snippet_outlined;
    case 'xls':
    case 'xlsx':
      return Icons.table_chart_outlined;
    case 'ppt':
    case 'pptx':
      return Icons.slideshow_outlined;
    case 'txt':
    case 'md':
      return Icons.article_outlined;
    default:
      return Icons.insert_drive_file_outlined;
  }
}

Color _fileAccent(String extension) {
  switch (extension.toLowerCase()) {
    case 'pdf':
      return AppColors.actionRed;
    case 'doc':
    case 'docx':
      return const Color(0xFF2563EB);
    case 'xls':
    case 'xlsx':
      return const Color(0xFF059669);
    case 'ppt':
    case 'pptx':
      return AppColors.warmHorizon;
    default:
      return AppColors.support;
  }
}
