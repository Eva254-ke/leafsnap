import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class PerenualSpeciesSummary {
  final int id;
  final String commonName;
  final String scientificName;
  final String? thumbnailUrl;
  final String? imageUrl;
  final String? watering;
  final List<String> sunlight;

  PerenualSpeciesSummary({
    required this.id,
    required this.commonName,
    required this.scientificName,
    this.thumbnailUrl,
    this.imageUrl,
    this.watering,
    required this.sunlight,
  });

  factory PerenualSpeciesSummary.fromMap(Map<String, dynamic> map) {
    final defaultImage = map['default_image'] as Map<String, dynamic>?;
    final scientificNames = (map['scientific_name'] as List<dynamic>?)?.cast<String>() ?? <String>[];
    return PerenualSpeciesSummary(
      id: (map['id'] as num?)?.toInt() ?? 0,
      commonName: (map['common_name'] as String?)?.trim().isNotEmpty == true
          ? map['common_name'] as String
          : (scientificNames.isNotEmpty ? scientificNames.first : 'Unknown'),
      scientificName: scientificNames.isNotEmpty ? scientificNames.first : 'Unknown',
      thumbnailUrl: defaultImage?['thumbnail'] as String?,
      imageUrl: defaultImage?['regular_url'] as String?,
      watering: map['watering'] as String?,
      sunlight: (map['sunlight'] as List<dynamic>?)?.cast<String>() ?? <String>[],
    );
  }

  factory PerenualSpeciesSummary.fromCacheMap(Map<String, dynamic> map) {
    return PerenualSpeciesSummary(
      id: (map['id'] as num?)?.toInt() ?? 0,
      commonName: map['commonName'] as String? ?? 'Unknown',
      scientificName: map['scientificName'] as String? ?? 'Unknown',
      thumbnailUrl: map['thumbnailUrl'] as String?,
      imageUrl: map['imageUrl'] as String?,
      watering: map['watering'] as String?,
      sunlight: (map['sunlight'] as List<dynamic>? ?? <dynamic>[]).cast<String>(),
    );
  }

  Map<String, dynamic> toCacheMap() {
    return <String, dynamic>{
      'id': id,
      'commonName': commonName,
      'scientificName': scientificName,
      'thumbnailUrl': thumbnailUrl,
      'imageUrl': imageUrl,
      'watering': watering,
      'sunlight': sunlight,
    };
  }
}

class PerenualDiseaseSummary {
  final int id;
  final String commonName;
  final String scientificName;
  final List<String> otherNames;
  final String? thumbnailUrl;

  PerenualDiseaseSummary({
    required this.id,
    required this.commonName,
    required this.scientificName,
    required this.otherNames,
    this.thumbnailUrl,
  });

  factory PerenualDiseaseSummary.fromMap(Map<String, dynamic> map) {
    final rawScientificName = map['scientific_name'];
    final scientificName = switch (rawScientificName) {
      String value => value.trim(),
      List<dynamic> values when values.isNotEmpty => values.first.toString().trim(),
      _ => '',
    };
    final otherNames = (map['other_name'] as List<dynamic>? ?? <dynamic>[])
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
    final commonName = (map['common_name'] as String?)?.trim();
    final imageList = (map['images'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .toList();
    final firstImage = imageList.isNotEmpty ? imageList.first : null;

    return PerenualDiseaseSummary(
      id: (map['id'] as num?)?.toInt() ?? 0,
      commonName: commonName?.isNotEmpty == true
          ? commonName!
          : (otherNames.isNotEmpty ? otherNames.first : 'Unknown issue'),
      scientificName: scientificName.isNotEmpty ? scientificName : 'Unknown issue',
      otherNames: otherNames,
      thumbnailUrl:
          (firstImage?['regular_url'] as String?)?.trim().isNotEmpty == true
              ? (firstImage?['regular_url'] as String?)?.trim()
              : (firstImage?['thumbnail'] as String?)?.trim(),
    );
  }

  factory PerenualDiseaseSummary.fromCacheMap(Map<String, dynamic> map) {
    return PerenualDiseaseSummary(
      id: (map['id'] as num?)?.toInt() ?? 0,
      commonName: map['commonName'] as String? ?? 'Unknown issue',
      scientificName: map['scientificName'] as String? ?? 'Unknown issue',
      otherNames: (map['otherNames'] as List<dynamic>? ?? <dynamic>[])
          .map((item) => item.toString())
          .toList(),
      thumbnailUrl: map['thumbnailUrl'] as String?,
    );
  }

  Map<String, dynamic> toCacheMap() {
    return <String, dynamic>{
      'id': id,
      'commonName': commonName,
      'scientificName': scientificName,
      'otherNames': otherNames,
      'thumbnailUrl': thumbnailUrl,
    };
  }
}

class PerenualCareSection {
  final String type;
  final String description;

  PerenualCareSection({
    required this.type,
    required this.description,
  });
}

class PerenualApi {
  static const String _baseUrl = 'https://perenual.com/api/v2';
  static const String _careGuideUrl = 'https://perenual.com/api/species-care-guide-list';
  static const String _diseaseGuideUrl = 'https://perenual.com/api/pest-disease-list';
  static const Duration _speciesCacheTtl = Duration(hours: 12);
  static const Duration _diseaseCacheTtl = Duration(days: 7);

  Future<http.Response> _getWithRetry(Uri uri) async {
    const delays = <Duration>[Duration(milliseconds: 800), Duration(milliseconds: 1600)];
    http.Response? lastResponse;

    for (var attempt = 0; attempt <= delays.length; attempt++) {
      final response = await http.get(uri);
      if (response.statusCode != 429) {
        return response;
      }
      lastResponse = response;
      if (attempt < delays.length) {
        await Future.delayed(delays[attempt]);
      }
    }

    return lastResponse ?? await http.get(uri);
  }

  String _requireApiKey() {
    final apiKey = dotenv.env['PLANT_QUERY_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw StateError('PLANT_QUERY_API_KEY is missing from .env');
    }
    return apiKey;
  }

  String _speciesCacheKey({String? query, required int page}) {
    final normalizedQuery = (query ?? '').trim().toLowerCase().replaceAll(' ', '_');
    return 'perenual_species_${normalizedQuery}_$page';
  }

  String _diseaseCacheKey({String? query, required int page}) {
    final normalizedQuery = (query ?? '').trim().toLowerCase().replaceAll(' ', '_');
    return 'perenual_disease_${normalizedQuery}_$page';
  }

  List<PerenualSpeciesSummary> _decodeSpeciesList(String body) {
    final jsonBody = jsonDecode(body) as Map<String, dynamic>;
    final data = (jsonBody['data'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    return data.map(PerenualSpeciesSummary.fromMap).where((item) => item.id != 0).toList();
  }

  List<PerenualDiseaseSummary> _decodeDiseaseList(String body) {
    final jsonBody = jsonDecode(body) as Map<String, dynamic>;
    final data = (jsonBody['data'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    return data.map(PerenualDiseaseSummary.fromMap).where((item) => item.id != 0).toList();
  }

  List<PerenualSpeciesSummary>? _loadCachedSpecies({
    required SharedPreferences prefs,
    required String cacheKey,
    required bool allowStale,
  }) {
    final cachedBody = prefs.getString(cacheKey);
    final cachedAt = prefs.getInt('${cacheKey}_ts');
    if (cachedBody == null || cachedAt == null) {
      return null;
    }
    final age = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(cachedAt));
    if (!allowStale && age > _speciesCacheTtl) {
      return null;
    }
    return _decodeSpeciesList(cachedBody);
  }

  List<PerenualDiseaseSummary>? _loadCachedDiseases({
    required SharedPreferences prefs,
    required String cacheKey,
    required bool allowStale,
  }) {
    final cachedBody = prefs.getString(cacheKey);
    final cachedAt = prefs.getInt('${cacheKey}_ts');
    if (cachedBody == null || cachedAt == null) {
      return null;
    }
    final age = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(cachedAt));
    if (!allowStale && age > _diseaseCacheTtl) {
      return null;
    }
    return _decodeDiseaseList(cachedBody);
  }

  Future<List<PerenualSpeciesSummary>> searchSpecies({String? query, int page = 1}) async {
    final apiKey = _requireApiKey();
    final uri = Uri.parse('$_baseUrl/species-list').replace(queryParameters: {
      'key': apiKey,
      'page': page.toString(),
      if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
    });
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = _speciesCacheKey(query: query, page: page);

    final freshCached = _loadCachedSpecies(
      prefs: prefs,
      cacheKey: cacheKey,
      allowStale: false,
    );
    if (freshCached != null && freshCached.isNotEmpty) {
      return freshCached;
    }

    try {
      final response = await _getWithRetry(uri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('Perenual API error: ${response.statusCode} ${response.body}');
      }
      await prefs.setString(cacheKey, response.body);
      await prefs.setInt('${cacheKey}_ts', DateTime.now().millisecondsSinceEpoch);
      return _decodeSpeciesList(response.body);
    } catch (_) {
      final staleCached = _loadCachedSpecies(
        prefs: prefs,
        cacheKey: cacheKey,
        allowStale: true,
      );
      if (staleCached != null && staleCached.isNotEmpty) {
        return staleCached;
      }
      rethrow;
    }
  }

  Future<List<PerenualDiseaseSummary>> searchDiseases({String? query, int page = 1}) async {
    final apiKey = _requireApiKey();
    final uri = Uri.parse(_diseaseGuideUrl).replace(queryParameters: {
      'key': apiKey,
      'page': page.toString(),
      if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
    });
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = _diseaseCacheKey(query: query, page: page);

    final freshCached = _loadCachedDiseases(
      prefs: prefs,
      cacheKey: cacheKey,
      allowStale: false,
    );
    if (freshCached != null && freshCached.isNotEmpty) {
      return freshCached;
    }

    try {
      final response = await _getWithRetry(uri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('Perenual API error: ${response.statusCode} ${response.body}');
      }
      await prefs.setString(cacheKey, response.body);
      await prefs.setInt('${cacheKey}_ts', DateTime.now().millisecondsSinceEpoch);
      return _decodeDiseaseList(response.body);
    } catch (_) {
      final staleCached = _loadCachedDiseases(
        prefs: prefs,
        cacheKey: cacheKey,
        allowStale: true,
      );
      if (staleCached != null && staleCached.isNotEmpty) {
        return staleCached;
      }
      rethrow;
    }
  }


  Future<Map<String, dynamic>> getSpeciesDetails(int id) async {
    final apiKey = _requireApiKey();
    final uri = Uri.parse('$_baseUrl/species/details/$id').replace(queryParameters: {
      'key': apiKey,
    });

    final response = await http.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('Perenual API error: ${response.statusCode} ${response.body}');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<PerenualCareSection>> getCareGuides({int? speciesId, List<String>? types}) async {
    final apiKey = _requireApiKey();
    final typeParam = (types == null || types.isEmpty) ? 'sunlight,watering' : types.join(',');
    final uri = Uri.parse(_careGuideUrl).replace(queryParameters: {
      'key': apiKey,
      if (speciesId != null) 'species_id': speciesId.toString(),
      'type': typeParam,
    });

    final response = await http.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('Perenual API error: ${response.statusCode} ${response.body}');
    }

    final jsonBody = jsonDecode(response.body) as Map<String, dynamic>;
    final data = (jsonBody['data'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final sections = <PerenualCareSection>[];
    for (final item in data) {
      final sectionList = (item['section'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
      for (final section in sectionList) {
        final type = section['type'] as String?;
        final description = section['description'] as String?;
        if (type != null && description != null) {
          sections.add(PerenualCareSection(type: type, description: description));
        }
      }
    }
    return sections;
  }
}
