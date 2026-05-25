import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sona/features/clinician/clinician_coming_soon_screen.dart';

void main() {
  testWidgets('shows title and coming soon label', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ClinicianComingSoonScreen(
            title: 'Resources',
            description: 'Handouts and templates will live here.',
            plannedItems: ['Parent handouts'],
          ),
        ),
      ),
    );

    expect(find.text('Resources'), findsOneWidget);
    expect(find.text('Coming in v0.2'), findsOneWidget);
    expect(find.text('Parent handouts'), findsOneWidget);
  });
}
