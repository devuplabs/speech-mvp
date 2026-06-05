import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sona/features/auth/admin_signup_screen.dart';
import 'package:sona/services/api_client.dart';

/// Widget tests for the Admin Sign-up screen (Auth·07).
///
/// Firebase is injected via `onCreateAccount`, and the API is stubbed with a
/// `MockClient`, so the screen runs without any live backend.
void main() {
  Future<_Harness> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(700, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Flutter's test font renders text far wider than production, so the long
    // button label overflows the fixed 440px card. Swallow only those benign
    // layout warnings. (Set inside the test: the binding resets onError per run.)
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if ('${details.exception}'.contains('A RenderFlex overflowed')) return;
      originalOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = originalOnError);

    final harness = _Harness();
    await tester.pumpWidget(MaterialApp(
      home: AdminSignupScreen(
        apiClient: harness.api,
        onCreateAccount: harness.createAccount,
        onAccountCreated: harness.onCreated,
      ),
    ));
    await tester.pumpAndSettle();
    return harness;
  }

  testWidgets('blocks submit and shows inline errors when invalid', (tester) async {
    final harness = await pumpScreen(tester);

    await tester.tap(find.text('Create account & continue'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your full name'), findsOneWidget);
    expect(find.text('Enter a valid email address'), findsOneWidget);
    expect(find.text('Enter your practice name'), findsOneWidget);
    expect(find.text('Use at least 10 characters'), findsOneWidget);
    expect(
      find.text('Please accept the Terms & GDPR notice to continue'),
      findsOneWidget,
    );
    expect(harness.createAccountCalls, 0);
    expect(harness.practiceCalls, 0);
  });

  testWidgets('enforces the password policy', (tester) async {
    final harness = await pumpScreen(tester);

    await _fill(tester, fullName: 'Dr. Sarah Whitfield', email: 'sarah@wsl.co.uk',
        practice: 'Whitfield Speech', password: 'short1!');
    await _acceptConsent(tester);
    await tester.tap(find.text('Create account & continue'));
    await tester.pumpAndSettle();
    expect(find.text('Use at least 10 characters'), findsOneWidget);

    // Long but no number/symbol.
    await tester.enterText(find.byType(TextField).at(3), 'abcdefghijkl');
    await tester.tap(find.text('Create account & continue'));
    await tester.pumpAndSettle();
    expect(find.text('Include at least one number'), findsOneWidget);

    expect(harness.createAccountCalls, 0);
  });

  testWidgets('creates the account + practice and reports the new id',
      (tester) async {
    final harness = await pumpScreen(tester);

    await _fill(tester,
        fullName: 'Dr. Sarah Whitfield',
        email: 'sarah@whitfieldspeech.co.uk',
        practice: 'Whitfield Speech & Language',
        password: 'Str0ng-pass!');
    await _acceptConsent(tester);

    await tester.tap(find.text('Create account & continue'));
    await tester.pumpAndSettle();

    expect(harness.createAccountCalls, 1);
    expect(harness.createdEmail, 'sarah@whitfieldspeech.co.uk');
    expect(harness.createdPassword, 'Str0ng-pass!');
    expect(harness.practiceCalls, 1);
    expect(harness.sentBody?['practiceName'], 'Whitfield Speech & Language');
    expect(harness.sentBody?['adminFullName'], 'Dr. Sarah Whitfield');
    expect(harness.createdPracticeId, 'prac_123');
  });
}

Future<void> _fill(
  WidgetTester tester, {
  required String fullName,
  required String email,
  required String practice,
  required String password,
}) async {
  await tester.enterText(find.byType(TextField).at(0), fullName);
  await tester.enterText(find.byType(TextField).at(1), email);
  await tester.enterText(find.byType(TextField).at(2), practice);
  await tester.enterText(find.byType(TextField).at(3), password);
  await tester.pump();
}

Future<void> _acceptConsent(WidgetTester tester) async {
  await tester.tap(find.byType(Checkbox));
  await tester.pump();
}

class _Harness {
  int createAccountCalls = 0;
  int practiceCalls = 0;
  String? createdEmail;
  String? createdPassword;
  String? createdPracticeId;
  Map<String, dynamic>? sentBody;

  late final SonaApiClient api = SonaApiClient(client: MockClient((req) async {
    if (req.method == 'POST' && req.url.path == '/v1/practices') {
      practiceCalls++;
      sentBody = jsonDecode(req.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({
          'practice': {'id': 'prac_123', 'displayName': sentBody?['practiceName']},
          'admin': {'id': 'user_1'},
        }),
        201,
        headers: {'content-type': 'application/json'},
      );
    }
    return http.Response('{"error":"not_found"}', 404);
  }));

  Future<void> createAccount({
    required String email,
    required String password,
  }) async {
    createAccountCalls++;
    createdEmail = email;
    createdPassword = password;
  }

  String? createdPracticeName;
  void onCreated(String id, String name) {
    createdPracticeId = id;
    createdPracticeName = name;
  }
}
