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
        "image": {
          "@type": "ImageObject",
          "url": "https://cdn.example.com/news/bahceli-yagis.webp"
        },
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
    expect(article.images, hasLength(1));
    expect(
      article.images.first.url,
      'https://cdn.example.com/news/bahceli-yagis.webp',
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
    <meta property="og:image" content="/uploads/world-cup-cover.jpg">
  </head>
  <body>
    <header>Giriş Yap</header>
    <article>
      <h1>Dünya Kupası’nda Forma Giyecek Milli Takım Oyuncularının Forma Numaraları Belli Oldu</h1>
      <p>A Milli Futbol Takımımız, yıllar sonra Dünya Kupası’nda boy gösterecek.</p>
      <img src="/uploads/world-cup-body-small.jpg" srcset="/uploads/world-cup-body-small.jpg 480w, /uploads/world-cup-body-large.jpg 1200w" alt="Milli takım oyuncuları">
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
    expect(article.images.map((image) => image.url), [
      'https://onedio.com/uploads/world-cup-cover.jpg',
      'https://onedio.com/uploads/world-cup-body-large.jpg',
      'https://onedio.com/uploads/world-cup-body-small.jpg',
    ]);
    expect(article.images.last.alt, 'Milli takım oyuncuları');
  });

  test('haber içindeki öneri görsellerini kaynak görsel saymaz', () async {
    final reader = AdminNewsSourceReader(
      httpClient: MockClient((request) async {
        return _htmlResponse('''
<!doctype html>
<html>
  <head>
    <meta property="og:title" content="Sağanak ve dolu yağışı meyveleri vurdu">
    <meta property="og:image" content="/uploads/saganak-dolu-main.jpg">
  </head>
  <body>
    <div class="article-text container-padding" property="articleBody">
      <p>Niğde’de etkili olan sağanak yağmur ve dolu yağışı, tarım alanlarında zarara neden oldu.</p>
      <p>Şehir genelinde etkili olan yağışın ardından bazı bölgelerde dolu kısa sürede etkisini artırdı.</p>
      <p>Üreticiler, dolunun etkisiyle meyvelerde hasar oluştuğunu ifade etti.</p>
      <div class="post-flash">
        <img src="/uploads/depo-yangini.jpg" alt="Niğde’de depo yangını korkuttu">
      </div>
    </div>
    <section class="related-news">
      <img src="/uploads/ilgili-haber.jpg" alt="İlgili haber">
    </section>
  </body>
</html>
''');
      }),
    );

    final article = await reader.read(
      'https://www.dmchaber.com/saganak-ve-dolu-yagisi-nigdede-meyveleri-vurdu',
    );

    expect(article.images.map((image) => image.url), [
      'https://www.dmchaber.com/uploads/saganak-dolu-main.jpg',
    ]);
  });

  test(
    'Mynet detay kutusunda banner ve ilgili haber görsellerini atar',
    () async {
      final reader = AdminNewsSourceReader(
        httpClient: MockClient((request) async {
          return _htmlResponse('''
<!doctype html>
<html>
  <head>
    <meta property="og:title" content="Kahramanmaraş'ta korkutan patlama: Deprem olduğunu düşündük">
    <meta property="og:image" content="https://imgrosetta.mynet.com.tr/file/24936004/24936004-1200x675.jpg">
    <script type="application/ld+json">
      {
        "@context": "https://schema.org",
        "@type": "NewsArticle",
        "headline": "Kahramanmaraş'ta korkutan patlama: Deprem olduğunu düşündük",
        "image": {
          "@type": "ImageObject",
          "url": "https://imgrosetta.mynet.com.tr/file/24936004/24936004-1200x675.jpg"
        },
        "articleBody": "Edinilen bilgilere göre olay merkez Onikişubat ilçesinde meydana geldi. Patlama sonrası çevreyi yoğun gaz kokusu sardı. Görgü tanıkları ilk anda deprem olduğunu düşündüklerini söyledi."
      }
    </script>
  </head>
  <body>
    <div class="detail-content-box ng-detail-content-box" property="articleBody">
      <h1>Kahramanmaraş'ta korkutan patlama: Deprem olduğunu düşündük</h1>
      <div class="feature-media">
        <img class="img-responsive" src="https://imgrosetta.mynet.com.tr/file/24936004/24936004-860x480.jpg" alt="Kahramanmaraş'ta korkutan patlama">
      </div>
      <div class="mymani-layout-banner">
        <img src="https://imgrosetta.mynet.com.tr/file/24628462/24628462-1200xauto.png" alt="banner">
      </div>
      <div class="detail-content-inner">
        <p>Edinilen bilgilere göre olay merkez Onikişubat ilçesinde meydana geldi.</p>
        <p><img class="in-text-image" src="https://imgrosetta.mynet.com.tr/file/24936010/1200xauto.jpg" alt="Kahramanmaraş ta korkutan patlama 1"></p>
        <p>Patlama sonrası çevreyi yoğun gaz kokusu sardı.</p>
        <p><img class="in-text-image" src="https://imgrosetta.mynet.com.tr/file/24936046/1200xauto.jpg" alt="Kahramanmaraş ta korkutan patlama 2"></p>
        <p>Görgü tanıkları ilk anda deprem olduğunu düşündüklerini söyledi.</p>
        <div class="ng-other-news-container haber">
          <div class="ng-other-news">
            <img src="https://imgrosetta.mynet.com.tr/file/24937393/24937393-320x184.jpg" alt="Sivas Off-Road yarışlarına rekor başvuru">
          </div>
          <div class="ng-other-news">
            <img src="https://imgrosetta.mynet.com.tr/file/24937363/24937363-320x184.jpg" alt="Kıskıvrak yakalandı">
          </div>
        </div>
      </div>
    </div>
  </body>
</html>
''');
        }),
      );

      final article = await reader.read(
        'https://haber.mynet.com/kahramanmaras-ta-korkutan-patlama-deprem-oldugunu-dusunduk-110107296748',
      );

      expect(article.images.map((image) => image.url), [
        'https://imgrosetta.mynet.com.tr/file/24936004/24936004-1200x675.jpg',
        'https://imgrosetta.mynet.com.tr/file/24936010/1200xauto.jpg',
        'https://imgrosetta.mynet.com.tr/file/24936046/1200xauto.jpg',
      ]);
    },
  );

  test(
    'JSON-LD quiz soru cevaplarını ve görsellerini kaynak metnine ekler',
    () async {
      final reader = AdminNewsSourceReader(
        httpClient: MockClient((request) async {
          return _htmlResponse('''
<!doctype html>
<html>
  <head>
    <script type="application/ld+json">
      {
        "@context": "https://schema.org",
        "@type": "Quiz",
        "name": "Dünya Kupası forma numarası testi",
        "description": "Milli takım forma numaralarını ölçen kısa test.",
        "image": "https://cdn.example.com/quiz/cover.jpg",
        "mainEntity": [
          {
            "@type": "Question",
            "name": "Arda Güler hangi forma numarasını giydi?",
            "image": "https://cdn.example.com/quiz/arda.jpg",
            "acceptedAnswer": {"@type": "Answer", "text": "10"},
            "suggestedAnswer": [
              {"@type": "Answer", "text": "8"},
              {"@type": "Answer", "text": "10"},
              {"@type": "Answer", "text": "14"}
            ]
          },
          {
            "@type": "Question",
            "name": "Mert Günok listede hangi numarayla yer aldı?",
            "acceptedAnswer": {"@type": "Answer", "text": "1"},
            "suggestedAnswer": [
              {"@type": "Answer", "text": "1"},
              {"@type": "Answer", "text": "12"}
            ]
          }
        ]
      }
    </script>
  </head>
  <body><main>Quiz sayfası</main></body>
</html>
''');
        }),
      );

      final article = await reader.read(
        'https://onedio.com/test/dunya-kupasi-forma-numarasi-testi',
      );

      expect(article.bodyText, contains('Test başlığı: Dünya Kupası'));
      expect(article.bodyText, contains('Test sorusu: Arda Güler'));
      expect(article.bodyText, contains('Doğru cevap: 10'));
      expect(article.bodyText, contains('Cevap: 14'));
      expect(article.images.map((image) => image.url), [
        'https://cdn.example.com/quiz/cover.jpg',
        'https://cdn.example.com/quiz/arda.jpg',
      ]);
    },
  );

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
