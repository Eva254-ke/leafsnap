import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/perenual_api.dart';
import '../home/plant_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const String _recentSearchesKey = 'plant_finder_recent_searches';

  // Reliable fallback images - all verified working URLs (Unsplash)
  static const Map<String, String> _fallbackImages = {
    'Tomato': 'https://images.unsplash.com/photo-1592924357228-91a4daadcfea?w=400&h=400&fit=crop',
    'Snake Plant': 'https://images.unsplash.com/photo-1599598425947-320d7f8c6b84?w=400&h=400&fit=crop',
    'Monstera': 'https://images.unsplash.com/photo-1614594975525-e45190c55d0b?w=400&h=400&fit=crop',
    'Spinach': 'https://images.unsplash.com/photo-1576045057995-568f588f82fb?w=400&h=400&fit=crop',
    'Lavender': 'https://images.unsplash.com/photo-1498522744425-5a8940e62e9f?w=400&h=400&fit=crop',
    'Cucumber': 'https://images.unsplash.com/photo-1449300079323-02e209d9d3a6?w=400&h=400&fit=crop',
    'Rose': 'https://images.unsplash.com/photo-1490750967868-58cb75069ed6?w=400&h=400&fit=crop',
    'Basil': 'https://images.unsplash.com/photo-1615485925694-a035a9e6c6c9?w=400&h=400&fit=crop',
    'Cactus': 'https://images.unsplash.com/photo-1459156212016-c812468e2115?w=400&h=400&fit=crop',
    'Orchid': 'https://images.unsplash.com/photo-1563240670-a7c7fac1b826?w=400&h=400&fit=crop',
  };

  final PerenualApi _perenualApi = PerenualApi();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  Timer? _searchDebounce;
  int _searchRequestId = 0;

  List<String> _recentSearches = <String>[];
  List<PerenualSpeciesSummary> _results = <PerenualSpeciesSummary>[];

  bool _isLoading = false;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery?.trim() ?? '';
    _searchController.text = _query;
    _loadRecentSearches();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });

    if (_query.length >= 2) {
      _searchPlants(_query);
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_recentSearchesKey) ?? <String>[];

    if (!mounted) return;
    setState(() {
      _recentSearches = stored;
    });
  }

  Future<void> _saveRecentSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return;

    final updated = <String>[
      trimmed,
      ..._recentSearches.where(
        (item) => item.toLowerCase() != trimmed.toLowerCase(),
      ),
    ].take(8).toList();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_recentSearchesKey, updated);

    if (!mounted) return;
    setState(() {
      _recentSearches = updated;
    });
  }

  Future<void> _clearRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recentSearchesKey);

    if (!mounted) return;
    setState(() {
      _recentSearches = <String>[];
    });
  }

  void _onQueryChanged(String value) {
    _searchDebounce?.cancel();

    final trimmed = value.trim();
    setState(() {
      _query = trimmed;
      _error = null;
    });

    if (trimmed.length < 2) {
      setState(() {
        _results = <PerenualSpeciesSummary>[];
        _isLoading = false;
      });
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _searchPlants(trimmed);
    });
  }

  void _selectQuery(String query) {
    _searchController.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
    _onQueryChanged(query);
    _searchFocusNode.requestFocus();
  }

  Future<void> _submitQuery(String value) async {
    final trimmed = value.trim();
    if (trimmed.length < 2) return;

    _searchDebounce?.cancel();
    await _saveRecentSearch(trimmed);
    await _searchPlants(trimmed);
  }

  Future<void> _searchPlants(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return;

    final requestId = ++_searchRequestId;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await _perenualApi.searchSpecies(query: trimmed, page: 1);
      if (!mounted || requestId != _searchRequestId) return;

      setState(() {
        _results = _sortedResults(trimmed, results);
      });
    } catch (error) {
      if (!mounted || requestId != _searchRequestId) return;

      setState(() {
        _error = error.toString();
        _results = <PerenualSpeciesSummary>[];
      });
    } finally {
      if (mounted && requestId == _searchRequestId) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<PerenualSpeciesSummary> _sortedResults(
    String query,
    List<PerenualSpeciesSummary> results,
  ) {
    final normalizedQuery = query.toLowerCase();
    final sorted = List<PerenualSpeciesSummary>.from(results);

    sorted.sort((a, b) {
      final aScore = _scoreSpecies(a, normalizedQuery);
      final bScore = _scoreSpecies(b, normalizedQuery);
      return bScore.compareTo(aScore);
    });

    return sorted.take(20).toList();
  }

  int _scoreSpecies(PerenualSpeciesSummary species, String normalizedQuery) {
    final commonName = species.commonName.toLowerCase();
    final scientificName = species.scientificName.toLowerCase();

    var score = 0;
    if (commonName == normalizedQuery) score += 12;
    if (commonName.startsWith(normalizedQuery)) score += 8;
    if (commonName.contains(normalizedQuery)) score += 5;
    if (scientificName.startsWith(normalizedQuery)) score += 4;
    if (scientificName.contains(normalizedQuery)) score += 2;
    if (_resolvedImageUrl(species) != null) score += 1;
    return score;
  }

  bool _isUsableImageUrl(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return false;
    }

    return !normalized.toLowerCase().contains('upgrade_access.jpg');
  }

  String? _resolvedImageUrl(PerenualSpeciesSummary plant) {
    final candidates = <String?>[plant.imageUrl, plant.thumbnailUrl];

    for (final candidate in candidates) {
      if (_isUsableImageUrl(candidate)) {
        return candidate!.trim();
      }
    }

    return null;
  }

  String _getReliableImageUrl(PerenualSpeciesSummary plant) {
    final apiUrl = _resolvedImageUrl(plant);
    if (apiUrl != null) return apiUrl;
    
    // Try fallback map
    final normalizedName = plant.commonName.trim().toLowerCase();
    for (final entry in _fallbackImages.entries) {
      if (entry.key.toLowerCase() == normalizedName) {
        return entry.value;
      }
    }
    
    // Generic fallback
    return 'https://images.unsplash.com/photo-1443890923422-7819ed4101c0?w=400&h=400&fit=crop';
  }

  Future<void> _openPlantDetails(PerenualSpeciesSummary plant) async {
    await _saveRecentSearch(plant.commonName);
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: 'Plant Detail'),
        builder: (context) => PlantDetailScreen(
          plantName: plant.commonName,
          imageUrl: _getReliableImageUrl(plant),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4FBF6),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _query.isEmpty
                  ? _buildDiscoveryView()
                  : _buildSearchStateView(),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFFF4FBF6),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        onPressed: () => Navigator.of(context).maybePop(),
        tooltip: 'Back',
        icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF15321E)),
      ),
      titleSpacing: 0,
      title: Padding(
        padding: const EdgeInsets.only(right: 16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
          ),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            onChanged: _onQueryChanged,
            onSubmitted: _submitQuery,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search plants',
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: Color(0xFF22A45D),
                size: 20,
              ),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () => _selectQuery(''),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Color(0xFF7A7A7A),
                        size: 20,
                      ),
                    ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1B1B1B),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDiscoveryView() {
    return ListView(
      key: const ValueKey<String>('discovery'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _buildRecentSearchesSection(),
      ],
    );
  }

  Widget _buildSearchStateView() {
    if (_query.length < 2) {
      return ListView(
        key: const ValueKey<String>('too-short'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _infoCard(
            title: 'Keep typing',
            subtitle: 'Use at least 2 letters to search the plant database.',
          ),
        ],
      );
    }

    if (_isLoading) {
      return ListView(
        key: const ValueKey<String>('loading'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: const [
          SizedBox(height: 32),
          Center(child: CircularProgressIndicator(color: Color(0xFF22A45D))),
        ],
      );
    }

    if (_error != null) {
      return ListView(
        key: const ValueKey<String>('error'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _infoCard(
            title: 'Search unavailable',
            subtitle: _error!,
          ),
        ],
      );
    }

    if (_results.isEmpty) {
      return ListView(
        key: const ValueKey<String>('empty'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _infoCard(
            title: 'No matches yet',
            subtitle: 'Try another name or use a broader search term for "$_query".',
          ),
        ],
      );
    }

    return ListView.separated(
      key: ValueKey<String>('results-$_query'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _results.length + 1,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _resultsHeader();
        }

        final plant = _results[index - 1];
        return _buildResultCard(plant);
      },
    );
  }

  Widget _resultsHeader() {
    return Row(
      children: [
        Expanded(
          child: Text(
            '${_results.length} matches for "$_query"',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1F2937),
            ),
          ),
        ),
        Text(
          'Tap to open care guide',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: const Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentSearchesSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Recent searches',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1B1B1B),
                ),
              ),
              const Spacer(),
              if (_recentSearches.isNotEmpty)
                TextButton(
                  onPressed: _clearRecentSearches,
                  child: Text(
                    'Clear',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF22A45D),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_recentSearches.isEmpty)
            Text(
              'Your recent plant lookups will show up here.',
              style: GoogleFonts.inter(
                fontSize: 13,
                height: 1.5,
                color: const Color(0xFF6B7280),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _recentSearches
                  .map(
                    (query) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF7EF),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFD4E8DB), width: 1),
                      ),
                      child: InkWell(
                        onTap: () => _selectQuery(query),
                        borderRadius: BorderRadius.circular(16),
                        child: Text(
                          query,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF21543A),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildResultCard(PerenualSpeciesSummary plant) {
    final imageUrl = _getReliableImageUrl(plant);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openPlantDetails(plant),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  width: 76,
                  height: 76,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => _resultPlaceholder(),
                  errorWidget: (context, url, error) => _resultPlaceholder(),
                  memCacheWidth: 152,
                  cacheKey: imageUrl,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF7EF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFD4E8DB), width: 1),
                      ),
                      child: Text(
                        'Plant care guide',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1D7A46),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      plant.commonName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1B1B1B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      plant.scientificName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Color(0xFF95A19A),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resultPlaceholder() {
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        color: const Color(0xFFE4F6E9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD4E8DB), width: 1),
      ),
      child: const Icon(
        Icons.eco_rounded,
        color: Color(0xFF1E7A46),
        size: 30,
      ),
    );
  }

  Widget _infoCard({
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1B1B1B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.5,
              color: const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}