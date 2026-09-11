import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../errors/api_exception.dart';

/// Interceptor para capturar y procesar respuestas con error
class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final apiException = ApiException.fromDioException(err);

    if (kDebugMode) {
      debugPrint(
        '[API ERROR] ${err.requestOptions.method} ${err.requestOptions.path}',
      );
      debugPrint('[API ERROR DETAIL] $apiException');
    }

    // Reenvía el error encapsulado en el DioException para que la app lo reciba ordenado
    final customDioException = DioException(
      requestOptions: err.requestOptions,
      response: err.response,
      type: err.type,
      error: apiException,
      message: apiException.message,
    );

    return handler.next(customDioException);
  }
}
