import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sona/features/feedback/feedback_overlay.dart';
import 'package:sona/features/feedback/feedback_page_context.dart';
import 'package:sona/services/api_client.dart';

void main() {
  Widget host({
    required bool enabled,
    SonaApiClient? api,
    FeedbackContextController? controller,
  }) {
    return MaterialApp(
      home: FeedbackOverlay(
        enabled: enabled,
        apiClient: api,
        contextController: controller,
        child: const Scaffold(body: Center(child: Text('app body'))),
      ),
    );
  }

  testWidgets('is invisible when disabled', (tester) async {
    await tester.pumpWidget(host(enabled: false));
    expect(find.byKey(const Key('feedback-fab')), findsNothing);
    expect(find.text('app body'), findsOneWidget);
  });

  testWidgets('shows the button when enabled', (tester) async {
    await tester.pumpWidget(host(enabled: true));
    expect(find.byKey(const Key('feedback-fab')), findsOneWidget);
  });

  testWidgets('opening, typing and sending posts PHI-safe context', (
    tester,
  ) async {
    http.Request? sent;
    final api = SonaApiClient(
      client: MockClient((req) async {
        sent = req;
        return http.Response('{"id":"fb-1"}', 201);
      }),
    );
    final controller = FeedbackContextController()
      ..set(
        const FeedbackPageContext(
          routeName: 'clinicianTriage',
          role: 'clinician',
          journeyStage: 'triage',
        ),
      );

    await tester.pumpWidget(
      host(enabled: true, api: api, controller: controller),
    );

    await tester.tap(find.byKey(const Key('feedback-fab')));
    await tester.pumpAndSettle();

    // Panel is open with the comment field.
    expect(find.byKey(const Key('feedback-comment')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('feedback-comment')),
      'Triage button did nothing',
    );
    await tester.tap(find.byKey(const Key('feedback-send')));
    await tester.pumpAndSettle();

    expect(sent, isNotNull);
    expect(sent!.url.path, '/v1/feedback');
    final body = jsonDecode(sent!.body) as Map<String, dynamic>;
    expect(body['type'], 'bug');
    expect(body['comment'], 'Triage button did nothing');
    expect(body['route'], 'clinicianTriage');
    expect(body['journeyStage'], 'triage');
    // PHI-safe: no identifying fields are ever sent.
    for (final key in body.keys) {
      expect(
        RegExp(
          r'name|email|dob|child|parent|token|answers',
          caseSensitive: false,
        ).hasMatch(key),
        isFalse,
        reason: 'feedback payload key "$key" looks PHI-shaped',
      );
    }
  });

  testWidgets('blocks sending an empty comment', (tester) async {
    http.Request? sent;
    final api = SonaApiClient(
      client: MockClient((req) async {
        sent = req;
        return http.Response('{"id":"x"}', 201);
      }),
    );

    await tester.pumpWidget(host(enabled: true, api: api));
    await tester.tap(find.byKey(const Key('feedback-fab')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('feedback-send')));
    await tester.pumpAndSettle();

    // No request sent; the panel stays open with a validation message.
    expect(sent, isNull);
    expect(find.text('Please add a comment.'), findsOneWidget);
  });
}
