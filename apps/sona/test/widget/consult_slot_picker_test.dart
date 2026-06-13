import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sona/design_system/sona_theme.dart';
import 'package:sona/features/clinician/consult_slot_picker.dart';
import 'package:sona/services/api_client.dart';

/// Stage · Consult slot picker + booking.
///
/// The picker lists available slots and reports the chosen start; booking the
/// chosen slot is the `POST /v1/cases/:id/consult` contract. A slot taken
/// between fetch and confirm comes back as 409 and must surface gracefully.

const _jsonHeaders = {'content-type': 'application/json'};

List<Map<String, dynamic>> _slots() => [
      {'start': '2026-06-16T09:00:00Z', 'available': true},
      {'start': '2026-06-16T09:20:00Z', 'available': false},
      {'start': '2026-06-18T14:00:00Z', 'available': true},
    ];

class _FakeBackend {
  _FakeBackend({this.bookStatus = 200});

  final int bookStatus;
  final requests = <http.Request>[];

  SonaApiClient client() => SonaApiClient(client: MockClient(_handle));

  http.Request? get lastBook => requests
      .where((r) => r.method == 'POST' && r.url.path.endsWith('/consult'))
      .toList()
      .lastOrNull;

  Future<http.Response> _handle(http.Request req) async {
    requests.add(req);
    if (req.url.path.endsWith('/consult') && req.method == 'POST') {
      if (bookStatus == 409) {
        return http.Response('{"error":"slot_taken"}', 409,
            headers: _jsonHeaders);
      }
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({'consultAt': body['start'], 'status': 'consult_booked'}),
        bookStatus,
        headers: _jsonHeaders,
      );
    }
    return http.Response('{"error":"not_found"}', 404);
  }
}

/// Stateful host that mirrors how the picker is used in production: it owns the
/// selected slot, then confirms by booking through the API client and reports
/// success / error inline.
class _PickerHost extends StatefulWidget {
  const _PickerHost({required this.api, required this.slots});

  final SonaApiClient api;
  final List<Map<String, dynamic>> slots;

  @override
  State<_PickerHost> createState() => _PickerHostState();
}

class _PickerHostState extends State<_PickerHost> {
  String? _selected;
  String? _status;

  Future<void> _confirm() async {
    if (_selected == null) return;
    try {
      await widget.api.bookConsult('case-1', start: _selected!);
      setState(() => _status = 'Consult booked');
    } on SonaApiException catch (e) {
      setState(() => _status = e.statusCode == 409
          ? 'That slot was just taken — pick another.'
          : 'Could not book the consult.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConsultSlotPicker(
          slots: widget.slots,
          selectedStart: _selected,
          onSelected: (s) => setState(() => _selected = s),
        ),
        FilledButton(
          onPressed: _selected == null ? null : _confirm,
          child: const Text('Confirm booking'),
        ),
        if (_status != null) Text(_status!),
      ],
    );
  }
}

Future<void> _pumpPicker(
  WidgetTester tester, {
  required List<Map<String, dynamic>> slots,
  String? selectedStart,
  required ValueChanged<String> onSelected,
  bool loading = false,
}) async {
  tester.view.physicalSize = const Size(900, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(MaterialApp(
    theme: sonaTheme(),
    home: Scaffold(
      body: ConsultSlotPicker(
        slots: slots,
        selectedStart: selectedStart,
        onSelected: onSelected,
        loading: loading,
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders only the available slots', (tester) async {
    await _pumpPicker(tester, slots: _slots(), onSelected: (_) {});

    // Two available slots → two list tiles; the unavailable one is filtered.
    expect(find.byType(ListTile), findsNWidgets(2));
  });

  testWidgets('loading shows a spinner instead of the list', (tester) async {
    // A spinner animates indefinitely, so pump once rather than settle.
    await tester.pumpWidget(MaterialApp(
      theme: sonaTheme(),
      home: Scaffold(
        body: ConsultSlotPicker(
          slots: const [],
          selectedStart: null,
          onSelected: (_) {},
          loading: true,
        ),
      ),
    ));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('no open slots shows the empty-state guidance', (tester) async {
    await _pumpPicker(
      tester,
      slots: const [
        {'start': '2026-06-16T09:00:00Z', 'available': false},
      ],
      onSelected: (_) {},
    );
    expect(find.textContaining('No open slots'), findsOneWidget);
  });

  testWidgets('tapping a slot reports the chosen start', (tester) async {
    String? chosen;
    await _pumpPicker(tester, slots: _slots(), onSelected: (s) => chosen = s);

    await tester.tap(find.byType(ListTile).first);
    await tester.pump();
    expect(chosen, '2026-06-16T09:00:00Z');
  });

  testWidgets('selected slot shows the tick affordance', (tester) async {
    await _pumpPicker(
      tester,
      slots: _slots(),
      selectedStart: '2026-06-18T14:00:00Z',
      onSelected: (_) {},
    );
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('select then confirm books the slot via the API', (tester) async {
    final fake = _FakeBackend();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: _PickerHost(api: fake.client(), slots: _slots())),
    ));
    await tester.pumpAndSettle();

    // Confirm is disabled until a slot is chosen.
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );

    await tester.tap(find.byType(ListTile).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm booking'));
    await tester.pumpAndSettle();

    expect(fake.lastBook, isNotNull);
    expect(jsonDecode(fake.lastBook!.body),
        containsPair('start', '2026-06-16T09:00:00Z'));
    expect(find.text('Consult booked'), findsOneWidget);
  });

  testWidgets('a 409 slot_taken is handled gracefully', (tester) async {
    final fake = _FakeBackend(bookStatus: 409);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: _PickerHost(api: fake.client(), slots: _slots())),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ListTile).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm booking'));
    await tester.pumpAndSettle();

    expect(find.textContaining('just taken'), findsOneWidget);
  });
}
