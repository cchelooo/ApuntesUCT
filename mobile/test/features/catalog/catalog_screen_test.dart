import 'dart:async';

import 'package:apuntesuct_mobile/core/widgets/empty_state.dart';
import 'package:apuntesuct_mobile/core/widgets/error_state.dart';
import 'package:apuntesuct_mobile/core/widgets/loading_state.dart';
import 'package:apuntesuct_mobile/features/catalog/domain/catalog_item.dart';
import 'package:apuntesuct_mobile/features/catalog/presentation/providers/catalog_provider.dart';
import 'package:apuntesuct_mobile/features/catalog/presentation/screens/catalog_screen.dart';
import 'package:apuntesuct_mobile/features/catalog/presentation/widgets/material_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  Widget buildTestWidget({List<dynamic> overrides = const []}) {
    final testRouter = GoRouter(
      initialLocation: '/catalog',
      routes: [
        GoRoute(
          path: '/catalog',
          builder: (context, state) => const CatalogScreen(),
        ),
      ],
    );

    return ProviderScope(
      overrides: overrides.cast(),
      child: MaterialApp.router(routerConfig: testRouter),
    );
  }

  group('CatalogScreen Estados Visuales (#67)', () {
    testWidgets('Muestra LoadingState mientras se cargan los datos de la API', (
      WidgetTester tester,
    ) async {
      final completer = Completer<List<CatalogItem>>();

      await tester.pumpWidget(
        buildTestWidget(
          overrides: [
            catalogListProvider.overrideWith((ref) => completer.future),
          ],
        ),
      );

      await tester.pump();

      expect(find.byType(LoadingState), findsOneWidget);
      expect(find.text('Cargando catálogo...'), findsOneWidget);

      completer.complete([]);
      await tester.pumpAndSettle();
    });

    testWidgets(
      'Muestra ErrorState ante fallo en la petición y permite reintentar',
      (WidgetTester tester) async {
        int fetchCalls = 0;

        await tester.pumpWidget(
          buildTestWidget(
            overrides: [
              catalogListProvider.overrideWith((ref) async {
                fetchCalls++;
                throw Exception('Fallo de conexión HTTP');
              }),
            ],
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byType(ErrorState), findsOneWidget);
        expect(
          find.text(
            'Error al cargar el catálogo. Por favor intenta nuevamente.',
          ),
          findsOneWidget,
        );
        expect(find.text('Reintentar'), findsOneWidget);

        // Probar que el botón Reintentar invalida y vuelve a solicitar
        await tester.tap(find.text('Reintentar'));
        await tester.pumpAndSettle();

        expect(fetchCalls, greaterThanOrEqualTo(2));
      },
    );

    testWidgets(
      'Muestra EmptyState cuando la lista de materiales viene vacía',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            overrides: [catalogListProvider.overrideWith((ref) async => [])],
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byType(EmptyState), findsOneWidget);
        expect(find.text('No se encontraron materiales'), findsOneWidget);
        expect(
          find.text('Prueba buscando con otro término o revisa la ortografía.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('Muestra MaterialCard cuando se reciben resultados exitosos', (
      WidgetTester tester,
    ) async {
      final mockItems = [
        const CatalogItem(
          id: 'sub-1',
          title: 'Estructuras de Datos',
          author: 'Universidad Católica de Temuco',
          subject: 'Ingeniería Civil Informática',
        ),
        const CatalogItem(
          id: 'sub-2',
          title: 'Cálculo I',
          author: 'Universidad Católica de Temuco',
          subject: 'Ingeniería Civil Informática',
        ),
      ];

      await tester.pumpWidget(
        buildTestWidget(
          overrides: [
            catalogListProvider.overrideWith((ref) async => mockItems),
          ],
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(MaterialCard), findsNWidgets(2));
      expect(find.text('Estructuras de Datos'), findsOneWidget);
      expect(find.text('Cálculo I'), findsOneWidget);
    });
    testWidgets(
      'Pull-to-refresh fallido transiciona de datos a ErrorState sin lanzar excepcion no controlada',
      (WidgetTester tester) async {
        bool failNext = false;

        await tester.pumpWidget(
          buildTestWidget(
            overrides: [
              catalogListProvider.overrideWith((ref) async {
                if (failNext) {
                  throw Exception('Error en recarga');
                }
                return [
                  const CatalogItem(
                    id: '1',
                    title: 'Cálculo I',
                    author: 'UCT',
                    subject: 'Informática',
                  ),
                ];
              }),
            ],
          ),
        );

        await tester.pumpAndSettle();

        // Verifica estado inicial con datos
        expect(find.text('Cálculo I'), findsOneWidget);

        // Simula que la próxima petición fallará
        failNext = true;

        // Dispara el gesto de pull-to-refresh
        await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
        await tester.pumpAndSettle();

        // Debe mostrar ErrorState sin romper la ejecución
        expect(find.byType(ErrorState), findsOneWidget);
        expect(
          find.text(
            'Error al cargar el catálogo. Por favor intenta nuevamente.',
          ),
          findsOneWidget,
        );
      },
    );
  });
}
