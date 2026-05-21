import 'dart:convert';

import 'package:sona/services/api_client.dart';

/// User-facing hint when Flutter web cannot reach the API.
String friendlyApiError(Object error) {
  if (error is SonaApiException) {
    if (error.statusCode == 400 && error.body.contains('validation_failed')) {
      try {
        final map = jsonDecode(error.body) as Map<String, dynamic>;
        final field = map['issues']?['fieldErrors'];
        if (field is Map && field.isNotEmpty) {
          final first = field.entries.first;
          return 'Please check your answers (${first.key}).';
        }
      } catch (_) {}
      return 'Some answers are invalid. Check email addresses and required fields.';
    }
    if (error.body.contains('database_not_configured')) {
      return 'API database not configured. Add DATABASE_URL to apps/api/.env, '
          'start Cloud SQL Auth Proxy, and restart the API (see docs/DEMO.md).';
    }
    if (error.statusCode == 409 && error.body.contains('intake_already_submitted')) {
      return 'This intake was already submitted. Use Get started to begin a new form.';
    }
    if (error.isNotFound) {
      return 'This intake session is no longer on the server. Start again or use Resume if you saved on this device.';
    }
    if (error.statusCode == 404) {
      return 'API returned 404. Check SONA_API_BASE_URL points at the running API.';
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
