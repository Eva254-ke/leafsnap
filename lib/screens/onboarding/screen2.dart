import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

import 'shared.dart';

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
  bool _hasConfiguredLottie = false;

  late final AnimationController _eyebrowController;
  late final Animation<double> _eyebrowFade;
  late final Animation<Offset> _eyebrowSlide;

  late final AnimationController _titleController;
  late final Animation<double> _titleFade;
  late final Animation<Offset> _titleSlide;

  late final AnimationController _subtitleController;
  late final Animation<double> _subtitleFade;
  late final Animation<Offset> _subtitleSlide;

  @override
  void initState() {
    super.initState();

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

    _startSceneSequence();

    _completeTimer = Timer(
      const Duration(seconds: 12),
      _completeOnboarding,
    );
  }

  void _configureLottie(LottieComposition composition) {
    if (_hasConfiguredLottie) {
      return;
    }

    _hasConfiguredLottie = true;
    _lottieController
      ..duration = composition.duration
      ..repeat();
  }

  void _startSceneSequence() {
    _eyebrowController.reset();
    _titleController.reset();
    _subtitleController.reset();

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
    _advanceTimer = Timer(const Duration(seconds: 4), _nextScene);
  }

  void _nextScene() async {
    if (_currentPage < _scenes.length - 1) {
      await _subtitleController.reverse();
      await _titleController.reverse();
      await _eyebrowController.reverse();
      
      setState(() {
        _currentPage++;
      });

      _startSceneSequence();
    }
  }

  void _completeOnboarding() {
    if (mounted) {
      HapticFeedback.mediumImpact();
      _lottieController.stop();
      _advanceTimer?.cancel();
      _completeTimer?.cancel();
      widget.onComplete();
    }
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
    final scene = _scenes[_currentPage];

    return Scaffold(
      body: AmbientBackground(
        child: SafeArea(
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
                final textWidth = constraints.maxWidth >= 420
                    ? 340.0
                    : constraints.maxWidth * 0.86;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const LeafSnapLogo(),
                    SizedBox(height: isCompact ? AppSpacing.lg : AppSpacing.xl),
                    Expanded(
                      child: Stack(
                        children: [
                          AnimatedAlign(
                            duration: const Duration(milliseconds: 650),
                            curve: Curves.easeInOutCubic,
                            alignment: scene.animationAlignment,
                            child: FractionallySizedBox(
                              widthFactor: scene.animationWidthFactor,
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: RepaintBoundary(
                                  child: Lottie.asset(
                                    'assets/animations/plant.json',
                                    controller: _lottieController,
                                    fit: BoxFit.contain,
                                    onLoaded: _configureLottie,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        decoration: BoxDecoration(
                                          color: palette.primarySoft,
                                          borderRadius: BorderRadius.circular(
                                            28,
                                          ),
                                          border: Border.all(
                                            color: palette.outline,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.eco_rounded,
                                          size: isCompact ? 72 : 88,
                                          color: palette.primary,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
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
                                        scene.eyebrow.toUpperCase(),
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: palette.primary,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                  FadeTransition(
                                    opacity: _titleFade,
                                    child: SlideTransition(
                                      position: _titleSlide,
                                      child: Text(
                                        scene.title,
                                        textAlign: scene.textAlign,
                                        style: GoogleFonts.manrope(
                                          fontSize: isCompact ? 30 : 34,
                                          fontWeight: FontWeight.w800,
                                          height: 1.12,
                                          color: palette.textPrimary,
                                          letterSpacing: -0.6,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  FadeTransition(
                                    opacity: _subtitleFade,
                                    child: SlideTransition(
                                      position: _subtitleSlide,
                                      child: Text(
                                        scene.subtitle,
                                        textAlign: scene.textAlign,
                                        style: GoogleFonts.inter(
                                          fontSize: isCompact ? 15 : 16,
                                          fontWeight: FontWeight.w500,
                                          color: palette.textSecondary,
                                          height: 1.5,
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
                    OnboardingDots(
                      currentPage: _currentPage,
                      totalPages: _scenes.length,
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
}

class _OnboardingScene {
  const _OnboardingScene({
    required this.title,
    required this.subtitle,
    required this.eyebrow,
    required this.textCardAlignment,
    required this.animationAlignment,
    required this.crossAxisAlignment,
    required this.textAlign,
    required this.animationWidthFactor,
  });

  final String title;
  final String subtitle;
  final String eyebrow;
  final Alignment textCardAlignment;
  final Alignment animationAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final TextAlign textAlign;
  final double animationWidthFactor;
}

const List<_OnboardingScene> _scenes = [
  _OnboardingScene(
    eyebrow: 'Discover',
    title: 'Every leaf tells\na story',
    subtitle: 'Point your camera and unlock the secrets of thousands of plants.',
    textCardAlignment: Alignment(0, 0.82),
    animationAlignment: Alignment(0, -0.2),
    crossAxisAlignment: CrossAxisAlignment.center,
    textAlign: TextAlign.center,
    animationWidthFactor: 0.82,
  ),
  _OnboardingScene(
    eyebrow: 'Learn',
    title: 'From curious\nto expert',
    subtitle: 'Identify trees, flowers, succulents, and more with confidence.',
    textCardAlignment: Alignment(-0.94, -0.8),
    animationAlignment: Alignment(0.72, -0.02),
    crossAxisAlignment: CrossAxisAlignment.start,
    textAlign: TextAlign.left,
    animationWidthFactor: 0.74,
  ),
  _OnboardingScene(
    eyebrow: 'Nurture',
    title: 'Give every plant\nthe care it needs',
    subtitle: 'Personalized watering, light, and care advice for a thriving garden.',
    textCardAlignment: Alignment(0.94, 0.74),
    animationAlignment: Alignment(-0.72, -0.04),
    crossAxisAlignment: CrossAxisAlignment.end,
    textAlign: TextAlign.right,
    animationWidthFactor: 0.74,
  ),
];
