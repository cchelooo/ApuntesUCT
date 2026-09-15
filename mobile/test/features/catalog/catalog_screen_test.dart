import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apuntesuct_mobile/core/widgets/empty_state.dart';
import 'package:apuntesuct_mobile/features/catalog/presentation/screens/catalog_screen.dart';
import 'package:apuntesuct_mobile/features/catalog/presentation/widgets/material_card.dart';

void main() {
  group('CatalogScreen Tests', () {
    testWidgets('Muestra barra de búsqueda y lista inicial de materiales',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CatalogScreen(),
        ),
      );

      expect(find.byType(SearchBar), findsOneWidget);
      expect(find.byType(MaterialCard), findsWidgets);
      expect(find.text('Catálogo de Materiales'), findsOneWidget);

      await tester.enterText(find.byType(SearchBar), 'Cálculo');
      await tester.pump();

      expect(find.text('Cálculo Diferencial e Integral'), findsOneWidget);
      expect(find.text('Álgebra Lineal y sus Aplicaciones'), findsNothing);
    });

    testWidgets('Muestra EmptyState cuando una búsqueda no encuentra resultados',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CatalogScreen(),
        ),
      );

      await tester.enterText(find.byType(SearchBar), 'TextoQueNoExiste12345');
      await tester.pump();

      expect(find.byType(MaterialCard), findsNothing);
      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('No se encontraron materiales'), findsOneWidget);
    });
  });
}