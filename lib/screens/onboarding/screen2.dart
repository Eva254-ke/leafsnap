import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

import 'shared.dart';
import '../../services/remote_config_service.dart';

class OnboardingScreen2 extends StatefulWidget {
  const OnboardingScreen2({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<OnboardingScreen2> createState() => _OnboardingScreen2State();
}

class _OnboardingScreen2State extends State<OnboardingScreen2>
    with TickerProviderStateMixin {
  Timer? _advanceTimer;
  Timer? _completeTimer;
  int _currentPage = 0;

  late final AnimationController _lottieController;
  String? _loadedAnimationAsset;

  late final AnimationController _eyebrowController;
  late final Animation<double> _eyebrowFade;
  late final Animation<Offset> _eyebrowSlide;

  late final AnimationController _titleController;
  late final Animation<double> _titleFade;
  late final Animation<Offset> _titleSlide;

  late final AnimationController _subtitleController;
  late final Animation<double> _subtitleFade;
  late final Animation<Offset> _subtitleSlide;

  // Pre-warm cache to ensure all animations load instantly
  final Map<String, LottieComposition> _lottieCache = {};
  final Set<String> _lottieSkipCacheAssets = {
    'assets/animations/growing_plants.json',
    'assets/animations/communication.json',
  };

  @override
  void initState() {
    super.initState();
    _setupControllers();
    _prewarmLottieAssets();
    _startSceneSequence();

    _completeTimer = Timer(
      const Duration(milliseconds: 14000),
      _completeOnboarding,
    );
  }

  void _setupControllers() {
    _lottieController = AnimationController(vsync: this);

    _eyebrowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _eyebrowFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _eyebrowController, curve: Curves.easeOutCubic),
    );
    _eyebrowSlide = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _eyebrowController, curve: Curves.easeOutCubic),
    );

    _titleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
    );
    _titleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _titleController, curve: Curves.easeOutCubic),
    );
    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.14),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _titleController, curve: Curves.easeOutCubic),
    );

    _subtitleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _subtitleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _subtitleController, curve: Curves.easeOutCubic),
    );
    _subtitleSlide = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _subtitleController, curve: Curves.easeOutCubic),
    );
  }

  // Pre-load all Lottie assets in background to guarantee instant playback
  Future<void> _prewarmLottieAssets() async {
    for (final scene in _scenes) {
      try {
        final byteData = await rootBundle.load(scene.animationAsset);
        final composition = await LottieComposition.fromByteData(byteData);
        _lottieCache[scene.animationAsset] = composition;
      } catch (_) {
        // Silently fail - Lottie.asset will handle loading as fallback
      }
    }
  }

  void _configureLottie(LottieComposition composition, String asset) {
    if (_loadedAnimationAsset == asset) return;
    _loadedAnimationAsset = asset;
    _lottieController
      ..duration = composition.duration
      ..repeat();
  }

  void _startSceneSequence() {
    if (!mounted) return;
    
    _eyebrowController.reset();
    _titleController.reset();
    _subtitleController.reset();

    // Staggered text entrance for cinematic feel
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _eyebrowController.forward();
    });
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) _titleController.forward();
    });
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) _subtitleController.forward();
    });

    _advanceTimer?.cancel();
    _advanceTimer = Timer(const Duration(milliseconds: 4500), _nextScene);
  }

  void _nextScene() async {
    if (_currentPage < _scenes.length - 1) {
      // Reverse text animations before transitioning
      await _subtitleController.reverse();
      await _titleController.reverse();
      await _eyebrowController.reverse();
      
      if (!mounted) return;
      
      setState(() => _currentPage++);
      
      // Subtle haptic feedback for emotional connection
      HapticFeedback.lightImpact();
      
      _startSceneSequence();
    }
  }

  void _completeOnboarding() {
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    _lottieController.stop();
    _advanceTimer?.cancel();
    _completeTimer?.cancel();
    widget.onComplete();
  }

  @override
  void dispose() {
    _advanceTimer?.cancel();
    _completeTimer?.cancel();
    _eyebrowController.dispose();
    _titleController.dispose();
    _subtitleController.dispose();
    _lottieController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final copy = RemoteConfigService.instance
        .getJson(RemoteConfigKeys.onboardingCopy);
    final scene = _scenes[_currentPage];
    
    final eyebrow = _resolveCopy(copy, scene.eyebrowKey, scene.fallbackEyebrow);
    final title = _resolveCopy(copy, scene.titleKey, scene.fallbackTitle);
    final subtitle = _resolveCopy(copy, scene.subtitleKey, scene.fallbackSubtitle);

    return Scaffold(
      body: _buildSceneBackground(
        scene,
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.xl,
              AppSpacing.lg,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxHeight < 720;
                final isTight = constraints.maxHeight < 680 ||
                    constraints.maxWidth < 360;
                final animationAlignment = isTight
                    ? (scene.animationAlignmentTight ?? scene.animationAlignment)
                    : scene.animationAlignment;
                final textWidth = constraints.maxWidth >= 420
                    ? 340.0
                    : constraints.maxWidth * 0.86;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Cinematic top progress indicator
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppSpacing.xs),
                        child: LinearProgressIndicator(
                          value: _calculateProgress(),
                          backgroundColor:
                              palette.surface.withValues(alpha: 0.15),
                          color: palette.primary,
                          minHeight: 3,
                        ),
                      ),
                    ),
                    const LeafSnapLogo(),
                    SizedBox(
                      height: isTight
                          ? AppSpacing.md
                          : (isCompact ? AppSpacing.lg : AppSpacing.xl),
                    ),
                    Expanded(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Lottie Animation - uses pre-warmed cache if available
                          AnimatedAlign(
                            duration: const Duration(milliseconds: 650),
                            curve: Curves.easeInOutCubic,
                            alignment: animationAlignment,
                            child: OverflowBox(
                              minWidth:
                                  constraints.maxWidth * scene.animationWidthFactor,
                              maxWidth:
                                  constraints.maxWidth * scene.animationWidthFactor,
                              child: SizedBox(
                                width: constraints.maxWidth *
                                    scene.animationWidthFactor,
                                child: AspectRatio(
                                  aspectRatio: scene.animationAspectRatio,
                                  child: RepaintBoundary(
                                    child: _buildLottieWidget(
                                      scene.animationAsset,
                                      isCompact,
                                      palette,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Text Block with staggered entrance animations
                          AnimatedAlign(
                            duration: const Duration(milliseconds: 650),
                            curve: Curves.easeInOutCubic,
                            alignment: scene.textCardAlignment,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: textWidth),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: scene.crossAxisAlignment,
                                children: [
                                  FadeTransition(
                                    opacity: _eyebrowFade,
                                    child: SlideTransition(
                                      position: _eyebrowSlide,
                                      child: Text(
                                        eyebrow.toUpperCase(),
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: palette.primary,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    height: isTight ? AppSpacing.md : AppSpacing.lg,
                                  ),
                                  FadeTransition(
                                    opacity: _titleFade,
                                    child: SlideTransition(
                                      position: _titleSlide,
                                      child: Text(
                                        title,
                                        textAlign: scene.textAlign,
                                        style: GoogleFonts.manrope(
                                          fontSize: isTight
                                              ? 26
                                              : (isCompact ? 30 : 34),
                                          fontWeight: FontWeight.w800,
                                          height: isTight ? 1.15 : 1.12,
                                          color: palette.textPrimary,
                                          letterSpacing: isTight ? -0.4 : -0.6,
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    height: isTight ? AppSpacing.sm : AppSpacing.md,
                                  ),
                                  FadeTransition(
                                    opacity: _subtitleFade,
                                    child: SlideTransition(
                                      position: _subtitleSlide,
                                      child: Text(
                                        subtitle,
                                        textAlign: scene.textAlign,
                                        style: GoogleFonts.inter(
                                          fontSize: isTight
                                              ? 13
                                              : (isCompact ? 15 : 16),
                                          fontWeight: FontWeight.w500,
                                          color: palette.textSecondary,
                                          height: isTight ? 1.45 : 1.5,
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
                    SizedBox(height: isCompact ? AppSpacing.lg : AppSpacing.xl),
                    // Bottom: Pagination dots only (no skip button)
                    Center(
                      child: OnboardingDots(
                        currentPage: _currentPage,
                        totalPages: _scenes.length,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // Calculate progress for the cinematic progress bar
  double _calculateProgress() {
    final sceneProgress = _advanceTimer != null ? 1.0 : 0.0;
    return (_currentPage + sceneProgress) / _scenes.length;
  }

  Widget _buildSceneBackground(_OnboardingScene scene, Widget child) {
    if (scene.animationAsset != 'assets/animations/maps.json') {
      return AmbientBackground(child: child);
    }

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFBFCFF),
            Color(0xFFF5F8FF),
          ],
        ),
      ),
      child: child,
    );
  }

  // Build Lottie widget with pre-warmed cache support
  Widget _buildLottieWidget(
    String asset,
    bool isCompact,
    AppPalette palette,
  ) {
    if (_lottieSkipCacheAssets.contains(asset)) {
      return Lottie.asset(
        asset,
        key: ValueKey('lottie_$asset'),
        controller: _lottieController,
        fit: BoxFit.contain,
        onLoaded: (composition) => _configureLottie(composition, asset),
        errorBuilder: (context, error, stackTrace) {
          return Container(
            decoration: BoxDecoration(
              color: palette.primarySoft,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: palette.outline),
            ),
            child: Icon(
              Icons.eco_rounded,
              size: isCompact ? 72 : 88,
              color: palette.primary,
            ),
          );
        },
      );
    }

    // Try to use pre-warmed composition for instant playback
    final cachedComposition = _lottieCache[asset];
    
    if (cachedComposition != null) {
      // Configure controller immediately for cached composition
      _configureLottie(cachedComposition, asset);
      return Lottie(
        composition: cachedComposition,
        controller: _lottieController,
        fit: BoxFit.contain,
        // Ensure animation restarts when scene changes
        key: ValueKey('lottie_$asset'),
      );
    }
    
    // Fallback: standard Lottie.asset with onLoaded callback
    return Lottie.asset(
      asset,
      key: ValueKey('lottie_$asset'),
      controller: _lottieController,
      fit: BoxFit.contain,
      onLoaded: (composition) => _configureLottie(composition, asset),
      errorBuilder: (context, error, stackTrace) {
        return Container(
          decoration: BoxDecoration(
            color: palette.primarySoft,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: palette.outline),
          ),
          child: Icon(
            Icons.eco_rounded,
            size: isCompact ? 72 : 88,
            color: palette.primary,
          ),
        );
      },
    );
  }
}

class _OnboardingScene {
  const _OnboardingScene({
    required this.titleKey,
    required this.subtitleKey,
    required this.eyebrowKey,
    required this.fallbackTitle,
    required this.fallbackSubtitle,
    required this.fallbackEyebrow,
    required this.textCardAlignment,
    required this.animationAlignment,
    this.animationAlignmentTight,
    required this.crossAxisAlignment,
    required this.textAlign,
    required this.animationWidthFactor,
    this.animationAspectRatio = 1,
    required this.animationAsset,
  });

  final String titleKey;
  final String subtitleKey;
  final String eyebrowKey;
  final String fallbackTitle;
  final String fallbackSubtitle;
  final String fallbackEyebrow;
  final Alignment textCardAlignment;
  final Alignment animationAlignment;
  final Alignment? animationAlignmentTight;
  final CrossAxisAlignment crossAxisAlignment;
  final TextAlign textAlign;
  final double animationWidthFactor;
  final double animationAspectRatio;
  final String animationAsset;
}

const List<_OnboardingScene> _scenes = [
  _OnboardingScene(
    eyebrowKey: 'scene1_eyebrow',
    titleKey: 'scene1_title',
    subtitleKey: 'scene1_subtitle',
    fallbackEyebrow: 'Discover',
    fallbackTitle: 'Every leaf tells\na story',
    fallbackSubtitle:
        'Point your camera and unlock the secrets of thousands of plants.',
    textCardAlignment: Alignment(0, 0.78),
    animationAlignment: Alignment(0, -0.24),
    animationAlignmentTight: Alignment(0, -0.34),
    crossAxisAlignment: CrossAxisAlignment.center,
    textAlign: TextAlign.center,
    animationWidthFactor: 0.78,
    animationAsset: 'assets/animations/plant.json',
  ),
  _OnboardingScene(
    eyebrowKey: 'scene2_eyebrow',
    titleKey: 'scene2_title',
    subtitleKey: 'scene2_subtitle',
    fallbackEyebrow: 'Learn',
    fallbackTitle: 'From curious\nto expert',
    fallbackSubtitle:
        'Identify trees, flowers, succulents, and more with confidence.',
    textCardAlignment: Alignment(0, -0.92),
    animationAlignment: Alignment(0, 0.24),
    animationAlignmentTight: Alignment(0, 0.18),
    crossAxisAlignment: CrossAxisAlignment.center,
    textAlign: TextAlign.center,
    animationWidthFactor: 1.1,
    animationAsset: 'assets/animations/communication.json',
  ),
  _OnboardingScene(
    eyebrowKey: 'scene3_eyebrow',
    titleKey: 'scene3_title',
    subtitleKey: 'scene3_subtitle',
    fallbackEyebrow: 'Nurture',
    fallbackTitle: 'Give every plant\nthe care it needs',
    fallbackSubtitle:
        'Personalized watering, light, and care advice for a thriving garden.',
    textCardAlignment: Alignment(0.9, 0.7),
    animationAlignment: Alignment(-0.6, -0.08),
    animationAlignmentTight: Alignment(-0.7, -0.2),
    crossAxisAlignment: CrossAxisAlignment.end,
    textAlign: TextAlign.right,
    animationWidthFactor: 0.76,
    animationAsset: 'assets/animations/growing_plants.json',
  ),
];

String _resolveCopy(
  Map<String, dynamic> copy,
  String key,
  String fallback,
) {
  final value = copy[key];
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }
  return fallback;
}
