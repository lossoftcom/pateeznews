import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/localization/admin_date_formatter.dart';
import '../../core/localization/admin_language_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../icons/symbols.dart';
import 'symbol_icon.dart';

Future<DateTime?> showAdminDateTimePicker(
  BuildContext context, {
  DateTime? initialValue,
  DateTime? firstDate,
  DateTime? lastDate,
}) async {
  final now = DateTime.now();
  final minValue = firstDate ?? now;
  final maxValue = lastDate ?? now.add(const Duration(days: 730));
  final initial = _clampDateTime(
    initialValue ?? now.add(const Duration(hours: 1)),
    minValue,
    maxValue,
  );

  return showDialog<DateTime>(
    context: context,
    barrierDismissible: true,
    builder: (context) => _AdminDateTimePickerDialog(
      initialValue: initial,
      minValue: minValue,
      maxValue: maxValue,
    ),
  );
}

class AdminDateTimeField extends StatelessWidget {
  const AdminDateTimeField({
    super.key,
    required this.label,
    required this.placeholder,
    required this.value,
    required this.onChanged,
    this.description,
    this.enabled = true,
  });

  final String label;
  final String placeholder;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final String? description;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final selected = value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.deepOcean,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 7),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.value),
          child: InkWell(
            onTap: enabled ? () => _pick(context) : null,
            borderRadius: BorderRadius.circular(AppRadius.value),
            mouseCursor: enabled
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
            child: Container(
              constraints: const BoxConstraints(minHeight: 58),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.value),
                border: Border.all(
                  color: selected == null
                      ? AppColors.line
                      : AppColors.warmHorizon.withValues(alpha: 0.48),
                ),
                boxShadow: selected == null
                    ? null
                    : [
                        BoxShadow(
                          color: AppColors.warmHorizon.withValues(alpha: 0.08),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.warmHorizon.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.value),
                    ),
                    child: const SymbolIcon(
                      Symbols.calendar_today_outlined,
                      size: 18,
                      color: AppColors.warmHorizon,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      selected == null
                          ? placeholder
                          : _formatDateTime(context, selected),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected == null
                            ? AppColors.support
                            : AppColors.deepOcean,
                        fontSize: 12,
                        fontWeight: selected == null
                            ? FontWeight.w700
                            : FontWeight.w800,
                        height: 1.25,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  if (selected != null) ...[
                    const SizedBox(width: 8),
                    Tooltip(
                      message: context.t('common.clear'),
                      child: IconButton(
                        onPressed: enabled ? () => onChanged(null) : null,
                        icon: const SymbolIcon(
                          Symbols.close,
                          size: 16,
                          color: AppColors.support,
                        ),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (description != null) ...[
          const SizedBox(height: 7),
          Text(
            description!,
            style: const TextStyle(
              color: AppColors.inkSoft,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              height: 1.35,
              letterSpacing: 0,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _pick(BuildContext context) async {
    final picked = await showAdminDateTimePicker(context, initialValue: value);
    if (picked != null && context.mounted) onChanged(picked);
  }
}

class _AdminDateTimePickerDialog extends StatefulWidget {
  const _AdminDateTimePickerDialog({
    required this.initialValue,
    required this.minValue,
    required this.maxValue,
  });

  final DateTime initialValue;
  final DateTime minValue;
  final DateTime maxValue;

  @override
  State<_AdminDateTimePickerDialog> createState() =>
      _AdminDateTimePickerDialogState();
}

class _AdminDateTimePickerDialogState
    extends State<_AdminDateTimePickerDialog> {
  late DateTime _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    final valid = _value.isAfter(widget.minValue);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 590),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.line.withValues(alpha: 0.86)),
            boxShadow: [
              BoxShadow(
                color: AppColors.deepOcean.withValues(alpha: 0.18),
                blurRadius: 34,
                offset: const Offset(0, 24),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 14, 12),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.deepOcean.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const SymbolIcon(
                        Symbols.schedule,
                        color: AppColors.deepOcean,
                        size: 19,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.t('admin.dateTimePicker.title'),
                            style: const TextStyle(
                              color: AppColors.deepOcean,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            context.t('admin.dateTimePicker.subtitle'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.inkSoft,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      mouseCursor: SystemMouseCursors.click,
                      icon: const SymbolIcon(
                        Symbols.close,
                        color: AppColors.support,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
              Container(height: 1, color: AppColors.softLine),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 520;
                    final picker = _PickerWheel(
                      value: _value,
                      minValue: widget.minValue,
                      maxValue: widget.maxValue,
                      onChanged: (value) => setState(() => _value = value),
                    );
                    final summary = _PickerSummary(value: _value);
                    if (compact) {
                      return Column(
                        children: [summary, const SizedBox(height: 14), picker],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 170, child: summary),
                        const SizedBox(width: 16),
                        Expanded(child: picker),
                      ],
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                child: Row(
                  children: [
                    if (!valid)
                      Expanded(
                        child: Text(
                          context.t('admin.dateTimePicker.futureOnly'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.actionRed,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                          ),
                        ),
                      )
                    else
                      const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style:
                          TextButton.styleFrom(
                            foregroundColor: AppColors.deepOcean,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ).copyWith(
                            mouseCursor: const WidgetStatePropertyAll(
                              SystemMouseCursors.click,
                            ),
                          ),
                      child: Text(context.t('common.cancel')),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 38,
                      child: TextButton(
                        onPressed: valid
                            ? () => Navigator.of(context).pop(_value)
                            : null,
                        style:
                            TextButton.styleFrom(
                              backgroundColor: valid
                                  ? AppColors.deepOcean
                                  : AppColors.softLine,
                              foregroundColor: valid
                                  ? Colors.white
                                  : AppColors.support,
                              disabledForegroundColor: AppColors.support,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.value,
                                ),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0,
                              ),
                            ).copyWith(
                              mouseCursor: WidgetStatePropertyAll(
                                valid
                                    ? SystemMouseCursors.click
                                    : SystemMouseCursors.basic,
                              ),
                            ),
                        child: Text(context.t('admin.dateTimePicker.confirm')),
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

class _PickerSummary extends StatelessWidget {
  const _PickerSummary({required this.value});

  final DateTime value;

  @override
  Widget build(BuildContext context) {
    final local = value.toLocal();
    final month = context.t('date.month.${local.month}');
    final weekday = context.t('date.weekday.${local.weekday}');
    return Container(
      height: 214,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.deepOcean,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t('admin.dateTimePicker.selected'),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '${local.day}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 42,
              fontWeight: FontWeight.w800,
              height: 0.95,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '$month\n$weekday',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              height: 1.16,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.value),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SymbolIcon(
                  Symbols.schedule,
                  color: Colors.white,
                  size: 15,
                ),
                const SizedBox(width: 7),
                Text(
                  formatAdminTime(local),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
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

class _PickerWheel extends StatelessWidget {
  const _PickerWheel({
    required this.value,
    required this.minValue,
    required this.maxValue,
    required this.onChanged,
  });

  final DateTime value;
  final DateTime minValue;
  final DateTime maxValue;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 214,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: CupertinoTheme(
          data: const CupertinoThemeData(
            brightness: Brightness.light,
            primaryColor: AppColors.deepOcean,
            textTheme: CupertinoTextThemeData(
              dateTimePickerTextStyle: TextStyle(
                color: AppColors.deepOcean,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ),
          child: CupertinoDatePicker(
            mode: CupertinoDatePickerMode.dateAndTime,
            initialDateTime: value,
            minimumDate: minValue,
            maximumDate: maxValue,
            minuteInterval: 1,
            use24hFormat: true,
            backgroundColor: Colors.transparent,
            onDateTimeChanged: onChanged,
          ),
        ),
      ),
    );
  }
}

String _formatDateTime(BuildContext context, DateTime value) {
  final local = value.toLocal();
  final month = context.t('date.month.${local.month}');
  return '${local.day} $month ${local.year} ${formatAdminTime(local)}';
}

DateTime _clampDateTime(DateTime value, DateTime min, DateTime max) {
  if (value.isBefore(min)) return min;
  if (value.isAfter(max)) return max;
  return value;
}
