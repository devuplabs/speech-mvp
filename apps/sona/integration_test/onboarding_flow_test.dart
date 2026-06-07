import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sona/features/auth/onboarding_flow.dart';
import 'package:sona/services/api_client.dart';

/// In-process onboarding integration test (Auth·15).
///
/// Drives the real wizard screens (01→05) through one MockClient — admin
/// sign-up → plan/seats → practice config → invite → live — for both
/// group-practice and single-clinician modes, plus seat-limit enforcement.
///
/// The full external E2E (real Firebase token + deployed API/web, invite email
/// → set-password → login) runs in the separate Playwright suite — see the
/// "Auth·15b" Notion task.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  void swallowOverflow() {
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      if ('${details.exception}'.contains('A RenderFlex overflowed')) return;
      original?.call(details);
    };
    addTearDown(() => FlutterError.onError = original);
  }

  Future<_Backend> pumpFlow(WidgetTester tester) async {
    tester.view.physicalSize = const Size(840, 1700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    swallowOverflow();

    final backend = _Backend();
    await tester.pumpWidget(MaterialApp(
      home: OnboardingFlow(
        apiClient: backend.api,
        onCreateAccount: backend.createAccount,
        onComplete: backend.complete,
      ),
    ));
    await tester.pumpAndSettle();
    return backend;
  }

  Future<void> signUp(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField).at(0), 'Dr. Sarah Whitfield');
    await tester.enterText(find.byType(TextField).at(1), 'sarah@wsl.co.uk');
    await tester.enterText(find.byType(TextField).at(2), 'Whitfield Speech');
    await tester.enterText(find.byType(TextField).at(3), 'Str0ng-pass!');
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.text('Create account & continue'));
    await tester.pumpAndSettle();
  }

  testWidgets('group practice: sign-up → plan → config → invite → live',
      (tester) async {
    final backend = await pumpFlow(tester);

    await signUp(tester);
    expect(find.text('Choose your plan'), findsOneWidget);

    // Bump to 6 seats, stay in group mode.
    await tester.tap(find.byKey(const ValueKey('seat-increment')));
    await tester.pump();
    expect(find.text('6 seats'), findsOneWidget);
    await tester.tap(find.text('Continue to practice setup'));
    await tester.pumpAndSettle();

    expect(find.text('Configure your practice'), findsOneWidget);
    await tester.tap(find.text('Continue to add clinicians'));
    await tester.pumpAndSettle();

    // Roster starts with the admin only.
    expect(find.text('Add your clinicians'), findsOneWidget);
    expect(find.text('1 of 6'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'james@wsl.co.uk');
    await tester.tap(find.text('+ Invite'));
    await tester.pumpAndSettle();
    expect(backend.inviteCalls, 1);
    expect(find.text('2 of 6'), findsOneWidget);

    await tester.tap(find.text('Finish setup'));
    await tester.pumpAndSettle();

    expect(find.text('Your practice is live'), findsOneWidget);
    await tester.tap(find.text('Go to admin dashboard'));
    await tester.pump();

    expect(backend.completed, isTrue);
    expect(backend.planMode, 'group');
    expect(backend.planSeats, 6);
    expect(backend.activated, isTrue);
  });

  testWidgets('single clinician: seat limit blocks extra invites',
      (tester) async {
    final backend = await pumpFlow(tester);

    await signUp(tester);
    await tester.tap(find.text('Single clinician'));
    await tester.pumpAndSettle();
    expect(find.text('Number of seats (clinicians)'), findsNothing);
    await tester.tap(find.text('Continue to practice setup'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue to add clinicians'));
    await tester.pumpAndSettle();

    // 1 seat, occupied by the admin → invites are blocked.
    expect(find.text('1 of 1'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'extra@wsl.co.uk');
    await tester.tap(find.text('+ Invite'));
    await tester.pumpAndSettle();

    expect(backend.inviteCalls, 0);
    expect(find.text('No seats left — increase seats to invite more.'),
        findsOneWidget);
    expect(backend.planMode, 'single');
    expect(backend.planSeats, 1);
  });
}

class _Backend {
  int inviteCalls = 0;
  bool completed = false;
  bool activated = false;
  String? planMode;
  int? planSeats;

  final List<Map<String, dynamic>> _roster = [
    {
      'fullName': 'Dr. Sarah Whitfield',
      'email': 'sarah@wsl.co.uk',
      'role': 'admin',
      'status': 'active',
    },
  ];
  int get _seatsUsed => _roster.where((c) => c['status'] != 'disabled').length;

  late final SonaApiClient api = SonaApiClient(client: MockClient((req) async {
    final path = req.url.path;
    final method = req.method;

    if (method == 'POST' && path == '/v1/practices') {
      return _json({
        'practice': {'id': 'prac_1', 'displayName': 'Whitfield Speech'},
        'admin': {'id': 'user_1', 'role': 'admin'},
      }, 201);
    }
    if (method == 'PATCH' && path == '/v1/practices/prac_1/plan') {
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      planMode = body['mode'] as String?;
      planSeats = body['seats'] as int?;
      return _json({'practice': {'id': 'prac_1', 'seats': planSeats}});
    }
    if (method == 'PATCH' && path == '/v1/practices/prac_1') {
      return _json({'practice': {'id': 'prac_1'}});
    }
    if (method == 'GET' && path == '/v1/practices/prac_1/clinicians') {
      return _json({'clinicians': _roster, 'seatsUsed': _seatsUsed});
    }
    if (method == 'POST' && path == '/v1/practices/prac_1/clinicians') {
      inviteCalls++;
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      _roster.add({
        'fullName': null,
        'email': body['email'],
        'role': 'clinician',
        'status': 'invited',
      });
      return _json({'clinician': _roster.last, 'invite': {'emailSent': true}}, 201);
    }
    if (method == 'POST' && path == '/v1/practices/prac_1/activate') {
      activated = true;
      return _json({'tenantId': 'prac_1', 'status': 'active'});
    }
    return http.Response('{"error":"not_found"}', 404);
  }));

  http.Response _json(Object body, [int status = 200]) => http.Response(
        jsonEncode(body),
        status,
        headers: {'content-type': 'application/json'},
      );

  Future<void> createAccount({required String email, required String password}) async {}
  void complete() => completed = true;
}
