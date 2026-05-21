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

  Future<String> bootstrapDemoTenant() async {
    final res = await _client.post(
      _base.replace(path: '/v1/demo/bootstrap'),
      headers: {'Content-Type': 'application/json'},
      body: '{}',
    );
    // 200 when reusing existing demo tenant; 201 when first created
    _ensureOk(res, allowedStatuses: {200, 201});
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return body['tenantId'] as String;
  }

  Future<Map<String, dynamic>> createTenant(String displayName) async {
    final res = await _client.post(
      _base.replace(path: '/v1/tenants'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'displayName': displayName}),
    );
    _ensureOk(res, expected: 201);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> listCases(String tenantId) async {
    final res = await _client.get(
      _base.replace(path: '/v1/tenants/$tenantId/cases'),
    );
    _ensureOk(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final list = body['cases'] as List<dynamic>? ?? [];
    return list.cast<Map<String, dynamic>>();
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
    _ensureOk(res, expected: 201);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getCase(String caseId) async {
    final res = await _client.get(_base.replace(path: '/v1/cases/$caseId'));
    _ensureOk(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> saveIntakeDraft(
    String caseId, {
    required Map<String, dynamic> answers,
    String? parentEmail,
    String? childDisplayName,
  }) async {
    final res = await _client.put(
      _base.replace(path: '/v1/cases/$caseId/intake/draft'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'answers': answers,
        'parentEmail': parentEmail,
        'childDisplayName': childDisplayName,
      }),
    );
    _ensureOk(res);
  }

  Future<Map<String, dynamic>> submitIntake(
    String caseId, {
    required Map<String, dynamic> answers,
    String? parentEmail,
    String? childDisplayName,
  }) async {
    final res = await _client.post(
      _base.replace(path: '/v1/cases/$caseId/intake'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'answers': answers,
        'consentVersion': 'mvp-v1',
        'parentEmail': parentEmail,
        'childDisplayName': childDisplayName,
      }),
    );
    _ensureOk(res, expected: 201);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> recordTriage(
    String caseId, {
    required String outcome,
    String? reason,
  }) async {
    final res = await _client.post(
      _base.replace(path: '/v1/cases/$caseId/triage'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'outcome': outcome, 'reason': reason}),
    );
    _ensureOk(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> publishParentSummary(String caseId) async {
    final res = await _client.post(
      _base.replace(path: '/v1/cases/$caseId/parent-summary/publish'),
      headers: {'Content-Type': 'application/json'},
      body: '{}',
    );
    _ensureOk(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<String> fetchParentSummaryHtml(String caseId) async {
    final res = await _client.get(
      _base.replace(path: '/v1/cases/$caseId/parent-summary'),
    );
    if (res.statusCode != 200) {
      throw SonaApiException(res.statusCode, res.body);
    }
    return res.body;
  }

  void _ensureOk(
    http.Response res, {
    int? expected,
    Set<int>? allowedStatuses,
  }) {
    final ok = res.statusCode >= 200 && res.statusCode < 300;
    final statusOk = allowedStatuses != null
        ? allowedStatuses.contains(res.statusCode)
        : expected == null || res.statusCode == expected;
    if (!ok || !statusOk) {
      throw SonaApiException(res.statusCode, res.body);
    }
  }
}

class SonaApiException implements Exception {
  SonaApiException(this.statusCode, this.body);
  final int statusCode;
  final String body;

  bool get isNotFound =>
      statusCode == 404 && body.contains('not_found');

  @override
  String toString() => 'SonaApiException($statusCode): $body';
}
