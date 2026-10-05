import 'dart:convert';
import 'dart:io';

import 'package:apuntesuct_mobile/features/materials/domain/models/material_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fixtures = jsonDecode(
    File('test/fixtures/materials/domain_foundations.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  group('MaterialStatus (#271, día 1)', () {
    test('reconoce PENDING_REVIEW sin aprobar el material', () {
      expect(
        MaterialStatus.fromJson(fixtures['pendingReview']),
        MaterialStatus.pendingReview,
      );
    });

    test('mantiene compatibilidad con las etiquetas de fixtures visuales', () {
      expect(
        MaterialStatus.fromJson(fixtures['legacyApproved']),
        MaterialStatus.approved,
      );
      expect(
        MaterialStatus.fromJson('pendiente'),
        MaterialStatus.pendingReview,
      );
      expect(MaterialStatus.fromJson('rechazado'), MaterialStatus.rejected);
      expect(MaterialStatus.fromJson('retirado'), MaterialStatus.withdrawn);
    });

    test('no convierte un estado ausente o desconocido en aprobado', () {
      for (final value in [null, '', '   ', fixtures['unknownStatus']]) {
        expect(MaterialStatus.fromJson(value), MaterialStatus.unknown);
      }
    });

    test('rechaza tipos JSON incompatibles', () {
      for (final value in <Object>[42, true, [], {}]) {
        expect(() => MaterialStatus.fromJson(value), throwsFormatException);
      }
    });

    test('serializa los estados del dominio sin perder su significado', () {
      for (final status in MaterialStatus.values) {
        expect(MaterialStatus.fromJson(status.toJson()), status);
      }
      expect(MaterialStatus.pendingReview.toJson(), 'PENDING_REVIEW');
    });
  });
}
