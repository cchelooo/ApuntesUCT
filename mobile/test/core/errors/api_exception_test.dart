import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:apuntesuct_mobile/core/errors/api_exception.dart';

void main() {
  group('ApiException Tests', () {
    test('Mapea timeout de conexion correctamente', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/test'),
        type: DioExceptionType.connectionTimeout,
      );

      final apiException = ApiException.fromDioException(dioException);

      expect(apiException.message, contains('Tiempo de espera agotado'));
    });

    test('Mapea error de conexion correctamente', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/test'),
        type: DioExceptionType.connectionError,
      );

      final apiException = ApiException.fromDioException(dioException);

      expect(apiException.message, contains('No se pudo establecer conexión'));
    });

    test('Mapea badResponse con mensaje personalizado del backend', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/test'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 400,
          data: {'message': 'Datos inválidos'},
        ),
      );

      final apiException = ApiException.fromDioException(dioException);

      expect(apiException.statusCode, equals(400));
      expect(apiException.message, equals('Datos inválidos'));
    });

    test('Mapea cancelacion de peticion correctamente', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/test'),
        type: DioExceptionType.cancel,
      );

      final apiException = ApiException.fromDioException(dioException);

      expect(apiException.message, contains('cancelada'));
    });
  });
}
