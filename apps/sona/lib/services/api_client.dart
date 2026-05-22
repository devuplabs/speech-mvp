import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:sona/config/env.dart';
import 'package:sona/utils/api_response.dart';

class SonaApiClient {
  SonaApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  Uri get _base => Uri.parse(Env.apiBaseUrl);

  /// Omit null keys — Zod `.optional()` rejects JSON `null` (expects absent field).
  static String _encodeJson(Map<String, dynamic> body) =>
      jsonEncode(Map<String, dynamic>.fromEntries(
        body.entries.where((e) => e.value != null),
      ));

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
      body: _encodeJson({
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
      body: _encodeJson({
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
      body: _encodeJson({
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

  /// Update the AI-drafted session plan with clinician edits and/or finalise.
  /// [sections] mirrors the API shape: each value is a list of bullet strings.
  Future<Map<String, dynamic>> updateSessionPlan(
    String caseId, {
    Map<String, List<String>>? sections,
    String? reviewStatus,
  }) async {
    final res = await _client.put(
      _base.replace(path: '/v1/cases/$caseId/session-plan'),
      headers: {'Content-Type': 'application/json'},
      body: _encodeJson({
        if (sections != null) 'sections': sections,
        if (reviewStatus != null) 'reviewStatus': reviewStatus,
      }),
    );
    _ensureOk(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> publishParentSummary(
    String caseId, {
    Map<String, dynamic>? options,
  }) async {
    final res = await _client.post(
      _base.replace(path: '/v1/cases/$caseId/parent-summary/publish'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({if (options != null) 'options': options}),
    );
    _ensureOk(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Preview the parent summary — does not persist. Returns
  /// `{html, projection: {title, sections:[{heading,bullets[]}], disclosure}}`.
  Future<Map<String, dynamic>> previewParentSummary(
    String caseId, {
    required Map<String, dynamic> options,
  }) async {
    final res = await _client.post(
      _base.replace(path: '/v1/cases/$caseId/parent-summary/preview'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'options': options}),
    );
    if (res.statusCode != 200) {
      throw SonaApiException(res.statusCode, res.body);
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Absolute URL to the PDF download — handed to the browser via `_blank`.
  Uri parentSummaryPdfUrl(String caseId) =>
      _base.replace(path: '/v1/cases/$caseId/parent-summary.pdf');

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
    if (!isAcceptableHttpStatus(
      res.statusCode,
      expected: expected,
      allowedStatuses: allowedStatuses,
    )) {
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
