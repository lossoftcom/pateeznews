import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pateeznews_admin/features/news/data/admin_news_source_reader.dart';

void main() {
  test('JSON-LD NewsArticle kaynak metnini çıkarır', () async {
    final reader = AdminNewsSourceReader(
      httpClient: MockClient((request) async {
        return _htmlResponse('''
<!doctype html>
<html>
  <head>
    <script type="application/ld+json">
      {
        "@context": "https://schema.org",
        "@type": "NewsArticle",
        "headline": "Bahçeli ve Kemerhisar’da yağış etkili oldu",
        "description": "Niğde’nin Bahçeli ve Kemerhisar beldelerinde dolu yağışı etkili oldu.",
        "datePublished": "2026-06-04T17:26:00+03:00",
        "author": {"@type": "Person", "name": "Hamza TAV"},
        "articleBody": "Niğde’nin Bahçeli ve Kemerhisar beldelerinde dolu yağışı etkili oldu.\\nNiğde’nin Bahçeli ve Kemerhisar beldelerinde etkili olan sağanak ve dolu yağışı, günlük yaşamı olumsuz etkilerken tarım alanlarında da zarara neden oldu."
      }
    </script>
  </head>
  <body><nav>Paylaş</nav></body>
</html>
''');
      }),
    );

    final article = await reader.read(
      'https://www.dmchaber.com/bahceli-ve-kemerhisarda-yagis-etkili-oldu',
    );

    expect(article.title, 'Bahçeli ve Kemerhisar’da yağış etkili oldu');
    expect(article.description, contains('dolu yağışı etkili oldu'));
    expect(article.author, 'Hamza TAV');
    expect(
      article.bodyText,
      contains('tarım alanlarında da zarara neden oldu'),
    );
    expect(article.toPromptBlock(), contains('Kaynak URL:'));
    expect(article.toPromptBlock(), contains('Kaynak metni:'));
  });

  test('HTML haber gövdesini okur ve sayfa gürültüsünü atar', () async {
    final reader = AdminNewsSourceReader(
      httpClient: MockClient((request) async {
        return _htmlResponse('''
<!doctype html>
<html>
  <head>
    <meta property="og:title" content="Dünya Kupası forma numaraları belli oldu">
    <meta name="description" content="Milli takım oyuncularının forma numaraları açıklandı.">
  </head>
  <body>
    <header>Giriş Yap</header>
    <article>
      <h1>Dünya Kupası’nda Forma Giyecek Milli Takım Oyuncularının Forma Numaraları Belli Oldu</h1>
      <p>A Milli Futbol Takımımız, yıllar sonra Dünya Kupası’nda boy gösterecek.</p>
      <p>İçeriğin Devamı Aşağıda</p>
      <h2>2026 Dünya Kupası’na sayılı günler kala heyecan da artıyor.</h2>
      <p>Türkiye formasıyla Dünya Kupası’nda mücadele edecek oyuncuların forma numaraları şöyle:</p>
      <p>1 — Mert Günok</p>
      <p>2 — Zeki Çelik</p>
      <p>3 — Merih Demiral</p>
      <p>Yorumlar ve Emojiler Aşağıda</p>
      <p>Bu haberler de ilginizi çekebilir</p>
      <p>Alakasız öneri haber</p>
    </article>
  </body>
</html>
''');
      }),
    );

    final article = await reader.read(
      'https://onedio.com/haber/dunya-kupasi-nda-forma-giyecek-milli-takim-oyuncularinin-forma-numaralari-belli-oldu-1363203',
    );

    expect(article.title, 'Dünya Kupası forma numaraları belli oldu');
    expect(article.bodyText, contains('1 — Mert Günok'));
    expect(article.bodyText, contains('2 — Zeki Çelik'));
    expect(article.bodyText, contains('3 — Merih Demiral'));
    expect(article.bodyText, isNot(contains('Alakasız öneri haber')));
    expect(article.bodyText, isNot(contains('İçeriğin Devamı Aşağıda')));
  });

  test('geçersiz şemalı linki reddeder', () async {
    const reader = AdminNewsSourceReader();

    expect(
      () => reader.read('ftp://example.com/haber'),
      throwsA(isA<AdminNewsSourceReadException>()),
    );
  });
}

http.Response _htmlResponse(String html) {
  return http.Response.bytes(
    utf8.encode(html),
    200,
    headers: const {'content-type': 'text/html; charset=utf-8'},
  );
}
