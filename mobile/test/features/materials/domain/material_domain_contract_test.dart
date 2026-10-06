import 'dart:convert';
import 'dart:io';

import 'package:apuntesuct_mobile/features/materials/domain/models/material_detail.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_page.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_status.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_summary.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_version.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fixtures = jsonDecode(
    File('test/fixtures/materials/domain_models.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  Map<String, dynamic> fixture(String name) =>
      Map<String, dynamic>.from(fixtures[name]);

  group('MaterialSummary (#271)', () {
    test('parsea el material completo y conserva las referencias lógicas', () {
      final material = MaterialSummary.fromJson(fixture('summary'));
      expect(material.subject!.id, '00000000-0000-4000-8000-000000000003');
      expect(material.subjectName, 'Estructuras de Datos');
      expect(material.university!.name, 'Universidad Católica de Temuco');
      expect(material.career!.id, fixture('summary')['careerId']);
      expect(
        material.professorReference!.id,
        fixture('summary')['professorId'],
      );
      expect(material.professor, 'Dr. Roberto Muñoz');
      expect(material.reviewStatus, MaterialStatus.pendingReview);
      expect(material.createdAt, DateTime.utc(2026, 10, 4, 12));
      expect(material.toJson(), fixture('summary'));
    });

    test(
      'parsea el mínimo sin inventar año, fecha, referencia o aprobación',
      () {
        final material = MaterialSummary.fromJson(fixture('minimalSummary'));
        expect(material.academicYear, isNull);
        expect(material.createdAt, isNull);
        expect(material.subject, isNull);
        expect(material.professorReference, isNull);
        expect(material.reviewStatus, MaterialStatus.unknown);
      },
    );

    test('rechaza identidad inválida y campos con tipos incompatibles', () {
      final minimal = fixture('minimalSummary');
      for (final json in [
        fixture('invalidSummary'),
        <String, dynamic>{},
        {...minimal, 'title': ' '},
        {...minimal, 'id': 123},
        {...minimal, 'status': 123},
        {...minimal, 'subjectId': ' '},
        {...minimal, 'academicYear': 2026.5},
        {...minimal, 'downloadCount': -1},
        {...minimal, 'rating': 'alto'},
        {...minimal, 'createdAt': 'fecha inválida'},
        {...minimal, 'createdAt': '2026-02-30T12:00:00Z'},
      ]) {
        expect(() => MaterialSummary.fromJson(json), throwsFormatException);
      }
    });

    test('conserva un estado futuro como desconocido sin publicarlo', () {
      final material = MaterialSummary.fromJson({
        ...fixture('minimalSummary'),
        'status': 'FUTURE_STATUS',
      });
      expect(material.reviewStatus, MaterialStatus.unknown);
      expect(material.toJson()['status'], 'FUTURE_STATUS');
    });

    test('no inventa nombres para referencias por ID aún no enriquecidas', () {
      final material = MaterialSummary.fromJson({
        ...fixture('minimalSummary'),
        'subjectId': 'subject-1',
        'careerId': 'career-1',
      });
      expect(material.subject!.name, isNull);
      expect(material.career!.name, isNull);
      expect(material.toJson().containsKey('subjectName'), isFalse);
      expect(material.toJson().containsKey('careerName'), isFalse);
    });
  });

  group('MaterialVersion y MaterialDetail (#271)', () {
    test('parsea la versión completa y mínima sin fabricar metadatos', () {
      final version = MaterialVersion.fromJson(fixture('version'));
      expect(version.fileSizeBytes, 1024);
      expect(version.versionNumber, 1);
      expect(version.toJson(), fixture('version'));
      final minimal = MaterialVersion.fromJson(fixture('minimalVersion'));
      expect(minimal.createdAt, isNull);
      expect(minimal.mimeType, isNull);
      expect(minimal.toJson(), fixture('minimalVersion'));
    });

    test('rechaza versiones inválidas y numeración fraccionaria', () {
      for (final json in [
        fixture('invalidVersion'),
        <String, dynamic>{},
        {...fixture('minimalVersion'), 'versionNumber': 1.5},
        {...fixture('minimalVersion'), 'fileSizeBytes': -1},
      ]) {
        expect(() => MaterialVersion.fromJson(json), throwsFormatException);
      }
    });

    test('parsea detalle con versión actual e historial', () {
      final json = {
        ...fixture('summary'),
        'downloadUrl': 'https://example.test/101.pdf',
        'fileSizeBytes': 1024,
        'tags': ['Grafos'],
        'viewCount': 5,
        'versions': [fixture('version')],
        'currentVersionId': fixture('version')['id'],
      };
      final detail = MaterialDetail.fromJson(json);
      expect(detail.currentVersion!.versionNumber, 1);
      expect(detail.summary.id, detail.currentVersion!.materialId);
      expect(detail.tags, ['Grafos']);
      expect(detail.toJson(), json);
      expect(() => detail.versions.clear(), throwsUnsupportedError);
    });

    test('parsea detalle mínimo sin historial ni datos de descarga', () {
      final detail = MaterialDetail.fromJson(fixture('minimalSummary'));
      expect(detail.versions, isEmpty);
      expect(detail.currentVersion, isNull);
      expect(detail.downloadUrl, isEmpty);
    });

    test('rechaza versiones de otro material y colecciones mal formadas', () {
      for (final json in [
        {
          ...fixture('summary'),
          'versions': [fixture('minimalVersion')],
        },
        {...fixture('summary'), 'versions': 'inválido'},
        {
          ...fixture('summary'),
          'tags': [42],
        },
        {...fixture('summary'), 'fileSizeBytes': -1},
      ]) {
        expect(() => MaterialDetail.fromJson(json), throwsFormatException);
      }
    });
  });

  group('MaterialPage (#271)', () {
    test(
      'conserva paginación, total y posibilidad de pedir la próxima página',
      () {
        final page = MaterialPage.fromJson({
          'items': [fixture('summary')],
          'page': 1,
          'pageSize': 1,
          'total': 2,
        });
        expect(page.items.single.id, fixture('summary')['id']);
        expect(page.totalPages, 2);
        expect(page.hasNextPage, isTrue);
        expect(MaterialPage.fromJson(page.toJson()).total, 2);
        expect(() => page.items.clear(), throwsUnsupportedError);
      },
    );

    test('admite página vacía y última página parcial', () {
      final empty = MaterialPage.fromJson({
        'items': [],
        'page': 1,
        'pageSize': 10,
        'total': 0,
      });
      expect(empty.totalPages, 0);
      expect(empty.hasNextPage, isFalse);
      final last = MaterialPage.fromJson({
        'items': [fixture('minimalSummary')],
        'page': 2,
        'pageSize': 2,
        'total': 3,
      });
      expect(last.hasNextPage, isFalse);
    });

    test('rechaza metadatos ausentes, inválidos o inconsistentes', () {
      final valid = {
        'items': <Object>[],
        'page': 1,
        'pageSize': 10,
        'total': 0,
      };
      for (final json in [
        <String, dynamic>{},
        {...valid, 'page': 0},
        {...valid, 'pageSize': 0},
        {...valid, 'total': -1},
        {
          ...valid,
          'items': [fixture('minimalSummary')],
        },
        {
          ...valid,
          'items': [42],
          'total': 1,
        },
      ]) {
        expect(() => MaterialPage.fromJson(json), throwsFormatException);
      }
    });
  });
}
