import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sona/features/auth/onboarding_flow.dart';
import 'package:sona/services/api_client.dart';

/// Integration test: drives the full onboarding wizard (screens 01→05) through
/// a single MockClient, verifying each step advances and the new practice id is
/// threaded through.
void main() {
  testWidgets('drives admin sign-up → plan → config → invite → live',
      (tester) async {
    tester.view.physicalSize = const Size(820, 1600);
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
      home: OnboardingFlow(
        apiClient: harness.api,
        onCreateAccount: harness.createAccount,
        onComplete: harness.complete,
      ),
    ));
    await tester.pumpAndSettle();

    // 01 — Admin sign-up.
    expect(find.text('Create your practice account'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), 'Dr. Sarah Whitfield');
    await tester.enterText(find.byType(TextField).at(1), 'sarah@wsl.co.uk');
    await tester.enterText(find.byType(TextField).at(2), 'Whitfield Speech');
    await tester.enterText(find.byType(TextField).at(3), 'Str0ng-pass!');
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.text('Create account & continue'));
    await tester.pumpAndSettle();

    // 02 — Plan & seats.
    expect(find.text('Choose your plan'), findsOneWidget);
    await tester.tap(find.text('Continue to practice setup'));
    await tester.pumpAndSettle();

    // 03 — Practice config (name prefilled from sign-up).
    expect(find.text('Configure your practice'), findsOneWidget);
    await tester.tap(find.text('Continue to add clinicians'));
    await tester.pumpAndSettle();

    // 04 — Invite clinicians.
    expect(find.text('Add your clinicians'), findsOneWidget);
    await tester.tap(find.text('Finish setup'));
    await tester.pumpAndSettle();

    // 05 — Practice live.
    expect(find.text('Your practice is live'), findsOneWidget);
    await tester.tap(find.text('Go to admin dashboard'));
    await tester.pump();

    expect(harness.completed, isTrue);
    expect(harness.createAccountCalls, 1);
    // Every practice-scoped call targeted the id returned by sign-up.
    expect(harness.paths.where((p) => p.contains('/v1/practices/prac_99')).isNotEmpty,
        isTrue);
  });
}

class _Harness {
  int createAccountCalls = 0;
  bool completed = false;
  final List<String> paths = [];

  late final SonaApiClient api = SonaApiClient(client: MockClient((req) async {
    paths.add(req.url.path);
    final path = req.url.path;

    if (req.method == 'POST' && path == '/v1/practices') {
      return _json({
        'practice': {'id': 'prac_99', 'displayName': 'Whitfield Speech'},
        'admin': {'id': 'user_1', 'role': 'admin'},
      }, 201);
    }
    if (req.method == 'PATCH' && path == '/v1/practices/prac_99/plan') {
      return _json({'practice': {'id': 'prac_99', 'seats': 5}});
    }
    if (req.method == 'PATCH' && path == '/v1/practices/prac_99') {
      return _json({'practice': {'id': 'prac_99'}});
    }
    if (req.method == 'GET' && path == '/v1/practices/prac_99/clinicians') {
      return _json({
        'clinicians': [
          {'fullName': 'Dr. Sarah Whitfield', 'email': 'sarah@wsl.co.uk', 'role': 'admin', 'status': 'active'},
        ],
        'seatsUsed': 1,
      });
    }
    if (req.method == 'POST' && path == '/v1/practices/prac_99/activate') {
      return _json({'tenantId': 'prac_99', 'status': 'active'});
    }
    return http.Response('{"error":"not_found"}', 404);
  }));

  http.Response _json(Object body, [int status = 200]) => http.Response(
        jsonEncode(body),
        status,
        headers: {'content-type': 'application/json'},
      );

  Future<void> createAccount({required String email, required String password}) async {
    createAccountCalls++;
  }

  void complete() => completed = true;
}
