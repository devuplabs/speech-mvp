import 'package:flutter/material.dart';
import 'package:sona/design_system/sona_colors.dart';

/// Figma-aligned type styles — use instead of ad-hoc font sizes.
abstract final class SonaTypography {
  static const pageTitle = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.bold,
    height: 1.2,
    color: SonaColors.textPrimary,
  );

  static const sectionTitle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: SonaColors.textPrimary,
  );

  static const screenTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    height: 1.3,
    color: SonaColors.textPrimary,
  );

  static const body = TextStyle(
    fontSize: 14,
    height: 1.5,
    color: SonaColors.textSecondary,
  );

  static const label = TextStyle(
    fontSize: 12,
    color: SonaColors.textMuted,
    fontWeight: FontWeight.w500,
  );

  static const clinicianTitle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: SonaColors.textPrimary,
  );

  static const clinicianGreeting = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: SonaColors.textPrimary,
  );
}
