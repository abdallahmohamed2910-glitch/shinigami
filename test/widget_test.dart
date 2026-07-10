import 'package:flutter_test/flutter_test.dart';
import 'package:shinigami/main.dart';

void main() {
  testWidgets('Smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ShinigamiApp());
  });
}
