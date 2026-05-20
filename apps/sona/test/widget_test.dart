import 'package:flutter_test/flutter_test.dart';
import 'package:sona/main.dart';

void main() {
  testWidgets('Sona home screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(const SonaApp());
    expect(find.text('Sona'), findsOneWidget);
    expect(find.textContaining('localhost:8080'), findsOneWidget);
  });
}
