import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';

import 'contact_list_models.dart';

class AdminContactImportParser {
  const AdminContactImportParser._();

  static final _emailPattern = RegExp(
    r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    caseSensitive: false,
  );

  static List<AdminContactImportRow> parseCsv(Uint8List bytes) {
    final text = utf8.decode(bytes, allowMalformed: true);
    final rows = csv.decode(text);
    return _fromRows(rows);
  }

  static List<AdminContactImportRow> parseXlsx(Uint8List bytes) {
    final workbook = SpreadsheetDecoder.decodeBytes(bytes);
    for (final table in workbook.tables.values) {
      if (table.rows.isNotEmpty) {
        return _fromRows(table.rows);
      }
    }
    return const <AdminContactImportRow>[];
  }

  static List<AdminContactImportRow> _fromRows(List<List<dynamic>> rows) {
    if (rows.isEmpty) return const <AdminContactImportRow>[];

    final firstRow = rows.first.map(_cellText).toList(growable: false);
    final headers = firstRow.map(_normalizeHeader).toList(growable: false);
    final emailIndex = headers.indexWhere(_isEmailHeader);
    final hasHeaders = emailIndex >= 0;
    final firstNameIndex = headers.indexWhere(_isFirstNameHeader);
    final lastNameIndex = headers.indexWhere(_isLastNameHeader);
    final phoneIndex = headers.indexWhere(_isPhoneHeader);
    final sourceRows = hasHeaders ? rows.skip(1) : rows;
    final unique = <String, AdminContactImportRow>{};

    for (final row in sourceRows) {
      final values = row.map(_cellText).toList(growable: false);
      final resolvedEmailIndex = hasHeaders
          ? emailIndex
          : values.indexWhere(
              (value) => _emailPattern.hasMatch(value.trim().toLowerCase()),
            );
      if (resolvedEmailIndex < 0 || resolvedEmailIndex >= values.length) {
        continue;
      }
      final email = values[resolvedEmailIndex].trim().toLowerCase();
      if (!_emailPattern.hasMatch(email)) continue;

      String valueAt(int index) =>
          index >= 0 && index < values.length ? values[index].trim() : '';

      var firstName = valueAt(firstNameIndex);
      var lastName = valueAt(lastNameIndex);
      var phone = valueAt(phoneIndex);
      if (!hasHeaders) {
        final remaining = <String>[
          for (var index = 0; index < values.length; index++)
            if (index != resolvedEmailIndex && values[index].trim().isNotEmpty)
              values[index].trim(),
        ];
        phone = remaining.firstWhere(
          (value) => RegExp(r'^\+?[\d\s()\-]{6,}$').hasMatch(value),
          orElse: () => '',
        );
        final names = remaining.where((value) => value != phone).toList();
        firstName = names.isEmpty ? '' : names.first;
        lastName = names.length < 2 ? '' : names.skip(1).join(' ');
      }

      unique[email] = AdminContactImportRow(
        email: email,
        firstName: firstName,
        lastName: lastName,
        phone: phone,
      );
    }
    return unique.values.toList(growable: false);
  }

  static String _cellText(dynamic value) {
    return value?.toString().replaceFirst('\ufeff', '').trim() ?? '';
  }

  static String _normalizeHeader(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('ş', 's')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  static bool _isEmailHeader(String value) => const {
    'email',
    'e_mail',
    'eposta',
    'mail',
    'mail_adresi',
    'email_address',
  }.contains(value);

  static bool _isFirstNameHeader(String value) =>
      const {'first_name', 'firstname', 'ad', 'isim', 'name'}.contains(value);

  static bool _isLastNameHeader(String value) =>
      const {'last_name', 'lastname', 'soyad', 'surname'}.contains(value);

  static bool _isPhoneHeader(String value) =>
      const {'phone', 'telefon', 'telephone', 'mobile', 'gsm'}.contains(value);
}
