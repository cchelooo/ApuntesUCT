import 'package:apuntesuct_mobile/features/materials/domain/models/material_fixtures.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/screens/material_detail_screen.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/widgets/material_summary_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Material Components Widget Tests (#284)', () {
    testWidgets('MaterialSummaryCard renderiza información contractual clave', (
      WidgetTester tester,
    ) async {
      bool tapped = false;
      final sample = MaterialFixtures.sampleSummary1;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MaterialSummaryCard(
              material: sample,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text(sample.title), findsOneWidget);
      expect(
        find.text('${sample.subjectName} • ${sample.careerName}'),
        findsOneWidget,
      );
      expect(find.text(sample.authorName), findsOneWidget);
      expect(find.text('4.8'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);

      await tester.tap(find.byType(MaterialSummaryCard));
      expect(tapped, isTrue);
    });

    testWidgets(
      'MaterialDetailScreen renderiza cabecera, etiquetas y estadísticas',
      (WidgetTester tester) async {
        final detail = MaterialFixtures.sampleDetail1;

        await tester.pumpWidget(
          MaterialApp(home: MaterialDetailScreen(detail: detail)),
        );

        expect(find.text('Detalle del Material'), findsOneWidget);
        expect(find.text(detail.summary.title), findsOneWidget);
        expect(find.text('Árboles'), findsOneWidget);
        expect(find.text('Descargar Material'), findsOneWidget);
        expect(find.text('Descargas'), findsOneWidget);
        expect(find.text('Calificación'), findsOneWidget);
        expect(find.text('Tamaño'), findsOneWidget);
      },
    );
  });
}
