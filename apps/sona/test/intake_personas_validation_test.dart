import 'package:flutter_test/flutter_test.dart';
import 'package:sona/test_utils/intake_personas.dart';

/// Each persona must satisfy `IntakeFormData.validateStep(1..8)` so the
/// dev-only "Fill sample" button + seed script never produce a payload that
/// cannot reach submit.
void main() {
  for (final p in intakePersonas) {
    test('persona ${p.id} passes validation for all 8 steps', () {
      final form = p.toFormData();
      for (var step = 1; step <= 8; step++) {
        final err = form.validateStep(step);
        expect(err, isNull,
            reason: 'Persona ${p.id} failed step $step: '
                '${err?.message} (field: ${err?.fieldKey})');
      }
    });
  }
}
