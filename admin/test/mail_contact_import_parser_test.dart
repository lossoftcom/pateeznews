import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pateeznews_admin/features/mail/presentation/contact_import_parser.dart';

void main() {
  test('parses localized CSV headers and quoted values', () {
    final bytes = Uint8List.fromList(
      utf8.encode(
        'E-posta;Ad;Soyad;Telefon\r\n'
        'ada@example.com;"Ada, Nur";Yılmaz;+90 555 111 22 33\r\n',
      ),
    );

    final contacts = AdminContactImportParser.parseCsv(bytes);

    expect(contacts, hasLength(1));
    expect(contacts.single.email, 'ada@example.com');
    expect(contacts.single.firstName, 'Ada, Nur');
    expect(contacts.single.lastName, 'Yılmaz');
    expect(contacts.single.phone, '+90 555 111 22 33');
  });

  test('detects email without headers and removes duplicates', () {
    final bytes = Uint8List.fromList(
      utf8.encode(
        'ali@example.com,Ali,Veli,+905551112233\n'
        'ALI@example.com,Updated,Name,+905559998877\n',
      ),
    );

    final contacts = AdminContactImportParser.parseCsv(bytes);

    expect(contacts, hasLength(1));
    expect(contacts.single.email, 'ali@example.com');
    expect(contacts.single.firstName, 'Updated');
    expect(contacts.single.lastName, 'Name');
    expect(contacts.single.phone, '+905559998877');
  });

  test('maps reordered Turkish headers', () {
    final bytes = Uint8List.fromList(
      utf8.encode(
        'Telefon;Soyad\u0131;E-posta;\u0130sim\r\n'
        '+90 555 111 22 33;Y\u0131lmaz;ada@example.com;Ada Nur\r\n',
      ),
    );

    final contacts = AdminContactImportParser.parseCsv(bytes);

    expect(contacts, hasLength(1));
    expect(contacts.single.email, 'ada@example.com');
    expect(contacts.single.firstName, 'Ada Nur');
    expect(contacts.single.lastName, 'Y\u0131lmaz');
    expect(contacts.single.phone, '+90 555 111 22 33');
  });

  test('exports sample CSV and XLSX that can be imported again', () {
    final csvContacts = AdminContactImportParser.parseCsv(
      AdminContactImportParser.sampleCsvBytes(),
    );
    final xlsxContacts = AdminContactImportParser.parseXlsx(
      AdminContactImportParser.sampleXlsxBytes(),
    );

    expect(csvContacts.map((contact) => contact.email), [
      'nasip@example.com',
      'okur@example.com',
    ]);
    expect(xlsxContacts.map((contact) => contact.email), [
      'nasip@example.com',
      'okur@example.com',
    ]);
  });
}
