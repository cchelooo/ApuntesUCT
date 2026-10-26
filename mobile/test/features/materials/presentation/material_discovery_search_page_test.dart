import 'package:apuntesuct_mobile/core/widgets/empty_state.dart';
import 'package:apuntesuct_mobile/core/widgets/error_state.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_detail.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_summary.dart';
import 'package:apuntesuct_mobile/features/materials/domain/repositories/materials_repository.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/providers/materials_discovery_provider.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/screens/material_discovery_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class MockSearchMaterialsRepository implements MaterialsRepository {
  final List<MaterialSummary> Function({
    String? query,
    String? subject,
    int page,
    int pageSize,
  })
  onGetMaterials;

  MockSearchMaterialsRepository({required this.onGetMaterials});

  @override
  Future<List<MaterialSummary>> getMaterials({
    String? query,
    String? subject,
    int page = 1,
    int pageSize = 10,
  }) async {
    return onGetMaterials(
      query: query,
      subject: subject,
      page: page,
      pageSize: pageSize,
    );
  }

  @override
  Future<List<String>> getAvailableSubjects() async => [
    'Cálculo I',
    'Álgebra Lineal',
  ];

  @override
  Future<MaterialDetail> getMaterialDetail(String id) async =>
      throw UnimplementedError();
}

void main() {
  Widget buildScreen(MaterialsRepository repository) {
    return ProviderScope(
      overrides: [materialsRepositoryProvider.overrideWithValue(repository)],
      child: const MaterialApp(home: MaterialDiscoveryScreen()),
    );
  }

  group('Issue #296: Búsqueda por texto y resultados paginados', () {
    testWidgets(
      'Criterio 1: La búsqueda aplica debounce de 300 ms antes de consultar',
      (WidgetTester tester) async {
        int callCount = 0;
        String? lastQuery;

        final repo = MockSearchMaterialsRepository(
          onGetMaterials: ({page = 1, pageSize = 10, query, subject}) {
            callCount++;
            lastQuery = query;
            return [
              const MaterialSummary(id: 'mat-1', title: 'Certamen Álgebra'),
            ];
          },
        );

        await tester.pumpWidget(buildScreen(repo));
        await tester.pumpAndSettle();

        expect(callCount, 1); // Carga inicial sin query

        // Escribimos en el buscador
        await tester.enterText(find.byType(SearchBar), 'Álgebra');
        await tester.pump(const Duration(milliseconds: 150));

        // A los 150 ms el debounce sigue activo y no debe haber llamado al repo
        expect(callCount, 1);

        // Pasados los 300 ms del debounce se dispara la búsqueda
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();

        expect(callCount, 2);
        expect(lastQuery, 'Álgebra');
      },
    );

    testWidgets(
      'Criterio 2: Cargar más no duplica materiales aunque la nueva página traiga repetidos internos y previos',
      (WidgetTester tester) async {
        final repo = MockSearchMaterialsRepository(
          onGetMaterials: ({page = 1, pageSize = 10, query, subject}) {
            if (page == 1) {
              return [
                const MaterialSummary(id: 'mat-1', title: 'Material 1'),
                const MaterialSummary(id: 'mat-2', title: 'Material 2'),
                const MaterialSummary(id: 'mat-3', title: 'Material 3'),
                const MaterialSummary(id: 'mat-4', title: 'Material 4'),
                const MaterialSummary(id: 'mat-5', title: 'Material 5'),
              ];
            }
            // Página 2 contiene 'mat-5' (repetido de página 1) y 'mat-6' dos veces (repetido interno)
            return [
              const MaterialSummary(
                id: 'mat-5',
                title: 'Material 5 (Duplicado previo)',
              ),
              const MaterialSummary(id: 'mat-6', title: 'Material 6'),
              const MaterialSummary(
                id: 'mat-6',
                title: 'Material 6 (Duplicado interno)',
              ),
            ];
          },
        );

        await tester.pumpWidget(buildScreen(repo));
        await tester.pumpAndSettle();

        final element = tester.element(find.byType(MaterialDiscoveryScreen));
        final container = ProviderScope.containerOf(element);

        expect(container.read(discoveryMaterialsProvider).items.length, 5);

        // Cargamos la siguiente página
        await container
            .read(discoveryMaterialsProvider.notifier)
            .loadNextPage();
        await tester.pumpAndSettle();

        final state = container.read(discoveryMaterialsProvider);
        // Debe contener exactamente 6 materiales únicos (mat-1 a mat-6), sin 7 u 8
        expect(state.items.length, 6);
        expect(state.items.map((m) => m.id).toList(), [
          'mat-1',
          'mat-2',
          'mat-3',
          'mat-4',
          'mat-5',
          'mat-6',
        ]);
      },
    );
    testWidgets(
      'Criterio 3: Pull-to-refresh representa un fallo como ErrorState sin lanzar excepción no controlada',
      (WidgetTester tester) async {
        bool shouldFail = false;

        final repo = MockSearchMaterialsRepository(
          onGetMaterials: ({page = 1, pageSize = 10, query, subject}) {
            if (shouldFail) {
              throw Exception('Fallo de conexión con Gateway');
            }
            return [
              const MaterialSummary(id: 'mat-1', title: 'Material Inicial'),
            ];
          },
        );

        await tester.pumpWidget(buildScreen(repo));
        await tester.pumpAndSettle();

        expect(find.text('Material Inicial'), findsOneWidget);
        expect(find.byType(ErrorState), findsNothing);

        // Simulamos fallo en el refresco
        shouldFail = true;

        // Ejecutamos pull-to-refresh
        await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
        await tester.pump();
        await tester.pumpAndSettle();

        // No hay excepción no controlada y se muestra ErrorState
        expect(tester.takeException(), isNull);
        expect(find.byType(ErrorState), findsOneWidget);
        expect(
          find.text(
            'Error al cargar materiales disponibles. Verifica tu conexión.',
          ),
          findsOneWidget,
        );
        expect(find.text('Reintentar'), findsOneWidget);
      },
    );

    testWidgets(
      'Criterio 4: Estado sin resultados incluye texto buscado y botón para limpiarlo',
      (WidgetTester tester) async {
        final repo = MockSearchMaterialsRepository(
          onGetMaterials: ({page = 1, pageSize = 10, query, subject}) {
            if (query != null && query.isNotEmpty) {
              return []; // Sin coincidencias
            }
            return [
              const MaterialSummary(id: 'mat-1', title: 'Material Inicial'),
            ];
          },
        );

        await tester.pumpWidget(buildScreen(repo));
        await tester.pumpAndSettle();

        expect(find.text('Material Inicial'), findsOneWidget);

        // Buscamos un término inexistente
        await tester.enterText(find.byType(SearchBar), 'Química Cuántica');
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();

        // Verifica que se muestre el texto de búsqueda dentro del EmptyState
        expect(find.byType(EmptyState), findsOneWidget);
        expect(find.text('Sin coincidencias'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(EmptyState),
            matching: find.textContaining('Química Cuántica'),
          ),
          findsOneWidget,
        );

        // Debe existir el botón para limpiar la búsqueda y filtros
        expect(find.text('Limpiar filtros y búsqueda'), findsOneWidget);

        // Al presionar el botón de limpiar, el campo se vacía y se recupera el listado
        await tester.tap(find.text('Limpiar filtros y búsqueda'));
        await tester.pumpAndSettle();

        expect(find.byType(EmptyState), findsNothing);
        expect(find.text('Material Inicial'), findsOneWidget);
      },
    );
  });
}
