import 'package:flutter/material.dart';

/// SmartDisc brand palette – blue/gray only.
/// - Dunkelblau #102a57 – primary, text
/// - Grau Azurblau #6f93b5 – accent
/// - Pastelgrau Azurblau #b4bfc9 – borders, muted
/// - Light blue-gray tints for backgrounds (no orange)
class AppColors {
  // ---- Palette (brand) ----
  /// Grau Azurblau – muted blue-gray (accent, links)
  static const Color grauAzurblau = Color(0xFF6F93B5);
  /// Dunkelblau – deep navy (primary, headings)
  static const Color dunkelblau = Color(0xFF102A57);
  /// Pastelgrau Azurblau – light blue-gray (borders, muted)
  static const Color pastelgrauAzurblau = Color(0xFFB4BFC9);

  // Lighter blue-gray tints (for backgrounds, no orange)
  static const Color grauAzurblau60 = Color(0xFFB8C9DD);
  static const Color pastelgrauAzurblau80 = Color(0xFFC9D2DA);
  static const Color backgroundLight = Color(0xFFE8ECF0);  // light blue-gray
  static const Color backgroundLighter = Color(0xFFF2F4F7); // very light blue-gray

  // ---- Semantic mapping ----
  // Brand
  static const Color primary = dunkelblau;
  static const Color primaryDark = Color(0xFF0A1E3A);
  static const Color accent = grauAzurblau;
  static const Color accentMuted = grauAzurblau60;

  static const Color secondary = grauAzurblau;
  static const Color bluePrimary = dunkelblau;
  static const Color blueMuted = pastelgrauAzurblau;

  // Surfaces (blue-gray and white only)
  static const Color background = backgroundLighter;
  static const Color backgroundAlt = backgroundLight;
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = pastelgrauAzurblau80;
  static const Color border = pastelgrauAzurblau;
  static const Color borderLight = pastelgrauAzurblau80;

  // Text
  static const Color textPrimary = dunkelblau;
  static const Color textSecondary = grauAzurblau;
  static const Color textMuted = pastelgrauAzurblau;
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textOnAccent = dunkelblau;

  // Cards & gradients (blue-gray only)
  static const Color cardGradientStart = backgroundLighter;
  static const Color cardGradientEnd = Color(0xFFFFFFFF);
  static const Color cardAccent = grauAzurblau60;
}
