import 'package:apuntesuct_mobile/core/network/api_client.dart';
import 'package:apuntesuct_mobile/features/catalog/data/catalog_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CatalogRepository API Error & Edge Cases Tests (#83)', () {
    test('Lanza DioException ante error de conexión o timeout', () async {
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

      expect(() => repository.getCatalog(), throwsA(isA<DioException>()));
    });

    test('Lanza DioException ante fallo de backend HTTP 500', () async {
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

      expect(() => repository.getCatalog(), throwsA(isA<DioException>()));
    });

    test('Lanza DioException ante recurso no encontrado HTTP 404', () async {
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

      expect(() => repository.getCatalog(), throwsA(isA<DioException>()));
    });

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
                null, // Caso borde: asignatura nula
              ],
            },
            {
              'id': 'car-vacia',
              'name': 'Carrera Sin Asignaturas',
              'subjects': [], // Caso borde: carrera sin ramos
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
