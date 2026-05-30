import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sona/design_system/sona_theme.dart';
import 'package:sona/design_system/widgets/sona_text_field.dart';
import 'package:sona/features/parent/intake/parent_intake_step_screen.dart';
import 'package:sona/state/sona_app_state.dart';

/// Regression for BUG-001: typed text must survive difficulty-checkbox toggles
/// and parent rebuilds that pass a stale empty [SonaTextField.value].
void main() {
  testWidgets('main concern text persists after difficulty checkbox toggle', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = SonaAppState()..formStep = 2;

    await tester.pumpWidget(
      MaterialApp(
        theme: sonaTheme(),
        home: ParentIntakeStepScreen(
          state: state,
          onBack: () {},
          onContinue: () async {},
          onSaveExit: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final concernField = find.widgetWithText(SonaTextField, 'Main concern *');
    expect(concernField, findsOneWidget);

    await tester.enterText(
      find.descendant(of: concernField, matching: find.byType(TextField)),
      'Test concern xyz',
    );
    await tester.pump();
    expect(state.intake.mainConcern, 'Test concern xyz');

    await tester.tap(find.byKey(const ValueKey('Speech sounds')));
    await tester.pumpAndSettle();

    expect(state.intake.mainConcern, 'Test concern xyz');
    expect(find.text('Test concern xyz'), findsOneWidget);
    expect(state.intake.difficulties, contains('Speech sounds'));
  });

  testWidgets('SonaTextField keeps controller text when parent passes stale empty value',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: _StaleValueHost(),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Typed before rebuild');
    await tester.pump();

    await tester.tap(find.text('Rebuild with stale empty'));
    await tester.pump();

    expect(find.text('Typed before rebuild'), findsOneWidget);
  });
}

/// Simulates a parent that rebuilds with `value: ''` while the controller still
/// holds user input (web IME / checkbox-triggered setState race).
class _StaleValueHost extends StatefulWidget {
  @override
  State<_StaleValueHost> createState() => _StaleValueHostState();
}

class _StaleValueHostState extends State<_StaleValueHost> {
  String _model = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          SonaTextField(
            label: 'Main concern',
            value: _model,
            onChanged: (v) => _model = v,
          ),
          TextButton(
            onPressed: () => setState(() {}),
            child: const Text('Rebuild with stale empty'),
          ),
        ],
      ),
    );
  }
}
