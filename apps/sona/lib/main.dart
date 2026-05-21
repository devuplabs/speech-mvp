import 'package:flutter/material.dart';
import 'package:sona/app/sona_app_shell.dart';
import 'package:sona/design_system/sona_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SonaApp());
}

class SonaApp extends StatelessWidget {
  const SonaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sona',
      debugShowCheckedModeBanner: false,
      theme: sonaTheme(),
      home: const SonaAppShell(),
    );
  }
}
