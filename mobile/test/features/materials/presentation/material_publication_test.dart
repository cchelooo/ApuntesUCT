import 'dart:convert';
import 'dart:io';

import 'package:apuntesuct_mobile/features/materials/domain/models/material_page.dart';
import 'package:apuntesuct_mobile/features/materials/data/material_detail_response.dart';
import 'package:apuntesuct_mobile/features/materials/data/search_response.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_detail.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_summary.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/screens/material_detail_screen.dart';
import 'package:apuntesuct_mobile/features/materials/presentation/widgets/material_publication_badges.dart';
import 'package:flutter/material.dart' hide MaterialPage;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('listing, detail and Search preserve the actual verification response field', () {
    Map<String, dynamic> fixture(String name) => jsonDecode(
      File('test/fixtures/materials/$name.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    expect(
      MaterialPage.fromJson(fixture('gateway_list')).items.single.verified,
      isFalse,
    );
    expect(
      materialDetailFromResponse(fixture('gateway_detail')).summary.verified,
      isTrue,
    );
    expect(
      searchPageFromResponse(fixture('gateway_search_page'))
          .items
          .single
          .verified,
      isTrue,
    );
  });
  test(
    'verification is a strict independent boolean and survives round trips',
    () {
      for (final status in [
        'PENDING_REVIEW',
        'PUBLISHED',
        'REJECTED',
        'WITHDRAWN',
        'RETIRED',
        'FUTURE_STATE',
        'APPROVED',
      ]) {
        for (final verified in [true, false]) {
          final material = MaterialSummary.fromJson({
            'id': 'm',
            'title': 'Guía',
            'status': status,
            'verified': verified,
            'type': 'DOCUMENT',
          });
          expect(material.verified, verified);
          expect(
            MaterialSummary.fromJson(material.toJson()).verified,
            verified,
          );
          expect(material.canDownload, status == 'PUBLISHED');
          if (status == 'RETIRED') {
            expect(material.toJson()['status'], 'RETIRED');
          }
        }
      }
      expect(
        MaterialSummary.fromJson({'id': 'm', 'title': 'Guía'}).verified,
        isFalse,
      );
      expect(
        () => MaterialSummary.fromJson({
          'id': 'm',
          'title': 'Guía',
          'verified': 'true',
        }),
        throwsFormatException,
      );
    },
  );

  for (final theme in [ThemeData.light(), ThemeData.dark()]) {
    for (final status in [
      'PENDING_REVIEW',
      'PUBLISHED',
      'REJECTED',
      'WITHDRAWN',
      'RETIRED',
      'FUTURE_STATE',
    ]) {
      testWidgets(
        '$status is separate from verified and actions are conservative at 320 px (${theme.brightness})',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(320, 800));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final summary = MaterialSummary(
            id: 'm',
            title: 'Guía de prueba',
            status: status,
            verified: true,
            materialType: 'DOCUMENT',
          );
          await tester.pumpWidget(
            ProviderScope(
              child: MaterialApp(
                theme: theme,
                home: MaterialDetailScreen(
                  detail: MaterialDetail(summary: summary),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(MaterialPublicationBadges), findsOneWidget);
          expect(find.text('Verificado'), findsOneWidget);
          expect(
            find.text('PUBLICADO'),
            status == 'PUBLISHED' ? findsOneWidget : findsNothing,
          );
          if (status == 'PUBLISHED') {
            await tester.scrollUntilVisible(
              find.text('Descargar Material'),
              200,
            );
            expect(find.text('Descargar Material'), findsOneWidget);
          } else {
            expect(find.text('Descargar Material'), findsNothing);
          }
          expect(
            find.text('Subir nueva versión'),
            findsNothing,
            reason: 'No existe identidad de autor autenticada',
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
