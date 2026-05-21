/// User-facing hint when Flutter web cannot reach the API.
String friendlyApiError(Object error) {
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
