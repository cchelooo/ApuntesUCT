import 'package:apuntesuct_mobile/core/errors/api_exception.dart';
import 'package:apuntesuct_mobile/core/network/api_client.dart';
import 'package:apuntesuct_mobile/features/materials/data/dio_material_repository.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/academic_reference.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_requests.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../presentation/upload_catalog_harness.dart'
    show isCatalogUuid, testBdId, testIciId, testUctId;

/// Respuesta 201 mínima según CreateMaterialResponseDto (issue #285).
/// Usa UUID reales de Catalog: los ficticios (`subj-bd-uuid`) caen en 400.
Map<String, dynamic> canned201({
  String id = 'mat-900',
  String title = 'Guía de prueba',
}) => {
  'status': 'success',
  'isSimulatedResponse': false,
  'message': 'Material registrado exitosamente en estado PENDING_REVIEW.',
  'data': {
    'id': id,
    'title': title,
    'description': 'Descripción de prueba.',
    'year': '2026',
    'type': 'DOCUMENT',
    'status': 'PENDING_REVIEW',
    'subjectId': testBdId,
    'careerId': testIciId,
    'professorId': null,
    'universityId': testUctId,
    'fileUrl': null,
    'fileSize': 3,
    'mimeType': 'application/pdf',
    'externalLink': null,
    'createdAt': '2026-10-05T14:00:00.000Z',
  },
};

UploadMaterialRequest fileRequest({
  List<int> bytes = const [1, 2, 3],
  Uri? backupLink,
}) => UploadMaterialRequest(
  title: 'Guía de prueba',
  description: 'Descripción de prueba.',
  university: AcademicReference(id: testUctId),
  career: AcademicReference(id: testIciId),
  subject: AcademicReference(id: testBdId),
  year: 2026,
  type: 'DOCUMENT',
  source: LocalMaterialFile(
    fileName: 'apuntes.pdf',
    mimeType: 'application/pdf',
    bytes: bytes,
  ),
  backupLink: backupLink,
);

void main() {
  group('DioMaterialRepository.upload (#285)', () {
    test('envía multipart con metadatos + archivo y parsea el 201', () async {
      FormData? captured;
      String? capturedContentType;
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              captured = options.data as FormData?;
              capturedContentType = options.contentType;
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 201,
                  data: canned201(),
                ),
              );
            },
          ),
        );
      final repository = DioMaterialRepository(ApiClient(customDio: dio));

      final detail = await repository.upload(
        fileRequest(backupLink: Uri.parse('https://drive.example.com/x')),
      );

      expect(captured, isNotNull);
      expect(capturedContentType, startsWith('multipart/form-data'));

      final fields = Map.fromEntries(captured!.fields);
      expect(fields['title'], 'Guía de prueba');
      expect(fields['description'], 'Descripción de prueba.');
      expect(fields['year'], '2026');
      expect(fields['type'], 'DOCUMENT');
      expect(fields['subjectId'], testBdId);
      expect(fields['careerId'], testIciId);
      expect(isCatalogUuid(fields['subjectId'] as String), isTrue);
      expect(isCatalogUuid(fields['careerId'] as String), isTrue);
      expect(fields['externalLink'], 'https://drive.example.com/x');

      expect(captured!.files, hasLength(1));
      final file = captured!.files.single;
      expect(file.key, 'file');
      expect(file.value.filename, 'apuntes.pdf');
      expect('${file.value.contentType}', 'application/pdf');
      final chunks = await file.value.finalize().toList();
      expect(chunks.expand((c) => c).toList(), [1, 2, 3]);

      expect(detail.summary.id, 'mat-900');
      expect(detail.summary.title, 'Guía de prueba');
      expect(detail.summary.reviewStatus.name, 'pendingReview');
      expect(detail.summary.academicYear, 2026);
      expect(detail.fileSizeBytes, 3);
    });

    test('fuente enlace envía externalLink sin parte de archivo', () async {
      FormData? captured;
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              captured = options.data as FormData?;
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 201,
                  data: canned201(title: 'Enlace de prueba'),
                ),
              );
            },
          ),
        );
      final repository = DioMaterialRepository(ApiClient(customDio: dio));

      final request = UploadMaterialRequest(
        title: 'Enlace de prueba',
        university: AcademicReference(id: testUctId),
        career: AcademicReference(id: testIciId),
        subject: AcademicReference(id: testBdId),
        year: 2026,
        type: 'LINK',
        source: ExternalMaterialLink(Uri.parse('https://example.com/a')),
      );

      final detail = await repository.upload(request);

      final fields = Map.fromEntries(captured!.fields);
      expect(fields['externalLink'], 'https://example.com/a');
      expect(fields.containsKey('description'), isFalse);
      expect(fields.containsKey('professorId'), isFalse);
      expect(captured!.files, isEmpty);
      expect(detail.summary.id, 'mat-900');
    });

    test(
      'propaga el 413 del backend con el ApiException del interceptor',
      () async {
        final dio = Dio()
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) {
                // Simula lo que el ErrorInterceptor real produce en
                // producción y verifica que el repositorio lo propaga.
                handler.reject(
                  DioException(
                    requestOptions: options,
                    type: DioExceptionType.badResponse,
                    response: Response(
                      requestOptions: options,
                      statusCode: 413,
                      data: {'message': 'El archivo excede el tamaño máximo.'},
                    ),
                    error: ApiException(
                      message: 'El archivo excede el tamaño máximo.',
                      statusCode: 413,
                    ),
                  ),
                  true,
                );
              },
            ),
          );
        final repository = DioMaterialRepository(ApiClient(customDio: dio));

        Object? caught;
        try {
          await repository.upload(fileRequest());
        } catch (e) {
          caught = e;
        }

        expect(caught, isA<DioException>());
        final api = (caught as DioException).error;
        expect(api, isA<ApiException>());
        expect((api as ApiException).statusCode, 413);
        expect(api.message, contains('excede'));
      },
    );
  });
}
