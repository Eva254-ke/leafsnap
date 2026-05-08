import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class INaturalistObservation {
  final int id;
  final String title;
  final String? commonName;
  final String? imageUrl;

  INaturalistObservation({
    required this.id,
    required this.title,
    this.commonName,
    this.imageUrl,
  });

  factory INaturalistObservation.fromMap(Map<String, dynamic> map) {
    final taxon = map['taxon'] as Map<String, dynamic>?;
    final photos = (map['photos'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final defaultPhoto = taxon?['default_photo'] as Map<String, dynamic>?;
    final firstPhoto = photos.isNotEmpty ? photos.first : null;
    final directUrl = (defaultPhoto?['medium_url'] as String?) ??
      (defaultPhoto?['url'] as String?) ??
      (firstPhoto?['original_url'] as String?) ??
      (firstPhoto?['url'] as String?);
    final normalizedUrl = directUrl
      ?.replaceFirst('square', 'medium')
      .replaceFirst('small', 'medium')
      .replaceFirst('http://', 'https://');

    return INaturalistObservation(
      id: (map['id'] as num?)?.toInt() ?? 0,
      title: taxon?['name'] as String? ?? 'Unknown',
      commonName: taxon?['preferred_common_name'] as String?,
      imageUrl: normalizedUrl,
    );
  }
}

class INaturalistApi {
  static const String _baseUrl = 'https://api.inaturalist.org/v1/observations';
  static const int _plantsTaxonId = 47126;

  Future<List<INaturalistObservation>> fetchNearbyPlants({
    required double latitude,
    required double longitude,
    int radiusKm = 30,
    int perPage = 10,
  }) async {
    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'taxon_id': _plantsTaxonId.toString(),
      'lat': latitude.toString(),
      'lng': longitude.toString(),
      'radius': radiusKm.toString(),
      'order_by': 'created_at',
      'order': 'desc',
      'photos': 'true',
      'quality_grade': 'research,needs_id,casual',
      'per_page': perPage.toString(),
    });

    final response = await http.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('iNaturalist API error: ${response.statusCode} ${response.body}');
    }

    final jsonBody = jsonDecode(response.body) as Map<String, dynamic>;
    final results = (jsonBody['results'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    return results.map(INaturalistObservation.fromMap).where((item) => item.id != 0).toList();
  }

  Future<List<INaturalistObservation>> searchPlants({
    required String query,
    int perPage = 20,
  }) async {
    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'taxon_id': _plantsTaxonId.toString(),
      'q': query,
      'order_by': 'observations',
      'order': 'desc',
      'photos': 'true',
      'quality_grade': 'research,needs_id,casual',
      'per_page': perPage.toString(),
    });

    final response = await http.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('iNaturalist API error: ${response.statusCode} ${response.body}');
    }

    final jsonBody = jsonDecode(response.body) as Map<String, dynamic>;
    final results = (jsonBody['results'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    return results.map(INaturalistObservation.fromMap).where((item) => item.id != 0).toList();
  }
}
