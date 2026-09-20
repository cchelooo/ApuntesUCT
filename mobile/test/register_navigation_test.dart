import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:apuntesuct_mobile/features/auth/data/mock_auth_repository.dart';
import 'package:apuntesuct_mobile/main.dart';

void main() {
  testWidgets('registro exitoso con sesión navega al Home', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() {
      tester.binding.setSurfaceSize(null);
      appRouter.go('/login');
    });

    appRouter.go('/login');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWith(
            (ref) => const MockAuthRepository(simulatedDelay: Duration.zero),
          ),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Parte del login y va al registro.
    await tester.ensureVisible(find.byType(TextButton));
    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();
    expect(find.text('Crear cuenta'), findsNWidgets(2));

    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(4));

    await tester.enterText(fields.at(0), 'Camila Soto');
    await tester.enterText(fields.at(1), 'csoto2020');
    await tester.enterText(fields.at(2), 'Password1');
    await tester.enterText(fields.at(3), 'Password1');
    await tester.pump();

    await tester.tap(find.text('Crear cuenta').last);
    await tester.pumpAndSettle();

    // Con sesión abierta, la app navega al Home y muestra el estado.
    expect(find.text('Estado de autenticación:'), findsOneWidget);
    expect(find.text('Autenticado'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
