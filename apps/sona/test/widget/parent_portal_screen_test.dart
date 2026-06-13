import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sona/features/parent/parent_portal_screen.dart';
import 'package:sona/main.dart';
import 'package:sona/services/api_client.dart';

/// Stage 9 family portal — widget tests against a mocked API client, mirroring
/// the payload shapes proven in `e2e/tests/carryover-api.spec.ts`.
void main() {
  const token = 'portal-token-123';

  Map<String, dynamic> fullPayload({
    Map<String, dynamic>? summary,
    List<Map<String, dynamic>>? resources,
    List<Map<String, dynamic>>? progress,
    String? reviewingClinicianName,
  }) {
    final now = DateTime.now();
    return {
      'case': {
        'id': 'case-1',
        'childDisplayName': 'Aria',
        'status': 'summary_sent',
      },
      'practiceName': 'Speech Sanctuary',
      'reviewingClinicianName': reviewingClinicianName,
      'summary': summary,
      'resources': resources ?? [],
      'progress': progress ?? [],
      'expiresAt': now.add(const Duration(days: 90)).toUtc().toIso8601String(),
    };
  }

  final defaultSummary = {
    'html':
        '<!DOCTYPE html><html><body><p>Aria made great progress with /s/ blends.</p></body></html>',
  };

  List<Map<String, dynamic>> defaultResources() => [
        {
          'id': 'r1',
          'caseId': 'case-1',
          'title': 'Daily sound practice',
          'description': 'Practise /s/ blends for 10 minutes a day.',
          'url': null,
          'category': 'home_practice',
          'createdAt': DateTime.now().toUtc().toIso8601String(),
        },
        {
          'id': 'r2',
          'caseId': 'case-1',
          'title': 'Book list',
          'description': null,
          'url': 'https://example.com/reading',
          'category': 'reading',
          'createdAt': DateTime.now().toUtc().toIso8601String(),
        },
      ];

  List<Map<String, dynamic>> defaultProgress() => [
        {
          'id': 'p1',
          'caseId': 'case-1',
          'author': 'clinician',
          'note': 'Introduced the home practice pack in session.',
          'rating': null,
          'createdAt': DateTime.now()
              .subtract(const Duration(days: 3))
              .toUtc()
              .toIso8601String(),
        },
        {
          'id': 'p2',
          'caseId': 'case-1',
          'author': 'parent',
          'note': 'We tried the sound games twice this week.',
          'rating': 'going_well',
          'createdAt': DateTime.now().toUtc().toIso8601String(),
        },
      ];

  http.Response json(Map<String, dynamic> data, [int status = 200]) =>
      http.Response(jsonEncode(data), status,
          headers: {'content-type': 'application/json'});

  Future<void> pumpPortal(
    WidgetTester tester,
    SonaApiClient api, {
    String portalToken = token,
  }) async {
    tester.view.physicalSize = const Size(440, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: ParentPortalScreen(api: api, token: portalToken),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('full payload renders summary, resources and timeline',
      (tester) async {
    final api = SonaApiClient(
      client: MockClient((req) async {
        if (req.method == 'GET' && req.url.path == '/v1/portal/$token') {
          return json(fullPayload(
            summary: defaultSummary,
            resources: defaultResources(),
            progress: defaultProgress(),
          ));
        }
        return http.Response('{"error":"not_found"}', 404);
      }),
    );

    await pumpPortal(tester, api);

    // Header + case display info.
    expect(find.text('Speech Sanctuary'), findsOneWidget);
    expect(find.text('Supporting Aria at home'), findsOneWidget);

    // Published summary, rendered from the HTML payload, with the
    // AI-disclosure / clinician-review presentation.
    expect(
      find.text('Aria made great progress with /s/ blends.'),
      findsOneWidget,
    );
    expect(find.text('AI-drafted · clinician-reviewed'), findsOneWidget);
    // No reviewing clinician name in this payload → generic AI-assisted line.
    expect(
      find.text('AI-assisted · reviewed by your clinician'),
      findsOneWidget,
    );

    // Resources grouped and badged by category.
    expect(find.text('Home practice'), findsOneWidget);
    expect(find.text('Daily sound practice'), findsOneWidget);
    expect(find.text('Practise /s/ blends for 10 minutes a day.'), findsOneWidget);
    expect(find.text('Reading'), findsOneWidget);
    expect(find.text('Book list'), findsOneWidget);
    expect(find.text('Open link'), findsOneWidget);

    // Timeline: both authors, parent rating shown, relative dates.
    expect(find.text('Past check-ins'), findsOneWidget);
    expect(find.text('Your clinician'), findsOneWidget);
    expect(find.text('You'), findsOneWidget);
    expect(find.text('We tried the sound games twice this week.'), findsOneWidget);
    expect(find.text('Introduced the home practice pack in session.'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('3 days ago'), findsOneWidget);
    // Parent rating badge (the rating pill in the form is a separate widget).
    expect(find.text('Going well'), findsNWidgets(2));
  });

  testWidgets(
      'reviewing clinician name is surfaced in the AI-assisted review line',
      (tester) async {
    final api = SonaApiClient(
      client: MockClient((req) async {
        if (req.method == 'GET' && req.url.path == '/v1/portal/$token') {
          return json(fullPayload(
            summary: defaultSummary,
            reviewingClinicianName: 'Dr. Sarah Whitfield',
          ));
        }
        return http.Response('{"error":"not_found"}', 404);
      }),
    );

    await pumpPortal(tester, api);

    expect(
      find.text('AI-assisted · reviewed by Dr. Sarah Whitfield'),
      findsOneWidget,
    );
    expect(
      find.text('AI-assisted · reviewed by your clinician'),
      findsNothing,
    );
  });

  testWidgets('null summary shows the placeholder copy', (tester) async {
    final api = SonaApiClient(
      client: MockClient((req) async {
        if (req.method == 'GET' && req.url.path == '/v1/portal/$token') {
          return json(fullPayload(summary: null, resources: defaultResources()));
        }
        return http.Response('{"error":"not_found"}', 404);
      }),
    );

    await pumpPortal(tester, api);

    expect(
      find.text('Your clinician will share your summary here once it’s ready.'),
      findsOneWidget,
    );
    expect(find.text('AI-drafted · clinician-reviewed'), findsNothing);
  });

  testWidgets('empty resources shows the empty state', (tester) async {
    final api = SonaApiClient(
      client: MockClient((req) async {
        if (req.method == 'GET' && req.url.path == '/v1/portal/$token') {
          return json(fullPayload(summary: defaultSummary, resources: []));
        }
        return http.Response('{"error":"not_found"}', 404);
      }),
    );

    await pumpPortal(tester, api);

    expect(
      find.text(
        'No resources shared yet. Anything your clinician shares will appear here.',
      ),
      findsOneWidget,
    );
    expect(find.text('No check-ins yet — your first one will appear here.'),
        findsOneWidget);
  });

  testWidgets('check-in submit posts note + rating, clears field, refreshes',
      (tester) async {
    Map<String, dynamic>? postedBody;
    var posted = false;

    final api = SonaApiClient(
      client: MockClient((req) async {
        if (req.method == 'GET' && req.url.path == '/v1/portal/$token') {
          // After the POST the refreshed payload includes the new entry.
          return json(fullPayload(
            summary: defaultSummary,
            progress: posted
                ? [
                    {
                      'id': 'p-new',
                      'caseId': 'case-1',
                      'author': 'parent',
                      'note': 'We practised after school.',
                      'rating': 'tried_it',
                      'createdAt': DateTime.now().toUtc().toIso8601String(),
                    },
                  ]
                : [],
          ));
        }
        if (req.method == 'POST' &&
            req.url.path == '/v1/portal/$token/progress') {
          posted = true;
          postedBody = jsonDecode(req.body) as Map<String, dynamic>;
          return json({
            'entry': {
              'id': 'p-new',
              'caseId': 'case-1',
              'author': 'parent',
              'note': postedBody!['note'],
              'rating': postedBody!['rating'],
              'createdAt': DateTime.now().toUtc().toIso8601String(),
            },
          }, 201);
        }
        return http.Response('{"error":"not_found"}', 404);
      }),
    );

    await pumpPortal(tester, api);

    await tester.enterText(
        find.byType(TextField), 'We practised after school.');
    await tester.tap(find.text('We tried it'));
    await tester.pump();
    await tester.tap(find.text('Share with your clinician'));
    await tester.pumpAndSettle();

    expect(postedBody, isNotNull);
    expect(postedBody!['note'], 'We practised after school.');
    expect(postedBody!['rating'], 'tried_it');

    // Note field cleared after submit.
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, isEmpty);

    // Timeline refreshed with the new entry.
    expect(find.text('We practised after school.'), findsOneWidget);
    expect(find.text('You'), findsOneWidget);
  });

  testWidgets('expired link (410) shows graceful inactive state',
      (tester) async {
    final api = SonaApiClient(
      client: MockClient((req) async {
        return http.Response('{"error":"expired"}', 410,
            headers: {'content-type': 'application/json'});
      }),
    );

    await pumpPortal(tester, api);

    expect(
      find.text(
        'This link is no longer active — ask your clinician for a new one.',
      ),
      findsOneWidget,
    );
    // No portal content rendered.
    expect(find.text('Past check-ins'), findsNothing);
  });

  testWidgets('unknown token (404) shows the same inactive state',
      (tester) async {
    final api = SonaApiClient(
      client: MockClient((req) async {
        return http.Response('{"error":"not_found"}', 404,
            headers: {'content-type': 'application/json'});
      }),
    );

    await pumpPortal(tester, api);

    expect(
      find.text(
        'This link is no longer active — ask your clinician for a new one.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('app deep link ?portal= routes straight to the portal screen',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(440, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = SonaApiClient(
      client: MockClient((req) async {
        if (req.method == 'GET' && req.url.path == '/v1/portal/$token') {
          return json(fullPayload(summary: defaultSummary));
        }
        return http.Response('{"error":"not_found"}', 404);
      }),
    );

    await tester.pumpWidget(SonaApp(apiClient: api, portalToken: token));
    await tester.pumpAndSettle();

    expect(find.text('Supporting Aria at home'), findsOneWidget);
    expect(find.text('Speech Therapy MVP'), findsNothing,
        reason: 'portal link must bypass the launcher');
  });

  group('portalRelativeDate', () {
    final now = DateTime(2026, 6, 12, 15, 30);

    test('boundaries', () {
      expect(portalRelativeDate(DateTime(2026, 6, 12, 1), now: now), 'Today');
      expect(portalRelativeDate(DateTime(2026, 6, 11, 23), now: now), 'Yesterday');
      expect(portalRelativeDate(DateTime(2026, 6, 9), now: now), '3 days ago');
      expect(portalRelativeDate(DateTime(2026, 6, 4), now: now), 'Last week');
      expect(portalRelativeDate(DateTime(2026, 5, 25), now: now), '2 weeks ago');
      expect(portalRelativeDate(DateTime(2026, 3, 1), now: now), '1 March 2026');
    });
  });
}
