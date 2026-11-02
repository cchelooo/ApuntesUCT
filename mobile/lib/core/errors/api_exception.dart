import 'package:dio/dio.dart';

/// Mensaje público compartido por las pantallas que consumen el Gateway.
String apiErrorMessage(Object? error, {required String fallback}) {
  final api = error is ApiException
      ? error
      : error is DioException && error.error is ApiException
      ? error.error as ApiException
      : null;
  return api != null && api.message.trim().isNotEmpty ? api.message : fallback;
}

/// Clase centralizada para manejar excepciones de la API
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  ApiException({required this.message, this.statusCode, this.data});

  /// Transforma un [DioException] en un [ApiException] con un mensaje amigable
  factory ApiException.fromDioException(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(
          message: 'Tiempo de espera agotado al conectar con el servidor.',
          statusCode: error.response?.statusCode,
        );
      case DioExceptionType.connectionError:
        return ApiException(
          message: 'No se pudo establecer conexión con el servidor. Verifica tu red o que el servidor esté activo.',
          statusCode: error.response?.statusCode,
        );
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        final responseData = error.response?.data;
        String message =
            'Ocurrió un error inesperado en el servidor ($statusCode).';

        // Intenta extraer el mensaje de error provisto por el backend si viene en formato JSON
        if (responseData is Map<String, dynamic>) {
          if (responseData.containsKey('message') &&
              responseData['message'] is String) {
            message = responseData['message'];
          } else if (responseData['message'] is List &&
              (responseData['message'] as List).isNotEmpty &&
              (responseData['message'] as List).every(
                (item) => item is String,
              )) {
            message = (responseData['message'] as List).join('\n');
          } else if (responseData.containsKey('detail') &&
              responseData['detail'] is String) {
            message = responseData['detail'];
          } else if (responseData.containsKey('error') &&
              responseData['error'] is String) {
            message = responseData['error'];
          }
        }

        return ApiException(
          message: message,
          statusCode: statusCode,
          data: responseData,
        );
      case DioExceptionType.cancel:
        return ApiException(message: 'La petición fue cancelada.');
      default:
        return ApiException(
          message: 'Error inesperado de red. Intenta nuevamente.',
          statusCode: error.response?.statusCode,
        );
    }
  }

  @override
  String toString() =>
      'ApiException(statusCode: $statusCode, message: $message)';
}
