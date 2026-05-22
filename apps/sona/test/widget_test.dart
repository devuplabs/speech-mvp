import 'package:flutter_test/flutter_test.dart';
import 'package:sona/main.dart';

void main() {
  testWidgets('Sona launcher renders the entry CTAs', (WidgetTester tester) async {
    await tester.pumpWidget(const SonaApp());
    await tester.pumpAndSettle();
    expect(find.text('Speech Therapy MVP'), findsOneWidget);
    expect(find.text('Parent intake (mobile)'), findsOneWidget);
    expect(find.text('Clinician workspace (desktop)'), findsOneWidget);
  });
}
