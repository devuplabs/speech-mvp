import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sona/design_system/sona_theme.dart';
import 'package:sona/features/clinician/clinician_parent_summary_screen.dart';
import 'package:sona/services/api_client.dart';
import 'package:sona/test_utils/intake_personas.dart';

/// Stage · Parent summary.
///
/// The clinician composes a parent-facing summary whose live phone preview is
/// driven by the loaded case: the child's name, the intake concern, and the
/// session-plan bullets. Changing the underlying draft sections changes the
/// preview (the "what happens next" / "for you at home" panels). Publishing is
/// the `POST /v1/cases/:id/parent-summary/publish` contract, exercised through
/// the API client with a MockClient backend.

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
      'status': 'summary_sent',
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
}) async {
  tester.view.physicalSize = const Size(1600, 2200);
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
      onBackClinician: () {},
    ),
  ));
  await tester.pumpAndSettle();
}

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

    testWidgets('changing the session-plan sections changes the live preview',
        (tester) async {
      // Initial draft.
      await _pump(
        tester,
        detail: _detail(
          goals: const ['Baseline fluency across three contexts'],
          homePractice: const ['Slow conversation game at dinner'],
        ),
      );
      expect(
        find.textContaining('Baseline fluency across three contexts'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Slow conversation game at dinner'),
        findsOneWidget,
      );

      // Re-pump with edited plan sections — the preview tracks the new content.
      await _pump(
        tester,
        detail: _detail(
          goals: const ['Reduce avoidance in low-pressure contexts'],
          homePractice: const ['Daily five-minute special time'],
        ),
      );
      expect(
        find.textContaining('Reduce avoidance in low-pressure contexts'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Daily five-minute special time'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Baseline fluency across three contexts'),
        findsNothing,
      );
    });

    testWidgets('loaded portal HTML is reflected in the preview',
        (tester) async {
      await _pump(
        tester,
        detail: _detail(),
        summaryHtml: '<h1>Summary</h1>',
      );
      expect(find.textContaining('Portal HTML loaded'), findsOneWidget);
    });
  });

  group('publish contract', () {
    test('publish posts to the parent-summary publish endpoint', () async {
      final fake = _FakeBackend();
      final result = await fake.client().publishParentSummary('case-jaden');

      expect(result['status'], 'summary_sent');
      expect(fake.lastPublish, isNotNull);
      expect(fake.lastPublish!.url.path,
          endsWith('/v1/cases/case-jaden/parent-summary/publish'));
    });

    test('publish surfaces a conflict (e.g. already published) as an error',
        () async {
      final fake = _FakeBackend(failStatus: 409);
      expect(
        () => fake.client().publishParentSummary('case-jaden'),
        throwsA(isA<SonaApiException>()
            .having((e) => e.statusCode, 'statusCode', 409)),
      );
    });
  });
}
