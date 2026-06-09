// lib/services/diagnose_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/perenual_api.dart';
import '../models/diagnose_models.dart';
import '../utils/api_rate_limiter.dart';

/// Service that fetches plant and issue showcase data, caches it, and throttles API calls.
class DiagnoseService {
  DiagnoseService._();
  static final DiagnoseService instance = DiagnoseService._();

  final PerenualApi _api = PerenualApi();
  final ApiRateLimiter _rateLimiter = ApiRateLimiter(maxCallsPerMinute: 30);

  static const String _plantsCacheKey = 'diagnose_showcase_plants';
  static const String _plantsCacheTsKey = 'diagnose_showcase_plants_ts';
  static const String _issuesCacheKey = 'diagnose_showcase_issues';
  static const String _issuesCacheTsKey = 'diagnose_showcase_issues_ts';
  static const Duration _cacheTtl = Duration(hours: 12);

  Future<List<DiagnosePlantCard>> getPlantCards({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    if (!forceRefresh) {
      final cached = _readCachedPlantCards(prefs);
      if (cached != null) return cached;
    }
    await _rateLimiter.acquire();
    final cards = await _fetchPlantCards();
    await _savePlantCards(prefs, cards);
    return cards;
  }

  Future<List<DiagnoseIssueCard>> getIssueCards({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    if (!forceRefresh) {
      final cached = _readCachedIssueCards(prefs);
      if (cached != null) return cached;
    }
    await _rateLimiter.acquire();
    final cards = await _fetchIssueCards();
    await _saveIssueCards(prefs, cards);
    return cards;
  }

  // Internal helpers – duplicated from DiagnoseScreen for simplicity.
  Future<List<DiagnosePlantCard>> _fetchPlantCards() async {
    final cards = <DiagnosePlantCard>[];
    for (final seed in _DiagnoseScreenHelper.plantSeeds) {
      final results = await _api.searchSpecies(query: seed.query, page: 1);
      final match = _DiagnoseScreenHelper.bestPlantMatch(seed, results);
      final imageUrl = match?.imageUrl ?? match?.thumbnailUrl;
      if (match == null || !_DiagnoseScreenHelper.hasUsableImageUrl(imageUrl)) continue;
      cards.add(DiagnosePlantCard(
        query: seed.query,
        focusLabel: seed.focusLabel,
        note: seed.note,
        species: match,
      ));
    }
    return cards;
  }

  Future<List<DiagnoseIssueCard>> _fetchIssueCards() async {
    final cards = <DiagnoseIssueCard>[];
    for (final seed in _DiagnoseScreenHelper.issueSeeds) {
      final results = await _api.searchDiseases(query: seed.query, page: 1);
      final match = _DiagnoseScreenHelper.bestIssueMatch(seed, results);
      if (match == null || !_DiagnoseScreenHelper.hasUsableImageUrl(match.thumbnailUrl)) continue;
      cards.add(DiagnoseIssueCard(
        query: seed.query,
        badge: seed.badge,
        note: seed.note,
        disease: match,
      ));
    }
    return cards;
  }

  List<DiagnosePlantCard>? _readCachedPlantCards(SharedPreferences prefs) {
    final body = prefs.getString(_plantsCacheKey);
    final ts = prefs.getInt(_plantsCacheTsKey);
    if (body == null || ts == null) return null;
    final age = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ts));
    if (age > _cacheTtl) return null;
    final decoded = jsonDecode(body) as List<dynamic>;
    return decoded.map((e) => DiagnosePlantCard.fromCacheMap(e as Map<String, dynamic>)).toList();
  }

  List<DiagnoseIssueCard>? _readCachedIssueCards(SharedPreferences prefs) {
    final body = prefs.getString(_issuesCacheKey);
    final ts = prefs.getInt(_issuesCacheTsKey);
    if (body == null || ts == null) return null;
    final age = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ts));
    if (age > _cacheTtl) return null;
    final decoded = jsonDecode(body) as List<dynamic>;
    return decoded.map((e) => DiagnoseIssueCard.fromCacheMap(e as Map<String, dynamic>)).toList();
  }

  Future<void> _savePlantCards(SharedPreferences prefs, List<DiagnosePlantCard> cards) async {
    await prefs.setString(_plantsCacheKey, jsonEncode(cards.map((c) => c.toCacheMap()).toList()));
    await prefs.setInt(_plantsCacheTsKey, DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> _saveIssueCards(SharedPreferences prefs, List<DiagnoseIssueCard> cards) async {
    await prefs.setString(_issuesCacheKey, jsonEncode(cards.map((c) => c.toCacheMap()).toList()));
    await prefs.setInt(_issuesCacheTsKey, DateTime.now().millisecondsSinceEpoch);
  }
}

// Helper to expose seed data and matching logic without pulling it from the UI.
class _DiagnoseScreenHelper {
  static const List<PlantShowcaseSeed> plantSeeds = <PlantShowcaseSeed>[
    // The seeds are duplicated from DiagnoseScreen for reference.
    PlantShowcaseSeed(
      query: 'Monstera',
      focusLabel: 'Indoor match',
      note: 'Compare yellow edges, tears, and broad-leaf discoloration.',
      preferredTerms: ['monstera', 'deliciosa', 'swiss cheese'],
    ),
    PlantShowcaseSeed(
      query: 'Solanum lycopersicum',
      focusLabel: 'Crop match',
      note: 'Useful for spotting curl, blight, and lower-leaf stress early.',
      preferredTerms: ['tomato', 'solanum lycopersicum'],
    ),
    PlantShowcaseSeed(
      query: 'Rose',
      focusLabel: 'Flowering match',
      note: 'Check mildew, black spots, and pest damage on delicate foliage.',
      preferredTerms: ['rose', 'rosa'],
    ),
    PlantShowcaseSeed(
      query: 'Pepper',
      focusLabel: 'Garden match',
      note: 'Great reference for holes, silvering, and heat-stress symptoms.',
      preferredTerms: ['pepper', 'capsicum'],
    ),
  ];

  static const List<IssueShowcaseSeed> issueSeeds = <IssueShowcaseSeed>[
    IssueShowcaseSeed(
      query: 'powdery mildew',
      badge: 'Fungal',
      note: 'White, dusty growth that spreads across the leaf surface.',
      aliases: ['mildew', 'powdery'],
    ),
    IssueShowcaseSeed(
      query: 'leaf spot',
      badge: 'Leaf damage',
      note: 'Dark lesions, yellow halos, and fast-spreading spotting.',
      aliases: ['spot', 'leaf spot'],
    ),
    IssueShowcaseSeed(
      query: 'aphids',
      badge: 'Pests',
      note: 'Sap-sucking insects that curl new growth and weaken stems.',
      aliases: ['aphid', 'insect'],
    ),
    IssueShowcaseSeed(
      query: 'blight',
      badge: 'Urgent',
      note: 'Rapid browning and collapse that can move through a plant fast.',
      aliases: ['blight', 'fungi'],
    ),
  ];

  static bool hasUsableImageUrl(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) return false;
    return !normalized.toLowerCase().contains('upgrade_access.jpg');
  }

  static PerenualSpeciesSummary? bestPlantMatch(PlantShowcaseSeed seed, List<PerenualSpeciesSummary> results) {
    // Reuse logic from DiagnoseScreen (simplified).
    PerenualSpeciesSummary? best;
    int bestScore = -1;
    for (final s in results) {
      int score = 0;
      final haystack = '${s.commonName} ${s.scientificName}'.toLowerCase();
      if (haystack.contains(seed.query.toLowerCase())) score += 5;
      for (final term in seed.preferredTerms) {
        if (haystack.contains(term.toLowerCase())) score += 2;
      }
      if (hasUsableImageUrl(s.imageUrl) || hasUsableImageUrl(s.thumbnailUrl)) score += 3;
      if (score > bestScore) {
        bestScore = score;
        best = s;
      }
    }
    return best;
  }

  static PerenualDiseaseSummary? bestIssueMatch(IssueShowcaseSeed seed, List<PerenualDiseaseSummary> results) {
    PerenualDiseaseSummary? best;
    int bestScore = -1;
    for (final d in results) {
      int score = 0;
      final haystack = '${d.commonName} ${d.scientificName} ${d.otherNames.join(' ')}'.toLowerCase();
      if (haystack.contains(seed.query.toLowerCase())) score += 5;
      for (final alias in seed.aliases) {
        if (haystack.contains(alias.toLowerCase())) score += 2;
      }
      if (hasUsableImageUrl(d.thumbnailUrl)) score += 3;
      if (score > bestScore) {
        bestScore = score;
        best = d;
      }
    }
    return best;
  }
}
