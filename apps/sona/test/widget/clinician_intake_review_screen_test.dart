import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sona/design_system/sona_theme.dart';
import 'package:sona/features/clinician/clinician_intake_review_screen.dart';
import 'package:sona/test_utils/intake_personas.dart';

/// Stage 3 · Intake review — one-screen client overview.
///
/// Drives the screen with the `{case, intake, drafts}` map shape returned by
/// `GET /v1/cases/:id`, populated from the shared persona fixtures so the
/// answer keys stay aligned with the real intake form.

Map<String, dynamic> _submittedDetail({bool locked = false}) {
  final persona = personaById('aria_speech_sounds_4yo');
  return {
    'case': {
      'id': 'case-aria',
      'tenantId': 't-1',
      'status': 'prep_ready',
      'parentEmail': persona.parentEmail,
      'childDisplayName': persona.childDisplayName,
      'referralSource': 'school',
    },
    'intake': {
      'id': 'intake-aria',
      'caseId': 'case-aria',
      'answers': {
        ...persona.answers,
        'consentGuardian': true,
        'consentPrivacy': true,
        'consentAccurate': true,
      },
      'consentVersion': 'mvp-v1',
      'locked': locked,
      'submittedAt': '2026-06-01T09:00:00Z',
    },
    'drafts': [
      {
        'kind': 'prep_brief',
        'content': {
          'probeAreas': ['Confirm final-consonant deletion in connected speech'],
          'redFlags': ['Attention drift in 1:1 play — screen during consult'],
          'references': [],
        },
      },
    ],
  };
}

Map<String, dynamic> _pendingDetail() => {
      'case': {
        'id': 'case-pending',
        'tenantId': 't-1',
        'status': 'intake_pending',
        'parentEmail': 'parent@example.com',
        'childDisplayName': 'Theo K.',
        'referralSource': 'health_visitor',
      },
      'intake': null,
      'drafts': const <Map<String, dynamic>>[],
    };

Future<void> _pump(
  WidgetTester tester, {
  required Map<String, dynamic>? detail,
  String? linkStatus,
  Future<String?> Function()? onResendLink,
  Future<void> Function()? onRevokeLink,
  VoidCallback? onOpenPrep,
}) async {
  tester.view.physicalSize = const Size(1440, 2400);
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
      body: ClinicianIntakeReviewScreen(
        caseDetail: detail,
        onBack: () {},
        linkStatus: linkStatus,
        onResendLink: onResendLink,
        onRevokeLink: onRevokeLink,
        onOpenPrep: onOpenPrep,
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('submitted intake renders grouped answers, consent and red flags',
      (tester) async {
    await _pump(tester, detail: _submittedDetail());

    expect(find.text('Intake review · Aria M.'), findsOneWidget);
    expect(find.text('Submitted'), findsWidgets);

    // All six answer groups render.
    for (final section in [
      'About the child',
      'Family & background',
      'Concerns',
      'Development',
      'Health',
      'Anything else',
    ]) {
      expect(find.text(section), findsOneWidget,
          reason: 'Section "$section" must render for a submitted intake');
    }

    // Persona-derived answers land in their groups.
    expect(find.textContaining('Hard to understand at nursery'), findsWidgets);
    expect(find.text('Speech sounds'), findsWidgets);
    expect(find.textContaining('Hampstead Health Centre'), findsOneWidget);
    expect(find.textContaining('11 months'), findsOneWidget);
    expect(find.textContaining('Healthy pregnancy'), findsOneWidget);

    // Consent status + version.
    expect(find.textContaining('Consent recorded (3 of 3'), findsOneWidget);
    expect(find.textContaining('mvp-v1'), findsOneWidget);

    // Red flags from the prep brief.
    expect(find.textContaining('Attention drift in 1:1 play'), findsOneWidget);

    // Referral source from the case row.
    expect(find.textContaining('Referral source: school'), findsOneWidget);

    // Submitted intakes do not surface link actions.
    expect(find.text('Resend link'), findsNothing);
    expect(find.text('Revoke link'), findsNothing);
  });

  testWidgets('pending intake shows link status with resend and revoke actions',
      (tester) async {
    var resent = 0;
    var revoked = 0;
    await _pump(
      tester,
      detail: _pendingDetail(),
      linkStatus: 'sent',
      onResendLink: () async {
        resent++;
        return 'https://example.com/intake?t=tok';
      },
      onRevokeLink: () async {
        revoked++;
      },
    );

    expect(find.text('Pending'), findsWidgets);
    expect(find.text('Link sent — awaiting the parent'), findsOneWidget);
    expect(find.textContaining('not submitted this intake yet'), findsOneWidget);
    expect(find.textContaining('Consent not yet recorded'), findsOneWidget);

    await tester.tap(find.text('Resend link'));
    await tester.pumpAndSettle();
    expect(resent, 1);

    // Revoke goes through a confirm dialog first.
    await tester.tap(find.text('Revoke link'));
    await tester.pumpAndSettle();
    expect(find.text('Revoke link?'), findsOneWidget);
    await tester.tap(find.text('Revoke'));
    await tester.pumpAndSettle();
    expect(revoked, 1);
  });

  testWidgets('locked intake shows the locked badge', (tester) async {
    await _pump(tester, detail: _submittedDetail(locked: true));
    expect(find.text('Locked'), findsNWidgets(2),
        reason: 'Locked badge renders in the header and the status card');
  });

  testWidgets('null case detail shows a friendly empty state', (tester) async {
    await _pump(tester, detail: null);
    expect(find.textContaining('No case loaded'), findsOneWidget);
  });

  testWidgets('Open consult prep action fires when wired', (tester) async {
    var opened = 0;
    await _pump(tester, detail: _submittedDetail(), onOpenPrep: () => opened++);
    await tester.tap(find.text('Open consult prep →'));
    expect(opened, 1);
  });
}
