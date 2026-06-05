import 'package:firebase_core/firebase_core.dart';

/// Firebase client config for the Sona web/mobile app (Auth·06).
///
/// Values are injected at **build time** via `--dart-define` from the Terraform
/// outputs of `infra/terraform/modules/firebase_auth` — these are public client
/// config (shipped in the bundle), not secrets. Example:
///
/// ```sh
/// flutter build web \
///   --dart-define=FIREBASE_API_KEY="$(terraform output -raw firebase_web_api_key)" \
///   --dart-define=FIREBASE_APP_ID="$(terraform output -raw firebase_web_app_id)" \
///   --dart-define=FIREBASE_PROJECT_ID="$(terraform output -raw firebase_project_id)" \
///   --dart-define=FIREBASE_AUTH_DOMAIN="$(terraform output -raw firebase_auth_domain)" \
///   --dart-define=FIREBASE_MESSAGING_SENDER_ID="$(terraform output -raw firebase_messaging_sender_id)"
/// ```
///
/// When the defines are absent (e.g. the demo build or widget tests),
/// [isConfigured] is false and the app skips Firebase init entirely.
class SonaFirebaseOptions {
  const SonaFirebaseOptions._();

  static const _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const _appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const _authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
  static const _messagingSenderId =
      String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');

  /// True once the build was given real Firebase client config.
  static bool get isConfigured =>
      _apiKey.isNotEmpty && _appId.isNotEmpty && _projectId.isNotEmpty;

  static FirebaseOptions get current => FirebaseOptions(
        apiKey: _apiKey,
        appId: _appId,
        projectId: _projectId,
        authDomain:
            _authDomain.isNotEmpty ? _authDomain : '$_projectId.firebaseapp.com',
        messagingSenderId: _messagingSenderId,
      );
}
