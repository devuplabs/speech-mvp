import 'package:flutter/foundation.dart';

class SonaAppState extends ChangeNotifier {
  String? tenantId;
  String? caseId;
  String childName = 'Aria M.';
  String parentEmail = 'parent@example.com';
  int formStep = 4;
  final Set<String> selectedConcerns = {'Fussy eater (limited foods)', 'Only eats specific brands/colours'};
  String dentistAnswer = 'Yes';
  bool consentGuardian = true;
  bool consentPrivacy = true;
  bool consentAccurate = false;
  String triageOutcome = 'short_block';
  String prepStatus = 'Ready';

  void resetForDemo() {
    tenantId = null;
    caseId = null;
    formStep = 4;
    selectedConcerns
      ..clear()
      ..addAll(['Fussy eater (limited foods)', 'Only eats specific brands/colours']);
    dentistAnswer = 'Yes';
    consentGuardian = true;
    consentPrivacy = true;
    consentAccurate = false;
    triageOutcome = 'short_block';
    prepStatus = 'Ready';
    notifyListeners();
  }
}
