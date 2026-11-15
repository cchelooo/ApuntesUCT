import 'package:apuntesuct_mobile/core/errors/api_exception.dart';
import 'package:apuntesuct_mobile/core/network/api_client.dart';
import 'package:apuntesuct_mobile/features/materials/data/dio_moderation_repository.dart';
import 'package:apuntesuct_mobile/features/materials/domain/models/material_status.dart';
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
  group('DioModerationRepository (#409)', () {
    test(
      'consulta GET /materials/pending con paginación y parsea items',
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
                        'id': 'mat-pending-01',
                        'title': 'Apuntes Cálculo II',
                        'status': 'PENDING_REVIEW',
                        'verified': false,
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

        final repo = DioModerationRepository(_FakeApiClient(dio));
        final result = await repo.listPending(page: 1, pageSize: 10);

        expect(capturedRequest?.path, '/materials/pending');
        expect(capturedRequest?.queryParameters, {'page': 1, 'pageSize': 10});
        expect(result.items, hasLength(1));
        expect(result.items.first.id, 'mat-pending-01');
        expect(result.items.first.reviewStatus, MaterialStatus.pendingReview);
      },
    );

    test('valida límites de paginación antes de enviar petición', () async {
      final repo = DioModerationRepository(_FakeApiClient(Dio()));

      expect(() => repo.listPending(page: 0), throwsArgumentError);
      expect(() => repo.listPending(pageSize: 101), throwsArgumentError);
    });

    test(
      'propaga ApiException cuando el Gateway rechaza acceso (403)',
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

        final repo = DioModerationRepository(_FakeApiClient(dio));
        expect(() => repo.listPending(), throwsA(isA<ApiException>()));
      },
    );
  });
}
