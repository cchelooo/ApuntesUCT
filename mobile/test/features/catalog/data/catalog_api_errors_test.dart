import 'package:apuntesuct_mobile/core/network/api_client.dart';
import 'package:apuntesuct_mobile/features/catalog/data/catalog_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CatalogRepository API Error & Edge Cases Tests (#83)', () {
    test('Lanza DioException ante connectionTimeout', () async {
      final apiClient = ApiClient(baseUrl: 'http://localhost:3002/api/v1');
      apiClient.dio.interceptors.clear();
      apiClient.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionTimeout,
                message: 'Tiempo de conexión agotado',
              ),
            );
          },
        ),
      );

      final repository = CatalogRepository(apiClient);

      expect(
        () => repository.getCatalog(),
        throwsA(
          isA<DioException>().having(
            (e) => e.type,
            'type',
            DioExceptionType.connectionTimeout,
          ),
        ),
      );
    });

    test('Lanza DioException ante connectionError (servidor caído)', () async {
      final apiClient = ApiClient(baseUrl: 'http://localhost:3002/api/v1');
      apiClient.dio.interceptors.clear();
      apiClient.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
                message: 'Conexión rechazada',
              ),
            );
          },
        ),
      );

      final repository = CatalogRepository(apiClient);

      expect(
        () => repository.getCatalog(),
        throwsA(
          isA<DioException>().having(
            (e) => e.type,
            'type',
            DioExceptionType.connectionError,
          ),
        ),
      );
    });

    test(
      'Lanza DioException ante fallo de backend HTTP 500 con statusCode 500',
      () async {
        final apiClient = ApiClient(baseUrl: 'http://localhost:3002/api/v1');
        apiClient.dio.interceptors.clear();
        apiClient.dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  response: Response(
                    requestOptions: options,
                    statusCode: 500,
                    data: {'message': 'Internal Server Error'},
                  ),
                  type: DioExceptionType.badResponse,
                ),
              );
            },
          ),
        );

        final repository = CatalogRepository(apiClient);

        expect(
          () => repository.getCatalog(),
          throwsA(
            isA<DioException>().having(
              (e) => e.response?.statusCode,
              'statusCode',
              500,
            ),
          ),
        );
      },
    );

    test(
      'Lanza DioException ante recurso HTTP 404 con statusCode 404',
      () async {
        final apiClient = ApiClient(baseUrl: 'http://localhost:3002/api/v1');
        apiClient.dio.interceptors.clear();
        apiClient.dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  response: Response(
                    requestOptions: options,
                    statusCode: 404,
                    data: {'message': 'Not Found'},
                  ),
                  type: DioExceptionType.badResponse,
                ),
              );
            },
          ),
        );

        final repository = CatalogRepository(apiClient);

        expect(
          () => repository.getCatalog(),
          throwsA(
            isA<DioException>().having(
              (e) => e.response?.statusCode,
              'statusCode',
              404,
            ),
          ),
        );
      },
    );

    test('Retorna lista vacía si el backend responde con data nula', () async {
      final apiClient = ApiClient(baseUrl: 'http://localhost:3002/api/v1');
      apiClient.dio.interceptors.clear();
      apiClient.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response(requestOptions: options, statusCode: 200, data: null),
            );
          },
        ),
      );

      final repository = CatalogRepository(apiClient);

      final result = await repository.getCatalog();
      expect(result, isEmpty);
    });

    test(
      'Retorna lista vacía si el backend responde con lista vacía []',
      () async {
        final apiClient = ApiClient(baseUrl: 'http://localhost:3002/api/v1');
        apiClient.dio.interceptors.clear();
        apiClient.dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              handler.resolve(
                Response(requestOptions: options, statusCode: 200, data: []),
              );
            },
          ),
        );

        final repository = CatalogRepository(apiClient);

        final result = await repository.getCatalog();
        expect(result, isEmpty);
      },
    );

    test('Estructura real UCT: tolera ramas con datos incompletos sin romper el árbol', () async {
      final uctPayload = [
        {
          'id': 'uni-uct',
          'name': 'Universidad Católica de Temuco',
          'careers': [
            {
              'id': 'car-inf',
              'name': 'Ingeniería Civil Informática',
              'subjects': [
                {
                  'id': 'sub-ed',
                  'name': 'Estructuras de Datos',
                  'description': 'Algoritmos y complejidad',
                },
                null,
              ],
            },
            {
              'id': 'car-vacia',
              'name': 'Carrera Sin Asignaturas',
              'subjects': [],
            },
          ],
        },
      ];

      final apiClient = ApiClient(baseUrl: 'http://localhost:3002/api/v1');
      apiClient.dio.interceptors.clear();
      apiClient.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: uctPayload,
              ),
            );
          },
        ),
      );

      final repository = CatalogRepository(apiClient);

      final result = await repository.getCatalog();
      expect(result.length, 1);
      expect(result.first.id, 'sub-ed');
      expect(result.first.title, 'Estructuras de Datos');
      expect(result.first.subject, 'Ingeniería Civil Informática');
      expect(result.first.author, 'Universidad Católica de Temuco');
    });
  });
}
