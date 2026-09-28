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

  group('CatalogScreen Pulido UI Tests (#82)', () {
    testWidgets('Muestra LoadingState mientras se cargan los datos', (
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

        await tester.tap(find.text('Reintentar'));
        await tester.pumpAndSettle();

        expect(fetchCalls, greaterThanOrEqualTo(2));
      },
    );

    testWidgets(
      'Muestra EmptyState estándar cuando el catálogo general está vacío',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            overrides: [catalogListProvider.overrideWith((ref) async => [])],
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byType(EmptyState), findsOneWidget);
        expect(find.text('No se encontraron materiales'), findsOneWidget);
      },
    );

    testWidgets(
      'Muestra EmptyState adaptado cuando no hay coincidencias con búsqueda',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            overrides: [
              catalogSearchQueryProvider.overrideWith(
                () => _MockQueryNotifier('Química'),
              ),
              catalogListProvider.overrideWith((ref) async => []),
            ],
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byType(EmptyState), findsOneWidget);
        expect(find.text('Sin resultados para "Química"'), findsOneWidget);
      },
    );

    testWidgets(
      'Muestra contador de resultados y MaterialCards con datos recibidos',
      (WidgetTester tester) async {
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

        expect(find.text('2 resultados encontrados'), findsOneWidget);
        expect(find.byType(MaterialCard), findsNWidgets(2));
        expect(find.text('Estructuras de Datos'), findsOneWidget);
        expect(find.text('Cálculo I'), findsOneWidget);
      },
    );

    testWidgets(
      'Pull-to-refresh fallido transiciona de datos a ErrorState sin excepción',
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

        expect(find.text('Cálculo I'), findsOneWidget);

        failNext = true;

        await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
        await tester.pumpAndSettle();

        expect(find.byType(ErrorState), findsOneWidget);
      },
    );
  });
}

class _MockQueryNotifier extends CatalogSearchQueryNotifier {
  final String initialQuery;
  _MockQueryNotifier(this.initialQuery);

  @override
  String build() => initialQuery;
}
