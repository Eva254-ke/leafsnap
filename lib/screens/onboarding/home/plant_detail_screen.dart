import 'dart:collection';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/garden_plant.dart';
import '../../../services/ambee_soil_api.dart';
import '../../../services/api_error.dart';
import '../../../services/location_permission_service.dart';
import '../../../services/perenual_api.dart';
import '../../../services/posthog_service.dart';

class PlantDetailScreen extends StatefulWidget {
  final String plantName;
  final GardenPlant? plant;
  final String? imageUrl;
  final String? localImagePath;
  final String? city;

  PlantDetailScreen({
    super.key,
    String? plantName,
    this.plant,
    String? imageUrl,
    String? localImagePath,
    this.city,
  })  : plantName =
            plantName ?? plant?.displayName ?? plant?.scientificName ?? 'Unknown',
        imageUrl = imageUrl ?? plant?.imageUrl,
        localImagePath = localImagePath ?? plant?.localImagePath;

  @override
  State<PlantDetailScreen> createState() => _PlantDetailScreenState();
}

class _SelectorOption {
  const _SelectorOption(this.label, this.icon);

  final String label;
  final IconData icon;
}

class _PlantDetailScreenState extends State<PlantDetailScreen>
    with SingleTickerProviderStateMixin {
  static const Map<String, String> _trustedCropImages = {
    'Maize':
        'https://commons.wikimedia.org/wiki/Special:FilePath/Corn%20Zea%20mays%20Plant%202000px.jpg?width=800',
    'Corn':
        'https://commons.wikimedia.org/wiki/Special:FilePath/Corn%20Zea%20mays%20Plant%202000px.jpg?width=800',
    'Beans':
        'https://commons.wikimedia.org/wiki/Special:FilePath/Phaseolus%20vulgaris%2C%20the%20common%20green%20bean.JPG?width=800',
    'Bean':
        'https://commons.wikimedia.org/wiki/Special:FilePath/Phaseolus%20vulgaris%2C%20the%20common%20green%20bean.JPG?width=800',
    'Phaseolus vulgaris':
        'https://commons.wikimedia.org/wiki/Special:FilePath/Phaseolus%20vulgaris%2C%20the%20common%20green%20bean.JPG?width=800',
  };

  final PerenualApi _perenualApi = PerenualApi();
  final AmbeeSoilApi _ambeeSoilApi = AmbeeSoilApi();

  late final AnimationController _chartController;
  late final Animation<double> _chartAnimation;

  bool _isLoading = false;
  bool _isLoadingSoil = false;
  String? _error;
  String? _soilError;
  PerenualSpeciesSummary? _summary;
  Map<String, dynamic>? _details;
  List<PerenualCareSection> _careSections = <PerenualCareSection>[];
  AmbeeSoilSnapshot? _soilSnapshot;
  String? _feedbackSection;
  String? _feedbackVote;
  String _selectedEnvironment = 'Indoor';
  late String _selectedArea;
  String? _resolvedAreaLabel;
  bool _areaManuallySelected = false;

  static const List<_SelectorOption> _environmentOptions = [
    _SelectorOption('Indoor', Icons.home_rounded),
    _SelectorOption('Balcony', Icons.apartment_rounded),
    _SelectorOption('Patio', Icons.wb_sunny_rounded),
    _SelectorOption('Greenhouse', Icons.yard_rounded),
    _SelectorOption('In the ground', Icons.grass_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _resolvedAreaLabel = _initialAreaLabel;
    _selectedArea = _defaultAreaLabel;
    _chartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _chartAnimation = CurvedAnimation(
      parent: _chartController,
      curve: Curves.easeOutCubic,
    );
    _loadDetails();
    _chartController.forward();
  }

  @override
  void dispose() {
    _chartController.dispose();
    super.dispose();
  }

  Future<void> _loadDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results =
          await _perenualApi.searchSpecies(query: widget.plantName, page: 1);
      if (results.isEmpty) {
        if (!mounted) return;
        setState(() {
          _error = 'No data found for ${widget.plantName}.';
        });
        return;
      }

      final match = results.first;
      final details = await _perenualApi.getSpeciesDetails(match.id);
      final care = await _perenualApi.getCareGuides(
        speciesId: match.id,
        types: const <String>['sunlight', 'watering', 'fertilizing'],
      );

      if (!mounted) return;
      setState(() {
        _summary = match;
        _details = details;
        _careSections = care;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = isRateLimitError(error)
            ? 'Plant details are busy right now. Please try again later.'
            : error.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadSoilSnapshot() async {
    setState(() {
      _isLoadingSoil = true;
      _soilError = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw StateError('Enable location to analyze local soil.');
      }

      final permission =
          await LocationPermissionService.checkAndRequestIfNeeded();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError('Location permission is needed for soil analysis.');
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      final areaLabel = await _resolvePlaceName(position);
      if (mounted && areaLabel != null) {
        setState(() {
          _resolvedAreaLabel = areaLabel;
          if (!_areaManuallySelected || _selectedArea == 'Locating...') {
            _selectedArea = areaLabel;
          }
        });
      }

      final snapshot = await _ambeeSoilApi.latestByLatLng(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      if (!mounted) return;
      setState(() {
        _soilSnapshot = snapshot;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _soilError = error is StateError
            ? error.message
            : 'Live soil analysis is unavailable right now.';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingSoil = false);
      }
    }
  }

  Future<String?> _resolvePlaceName(Position position) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isEmpty) return _initialAreaLabel;

      final place = placemarks.first;
      return _firstNonEmpty([
        place.locality,
        place.subAdministrativeArea,
        place.administrativeArea,
        place.name,
        place.country,
      ]);
    } catch (_) {
      return _initialAreaLabel;
    }
  }

  String? _firstNonEmpty(Iterable<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final profile = _careProfileForPlant(displayName);
    final imageUrl = _trustedImageUrlForPlant(widget.plantName) ??
        widget.imageUrl ??
        _trustedImageUrlForPlant(_summary?.commonName) ??
        _trustedImageUrlForPlant(_summary?.scientificName) ??
        _summary?.imageUrl ??
        _summary?.thumbnailUrl;
    final localImageFile = _imageFileFromPath(widget.localImagePath);

    return DefaultTabController(
      length: 8,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F8F6),
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF151A17),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          title: Text(
            displayName,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: () {
                _loadDetails();
              },
              icon: const Icon(Icons.more_horiz_rounded),
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            labelColor: const Color(0xFF23B28B),
            unselectedLabelColor: const Color(0xFF68706B),
            indicatorColor: const Color(0xFF23B28B),
            indicatorWeight: 4,
            labelStyle: GoogleFonts.inter(
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
            tabs: const [
              Tab(text: 'Watering'),
              Tab(text: 'Sunlight'),
              Tab(text: 'Temperature'),
              Tab(text: 'Fertilizing'),
              Tab(text: 'Pruning'),
              Tab(text: 'Repotting'),
              Tab(text: 'Soil'),
              Tab(text: 'Diseases'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF23B28B)),
              )
            : _error != null
                ? _buildErrorState(_error!)
                : TabBarView(
                    children: [
                      _buildWateringTab(profile, imageUrl, localImageFile),
                      _buildSunlightTab(profile, imageUrl, localImageFile),
                      _buildTemperatureTab(profile),
                      _buildFertilizingTab(profile),
                      _buildPruningTab(profile),
                      _buildRepottingTab(profile),
                      _buildSoilTab(profile),
                      _buildDiseaseTab(profile),
                    ],
                  ),
      ),
    );
  }

  String get displayName {
    final common = _summary?.commonName.trim();
    if (common != null && common.isNotEmpty && common != 'Unknown') {
      return common;
    }
    return widget.plantName;
  }

  Widget _buildWateringTab(
    _CareProfile profile,
    String? imageUrl,
    File? localImageFile,
  ) {
    return _careScroll(
      section: 'watering',
      children: [
        _environmentSelector(),
        _sectionTitle('Watering schedule'),
        AnimatedBuilder(
          animation: _chartAnimation,
          builder: (context, child) {
            return CustomPaint(
              painter: _WateringChartPainter(
                stages: profile.wateringStages,
                progress: _chartAnimation.value,
              ),
              child: const SizedBox(height: 260, width: double.infinity),
            );
          },
        ),
        const SizedBox(height: 12),
        _stageLegend(profile.wateringStages),
        const SizedBox(height: 18),
        _locationCard(profile),
        _contentBlock(
          title: 'Key tips for watering',
          body: _firstCareSection('watering') ?? profile.wateringTips,
        ),
        _feedbackBlock('watering'),
      ],
    );
  }

  Widget _buildSunlightTab(
    _CareProfile profile,
    String? imageUrl,
    File? localImageFile,
  ) {
    final sunlight = (_details?['sunlight'] as List<dynamic>? ?? <dynamic>[])
        .map((item) => item.toString())
        .toList();
    return _careScroll(
      section: 'sunlight',
      children: [
        _heroImage(imageUrl, localImageFile),
        _sectionTitle('Sunlight needs'),
        _metricBand(
          icon: Icons.wb_sunny_outlined,
          label: sunlight.isNotEmpty ? sunlight.join(', ') : profile.sunlight,
          value: 'Best light range',
        ),
        _sunlightMeter(profile.sunlightScore),
        _contentBlock(
          title: 'Key tips for sunlight',
          body: _firstCareSection('sunlight') ?? profile.sunlightTips,
        ),
        _feedbackBlock('sunlight'),
      ],
    );
  }

  Widget _buildTemperatureTab(_CareProfile profile) {
    final hardiness = _details?['hardiness'] as Map<String, dynamic>?;
    final range = hardiness == null
        ? profile.temperatureRange
        : '${hardiness['min'] ?? '-'} to ${hardiness['max'] ?? '-'}';
    return _careScroll(
      section: 'temperature',
      children: [
        _sectionTitle('Temperature range'),
        _metricBand(
          icon: Icons.thermostat_rounded,
          label: range,
          value: 'Ideal growing window',
        ),
        _temperatureScale(profile.minTempC, profile.maxTempC),
        _contentBlock(
          title: 'Heat and cold protection',
          body: profile.temperatureTips,
        ),
        _feedbackBlock('temperature'),
      ],
    );
  }

  Widget _buildFertilizingTab(_CareProfile profile) {
    return _careScroll(
      section: 'fertilizing',
      children: [
        _sectionTitle('Fertilizing plan'),
        _metricBand(
          icon: Icons.science_outlined,
          label: profile.fertilizerCadence,
          value: profile.npkHint,
        ),
        _contentBlock(
          title: 'Key tips for fertilizing',
          body: _firstCareSection('fertilizing') ?? profile.fertilizingTips,
        ),
        _tipList(profile.fertilizerChecklist),
        _feedbackBlock('fertilizing'),
      ],
    );
  }

  Widget _buildPruningTab(_CareProfile profile) {
    return _careScroll(
      section: 'pruning',
      children: [
        _sectionTitle('Pre-pruning check'),
        _contentBlock(title: 'When to prune', body: profile.pruningCheck),
        _contentBlock(title: 'Pruning techniques', body: profile.pruningTips),
        _tipList(profile.pruningChecklist),
        _feedbackBlock('pruning'),
      ],
    );
  }

  Widget _buildRepottingTab(_CareProfile profile) {
    return _careScroll(
      section: 'repotting',
      children: [
        _sectionTitle('Repotting check'),
        _metricBand(
          icon: Icons.yard_outlined,
          label: profile.repotCadence,
          value: 'Watch roots, drainage, and growth speed',
        ),
        _contentBlock(title: 'When to repot', body: profile.repottingTips),
        _tipList(profile.repottingChecklist),
        _feedbackBlock('repotting'),
      ],
    );
  }

  Widget _buildSoilTab(_CareProfile profile) {
    return _careScroll(
      section: 'soil',
      children: [
        _environmentSelector(),
        _sectionTitle('Soil needs'),
        _soilSummary(profile),
        const SizedBox(height: 22),
        _phStrip(profile.minPh, profile.maxPh),
        const SizedBox(height: 22),
        _liveSoilCard(),
        _contentBlock(title: 'Key tips for soil', body: profile.soilTips),
        _feedbackBlock('soil'),
      ],
    );
  }

  Widget _buildDiseaseTab(_CareProfile profile) {
    return _careScroll(
      section: 'diseases',
      children: [
        _sectionTitle('Disease watch'),
        _metricBand(
          icon: Icons.health_and_safety_outlined,
          label: profile.commonProblems.join(', '),
          value: 'Most common risks',
        ),
        _contentBlock(
          title: 'Prevention',
          body: profile.diseasePrevention,
        ),
        _tipList(profile.diseaseChecklist),
        _feedbackBlock('diseases'),
      ],
    );
  }

  Widget _careScroll({
    required String section,
    required List<Widget> children,
  }) {
    PosthogService.instance.capture(
      'plant_detail_section_viewed',
      properties: <String, Object>{
        'plant': displayName,
        'section': section,
      },
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
      children: children,
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 27,
                fontWeight: FontWeight.w900,
                color: Colors.black,
              ),
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_horiz_rounded),
          ),
        ],
      ),
    );
  }

  Widget _environmentSelector() {
    return Align(
      alignment: Alignment.centerLeft,
      child: _selectorShell(
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _selectedEnvironment,
            borderRadius: BorderRadius.circular(14),
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF23B28B),
            ),
            selectedItemBuilder: (context) => _environmentOptions.map((option) {
              return _selectorValue(
                icon: option.icon,
                label: option.label,
              );
            }).toList(),
            items: _environmentOptions.map((option) {
              return DropdownMenuItem<String>(
                value: option.label,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(option.icon, color: const Color(0xFF23B28B), size: 20),
                    const SizedBox(width: 10),
                    Text(
                      option.label,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _selectedEnvironment = value);
            },
          ),
        ),
      ),
    );
  }

  Widget _areaSelector() {
    final options = _areaOptions;
    if (!options.contains(_selectedArea)) {
      _selectedArea = options.first;
    }

    return _selectorShell(
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedArea,
          borderRadius: BorderRadius.circular(14),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Color(0xFF23B28B),
          ),
          selectedItemBuilder: (context) => options.map((area) {
            return _selectorValue(
              icon: Icons.location_on_outlined,
              label: area,
              compact: true,
            );
          }).toList(),
          items: options.map((area) {
            return DropdownMenuItem<String>(
              value: area,
              child: Text(
                area,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _areaManuallySelected = true;
              _selectedArea = value;
            });
          },
        ),
      ),
    );
  }

  Widget _selectorShell({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE1E9E6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _selectorValue({
    required IconData icon,
    required String label,
    bool compact = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFF23B28B), size: compact ? 18 : 20),
        const SizedBox(width: 8),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: compact ? 130 : 180),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: const Color(0xFF1C8E72),
              fontSize: compact ? 14 : 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  List<String> get _areaOptions {
    final current = _defaultAreaLabel;
    final city = _resolvedAreaLabel ?? widget.city?.trim();
    final options = <String>[
      current,
      if (city != null && city.isNotEmpty && city != 'Locating...')
        '$city outskirts',
      if (city != null && city.isNotEmpty && city != 'Locating...') 'Near $city',
      'Nearby farms',
      'Nearby gardens',
    ];
    return LinkedHashSet<String>.from(options).toList(growable: false);
  }

  String get _defaultAreaLabel {
    return _resolvedAreaLabel ?? 'Locating...';
  }

  String? get _initialAreaLabel {
    final city = widget.city?.trim();
    return city != null && city.isNotEmpty ? city : null;
  }

  String get _selectedEnvironmentSummary {
    switch (_selectedEnvironment) {
      case 'Indoor':
        return 'Indoor pot';
      case 'Balcony':
        return 'Balcony planter';
      case 'Patio':
        return 'Patio container';
      case 'Greenhouse':
        return 'Greenhouse bed';
      case 'In the ground':
        return 'Ground planting';
      default:
        return _selectedEnvironment;
    }
  }

  Widget _environmentSummaryChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBFA),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD8E2DF)),
      ),
      child: Text(
        _selectedEnvironmentSummary,
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w800,
          color: const Color(0xFF1C8E72),
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _stageLegend(List<_WateringStage> stages) {
    return Wrap(
      spacing: 22,
      runSpacing: 18,
      children: stages.map((stage) {
        return SizedBox(
          width: 145,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: CircleAvatar(radius: 5, backgroundColor: stage.color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stage.label,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF626866),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Every ${stage.days} days',
                      style: GoogleFonts.inter(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _locationCard(_CareProfile profile) {
    final month = _monthName(DateTime.now().month);
    return Container(
      margin: const EdgeInsets.only(top: 6, bottom: 24),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF5F4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text.rich(
            TextSpan(
              text: 'Based on: ',
              style: GoogleFonts.inter(
                color: const Color(0xFF686E6B),
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
              children: [
                TextSpan(
                  text: '$month, ',
                  style: const TextStyle(color: Colors.black),
                ),
              ],
            ),
          ),
          _environmentSummaryChip(),
          _areaSelector(),
        ],
      ),
    );
  }

  Widget _contentBlock({required String title, required String body}) {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.only(top: 24),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFEAF0EE), width: 8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            body,
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF3D4140),
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricBand({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5ECE9)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0xFFD9FBF2),
            child: Icon(icon, color: const Color(0xFF23B28B), size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF6B706E),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tipList(List<String> tips) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      child: Column(
        children: tips.map((tip) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF23B28B),
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tip,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _sunlightMeter(double score) {
    return Container(
      margin: const EdgeInsets.only(top: 18),
      height: 18,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: const LinearGradient(
          colors: [
            Color(0xFFB8E6FF),
            Color(0xFFFFF3A0),
            Color(0xFFFFB25A),
          ],
        ),
      ),
      child: Align(
        alignment: Alignment((score.clamp(0, 1) * 2) - 1, 0),
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF23B28B), width: 3),
          ),
        ),
      ),
    );
  }

  Widget _temperatureScale(double minTemp, double maxTemp) {
    return Container(
      margin: const EdgeInsets.only(top: 18),
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF8CC9FF),
            Color(0xFFBEEB8F),
            Color(0xFFFFC76E),
            Color(0xFFFF736A),
          ],
        ),
      ),
      child: Center(
        child: Text(
          '${minTemp.round()} C - ${maxTemp.round()} C',
          style: GoogleFonts.inter(
            color: Colors.black,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _soilSummary(_CareProfile profile) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const CircleAvatar(
          radius: 36,
          backgroundColor: Color(0xFFD9FBF2),
          child: Icon(Icons.landscape_rounded, color: Color(0xFF23B28B), size: 34),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.soilTypes.join(', '),
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Suitable soil types',
                style: GoogleFonts.inter(
                  fontSize: 17,
                  color: const Color(0xFF6B706E),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _phStrip(double minPh, double maxPh) {
    final colors = <Color>[
      const Color(0xFFF3CCCC),
      const Color(0xFFF3DCC2),
      const Color(0xFFF4E8BE),
      const Color(0xFFF3F1BA),
      const Color(0xFFE5EDC5),
      const Color(0xFF8CB958),
      const Color(0xFF62AC51),
      const Color(0xFFC5DFC4),
      const Color(0xFFC5E2D5),
      const Color(0xFFC5E0E3),
      const Color(0xFFC5D3E3),
      const Color(0xFFC9CDE5),
      const Color(0xFFCCC7E3),
      const Color(0xFFD1C6E3),
      const Color(0xFFD6C6E2),
    ];
    final center = ((minPh + maxPh) / 2).round().clamp(0, 14);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFDFFFF8),
            border: Border.all(color: const Color(0xFF6ADBC7)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            '${minPh.toStringAsFixed(0)} pH-${maxPh.toStringAsFixed(0)} pH',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: List.generate(15, (index) {
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Container(
                  height: index == center ? 38 : 28,
                  decoration: BoxDecoration(
                    color: colors[index],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            15,
            (index) => Text(
              '$index',
              style: GoogleFonts.inter(
                color: const Color(0xFF6B706E),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _liveSoilCard() {
    final snapshot = _soilSnapshot;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5ECE9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sensors_rounded, color: Color(0xFF23B28B)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Live soil analysis',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (_isLoadingSoil)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF23B28B),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (snapshot != null && snapshot.hasLiveSoilData)
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _soilMetric('Moisture', _formatMetric(snapshot.soilMoisture, '%')),
                _soilMetric('Soil temp', _formatMetric(snapshot.soilTemperatureC, 'C')),
                _soilMetric('Surface', _formatMetric(snapshot.surfaceTemperatureC, 'C')),
                _soilMetric('Humidity', _formatMetric(snapshot.humidity, '%')),
              ],
            )
          else
            Text(
              _soilError ??
                  'Use your location to check live Ambee soil data when you need it.',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF68706B),
                height: 1.45,
              ),
            ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isLoadingSoil ? null : _loadSoilSnapshot,
              icon: _isLoadingSoil
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.location_searching_rounded),
              label: Text(
                _isLoadingSoil ? 'Checking soil...' : 'Analyze Local Soil',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF23B28B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _soilMetric(String label, String value) {
    return Container(
      width: 132,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F8F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: const Color(0xFF68706B),
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.inter(
              color: Colors.black,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _feedbackBlock(String section) {
    final selectedVote = _feedbackSection == section ? _feedbackVote : null;
    return Container(
      margin: const EdgeInsets.only(top: 30),
      padding: const EdgeInsets.symmetric(vertical: 26),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFEAF0EE), width: 8)),
      ),
      child: Column(
        children: [
          Text(
            'Do You Like the Information about $displayName?',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF333735),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _feedbackButton(
                  section: section,
                  vote: 'like',
                  selected: selectedVote == 'like',
                  icon: Icons.thumb_up_alt_outlined,
                  label: 'Like',
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _feedbackButton(
                  section: section,
                  vote: 'dislike',
                  selected: selectedVote == 'dislike',
                  icon: Icons.thumb_down_alt_outlined,
                  label: 'Dislike',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _feedbackButton({
    required String section,
    required String vote,
    required bool selected,
    required IconData icon,
    required String label,
  }) {
    return OutlinedButton.icon(
      onPressed: () => _submitFeedback(section: section, vote: vote),
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: selected ? Colors.white : const Color(0xFF333735),
        backgroundColor: selected ? const Color(0xFF23B28B) : Colors.white,
        side: BorderSide(
          color: selected ? const Color(0xFF23B28B) : const Color(0xFFD7DEDB),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14),
        textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
    );
  }

  Future<void> _submitFeedback({
    required String section,
    required String vote,
  }) async {
    setState(() {
      _feedbackSection = section;
      _feedbackVote = vote;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('content_feedback').add({
        'userId': user?.uid,
        'plantName': displayName,
        'scientificName': _summary?.scientificName ?? widget.plant?.scientificName,
        'section': section,
        'vote': vote,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await PosthogService.instance.capture(
        'care_content_feedback',
        properties: <String, Object>{
          'plant': displayName,
          'section': section,
          'vote': vote,
        },
      );
    } catch (_) {
      // Feedback should feel instant even if analytics storage is unavailable.
    }
  }

  Widget _heroImage(String? imageUrl, File? localImageFile) {
    if (localImageFile != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Image.file(
          localImageFile,
          height: 190,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      );
    }
    if (imageUrl == null || imageUrl.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Image.network(
        imageUrl,
        height: 190,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(color: Colors.red, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  String? _firstCareSection(String type) {
    for (final section in _careSections) {
      if (section.type == type) {
        return section.description;
      }
    }
    return null;
  }

  File? _imageFileFromPath(String? path) {
    final trimmedPath = path?.trim();
    if (trimmedPath == null || trimmedPath.isEmpty) {
      return null;
    }

    final file = File(trimmedPath);
    return file.existsSync() ? file : null;
  }

  String? _trustedImageUrlForPlant(String? plantName) {
    final normalizedName = _normalizePlantName(plantName ?? '');
    if (normalizedName.isEmpty) {
      return null;
    }

    for (final entry in _trustedCropImages.entries) {
      final normalizedKey = _normalizePlantName(entry.key);
      if (normalizedName == normalizedKey ||
          normalizedName.contains(normalizedKey) ||
          normalizedKey.contains(normalizedName)) {
        return entry.value;
      }
    }

    return null;
  }

  _CareProfile _careProfileForPlant(String plantName) {
    final normalized = _normalizePlantName(plantName);
    // Tomato-specific care removed; using generic care based on uploaded plant.

    if (normalized.contains('maize') ||
        normalized.contains('corn') ||
        normalized.contains('zea mays')) {
      return _CareProfile.maize();
    }
    if (normalized.contains('bean') || normalized.contains('phaseolus')) {
      return _CareProfile.beans();
    }
    return _CareProfile.generic(plantName);
  }

  String _normalizePlantName(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _formatMetric(double? value, String unit) {
    if (value == null) {
      return '--';
    }
    return '${value.toStringAsFixed(value.abs() >= 10 ? 0 : 1)} $unit';
  }

  String _monthName(int month) {
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[(month - 1).clamp(0, 11)];
  }
}

class _CareProfile {
  const _CareProfile({
    required this.wateringStages,
    required this.wateringTips,
    required this.sunlight,
    required this.sunlightTips,
    required this.sunlightScore,
    required this.temperatureRange,
    required this.minTempC,
    required this.maxTempC,
    required this.temperatureTips,
    required this.fertilizerCadence,
    required this.npkHint,
    required this.fertilizingTips,
    required this.fertilizerChecklist,
    required this.pruningCheck,
    required this.pruningTips,
    required this.pruningChecklist,
    required this.repotCadence,
    required this.repottingTips,
    required this.repottingChecklist,
    required this.soilTypes,
    required this.minPh,
    required this.maxPh,
    required this.soilTips,
    required this.commonProblems,
    required this.diseasePrevention,
    required this.diseaseChecklist,
  });

  final List<_WateringStage> wateringStages;
  final String wateringTips;
  final String sunlight;
  final String sunlightTips;
  final double sunlightScore;
  final String temperatureRange;
  final double minTempC;
  final double maxTempC;
  final String temperatureTips;
  final String fertilizerCadence;
  final String npkHint;
  final String fertilizingTips;
  final List<String> fertilizerChecklist;
  final String pruningCheck;
  final String pruningTips;
  final List<String> pruningChecklist;
  final String repotCadence;
  final String repottingTips;
  final List<String> repottingChecklist;
  final List<String> soilTypes;
  final double minPh;
  final double maxPh;
  final String soilTips;
  final List<String> commonProblems;
  final String diseasePrevention;
  final List<String> diseaseChecklist;




  factory _CareProfile.maize() {
    return _CareProfile(
      wateringStages: const <_WateringStage>[
        _WateringStage('Seedling', 3, Color(0xFF5ED03D), Icons.spa_rounded),
        _WateringStage('Growing', 5, Color(0xFF34C6AD), Icons.grass_rounded),
        _WateringStage('Tasseling', 3, Color(0xFFFF9800), Icons.filter_vintage_rounded),
        _WateringStage('Grain fill', 4, Color(0xFFFF6F6A), Icons.eco_rounded),
      ],
      wateringTips:
          'Maize needs consistent moisture during tasseling and grain fill. Water deeply so roots follow moisture downward.',
      sunlight: 'Full sun',
      sunlightTips:
          'Plant maize in open sun. Shading reduces stalk strength, tasseling quality, and cob filling.',
      sunlightScore: 0.88,
      temperatureRange: '18 C - 32 C',
      minTempC: 18,
      maxTempC: 32,
      temperatureTips:
          'Maize grows fastest in warm weather. Cold soil slows germination, while heat stress during tasseling can reduce yield.',
      fertilizerCadence: 'At planting and knee-high stage',
      npkHint: 'Nitrogen-forward feeding',
      fertilizingTips:
          'Maize is a heavy nitrogen feeder. Side-dress before rapid stem growth and keep nutrients away from direct seed contact.',
      fertilizerChecklist: const <String>[
        'Add compost or manure before planting.',
        'Side-dress nitrogen when plants are knee high.',
        'Water after feeding to move nutrients into the root zone.',
      ],
      pruningCheck: 'Maize usually does not need pruning.',
      pruningTips:
          'Remove only diseased leaves or broken stalks. Keep healthy leaves because they power cob development.',
      pruningChecklist: const <String>[
        'Do not remove tassels unless doing controlled pollination.',
        'Remove badly diseased leaves from the field.',
        'Keep rows open enough for airflow.',
      ],
      repotCadence: 'Best direct-sown',
      repottingTips:
          'Maize dislikes root disturbance. If started in trays, transplant while young before roots bind.',
      repottingChecklist: const <String>[
        'Transplant with the full root plug.',
        'Water immediately after moving.',
        'Avoid transplanting during midday heat.',
      ],
      soilTypes: const <String>['Deep Loam', 'Fertile Soil'],
      minPh: 5.8,
      maxPh: 7,
      soilTips:
          'Maize prefers deep, fertile, well-drained soil with strong organic matter. Compacted soil limits root depth and drought resilience.',
      commonProblems: const <String>['Armyworm', 'Rust', 'Leaf blight'],
      diseasePrevention:
          'Scout the whorl and leaf surfaces early. Rotate fields, remove crop debris, and act quickly on caterpillar feeding damage.',
      diseaseChecklist: const <String>[
        'Inspect leaf whorls for caterpillars.',
        'Watch for orange rust pustules.',
        'Avoid water stress during tasseling.',
      ],
    );
  }

  factory _CareProfile.beans() {
    return _CareProfile(
      wateringStages: const <_WateringStage>[
        _WateringStage('Seedling', 3, Color(0xFF5ED03D), Icons.spa_rounded),
        _WateringStage('Vining', 4, Color(0xFF34C6AD), Icons.grass_rounded),
        _WateringStage('Flowering', 3, Color(0xFFFF9800), Icons.filter_vintage_rounded),
        _WateringStage('Pods', 3, Color(0xFFFF6F6A), Icons.eco_rounded),
      ],
      wateringTips:
          'Beans need steady moisture during flowering and pod set. Keep leaves as dry as possible to reduce fungal spotting.',
      sunlight: 'Full sun to part shade',
      sunlightTips:
          'Beans perform best with bright sun, but light afternoon shade can help during very hot weather.',
      sunlightScore: 0.72,
      temperatureRange: '16 C - 29 C',
      minTempC: 16,
      maxTempC: 29,
      temperatureTips:
          'Beans prefer warm soil. Cold or waterlogged conditions can reduce germination and increase root rot.',
      fertilizerCadence: 'Light feeding',
      npkHint: 'Low nitrogen, compost-rich soil',
      fertilizingTips:
          'Beans fix nitrogen, so avoid heavy nitrogen feeding. Use compost and a balanced light feed if plants look weak.',
      fertilizerChecklist: const <String>[
        'Avoid overfeeding nitrogen.',
        'Use compost for soil structure.',
        'Support flowering with potassium if pods are weak.',
      ],
      pruningCheck: 'Prune only for airflow or damaged growth.',
      pruningTips:
          'Remove yellow, diseased, or crowded leaves. For climbing beans, guide vines onto support instead of cutting aggressively.',
      pruningChecklist: const <String>[
        'Remove leaves with fungal spots.',
        'Keep foliage off wet soil.',
        'Train vines early onto stakes or trellis.',
      ],
      repotCadence: 'Best direct-sown',
      repottingTips:
          'Beans dislike root disturbance. Direct sow when possible, or transplant young seedlings gently.',
      repottingChecklist: const <String>[
        'Move seedlings before roots tangle.',
        'Keep soil warm after transplanting.',
        'Water gently at the base.',
      ],
      soilTypes: const <String>['Loam', 'Sandy Loam'],
      minPh: 6,
      maxPh: 7,
      soilTips:
          'Beans prefer loose, well-drained soil with moderate fertility. Good airflow and drainage are more important than heavy feeding.',
      commonProblems: const <String>['Rust', 'Anthracnose', 'Aphids'],
      diseasePrevention:
          'Water at the base, avoid handling plants when wet, and remove infected leaves early to slow fungal spread.',
      diseaseChecklist: const <String>[
        'Check for rust-colored spots under leaves.',
        'Remove infected plant debris.',
        'Rotate beans to a new bed each season.',
      ],
    );
  }

  factory _CareProfile.generic(String plantName) {
    return _CareProfile(
      wateringStages: const <_WateringStage>[
        _WateringStage('Seedling', 3, Color(0xFF5ED03D), Icons.spa_rounded),
        _WateringStage('Growing', 5, Color(0xFF34C6AD), Icons.local_florist_rounded),
        _WateringStage('Flowering', 4, Color(0xFFFF9800), Icons.filter_vintage_rounded),
        _WateringStage('Mature', 4, Color(0xFFFF6F6A), Icons.eco_rounded),
      ],
      wateringTips:
          'Keep soil evenly moist without leaving roots waterlogged. Adjust watering after checking the top soil and recent weather.',
      sunlight: 'Bright light',
      sunlightTips:
          'Give the plant bright, appropriate light and adjust if leaves scorch, stretch, or pale.',
      sunlightScore: 0.65,
      temperatureRange: '16 C - 30 C',
      minTempC: 16,
      maxTempC: 30,
      temperatureTips:
          'Avoid sudden temperature swings and protect roots from heat or cold stress.',
      fertilizerCadence: 'During active growth',
      npkHint: 'Balanced light feeding',
      fertilizingTips:
          'Feed lightly during active growth and pause when the plant is stressed.',
      fertilizerChecklist: const <String>[
        'Do not feed dry roots.',
        'Use compost where possible.',
        'Reduce feeding in cold or low-light periods.',
      ],
      pruningCheck: 'Prune when growth is crowded, weak, or diseased.',
      pruningTips:
          'Remove dead or infected growth first, then shape lightly for airflow.',
      pruningChecklist: const <String>[
        'Use clean tools.',
        'Remove diseased leaves promptly.',
        'Avoid heavy pruning during stress.',
      ],
      repotCadence: 'When roots fill the container',
      repottingTips:
          'Repot when roots circle the pot, water drains too quickly, or growth stalls despite good care.',
      repottingChecklist: const <String>[
        'Choose a slightly larger container.',
        'Keep drainage open.',
        'Water after repotting.',
      ],
      soilTypes: const <String>['Loam', 'Well-drained Soil'],
      minPh: 6,
      maxPh: 7,
      soilTips:
          'Use a well-draining soil mix with organic matter. Avoid compacted or constantly wet soil.',
      commonProblems: const <String>['Leaf spot', 'Aphids', 'Root rot'],
      diseasePrevention:
          'Improve airflow, avoid overwatering, and remove infected leaves before disease spreads.',
      diseaseChecklist: const <String>[
        'Inspect new growth weekly.',
        'Avoid wet foliage overnight.',
        'Quarantine sick plants when possible.',
      ],
    );
  }
}

class _WateringStage {
  const _WateringStage(this.label, this.days, this.color, this.icon);

  final String label;
  final int days;
  final Color color;
  final IconData icon;
}

class _WateringChartPainter extends CustomPainter {
  _WateringChartPainter({
    required this.stages,
    required this.progress,
  });

  final List<_WateringStage> stages;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final chartRect = Rect.fromLTWH(34, 22, size.width - 54, size.height - 68);
    final gridPaint = Paint()
      ..color = const Color(0xFFE9EEEE)
      ..strokeWidth = 1;
    final axisPaint = Paint()
      ..color = const Color(0xFFE1E7E4)
      ..strokeWidth = 1.4;

    for (var i = 0; i < 4; i++) {
      final y = chartRect.top + chartRect.height * (i / 3);
      canvas.drawLine(Offset(chartRect.left, y), Offset(chartRect.right, y), gridPaint);
    }
    for (var i = 0; i < stages.length; i++) {
      final x = chartRect.left + chartRect.width * (i / (stages.length - 1));
      canvas.drawLine(Offset(x, chartRect.top), Offset(x, chartRect.bottom), gridPaint);
    }
    canvas.drawRect(chartRect, axisPaint..style = PaintingStyle.stroke);

    final points = <Offset>[];
    for (var i = 0; i < stages.length; i++) {
      final x = chartRect.left + chartRect.width * (i / (stages.length - 1));
      final normalized = (stages[i].days - 2) / 5;
      final y = chartRect.top + chartRect.height * normalized.clamp(0, 1);
      points.add(Offset(x, y));
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 0; i < points.length - 1; i++) {
      final current = points[i];
      final next = points[i + 1];
      final midX = (current.dx + next.dx) / 2;
      path.cubicTo(midX, current.dy, midX, next.dy, next.dx, next.dy);
    }

    final metric = path.computeMetrics().first;
    final partial = metric.extractPath(0, metric.length * progress.clamp(0, 1));
    final gradient = LinearGradient(
      colors: stages.map((stage) => stage.color).toList(),
    ).createShader(chartRect);
    canvas.drawPath(
      partial,
      Paint()
        ..shader = gradient
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 5,
    );

    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i < stages.length; i++) {
      final point = points[i];
      final stage = stages[i];
      final paint = Paint()..color = stage.color;
      canvas.drawCircle(point, 6, Paint()..color = Colors.white);
      canvas.drawCircle(point, 5, paint);
      canvas.drawCircle(
        Offset(point.dx, chartRect.top + 38),
        24,
        Paint()
          ..color = Colors.white
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      final iconPainter = TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(
          text: String.fromCharCode(stage.icon.codePoint),
          style: TextStyle(
            fontSize: 22,
            fontFamily: stage.icon.fontFamily,
            package: stage.icon.fontPackage,
            color: stage.color,
          ),
        ),
      )..layout();
      iconPainter.paint(
        canvas,
        Offset(point.dx - iconPainter.width / 2, chartRect.top + 27),
      );

      textPainter.text = TextSpan(
        text: stage.label,
        style: const TextStyle(
          color: Color(0xFF7B817E),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      );
      textPainter.layout(maxWidth: 90);
      textPainter.paint(
        canvas,
        Offset(point.dx - textPainter.width / 2, chartRect.bottom + 12),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WateringChartPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.stages != stages;
  }
}
