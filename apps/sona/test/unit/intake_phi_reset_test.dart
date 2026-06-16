import 'package:flutter_test/flutter_test.dart';
import 'package:sona/state/sona_app_state.dart';

/// PHI must never bleed between users/cases on a shared device (DEV-73).
/// `resetIntake()` is the single clear used on sign-out, on a fresh intake, and
/// after submit, so these tests pin that it wipes every intake field + flag.
void main() {
  SonaAppState seededState() {
    final s = SonaAppState();
    s.intake
      ..email = 'parent@example.com'
      ..childName = 'Ada Lovelace'
      ..dateOfBirth = '10/12/2019'
      ..motherMobile = '07000000000'
      ..mainConcern = 'late talking'
      ..diagnosis = 'none'
      ..completedBy = 'Mary Lovelace';
    s.intake.difficulties.add('expression');
    s.formStep = 5;
    s.formSubstep = 1;
    s.returnToReviewAfterEdit = true;
    s.draftDirty = true;
    s.consentGuardian = true;
    s.consentPrivacy = true;
    s.consentAccurate = true;
    s.pendingValidationFieldKey = 'mainConcern';
    s.pendingValidationMessage = 'required';
    s.intakeLocked = true;
    s.intakeLinkExpired = true;
    return s;
  }

  group('SonaAppState.resetIntake', () {
    test('clears all intake PHI fields', () {
      final s = seededState();
      s.resetIntake();
      expect(s.intake.email, '');
      expect(s.intake.childName, '');
      expect(s.intake.dateOfBirth, '');
      expect(s.intake.motherMobile, '');
      expect(s.intake.mainConcern, '');
      expect(s.intake.diagnosis, '');
      expect(s.intake.completedBy, '');
      expect(s.intake.difficulties, isEmpty);
    });

    test('resets per-intake form, consent and validation flags', () {
      final s = seededState();
      s.resetIntake();
      expect(s.formStep, 1);
      expect(s.formSubstep, 0);
      expect(s.returnToReviewAfterEdit, isFalse);
      expect(s.draftDirty, isFalse);
      expect(s.consentGuardian, isFalse);
      expect(s.consentPrivacy, isFalse);
      expect(s.consentAccurate, isFalse);
      expect(s.pendingValidationFieldKey, isNull);
      expect(s.pendingValidationMessage, isNull);
      expect(s.intakeLocked, isFalse);
      expect(s.intakeLinkExpired, isFalse);
    });

    test('notifies listeners so dependent widgets rebuild', () {
      final s = seededState();
      var notified = 0;
      s.addListener(() => notified++);
      s.resetIntake();
      expect(notified, greaterThan(0));
    });

    test('resetForDemo also clears all intake PHI, not just a few fields', () {
      final s = seededState();
      s.resetForDemo();
      expect(s.intake.childName, '');
      expect(s.intake.mainConcern, '');
      expect(s.intake.completedBy, '');
      expect(s.intake.difficulties, isEmpty);
    });
  });
}
