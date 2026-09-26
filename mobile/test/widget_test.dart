import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:apuntesuct_mobile/main.dart';

import 'helpers/test_harness.dart';

void main() {
  testWidgets('muestra el flujo de autenticación de la maqueta', (
    WidgetTester tester,
  ) async {
    appRouter.go('/login');
    addTearDown(() => appRouter.go('/login'));

    await pumpAppUnderTest(tester, app: const ProviderScope(child: MyApp()));

    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('Correo institucional'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));

    final titleRect = tester.getRect(find.text('Iniciar sesión'));
    final buttonRect = tester.getRect(find.byType(FilledButton));

    await tester.tap(find.byTooltip('Cambiar a modo oscuro'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 210));

    // Sólo se anima el acento del fondo; el formulario no debe desplazarse.
    expect(tester.getRect(find.text('Iniciar sesión')), titleRect);
    expect(tester.getRect(find.byType(FilledButton)), buttonRect);

    await tester.pumpAndSettle();
    expect(find.text('Iniciar sesión'), findsOneWidget);

    await tester.ensureVisible(find.byType(TextButton));
    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();

    expect(find.text('Crear cuenta'), findsNWidgets(2));
    expect(find.text('Repetir contraseña'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(4));

    tester.view.physicalSize = const Size(844, 390);
    await tester.pumpAndSettle();
    expect(find.text('Crear cuenta'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
