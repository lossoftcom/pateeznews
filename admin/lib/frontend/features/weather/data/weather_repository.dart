import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../core/network/frontend_http_client.dart';
import 'package:pateeznews_admin/shared/icons/symbols.dart';

import '../../../core/network/local_api_base_url.dart';
import '../../../core/theme/app_colors.dart';

@immutable
class WeatherData {
  const WeatherData({
    required this.location,
    required this.country,
    required this.latitude,
    required this.longitude,
    required this.timezone,
    required this.source,
    required this.serviceDateLabel,
    required this.fetchedAt,
    required this.updateIntervalMinutes,
    required this.current,
    required this.hourly,
    required this.daily,
    required this.errorMessage,
  });

  const WeatherData.empty({this.errorMessage = ''})
    : location = 'Niğde',
      country = 'Türkiye',
      latitude = 37.96583,
      longitude = 34.67935,
      timezone = 'Europe/Istanbul',
      source = 'Open-Meteo',
      serviceDateLabel = '',
      fetchedAt = '',
      updateIntervalMinutes = 30,
      current = const WeatherCurrent.empty(),
      hourly = const [],
      daily = const [];

  factory WeatherData.fromJson(Map<dynamic, dynamic> json) {
    return WeatherData(
      location: _string(json['location'], fallback: 'Niğde'),
      country: _string(json['country'], fallback: 'Türkiye'),
      latitude: _double(json['latitude'], 37.96583),
      longitude: _double(json['longitude'], 34.67935),
      timezone: _string(json['timezone'], fallback: 'Europe/Istanbul'),
      source: _string(json['source'], fallback: 'Open-Meteo'),
      serviceDateLabel: _string(json['serviceDateLabel']),
      fetchedAt: _string(json['fetchedAt']),
      updateIntervalMinutes: _int(json['updateIntervalMinutes'], 30),
      current: json['current'] is Map
          ? WeatherCurrent.fromJson(json['current'] as Map)
          : const WeatherCurrent.empty(),
      hourly: [
        for (final row
            in (json['hourly'] is List ? json['hourly'] as List : const []))
          if (row is Map) WeatherHour.fromJson(row),
      ],
      daily: [
        for (final row
            in (json['daily'] is List ? json['daily'] as List : const []))
          if (row is Map) WeatherDay.fromJson(row),
      ],
      errorMessage: _string(json['error']),
    );
  }

  final String location;
  final String country;
  final double latitude;
  final double longitude;
  final String timezone;
  final String source;
  final String serviceDateLabel;
  final String fetchedAt;
  final int updateIntervalMinutes;
  final WeatherCurrent current;
  final List<WeatherHour> hourly;
  final List<WeatherDay> daily;
  final String errorMessage;

  bool get hasWeather => current.hasValue;

  String get conditionLabel => weatherConditionLabel(current.weatherCode);

  int get weekMin {
    if (daily.isEmpty) return current.temperature;
    return daily
        .map((day) => day.min)
        .reduce((left, right) => left < right ? left : right);
  }

  int get weekMax {
    if (daily.isEmpty) return current.temperature;
    return daily
        .map((day) => day.max)
        .reduce((left, right) => left > right ? left : right);
  }

  WeatherDay? get today => daily.isEmpty ? null : daily.first;
}

@immutable
class WeatherCurrent {
  const WeatherCurrent({
    required this.temperature,
    required this.apparentTemperature,
    required this.humidity,
    required this.weatherCode,
    required this.isDay,
    required this.precipitation,
    required this.rain,
    required this.showers,
    required this.snowfall,
    required this.cloudCover,
    required this.pressure,
    required this.surfacePressure,
    required this.windSpeed,
    required this.windDirection,
    required this.windGusts,
    required this.time,
  });

  const WeatherCurrent.empty()
    : temperature = 0,
      apparentTemperature = 0,
      humidity = 0,
      weatherCode = 2,
      isDay = true,
      precipitation = 0,
      rain = 0,
      showers = 0,
      snowfall = 0,
      cloudCover = 0,
      pressure = 0,
      surfacePressure = 0,
      windSpeed = 0,
      windDirection = 0,
      windGusts = 0,
      time = '';

  factory WeatherCurrent.fromJson(Map<dynamic, dynamic> json) {
    return WeatherCurrent(
      temperature: _int(json['temperature'], 0),
      apparentTemperature: _int(json['apparentTemperature'], 0),
      humidity: _int(json['humidity'], 0),
      weatherCode: _int(json['weatherCode'], 2),
      isDay: _int(json['isDay'], 1) != 0,
      precipitation: _double(json['precipitation'], 0),
      rain: _double(json['rain'], 0),
      showers: _double(json['showers'], 0),
      snowfall: _double(json['snowfall'], 0),
      cloudCover: _int(json['cloudCover'], 0),
      pressure: _int(json['pressure'], 0),
      surfacePressure: _int(json['surfacePressure'], 0),
      windSpeed: _int(json['windSpeed'], 0),
      windDirection: _int(json['windDirection'], 0),
      windGusts: _int(json['windGusts'], 0),
      time: _string(json['time']),
    );
  }

  final int temperature;
  final int apparentTemperature;
  final int humidity;
  final int weatherCode;
  final bool isDay;
  final double precipitation;
  final double rain;
  final double showers;
  final double snowfall;
  final int cloudCover;
  final int pressure;
  final int surfacePressure;
  final int windSpeed;
  final int windDirection;
  final int windGusts;
  final String time;

  bool get hasValue => time.isNotEmpty || temperature != 0 || weatherCode != 2;
}

@immutable
class WeatherHour {
  const WeatherHour({
    required this.time,
    required this.label,
    required this.temperature,
    required this.apparentTemperature,
    required this.humidity,
    required this.weatherCode,
    required this.isDay,
    required this.precipitationProbability,
    required this.precipitation,
    required this.windSpeed,
  });

  factory WeatherHour.fromJson(Map<dynamic, dynamic> json) {
    return WeatherHour(
      time: _string(json['time']),
      label: _string(json['label']),
      temperature: _int(json['temperature'], 0),
      apparentTemperature: _int(json['apparentTemperature'], 0),
      humidity: _int(json['humidity'], 0),
      weatherCode: _int(json['weatherCode'], 2),
      isDay: _int(json['isDay'], 1) != 0,
      precipitationProbability: _int(json['precipitationProbability'], 0),
      precipitation: _double(json['precipitation'], 0),
      windSpeed: _int(json['windSpeed'], 0),
    );
  }

  final String time;
  final String label;
  final int temperature;
  final int apparentTemperature;
  final int humidity;
  final int weatherCode;
  final bool isDay;
  final int precipitationProbability;
  final double precipitation;
  final int windSpeed;
}

@immutable
class WeatherDay {
  const WeatherDay({
    required this.date,
    required this.label,
    required this.weatherCode,
    required this.max,
    required this.min,
    required this.apparentMax,
    required this.apparentMin,
    required this.precipitationSum,
    required this.precipitationProbability,
    this.precipitationHourLabel = '',
    required this.windSpeedMax,
    required this.sunrise,
    required this.sunset,
    required this.uvIndex,
  });

  factory WeatherDay.fromJson(Map<dynamic, dynamic> json) {
    return WeatherDay(
      date: _string(json['date']),
      label: _string(json['label']),
      weatherCode: _int(json['weatherCode'], 2),
      max: _int(json['max'], 0),
      min: _int(json['min'], 0),
      apparentMax: _int(json['apparentMax'], 0),
      apparentMin: _int(json['apparentMin'], 0),
      precipitationSum: _double(json['precipitationSum'], 0),
      precipitationProbability: _int(json['precipitationProbability'], 0),
      precipitationHourLabel: _string(json['precipitationHourLabel']),
      windSpeedMax: _int(json['windSpeedMax'], 0),
      sunrise: _string(json['sunrise']),
      sunset: _string(json['sunset']),
      uvIndex: _double(json['uvIndex'], 0),
    );
  }

  final String date;
  final String label;
  final int weatherCode;
  final int max;
  final int min;
  final int apparentMax;
  final int apparentMin;
  final double precipitationSum;
  final int precipitationProbability;
  final String precipitationHourLabel;
  final int windSpeedMax;
  final String sunrise;
  final String sunset;
  final double uvIndex;
}

enum WeatherMotionKind { clearDay, clearNight, cloudy, fog, rain, snow, storm }

WeatherMotionKind weatherMotionKind(int code, bool isDay) {
  if (code >= 95) return WeatherMotionKind.storm;
  if ((code >= 71 && code <= 77) || code == 85 || code == 86) {
    return WeatherMotionKind.snow;
  }
  if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) {
    return WeatherMotionKind.rain;
  }
  if (code == 45 || code == 48) return WeatherMotionKind.fog;
  if (code == 0) {
    return isDay ? WeatherMotionKind.clearDay : WeatherMotionKind.clearNight;
  }
  return WeatherMotionKind.cloudy;
}

IconData weatherIcon(int code, bool isDay) {
  return switch (weatherMotionKind(code, isDay)) {
    WeatherMotionKind.clearDay => Symbols.sun_fill,
    WeatherMotionKind.clearNight => Symbols.moon_clear_fill,
    WeatherMotionKind.cloudy =>
      isDay ? Symbols.sun_cloudy_fill : Symbols.moon_cloudy_fill,
    WeatherMotionKind.fog => Symbols.foggy_fill,
    WeatherMotionKind.rain => Symbols.rainy_fill,
    WeatherMotionKind.snow => Symbols.cloudy_fill,
    WeatherMotionKind.storm => Symbols.rainy_fill,
  };
}

Color weatherTint(int code, bool isDay) {
  return switch (weatherMotionKind(code, isDay)) {
    WeatherMotionKind.clearDay ||
    WeatherMotionKind.cloudy => AppColors.warmHorizon,
    WeatherMotionKind.clearNight => AppColors.deepOcean,
    WeatherMotionKind.fog => AppColors.support,
    WeatherMotionKind.rain ||
    WeatherMotionKind.snow ||
    WeatherMotionKind.storm => AppColors.deepOcean,
  };
}

String weatherPrecipitationLabel(int code, bool isDay) {
  return switch (weatherMotionKind(code, isDay)) {
    WeatherMotionKind.snow => 'Kar',
    WeatherMotionKind.rain || WeatherMotionKind.storm => 'Yağmur',
    _ => 'Yağış',
  };
}

String weatherConditionLabel(int code) {
  if (code == 0) return 'Açık';
  if (code == 1) return 'Az bulutlu';
  if (code == 2) return 'Parçalı bulutlu';
  if (code == 3) return 'Kapalı';
  if (code == 45 || code == 48) return 'Sisli';
  if (code >= 51 && code <= 57) return 'Çisenti';
  if (code >= 61 && code <= 67) return 'Yağmurlu';
  if (code >= 71 && code <= 77) return 'Karlı';
  if (code >= 80 && code <= 82) return 'Sağanak yağışlı';
  if (code == 85 || code == 86) return 'Kar sağanağı';
  if (code >= 95) return 'Gök gürültülü';
  return 'Parçalı bulutlu';
}

class WeatherRepository {
  const WeatherRepository({this.httpClient, this.apiBaseUrl});

  static const _apiBaseUrl = String.fromEnvironment('PATEEZNEWS_API_BASE_URL');
  static const _timeout = Duration(seconds: 13);

  final http.Client? httpClient;
  final String? apiBaseUrl;

  Future<WeatherData> fetch({bool forceRefresh = false}) async {
    final uri = _uri(
      '/api/app/weather?lang=tr${forceRefresh ? '&refresh=1' : ''}',
    );
    final client = httpClient ?? sharedFrontendClient;
    try {
      final response = await client
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(_timeout);
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map) return const WeatherData.empty();
      final data = WeatherData.fromJson(decoded);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return WeatherData.empty(
          errorMessage: data.errorMessage.isEmpty
              ? 'Hava durumu alınamadı'
              : data.errorMessage,
        );
      }
      return data;
    } catch (_) {
      return const WeatherData.empty(errorMessage: 'Hava durumu alınamadı');
    } finally {
      // Shared frontend client is not closed.
    }
  }

  Uri _uri(String path) {
    return frontendApiUri(path, configuredBaseUrl: apiBaseUrl ?? _apiBaseUrl);
  }
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
  final parsed = double.tryParse(value?.toString() ?? '');
  return parsed ?? fallback;
}
