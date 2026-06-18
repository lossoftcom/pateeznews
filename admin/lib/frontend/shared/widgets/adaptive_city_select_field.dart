import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pateeznews_admin/shared/constants/turkey_cities.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

class AdaptiveCitySelectField extends StatelessWidget {
  const AdaptiveCitySelectField({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'Şehir',
    this.enabled = true,
    this.padding = EdgeInsets.zero,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final String label;
  final bool enabled;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final safeValue = isTurkeyCity(value) ? normalizeTurkeyCity(value) : null;
    final borderRadius = BorderRadius.circular(AppRadius.value);
    return Padding(
      padding: padding,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: label,
        value: safeValue ?? 'Şehir seç',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: borderRadius,
            onTap: enabled ? () => _openPicker(context) : null,
            child: InputDecorator(
              isEmpty: safeValue == null,
              decoration: InputDecoration(
                labelText: label,
                prefixIcon: const Icon(
                  Symbols.location_on_rounded,
                  color: AppColors.iconMuted,
                  size: 18,
                ),
                suffixIcon: const Icon(
                  Symbols.keyboard_arrow_down_rounded,
                  color: AppColors.iconMuted,
                  size: 18,
                ),
                filled: true,
                fillColor: AppColors.surface,
                labelStyle: AppTypography.meta.copyWith(
                  color: AppColors.support,
                ),
                hintStyle: AppTypography.bodySmall.copyWith(
                  color: AppColors.placeholder,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 12,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: borderRadius,
                  borderSide: const BorderSide(color: AppColors.softLine),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: borderRadius,
                  borderSide: const BorderSide(
                    color: AppColors.deepOcean,
                    width: 1.2,
                  ),
                ),
                border: OutlineInputBorder(borderRadius: borderRadius),
              ),
              child: Text(
                safeValue ?? 'Şehir seç',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.titleS.copyWith(
                  color: safeValue == null
                      ? AppColors.placeholder
                      : AppColors.inkStrong,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openPicker(BuildContext context) async {
    final selected = isTurkeyCity(value)
        ? normalizeTurkeyCity(value)
        : defaultTurkeyCity;
    final isCupertino =
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
    final picked = isCupertino
        ? await showCupertinoModalPopup<String>(
            context: context,
            semanticsDismissible: true,
            builder: (_) => _CupertinoCityPickerSheet(initialValue: selected),
          )
        : await showModalBottomSheet<String>(
            context: context,
            useSafeArea: true,
            isScrollControlled: true,
            backgroundColor: AppColors.surface,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            builder: (_) => _MaterialCityPickerSheet(selectedValue: selected),
          );
    if (picked != null && picked.isNotEmpty) onChanged(picked);
  }
}

class _CupertinoCityPickerSheet extends StatefulWidget {
  const _CupertinoCityPickerSheet({required this.initialValue});

  final String initialValue;

  @override
  State<_CupertinoCityPickerSheet> createState() =>
      _CupertinoCityPickerSheetState();
}

class _CupertinoCityPickerSheetState extends State<_CupertinoCityPickerSheet> {
  late final FixedExtentScrollController _controller;
  late var _selectedIndex = _cityIndex(widget.initialValue);

  @override
  void initState() {
    super.initState();
    _controller = FixedExtentScrollController(initialItem: _selectedIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoTheme(
      data: const CupertinoThemeData(brightness: Brightness.light),
      child: Container(
        height: 318 + MediaQuery.paddingOf(context).bottom,
        color: AppColors.surface,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              SizedBox(
                height: 48,
                child: Row(
                  children: [
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'İptal',
                        style: AppTypography.body.copyWith(
                          color: AppColors.support,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Şehir',
                        textAlign: TextAlign.center,
                        style: AppTypography.titleS.copyWith(
                          color: AppColors.inkStrong,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      onPressed: () {
                        Navigator.of(context).pop(turkeyCities[_selectedIndex]);
                      },
                      child: Text(
                        'Seç',
                        style: AppTypography.body.copyWith(
                          color: AppColors.actionRed,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.softLine),
              Expanded(
                child: CupertinoPicker(
                  scrollController: _controller,
                  itemExtent: 38,
                  magnification: 1.04,
                  squeeze: 1.16,
                  useMagnifier: true,
                  onSelectedItemChanged: (index) {
                    setState(() => _selectedIndex = index);
                  },
                  children: [
                    for (final city in turkeyCities)
                      Center(
                        child: Text(
                          city,
                          style: AppTypography.titleS.copyWith(
                            color: AppColors.inkStrong,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MaterialCityPickerSheet extends StatelessWidget {
  const _MaterialCityPickerSheet({required this.selectedValue});

  final String selectedValue;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _cityIndex(selectedValue);
    return FractionallySizedBox(
      heightFactor: 0.72,
      child: Column(
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            decoration: BoxDecoration(
              color: AppColors.softLine,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 10, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Şehir seç',
                    style: AppTypography.titleM.copyWith(
                      color: AppColors.inkStrong,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Kapat',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Symbols.close, size: 20),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.softLine),
          Expanded(
            child: ListView.builder(
              controller: ScrollController(
                initialScrollOffset:
                    (selectedIndex - 3)
                        .clamp(0, turkeyCities.length)
                        .toDouble() *
                    48,
              ),
              itemCount: turkeyCities.length,
              itemBuilder: (context, index) {
                final city = turkeyCities[index];
                final selected = city == selectedValue;
                return ListTile(
                  dense: true,
                  minLeadingWidth: 20,
                  leading: Icon(
                    selected
                        ? Symbols.check_circle
                        : Symbols.location_on_rounded,
                    size: 19,
                    color: selected ? AppColors.actionRed : AppColors.iconMuted,
                  ),
                  title: Text(
                    city,
                    style: AppTypography.titleS.copyWith(
                      color: AppColors.inkStrong,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                    ),
                  ),
                  selected: selected,
                  selectedTileColor: AppColors.actionRed.withValues(
                    alpha: 0.08,
                  ),
                  onTap: () => Navigator.of(context).pop(city),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

int _cityIndex(String value) {
  final normalized = normalizeTurkeyCity(value);
  final index = turkeyCities.indexOf(normalized);
  return index < 0 ? turkeyCities.indexOf(defaultTurkeyCity) : index;
}
