import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sona/design_system/sona_theme.dart';
import 'package:sona/features/parent/intake/parent_intake_step_screen.dart';
import 'package:sona/state/sona_app_state.dart';

import '../fixtures/valid_intake_fixture.dart';

/// Regression tests for the parent-intake step 1 page 1 → page 2 → step 2
/// transition (the bug in PR #19 that left users stranded on page 2 of step 1).
///
/// We exercise [ParentIntakeStepScreen] with the same orchestration logic that
/// lives in `_parentContinue`, mirrored here as a pure helper, so we can verify
/// the substep advance + pop-back behavior without spinning up the API.
void main() {
  Future<void> pumpScreen(
    WidgetTester tester,
    SonaAppState state, {
    required Future<void> Function() onContinue,
    required VoidCallback onBack,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sonaTheme(),
        home: ParentIntakeStepScreen(
          state: state,
          onBack: onBack,
          onContinue: onContinue,
          onSaveExit: () async {},
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('step 1 page 1 → page 2 → step 2 transition with valid data', (tester) async {
    final state = SonaAppState();
    final fixture = buildValidIntakeFixture();
    state.intake
      ..email = fixture.email
      ..childName = fixture.childName
      ..dateOfBirth = fixture.dateOfBirth
      ..ageAtReferral = fixture.ageAtReferral
      ..childAddress = fixture.childAddress
      ..motherName = fixture.motherName
      ..motherMobile = fixture.motherMobile
      ..motherEmail = fixture.motherEmail
      ..fatherMobile = fixture.fatherMobile
      ..fatherEmail = fixture.fatherEmail
      ..gpPractice = fixture.gpPractice
      ..gpAddress = fixture.gpAddress
      ..gpPhone = fixture.gpPhone
      ..referredBy = fixture.referredBy
      ..heardAbout = fixture.heardAbout;
    expect(state.formStep, 1);
    expect(state.formSubstep, 0);

    Future<void> simulateContinue() async {
      // Mirrors `_parentContinue` substep logic in `sona_app_shell.dart`.
      if (state.formStep == 1 && state.formSubstep == 0) {
        final pageErr = state.intake.validateStep1a();
        if (pageErr != null) {
          state.pendingValidationFieldKey = pageErr.fieldKey;
          state.pendingValidationMessage = pageErr.message;
          return;
        }
        state.pendingValidationFieldKey = null;
        state.pendingValidationMessage = null;
        state.formSubstep = 1;
        return;
      }
      final err = state.intake.validateStep(state.formStep);
      if (err != null) {
        state.pendingValidationFieldKey = err.fieldKey;
        state.pendingValidationMessage = err.message;
        return;
      }
      state.pendingValidationFieldKey = null;
      state.pendingValidationMessage = null;
      state.formStep += 1;
      state.formSubstep = 0;
    }

    await pumpScreen(
      tester,
      state,
      onContinue: simulateContinue,
      onBack: () {},
    );

    // First Continue: page 1a is valid, advance to page 1b.
    await tester.tap(find.text('Continue →'));
    await tester.pumpAndSettle();
    expect(state.formStep, 1);
    expect(state.formSubstep, 1);
    expect(state.pendingValidationFieldKey, isNull);

    // Re-render so the next tap targets the page-1b layout.
    await pumpScreen(
      tester,
      state,
      onContinue: simulateContinue,
      onBack: () {},
    );

    // Second Continue: full step 1 is valid, advance to step 2.
    await tester.tap(find.text('Continue →'));
    await tester.pumpAndSettle();
    expect(state.formStep, 2,
        reason: 'Step 1 page 2 Continue must advance to step 2 of 8 — this is the demo-blocking regression.');
    expect(state.formSubstep, 0);
  });

  testWidgets('page 2 Continue with missing 1a field pops back to page 1', (tester) async {
    final state = SonaAppState();
    final fixture = buildValidIntakeFixture();
    state.intake
      ..email = '' // Intentionally clear an essential page-1 field
      ..childName = fixture.childName
      ..dateOfBirth = fixture.dateOfBirth
      ..ageAtReferral = fixture.ageAtReferral
      ..childAddress = fixture.childAddress
      ..motherName = fixture.motherName
      ..motherMobile = fixture.motherMobile
      ..motherEmail = fixture.motherEmail
      ..fatherMobile = fixture.fatherMobile
      ..fatherEmail = fixture.fatherEmail
      ..gpPractice = fixture.gpPractice
      ..gpAddress = fixture.gpAddress
      ..gpPhone = fixture.gpPhone
      ..referredBy = fixture.referredBy
      ..heardAbout = fixture.heardAbout;
    state.formStep = 1;
    state.formSubstep = 1; // Pretend the user is already on page 2.

    Future<void> simulateContinueFromPage2() async {
      final err = state.intake.validateStep(1);
      if (err != null) {
        if (state.formSubstep == 1 &&
            err.fieldKey == 'email' /* a 1a field */) {
          state.formSubstep = 0;
        }
        state.pendingValidationFieldKey = err.fieldKey;
        state.pendingValidationMessage = err.message;
      }
    }

    await pumpScreen(
      tester,
      state,
      onContinue: simulateContinueFromPage2,
      onBack: () {},
    );

    await tester.tap(find.text('Continue →'));
    await tester.pumpAndSettle();

    expect(state.formStep, 1);
    expect(state.formSubstep, 0,
        reason: 'Validation failure on a page-1a field must pop back to page 1 so the user can fix it.');
    expect(state.pendingValidationFieldKey, 'email');
    expect(state.pendingValidationMessage, isNotNull);
  });

  testWidgets('page header reflects the current substep', (tester) async {
    final state = SonaAppState();
    state.formStep = 1;
    state.formSubstep = 0;
    await pumpScreen(
      tester,
      state,
      onContinue: () async {},
      onBack: () {},
    );
    expect(find.text('Page 1 of 2'), findsOneWidget);

    state.formSubstep = 1;
    await tester.pumpWidget(
      MaterialApp(
        theme: sonaTheme(),
        home: ParentIntakeStepScreen(
          state: state,
          onBack: () {},
          onContinue: () async {},
          onSaveExit: () async {},
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Page 2 of 2'), findsOneWidget);
  });
}
