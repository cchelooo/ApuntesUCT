import 'package:apuntesuct_mobile/features/materials/data/material_upload_response.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> uploadData({
  Object? id = 'mat-900',
  Object? title = 'Guía de prueba',
  Object? year = '2026',
  Object? fileSize = 1234,
  Object? description = 'Descripción.',
  Object? createdAt = '2026-10-05T14:00:00.000Z',
}) => {
  'id': id,
  'title': title,
  'description': description,
  'year': year,
  'type': 'DOCUMENT',
  'status': 'PENDING_REVIEW',
  'subjectId': '55555555-5555-4555-8555-555555555555',
  'careerId': '33333333-3333-4333-8333-333333333333',
  'professorId': null,
  'universityId': '11111111-1111-4111-8111-111111111111',
  'fileUrl': null,
  'fileSize': fileSize,
  'mimeType': 'application/pdf',
  'externalLink': null,
  'createdAt': createdAt,
};

void main() {
  group('materialDetailFromUploadResponse (#285, H6)', () {
    test('mapea el 201 mínimo con year como cadena', () {
      final detail = materialDetailFromUploadResponse(uploadData());

      expect(detail.summary.id, 'mat-900');
      expect(detail.summary.title, 'Guía de prueba');
      expect(detail.summary.academicYear, 2026);
      expect(detail.summary.materialType, 'DOCUMENT');
      expect(detail.summary.reviewStatus.name, 'pendingReview');
      expect(detail.summary.subject?.id, contains('5555'));
      expect(detail.fileSizeBytes, 1234);
      expect(detail.summary.createdAt, isNotNull);
    });

    test('tolera year numérico, fileSize cadena/nulo y nulos opcionales', () {
      final numeric = materialDetailFromUploadResponse(
        uploadData(year: 2026, fileSize: '2048', description: null),
      );
      expect(numeric.summary.academicYear, 2026);
      expect(numeric.fileSizeBytes, 2048);
      expect(numeric.summary.description, '');

      final noSize = materialDetailFromUploadResponse(
        uploadData(fileSize: null, createdAt: 'no-es-fecha'),
      );
      expect(noSize.fileSizeBytes, 0);
      expect(noSize.summary.createdAt, isNull);
    });

    test('lanza FormatException sin id o sin título', () {
      expect(
        () => materialDetailFromUploadResponse(uploadData(id: '')),
        throwsFormatException,
      );
      expect(
        () => materialDetailFromUploadResponse(uploadData(title: '   ')),
        throwsFormatException,
      );
    });
  });
}
