import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sona/features/auth/invite_clinicians_screen.dart';
import 'package:sona/services/api_client.dart';

void main() {
  group('parseCliniciansCsv', () {
    test('parses email/name/role rows and skips junk', () {
      final rows = parseCliniciansCsv(
        'email,name,role\n'
        'james@p.co.uk, James Okafor, clinician\n'
        '\n'
        'priya@p.co.uk, Priya Nair, admin\n'
        'not-an-email\n',
      );
      expect(rows, [
        {'email': 'james@p.co.uk', 'fullName': 'James Okafor', 'role': 'clinician'},
        {'email': 'priya@p.co.uk', 'fullName': 'Priya Nair', 'role': 'admin'},
      ]);
    });

    test('defaults role to clinician and tolerates email-only rows', () {
      final rows = parseCliniciansCsv('solo@p.co.uk');
      expect(rows, [
        {'email': 'solo@p.co.uk', 'role': 'clinician'},
      ]);
    });
  });

  Future<_Harness> pumpScreen(WidgetTester tester, {int totalSeats = 5}) async {
    tester.view.physicalSize = const Size(800, 1500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if ('${details.exception}'.contains('A RenderFlex overflowed')) return;
      originalOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = originalOnError);

    final harness = _Harness();
    await tester.pumpWidget(MaterialApp(
      home: InviteCliniciansScreen(
        apiClient: harness.api,
        practiceId: 'prac_1',
        totalSeats: totalSeats,
        onFinish: harness.onFinish,
      ),
    ));
    await tester.pumpAndSettle();
    return harness;
  }

  testWidgets('renders the roster with badges and seat count', (tester) async {
    await pumpScreen(tester);
    expect(find.text('Dr. Sarah Whitfield'), findsOneWidget);
    expect(find.text('James Okafor'), findsOneWidget);
    expect(find.text('Admin'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Clinician'), findsOneWidget);
    expect(find.text('Invited'), findsOneWidget);
    expect(find.text('2 of 5'), findsOneWidget);
  });

  testWidgets('invites by email and updates seats used', (tester) async {
    final harness = await pumpScreen(tester);

    await tester.enterText(find.byType(TextField), 'priya@whitfieldspeech.co.uk');
    await tester.tap(find.text('+ Invite'));
    await tester.pumpAndSettle();

    expect(harness.inviteCalls, 1);
    expect(harness.invitedEmails, contains('priya@whitfieldspeech.co.uk'));
    expect(find.text('3 of 5'), findsOneWidget);
  });

  testWidgets('blocks invite when no seats remain', (tester) async {
    final harness = await pumpScreen(tester, totalSeats: 2);

    await tester.enterText(find.byType(TextField), 'priya@whitfieldspeech.co.uk');
    await tester.tap(find.text('+ Invite'));
    await tester.pumpAndSettle();

    expect(harness.inviteCalls, 0);
    expect(find.text('No seats left — increase seats to invite more.'),
        findsOneWidget);
  });

  testWidgets('finish activates the practice and advances', (tester) async {
    final harness = await pumpScreen(tester);

    await tester.tap(find.text('Finish setup'));
    await tester.pumpAndSettle();

    expect(harness.activateCalls, 1);
    expect(harness.finished, isTrue);
  });
}

class _Harness {
  final List<Map<String, dynamic>> clinicians = [
    {
      'fullName': 'Dr. Sarah Whitfield',
      'email': 'sarah@whitfieldspeech.co.uk',
      'role': 'admin',
      'status': 'active',
    },
    {
      'fullName': 'James Okafor',
      'email': 'james@whitfieldspeech.co.uk',
      'role': 'clinician',
      'status': 'invited',
    },
  ];
  int inviteCalls = 0;
  int activateCalls = 0;
  bool finished = false;
  final List<String> invitedEmails = [];

  int get _seatsUsed => clinicians.where((c) => c['status'] != 'disabled').length;

  late final SonaApiClient api = SonaApiClient(client: MockClient((req) async {
    final path = req.url.path;
    if (req.method == 'GET' && path == '/v1/practices/prac_1/clinicians') {
      return _json({'clinicians': clinicians, 'seatsUsed': _seatsUsed});
    }
    if (req.method == 'POST' && path == '/v1/practices/prac_1/clinicians') {
      inviteCalls++;
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      invitedEmails.add(body['email'] as String);
      clinicians.add({
        'fullName': null,
        'email': body['email'],
        'role': body['role'] ?? 'clinician',
        'status': 'invited',
      });
      return _json({'clinician': clinicians.last, 'invite': {'emailSent': true}}, 201);
    }
    if (req.method == 'POST' && path == '/v1/practices/prac_1/activate') {
      activateCalls++;
      return _json({'tenantId': 'prac_1', 'status': 'active'});
    }
    return http.Response('{"error":"not_found"}', 404);
  }));

  http.Response _json(Object body, [int status = 200]) => http.Response(
        jsonEncode(body),
        status,
        headers: {'content-type': 'application/json'},
      );

  void onFinish() => finished = true;
}
