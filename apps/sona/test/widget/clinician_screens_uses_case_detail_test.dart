import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sona/design_system/sona_theme.dart';
import 'package:sona/features/clinician/clinician_parent_summary_screen.dart';
import 'package:sona/features/clinician/clinician_prep_screen.dart';
import 'package:sona/features/clinician/clinician_triage_screen.dart';

/// Regression tests for the dashboard → prep/triage/summary bug where every
/// clicked case showed Aria's hardcoded persona. After the fix, each screen
/// renders the child name + intake-derived content from the loaded
/// `caseDetail` map (the `{case, intake, drafts}` shape returned by
/// `GET /v1/cases/:id`).
///
/// We use Jaden (7yo stutter persona) on purpose — Aria's name MUST NOT
/// appear anywhere on the rendered tree when a non-Aria case is loaded.

Map<String, dynamic> _jadenDetail() => {
      'case': {
        'id': 'case-jaden',
        'tenantId': 't-1',
        'status': 'prep_ready',
        'parentEmail': 'lisa.o@example.com',
        'childDisplayName': 'Jaden O.',
      },
      'intake': {
        'id': 'intake-jaden',
        'caseId': 'case-jaden',
        'answers': {
          'childName': 'Jaden O.',
          'email': 'lisa.o@example.com',
          'motherName': 'Lisa O.',
          'mainConcern':
              'Stuttering since age 4 — worse in class presentations.',
          'difficulties': ['Expressing ideas clearly', 'Sitting or standing still'],
          'ageAtReferral': '7',
        },
        'submittedAt': '2026-05-29T10:00:00Z',
      },
      'drafts': [
        {
          'kind': 'prep_brief',
          'content': {
            'label': 'DRAFT — clinician must review',
            'probeAreas': [
              'Confirm primary concern with parent: "Stuttering since age 4"',
              'Check easy-onset breathing strategies tried at home',
            ],
            'redFlags': [
              'Confidence dropping in class — handle pacing carefully',
            ],
            'references': [
              {
                'title': 'Stammering / fluency overview',
                'source': 'RCSLT clinical guidance',
              },
            ],
          },
        },
        {
          'kind': 'session_plan',
          'content': {
            'reviewStatus': 'final',
            'sections': {
              'goals': [
                'Baseline % syllables stuttered across 3 contexts.',
                'Reduce avoidance behaviours in low-pressure contexts.',
              ],
              'homePractice': [
                'Slow conversation game at dinner.',
                "Daily 5-minute 'special time' with no interruptions.",
              ],
            },
          },
        },
      ],
    };

Future<void> _pumpPrep(WidgetTester tester, Map<String, dynamic>? detail) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final original = FlutterError.onError;
  FlutterError.onError = (d) {
    final m = '${d.exception}';
    if (m.contains('A RenderFlex overflowed')) return;
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
  testWidgets('prep screen header reads child name from caseDetail (not Aria)',
      (tester) async {
    await _pumpPrep(tester, _jadenDetail());
    expect(find.textContaining('Jaden O.'), findsWidgets,
        reason: 'Clicked Jaden — Jaden\'s name must render');
    expect(find.textContaining('Aria'), findsNothing,
        reason: 'Aria must not appear when a different case is loaded');
  });

  testWidgets('prep screen renders intake-derived concern + difficulties',
      (tester) async {
    await _pumpPrep(tester, _jadenDetail());
    expect(find.textContaining('Stuttering since age 4'), findsWidgets);
    expect(find.text('Expressing ideas clearly'), findsOneWidget);
    expect(find.text('Sitting or standing still'), findsOneWidget);
  });

  testWidgets('prep screen renders AI-drafted probe areas from prep_brief',
      (tester) async {
    await _pumpPrep(tester, _jadenDetail());
    expect(find.text('Suggested probe areas'), findsOneWidget);
    expect(
      find.textContaining('Stuttering since age 4'),
      findsWidgets,
    );
    expect(find.textContaining('easy-onset'), findsWidgets);
  });

  testWidgets('prep screen falls back to placeholder when caseDetail is null',
      (tester) async {
    await _pumpPrep(tester, null);
    expect(find.text('Consult prep · Client'), findsOneWidget);
    expect(find.textContaining('No case loaded'), findsWidgets);
    expect(find.textContaining('Aria'), findsNothing);
  });

  testWidgets('triage screen header reads child name from caseDetail (not Aria)',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final original = FlutterError.onError;
    FlutterError.onError = (d) {
      final m = '${d.exception}';
      if (m.contains('A RenderFlex overflowed')) return;
      original?.call(d);
    };
    addTearDown(() => FlutterError.onError = original);

    await tester.pumpWidget(MaterialApp(
      theme: sonaTheme(),
      home: Scaffold(
        body: ClinicianTriageScreen(
          caseDetail: _jadenDetail(),
          onPublishSummary: () {},
          onBackPrep: () {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Jaden O.'), findsWidgets);
    expect(find.textContaining('Aria'), findsNothing);
  });

  testWidgets(
      'parent summary screen renders child name + intake-derived bullets (not Aria)',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final original = FlutterError.onError;
    FlutterError.onError = (d) {
      final m = '${d.exception}';
      if (m.contains('A RenderFlex overflowed')) return;
      original?.call(d);
    };
    addTearDown(() => FlutterError.onError = original);

    await tester.pumpWidget(MaterialApp(
      theme: sonaTheme(),
      home: ClinicianParentSummaryScreen(
        caseDetail: _jadenDetail(),
        summaryHtml: null,
        onBackClinician: () {},
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text("Jaden O.'s consultation summary"), findsOneWidget);
    expect(find.textContaining('Stuttering since age 4'), findsWidgets);
    // The session-plan-derived bullets surface in the parent's "what happens
    // next" / "for you at home" panels instead of Aria's hardcoded list.
    expect(find.textContaining('syllables stuttered'), findsWidgets);
    expect(find.textContaining('Slow conversation game'), findsWidgets);
    expect(find.textContaining('Aria'), findsNothing);
  });
}
