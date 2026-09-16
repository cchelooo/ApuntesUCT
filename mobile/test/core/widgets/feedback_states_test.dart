import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apuntesuct_mobile/core/widgets/empty_state.dart';
import 'package:apuntesuct_mobile/core/widgets/error_state.dart';
import 'package:apuntesuct_mobile/core/widgets/loading_state.dart';

void main() {
  group('Componentes de Estado UI (#55)', () {
    testWidgets('LoadingState renderiza CircularProgressIndicator y mensaje', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: LoadingState(message: 'Cargando apuntes...')),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Cargando apuntes...'), findsOneWidget);
    });

    testWidgets(
      'ErrorState muestra mensaje y dispara onRetry al presionar botón',
      (tester) async {
        bool reintentado = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ErrorState(
                message: 'Error de servidor 500',
                onRetry: () {
                  reintentado = true;
                },
              ),
            ),
          ),
        );

        expect(find.text('Ocurrió un problema'), findsOneWidget);
        expect(find.text('Error de servidor 500'), findsOneWidget);
        expect(find.byType(FilledButton), findsOneWidget);

        await tester.tap(find.byType(FilledButton));
        await tester.pump();

        expect(reintentado, isTrue);
      },
    );

    testWidgets('EmptyState muestra título y subtítulo personalizados', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyState(
              title: 'Sin resultados',
              subtitle: 'Prueba con otra materia',
            ),
          ),
        ),
      );

      expect(find.text('Sin resultados'), findsOneWidget);
      expect(find.text('Prueba con otra materia'), findsOneWidget);
      expect(find.byIcon(Icons.search_off_rounded), findsOneWidget);
    });
  });
}
