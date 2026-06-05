import 'package:http/http.dart' as http;

/// An [http.Client] that attaches `Authorization: Bearer <token>` from an async
/// token provider (the Firebase ID token) to every outgoing request.
///
/// Wrapping the client this way lets [SonaApiClient] gain authentication without
/// touching each call site (Auth·06). Requests with no available token are sent
/// unchanged, so unauthenticated endpoints (e.g. parent intake links) keep
/// working.
class AuthedHttpClient extends http.BaseClient {
  AuthedHttpClient({
    required Future<String?> Function() tokenProvider,
    http.Client? inner,
  })  // Keep a public `tokenProvider` param name (an initializing formal would
      // expose the private field name to callers).
      // ignore: prefer_initializing_formals
      : _tokenProvider = tokenProvider,
        _inner = inner ?? http.Client();

  final Future<String?> Function() _tokenProvider;
  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final token = await _tokenProvider();
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
