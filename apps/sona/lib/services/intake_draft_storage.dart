import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
/// Local draft backup — never log contents (PHI).
class IntakeDraftStorage {
  static const _keyPrefix = 'sona_intake_draft_';
  static const _lastCaseKey = 'sona_intake_last_case_id';

  Future<void> saveLastCaseId(String caseId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastCaseKey, caseId);
  }

  Future<String?> loadLastCaseId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastCaseKey);
  }

  Future<void> clearLastCaseId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastCaseKey);
  }

  Future<void> saveLocal({
    required String caseId,
    required Map<String, dynamic> answers,
    required int formStep,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode({
      'caseId': caseId,
      'formStep': formStep,
      'savedAt': DateTime.now().toIso8601String(),
      'answers': answers,
    });
    await prefs.setString('$_keyPrefix$caseId', payload);
  }

  Future<({Map<String, dynamic> answers, int formStep})?> loadLocal(String caseId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_keyPrefix$caseId');
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final answers = map['answers'] as Map<String, dynamic>? ?? {};
      final step = map['formStep'] as int? ?? 1;
      return (answers: answers, formStep: step);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearLocal(String caseId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_keyPrefix$caseId');
  }
}
