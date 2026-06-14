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

/// Clinician-facing label for each outcome value (mirrors [kTriageOutcomes]).
const _outcomeLabels = <String, String>{
  'strategy_only': 'Strategies only',
  'short_block': 'Short therapy block',
  'full_assessment': 'Full assessment',
  'refer_out': 'Refer onward',
};

Future<void> _pump(
  WidgetTester tester, {
  Map<String, dynamic>? detail,
  void Function(String outcome, String reason)? onPublishSummary,
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
        onPublishSummary: onPublishSummary ?? (_, _) {},
        onBackPrep: () {},
        busy: busy,
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('triage screen UI', () {
    testWidgets(
        'renders the triage outcome card, all four outcomes and rationale field',
        (tester) async {
      await _pump(tester);

      expect(find.text('Triage & session plan'), findsOneWidget);
      expect(find.text('Triage outcome'), findsOneWidget);
      // All four canonical outcomes are offered as selectable cards.
      for (final label in _outcomeLabels.values) {
        expect(find.text(label), findsOneWidget);
      }
      // Clinical rationale field.
      expect(
        find.widgetWithText(TextField, 'Clinical rationale'),
        findsOneWidget,
      );
    });

    testWidgets('header reads the child name from the loaded case',
        (tester) async {
      await _pump(tester);
      expect(find.textContaining('Jaden O.'), findsWidgets);
      expect(find.textContaining('Aria'), findsNothing);
    });

    testWidgets('publish is disabled until an outcome is chosen',
        (tester) async {
      var published = 0;
      await _pump(tester, onPublishSummary: (_, _) => published++);

      // No outcome selected → button is disabled.
      var button = tester.widget<FilledButton>(find.byType(FilledButton).first);
      expect(button.onPressed, isNull,
          reason: 'Cannot publish before a triage outcome is chosen');

      // Selecting an outcome (one that does not require a rationale) enables it.
      await tester.tap(find.text(_outcomeLabels['strategy_only']!));
      await tester.pumpAndSettle();
      button = tester.widget<FilledButton>(find.byType(FilledButton).first);
      expect(button.onPressed, isNotNull);

      await tester.tap(find.text('Review parent summary →'));
      await tester.pump();
      expect(published, 1);
    });

    testWidgets(
        'publish stays disabled when the chosen outcome requires a rationale '
        'until one is entered', (tester) async {
      String? sentOutcome;
      String? sentReason;
      await _pump(tester, onPublishSummary: (o, r) {
        sentOutcome = o;
        sentReason = r;
      });

      // refer_out requires a rationale.
      await tester.tap(find.text(_outcomeLabels['refer_out']!));
      await tester.pumpAndSettle();
      var button = tester.widget<FilledButton>(find.byType(FilledButton).first);
      expect(button.onPressed, isNull,
          reason: 'refer_out must capture a written rationale');

      await tester.enterText(
        find.widgetWithText(TextField, 'Clinical rationale (required)'),
        'Outside our scope of practice',
      );
      await tester.pumpAndSettle();
      button = tester.widget<FilledButton>(find.byType(FilledButton).first);
      expect(button.onPressed, isNotNull);

      await tester.tap(find.text('Review parent summary →'));
      await tester.pump();
      expect(sentOutcome, 'refer_out');
      expect(sentReason, 'Outside our scope of practice');
    });

    testWidgets('publish reports the selected outcome and trimmed rationale',
        (tester) async {
      String? sentOutcome;
      String? sentReason;
      await _pump(tester, onPublishSummary: (o, r) {
        sentOutcome = o;
        sentReason = r;
      });

      await tester.tap(find.text(_outcomeLabels['short_block']!));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Clinical rationale'),
        '  Six-session block for /r/  ',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Review parent summary →'));
      await tester.pump();
      expect(sentOutcome, 'short_block');
      expect(sentReason, 'Six-session block for /r/');
    });

    testWidgets('publish is disabled while a publish is in flight',
        (tester) async {
      var published = 0;
      await _pump(tester, onPublishSummary: (_, _) => published++, busy: true);

      expect(find.text('Recording…'), findsOneWidget);
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

  group('triage screen → API (end to end through the callback)', () {
    for (final outcome in _outcomes) {
      testWidgets('selecting "$outcome" + rationale POSTs exactly those values',
          (tester) async {
        final fake = _FakeBackend();
        final api = fake.client();

        await _pump(tester, onPublishSummary: (o, r) async {
          await api.recordTriage('case-jaden', outcome: o, reason: r);
        });

        await tester.tap(find.text(_outcomeLabels[outcome]!));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextField),
          'Rationale for $outcome',
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Review parent summary →'));
        await tester.pumpAndSettle();

        final body = jsonDecode(fake.lastTriage!.body) as Map<String, dynamic>;
        expect(body['outcome'], outcome);
        expect(body['reason'], 'Rationale for $outcome');
      });
    }

    testWidgets('no API call is made when no outcome is selected',
        (tester) async {
      final fake = _FakeBackend();
      final api = fake.client();

      await _pump(tester, onPublishSummary: (o, r) async {
        await api.recordTriage('case-jaden', outcome: o, reason: r);
      });

      // Button disabled → tapping is a no-op, nothing reaches the backend.
      await tester.tap(find.text('Review parent summary →'));
      await tester.pumpAndSettle();
      expect(fake.lastTriage, isNull);
    });

    testWidgets('surfaces the failure when the triage POST errors',
        (tester) async {
      final fake = _FakeBackend(failStatus: 500);
      final api = fake.client();
      Object? caught;

      await _pump(tester, onPublishSummary: (o, r) async {
        try {
          await api.recordTriage('case-jaden', outcome: o, reason: r);
        } catch (e) {
          caught = e;
        }
      });

      await tester.tap(find.text(_outcomeLabels['strategy_only']!));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Review parent summary →'));
      await tester.pumpAndSettle();

      expect(caught, isA<SonaApiException>());
      expect((caught as SonaApiException).statusCode, 500);
    });
  });
}
