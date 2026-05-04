import 'package:flutter_test/flutter_test.dart';
import 'package:gratify/main.dart';

void main() {
  testWidgets('App renders home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const GratifyApp());
    expect(find.text('Gratify'), findsOneWidget);
  });
}
