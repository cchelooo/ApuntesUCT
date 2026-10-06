import 'dart:convert';
import 'dart:io';

import 'package:apuntesuct_mobile/features/materials/domain/models/academic_reference.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fixtures = jsonDecode(
    File('test/fixtures/materials/domain_foundations.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  group('AcademicReference (#271, día 1)', () {
    test('conserva ID y nombre de una referencia completa', () {
      final json = fixtures['completeReference'] as Map<String, dynamic>;
      final reference = AcademicReference.fromJson(json);

      expect(reference.id, json['id']);
      expect(reference.name, 'Estructuras de Datos');
      expect(reference.toJson(), json);
    });

    test('admite una referencia mínima sin inventar el nombre', () {
      final json = fixtures['minimalReference'] as Map<String, dynamic>;
      final reference = AcademicReference.fromJson(json);

      expect(reference.id, json['id']);
      expect(reference.name, isNull);
      expect(reference.toJson(), json);
    });

    test('rechaza un ID vacío en el fixture inválido', () {
      expect(
        () => AcademicReference.fromJson(
          fixtures['invalidReference'] as Map<String, dynamic>,
        ),
        throwsFormatException,
      );
    });

    test('rechaza ID ausente o de otro tipo y nombres inválidos', () {
      for (final json in <Map<String, dynamic>>[
        {},
        {'id': 42},
        {'id': 'subject-1', 'name': 42},
        {'id': 'subject-1', 'name': '   '},
      ]) {
        expect(() => AcademicReference.fromJson(json), throwsFormatException);
      }
    });

    test('también valida referencias construidas sin JSON', () {
      expect(() => AcademicReference(id: '   '), throwsArgumentError);
      expect(
        () => AcademicReference(id: 'subject-1', name: ''),
        throwsArgumentError,
      );
    });
  });
}
