import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../components/app_header.dart';
import '../../../services/diagnose_image_cache.dart';
import '../../../services/perenual_api.dart';
import '../camera/camera_screen.dart';
import 'diagnose_history_screen.dart';

class DiagnoseScreen extends StatefulWidget {
  const DiagnoseScreen({super.key, this.initialImage});

  final Object? initialImage;

  @override
  State<DiagnoseScreen> createState() => _DiagnoseScreenState();
}

class _DiagnoseScreenState extends State<DiagnoseScreen>
    with SingleTickerProviderStateMixin {
  static const Duration _showcaseCacheTtl = Duration(days: 10);
  static const double _showcaseCardBaseHeight = 242;
  static const double _showcaseCardShadowBuffer = 38;
  static const String _plantsCacheKey = 'diagnose_showcase_plants';
  static const String _plantsCacheTsKey = 'diagnose_showcase_plants_ts';
  static const String _issuesCacheKey = 'diagnose_showcase_issues';
  static const String _issuesCacheTsKey = 'diagnose_showcase_issues_ts';

  static const List<_PlantShowcaseSeed> _plantSeeds = <_PlantShowcaseSeed>[
    _PlantShowcaseSeed(
      query: 'Monstera',
      focusLabel: 'Indoor match',
      note: 'Compare yellow edges, tears, and broad-leaf discoloration.',
      preferredTerms: <String>['monstera', 'deliciosa', 'swiss cheese'],
    ),
    _PlantShowcaseSeed(
      query: 'Solanum lycopersicum',
      focusLabel: 'Crop match',
      note: 'Useful for spotting curl, blight, and lower-leaf stress early.',
      preferredTerms: <String>['tomato', 'solanum lycopersicum'],
    ),
    _PlantShowcaseSeed(
      query: 'Rose',
      focusLabel: 'Flowering match',
      note: 'Check mildew, black spots, and pest damage on delicate foliage.',
      preferredTerms: <String>['rose', 'rosa'],
    ),
    _PlantShowcaseSeed(
      query: 'Pepper',
      focusLabel: 'Garden match',
      note: 'Great reference for holes, silvering, and heat-stress symptoms.',
      preferredTerms: <String>['pepper', 'capsicum'],
    ),
  ];

  static const List<_IssueShowcaseSeed> _issueSeeds = <_IssueShowcaseSeed>[
    _IssueShowcaseSeed(
      query: 'powdery mildew',
      badge: 'Fungal',
      note: 'White, dusty growth that spreads across the leaf surface.',
      aliases: <String>['mildew', 'powdery'],
    ),
    _IssueShowcaseSeed(
      query: 'leaf spot',
      badge: 'Leaf damage',
      note: 'Dark lesions, yellow halos, and fast-spreading spotting.',
      aliases: <String>['spot', 'leaf spot'],
    ),
    _IssueShowcaseSeed(
      query: 'aphids',
      badge: 'Pests',
      note: 'Sap-sucking insects that curl new growth and weaken stems.',
      aliases: <String>['aphid', 'insect'],
    ),
    _IssueShowcaseSeed(
      query: 'blight',
      badge: 'Urgent',
      note: 'Rapid browning and collapse that can move through a plant fast.',
      aliases: <String>['blight', 'fungi'],
    ),
  ];

  final PerenualApi _perenualApi = PerenualApi();

  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;

  List<_DiagnosePlantCard> _plantCards = <_DiagnosePlantCard>[];
  List<_DiagnoseIssueCard> _issueCards = <_DiagnoseIssueCard>[];
  bool _isLoadingShowcase = false;
  String? _showcaseError;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 320),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _animationController.forward();

    unawaited(_loadCachedShowcase(allowStale: true));
    unawaited(_loadShowcase());
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _openCamera() {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'Camera'),
        builder: (_) => const CameraScreen(),
      ),
    );
  }

  Future<void> _loadCachedShowcase({required bool allowStale}) async {
    final prefs = await SharedPreferences.getInstance();
    final cachedPlants = _readCachedPlantCards(
      prefs: prefs,
      cacheKey: _plantsCacheKey,
      cacheTsKey: _plantsCacheTsKey,
      allowStale: allowStale,
    );
    final cachedIssues = _readCachedIssueCards(
      prefs: prefs,
      cacheKey: _issuesCacheKey,
      cacheTsKey: _issuesCacheTsKey,
      allowStale: allowStale,
    );

    if (!mounted) {
      return;
    }

    if (cachedPlants != null || cachedIssues != null) {
      setState(() {
        if (cachedPlants != null) {
          _plantCards = cachedPlants;
        }
        if (cachedIssues != null) {
          _issueCards = cachedIssues;
        }
      });
      unawaited(_warmImageCache());
    }
  }

  List<_DiagnosePlantCard>? _readCachedPlantCards({
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
    if (!allowStale && age > _showcaseCacheTtl) {
      return null;
    }

    final decoded = jsonDecode(cachedBody) as List<dynamic>;
    final cards = decoded
        .cast<Map<String, dynamic>>()
        .map(_DiagnosePlantCard.fromCacheMap)
        .toList();
    final validQueries = _plantSeeds.map((seed) => seed.query).toSet();
    if (cards.any((item) => !validQueries.contains(item.query))) {
      return null;
    }
    return cards;
  }

  List<_DiagnoseIssueCard>? _readCachedIssueCards({
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
    if (!allowStale && age > _showcaseCacheTtl) {
      return null;
    }

    final decoded = jsonDecode(cachedBody) as List<dynamic>;
    return decoded
        .cast<Map<String, dynamic>>()
        .map(_DiagnoseIssueCard.fromCacheMap)
        .toList();
  }

  Future<void> _saveShowcase({
    required List<_DiagnosePlantCard> plants,
    required List<_DiagnoseIssueCard> issues,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _plantsCacheKey,
      jsonEncode(plants.map((item) => item.toCacheMap()).toList()),
    );
    await prefs.setInt(
      _plantsCacheTsKey,
      DateTime.now().millisecondsSinceEpoch,
    );
    await prefs.setString(
      _issuesCacheKey,
      jsonEncode(issues.map((item) => item.toCacheMap()).toList()),
    );
    await prefs.setInt(
      _issuesCacheTsKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> _loadShowcase({bool forceRefresh = false}) async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoadingShowcase = true;
      if (forceRefresh) {
        _showcaseError = null;
      }
    });

    try {
      final plantCards = await _fetchPlantCards();
      final issueCards = await _fetchIssueCards();

      if (!mounted) {
        return;
      }

      setState(() {
        _plantCards = plantCards;
        _issueCards = issueCards;
        _showcaseError = null;
      });

      await _saveShowcase(plants: plantCards, issues: issueCards);
      unawaited(_warmImageCache());
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _showcaseError = _describeShowcaseError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingShowcase = false;
        });
      }
    }
  }

  Future<List<_DiagnosePlantCard>> _fetchPlantCards() async {
    final cards = <_DiagnosePlantCard>[];

    for (final seed in _plantSeeds) {
      final results = await _perenualApi.searchSpecies(query: seed.query, page: 1);
      final match = _bestPlantMatch(seed, results);
      final imageUrl = match?.imageUrl ?? match?.thumbnailUrl;
      if (match == null || !_hasUsableImageUrl(imageUrl)) {
        continue;
      }

      cards.add(
        _DiagnosePlantCard(
          query: seed.query,
          focusLabel: seed.focusLabel,
          note: seed.note,
          species: match,
        ),
      );
    }

    return cards;
  }

  Future<List<_DiagnoseIssueCard>> _fetchIssueCards() async {
    final cards = <_DiagnoseIssueCard>[];

    for (final seed in _issueSeeds) {
      final results = await _perenualApi.searchDiseases(query: seed.query, page: 1);
      final match = _bestIssueMatch(seed, results);
      if (match == null || !_hasUsableImageUrl(match.thumbnailUrl)) {
        continue;
      }

      cards.add(
        _DiagnoseIssueCard(
          query: seed.query,
          badge: seed.badge,
          note: seed.note,
          disease: match,
        ),
      );
    }

    return cards;
  }

  PerenualSpeciesSummary? _bestPlantMatch(
    _PlantShowcaseSeed seed,
    List<PerenualSpeciesSummary> results,
  ) {
    PerenualSpeciesSummary? bestMatch;
    PerenualSpeciesSummary? fallbackWithImage;
    var bestScore = -1;
    final normalizedQuery = seed.query.toLowerCase();

    for (final species in results) {
      final haystack = '${species.commonName} ${species.scientificName}'.toLowerCase();
      final hasImage = _hasUsableImageUrl(species.imageUrl) ||
          _hasUsableImageUrl(species.thumbnailUrl);

      if (hasImage) {
        fallbackWithImage ??= species;
      }

      var score = 0;
      if (haystack.contains(normalizedQuery)) {
        score += 5;
      }
      for (final preferredTerm in seed.preferredTerms) {
        if (haystack.contains(preferredTerm.toLowerCase())) {
          score += 2;
        }
      }
      if (hasImage) {
        score += 3;
      }

      if (score > bestScore) {
        bestScore = score;
        bestMatch = species;
      }
    }

    return bestMatch ?? fallbackWithImage ?? (results.isEmpty ? null : results.first);
  }

  PerenualDiseaseSummary? _bestIssueMatch(
    _IssueShowcaseSeed seed,
    List<PerenualDiseaseSummary> results,
  ) {
    PerenualDiseaseSummary? bestMatch;
    PerenualDiseaseSummary? fallbackWithImage;
    var bestScore = -1;
    final normalizedQuery = seed.query.toLowerCase();

    for (final issue in results) {
      final haystack =
          '${issue.commonName} ${issue.scientificName} ${issue.otherNames.join(' ')}'
              .toLowerCase();
      final hasImage = _hasUsableImageUrl(issue.thumbnailUrl);

      if (hasImage) {
        fallbackWithImage ??= issue;
      }

      var score = 0;
      if (haystack.contains(normalizedQuery)) {
        score += 5;
      }
      for (final alias in seed.aliases) {
        if (haystack.contains(alias.toLowerCase())) {
          score += 2;
        }
      }
      if (hasImage) {
        score += 3;
      }

      if (score > bestScore) {
        bestScore = score;
        bestMatch = issue;
      }
    }

    return bestMatch ?? fallbackWithImage ?? (results.isEmpty ? null : results.first);
  }

  bool _hasUsableImageUrl(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return false;
    }

    return !normalized.toLowerCase().contains('upgrade_access.jpg');
  }

  String _describeShowcaseError(Object error) {
    if (error is StateError &&
        error.message.toString().contains('PLANT_QUERY_API_KEY')) {
      return 'Plant references are temporarily unavailable right now.';
    }
    if (error is HttpException) {
      return 'Could not refresh references right now. Pull to try again.';
    }
    return 'Could not load references right now. Pull to try again.';
  }

  Future<void> _warmImageCache() async {
    final urls = <String>{
      ..._plantCards
          .map((item) => item.imageUrl)
          .where((url) => _hasUsableImageUrl(url))
          .cast<String>(),
      ..._issueCards
          .map((item) => item.imageUrl)
          .where((url) => _hasUsableImageUrl(url))
          .cast<String>(),
    };

    if (urls.isEmpty) {
      return;
    }

    try {
      await Future.wait(
        urls.map(
          (url) => DiagnoseImageCacheManager.instance.downloadFile(
            url,
            key: url,
          ),
        ),
      );
    } catch (_) {
      // Keep the screen usable even if image prefetching fails.
    }
  }

  int? _safeToInt(double value) {
    if (!value.isFinite || value <= 0) {
      return null;
    }
    return value.round();
  }

  @override
  Widget build(BuildContext context) {
    final hasContent = _plantCards.isNotEmpty || _issueCards.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF4FBF5),
      appBar: AppHeader(
        title: 'Diagnose',
        rightActions: [
          IconButton(
            icon: const Icon(Icons.support_agent_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Support coming soon.')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  settings: const RouteSettings(name: 'Diagnose History'),
                  builder: (_) => const DiagnoseHistoryScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: RefreshIndicator(
          color: const Color(0xFF1D7A43),
          onRefresh: () => _loadShowcase(forceRefresh: true),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _buildHeroCard(),
              const SizedBox(height: 18),
              if (_showcaseError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildInfoBanner(
                    message: _showcaseError!,
                    tone: hasContent ? _BannerTone.warning : _BannerTone.error,
                  ),
                ),
              _buildSectionHeader(
                title: 'Matching Plants',
                subtitle:
                    'Real plant photos you can compare before running a scan.',
              ),
              const SizedBox(height: 12),
              if (_isLoadingShowcase && _plantCards.isEmpty)
                _buildHorizontalSkeleton()
              else if (_plantCards.isEmpty)
                _buildInfoBanner(
                  message:
                      'No plant references are ready yet. Pull to refresh and try again.',
                )
              else
                _buildPlantScroller(),
              const SizedBox(height: 24),
              _buildSectionHeader(
                title: 'Plants With Problems',
                subtitle:
                    'Common issue examples to help you compare spots, pests, and discoloration.',
              ),
              const SizedBox(height: 12),
              if (_isLoadingShowcase && _issueCards.isEmpty)
                _buildHorizontalSkeleton()
              else if (_issueCards.isEmpty)
                _buildInfoBanner(
                  message:
                      'No issue references are ready yet. Pull to refresh and try again.',
                )
              else
                _buildIssueScroller(),
              if (_isLoadingShowcase && hasContent) ...[
                const SizedBox(height: 18),
                const LinearProgressIndicator(
                  minHeight: 3,
                  color: Color(0xFF1D7A43),
                  backgroundColor: Color(0xFFDDEFE0),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard() {
    final heroIssue = _issueCards.isNotEmpty ? _issueCards.first : null;
    final heroImage = heroIssue?.imageUrl ??
        (_plantCards.isNotEmpty ? _plantCards.first.imageUrl : null);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: SizedBox(
              height: 232,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildCachedImage(
                    imageUrl: heroImage,
                    width: double.infinity,
                    height: 232,
                    borderRadius: BorderRadius.zero,
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.12),
                          Colors.black.withValues(alpha: 0.58),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.24),
                            ),
                          ),
                          child: Text(
                            'Visual reference library',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Compare leaves with visual references',
                          style: GoogleFonts.inter(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.15,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          heroIssue == null
                              ? 'Helpful examples appear here while you compare color, texture, and spotting.'
                              : '${heroIssue.disease.commonName} gives you a quick symptom reference while you compare your plant.',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.92),
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildMetricPill(
                      icon: Icons.local_florist_rounded,
                      label: '${_plantCards.length} plant matches',
                    ),
                    _buildMetricPill(
                      icon: Icons.bug_report_outlined,
                      label: '${_issueCards.length} issue cards',
                    ),
                    _buildMetricPill(
                      icon: Icons.save_alt_rounded,
                      label: 'Quick compare',
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _openCamera,
                    icon: const Icon(Icons.camera_alt_rounded, size: 20),
                    label: Text(
                      widget.initialImage == null
                          ? 'Auto Diagnose'
                          : 'Continue Diagnose',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1D7A43),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricPill({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F8F2),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD5E9D9)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF1D7A43)),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1F2F23),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF19231B),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF6C7D70),
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildPlantScroller() {
    final cardHeight = _showcaseCardHeight(context);
    return SizedBox(
      height: cardHeight + _showcaseCardShadowBuffer,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _plantCards.length,
        separatorBuilder: (context, index) => const SizedBox(width: 14),
        itemBuilder: (context, index) => _buildPlantCard(_plantCards[index]),
      ),
    );
  }

  Widget _buildIssueScroller() {
    final cardHeight = _showcaseCardHeight(context);
    return SizedBox(
      height: cardHeight + _showcaseCardShadowBuffer,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _issueCards.length,
        separatorBuilder: (context, index) => const SizedBox(width: 14),
        itemBuilder: (context, index) => _buildIssueCard(_issueCards[index]),
      ),
    );
  }

  Widget _buildPlantCard(_DiagnosePlantCard plant) {
    return SizedBox(
      width: 188,
      height: _showcaseCardHeight(context),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                _buildCachedImage(
                  imageUrl: plant.imageUrl,
                  width: 188,
                  height: 118,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(22),
                  ),
                ),
                Positioned(
                  left: 12,
                  top: 12,
                  child: _buildCardBadge(
                    plant.focusLabel,
                    background: const Color(0xCCFFFFFF),
                    foreground: const Color(0xFF1D7A43),
                  ),
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plant.species.commonName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF18211A),
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      plant.species.scientificName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF708171),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Text(
                          plant.note,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF526254),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIssueCard(_DiagnoseIssueCard issue) {
    return SizedBox(
      width: 194,
      height: _showcaseCardHeight(context),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                _buildCachedImage(
                  imageUrl: issue.imageUrl,
                  width: 194,
                  height: 116,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(22),
                  ),
                ),
                Positioned(
                  right: 12,
                  top: 12,
                  child: _buildCardBadge(
                    issue.badge,
                    background: const Color(0xFF1C2E22),
                    foreground: Colors.white,
                  ),
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      issue.disease.commonName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF18211A),
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      issue.disease.scientificName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF708171),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Text(
                          issue.note,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF526254),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _showcaseCardHeight(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final clampedTextScale = switch (textScale) {
      < 1.0 => 1.0,
      > 2.0 => 2.0,
      _ => textScale,
    };

    return _showcaseCardBaseHeight + (clampedTextScale - 1.0) * 72.0;
  }

  Widget _buildCardBadge(
    String label, {
    required Color background,
    required Color foreground,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }

  Widget _buildHorizontalSkeleton() {
    final cardHeight = _showcaseCardHeight(context);
    return SizedBox(
      height: cardHeight + _showcaseCardShadowBuffer,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        separatorBuilder: (context, index) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          return SizedBox(
            width: 188,
            height: cardHeight,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                children: [
                  Container(
                    height: 126,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE8F2E9),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(22),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 14,
                            width: 112,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F2E9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            height: 10,
                            width: 82,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F6F0),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            height: 10,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F6F0),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 10,
                            width: 130,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F6F0),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoBanner({
    required String message,
    _BannerTone tone = _BannerTone.neutral,
  }) {
    final Color background;
    final Color border;
    final Color textColor;
    final IconData icon;

    switch (tone) {
      case _BannerTone.warning:
        background = const Color(0xFFFFF7E8);
        border = const Color(0xFFF1D38E);
        textColor = const Color(0xFF6F5206);
        icon = Icons.info_outline_rounded;
      case _BannerTone.error:
        background = const Color(0xFFFFEFEF);
        border = const Color(0xFFF2C4C4);
        textColor = const Color(0xFF8F2E2E);
        icon = Icons.error_outline_rounded;
      case _BannerTone.neutral:
        background = Colors.white;
        border = const Color(0xFFDCE9DD);
        textColor = const Color(0xFF4E6152);
        icon = Icons.cloud_done_outlined;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: textColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textColor,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCachedImage({
    required String? imageUrl,
    required double width,
    required double height,
    required BorderRadius borderRadius,
  }) {
    if (!_hasUsableImageUrl(imageUrl)) {
      return _imagePlaceholder(
        width: width,
        height: height,
        borderRadius: borderRadius,
      );
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: CachedNetworkImage(
        imageUrl: imageUrl!.trim(),
        width: width,
        height: height,
        fit: BoxFit.cover,
        cacheManager: DiagnoseImageCacheManager.instance,
        cacheKey: imageUrl.trim(),
        memCacheWidth: width.isFinite ? _safeToInt(width * 2) : null,
        memCacheHeight: height.isFinite ? _safeToInt(height * 2) : null,
        placeholder: (context, url) => _imagePlaceholder(
          width: width,
          height: height,
          borderRadius: borderRadius,
        ),
        errorWidget: (context, url, error) => _imagePlaceholder(
          width: width,
          height: height,
          borderRadius: borderRadius,
        ),
      ),
    );
  }

  Widget _imagePlaceholder({
    required double width,
    required double height,
    required BorderRadius borderRadius,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFE8F4E9),
            Color(0xFFD8EAD9),
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.local_florist_rounded,
          size: 34,
          color: Color(0xFF2B7B45),
        ),
      ),
    );
  }
}

class _PlantShowcaseSeed {
  const _PlantShowcaseSeed({
    required this.query,
    required this.focusLabel,
    required this.note,
    this.preferredTerms = const <String>[],
  });

  final String query;
  final String focusLabel;
  final String note;
  final List<String> preferredTerms;
}

class _IssueShowcaseSeed {
  const _IssueShowcaseSeed({
    required this.query,
    required this.badge,
    required this.note,
    this.aliases = const <String>[],
  });

  final String query;
  final String badge;
  final String note;
  final List<String> aliases;
}

class _DiagnosePlantCard {
  const _DiagnosePlantCard({
    required this.query,
    required this.focusLabel,
    required this.note,
    required this.species,
  });

  factory _DiagnosePlantCard.fromCacheMap(Map<String, dynamic> map) {
    return _DiagnosePlantCard(
      query: map['query'] as String? ?? '',
      focusLabel: map['focusLabel'] as String? ?? '',
      note: map['note'] as String? ?? '',
      species: PerenualSpeciesSummary.fromCacheMap(
        (map['species'] as Map<String, dynamic>? ?? <String, dynamic>{}),
      ),
    );
  }

  final String query;
  final String focusLabel;
  final String note;
  final PerenualSpeciesSummary species;

  String? get imageUrl => species.imageUrl ?? species.thumbnailUrl;

  Map<String, dynamic> toCacheMap() {
    return <String, dynamic>{
      'query': query,
      'focusLabel': focusLabel,
      'note': note,
      'species': species.toCacheMap(),
    };
  }
}

class _DiagnoseIssueCard {
  const _DiagnoseIssueCard({
    required this.query,
    required this.badge,
    required this.note,
    required this.disease,
  });

  factory _DiagnoseIssueCard.fromCacheMap(Map<String, dynamic> map) {
    return _DiagnoseIssueCard(
      query: map['query'] as String? ?? '',
      badge: map['badge'] as String? ?? '',
      note: map['note'] as String? ?? '',
      disease: PerenualDiseaseSummary.fromCacheMap(
        (map['disease'] as Map<String, dynamic>? ?? <String, dynamic>{}),
      ),
    );
  }

  final String query;
  final String badge;
  final String note;
  final PerenualDiseaseSummary disease;

  String? get imageUrl => disease.thumbnailUrl;

  Map<String, dynamic> toCacheMap() {
    return <String, dynamic>{
      'query': query,
      'badge': badge,
      'note': note,
      'disease': disease.toCacheMap(),
    };
  }
}

enum _BannerTone {
  neutral,
  warning,
  error,
}
