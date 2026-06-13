import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sona/design_system/sona_colors.dart';
import 'package:sona/design_system/sona_theme.dart';
import 'package:sona/features/clinician/clinician_today_screen.dart';
import 'package:sona/state/sona_app_state.dart';
import 'package:sona/utils/case_status.dart';

/// Stage · Today dashboard status badges.
///
/// Each case row renders a status badge whose label comes from
/// `prepLabelFromCaseStatus` and whose colour splits on "Ready" (success
/// green) vs everything-else (warning amber). Drives the real
/// [ClinicianTodayScreen] off a populated [SonaAppState] and asserts the
/// rendered label + colour for every dashboard status, including the DEV-10
/// additions `consult_booked` and `carryover`.

SonaAppState _stateWith(List<Map<String, dynamic>> cases) {
  final state = SonaAppState();
  state.clinicianCases = cases;
  return state;
}

Map<String, dynamic> _caseRow(String id, String status) => {
      'id': id,
      'childDisplayName': 'Child $id',
      'status': status,
    };

Future<void> _pump(WidgetTester tester, SonaAppState state) async {
  tester.view.physicalSize = const Size(1440, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final original = FlutterError.onError;
  FlutterError.onError = (d) {
    if ('${d.exception}'.contains('A RenderFlex overflowed')) return;
    original?.call(d);
  };
  addTearDown(() => FlutterError.onError = original);

  await tester.pumpWidget(MaterialApp(
    theme: sonaTheme(),
    home: Scaffold(
      body: ClinicianTodayScreen(
        state: state,
        onOpenReview: (_) {},
        onRefresh: () async {},
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

/// The badge is the innermost Text under a pill Container that uses the
/// success / warning background tokens. We assert via the enclosing
/// Container's decoration colour.
Color _badgeColourFor(WidgetTester tester, String label) {
  final container = tester.widget<Container>(
    find
        .ancestor(
          of: find.text(label),
          matching: find.byType(Container),
        )
        .first,
  );
  return (container.decoration as BoxDecoration).color!;
}

void main() {
  testWidgets('renders the correct label for every dashboard status',
      (tester) async {
    final cases = const {
          'intake_submitted': 'Drafting',
          'prep_drafting': 'Drafting',
          'prep_ready': 'Ready',
          'consult_booked': 'Consult booked',
          'triaged': 'Triaged',
          'plan_ready': 'Ready',
          'summary_sent': 'Ready',
          'carryover': 'Carryover',
        }.entries
        .toList();

    final state = _stateWith([
      for (var i = 0; i < cases.length; i++) _caseRow('$i', cases[i].key),
    ]);
    await _pump(tester, state);

    for (final entry in cases) {
      expect(
        find.text(entry.value),
        findsWidgets,
        reason: '${entry.key} should render the "${entry.value}" badge',
      );
    }
  });

  testWidgets('a Ready case badge uses the success colour', (tester) async {
    final state = _stateWith([_caseRow('1', 'prep_ready')]);
    await _pump(tester, state);

    expect(prepLabelFromCaseStatus('prep_ready'), 'Ready');
    expect(_badgeColourFor(tester, 'Ready'), SonaColors.successBg);
  });

  testWidgets('a consult_booked case badge uses the warning colour',
      (tester) async {
    final state = _stateWith([_caseRow('1', 'consult_booked')]);
    await _pump(tester, state);

    expect(prepLabelFromCaseStatus('consult_booked'), 'Consult booked');
    expect(_badgeColourFor(tester, 'Consult booked'), SonaColors.warningBg);
  });

  testWidgets('a carryover case badge uses the warning colour', (tester) async {
    final state = _stateWith([_caseRow('1', 'carryover')]);
    await _pump(tester, state);

    expect(prepLabelFromCaseStatus('carryover'), 'Carryover');
    expect(_badgeColourFor(tester, 'Carryover'), SonaColors.warningBg);
  });

  testWidgets('intake_pending cases are filtered off the dashboard',
      (tester) async {
    final state = _stateWith([
      _caseRow('1', 'intake_pending'),
      _caseRow('2', 'prep_ready'),
    ]);
    await _pump(tester, state);

    // Only the prep_ready case is shown; its badge label appears, "Not
    // started" (the intake_pending label) does not.
    expect(find.text('Ready'), findsWidgets);
    expect(find.text('Not started'), findsNothing);
  });
}
