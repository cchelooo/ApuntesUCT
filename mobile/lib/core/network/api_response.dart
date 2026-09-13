import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../errors/api_exception.dart';

/// Tipo alias para representar el estado de una petición asíncrona hacia la API
/// utilizando la infraestructura nativa de Riverpod (AsyncLoading, AsyncData, AsyncError).
typedef ApiResponse<T> = AsyncValue<T>;

/// Utilidad para ejecutar peticiones HTTP y mapear el resultado automáticamente
/// a estados de Riverpod ([AsyncData] en éxito, [AsyncError] con [ApiException] en fallo).
class ApiResponseHandler {
  static Future<AsyncValue<T>> guard<T>(Future<T> Function() request) async {
    try {
      final result = await request();
      return AsyncData(result);
    } on DioException catch (dioErr, stackTrace) {
      final apiException = ApiException.fromDioException(dioErr);
      return AsyncError(apiException, stackTrace);
    } on ApiException catch (apiErr, stackTrace) {
      return AsyncError(apiErr, stackTrace);
    } catch (err, stackTrace) {
      return AsyncError(err, stackTrace);
    }
  }
}
