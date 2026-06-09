import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class AmbeeSoilSnapshot {
  const AmbeeSoilSnapshot({
    this.soilMoisture,
    this.soilTemperatureC,
    this.surfaceTemperatureC,
    this.humidity,
    this.updatedAt,
    this.source = 'Ambee',
  });

  final double? soilMoisture;
  final double? soilTemperatureC;
  final double? surfaceTemperatureC;
  final double? humidity;
  final DateTime? updatedAt;
  final String source;

  bool get hasLiveSoilData =>
      soilMoisture != null ||
      soilTemperatureC != null ||
      surfaceTemperatureC != null ||
      humidity != null;
}

class AmbeeSoilApi {
  static const String _baseUrl = 'https://api.ambeedata.com';

  Future<AmbeeSoilSnapshot> latestByLatLng({
    required double latitude,
    required double longitude,
  }) async {
    final apiKey = _requireApiKey();
    final uri = Uri.parse('$_baseUrl/soil/latest/by-lat-lng').replace(
      queryParameters: <String, String>{
        'lat': latitude.toString(),
        'lng': longitude.toString(),
      },
    );

    final response = await http.get(
      uri,
      headers: <String, String>{
        'x-api-key': apiKey,
        'Content-type': 'application/json',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('Ambee soil error: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Unexpected Ambee soil response');
    }

    return _snapshotFromMap(decoded);
  }

  String _requireApiKey() {
    final apiKey = dotenv.env['AMBEE_API_KEY'];
    if (apiKey == null || apiKey.trim().isEmpty) {
      throw StateError('AMBEE_API_KEY is missing from .env');
    }
    return apiKey.trim();
  }

  AmbeeSoilSnapshot _snapshotFromMap(Map<String, dynamic> body) {
    final candidates = <Map<String, dynamic>>[
      body,
      if (body['data'] is Map<String, dynamic>) body['data'] as Map<String, dynamic>,
      if (body['soil'] is Map<String, dynamic>) body['soil'] as Map<String, dynamic>,
      if (body['stations'] is List<dynamic>)
        ...(body['stations'] as List<dynamic>).whereType<Map<String, dynamic>>(),
    ];

    Map<String, dynamic> merged = <String, dynamic>{};
    for (final candidate in candidates) {
      merged = <String, dynamic>{...merged, ...candidate};
    }

    return AmbeeSoilSnapshot(
      soilMoisture: _numberFromAny(
        merged,
        const <String>[
          'soil_moisture',
          'soilMoisture',
          'moisture',
          'sm',
          'soilWaterContent',
        ],
      ),
      soilTemperatureC: _numberFromAny(
        merged,
        const <String>[
          'soil_temperature',
          'soilTemperature',
          'soilTemp',
          'st',
        ],
      ),
      surfaceTemperatureC: _numberFromAny(
        merged,
        const <String>[
          'surface_temperature',
          'surfaceTemperature',
          'temperature',
          'temp',
        ],
      ),
      humidity: _numberFromAny(merged, const <String>['humidity', 'rh']),
      updatedAt: _dateFromAny(
        merged,
        const <String>['updatedAt', 'updated_at', 'time', 'timestamp'],
      ),
    );
  }

  double? _numberFromAny(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is num) {
        return value.toDouble();
      }
      if (value is String) {
        return double.tryParse(value);
      }
    }
    return null;
  }

  DateTime? _dateFromAny(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is String) {
        return DateTime.tryParse(value);
      }
    }
    return null;
  }
}
