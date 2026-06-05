import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sona/features/auth/admin_home_screen.dart';

void main() {
  testWidgets('renders the admin landing and wires actions', (tester) async {
    tester.view.physicalSize = const Size(700, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var openedWorkspace = 0;
    var signedOut = 0;

    await tester.pumpWidget(MaterialApp(
      home: AdminHomeScreen(
        practiceName: 'Whitfield Speech & Language',
        onOpenWorkspace: () => openedWorkspace++,
        onSignOut: () => signedOut++,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Whitfield Speech & Language'), findsOneWidget);
    expect(find.text('Admin'), findsWidgets); // header label + badge

    await tester.tap(find.text('Open clinician workspace'));
    await tester.pump();
    expect(openedWorkspace, 1);

    await tester.tap(find.text('Sign out'));
    await tester.pump();
    expect(signedOut, 1);
  });
}
