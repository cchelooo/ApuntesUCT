import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

import '../config/api_config.dart';
import 'error_interceptor.dart';

class ApiClient {
  final Dio dio;

  ApiClient({String? baseUrl, Dio? customDio})
    : dio =
          customDio ??
          Dio(
            BaseOptions(
              baseUrl: baseUrl ?? ApiConfig.gatewayBaseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
            ),
          ) {
    // Interceptor para manejo unificado de errores (Issue #40)
    dio.interceptors.add(ErrorInterceptor());

    if (kDebugMode) {
      dio.interceptors.add(
        LogInterceptor(
          request: true,
          requestHeader: false,
          requestBody: false,
          responseHeader: false,
          responseBody: false,
          error: true,
        ),
      );
    }
  }
}
