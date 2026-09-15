import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apuntesuct_mobile/features/catalog/presentation/screens/catalog_screen.dart';
import 'package:apuntesuct_mobile/features/catalog/presentation/widgets/material_card.dart';


void main() {
  testWidgets('CatalogScreen muestra barra de búsqueda y lista de tarjetas',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CatalogScreen(),
      ),
    );

    // Verifica que existan la barra de búsqueda y elementos iniciales
    expect(find.byType(SearchBar), findsOneWidget);
    expect(find.byType(MaterialCard), findsWidgets);
    expect(find.text('Catálogo de Materiales'), findsOneWidget);

    // Simula escribir 'Cálculo' en el buscador
    await tester.enterText(find.byType(SearchBar), 'Cálculo');
    await tester.pump();

    // Solo debe coincidir la tarjeta de Cálculo
    expect(find.text('Cálculo Diferencial e Integral'), findsOneWidget);
    expect(find.text('Álgebra Lineal y sus Aplicaciones'), findsNothing);
  });
}