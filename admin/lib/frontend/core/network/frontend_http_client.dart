import 'package:http/http.dart' as http;

/// Tüm frontend repository'lerinin paylaştığı tek HTTP client. Keep-alive
/// bağlantıları yeniden kullanır; soğuk açılışta tekrarlayan TLS el sıkışmalarını
/// azaltır. Uygulama ömrü boyunca yaşar — KAPATILMAZ.
///
/// Testlerde repository'lere `httpClient:` ile MockClient enjekte edildiğinde bu
/// client hiç kullanılmaz; üretimde ise `httpClient` verilmediğinde devreye girer.
final http.Client sharedFrontendClient = http.Client();
