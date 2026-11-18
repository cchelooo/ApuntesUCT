import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/api_config.dart';
import 'error_interceptor.dart';
import '../session/session_controller.dart';
import '../session/session_storage.dart';
import '../session/session_interceptor.dart';

final apiclientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(session: ref.watch(sessionControllerProvider));
  ref.onDispose(() => client.dio.close(force: true));
  return client;
});

class ApiClient {
  final Dio dio;
  final SessionController session;

  ApiClient({String? baseUrl, Dio? customDio, SessionController? session})
    : session = session ?? SessionController(MemorySessionStorage()),
      dio =
          customDio ??
          Dio(
            BaseOptions(
              baseUrl: baseUrl ?? ApiConfig.gatewayBaseUrl,
              followRedirects: false,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
            ),
          ) {
    dio.interceptors.add(
      SessionInterceptor(this.session, Uri.parse(dio.options.baseUrl)),
    );
    // Interceptor para manejo unificado de errores (Issue #40)
    dio.interceptors.add(ErrorInterceptor());
  }
}
