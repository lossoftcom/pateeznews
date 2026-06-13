import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../../core/mock/home_mock_data.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/cached_image.dart';

const double _recipeCornerRadius = 4;
const Color _recipeGreen = Color(0xFF1F9B6D);

class DetailRecipeBlock extends StatefulWidget {
  const DetailRecipeBlock({
    super.key,
    required this.data,
    required this.title,
    required this.description,
  });

  final NewsRecipeData data;
  final String title;
  final String description;

  @override
  State<DetailRecipeBlock> createState() => _DetailRecipeBlockState();
}

class _DetailRecipeBlockState extends State<DetailRecipeBlock> {
  final Set<int> _checkedIngredients = {};

  @override
  void didUpdateWidget(covariant DetailRecipeBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) _checkedIngredients.clear();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final ingredients = data.ingredients
        .where((item) => item.text.trim().isNotEmpty)
        .toList(growable: false);
    final nutrition = data.nutrition
        .where(
          (item) =>
              item.label.trim().isNotEmpty || item.value.trim().isNotEmpty,
        )
        .toList(growable: false);
    final directions = data.directions
        .where((item) => item.isValid)
        .toList(growable: false);
    final stats = _recipeStats(data);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RecipeHeader(
          ingredientCount: ingredients.length,
          stepCount: directions.length,
        ),
        if (widget.title.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            widget.title.trim(),
            style: AppTypography.mobileNewsCardTitle.copyWith(
              color: AppColors.inkStrong,
              fontSize: 23,
              fontWeight: FontWeight.w900,
              height: 1.08,
              letterSpacing: 0,
            ),
          ),
        ],
        if (widget.description.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            widget.description.trim(),
            style: AppTypography.mobileNewsCardSummary.copyWith(
              color: AppColors.inkSoft.withValues(alpha: 0.88),
              fontSize: 14,
              height: 1.46,
              letterSpacing: 0,
            ),
          ),
        ],
        if (stats.isNotEmpty) ...[
          const SizedBox(height: 15),
          _RecipeStatsPanel(stats: stats),
        ],
        if (ingredients.isNotEmpty) ...[
          const SizedBox(height: 18),
          _RecipeSectionTitle(
            icon: Symbols.restaurant_line,
            title: 'Malzemeler',
            trailing: '${_checkedIngredients.length}/${ingredients.length}',
          ),
          const SizedBox(height: 9),
          _RecipeIngredientList(
            ingredients: ingredients,
            checkedIngredients: _checkedIngredients,
            onToggle: _toggleIngredient,
          ),
        ],
        if (nutrition.isNotEmpty) ...[
          const SizedBox(height: 18),
          _RecipeSectionTitle(
            icon: Symbols.local_fire_department_rounded,
            title: 'Besin Değerleri',
            trailing: '${nutrition.length} değer',
          ),
          const SizedBox(height: 9),
          _RecipeNutritionPanel(nutrition: nutrition),
        ],
        if (directions.isNotEmpty) ...[
          const SizedBox(height: 18),
          _RecipeSectionTitle(
            icon: Symbols.format_list_numbered,
            title: 'Yapılış',
            trailing: '${directions.length} adım',
          ),
          const SizedBox(height: 10),
          for (var index = 0; index < directions.length; index += 1) ...[
            _RecipeDirectionStep(
              direction: directions[index],
              displayNumber: index + 1,
            ),
            if (index != directions.length - 1) const SizedBox(height: 12),
          ],
        ],
      ],
    );
  }

  void _toggleIngredient(int index) {
    setState(() {
      if (!_checkedIngredients.add(index)) _checkedIngredients.remove(index);
    });
  }
}

class _RecipeHeader extends StatelessWidget {
  const _RecipeHeader({required this.ingredientCount, required this.stepCount});

  final int ingredientCount;
  final int stepCount;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (ingredientCount > 0) '$ingredientCount malzeme',
      if (stepCount > 0) '$stepCount adım',
    ];
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.actionRed.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(_recipeCornerRadius),
            border: Border.all(
              color: AppColors.actionRed.withValues(alpha: 0.12),
            ),
          ),
          child: const Icon(
            Symbols.restaurant_line,
            size: 18,
            color: AppColors.actionRed,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tarif',
                style: AppTypography.meta.copyWith(
                  color: AppColors.inkStrong,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                parts.isEmpty ? 'Yemek tarifi' : parts.join(' · '),
                style: AppTypography.meta.copyWith(
                  color: AppColors.support,
                  fontSize: 10.8,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
        _RecipeTinyPill(text: stepCount > 0 ? 'Adım adım' : 'Oku'),
      ],
    );
  }
}

class _RecipeStatsPanel extends StatelessWidget {
  const _RecipeStatsPanel({required this.stats});

  final List<_RecipeStat> stats;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(_recipeCornerRadius),
        border: Border.all(color: AppColors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = constraints.maxWidth < 330
                ? constraints.maxWidth
                : (constraints.maxWidth - 8) / 2;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final stat in stats)
                  SizedBox(width: itemWidth, child: _RecipeStatTile(stat)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RecipeStatTile extends StatelessWidget {
  const _RecipeStatTile(this.stat);

  final _RecipeStat stat;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(_recipeCornerRadius),
        border: Border.all(color: AppColors.softLine),
      ),
      child: Row(
        children: [
          Icon(stat.icon, size: 16, color: stat.color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  stat.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.meta.copyWith(
                    color: AppColors.support,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  stat.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.inkStrong,
                    fontSize: 12.6,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
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

class _RecipeSectionTitle extends StatelessWidget {
  const _RecipeSectionTitle({
    required this.icon,
    required this.title,
    required this.trailing,
  });

  final IconData icon;
  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.actionRed),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            title,
            style: AppTypography.titleS.copyWith(
              color: AppColors.inkStrong,
              fontSize: 15.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ),
        Text(
          trailing,
          style: AppTypography.meta.copyWith(
            color: AppColors.support,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _RecipeIngredientList extends StatelessWidget {
  const _RecipeIngredientList({
    required this.ingredients,
    required this.checkedIngredients,
    required this.onToggle,
  });

  final List<NewsRecipeIngredient> ingredients;
  final Set<int> checkedIngredients;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(_recipeCornerRadius),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepOcean.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          for (var index = 0; index < ingredients.length; index += 1) ...[
            _RecipeIngredientRow(
              text: ingredients[index].text,
              checked: checkedIngredients.contains(index),
              onTap: () => onToggle(index),
            ),
            if (index != ingredients.length - 1)
              Divider(height: 1, thickness: 1, color: AppColors.softLine),
          ],
        ],
      ),
    );
  }
}

class _RecipeIngredientRow extends StatelessWidget {
  const _RecipeIngredientRow({
    required this.text,
    required this.checked,
    required this.onTap,
  });

  final String text;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_recipeCornerRadius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.fromLTRB(11, 10, 12, 10),
          color: checked
              ? _recipeGreen.withValues(alpha: 0.07)
              : Colors.transparent,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 21,
                height: 21,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: checked ? _recipeGreen : AppColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(_recipeCornerRadius),
                  border: Border.all(
                    color: checked
                        ? _recipeGreen
                        : AppColors.deepOcean.withValues(alpha: 0.14),
                  ),
                ),
                child: checked
                    ? const Icon(
                        Symbols.check_rounded,
                        size: 13,
                        color: Colors.white,
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: AppTypography.body.copyWith(
                    color: checked ? AppColors.support : AppColors.inkStrong,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    height: 1.33,
                    letterSpacing: 0,
                    decoration: checked ? TextDecoration.lineThrough : null,
                    decorationColor: AppColors.support,
                    decorationThickness: 1.4,
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

class _RecipeNutritionPanel extends StatelessWidget {
  const _RecipeNutritionPanel({required this.nutrition});

  final List<NewsRecipeNutrition> nutrition;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(_recipeCornerRadius),
        border: Border.all(color: AppColors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            for (var index = 0; index < nutrition.length; index += 1) ...[
              _RecipeNutritionRow(item: nutrition[index]),
              if (index != nutrition.length - 1)
                Divider(height: 13, thickness: 1, color: AppColors.softLine),
            ],
          ],
        ),
      ),
    );
  }
}

class _RecipeNutritionRow extends StatelessWidget {
  const _RecipeNutritionRow({required this.item});

  final NewsRecipeNutrition item;

  @override
  Widget build(BuildContext context) {
    final label = item.label.trim();
    final value = item.value.trim();
    return Row(
      children: [
        Expanded(
          child: Text(
            label.isEmpty ? 'Değer' : label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.inkSoft,
              fontSize: 12.2,
              fontWeight: FontWeight.w800,
              height: 1.2,
              letterSpacing: 0,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          textAlign: TextAlign.right,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.inkStrong,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            height: 1.15,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _RecipeDirectionStep extends StatelessWidget {
  const _RecipeDirectionStep({
    required this.direction,
    required this.displayNumber,
  });

  final NewsRecipeDirection direction;
  final int displayNumber;

  @override
  Widget build(BuildContext context) {
    final title = direction.title.trim();
    final content = direction.content.trim();
    final imageUrl = direction.imageUrl.trim();
    final caption = direction.imageDescription.trim();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(_recipeCornerRadius),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepOcean.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 3,
              decoration: const BoxDecoration(
                color: AppColors.actionRed,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(_recipeCornerRadius),
                  bottomLeft: Radius.circular(_recipeCornerRadius),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 12, 12, 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.deepOcean,
                        borderRadius: BorderRadius.circular(
                          _recipeCornerRadius,
                        ),
                      ),
                      child: Text(
                        '$displayNumber',
                        style: AppTypography.meta.copyWith(
                          color: Colors.white,
                          fontSize: 12.2,
                          fontWeight: FontWeight.w900,
                          height: 1,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title.isEmpty ? 'Adım $displayNumber' : title,
                        style: AppTypography.titleM.copyWith(
                          color: AppColors.inkStrong,
                          fontSize: 17.2,
                          fontWeight: FontWeight.w900,
                          height: 1.14,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ],
                ),
                if (imageUrl.isNotEmpty) ...[
                  const SizedBox(height: 11),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(_recipeCornerRadius),
                    child: AspectRatio(
                      aspectRatio: 16 / 10,
                      child: ColoredBox(
                        color: AppColors.surfaceSoft,
                        child: CachedImage(
                          url: imageUrl,
                          fit: BoxFit.contain,
                          placeholderColor: AppColors.surfaceSoft,
                        ),
                      ),
                    ),
                  ),
                ],
                if (caption.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Text(
                    caption,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.support,
                      fontSize: 11.3,
                      fontStyle: FontStyle.italic,
                      height: 1.32,
                      letterSpacing: 0,
                    ),
                  ),
                ],
                if (content.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    content,
                    style: AppTypography.mobileDetailBody.copyWith(
                      color: AppColors.ink.withValues(alpha: 0.92),
                      fontSize: 15.2,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipeTinyPill extends StatelessWidget {
  const _RecipeTinyPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.warmHorizon.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(_recipeCornerRadius),
        border: Border.all(color: AppColors.warmHorizon.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Text(
          text,
          style: AppTypography.meta.copyWith(
            color: AppColors.warmHorizon,
            fontSize: 10.6,
            fontWeight: FontWeight.w900,
            height: 1,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _RecipeStat {
  const _RecipeStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
}

List<_RecipeStat> _recipeStats(NewsRecipeData data) {
  final stats = <_RecipeStat>[];
  if (data.prepTime.trim().isNotEmpty) {
    stats.add(
      _RecipeStat(
        icon: Symbols.schedule_rounded,
        label: 'Hazırlık',
        value: data.prepTime.trim(),
        color: AppColors.deepOcean,
      ),
    );
  }
  if (data.cookTime.trim().isNotEmpty) {
    stats.add(
      _RecipeStat(
        icon: Symbols.local_fire_department_rounded,
        label: 'Pişirme',
        value: data.cookTime.trim(),
        color: AppColors.actionRed,
      ),
    );
  }
  if (data.serving.trim().isNotEmpty) {
    stats.add(
      _RecipeStat(
        icon: Symbols.people_alt_outlined,
        label: 'Porsiyon',
        value: data.serving.trim(),
        color: AppColors.warmHorizon,
      ),
    );
  }
  final difficulty = _difficultyLabel(data.difficulty);
  if (difficulty.isNotEmpty) {
    stats.add(
      _RecipeStat(
        icon: Symbols.trending_up_rounded,
        label: 'Zorluk',
        value: difficulty,
        color: AppColors.deepOcean,
      ),
    );
  }
  return stats;
}

String _difficultyLabel(String value) {
  return switch (value.trim().toLowerCase()) {
    'easy' => 'Kolay',
    'medium' => 'Orta',
    'hard' => 'Zor',
    _ => '',
  };
}
