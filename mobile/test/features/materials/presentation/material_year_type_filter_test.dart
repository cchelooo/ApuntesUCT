import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:apuntesuct_mobile/features/catalog/presentation/providers/academic_hierarchy_provider.dart';
import 'package:apuntesuct_mobile/features/materials/data/dio_catalog_selector_repository.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_page.dart'
    as domain;
import 'package:apuntesuct_mobile/features/materials/domain/models/material_requests.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_summary.dart';
import 'package:apuntesuct_mobile/features/materials/domain/repositories/material_repository.dart';
import 'package:apuntesuct_mobile/features/materials/domain/repositories/search_repository.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/providers/materials_discovery_provider.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/screens/material_discovery_screen.dart';

class CapturingSearchRepository implements SearchRepository {
  final List<MaterialSearchQuery> capturedQueries = [];
  final List<int> capturedPages = [];
  List<MaterialSummary> nextResults = [];

  @override
  Future<domain.MaterialPage> search(
    MaterialSearchQuery query, {
    int page = 1,
    int pageSize = 10,
    dynamic cancelToken,
  }) async {
    capturedQueries.add(query);
    capturedPages.add(page);
    return domain.MaterialPage(
      items: nextResults,
      total: nextResults.length,
      page: page,
      pageSize: pageSize,
    );
  }
}

class FakeMaterialRepository implements MaterialRepository {
  List<MaterialSummary> nextList = [];

  @override
  Future<domain.MaterialPage> list({int page = 1, int pageSize = 10}) async {
    return domain.MaterialPage(
      items: nextList,
      total: nextList.length,
      page: page,
      pageSize: pageSize,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeCatalogSelectorRepository implements CatalogSelectorRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Issue #295: Integrar Año, Tipo y acción Limpiar filtros', () {
    late CapturingSearchRepository capturingSearchRepo;
    late FakeMaterialRepository fakeMaterialRepo;
    late DioMaterialsDiscoveryRepository discoveryRepo;

    setUp(() {
      capturingSearchRepo = CapturingSearchRepository();
      fakeMaterialRepo = FakeMaterialRepository();
      discoveryRepo = DioMaterialsDiscoveryRepository(
        searchRepo: capturingSearchRepo,
        materialRepo: fakeMaterialRepo,
        catalogRepo: FakeCatalogSelectorRepository() as dynamic,
      );
    });

    test('Criterio 1 & 4: Año y Tipo afectan resultados reales y coinciden con Swagger', () async {
      final sampleItem = const MaterialSummary(
        id: 'mat-2026-doc',
        title: 'Apunte Cálculo 2026',
        academicYear: 2026,
        materialType: 'DOCUMENT',
      );
      capturingSearchRepo.nextResults = [sampleItem];

      final container = ProviderContainer(
        overrides: [
          materialsRepositoryProvider.overrideWithValue(discoveryRepo),
        ],
      );
      addTearDown(container.dispose);

      // Inicia con carga sin filtros
      container.read(discoveryMaterialsProvider);
      await Future<void>.delayed(Duration.zero);

      // Aplica Año contractual (2026) y Tipo contractual (DOCUMENT)
      await container.read(discoveryMaterialsProvider.notifier).setYear(2026);
      await container.read(discoveryMaterialsProvider.notifier).setType('DOCUMENT');

      // Verifica que Search Service recibió año y tipo contractuales
      expect(capturingSearchRepo.capturedQueries, isNotEmpty);
      final lastQuery = capturingSearchRepo.capturedQueries.last;
      expect(lastQuery.year, 2026);
      expect(lastQuery.type, 'DOCUMENT');

      final state = container.read(discoveryMaterialsProvider);
      expect(state.items, hasLength(1));
      expect(state.items.first.id, 'mat-2026-doc');
      expect(state.items.first.academicYear, 2026);
      expect(state.items.first.materialType, 'DOCUMENT');
      expect(state.selectedYear, 2026);
      expect(state.selectedType, 'DOCUMENT');
    });

    test('Criterio 2: Se utilizan enums/valores del contrato, no textos inventados en Mobile', () {
      // Verifica que defaultTypes corresponde a los enums oficiales de Material Service / Swagger
      const expectedContractTypes = [
        'DOCUMENT',
        'PRESENTATION',
        'EXAM',
        'SUMMARY',
        'LINK',
      ];
      expect(
        AcademicHierarchyState.defaultTypes,
        equals(expectedContractTypes),
        reason: 'Los tipos por defecto deben coincidir con MaterialType de Swagger',
      );

      // Ningún texto inventado previo debe estar en la lista por defecto
      for (final invented in ['apunte', 'certamen', 'guia', 'prueba', 'examen']) {
        expect(
          AcademicHierarchyState.defaultTypes.contains(invented),
          isFalse,
          reason: '$invented es un texto inventado en Mobile y no pertenece al contrato',
        );
      }

      // Los años por defecto deben ser enteros válidos de 4 dígitos (1900-2099)
      for (final year in AcademicHierarchyState.defaultYears) {
        expect(year, inInclusiveRange(1900, 2099));
      }
    });

    test('Criterio 3: Limpiar filtros restablece estado, consulta y paginación', () async {
      final container = ProviderContainer(
        overrides: [
          materialsRepositoryProvider.overrideWithValue(discoveryRepo),
        ],
      );
      addTearDown(container.dispose);

      container.read(discoveryMaterialsProvider);
      await Future<void>.delayed(Duration.zero);

      // Establece consulta, año, tipo y simula avance de página
      await container.read(discoveryMaterialsProvider.notifier).setQuery('calculo');
      await container.read(discoveryMaterialsProvider.notifier).setYear(2025);
      await container.read(discoveryMaterialsProvider.notifier).setType('PRESENTATION');
      container.read(academicHierarchyProvider.notifier).selectYear(2025);
      container.read(academicHierarchyProvider.notifier).selectType('PRESENTATION');

      var state = container.read(discoveryMaterialsProvider);
      expect(state.query, 'calculo');
      expect(state.selectedYear, 2025);
      expect(state.selectedType, 'PRESENTATION');
      expect(state.isSearchActive, isTrue);

      // Ejecuta acción Limpiar filtros
      await container.read(discoveryMaterialsProvider.notifier).clearFilters();

      state = container.read(discoveryMaterialsProvider);
      expect(state.query, isEmpty, reason: 'Consulta debe quedar vacía');
      expect(state.selectedYear, isNull, reason: 'Año debe restablecerse');
      expect(state.selectedType, isNull, reason: 'Tipo debe restablecerse');
      expect(state.page, 1, reason: 'Paginación debe volver a página 1');
      expect(state.hasHierarchyFilters, isFalse);
      expect(
        container.read(academicHierarchyProvider).selection.isEmpty,
        isTrue,
        reason: 'Estado de selección académica debe limpiarse',
      );
    });

    testWidgets('Criterio 1, 3 & 4: Chips activos de Año y Tipo con borrado individual y Limpiar todo en UI', (
      WidgetTester tester,
    ) async {
      final item1 = const MaterialSummary(
        id: 'mat-1',
        title: 'Presentación Álgebra',
        academicYear: 2026,
        materialType: 'PRESENTATION',
      );
      fakeMaterialRepo.nextList = [item1];
      capturingSearchRepo.nextResults = [item1];

      final container = ProviderContainer(
        overrides: [
          materialsRepositoryProvider.overrideWithValue(discoveryRepo),
        ],
      );

      final router = GoRouter(
        initialLocation: '/materials',
        routes: [
          GoRoute(
            path: '/materials',
            builder: (context, state) => const MaterialDiscoveryScreen(),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Configura filtros de Año y Tipo
      await container.read(discoveryMaterialsProvider.notifier).setYear(2026);
      await container.read(discoveryMaterialsProvider.notifier).setType('PRESENTATION');
      await tester.pumpAndSettle();

      // Verifica chips visibles
      expect(find.byKey(const Key('active_chip_year')), findsOneWidget);
      expect(find.text('Año: 2026'), findsOneWidget);
      expect(find.byKey(const Key('active_chip_type')), findsOneWidget);
      expect(find.text('Tipo: PRESENTATION'), findsOneWidget);
      expect(find.byKey(const Key('clear_all_filters_button')), findsOneWidget);

      // Borrado individual del filtro Año
      await tester.tap(find.descendant(
        of: find.byKey(const Key('active_chip_year')),
        matching: find.byType(InkWell),
      ).last);
      await tester.pumpAndSettle();

      expect(container.read(discoveryMaterialsProvider).selectedYear, isNull);
      expect(find.byKey(const Key('active_chip_year')), findsNothing);
      expect(find.byKey(const Key('active_chip_type')), findsOneWidget);

      // Botón Limpiar todo
      await tester.tap(find.byKey(const Key('clear_all_filters_button')));
      await tester.pumpAndSettle();

      final state = container.read(discoveryMaterialsProvider);
      expect(state.selectedYear, isNull);
      expect(state.selectedType, isNull);
      expect(find.byKey(const Key('active_chip_type')), findsNothing);
      expect(find.byKey(const Key('clear_all_filters_button')), findsNothing);
    });

    testWidgets('Criterio 3: Estado sin resultados ofrece botón para limpiar filtros y búsqueda', (
      WidgetTester tester,
    ) async {
      capturingSearchRepo.nextResults = [];

      final container = ProviderContainer(
        overrides: [
          materialsRepositoryProvider.overrideWithValue(discoveryRepo),
        ],
      );

      final router = GoRouter(
        initialLocation: '/materials',
        routes: [
          GoRoute(
            path: '/materials',
            builder: (context, state) => const MaterialDiscoveryScreen(),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Aplica un filtro sin resultados
      await container.read(discoveryMaterialsProvider.notifier).setYear(2021);
      await container.read(discoveryMaterialsProvider.notifier).setType('EXAM');
      await tester.pumpAndSettle();

      expect(find.text('Sin coincidencias'), findsOneWidget);
      expect(find.byKey(const Key('empty_state_clear_button')), findsOneWidget);

      // Presionar Limpiar filtros y búsqueda restablece todo
      await tester.tap(find.byKey(const Key('empty_state_clear_button')));
      await tester.pumpAndSettle();

      final state = container.read(discoveryMaterialsProvider);
      expect(state.selectedYear, isNull);
      expect(state.selectedType, isNull);
      expect(state.page, 1);
    });
  });
}
