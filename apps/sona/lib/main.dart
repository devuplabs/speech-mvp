import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:sona/app/sona_app_shell.dart';
import 'package:sona/config/firebase_options.dart';
import 'package:sona/design_system/sona_theme.dart';
import 'package:sona/services/api_client.dart';
import 'package:sona/services/auth/auth_controller.dart';
import 'package:sona/services/auth/authed_http_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase is optional: only initialise when this build was given client
  // config (Auth·06). Demo builds and tests run without it.
  AuthController? authController;
  if (SonaFirebaseOptions.isConfigured) {
    try {
      await Firebase.initializeApp(options: SonaFirebaseOptions.current);
      authController = AuthController();
    } catch (e) {
      debugPrint('Firebase init skipped: $e');
    }
  }

  String? intakeToken;
  String? portalToken;
  String? inviteCode;
  if (kIsWeb) {
    intakeToken = Uri.base.queryParameters['t'];
    portalToken = Uri.base.queryParameters['portal'];
    inviteCode = inviteCodeFromUri(Uri.base);
  }
  runApp(SonaApp(
    intakeToken: intakeToken,
    portalToken: portalToken,
    inviteCode: inviteCode,
    authController: authController,
  ));
}

/// Extracts a Firebase action code from an inbound invite / password-reset link
/// (Auth·16). Invite-accept (Auth·05) and "forgot password" emails both land as
/// `…/auth/accept-invite?mode=resetPassword&oobCode=…`; either routes to the
/// set-password screen. Returns null when no usable reset code is present.
String? inviteCodeFromUri(Uri uri) {
  final code = uri.queryParameters['oobCode'];
  if (code == null || code.isEmpty) return null;
  final mode = uri.queryParameters['mode'];
  if (mode != null && mode != 'resetPassword') return null;
  return code;
}

class SonaApp extends StatelessWidget {
  const SonaApp({
    super.key,
    this.apiClient,
    this.intakeToken,
    this.portalToken,
    this.inviteCode,
    this.authController,
  });

  /// Optional override so integration tests can inject a fake [SonaApiClient]
  /// (e.g. one backed by a `MockClient`) without spinning up the real API.
  final SonaApiClient? apiClient;
  final String? intakeToken;

  /// Family-portal magic-link token from the parent web URL `?portal=`
  /// (Stage 9). Distinct from the single-use intake `?t=` link.
  final String? portalToken;

  /// Firebase reset/invite action code from the inbound web URL (Auth·16).
  final String? inviteCode;

  /// Present only when Firebase is configured; drives auth state + token
  /// injection on API calls (Auth·06).
  final AuthController? authController;

  @override
  Widget build(BuildContext context) {
    // Prefer an explicitly injected client (tests). Otherwise, when signed-in
    // auth is available, attach the Firebase ID token to every request.
    final client = apiClient ??
        (authController != null
            ? SonaApiClient(
                client: AuthedHttpClient(
                  tokenProvider: authController!.idToken,
                ),
              )
            : null);

    return MaterialApp(
      title: 'Sona',
      debugShowCheckedModeBanner: false,
      theme: sonaTheme(),
      home: SonaAppShell(
        apiClient: client,
        intakeToken: intakeToken,
        portalToken: portalToken,
        inviteCode: inviteCode,
        authController: authController,
      ),
    );
  }
}
