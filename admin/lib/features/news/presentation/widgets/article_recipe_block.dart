import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

import '../../../../core/localization/admin_language_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../shared/data/media_service.dart';
import '../../../../shared/widgets/admin_rich_text_editor.dart'
    show adminEmptyQuillDeltaJson, adminQuillDocumentFromJson;
import '../../../../shared/widgets/media_library_dialog.dart';

const _recipeBlockStrongLine = Color(0xFFDDE5E8);
const _recipeBlockSoftLine = Color(0xFFE8EEF1);
const _recipeBlockMutedText = Color(0xFF5F6F78);
const _recipeBlockUploadInk = Color(0xFF6D7B83);
const _recipeBlockVisualHeight = 220.0;
const _recipeBlockEditorBodyHeight = 192.0;

class RecipeBlockEntry {
  RecipeBlockEntry()
    : prepTimeController = TextEditingController(),
      cookTimeController = TextEditingController(),
      servingController = TextEditingController();

  final TextEditingController prepTimeController;
  final TextEditingController cookTimeController;
  final TextEditingController servingController;
  String difficulty = '';
  final ingredients = <RecipeIngredientEntry>[RecipeIngredientEntry()];
  final nutrition = <RecipeNutritionEntry>[RecipeNutritionEntry()];
  final directions = <RecipeDirectionEntry>[RecipeDirectionEntry()];

  void dispose() {
    prepTimeController.dispose();
    cookTimeController.dispose();
    servingController.dispose();
    for (final ingredient in ingredients) {
      ingredient.dispose();
    }
    for (final item in nutrition) {
      item.dispose();
    }
    for (final direction in directions) {
      direction.dispose();
    }
  }
}

class RecipeIngredientEntry {
  RecipeIngredientEntry() : textController = TextEditingController();

  final TextEditingController textController;

  void dispose() {
    textController.dispose();
  }
}

class RecipeNutritionEntry {
  RecipeNutritionEntry()
    : labelController = TextEditingController(),
      valueController = TextEditingController();

  final TextEditingController labelController;
  final TextEditingController valueController;

  void dispose() {
    labelController.dispose();
    valueController.dispose();
  }
}

class RecipeDirectionEntry {
  RecipeDirectionEntry()
    : titleController = TextEditingController(),
      imageDescriptionController = TextEditingController(),
      contentController = quill.QuillController(
        document: adminQuillDocumentFromJson(adminEmptyQuillDeltaJson),
        selection: const TextSelection.collapsed(offset: 0),
      );

  final TextEditingController titleController;
  final TextEditingController imageDescriptionController;
  final quill.QuillController contentController;
  String? imageUrl;
  var collapsed = false;

  void dispose() {
    titleController.dispose();
    imageDescriptionController.dispose();
    contentController.dispose();
  }
}

class ArticleRecipeSettingsCard extends StatelessWidget {
  const ArticleRecipeSettingsCard({
    super.key,
    required this.entry,
    required this.onDifficultyChanged,
  });

  final RecipeBlockEntry entry;
  final ValueChanged<String> onDifficultyChanged;

  @override
  Widget build(BuildContext context) {
    return _RecipeSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RecipeSectionHeader(
            icon: Icons.restaurant_outlined,
            title: 'newsAdd.recipe.settingsTitle',
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 820;
              final fields = [
                _RecipeTextFieldControl(
                  label: 'newsAdd.recipe.prepTime',
                  controller: entry.prepTimeController,
                  hintTextKey: 'newsAdd.recipe.prepTimeHint',
                ),
                _RecipeTextFieldControl(
                  label: 'newsAdd.recipe.cookTime',
                  controller: entry.cookTimeController,
                  hintTextKey: 'newsAdd.recipe.cookTimeHint',
                ),
                _RecipeTextFieldControl(
                  label: 'newsAdd.recipe.serving',
                  controller: entry.servingController,
                  hintTextKey: 'newsAdd.recipe.servingHint',
                ),
                _RecipeDifficultyControl(
                  value: entry.difficulty,
                  onChanged: onDifficultyChanged,
                ),
              ];

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < fields.length; i++) ...[
                      fields[i],
                      if (i != fields.length - 1) const SizedBox(height: 14),
                    ],
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < fields.length; i++) ...[
                    Expanded(child: fields[i]),
                    if (i != fields.length - 1) const SizedBox(width: 16),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class ArticleRecipeDetailsCard extends StatelessWidget {
  const ArticleRecipeDetailsCard({
    super.key,
    required this.entry,
    required this.onAddIngredient,
    required this.onRemoveIngredient,
    required this.onAddNutrition,
    required this.onRemoveNutrition,
    required this.onAddDirection,
    required this.onRemoveDirection,
    required this.onMoveDirection,
    required this.onToggleDirectionCollapsed,
    required this.onDirectionImageChanged,
  });

  final RecipeBlockEntry entry;
  final VoidCallback onAddIngredient;
  final ValueChanged<RecipeIngredientEntry> onRemoveIngredient;
  final VoidCallback onAddNutrition;
  final ValueChanged<RecipeNutritionEntry> onRemoveNutrition;
  final VoidCallback onAddDirection;
  final ValueChanged<RecipeDirectionEntry> onRemoveDirection;
  final void Function(RecipeDirectionEntry direction, int delta)
  onMoveDirection;
  final ValueChanged<RecipeDirectionEntry> onToggleDirectionCollapsed;
  final void Function(RecipeDirectionEntry direction, String? imageUrl)
  onDirectionImageChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 780;
            final ingredientsCard = _RecipeIngredientListCard(
              entries: entry.ingredients,
              onAdd: onAddIngredient,
              onRemove: onRemoveIngredient,
            );
            final nutritionCard = _RecipeNutritionListCard(
              entries: entry.nutrition,
              onAdd: onAddNutrition,
              onRemove: onRemoveNutrition,
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ingredientsCard,
                  const SizedBox(height: 18),
                  nutritionCard,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: ingredientsCard),
                const SizedBox(width: 20),
                Expanded(child: nutritionCard),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        for (var i = 0; i < entry.directions.length; i++) ...[
          _RecipeDirectionCard(
            direction: entry.directions[i],
            index: i,
            totalItems: entry.directions.length,
            onRemove: () => onRemoveDirection(entry.directions[i]),
            onMoveUp: () => onMoveDirection(entry.directions[i], -1),
            onMoveDown: () => onMoveDirection(entry.directions[i], 1),
            onToggleCollapsed: () =>
                onToggleDirectionCollapsed(entry.directions[i]),
            onImageChanged: (imageUrl) =>
                onDirectionImageChanged(entry.directions[i], imageUrl),
          ),
          if (i != entry.directions.length - 1) const SizedBox(height: 18),
        ],
        const SizedBox(height: 18),
        _RecipeAddButton(
          label: 'newsAdd.recipe.addDirection',
          onTap: onAddDirection,
        ),
      ],
    );
  }
}

class _RecipeIngredientListCard extends StatelessWidget {
  const _RecipeIngredientListCard({
    required this.entries,
    required this.onAdd,
    required this.onRemove,
  });

  final List<RecipeIngredientEntry> entries;
  final VoidCallback onAdd;
  final ValueChanged<RecipeIngredientEntry> onRemove;

  @override
  Widget build(BuildContext context) {
    return _RecipeSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RecipeListHeader(
            icon: Icons.local_dining_outlined,
            title: 'newsAdd.recipe.ingredients',
            addLabel: 'newsAdd.recipe.addIngredient',
            onAdd: onAdd,
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < entries.length; i++) ...[
            _RecipeIngredientRow(
              entry: entries[i],
              index: i,
              canDelete: entries.length > 1,
              onRemove: () => onRemove(entries[i]),
            ),
            if (i != entries.length - 1) const SizedBox(height: 10),
          ],
          const SizedBox(height: 12),
          Text(
            context.t('newsAdd.recipe.ingredientExample'),
            style: const TextStyle(
              color: AppColors.deepOcean,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipeNutritionListCard extends StatelessWidget {
  const _RecipeNutritionListCard({
    required this.entries,
    required this.onAdd,
    required this.onRemove,
  });

  final List<RecipeNutritionEntry> entries;
  final VoidCallback onAdd;
  final ValueChanged<RecipeNutritionEntry> onRemove;

  @override
  Widget build(BuildContext context) {
    return _RecipeSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RecipeListHeader(
            icon: Icons.egg_alt_outlined,
            title: 'newsAdd.recipe.nutrition',
            addLabel: 'newsAdd.recipe.addNutrition',
            onAdd: onAdd,
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < entries.length; i++) ...[
            _RecipeNutritionRow(
              entry: entries[i],
              canDelete: entries.length > 1,
              onRemove: () => onRemove(entries[i]),
            ),
            if (i != entries.length - 1) const SizedBox(height: 10),
          ],
          const SizedBox(height: 12),
          Text(
            context.t('newsAdd.recipe.nutritionExample'),
            style: const TextStyle(
              color: AppColors.deepOcean,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipeListHeader extends StatelessWidget {
  const _RecipeListHeader({
    required this.icon,
    required this.title,
    required this.addLabel,
    required this.onAdd,
  });

  final IconData icon;
  final String title;
  final String addLabel;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _recipeBlockSoftLine)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.actionRed, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.t(title),
              style: const TextStyle(
                color: AppColors.deepOcean,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ),
          _RecipeSmallAddButton(label: addLabel, onTap: onAdd),
        ],
      ),
    );
  }
}

class _RecipeIngredientRow extends StatelessWidget {
  const _RecipeIngredientRow({
    required this.entry,
    required this.index,
    required this.canDelete,
    required this.onRemove,
  });

  final RecipeIngredientEntry entry;
  final int index;
  final bool canDelete;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RecipeNumberBadge(index + 1),
          const SizedBox(width: 10),
          Expanded(
            child: _RecipeTextInputBox(
              controller: entry.textController,
              hintTextKey: 'newsAdd.recipe.ingredientHint',
              fontSize: 13,
              bold: true,
            ),
          ),
          const SizedBox(width: 8),
          _RecipeTinyIconButton(
            icon: Icons.delete_outline,
            active: canDelete,
            onTap: onRemove,
          ),
        ],
      ),
    );
  }
}

class _RecipeNutritionRow extends StatelessWidget {
  const _RecipeNutritionRow({
    required this.entry,
    required this.canDelete,
    required this.onRemove,
  });

  final RecipeNutritionEntry entry;
  final bool canDelete;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _RecipeTextInputBox(
              controller: entry.labelController,
              hintTextKey: 'newsAdd.recipe.nutritionLabelHint',
              fontSize: 13,
              bold: true,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _RecipeTextInputBox(
              controller: entry.valueController,
              hintTextKey: 'newsAdd.recipe.nutritionValueHint',
              fontSize: 13,
              bold: true,
            ),
          ),
          const SizedBox(width: 8),
          _RecipeTinyIconButton(
            icon: Icons.delete_outline,
            active: canDelete,
            onTap: onRemove,
          ),
        ],
      ),
    );
  }
}

class _RecipeDirectionCard extends StatelessWidget {
  const _RecipeDirectionCard({
    required this.direction,
    required this.index,
    required this.totalItems,
    required this.onRemove,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onToggleCollapsed,
    required this.onImageChanged,
  });

  final RecipeDirectionEntry direction;
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
    return _RecipeSectionCard(
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
                          '${context.t('newsAdd.recipe.direction')} #$displayNumber',
                          style: const TextStyle(
                            color: AppColors.deepOcean,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      _RecipeCollapseButton(
                        collapsed: direction.collapsed,
                        onTap: onToggleCollapsed,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(height: 1, color: _recipeBlockSoftLine),
                  if (!direction.collapsed) ...[
                    const SizedBox(height: 20),
                    _RecipeDirectionTitleRow(
                      direction: direction,
                      displayNumber: displayNumber,
                    ),
                    const SizedBox(height: 18),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxWidth < 760;
                        final imagePanel = _RecipeImagePanel(
                          imageUrl: direction.imageUrl,
                          imageDescriptionController:
                              direction.imageDescriptionController,
                          onPickImage: () => _pickImage(context),
                          onPickUrl: () => _pickUrl(context),
                          onClear: () => onImageChanged(null),
                        );
                        final contentPanel = _RecipeContentPanel(
                          controller: direction.contentController,
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
            child: _RecipeActionRail(
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

class _RecipeDirectionTitleRow extends StatelessWidget {
  const _RecipeDirectionTitleRow({
    required this.direction,
    required this.displayNumber,
  });

  final RecipeDirectionEntry direction;
  final int displayNumber;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _RecipeFieldLabel('newsAdd.recipe.directionTitle'),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _RecipeNumberBadge(displayNumber),
              const SizedBox(width: 10),
              Expanded(
                child: _RecipeTextInputBox(
                  controller: direction.titleController,
                  hintTextKey: 'newsAdd.recipe.directionTitleHint',
                  fontSize: 13,
                  bold: true,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RecipeImagePanel extends StatelessWidget {
  const _RecipeImagePanel({
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
        const _RecipeFieldLabel('newsAdd.recipe.directionImage'),
        _RecipeDashedImageBox(
          imageUrl: imageUrl,
          onPickImage: onPickImage,
          onPickUrl: onPickUrl,
          onClear: onClear,
        ),
        const SizedBox(height: 10),
        _RecipeTextInputBox(
          controller: imageDescriptionController,
          hintTextKey: 'newsAdd.recipe.imageDescriptionHint',
          fontSize: 12.5,
        ),
      ],
    );
  }
}

class _RecipeContentPanel extends StatelessWidget {
  const _RecipeContentPanel({required this.controller});

  final quill.QuillController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _RecipeFieldLabel('newsAdd.recipe.directionContent'),
        _RecipeRichTextEditor(
          controller: controller,
          placeholder: 'newsAdd.recipe.directionContentHint',
        ),
      ],
    );
  }
}

class _RecipeSectionHeader extends StatelessWidget {
  const _RecipeSectionHeader({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _recipeBlockSoftLine)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.actionRed.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.value),
            ),
            child: Icon(icon, color: AppColors.actionRed, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.t(title),
              style: const TextStyle(
                color: AppColors.deepOcean,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipeSectionCard extends StatelessWidget {
  const _RecipeSectionCard({required this.child, this.padding});

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
        border: Border.all(color: _recipeBlockStrongLine),
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

class _RecipeTextFieldControl extends StatelessWidget {
  const _RecipeTextFieldControl({
    required this.label,
    required this.controller,
    required this.hintTextKey,
  });

  final String label;
  final TextEditingController controller;
  final String hintTextKey;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RecipeFieldLabel(label),
        _RecipeTextInputBox(
          controller: controller,
          hintTextKey: hintTextKey,
          fontSize: 13,
          bold: true,
        ),
      ],
    );
  }
}

class _RecipeDifficultyControl extends StatelessWidget {
  const _RecipeDifficultyControl({
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _RecipeFieldLabel('newsAdd.recipe.difficulty'),
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.value),
            border: Border.all(color: _recipeBlockStrongLine),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value.isEmpty ? null : value,
              isExpanded: true,
              hint: Text(context.t('newsAdd.recipe.difficultySelect')),
              icon: const Icon(
                Icons.keyboard_arrow_down,
                size: 18,
                color: _recipeBlockMutedText,
              ),
              style: const TextStyle(
                color: AppColors.deepOcean,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.value),
              items: const [
                DropdownMenuItem(
                  value: 'easy',
                  child: _TranslatedMenuText('newsAdd.recipe.difficultyEasy'),
                ),
                DropdownMenuItem(
                  value: 'medium',
                  child: _TranslatedMenuText('newsAdd.recipe.difficultyMedium'),
                ),
                DropdownMenuItem(
                  value: 'hard',
                  child: _TranslatedMenuText('newsAdd.recipe.difficultyHard'),
                ),
              ],
              onChanged: (next) => onChanged(next ?? ''),
            ),
          ),
        ),
      ],
    );
  }
}

class _TranslatedMenuText extends StatelessWidget {
  const _TranslatedMenuText(this.keyName);

  final String keyName;

  @override
  Widget build(BuildContext context) {
    return Text(context.t(keyName));
  }
}

class _RecipeFieldLabel extends StatelessWidget {
  const _RecipeFieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(
        context.t(text),
        style: const TextStyle(
          color: _recipeBlockMutedText,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _RecipeNumberBadge extends StatelessWidget {
  const _RecipeNumberBadge(this.number);

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

class _RecipeTextInputBox extends StatelessWidget {
  const _RecipeTextInputBox({
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
        border: Border.all(color: _recipeBlockStrongLine),
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

class _RecipeDashedImageBox extends StatelessWidget {
  const _RecipeDashedImageBox({
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
      painter: _RecipeDashedBorderPainter(
        color: _recipeBlockStrongLine,
        radius: AppRadius.value,
      ),
      child: Container(
        height: _recipeBlockVisualHeight,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(AppRadius.value),
        ),
        child: imageUrl == null
            ? _RecipeEmptyImagePicker(
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
                      errorBuilder: (_, _, _) => _RecipeEmptyImagePicker(
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
                        _RecipeImageActionButton(
                          icon: Icons.edit_outlined,
                          color: AppColors.deepOcean,
                          onTap: onPickImage,
                        ),
                        const SizedBox(width: 8),
                        _RecipeImageActionButton(
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

class _RecipeEmptyImagePicker extends StatelessWidget {
  const _RecipeEmptyImagePicker({
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
              const Icon(Icons.add, color: _recipeBlockUploadInk, size: 32),
              const SizedBox(height: 8),
              Text(
                context.t('newsAdd.imageSelect'),
                style: const TextStyle(
                  color: _recipeBlockUploadInk,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 12),
              _RecipeUrlUploadButton(onTap: onPickUrl),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecipeUrlUploadButton extends StatelessWidget {
  const _RecipeUrlUploadButton({required this.onTap});

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
            border: Border.all(color: _recipeBlockStrongLine),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.public, size: 13, color: AppColors.deepOcean),
              const SizedBox(width: 7),
              Text(
                context.t('newsAdd.addUrl'),
                style: const TextStyle(
                  color: AppColors.deepOcean,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecipeImageActionButton extends StatelessWidget {
  const _RecipeImageActionButton({
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
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.value),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
              ),
            ],
          ),
          child: Icon(icon, size: 17, color: color),
        ),
      ),
    );
  }
}

class _RecipeActionRail extends StatelessWidget {
  const _RecipeActionRail({
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
        border: Border(right: BorderSide(color: _recipeBlockSoftLine)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          _RecipeRailIconButton(
            icon: Icons.keyboard_arrow_up,
            active: canMoveUp,
            onTap: onMoveUp,
          ),
          const SizedBox(height: 8),
          _RecipeRailIconButton(
            icon: Icons.keyboard_arrow_down,
            active: canMoveDown,
            onTap: onMoveDown,
          ),
          const Spacer(),
          _RecipeRailIconButton(
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

class _RecipeRailIconButton extends StatelessWidget {
  const _RecipeRailIconButton({
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

class _RecipeTinyIconButton extends StatelessWidget {
  const _RecipeTinyIconButton({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: active ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: active ? onTap : null,
        child: Container(
          width: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active
                ? AppColors.actionRed.withValues(alpha: 0.05)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.value),
            border: Border.all(
              color: active
                  ? AppColors.actionRed.withValues(alpha: 0.14)
                  : _recipeBlockStrongLine.withValues(alpha: 0.6),
            ),
          ),
          child: Icon(
            icon,
            size: 17,
            color: active
                ? AppColors.actionRed
                : AppColors.iconMuted.withValues(alpha: 0.38),
          ),
        ),
      ),
    );
  }
}

class _RecipeCollapseButton extends StatelessWidget {
  const _RecipeCollapseButton({required this.collapsed, required this.onTap});

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
            color: _recipeBlockMutedText,
          ),
        ),
      ),
    );
  }
}

class _RecipeSmallAddButton extends StatelessWidget {
  const _RecipeSmallAddButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.warmHorizon,
            borderRadius: BorderRadius.circular(AppRadius.value),
            boxShadow: [
              BoxShadow(
                color: AppColors.warmHorizon.withValues(alpha: 0.22),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            '+ ${context.t(label)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}

class _RecipeAddButton extends StatelessWidget {
  const _RecipeAddButton({required this.label, required this.onTap});

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
            foregroundPainter: _RecipeDashedBorderPainter(
              color: AppColors.actionRed.withValues(alpha: 0.28),
              radius: AppRadius.value,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.actionRed.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(AppRadius.value),
              ),
              child: Text(
                '+ ${context.t(label)}',
                style: const TextStyle(
                  color: AppColors.actionRed,
                  fontSize: 12.5,
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

class _RecipeRichTextEditor extends StatelessWidget {
  const _RecipeRichTextEditor({
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
        border: Border.all(color: _recipeBlockStrongLine),
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
            height: _recipeBlockEditorBodyHeight,
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

class _RecipeDashedBorderPainter extends CustomPainter {
  const _RecipeDashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;
  static const _strokeWidth = 1.2;
  static const _dashWidth = 6.0;
  static const _dashGap = 5.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = _strokeWidth
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = distance + _dashWidth;
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + _dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RecipeDashedBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}
