import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../../../components/remote_config_ui.dart';
import '../../../services/ambee_soil_api.dart';
import '../../../services/api_error.dart';
import '../../../services/perenual_api.dart';
import '../../../services/plantnet_api.dart';
import '../../../services/plant_store.dart';
import 'camera_screen.dart';
import 'camera_tools.dart';

class PlantResultScreen extends StatefulWidget {
  final File imageFile;
  final String scientificName;
  final double score;
  final String? errorMessage;
  final List<PlantNetPlantMatch> plantNetMatches;
  final CameraToolDefinition selectedTool;

  const PlantResultScreen({
    super.key,
    required this.imageFile,
    required this.scientificName,
    required this.score,
    required this.selectedTool,
    this.errorMessage,
    this.plantNetMatches = const <PlantNetPlantMatch>[],
  });

  @override
  State<PlantResultScreen> createState() => _PlantResultScreenState();
}

class _PlantResultScreenState extends State<PlantResultScreen> with SingleTickerProviderStateMixin {
  // Centralized Color Palette
  static const _primary = Color(0xFF00A86B);
  static const _primaryLight = Color(0xFFE5F8F0);
  static const _background = Color(0xFFF4F7F5);
  static const _surface = Colors.white;
  static const _textPrimary = Color(0xFF242927);
  static const _textSecondary = Color(0xFF747977);
  static const _textTertiary = Color(0xFF9B9F9D);
  static const _error = Color(0xFFE95555);
  static const _errorLight = Color(0xFFFFF7F4);
  static const _border = Color(0xFFE1E7E4);

  static const _problemThreshold = 0.12;
  final FlutterTts _tts = FlutterTts();
  late TabController _tabController;

  static const Map<String, List<String>> _localNames = {
    'solanum lycopersicum': ['Nyanya', 'Tomato'],
    'zea mays': ['Mahindi', 'Maize'],
    'phaseolus vulgaris': ['Maharagwe', 'Beans'],
    'allium cepa': ['Kitunguu', 'Onion'],
    'brassica oleracea': ['Kabichi', 'Cabbage'],
    'spinacia oleracea': ['Spinachi', 'Spinach'],
    'capsicum annuum': ['Pilipili hoho', 'Pepper'],
    'musa acuminata': ['Ndizi', 'Banana'],
    'manihot esculenta': ['Muhogo', 'Cassava'],
    'solanum tuberosum': ['Viazi', 'Potato'],
    'monstera deliciosa': ['Swiss cheese plant', 'Monstera'],
  };

  final PerenualApi _perenualApi = PerenualApi();
  final PlantNetApi _plantNetApi = PlantNetApi();
  final AmbeeSoilApi _soilApi = AmbeeSoilApi();

  bool _isLoadingPlantInfo = false;
  bool _isLoadingIssues = false;
  String? _plantInfoError;
  String? _issuesError; // FIX #1: Added missing variable
  PerenualSpeciesSummary? _match;
  Map<String, dynamic>? _details;
  List<PerenualCareSection> _careSections = [];
  List<PlantNetDiseaseMatch> _diseaseMatches = [];
  AmbeeSoilSnapshot? _soilSnapshot;
  bool _isLoadingSoil = false;
  String? _soilError;

  bool _toxicityExpanded = true;
  bool _petsExpanded = true;
  bool _weedExpanded = true;
  bool _distributionExpanded = true;
  bool? _feedbackHelpful;
  bool _isSavingToGarden = false;
  bool _savedToGarden = false;
  int _heroImagePage = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    if (widget.errorMessage == null) {
      _loadData();
    }
  }

  @override
  void dispose() {
    _tts.stop();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoadingPlantInfo = true;
      _isLoadingIssues = true;
      _plantInfoError = null;
      _issuesError = null;
    });

    try {
      final results = await _perenualApi
          .searchSpecies(query: widget.scientificName, page: 1)
          .timeout(const Duration(seconds: 8));

      if (results.isEmpty) {
        if (!mounted) return;
        setState(() {
          _plantInfoError = 'No reference details found for ${widget.scientificName}.';
        });
        return;
      }

      final match = results.first;
      
      final detailsFuture = _perenualApi
          .getSpeciesDetails(match.id)
          .timeout(
            const Duration(seconds: 6), 
            onTimeout: () => Future<Map<String, dynamic>>.value(_detailsFromSummary(match)),
          );
      
      final careFuture = _perenualApi
          .getCareGuides(speciesId: match.id, types: const ['sunlight', 'watering', 'fertilizing'])
          .timeout(
            const Duration(seconds: 6), 
            onTimeout: () => Future<List<PerenualCareSection>>.value(const []),
          );

      final issuesFuture = _shouldRunIssueScan
          ? _plantNetApi
              .identifyDiseases(images: [widget.imageFile], organs: const ['auto'], language: 'en')
              .timeout(const Duration(seconds: 12))
          : Future<Map<String, dynamic>?>.value(null);

      final resultsTuple = await Future.wait([
        detailsFuture, 
        careFuture, 
        issuesFuture,
      ]);
      
      final details = resultsTuple[0] as Map<String, dynamic>;
      final care = resultsTuple[1] as List<PerenualCareSection>;
      final issuesResponse = resultsTuple[2] as Map<String, dynamic>?;

      List<PlantNetDiseaseMatch> issues = [];
      if (issuesResponse != null) {
        issues = _plantNetApi
            .parseDiseaseMatches(issuesResponse)
            .where((m) => _isCredibleProblem(m))
            .take(3)
            .toList();
      }

      if (!mounted) return;
      setState(() {
        _match = match;
        _details = details;
        _careSections = care;
        _diseaseMatches = issues;
      });
    } catch (error) {
      if (!mounted) return;
      final isRateLimit = isRateLimitError(error);
      setState(() {
        _plantInfoError = isRateLimit
            ? 'Plant care details are busy. Please try again later.'
            : 'Reference details are unavailable.';
        _issuesError = isRateLimit
            ? 'Issue detection is busy. Please try again later.'
            : 'Issue scan is unavailable.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPlantInfo = false;
          _isLoadingIssues = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // FIX #2: Simplified null-aware chaining
    final referenceImageUrl =
        _match?.imageUrl ?? _firstPlantNetImage(widget.plantNetMatches);

    final displayName = _displayName;
    final scientificName = _scientificName;
    final confidence = (widget.score * 100).clamp(0, 100).toStringAsFixed(1);
    final bestProblem = _bestProblem;
    final isSick = bestProblem != null;
    final galleryImages = _heroGalleryImages(referenceImageUrl, bestProblem);

    return RemoteConfigBuilder(
      screenId: RemoteConfigScreens.plantResult,
      fallbackBackgroundColor: _background,
      fallbackPrimaryColor: _primary,
      builder: (context, remoteConfig) {
        return Scaffold(
          backgroundColor: remoteConfig.backgroundColor ?? _background,
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverToBoxAdapter(
                child: _buildHero(
                  displayName: displayName,
                  scientificName: scientificName,
                  confidence: confidence,
                  galleryImages: galleryImages,
                ),
              ),
              SliverPersistentHeader(
                delegate: _SliverAppBarDelegate(
                  minHeight: 56,
                  maxHeight: 56,
                  child: Container(
                    color: _surface,
                    child: TabBar(
                      controller: _tabController,
                      labelColor: _primary,
                      unselectedLabelColor: _textSecondary,
                      indicatorColor: _primary,
                      indicatorWeight: 3,
                      labelStyle: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                      tabs: const [
                        Tab(text: 'Overview'),
                        Tab(text: 'Care'),
                        Tab(text: 'Soil'),
                        Tab(text: 'Explore'),
                      ],
                    ),
                  ),
                ),
                pinned: true,
              ),
            ],
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(isSick: isSick, bestProblem: bestProblem),
                _buildCareTab(),
                _buildSoilTab(),
                _buildExploreTab(
                  displayName,
                  scientificName,
                  referenceImageUrl: referenceImageUrl,
                ),
              ],
            ),
          ),
          bottomNavigationBar: _buildBottomBar(),
        );
      },
    );
  }

  Widget _buildHero({
    required String displayName,
    required String scientificName,
    required String confidence,
    required List<_ResultGalleryImage> galleryImages,
  }) {
    final imageCount = galleryImages.length;
    final currentPage = imageCount == 0
        ? 0
        : _heroImagePage.clamp(0, imageCount - 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 340,
          child: Stack(
            children: [
              PageView.builder(
                itemCount: imageCount,
                onPageChanged: (index) => setState(() => _heroImagePage = index),
                itemBuilder: (context, index) {
                  final image = galleryImages[index];
                  return _buildHeroGalleryImage(image);
                },
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.20),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        _circleIcon(Icons.arrow_back_ios_new_rounded, () => Navigator.pop(context)),
                        const Spacer(),
                        _circleIcon(Icons.camera_alt_outlined, _openNewScan),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 16,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    galleryImages[currentPage].label,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.photo_library, color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${currentPage + 1}/$imageCount',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (imageCount > 1)
                Positioned(
                  bottom: 20,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      imageCount,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: index == currentPage ? 18 : 7,
                        height: 7,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: index == currentPage
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.52),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          decoration: const BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // FIX #3: English name in BOLD, scientific name below in italic
              Text(
                displayName,
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    scientificName,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w600,
                      color: _textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _pronounceButton(scientificName),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Also known as: $_alsoKnownAsText',
                style: GoogleFonts.inter(
                  color: _textSecondary,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$confidence% confidence',
                  style: GoogleFonts.inter(
                    color: _primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeroGalleryImage(_ResultGalleryImage image) {
    if (image.file != null) {
      return Image.file(
        image.file!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }

    final url = image.url;
    if (url == null || url.trim().isEmpty) {
      return Image.file(
        widget.imageFile,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }

    return Image.network(
      url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }
        return Container(
          color: _primaryLight,
          child: const Center(
            child: CircularProgressIndicator(color: _primary),
          ),
        );
      },
      errorBuilder: (_, __, ___) => Image.file(
        widget.imageFile,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      ),
    );
  }

  Widget _buildOverviewTab({required bool isSick, required PlantNetDiseaseMatch? bestProblem}) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      children: [
        if (_isLoadingIssues)
          _loadingCard()
        else if (widget.errorMessage != null)
          _errorCard(widget.errorMessage!)
        else if (isSick && bestProblem != null)
          _sickPlantCard(bestProblem)
        else if (_issuesError != null) // FIX #1: Now this variable exists
          _errorCard(_issuesError!)
        else if (!_shouldRunIssueScan || _diseaseMatches.isEmpty)
          _healthyCard(),
        const SizedBox(height: 20),
        _sectionTitle('Basic Info'),
        _basicInfoCard(),
      ],
    );
  }

  Widget _sickPlantCard(PlantNetDiseaseMatch problem) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _errorLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _error.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: _error,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This plant looks Sick!',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _error,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${problem.description} (${(problem.score * 100).toStringAsFixed(0)}% match)',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: _textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (problem.images.isNotEmpty) ...[
            Text(
              'Health reference photos',
              style: GoogleFonts.inter(
                color: _textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 86,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: problem.images.length > 4 ? 4 : problem.images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final imageUrl = problem.images[index].bestUrl;
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: imageUrl == null || imageUrl.isEmpty
                        ? Image.file(
                            widget.imageFile,
                            width: 92,
                            height: 86,
                            fit: BoxFit.cover,
                          )
                        : Image.network(
                            imageUrl,
                            width: 92,
                            height: 86,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Image.file(
                              widget.imageFile,
                              width: 92,
                              height: 86,
                              fit: BoxFit.cover,
                            ),
                          ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _tabController.animateTo(1),
              style: ElevatedButton.styleFrom(
                backgroundColor: _error,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'View Treatment',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _healthyCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _primaryLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: _primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Plant looks healthy! No issues detected.',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _conditionPhotosCard(PlantNetDiseaseMatch? bestProblem) {
    final plantImages = widget.plantNetMatches
        .expand((match) => match.images)
        .map((image) => image.bestUrl)
        .whereType<String>()
        .where((url) => url.trim().isNotEmpty)
        .toSet()
        .take(5)
        .toList();
    final issueImages = (bestProblem?.images ?? const <PlantNetImageReference>[])
        .map((image) => image.bestUrl)
        .whereType<String>()
        .where((url) => url.trim().isNotEmpty)
        .toSet()
        .take(5)
        .toList();

    final items = <_ConditionPhoto>[
      _ConditionPhoto.file(widget.imageFile, 'Your scan'),
      for (final url in plantImages) _ConditionPhoto.network(url, 'Healthy reference'),
      for (final url in issueImages) _ConditionPhoto.network(url, 'Issue reference'),
    ];

    if (items.length <= 1) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Plant condition photos',
            style: GoogleFonts.inter(
              color: _textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            bestProblem == null
                ? 'Compare your scan with healthy reference images.'
                : 'Compare your scan with healthy and issue reference images.',
            style: GoogleFonts.inter(
              color: _textSecondary,
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 118,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final item = items[index];
                return InkWell(
                  onTap: () => _showConditionPhotoDetail(item),
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 112,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: _conditionPhotoImage(
                                item,
                                width: 112,
                                height: 86,
                              ),
                            ),
                            Positioned(
                              right: 6,
                              top: 6,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.52),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: const Icon(
                                  Icons.open_in_full_rounded,
                                  color: Colors.white,
                                  size: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: _textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _conditionPhotoImage(
    _ConditionPhoto item, {
    required double width,
    required double height,
    BoxFit fit = BoxFit.cover,
  }) {
    final file = item.file;
    if (file != null) {
      return Image.file(
        file,
        width: width,
        height: height,
        fit: fit,
      );
    }

    return Image.network(
      item.url!,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, __, ___) => Image.file(
        widget.imageFile,
        width: width,
        height: height,
        fit: fit,
      ),
    );
  }

  void _showConditionPhotoDetail(_ConditionPhoto item) {
    final isScan = item.file != null;
    final isIssue = item.label.toLowerCase().contains('issue');
    final detail = isScan
        ? 'This is the exact photo used for identification. Compare the focused area against the reference photos.'
        : isIssue
            ? 'Reference image for a possible health issue. Compare leaf spots, discoloration, wilting, or damage patterns.'
            : 'Healthy reference image for $_displayName. Compare color, leaf shape, texture, and growth pattern.';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _border,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    aspectRatio: 1.15,
                    child: _conditionPhotoImage(
                      item,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isIssue
                            ? _errorLight
                            : isScan
                                ? _background
                                : _primaryLight,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        item.label,
                        style: GoogleFonts.inter(
                          color: isIssue
                              ? _error
                              : isScan
                                  ? _textPrimary
                                  : _primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _displayName,
                  style: GoogleFonts.inter(
                    color: _textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _scientificName,
                  style: GoogleFonts.inter(
                    color: _textSecondary,
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  detail,
                  style: GoogleFonts.inter(
                    color: _textSecondary,
                    fontSize: 14,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCareTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      children: [
        if (_isLoadingPlantInfo)
          _loadingCard()
        else ...[
          _careMetricCard(
            icon: Icons.water_drop,
            title: 'Watering',
            value: _details?['watering'] as String? ?? 'Water when top soil is dry',
            body: _firstCareSection('watering'),
          ),
          const SizedBox(height: 12),
          _careMetricCard(
            icon: Icons.wb_sunny,
            title: 'Sunlight',
            value: _getSunlightValue(),
            body: _firstCareSection('sunlight'),
          ),
          const SizedBox(height: 12),
          _careMetricCard(
            icon: Icons.science_outlined,
            title: 'Fertilizer',
            value: _details?['care_level'] as String? ?? 'Light feeding',
            body: _firstCareSection('fertilizing'),
          ),
        ],
        if (_plantInfoError != null) ...[
          const SizedBox(height: 12),
          _errorCard(_plantInfoError!),
        ],
      ],
    );
  }

  Widget _buildSoilTab() {
    final snapshot = _soilSnapshot;
    final moisturePercent = _soilMoisturePercent(snapshot);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: _primaryLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.landscape_rounded, color: _primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Soil Analyzer',
                      style: GoogleFonts.inter(
                        color: _textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                snapshot?.hasLiveSoilData == true
                    ? _soilAdvice(snapshot!)
                    : 'Check live soil moisture and temperature around this plant before watering or feeding.',
                style: GoogleFonts.inter(
                  color: _textSecondary,
                  fontSize: 14,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isLoadingSoil ? null : _loadSoilSnapshot,
                  icon: _isLoadingSoil
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.location_searching_rounded),
                  label: Text(_isLoadingSoil ? 'Checking soil...' : 'Analyze Local Soil'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_soilError != null) ...[
          const SizedBox(height: 12),
          _soilNoteCard(_soilError!),
        ],
        const SizedBox(height: 16),
        _sectionTitle(snapshot?.hasLiveSoilData == true
            ? 'Live Soil Reading'
            : 'Soil Care Guide'),
        if (snapshot?.hasLiveSoilData == true)
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.25,
            children: [
              _soilMetricTile(
                icon: Icons.water_drop_rounded,
                label: 'Moisture',
                value: moisturePercent == null
                    ? '--'
                    : '${moisturePercent.toStringAsFixed(0)}%',
              ),
              _soilMetricTile(
                icon: Icons.thermostat_rounded,
                label: 'Soil Temp',
                value: _formatTemperature(snapshot!.soilTemperatureC),
              ),
              _soilMetricTile(
                icon: Icons.wb_sunny_rounded,
                label: 'Surface',
                value: _formatTemperature(snapshot.surfaceTemperatureC),
              ),
              _soilMetricTile(
                icon: Icons.air_rounded,
                label: 'Humidity',
                value: _formatPercent(snapshot.humidity),
              ),
            ],
          )
        else
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.25,
            children: [
              _soilMetricTile(
                icon: Icons.water_drop_rounded,
                label: 'Moisture',
                value: 'Top soil',
              ),
              _soilMetricTile(
                icon: Icons.grain_rounded,
                label: 'Drainage',
                value: 'Light',
              ),
              _soilMetricTile(
                icon: Icons.thermostat_rounded,
                label: 'Root Zone',
                value: '18-29C',
              ),
              _soilMetricTile(
                icon: Icons.compost_rounded,
                label: 'Feeding',
                value: 'Gentle',
              ),
            ],
          ),
        if (snapshot?.hasLiveSoilData == true) ...[
          const SizedBox(height: 16),
          Text(
            'Source: ${snapshot!.source}',
            style: GoogleFonts.inter(
              color: _textTertiary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildExploreTab(
    String displayName,
    String scientificName, {
    required String? referenceImageUrl,
  }) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 360;
            final cards = [
              _shareCard(
                displayName,
                scientificName,
                imageUrl: referenceImageUrl,
                vertical: true,
              ),
              _shareCard(
                displayName,
                scientificName,
                imageUrl: referenceImageUrl,
                vertical: false,
              ),
            ];

            if (stacked) {
              return Column(
                children: [
                  cards.first,
                  const SizedBox(height: 12),
                  cards.last,
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: cards.first),
                const SizedBox(width: 12),
                Expanded(child: cards.last),
              ],
            );
          },
        ),
        _conditionPhotosCard(_bestProblem),
        const SizedBox(height: 20),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF087A53), _primary],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _primary.withValues(alpha: 0.28),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: FilledButton.icon(
            onPressed: _shareResult,
            icon: const Icon(Icons.ios_share_rounded, size: 21),
            label: Text(
              'Share Premium Report',
              style: GoogleFonts.inter(fontWeight: FontWeight.w800),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 17),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Did you find it helpful?',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _feedbackButton(
                helpful: true,
                icon: Icons.thumb_up_alt_rounded,
                label: 'Yes',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _feedbackButton(
                helpful: false,
                icon: Icons.thumb_down_alt_rounded,
                label: 'No',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _feedbackButton({
    required bool helpful,
    required IconData icon,
    required String label,
  }) {
    final selected = _feedbackHelpful == helpful;
    final color = helpful ? _primary : _error;
    return OutlinedButton.icon(
      onPressed: () => _handleFeedback(helpful),
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? color.withValues(alpha: 0.12) : _surface,
        foregroundColor: selected ? color : _textPrimary,
        side: BorderSide(color: selected ? color : _border, width: selected ? 1.5 : 1),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _basicInfoCard() {
    final profile = _resultProfile(_scientificName, _displayName);
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          _expandableRow(
            icon: Icons.info_outline,
            title: 'Toxicity to Humans',
            value: profile.humanToxicity,
            isExpanded: _toxicityExpanded,
            onTap: () => setState(() => _toxicityExpanded = !_toxicityExpanded),
          ),
          _divider(),
          _expandableRow(
            icon: Icons.pets,
            title: 'Toxicity to Pets',
            value: profile.petToxicity,
            isExpanded: _petsExpanded,
            onTap: () => setState(() => _petsExpanded = !_petsExpanded),
          ),
          _divider(),
          _expandableRow(
            icon: Icons.grass,
            title: 'Weed Potential',
            value: profile.weedPotential,
            isExpanded: _weedExpanded,
            onTap: () => setState(() => _weedExpanded = !_weedExpanded),
          ),
          _divider(),
          _expandableRow(
            icon: Icons.public,
            title: 'Distribution',
            value: profile.distribution,
            isExpanded: _distributionExpanded,
            onTap: () => setState(() => _distributionExpanded = !_distributionExpanded),
            showMap: true,
          ),
        ],
      ),
    );
  }

  Widget _expandableRow({
    required IconData icon,
    required String title,
    required String value,
    required bool isExpanded,
    required VoidCallback onTap,
    bool showMap = false,
  }) {
    return Column(
      children: [
        ListTile(
          leading: Icon(icon, color: _textTertiary, size: 22),
          title: Text(
            title,
            style: GoogleFonts.inter(
              color: _textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              value,
              style: GoogleFonts.inter(
                color: _textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          trailing: Icon(
            isExpanded ? Icons.expand_less : Icons.chevron_right,
            color: _textTertiary,
          ),
          onTap: onTap,
        ),
        if (isExpanded) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              _getExpandedDescription(title),
              style: GoogleFonts.inter(
                color: _textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
          if (showMap)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _DistributionMapCard(distribution: value),
            ),
        ],
      ],
    );
  }

  Widget _shareCard(
    String displayName,
    String scientificName, {
    required String? imageUrl,
    required bool vertical,
  }) {
    return Container(
      height: vertical ? 300 : 210,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: imageUrl != null && imageUrl.trim().isNotEmpty
                ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Image.file(
                      widget.imageFile,
                      fit: BoxFit.cover,
                    ),
                  )
                : Image.file(
                    widget.imageFile,
                    fit: BoxFit.cover,
                  ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.08),
                    Colors.black.withValues(alpha: 0.12),
                    Colors.black.withValues(alpha: 0.64),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: Image.asset(
                    'assets/icons/logo_mark_square.png',
                    width: 28,
                    height: 28,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'LeafSnap AI',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 60,
            left: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                Text(
                  scientificName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontStyle: FontStyle.italic,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (vertical)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  Expanded(child: _miniInfo(icon: Icons.wb_sunny, label: 'Partial sun')),
                  Expanded(child: _miniInfo(icon: Icons.water_drop, label: '7 days')),
                  Expanded(child: _miniInfo(icon: Icons.info, label: 'Check')),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _miniInfo({required IconData icon, required String label}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.white.withValues(alpha: 0.88),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    final canSave = !_isSavingToGarden && !_savedToGarden;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: _surface,
        border: const Border(top: BorderSide(color: _border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        child: Row(
          children: [
            _bottomIconAction(
              icon: Icons.add_a_photo_rounded,
              label: 'New',
              onPressed: _openNewScan,
            ),
            const SizedBox(width: 10),
            _bottomIconAction(
              icon: Icons.ios_share_rounded,
              label: 'Share',
              onPressed: _shareResult,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: canSave ? _saveToGarden : null,
                icon: _isSavingToGarden
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        _savedToGarden ? Icons.check_circle_rounded : Icons.yard_rounded,
                        size: 21,
                      ),
                label: Text(
                  _savedToGarden ? 'Saved' : (_isSavingToGarden ? 'Saving...' : 'Save to Garden'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: _savedToGarden ? const Color(0xFF177A50) : _primary,
                  disabledBackgroundColor:
                      _savedToGarden ? const Color(0xFF177A50) : _primary,
                  disabledForegroundColor: Colors.white,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomIconAction({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: 58,
      child: Semantics(
        button: true,
        label: label,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFDDE6E2)),
                  ),
                  child: Icon(icon, color: const Color(0xFF3B4742), size: 20),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: _textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _circleIcon(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: const BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _pronounceButton(String text) {
    return IconButton(
      onPressed: () async {
        await _tts.setLanguage('en-US');
        await _tts.setPitch(1.0);
        await _tts.speak(text);
      },
      icon: const Icon(Icons.volume_up, color: _primary, size: 20),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: _textPrimary,
        ),
      ),
    );
  }

  Widget _divider() => Divider(height: 1, thickness: 1, color: _border);

  Widget _loadingCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: _surface,
      child: const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _errorCard(String message) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: _errorLight,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: _error),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(color: _textPrimary, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _soilNoteCard(String message) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: _primaryLight,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: _primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(
                  color: _textPrimary,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _careMetricCard({
    required IconData icon,
    required String title,
    required String value,
    required String body,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: _surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: _primaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: _primary, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              body,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: _textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _soilMetricTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: _primaryLight,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: _primary, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: _textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: _textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _loadSoilSnapshot() async {
    setState(() {
      _isLoadingSoil = true;
      _soilError = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw StateError('Turn on location services to check local soil.');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError('Allow location access to analyze soil for this plant.');
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      final snapshot = await _soilApi
          .latestByLatLng(
            latitude: position.latitude,
            longitude: position.longitude,
          )
          .timeout(const Duration(seconds: 12));

      if (!mounted) return;
      setState(() {
        _soilSnapshot = snapshot;
        _soilError = snapshot.hasLiveSoilData
            ? null
            : 'Live soil data is limited here, so showing a care-based soil guide.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _soilError = _describeSoilError(error);
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingSoil = false);
      }
    }
  }

  String _describeSoilError(Object error) {
    if (error is StateError) {
      return error.message;
    }
    if (isRateLimitError(error)) {
      return 'Live soil data is busy, so showing a care-based soil guide.';
    }
    return 'Live soil data could not load, so showing a care-based soil guide.';
  }

  double? _soilMoisturePercent(AmbeeSoilSnapshot? snapshot) {
    final raw = snapshot?.soilMoisture;
    if (raw == null) return null;
    return raw <= 1 ? raw * 100 : raw.clamp(0, 100).toDouble();
  }

  String _soilAdvice(AmbeeSoilSnapshot snapshot) {
    final moisture = _soilMoisturePercent(snapshot);
    if (moisture == null) {
      return 'Live soil data found. Use the temperature and humidity readings with the care plan before watering.';
    }
    if (moisture < 25) {
      return 'Soil looks dry for $_displayName. Water gently and recheck before adding fertilizer.';
    }
    if (moisture > 75) {
      return 'Soil looks wet for $_displayName. Hold watering and improve drainage if leaves are yellowing.';
    }
    return 'Soil moisture looks balanced for $_displayName. Keep following the care rhythm below.';
  }

  String _formatTemperature(double? value) {
    if (value == null) return '--';
    return '${value.round()}\u00B0C';
  }

  String _formatPercent(double? value) {
    if (value == null) return '--';
    final normalized = value <= 1 ? value * 100 : value;
    return '${normalized.clamp(0, 100).round()}%';
  }

  Future<void> _shareResult() async {
    final text = '$_displayName ($_scientificName)\n'
        'Identified with LeafSnap AI\n'
        'Confidence: ${(widget.score * 100).toStringAsFixed(1)}%';
    await Share.share(text, subject: 'Plant Identification Result');
  }

  void _handleFeedback(bool helpful) {
    setState(() => _feedbackHelpful = helpful);
  }

  void _saveToGarden() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved to My Garden!')),
    );
  }

  Future<void> _openNewScan() async {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const CameraScreen()),
    );
  }

  String get _displayName {
    final perenualName = _englishNameOrNull(_match?.commonName);
    if (perenualName != null) {
      return perenualName;
    }

    for (final match in widget.plantNetMatches) {
      for (final name in match.commonNames) {
        final englishName = _englishNameOrNull(name);
        if (englishName != null) {
          return englishName;
        }
      }
    }

    final localNames = _localNames[widget.scientificName.toLowerCase()] ?? const [];
    for (final name in localNames.reversed) {
      final englishName = _englishNameOrNull(name);
      if (englishName != null) {
        return englishName;
      }
    }

    return widget.scientificName;
  }

  String get _scientificName => widget.scientificName;

  String get _alsoKnownAsText {
    final names = <String>[
      ...widget.plantNetMatches.expand((match) => match.commonNames),
      ...?_localNames[widget.scientificName.toLowerCase()],
    ].map((name) => name.trim()).where((name) => name.isNotEmpty).toSet().toList();

    return names.isEmpty ? 'Common names' : names.join(', ');
  }

  String? _englishNameOrNull(String? raw) {
    final name = raw?.trim();
    if (name == null || name.isEmpty || name.toLowerCase() == 'unknown') {
      return null;
    }

    const nonEnglishLocalNames = {
      'nyanya',
      'mahindi',
      'maharagwe',
      'kitunguu',
      'kabichi',
      'spinachi',
      'pilipili hoho',
      'ndizi',
      'muhogo',
      'viazi',
    };

    if (nonEnglishLocalNames.contains(name.toLowerCase())) {
      return null;
    }

    return name;
  }

  List<_ResultGalleryImage> _heroGalleryImages(
    String? referenceImageUrl,
    PlantNetDiseaseMatch? bestProblem,
  ) {
    final images = <_ResultGalleryImage>[
      _ResultGalleryImage.file(widget.imageFile, label: 'Your scan'),
    ];
    final seenUrls = <String>{};

    void addUrl(String? rawUrl, String label) {
      final url = rawUrl?.trim();
      if (url == null || url.isEmpty || !seenUrls.add(url)) {
        return;
      }
      images.add(_ResultGalleryImage.network(url, label: label));
    }

    addUrl(referenceImageUrl, 'Plant reference');
    addUrl(_match?.thumbnailUrl, 'Plant reference');
    for (final match in widget.plantNetMatches) {
      for (final image in match.images) {
        addUrl(image.bestUrl, 'Plant reference');
      }
    }
    if (bestProblem != null) {
      addUrl(bestProblem.imageUrl, 'Health reference');
      for (final image in bestProblem.images) {
        addUrl(image.bestUrl, 'Health reference');
      }
    }

    return images.take(4).toList();
  }

  String _firstPlantNetImage(List<PlantNetPlantMatch> matches) {
    if (matches.isEmpty) return '';
    return matches.first.imageUrl ?? '';
  }

  bool get _shouldRunIssueScan => true;
  PlantNetDiseaseMatch? get _bestProblem => _diseaseMatches.isEmpty ? null : _diseaseMatches.first;
  
  String _getSunlightValue() {
    final list = _details?['sunlight'] as List<dynamic>? ?? [];
    return list.isEmpty ? 'Bright indirect light' : list.join(', ');
  }
  
  String _firstCareSection(String type) {
    return _careSections.firstWhere(
      (s) => s.type == type,
      orElse: () => PerenualCareSection(type: type, description: ''),
    ).description;
  }
  
  String _getExpandedDescription(String title) {
    switch (title) {
      case 'Toxicity to Humans':
        return 'Mildly toxic if ingested. Keep out of reach of children.';
      case 'Toxicity to Pets':
        return 'Toxic to dogs and cats. Can cause oral irritation and difficulty swallowing.';
      case 'Weed Potential':
        return 'Not considered invasive in most regions.';
      case 'Distribution':
        return 'Native to Central America. Widely cultivated in tropical and subtropical regions.';
      default:
        return '';
    }
  }
  
  Map<String, dynamic> _detailsFromSummary(PerenualSpeciesSummary m) => {};
  
  PlantProfile _resultProfile(String scientific, String display) {
    return const PlantProfile(
      humanToxicity: 'Mildly toxic',
      petToxicity: 'Toxic to pets',
      weedPotential: 'Not a weed',
      distribution: 'Cultivated globally',
    );
  }
  
  bool _isCredibleProblem(PlantNetDiseaseMatch m) => m.score > _problemThreshold;
}

class _ResultGalleryImage {
  const _ResultGalleryImage._({
    this.file,
    this.url,
    required this.label,
  });

  factory _ResultGalleryImage.file(File file, {required String label}) {
    return _ResultGalleryImage._(file: file, label: label);
  }

  factory _ResultGalleryImage.network(String url, {required String label}) {
    return _ResultGalleryImage._(url: url, label: label);
  }

  final File? file;
  final String? url;
  final String label;
}

class _WorldMapPreview extends StatelessWidget {
  const _WorldMapPreview();

  static const _accurateMapUrl =
      'https://upload.wikimedia.org/wikipedia/commons/5/51/BlankMap-Equirectangular.svg';

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: ColoredBox(
        color: const Color(0xFFDDF2FE),
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                child: SvgPicture.network(
                  _accurateMapUrl,
                  fit: BoxFit.contain,
                  colorFilter: const ColorFilter.mode(
                    Color(0xFF20BFC3),
                    BlendMode.srcIn,
                  ),
                  placeholderBuilder: (_) => const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    ),
                  ),
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(
                      Icons.public_rounded,
                      color: Color(0xFF20BFC3),
                      size: 48,
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _DistributionOverlayPainter()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DistributionOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final pinPaint = Paint()
      ..color = const Color(0xFF1FC33A)
      ..style = PaintingStyle.fill;
    final pinGlow = Paint()
      ..color = const Color(0xFF1FC33A).withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;
    final pinBorder = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (final pos in [
      Offset(w * 0.22, h * 0.72),
      Offset(w * 0.50, h * 0.50),
      Offset(w * 0.67, h * 0.38),
      Offset(w * 0.80, h * 0.68),
    ]) {
      canvas.drawCircle(pos, 11, pinGlow);
      canvas.drawCircle(pos, 5, pinPaint);
      canvas.drawCircle(pos, 5.5, pinBorder);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DistributionMapCard extends StatelessWidget {
  const _DistributionMapCard({required this.distribution});

  final String distribution;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _ResultPalette.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            height: 178,
            child: _WorldMapPreview(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Habitat',
                  style: GoogleFonts.inter(
                    color: _ResultPalette.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  distribution,
                  style: GoogleFonts.inter(
                    color: _ResultPalette.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                const _DistributionLegendRow(
                  color: Color(0xFF1FC33A),
                  title: 'Native',
                  body: 'Species present in wild and native habitats.',
                ),
                const _DistributionLegendRow(
                  color: Color(0xFF20BFC3),
                  title: 'Cultivated',
                  body: 'Species cultivated as garden or house plant.',
                ),
                const _DistributionLegendRow(
                  color: Color(0xFF1467D8),
                  title: 'Introduced',
                  body: 'Species present outside native range.',
                ),
                const _DistributionLegendRow(
                  color: Color(0xFFE5264F),
                  title: 'Invasive',
                  body: 'Species reported as invasive in some regions.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DistributionLegendRow extends StatelessWidget {
  const _DistributionLegendRow({
    required this.color,
    required this.title,
    required this.body,
  });

  final Color color;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 13,
            height: 13,
            margin: const EdgeInsets.only(top: 3),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.inter(
                  color: _ResultPalette.textPrimary,
                  fontSize: 13,
                  height: 1.35,
                ),
                children: [
                  TextSpan(
                    text: '$title\n',
                    style: GoogleFonts.inter(
                      color: _ResultPalette.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(text: body),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConditionPhoto {
  const _ConditionPhoto.file(this.file, this.label) : url = null;

  const _ConditionPhoto.network(this.url, this.label) : file = null;

  final File? file;
  final String? url;
  final String label;
}

class _ResultPalette {
  static const textPrimary = Color(0xFF242927);
  static const textSecondary = Color(0xFF747977);
  static const border = Color(0xFFE1E7E4);
}

class _WorldMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final oceanRect = Rect.fromLTWH(0, 0, w, h);
    final oceanPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFDDF2FE), Color(0xFFCDEBFA)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(oceanRect)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(oceanRect, const Radius.circular(18)),
      oceanPaint,
    );

    final landPaint = Paint()
      ..color = const Color(0xFF20BFC3)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final borderPaint = Paint()
      ..color = const Color(0xFF139EA2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..isAntiAlias = true;

    // Grid lines
    final gridPaint = Paint()
      ..color = const Color(0xFF90CAE8).withOpacity(0.5)
      ..strokeWidth = 0.5;
    // Latitude lines
    for (final y in [0.22, 0.38, 0.50, 0.62, 0.78]) {
      canvas.drawLine(Offset(0, h * y), Offset(w, h * y), gridPaint);
    }
    // Longitude lines
    for (final x in [0.15, 0.30, 0.45, 0.60, 0.75, 0.88]) {
      canvas.drawLine(Offset(w * x, 0), Offset(w * x, h), gridPaint);
    }
    // Equator highlight
    final equatorPaint = Paint()
      ..color = const Color(0xFF90CAE8)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(0, h * 0.50), Offset(w, h * 0.50), equatorPaint);

    // Helper to draw a continent outline from normalized points
    void continent(List<Offset> pts) {
      if (pts.length < 2) return;
      final path = Path()..moveTo(pts.first.dx * w, pts.first.dy * h);
      for (int i = 1; i < pts.length; i++) {
        path.lineTo(pts[i].dx * w, pts[i].dy * h);
      }
      path.close();
      canvas.drawPath(path, landPaint);
      canvas.drawPath(path, borderPaint);
    }

    // North America
    continent(const [
      Offset(0.08, 0.14), Offset(0.13, 0.10), Offset(0.18, 0.11),
      Offset(0.24, 0.09), Offset(0.28, 0.13), Offset(0.30, 0.10),
      Offset(0.32, 0.12), Offset(0.30, 0.17), Offset(0.27, 0.20),
      Offset(0.28, 0.25), Offset(0.25, 0.28), Offset(0.26, 0.33),
      Offset(0.22, 0.36), Offset(0.20, 0.43), Offset(0.22, 0.48),
      Offset(0.21, 0.52), Offset(0.18, 0.55), Offset(0.20, 0.58),
      Offset(0.22, 0.56), Offset(0.24, 0.59), Offset(0.22, 0.63),
      Offset(0.18, 0.62), Offset(0.15, 0.56), Offset(0.12, 0.48),
      Offset(0.10, 0.42), Offset(0.08, 0.36), Offset(0.07, 0.26),
      Offset(0.08, 0.18),
    ]);

    // Greenland
    continent(const [
      Offset(0.16, 0.06), Offset(0.22, 0.04), Offset(0.27, 0.06),
      Offset(0.26, 0.12), Offset(0.20, 0.13), Offset(0.14, 0.10),
    ]);

    // Central America
    continent(const [
      Offset(0.20, 0.58), Offset(0.22, 0.56), Offset(0.24, 0.60),
      Offset(0.23, 0.64), Offset(0.21, 0.65),
    ]);

    // South America
    continent(const [
      Offset(0.23, 0.64), Offset(0.27, 0.62), Offset(0.32, 0.62),
      Offset(0.34, 0.65), Offset(0.36, 0.63), Offset(0.37, 0.67),
      Offset(0.35, 0.73), Offset(0.33, 0.80), Offset(0.30, 0.86),
      Offset(0.27, 0.90), Offset(0.24, 0.87), Offset(0.22, 0.82),
      Offset(0.20, 0.75), Offset(0.20, 0.68),
    ]);

    // Europe
    continent(const [
      Offset(0.44, 0.14), Offset(0.50, 0.12), Offset(0.56, 0.14),
      Offset(0.58, 0.18), Offset(0.56, 0.22), Offset(0.53, 0.24),
      Offset(0.55, 0.27), Offset(0.52, 0.30), Offset(0.50, 0.28),
      Offset(0.47, 0.31), Offset(0.44, 0.30), Offset(0.42, 0.27),
      Offset(0.43, 0.22), Offset(0.41, 0.19),
    ]);

    // Scandinavia
    continent(const [
      Offset(0.50, 0.12), Offset(0.52, 0.08), Offset(0.55, 0.10),
      Offset(0.54, 0.14), Offset(0.51, 0.15),
    ]);
    continent(const [
      Offset(0.48, 0.11), Offset(0.50, 0.08), Offset(0.51, 0.10),
      Offset(0.49, 0.13),
    ]);

    // Africa
    continent(const [
      Offset(0.44, 0.30), Offset(0.52, 0.28), Offset(0.57, 0.30),
      Offset(0.60, 0.34), Offset(0.62, 0.40), Offset(0.60, 0.47),
      Offset(0.62, 0.54), Offset(0.58, 0.62), Offset(0.54, 0.68),
      Offset(0.50, 0.74), Offset(0.48, 0.80), Offset(0.46, 0.76),
      Offset(0.44, 0.68), Offset(0.42, 0.60), Offset(0.41, 0.52),
      Offset(0.42, 0.44), Offset(0.41, 0.37), Offset(0.43, 0.32),
    ]);

    // Madagascar
    continent(const [
      Offset(0.58, 0.57), Offset(0.60, 0.55), Offset(0.62, 0.60),
      Offset(0.60, 0.66), Offset(0.58, 0.63),
    ]);

    // Asia (main body)
    continent(const [
      Offset(0.56, 0.14), Offset(0.63, 0.12), Offset(0.70, 0.10),
      Offset(0.78, 0.12), Offset(0.86, 0.16), Offset(0.90, 0.22),
      Offset(0.88, 0.28), Offset(0.85, 0.34), Offset(0.88, 0.38),
      Offset(0.86, 0.43), Offset(0.82, 0.46), Offset(0.84, 0.50),
      Offset(0.80, 0.52), Offset(0.76, 0.50), Offset(0.72, 0.53),
      Offset(0.68, 0.50), Offset(0.65, 0.52), Offset(0.62, 0.48),
      Offset(0.60, 0.44), Offset(0.60, 0.38), Offset(0.58, 0.34),
      Offset(0.60, 0.30), Offset(0.58, 0.25), Offset(0.56, 0.20),
    ]);

    // Arabian Peninsula
    continent(const [
      Offset(0.58, 0.34), Offset(0.63, 0.32), Offset(0.66, 0.36),
      Offset(0.65, 0.44), Offset(0.62, 0.48), Offset(0.59, 0.44),
      Offset(0.58, 0.40),
    ]);

    // Indian subcontinent
    continent(const [
      Offset(0.65, 0.32), Offset(0.70, 0.30), Offset(0.73, 0.34),
      Offset(0.72, 0.42), Offset(0.70, 0.50), Offset(0.68, 0.56),
      Offset(0.66, 0.52), Offset(0.65, 0.44),
    ]);

    // Southeast Asia Peninsula
    continent(const [
      Offset(0.76, 0.45), Offset(0.78, 0.44), Offset(0.80, 0.48),
      Offset(0.78, 0.54), Offset(0.76, 0.56), Offset(0.74, 0.52),
    ]);

    // Indonesia / Philippines (cluster)
    continent(const [
      Offset(0.78, 0.54), Offset(0.82, 0.54), Offset(0.84, 0.57),
      Offset(0.82, 0.60), Offset(0.78, 0.58),
    ]);
    continent(const [
      Offset(0.84, 0.52), Offset(0.87, 0.51), Offset(0.88, 0.54),
      Offset(0.85, 0.56),
    ]);

    // Japan
    continent(const [
      Offset(0.86, 0.24), Offset(0.88, 0.22), Offset(0.90, 0.26),
      Offset(0.88, 0.30), Offset(0.86, 0.28),
    ]);
    continent(const [
      Offset(0.88, 0.30), Offset(0.89, 0.28), Offset(0.91, 0.31),
      Offset(0.89, 0.33),
    ]);

    // Australia
    continent(const [
      Offset(0.78, 0.62), Offset(0.86, 0.62), Offset(0.92, 0.65),
      Offset(0.94, 0.70), Offset(0.92, 0.78), Offset(0.88, 0.82),
      Offset(0.82, 0.84), Offset(0.76, 0.82), Offset(0.74, 0.76),
      Offset(0.73, 0.70), Offset(0.75, 0.64),
    ]);

    // New Zealand (two islands)
    continent(const [
      Offset(0.95, 0.78), Offset(0.97, 0.76), Offset(0.98, 0.80),
      Offset(0.96, 0.82),
    ]);
    continent(const [
      Offset(0.95, 0.83), Offset(0.97, 0.82), Offset(0.97, 0.86),
      Offset(0.95, 0.87),
    ]);

    // UK / Ireland
    continent(const [
      Offset(0.42, 0.18), Offset(0.44, 0.15), Offset(0.46, 0.17),
      Offset(0.44, 0.21),
    ]);
    continent(const [
      Offset(0.40, 0.18), Offset(0.42, 0.17), Offset(0.42, 0.21),
      Offset(0.40, 0.20),
    ]);

    final pinPaint = Paint()
      ..color = const Color(0xFF1FC33A)
      ..style = PaintingStyle.fill;
    final pinGlow = Paint()
      ..color = const Color(0xFF1FC33A).withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;
    final pinBorder = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (final pos in [
      Offset(w * 0.22, h * 0.72), // South America
      Offset(w * 0.50, h * 0.50), // Africa
      Offset(w * 0.67, h * 0.38), // South Asia
      Offset(w * 0.80, h * 0.68), // Australia
    ]) {
      canvas.drawCircle(pos, 11, pinGlow);
      canvas.drawCircle(pos, 5.0, pinPaint);
      canvas.drawCircle(pos, 5.5, pinBorder);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  final double minHeight;
  final double maxHeight;
  final Widget child;

  @override
  double get minExtent => minHeight;
  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight ||
        minHeight != oldDelegate.minHeight ||
        child != oldDelegate.child;
  }
}

class PlantProfile {
  final String humanToxicity;
  final String petToxicity;
  final String weedPotential;
  final String distribution;
  const PlantProfile({
    required this.humanToxicity,
    required this.petToxicity,
    required this.weedPotential,
    required this.distribution,
  });
}
