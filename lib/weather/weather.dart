import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';

import '../astro/sun_moon.dart';
import '../lunar/format.dart';

/// One day of forecast.
class DayWeather {
  const DayWeather({required this.date, required this.code, required this.max, required this.min, this.rain});

  final DateTime date;

  /// WMO weather code.
  final int code;
  final double max;
  final double min;

  /// Chance of rain, %.
  final int? rain;

  String get emoji => weatherOf(code).$1;
  String get description => weatherOf(code).$2;

  /// "24–31°C".
  String get range => '${min.round()}–${max.round()}°C';
}

/// Emoji and Vietnamese description of a WMO weather code.
(String, String) weatherOf(int code) => switch (code) {
  0 => ('☀️', 'Trời quang'),
  1 => ('🌤️', 'Ít mây'),
  2 => ('⛅', 'Có mây'),
  3 => ('☁️', 'Nhiều mây'),
  45 || 48 => ('🌫️', 'Sương mù'),
  51 || 53 || 55 || 56 || 57 => ('🌦️', 'Mưa phùn'),
  61 || 66 => ('🌧️', 'Mưa nhỏ'),
  63 => ('🌧️', 'Mưa vừa'),
  65 || 67 => ('🌧️', 'Mưa to'),
  71 || 73 || 75 || 77 || 85 || 86 => ('❄️', 'Tuyết'),
  80 || 81 => ('🌦️', 'Mưa rào'),
  82 => ('⛈️', 'Mưa rào rất to'),
  95 => ('⛈️', 'Dông'),
  96 || 99 => ('⛈️', 'Dông, mưa đá'),
  _ => ('🌡️', 'Không rõ'),
};

/// Parses Open-Meteo's daily forecast.
List<DayWeather> parseForecast(String body) {
  final daily = (jsonDecode(body) as Map<String, Object?>)['daily']! as Map<String, Object?>;
  final dates = (daily['time']! as List).cast<String>();
  final codes = daily['weather_code']! as List;
  final max = daily['temperature_2m_max']! as List;
  final min = daily['temperature_2m_min']! as List;
  final rain = daily['precipitation_probability_max'] as List?;
  return [
    for (var i = 0; i < dates.length; i++)
      if (codes[i] != null && max[i] != null && min[i] != null)
        DayWeather(
          date: DateTime.parse(dates[i]),
          code: (codes[i] as num).toInt(),
          max: (max[i] as num).toDouble(),
          min: (min[i] as num).toDouble(),
          rain: (rain?[i] as num?)?.toInt(),
        ),
  ];
}

/// Downloads Open-Meteo's 7-day daily forecast for [city] (free, no account).
Future<String> fetchOpenMeteo(City city) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': '${city.lat}',
      'longitude': '${city.lon}',
      'daily': 'weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max',
      'timezone': 'Asia/Bangkok',
      'forecast_days': '7',
    });
    final response = await (await client.getUrl(uri)).close().timeout(const Duration(seconds: 15));
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode != 200) throw HttpException('HTTP ${response.statusCode}');
    return body;
  } finally {
    client.close();
  }
}

/// A 7-day forecast, refreshed at most hourly or when the city changes. Needs the internet; failures are kept
/// quiet and shown as a retry. [fetch] is replaceable for tests.
class WeatherService extends ChangeNotifier {
  WeatherService({this.fetch = fetchOpenMeteo});

  final Future<String> Function(City city) fetch;
  List<DayWeather> forecast = [];
  bool loading = false;
  String? error;
  City? _city;
  DateTime? _fetched;

  DayWeather? on(DateTime date) => forecast.where((d) => sameDay(d.date, date)).firstOrNull;

  Future<void> refresh(City city, {bool force = false}) async {
    final fresh = _fetched != null && DateTime.now().difference(_fetched!) < const Duration(hours: 1);
    if (loading || (!force && fresh && _city == city)) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      forecast = parseForecast(await fetch(city));
      _city = city;
      _fetched = DateTime.now();
    } on Object {
      error = 'Không tải được thời tiết. Kiểm tra kết nối mạng.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}

class WeatherScope extends InheritedNotifier<WeatherService> {
  const WeatherScope({super.key, required WeatherService service, required super.child}) : super(notifier: service);

  static WeatherService of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<WeatherScope>()!.notifier!;
}
