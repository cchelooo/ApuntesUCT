import 'package:apuntesuct_mobile/core/widgets/empty_state.dart';
import 'package:apuntesuct_mobile/features/catalog/presentation/screens/catalog_screen.dart';
import 'package:apuntesuct_mobile/features/catalog/presentation/widgets/material_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('CatalogScreen Router Tests', () {
    testWidgets(
      'CatalogScreen se muestra al navegar a /catalog mediante GoRouter',
      (WidgetTester tester) async {
        final testRouter = GoRouter(
          initialLocation: '/catalog',
          routes: [
            GoRoute(
              path: '/catalog',
              builder: (context, state) => const CatalogScreen(),
            ),
          ],
        );

        await tester.pumpWidget(MaterialApp.router(routerConfig: testRouter));
        await tester.pumpAndSettle();

        expect(find.byType(SearchBar), findsOneWidget);
        expect(find.byType(MaterialCard), findsWidgets);
        expect(find.text('Catálogo de Materiales'), findsOneWidget);

        await tester.enterText(find.byType(SearchBar), 'Cálculo');
        await tester.pump();

        expect(find.text('Cálculo Diferencial e Integral'), findsOneWidget);
        expect(find.text('Álgebra Lineal y sus Aplicaciones'), findsNothing);
      },
    );

    testWidgets(
      'Muestra EmptyState cuando una búsqueda no encuentra resultados',
      (WidgetTester tester) async {
        final testRouter = GoRouter(
          initialLocation: '/catalog',
          routes: [
            GoRoute(
              path: '/catalog',
              builder: (context, state) => const CatalogScreen(),
            ),
          ],
        );

        await tester.pumpWidget(MaterialApp.router(routerConfig: testRouter));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(SearchBar), 'TextoInexistente999');
        await tester.pump();

        expect(find.byType(MaterialCard), findsNothing);
        expect(find.byType(EmptyState), findsOneWidget);
        expect(find.text('No se encontraron materiales'), findsOneWidget);
      },
    );
  });
}
