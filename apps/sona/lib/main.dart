import 'package:flutter/material.dart';
import 'package:sona/design_system/theme.dart';
import 'package:sona/features/home/home_screen.dart';

void main() {
  runApp(const SonaApp());
}

class SonaApp extends StatelessWidget {
  const SonaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sona',
      theme: sonaTheme(),
      home: const HomeScreen(),
    );
  }
}
