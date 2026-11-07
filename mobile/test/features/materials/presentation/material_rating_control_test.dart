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

      expect(find.byType(IconButton), findsNWidgets(5));

      await tester.tap(find.byType(IconButton).at(4));
      expect(selectedValue, 5);
    });

    testWidgets('Deshabilita los botones cuando isEnabled es falso', (WidgetTester tester) async {
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

    testWidgets('Muestra indicador visual y etiqueta accesible cuando isSubmitting es verdadero', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MaterialRatingControl(
              rating: 4,
              isSubmitting: true,
            ),
          ),
        ),
      );

      // Verifica que las estrellas ya no se muestran
      expect(find.byType(IconButton), findsNothing);
      
      // Verifica que aparece el indicador de carga y el texto de envío accesible
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Enviando calificación...'), findsOneWidget);
    });
  });
}