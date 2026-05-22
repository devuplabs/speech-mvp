import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sona/design_system/sona_theme.dart';
import 'package:sona/features/clinician/clinician_session_plan_screen.dart';

void main() {
  Map<String, dynamic> ariaPlanCase() => {
        'case': {
          'id': 'case-1',
          'tenantId': 't-1',
          'status': 'plan_ready',
          'childDisplayName': 'Aria M.',
        },
        'intake': {
          'answers': {
            'mainConcern': 'Speech sound delay',
            'difficulties': ['Speech sounds'],
          },
        },
        'drafts': [
          {
            'kind': 'session_plan',
            'content': {
              'label': 'DRAFT — clinician must review',
              'reviewStatus': 'draft',
              'sections': {
                'goals': [
                  'Establish baseline of speech-sound inventory (DEAP screen).',
                  'Identify 2–3 priority targets.',
                ],
                'activities': ['Play-based articulation probe.'],
                'homePractice': ["5 minutes daily of 'silly sound' play."],
                'materials': ['DEAP articulation cards'],
                'parentGoals': ['Notice + acknowledge clear speech.'],
              },
              'source': 'mvp_stub',
            },
          },
        ],
      };

  Future<({Map<String, List<String>>? sections, String? reviewStatus})> pump(
    WidgetTester tester, {
    Map<String, dynamic>? caseDetail,
  }) async {
    tester.view.physicalSize = const Size(1440, 1200);
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

    Map<String, List<String>>? savedSections;
    String? savedStatus;
    await tester.pumpWidget(MaterialApp(
      theme: sonaTheme(),
      home: Scaffold(
        body: ClinicianSessionPlanScreen(
          caseDetail: caseDetail ?? ariaPlanCase(),
          onBackTriage: () {},
          onPublishSummary: () {},
          onSavePlan: ({required sections, required reviewStatus}) async {
            savedSections = sections;
            savedStatus = reviewStatus;
          },
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return (sections: savedSections, reviewStatus: savedStatus);
  }

  testWidgets('renders all 5 plan sections + AI-draft badge',
      (tester) async {
    await pump(tester);
    expect(find.text('Goals'), findsOneWidget);
    expect(find.text('Activities'), findsOneWidget);
    expect(find.text('Home practice'), findsOneWidget);
    expect(find.text('Materials'), findsOneWidget);
    expect(find.text('Parent goals'), findsOneWidget);
    expect(find.textContaining('AI-drafted'), findsWidgets);
  });

  testWidgets('hydrates section bullets from caseDetail draft',
      (tester) async {
    await pump(tester);
    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .map((tf) => tf.controller!.text)
        .toList();
    expect(fields, contains(contains('DEAP screen')));
    expect(fields, contains(contains('articulation probe')));
    expect(fields, contains(contains('silly sound')));
  });

  testWidgets('shows DRAFT badge when reviewStatus=draft', (tester) async {
    await pump(tester);
    expect(find.text('DRAFT'), findsOneWidget);
  });

  testWidgets('publish CTA disabled while status is draft', (tester) async {
    await pump(tester);
    final tonal = tester
        .widget<FilledButton>(find.byWidgetPredicate((w) =>
            w is FilledButton &&
            w.child is Text &&
            ((w.child as Text).data ?? '').contains('Publish parent summary')));
    expect(tonal.onPressed, isNull);
  });

  testWidgets('Save draft posts current sections + draft status',
      (tester) async {
    Map<String, List<String>>? captured;
    String? capturedStatus;
    await tester.pumpWidget(MaterialApp(
      theme: sonaTheme(),
      home: Scaffold(
        body: ClinicianSessionPlanScreen(
          caseDetail: ariaPlanCase(),
          onBackTriage: () {},
          onPublishSummary: () {},
          onSavePlan: ({required sections, required reviewStatus}) async {
            captured = sections;
            capturedStatus = reviewStatus;
          },
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final saveDraftFinder = find.widgetWithText(OutlinedButton, 'Save draft');
    await tester.ensureVisible(saveDraftFinder);
    await tester.pumpAndSettle();
    await tester.tap(saveDraftFinder);
    await tester.pumpAndSettle();

    expect(capturedStatus, 'draft');
    expect(captured!['goals']!.length, 2);
    expect(captured!['goals']!.first, contains('baseline'));
    expect(captured!['materials']!, contains('DEAP articulation cards'));
  });

  testWidgets('Save as final marks reviewStatus=final + flips badge',
      (tester) async {
    String? capturedStatus;
    await tester.pumpWidget(MaterialApp(
      theme: sonaTheme(),
      home: Scaffold(
        body: ClinicianSessionPlanScreen(
          caseDetail: ariaPlanCase(),
          onBackTriage: () {},
          onPublishSummary: () {},
          onSavePlan: ({required sections, required reviewStatus}) async {
            capturedStatus = reviewStatus;
          },
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final saveFinalFinder = find.widgetWithText(FilledButton, 'Save as final');
    await tester.ensureVisible(saveFinalFinder);
    await tester.pumpAndSettle();
    await tester.tap(saveFinalFinder);
    await tester.pumpAndSettle();

    expect(capturedStatus, 'final');
    expect(find.text('FINAL'), findsOneWidget);
  });

  testWidgets('Add inserts a new editable bullet in the chosen section',
      (tester) async {
    await pump(tester);
    final addButtons = find.text('Add');
    expect(addButtons, findsNWidgets(5));
    final goalsFieldsBefore = tester
        .widgetList<TextField>(find.byType(TextField))
        .length;
    await tester.tap(addButtons.first);
    await tester.pumpAndSettle();
    final goalsFieldsAfter = tester
        .widgetList<TextField>(find.byType(TextField))
        .length;
    expect(goalsFieldsAfter, goalsFieldsBefore + 1);
  });

  testWidgets('Remove deletes the bullet from the section', (tester) async {
    await pump(tester);
    final beforeFields = tester
        .widgetList<TextField>(find.byType(TextField))
        .length;
    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();
    final afterFields = tester
        .widgetList<TextField>(find.byType(TextField))
        .length;
    expect(afterFields, beforeFields - 1);
  });
}
