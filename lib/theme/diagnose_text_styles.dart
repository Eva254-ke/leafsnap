import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Static text styles for the Diagnose feature.
/// Centralising these removes ~18 inline GoogleFonts.inter() call sites and
/// ensures parameter consistency across cards, headers, and banners.
abstract final class DiagnoseTextStyles {
  // ── Section headers ────────────────────────────────────────────────────────
  static final TextStyle sectionTitle = GoogleFonts.inter(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static final TextStyle sectionSubtitle = GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    height: 1.4,
  );

  // ── Cards ──────────────────────────────────────────────────────────────────
  static final TextStyle cardTitle = GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimaryDark,
    height: 1.2,
  );

  static final TextStyle cardScientific = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textScientific,
    fontStyle: FontStyle.italic,
  );

  static final TextStyle cardNote = GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.textNote,
    height: 1.4,
  );

  // ── Hero card ──────────────────────────────────────────────────────────────
  static final TextStyle heroTag = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );

  static final TextStyle heroHeadline = GoogleFonts.inter(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: Colors.white,
    height: 1.15,
    letterSpacing: -0.4,
  );

  static final TextStyle heroBody = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: Colors.white.withValues(alpha: 0.92),
    height: 1.45,
  );

  static final TextStyle heroButton = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w700,
  );

  // ── Metric pills ───────────────────────────────────────────────────────────
  static final TextStyle metricPillLabel = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: AppColors.textMetricLabel,
  );

  // ── Banners ────────────────────────────────────────────────────────────────
  static final TextStyle bannerText = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.45,
  );

  // ── Badges ─────────────────────────────────────────────────────────────────
  static final TextStyle badgeLabel = GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w700,
  );
}