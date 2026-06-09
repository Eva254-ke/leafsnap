import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api_error.dart';

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
  static const List<Map<String, dynamic>> _fallbackSpecies = <Map<String, dynamic>>[
    {
      'id': -1001,
      'commonName': 'Tomato',
      'scientificName': 'Solanum lycopersicum',
      'imageUrl': 'https://images.unsplash.com/photo-1592924357228-91a4daadcfea?w=800&h=600&fit=crop',
      'thumbnailUrl': 'https://images.unsplash.com/photo-1592924357228-91a4daadcfea?w=240&h=180&fit=crop',
      'watering': 'Average',
      'sunlight': <String>['Full sun'],
      'careLevel': 'Moderate',
      'aliases': <String>['tomato', 'solanum lycopersicum'],
      'description': 'Tomatoes grow best in warm conditions with steady moisture, full sun, and support for fruiting stems.',
    },
    {
      'id': -1002,
      'commonName': 'Maize',
      'scientificName': 'Zea mays',
      'imageUrl':
          'https://www.grantthornton.in/globalassets/1.-member-firms/india/assets/pdf-images/554x544px/photograph/554x544px_website_photographs_641.jpg',
      'thumbnailUrl':
          'https://www.grantthornton.in/globalassets/1.-member-firms/india/assets/pdf-images/554x544px/photograph/554x544px_website_photographs_641.jpg',
      'watering': 'Average',
      'sunlight': <String>['Full sun'],
      'careLevel': 'Moderate',
      'aliases': <String>['maize', 'corn', 'zea mays'],
      'description': 'Maize needs full sun, fertile soil, and consistent watering during tasseling and grain fill.',
    },
    {
      'id': -1003,
      'commonName': 'Bean',
      'scientificName': 'Phaseolus vulgaris',
      'imageUrl': 'https://www.thespruce.com/thmb/cSsyLW4TIiQg0o4rk0wNdXzWrMM=/3564x2477/filters:no_upscale():max_bytes(150000):strip_icc()/GettyImages-1820512381-5bec11bf46e0fb0026b2d89c.jpg',
      'thumbnailUrl': 'https://www.thespruce.com/thmb/cSsyLW4TIiQg0o4rk0wNdXzWrMM=/3564x2477/filters:no_upscale():max_bytes(150000):strip_icc()/GettyImages-1820512381-5bec11bf46e0fb0026b2d89c.jpg',
      'watering': 'Average',
      'sunlight': <String>['Full sun', 'Part shade'],
      'careLevel': 'Easy',
      'aliases': <String>['bean', 'beans', 'phaseolus'],
      'description': 'Beans prefer warm soil, regular moisture, and good airflow to reduce fungal leaf problems.',
    },
    {
      'id': -1004,
      'commonName': 'Onion',
      'scientificName': 'Allium cepa',
      'imageUrl': 'https://growhappierplants.com/wp-content/uploads/2023/05/green-onion-plants.jpg',
      'thumbnailUrl': 'https://growhappierplants.com/wp-content/uploads/2023/05/green-onion-plants.jpg',
      'watering': 'Average',
      'sunlight': <String>['Full sun'],
      'careLevel': 'Easy',
      'aliases': <String>['onion', 'allium cepa'],
      'description': 'Onions need loose soil, full sun, and even moisture while bulbs are swelling.',
    },
    {
      'id': -1005,
      'commonName': 'Cabbage',
      'scientificName': 'Brassica oleracea',
      'imageUrl':
          'https://tse1.mm.bing.net/th/id/OIP.5ATExUzSl3XqRjWJn9KebQHaFq?w=570&h=436&rs=1&pid=ImgDetMain&o=7&rm=3',
      'thumbnailUrl':
          'https://tse1.mm.bing.net/th/id/OIP.5ATExUzSl3XqRjWJn9KebQHaFq?w=570&h=436&rs=1&pid=ImgDetMain&o=7&rm=3',
      'watering': 'Average',
      'sunlight': <String>['Full sun', 'Part shade'],
      'careLevel': 'Moderate',
      'aliases': <String>['cabbage', 'brassica oleracea', 'kale'],
      'description': 'Cabbage and related brassicas prefer cool weather, steady moisture, and pest monitoring.',
    },
    {
      'id': -1006,
      'commonName': 'Pepper',
      'scientificName': 'Capsicum annuum',
      'imageUrl': 'https://images.unsplash.com/photo-1583119022894-919a68a3d0e3?w=800&h=600&fit=crop',
      'thumbnailUrl': 'https://images.unsplash.com/photo-1583119022894-919a68a3d0e3?w=240&h=180&fit=crop',
      'watering': 'Average',
      'sunlight': <String>['Full sun'],
      'careLevel': 'Moderate',
      'aliases': <String>['pepper', 'capsicum', 'capsicum annuum'],
      'description': 'Peppers like warmth, bright sun, and consistent moisture without waterlogged roots.',
    },
    {
      'id': -1007,
      'commonName': 'Spinach',
      'scientificName': 'Spinacia oleracea',
      'imageUrl': 'https://images.unsplash.com/photo-1576045057995-568f588f82fb?w=800&h=600&fit=crop',
      'thumbnailUrl': 'https://images.unsplash.com/photo-1576045057995-568f588f82fb?w=240&h=180&fit=crop',
      'watering': 'Average',
      'sunlight': <String>['Part shade', 'Full sun'],
      'careLevel': 'Easy',
      'aliases': <String>['spinach', 'spinacia oleracea'],
      'description': 'Spinach grows quickly in cooler weather and benefits from light shade in hot periods.',
    },
    {
      'id': -1008,
      'commonName': 'Cucumber',
      'scientificName': 'Cucumis sativus',
      'imageUrl': 'https://images.unsplash.com/photo-1449300079323-02e209d9d3a6?w=800&h=600&fit=crop',
      'thumbnailUrl': 'https://images.unsplash.com/photo-1449300079323-02e209d9d3a6?w=240&h=180&fit=crop',
      'watering': 'Frequent',
      'sunlight': <String>['Full sun'],
      'careLevel': 'Moderate',
      'aliases': <String>['cucumber', 'cucumis sativus'],
      'description': 'Cucumbers need warm conditions, frequent watering, and airflow around vines.',
    },
    {
      'id': -1009,
      'commonName': 'Carrot',
      'scientificName': 'Daucus carota',
      'imageUrl': 'https://images.unsplash.com/photo-1447175008436-054170c2e979?w=800&h=600&fit=crop',
      'thumbnailUrl': 'https://images.unsplash.com/photo-1447175008436-054170c2e979?w=240&h=180&fit=crop',
      'watering': 'Average',
      'sunlight': <String>['Full sun', 'Part shade'],
      'careLevel': 'Easy',
      'aliases': <String>['carrot', 'daucus carota'],
      'description': 'Carrots need loose soil, steady moisture, and thinning for straight roots.',
    },
    {
      'id': -1010,
      'commonName': 'Lettuce',
      'scientificName': 'Lactuca sativa',
      'imageUrl': 'https://images.unsplash.com/photo-1622205313162-be1d5712a43d?w=800&h=600&fit=crop',
      'thumbnailUrl': 'https://images.unsplash.com/photo-1622205313162-be1d5712a43d?w=240&h=180&fit=crop',
      'watering': 'Average',
      'sunlight': <String>['Part shade', 'Full sun'],
      'careLevel': 'Easy',
      'aliases': <String>['lettuce', 'lactuca sativa'],
      'description': 'Lettuce prefers cool conditions, gentle sun, and regular watering for tender leaves.',
    },
    {
      'id': -1011,
      'commonName': 'Banana',
      'scientificName': 'Musa acuminata',
      'imageUrl': 'https://images.unsplash.com/photo-1571771096344-2a5e0c3c2f8e?w=800&h=600&fit=crop',
      'thumbnailUrl': 'https://images.unsplash.com/photo-1571771096344-2a5e0c3c2f8e?w=240&h=180&fit=crop',
      'watering': 'Frequent',
      'sunlight': <String>['Full sun'],
      'careLevel': 'Moderate',
      'aliases': <String>['banana', 'plantain', 'musa'],
      'description': 'Bananas and plantains need warmth, rich soil, regular feeding, and generous water.',
    },
    {
      'id': -1012,
      'commonName': 'Rice',
      'scientificName': 'Oryza sativa',
      'imageUrl': 'https://images.unsplash.com/photo-1536304993881-ff6e9eefa2a6?w=800&h=600&fit=crop',
      'thumbnailUrl': 'https://images.unsplash.com/photo-1536304993881-ff6e9eefa2a6?w=240&h=180&fit=crop',
      'watering': 'Frequent',
      'sunlight': <String>['Full sun'],
      'careLevel': 'Moderate',
      'aliases': <String>['rice', 'oryza sativa'],
      'description': 'Rice grows best with high moisture, warm temperatures, and full sun.',
    },
    {
      'id': -1013,
      'commonName': 'Okra',
      'scientificName': 'Abelmoschus esculentus',
      'imageUrl': 'https://images.unsplash.com/photo-1425543103986-22abb7d7e8d2?w=800&h=600&fit=crop',
      'thumbnailUrl': 'https://images.unsplash.com/photo-1425543103986-22abb7d7e8d2?w=240&h=180&fit=crop',
      'watering': 'Average',
      'sunlight': <String>['Full sun'],
      'careLevel': 'Easy',
      'aliases': <String>['okra', 'abelmoschus esculentus'],
      'description': 'Okra thrives in heat with full sun and consistent moisture during pod formation.',
    },
    {
      'id': -1014,
      'commonName': 'Cassava',
      'scientificName': 'Manihot esculenta',
      'imageUrl': 'https://images.unsplash.com/photo-1587049352846-4a222e784d38?w=800&h=600&fit=crop',
      'thumbnailUrl': 'https://images.unsplash.com/photo-1587049352846-4a222e784d38?w=240&h=180&fit=crop',
      'watering': 'Minimum',
      'sunlight': <String>['Full sun'],
      'careLevel': 'Easy',
      'aliases': <String>['cassava', 'manihot esculenta'],
      'description': 'Cassava tolerates dry spells once established but performs best in warm, sunny sites.',
    },
    {
      'id': -1015,
      'commonName': 'Potato',
      'scientificName': 'Solanum tuberosum',
      'imageUrl': 'https://images.unsplash.com/photo-1518977676601-b53f82aba655?w=800&h=600&fit=crop',
      'thumbnailUrl': 'https://images.unsplash.com/photo-1518977676601-b53f82aba655?w=240&h=180&fit=crop',
      'watering': 'Average',
      'sunlight': <String>['Full sun'],
      'careLevel': 'Moderate',
      'aliases': <String>['potato', 'solanum tuberosum'],
      'description': 'Potatoes need loose soil, full sun, and steady moisture while tubers size up.',
    },
    {
      'id': -1016,
      'commonName': 'Monstera',
      'scientificName': 'Monstera deliciosa',
      'imageUrl': 'https://images.unsplash.com/photo-1614594975525-e45190c55d0b?w=800&h=600&fit=crop',
      'thumbnailUrl': 'https://images.unsplash.com/photo-1614594975525-e45190c55d0b?w=240&h=180&fit=crop',
      'watering': 'Average',
      'sunlight': <String>['Part shade', 'Indirect light'],
      'careLevel': 'Easy',
      'aliases': <String>['monstera', 'monstera deliciosa', 'swiss cheese'],
      'description': 'Monstera prefers bright indirect light, chunky soil, and drying slightly between waterings.',
    },
    {
      'id': -1017,
      'commonName': 'Rose',
      'scientificName': 'Rosa',
      'imageUrl': 'https://images.unsplash.com/photo-1496062031456-07b8f162a322?w=800&h=600&fit=crop',
      'thumbnailUrl': 'https://images.unsplash.com/photo-1496062031456-07b8f162a322?w=240&h=180&fit=crop',
      'watering': 'Average',
      'sunlight': <String>['Full sun'],
      'careLevel': 'Moderate',
      'aliases': <String>['rose', 'rosa'],
      'description': 'Roses need strong light, deep watering, and regular inspection for mildew and black spot.',
    },
  ];

  static const List<Map<String, dynamic>> _fallbackDiseases = <Map<String, dynamic>>[
    {
      'id': -2001,
      'commonName': 'Powdery mildew',
      'scientificName': 'Powdery mildew',
      'otherNames': <String>['mildew', 'fungal disease'],
      'thumbnailUrl': 'https://images.unsplash.com/photo-1598512752271-33f913a5af13?w=800&h=600&fit=crop',
      'aliases': <String>['powdery mildew', 'mildew', 'powdery'],
    },
    {
      'id': -2002,
      'commonName': 'Leaf spot',
      'scientificName': 'Leaf spot disease',
      'otherNames': <String>['spot', 'leaf damage', 'fungal spot'],
      'thumbnailUrl': 'https://images.unsplash.com/photo-1501004318641-b39e6451bec6?w=800&h=600&fit=crop',
      'aliases': <String>['leaf spot', 'spot', 'lesion'],
    },
    {
      'id': -2003,
      'commonName': 'Aphids',
      'scientificName': 'Aphidoidea',
      'otherNames': <String>['aphid', 'plant lice', 'sap sucking insects'],
      'thumbnailUrl': 'https://images.unsplash.com/photo-1464226184884-fa280b87c399?w=800&h=600&fit=crop',
      'aliases': <String>['aphids', 'aphid', 'insect', 'pest'],
    },
    {
      'id': -2004,
      'commonName': 'Blight',
      'scientificName': 'Plant blight',
      'otherNames': <String>['early blight', 'late blight', 'fungal blight'],
      'thumbnailUrl': 'https://images.unsplash.com/photo-1416879595882-3373a0480b5b?w=800&h=600&fit=crop',
      'aliases': <String>['blight', 'early blight', 'late blight', 'fungi'],
    },
  ];

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

  String _normalizeSearchText(String value) {
    return value.trim().toLowerCase();
  }

  bool _matchesFallbackQuery(Map<String, dynamic> item, String query) {
    final normalizedQuery = _normalizeSearchText(query);
    if (normalizedQuery.isEmpty) {
      return true;
    }
    final fields = <String>[
      item['commonName'] as String? ?? '',
      item['scientificName'] as String? ?? '',
      ...(item['aliases'] as List<String>? ?? const <String>[]),
      ...(item['otherNames'] as List<String>? ?? const <String>[]),
    ].map(_normalizeSearchText);

    return fields.any(
      (field) =>
          field.contains(normalizedQuery) ||
          normalizedQuery.contains(field),
    );
  }

  List<PerenualSpeciesSummary> _fallbackSpeciesForQuery(String? query) {
    if (query != null && query.trim().isNotEmpty) {
      return _fallbackSpecies
          .where((item) => _matchesFallbackQuery(item, query))
          .map(_speciesFromFallback)
          .toList();
    }
    return _fallbackSpecies.take(12).map(_speciesFromFallback).toList();
  }

  List<PerenualDiseaseSummary> _fallbackDiseasesForQuery(String? query) {
    if (query != null && query.trim().isNotEmpty) {
      return _fallbackDiseases
          .where((item) => _matchesFallbackQuery(item, query))
          .map(_diseaseFromFallback)
          .toList();
    }
    return _fallbackDiseases.map(_diseaseFromFallback).toList();
  }

  PerenualSpeciesSummary _speciesFromFallback(Map<String, dynamic> item) {
    return PerenualSpeciesSummary(
      id: item['id'] as int,
      commonName: item['commonName'] as String,
      scientificName: item['scientificName'] as String,
      thumbnailUrl: item['thumbnailUrl'] as String?,
      imageUrl: item['imageUrl'] as String?,
      watering: item['watering'] as String?,
      sunlight: item['sunlight'] as List<String>? ?? const <String>[],
    );
  }

  PerenualDiseaseSummary _diseaseFromFallback(Map<String, dynamic> item) {
    return PerenualDiseaseSummary(
      id: item['id'] as int,
      commonName: item['commonName'] as String,
      scientificName: item['scientificName'] as String,
      otherNames: item['otherNames'] as List<String>? ?? const <String>[],
      thumbnailUrl: item['thumbnailUrl'] as String?,
    );
  }

  Map<String, dynamic>? _fallbackSpeciesById(int id) {
    for (final item in _fallbackSpecies) {
      if (item['id'] == id) {
        return item;
      }
    }
    return null;
  }

  List<PerenualCareSection> _fallbackCareSectionsFor(
    Map<String, dynamic> item, {
    List<String>? types,
  }) {
    final requestedTypes = (types == null || types.isEmpty)
        ? const <String>['sunlight', 'watering']
        : types;
    final descriptions = <String, String>{
      'sunlight':
          '${item['commonName']} usually prefers ${(item['sunlight'] as List<String>? ?? const <String>['bright light']).join(', ').toLowerCase()}. Adjust exposure if leaves scorch, pale, or stretch.',
      'watering':
          'Keep ${item['commonName']} on a ${_normalizeSearchText(item['watering'] as String? ?? 'average')} watering rhythm. Check the top soil before watering and avoid leaving roots waterlogged.',
      'fertilizing':
          'Feed ${item['commonName']} lightly during active growth. Reduce feeding when growth slows or the plant is stressed.',
    };

    return requestedTypes
        .where(descriptions.containsKey)
        .map(
          (type) => PerenualCareSection(
            type: type,
            description: descriptions[type]!,
          ),
        )
        .toList();
  }

  Future<List<PerenualSpeciesSummary>> searchSpecies({String? query, int page = 1}) async {
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
      final apiKey = _requireApiKey();
      final uri = Uri.parse('$_baseUrl/species-list').replace(queryParameters: {
        'key': apiKey,
        'page': page.toString(),
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      });
      final response = await _getWithRetry(uri);
      if (response.statusCode == 429) {
        throw ApiRateLimitException('Request limit reached.');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Reference service error: ${response.statusCode} ${response.body}',
        );
      }
      final decoded = _decodeSpeciesList(response.body);
      if (decoded.isEmpty) {
        final fallback = _fallbackSpeciesForQuery(query);
        if (fallback.isNotEmpty) {
          return fallback;
        }
      }
      await prefs.setString(cacheKey, response.body);
      await prefs.setInt('${cacheKey}_ts', DateTime.now().millisecondsSinceEpoch);
      return decoded;
    } catch (_) {
      final staleCached = _loadCachedSpecies(
        prefs: prefs,
        cacheKey: cacheKey,
        allowStale: true,
      );
      if (staleCached != null && staleCached.isNotEmpty) {
        return staleCached;
      }
      final fallback = _fallbackSpeciesForQuery(query);
      if (fallback.isNotEmpty) {
        return fallback;
      }
      rethrow;
    }
  }

  Future<List<PerenualDiseaseSummary>> searchDiseases({String? query, int page = 1}) async {
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
      final apiKey = _requireApiKey();
      final uri = Uri.parse(_diseaseGuideUrl).replace(queryParameters: {
        'key': apiKey,
        'page': page.toString(),
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      });
      final response = await _getWithRetry(uri);
      if (response.statusCode == 429) {
        throw ApiRateLimitException('Request limit reached.');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Reference service error: ${response.statusCode} ${response.body}',
        );
      }
      final decoded = _decodeDiseaseList(response.body);
      if (decoded.isEmpty) {
        final fallback = _fallbackDiseasesForQuery(query);
        if (fallback.isNotEmpty) {
          return fallback;
        }
      }
      await prefs.setString(cacheKey, response.body);
      await prefs.setInt('${cacheKey}_ts', DateTime.now().millisecondsSinceEpoch);
      return decoded;
    } catch (_) {
      final staleCached = _loadCachedDiseases(
        prefs: prefs,
        cacheKey: cacheKey,
        allowStale: true,
      );
      if (staleCached != null && staleCached.isNotEmpty) {
        return staleCached;
      }
      final fallback = _fallbackDiseasesForQuery(query);
      if (fallback.isNotEmpty) {
        return fallback;
      }
      rethrow;
    }
  }


  Future<Map<String, dynamic>> getSpeciesDetails(int id) async {
    final fallback = _fallbackSpeciesById(id);
    if (fallback != null) {
      return <String, dynamic>{
        'id': fallback['id'],
        'common_name': fallback['commonName'],
        'scientific_name': <String>[fallback['scientificName'] as String],
        'watering': fallback['watering'],
        'sunlight': fallback['sunlight'],
        'care_level': fallback['careLevel'],
        'description': fallback['description'],
        'hardiness': <String, dynamic>{'min': '10 C', 'max': '32 C'},
        'default_image': <String, dynamic>{
          'thumbnail': fallback['thumbnailUrl'],
          'regular_url': fallback['imageUrl'],
        },
      };
    }

    try {
      final apiKey = _requireApiKey();
      final uri = Uri.parse('$_baseUrl/species/details/$id').replace(queryParameters: {
        'key': apiKey,
      });

      final response = await http.get(uri);
      if (response.statusCode == 429) {
        throw ApiRateLimitException('Request limit reached.');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Reference service error: ${response.statusCode} ${response.body}',
        );
      }

      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      rethrow;
    }
  }

  Future<List<PerenualCareSection>> getCareGuides({int? speciesId, List<String>? types}) async {
    final fallback = speciesId == null ? null : _fallbackSpeciesById(speciesId);
    if (fallback != null) {
      return _fallbackCareSectionsFor(fallback, types: types);
    }

    final apiKey = _requireApiKey();
    final typeParam = (types == null || types.isEmpty) ? 'sunlight,watering' : types.join(',');
    final uri = Uri.parse(_careGuideUrl).replace(queryParameters: {
      'key': apiKey,
      if (speciesId != null) 'species_id': speciesId.toString(),
      'type': typeParam,
    });

    final response = await http.get(uri);
    if (response.statusCode == 429) {
      throw ApiRateLimitException('Request limit reached.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Reference service error: ${response.statusCode} ${response.body}',
      );
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
