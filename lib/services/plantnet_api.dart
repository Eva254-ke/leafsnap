import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'api_error.dart';
import 'remote_config_service.dart';

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

/// Production-grade PlantNet API client with retry logic, proper timeouts,
/// and comprehensive error handling.
class PlantNetApi {
  PlantNetApi({http.Client? client}) : _client = client ?? http.Client();

  static const String _identifyBaseUrl = 'https://my-api.plantnet.org/v2/identify';
  static const String _defaultBackendBaseUrl =
      'https://leafsnap-api.cloubridge.com';

  // Configurable timeouts
  static const Duration _plantIdentificationTimeout = Duration(seconds: 25);
  static const Duration _diseaseDetectionTimeout = Duration(seconds: 35);
  static const Duration _responseReadTimeout = Duration(seconds: 15);
  static const Duration _backendRequestTimeout = Duration(seconds: 30);

  // Retry configuration
  static const int _maxRetries = 2;
  static const Duration _initialRetryDelay = Duration(seconds: 2);

  final http.Client _client;
  int _consecutiveFailures = 0;
  DateTime? _lastFailureTime;

  Future<Map<String, dynamic>> identify({
    required List<File> images,
    required List<String> organs,
    String project = 'all',
    String? language,
    bool includeRelatedImages = false,
  }) async {
    _validateImagesAndOrgans(images, organs);

    final backendBaseUrl = _backendBaseUrl();
    if (backendBaseUrl != null) {
      return _withRetry(
        () => _submitBackendIdentifyRequest(
          baseUrl: backendBaseUrl,
          images: images,
          organs: organs,
          project: project,
          language: language,
          includeRelatedImages: includeRelatedImages,
        ),
        operationName: 'backend_identify',
      );
    }

    return _withRetry(
      () => _submitMultipartRequest(
        uri: Uri.parse('$_identifyBaseUrl/$project').replace(
          queryParameters: <String, String>{
            'api-key': _requireApiKey(),
            'include-related-images': includeRelatedImages.toString(),
            'no-reject': 'true',
            'nb-results': '3',
            if (language != null) 'lang': language,
          },
        ),
        images: images,
        organs: organs,
        timeout: _plantIdentificationTimeout,
        operationName: 'plant_identification',
      ),
      operationName: 'plant_identification',
    );
  }

  /// Disease detection uses the SAME identify endpoint with 'leaf' organ
  /// PlantNet doesn't have a separate /diseases/identify endpoint
  Future<Map<String, dynamic>> identifyDiseases({
    required List<File> images,
    required List<String> organs,
    String? language,
    bool includeRelatedImages = false,
  }) async {
    _validateImagesAndOrgans(images, organs);

    debugPrint('🔬 PlantNet: Starting disease detection via identify endpoint');
    debugPrint('🔬 PlantNet: Using organs: $organs');

    return _withRetry(
      () => _submitMultipartRequest(
        uri: Uri.parse('$_identifyBaseUrl/all').replace(
          queryParameters: <String, String>{
            'api-key': _requireApiKey(),
            'include-related-images': includeRelatedImages.toString(),
            'no-reject': 'true',
            'nb-results': '5',
            if (language != null) 'lang': language,
          },
        ),
        images: images,
        organs: organs,
        timeout: _diseaseDetectionTimeout,
        operationName: 'disease_detection',
      ),
      operationName: 'disease_detection',
    );
  }

  List<PlantNetPlantMatch> parsePlantMatches(Map<String, dynamic> response) {
    final results = response['results'];
    if (results == null || results is! List) {
      debugPrint('⚠️ PlantNet: No results found in response');
      return <PlantNetPlantMatch>[];
    }

    return results
        .whereType<Map<String, dynamic>>()
        .map(PlantNetPlantMatch.fromMap)
        .toList();
  }

  /// Parse disease matches from identify response
  /// Looks for results that contain disease-related keywords
  List<PlantNetDiseaseMatch> parseDiseaseMatches(Map<String, dynamic> response) {
    final results = response['results'];
    if (results == null || results is! List) {
      debugPrint('⚠️ PlantNet: No disease results found in response');
      return <PlantNetDiseaseMatch>[];
    }

    final diseaseKeywords = [
      'blight', 'rust', 'mildew', 'spot', 'rot', 'wilt', 'canker',
      'mosaic', 'scab', 'mold', 'decay', 'lesion', 'yellow', 'brown',
      'black', 'white', 'powdery', 'downy', 'bacterial', 'viral', 'fungal',
      'disease', 'infected', 'damaged', 'necrosis', 'chlorosis'
    ];

    final diseases = <PlantNetDiseaseMatch>[];

    for (final result in results.whereType<Map<String, dynamic>>()) {
      final species = result['species'] as Map<String, dynamic>? ?? {};
      final scientificName = (species['scientificNameWithoutAuthor'] as String?)?.toLowerCase() ?? '';
      final commonNames = (species['commonNames'] as List<dynamic>? ?? [])
          .map((e) => e.toString().toLowerCase())
          .toList();

      // Check if this result indicates a disease
      bool isDisease = false;
      String diseaseDescription = '';

      for (final keyword in diseaseKeywords) {
        if (scientificName.contains(keyword)) {
          isDisease = true;
          diseaseDescription = scientificName;
          break;
        }
        for (final commonName in commonNames) {
          if (commonName.contains(keyword)) {
            isDisease = true;
            diseaseDescription = commonName;
            break;
          }
        }
        if (isDisease) break;
      }

      if (isDisease) {
        final images = (result['images'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(PlantNetImageReference.fromMap)
            .toList();

        diseases.add(PlantNetDiseaseMatch(
          code: scientificName.isNotEmpty ? scientificName : 'disease',
          description: diseaseDescription.isNotEmpty 
              ? diseaseDescription 
              : (scientificName.isNotEmpty ? scientificName : 'Unknown disease'),
          score: (result['score'] as num?)?.toDouble() ?? 0,
          images: images,
        ));
      }
    }

    debugPrint('🔬 PlantNet: Found ${diseases.length} disease matches');
    return diseases;
  }

  /// Dispose the HTTP client to free resources
  void dispose() {
    _client.close();
  }

  // ============================================================================
  // PRIVATE METHODS
  // ============================================================================

  void _validateImagesAndOrgans(List<File> images, List<String> organs) {
    if (images.isEmpty || images.length > 5) {
      throw ArgumentError('images must be between 1 and 5 items');
    }
    if (images.length != organs.length) {
      throw ArgumentError('images and organs must have the same length');
    }

    for (var i = 0; i < images.length; i++) {
      final file = images[i];
      if (!file.existsSync()) {
        throw ArgumentError('Image file does not exist: ${file.path}');
      }
      if (file.lengthSync() == 0) {
        throw ArgumentError('Image file is empty: ${file.path}');
      }
    }
  }

  String _requireApiKey() {
    final apiKey = dotenv.env['PLANTNET_API_KEY'];
    if (apiKey == null || apiKey.trim().isEmpty) {
      throw StateError(
        'PLANTNET_API_KEY is missing from .env file. '
        'Please add your PlantNet API key to the .env file.',
      );
    }
    return apiKey.trim();
  }

  String? _backendBaseUrl() {
    try {
      final raw = RemoteConfigService.instance
          .getString(RemoteConfigKeys.backendBaseUrl)
          .trim();
      if (raw.isEmpty) {
        return _defaultBackendBaseUrl;
      }
      final normalized = raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
      final host = Uri.tryParse(normalized)?.host.toLowerCase();
      if (host != 'leafsnap-api.cloubridge.com') {
        return _defaultBackendBaseUrl;
      }
      return normalized;
    } catch (e) {
      debugPrint('⚠️ PlantNet: Failed to get backend URL from remote config: $e');
      return _defaultBackendBaseUrl;
    }
  }

  /// Retry wrapper with exponential backoff
  Future<Map<String, dynamic>> _withRetry(
    Future<Map<String, dynamic>> Function() operation, {
    required String operationName,
  }) async {
    if (_consecutiveFailures >= 5) {
      final timeSinceLastFailure = DateTime.now().difference(_lastFailureTime ?? DateTime.now());
      if (timeSinceLastFailure < const Duration(minutes: 2)) {
        debugPrint('🚫 PlantNet: Circuit breaker open - too many recent failures');
        throw const ApiUnavailableException(
          'Service temporarily unavailable. Please try again in a few minutes.',
        );
      } else {
        _consecutiveFailures = 0;
        debugPrint('✅ PlantNet: Circuit breaker reset after cooldown');
      }
    }

    for (var attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        if (attempt > 0) {
          debugPrint('🔄 PlantNet [$operationName]: Retry attempt $attempt of $_maxRetries');
          await Future.delayed(_initialRetryDelay * attempt);
        }

        final result = await operation();
        
        if (_consecutiveFailures > 0) {
          debugPrint('✅ PlantNet [$operationName]: Success after $_consecutiveFailures failures');
          _consecutiveFailures = 0;
        }
        
        return result;
      } on ApiRateLimitException {
        debugPrint('🚫 PlantNet [$operationName]: Rate limited - not retrying');
        rethrow;
      } on SocketException catch (e) {
        debugPrint('⚠️ PlantNet [$operationName]: Network error (attempt ${attempt + 1}): $e');
        _recordFailure();
        if (attempt == _maxRetries) {
          throw const ApiUnavailableException(
            'Network connection failed. Please check your internet connection.',
          );
        }
      } on TimeoutException catch (e) {
        debugPrint('⚠️ PlantNet [$operationName]: Timeout (attempt ${attempt + 1}): $e');
        _recordFailure();
        if (attempt == _maxRetries) {
          throw const HttpException(
            'Request timed out. The service is taking too long to respond.',
          );
        }
      } on HttpException catch (e) {
        final message = e.message.toLowerCase();
        if (message.contains('500') || message.contains('502') || 
            message.contains('503') || message.contains('504')) {
          debugPrint('⚠️ PlantNet [$operationName]: Server error (attempt ${attempt + 1}): $e');
          _recordFailure();
          if (attempt == _maxRetries) {
            throw const ApiUnavailableException(
              'Service temporarily unavailable. Please try again later.',
            );
          }
        } else {
          debugPrint('❌ PlantNet [$operationName]: Client error - not retrying: $e');
          rethrow;
        }
      } catch (e) {
        debugPrint('❌ PlantNet [$operationName]: Unknown error: $e');
        _recordFailure();
        rethrow;
      }
    }

    throw const ApiUnavailableException('Service unavailable after multiple attempts.');
  }

  void _recordFailure() {
    _consecutiveFailures++;
    _lastFailureTime = DateTime.now();
    debugPrint('📊 PlantNet: Failure count: $_consecutiveFailures');
  }

  Future<Map<String, dynamic>> _submitBackendIdentifyRequest({
    required String baseUrl,
    required List<File> images,
    required List<String> organs,
    required String project,
    required String? language,
    required bool includeRelatedImages,
  }) async {
    debugPrint('🌿 PlantNet: Submitting backend identify request to $baseUrl');

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/v1/identify/plant'),
    );
    request.fields['project'] = project;
    request.fields['includeRelatedImages'] = includeRelatedImages.toString();
    if (language != null) {
      request.fields['language'] = language;
    }

    for (var i = 0; i < images.length; i++) {
      request.files.add(http.MultipartFile.fromString('organs', organs[i]));
      request.files.add(await http.MultipartFile.fromPath('images', images[i].path));
    }

    final streamedResponse = await request.send().timeout(_backendRequestTimeout);
    final response = await http.Response.fromStream(streamedResponse).timeout(
      _responseReadTimeout,
    );

    debugPrint('🌿 PlantNet Backend: Status ${response.statusCode}');

    if (response.statusCode == 429) {
      throw ApiRateLimitException('Request limit reached. Please wait before trying again.');
    }
    if (response.statusCode == 503) {
      throw const ApiUnavailableException('Identification service unavailable.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Identification gateway error: ${response.statusCode} - ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}',
      );
    }

    final jsonBody = jsonDecode(response.body);
    if (jsonBody is Map<String, dynamic>) {
      debugPrint('✅ PlantNet Backend: Successfully parsed response');
      return jsonBody;
    }

    throw const FormatException('Unexpected identification response format');
  }

  Future<Map<String, dynamic>> _submitMultipartRequest({
    required Uri uri,
    required List<File> images,
    required List<String> organs,
    required Duration timeout,
    required String operationName,
  }) async {
    debugPrint('🌿 PlantNet [$operationName]: Submitting request with timeout ${timeout.inSeconds}s');
    debugPrint('🌿 PlantNet [$operationName]: URI: $uri');

    final request = http.MultipartRequest('POST', uri);

    for (var i = 0; i < images.length; i++) {
      request.files.add(http.MultipartFile.fromString('organs', organs[i]));
      request.files.add(await http.MultipartFile.fromPath('images', images[i].path));
      debugPrint('🌿 PlantNet [$operationName]: Added image ${i + 1} with organ: ${organs[i]}');
    }

    final streamedResponse = await request.send().timeout(timeout);
    final response = await http.Response.fromStream(streamedResponse).timeout(
      _responseReadTimeout,
    );

    debugPrint('🌿 PlantNet [$operationName]: Status ${response.statusCode}');
    debugPrint('🌿 PlantNet [$operationName]: Response body length: ${response.body.length}');

    if (response.statusCode == 429) {
      throw ApiRateLimitException(
        'PlantNet API rate limit reached. Free tier allows limited requests per day.',
      );
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const ApiUnavailableException(
        'PlantNet API authentication failed. Please check your API key.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final errorBody = response.body.length > 300 
          ? response.body.substring(0, 300) 
          : response.body;
      throw HttpException(
        'PlantNet API error: ${response.statusCode} - $errorBody',
      );
    }

    final jsonBody = jsonDecode(response.body);
    if (jsonBody is Map<String, dynamic>) {
      final results = jsonBody['results'];
      final resultCount = results is List ? results.length : 0;
      debugPrint('✅ PlantNet [$operationName]: Success - $resultCount results');
      return jsonBody;
    }

    throw const FormatException('Unexpected PlantNet response format');
  }
}