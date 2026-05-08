import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ThemeData build(Brightness brightness) {
    final palette = AppPalette.forBrightness(brightness);
    final baseTheme = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: palette.primary,
        brightness: brightness,
        primary: palette.primary,
        secondary: palette.primaryStrong,
        surface: palette.surface,
      ),
      scaffoldBackgroundColor: palette.background,
      splashFactory: NoSplash.splashFactory,
    );

    final textTheme = GoogleFonts.interTextTheme(baseTheme.textTheme).copyWith(
      displaySmall: GoogleFonts.manrope(
        fontSize: 42,
        fontWeight: FontWeight.w800,
        height: 1.04,
        color: palette.textPrimary,
      ),
      headlineMedium: GoogleFonts.manrope(
        fontSize: 30,
        fontWeight: FontWeight.w800,
        height: 1.12,
        color: palette.textPrimary,
      ),
      titleLarge: GoogleFonts.manrope(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.18,
        color: palette.textPrimary,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.25,
        color: palette.textPrimary,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        height: 1.5,
        color: palette.textSecondary,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        height: 1.45,
        color: palette.textSecondary,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
        color: palette.buttonText,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
        color: palette.textSecondary,
      ),
    );

    return baseTheme.copyWith(
      textTheme: textTheme,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.primary,
          foregroundColor: palette.buttonText,
          minimumSize: const Size.fromHeight(58),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.xl),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.textPrimary,
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      dividerColor: palette.outline,
    );
  }
}

class AppPalette {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceTint,
    required this.outline,
    required this.textPrimary,
    required this.textSecondary,
    required this.primary,
    required this.primaryStrong,
    required this.primarySoft,
    required this.buttonText,
    required this.heroStart,
    required this.heroEnd,
    required this.heroGlow,
    required this.imageOverlay,
    required this.shadow,
  });

  final Color background;
  final Color surface;
  final Color surfaceRaised;
  final Color surfaceTint;
  final Color outline;
  final Color textPrimary;
  final Color textSecondary;
  final Color primary;
  final Color primaryStrong;
  final Color primarySoft;
  final Color buttonText;
  final Color heroStart;
  final Color heroEnd;
  final Color heroGlow;
  final Color imageOverlay;
  final Color shadow;

  static const light = AppPalette(
    background: Color(0xFFF5F8F2),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFF0F5ED),
    surfaceTint: Color(0xF7FFFFFF),
    outline: Color(0xFFD5E1D2),
    textPrimary: Color(0xFF152417),
    textSecondary: Color(0xFF57705A),
    primary: Color(0xFF2E8E5B),
    primaryStrong: Color(0xFF1D7246),
    primarySoft: Color(0xFFE3F4E8),
    buttonText: Colors.white,
    heroStart: Color(0xFFDFF3E2),
    heroEnd: Color(0xFFF6FBF5),
    heroGlow: Color(0x8036A766),
    imageOverlay: Color(0x33101910),
    shadow: Color(0x1F163119),
  );

  static const dark = AppPalette(
    background: Color(0xFF07110A),
    surface: Color(0xFF101B12),
    surfaceRaised: Color(0xFF152417),
    surfaceTint: Color(0xE619281C),
    outline: Color(0xFF284530),
    textPrimary: Color(0xFFF2F6F0),
    textSecondary: Color(0xFFA0B8A3),
    primary: Color(0xFF41C47A),
    primaryStrong: Color(0xFF2EA965),
    primarySoft: Color(0xFF173522),
    buttonText: Colors.white,
    heroStart: Color(0xFF0D1F14),
    heroEnd: Color(0xFF081109),
    heroGlow: Color(0x6641C47A),
    imageOverlay: Color(0x66101810),
    shadow: Color(0x66101711),
  );

  static AppPalette of(BuildContext context) {
    return forBrightness(Theme.of(context).brightness);
  }

  static AppPalette forBrightness(Brightness brightness) {
    return brightness == Brightness.dark ? dark : light;
  }
}

class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
  static const double xxxxl = 64;
}

class AppImageUrls {
  static const identify =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuB75FRuxRegsPRMh9CO6UyGfwOAA44c3zDobYY7rmr9u5KLx4MBXYcWHZRNmAt5fQCHPVl1j1aO9onKU3ul_1As4-yPfiYeXASzS1izSVTVY5tDnbTEsY6ownR9ufbIg_1Vji7CDWT5B3ZGzg0NlSvqgKoiAFxo10qa2HnYlaUbs5x8obnCL2uAVQEoR4yWLPZWKknJqEwJb2wOLxI94y_7a-YgR90iZzmB06u221qO8-DvDAPRsuK12QU6ZN7C5bjtiP9cWK6UfEc';

  static const care =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuDADaCzSWHkQ8owPBQxd7x94o75-xndqs5R-SAWChhgE6TbyWzV_MoNR9ASYlX6RBZMiB3pwnhnvdznl17GoW0LZo3N_LhV3SBxj4owXdvBKiPC6wkJigOvgDQB2r_r2zsXQ4x_abrVVIG_r5OM-lyuzTyl-CjzwoIr1ZIxaW17wI-OaJHvBej12XrDimyXbEuknoXXZBdJg1eaBZ3UHivlJgXmR05gc0VyPva01E91tEWwKg4FKrx9UQAjB1u3tEedihb59l_Vnek';
}

class ThemedPanel extends StatelessWidget {
  const ThemedPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
    this.color,
    this.radius = 30,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? palette.surfaceTint,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: palette.outline),
        boxShadow: [
          BoxShadow(
            color: palette.shadow,
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: child,
    );
  }
}

class AmbientBackground extends StatelessWidget {
  const AmbientBackground({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.heroStart, palette.heroEnd],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -90,
            right: -60,
            child: _GlowOrb(
              size: 220,
              color: palette.heroGlow,
            ),
          ),
          Positioned(
            left: -70,
            bottom: 180,
            child: _GlowOrb(
              size: 180,
              color: palette.primarySoft,
            ),
          ),
          if (child != null) child!,
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withOpacity(0)],
          ),
        ),
      ),
    );
  }
}

class OnboardingDots extends StatelessWidget {
  const OnboardingDots({
    super.key,
    required this.currentPage,
    required this.totalPages,
  });

  final int currentPage;
  final int totalPages;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        totalPages,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: EdgeInsets.only(
            right: index == totalPages - 1 ? 0 : AppSpacing.sm,
          ),
          width: index == currentPage ? 28 : 10,
          height: 10,
          decoration: BoxDecoration(
            color: index == currentPage
                ? palette.primary
                : palette.outline.withOpacity(0.85),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}

class LeafSnapLogo extends StatelessWidget {
  const LeafSnapLogo({super.key, this.centered = false});

  final bool centered;
  static const _logoSize = 40.0;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    final logo = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: _logoSize,
          height: _logoSize,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: palette.shadow,
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.asset(
              'assets/icons/logo.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Text(
          'LeafSnap AI',
          style: GoogleFonts.manrope(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: palette.textPrimary,
          ),
        ),
      ],
    );

    return centered ? Center(child: logo) : logo;
  }
}

class PlantImageFrame extends StatelessWidget {
  const PlantImageFrame({
    super.key,
    required this.imageUrl,
    required this.label,
    this.overlay,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.scale = 1,
  });

  final String imageUrl;
  final String label;
  final Widget? overlay;
  final BoxFit fit;
  final Alignment alignment;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    final image = Image.network(
      imageUrl,
      fit: fit,
      alignment: alignment,
      errorBuilder: (_, __, ___) => _ImageFallback(label: label),
      loadingBuilder: (_, child, progress) {
        if (progress == null) {
          return child;
        }

        return _ImageFallback(label: label);
      },
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Transform.scale(scale: scale, child: image),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  palette.imageOverlay.withOpacity(0.1),
                  palette.imageOverlay,
                ],
              ),
            ),
          ),
          if (overlay != null) overlay!,
        ],
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.heroStart, palette.surfaceRaised],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.local_florist_rounded, color: palette.primary, size: 58),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: palette.textPrimary,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
