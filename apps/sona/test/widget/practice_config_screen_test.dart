import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sona/features/auth/practice_config_screen.dart';
import 'package:sona/services/api_client.dart';

void main() {
  Future<_Harness> pumpScreen(
    WidgetTester tester, {
    String practiceName = 'Whitfield Speech & Language',
    List<String> specialties = const ['Paediatric'],
  }) async {
    tester.view.physicalSize = const Size(800, 1500);
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
      home: PracticeConfigScreen(
        apiClient: harness.api,
        practiceId: 'prac_1',
        onContinue: harness.onContinue,
        initialPracticeName: practiceName,
        initialSpecialties: specialties,
      ),
    ));
    await tester.pumpAndSettle();
    return harness;
  }

  testWidgets('renders the specialty options', (tester) async {
    await pumpScreen(tester);
    for (final option in PracticeConfigScreen.specialtyOptions) {
      expect(find.text(option), findsOneWidget);
    }
  });

  testWidgets('persists name, location and multi-selected specialties',
      (tester) async {
    final harness = await pumpScreen(tester);

    await tester.enterText(find.byType(TextField).at(1), 'Manchester, England');
    await tester.tap(find.text('Adult'));
    await tester.tap(find.text('Voice'));
    await tester.pump();

    await tester.tap(find.text('Continue to add clinicians'));
    await tester.pumpAndSettle();

    expect(harness.calls, 1);
    expect(harness.sentBody?['practiceName'], 'Whitfield Speech & Language');
    expect(harness.sentBody?['location'], 'Manchester, England');
    expect(
      (harness.sentBody?['specialties'] as List).cast<String>(),
      ['Paediatric', 'Adult', 'Voice'],
    );
    expect(harness.continued, isTrue);
  });

  testWidgets('deselecting removes a specialty', (tester) async {
    final harness = await pumpScreen(tester);

    await tester.tap(find.text('Paediatric')); // was selected → remove
    await tester.pump();
    await tester.tap(find.text('Continue to add clinicians'));
    await tester.pumpAndSettle();

    expect((harness.sentBody?['specialties'] as List), isEmpty);
  });

  testWidgets('requires a practice name', (tester) async {
    final harness = await pumpScreen(tester, practiceName: '');

    await tester.tap(find.text('Continue to add clinicians'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your practice name'), findsOneWidget);
    expect(harness.calls, 0);
  });
}

class _Harness {
  int calls = 0;
  bool continued = false;
  Map<String, dynamic>? sentBody;

  late final SonaApiClient api = SonaApiClient(client: MockClient((req) async {
    if (req.method == 'PATCH' && req.url.path == '/v1/practices/prac_1') {
      calls++;
      sentBody = jsonDecode(req.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({'practice': {'id': 'prac_1'}}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    return http.Response('{"error":"not_found"}', 404);
  }));

  void onContinue() => continued = true;
}
