import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/garden_plant.dart';
import '../../../services/perenual_api.dart';

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
            plantName ??
            plant?.displayName ??
            plant?.scientificName ??
            'Unknown',
        imageUrl = imageUrl ?? plant?.imageUrl,
        localImagePath = localImagePath ?? plant?.localImagePath;

  @override
  State<PlantDetailScreen> createState() => _PlantDetailScreenState();
}

class _PlantDetailScreenState extends State<PlantDetailScreen> {
  final PerenualApi _perenualApi = PerenualApi();
  bool _isLoading = false;
  String? _error;
  PerenualSpeciesSummary? _summary;
  Map<String, dynamic>? _details;
  List<PerenualCareSection> _careSections = [];

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await _perenualApi.searchSpecies(query: widget.plantName, page: 1);
      if (results.isEmpty) {
        setState(() {
          _error = 'No data found for ${widget.plantName}.';
        });
        return;
      }
      final match = results.first;
      final details = await _perenualApi.getSpeciesDetails(match.id);
      final care = await _perenualApi.getCareGuides(
        speciesId: match.id,
        types: const ['sunlight', 'watering', 'fertilizing'],
      );
      setState(() {
        _summary = match;
        _details = details;
        _careSections = care;
      });
    } catch (error) {
      setState(() {
        _error = error.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.imageUrl ?? _summary?.imageUrl ?? _summary?.thumbnailUrl;
    final localImageFile = _imageFileFromPath(widget.localImagePath);
    final sunlight = (_details?['sunlight'] as List<dynamic>? ?? []).cast<String>();
    final watering = _details?['watering'] as String?;
    final hardiness = _details?['hardiness'] as Map<String, dynamic>?;
    final tempRange = hardiness == null ? null : '${hardiness['min'] ?? '-'} to ${hardiness['max'] ?? '-'}';

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: const Color(0xFFF0FFF4),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF0FFF4),
          foregroundColor: const Color(0xFF1B1B1B),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          title: Text(
            widget.plantName,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: const Color(0xFF1B1B1B),
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.more_horiz),
              onPressed: () {},
            ),
          ],
          bottom: const TabBar(
            labelColor: Color(0xFF228B22),
            unselectedLabelColor: Colors.grey,
            indicatorColor: Color(0xFF228B22),
            tabs: [
              Tab(text: 'Watering'),
              Tab(text: 'Sunlight'),
              Tab(text: 'Temperature'),
              Tab(text: 'Fertilizing'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                : TabBarView(
                    children: [
                      _buildCareTab(
                        title: 'Watering schedule',
                        subtitle: watering ?? 'No watering data available.',
                        description: _firstCareSection('watering') ?? 'No watering guide available yet.',
                        imageUrl: imageUrl,
                        localImageFile: localImageFile,
                      ),
                      _buildCareTab(
                        title: 'Sunlight needs',
                        subtitle: sunlight.isNotEmpty ? sunlight.join(', ') : 'No sunlight data available.',
                        description: _firstCareSection('sunlight') ?? 'No sunlight guide available yet.',
                        imageUrl: imageUrl,
                        localImageFile: localImageFile,
                      ),
                      _buildCareTab(
                        title: 'Temperature range',
                        subtitle: tempRange ?? 'No temperature range available.',
                        description: _details?['description'] as String? ?? 'No temperature guidance available yet.',
                        imageUrl: imageUrl,
                        localImageFile: localImageFile,
                      ),
                      _buildCareTab(
                        title: 'Fertilizing tips',
                        subtitle: _details?['care_level'] as String? ?? 'No fertilizing data available.',
                        description: _firstCareSection('fertilizing') ?? 'No fertilizing guide available yet.',
                        imageUrl: imageUrl,
                        localImageFile: localImageFile,
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildCareTab({
    required String title,
    required String subtitle,
    required String description,
    String? imageUrl,
    File? localImageFile,
  }) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (localImageFile != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(
              localImageFile,
              height: 200,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _imageFallback(200),
            ),
          )
        else if (imageUrl != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              imageUrl,
              height: 200,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _imageFallback(200),
            ),
          )
        else
          _imageFallback(200),
        const SizedBox(height: 16),
        if (widget.city != null)
          Row(
            children: [
              const Icon(Icons.place, color: Colors.green),
              const SizedBox(width: 8),
              Text(widget.city!, style: GoogleFonts.inter(color: Colors.grey)),
            ],
          ),
        const SizedBox(height: 16),
        Text(title, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(subtitle, style: GoogleFonts.inter(color: const Color(0xFF228B22), fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        Text(description, style: GoogleFonts.inter(height: 1.5)),
      ],
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
    if (!file.existsSync()) {
      return null;
    }
    return file;
  }

  Widget _imageFallback(double height) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E8),
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.image, size: 48, color: Color(0xFF228B22)),
    );
  }
}
