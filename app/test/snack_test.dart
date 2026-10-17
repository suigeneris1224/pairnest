import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pairnest/core/widgets/common.dart';

void main() {
  testWidgets('an Undo snack bar goes away on its own', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showSnack(context, 'Expense saved', actionLabel: 'Undo', onAction: () {}),
              child: const Text('Save'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Expense saved'), findsOneWidget);

    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Expense saved'), findsNothing);
  });
}
