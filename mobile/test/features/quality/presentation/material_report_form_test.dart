import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apuntesuct_mobile/features/quality/domain/models/report_motive.dart';
import 'package:apuntesuct_mobile/features/quality/presentation/widgets/material_report_form.dart';

void main() {
  group('MaterialReportForm Tests (#398, #406)', () {
    testWidgets('Muestra la identificación del material a reportar', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MaterialReportForm(
              materialId: '11111111-2222-4333-8444-555555555555',
              materialTitle: 'Guía de Cálculo',
              onSubmit: (_, _) {},
            ),
          ),
        ),
      );

      expect(find.textContaining('Guía de Cálculo'), findsOneWidget);
    });

    testWidgets(
      'Muestra error de validación si se envía sin seleccionar motivo',
      (WidgetTester tester) async {
        bool submitted = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MaterialReportForm(
                materialId: '11111111-2222-4333-8444-555555555555',
                materialTitle: 'Material X',
                onSubmit: (_, _) => submitted = true,
              ),
            ),
          ),
        );

        await tester.tap(find.text('Enviar Reporte'));
        await tester.pumpAndSettle();

        expect(
          find.text('Por favor, seleccione un motivo obligatorio.'),
          findsOneWidget,
        );
        expect(submitted, isFalse);
      },
    );

    testWidgets(
      'Ejecuta onSubmit con motivo contractual y bloquea controles cuando OTHER no tiene detalles',
      (WidgetTester tester) async {
        ReportMotive? submittedMotive;
        String? submittedDesc;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MaterialReportForm(
                materialId: '11111111-2222-4333-8444-555555555555',
                materialTitle: 'Material Y',
                onSubmit: (motive, desc) {
                  submittedMotive = motive;
                  submittedDesc = desc;
                },
              ),
            ),
          ),
        );

        // Seleccionamos motivo OTHER sin detalles -> debe exigir detalles
        await tester.tap(find.byType(DropdownButtonFormField<ReportMotive>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Otro motivo').last);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Enviar Reporte'));
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Debes especificar los detalles cuando seleccionas "Otro motivo".',
          ),
          findsOneWidget,
        );
        expect(submittedMotive, isNull);

        // Seleccionamos motivo contractual INCORRECT_INFORMATION y escribimos descripción
        await tester.tap(find.byType(DropdownButtonFormField<ReportMotive>));
        await tester.pumpAndSettle();
        await tester.tap(
          find.text('Información errónea o desactualizada').last,
        );
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextFormField), 'Versión antigua');
        await tester.tap(find.text('Enviar Reporte'));
        await tester.pumpAndSettle();

        expect(submittedMotive, ReportMotive.incorrectInformation);
        expect(submittedMotive?.code, 'INCORRECT_INFORMATION');
        expect(submittedDesc, 'Versión antigua');
      },
    );

    testWidgets(
      'Conserva el texto ingresado al recibir un estado de error externo',
      (WidgetTester tester) async {
        final widget = MaterialApp(
          home: Scaffold(
            body: MaterialReportForm(
              materialId: '11111111-2222-4333-8444-555555555555',
              materialTitle: 'Material Z',
              errorMessage: 'Ocurrió un error en el servidor',
              onSubmit: (_, _) {},
            ),
          ),
        );

        await tester.pumpWidget(widget);

        await tester.enterText(
          find.byType(TextFormField),
          'El enlace está caído',
        );
        await tester.pumpAndSettle();

        expect(find.text('Ocurrió un error en el servidor'), findsOneWidget);
        expect(find.text('El enlace está caído'), findsOneWidget);
      },
    );
  });
}
