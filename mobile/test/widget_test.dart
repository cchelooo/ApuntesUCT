// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:apuntesuct_mobile/main.dart';

void main() {
  testWidgets('Auth state Riverpod provider test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MyApp(),
      ),
    );

    expect(find.text('No autenticado'), findsOneWidget);
    expect(find.text('Autenticado'), findsNothing);

    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    expect(find.text('Autenticado'), findsOneWidget);
    expect(find.text('No autenticado'), findsNothing);
  });
}
