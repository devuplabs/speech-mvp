import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sona/design_system/sona_theme.dart';
import 'package:sona/features/clinician/clinician_parent_summary_screen.dart';
import 'package:sona/services/api_client.dart';
import 'package:sona/test_utils/intake_personas.dart';

/// Stage 8 · Parent-summary editor (DEV-50).
///
/// The clinician shapes the tone-adjusted family summary before publishing: a
/// live phone preview is driven by the editable body (seeded from the loaded
/// case — the child's name, intake concern, and session-plan bullets), and the
/// tone / reading-level presets re-draft that body. Publishing sends the
/// clinician's FINAL edited `htmlBody` through the
/// `POST /v1/cases/:id/parent-summary/publish` contract, exercised here via the
/// API client with a MockClient backend.

const _jsonHeaders = {'content-type': 'application/json'};

Map<String, dynamic> _detail({
  List<String>? goals,
  List<String>? homePractice,
}) {
  final persona = personaById('jaden_stutter_7yo');
  final sections = <String, dynamic>{};
  if (goals != null) sections['goals'] = goals;
  if (homePractice != null) sections['homePractice'] = homePractice;
  return {
    'case': {
      'id': 'case-jaden',
      'tenantId': 't-1',
      'status': 'triaged',
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
      {
        'kind': 'session_plan',
        'content': {'sections': sections},
      },
    ],
  };
}

class _FakeBackend {
  _FakeBackend({this.failStatus});

  final int? failStatus;
  final requests = <http.Request>[];

  SonaApiClient client() => SonaApiClient(client: MockClient(_handle));

  http.Request? get lastPublish => requests
      .where((r) => r.method == 'POST' && r.url.path.endsWith('/publish'))
      .toList()
      .lastOrNull;

  Map<String, dynamic>? get lastPublishBody {
    final req = lastPublish;
    if (req == null || req.body.isEmpty) return null;
    return jsonDecode(req.body) as Map<String, dynamic>;
  }

  Future<http.Response> _handle(http.Request req) async {
    requests.add(req);
    if (req.url.path.endsWith('/parent-summary/publish') &&
        req.method == 'POST') {
      if (failStatus != null) {
        return http.Response('{"error":"conflict"}', failStatus!,
            headers: _jsonHeaders);
      }
      return http.Response(
        jsonEncode({'status': 'summary_sent', 'publishedAt': '2026-06-13T09:00:00Z'}),
        200,
        headers: _jsonHeaders,
      );
    }
    return http.Response('{"error":"not_found"}', 404);
  }
}

Future<void> _pump(
  WidgetTester tester, {
  required Map<String, dynamic> detail,
  String? summaryHtml,
  Future<void> Function(String htmlBody)? onPublish,
  bool published = false,
  bool busy = false,
}) async {
  tester.view.physicalSize = const Size(1600, 2600);
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
    home: ClinicianParentSummaryScreen(
      caseDetail: detail,
      summaryHtml: summaryHtml,
      onPublish: onPublish,
      published: published,
      busy: busy,
      onBackClinician: () {},
    ),
  ));
  await tester.pumpAndSettle();
}

/// The body editor TextField (multi-line). It is the only field with maxLines
/// driving the live preview.
Finder _bodyField() => find.byWidgetPredicate(
      (w) => w is TextField && (w.maxLines ?? 1) > 1,
    );

void main() {
  group('live preview', () {
    testWidgets('preview reflects the loaded child and intake concern',
        (tester) async {
      await _pump(tester, detail: _detail());

      expect(find.text("Jaden O.'s consultation summary"), findsOneWidget);
      expect(find.textContaining('Stuttering since age 4'), findsWidgets);
      // The three parent-facing sections are present.
      expect(find.text('What we discussed'), findsOneWidget);
      expect(find.text('What happens next'), findsOneWidget);
      expect(find.text('For you at home'), findsOneWidget);
    });

    testWidgets('the session-plan bullets seed the editable body + preview',
        (tester) async {
      await _pump(
        tester,
        detail: _detail(
          goals: const ['Baseline fluency across three contexts'],
          homePractice: const ['Slow conversation game at dinner'],
        ),
      );
      expect(
        find.textContaining('Baseline fluency across three contexts'),
        findsWidgets,
      );
      expect(
        find.textContaining('Slow conversation game at dinner'),
        findsWidgets,
      );
    });

    testWidgets('editing the body updates the live preview', (tester) async {
      await _pump(tester, detail: _detail());

      // Type a brand-new section heading + bullet into the body field.
      await tester.enterText(
        _bodyField(),
        'Custom heading\n- A clinician-written bullet',
      );
      await tester.pumpAndSettle();

      expect(find.text('Custom heading'), findsOneWidget);
      expect(
        find.textContaining('A clinician-written bullet'),
        findsWidgets,
      );
      // The default seeded section is gone now the body was replaced.
      expect(find.text('What we discussed'), findsNothing);
    });

    testWidgets('changing tone re-drafts the body / preview intro',
        (tester) async {
      await _pump(tester, detail: _detail());

      // Default tone is Warm; its standard intro greets the family warmly.
      expect(find.textContaining('It was lovely to meet you'), findsWidgets);

      await tester.tap(find.text('Clinical'));
      await tester.pumpAndSettle();

      // Clinical tone replaces the warm greeting with a records-style intro.
      expect(find.textContaining('It was lovely to meet you'), findsNothing);
      expect(
        find.textContaining('This summary records the outcome'),
        findsWidgets,
      );
    });

    testWidgets('the AI-assisted / clinician-reviewed disclosure is shown',
        (tester) async {
      await _pump(tester, detail: _detail());
      expect(
        find.text('AI-assisted · reviewed by your clinician'),
        findsWidgets,
      );
    });
  });

  group('publish', () {
    testWidgets('Publish sends the clinician final edited htmlBody',
        (tester) async {
      String? sent;
      await _pump(
        tester,
        detail: _detail(),
        onPublish: (html) async => sent = html,
      );

      // Clinician edits the body, then publishes.
      await tester.enterText(
        _bodyField(),
        'Our edited intro for the family.\n'
        'Next steps\n- Book the assessment',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Publish to family'));
      await tester.pumpAndSettle();

      expect(sent, isNotNull);
      // The edited copy + disclosure travel in the published HTML.
      expect(sent, contains('Our edited intro for the family.'));
      expect(sent, contains('<li>Book the assessment</li>'));
      expect(sent, contains('AI-assisted · reviewed by your clinician'));
    });

    testWidgets('published state shows confirmation + carryover hand-off',
        (tester) async {
      await _pump(
        tester,
        detail: _detail(),
        onPublish: (_) async {},
        published: true,
      );
      expect(find.textContaining('Published to the portal'), findsOneWidget);
      expect(find.text('Re-publish summary'), findsOneWidget);
    });
  });

  group('publish contract (api client)', () {
    test('publish posts the clinician htmlBody to the publish endpoint',
        () async {
      final fake = _FakeBackend();
      final result = await fake.client().publishParentSummary(
            'case-jaden',
            htmlBody: '<p>reviewed body</p>',
          );

      expect(result['status'], 'summary_sent');
      expect(fake.lastPublish, isNotNull);
      expect(fake.lastPublish!.url.path,
          endsWith('/v1/cases/case-jaden/parent-summary/publish'));
      expect(fake.lastPublishBody?['htmlBody'], '<p>reviewed body</p>');
    });

    test('publish omits htmlBody when none is provided', () async {
      final fake = _FakeBackend();
      await fake.client().publishParentSummary('case-jaden');
      expect(fake.lastPublishBody, anyOf(isNull, isEmpty));
    });

    test('publish surfaces a conflict (e.g. already published) as an error',
        () async {
      final fake = _FakeBackend(failStatus: 409);
      expect(
        () => fake.client().publishParentSummary('case-jaden',
            htmlBody: '<p>x</p>'),
        throwsA(isA<SonaApiException>()
            .having((e) => e.statusCode, 'statusCode', 409)),
      );
    });
  });
}
