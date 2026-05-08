import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';

import '../../../services/plantnet_api.dart';
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
  late CameraToolDefinition _selectedTool;

  List<CameraDescription> _cameras = [];
  CameraController? _controller;
  CameraDescription? _activeCamera;
  int _cameraIndex = 0;
  bool _isFlashOn = false;
  bool _isSettingUpCamera = false;

  File? _image;
  bool _isLoading = false;
  int _analysisStepIndex = 0;
  String? _error;

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
    controller?.dispose();
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
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _disposeCameraController();
        break;
    }
  }

  Future<void> _setupCamera() async {
    if (_isSettingUpCamera) {
      return;
    }

    try {
      final cameras = await availableCameras();
      if (!mounted) {
        return;
      }
      setState(() {
        _cameras = cameras;
      });
      if (cameras.isNotEmpty) {
        final preferredCamera =
            _activeCamera != null && cameras.contains(_activeCamera)
            ? _activeCamera!
            : cameras.first;
        await _initController(preferredCamera);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Camera unavailable.';
      });
    }
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
    await controller.dispose();
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
      await controller.dispose();
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Camera unavailable.';
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
        _error = 'Camera not ready.';
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
      });
      await _identifyPlant();
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

    setState(() {
      _error = null;
    });

    final XFile? picked = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1600,
    );

    if (picked == null) {
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _image = File(picked.path);
    });

    await _identifyPlant();
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

    setState(() {
      _isLoading = true;
      _error = null;
      _analysisStepIndex = 0;
    });

    try {
      final stepProgress = _runAnalysisSteps();
      final response = await _api.identify(
        images: [selectedImage],
        organs: ['auto'],
        project: 'all',
        language: 'en',
      );
      await stepProgress;

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
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
      });
    }
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
      await Future.delayed(const Duration(milliseconds: 600));
    }
  }

  void _selectTool(CameraToolDefinition tool) {
    if (_isLoading) {
      return;
    }

    setState(() {
      _selectedTool = tool;
      _error = tool.isRunnable ? null : tool.unavailableMessage;
      _analysisStepIndex = 0;
    });
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
                      ? Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF0B0D0F), Color(0xFF0F1A12)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(color: Color(0xFF48C774)),
                          ),
                        )
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
                        _supportBadge(_selectedTool),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const SizedBox(height: 14),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _galleryButton(),
                        _shutterButton(),
                        _hintBadge(),
                      ],
                    ),
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

  Widget _toolRail({
    required String label,
    required List<CameraToolDefinition> tools,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.white54,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemBuilder: (context, index) => _toolChip(tools[index]),
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemCount: tools.length,
          ),
        ),
      ],
    );
  }

  Widget _toolChip(CameraToolDefinition tool) {
    final isSelected = tool.id == _selectedTool.id;
    final fillColor = isSelected ? tool.accentColor : const Color(0xFF1A1F1C);
    final borderColor = isSelected ? Colors.transparent : const Color(0xFF2D3A33);
    final textColor = isSelected ? Colors.white : Colors.white70;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: _isLoading ? null : () => _selectTool(tool),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(tool.icon, size: 16, color: textColor),
              const SizedBox(width: 6),
              Text(
                tool.title,
                style: GoogleFonts.inter(
                  color: textColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _supportBadge(CameraToolDefinition tool) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tool.supportTint,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        tool.supportBadgeLabel,
        style: GoogleFonts.inter(
          color: tool.supportColor,
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
}
