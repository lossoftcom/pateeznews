import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/network/frontend_http_client.dart';

import '../../../core/network/local_api_base_url.dart';

@immutable
class MarketsData {
  const MarketsData({
    required this.enabled,
    required this.provider,
    required this.source,
    required this.serviceDateLabel,
    required this.fetchedAt,
    required this.updateIntervalSeconds,
    required this.currencies,
    required this.gold,
    required this.errorMessage,
  });

  const MarketsData.empty({this.errorMessage = ''})
    : enabled = true,
      provider = 'genelpara',
      source = 'GenelPara',
      serviceDateLabel = '',
      fetchedAt = '',
      updateIntervalSeconds = 180,
      currencies = const [],
      gold = const [];

  factory MarketsData.fromJson(Map<dynamic, dynamic> json) {
    return MarketsData(
      enabled: json['enabled'] != false,
      provider: _string(json['provider'], fallback: 'genelpara'),
      source: _string(json['source'], fallback: 'GenelPara'),
      serviceDateLabel: _string(json['serviceDateLabel']),
      fetchedAt: _string(json['fetchedAt']),
      updateIntervalSeconds: _int(json['updateIntervalSeconds'], 180),
      currencies: [
        for (final row
            in (json['currencies'] is List
                ? json['currencies'] as List
                : const []))
          if (row is Map) MarketRate.fromJson(row),
      ],
      gold: [
        for (final row
            in (json['gold'] is List ? json['gold'] as List : const []))
          if (row is Map) MarketRate.fromJson(row),
      ],
      errorMessage: _string(json['error']),
    );
  }

  final bool enabled;
  final String provider;
  final String source;
  final String serviceDateLabel;
  final String fetchedAt;
  final int updateIntervalSeconds;
  final List<MarketRate> currencies;
  final List<MarketRate> gold;
  final String errorMessage;

  bool get hasMarkets => currencies.isNotEmpty || gold.isNotEmpty;
}

@immutable
class MarketRate {
  const MarketRate({
    required this.id,
    required this.symbol,
    required this.name,
    required this.bid,
    required this.ask,
    required this.changeAmount,
    required this.changePercent,
    required this.up,
    required this.currencyCode,
    required this.currencySymbol,
    this.secondaryBid,
    this.secondaryAsk,
    this.secondaryCurrencyCode = '',
    this.secondaryCurrencySymbol = '',
    required this.timestamp,
  });

  factory MarketRate.fromJson(Map<dynamic, dynamic> json) {
    return MarketRate(
      id: _string(json['id']),
      symbol: _string(json['symbol']),
      name: _string(json['name']),
      bid: _double(json['bid'], 0),
      ask: _double(json['ask'], 0),
      changeAmount: _nullableDouble(json['changeAmount']),
      changePercent: _nullableDouble(json['changePercent']),
      up: json['isUp'] != false,
      currencyCode: _string(json['currencyCode'], fallback: 'TRY'),
      currencySymbol: _string(json['currencySymbol'], fallback: '₺'),
      secondaryBid: _nullableDouble(json['secondaryBid']),
      secondaryAsk: _nullableDouble(json['secondaryAsk']),
      secondaryCurrencyCode: _string(json['secondaryCurrencyCode']),
      secondaryCurrencySymbol: _string(json['secondaryCurrencySymbol']),
      timestamp: _string(json['timestamp']),
    );
  }

  final String id;
  final String symbol;
  final String name;
  final double bid;
  final double ask;
  final double? changeAmount;
  final double? changePercent;
  final bool up;
  final String currencyCode;
  final String currencySymbol;
  final double? secondaryBid;
  final double? secondaryAsk;
  final String secondaryCurrencyCode;
  final String secondaryCurrencySymbol;
  final String timestamp;

  String get code => symbol;
  String get price => '$currencySymbol${formatMarketValue(ask)}';
  String get bidLabel => '$currencySymbol${formatMarketValue(bid)}';
  String get askLabel => '$currencySymbol${formatMarketValue(ask)}';
  bool get hasSecondaryAsk =>
      secondaryAsk != null &&
      secondaryCurrencyCode.isNotEmpty &&
      secondaryCurrencySymbol.isNotEmpty;
  String get secondaryAskLabel => hasSecondaryAsk
      ? '$secondaryCurrencySymbol${formatMarketValue(secondaryAsk!)}'
      : '';
  String get changePct {
    final value = changePercent;
    if (value == null) return 'Canlı';
    final sign = value > 0 ? '+' : '';
    return '$sign${value.toStringAsFixed(2).replaceAll('.', ',')}%';
  }

  List<double> get spark {
    final base = ask == 0 ? 1.0 : ask;
    final direction = up ? 1.0 : -1.0;
    final intensity = ((changePercent ?? 0).abs() / 100)
        .clamp(0.006, 0.055)
        .toDouble();
    return List<double>.generate(7, (index) {
      final drift = (index - 3) * intensity * direction;
      final wave = (index.isEven ? 0.004 : -0.003) * base;
      return base + (base * drift) + wave;
    });
  }
}

class MarketsRepository {
  const MarketsRepository({this.httpClient, this.apiBaseUrl});

  static const _apiBaseUrl = String.fromEnvironment('PATEEZNEWS_API_BASE_URL');
  static const _timeout = Duration(seconds: 13);

  final http.Client? httpClient;
  final String? apiBaseUrl;

  Future<MarketsData> fetch({bool forceRefresh = false}) async {
    final uri = _uri(
      '/api/app/markets?lang=tr${forceRefresh ? '&refresh=1' : ''}',
    );
    final client = httpClient ?? sharedFrontendClient;
    try {
      final response = await client
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(_timeout);
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map) return const MarketsData.empty();
      final data = MarketsData.fromJson(decoded);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return MarketsData.empty(
          errorMessage: data.errorMessage.isEmpty
              ? 'Piyasa verisi alınamadı'
              : data.errorMessage,
        );
      }
      return data;
    } catch (_) {
      return const MarketsData.empty(errorMessage: 'Piyasa verisi alınamadı');
    } finally {
      // Shared frontend client is not closed.
    }
  }

  Uri _uri(String path) {
    return frontendApiUri(path, configuredBaseUrl: apiBaseUrl ?? _apiBaseUrl);
  }
}

String formatMarketValue(double value) {
  final digits = value >= 100 ? 2 : 4;
  final fixed = value.toStringAsFixed(digits);
  final parts = fixed.split('.');
  final whole = parts.first.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  return parts.length == 1 ? whole : '$whole,${parts.last}';
}

String _string(Object? value, {String fallback = ''}) {
  final result = (value ?? '').toString().trim();
  return result.isEmpty ? fallback : result;
}

int _int(Object? value, int fallback) {
  final parsed = num.tryParse(value?.toString() ?? '');
  return parsed?.round() ?? fallback;
}

double _double(Object? value, double fallback) {
  final parsed = double.tryParse(
    (value?.toString() ?? '').replaceAll(',', '.'),
  );
  return parsed ?? fallback;
}

double? _nullableDouble(Object? value) {
  if (value == null) return null;
  return double.tryParse(value.toString().replaceAll(',', '.'));
}
