import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sona/features/auth/clinician_login_screen.dart';

void main() {
  Future<_Calls> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(700, 1500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if ('${details.exception}'.contains('A RenderFlex overflowed')) return;
      originalOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = originalOnError);

    final calls = _Calls();
    await tester.pumpWidget(MaterialApp(
      home: ClinicianLoginScreen(
        onPasswordSignIn: calls.passwordSignIn,
        onMagicLink: calls.magicLink,
        onForgotPassword: calls.forgotPassword,
        onSignedIn: calls.signedIn,
      ),
    ));
    await tester.pumpAndSettle();
    return calls;
  }

  testWidgets('validates email and password before signing in', (tester) async {
    final calls = await pumpScreen(tester);

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid email address'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
    expect(calls.signInCount, 0);
  });

  testWidgets('signs in with email + password', (tester) async {
    final calls = await pumpScreen(tester);

    await tester.enterText(find.byType(TextField).at(0), 'james@wsl.co.uk');
    await tester.enterText(find.byType(TextField).at(1), 'sup3r-secret!');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(calls.signInCount, 1);
    expect(calls.email, 'james@wsl.co.uk');
    expect(calls.password, 'sup3r-secret!');
    expect(calls.signedInCount, 1);
  });

  testWidgets('sends a magic link', (tester) async {
    final calls = await pumpScreen(tester);

    await tester.enterText(find.byType(TextField).at(0), 'james@wsl.co.uk');
    await tester.tap(find.text('Email me a magic link'));
    await tester.pumpAndSettle();

    expect(calls.magicLinkEmail, 'james@wsl.co.uk');
    expect(find.textContaining('Magic link sent to james@wsl.co.uk'), findsOneWidget);
  });

  testWidgets('forgot password sends a reset email', (tester) async {
    final calls = await pumpScreen(tester);

    await tester.enterText(find.byType(TextField).at(0), 'james@wsl.co.uk');
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();

    expect(calls.forgotEmail, 'james@wsl.co.uk');
    expect(find.textContaining('Password reset email sent'), findsOneWidget);
  });

  testWidgets('magic link requires an email first', (tester) async {
    final calls = await pumpScreen(tester);

    await tester.tap(find.text('Email me a magic link'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your email first'), findsOneWidget);
    expect(calls.magicLinkEmail, isNull);
  });
}

class _Calls {
  int signInCount = 0;
  int signedInCount = 0;
  String? email;
  String? password;
  String? magicLinkEmail;
  String? forgotEmail;

  Future<void> passwordSignIn({
    required String email,
    required String password,
  }) async {
    signInCount++;
    this.email = email;
    this.password = password;
  }

  Future<void> magicLink(String email) async => magicLinkEmail = email;
  Future<void> forgotPassword(String email) async => forgotEmail = email;
  void signedIn() => signedInCount++;
}
