import 'package:flutter/material.dart';

/// SmartDisc palette: sporty, outdoor, premium.
/// Primary teal, warm accent, clear hierarchy.
class AppColors {
  // Brand
  static const Color primary = Color(0xFF0D9488);       // Teal
  static const Color primaryDark = Color(0xFF0F766E);
  static const Color accent = Color(0xFFF59E0B);        // Amber
  static const Color accentMuted = Color(0xFFFDE68A);

  // Legacy aliases for gradual migration
  static const Color secondary = Color(0xFF06B6D4);
  static const Color bluePrimary = Color(0xFF0D9488);
  static const Color blueMuted = Color(0xFF5EEAD4);

  // Surfaces
  static const Color background = Color(0xFFF0FDFA);    // Very light teal tint
  static const Color backgroundAlt = Color(0xFFCCFBF1); // Subtle mint
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF1F5F9);
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderLight = Color(0xFFF1F5F9);

  // Text
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted = Color(0xFF64748B);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textOnAccent = Color(0xFF1E293B);

  // Cards & gradients
  static const Color cardGradientStart = Color(0xFFF0FDFA);
  static const Color cardGradientEnd = Color(0xFFE0F2FE);
  static const Color cardAccent = Color(0xFF99F6E4);
}
