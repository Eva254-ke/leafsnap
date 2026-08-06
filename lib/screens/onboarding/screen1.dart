import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:url_launcher/url_launcher.dart';

import 'shared.dart';
import '../../services/remote_config_service.dart';

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
  bool _lottieLoaded = false;

  @override
  void initState() {
    super.initState();

    _lottieController = AnimationController(vsync: this);
    
    // Text animation starts immediately
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
    
    // Pre-cache the Lottie animation file to avoid jank
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _precacheLottie();
    });
  }

  Future<void> _precacheLottie() async {
    try {
      final data = await rootBundle.load(
        'assets/animations/realistic_leaf_scan.json',
      );
      await LottieComposition.fromByteData(data);
      if (mounted) {
        setState(() => _lottieLoaded = true);
      }
    } catch (e) {
      debugPrint('Error precaching Lottie: $e');
      // Still mark as loaded to show fallback
      if (mounted) {
        setState(() => _lottieLoaded = true);
      }
    }
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
    final copy = RemoteConfigService.instance
      .getJson(RemoteConfigKeys.onboardingCopy);
    final title = (copy['screen1_title'] as String?)
        ?.trim()
        .isNotEmpty ==
      true
      ? (copy['screen1_title'] as String)
      : 'The magic of nature\nat your fingertips';
    final subtitle = (copy['screen1_subtitle'] as String?)
        ?.trim()
        .isNotEmpty ==
      true
      ? (copy['screen1_subtitle'] as String)
      : 'Identify any plant instantly\nwith 99.9% accuracy';
    final cta = (copy['screen1_cta'] as String?)?.trim().isNotEmpty == true
      ? (copy['screen1_cta'] as String)
      : 'Continue';
    final terms = (copy['screen1_terms'] as String?)?.trim().isNotEmpty == true
      ? (copy['screen1_terms'] as String)
      : 'By tapping Continue, you agree to our Terms of Use and confirm you have read our Privacy Policy';

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
                    ChloraLogo(),
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
                        child: _lottieLoaded
                            ? Stack(
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
                              )
                            : Container(
                                decoration: BoxDecoration(
                                  color: palette.primarySoft,
                                  borderRadius: BorderRadius.circular(34),
                                  border: Border.all(
                                    color: palette.primary.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Center(
                                  child: SizedBox(
                                    width: 50,
                                    height: 50,
                                    child: CircularProgressIndicator(
                                      color: palette.primary,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
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
                                    title,
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
                                    subtitle,
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
                    _TermsNotice(text: terms),
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

class _TermsNotice extends StatefulWidget {
  const _TermsNotice({required this.text});

  final String text;

  @override
  State<_TermsNotice> createState() => _TermsNoticeState();
}

class _TermsNoticeState extends State<_TermsNotice> {
  static final Uri _legalUri = Uri.parse('https://sites.google.com/view/leafsnapai/home');

  late final TapGestureRecognizer _privacyRecognizer;
  late final TapGestureRecognizer _termsRecognizer;

  @override
  void initState() {
    super.initState();
    _privacyRecognizer = TapGestureRecognizer()..onTap = _openLegalPage;
    _termsRecognizer = TapGestureRecognizer()..onTap = _openLegalPage;
  }

  @override
  void dispose() {
    _privacyRecognizer.dispose();
    _termsRecognizer.dispose();
    super.dispose();
  }

  Future<void> _openLegalPage() async {
    if (!await launchUrl(_legalUri, mode: LaunchMode.externalApplication) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open legal page')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final baseStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: palette.textSecondary,
          fontSize: 12,
          height: 1.5,
        );
    final linkStyle = baseStyle?.copyWith(
      color: palette.primaryStrong,
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
      decorationColor: palette.primaryStrong,
    );

    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: [
          const TextSpan(text: 'By tapping Continue, you agree to our '),
          TextSpan(
            text: 'Terms of Use',
            style: linkStyle,
            recognizer: _termsRecognizer,
          ),
          const TextSpan(text: ' and confirm you have read our '),
          TextSpan(
            text: 'Privacy Policy',
            style: linkStyle,
            recognizer: _privacyRecognizer,
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
