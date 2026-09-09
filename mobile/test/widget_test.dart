import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:apuntesuct_mobile/main.dart';

void main() {
  testWidgets('muestra el flujo de autenticación de la maqueta', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    await tester.pumpAndSettle();

    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('Correo institucional'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));

    await tester.tap(find.byTooltip('Cambiar a modo oscuro'));
    await tester.pumpAndSettle();
    expect(find.text('Iniciar\nsesión'), findsOneWidget);

    await tester.ensureVisible(find.byType(TextButton));
    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();

    expect(find.text('Crear cuenta'), findsNWidgets(2));
    expect(find.text('REPETIR CONTRASEÑA'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(4));
  });
}
