import 'package:flutter_test/flutter_test.dart';
import 'package:pateeznews_admin/shared/data/admin_image_url.dart';

void main() {
  test('http(s)/data url olduğu gibi döner', () {
    expect(adminImageUrl('https://x/y.png'), 'https://x/y.png');
    expect(adminImageUrl('data:image/png;base64,AAAA'),
        'data:image/png;base64,AAAA');
  });

  test('boş değer boş döner', () {
    expect(adminImageUrl(''), '');
    expect(adminImageUrl('   '), '');
  });

  test('genişlik verilince ?w= ve ?q= ekler', () {
    final url = adminImageUrl('image/2026/foo.png', width: 180);
    expect(url, contains('w=180'));
    expect(url, contains('q=86'));
  });
}
