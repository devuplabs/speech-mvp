import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:sona/app/sona_app_shell.dart';
import 'package:sona/design_system/sona_theme.dart';
import 'package:sona/services/api_client.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  String? intakeToken;
  if (kIsWeb) {
    intakeToken = Uri.base.queryParameters['t'];
  }
  runApp(SonaApp(intakeToken: intakeToken));
}

class SonaApp extends StatelessWidget {
  const SonaApp({super.key, this.apiClient, this.intakeToken});

  /// Optional override so integration tests can inject a fake [SonaApiClient]
  /// (e.g. one backed by a `MockClient`) without spinning up the real API.
  final SonaApiClient? apiClient;
  final String? intakeToken;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sona',
      debugShowCheckedModeBanner: false,
      theme: sonaTheme(),
      home: SonaAppShell(apiClient: apiClient, intakeToken: intakeToken),
    );
  }
}
