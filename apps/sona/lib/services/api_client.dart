import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:sona/config/env.dart';

class SonaApiClient {
  SonaApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  Uri get _base => Uri.parse(Env.apiBaseUrl);

  Future<Map<String, dynamic>> health() async {
    final res = await _client.get(_base.replace(path: '/health'));
    _ensureOk(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createTenant(String displayName) async {
    final res = await _client.post(
      _base.replace(path: '/v1/tenants'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'displayName': displayName}),
    );
    _ensureOk(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createCase({
    required String tenantId,
    String? parentEmail,
    String? childDisplayName,
  }) async {
    final res = await _client.post(
      _base.replace(path: '/v1/cases'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'tenantId': tenantId,
        'parentEmail': parentEmail,
        'childDisplayName': childDisplayName,
      }),
    );
    _ensureOk(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getCase(String caseId) async {
    final res = await _client.get(_base.replace(path: '/v1/cases/$caseId'));
    _ensureOk(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> submitIntake(
    String caseId, {
    required Map<String, dynamic> answers,
    String? parentEmail,
  }) async {
    final res = await _client.post(
      _base.replace(path: '/v1/cases/$caseId/intake'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'answers': answers,
        'consentVersion': 'mvp-v0.1',
        'parentEmail': ?parentEmail,
      }),
    );
    _ensureOk(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  void _ensureOk(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw SonaApiException(res.statusCode, res.body);
    }
  }
}

class SonaApiException implements Exception {
  SonaApiException(this.statusCode, this.body);
  final int statusCode;
  final String body;

  @override
  String toString() => 'SonaApiException($statusCode): $body';
}
