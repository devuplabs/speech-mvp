import 'package:flutter/material.dart';

ThemeData sonaTheme() {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF1E5A8E),
      brightness: Brightness.light,
    ),
    useMaterial3: true,
  );
}
