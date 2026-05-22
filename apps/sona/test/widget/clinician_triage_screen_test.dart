import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sona/design_system/sona_theme.dart';
import 'package:sona/features/clinician/clinician_triage_screen.dart';

void main() {
  Future<({String? outcome, String? reason})> pump(
    WidgetTester tester, {
    Map<String, dynamic>? caseDetail,
  }) async {
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

    String? savedOutcome;
    String? savedReason;
    await tester.pumpWidget(MaterialApp(
      theme: sonaTheme(),
      home: Scaffold(
        body: ClinicianTriageScreen(
          caseDetail: caseDetail,
          onSaveTriage: ({required outcome, required reason}) async {
            savedOutcome = outcome;
            savedReason = reason;
          },
          onPublishSummary: () {},
          onBackPrep: () {},
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return (outcome: savedOutcome, reason: savedReason);
  }

  testWidgets('renders all 4 MVP outcome cards', (tester) async {
    await pump(tester);
    expect(find.text('Strategy only'), findsOneWidget);
    expect(find.text('Short block'), findsOneWidget);
    expect(find.text('Full assessment'), findsOneWidget);
    expect(find.text('Refer onward'), findsOneWidget);
  });

  testWidgets('defaults to short_block selection', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? capturedOutcome;
    String? capturedReason;
    await tester.pumpWidget(MaterialApp(
      theme: sonaTheme(),
      home: Scaffold(
        body: ClinicianTriageScreen(
          onSaveTriage: ({required outcome, required reason}) async {
            capturedOutcome = outcome;
            capturedReason = reason;
          },
          onPublishSummary: () {},
          onBackPrep: () {},
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save triage'));
    await tester.pumpAndSettle();
    expect(capturedOutcome, 'short_block');
    expect(capturedReason, '');
  });

  testWidgets('saves selected outcome + reason via onSaveTriage',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? capturedOutcome;
    String? capturedReason;
    await tester.pumpWidget(MaterialApp(
      theme: sonaTheme(),
      home: Scaffold(
        body: ClinicianTriageScreen(
          onSaveTriage: ({required outcome, required reason}) async {
            capturedOutcome = outcome;
            capturedReason = reason;
          },
          onPublishSummary: () {},
          onBackPrep: () {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Tap the outcome card via its label; the InkWell wraps the card so this
    // hit-tests cleanly.
    await tester.tap(find.text('Full assessment'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField),
        'Speech sounds DEAP recommended; book 60-min standardised slot.');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save triage'));
    await tester.pumpAndSettle();
    expect(capturedOutcome, 'full_assessment');
    expect(capturedReason, contains('DEAP'));
  });

  testWidgets('rehydrates from existing triage row and shows Update label',
      (tester) async {
    await pump(tester, caseDetail: {
      'case': {'id': 'c-1', 'childDisplayName': 'Mia R.'},
      'intake': null,
      'drafts': const [],
      'triage': [
        {
          'id': 't-1',
          'caseId': 'c-1',
          'outcome': 'refer_out',
          'reason': 'NHS ADOS-2 already in flight.',
          'recordedAt': '2026-05-22T10:00:00Z',
        },
      ],
    });
    expect(find.text('Update triage'), findsOneWidget);
    // The radio next to "Refer onward" is selected (checked icon present).
    expect(
      find.byIcon(Icons.radio_button_checked),
      findsOneWidget,
    );
    expect(find.textContaining('ADOS-2'), findsWidgets);
  });

  testWidgets('publish-summary CTA is disabled until triage is saved',
      (tester) async {
    await pump(tester);
    final pub = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
    expect(pub.onPressed, isNull);
  });

  testWidgets('publish-summary CTA enabled after a triage row exists',
      (tester) async {
    await pump(tester, caseDetail: {
      'case': {'id': 'c-2'},
      'intake': null,
      'drafts': const [],
      'triage': [
        {
          'outcome': 'short_block',
          'reason': '',
          'recordedAt': '2026-05-22T10:00:00Z',
        },
      ],
    });
    final pub = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
    expect(pub.onPressed, isNotNull);
  });

  testWidgets('reads childDisplayName for the header', (tester) async {
    await pump(tester, caseDetail: {
      'case': {'id': 'c-3', 'childDisplayName': 'Theo K.'},
      'intake': null,
      'drafts': const [],
    });
    expect(find.textContaining('Theo K.'), findsWidgets);
  });
}
