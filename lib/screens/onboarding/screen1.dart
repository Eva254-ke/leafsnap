import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import 'shared.dart';

class OnboardingScreen1 extends StatefulWidget {
  const OnboardingScreen1({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  State<OnboardingScreen1> createState() => _OnboardingScreen1State();
}

class _OnboardingScreen1State extends State<OnboardingScreen1>
    with TickerProviderStateMixin {
  late final AnimationController _lottieController;
  late final AnimationController _textAnimationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _lottieController = AnimationController(vsync: this);
    
    // Text animation starts after Lottie loads
    _textAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textAnimationController, curve: Curves.easeOut),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3), 
      end: Offset.zero
    ).animate(
      CurvedAnimation(parent: _textAnimationController, curve: Curves.easeOutCubic),
    );

    _textAnimationController.forward();
  }

  @override
  void dispose() {
    _lottieController.dispose();
    _textAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final palette = AppPalette.of(context);

    return Scaffold(
      body: AmbientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top section with logo
                const SizedBox(height: 16),
                const Row(
                  children: [
                    LeafSnapLogo(),
                  ],
                ),
                
                // Middle section with Lottie animation and text
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Premium Lottie Animation - Realistic Leaf Scan
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.45,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Lottie animation with fallback
                            RepaintBoundary(
                              child: Lottie.asset(
                                'assets/animations/realistic_leaf_scan.json',
                                controller: _lottieController,
                                fit: BoxFit.contain,
                                onLoaded: (composition) {
                                  _lottieController
                                    ..duration = composition.duration
                                    ..repeat();
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  assert(() {
                                    debugPrint('Lottie load error: $error');
                                    return true;
                                  }());
                                  return Container(
                                    decoration: BoxDecoration(
                                      color: palette.primarySoft,
                                      borderRadius: BorderRadius.circular(34),
                                      border: Border.all(
                                        color: palette.primary.withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Center(
                                      child: Icon(
                                        Icons.eco_rounded,
                                        size: 80,
                                        color: palette.primary,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Simple, empathetic text - no janky animations
                      AnimatedBuilder(
                        animation: _textAnimationController,
                        builder: (context, child) {
                          return Opacity(
                            opacity: _fadeAnimation.value,
                            child: Transform.translate(
                              offset: _slideAnimation.value,
                              child: Column(
                                children: [
                                  Text(
                                    'The magic of nature\nat your fingertips',
                                    textAlign: TextAlign.center,
                                    style: textTheme.headlineSmall?.copyWith(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w700,
                                      height: 1.3,
                                      color: palette.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Identify any plant instantly\nwith 99.9% accuracy',
                                    textAlign: TextAlign.center,
                                    style: textTheme.bodyLarge?.copyWith(
                                      fontSize: 16,
                                      color: palette.textSecondary,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                
                // Bottom section with button and terms - EXACTLY AS REQUESTED
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FilledButton(
                      onPressed: widget.onContinue,
                      style: FilledButton.styleFrom(
                        backgroundColor: palette.primaryStrong,
                        foregroundColor: palette.buttonText,
                        minimumSize: const Size(double.infinity, 46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xxl,
                          vertical: AppSpacing.md,
                        ),
                      ),
                      child: const Text('Continue'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const _TermsNotice(),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TermsNotice extends StatelessWidget {
  const _TermsNotice();

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Text(
      'By tapping Continue, you agree to our Terms of Use\nand Privacy Policy.',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: palette.textSecondary,
            fontSize: 12,
            height: 1.5,
          ),
    );
  }
}