import 'package:apuntesuct_mobile/core/widgets/empty_state.dart';
import 'package:apuntesuct_mobile/core/widgets/loading_state.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_fixtures.dart';
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
      'Muestra campo de búsqueda, botón de filtros y loading inicial',
      (WidgetTester tester) async {
        await tester.pumpWidget(buildScreen());

        expect(find.byType(SearchBar), findsOneWidget);
        expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
        expect(find.byType(LoadingState), findsOneWidget);

        await tester.pumpAndSettle();
        expect(find.byType(MaterialSummaryCard), findsWidgets);
      },
    );

    testWidgets('Renderiza lista de materiales simulados correctamente', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildScreen(
          overrides: [
            paginatedMaterialsProvider.overrideWith(
              (ref) async => MaterialFixtures.sampleSummaries,
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(MaterialSummaryCard), findsNWidgets(2));
      expect(
        find.text('Resumen Certamen 1 - Estructuras de Datos'),
        findsOneWidget,
      );
      expect(
        find.text('Guía de Ejercicios Resueltos - Cálculo I'),
        findsOneWidget,
      );
    });

    testWidgets('Muestra EmptyState cuando la lista de resultados está vacía', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildScreen(
          overrides: [
            paginatedMaterialsProvider.overrideWith((ref) async => []),
          ],
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('No se encontraron materiales'), findsOneWidget);
    });
  });
}
