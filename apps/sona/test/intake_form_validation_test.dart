import 'package:flutter_test/flutter_test.dart';
import 'package:sona/utils/intake_validation.dart';
import 'fixtures/valid_intake_fixture.dart';

void main() {
  // ---- computeAgeAtReferral unit tests ----

  test('computeAgeAtReferral returns correct years and months', () {
    final result = IntakeValidation.computeAgeAtReferral(
      '15 / 03 / 2019',
      now: DateTime(2026, 5, 22),
    );
    expect(result, '7 years, 2 months');
  });

  test('computeAgeAtReferral handles exactly N years (no months)', () {
    final result = IntakeValidation.computeAgeAtReferral(
      '22 / 05 / 2021',
      now: DateTime(2026, 5, 22),
    );
    expect(result, '5 years');
  });

  test('computeAgeAtReferral handles months-only (under 1 year)', () {
    final result = IntakeValidation.computeAgeAtReferral(
      '01 / 02 / 2026',
      now: DateTime(2026, 5, 22),
    );
    expect(result, '3 months');
  });

  test('computeAgeAtReferral returns null for invalid DOB', () {
    expect(IntakeValidation.computeAgeAtReferral('not-a-date'), isNull);
    expect(IntakeValidation.computeAgeAtReferral(''), isNull);
  });

  test('computeAgeAtReferral returns null for future DOB', () {
    final result = IntakeValidation.computeAgeAtReferral(
      '01 / 01 / 2030',
      now: DateTime(2026, 5, 22),
    );
    expect(result, isNull);
  });

  test('ageAtReferral getter on IntakeFormData computes from dateOfBirth', () {
    final intake = buildValidIntakeFixture();
    // fixture DOB = 01 / 05 / 2019; running with system clock but value is non-empty
    expect(intake.ageAtReferral, isNotEmpty);
    expect(intake.ageAtReferral, contains('year'));
  });

  test('completionDate is not in IntakeFormData.toJson()', () {
    final intake = buildValidIntakeFixture();
    final json = intake.toJson();
    expect(json.containsKey('completionDate'), isFalse,
        reason: 'completionDate must not appear in the client payload — server sets it');
  });

  test('step 8 validation no longer requires completionDate', () {
    final intake = buildValidIntakeFixture();
    // completionDate not set — should still pass step 8
    final err = intake.validateStep(8);
    expect(err, isNull, reason: 'step 8 must pass without completionDate');
  });

  test('father fields are optional when fatherDetailsApplicable=false', () {
    final intake = buildValidIntakeFixture()
      ..fatherDetailsApplicable = false
      ..fatherMobile = ''
      ..fatherEmail = '';
    final err = intake.validateStep(1);
    expect(err, isNull,
        reason: 'step 1 must pass without father fields when single-parent toggle is off');
  });

  test('father fields are required when fatherDetailsApplicable=true', () {
    final intake = buildValidIntakeFixture()
      ..fatherDetailsApplicable = true
      ..fatherMobile = '';
    final err = intake.validateStep(1);
    expect(err, isNotNull);
    expect(err!.fieldKey, 'fatherMobile');
  });

  // ---- existing tests ----

  test('valid intake fixture passes validation for all 8 steps', () {
    final intake = buildValidIntakeFixture();
    for (var step = 1; step <= 8; step++) {
      expect(
        intake.validateStep(step),
        isNull,
        reason: 'step $step should be valid',
      );
    }
  });

  test('missing email fails step 1 with fieldKey=email', () {
    final intake = buildValidIntakeFixture()..email = '';
    final err = intake.validateStep(1);
    expect(err, isNotNull);
    expect(err!.fieldKey, 'email');
  });

  test('empty difficulties fails step 2 with fieldKey=difficulties', () {
    final intake = buildValidIntakeFixture()..difficulties.clear();
    final err = intake.validateStep(2);
    expect(err, isNotNull);
    expect(err!.fieldKey, 'difficulties');
  });

  test('missing GP phone fails step 1 with fieldKey=gpPhone', () {
    final intake = buildValidIntakeFixture()..gpPhone = '';
    final err = intake.validateStep(1);
    expect(err, isNotNull);
    expect(err!.fieldKey, 'gpPhone');
  });
}
