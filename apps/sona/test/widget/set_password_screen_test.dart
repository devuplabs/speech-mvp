import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sona/features/auth/set_password_screen.dart';

void main() {
  Future<_Calls> pumpScreen(
    WidgetTester tester, {
    bool validCode = true,
  }) async {
    tester.view.physicalSize = const Size(700, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if ('${details.exception}'.contains('A RenderFlex overflowed')) return;
      originalOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = originalOnError);

    final calls = _Calls(validCode: validCode);
    await tester.pumpWidget(MaterialApp(
      home: SetPasswordScreen(
        oobCode: 'code-123',
        onVerifyCode: calls.verifyCode,
        onSetPassword: calls.setPassword,
        onCompleted: calls.completed,
        inviterName: 'Dr. Sarah Whitfield',
        practiceName: 'Whitfield Speech & Language',
      ),
    ));
    await tester.pumpAndSettle();
    return calls;
  }

  testWidgets('verifies the code and shows the invite + read-only email',
      (tester) async {
    await pumpScreen(tester);

    expect(find.text('Set your password'), findsOneWidget);
    expect(find.text('Invitation from Dr. Sarah Whitfield'), findsOneWidget);
    expect(find.text('james@whitfieldspeech.co.uk'), findsOneWidget);
    expect(
      find.textContaining('added to Whitfield Speech & Language as a Clinician'),
      findsOneWidget,
    );
  });

  testWidgets('handles an invalid/expired link', (tester) async {
    final calls = await pumpScreen(tester, validCode: false);

    expect(find.text('Invite link invalid or expired'), findsOneWidget);
    expect(find.text('Set your password'), findsNothing);
    expect(calls.verifyCount, 1);
  });

  testWidgets('enforces password rules before enabling submit', (tester) async {
    final calls = await pumpScreen(tester);

    // Too short → button disabled, nothing happens.
    await tester.enterText(find.byType(TextField).at(0), 'short1!');
    await tester.enterText(find.byType(TextField).at(1), 'short1!');
    await tester.pump();
    await tester.tap(find.text('Set password & continue'));
    await tester.pumpAndSettle();
    expect(calls.setCount, 0);

    // Mismatch → shows hint, still disabled.
    await tester.enterText(find.byType(TextField).at(0), 'Str0ng-pass!');
    await tester.enterText(find.byType(TextField).at(1), 'different1!');
    await tester.pump();
    expect(find.text('Passwords don’t match'), findsOneWidget);
    await tester.tap(find.text('Set password & continue'));
    await tester.pumpAndSettle();
    expect(calls.setCount, 0);
  });

  testWidgets('sets the password and completes', (tester) async {
    final calls = await pumpScreen(tester);

    await tester.enterText(find.byType(TextField).at(0), 'Str0ng-pass!');
    await tester.enterText(find.byType(TextField).at(1), 'Str0ng-pass!');
    await tester.pump();
    await tester.tap(find.text('Set password & continue'));
    await tester.pumpAndSettle();

    expect(calls.setCount, 1);
    expect(calls.setCode, 'code-123');
    expect(calls.setPasswordValue, 'Str0ng-pass!');
    expect(calls.completedCount, 1);
  });
}

class _Calls {
  _Calls({required this.validCode});
  final bool validCode;

  int verifyCount = 0;
  int setCount = 0;
  int completedCount = 0;
  String? setCode;
  String? setPasswordValue;

  Future<String> verifyCode(String code) async {
    verifyCount++;
    if (!validCode) throw Exception('expired');
    return 'james@whitfieldspeech.co.uk';
  }

  Future<void> setPassword({required String code, required String password}) async {
    setCount++;
    setCode = code;
    setPasswordValue = password;
  }

  void completed() => completedCount++;
}
