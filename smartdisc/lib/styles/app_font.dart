import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppFont {
  static const TextStyle logoMark = TextStyle(
    fontFamily: 'Georgia',
    fontSize: 28,
    letterSpacing: 4,
    fontWeight: FontWeight.w600,
    color: AppColors.primary,
  );

  static const TextStyle headline = TextStyle(
    fontFamily: 'Georgia',
    fontSize: 26,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  static const TextStyle subheadline = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  static const TextStyle statValue = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static const TextStyle statLabel = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  static const TextStyle body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textMuted,
  );

  static const TextStyle link = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.bluePrimary,
    decoration: TextDecoration.underline,
  );

  static const TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.white,
    letterSpacing: 0.2,
  );
}
