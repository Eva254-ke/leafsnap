import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class PlantNetImageReference {
  const PlantNetImageReference({
    this.originalUrl,
    this.mediumUrl,
    this.smallUrl,
    this.citation,
  });

  final String? originalUrl;
  final String? mediumUrl;
  final String? smallUrl;
  final String? citation;

  factory PlantNetImageReference.fromMap(Map<String, dynamic> map) {
    final urlMap = map['url'] as Map<String, dynamic>? ?? <String, dynamic>{};
    return PlantNetImageReference(
      originalUrl: (urlMap['o'] as String?)?.trim(),
      mediumUrl: (urlMap['m'] as String?)?.trim(),
      smallUrl: (urlMap['s'] as String?)?.trim(),
      citation: (map['citation'] as String?)?.trim(),
    );
  }

  String? get bestUrl {
    for (final candidate in <String?>[mediumUrl, smallUrl, originalUrl]) {
      final normalized = candidate?.trim();
      if (normalized != null && normalized.isNotEmpty) {
        return normalized;
      }
    }
    return null;
  }
}

class PlantNetPlantMatch {
  const PlantNetPlantMatch({
    required this.scientificName,
    required this.score,
    this.commonNames = const <String>[],
    this.images = const <PlantNetImageReference>[],
  });

  final String scientificName;
  final double score;
  final List<String> commonNames;
  final List<PlantNetImageReference> images;

  factory PlantNetPlantMatch.fromMap(Map<String, dynamic> map) {
    final species = map['species'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final commonNames = (species['commonNames'] as List<dynamic>? ?? const <dynamic>[])
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
    final images = (map['images'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(PlantNetImageReference.fromMap)
        .toList();

    return PlantNetPlantMatch(
      scientificName:
          (species['scientificNameWithoutAuthor'] as String?)?.trim().isNotEmpty == true
              ? (species['scientificNameWithoutAuthor'] as String).trim()
              : ((species['scientificName'] as String?)?.trim() ?? 'Unknown'),
      score: (map['score'] as num?)?.toDouble() ?? 0,
      commonNames: commonNames,
      images: images,
    );
  }

  String get displayName =>
      commonNames.isNotEmpty ? commonNames.first : scientificName;

  String? get imageUrl {
    for (final image in images) {
      final candidate = image.bestUrl;
      if (candidate != null && candidate.isNotEmpty) {
        return candidate;
      }
    }
    return null;
  }
}

class PlantNetDiseaseMatch {
  const PlantNetDiseaseMatch({
    required this.code,
    required this.description,
    required this.score,
    this.images = const <PlantNetImageReference>[],
  });

  final String code;
  final String description;
  final double score;
  final List<PlantNetImageReference> images;

  factory PlantNetDiseaseMatch.fromMap(Map<String, dynamic> map) {
    final images = (map['images'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(PlantNetImageReference.fromMap)
        .toList();

    return PlantNetDiseaseMatch(
      code: (map['name'] as String?)?.trim() ?? 'Unknown',
      description:
          (map['description'] as String?)?.trim().isNotEmpty == true
              ? (map['description'] as String).trim()
              : ((map['name'] as String?)?.trim() ?? 'Unknown issue'),
      score: (map['score'] as num?)?.toDouble() ?? 0,
      images: images,
    );
  }

  String? get imageUrl {
    for (final image in images) {
      final candidate = image.bestUrl;
      if (candidate != null && candidate.isNotEmpty) {
        return candidate;
      }
    }
    return null;
  }
}

class PlantNetApi {
  static const String _identifyBaseUrl = 'https://my-api.plantnet.org/v2/identify';
  static const String _diseasesBaseUrl =
      'https://my-api.plantnet.org/v2/diseases/identify';

  Future<Map<String, dynamic>> identify({
    required List<File> images,
    required List<String> organs,
    String project = 'all',
    String? language,
  }) async {
    return _submitMultipartRequest(
      uri: Uri.parse('$_identifyBaseUrl/$project').replace(
        queryParameters: <String, String>{
          'api-key': _requireApiKey(),
          'include-related-images': 'true',
          if (language != null) 'lang': language,
        },
      ),
      images: images,
      organs: organs,
    );
  }

  Future<Map<String, dynamic>> identifyDiseases({
    required List<File> images,
    required List<String> organs,
    String? language,
  }) async {
    return _submitMultipartRequest(
      uri: Uri.parse(_diseasesBaseUrl).replace(
        queryParameters: <String, String>{
          'api-key': _requireApiKey(),
          'include-related-images': 'true',
          if (language != null) 'lang': language,
        },
      ),
      images: images,
      organs: organs,
    );
  }

  List<PlantNetPlantMatch> parsePlantMatches(Map<String, dynamic> response) {
    return (response['results'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(PlantNetPlantMatch.fromMap)
        .toList();
  }

  List<PlantNetDiseaseMatch> parseDiseaseMatches(Map<String, dynamic> response) {
    return (response['results'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(PlantNetDiseaseMatch.fromMap)
        .toList();
  }

  String _requireApiKey() {
    final apiKey = dotenv.env['PLANTNET_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw StateError('PLANTNET_API_KEY is missing from .env');
    }
    return apiKey;
  }

  Future<Map<String, dynamic>> _submitMultipartRequest({
    required Uri uri,
    required List<File> images,
    required List<String> organs,
  }) async {
    if (images.isEmpty || images.length > 5) {
      throw ArgumentError('images must be between 1 and 5 items');
    }
    if (images.length != organs.length) {
      throw ArgumentError('images and organs must have the same length');
    }

    final request = http.MultipartRequest('POST', uri);

    for (var i = 0; i < images.length; i++) {
      request.files.add(http.MultipartFile.fromString('organs', organs[i]));
      request.files.add(await http.MultipartFile.fromPath('images', images[i].path));
    }

    final response = await http.Response.fromStream(await request.send());
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('PlantNet API error: ${response.statusCode} ${response.body}');
    }

    final jsonBody = jsonDecode(response.body);
    if (jsonBody is Map<String, dynamic>) {
      return jsonBody;
    }

    throw const FormatException('Unexpected PlantNet response');
  }
}
