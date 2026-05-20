/// Compile-time API base URL. Override per environment:
/// `flutter run --dart-define=SONA_API_BASE_URL=https://api.dev.example`
class Env {
  static const apiBaseUrl = String.fromEnvironment(
    'SONA_API_BASE_URL',
    defaultValue: 'https://sona-api-dev-3rhenudy6a-nw.a.run.app',
  );
}
