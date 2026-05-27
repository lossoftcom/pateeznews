import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_test/flutter_test.dart';
import 'package:pateeznews_admin/shared/widgets/admin_rich_text_editor.dart';

void main() {
  test('React uyumlu HTML quill editore yuklenip HTML olarak geri yazilir', () {
    final document = adminQuillDocumentFromStoredHtml(
      '<p><strong>Baslik</strong> ve <em>metin</em></p>',
    );
    final controller = quill.QuillController(
      document: document,
      selection: const TextSelection.collapsed(offset: 0),
    );

    final html = adminQuillHtml(controller);

    expect(controller.document.toPlainText(), contains('Baslik ve metin'));
    expect(html, contains('<strong>Baslik</strong>'));
    expect(html, contains('<em>metin</em>'));
  });

  test('Bos quill dokumani bos HTML olarak kaydedilir', () {
    final controller = quill.QuillController(
      document: adminQuillDocumentFromJson(adminEmptyQuillDeltaJson),
      selection: const TextSelection.collapsed(offset: 0),
    );

    expect(adminQuillHtml(controller), isEmpty);
  });
}
