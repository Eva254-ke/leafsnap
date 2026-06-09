import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Animated logo widget that displays the app logo with animations
/// 
/// Usage:
/// ```dart
/// // Simple animated logo
/// AnimatedLogoWidget()
/// 
/// // Custom size with looping
/// AnimatedLogoWidget(
///   size: 200,
///   animate: true,
///   repeat: true,
/// )
/// 
/// // Static logo
/// AnimatedLogoWidget(animate: false)
/// ```
class AnimatedLogoWidget extends StatefulWidget {
  /// Size of the logo in pixels
  final double size;

  /// Whether to animate the logo (default: true)
  final bool animate;

  /// Whether to repeat the animation (default: true)
  final bool repeat;

  /// Animation speed multiplier (default: 1.0)
  final double animationSpeed;

  /// Callback when animation completes (only fires if repeat is false)
  final VoidCallback? onAnimationComplete;

  const AnimatedLogoWidget({
    super.key,
    this.size = 150,
    this.animate = true,
    this.repeat = true,
    this.animationSpeed = 1.0,
    this.onAnimationComplete,
  });

  @override
  State<AnimatedLogoWidget> createState() => _AnimatedLogoWidgetState();
}

class _AnimatedLogoWidgetState extends State<AnimatedLogoWidget>
    with TickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    if (widget.animate) {
      if (widget.repeat) {
        _controller.repeat();
      } else {
        _controller.forward().then((_) {
          widget.onAnimationComplete?.call();
        });
      }
    }
  }

  @override
  void didUpdateWidget(AnimatedLogoWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.animate != widget.animate) {
      if (widget.animate) {
        if (widget.repeat) {
          _controller.repeat();
        } else {
          _controller.forward();
        }
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.animate) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: Lottie.asset(
          'assets/animations/logo_splash.json',
          controller: _controller,
          repeat: widget.repeat,
        ),
      );
    }

    // Static logo fallback
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Image.asset(
        'assets/icons/logo.png',
        fit: BoxFit.contain,
      ),
    );
  }
}

/// App launch splash screen with the branded Lottie logo.
class AnimatedLogoSplashScreen extends StatefulWidget {
  /// App title to display below the logo
  final String? title;

  /// Subtitle to display below the title
  final String? subtitle;

  /// Duration to show the splash screen
  final Duration displayDuration;

  /// Callback when splash screen animation completes
  final VoidCallback? onComplete;

  /// Custom theme colors
  final Color? backgroundColor;
  final Color? accentColor;

  const AnimatedLogoSplashScreen({
    super.key,
    this.title,
    this.subtitle,
    this.displayDuration = const Duration(seconds: 3),
    this.onComplete,
    this.backgroundColor,
    this.accentColor,
  });

  @override
  State<AnimatedLogoSplashScreen> createState() =>
      _AnimatedLogoSplashScreenState();
}

class _AnimatedLogoSplashScreenState extends State<AnimatedLogoSplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late AnimationController _progressController;
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _contentOpacityAnimation;

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();

    _progressController = AnimationController(
      vsync: this,
      duration: widget.displayDuration,
    )..forward();

    _logoScaleAnimation = Tween<double>(begin: 0.96, end: 1).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOutCubic),
    );
    _contentOpacityAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );

    Future.delayed(widget.displayDuration, () {
      if (mounted) {
        widget.onComplete?.call();
      }
    });
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = widget.accentColor ?? const Color(0xFF17B897);
    final showText = widget.title != null || widget.subtitle != null;

    return Scaffold(
      backgroundColor: widget.backgroundColor ?? const Color(0xFFF5FFFB),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: FadeTransition(
              opacity: _contentOpacityAnimation,
              child: AnimatedBuilder(
                animation: Listenable.merge(
                  [_logoScaleAnimation, _progressController],
                ),
                builder: (context, child) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Transform.scale(
                        scale: _logoScaleAnimation.value,
                        child: SizedBox(
                          width: 260,
                          height: 220,
                          child: Lottie.asset(
                            'assets/animations/logo_splash.json',
                            fit: BoxFit.contain,
                            repeat: false,
                          ),
                        ),
                      ),
                      if (widget.title != null) ...[
                        const SizedBox(height: 18),
                        Text(
                          widget.title!,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF17382C),
                                letterSpacing: 0,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      if (widget.subtitle != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          widget.subtitle!,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: const Color(0xFF5E746D),
                                    height: 1.35,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0,
                                  ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      if (showText) ...[
                        const SizedBox(height: 30),
                        SizedBox(
                          width: 104,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: _progressController.value,
                              minHeight: 3,
                              color: accentColor,
                              backgroundColor:
                                  accentColor.withValues(alpha: 0.12),
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Badge widget with animated logo
class AnimatedLogoBadge extends StatelessWidget {
  /// Size of the badge
  final double size;

  /// Whether to show animation
  final bool animate;

  /// Badge label
  final String? label;

  /// Badge color
  final Color? backgroundColor;

  const AnimatedLogoBadge({
    super.key,
    this.size = 80,
    this.animate = true,
    this.label,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: backgroundColor ?? Colors.teal.shade50,
            border: Border.all(
              color: Colors.teal.shade200,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.teal.withValues(alpha: 0.2),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: AnimatedLogoWidget(
              size: size - 16,
              animate: animate,
              repeat: true,
            ),
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: 8),
          Text(
            label!,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
        ]
      ],
    );
  }
}
