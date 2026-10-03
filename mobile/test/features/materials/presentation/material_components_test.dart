import 'package:apuntesuct_mobile/features/materials/domain/models/material_fixtures.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_summary.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/screens/material_detail_screen.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/widgets/material_summary_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Material Components Widget Tests (#284)', () {
    testWidgets(
      'MaterialSummaryCard renderiza campos de profesor, año, tipo y estado',
      (WidgetTester tester) async {
        final sample = MaterialFixtures.sampleSummary1;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: MaterialSummaryCard(material: sample)),
          ),
        );

        expect(find.text(sample.title), findsOneWidget);
        expect(find.text('Prof. Dr. Roberto Muñoz'), findsOneWidget);
        expect(find.text('2026'), findsOneWidget);
        expect(find.text('CERTAMEN'), findsOneWidget);
        expect(find.text('APROBADO'), findsOneWidget);
      },
    );

    testWidgets(
      'MaterialSummaryCard navega a MaterialDetailScreen al hacer tap',
      (WidgetTester tester) async {
        final sample = MaterialFixtures.sampleSummary1;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: MaterialSummaryCard(material: sample)),
          ),
        );

        await tester.tap(find.byType(MaterialSummaryCard));
        await tester.pumpAndSettle();

        expect(find.byType(MaterialDetailScreen), findsOneWidget);
        expect(find.text('Detalle del Material'), findsOneWidget);
        expect(find.text('Docente: Dr. Roberto Muñoz'), findsOneWidget);
      },
    );

    testWidgets(
      'MaterialSummaryCard no genera overflow en pantallas angostas de 320px con autor largo',
      (WidgetTester tester) async {
        final longAuthorSample = MaterialSummary(
          id: 'mat-overflow-test',
          title: 'Título muy largo para probar overflows en pantalla pequeña',
          description: 'Descripción de prueba para verificar altura y desborde',
          authorName: 'Estudiante Con Nombre Extremadamente Largo Y Extenso Del Sur De Chile',
          subjectName: 'Estructuras de Datos',
          careerName: 'Ingeniería Civil Informática',
          fileType: 'pdf',
          professor: 'Profesor Nombre Muy Largo',
          academicYear: 2026,
          materialType: 'certamen',
          status: 'aprobado',
          downloadCount: 9999,
          rating: 5.0,
          createdAt: DateTime(2026, 3, 15),
        );

        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MaterialSummaryCard(material: longAuthorSample),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
      },
    );
  });
}
