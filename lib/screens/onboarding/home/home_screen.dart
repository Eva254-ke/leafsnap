import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../components/remote_config_ui.dart';
import '../../../services/api_error.dart';
import '../../../services/billing_service.dart';
import '../../../services/inaturalist_api.dart';
import '../../../services/location_permission_service.dart';
import '../../../services/perenual_api.dart';
import '../../../services/weather_service.dart';
import 'plant_detail_screen.dart';
import '../search/search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  static const List<String> _weedWatchQueries = <String>[
    'Blackjack',
    'Pigweed',
    'Nutgrass',
    'Crabgrass',
  ];

  static const Duration _cropCacheTtl = Duration(hours: 12);
  static const Duration _locationTimeout = Duration(seconds: 8);
  static const Duration _geocodeTimeout = Duration(seconds: 4);

  final PerenualApi _perenualApi = PerenualApi();
  final INaturalistApi _inatApi = INaturalistApi();
  final WeatherService _weatherService = WeatherService();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  String _locationLabel = 'Locating...';
  String _city = 'your area';
  String _country = '';
  String _selectedTown = '';
  List<String> _nearbyTowns = <String>[];
  WeatherSnapshot? _weather;

  bool _isLoadingCrops = false;
  String? _cropError;
  bool _isApiLimitReached = false;
  List<PerenualSpeciesSummary> _spotlightCrops = [];
  List<PerenualSpeciesSummary> _cropLibrary = [];

  bool _isLoadingWeeds = false;
  String? _weedError;
  List<INaturalistObservation> _weedWatch = [];

  // Reliable fallback images for common plants (Unsplash - free to use)
  static const Map<String, String> _fallbackPlantImages = {
    'Tomato': 'https://images.unsplash.com/photo-1592924357228-91a4daadcfea?w=400&h=300&fit=crop',
    'Maize':
        'https://www.grantthornton.in/globalassets/1.-member-firms/india/assets/pdf-images/554x544px/photograph/554x544px_website_photographs_641.jpg',
    'Corn':
        'https://www.grantthornton.in/globalassets/1.-member-firms/india/assets/pdf-images/554x544px/photograph/554x544px_website_photographs_641.jpg',
    'Bean': 'https://www.thespruce.com/thmb/cSsyLW4TIiQg0o4rk0wNdXzWrMM=/3564x2477/filters:no_upscale():max_bytes(150000):strip_icc()/GettyImages-1820512381-5bec11bf46e0fb0026b2d89c.jpg',
    'Beans': 'https://www.thespruce.com/thmb/cSsyLW4TIiQg0o4rk0wNdXzWrMM=/3564x2477/filters:no_upscale():max_bytes(150000):strip_icc()/GettyImages-1820512381-5bec11bf46e0fb0026b2d89c.jpg',
    'Phaseolus vulgaris': 'https://www.thespruce.com/thmb/cSsyLW4TIiQg0o4rk0wNdXzWrMM=/3564x2477/filters:no_upscale():max_bytes(150000):strip_icc()/GettyImages-1820512381-5bec11bf46e0fb0026b2d89c.jpg',
    'Spinach': 'https://media.istockphoto.com/id/477028180/photo/sliverbeet-grow-in-vegetable-garden.jpg?s=612x612&w=0&k=20&c=w3NUQmdUTE5idrgVqn101GoHTwwjBqf6QGnvTvqtgHs=',
    'Kale': 'https://tse4.mm.bing.net/th/id/OIP.XfJY39qYuB4mZ8nC2FQD3gHaEz?rs=1&pid=ImgDetMain&o=7&rm=3',
    'Cabbage':
        'https://tse1.mm.bing.net/th/id/OIP.5ATExUzSl3XqRjWJn9KebQHaFq?w=570&h=436&rs=1&pid=ImgDetMain&o=7&rm=3',
    'Onion': 'https://growhappierplants.com/wp-content/uploads/2023/05/green-onion-plants.jpg',
    'Pepper': 'https://images.unsplash.com/photo-1563565375-f3fdfdbefa83?w=400&h=300&fit=crop',
    'Cucumber': 'https://images.unsplash.com/photo-1449300079323-02e209d9d3a6?w=400&h=300&fit=crop',
    'Lettuce': 'https://images.unsplash.com/photo-1622206151226-18ca2c9ab4a1?w=400&h=300&fit=crop',
    'Carrot': 'https://tse1.mm.bing.net/th/id/OIP.rvpW66Zu3XtCsAxOYQ5-4QHaE6?rs=1&pid=ImgDetMain&o=7&rm=3',
    'Potato': 'https://images.unsplash.com/photo-1518977676654-2e86c6b7c8f0?w=400&h=300&fit=crop',
    'Rice': 'https://images.unsplash.com/photo-1586201375761-83865001e31c?w=400&h=300&fit=crop',
    'Okra': 'https://images.unsplash.com/photo-1601648764658-ad37934f8c0e?w=400&h=300&fit=crop',
    'Cassava': 'https://images.unsplash.com/photo-1601648764658-ad37934f8c0e?w=400&h=300&fit=crop',
    'Plantain': 'https://images.unsplash.com/photo-1571771096344-2a5e0c3c2f8e?w=400&h=300&fit=crop',
  };

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _animationController.forward();

    _loadCachedCrops(allowStale: true, town: _city);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadLocation();
      }
    });
    _loadWeedWatch();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled()
          .timeout(const Duration(seconds: 3));
      if (!serviceEnabled) {
        await _useDefaultLocationData(label: 'Enable location');
        return;
      }

      final permission =
          await LocationPermissionService.checkAndRequestIfNeeded();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        await _useDefaultLocationData(
          label: permission == LocationPermission.deniedForever
              ? 'Enable in settings'
              : 'Location off',
        );
        return;
      }

      final position = await _currentOrLastKnownPosition();
      if (position == null) {
        await _useDefaultLocationData(label: 'Location unavailable');
        return;
      }

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      ).timeout(_geocodeTimeout, onTimeout: () => []);
      final place = placemarks.isNotEmpty ? placemarks.first : null;
      final city = place?.locality?.isNotEmpty == true
          ? place!.locality
          : place?.subAdministrativeArea;
      final region = place?.administrativeArea ?? '';
      final resolvedLabel =
          city?.isNotEmpty == true
              ? city!
              : (region.isNotEmpty ? region : 'Your area');

      if (!mounted) return;
      setState(() {
        _city = resolvedLabel;
        _country = place?.country ?? '';
        _locationLabel = resolvedLabel;
        _nearbyTowns = _nearbyTownsForLocation(
          city: resolvedLabel,
          country: _country,
        );
        _selectedTown = _nearbyTowns.contains(resolvedLabel)
            ? resolvedLabel
            : _nearbyTowns.first;
      });

      _loadWeather(latitude: position.latitude, longitude: position.longitude);
      _loadCropCollections();
    } catch (_) {
      await _useDefaultLocationData(label: 'Location unavailable');
    }
  }

  Future<Position?> _currentOrLastKnownPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: _locationTimeout,
      );
    } catch (_) {
      try {
        return await Geolocator.getLastKnownPosition();
      } catch (_) {
        return null;
      }
    }
  }

  Future<void> _useDefaultLocationData({required String label}) async {
    if (!mounted) return;
    setState(() {
      _locationLabel = label;
      _city = 'your area';
      _country = '';
      _weather = null;
      _nearbyTowns = _nearbyTownsForLocation(city: _city, country: _country);
      _selectedTown = _nearbyTowns.first;
    });
    await _loadCachedCrops(allowStale: true, town: _city);
    _loadCropCollections();
  }

  Future<void> _loadWeather({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final snapshot = await _weatherService.fetchWeather(
        latitude: latitude,
        longitude: longitude,
      );

      if (!mounted) return;
      setState(() {
        _weather = snapshot;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _weather = null;
      });
    }
  }

  Future<void> _loadCropCollections() async {
    final town = _selectedTown.isNotEmpty ? _selectedTown : _city;
    setState(() {
      _isLoadingCrops = true;
      _cropError = null;
      _isApiLimitReached = false;
    });

    await _loadCachedCrops(allowStale: true, town: town);

    try {
      final profile = _cropProfileForTown(town);
      final spotlight = await _fetchCropMatches(profile.spotlight);
      final library = await _fetchCropMatches(profile.library);

      if (!mounted) return;
      setState(() {
        _spotlightCrops = spotlight;
        _cropLibrary = library;
        _isApiLimitReached = false;
      });
      await _saveCachedCrops(town: town, spotlight: spotlight, library: library);
    } catch (error) {
      if (!mounted) return;
      if (isRateLimitError(error)) {
        setState(() {
          _isApiLimitReached = true;
        });
        if (_spotlightCrops.isNotEmpty || _cropLibrary.isNotEmpty) {
          // Keep cached data, don't set error
          return;
        }
      }
      setState(() {
        _cropError = _describeCropError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCrops = false;
        });
      }
    }
  }

  Future<void> _loadCachedCrops({
    required bool allowStale,
    required String town,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final spotlightCacheKey = _spotlightCacheKey(town);
    final spotlightCacheTsKey = _spotlightCacheTsKey(town);
    final libraryCacheKey = _libraryCacheKey(town);
    final libraryCacheTsKey = _libraryCacheTsKey(town);

    final cachedSpotlight = _readCachedCrops(
      prefs: prefs,
      cacheKey: spotlightCacheKey,
      cacheTsKey: spotlightCacheTsKey,
      allowStale: allowStale,
    );
    final cachedLibrary = _readCachedCrops(
      prefs: prefs,
      cacheKey: libraryCacheKey,
      cacheTsKey: libraryCacheTsKey,
      allowStale: allowStale,
    );

    if (!mounted) return;
    if (cachedSpotlight != null || cachedLibrary != null) {
      setState(() {
        if (cachedSpotlight != null) {
          _spotlightCrops = cachedSpotlight;
        }
        if (cachedLibrary != null) {
          _cropLibrary = cachedLibrary;
        }
      });
    }
  }

  List<PerenualSpeciesSummary>? _readCachedCrops({
    required SharedPreferences prefs,
    required String cacheKey,
    required String cacheTsKey,
    required bool allowStale,
  }) {
    final cachedBody = prefs.getString(cacheKey);
    final cachedAt = prefs.getInt(cacheTsKey);
    if (cachedBody == null || cachedAt == null) {
      return null;
    }
    final age = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(cachedAt),
    );
    if (!allowStale && age > _cropCacheTtl) {
      return null;
    }
    final decoded = jsonDecode(cachedBody) as List<dynamic>;
    return decoded
        .cast<Map<String, dynamic>>()
        .map(PerenualSpeciesSummary.fromCacheMap)
        .where((item) => item.id != 0)
        .toList();
  }

  Future<void> _saveCachedCrops({
    required String town,
    required List<PerenualSpeciesSummary> spotlight,
    required List<PerenualSpeciesSummary> library,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final spotlightCacheKey = _spotlightCacheKey(town);
    final spotlightCacheTsKey = _spotlightCacheTsKey(town);
    final libraryCacheKey = _libraryCacheKey(town);
    final libraryCacheTsKey = _libraryCacheTsKey(town);

    await prefs.setString(
      spotlightCacheKey,
      jsonEncode(spotlight.map((item) => item.toCacheMap()).toList()),
    );
    await prefs.setInt(
      spotlightCacheTsKey,
      DateTime.now().millisecondsSinceEpoch,
    );
    await prefs.setString(
      libraryCacheKey,
      jsonEncode(library.map((item) => item.toCacheMap()).toList()),
    );
    await prefs.setInt(
      libraryCacheTsKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  String _normalizedCacheKeyPart(String value) {
    final normalized = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    return normalized.isEmpty ? 'default' : normalized;
  }

  String _spotlightCacheKey(String town) =>
      'home_spotlight_crops_${_normalizedCacheKeyPart(town)}';

  String _spotlightCacheTsKey(String town) =>
      'home_spotlight_crops_${_normalizedCacheKeyPart(town)}_ts';

  String _libraryCacheKey(String town) =>
      'home_library_crops_${_normalizedCacheKeyPart(town)}';

  String _libraryCacheTsKey(String town) =>
      'home_library_crops_${_normalizedCacheKeyPart(town)}_ts';

  String _describeCropError(Object error) {
    if (error is StateError && error.message.contains('PLANT_QUERY_API_KEY')) {
      return 'Missing PLANT_QUERY_API_KEY in .env';
    }
    if (error is HttpException) {
      return error.message;
    }
    if (isRateLimitError(error)) {
      return 'Plant references are busy right now. Please try again later.';
    }
    return error.toString();
  }

  Future<void> _loadWeedWatch() async {
    setState(() {
      _isLoadingWeeds = true;
      _weedError = null;
    });

    try {
      final weeds = await _fetchWeedMatches(_weedWatchQueries);

      if (!mounted) return;
      setState(() {
        _weedWatch = weeds;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _weedError = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingWeeds = false;
        });
      }
    }
  }

  // Simplified weather icons: sunny, cloudy, or rainy (cloud for anything wet)
  IconData _weatherIconForCode(int? code, bool isDay) {
    if (code == null) {
      return isDay ? Icons.wb_sunny_outlined : Icons.nightlight_outlined;
    }

    // Open-Meteo: 0 = clear sky, 1 = mainly clear.
    if (code == 0 || code == 1) {
      return isDay ? Icons.wb_sunny_outlined : Icons.nightlight_outlined;
    }
    // 2 = partly cloudy, 3 = overcast.
    if (code >= 2 && code <= 3) {
      return Icons.cloud_outlined;
    }
    // Fog, mist
    if (code >= 45 && code <= 48) {
      return Icons.cloud_outlined;
    }
    // Drizzle, rain, showers, snow, thunderstorm â€” all show cloud icon
    if (code >= 51) {
      return Icons.cloud_outlined;
    }
    return isDay ? Icons.wb_sunny_outlined : Icons.nightlight_outlined;
  }

  Future<List<PerenualSpeciesSummary>> _fetchCropMatches(
    List<_CropQuery> queries,
  ) async {
    final picks = <PerenualSpeciesSummary>[];
    final seen = <String>{};

    for (final query in queries) {
      final results = await _perenualApi.searchSpecies(
        query: query.searchTerm,
        page: 1,
      );
      final match = _bestSpeciesMatch(query: query, results: results);
      if (match == null) continue;

      final key =
          '${match.commonName.toLowerCase()}|${match.scientificName.toLowerCase()}';
      if (seen.add(key)) {
        picks.add(match);
      }
    }

    return picks;
  }

  Future<List<INaturalistObservation>> _fetchWeedMatches(
    List<String> queries,
  ) async {
    final picks = <INaturalistObservation>[];
    final seen = <String>{};

    for (final query in queries) {
      final results = await _inatApi.searchPlants(query: query, perPage: 8);
      final match = _bestObservationMatch(query: query, results: results);
      if (match == null) continue;

      final primaryName = (match.commonName ?? match.title).toLowerCase();
      final key = '$primaryName|${match.title.toLowerCase()}';
      if (seen.add(key)) {
        picks.add(match);
      }
    }

    return picks;
  }

  PerenualSpeciesSummary? _bestSpeciesMatch({
    required _CropQuery query,
    required List<PerenualSpeciesSummary> results,
  }) {
    PerenualSpeciesSummary? bestMatch;
    PerenualSpeciesSummary? fallbackWithImage;
    PerenualSpeciesSummary? fallback;
    var bestScore = -1;

    for (final species in results) {
      final haystack = '${species.commonName} ${species.scientificName}'
          .toLowerCase();
      final hasImage =
          _hasUsableImageUrl(species.imageUrl) ||
          _hasUsableImageUrl(species.thumbnailUrl);
      final isExcluded = _containsAny(haystack, query.excludedTerms);

      if (!isExcluded) {
        fallback ??= species;
        if (hasImage) {
          fallbackWithImage ??= species;
        }
      }

      if (isExcluded) {
        continue;
      }

      var score = 0;
      if (haystack.contains(query.searchTerm.toLowerCase())) {
        score += 4;
      }
      if (_containsAny(haystack, query.preferredTerms)) {
        score += 5;
      }
      if (species.commonName.toLowerCase() == query.searchTerm.toLowerCase()) {
        score += 3;
      }
      if (hasImage) {
        score += 2;
      }

      if (score > bestScore) {
        bestScore = score;
        bestMatch = species;
      }
    }

    return bestMatch ?? fallbackWithImage ?? fallback;
  }

  INaturalistObservation? _bestObservationMatch({
    required String query,
    required List<INaturalistObservation> results,
  }) {
    for (final observation in results) {
      final haystack = '${observation.commonName ?? ''} ${observation.title}'
          .toLowerCase();
      if (haystack.contains(query.toLowerCase())) {
        return observation;
      }
    }
    return results.isEmpty ? null : results.first;
  }

  List<String> _nearbyTownsForLocation({
    required String city,
    required String country,
  }) {
    final normalizedCountry = country.toLowerCase();

    if (_matchesCountry(normalizedCountry, const <String>[
      'kenya',
      'uganda',
      'tanzania',
      'rwanda',
      'ethiopia',
    ])) {
      return <String>[
        city,
        'Kiambu',
        'Thika',
        'Machakos',
        'Kajiado',
      ];
    }

    if (_matchesCountry(normalizedCountry, const <String>[
      'nigeria',
      'ghana',
      'cameroon',
      'senegal',
      'ivory coast',
      'cote d\'ivoire',
    ])) {
      return <String>[
        city,
        'Lagos',
        'Ibadan',
        'Abeokuta',
        'Ado-Ekiti',
      ];
    }

    return <String>[
      city,
      'Nearby Town 1',
      'Nearby Town 2',
      'Nearby Town 3',
      'Nearby Town 4',
    ];
  }

  _CropProfile _cropProfileForTown(String town) {
    final selectedTown = town.toLowerCase();
    final country = _country.toLowerCase();

    if (_matchesCountry(country, const <String>[
      'kenya',
      'uganda',
      'tanzania',
      'rwanda',
      'ethiopia',
    ])) {
      if (selectedTown.contains('nairobi')) {
        return const _CropProfile(
          spotlight: <_CropQuery>[
            _CropQuery(searchTerm: 'Tomato', preferredTerms: <String>['tomato', 'solanum lycopersicum']),
            _CropQuery(searchTerm: 'Spinach', preferredTerms: <String>['spinach', 'spinacia oleracea']),
            _CropQuery(searchTerm: 'Cucumber', preferredTerms: <String>['cucumber', 'cucumis sativus']),
            _CropQuery(searchTerm: 'Beans', preferredTerms: <String>['bean', 'phaseolus']),
            _CropQuery(searchTerm: 'Kale', preferredTerms: <String>['kale', 'brassica oleracea']),
          ],
          library: <_CropQuery>[
            _CropQuery(searchTerm: 'Carrot', preferredTerms: <String>['carrot', 'daucus carota']),
            _CropQuery(searchTerm: 'Lettuce', preferredTerms: <String>['lettuce', 'lactuca sativa']),
            _CropQuery(searchTerm: 'Pepper', preferredTerms: <String>['pepper', 'capsicum']),
            _CropQuery(searchTerm: 'Onion', preferredTerms: <String>['onion', 'allium cepa']),
          ],
        );
      }

      if (selectedTown.contains('thika')) {
        return const _CropProfile(
          spotlight: <_CropQuery>[
            _CropQuery(searchTerm: 'Maize', preferredTerms: <String>['maize', 'corn', 'zea mays']),
            _CropQuery(searchTerm: 'Beans', preferredTerms: <String>['bean', 'phaseolus']),
            _CropQuery(searchTerm: 'Tomato', preferredTerms: <String>['tomato', 'solanum lycopersicum']),
            _CropQuery(searchTerm: 'Cabbage', preferredTerms: <String>['cabbage', 'brassica oleracea']),
            _CropQuery(searchTerm: 'Onion', preferredTerms: <String>['onion', 'allium cepa']),
          ],
          library: <_CropQuery>[
            _CropQuery(searchTerm: 'Carrot', preferredTerms: <String>['carrot', 'daucus carota']),
            _CropQuery(searchTerm: 'Spinach', preferredTerms: <String>['spinach', 'spinacia oleracea']),
            _CropQuery(searchTerm: 'Pepper', preferredTerms: <String>['pepper', 'capsicum']),
            _CropQuery(searchTerm: 'Lettuce', preferredTerms: <String>['lettuce', 'lactuca sativa']),
          ],
        );
      }

      if (selectedTown.contains('machakos')) {
        return const _CropProfile(
          spotlight: <_CropQuery>[
            _CropQuery(searchTerm: 'Tomato', preferredTerms: <String>['tomato', 'solanum lycopersicum']),
            _CropQuery(searchTerm: 'Pepper', preferredTerms: <String>['pepper', 'capsicum']),
            _CropQuery(searchTerm: 'Onion', preferredTerms: <String>['onion', 'allium cepa']),
            _CropQuery(searchTerm: 'Beans', preferredTerms: <String>['bean', 'phaseolus']),
            _CropQuery(searchTerm: 'Kale', preferredTerms: <String>['kale', 'brassica oleracea']),
          ],
          library: <_CropQuery>[
            _CropQuery(searchTerm: 'Cucumber', preferredTerms: <String>['cucumber', 'cucumis sativus']),
            _CropQuery(searchTerm: 'Carrot', preferredTerms: <String>['carrot', 'daucus carota']),
            _CropQuery(searchTerm: 'Lettuce', preferredTerms: <String>['lettuce', 'lactuca sativa']),
            _CropQuery(searchTerm: 'Spinach', preferredTerms: <String>['spinach', 'spinacia oleracea']),
          ],
        );
      }

      if (selectedTown.contains('kajiado')) {
        return const _CropProfile(
          spotlight: <_CropQuery>[
            _CropQuery(searchTerm: 'Cabbage', preferredTerms: <String>['cabbage', 'brassica oleracea']),
            _CropQuery(searchTerm: 'Potato', preferredTerms: <String>['potato', 'solanum tuberosum']),
            _CropQuery(searchTerm: 'Tomato', preferredTerms: <String>['tomato', 'solanum lycopersicum']),
            _CropQuery(searchTerm: 'Beans', preferredTerms: <String>['bean', 'phaseolus']),
            _CropQuery(searchTerm: 'Onion', preferredTerms: <String>['onion', 'allium cepa']),
          ],
          library: <_CropQuery>[
            _CropQuery(searchTerm: 'Carrot', preferredTerms: <String>['carrot', 'daucus carota']),
            _CropQuery(searchTerm: 'Pepper', preferredTerms: <String>['pepper', 'capsicum']),
            _CropQuery(searchTerm: 'Lettuce', preferredTerms: <String>['lettuce', 'lactuca sativa']),
            _CropQuery(searchTerm: 'Maize', preferredTerms: <String>['maize', 'corn', 'zea mays']),
          ],
        );
      }

      return const _CropProfile(
        spotlight: <_CropQuery>[
          _CropQuery(searchTerm: 'Tomato', preferredTerms: <String>['tomato', 'solanum lycopersicum'], excludedTerms: <String>['tree tomato', 'tamarillo', 'solanum betaceum']),
          _CropQuery(searchTerm: 'Onion', preferredTerms: <String>['onion', 'allium cepa']),
          _CropQuery(searchTerm: 'Maize', preferredTerms: <String>['maize', 'corn', 'zea mays']),
          _CropQuery(searchTerm: 'Beans', preferredTerms: <String>['bean', 'phaseolus']),
          _CropQuery(searchTerm: 'Cabbage', preferredTerms: <String>['cabbage', 'brassica oleracea']),
        ],
        library: <_CropQuery>[
          _CropQuery(searchTerm: 'Pepper', preferredTerms: <String>['pepper', 'capsicum']),
          _CropQuery(searchTerm: 'Rice', preferredTerms: <String>['rice', 'oryza sativa']),
          _CropQuery(searchTerm: 'Banana', preferredTerms: <String>['banana', 'musa']),
          _CropQuery(searchTerm: 'Okra', preferredTerms: <String>['okra', 'abelmoschus esculentus']),
        ],
      );
    }

    if (_matchesCountry(country, const <String>[
      'nigeria',
      'ghana',
      'cameroon',
      'senegal',
      'ivory coast',
      'cote d\'ivoire',
    ])) {
      return const _CropProfile(
        spotlight: <_CropQuery>[
          _CropQuery(searchTerm: 'Tomato', preferredTerms: <String>['tomato', 'solanum lycopersicum'], excludedTerms: <String>['tree tomato', 'tamarillo', 'solanum betaceum']),
          _CropQuery(searchTerm: 'Pepper', preferredTerms: <String>['pepper', 'capsicum']),
          _CropQuery(searchTerm: 'Onion', preferredTerms: <String>['onion', 'allium cepa']),
          _CropQuery(searchTerm: 'Okra', preferredTerms: <String>['okra', 'abelmoschus esculentus']),
          _CropQuery(searchTerm: 'Maize', preferredTerms: <String>['maize', 'corn', 'zea mays']),
        ],
        library: <_CropQuery>[
          _CropQuery(searchTerm: 'Cassava', preferredTerms: <String>['cassava', 'manihot esculenta']),
          _CropQuery(searchTerm: 'Beans', preferredTerms: <String>['bean', 'phaseolus']),
          _CropQuery(searchTerm: 'Plantain', preferredTerms: <String>['plantain', 'musa']),
          _CropQuery(searchTerm: 'Rice', preferredTerms: <String>['rice', 'oryza sativa']),
        ],
      );
    }

    return const _CropProfile(
      spotlight: <_CropQuery>[
        _CropQuery(searchTerm: 'Tomato', preferredTerms: <String>['tomato', 'solanum lycopersicum'], excludedTerms: <String>['tree tomato', 'tamarillo', 'solanum betaceum']),
        _CropQuery(searchTerm: 'Onion', preferredTerms: <String>['onion', 'allium cepa']),
        _CropQuery(searchTerm: 'Pepper', preferredTerms: <String>['pepper', 'capsicum']),
        _CropQuery(searchTerm: 'Cucumber', preferredTerms: <String>['cucumber', 'cucumis sativus']),
        _CropQuery(searchTerm: 'Lettuce', preferredTerms: <String>['lettuce', 'lactuca sativa']),
      ],
      library: <_CropQuery>[
        _CropQuery(searchTerm: 'Beans', preferredTerms: <String>['bean', 'phaseolus']),
        _CropQuery(searchTerm: 'Cabbage', preferredTerms: <String>['cabbage', 'brassica oleracea']),
        _CropQuery(searchTerm: 'Maize', preferredTerms: <String>['maize', 'corn', 'zea mays']),
        _CropQuery(searchTerm: 'Banana', preferredTerms: <String>['banana', 'musa']),
      ],
    );
  }

  bool _containsAny(String haystack, List<String> terms) {
    for (final term in terms) {
      if (haystack.contains(term.toLowerCase())) {
        return true;
      }
    }
    return false;
  }

  bool _matchesCountry(String country, List<String> options) {
    for (final option in options) {
      if (country.contains(option)) {
        return true;
      }
    }
    return false;
  }

  String _normalizePlantName(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool _hasUsableImageUrl(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return false;
    }

    return !normalized.toLowerCase().contains('upgrade_access.jpg');
  }

  String? _fallbackImageUrlForPlant(String plantName) {
    final normalizedName = _normalizePlantName(plantName);
    if (normalizedName.isEmpty) {
      return null;
    }

    for (final entry in _fallbackPlantImages.entries) {
      final normalizedKey = _normalizePlantName(entry.key);
      if (normalizedKey == normalizedName ||
          normalizedName.contains(normalizedKey) ||
          normalizedKey.contains(normalizedName)) {
        return entry.value;
      }
    }

    return null;
  }

  bool _prefersCuratedImage(String plantName) {
    final normalizedName = _normalizePlantName(plantName);
    return normalizedName.contains('spinach') ||
        normalizedName.contains('spinacia oleracea') ||
        normalizedName.contains('bean') ||
        normalizedName.contains('phaseolus') ||
        normalizedName.contains('cabbage') ||
        normalizedName.contains('onion') ||
        normalizedName.contains('allium cepa');
  }

  List<String> _imageCandidates(String? apiUrl, String plantName) {
    final candidates = <String>[];
    final fallbackUrl = _fallbackImageUrlForPlant(plantName);

    if (_prefersCuratedImage(plantName) && fallbackUrl != null) {
      candidates.add(fallbackUrl);
    }

    if (_hasUsableImageUrl(apiUrl)) {
      candidates.add(apiUrl!.trim());
    }

    if (!_prefersCuratedImage(plantName) && fallbackUrl != null) {
      candidates.add(fallbackUrl);
    }

    return candidates.toSet().toList();
  }

  String? _preferredImageUrl(String? apiUrl, String plantName) {
    final candidates = _imageCandidates(apiUrl, plantName);
    return candidates.isEmpty ? null : candidates.first;
  }

  int? _safeToInt(double? value) {
    if (value == null || value.isNaN || value.isInfinite) {
      return null;
    }
    return value.toInt();
  }

  Widget _buildCachedImage({
    required String? imageUrl,
    required String plantName,
    required double width,
    required double height,
    BoxFit fit = BoxFit.cover,
  }) {
    // Ensure dimensions are finite
    final safeWidth = width.isFinite ? width : 140.0;
    final safeHeight = height.isFinite ? height : 110.0;

    final candidates = _imageCandidates(imageUrl, plantName);

    return _buildCachedImageFromCandidates(
      candidates: candidates,
      plantName: plantName,
      width: safeWidth,
      height: safeHeight,
      fit: fit,
    );
  }

  Widget _buildCachedImageFromCandidates({
    required List<String> candidates,
    required String plantName,
    required double width,
    required double height,
    required BoxFit fit,
    int index = 0,
  }) {
    if (index >= candidates.length) {
      return _imagePlaceholder(width: width, height: height);
    }

    final currentUrl = candidates[index];

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: currentUrl,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) => _imagePlaceholder(width: width, height: height),
        errorWidget: (context, url, error) => _buildCachedImageFromCandidates(
          candidates: candidates,
          plantName: plantName,
          width: width,
          height: height,
          fit: fit,
          index: index + 1,
        ),
        memCacheWidth: _safeToInt(width),
        cacheKey: currentUrl,
        // Removed DefaultCacheManager - CachedNetworkImage uses default cache automatically
      ),
    );
  }

  Widget _imagePlaceholder({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
      ),
      child: const Icon(Icons.local_florist, color: Color(0xFF228B22), size: 24),
    );
  }

  Widget _buildSkeletonCard({required double width, required double height}) {
    final safeWidth = width.isFinite ? width : 140.0;
    final safeHeight = height.isFinite ? height : 110.0;
    
    return Container(
      width: safeWidth,
      height: safeHeight,
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final town = _selectedTown.isNotEmpty ? _selectedTown : _locationLabel;
    final currentTemp =
        _weather?.currentTempC != null ? '${_weather?.currentTempC.round()}\u00B0' : '--';
    final weatherCode = _weather?.weatherCode;
    final isDay = _weather?.isDay ?? true;
    return RemoteConfigBuilder(
      screenId: RemoteConfigScreens.home,
      fallbackBackgroundColor: const Color(0xFFF0FFF4),
      fallbackPrimaryColor: const Color(0xFF228B22),
      builder: (context, remoteConfig) {
        return Scaffold(
      backgroundColor: remoteConfig.backgroundColor,
      appBar: AppBar(
        backgroundColor: remoteConfig.backgroundColor,
        foregroundColor: const Color(0xFF1B1B1B),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: PopupMenuButton<String>(
          tooltip: 'Choose nearby town',
          offset: const Offset(0, 48),
          onSelected: (value) {
            if (value == _selectedTown) return;
            setState(() {
              _selectedTown = value;
            });
            _loadCropCollections();
          },
          itemBuilder: (context) {
            return _nearbyTowns
                .map(
                  (townName) => PopupMenuItem<String>(
                    value: townName,
                    child: Text(townName, style: GoogleFonts.inter(fontSize: 14)),
                  ),
                )
                .toList();
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  town,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                    color: const Color(0xFF1B1B1B),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_drop_down, color: Color(0xFF1B1B1B), size: 20),
            ],
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Show current temperature only
                Text(
                  currentTemp,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1B1B1B),
                  ),
                ),
                const SizedBox(width: 8),
                // Fixed: Simple weather icon - sunny, cloudy, or rainy (cloud for wet)
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
                  ),
                  child: Icon(
                    _weatherIconForCode(weatherCode, isDay),
                    color: const Color(0xFF228B22),
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (remoteConfig.banner != null) ...[
              RemoteScreenBanner(
                banner: remoteConfig.banner!,
                primaryColor: remoteConfig.primaryColor,
              ),
              const SizedBox(height: 16),
            ],
            if (_hasLocationIssue) ...[
              _buildLocationIssueCard(),
              const SizedBox(height: 16),
            ],
            if (_isApiLimitReached) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFE08A)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.cloud_off_outlined,
                      color: Color(0xFF8A5A00),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Plant references are busy',
                            style: GoogleFonts.spaceGrotesk(
                              color: const Color(0xFF5D3D00),
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Cached crops may still appear. Please try again later.',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF7A5200),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            _buildPlantSearchSection(),
            const SizedBox(height: 24),
            _buildSectionHeader(title: 'Hot Right Now in $town'),
            const SizedBox(height: 12),
            if (_isLoadingCrops && _spotlightCrops.isEmpty)
              _buildSpotlightSkeleton()
            else if (_cropError != null && _spotlightCrops.isEmpty)
              _sectionErrorCard(
                'Crop suggestions are unavailable right now.\n$_cropError',
                onRetry: _loadCropCollections,
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isLoadingCrops)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: LinearProgressIndicator(color: Color(0xFF228B22)),
                    ),
                  _buildSpotlightCrops(),
                ],
              ),
            const SizedBox(height: 24),
            _buildSectionHeader(title: 'Weed Watch'),
            const SizedBox(height: 12),
            if (_isLoadingWeeds)
              _buildWeedWatchSkeleton()
            else if (_weedError != null)
              _sectionErrorCard(
                'Weed watch is unavailable right now.',
                onRetry: _loadWeedWatch,
              )
            else
              _buildWeedWatch(),
            const SizedBox(height: 24),
            _buildSectionHeader(title: 'Crop Library'),
            const SizedBox(height: 12),
            if (_isLoadingCrops && _cropLibrary.isEmpty)
              _buildLibrarySkeleton()
            else if (_cropError != null && _cropLibrary.isEmpty)
              _sectionErrorCard(
                'Crop library is unavailable right now.\n$_cropError',
                onRetry: _loadCropCollections,
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isLoadingCrops)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: LinearProgressIndicator(color: Color(0xFF228B22)),
                    ),
                  _buildCropLibrary(),
                ],
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
        );
      },
    );
  }

  Widget _buildPlantSearchSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(title: 'Search plants'),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _openPlantSearch,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.search_rounded,
                  color: Color(0xFF22A45D),
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Search plants',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xFF7A7A7A),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  bool get _hasLocationIssue =>
      _locationLabel == 'Enable location' ||
      _locationLabel == 'Enable in settings' ||
      _locationLabel == 'Location off' ||
      _locationLabel == 'Location unavailable';

  Widget _buildLocationIssueCard() {
    final needsAppSettings = _locationLabel == 'Enable in settings';
    final message = needsAppSettings
        ? 'Location was denied. Enable it in app settings to show crops near you.'
        : 'Allow location to show crops and weather near you.';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.location_off_outlined,
            color: Color(0xFF228B22),
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF516052),
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(width: 10),
          TextButton(
            onPressed: () {
              if (needsAppSettings) {
                Geolocator.openAppSettings();
              } else {
                Geolocator.openLocationSettings();
              }
            },
            child: Text(
              'Open',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF228B22),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildSectionHeader({required String title}) {
    return Text(
      title,
      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF1B1B1B)),
    );
  }

  Widget _sectionErrorCard(String message, {VoidCallback? onRetry}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF7A7A7A))),
          if (onRetry != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 36,
              child: ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF228B22),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: Text('Retry', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSpotlightSkeleton() {
    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 4,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _buildSkeletonCard(width: 140, height: 180),
          );
        },
      ),
    );
  }

  Widget _buildSpotlightCrops() {
    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _spotlightCrops.length,
        itemBuilder: (context, index) {
          final crop = _spotlightCrops[index];
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _buildSmallCard(
              title: crop.commonName,
              imageUrl: crop.imageUrl ?? crop.thumbnailUrl,
              onTap: () => _navigateToPlantDetails(
                crop.commonName,
                imageUrl: _preferredImageUrl(
                  crop.imageUrl ?? crop.thumbnailUrl,
                  crop.commonName,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWeedWatchSkeleton() {
    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 4,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _buildSkeletonCard(width: 140, height: 180),
          );
        },
      ),
    );
  }

  Widget _buildWeedWatch() {
    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _weedWatch.length,
        itemBuilder: (context, index) {
          final weed = _weedWatch[index];
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _buildSmallCard(
              title: weed.commonName ?? weed.title,
              imageUrl: weed.imageUrl,
              onTap: () async {
                if (!BillingService.instance.isPremium.value) {
                  await BillingService.instance.presentPaywall();
                  if (!BillingService.instance.isPremium.value) return;
                }
                _navigateToINaturalistDetails(weed.id);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildLibrarySkeleton() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: 4,
      itemBuilder: (context, index) {
        return _buildSkeletonCard(width: 140, height: 160);
      },
    );
  }

  Widget _buildCropLibrary() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: _cropLibrary.length,
      itemBuilder: (context, index) {
        final crop = _cropLibrary[index];
        return _buildLargeCard(
          title: crop.commonName,
          imageUrl: crop.imageUrl ?? crop.thumbnailUrl,
          onTap: () => _navigateToPlantDetails(
            crop.commonName,
            imageUrl: _preferredImageUrl(
              crop.imageUrl ?? crop.thumbnailUrl,
              crop.commonName,
            ),
          ),
        );
      },
    );
  }

  Widget _buildSmallCard({
    required String title,
    String? imageUrl,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCachedImage(
              imageUrl: imageUrl,
              plantName: title,
              width: 140,
              height: 110,
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                title,
                style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: const Color(0xFF1B1B1B)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLargeCard({
    required String title,
    String? imageUrl,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCachedImage(
              imageUrl: imageUrl,
              plantName: title,
              width: 140,
              height: 130,
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                title,
                style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14, color: const Color(0xFF1B1B1B)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToPlantDetails(String plantName, {String? imageUrl}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: 'Plant Detail'),
        builder: (context) => PlantDetailScreen(
          plantName: plantName,
          imageUrl: imageUrl,
        ),
      ),
    );
  }

  void _openPlantSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: 'Search'),
        builder: (context) => const SearchScreen(),
      ),
    );
  }

  void _navigateToINaturalistDetails(int observationId) {
    debugPrint('Navigate to iNaturalist observation: $observationId');
  }
}

class _CropProfile {
  const _CropProfile({required this.spotlight, required this.library});
  final List<_CropQuery> spotlight;
  final List<_CropQuery> library;
}

class _CropQuery {
  const _CropQuery({
    required this.searchTerm,
    this.preferredTerms = const [],
    this.excludedTerms = const [],
  });
  final String searchTerm;
  final List<String> preferredTerms;
  final List<String> excludedTerms;
}
