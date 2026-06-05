import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sona/features/auth/practice_live_screen.dart';
import 'package:sona/services/api_client.dart';

void main() {
  Future<_Harness> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
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
      home: PracticeLiveScreen(
        apiClient: harness.api,
        practiceId: 'prac_1',
        practiceName: 'Whitfield Speech & Language',
        seats: 5,
        onGoToDashboard: harness.onGoToDashboard,
      ),
    ));
    await tester.pumpAndSettle();
    return harness;
  }

  testWidgets('shows the success state with real summary stats', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Your practice is live'), findsOneWidget);
    expect(
      find.textContaining('Whitfield Speech & Language is set up with 5 seats'),
      findsOneWidget,
    );
    expect(find.text('Admin'), findsOneWidget);
    expect(find.text('Clinicians invited'), findsOneWidget);
    expect(find.text('Seats'), findsOneWidget);
    // 1 admin, 2 clinicians, 5 seats
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
  });

  testWidgets('CTA routes to the admin dashboard', (tester) async {
    final harness = await pumpScreen(tester);

    await tester.tap(find.text('Go to admin dashboard'));
    await tester.pump();

    expect(harness.dashboardTaps, 1);
  });

  testWidgets('gated import link explains GDPR review', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Import patient data (GDPR review required)'));
    await tester.pump();

    expect(
      find.text('Patient import requires GDPR review — coming soon.'),
      findsOneWidget,
    );
  });
}

class _Harness {
  int dashboardTaps = 0;

  late final SonaApiClient api = SonaApiClient(client: MockClient((req) async {
    if (req.method == 'GET' && req.url.path == '/v1/practices/prac_1/clinicians') {
      return http.Response(
        jsonEncode({
          'clinicians': [
            {'role': 'admin', 'status': 'active'},
            {'role': 'clinician', 'status': 'invited'},
            {'role': 'clinician', 'status': 'invited'},
          ],
          'seatsUsed': 3,
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    return http.Response('{"error":"not_found"}', 404);
  }));

  void onGoToDashboard() => dashboardTaps++;
}
