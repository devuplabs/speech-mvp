import 'package:flutter_test/flutter_test.dart';
import 'fixtures/valid_intake_fixture.dart';

void main() {
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

  test('missing email fails step 1', () {
    final intake = buildValidIntakeFixture()..email = '';
    expect(intake.validateStep(1), isNotNull);
  });

  test('empty difficulties fails step 2', () {
    final intake = buildValidIntakeFixture()..difficulties.clear();
    expect(intake.validateStep(2), isNotNull);
  });
}
