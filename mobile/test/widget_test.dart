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

    // Initial state: not authenticated
    expect(find.text('No autenticado'), findsOneWidget);
    expect(find.text('Autenticado'), findsNothing);

    // Tap the toggle button to log in
    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    // Updated state: authenticated
    expect(find.text('Autenticado'), findsOneWidget);
    expect(find.text('No autenticado'), findsNothing);
  });
}
