import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sona/design_system/sona_theme.dart';
import 'package:sona/features/clinician/clinician_prep_screen.dart';

/// Widget tests for [ClinicianPrepScreen] rendering against the real shape
/// returned by `GET /v1/cases/:id` (case + intake + drafts[]). The shapes
/// here match what `buildStubPrepBrief` produces in `apps/api`, so a UI
/// regression and a backend-shape regression both fail loudly.
void main() {
  Future<void> pump(WidgetTester tester, Map<String, dynamic>? detail) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      final msg = '${details.exception}';
      if (msg.contains('A RenderFlex overflowed')) return;
      originalOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = originalOnError);

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

  Map<String, dynamic> ariaCase() => {
        'case': {
          'id': 'case-1',
          'tenantId': 't-1',
          'status': 'prep_ready',
          'parentEmail': 'anna.m@example.com',
          'childDisplayName': 'Aria M.',
        },
        'intake': {
          'id': 'intake-1',
          'caseId': 'case-1',
          'answers': {
            'childName': 'Aria M.',
            'email': 'anna.m@example.com',
            'motherName': 'Anna M.',
            'completedBy': 'Anna M. (mother)',
            'mainConcern':
                'Hard to understand at nursery — drops final consonants.',
            'difficulties': ['Speech sounds', 'Staying on task'],
            'ageAtReferral': '4',
            'senPlan': 'No EHCP; on SENCO monitor',
          },
          'submittedAt': '2026-05-22T03:00:00Z',
        },
        'drafts': [
          {
            'kind': 'prep_brief',
            'content': {
              'label': 'DRAFT — clinician must review',
              'probeAreas': [
                'Confirm primary concern with parent: "Hard to understand..."',
                'Sample top difficulties in 1:1 play: Speech sounds, Staying on task',
              ],
              'redFlags': [
                'No red flags from intake — confirm in conversation',
              ],
              'references': [
                {
                  'title': 'Speech sound disorder',
                  'source': 'RCSLT clinical guidance',
                  'url':
                      'https://www.rcslt.org/members/clinical-guidance/speech-sound-disorder/',
                },
              ],
            },
          },
        ],
      };

  testWidgets('renders child snapshot from real case detail', (tester) async {
    await pump(tester, ariaCase());

    expect(find.text('Consult prep · Aria M.'), findsOneWidget);
    expect(find.textContaining('Anna M.'), findsWidgets);
    expect(find.textContaining('anna.m@example.com'), findsWidgets);
    expect(find.textContaining('Hard to understand'), findsWidgets);
    expect(find.text('Speech sounds'), findsOneWidget);
    expect(find.text('Staying on task'), findsOneWidget);
  });

  testWidgets('renders AI-drafted probe areas from prep_brief',
      (tester) async {
    await pump(tester, ariaCase());

    expect(find.text('Suggested probe areas'), findsOneWidget);
    expect(find.textContaining('Confirm primary concern'), findsWidgets);
    expect(
      find.textContaining('Sample top difficulties'),
      findsWidgets,
    );
  });

  testWidgets('renders the AI-draft badge for the prep brief',
      (tester) async {
    await pump(tester, ariaCase());
    expect(find.textContaining('AI-drafted'), findsWidgets);
  });

  testWidgets('renders red-flag + references panels from the draft',
      (tester) async {
    await pump(tester, ariaCase());
    expect(find.text('Red flags'), findsOneWidget);
    expect(find.text('References'), findsOneWidget);
    expect(find.textContaining('RCSLT'), findsWidgets);
    expect(find.textContaining('Speech sound disorder'), findsWidgets);
  });

  testWidgets('falls back gracefully when no case is loaded yet',
      (tester) async {
    await pump(tester, null);

    expect(find.text('Consult prep · Client'), findsOneWidget);
    expect(
      find.textContaining('No case loaded'),
      findsWidgets,
    );
    // Continue button is disabled until a case is loaded.
    final filled = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(filled.onPressed, isNull);
  });

  testWidgets('falls back when intake submitted but prep brief not drafted yet',
      (tester) async {
    final detail = {
      'case': {
        'id': 'case-2',
        'tenantId': 't-1',
        'status': 'prep_drafting',
        'parentEmail': 'p@example.com',
        'childDisplayName': 'Jaden O.',
      },
      'intake': {
        'id': 'intake-2',
        'answers': {
          'childName': 'Jaden O.',
          'mainConcern': 'Stuttering since age 4',
        },
      },
      'drafts': const <Map<String, dynamic>>[],
    };

    await pump(tester, detail);

    expect(find.text('Consult prep · Jaden O.'), findsOneWidget);
    expect(
      find.textContaining('No prep brief yet'),
      findsWidgets,
    );
  });
}
