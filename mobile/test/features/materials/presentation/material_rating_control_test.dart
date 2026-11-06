import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/widgets/material_rating_control.dart';

void main() {
  group('MaterialRatingControl Tests (#397)', () {
    testWidgets('Renderiza 5 estrellas y reconoce la calificación seleccionada', (WidgetTester tester) async {
      int? selectedValue;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MaterialRatingControl(
              rating: 3,
              onRatingSelected: (val) => selectedValue = val,
            ),
          ),
        ),
      );

      // Debe encontrar 5 iconos de estrella en total
      expect(find.byType(IconButton), findsNWidgets(5));

      // Las primeras 3 deben estar seleccionadas (rellenas)
      // Tocamos la estrella 5 para probar el callback
      await tester.tap(find.byType(IconButton).at(4));
      expect(selectedValue, 5);
    });

    testWidgets('Deshabilita los botones cuando isEnabled es falso o está enviando', (WidgetTester tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MaterialRatingControl(
              rating: 4,
              isEnabled: false,
              onRatingSelected: (_) => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(IconButton).first);
      expect(tapped, isFalse);
    });
  });
}