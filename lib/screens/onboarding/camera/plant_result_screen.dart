import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:share_plus/share_plus.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import '../../../components/remote_config_ui.dart';
import '../../../services/ambee_soil_api.dart';
import '../../../services/api_error.dart';
import '../../../services/location_permission_service.dart';
import '../../../services/perenual_api.dart';
import '../../../services/plantnet_api.dart';
import 'camera_screen.dart';
import 'camera_tools.dart';

// ============================================================================
// DETECTION RESULT MODEL
// ============================================================================
class DetectionResult {
  final String className;
  final double confidence;
  final Rect boundingBox;

  DetectionResult({
    required this.className,
    required this.confidence,
    required this.boundingBox,
  });

  bool get isHealthy => className.toLowerCase().contains('healthy');

  String get formattedName {
    return className
        .replaceAll('___', ' - ')
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        }).join(' ');
  }
}

// ============================================================================
// DISEASE OVERLAY PAINTER
// ============================================================================
class DiseaseOverlayPainter extends CustomPainter {
  final List<DetectionResult> detections;
  final Size? imageSize;

  DiseaseOverlayPainter({
    required this.detections,
    required this.imageSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (detections.isEmpty) return;

    final sourceSize = imageSize;
    final Rect paintedImageRect;

    if (sourceSize == null || sourceSize.width <= 0 || sourceSize.height <= 0) {
      paintedImageRect = Offset.zero & size;
    } else {
      final fitted = applyBoxFit(BoxFit.cover, sourceSize, size);
      final dx = (size.width - fitted.destination.width) / 2;
      final dy = (size.height - fitted.destination.height) / 2;
      paintedImageRect = Offset(dx, dy) & fitted.destination;
    }

    for (final detection in detections) {
      final left = paintedImageRect.left + detection.boundingBox.left * paintedImageRect.width;
      final top = paintedImageRect.top + detection.boundingBox.top * paintedImageRect.height;
      final right = paintedImageRect.left + detection.boundingBox.right * paintedImageRect.width;
      final bottom = paintedImageRect.top + detection.boundingBox.bottom * paintedImageRect.height;

      final rect = Rect.fromLTRB(left, top, right, bottom);

      canvas.drawRect(rect, Paint()..color = const Color(0xFFE95555).withValues(alpha: 0.15));
      canvas.drawRect(
        rect,
        Paint()
          ..color = const Color(0xFFE95555)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );

      final labelText = '${detection.formattedName} ${(detection.confidence * 100).toStringAsFixed(0)}%';
      final textPainter = TextPainter(
        text: TextSpan(
          text: labelText,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
      textPainter.layout();

      final labelPadding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4);
      final labelSize = Size(
        textPainter.width + labelPadding.horizontal,
        textPainter.height + labelPadding.vertical,
      );

      final labelTop = rect.top - labelSize.height - 4 < 6
          ? rect.top + 6
          : rect.top - labelSize.height - 4;

      final labelRect = Rect.fromLTWH(
        rect.left,
        labelTop,
        labelSize.width,
        labelSize.height,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(labelRect, const Radius.circular(6)),
        Paint()..color = const Color(0xFFE95555),
      );

      textPainter.paint(
        canvas,
        Offset(labelRect.left + labelPadding.left, labelRect.top + labelPadding.top),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ============================================================================
// MAIN SCREEN
// ============================================================================
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

  // Hardcoded fallback images for common plants
  static const Map<String, String> _fallbackPlantImages = {
    'Tomato': 'https://images.unsplash.com/photo-1592924357228-91a4daadcfea?w=400&h=300&fit=crop',
    'Spinach': 'https://media.istockphoto.com/id/477028180/photo/sliverbeet-grow-in-vegetable-garden.jpg?s=612x612&w=0&k=20&c=w3NUQmdUTE5idrgVqn101GoHTwwjBqf6QGnvTvqtgHs=',
    'Maize': 'https://www.grantthornton.in/globalassets/1.-member-firms/india/assets/pdf-images/554x544px/photograph/554x544px_website_photographs_641.jpg',
    'Beans': 'https://www.thespruce.com/thmb/cSsyLW4TIiQg0o4rk0wNdXzWrMM=/3564x2477/filters:no_upscale():max_bytes(150000):strip_icc()/GettyImages-1820512381-5bec11bf46e0fb0026b2d89c.jpg',
    'Kale': 'https://tse4.mm.bing.net/th/id/OIP.XfJY39qYuB4mZ8nC2FQD3gHaEz?rs=1&pid=ImgDetMain&o=7&rm=3',
    'Cabbage': 'https://tse1.mm.bing.net/th/id/OIP.5ATExUzSl3XqRjWJn9KebQHaFq?w=570&h=436&rs=1&pid=ImgDetMain&o=7&rm=3',
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

  final PerenualApi _perenualApi = PerenualApi();
  final AmbeeSoilApi _soilApi = AmbeeSoilApi();

  bool _isLoadingPlantInfo = false;
  String? _plantInfoError;
  PerenualSpeciesSummary? _match;
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
  final bool _isSavingToGarden = false;
  final bool _savedToGarden = false;

  int _heroImagePage = 0;

  // TFLite Detection State
  Interpreter? _interpreter;
  List<String> _labels = [];
  List<DetectionResult> _detections = [];
  DetectionResult? _localDiagnosis;
  bool _isLoadingDetections = false;
  bool _healthModelInDomain = true;
  bool _localDiagnosisUncertain = false;
  Size? _analysisImageSize;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initializeLocalDiagnosis();
    if (widget.errorMessage == null) {
      _loadData();
    }
  }

  Future<void> _initializeLocalDiagnosis() async {
    await _loadModel();
    await _runTFLiteDetection();
  }

  Future<void> _loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/models/leafsnap_disease_v1.tflite');
      final labelsData = await rootBundle.loadString('assets/models/labels.txt');
      _labels = labelsData.split('\n').map((line) {
        final parts = line.split(':');
        return parts.length > 1 ? parts[1].trim() : parts[0].trim();
      }).where((label) => label.isNotEmpty).toList();
    } catch (e) {
      debugPrint('[TFLite] Failed to load model: $e');
    }
  }

  @override
  void dispose() {
    _interpreter?.close();
    _tts.stop();
    _tabController.dispose();
    super.dispose();
  }

  // ============================================================================
  // DYNAMIC API DATA FETCHING
  // ============================================================================
  Future<void> _loadData() async {
    setState(() {
      _isLoadingPlantInfo = true;
      _plantInfoError = null;
    });

    Object? plantInfoError;

    try {
      final results = await _perenualApi
          .searchSpecies(query: widget.scientificName, page: 1)
          .timeout(const Duration(seconds: 10));

      if (results.isNotEmpty) {
        final match = results.first;
        final careGuides = await _perenualApi.getCareGuides(
          speciesId: match.id,
          types: const ['sunlight', 'watering', 'fertilizing'],
        ).timeout(
          const Duration(seconds: 8),
          onTimeout: () => <PerenualCareSection>[],
        );

        if (!mounted) return;
        setState(() {
          _match = match;
          _careSections = careGuides;
        });
      } else {
        plantInfoError = 'No reference details found for ${widget.scientificName}.';
      }
    } catch (e) {
      plantInfoError = e;
    }

    if (!mounted) return;
    setState(() {
      _diseaseMatches = const <PlantNetDiseaseMatch>[];
      if (plantInfoError != null) {
        _plantInfoError = _formatError(plantInfoError);
      }
      _isLoadingPlantInfo = false;
    });
  }

  String _formatError(Object error) {
    if (error is String) return error;
    if (error is TimeoutException) return 'Request timed out. Please check your connection.';
    if (error is ApiRateLimitException) return 'Service is busy. Please try again later.';
    if (error is ApiUnavailableException) return error.message ?? 'Service temporarily unavailable.';
    final errorStr = error.toString();
    return errorStr.length > 150 ? errorStr.substring(0, 150) : errorStr;
  }

  // ============================================================================
  // TFLITE DETECTION LOGIC
  // ============================================================================
  Future<void> _runTFLiteDetection() async {
    if (_interpreter == null || _labels.isEmpty) return;

    setState(() => _isLoadingDetections = true);

    try {
      final imageBytes = await widget.imageFile.readAsBytes();
      final originalImage = img.decodeImage(imageBytes);
      if (originalImage == null) throw Exception('Failed to decode image');

      if (mounted) {
        setState(() {
          _analysisImageSize = Size(
            originalImage.width.toDouble(),
            originalImage.height.toDouble(),
          );
        });
      }

      final resizedImage = img.copyResize(
        originalImage,
        width: 224,
        height: 224,
        interpolation: img.Interpolation.linear,
      );

      final input = Float32List(1 * 224 * 224 * 3);
      var pixelIndex = 0;
      for (var y = 0; y < 224; y++) {
        for (var x = 0; x < 224; x++) {
          final pixel = resizedImage.getPixel(x, y);
          input[pixelIndex++] = (pixel.r.toInt() / 127.5) - 1.0;
          input[pixelIndex++] = (pixel.g.toInt() / 127.5) - 1.0;
          input[pixelIndex++] = (pixel.b.toInt() / 127.5) - 1.0;
        }
      }

      final output = List.filled(1 * _labels.length, 0.0).reshape([1, _labels.length]);
      _interpreter!.run(input.reshape([1, 224, 224, 3]), output);

      final probabilities = output[0] as List<double>;
      double maxConfidence = 0.0;
      int maxIndex = 0;
      for (var i = 0; i < probabilities.length; i++) {
        if (probabilities[i] > maxConfidence) {
          maxConfidence = probabilities[i];
          maxIndex = i;
        }
      }

      final topLabel = _labels[maxIndex];
      final diagnosis = DetectionResult(
        className: topLabel,
        confidence: maxConfidence,
        boundingBox: Rect.zero,
      );

      final inDomain = _isHealthModelInDomain(topLabel);
      final isHealthy = topLabel.toLowerCase().contains('healthy');
      final isConfident = maxConfidence >= 0.50;
      final detections = <DetectionResult>[];

      if (inDomain && isConfident && !isHealthy) {
        final sickSpots = _findSickSpots(originalImage);
        if (sickSpots.isNotEmpty) {
          for (final spot in sickSpots) {
            detections.add(DetectionResult(
              className: topLabel,
              confidence: maxConfidence,
              boundingBox: spot,
            ));
          }
        } else {
          detections.add(DetectionResult(
            className: topLabel,
            confidence: maxConfidence,
            boundingBox: const Rect.fromLTRB(0.2, 0.2, 0.8, 0.8),
          ));
        }
      }

      if (mounted) {
        setState(() {
          _localDiagnosis = diagnosis;
          _healthModelInDomain = inDomain;
          _localDiagnosisUncertain = !isConfident;
          _detections = detections;
          _isLoadingDetections = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingDetections = false);
    }
  }

  bool _isHealthModelInDomain(String label) {
    final normalizedLabel = label.toLowerCase();
    final haystack = '${widget.scientificName} $_displayName $_alsoKnownAsText'.toLowerCase();
    if (haystack.contains('unknown')) return true;

    const supportedTerms = <String, List<String>>{
      'apple': ['apple', 'malus'],
      'blueberry': ['blueberry', 'vaccinium'],
      'cherry': ['cherry', 'prunus'],
      'corn': ['corn', 'maize', 'zea mays'],
      'grape': ['grape', 'vitis'],
      'orange': ['orange', 'citrus'],
      'peach': ['peach', 'prunus persica'],
      'pepper': ['pepper', 'capsicum'],
      'potato': ['potato', 'solanum tuberosum'],
      'raspberry': ['raspberry', 'rubus'],
      'soybean': ['soybean', 'glycine max'],
      'squash': ['squash', 'cucurbita'],
      'strawberry': ['strawberry', 'fragaria'],
      'tomato': ['tomato', 'solanum lycopersicum'],
    };

    for (final entry in supportedTerms.entries) {
      if (!normalizedLabel.contains(entry.key)) continue;
      return entry.value.any(haystack.contains);
    }
    return false;
  }

  List<Rect> _findSickSpots(img.Image image) {
    final maxDimension = image.width > image.height ? image.width : image.height;
    final analysisImage = maxDimension > 720
        ? img.copyResize(
            image,
            width: image.width >= image.height ? 720 : null,
            height: image.height > image.width ? 720 : null,
            interpolation: img.Interpolation.average,
          )
        : image;

    final spots = <_SymptomRegion>[];
    final width = analysisImage.width;
    final height = analysisImage.height;
    final totalPixels = width * height;

    final sickPixels = List<bool>.filled(totalPixels, false);
    var sickCount = 0;

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final pixel = analysisImage.getPixel(x, y);
        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();

        final maxChannel = r > g ? (r > b ? r : b) : (g > b ? g : b);
        final minChannel = r < g ? (r < b ? r : b) : (g < b ? g : b);
        final spread = maxChannel - minChannel;
        final brightness = (r + g + b) / 3;

        final isYellowSpot = r > 115 && g > 100 && b < 150 && (r - b) > 32 && (g - b) > 18;
        final isChloroticYellow = r > 135 && g > 135 && b < 125 && (r + g - (2 * b)) > 80;
        final isBrownNecrosis = r > 70 && g > 42 && b < 105 && r >= g && (r - b) > 24 && brightness < 170;
        final isDarkNecrosis = brightness < 92 && spread > 18 && r < 135 && g < 135 && b < 135;
        final isReddishSpot = r > 135 && g < 125 && b < 115 && (r - g) > 30;

        final isSick = isYellowSpot || isChloroticYellow || isBrownNecrosis || isDarkNecrosis || isReddishSpot;

        final index = y * width + x;
        sickPixels[index] = isSick;
        if (isSick) sickCount++;
      }
    }

    final sickPercentage = (sickCount / totalPixels) * 100;
    if (sickPercentage < 0.03) return const <Rect>[];

    final visited = List<bool>.filled(totalPixels, false);
    final minSize = ((totalPixels * 0.00015).round()).clamp(18, 160).toInt();
    final maxSize = (totalPixels * 0.45).round();
    const padding = 0.025;

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final start = y * width + x;
        if (!sickPixels[start] || visited[start]) continue;

        final stack = <int>[start];
        var size = 0;
        var minX = width;
        var maxX = 0;
        var minY = height;
        var maxY = 0;

        while (stack.isNotEmpty) {
          final current = stack.removeLast();
          if (visited[current] || !sickPixels[current]) continue;
          visited[current] = true;
          size++;

          final cx = current % width;
          final cy = current ~/ width;

          if (cx < minX) minX = cx;
          if (cx > maxX) maxX = cx;
          if (cy < minY) minY = cy;
          if (cy > maxY) maxY = cy;

          for (var dy = -1; dy <= 1; dy++) {
            for (var dx = -1; dx <= 1; dx++) {
              if (dx == 0 && dy == 0) continue;
              final nx = cx + dx;
              final ny = cy + dy;
              if (nx < 0 || nx >= width || ny < 0 || ny >= height) continue;
              final next = ny * width + nx;
              if (sickPixels[next] && !visited[next]) stack.add(next);
            }
          }
        }

        if (size < minSize || size > maxSize) continue;
        final boxWidth = maxX - minX + 1;
        final boxHeight = maxY - minY + 1;
        if (boxWidth < 4 || boxHeight < 4) continue;

        final rect = Rect.fromLTRB(
          (minX / width - padding).clamp(0.0, 1.0),
          (minY / height - padding).clamp(0.0, 1.0),
          ((maxX + 1) / width + padding).clamp(0.0, 1.0),
          ((maxY + 1) / height + padding).clamp(0.0, 1.0),
        );
        spots.add(_SymptomRegion(rect: rect, pixelCount: size));
      }
    }

    spots.sort((a, b) => b.pixelCount.compareTo(a.pixelCount));
    return spots.take(6).map((spot) => spot.rect).toList();
  }

  // ============================================================================
  // BUILD METHOD
  // ============================================================================
  @override
  Widget build(BuildContext context) {
    final referenceImageUrl = _match?.imageUrl ?? _firstPlantNetImage(widget.plantNetMatches);
    final displayName = _displayName;
    final scientificName = _scientificName;
    final confidence = (widget.score * 100).clamp(0, 100).toStringAsFixed(1);
    final bestProblem = _bestProblem;
    final isSick = bestProblem != null || _detections.isNotEmpty;
    final galleryImages = _heroGalleryImages(referenceImageUrl, bestProblem);

    return RemoteConfigBuilder(
      screenId: RemoteConfigScreens.plantResult,
      fallbackBackgroundColor: _background,
      fallbackPrimaryColor: _primary,
      builder: (context, remoteConfig) {
        return Scaffold(
          backgroundColor: remoteConfig.backgroundColor,
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
    final currentPage = imageCount == 0 ? 0 : _heroImagePage.clamp(0, imageCount - 1);

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
                          color: index == currentPage ? Colors.white : Colors.white.withValues(alpha: 0.52),
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
    Widget imageWidget;
    if (image.file != null) {
      imageWidget = Image.file(
        image.file!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    } else {
      final url = image.url;
      if (url == null || url.trim().isEmpty) {
        imageWidget = Image.file(
          widget.imageFile,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        );
      } else {
        imageWidget = Image.network(
          url,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              color: _primaryLight,
              child: const Center(
                child: CircularProgressIndicator(color: _primary),
              ),
            );
          },
          errorBuilder: (_, _, _) => Image.file(
            widget.imageFile,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
        );
      }
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        imageWidget,
        if (_detections.isNotEmpty && image.file?.path == widget.imageFile.path)
          CustomPaint(
            size: Size.infinite,
            painter: DiseaseOverlayPainter(
              detections: _detections,
              imageSize: _analysisImageSize,
            ),
          ),
        if (_isLoadingDetections)
          Container(
            color: Colors.black26,
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 12),
                  Text(
                    'Analyzing plant health...',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildOverviewTab({required bool isSick, required PlantNetDiseaseMatch? bestProblem}) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      children: [
        if (_isLoadingDetections)
          _loadingCard()
        else if (!_healthModelInDomain)
          _healthUnavailableCard()
        else if (_localDiagnosisUncertain)
          _uncertainHealthCard()
        else if (_localDiagnosis != null && !_localDiagnosis!.isHealthy)
          _localDiagnosisCard(_localDiagnosis!)
        else if (_localDiagnosis != null && _localDiagnosis!.isHealthy)
          _healthyCard(_localDiagnosis!)
        else if (widget.errorMessage != null)
          _errorCard(widget.errorMessage!)
        else if (isSick && bestProblem != null)
          _sickPlantCard(bestProblem)
        else if (!_shouldRunIssueScan || _diseaseMatches.isEmpty)
          _healthyCard(null),
        const SizedBox(height: 20),
        _sectionTitle('Basic Info'),
        _basicInfoCard(),
      ],
    );
  }

  Widget _localDiagnosisCard(DetectionResult detection) {
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
                      'Possible plant disease detected',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _error,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${detection.formattedName} - ${(detection.confidence * 100).toStringAsFixed(0)}% confidence',
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
          const SizedBox(height: 14),
          Text(
            _detections.length == 1
                ? 'The highlighted area is an estimated visible symptom region from your photo.'
                : 'The highlighted areas are estimated visible symptom regions from your photo.',
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.4,
              color: _textSecondary,
            ),
          ),
          const SizedBox(height: 16),
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
                'View Care Guidance',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
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
                separatorBuilder: (_, _) => const SizedBox(width: 10),
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
                            errorBuilder: (_, _, _) => Image.file(
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

  Widget _healthUnavailableCard() {
    return _statusCard(
      icon: Icons.info_outline_rounded,
      color: _textSecondary,
      background: const Color(0xFFF7F8F7),
      borderColor: _border,
      title: 'Health model not available for this plant yet',
      message: 'The offline disease model currently covers specific common crops. Please use the dynamic care guide below for this plant.',
    );
  }

  Widget _uncertainHealthCard() {
    final diagnosis = _localDiagnosis;
    final message = diagnosis == null
        ? 'Try a closer crop of the affected leaf in natural light.'
        : 'The closest local model match was ${diagnosis.formattedName} at ${(diagnosis.confidence * 100).toStringAsFixed(0)}%, which is below the launch confidence threshold. Try a closer crop of the affected area.';
    return _statusCard(
      icon: Icons.help_outline_rounded,
      color: const Color(0xFFB7791F),
      background: const Color(0xFFFFFAEB),
      borderColor: const Color(0xFFE8C36A),
      title: 'Health result is uncertain',
      message: message,
    );
  }

  Widget _healthyCard(DetectionResult? diagnosis) {
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
              diagnosis == null
                  ? 'No issues detected in this scan.'
                  : 'Plant looks healthy - ${(diagnosis.confidence * 100).toStringAsFixed(0)}% confidence.',
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

  Widget _statusCard({
    required IconData icon,
    required Color color,
    required Color background,
    required Color borderColor,
    required String title,
    required String message,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    height: 1.4,
                    color: _textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
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

  // ============================================================================
  // 100% DYNAMIC CARE TAB (API-DRIVEN) - FIXED
  // ============================================================================
  Widget _buildCareTab() {
    if (_isLoadingPlantInfo) {
      return const Center(child: CircularProgressIndicator(color: _primary));
    }

    return RefreshIndicator(
      color: _primary,
      backgroundColor: _surface,
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
        children: [
          if (_localDiagnosis != null && !_localDiagnosis!.isHealthy) ...[
            _buildDiseaseSpecificCareCard(_localDiagnosis!),
            const SizedBox(height: 28),
          ],
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Personalized Care Guide',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Tailored instructions based on $_displayName\'s specific needs.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: _textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_careSections.isEmpty)
            _buildEmptyCareState()
          else
            ..._careSections.map((section) => _buildProfessionalCareCard(section)),
          if (_plantInfoError != null) ...[
            const SizedBox(height: 16),
            _errorCard(_plantInfoError!),
          ],
        ],
      ),
    );
  }

  Widget _buildProfessionalCareCard(PerenualCareSection section) {
    final type = section.type.toLowerCase();
    final icon = _getCareIcon(type);
    final title = _getCareTitle(type);
    final color = _getCareColor(type);
    
    String cleanDescription = section.description.trim();
    if (cleanDescription.isEmpty) {
      cleanDescription = 'No specific instructions available for this care aspect.';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withValues(alpha: 0.12), color.withValues(alpha: 0.02)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Text(
              cleanDescription,
              style: GoogleFonts.inter(
                fontSize: 14.5,
                color: _textSecondary,
                height: 1.55,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCareState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Icon(Icons.eco_outlined, size: 48, color: _textTertiary),
          const SizedBox(height: 16),
          Text(
            'Care Guide Unavailable',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We couldn\'t fetch specific care instructions for this plant right now. Please check back later.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: _textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCareIcon(String type) {
    if (type.contains('water')) return Icons.water_drop_rounded;
    if (type.contains('sun') || type.contains('light')) return Icons.wb_sunny_rounded;
    if (type.contains('fertil') || type.contains('feed')) return Icons.science_rounded;
    return Icons.eco_rounded;
  }

  String _getCareTitle(String type) {
    if (type.contains('water')) return 'Watering Guide';
    if (type.contains('sun') || type.contains('light')) return 'Sunlight & Placement';
    if (type.contains('fertil') || type.contains('feed')) return 'Fertilizing Schedule';
    return 'General Care';
  }

  Color _getCareColor(String type) {
    if (type.contains('water')) return const Color(0xFF2196F3);
    if (type.contains('sun') || type.contains('light')) return const Color(0xFFFF9800);
    if (type.contains('fertil') || type.contains('feed')) return const Color(0xFF4CAF50);
    return _primary;
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
        _sectionTitle(snapshot?.hasLiveSoilData == true ? 'Live Soil Reading' : 'Soil Care Guide'),
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
                value: moisturePercent == null ? '--' : '${moisturePercent.toStringAsFixed(0)}%',
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
              _soilMetricTile(icon: Icons.water_drop_rounded, label: 'Moisture', value: 'Top soil'),
              _soilMetricTile(icon: Icons.grain_rounded, label: 'Drainage', value: 'Light'),
              _soilMetricTile(icon: Icons.thermostat_rounded, label: 'Root Zone', value: '18-29C'),
              _soilMetricTile(icon: Icons.compost_rounded, label: 'Feeding', value: 'Gentle'),
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

    if (items.length <= 1) return const SizedBox.shrink();

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
              separatorBuilder: (_, _) => const SizedBox(width: 10),
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
      errorBuilder: (_, _, _) => Image.file(
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
                        color: isIssue ? _errorLight : isScan ? _background : _primaryLight,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        item.label,
                        style: GoogleFonts.inter(
                          color: isIssue ? _error : isScan ? _textPrimary : _primary,
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

      final permission = await LocationPermissionService.checkAndRequestIfNeeded();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
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
    if (error is StateError) return error.message;
    if (isRateLimitError(error)) return 'Live soil data is busy, so showing a care-based soil guide.';
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
        'Identified with Chlora\n'
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
    if (perenualName != null) return perenualName;

    for (final match in widget.plantNetMatches) {
      for (final name in match.commonNames) {
        final englishName = _englishNameOrNull(name);
        if (englishName != null) return englishName;
      }
    }

    final localNames = _localNames[widget.scientificName.toLowerCase()] ?? const [];
    for (final name in localNames.reversed) {
      final englishName = _englishNameOrNull(name);
      if (englishName != null) return englishName;
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
    if (name == null || name.isEmpty || name.toLowerCase() == 'unknown') return null;

    const nonEnglishLocalNames = {
      'nyanya', 'mahindi', 'maharagwe', 'kitunguu', 'kabichi',
      'spinachi', 'pilipili hoho', 'ndizi', 'muhogo', 'viazi',
    };
    if (nonEnglishLocalNames.contains(name.toLowerCase())) return null;

    return name;
  }

  // Fallback image logic for plants without API images
  String? _fallbackImageUrlForPlant(String plantName) {
    final normalizedName = plantName.toLowerCase().trim();
    if (normalizedName.isEmpty) return null;

    for (final entry in _fallbackPlantImages.entries) {
      if (normalizedName.contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }
    return null;
  }

  bool _prefersCuratedImage(String plantName) {
    final normalizedName = plantName.toLowerCase();
    return normalizedName.contains('spinach') ||
        normalizedName.contains('spinacia oleracea') ||
        normalizedName.contains('cabbage') ||
        normalizedName.contains('onion');
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
      if (url == null || url.isEmpty || !seenUrls.add(url)) return;
      images.add(_ResultGalleryImage.network(url, label: label));
    }

    // For spinach, prefer the hardcoded fallback image as the primary reference
    final plantName = _displayName.toLowerCase();
    if (plantName.contains('spinach') || plantName.contains('spinacia oleracea')) {
      final fallbackUrl = _fallbackImageUrlForPlant(_displayName);
      if (fallbackUrl != null && !seenUrls.contains(fallbackUrl)) {
        // Add fallback image as the FIRST reference (after user scan)
        images.insert(1, _ResultGalleryImage.network(fallbackUrl, label: 'Spinach reference'));
      }
      // Skip API reference for spinach to ensure fallback is used
      return images.take(4).toList();
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

  Widget _buildDiseaseSpecificCareCard(DetectionResult detection) {
    final treatmentSteps = _getTreatmentSteps(detection.className);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_errorLight, _errorLight.withValues(alpha: 0.6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _error.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: _error.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _error.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.medical_services_rounded, color: _error, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Treatment Plan',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _error.withValues(alpha: 0.8),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detection.formattedName,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...treatmentSteps.asMap().entries.map((e) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    margin: const EdgeInsets.only(right: 12, top: 1),
                    decoration: BoxDecoration(
                      color: _error.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${e.key + 1}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: _error,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      e.value,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: _textPrimary,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  List<String> _getTreatmentSteps(String diseaseName) {
    final normalized = diseaseName.toLowerCase();
    if (normalized.contains('tomato')) {
      // Skip hardcoded treatment for tomato-related detections
      return [];
    }
    if (normalized.contains('bacterial')) {
      return [
        'Remove affected leaves immediately and dispose in trash (not compost)',
        'Improve air circulation around plant',
        'Water at soil level, avoid wetting leaves',
        'Apply copper-based bactericide if spreading',
      ];
    }
    if (normalized.contains('blight') || normalized.contains('late blight')) {
      return [
        'Remove all affected foliage immediately',
        'Increase spacing between plants for airflow',
        'Apply preventive fungicide every 7-10 days',
        'Water only at base of plant, never on leaves',
      ];
    }
    if (normalized.contains('powdery mildew')) {
      return [
        'Spray with neem oil or baking soda solution (1 tsp per quart water)',
        'Improve air circulation and reduce humidity',
        'Remove affected leaves in dry weather',
        'Apply weekly until symptoms disappear',
      ];
    }
    if (normalized.contains('leaf spot')) {
      return [
        'Remove spotted leaves and destroy them',
        'Water at soil level to keep foliage dry',
        'Apply fungicide containing chlorothalonil',
        'Ensure good drainage around plant base',
      ];
    }
    if (normalized.contains('rust')) {
      return [
        'Remove affected leaves in dry conditions',
        'Improve air circulation significantly',
        'Apply sulfur-based fungicide',
        'Avoid overhead watering completely',
      ];
    }
    return [
      'Remove and dispose of affected plant parts',
      'Improve air circulation around the plant',
      'Adjust watering to keep leaves dry',
      'Consider organic fungicide if symptoms persist',
    ];
  }

  String _getExpandedDescription(String title) {
    switch (title) {
      case 'Toxicity to Humans':
        return 'Please verify with local agricultural guidelines, as toxicity can vary by species and preparation.';
      case 'Toxicity to Pets':
        return 'Always consult a veterinarian before allowing pets to interact with unfamiliar plants.';
      case 'Weed Potential':
        return 'Check local invasive species lists to ensure this plant is safe for your region.';
      case 'Distribution':
        return 'Distribution varies by species. Refer to the map above for general habitat information.';
      default:
        return '';
    }
  }

  PlantProfile _resultProfile(String scientific, String display) {
    return const PlantProfile(
      humanToxicity: 'Consult local guidelines',
      petToxicity: 'Consult a veterinarian',
      weedPotential: 'Check local lists',
      distribution: 'See map for details',
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
                  disabledBackgroundColor: _savedToGarden ? const Color(0xFF177A50) : _primary,
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
}

// ============================================================================
// HELPER CLASSES & WIDGETS
// ============================================================================
class _SymptomRegion {
  const _SymptomRegion({required this.rect, required this.pixelCount});
  final Rect rect;
  final int pixelCount;
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
                  errorBuilder: (_, _, _) => const Center(
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