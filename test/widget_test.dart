import 'package:flutter_test/flutter_test.dart';
import 'package:bloom/main.dart';

void main() {
  testWidgets('BLOOM app starts', (WidgetTester tester) async {
    await tester.pumpWidget(const BloomApp());

    expect(find.text('BLOOM'), findsOneWidget);
    expect(find.text('Create a Bloom'), findsOneWidget);
  });
}
