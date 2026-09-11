import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

class ApiClient {
  static const String defaultBaseUrl = 'http://10.0.2.2:3000/api/v1';

  final Dio dio;

  ApiClient({String? baseUrl, Dio? customDio})
    : dio =
          customDio ??
          Dio(
            BaseOptions(
              baseUrl: baseUrl ?? defaultBaseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
            ),
          ) {
    // Limitar logs solo a debug y proteger credenciales/tokens sensibles
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
