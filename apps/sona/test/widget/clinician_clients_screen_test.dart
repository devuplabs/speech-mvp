import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sona/features/clinician/clinician_clients_screen.dart';
import 'package:sona/state/sona_app_state.dart';

Future<void> _noopRegister({
  required String childFirstName,
  required String dateOfBirth,
  required String parentName,
  required String parentEmail,
  String? parentPhone,
  required String referralSource,
  String? initialConcerns,
  required bool sendIntakeLink,
  String? bookConsultStart,
}) async {}

void main() {
  testWidgets('empty state shows register CTA', (tester) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final state = SonaAppState();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClinicianClientsScreen(
            state: state,
            onRefresh: () async {},
            onOpenCase: (_) {},
            onRegisterPatient: _noopRegister,
          ),
        ),
      ),
    );
    expect(find.text('Register your first patient'), findsWidgets);
  });

  testWidgets('header opens new patient sheet', (tester) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final state = SonaAppState();
    state.clinicianCases = [
      {
        'id': 'c1',
        'childDisplayName': 'Aria',
        'parentEmail': 'a@example.com',
        'status': 'intake_pending',
        'updatedAt': DateTime.now().toIso8601String(),
      },
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClinicianClientsScreen(
            state: state,
            onRefresh: () async {},
            onOpenCase: (_) {},
            onRegisterPatient: _noopRegister,
          ),
        ),
      ),
    );
    await tester.tap(find.text('+ New patient'));
    await tester.pumpAndSettle();
    expect(find.text('New patient'), findsOneWidget);
  });
}
