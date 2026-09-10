import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';

void main() {
  testWidgets('NEXA app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const NexaApp());

    expect(find.text('NEXA'), findsWidgets);
  });
}