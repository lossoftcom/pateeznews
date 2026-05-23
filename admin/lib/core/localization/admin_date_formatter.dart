import 'package:flutter/widgets.dart';

import 'admin_language_controller.dart';

String formatAdminFullDate(BuildContext context, DateTime? value) {
  if (value == null) return '-';
  final local = value.toLocal();
  final month = context.t('date.month.${local.month}');
  final weekday = context.t('date.weekday.${local.weekday}');

  return context.t(
    'date.fullDateFormat',
    values: {
      'day': local.day,
      'month': month,
      'year': local.year,
      'weekday': weekday,
    },
  );
}

String formatAdminTime(DateTime? value) {
  if (value == null) return '';
  final local = value.toLocal();
  return '${_two(local.hour)}:${_two(local.minute)}';
}

String _two(int value) => value.toString().padLeft(2, '0');
