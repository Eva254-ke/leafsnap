import 'dart:io';

import 'package:flutter/material.dart';

import '../../../components/app_header.dart';
import '../../../services/perenual_api.dart';
import '../../../services/plant_store.dart';
import '../../../services/plantnet_api.dart';
import '../../my_plants/my_plants_screen.dart';
import '../diagnose/diagnose_history_screen.dart';
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

class _PlantResultScreenState extends State<PlantResultScreen> {
  final PerenualApi _perenualApi = PerenualApi();
  final PlantNetApi _plantNetApi = PlantNetApi();
  static final PlantStore _store = PlantStore();

  bool _isLoadingPlantInfo = false;
  bool _isLoadingIssues = false;
  String? _plantInfoError;
  String? _issuesError;
  PerenualSpeciesSummary? _match;
  Map<String, dynamic>? _details;
  List<PerenualCareSection> _careSections = <PerenualCareSection>[];
  List<PlantNetDiseaseMatch> _diseaseMatches = <PlantNetDiseaseMatch>[];

  @override
  void initState() {
    super.initState();
    if (widget.errorMessage == null) {
      _loadPlantInfo();
      _loadPlantProblems();
    }
  }

  Future<void> _loadPlantInfo() async {
    setState(() {
      _isLoadingPlantInfo = true;
      _plantInfoError = null;
    });

    try {
      final results = await _perenualApi.searchSpecies(
        query: widget.scientificName,
        page: 1,
      );
      if (results.isEmpty) {
        if (!mounted) {
          return;
        }
        setState(() {
          _plantInfoError =
              'No reference details found for ${widget.scientificName}.';
        });
        return;
      }

      final match = results.first;
      final details = await _perenualApi.getSpeciesDetails(match.id);
      final care = await _perenualApi.getCareGuides(speciesId: match.id);

      if (!mounted) {
        return;
      }
      setState(() {
        _match = match;
        _details = details;
        _careSections = care;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _plantInfoError = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPlantInfo = false;
        });
      }
    }
  }

  Future<void> _loadPlantProblems() async {
    setState(() {
      _isLoadingIssues = true;
      _issuesError = null;
    });

    try {
      final response = await _plantNetApi.identifyDiseases(
        images: <File>[widget.imageFile],
        organs: const <String>['auto'],
        language: 'en',
      );
      final matches = _plantNetApi
          .parseDiseaseMatches(response)
          .where((item) => item.score >= 0.05)
          .take(3)
          .toList();

      if (!mounted) {
        return;
      }
      setState(() {
        _diseaseMatches = matches;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _issuesError = 'Issue scan is unavailable right now.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingIssues = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final confidence = (widget.score * 100).clamp(0, 100).toStringAsFixed(1);
    final referenceImageUrl =
        _match?.imageUrl ??
        _match?.thumbnailUrl ??
        _firstPlantNetImage(widget.plantNetMatches);
    final displayName =
        _match?.commonName ??
        (widget.plantNetMatches.isNotEmpty
            ? widget.plantNetMatches.first.displayName
            : widget.scientificName);
    final watering = _details?['watering'] as String?;
    final sunlight = (_details?['sunlight'] as List<dynamic>? ?? <dynamic>[])
        .map((item) => item.toString())
        .toList();
    final sunlightGuide = _firstCareSection('sunlight');
    final wateringGuide = _firstCareSection('watering');
    final similarMatches = widget.plantNetMatches.length > 1
        ? widget.plantNetMatches.skip(1).take(3).toList()
        : widget.plantNetMatches.take(1).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF0FFF4),
      appBar: const AppHeader(title: 'Result'),
      body: Column(
        children: <Widget>[
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: <Widget>[
                _buildCapturedImage(),
                const SizedBox(height: 20),
                Text(
                  widget.scientificName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Confidence: $confidence%',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF228B22),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                _buildToolSummaryCard(),
                if (widget.errorMessage != null) ...<Widget>[
                  const SizedBox(height: 16),
                  Text(
                    widget.errorMessage!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ] else ...<Widget>[
                  const SizedBox(height: 20),
                  _buildSectionTitle(
                    _referenceSectionTitle(),
                    _referenceSectionSubtitle(),
                  ),
                  const SizedBox(height: 12),
                  if (_isLoadingPlantInfo)
                    const Center(child: CircularProgressIndicator())
                  else
                    _buildReferenceCard(
                      displayName: displayName,
                      scientificName: widget.scientificName,
                      imageUrl: referenceImageUrl,
                      watering: watering,
                      sunlight: sunlight,
                      sunlightGuide: sunlightGuide,
                      wateringGuide: wateringGuide,
                      errorText: _plantInfoError,
                    ),
                  if (similarMatches.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 24),
                    _buildSectionTitle(
                      'Similar plant matches',
                      'Additional matches from the same photo, with their own reference images.',
                    ),
                    const SizedBox(height: 12),
                    ...similarMatches.map(_buildSimilarPlantCard),
                  ],
                  const SizedBox(height: 24),
                  _buildSectionTitle(
                    _issueSectionTitle(),
                    _issueSectionSubtitle(),
                  ),
                  const SizedBox(height: 12),
                  if (_isLoadingIssues)
                    const Center(child: CircularProgressIndicator())
                  else if (_diseaseMatches.isNotEmpty)
                    ..._diseaseMatches.map(_buildIssueCard)
                  else
                    _buildInfoCard(
                      _issuesError ??
                          'No strong issue signal was detected from this photo.',
                    ),
                ],
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: widget.errorMessage != null
                          ? null
                          : () async {
                              await _store.saveToMyPlants(
                                scientificName: widget.scientificName,
                                score: widget.score,
                                commonName: _match?.commonName,
                                commonNames: _match == null
                                    ? null
                                    : <String>[_match!.commonName],
                                imageFile: widget.imageFile,
                                referenceImageUrl: referenceImageUrl,
                              );
                              if (!context.mounted) {
                                return;
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Saved to My Plants.'),
                                ),
                              );
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  settings: const RouteSettings(name: 'My Plants'),
                                  builder: (_) => const MyPlantsScreen(),
                                ),
                              );
                            },
                      icon: const Icon(Icons.favorite),
                      label: const Text('Save to My Plants'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF228B22),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            settings: const RouteSettings(name: 'Diagnose History'),
                            builder: (_) => const DiagnoseHistoryScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.history),
                      label: const Text('View History'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF228B22),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        side: const BorderSide(color: Color(0xFF228B22)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
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
    );
  }

  Widget _buildCapturedImage() {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Colors.black12, blurRadius: 10),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.file(widget.imageFile, fit: BoxFit.cover),
      ),
    );
  }

  Widget _buildToolSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: widget.selectedTool.supportTint),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  widget.selectedTool.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: widget.selectedTool.supportTint,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  widget.selectedTool.supportBadgeLabel,
                  style: TextStyle(
                    color: widget.selectedTool.supportColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            widget.selectedTool.supportTitle,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF243525),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.selectedTool.plantNetNote,
            style: const TextStyle(color: Color(0xFF516052), height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildReferenceCard({
    required String displayName,
    required String scientificName,
    required String? imageUrl,
    required String? watering,
    required List<String> sunlight,
    required String? sunlightGuide,
    required String? wateringGuide,
    required String? errorText,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Colors.black12, blurRadius: 6),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _buildNetworkImage(
              imageUrl: imageUrl,
              width: double.infinity,
              height: 180,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            displayName,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            scientificName,
            style: const TextStyle(
              color: Colors.grey,
              fontStyle: FontStyle.italic,
              fontSize: 14,
            ),
          ),
          if (watering != null || sunlight.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                if (watering != null)
                  _buildMetaChip(
                    Icons.water_drop_outlined,
                    'Watering: $watering',
                  ),
                if (sunlight.isNotEmpty)
                  _buildMetaChip(
                    Icons.wb_sunny_outlined,
                    'Sunlight: ${sunlight.join(', ')}',
                  ),
              ],
            ),
          ],
          if (sunlightGuide != null) ...<Widget>[
            const SizedBox(height: 12),
            Text(sunlightGuide, maxLines: 3, overflow: TextOverflow.ellipsis),
          ],
          if (wateringGuide != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(wateringGuide, maxLines: 3, overflow: TextOverflow.ellipsis),
          ],
          if (errorText != null && errorText.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Text(errorText, style: const TextStyle(color: Colors.red)),
          ],
        ],
      ),
    );
  }

  Widget _buildSimilarPlantCard(PlantNetPlantMatch match) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E0E0)),
        boxShadow: <BoxShadow>[
          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _buildNetworkImage(
              imageUrl: match.imageUrl,
              width: double.infinity,
              height: 140,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            match.displayName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            match.scientificName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.grey,
              fontStyle: FontStyle.italic,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF7EF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Match: ${(match.score * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(
                    color: Color(0xFF228B22),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIssueCard(PlantNetDiseaseMatch match) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: _buildNetworkImage(
              imageUrl: match.imageUrl,
              width: 72,
              height: 72,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        match.code,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(match.score * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(
                        color: Color(0xFFE67E22),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  match.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaChip(IconData icon, String label) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width - 72,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF7EF),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 16, color: const Color(0xFF228B22)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }

  Widget _buildInfoCard(String message) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Text(message, style: const TextStyle(color: Color(0xFF516052))),
    );
  }

  Widget _buildNetworkImage({
    required String? imageUrl,
    required double width,
    required double height,
  }) {
    if (!_hasUsableImageUrl(imageUrl)) {
      return _imagePlaceholder(width: width, height: height);
    }

    return Image.network(
      imageUrl!.trim(),
      width: width,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) =>
          _imagePlaceholder(width: width, height: height),
    );
  }

  Widget _imagePlaceholder({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      color: const Color(0xFFE8F5E8),
      child: const Icon(Icons.image, color: Color(0xFF228B22)),
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

  String? _firstPlantNetImage(List<PlantNetPlantMatch> matches) {
    for (final match in matches) {
      final imageUrl = match.imageUrl;
      if (_hasUsableImageUrl(imageUrl)) {
        return imageUrl;
      }
    }
    return null;
  }

  bool _hasUsableImageUrl(String? value) {
    final normalized = value?.trim();
    return normalized != null && normalized.isNotEmpty;
  }

  String _referenceSectionTitle() {
    switch (widget.selectedTool.id) {
      case CameraToolId.waterCalc:
        return 'Plant behind this watering guide';
      case CameraToolId.plantAdvisor:
        return 'Plant behind this care advice';
      case CameraToolId.repotChecker:
        return 'Plant behind this repot check';
      case CameraToolId.treeId:
        return 'Identified tree';
      case CameraToolId.insectId:
        return 'Likely host plant';
      default:
        return 'Identified plant';
    }
  }

  String _referenceSectionSubtitle() {
    switch (widget.selectedTool.id) {
      case CameraToolId.waterCalc:
        return 'We identify the plant first, then use its stored watering guidance as a starting point.';
      case CameraToolId.plantAdvisor:
        return 'We identify the plant first, then surface the strongest care notes available in the app.';
      case CameraToolId.repotChecker:
        return 'Species details help, but a real repot check still needs pot size, roots, and growth context.';
      case CameraToolId.treeId:
        return 'Reference image and care notes for the tree match from your scan.';
      case CameraToolId.insectId:
        return 'When possible, we identify the plant first so the pest clues make more sense.';
      default:
        return 'Reference image and care notes for the match from your scan.';
    }
  }

  String _issueSectionTitle() {
    if (widget.selectedTool.id == CameraToolId.insectId) {
      return 'Possible pests or plant damage';
    }
    return 'Possible plant problems';
  }

  String _issueSectionSubtitle() {
    if (widget.selectedTool.id == CameraToolId.insectId) {
      return 'These hints work best when the insect, pest damage, or symptoms are visible on the plant.';
    }
    return 'Photo-based issue hints. Treat these as suggestions, not a final diagnosis.';
  }
}
