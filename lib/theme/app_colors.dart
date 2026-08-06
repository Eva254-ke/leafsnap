import 'package:flutter/material.dart';

/// Named colour constants extracted from DiagnoseScreen.
/// Values are identical to the originals — this is a pure rename, not a
/// redesign. Wire these into a ColorScheme extension when you're ready for
/// proper theming.
abstract final class AppColors {
  // ── Brand ──────────────────────────────────────────────────────────────────
  static const Color brandGreen = Color(0xFF1D7A43);
  static const Color brandGreenLight = Color(0xFFDDEFE0);

  // ── Backgrounds ────────────────────────────────────────────────────────────
  static const Color backgroundGreen = Color(0xFFF4FBF5);

  // ── Surfaces ───────────────────────────────────────────────────────────────
  static const Color cardBackground = Colors.white;

  // ── Text ───────────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF19231B);
  static const Color textPrimaryDark = Color(0xFF18211A);
  static const Color textSecondary = Color(0xFF6C7D70);
  static const Color textNote = Color(0xFF526254);
  static const Color textScientific = Color(0xFF708171);
  static const Color textMetricLabel = Color(0xFF1F2F23);

  // ── Borders & fills ────────────────────────────────────────────────────────
  static const Color pillBackground = Color(0xFFF2F8F2);
  static const Color pillBorder = Color(0xFFD5E9D9);

  // ── Skeleton / placeholder ─────────────────────────────────────────────────
  static const Color skeletonPrimary = Color(0xFFE8F2E9);
  static const Color skeletonSecondary = Color(0xFFF0F6F0);
  static const Color placeholderGradientStart = Color(0xFFE8F4E9);
  static const Color placeholderGradientEnd = Color(0xFFD8EAD9);
  static const Color placeholderIcon = Color(0xFF2B7B45);

  // ── Badge ──────────────────────────────────────────────────────────────────
  static const Color badgeBackground = Color(0xFF1C2E22);

  // ── Banners ────────────────────────────────────────────────────────────────
  // Warning
  static const Color bannerWarningBackground = Color(0xFFFFF7E8);
  static const Color bannerWarningBorder = Color(0xFFF1D38E);
  static const Color bannerWarningText = Color(0xFF6F5206);

  // Error
  static const Color bannerErrorBackground = Color(0xFFFFEFEF);
  static const Color bannerErrorBorder = Color(0xFFF2C4C4);
  static const Color bannerErrorText = Color(0xFF8F2E2E);

  // Neutral
  static const Color bannerNeutralBorder = Color(0xFFDCE9DD);
  static const Color bannerNeutralText = Color(0xFF4E6152);
}