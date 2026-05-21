import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sona/design_system/widgets/sona_text_field.dart';

/// Guards the parent-intake fix where SonaTextField switched from relying on
/// TextField.onChanged to listening on its TextEditingController. Programmatic
/// edits (browser autofill, Flutter web's shared hidden <input>, drive-driven
/// integration tests) must trigger the parent's onChanged so IntakeFormData
/// stays in sync with what the user sees on screen.
void main() {
  testWidgets('SonaTextField forwards user keystrokes to onChanged', (tester) async {
    String latest = '';
    int callCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SonaTextField(
            label: 'Email',
            value: '',
            onChanged: (v) {
              latest = v;
              callCount++;
            },
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'parent@example.com');
    await tester.pump();
    expect(latest, 'parent@example.com');
    expect(callCount, greaterThanOrEqualTo(1));
  });

  testWidgets(
    'SonaTextField propagates programmatic controller writes (race-fix coverage)',
    (tester) async {
      String latest = '';
      int callCount = 0;
      final fieldKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SonaTextField(
              key: fieldKey,
              label: 'GP phone',
              value: '',
              onChanged: (v) {
                latest = v;
                callCount++;
              },
            ),
          ),
        ),
      );

      // Reach into the live TextField and write to its controller, mimicking
      // Flutter web's shared-hidden-input pathway / browser autofill that used
      // to bypass TextField.onChanged.
      final fieldState = tester.state(find.byType(TextField));
      // ignore: invalid_use_of_protected_member
      final controller = (fieldState.widget as TextField).controller!;
      controller.text = '02070000000';
      await tester.pump();

      expect(latest, '02070000000',
          reason: 'controller listener must forward programmatic writes to onChanged');
      expect(callCount, 1);
    },
  );

  testWidgets(
    'SonaTextField does not loop on parent-driven value updates',
    (tester) async {
      int callCount = 0;
      String currentValue = 'a';
      late StateSetter rebuild;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(builder: (context, setState) {
              rebuild = setState;
              return SonaTextField(
                label: 'Field',
                value: currentValue,
                onChanged: (_) => callCount++,
              );
            }),
          ),
        ),
      );
      // Flush initial frame.
      await tester.pump();
      expect(callCount, 0);

      // Parent-driven update (e.g. draft restore) must NOT call onChanged.
      rebuild(() => currentValue = 'restored');
      await tester.pump();
      expect(callCount, 0,
          reason: 'didUpdateWidget must suppress the listener when syncing widget.value');
    },
  );
}
