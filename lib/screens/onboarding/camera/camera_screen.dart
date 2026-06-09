import 'dart:math' as math;
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../services/api_error.dart';
import '../../../services/billing_service.dart';
import '../../../services/plantnet_api.dart';
import '../../../services/scan_limit_service.dart';
import '../../premium/premium_paywall_screen.dart';
import 'camera_tools.dart';
import 'plant_result_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key, this.initialToolId});

  final CameraToolId? initialToolId;

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  final ImagePicker _picker = ImagePicker();
  final PlantNetApi _api = PlantNetApi();
  final ScanLimitService _scanLimitService = ScanLimitService();
  late CameraToolDefinition _selectedTool;

  List<CameraDescription> _cameras = [];
  CameraController? _controller;
  CameraDescription? _activeCamera;
  int _cameraIndex = 0;
  bool _isFlashOn = false;
  bool _isSettingUpCamera = false;
  bool _isPickingImage = false;

  File? _image;
  bool _isLoading = false;
  int _analysisStepIndex = 0;
  String? _error;
  String _selectedFocus = 'auto';

  static const List<_FocusPart> _focusParts = [
    _FocusPart('auto', 'Auto', Icons.auto_awesome_rounded),
    _FocusPart('leaf', 'Leaf', Icons.eco_rounded),
    _FocusPart('flower', 'Flower', Icons.local_florist_rounded),
    _FocusPart('fruit', 'Fruit', Icons.spa_rounded),
    _FocusPart('bark', 'Bark', Icons.forest_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _selectedTool = cameraToolById(widget.initialToolId);
    WidgetsBinding.instance.addObserver(this);
    _setupCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final controller = _controller;
    _controller = null;
    controller?.dispose().catchError((_) {});
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) {
      return;
    }

    switch (state) {
      case AppLifecycleState.resumed:
        _restoreCameraIfNeeded();
        break;
      // inactive & hidden are transient — the image picker triggers
      // inactive but the camera should survive. Only paused/detached
      // means we've genuinely left the screen.
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        if (!_isPickingImage) {
          _disposeCameraController();
        }
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        break;
    }
  }

  Future<void> _setupCamera() async {
    if (_isSettingUpCamera) {
      return;
    }

    try {
      final hasPermission = await _ensureCameraPermission();
      if (!hasPermission) {
        return;
      }
      final cameras = await availableCameras();
      if (!mounted) {
        return;
      }
      setState(() {
        _cameras = cameras;
      });
      if (cameras.isNotEmpty) {
        final preferredCamera = _preferredCamera(cameras);
        await _initController(preferredCamera);
      } else {
        setState(() {
          _error = 'No camera was found on this device. You can still identify from gallery.';
        });
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = _cameraErrorMessage(error);
      });
    }
  }

  Future<bool> _ensureCameraPermission() async {
    var status = await Permission.camera.status;
    if (status.isDenied) {
      status = await Permission.camera.request();
    }

    if (!mounted) {
      return false;
    }

    if (status.isGranted || status.isLimited) {
      return true;
    }

    setState(() {
      _error = status.isPermanentlyDenied || status.isRestricted
          ? 'Camera access is blocked. Enable it in settings, or choose a photo from gallery.'
          : 'Camera permission is needed to scan a plant. You can choose a photo from gallery.';
    });
    return false;
  }

  CameraDescription _preferredCamera(List<CameraDescription> cameras) {
    if (_activeCamera != null && cameras.contains(_activeCamera)) {
      return _activeCamera!;
    }
    for (final camera in cameras) {
      if (camera.lensDirection == CameraLensDirection.back) {
        return camera;
      }
    }
    return cameras.first;
  }

  String _cameraErrorMessage(Object error) {
    if (error is CameraException) {
      switch (error.code) {
        case 'CameraAccessDenied':
        case 'CameraAccessDeniedWithoutPrompt':
          return 'Camera permission was denied. Enable it in settings, or choose a photo from gallery.';
        case 'CameraAccessRestricted':
          return 'Camera access is restricted on this device.';
        case 'CameraInUse':
          return 'The camera is being used by another app. Close it and try again.';
        default:
          return 'Camera unavailable. Try again, or choose a photo from gallery.';
      }
    }
    return 'Camera unavailable. Try again, or choose a photo from gallery.';
  }

  Future<void> _disposeCameraController() async {
    final controller = _controller;
    if (controller == null) {
      return;
    }

    _controller = null;
    if (mounted) {
      setState(() {});
    }
    try {
      await controller.dispose();
    } catch (_) {
      // CameraX can throw if Flutter tears down a preview while it is still
      // negotiating a surface. The controller is already detached from UI.
    }
  }

  Future<void> _initController(CameraDescription description) async {
    if (_isSettingUpCamera) {
      return;
    }

    _isSettingUpCamera = true;
    await _disposeCameraController();

    final controller = CameraController(
      description,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await controller.initialize();
      await controller.setFlashMode(FlashMode.off);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _activeCamera = description;
        _cameraIndex = _cameras.indexOf(description);
        _isFlashOn = false;
        _error = null;
      });
    } catch (error) {
      try {
        await controller.dispose();
      } catch (_) {
        // Ignore secondary dispose errors after an initialization failure.
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _error = _cameraErrorMessage(error);
      });
    } finally {
      _isSettingUpCamera = false;
    }
  }

  Future<void> _restoreCameraIfNeeded() async {
    if (_isLoading || _image != null || _isSettingUpCamera) {
      return;
    }
    if (_controller != null && _controller!.value.isInitialized) {
      return;
    }
    if (_cameras.isEmpty) {
      await _setupCamera();
      return;
    }

    final description =
        _activeCamera ??
        (_cameraIndex >= 0 && _cameraIndex < _cameras.length
            ? _cameras[_cameraIndex]
            : _cameras.first);
    await _initController(description);
  }

  Future<void> _captureImage() async {
    if (!_selectedTool.isRunnable) {
      _showToolUnavailable();
      return;
    }
    if (_isLoading || _isSettingUpCamera) {
      return;
    }
    if (_controller == null || !_controller!.value.isInitialized) {
      setState(() {
        _error = 'Preparing camera...';
      });
      await _restoreCameraIfNeeded();
      if (!mounted) {
        return;
      }
    }
    if (_controller == null || !_controller!.value.isInitialized) {
      setState(() {
        _error = 'Camera is not ready. Try again, or choose a photo from gallery.';
      });
      return;
    }
    if (_controller!.value.isTakingPicture) {
      return;
    }

    try {
      setState(() {
        _error = null;
      });
      final file = await _controller!.takePicture();
      if (!mounted) {
        return;
      }
      setState(() {
        _image = File(file.path);
        _selectedFocus = 'auto';
      });
      await _disposeCameraController();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Failed to capture photo.';
      });
    }
  }

  Future<void> _pickFromGallery() async {
    await _pickImage(ImageSource.gallery);
  }

  Future<void> _pickImage(ImageSource source) async {
    if (!_selectedTool.isRunnable) {
      _showToolUnavailable();
      return;
    }
    if (_isLoading || _isPickingImage) {
      return;
    }

    setState(() {
      _error = null;
    });

    XFile? picked;
    _isPickingImage = true;
    try {
      picked = await _picker.pickImage(
        source: source,
        imageQuality: 76,
        maxWidth: 1280,
      );
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.code == 'already_active'
            ? 'Photo picker is already open.'
            : 'Could not open photo picker. Try again.';
      });
      return;
    } finally {
      _isPickingImage = false;
    }

    final pickedFile = picked;
    if (pickedFile == null) {
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _image = File(pickedFile.path);
      _selectedFocus = 'auto';
    });
  }

  Future<void> _toggleFlash() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      return;
    }
    try {
      final newMode = _isFlashOn ? FlashMode.off : FlashMode.torch;
      await _controller!.setFlashMode(newMode);
      if (!mounted) {
        return;
      }
      setState(() {
        _isFlashOn = !_isFlashOn;
      });
    } catch (_) {
      // Ignore flash failures on devices without flash.
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 || _isSettingUpCamera || _isLoading) {
      return;
    }
    final nextIndex = (_cameraIndex + 1) % _cameras.length;
    await _initController(_cameras[nextIndex]);
  }

  Future<void> _identifyPlant() async {
    final selectedImage = _image;
    if (selectedImage == null) {
      setState(() {
        _error = 'Capture a photo first.';
      });
      return;
    }

    final isPremium = BillingService.instance.isPremium.value;
    final canScan = isPremium || await _scanLimitService.canScan();
    if (!canScan) {
      await _openPaywall(
        headline: 'Upgrade to keep scanning',
        subhead: 'You have used today\'s free scans. Go premium to continue.',
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Upgrade to keep scanning.';
        _image = null;
        _isLoading = false;
      });
      await _restoreCameraIfNeeded();
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
      _analysisStepIndex = 0;
    });

    try {
      final stepProgress = _runAnalysisSteps();
      final response = await _api.identify(
        images: [selectedImage],
        organs: [_selectedFocus],
        project: 'all',
        language: 'en',
        includeRelatedImages: true,
      );
      await stepProgress;
      if (!isPremium) {
        await _scanLimitService.recordScan();
      }

      final results = response['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) {
        if (!mounted) {
          return;
        }
        await _openResultScreen(
          PlantResultScreen(
            imageFile: selectedImage,
            scientificName: 'Unknown',
            score: 0,
            errorMessage: 'No matches returned.',
            selectedTool: _selectedTool,
          ),
        );
      } else {
        final top = results.first as Map<String, dynamic>;
        final species = top['species'] as Map<String, dynamic>?;
        final name = species?['scientificNameWithoutAuthor'] as String? ?? 'Unknown';
        final score = top['score'] as num? ?? 0;
        final plantMatches = _api.parsePlantMatches(response);
        if (!mounted) {
          return;
        }
        await _openResultScreen(
          PlantResultScreen(
            imageFile: selectedImage,
            scientificName: name,
            score: score.toDouble(),
            plantNetMatches: plantMatches,
            selectedTool: _selectedTool,
          ),
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      debugPrint('Plant identification failed: $error');
      await _logIdentificationDiagnostics();
      final message = _scanFailureMessage(error);
      await _openResultScreen(
        PlantResultScreen(
          imageFile: selectedImage,
          scientificName: 'Unknown',
          score: 0,
          errorMessage: message,
          selectedTool: _selectedTool,
        ),
      );
      if (!mounted) {
        return;
      }
      if (isRateLimitError(error)) {
        setState(() {
          _error = message;
        });
      } else {
        setState(() {
          _error = message;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _logIdentificationDiagnostics() async {}

  String _scanFailureMessage(Object error) {
    if (isRateLimitError(error)) {
      return 'Plant identification is busy right now. Please try again later.';
    }
    if (error is ApiUnavailableException) {
      return 'LeafSnap AI identification is temporarily unavailable. Please try again soon.';
    }
    if (isNetworkApiError(error)) {
      return 'LeafSnap AI could not reach the identification service. Check your connection and try again.';
    }
    if (error is HttpException) {
      return 'LeafSnap AI had trouble identifying this photo. Try again with a clear leaf, flower, fruit, or bark shot.';
    }
    if (error is FormatException) {
      return 'LeafSnap AI received an unexpected identification response. Please try again.';
    }
    return 'We could not complete the scan. Try again with a clearer plant photo.';
  }

  Future<void> _openPaywall({String? headline, String? subhead}) async {
    await _disposeCameraController();
    if (!mounted) {
      return;
    }

    final scansUsed = await _scanLimitService.getScanCount();
    if (!mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'Premium Paywall'),
        builder: (_) => PremiumPaywallScreen(
          headline: headline,
          subhead: subhead,
          scansUsed: scansUsed,
          scanLimit: ScanLimitService.scanLimit,
        ),
      ),
    );

    if (!mounted) {
      return;
    }
    await _restoreCameraIfNeeded();
  }

  Future<void> _openResultScreen(PlantResultScreen screen) async {
    await _disposeCameraController();
    if (!mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        settings: RouteSettings(name: screen.runtimeType.toString()),
        builder: (_) => screen,
      ),
    );
    if (!mounted) {
      return;
    }

    setState(() {
      _image = null;
      _error = null;
      _analysisStepIndex = 0;
      _isLoading = false;
    });
    await _restoreCameraIfNeeded();
  }

  Future<void> _runAnalysisSteps() async {
    final steps = _selectedTool.analysisSteps;
    for (var i = 0; i < steps.length; i++) {
      if (!mounted) {
        return;
      }
      setState(() {
        _analysisStepIndex = i;
      });
      await Future.delayed(const Duration(milliseconds: 320));
    }
  }

  void _showToolUnavailable() {
    final message = _selectedTool.unavailableMessage;
    setState(() {
      _error = message;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _scanReviewedImage() async {
    if (_image == null) {
      setState(() {
        _error = 'Capture or choose a photo first.';
      });
      return;
    }
    await _identifyPlant();
  }

  Future<void> _retakePhoto() async {
    setState(() {
      _image = null;
      _error = null;
      _selectedFocus = 'auto';
    });
    await _restoreCameraIfNeeded();
  }

  Future<void> _cropImageToGuide() async {
    final image = _image;
    if (image == null || _isLoading) {
      return;
    }

    final croppedFile = await Navigator.of(context).push<File>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _CropImageScreen(imageFile: image),
      ),
    );

    if (!mounted || croppedFile == null) {
      return;
    }

    setState(() {
      _image = croppedFile;
      _error = null;
    });
  }

  static Future<File> _writeCroppedImage({
    required File originalFile,
    required Rect sourceRect,
  }) async {
    final bytes = await originalFile.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final source = frame.image;
    final safeRect = sourceRect
        .intersect(Rect.fromLTWH(0, 0, source.width.toDouble(), source.height.toDouble()));
    final outputSide = math.min(safeRect.width, safeRect.height).round().clamp(1, 1600);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImageRect(
      source,
      safeRect,
      Rect.fromLTWH(0, 0, outputSide.toDouble(), outputSide.toDouble()),
      Paint(),
    );
    final picture = recorder.endRecording();
    final cropped = await picture.toImage(outputSide, outputSide);
    final data = await cropped.toByteData(format: ui.ImageByteFormat.png);
    source.dispose();
    cropped.dispose();

    if (data == null) {
      throw StateError('Could not encode cropped image.');
    }

    final path =
        '${originalFile.parent.path}${Platform.pathSeparator}leafsnap_crop_${DateTime.now().millisecondsSinceEpoch}.png';
    return File(path).writeAsBytes(data.buffer.asUint8List());
  }

  @override
  Widget build(BuildContext context) {
    final steps = _selectedTool.analysisSteps;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0D0F),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: _image == null
                  ? (_controller == null || !_controller!.value.isInitialized
                      ? _cameraPlaceholder()
                      : CameraPreview(_controller!))
                  : Image.file(_image!, fit: BoxFit.cover),
            ),
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xAA000000), Color(0x00000000), Color(0xCC000000)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  _topIconButton(Icons.close, () => Navigator.of(context).maybePop()),
                  const Spacer(),
                  _topIconButton(Icons.help_outline, () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(_selectedTool.helpText)),
                    );
                  }),
                  const SizedBox(width: 12),
                  _topIconButton(_isFlashOn ? Icons.flash_on : Icons.flash_off, _toggleFlash),
                  const SizedBox(width: 12),
                  _topIconButton(Icons.cameraswitch, _switchCamera),
                ],
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 240,
                    height: 240,
                    child: Stack(
                      children: [
                        _corner(Alignment.topLeft),
                        _corner(Alignment.topRight),
                        _corner(Alignment.bottomLeft),
                        _corner(Alignment.bottomRight),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _selectedTool.cameraTitle,
                    style: GoogleFonts.playfairDisplay(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 280,
                    child: Text(
                      _selectedTool.cameraHint,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
                decoration: const BoxDecoration(
                  color: Color(0xFF0B0D0F),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _selectedTool.title,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (_selectedTool.requiresPremium) _accessBadge(_selectedTool),
                      ],
                    ),
                    if (_image == null) ...[
                      const SizedBox(height: 40),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _galleryButton(),
                          _shutterButton(),
                          _hintBadge(),
                        ],
                      ),
                    ] else ...[
                      const SizedBox(height: 10),
                      Text(
                        'Confirm the plant part to focus before scanning.',
                        style: GoogleFonts.inter(
                          color: Colors.white70,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _focusPartSelector(),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isLoading ? null : _retakePhoto,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Retake'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white38),
                                padding: const EdgeInsets.symmetric(vertical: 13),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isLoading ? null : _cropImageToGuide,
                              icon: const Icon(Icons.crop_rounded),
                              label: const Text('Crop'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white38),
                                padding: const EdgeInsets.symmetric(vertical: 13),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _isLoading ? null : _scanReviewedImage,
                              icon: const Icon(Icons.search_rounded),
                              label: const Text('Scan'),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF1F7A3F),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 13),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: const TextStyle(color: Color(0xFFFF6B6B)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (_isLoading)
              Positioned.fill(
                child: Container(
                  color: const Color(0xCC0B0D0F),
                  child: Center(
                    child: Container(
                      width: 280,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF121815),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 16)],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Analyzing',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          for (var i = 0; i < steps.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  Icon(
                                    i <= _analysisStepIndex ? Icons.check_circle : Icons.radio_button_unchecked,
                                    color: i <= _analysisStepIndex ? const Color(0xFF48C774) : Colors.white38,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    steps[i],
                                    style: const TextStyle(color: Colors.white70),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _cameraPlaceholder() {
    final message = _error;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0B0D0F), Color(0xFF0F1A12)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 96, 28, 180),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isSettingUpCamera || message == null) ...[
                const CircularProgressIndicator(color: Color(0xFF48C774)),
                const SizedBox(height: 18),
                Text(
                  'Opening camera...',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ] else ...[
                const Icon(
                  Icons.camera_alt_outlined,
                  color: Colors.white70,
                  size: 38,
                ),
                const SizedBox(height: 14),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _isLoading ? null : _setupCamera,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Try Again'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _pickFromGallery,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Gallery'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1F7A3F),
                        foregroundColor: Colors.white,
                      ),
                    ),
                    if (message.toLowerCase().contains('settings'))
                      TextButton(
                        onPressed: _isLoading ? null : openAppSettings,
                        child: const Text('Open Settings'),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _topIconButton(IconData icon, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0x66000000),
        borderRadius: BorderRadius.circular(14),
      ),
      child: IconButton(
        onPressed: _isLoading ? null : onPressed,
        icon: Icon(icon, color: Colors.white),
      ),
    );
  }

  Widget _corner(Alignment alignment) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          border: Border(
            top: alignment.y < 0 ? const BorderSide(color: Colors.white, width: 3) : BorderSide.none,
            bottom: alignment.y > 0 ? const BorderSide(color: Colors.white, width: 3) : BorderSide.none,
            left: alignment.x < 0 ? const BorderSide(color: Colors.white, width: 3) : BorderSide.none,
            right: alignment.x > 0 ? const BorderSide(color: Colors.white, width: 3) : BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _accessBadge(CameraToolDefinition tool) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tool.accessTint,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        tool.accessBadgeLabel,
        style: GoogleFonts.inter(
          color: tool.accessColor,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _galleryButton() {
    return GestureDetector(
      onTap: _isLoading || !_selectedTool.isRunnable ? null : _pickFromGallery,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1F1C),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2D3A33)),
        ),
        child: _image == null
            ? const Icon(Icons.photo_library, color: Colors.white70)
            : ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.file(_image!, fit: BoxFit.cover),
              ),
      ),
    );
  }

  Widget _shutterButton() {
    return GestureDetector(
      onTap: _isLoading || !_selectedTool.isRunnable ? null : _captureImage,
      child: Container(
        width: 78,
        height: 78,
        decoration: BoxDecoration(
          color: _selectedTool.isRunnable
              ? const Color(0xFF1F7A3F)
              : const Color(0xFF4E3A50),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _selectedTool.isRunnable
                  ? const Color(0x6629B866)
                  : const Color(0x664E3A50),
              blurRadius: 18,
            ),
          ],
        ),
        child: Center(
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: const Color(0xFF0B0D0F),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
            ),
          ),
        ),
      ),
    );
  }

  Widget _hintBadge() {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F1C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2D3A33)),
      ),
      child: Icon(
        _selectedTool.isRunnable ? Icons.info_outline : Icons.block_outlined,
        color: Colors.white70,
      ),
    );
  }

  Widget _focusPartSelector() {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _focusParts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final part = _focusParts[index];
          final selected = part.organ == _selectedFocus;
          return ChoiceChip(
            selected: selected,
            onSelected: (_) => setState(() => _selectedFocus = part.organ),
            avatar: Icon(
              part.icon,
              size: 17,
              color: selected ? Colors.white : Colors.white70,
            ),
            label: Text(part.label),
            labelStyle: GoogleFonts.inter(
              color: selected ? Colors.white : Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
            selectedColor: const Color(0xFF1F7A3F),
            backgroundColor: const Color(0xFF1A1F1C),
            side: BorderSide(
              color: selected ? const Color(0xFF56D889) : const Color(0xFF2D3A33),
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          );
        },
      ),
    );
  }
}

class _FocusPart {
  const _FocusPart(this.organ, this.label, this.icon);

  final String organ;
  final String label;
  final IconData icon;
}

class _CropImageScreen extends StatefulWidget {
  const _CropImageScreen({required this.imageFile});

  final File imageFile;

  @override
  State<_CropImageScreen> createState() => _CropImageScreenState();
}

class _CropImageScreenState extends State<_CropImageScreen> {
  final TransformationController _controller = TransformationController();
  Future<ui.Image>? _imageFuture;
  bool _initialized = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _imageFuture = _decodeImage();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<ui.Image> _decodeImage() async {
    final bytes = await widget.imageFile.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  void _setInitialTransform({
    required double cropSide,
    required double displayWidth,
    required double displayHeight,
  }) {
    if (_initialized) {
      return;
    }
    _initialized = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _controller.value = Matrix4.identity()
        ..translate(
          (cropSide - displayWidth) / 2,
          (cropSide - displayHeight) / 2,
        );
    });
  }

  Future<void> _applyCrop({
    required ui.Image image,
    required double cropSide,
    required double displayScale,
  }) async {
    if (_isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final inverse = Matrix4.inverted(_controller.value);
      final topLeft = MatrixUtils.transformPoint(inverse, Offset.zero);
      final bottomRight = MatrixUtils.transformPoint(
        inverse,
        Offset(cropSide, cropSide),
      );
      final childRect = Rect.fromPoints(topLeft, bottomRight);
      final sourceRect = Rect.fromLTRB(
        childRect.left / displayScale,
        childRect.top / displayScale,
        childRect.right / displayScale,
        childRect.bottom / displayScale,
      ).intersect(
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      );

      if (sourceRect.width < 8 || sourceRect.height < 8) {
        throw StateError('Crop area is too small.');
      }

      final cropped = await _CameraScreenState._writeCroppedImage(
        originalFile: widget.imageFile,
        sourceRect: sourceRect,
      );

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(cropped);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adjust the crop area and try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0D0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0D0F),
        foregroundColor: Colors.white,
        title: Text(
          'Crop scan area',
          style: GoogleFonts.inter(fontWeight: FontWeight.w800),
        ),
      ),
      body: FutureBuilder<ui.Image>(
        future: _imageFuture,
        builder: (context, snapshot) {
          final image = snapshot.data;
          if (image == null) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF48C774)),
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final cropSide = math.min(
                constraints.maxWidth - 32,
                constraints.maxHeight - 170,
              ).clamp(220.0, 420.0);
              final displayScale = math.max(
                cropSide / image.width,
                cropSide / image.height,
              );
              final displayWidth = image.width * displayScale;
              final displayHeight = image.height * displayScale;
              _setInitialTransform(
                cropSide: cropSide,
                displayWidth: displayWidth,
                displayHeight: displayHeight,
              );

              return SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 18),
                    Center(
                      child: Container(
                        width: cropSide,
                        height: cropSide,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            InteractiveViewer(
                              transformationController: _controller,
                              constrained: false,
                              minScale: 1,
                              maxScale: 5,
                              boundaryMargin: EdgeInsets.all(cropSide),
                              child: SizedBox(
                                width: displayWidth,
                                height: displayHeight,
                                child: Image.file(
                                  widget.imageFile,
                                  fit: BoxFit.fill,
                                ),
                              ),
                            ),
                            IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: const Color(0xFF48C774),
                                    width: 3,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'Pinch or drag until the leaf, flower, fruit, bark, or sick area fills the box.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: Colors.white70,
                          fontSize: 14,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white38),
                                padding: const EdgeInsets.symmetric(vertical: 15),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _isSaving
                                  ? null
                                  : () => _applyCrop(
                                        image: image,
                                        cropSide: cropSide,
                                        displayScale: displayScale,
                                      ),
                              icon: _isSaving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.check_rounded),
                              label: Text(_isSaving ? 'Saving...' : 'Apply Crop'),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF1F7A3F),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 15),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
