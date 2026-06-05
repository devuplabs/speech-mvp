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
      body: jsonEncode({'practice': 'demo'}),
    );
    // 200 when reusing existing demo tenant; 201 when first created
    _ensureOk(res, allowedStatuses: {200, 201});
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return body['tenantId'] as String;
  }

  /// Roster (screen 04). Returns `{ clinicians: [...], seatsUsed }`.
  Future<Map<String, dynamic>> listPracticeClinicians(String practiceId) async {
    final res = await _client.get(
      _base.replace(path: '/v1/practices/$practiceId/clinicians'),
    );
    _ensureOk(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Invite a clinician (screen 04) — triggers the Auth·05 invite email.
  Future<Map<String, dynamic>> inviteClinician(
    String practiceId, {
    required String email,
    String? fullName,
    String role = 'clinician',
  }) async {
    final res = await _client.post(
      _base.replace(path: '/v1/practices/$practiceId/clinicians'),
      headers: {'Content-Type': 'application/json'},
      body: _encodeJson({'email': email, 'fullName': fullName, 'role': role}),
    );
    _ensureOk(res, allowedStatuses: {200, 201});
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Bulk invite via CSV import (screen 04).
  Future<Map<String, dynamic>> importClinicians(
    String practiceId,
    List<Map<String, dynamic>> clinicians,
  ) async {
    final res = await _client.post(
      _base.replace(path: '/v1/practices/$practiceId/clinicians/import'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'clinicians': clinicians}),
    );
    _ensureOk(res, allowedStatuses: {200, 201});
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Finish setup (screen 04 → 05). Activates the practice.
  Future<Map<String, dynamic>> activatePractice(String practiceId) async {
    final res = await _client.post(
      _base.replace(path: '/v1/practices/$practiceId/activate'),
      headers: {'Content-Type': 'application/json'},
      body: '{}',
    );
    _ensureOk(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Practice config (screen 03). Updates name / location / specialties.
  Future<Map<String, dynamic>> updatePracticeConfig(
    String practiceId, {
    String? practiceName,
    String? location,
    List<String>? specialties,
  }) async {
    final res = await _client.patch(
      _base.replace(path: '/v1/practices/$practiceId'),
      headers: {'Content-Type': 'application/json'},
      body: _encodeJson({
        'practiceName': practiceName,
        'location': location,
        'specialties': specialties,
      }),
    );
    _ensureOk(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Plan & seats (screen 02). Sets the practice `mode` + `seats`.
  Future<Map<String, dynamic>> updatePlan(
    String practiceId, {
    required String mode,
    required int seats,
  }) async {
    final res = await _client.patch(
      _base.replace(path: '/v1/practices/$practiceId/plan'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'mode': mode, 'seats': seats}),
    );
    _ensureOk(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Admin sign-up (screen 01). Creates the practice + admin seat from the
  /// caller's verified Firebase token. Returns `{ practice, admin }`.
  Future<Map<String, dynamic>> createPractice({
    required String practiceName,
    required String adminFullName,
    String? adminEmail,
  }) async {
    final res = await _client.post(
      _base.replace(path: '/v1/practices'),
      headers: {'Content-Type': 'application/json'},
      body: _encodeJson({
        'practiceName': practiceName,
        'adminFullName': adminFullName,
        'adminEmail': adminEmail,
      }),
    );
    _ensureOk(res, allowedStatuses: {200, 201});
    return jsonDecode(res.body) as Map<String, dynamic>;
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


  Future<List<Map<String, dynamic>>> listIntakeSubmissions(String tenantId) async {
    final res = await _client.get(
      _base.replace(path: '/v1/tenants/$tenantId/intake-submissions'),
    );
    _ensureOk(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['items'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> resendIntakeLink(
    String caseId, {
    String? templateId,
  }) async {
    final res = await _client.post(
      _base.replace(path: '/v1/cases/$caseId/intake-links/resend'),
      headers: {'Content-Type': 'application/json'},
      body: _encodeJson({'templateId': templateId}),
    );
    _ensureOk(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> revokeIntakeLink(String caseId) async {
    final res = await _client.post(
      _base.replace(path: '/v1/cases/$caseId/intake-links/revoke'),
      headers: {'Content-Type': 'application/json'},
      body: '{}',
    );
    _ensureOk(res, allowedStatuses: {204});
  }

  Future<void> lockIntake(String caseId) async {
    final res = await _client.post(
      _base.replace(path: '/v1/cases/$caseId/intake/lock'),
      headers: {'Content-Type': 'application/json'},
      body: '{}',
    );
    _ensureOk(res, allowedStatuses: {204});
  }

  Future<Map<String, dynamic>> registerPatient({
    required String tenantId,
    required String childFirstName,
    required String dateOfBirth,
    required String parentName,
    required String parentEmail,
    String? parentPhone,
    required String referralSource,
    String? initialConcerns,
    bool sendIntakeLink = true,
    String? templateId,
    String? bookConsultStart,
    int bookConsultDurationMinutes = 20,
  }) async {
    final res = await _client.post(
      _base.replace(path: '/v1/clinicians/me/patients'),
      headers: {'Content-Type': 'application/json'},
      body: _encodeJson({
        'tenantId': tenantId,
        'childFirstName': childFirstName,
        'dateOfBirth': dateOfBirth,
        'parentName': parentName,
        'parentEmail': parentEmail,
        'parentPhone': parentPhone,
        'referralSource': referralSource,
        'initialConcerns': initialConcerns,
        'sendIntakeLink': sendIntakeLink,
        'templateId': templateId,
        if (bookConsultStart != null)
          'bookConsult': {
            'start': bookConsultStart,
            'durationMinutes': bookConsultDurationMinutes,
          },
      }),
    );
    _ensureOk(res, allowedStatuses: {200, 201});
    return jsonDecode(res.body) as Map<String, dynamic>;
  }


  Future<List<Map<String, dynamic>>> listClinicalReports(String tenantId) async {
    final res = await _client.get(
      _base.replace(path: '/v1/tenants/$tenantId/clinical-reports'),
    );
    _ensureOk(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['items'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> fetchClinicalReport(String caseId) async {
    final res = await _client.get(
      _base.replace(path: '/v1/cases/$caseId/clinical-report'),
    );
    _ensureOk(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> generateClinicalReport(String caseId) async {
    final res = await _client.post(
      _base.replace(path: '/v1/cases/$caseId/clinical-report/generate'),
      headers: {'Content-Type': 'application/json'},
      body: '{}',
    );
    _ensureOk(res);
  }

  String clinicalReportPdfUrl(String caseId) =>
      _base.replace(path: '/v1/cases/$caseId/clinical-report.pdf').toString();

  Future<Map<String, dynamic>> resolveIntakeLink(String token) async {
    final res = await _client.get(
      _base.replace(path: '/v1/intake-links/$token'),
    );
    _ensureOk(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }


  Future<List<Map<String, dynamic>>> fetchAvailabilitySlots(
    String tenantId, {
    String? from,
    String? to,
  }) async {
    final fromQ = from ?? DateTime.now().toUtc().toIso8601String();
    final toQ = to ?? DateTime.now().add(const Duration(days: 14)).toUtc().toIso8601String();
    final res = await _client.get(
      _base.replace(
        path: '/v1/clinicians/me/availability',
        queryParameters: {
          'tenantId': tenantId,
          'from': fromQ,
          'to': toQ,
        },
      ),
    );
    _ensureOk(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['slots'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchAvailabilityRules(String tenantId) async {
    final res = await _client.get(
      _base.replace(
        path: '/v1/clinicians/me/availability/rules',
        queryParameters: {'tenantId': tenantId},
      ),
    );
    _ensureOk(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['rules'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> saveAvailabilityRules(
    String tenantId,
    List<Map<String, dynamic>> rules,
  ) async {
    final res = await _client.put(
      _base.replace(path: '/v1/clinicians/me/availability/rules'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'tenantId': tenantId, 'rules': rules}),
    );
    _ensureOk(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['rules'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> bookConsult(
    String caseId, {
    required String start,
    int durationMinutes = 20,
  }) async {
    final res = await _client.post(
      _base.replace(path: '/v1/cases/$caseId/consult'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'start': start, 'durationMinutes': durationMinutes}),
    );
    _ensureOk(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<String> fetchConsultIcs(String caseId) async {
    final res = await _client.get(_base.replace(path: '/v1/cases/$caseId/consult.ics'));
    _ensureOk(res);
    return res.body;
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
