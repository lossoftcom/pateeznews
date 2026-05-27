import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

import '../../../../core/localization/admin_language_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../shared/data/media_service.dart';
import '../../../../shared/widgets/admin_rich_text_editor.dart'
    show adminEmptyQuillDeltaJson, adminQuillDocumentFromJson;
import '../../../../shared/widgets/media_library_dialog.dart';

const _tocBlockStrongLine = Color(0xFFDDE5E8);
const _tocBlockSoftLine = Color(0xFFE8EEF1);
const _tocBlockMutedText = Color(0xFF5F6F78);
const _tocBlockUploadInk = Color(0xFF6D7B83);
const _tocBlockEditorChrome = Color(0xFFFBF7F1);
const _tocBlockEditorLine = Color(0x298C6D53);
const _tocBlockVisualHeight = 220.0;
const _tocBlockEditorBodyHeight = 192.0;

const tocListStyleOptions = <String>[
  'none',
  'decimal',
  'decimal-leading-zero',
  'circle',
  'disc',
  'square',
  'lower-alpha',
  'upper-alpha',
  'lower-roman',
  'upper-roman',
];

const _tocListStyleLabelKeys = <String, String>{
  'none': 'newsAdd.toc.styleNone',
  'decimal': 'newsAdd.toc.styleDecimal',
  'decimal-leading-zero': 'newsAdd.toc.styleDecimalLeadingZero',
  'circle': 'newsAdd.toc.styleCircle',
  'disc': 'newsAdd.toc.styleDisc',
  'square': 'newsAdd.toc.styleSquare',
  'lower-alpha': 'newsAdd.toc.styleLowerAlpha',
  'upper-alpha': 'newsAdd.toc.styleUpperAlpha',
  'lower-roman': 'newsAdd.toc.styleLowerRoman',
  'upper-roman': 'newsAdd.toc.styleUpperRoman',
};

class TocBlockEntry {
  TocBlockEntry();

  var level1Style = 'none';
  var level2Style = 'none';
  var level3Style = 'none';
  var showLevel1InText = false;
  var showLevel2InText = false;
  var showLevel3InText = false;
  final items = <TocItemEntry>[TocItemEntry()];

  String styleForLevel(int level) {
    return switch (level) {
      1 => level1Style,
      2 => level2Style,
      _ => level3Style,
    };
  }

  void setStyleForLevel(int level, String value) {
    switch (level) {
      case 1:
        level1Style = value;
      case 2:
        level2Style = value;
      default:
        level3Style = value;
    }
  }

  bool showStyleForLevel(int level) {
    return switch (level) {
      1 => showLevel1InText,
      2 => showLevel2InText,
      _ => showLevel3InText,
    };
  }

  void setShowStyleForLevel(int level, bool value) {
    switch (level) {
      case 1:
        showLevel1InText = value;
      case 2:
        showLevel2InText = value;
      default:
        showLevel3InText = value;
    }
  }

  void dispose() {
    for (final item in items) {
      item.dispose();
    }
  }
}

class TocItemEntry {
  TocItemEntry()
    : titleController = TextEditingController(),
      parentLinkController = TextEditingController(),
      imageDescriptionController = TextEditingController(),
      contentController = quill.QuillController(
        document: adminQuillDocumentFromJson(adminEmptyQuillDeltaJson),
        selection: const TextSelection.collapsed(offset: 0),
      );

  final TextEditingController titleController;
  final TextEditingController parentLinkController;
  final TextEditingController imageDescriptionController;
  final quill.QuillController contentController;
  String? imageUrl;
  var collapsed = false;

  void dispose() {
    titleController.dispose();
    parentLinkController.dispose();
    imageDescriptionController.dispose();
    contentController.dispose();
  }
}

class ArticleTableOfContentsBlockCard extends StatelessWidget {
  const ArticleTableOfContentsBlockCard({
    super.key,
    required this.entry,
    required this.onStyleChanged,
    required this.onShowStyleChanged,
    required this.onAddItem,
    required this.onRemoveItem,
    required this.onMoveItem,
    required this.onToggleItemCollapsed,
    required this.onItemImageChanged,
  });

  final TocBlockEntry entry;
  final void Function(int level, String value) onStyleChanged;
  final void Function(int level, bool value) onShowStyleChanged;
  final VoidCallback onAddItem;
  final ValueChanged<TocItemEntry> onRemoveItem;
  final void Function(TocItemEntry item, int delta) onMoveItem;
  final ValueChanged<TocItemEntry> onToggleItemCollapsed;
  final void Function(TocItemEntry item, String? imageUrl) onItemImageChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TocSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TocSectionHeader(
                icon: Icons.format_list_bulleted,
                title: 'newsAdd.toc.blockTitle',
                subtitle: 'newsAdd.toc.blockDescription',
              ),
              const SizedBox(height: 20),
              _LinkStylePanel(
                entry: entry,
                onStyleChanged: onStyleChanged,
                onShowStyleChanged: onShowStyleChanged,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        for (var i = 0; i < entry.items.length; i++) ...[
          _TocItemCard(
            item: entry.items[i],
            index: i,
            totalItems: entry.items.length,
            onRemove: () => onRemoveItem(entry.items[i]),
            onMoveUp: () => onMoveItem(entry.items[i], -1),
            onMoveDown: () => onMoveItem(entry.items[i], 1),
            onToggleCollapsed: () => onToggleItemCollapsed(entry.items[i]),
            onImageChanged: (imageUrl) =>
                onItemImageChanged(entry.items[i], imageUrl),
          ),
          if (i != entry.items.length - 1) const SizedBox(height: 18),
        ],
        const SizedBox(height: 18),
        _TocAddButton(label: 'newsAdd.toc.addItem', onTap: onAddItem),
      ],
    );
  }
}

class _LinkStylePanel extends StatelessWidget {
  const _LinkStylePanel({
    required this.entry,
    required this.onStyleChanged,
    required this.onShowStyleChanged,
  });

  final TocBlockEntry entry;
  final void Function(int level, String value) onStyleChanged;
  final void Function(int level, bool value) onShowStyleChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.format_list_numbered,
              size: 17,
              color: _tocBlockMutedText,
            ),
            const SizedBox(width: 8),
            Text(
              context.t('newsAdd.toc.linkListStyle'),
              style: const TextStyle(
                color: _tocBlockMutedText,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 760;
            final controls = [
              _LevelStyleControl(
                label: 'newsAdd.toc.level1',
                value: entry.level1Style,
                showInText: entry.showLevel1InText,
                onStyleChanged: (value) => onStyleChanged(1, value),
                onShowChanged: (value) => onShowStyleChanged(1, value),
              ),
              _LevelStyleControl(
                label: 'newsAdd.toc.level2',
                value: entry.level2Style,
                showInText: entry.showLevel2InText,
                onStyleChanged: (value) => onStyleChanged(2, value),
                onShowChanged: (value) => onShowStyleChanged(2, value),
              ),
              _LevelStyleControl(
                label: 'newsAdd.toc.level3',
                value: entry.level3Style,
                showInText: entry.showLevel3InText,
                onStyleChanged: (value) => onStyleChanged(3, value),
                onShowChanged: (value) => onShowStyleChanged(3, value),
              ),
            ];

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < controls.length; i++) ...[
                    controls[i],
                    if (i != controls.length - 1) const SizedBox(height: 14),
                  ],
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < controls.length; i++) ...[
                  Expanded(child: controls[i]),
                  if (i != controls.length - 1) const SizedBox(width: 16),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _LevelStyleControl extends StatelessWidget {
  const _LevelStyleControl({
    required this.label,
    required this.value,
    required this.showInText,
    required this.onStyleChanged,
    required this.onShowChanged,
  });

  final String label;
  final String value;
  final bool showInText;
  final ValueChanged<String> onStyleChanged;
  final ValueChanged<bool> onShowChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.t(label),
          style: const TextStyle(
            color: _tocBlockMutedText,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        _TocStyleSelect(value: value, onChanged: onStyleChanged),
        const SizedBox(height: 8),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onShowChanged(!showInText),
            child: Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: Checkbox(
                    value: showInText,
                    onChanged: (value) => onShowChanged(value ?? false),
                    activeColor: AppColors.deepOcean,
                    side: const BorderSide(color: _tocBlockStrongLine),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.t('newsAdd.toc.showStyleInText'),
                    style: const TextStyle(
                      color: AppColors.deepOcean,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TocStyleSelect extends StatelessWidget {
  const _TocStyleSelect({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.value),
        border: Border.all(color: _tocBlockStrongLine),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down,
            size: 18,
            color: _tocBlockMutedText,
          ),
          style: const TextStyle(
            color: AppColors.deepOcean,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.value),
          items: [
            for (final option in tocListStyleOptions)
              DropdownMenuItem(
                value: option,
                child: Text(context.t(_tocListStyleLabelKeys[option]!)),
              ),
          ],
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
        ),
      ),
    );
  }
}

class _TocItemCard extends StatelessWidget {
  const _TocItemCard({
    required this.item,
    required this.index,
    required this.totalItems,
    required this.onRemove,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onToggleCollapsed,
    required this.onImageChanged,
  });

  final TocItemEntry item;
  final int index;
  final int totalItems;
  final VoidCallback onRemove;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onToggleCollapsed;
  final ValueChanged<String?> onImageChanged;

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
    final displayNumber = index + 1;
    return _TocSectionCard(
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
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.actionRed.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(AppRadius.value),
                        ),
                        child: const Icon(
                          Icons.format_list_numbered,
                          color: AppColors.actionRed,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${context.t('newsAdd.toc.item')} #$displayNumber',
                          style: const TextStyle(
                            color: AppColors.deepOcean,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      _TocCollapseButton(
                        collapsed: item.collapsed,
                        onTap: onToggleCollapsed,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(height: 1, color: _tocBlockSoftLine),
                  if (!item.collapsed) ...[
                    const SizedBox(height: 20),
                    _TocTitleParentRow(
                      item: item,
                      displayNumber: displayNumber,
                    ),
                    const SizedBox(height: 18),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxWidth < 760;
                        final imagePanel = _TocImagePanel(
                          imageUrl: item.imageUrl,
                          imageDescriptionController:
                              item.imageDescriptionController,
                          onPickImage: () => _pickImage(context),
                          onPickUrl: () => _pickUrl(context),
                          onClear: () => onImageChanged(null),
                        );
                        final contentPanel = _TocContentPanel(
                          controller: item.contentController,
                        );

                        if (compact) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              imagePanel,
                              const SizedBox(height: 16),
                              contentPanel,
                            ],
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 5, child: imagePanel),
                            const SizedBox(width: 24),
                            Expanded(flex: 10, child: contentPanel),
                          ],
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: _TocActionRail(
              canMoveUp: index > 0,
              canMoveDown: index < totalItems - 1,
              canDelete: totalItems > 1,
              onDelete: onRemove,
              onMoveUp: onMoveUp,
              onMoveDown: onMoveDown,
            ),
          ),
        ],
      ),
    );
  }
}

class _TocTitleParentRow extends StatelessWidget {
  const _TocTitleParentRow({required this.item, required this.displayNumber});

  final TocItemEntry item;
  final int displayNumber;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final titleField = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _TocFieldLabel('newsAdd.toc.itemTitle'),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TocNumberBadge(displayNumber),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _TocTextInputBox(
                      controller: item.titleController,
                      hintTextKey: 'newsAdd.toc.itemTitleHint',
                      fontSize: 13,
                      bold: true,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
        final parentField = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _TocFieldLabel('newsAdd.toc.parentLink'),
            _TocTextInputBox(
              controller: item.parentLinkController,
              hintTextKey: 'newsAdd.toc.parentLinkHint',
              fontSize: 13,
              bold: true,
            ),
          ],
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [titleField, const SizedBox(height: 14), parentField],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: titleField),
            const SizedBox(width: 16),
            SizedBox(width: 220, child: parentField),
          ],
        );
      },
    );
  }
}

class _TocImagePanel extends StatelessWidget {
  const _TocImagePanel({
    required this.imageUrl,
    required this.imageDescriptionController,
    required this.onPickImage,
    required this.onPickUrl,
    required this.onClear,
  });

  final String? imageUrl;
  final TextEditingController imageDescriptionController;
  final VoidCallback onPickImage;
  final VoidCallback onPickUrl;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _TocFieldLabel('newsAdd.toc.itemImage'),
        _TocDashedImageBox(
          imageUrl: imageUrl,
          onPickImage: onPickImage,
          onPickUrl: onPickUrl,
          onClear: onClear,
        ),
        const SizedBox(height: 10),
        _TocTextInputBox(
          controller: imageDescriptionController,
          hintTextKey: 'newsAdd.toc.imageDescriptionHint',
          fontSize: 12.5,
        ),
      ],
    );
  }
}

class _TocContentPanel extends StatelessWidget {
  const _TocContentPanel({required this.controller});

  final quill.QuillController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _TocFieldLabel('newsAdd.toc.itemContent'),
        _TocRichTextEditor(
          controller: controller,
          placeholder: 'newsAdd.toc.itemContentHint',
        ),
      ],
    );
  }
}

class _TocActionRail extends StatelessWidget {
  const _TocActionRail({
    required this.canMoveUp,
    required this.canMoveDown,
    required this.canDelete,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final bool canMoveUp;
  final bool canMoveDown;
  final bool canDelete;
  final VoidCallback onDelete;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: _tocBlockSoftLine)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          _TocRailIconButton(
            icon: Icons.keyboard_arrow_up,
            active: canMoveUp,
            onTap: onMoveUp,
          ),
          const SizedBox(height: 8),
          _TocRailIconButton(
            icon: Icons.keyboard_arrow_down,
            active: canMoveDown,
            onTap: onMoveDown,
          ),
          const Spacer(),
          _TocRailIconButton(
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

class _TocRailIconButton extends StatelessWidget {
  const _TocRailIconButton({
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

class _TocCollapseButton extends StatelessWidget {
  const _TocCollapseButton({required this.collapsed, required this.onTap});

  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(
            collapsed ? Icons.keyboard_arrow_left : Icons.keyboard_arrow_down,
            size: 22,
            color: _tocBlockMutedText,
          ),
        ),
      ),
    );
  }
}

class _TocSectionHeader extends StatelessWidget {
  const _TocSectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _tocBlockSoftLine)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.deepOcean.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(AppRadius.value),
            ),
            child: Icon(icon, color: AppColors.deepOcean, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t(title),
                  style: const TextStyle(
                    color: AppColors.deepOcean,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  context.t(subtitle),
                  style: TextStyle(
                    color: _tocBlockMutedText.withValues(alpha: 0.78),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
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

class _TocSectionCard extends StatelessWidget {
  const _TocSectionCard({required this.child, this.padding});

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
        border: Border.all(color: _tocBlockStrongLine),
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

class _TocFieldLabel extends StatelessWidget {
  const _TocFieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(
        context.t(text),
        style: const TextStyle(
          color: _tocBlockMutedText,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _TocNumberBadge extends StatelessWidget {
  const _TocNumberBadge(this.number);

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

class _TocTextInputBox extends StatelessWidget {
  const _TocTextInputBox({
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
        border: Border.all(color: _tocBlockStrongLine),
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

class _TocDashedImageBox extends StatelessWidget {
  const _TocDashedImageBox({
    required this.imageUrl,
    required this.onPickImage,
    required this.onPickUrl,
    required this.onClear,
  });

  final String? imageUrl;
  final VoidCallback onPickImage;
  final VoidCallback onPickUrl;
  final VoidCallback onClear;

  String _resolvedImageUrl(String value) {
    if (value.startsWith('http')) return value;
    return MediaService().resolveImageUrl(value, width: 720, quality: 90);
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _TocDashedBorderPainter(
        color: _tocBlockStrongLine,
        radius: AppRadius.value,
      ),
      child: Container(
        height: _tocBlockVisualHeight,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(AppRadius.value),
        ),
        child: imageUrl == null
            ? _TocEmptyImagePicker(
                onPickImage: onPickImage,
                onPickUrl: onPickUrl,
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Image.network(
                      _resolvedImageUrl(imageUrl!),
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      cacheWidth: 720,
                      gaplessPlayback: true,
                      errorBuilder: (_, _, _) => _TocEmptyImagePicker(
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
                        _TocImageActionButton(
                          icon: Icons.edit_outlined,
                          color: AppColors.deepOcean,
                          onTap: onPickImage,
                        ),
                        const SizedBox(width: 8),
                        _TocImageActionButton(
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

class _TocEmptyImagePicker extends StatelessWidget {
  const _TocEmptyImagePicker({
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
              const Icon(Icons.add, color: _tocBlockUploadInk, size: 32),
              const SizedBox(height: 8),
              Text(
                context.t('newsAdd.imageSelect'),
                style: const TextStyle(
                  color: _tocBlockUploadInk,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 12),
              _TocUrlUploadButton(onTap: onPickUrl),
            ],
          ),
        ),
      ),
    );
  }
}

class _TocUrlUploadButton extends StatelessWidget {
  const _TocUrlUploadButton({required this.onTap});

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
            border: Border.all(color: _tocBlockStrongLine),
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

class _TocImageActionButton extends StatelessWidget {
  const _TocImageActionButton({
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
            border: Border.all(color: _tocBlockStrongLine),
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

class _TocRichTextEditor extends StatelessWidget {
  const _TocRichTextEditor({
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
        border: Border.all(color: _tocBlockStrongLine),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: const BoxDecoration(
              color: _tocBlockEditorChrome,
              border: Border(bottom: BorderSide(color: _tocBlockEditorLine)),
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
            height: _tocBlockEditorBodyHeight,
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

class _TocAddButton extends StatelessWidget {
  const _TocAddButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: CustomPaint(
            painter: _TocDashedBorderPainter(
              color: AppColors.actionRed.withValues(alpha: 0.34),
              radius: AppRadius.value,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.actionRed.withValues(alpha: 0.045),
                borderRadius: BorderRadius.circular(AppRadius.value),
              ),
              child: Text(
                '+ ${context.t(label)}',
                style: const TextStyle(
                  color: AppColors.actionRed,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TocDashedBorderPainter extends CustomPainter {
  const _TocDashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      const dashWidth = 6.0;
      const dashGap = 5.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + dashWidth),
          paint,
        );
        distance += dashWidth + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TocDashedBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}
