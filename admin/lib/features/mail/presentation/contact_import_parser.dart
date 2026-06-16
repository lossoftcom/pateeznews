import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';

import 'contact_list_models.dart';

class AdminContactImportParser {
  const AdminContactImportParser._();

  static const _sampleRows = <List<String>>[
    ['E-posta', 'Ad', 'Soyad', 'Telefon'],
    ['nasip@example.com', 'Nasip', 'Gundogu', '+905419474980'],
    ['okur@example.com', 'Pateez', 'Okuru', '+905550000000'],
  ];

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

  static Uint8List sampleCsvBytes() {
    return Uint8List.fromList(utf8.encode('\ufeff${csv.encode(_sampleRows)}'));
  }

  static Uint8List sampleXlsxBytes() {
    final archive = Archive()
      ..addFile(_archiveFile('[Content_Types].xml', _contentTypesXml))
      ..addFile(_archiveFile('_rels/.rels', _rootRelsXml))
      ..addFile(_archiveFile('docProps/app.xml', _appPropsXml))
      ..addFile(_archiveFile('docProps/core.xml', _corePropsXml))
      ..addFile(_archiveFile('xl/workbook.xml', _workbookXml))
      ..addFile(_archiveFile('xl/_rels/workbook.xml.rels', _workbookRelsXml))
      ..addFile(_archiveFile('xl/styles.xml', _stylesXml))
      ..addFile(_archiveFile('xl/worksheets/sheet1.xml', _sheetXml()));
    return Uint8List.fromList(ZipEncoder().encode(archive) ?? const <int>[]);
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
        .replaceAll('\u0131', 'i')
        .replaceAll('\u015f', 's')
        .replaceAll('\u011f', 'g')
        .replaceAll('\u00fc', 'u')
        .replaceAll('\u00f6', 'o')
        .replaceAll('\u00e7', 'c')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  static bool _isEmailHeader(String value) => const {
    'email',
    'e_mail',
    'e_posta',
    'eposta',
    'mail',
    'mail_adresi',
    'email_address',
  }.contains(value);

  static bool _isFirstNameHeader(String value) =>
      const {'first_name', 'firstname', 'ad', 'isim', 'name'}.contains(value);

  static bool _isLastNameHeader(String value) => const {
    'last_name',
    'lastname',
    'soyad',
    'soyadi',
    'surname',
  }.contains(value);

  static bool _isPhoneHeader(String value) =>
      const {'phone', 'telefon', 'telephone', 'mobile', 'gsm'}.contains(value);

  static ArchiveFile _archiveFile(String name, String content) {
    final bytes = utf8.encode(content);
    return ArchiveFile(name, bytes.length, bytes);
  }

  static String _cellReference(int rowIndex, int columnIndex) {
    var number = columnIndex + 1;
    final buffer = StringBuffer();
    while (number > 0) {
      final remainder = (number - 1) % 26;
      buffer.writeCharCode(65 + remainder);
      number = (number - remainder - 1) ~/ 26;
    }
    return '${buffer.toString()}${rowIndex + 1}';
  }

  static String _xmlEscape(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  static String _sheetXml() {
    final rows = StringBuffer();
    for (var rowIndex = 0; rowIndex < _sampleRows.length; rowIndex++) {
      rows.write('<row r="${rowIndex + 1}">');
      final row = _sampleRows[rowIndex];
      for (var columnIndex = 0; columnIndex < row.length; columnIndex++) {
        final ref = _cellReference(rowIndex, columnIndex);
        rows.write(
          '<c r="$ref" t="inlineStr"><is><t>${_xmlEscape(row[columnIndex])}</t></is></c>',
        );
      }
      rows.write('</row>');
    }
    return '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <dimension ref="A1:D${_sampleRows.length}"/>
  <sheetViews><sheetView workbookViewId="0"/></sheetViews>
  <sheetFormatPr defaultRowHeight="15"/>
  <sheetData>$rows</sheetData>
</worksheet>
''';
  }

  static const _contentTypesXml = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
  <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
  <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
  <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
</Types>
''';

  static const _rootRelsXml = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
</Relationships>
''';

  static const _workbookXml = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheets>
    <sheet name="Kisiler" sheetId="1" r:id="rId1"/>
  </sheets>
</workbook>
''';

  static const _workbookRelsXml = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>
''';

  static const _stylesXml = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <fonts count="1"><font><sz val="11"/><name val="Calibri"/></font></fonts>
  <fills count="1"><fill><patternFill patternType="none"/></fill></fills>
  <borders count="1"><border/></borders>
  <cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
  <cellXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/></cellXfs>
</styleSheet>
''';

  static const _appPropsXml = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties">
  <Application>Pateez Admin</Application>
</Properties>
''';

  static const _corePropsXml = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <dc:creator>Pateez Admin</dc:creator>
  <dc:title>Kisi Listesi Ornegi</dc:title>
</cp:coreProperties>
''';
}
