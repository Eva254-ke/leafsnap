
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class DetectionResult {
  final String className;
  final double confidence;
  final Rect boundingBox; // Normalized (0.0 to 1.0)
  
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

class DiseaseDetectionService {
  static final DiseaseDetectionService _instance = DiseaseDetectionService._internal();
  factory DiseaseDetectionService() => _instance;
  DiseaseDetectionService._internal();

  Interpreter? _interpreter;
  List<String> _labels = [];
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Load TFLite model
      _interpreter = await Interpreter.fromAsset('assets/models/leafsnap_disease_v1.tflite');
      
      // Load labels
      final labelsData = await rootBundle.loadString('assets/models/labels.txt');
      _labels = labelsData.split('\n').map((line) {
        final parts = line.split(':');
        return parts.length > 1 ? parts[1].trim() : parts[0].trim();
      }).where((label) => label.isNotEmpty).toList();
      
      _isInitialized = true;
      debugPrint('DiseaseDetectionService initialized with ${_labels.length} classes');
    } catch (e) {
      debugPrint('Failed to initialize DiseaseDetectionService: $e');
      rethrow;
    }
  }

  Future<List<DetectionResult>> detectDiseases(File imageFile) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (_interpreter == null || _labels.isEmpty) {
      throw Exception('Model not initialized');
    }

    // 1. Load and preprocess image
    final imageBytes = await imageFile.readAsBytes();
    final originalImage = img.decodeImage(imageBytes);
    
    if (originalImage == null) {
      throw Exception('Failed to decode image');
    }

    // 2. Resize to 224x224
    final resizedImage = img.copyResize(
      originalImage,
      width: 224,
      height: 224,
      interpolation: img.Interpolation.linear,
    );

    // 3. Convert to Float32List with normalization [-1, 1] for MobileNetV3
    final input = Float32List(1 * 224 * 224 * 3);
    var pixelIndex = 0;
    
    for (var y = 0; y < 224; y++) {
      for (var x = 0; x < 224; x++) {
        final pixel = resizedImage.getPixel(x, y);
        
        // Extract RGB using image v4 API (pixel.r, pixel.g, pixel.b)
        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();
        
        // MobileNetV3 preprocessing: (pixel / 127.5) - 1.0
        input[pixelIndex++] = (r / 127.5) - 1.0;
        input[pixelIndex++] = (g / 127.5) - 1.0;
        input[pixelIndex++] = (b / 127.5) - 1.0;
      }
    }

    // 4. Reshape input for TFLite: [1, 224, 224, 3]
    final inputReshaped = input.reshape([1, 224, 224, 3]);

    // 5. Run inference
    final output = List.filled(1 * _labels.length, 0.0).reshape([1, _labels.length]);
    _interpreter!.run(inputReshaped, output);

    // 6. Parse results
    final probabilities = output[0] as List<double>;
    final detections = <DetectionResult>[];

    // Find top prediction
    double maxConfidence = 0.0;
    int maxIndex = 0;
    
    for (var i = 0; i < probabilities.length; i++) {
      if (probabilities[i] > maxConfidence) {
        maxConfidence = probabilities[i];
        maxIndex = i;
      }
    }

    // Confidence threshold: only return if > 60% confident
    if (maxConfidence >= 0.60) {
      detections.add(DetectionResult(
        className: _labels[maxIndex],
        confidence: maxConfidence,
        // Default bounding box covering most of the image
        boundingBox: const Rect.fromLTRB(0.15, 0.1, 0.85, 0.9),
      ));
    }

    return detections;
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
  }
}