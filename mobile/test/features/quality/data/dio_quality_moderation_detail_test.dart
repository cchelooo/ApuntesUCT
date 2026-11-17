import 'package:apuntesuct_mobile/core/errors/api_exception.dart';
import 'package:apuntesuct_mobile/core/network/api_client.dart';
import 'package:apuntesuct_mobile/features/quality/data/dio_quality_moderation_repository.dart';
import 'package:apuntesuct_mobile/features/quality/domain/repositories/quality_moderation_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeApiClient implements ApiClient {
  _FakeApiClient(this.dio);

  @override
  final Dio dio;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) => handler(options);

  @override
  void close({bool force = false}) {}
}

void main() {
  group(
    'DioQualityModerationRepository - Detalle y descarga privada (#410)',
    () {
      test('consume GET /quality/moderation/materials/:id sin tocar endpoints públicos', () async {
        late RequestOptions captured;
        final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8080/api/v1'));
        dio.httpClientAdapter = _StubAdapter((options) async {
          captured = options;
          return ResponseBody.fromString(
            '''
            {
              "reviewId": "rev-12",
              "materialId": "mat-700",
              "title": "Apuntes de Sistemas Operativos",
              "description": "Resumen unidad 2",
              "authorName": "Camila Soto",
              "subjectName": "Sistemas Operativos",
              "careerName": "Ingeniería Civil Informática",
              "professor": "Prof. Morales",
              "materialType": "DOCUMENT",
              "academicYear": 2026,
              "status": "PENDING_REVIEW",
              "fileSizeBytes": 2048,
              "mimeType": "application/pdf",
              "tags": ["procesos", "hilos"],
              "currentVersionId": "ver-2",
              "versions": [
                {
                  "id": "ver-1",
                  "versionNumber": 1,
                  "originalFilename": "so_v1.pdf",
                  "mimeType": "application/pdf",
                  "fileSize": "1024",
                  "storageKey": "secret/minio/key"
                },
                {
                  "id": "ver-2",
                  "versionNumber": 2,
                  "originalFilename": "so_v2.pdf",
                  "mimeType": "application/pdf",
                  "fileSize": "2048",
                  "storageKey": "secret/minio/key_v2"
                }
              ]
            }
            ''',
            200,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
            },
          );
        });

        final repo = DioQualityModerationRepository(_FakeApiClient(dio));
        final detail = await repo.getPendingMaterialDetail('mat-700');

        expect(captured.path, '/quality/moderation/materials/mat-700');
        expect(captured.path.startsWith('/materials'), isFalse);
        expect(detail.materialId, 'mat-700');
        expect(detail.reviewId, 'rev-12');
        expect(detail.title, 'Apuntes de Sistemas Operativos');
        expect(detail.currentVersion?.id, 'ver-2');
        expect(detail.currentVersion?.storageKey, isNull);
        expect(detail.tags, ['procesos', 'hilos']);
      });

      test(
        'mapea 404 a ModerationMaterialNotFoundException y 403 a ApiException',
        () async {
          var status = 404;
          final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8080/api/v1'));
          dio.httpClientAdapter = _StubAdapter((options) async {
            return ResponseBody.fromString(
              '{"message":"No autorizado o inexistente"}',
              status,
              headers: {
                Headers.contentTypeHeader: ['application/json'],
              },
            );
          });

          final repo = DioQualityModerationRepository(_FakeApiClient(dio));

          await expectLater(
            repo.getPendingMaterialDetail('mat-404'),
            throwsA(isA<ModerationMaterialNotFoundException>()),
          );

          status = 403;
          await expectLater(
            repo.getPendingMaterialDetail('mat-403'),
            throwsA(
              isA<ApiException>().having(
                (e) => e.statusCode,
                'statusCode',
                403,
              ),
            ),
          );
        },
      );

      test('descarga binario autorizado desde /quality/moderation/materials/:id/download', () async {
        late RequestOptions captured;
        final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8080/api/v1'));
        dio.httpClientAdapter = _StubAdapter((options) async {
          captured = options;
          return ResponseBody.fromBytes(
            [1, 2, 3, 4],
            200,
            headers: {
              Headers.contentTypeHeader: ['application/pdf'],
              'content-disposition': [
                "attachment; filename*=UTF-8''guia%20pendiente.pdf",
              ],
            },
          );
        });

        final repo = DioQualityModerationRepository(_FakeApiClient(dio));
        final download = await repo.downloadPendingMaterial(
          'mat-700',
          versionId: 'ver-2',
        );

        expect(captured.path, '/quality/moderation/materials/mat-700/download');
        expect(captured.queryParameters, {'versionId': 'ver-2'});
        expect(download.fileName, 'guia pendiente.pdf');
        expect(download.mimeType, 'application/pdf');
        expect(download.bytes, [1, 2, 3, 4]);
      });
    },
  );
}
