import 'package:apuntesuct_mobile/core/widgets/empty_state.dart';
import 'package:apuntesuct_mobile/core/widgets/loading_state.dart';
import 'package:apuntesuct_mobile/features/materials/data/mock_materials_repository.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_fixtures.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_summary.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/providers/materials_discovery_provider.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/screens/material_discovery_screen.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/widgets/material_summary_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildScreen({List<dynamic> overrides = const []}) {
    return ProviderScope(
      overrides: overrides.cast(),
      child: const MaterialApp(home: MaterialDiscoveryScreen()),
    );
  }

  group('MaterialDiscoveryScreen Widget Tests (#283)', () {
    testWidgets(
      'Muestra campo de búsqueda, filtros y carga materiales iniciales',
      (WidgetTester tester) async {
        await tester.pumpWidget(buildScreen());

        expect(find.byType(SearchBar), findsOneWidget);
        expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
        expect(find.byType(LoadingState), findsOneWidget);

        await tester.pumpAndSettle();
        expect(find.byType(MaterialSummaryCard), findsWidgets);
      },
    );

    testWidgets(
      'Cancelar debounce al limpiar no ejecuta la búsqueda descartada',
      (WidgetTester tester) async {
        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();

        // Escribir texto en el buscador
        await tester.enterText(find.byType(SearchBar), 'Cálculo');
        await tester.pump(const Duration(milliseconds: 100)); // Menos de 300ms

        // Presionar botón de limpiar (icono clear)
        expect(find.byIcon(Icons.clear), findsOneWidget);
        await tester.tap(find.byIcon(Icons.clear));
        await tester.pump();

        // Avanzar el tiempo más allá del debounce original
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();

        // El campo debe estar vacío y listando todos los iniciales
        expect(find.text('Cálculo'), findsNothing);
        expect(find.byType(MaterialSummaryCard), findsNWidgets(2));
      },
    );

    testWidgets(
      'Distingue entre catálogo global vacío y búsqueda sin coincidencias',
      (WidgetTester tester) async {
        // Caso 1: Catálogo totalmente vacío
        await tester.pumpWidget(
          buildScreen(
            overrides: [
              materialsRepositoryProvider.overrideWithValue(
                MockMaterialsRepository(
                  customDataset: [],
                  delay: Duration.zero,
                ),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(EmptyState), findsOneWidget);
        expect(find.text('Catálogo de materiales vacío'), findsOneWidget);

        // Caso 2: Catálogo con datos pero sin resultados para la búsqueda
        await tester.pumpWidget(
          buildScreen(
            overrides: [
              materialsRepositoryProvider.overrideWithValue(
                MockMaterialsRepository(
                  customDataset: MaterialFixtures.sampleSummaries,
                  delay: Duration.zero,
                ),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Búsqueda sin coincidencias
        await tester.enterText(find.byType(SearchBar), 'TextoInexistente123');
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();

        expect(find.byType(EmptyState), findsOneWidget);
        expect(find.text('Sin coincidencias'), findsOneWidget);
      },
    );

    test('Paginación acumulativa conserva elementos previos', () async {
      final dataset = List.generate(
        8,
        (i) => MaterialSummary(
          id: 'item-$i',
          title: 'Material Item $i',
          description: 'Desc',
          authorName: 'Autor $i',
          subjectName: 'Ramo',
          careerName: 'UCT',
          fileType: 'pdf',
          createdAt: DateTime(2026, 1, 1),
        ),
      );

      final container = ProviderContainer(
        overrides: [
          materialsRepositoryProvider.overrideWithValue(
            MockMaterialsRepository(
              customDataset: dataset,
              delay: Duration.zero,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(discoveryMaterialsProvider.notifier);
      await notifier.refresh();

      var state = container.read(discoveryMaterialsProvider);
      expect(state.items.length, 5);
      expect(state.hasMore, isTrue);

      await notifier.loadNextPage();
      state = container.read(discoveryMaterialsProvider);

      expect(state.items.length, 8);
      expect(state.hasMore, isFalse);
    });
  });
}
