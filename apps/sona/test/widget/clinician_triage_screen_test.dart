import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sona/design_system/sona_theme.dart';
import 'package:sona/features/clinician/clinician_triage_screen.dart';
import 'package:sona/services/api_client.dart';
import 'package:sona/test_utils/intake_personas.dart';

/// Stage · Triage & session plan.
///
/// Two halves to this screen's behaviour:
///   1. The widget itself — renders the loaded case, surfaces the triage
///      outcomes + clinician notes field, and fires the publish callback.
///   2. The triage write contract — `POST /v1/cases/:id/triage` carries the
///      chosen outcome + reason, and surfaces an error when the call fails.
///      Driven through [SonaApiClient] with an in-memory backend, mirroring
///      the `MockClient` style used across the clinician widget tests.

const _jsonHeaders = {'content-type': 'application/json'};

/// The four triage outcomes the clinical loop records (DEV-10 vocabulary).
const _outcomes = <String>[
  'strategy_only',
  'short_block',
  'full_assessment',
  'refer_out',
];

Map<String, dynamic> _caseDetail() {
  final persona = personaById('jaden_stutter_7yo');
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
    'drafts': const <Map<String, dynamic>>[],
  };
}

/// Minimal triage backend — records the outcome, or returns the configured
/// failure status so the error path can be exercised deterministically.
class _FakeBackend {
  _FakeBackend({this.failStatus});

  final int? failStatus;
  final requests = <http.Request>[];

  SonaApiClient client() => SonaApiClient(client: MockClient(_handle));

  http.Request? get lastTriage => requests
      .where((r) => r.method == 'POST' && r.url.path.endsWith('/triage'))
      .toList()
      .lastOrNull;

  Future<http.Response> _handle(http.Request req) async {
    requests.add(req);
    if (req.url.path.endsWith('/triage') && req.method == 'POST') {
      if (failStatus != null) {
        return http.Response('{"error":"server_error"}', failStatus!,
            headers: _jsonHeaders);
      }
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({
          'id': 'case-jaden',
          'status': 'triaged',
          'outcome': body['outcome'],
          'reason': body['reason'],
        }),
        200,
        headers: _jsonHeaders,
      );
    }
    return http.Response('{"error":"not_found"}', 404);
  }
}

Future<void> _pump(
  WidgetTester tester, {
  Map<String, dynamic>? detail,
  VoidCallback? onPublishSummary,
  bool busy = false,
}) async {
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
      body: ClinicianTriageScreen(
        caseDetail: detail ?? _caseDetail(),
        onPublishSummary: onPublishSummary ?? () {},
        onBackPrep: () {},
        busy: busy,
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('triage screen UI', () {
    testWidgets('renders the triage outcome card, chips and clinician notes',
        (tester) async {
      await _pump(tester);

      expect(find.text('Triage & session plan'), findsOneWidget);
      expect(find.text('Triage outcome'), findsOneWidget);
      // Outcome chips are selectable options on the triage card.
      expect(find.text('Speech sound disorder'), findsOneWidget);
      expect(find.text('Refer onward'), findsOneWidget);
      // Internal reason / notes field.
      expect(
        find.widgetWithText(TextField, 'Clinician notes (internal)'),
        findsOneWidget,
      );
    });

    testWidgets('header reads the child name from the loaded case',
        (tester) async {
      await _pump(tester);
      expect(find.textContaining('Jaden O.'), findsWidgets);
      expect(find.textContaining('Aria'), findsNothing);
    });

    testWidgets('publish parent summary fires the callback when not busy',
        (tester) async {
      var published = 0;
      await _pump(tester, onPublishSummary: () => published++);

      await tester.tap(find.text('Publish parent summary'));
      await tester.pump();
      expect(published, 1);
    });

    testWidgets('publish is disabled while a publish is in flight',
        (tester) async {
      var published = 0;
      await _pump(tester, onPublishSummary: () => published++, busy: true);

      expect(find.text('Publishing…'), findsOneWidget);
      final button =
          tester.widget<FilledButton>(find.byType(FilledButton).first);
      expect(button.onPressed, isNull,
          reason: 'A busy publish button must not re-fire the API call');
    });
  });

  group('triage write contract', () {
    for (final outcome in _outcomes) {
      test('records the "$outcome" outcome with a reason', () async {
        final fake = _FakeBackend();
        final result = await fake.client().recordTriage(
              'case-jaden',
              outcome: outcome,
              reason: 'Clinical rationale for $outcome',
            );

        expect(result['status'], 'triaged');
        final body =
            jsonDecode(fake.lastTriage!.body) as Map<String, dynamic>;
        expect(body['outcome'], outcome);
        expect(body['reason'], 'Clinical rationale for $outcome');
      });
    }

    test('surfaces an error when the triage call fails', () async {
      final fake = _FakeBackend(failStatus: 500);
      expect(
        () => fake.client().recordTriage('case-jaden', outcome: 'refer_out'),
        throwsA(isA<SonaApiException>()
            .having((e) => e.statusCode, 'statusCode', 500)),
      );
    });
  });
}
