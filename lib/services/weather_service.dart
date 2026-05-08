import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class WeatherSnapshot {
  final double currentTempC;
  final double minTempC;
  final double maxTempC;
  final int weatherCode;
  final bool isDay;

  WeatherSnapshot({
    required this.currentTempC,
    required this.minTempC,
    required this.maxTempC,
    required this.weatherCode,
    required this.isDay,
  });

  factory WeatherSnapshot.fromMap(Map<String, dynamic> map) {
    final current =
        map['current'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final daily = map['daily'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final minTemps =
        (daily['temperature_2m_min'] as List<dynamic>? ?? <dynamic>[]);
    final maxTemps =
        (daily['temperature_2m_max'] as List<dynamic>? ?? <dynamic>[]);

    return WeatherSnapshot(
      currentTempC: (current['temperature_2m'] as num?)?.toDouble() ?? 0,
      minTempC: minTemps.isNotEmpty ? (minTemps.first as num).toDouble() : 0,
      maxTempC: maxTemps.isNotEmpty ? (maxTemps.first as num).toDouble() : 0,
      weatherCode: (current['weather_code'] as num?)?.toInt() ?? -1,
      isDay: (current['is_day'] as num?)?.toInt() == 1,
    );
  }

  String get summary {
    switch (weatherCode) {
      case 0:
        return isDay ? 'Clear' : 'Clear night';
      case 1:
        return 'Mainly clear';
      case 2:
        return 'Partly cloudy';
      case 3:
        return 'Overcast';
      case 45:
      case 48:
        return 'Foggy';
      case 51:
      case 53:
      case 55:
      case 56:
      case 57:
        return 'Drizzle';
      case 61:
      case 63:
      case 65:
      case 66:
      case 67:
        return 'Rain';
      case 71:
      case 73:
      case 75:
      case 77:
        return 'Snow';
      case 80:
      case 81:
      case 82:
        return 'Showers';
      case 85:
      case 86:
        return 'Snow showers';
      case 95:
      case 96:
      case 99:
        return 'Stormy';
      default:
        return 'Forecast ready';
    }
  }
}

class WeatherService {
  static const String _baseUrl = 'https://api.open-meteo.com/v1/forecast';

  Future<WeatherSnapshot> fetchWeather({
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: <String, String>{
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'current': 'temperature_2m,weather_code,is_day',
        'daily': 'temperature_2m_max,temperature_2m_min',
        'forecast_days': '1',
        'temperature_unit': 'celsius',
        'timezone': 'auto',
      },
    );

    final response = await http.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Weather API error: ${response.statusCode} ${response.body}',
      );
    }

    final jsonBody = jsonDecode(response.body) as Map<String, dynamic>;
    return WeatherSnapshot.fromMap(jsonBody);
  }
}
