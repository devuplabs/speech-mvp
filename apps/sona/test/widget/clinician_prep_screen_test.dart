import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sona/design_system/sona_theme.dart';
import 'package:sona/features/clinician/clinician_prep_screen.dart';
import 'package:sona/test_utils/intake_personas.dart';

/// Stage · Consult prep.
///
/// Covers the three draft lifecycle states the clinician sees:
///   - drafting: case loaded, prep brief not yet generated;
///   - ready: prep brief present with probe areas + red flags + DRAFT marker;
///   - failed: draft generation failed server-side (retry prompt).
///
/// Content is built from the shared Jaden persona so probe areas / red flags
/// stay aligned with a realistic intake.

Map<String, dynamic> _baseCase({
  required String status,
  Map<String, dynamic>? prepBrief,
}) {
  final persona = personaById('jaden_stutter_7yo');
  return {
    'case': {
      'id': 'case-jaden',
      'tenantId': 't-1',
      'status': status,
      'parentEmail': persona.parentEmail,
      'childDisplayName': persona.childDisplayName,
    },
    'intake': {
      'id': 'intake-jaden',
      'caseId': 'case-jaden',
      'answers': persona.answers,
      'submittedAt': '2026-06-01T09:00:00Z',
    },
    'drafts': [
      if (prepBrief != null) {'kind': 'prep_brief', 'content': prepBrief},
    ],
  };
}

Map<String, dynamic> _readyBrief() => {
      'label': 'DRAFT — clinician must review',
      'probeAreas': [
        'Confirm primary concern: stuttering since age 4',
        'Check easy-onset breathing strategies tried at home',
      ],
      'redFlags': [
        'Confidence dropping in class — handle pacing carefully',
      ],
      'references': [
        {'title': 'Stammering / fluency overview', 'source': 'RCSLT'},
      ],
    };

Future<void> _pump(WidgetTester tester, Map<String, dynamic>? detail) async {
  tester.view.physicalSize = const Size(1440, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final original = FlutterError.onError;
  FlutterError.onError = (d) {
    if ('${d.exception}'.contains('A RenderFlex overflowed')) return;
    original?.call(d);
  };
  addTearDown(() => FlutterError.onError = original);

  await tester.pumpWidget(MaterialApp(
    theme: sonaTheme(),
    home: Scaffold(
      body: ClinicianPrepScreen(
        caseDetail: detail,
        onContinueTriage: () {},
        onBackToday: () {},
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('drafting state: brief not yet generated shows the drafting banner',
      (tester) async {
    await _pump(tester, _baseCase(status: 'prep_drafting'));

    expect(find.textContaining('still drafting'), findsOneWidget);
    // Placeholder rather than probe bullets.
    expect(
      find.textContaining('Once intake is submitted the AI draft fills'),
      findsOneWidget,
    );
  });

  testWidgets('ready state: probe areas and red flags render from the draft',
      (tester) async {
    await _pump(
      tester,
      _baseCase(status: 'prep_ready', prepBrief: _readyBrief()),
    );

    expect(find.textContaining('Consult ready'), findsOneWidget);
    expect(find.text('Suggested probe areas'), findsOneWidget);
    expect(
      find.textContaining('stuttering since age 4'),
      findsOneWidget,
    );
    expect(find.textContaining('easy-onset breathing'), findsOneWidget);
    // Red flags panel.
    expect(find.text('Red flags'), findsOneWidget);
    expect(
      find.textContaining('Confidence dropping in class'),
      findsOneWidget,
    );
  });

  testWidgets('ready state shows the "DRAFT — clinician must review" marker',
      (tester) async {
    await _pump(
      tester,
      _baseCase(status: 'prep_ready', prepBrief: _readyBrief()),
    );
    expect(find.text('DRAFT — clinician must review'), findsOneWidget);
  });

  testWidgets('failed state: draft generation failure prompts a retry',
      (tester) async {
    await _pump(
      tester,
      _baseCase(status: 'prep_failed'),
    );
    expect(find.textContaining('failed to generate'), findsOneWidget);
    expect(find.textContaining('refresh to retry'), findsOneWidget);
  });

  testWidgets('failed flag on the draft itself also surfaces the failure',
      (tester) async {
    await _pump(
      tester,
      _baseCase(
        status: 'prep_ready',
        prepBrief: {'reviewStatus': 'failed', 'probeAreas': const []},
      ),
    );
    expect(find.textContaining('failed to generate'), findsOneWidget);
  });

  testWidgets('null case detail falls back to the no-case placeholder',
      (tester) async {
    await _pump(tester, null);
    expect(find.text('Consult prep · Client'), findsOneWidget);
    expect(find.textContaining('No case loaded'), findsWidgets);
  });
}
