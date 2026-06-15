import 'package:flutter/material.dart';

/// Türkçe-duyarsız (aksan + büyük/küçük harf) arama normalizasyonu.
///
/// Sunucudaki `pateez_admin_normalize_search_text` (unaccent + lower) ile aynı
/// mantığı izler: ş→s, ı/İ/I→i, ç→c, ğ→g, ö→o, ü→u, â→a … Böylece istemci
/// tarafı anlık filtre ve highlight, sunucu aramasıyla tutarlı sonuç verir.
///
/// Eşleme kod-birimi (UTF-16) başına **1:1** yapıldığından metnin uzunluğu
/// korunur; normalize edilmiş metindeki eşleşme index'leri orijinal metne
/// birebir karşılık gelir (emoji/surrogate çiftleri olduğu gibi bırakılır).
int _normalizeUnit(int unit) {
  switch (unit) {
    case 0x49: // I
    case 0x69: // i
    case 0x131: // ı
    case 0x130: // İ
    case 0xCE: // Î
    case 0xEE: // î
      return 0x69; // i
    case 0x53: // S
    case 0x73: // s
    case 0x15E: // Ş
    case 0x15F: // ş
      return 0x73; // s
    case 0x47: // G
    case 0x67: // g
    case 0x11E: // Ğ
    case 0x11F: // ğ
      return 0x67; // g
    case 0x55: // U
    case 0x75: // u
    case 0xDC: // Ü
    case 0xFC: // ü
    case 0xDB: // Û
    case 0xFB: // û
      return 0x75; // u
    case 0x4F: // O
    case 0x6F: // o
    case 0xD6: // Ö
    case 0xF6: // ö
      return 0x6F; // o
    case 0x43: // C
    case 0x63: // c
    case 0xC7: // Ç
    case 0xE7: // ç
      return 0x63; // c
    case 0x41: // A
    case 0x61: // a
    case 0xC2: // Â
    case 0xE2: // â
      return 0x61; // a
  }
  if (unit >= 0x41 && unit <= 0x5A) return unit + 0x20; // A-Z → a-z
  return unit;
}

/// Metni arama için normalize eder (uzunluk korunur).
String normalizeSearchText(String input) {
  if (input.isEmpty) return input;
  final units = input.codeUnits;
  final out = List<int>.filled(units.length, 0);
  for (var i = 0; i < units.length; i++) {
    out[i] = _normalizeUnit(units[i]);
  }
  return String.fromCharCodes(out);
}

List<String> _queryTokens(String query) {
  if (query.trim().isEmpty) return const [];
  return normalizeSearchText(query)
      .split(RegExp(r'\s+'))
      .where((token) => token.isNotEmpty)
      .toList(growable: false);
}

/// [haystack] içinde [query]'deki tüm kelimeler (AND) geçiyor mu?
/// Anlık istemci filtresi bunu kullanır.
bool searchMatchesAll(String haystack, String query) {
  final tokens = _queryTokens(query);
  if (tokens.isEmpty) return true;
  final normalized = normalizeSearchText(haystack);
  for (final token in tokens) {
    if (!normalized.contains(token)) return false;
  }
  return true;
}

class _MatchRange {
  const _MatchRange(this.start, this.end);
  final int start;
  final int end;
}

List<_MatchRange> _matchRanges(String source, String query) {
  final tokens = _queryTokens(query);
  if (tokens.isEmpty || source.isEmpty) return const [];
  final normalized = normalizeSearchText(source);
  final raw = <_MatchRange>[];
  for (final token in tokens) {
    var from = 0;
    while (from <= normalized.length - token.length) {
      final index = normalized.indexOf(token, from);
      if (index < 0) break;
      raw.add(_MatchRange(index, index + token.length));
      from = index + token.length;
    }
  }
  if (raw.isEmpty) return const [];
  raw.sort((a, b) => a.start.compareTo(b.start));
  final merged = <_MatchRange>[];
  for (final range in raw) {
    if (merged.isNotEmpty && range.start <= merged.last.end) {
      final last = merged.removeLast();
      merged.add(_MatchRange(last.start, range.end > last.end ? range.end : last.end));
    } else {
      merged.add(range);
    }
  }
  return merged;
}

/// Eşleşen arama kelimelerini sarı zeminle vurgulayan metin.
///
/// [query] boşsa veya eşleşme yoksa düz [Text] gibi davranır (ekstra maliyet
/// yok). Eşleşme varsa yalnızca eşleşen parçalara [highlightStyle] uygulanır.
class HighlightedText extends StatelessWidget {
  const HighlightedText(
    this.text, {
    super.key,
    required this.query,
    this.style,
    this.highlightStyle,
    this.maxLines,
    this.overflow,
    this.textAlign,
  });

  final String text;
  final String query;
  final TextStyle? style;
  final TextStyle? highlightStyle;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  /// Klasik arama vurgusu — sıcak sarı zemin (tarayıcı Ctrl+F hissi).
  static const Color highlightColor = Color(0xFFFFE082);

  @override
  Widget build(BuildContext context) {
    final ranges = _matchRanges(text, query);
    if (ranges.isEmpty) {
      return Text(
        text,
        style: style,
        maxLines: maxLines,
        overflow: overflow,
        textAlign: textAlign,
      );
    }

    final matchStyle =
        (highlightStyle ?? const TextStyle(fontWeight: FontWeight.w700)).copyWith(
          backgroundColor: highlightStyle?.backgroundColor ?? highlightColor,
        );

    final spans = <TextSpan>[];
    var cursor = 0;
    for (final range in ranges) {
      if (range.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, range.start)));
      }
      spans.add(
        TextSpan(text: text.substring(range.start, range.end), style: matchStyle),
      );
      cursor = range.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }

    return Text.rich(
      TextSpan(style: style, children: spans),
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
    );
  }
}
