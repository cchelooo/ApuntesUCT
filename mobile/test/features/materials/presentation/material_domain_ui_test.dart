import 'package:apuntesuct_mobile/features/materials/domain/models/material_summary.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/screens/material_detail_screen.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/widgets/material_summary_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'material en revisión se muestra y navega en 320px sin mostrar códigos internos',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final material = MaterialSummary.fromJson({
        'id': 'material-pending',
        'title': 'Guía pendiente de revisión',
        'status': 'PENDING_REVIEW',
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MaterialSummaryCard(material: material)),
        ),
      );
      expect(find.text('EN REVISIÓN'), findsOneWidget);
      expect(find.text('PENDING_REVIEW'), findsNothing);
      expect(find.text('Sin año'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(MaterialSummaryCard));
      await tester.pumpAndSettle();
      final screen = tester.widget<MaterialDetailScreen>(
        find.byType(MaterialDetailScreen),
      );
      expect(screen.detail.summary.id, material.id);
      expect(find.text('Sin año'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
