/// User-facing hint when Flutter web cannot reach the API.
String friendlyApiError(Object error) {
  final msg = error.toString();
  if (msg.contains('Failed to fetch') ||
      msg.contains('ClientException') ||
      msg.contains('XMLHttpRequest')) {
    return 'Cannot reach the API from the browser (often CORS). '
        'Redeploy the API with CORS enabled, or run the API locally on port 8080.';
  }
  return msg;
}
