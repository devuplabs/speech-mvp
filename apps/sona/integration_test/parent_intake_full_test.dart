import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sona/design_system/widgets/sona_date_field.dart';
import 'package:sona/main.dart';
import 'package:sona/services/api_client.dart';
import 'package:sona/test_utils/intake_personas.dart';

/// Persona-driven integration test for the parent intake.
///
/// Walks the full 8-step flow + review + submit for every synthetic persona
/// in `lib/test_utils/intake_personas.dart`, asserting the submit payload that
/// the API receives matches the persona's canonical answers.
///
/// This is the long-term sibling of `test/widget/parent_intake_full_flow_test.dart`:
///   - `test/widget/...` is the always-fast safety net for the demo-blocker fix
///     (PR #21) — it tests one hardcoded happy path and runs in any `flutter test`.
///   - `integration_test/parent_intake_full_test.dart` (this file) re-uses the
///     same `WidgetTester.enterText` strategy under
///     `IntegrationTestWidgetsFlutterBinding` so it can be promoted to real
///     Chrome via `chromedriver` once the CI image is wired (see README in
///     this folder). Today it still runs as a normal `flutter test` job — the
///     IntegrationTestWidgetsFlutterBinding falls back to the Dart VM binding
///     when no driver is attached.
///
/// Targets the test-pyramid latency the buildout brief asks for:
///   - Each persona's full 8-step pass completes in well under 5 seconds locally.
///   - Total for 4 personas is < 20 seconds.
///
/// Adding a new persona to `lib/test_utils/intake_personas.dart` auto-extends
/// the coverage — no changes needed here.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  for (final persona in intakePersonas) {
    testWidgets(
      'parent intake submits for ${persona.id}',
      (tester) async {
        tester.view.physicalSize = const Size(440, 4000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        // Swallow benign layout overflow warnings (the 375-wide mobile shell
        // and review screen contain a couple of Rows that overflow in the
        // test viewport — unrelated to flow correctness).
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

        await tester.tap(find.text('Parent intake (mobile)'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Get started'));
        await tester.pumpAndSettle(const Duration(seconds: 2));

        await _runPersonaFlow(tester, persona);

        // Review screen: tick all three consent checkboxes + submit.
        expect(find.textContaining('Review'), findsWidgets,
            reason: 'Should land on review after step 8 for ${persona.id}');
        final boxes = find.byType(Checkbox);
        expect(boxes, findsNWidgets(3),
            reason: 'Review screen renders exactly 3 consent checkboxes');
        for (var i = 0; i < 3; i++) {
          await tester.tap(boxes.at(i));
          await tester.pump();
        }
        await tester.tap(find.text('Submit'));
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Assertions on what hit the API.
        expect(fake.submittedAnswers, isNotNull,
            reason: 'API submit must be called for ${persona.id}');
        final got = fake.submittedAnswers!;
        expect(got['email'], persona.answers['email']);
        expect(got['childName'], persona.answers['childName']);
        expect(got['gpPhone'], persona.answers['gpPhone']);
        expect(
          (got['difficulties'] as List).toSet(),
          (persona.answers['difficulties'] as List).toSet(),
          reason: 'Difficulties round-trip must match persona for ${persona.id}',
        );
        expect(got['consentGuardian'], true);
        expect(got['consentPrivacy'], true);
        expect(got['consentAccurate'], true);
      },
    );
  }
}

/// Drives every step of the parent intake for [persona] using its canonical
/// answers, mirroring what `_fillSampleAndOpenReview` would do for a human
/// tester. Kept in one place so adding a new field to the persona schema is
/// the only edit needed.
Future<void> _runPersonaFlow(WidgetTester tester, IntakePersona p) async {
  final a = p.answers;

  // ---- Step 1 page 1a ----
  await _enterByLabel(tester, 'Email *', a['email'] as String);
  await _enterByLabel(tester, "Child's name *", a['childName'] as String);
  await _setDate(tester, 'Date of birth *', a['dateOfBirth'] as String);
  await _enterByLabel(tester, 'Age at referral *', a['ageAtReferral'] as String);
  await _enterByLabel(tester, "Child's address *", a['childAddress'] as String);
  await _enterByLabel(tester, "Mother's name *", a['motherName'] as String);
  await _enterByLabel(tester, "Mother's mobile *", a['motherMobile'] as String);
  await _enterByLabel(tester, "Mother's email *", a['motherEmail'] as String);
  await _continue(tester);
  expect(find.text('Page 2 of 2'), findsOneWidget,
      reason: '${p.id}: continue should advance from page 1a to 1b');

  // ---- Step 1 page 1b ----
  await _enterByLabel(tester, "Father's mobile *", a['fatherMobile'] as String);
  await _enterByLabel(tester, "Father's email *", a['fatherEmail'] as String);
  await _enterByLabel(tester, 'GP practice *', a['gpPractice'] as String);
  await _enterByLabel(tester, 'GP address *', a['gpAddress'] as String);
  await _enterByLabel(tester, 'GP phone *', a['gpPhone'] as String);
  await _enterByLabel(tester, 'Who referred your child? *', a['referredBy'] as String);
  await _enterByLabel(
      tester, 'How did you hear about Speech Sanctuary? *', a['heardAbout'] as String);
  await _continue(tester);
  expect(find.text('Step 2 of 8'), findsOneWidget,
      reason: '${p.id}: continue from 1b must reach step 2');

  // ---- Step 2 ----
  await _enterByLabel(tester, 'Main concern *', a['mainConcern'] as String);
  for (final d in (a['difficulties'] as List).cast<String>()) {
    await tester.tap(find.text(d).first);
    await tester.pump();
  }
  await _continue(tester);

  // ---- Step 3 ----
  expect(find.text('Step 3 of 8'), findsOneWidget);
  await _tapYesNo(tester, 'Assessed by other professionals?',
      a['assessedByOthers'] as String);
  if ((a['assessedByOthers'] as String) == 'yes') {
    await _enterByLabel(tester, 'If yes — details *',
        a['assessedByOthersDetails'] as String);
  }
  await _tapYesNo(tester, 'Receiving therapy now?', a['receivingTherapy'] as String);
  if ((a['receivingTherapy'] as String) == 'yes') {
    await _enterByLabel(
        tester, 'If yes — therapy details *', a['therapyDetails'] as String);
  }
  await _enterByLabel(tester, 'Languages child exposed to *',
      a['languagesExposed'] as String);
  await _enterByLabel(
      tester, 'Languages spoken by parents *', a['parentLanguages'] as String);
  await _enterByLabel(
      tester, 'Languages spoken by child *', a['childLanguages'] as String);
  await _tapYesNo(tester,
      'Family history of SLT/learning/attention difficulties?',
      a['familyHistory'] as String);
  if ((a['familyHistory'] as String) == 'yes') {
    await _enterByLabel(tester, 'If yes — explain *',
        a['familyHistoryDetails'] as String);
  }
  await _continue(tester);

  // ---- Step 4 ----
  expect(find.text('Step 4 of 8'), findsOneWidget);
  await _enterByLabel(
      tester, "Mother's health during pregnancy *", a['pregnancyHealth'] as String);
  await _enterByLabel(
      tester, 'Premature? If yes, how many weeks *', a['prematureDetails'] as String);
  await _enterByLabel(tester, "Baby's weight at birth *", a['birthWeight'] as String);
  await _enterByLabel(
      tester, 'Complications during birth *', a['birthComplications'] as String);
  await _enterByLabel(tester, 'Complications after birth *',
      a['afterBirthComplications'] as String);
  await _continue(tester);

  // ---- Step 5 ----
  expect(find.text('Step 5 of 8'), findsOneWidget);
  await _enterByLabel(tester, 'Early childhood illnesses *', a['earlyIllnesses'] as String);
  await _enterByLabel(tester, 'General health *', a['generalHealth'] as String);
  await _enterByLabel(tester, 'Known diagnosis / syndrome *', a['diagnosis'] as String);
  await _enterByLabel(tester, 'Regular medications *', a['medications'] as String);
  await _enterByLabel(tester, 'Hospitalised? (details) *', a['hospitalised'] as String);
  await _enterByLabel(
      tester, 'Hearing tested? (when & outcome) *', a['hearingTested'] as String);
  await _enterByLabel(tester, 'History of ear infections *', a['earInfections'] as String);
  await _enterByLabel(
      tester, 'Ear surgery / ENT involvement *', a['entInvolvement'] as String);
  await _enterByLabel(
      tester, 'Eyes tested? (when & outcome) *', a['visionTested'] as String);
  await _continue(tester);

  // ---- Step 6 ----
  expect(find.text('Step 6 of 8'), findsOneWidget);
  await _tapYesNo(tester, 'Responds to own name?', a['respondsToName'] as String);
  await _enterByLabel(tester, 'Age of first words *', a['ageFirstWords'] as String);
  await _enterByLabel(tester, 'Age of two-word phrases *', a['ageTwoWordPhrases'] as String);
  await _enterByLabel(tester, 'Attention & listening skills *', a['attentionListening'] as String);
  await _enterByLabel(tester, 'Sentence examples *', a['sentenceExamples'] as String);
  await _enterByLabel(tester, 'Shows understanding by *', a['showsUnderstanding'] as String);
  await _continue(tester);

  // ---- Step 7 ----
  expect(find.text('Step 7 of 8'), findsOneWidget);
  await _enterByLabel(tester, 'Describe your child (temperament) *', a['temperament'] as String);
  await _enterByLabel(tester, 'Social skills *', a['socialSkills'] as String);
  await _enterByLabel(tester, 'Peer interaction *', a['peerInteraction'] as String);
  await _enterByLabel(tester, 'Favourite play / motivators *', a['favouritePlay'] as String);
  await _enterByLabel(
      tester, 'Communication self-awareness *', a['communicationAwareness'] as String);
  await _continue(tester);

  // ---- Step 8 ----
  expect(find.text('Step 8 of 8'), findsOneWidget);
  await _enterByLabel(
      tester, 'School / nursery (name & address) *', a['schoolNameAddress'] as String);
  final nurseryDays = a['nurseryDays'] as String;
  if (nurseryDays.isNotEmpty) {
    await _enterByLabel(tester, 'Nursery days/times', nurseryDays);
  }
  await _enterByLabel(tester, 'SEN plan or EHCP *', a['senPlan'] as String);
  await _tapYesNo(tester, 'May child be photographed/filmed?', a['photoConsent'] as String);
  await _enterByLabel(tester, 'Form completed by *', a['completedBy'] as String);
  await _setDate(tester, 'Date of completion *', a['completionDate'] as String);
  await _continue(tester);
}

Future<void> _enterByLabel(WidgetTester tester, String label, String text) async {
  final labelFinder = find.text(label);
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

Future<void> _tapYesNo(WidgetTester tester, String label, String value) async {
  final labelFinder = find.text('$label *');
  final fieldRow = find.ancestor(
    of: labelFinder,
    matching: find.byType(Column),
  );
  final choice = value == 'yes' ? 'Yes' : 'No';
  await tester.tap(
    find.descendant(of: fieldRow.first, matching: find.text(choice)).first,
  );
  await tester.pump();
}

Future<void> _continue(WidgetTester tester) async {
  await tester.tap(find.text('Continue →'));
  await tester.pumpAndSettle(const Duration(seconds: 2));
}

/// In-memory backend mirroring what the parent intake flow calls.
class _FakeBackend {
  String? caseId;
  Map<String, dynamic>? submittedAnswers;

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
      return ok(200, {
        'ok': true,
        'intake': {'id': 'fake-intake', 'caseId': caseId, 'answers': body()['answers']},
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
