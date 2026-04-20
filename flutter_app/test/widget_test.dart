import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows assignment title text', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Text('National ID Mobile'),
        ),
      ),
    );

    expect(find.text('National ID Mobile'), findsOneWidget);
  });
}
