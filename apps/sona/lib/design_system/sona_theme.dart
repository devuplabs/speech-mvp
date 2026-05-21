import 'package:flutter/material.dart';
import 'package:sona/design_system/sona_colors.dart';

/// Inter-like stack without network font fetch (reliable on Flutter web).
const _fontFamily = 'Inter';
const _fontFallback = ['Segoe UI', 'Roboto', 'Helvetica Neue', 'Arial', 'sans-serif'];

ThemeData sonaTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: _fontFamily,
    fontFamilyFallback: _fontFallback,
    scaffoldBackgroundColor: SonaColors.background,
    colorScheme: const ColorScheme.light(
      primary: SonaColors.primary,
      secondary: SonaColors.accent,
      surface: SonaColors.surface,
      onPrimary: Colors.white,
      onSurface: SonaColors.textPrimary,
    ),
  );

  final inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: SonaColors.border),
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: SonaColors.textPrimary,
      displayColor: SonaColors.textPrimary,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: SonaColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: SonaColors.surface,
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: inputBorder.copyWith(
        borderSide: const BorderSide(color: SonaColors.primary, width: 1.5),
      ),
    ),
  );
}
