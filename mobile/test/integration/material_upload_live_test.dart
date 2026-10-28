import 'dart:convert';
import 'dart:io';

import 'package:apuntesuct_mobile/core/errors/api_exception.dart';
import 'package:apuntesuct_mobile/core/network/api_client.dart';
import 'package:apuntesuct_mobile/features/materials/data/dio_material_repository.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/academic_reference.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_requests.dart';
import 'package:flutter_test/flutter_test.dart';

const runUploadSmoke = bool.fromEnvironment('RUN_MATERIAL_UPLOAD_SMOKE');

const subjectId = String.fromEnvironment('MATERIAL_TEST_SUBJECT_ID');
const careerId = String.fromEnvironment('MATERIAL_TEST_CAREER_ID');
const filePath = String.fromEnvironment('MATERIAL_TEST_PDF_PATH');
final enabled = runUploadSmoke && subjectId.isNotEmpty && careerId.isNotEmpty;

/// Optativo: crea registros reales. Usar un entorno desechable con Catalog,
/// PostgreSQL, MinIO y contexto de autor válidos. No habilitado por defecto.
void main() {
  late ApiClient client;
  late DioMaterialRepository repository;

  setUp(() {
    client = ApiClient();
    repository = DioMaterialRepository(client);
  });
  tearDown(() => client.dio.close(force: true));

  UploadMaterialRequest request(MaterialSource source, String type) =>
      UploadMaterialRequest(
        title: 'Prueba HTTP de contrato Mobile',
        university: AcademicReference(id: 'university-contract-test'),
        career: AcademicReference(id: careerId),
        subject: AcademicReference(id: subjectId),
        year: 2026,
        type: type,
        source: source,
      );

  test(
    'multipart FILE atraviesa Gateway y reconoce la respuesta persistida',
    () async {
      final bytes = File(filePath).readAsBytesSync();
      final detail = await repository.upload(
        request(
          LocalMaterialFile(
            fileName: 'contrato.pdf',
            mimeType: 'application/pdf',
            bytes: bytes,
          ),
          'DOCUMENT',
        ),
      );
      expect(detail.isSimulatedResponse, isFalse);
      expect(detail.fileSizeBytes, bytes.length);
      expect(detail.mimeType, 'application/pdf');
      expect(detail.summary.academicYear, 2026);
      expect(detail.summary.subject!.id, subjectId);
      expect(detail.downloadUrl, isEmpty);
    },
    skip: !enabled || filePath.isEmpty,
  );

  test('multipart LINK atraviesa Gateway sin adjunto', () async {
    final link = Uri.parse('https://example.com/contract');
    final detail = await repository.upload(
      request(ExternalMaterialLink(link), 'LINK'),
    );
    expect(detail.isSimulatedResponse, isFalse);
    expect(detail.externalLink, link.toString());
    expect(detail.fileSizeBytes, 0);
    expect(detail.mimeType, isNull);
  }, skip: !enabled);

  test(
    'el rechazo HTTP 415 de Material se conserva pasando por Gateway',
    () async {
      await expectLater(
        repository.upload(
          request(
            LocalMaterialFile(
              fileName: 'false.pdf',
              mimeType: 'application/pdf',
              bytes: utf8.encode('not a PDF'),
            ),
            'DOCUMENT',
          ),
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 415)
              .having(
                (e) => e.message,
                'message',
                contains('Tipo de archivo no admitido'),
              ),
        ),
      );
    },
    skip: !enabled,
  );
}
