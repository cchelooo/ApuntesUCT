import 'package:apuntesuct_mobile/core/widgets/empty_state.dart';
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

  group('CatalogScreen Provider Integration Tests (#66)', () {
    testWidgets('CatalogScreen consume catalogListProvider y renderiza items', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(
          overrides: [
            catalogListProvider.overrideWith(
              (ref) async => [
                const CatalogItem(
                  id: '1',
                  title: 'Cálculo I',
                  author: 'UCT',
                  subject: 'Informática',
                ),
              ],
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(SearchBar), findsOneWidget);
      expect(find.byType(MaterialCard), findsOneWidget);
      expect(find.text('Cálculo I'), findsOneWidget);
    });

    testWidgets('Muestra EmptyState cuando no hay resultados en el provider', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(
          overrides: [catalogListProvider.overrideWith((ref) async => [])],
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('No se encontraron materiales'), findsOneWidget);
    });
  });
}
