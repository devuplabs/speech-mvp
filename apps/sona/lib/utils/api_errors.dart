import 'package:sona/services/api_client.dart';

/// User-facing hint when Flutter web cannot reach the API.
String friendlyApiError(Object error) {
  if (error is SonaApiException) {
    if (error.body.contains('database_not_configured')) {
      return 'API database not configured. Add DATABASE_URL to apps/api/.env, '
          'start Cloud SQL Auth Proxy, and restart the API (see docs/DEMO.md).';
    }
    if (error.statusCode == 404) {
      return 'API returned 404. If using a local API, connect DATABASE_URL; '
          'otherwise check SONA_API_BASE_URL points at the running API.';
    }
  }

  final msg = error.toString();
  if (msg.contains('Failed to fetch') ||
      msg.contains('ClientException') ||
      msg.contains('XMLHttpRequest')) {
    return 'Cannot reach the API from the browser (often CORS). '
        'For local dev set NODE_ENV=development and CORS_ALLOW_LOCALHOST=true on the API. '
        'For Cloud Run set CORS_ORIGINS to your app URL only.';
  }
  return msg;
}
