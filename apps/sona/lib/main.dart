import 'package:flutter/material.dart';
import 'package:sona/app/sona_app_shell.dart';
import 'package:sona/design_system/sona_theme.dart';
import 'package:sona/services/api_client.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SonaApp());
}

class SonaApp extends StatelessWidget {
  const SonaApp({super.key, this.apiClient});

  /// Optional override so integration tests can inject a fake [SonaApiClient]
  /// (e.g. one backed by a `MockClient`) without spinning up the real API.
  final SonaApiClient? apiClient;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sona',
      debugShowCheckedModeBanner: false,
      theme: sonaTheme(),
      home: SonaAppShell(apiClient: apiClient),
    );
  }
}
