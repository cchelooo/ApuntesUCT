import 'package:apuntesuct_mobile/core/errors/api_exception.dart';
import 'package:apuntesuct_mobile/core/network/api_client.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_status.dart';
import 'package:apuntesuct_mobile/features/quality/data/dio_quality_moderation_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeApiClient implements ApiClient {
  _FakeApiClient(this.dio);

  @override
  final Dio dio;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('DioQualityModerationRepository (#409)', () {
    test(
      'consulta GET /quality/moderation/pending y mapea DTO privado de Quality',
      () async {
        final dio = Dio(
          BaseOptions(baseUrl: 'https://gateway.example.test/api/v1'),
        );
        RequestOptions? capturedRequest;

        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              capturedRequest = options;
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'items': [
                      {
                        'id': 'rev-101',
                        'materialId': 'mat-pending-01',
                        'materialVersionId': 'ver-01',
                        'submittedAt': '2026-11-15T10:00:00.000Z',
                        'material': {
                          'id': 'mat-pending-01',
                          'title': 'Apuntes Cálculo II',
                          'status': 'PENDING_REVIEW',
                          'subjectName': 'Cálculo II',
                          'authorName': 'Camila Soto',
                        },
                      },
                    ],
                    'page': 1,
                    'pageSize': 10,
                    'total': 1,
                  },
                ),
              );
            },
          ),
        );

        final repo = DioQualityModerationRepository(_FakeApiClient(dio));
        final result = await repo.listPendingModeration(page: 1, pageSize: 10);

        expect(capturedRequest?.path, '/quality/moderation/pending');
        expect(capturedRequest?.queryParameters, {'page': 1, 'pageSize': 10});
        expect(result.items, hasLength(1));

        final item = result.items.first;
        expect(item.reviewId, 'rev-101');
        expect(item.materialId, 'mat-pending-01');
        expect(item.materialVersionId, 'ver-01');
        expect(item.title, 'Apuntes Cálculo II');
        expect(
          item.toMaterialSummary().reviewStatus,
          MaterialStatus.pendingReview,
        );
      },
    );

    test('valida límites de paginación antes de enviar petición', () async {
      final repo = DioQualityModerationRepository(_FakeApiClient(Dio()));

      expect(() => repo.listPendingModeration(page: 0), throwsArgumentError);
      expect(
        () => repo.listPendingModeration(pageSize: 101),
        throwsArgumentError,
      );
    });

    test(
      'propaga ApiException cuando Gateway/Quality rechaza acceso (403)',
      () async {
        final dio = Dio(
          BaseOptions(baseUrl: 'https://gateway.example.test/api/v1'),
        );
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.badResponse,
                  response: Response(
                    requestOptions: options,
                    statusCode: 403,
                    data: {'message': 'Forbidden'},
                  ),
                  error: ApiException(
                    statusCode: 403,
                    message: 'Acceso denegado para rol estudiante.',
                  ),
                ),
              );
            },
          ),
        );

        final repo = DioQualityModerationRepository(_FakeApiClient(dio));
        expect(
          () => repo.listPendingModeration(),
          throwsA(isA<ApiException>()),
        );
      },
    );
  });
}
