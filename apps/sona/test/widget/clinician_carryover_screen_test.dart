import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sona/features/clinician/clinician_carryover_screen.dart';
import 'package:sona/services/api_client.dart';

const _jsonHeaders = {'content-type': 'application/json'};
const _caseId = 'c1';

/// In-memory carryover backend mirroring the v1 API shapes
/// (`{resources: [...]}`, `{entries: [...]}`, `{token, expiresAt}` — see
/// e2e/tests/carryover-api.spec.ts).
class _FakeBackend {
  final requests = <http.Request>[];
  List<Map<String, dynamic>> resources = [];
  List<Map<String, dynamic>> entries = [];
  int _nextId = 1;

  SonaApiClient client() => SonaApiClient(client: MockClient(_handle));

  List<http.Request> ofMethod(String method, String pathSuffix) => requests
      .where((r) => r.method == method && r.url.path.endsWith(pathSuffix))
      .toList();

  Future<http.Response> _handle(http.Request req) async {
    requests.add(req);
    final path = req.url.path;
    final resourcesPath = '/v1/cases/$_caseId/carryover/resources';
    final progressPath = '/v1/cases/$_caseId/carryover/progress';

    if (path == resourcesPath && req.method == 'GET') {
      return http.Response(jsonEncode({'resources': resources}), 200,
          headers: _jsonHeaders);
    }
    if (path == resourcesPath && req.method == 'POST') {
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      final row = <String, dynamic>{
        'id': 'r${_nextId++}',
        'caseId': _caseId,
        'title': body['title'],
        'description': body['description'],
        'url': body['url'],
        'category': body['category'],
        'sourceDraftId': body['sourceDraftId'],
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      };
      resources.add(row);
      return http.Response(jsonEncode({'resource': row}), 201,
          headers: _jsonHeaders);
    }
    if (path.startsWith('$resourcesPath/')) {
      final id = path.split('/').last;
      final index = resources.indexWhere((r) => r['id'] == id);
      if (index < 0) return http.Response('{"error":"not_found"}', 404);
      if (req.method == 'PATCH') {
        final patch = jsonDecode(req.body) as Map<String, dynamic>;
        resources[index] = {...resources[index], ...patch};
        return http.Response(jsonEncode({'resource': resources[index]}), 200,
            headers: _jsonHeaders);
      }
      if (req.method == 'DELETE') {
        resources.removeAt(index);
        return http.Response('', 204);
      }
    }
    if (path == progressPath && req.method == 'GET') {
      return http.Response(jsonEncode({'entries': entries}), 200,
          headers: _jsonHeaders);
    }
    if (path == progressPath && req.method == 'POST') {
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      final row = <String, dynamic>{
        'id': 'p${_nextId++}',
        'caseId': _caseId,
        'author': 'clinician',
        'note': body['note'],
        'rating': body['rating'],
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      };
      entries.insert(0, row); // API returns newest-first
      return http.Response(jsonEncode({'entry': row}), 201,
          headers: _jsonHeaders);
    }
    if (path == '/v1/cases/$_caseId/portal-links' && req.method == 'POST') {
      return http.Response(
        jsonEncode({
          'token': 'tok-abc123',
          'expiresAt': DateTime.now()
              .add(const Duration(days: 90))
              .toUtc()
              .toIso8601String(),
        }),
        201,
        headers: _jsonHeaders,
      );
    }
    if (path == '/v1/cases/$_caseId/portal-links/revoke' &&
        req.method == 'POST') {
      return http.Response('', 204);
    }
    return http.Response('{"error":"not_found"}', 404);
  }
}

Map<String, dynamic> _caseDetailWithPlan(List<String> homePractice) => {
      'case': {'id': _caseId, 'childDisplayName': 'Aria'},
      'drafts': [
        {
          'id': 'd1',
          'kind': 'session_plan',
          'content': {
            'sections': {'homePractice': homePractice},
          },
        },
      ],
    };

/// Captures `Clipboard.setData` payloads — without a mock handler the platform
/// channel throws `MissingPluginException` under flutter_test.
List<String> _mockClipboard(WidgetTester tester) {
  final copied = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add(((call.arguments as Map)['text'] as String?) ?? '');
      }
      return null;
    },
  );
  addTearDown(() => tester.binding.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, null));
  return copied;
}

Future<void> _pump(
  WidgetTester tester,
  _FakeBackend fake, {
  Map<String, dynamic>? caseDetail,
}) async {
  tester.view.physicalSize = const Size(1400, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ClinicianCarryoverScreen(
          api: fake.client(),
          caseId: _caseId,
          webBaseUrl: 'https://web.example',
          onBack: () {},
          caseDetail: caseDetail,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('empty state shows resource and progress placeholders',
      (tester) async {
    final fake = _FakeBackend();
    await _pump(tester, fake);

    expect(find.text('Carryover & home practice · Client'), findsOneWidget);
    expect(
      find.textContaining('No resources shared yet'),
      findsOneWidget,
    );
    expect(find.textContaining('No progress logged yet'), findsOneWidget);
  });

  testWidgets('add resource requires a title then POSTs the new resource',
      (tester) async {
    final fake = _FakeBackend();
    await _pump(tester, fake);

    await tester.tap(find.text('Add resource'));
    await tester.pumpAndSettle();
    // Title required — saving with an empty title shows an inline error.
    await tester.tap(find.text('Add').last);
    await tester.pumpAndSettle();
    expect(find.text('Title is required'), findsOneWidget);

    await tester.enterText(
        find.widgetWithText(TextField, 'Title *'), 'Daily sound practice');
    await tester.enterText(find.widgetWithText(TextField, 'Description'),
        'Practise /s/ blends for 10 minutes a day.');
    await tester.tap(find.text('Reading'));
    await tester.pump();
    await tester.tap(find.text('Add').last);
    await tester.pumpAndSettle();

    final posts = fake.ofMethod('POST', '/carryover/resources');
    expect(posts, hasLength(1));
    final body = jsonDecode(posts.single.body) as Map<String, dynamic>;
    expect(body['title'], 'Daily sound practice');
    expect(body['description'], 'Practise /s/ blends for 10 minutes a day.');
    expect(body['category'], 'reading');
    expect(body.containsKey('url'), isFalse,
        reason: 'null optional fields are omitted, not sent as JSON null');
    expect(find.text('Daily sound practice'), findsOneWidget);
  });

  testWidgets('populated list supports edit and delete', (tester) async {
    final fake = _FakeBackend()
      ..resources = [
        {
          'id': 'r1',
          'caseId': _caseId,
          'title': 'Daily sound practice',
          'description': 'Ten minutes a day.',
          'url': null,
          'category': 'home_practice',
          'sourceDraftId': null,
          'createdAt': '2026-06-10T10:00:00.000Z',
        },
        {
          'id': 'r2',
          'caseId': _caseId,
          'title': 'Book list',
          'description': null,
          'url': 'https://example.com/reading',
          'category': 'reading',
          'sourceDraftId': null,
          'createdAt': '2026-06-10T11:00:00.000Z',
        },
      ];
    await _pump(tester, fake);

    expect(find.text('Daily sound practice'), findsOneWidget);
    expect(find.text('Book list'), findsOneWidget);
    expect(find.text('https://example.com/reading'), findsOneWidget);

    // Edit the first resource's title.
    await tester.tap(find.text('Edit').first);
    await tester.pumpAndSettle();
    expect(find.text('Edit resource'), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextField, 'Daily sound practice'),
        'Daily sound practice (week 2)');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final patches = fake.ofMethod('PATCH', '/carryover/resources/r1');
    expect(patches, hasLength(1));
    expect(jsonDecode(patches.single.body),
        containsPair('title', 'Daily sound practice (week 2)'));
    expect(find.text('Daily sound practice (week 2)'), findsOneWidget);

    // Delete the second resource — confirm dialog first.
    await tester.tap(find.text('Remove').last);
    await tester.pumpAndSettle();
    expect(find.text('Remove resource?'), findsOneWidget);
    await tester.tap(find.text('Remove').last);
    await tester.pumpAndSettle();

    expect(fake.ofMethod('DELETE', '/carryover/resources/r2'), hasLength(1));
    expect(find.text('Book list'), findsNothing);
  });

  testWidgets('import from session plan POSTs new items and skips duplicates',
      (tester) async {
    final fake = _FakeBackend()
      ..resources = [
        {
          'id': 'r1',
          'caseId': _caseId,
          'title': 'Practice A',
          'description': null,
          'url': null,
          'category': 'home_practice',
          'sourceDraftId': 'd1',
          'createdAt': '2026-06-10T10:00:00.000Z',
        },
      ];
    await _pump(
      tester,
      fake,
      caseDetail: _caseDetailWithPlan(['Practice A', 'Practice B']),
    );

    await tester.tap(find.text('Import from session plan'));
    await tester.pumpAndSettle();

    final posts = fake.ofMethod('POST', '/carryover/resources');
    expect(posts, hasLength(1),
        reason: 'Practice A is already shared — only Practice B is created');
    final body = jsonDecode(posts.single.body) as Map<String, dynamic>;
    expect(body['title'], 'Practice B');
    expect(body['category'], 'home_practice');
    expect(body['sourceDraftId'], 'd1');
    expect(find.text('Practice B'), findsOneWidget);
    expect(
      find.textContaining('Imported 1 item(s) from the session plan'),
      findsOneWidget,
    );

    // Let the first snackbar expire so the second isn't queued behind it.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    // Re-tapping is a no-op: everything is already imported.
    await tester.tap(find.text('Import from session plan'));
    await tester.pumpAndSettle();
    expect(fake.ofMethod('POST', '/carryover/resources'), hasLength(1));
    expect(find.text('All session-plan items are already shared.'),
        findsOneWidget);
  });

  testWidgets('share with family surfaces the copyable portal URL',
      (tester) async {
    final fake = _FakeBackend();
    final copied = _mockClipboard(tester);
    await _pump(tester, fake, caseDetail: _caseDetailWithPlan(const []));

    await tester.tap(find.text('Share with family'));
    await tester.pumpAndSettle();

    expect(fake.ofMethod('POST', '/portal-links'), hasLength(1));
    expect(
      find.textContaining('https://web.example/?portal=tok-abc123'),
      findsOneWidget,
    );
    expect(find.text('Copy again'), findsOneWidget);
    expect(copied, ['https://web.example/?portal=tok-abc123']);
  });

  testWidgets('revoke access confirms then POSTs the revoke', (tester) async {
    final fake = _FakeBackend();
    await _pump(tester, fake);

    await tester.tap(find.text('Revoke access'));
    await tester.pumpAndSettle();
    expect(find.text('Revoke portal access?'), findsOneWidget);
    await tester.tap(find.text('Revoke'));
    await tester.pumpAndSettle();

    expect(fake.ofMethod('POST', '/portal-links/revoke'), hasLength(1));
    expect(find.text('Portal access revoked.'), findsOneWidget);
  });

  testWidgets('progress timeline renders family and clinician entries',
      (tester) async {
    final fake = _FakeBackend()
      ..entries = [
        {
          'id': 'p2',
          'caseId': _caseId,
          'author': 'parent',
          'note': 'We tried the sound games twice this week.',
          'rating': 'going_well',
          'createdAt': DateTime.now()
              .subtract(const Duration(hours: 3))
              .toUtc()
              .toIso8601String(),
        },
        {
          'id': 'p1',
          'caseId': _caseId,
          'author': 'clinician',
          'note': 'Introduced the home practice pack in session.',
          'rating': null,
          'createdAt': DateTime.now()
              .subtract(const Duration(days: 2))
              .toUtc()
              .toIso8601String(),
        },
      ];
    await _pump(tester, fake);

    expect(find.text('Family'), findsOneWidget);
    expect(find.text('Clinician'), findsOneWidget);
    expect(find.text('We tried the sound games twice this week.'),
        findsOneWidget);
    expect(find.text('Introduced the home practice pack in session.'),
        findsOneWidget);
    expect(find.textContaining('Going well'), findsOneWidget);
    expect(find.textContaining('2d ago'), findsOneWidget);
  });

  testWidgets('clinician can add a progress note', (tester) async {
    final fake = _FakeBackend();
    await _pump(tester, fake);

    await tester.enterText(
      find.widgetWithText(TextField, 'Add a note for this case'),
      'Reviewed home practice with parent.',
    );
    await tester.tap(find.text('Add note'));
    await tester.pumpAndSettle();

    final posts = fake.ofMethod('POST', '/carryover/progress');
    expect(posts, hasLength(1));
    expect(jsonDecode(posts.single.body),
        containsPair('note', 'Reviewed home practice with parent.'));
    expect(find.text('Reviewed home practice with parent.'), findsOneWidget);
    expect(find.text('Clinician'), findsOneWidget);
  });
}
