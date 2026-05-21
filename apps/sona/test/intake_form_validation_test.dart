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
