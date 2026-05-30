import 'dart:convert';

import 'package:sona/services/api_client.dart';
import 'package:sona/utils/intake_field_labels.dart';

/// One field-level issue from a `validation_failed` API response.
typedef ApiFieldIssue = ({String fieldKey, String label, String message});

/// Parsed API validation payload for routing to the intake form.
class ApiValidationFailure {
  ApiValidationFailure({required this.issues});

  final List<ApiFieldIssue> issues;

  String? get firstFieldKey => issues.isEmpty ? null : issues.first.fieldKey;

  String get summaryMessage {
    if (issues.isEmpty) return 'Some answers are invalid. Check required fields.';
    final parts = issues
        .map((i) => '${i.label} (${i.message})')
        .join(', ');
    return 'Please fix: $parts.';
  }
}

String _normalizeFieldKey(String raw) {
  final key = raw.trim();
  if (key.startsWith('answers.')) return key.substring('answers.'.length);
  return key;
}

String _messageForField(dynamic raw) {
  if (raw is List && raw.isNotEmpty) {
    return raw.first.toString();
  }
  return raw?.toString() ?? 'invalid';
}

/// Returns structured validation when [error] is a 400 `validation_failed` body.
ApiValidationFailure? parseApiValidationFailure(SonaApiException error) {
  if (error.statusCode != 400 || !error.body.contains('validation_failed')) {
    return null;
  }
  try {
    final map = jsonDecode(error.body) as Map<String, dynamic>;
    final issuesRoot = map['issues'];
    if (issuesRoot is! Map<String, dynamic>) return null;

    final fieldErrors = issuesRoot['fieldErrors'];
    final formErrors = issuesRoot['formErrors'];

    final issues = <ApiFieldIssue>[];

    if (fieldErrors is Map) {
      for (final entry in fieldErrors.entries) {
        final key = _normalizeFieldKey(entry.key.toString());
        issues.add((
          fieldKey: key,
          label: IntakeFieldLabels.labelFor(key),
          message: _messageForField(entry.value),
        ));
      }
    }

    if (formErrors is List) {
      for (final err in formErrors) {
        final msg = err.toString();
        if (msg.isNotEmpty) {
          issues.add((
            fieldKey: 'form',
            label: 'Form',
            message: msg,
          ));
        }
      }
    }

    if (issues.isEmpty) return null;
    return ApiValidationFailure(issues: issues);
  } catch (_) {
    return null;
  }
}

/// User-facing hint when Flutter web cannot reach the API.
String friendlyApiError(Object error) {
  if (error is SonaApiException) {
    final validation = parseApiValidationFailure(error);
    if (validation != null) {
      return validation.summaryMessage;
    }
    if (error.statusCode == 400 && error.body.contains('validation_failed')) {
      final excerpt = error.body.length > 160
          ? '${error.body.substring(0, 157)}…'
          : error.body;
      return 'Validation failed (${error.statusCode}): $excerpt';
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
