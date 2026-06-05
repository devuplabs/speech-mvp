import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sona/features/auth/plan_seats_screen.dart';
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
      home: PlanSeatsScreen(
        apiClient: harness.api,
        practiceId: 'prac_1',
        onContinue: harness.onContinue,
      ),
    ));
    await tester.pumpAndSettle();
    return harness;
  }

  testWidgets('shows the default group plan with live price', (tester) async {
    await pumpScreen(tester);
    expect(find.text('5 seats'), findsOneWidget);
    expect(find.text('5 seats × £29 / mo'), findsOneWidget);
    expect(find.text('£145 / mo'), findsOneWidget);
  });

  testWidgets('recalculates price as seats change', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('seat-increment')));
    await tester.pump();
    expect(find.text('6 seats'), findsOneWidget);
    expect(find.text('£174 / mo'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('seat-decrement')));
    await tester.tap(find.byKey(const ValueKey('seat-decrement')));
    await tester.pump();
    expect(find.text('4 seats'), findsOneWidget);
    expect(find.text('£116 / mo'), findsOneWidget);
  });

  testWidgets('single mode collapses the seat stepper', (tester) async {
    await pumpScreen(tester);
    expect(find.text('Number of seats (clinicians)'), findsOneWidget);

    await tester.tap(find.text('Single clinician'));
    await tester.pumpAndSettle();

    expect(find.text('Number of seats (clinicians)'), findsNothing);
    expect(find.text('1 seat × £29 / mo'), findsOneWidget);
    expect(find.text('£29 / mo'), findsOneWidget);
  });

  testWidgets('persists the plan and advances', (tester) async {
    final harness = await pumpScreen(tester);

    await tester.tap(find.byKey(const ValueKey('seat-increment'))); // 6 seats
    await tester.pump();
    await tester.tap(find.text('Continue to practice setup'));
    await tester.pumpAndSettle();

    expect(harness.planCalls, 1);
    expect(harness.sentBody?['mode'], 'group');
    expect(harness.sentBody?['seats'], 6);
    expect(harness.continued, isTrue);
  });

  testWidgets('persists single mode as one seat', (tester) async {
    final harness = await pumpScreen(tester);

    await tester.tap(find.text('Single clinician'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue to practice setup'));
    await tester.pumpAndSettle();

    expect(harness.sentBody?['mode'], 'single');
    expect(harness.sentBody?['seats'], 1);
    expect(harness.continued, isTrue);
  });
}

class _Harness {
  int planCalls = 0;
  bool continued = false;
  Map<String, dynamic>? sentBody;

  late final SonaApiClient api = SonaApiClient(client: MockClient((req) async {
    if (req.method == 'PATCH' && req.url.path == '/v1/practices/prac_1/plan') {
      planCalls++;
      sentBody = jsonDecode(req.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({
          'practice': {
            'id': 'prac_1',
            'mode': sentBody?['mode'],
            'seats': sentBody?['seats'],
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    return http.Response('{"error":"not_found"}', 404);
  }));

  int? continuedSeats;
  void onContinue(int seats) {
    continued = true;
    continuedSeats = seats;
  }
}
