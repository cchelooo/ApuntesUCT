import 'package:dio/dio.dart';

class ApiClient {
  // Aquí va la URL base del API Gateway (Issue #39)
  // Ajusta la IP o URL según lo que haya definido el backend/gateway
  static const String baseUrl = 'http://10.0.2.2:8000/api/v1'; 

  late final Dio dio;

  ApiClient() {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Interceptor básico para logs o depuración inicial
    dio.interceptors.add(
      LogInterceptor(
        request: true,
        requestHeader: true,
        requestBody: true,
        responseHeader: true,
        responseBody: true,
        error: true,
      ),
    );
  }
}