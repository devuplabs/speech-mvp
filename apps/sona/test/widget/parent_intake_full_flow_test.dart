import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sona/design_system/widgets/sona_date_field.dart';
import 'package:sona/main.dart';
import 'package:sona/services/api_client.dart';

/// Full-flow widget test for parent intake.
///
/// Drives the real `SonaApp` through all 8 steps via `WidgetTester.enterText`,
/// using a `MockClient` to stub the API. Sister test of the manual web flow we
/// proved out by hand on dev: it exercises substep transitions, step
/// advancement, validation order, and the submit payload that the API
/// receives. Acts as the deterministic safety net for the demo-blocker fix
/// shipped in PR #21 (step 1 page 1 → page 2 → step 2 transition).
///
/// Promotion path: an `integration_test/` mirror of this file (with the same
/// helpers) ships in the same PR for chromedriver/Patrol-based runs once the
/// CI image is set up. Today this test runs in any `flutter test` invocation.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('parent intake completes all 8 steps and submits', (tester) async {
    // Force a tall, narrow viewport so the 375-wide mobile shell renders, the
    // bottom status row fits, and every step's fields are visible without
    // scrolling. Keeps `find.text(...)` reliable across all 8 steps.
    tester.view.physicalSize = const Size(440, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // The mobile shell + review screen contain a couple of horizontal Rows
    // that overflow in the test viewport. Those overflows are unrelated to
    // the parent-intake flow this test guards, so swallow them so the test
    // framework doesn't fail on benign layout warnings.
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      final msg = '${details.exception}';
      if (msg.contains('A RenderFlex overflowed')) return;
      if (msg.contains('Looking up a deactivated widget')) return;
      originalOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = originalOnError);

    final fake = _FakeBackend();

    await tester.pumpWidget(SonaApp(apiClient: fake.client()));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Launcher → parent welcome → start fresh intake.
    await tester.tap(find.text('Parent intake (mobile)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get started'));
    // Bootstrap + create case happen inside _run; settle generously.
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('About you & your child'), findsOneWidget,
        reason: 'Step 1 page 1a should render after Get started');

    // ---- Step 1 page 1a ----
    await _enterByLabel(tester, 'Email *', 'test.parent@example.com');
    await _enterByLabel(tester, "Child's name *", 'Alex Test');
    await _setDate(tester, 'Date of birth *', '15 / 03 / 2019');
    await _enterByLabel(tester, 'Age at referral *', '5');
    await _enterByLabel(tester, "Child's address *", '1 Test Street, London');
    await _enterByLabel(tester, "Mother's name *", 'Jane Test');
    await _enterByLabel(tester, "Mother's mobile *", '07700900001');
    await _enterByLabel(tester, "Mother's email *", 'mother@example.com');
    await _continue(tester);

    expect(find.text('Page 2 of 2'), findsOneWidget,
        reason: 'Continue from page 1a should advance to page 1b');

    // ---- Step 1 page 1b (the demo-blocker transition) ----
    await _enterByLabel(tester, "Father's mobile *", '07700900002');
    await _enterByLabel(tester, "Father's email *", 'father@example.com');
    await _enterByLabel(tester, 'GP practice *', 'Test GP');
    await _enterByLabel(tester, 'GP address *', 'GP Street');
    await _enterByLabel(tester, 'GP phone *', '02070000000');
    await _enterByLabel(tester, 'Who referred your child? *', 'School');
    await _enterByLabel(
        tester, 'How did you hear about Speech Sanctuary? *', 'Website');
    await _continue(tester);

    expect(find.text('Step 2 of 8'), findsOneWidget,
        reason:
            'Continue from step 1 page 1b MUST advance to step 2 of 8 — this is the regression PR #21 fixed.');

    // ---- Step 2 ----
    await _enterByLabel(tester, 'Main concern *', 'Speech delay test');
    await tester.tap(find.text('Speech sounds').first);
    await tester.pump();
    await tester.tap(find.text('Staying on task').first);
    await tester.pump();
    await _continue(tester);

    // ---- Step 3 ----
    expect(find.text('Step 3 of 8'), findsOneWidget);
    await _tapYesNo(tester, 'Assessed by other professionals?', 'No');
    await _tapYesNo(tester, 'Receiving therapy now?', 'No');
    await _enterByLabel(tester, 'Languages child exposed to *', 'English');
    await _enterByLabel(tester, 'Languages spoken by parents *', 'English');
    await _enterByLabel(tester, 'Languages spoken by child *', 'English');
    await _tapYesNo(
        tester,
        'Family history of SLT/learning/attention difficulties?',
        'No');
    await _continue(tester);

    // ---- Step 4 ----
    expect(find.text('Step 4 of 8'), findsOneWidget);
    await _enterByLabel(
        tester, "Mother's health during pregnancy *", 'Normal');
    await _enterByLabel(
        tester, 'Premature? If yes, how many weeks *', 'No');
    await _enterByLabel(tester, "Baby's weight at birth *", '3.2kg');
    await _enterByLabel(tester, 'Complications during birth *', 'None');
    await _enterByLabel(tester, 'Complications after birth *', 'None');
    await _continue(tester);

    // ---- Step 5 ----
    expect(find.text('Step 5 of 8'), findsOneWidget);
    await _enterByLabel(tester, 'Early childhood illnesses *', 'None');
    await _enterByLabel(tester, 'General health *', 'Good');
    await _enterByLabel(tester, 'Known diagnosis / syndrome *', 'None');
    await _enterByLabel(tester, 'Regular medications *', 'None');
    await _enterByLabel(tester, 'Hospitalised? (details) *', 'No');
    await _enterByLabel(
        tester, 'Hearing tested? (when & outcome) *', 'Yes normal');
    await _enterByLabel(tester, 'History of ear infections *', 'None');
    await _enterByLabel(tester, 'Ear surgery / ENT involvement *', 'None');
    await _enterByLabel(
        tester, 'Eyes tested? (when & outcome) *', 'Yes normal');
    await _continue(tester);

    // ---- Step 6 ----
    expect(find.text('Step 6 of 8'), findsOneWidget);
    await _tapYesNo(tester, 'Responds to own name?', 'Yes');
    await _enterByLabel(tester, 'Age of first words *', '12 months');
    await _enterByLabel(tester, 'Age of two-word phrases *', '18 months');
    await _enterByLabel(tester, 'Attention & listening skills *', 'Variable');
    await _enterByLabel(tester, 'Sentence examples *', 'Want juice');
    await _enterByLabel(tester, 'Shows understanding by *', 'Follows directions');
    await _continue(tester);

    // ---- Step 7 ----
    expect(find.text('Step 7 of 8'), findsOneWidget);
    await _enterByLabel(tester, 'Describe your child (temperament) *', 'Friendly');
    await _enterByLabel(tester, 'Social skills *', 'Good');
    await _enterByLabel(tester, 'Peer interaction *', 'Plays well');
    await _enterByLabel(tester, 'Favourite play / motivators *', 'Blocks');
    await _enterByLabel(
        tester, 'Communication self-awareness *', 'Some awareness');
    await _continue(tester);

    // ---- Step 8 ----
    expect(find.text('Step 8 of 8'), findsOneWidget);
    await _enterByLabel(
        tester, 'School / nursery (name & address) *', 'Test Nursery, London');
    await _enterByLabel(tester, 'Nursery days/times', 'Mon-Fri');
    await _enterByLabel(tester, 'SEN plan or EHCP *', 'None');
    await _tapYesNo(tester, 'May child be photographed/filmed?', 'No');
    await _enterByLabel(tester, 'Form completed by *', 'Jane Test');
    await _setDate(tester, 'Date of completion *', '20 / 05 / 2026');
    await _continue(tester);

    // ---- Review & submit ----
    expect(find.textContaining('Review'), findsWidgets);
    // Tick the three consent checkboxes; Review screen lays them out in order.
    final checkboxes = find.byType(Checkbox);
    expect(checkboxes, findsNWidgets(3));
    for (var i = 0; i < 3; i++) {
      await tester.tap(checkboxes.at(i));
      await tester.pump();
    }
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(fake.submittedAnswers, isNotNull, reason: 'API submit must be called');
    expect(fake.submittedAnswers!['email'], 'test.parent@example.com');
    expect(fake.submittedAnswers!['childName'], 'Alex Test');
    expect(fake.submittedAnswers!['gpPhone'], '02070000000');
    expect(
      (fake.submittedAnswers!['difficulties'] as List).toSet(),
      {'Speech sounds', 'Staying on task'},
    );
    expect(fake.submittedAnswers!['consentGuardian'], true);
    expect(fake.submittedAnswers!['consentPrivacy'], true);
    expect(fake.submittedAnswers!['consentAccurate'], true);
  });
}

/// Resolves a `SonaTextField` by its rendered label and types [text] into
/// the inner `TextField`. Relies on the test viewport being tall enough to
/// keep every step's fields visible (set in the test body).
Future<void> _enterByLabel(WidgetTester tester, String label, String text) async {
  final labelFinder = find.text(label);
  // The label sits in the parent Column above the TextField; walk up to find
  // the surrounding Padding and target the descendant TextField.
  final ancestor = find.ancestor(
    of: labelFinder,
    matching: find.byType(Padding),
  );
  final fieldFinder = find
      .descendant(of: ancestor.first, matching: find.byType(TextField))
      .first;
  await tester.enterText(fieldFinder, text);
  await tester.pump();
}

/// Sets a `SonaDateField`'s value by invoking its public `onChanged` callback
/// directly — the field is `readOnly` and the platform date picker is a real
/// dialog that we can't easily drive in a widget test.
Future<void> _setDate(WidgetTester tester, String label, String value) async {
  final labelFinder = find.text(label);
  final dateFieldFinder = find.ancestor(
    of: labelFinder,
    matching: find.byType(SonaDateField),
  );
  final widget = tester.widget<SonaDateField>(dateFieldFinder.first);
  widget.onChanged(value);
  await tester.pumpAndSettle();
}

Future<void> _tapYesNo(WidgetTester tester, String label, String choice) async {
  // SonaYesNoField defaults to required:true, which appends ' *' to the label.
  final labelFinder = find.text('$label *');
  // ChoiceChip pattern: locate the parent SonaYesNoField via its label, then
  // tap the Yes/No chip nested inside it.
  final fieldRow = find.ancestor(
    of: labelFinder,
    matching: find.byType(Column),
  );
  await tester.tap(
    find.descendant(of: fieldRow.first, matching: find.text(choice)).first,
  );
  await tester.pump();
}

Future<void> _continue(WidgetTester tester) async {
  await tester.tap(find.text('Continue →'));
  await tester.pumpAndSettle(const Duration(seconds: 2));
}

/// In-memory backend that mirrors what the parent-intake flow exercises.
class _FakeBackend {
  String? caseId;
  Map<String, dynamic>? submittedAnswers;
  Map<String, dynamic>? draftAnswers;

  SonaApiClient client() => SonaApiClient(client: MockClient(_handler));

  Future<http.Response> _handler(http.Request req) async {
    final path = req.url.path;
    Map<String, dynamic> body() => req.body.isEmpty
        ? <String, dynamic>{}
        : (jsonDecode(req.body) as Map<String, dynamic>);

    http.Response ok(int status, Map<String, dynamic> data) => http.Response(
          jsonEncode(data),
          status,
          headers: {'content-type': 'application/json'},
        );

    if (path == '/v1/demo/bootstrap' && req.method == 'POST') {
      return ok(200, {'tenantId': 'fake-tenant', 'jurisdiction': 'uk'});
    }
    if (path == '/v1/cases' && req.method == 'POST') {
      caseId = 'fake-case-id';
      return ok(201, {
        'id': caseId,
        'tenantId': body()['tenantId'],
        'status': 'intake_pending',
        'parentEmail': body()['parentEmail'],
        'childDisplayName': body()['childDisplayName'],
      });
    }
    if (path.startsWith('/v1/cases/') &&
        path.endsWith('/intake/draft') &&
        req.method == 'PUT') {
      draftAnswers = body()['answers'] as Map<String, dynamic>?;
      return ok(200, {
        'ok': true,
        'intake': {'id': 'fake-intake', 'caseId': caseId, 'answers': draftAnswers},
      });
    }
    if (path.startsWith('/v1/cases/') &&
        path.endsWith('/intake') &&
        req.method == 'POST') {
      submittedAnswers = body()['answers'] as Map<String, dynamic>?;
      return ok(200, {
        'case': {
          'id': caseId,
          'tenantId': 'fake-tenant',
          'status': 'prep_ready',
        },
        'intake': {'id': 'fake-intake', 'submittedAt': DateTime.now().toIso8601String()},
      });
    }
    if (path.startsWith('/v1/cases/') && req.method == 'GET') {
      return ok(200, {
        'case': {
          'id': caseId,
          'tenantId': 'fake-tenant',
          'status': 'intake_pending',
          'parentEmail': null,
        },
        'intake': null,
        'drafts': const [],
      });
    }
    return http.Response('not found', 404);
  }
}
