import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../errors/api_error_model.dart';
import '../errors/api_exception.dart';
import 'token_store.dart';

/// Cliente HTTP de la aplicación construido sobre Dio.
///
/// Responsabilidades:
/// - centralizar la URL base del API Gateway y los timeouts;
/// - adjuntar el token de sesión en cada petición autenticada;
/// - traducir cualquier DioException a la jerarquía [ApiException], para que la
///   capa de presentación no dependa del paquete HTTP.
///
/// No parsea modelos: devuelve el JSON decodificado y cada modelo se encarga de
/// su propio fromJson.
class ApiClient {
  final Dio _dio;
  final TokenStore _tokenStore;

  ApiClient({Dio? dio, TokenStore? tokenStore, String? baseUrl})
    : _tokenStore = tokenStore ?? TokenStore(),
      _dio = dio ?? Dio() {
    _dio.options = _dio.options.copyWith(
      baseUrl: baseUrl ?? AppConfig.apiBaseUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      sendTimeout: AppConfig.sendTimeout,
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
      // Los códigos de error se manejan como excepciones tipadas y no como
      // respuestas válidas: sólo 2xx pasa sin lanzar.
      validateStatus: (status) =>
          status != null && status >= 200 && status < 300,
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = _tokenStore.accessToken;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) {
          // Una sesión rechazada por el backend no debe quedar en memoria.
          if (error.response?.statusCode == 401) {
            _tokenStore.clear();
          }
          handler.next(error);
        },
      ),
    );

    if (AppConfig.enableHttpLogs) {
      _dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          logPrint: (object) => debugPrint(object.toString()),
        ),
      );
    }
  }

  /// Almacén de tokens asociado a este cliente.
  TokenStore get tokenStore => _tokenStore;

  /// Instancia Dio subyacente. Expuesta para pruebas y diagnóstico.
  @visibleForTesting
  Dio get dio => _dio;

  /// GET que espera un objeto JSON como respuesta.
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) {
    return _run(() async {
      final response = await _dio.get<dynamic>(
        path,
        queryParameters: queryParameters,
      );
      return _asJsonObject(response.data, path);
    });
  }

  /// GET que espera un arreglo JSON como respuesta.
  ///
  /// Cubre los endpoints de catálogo que devuelven listas cortas sin envoltorio
  /// de paginación.
  Future<List<dynamic>> getJsonList(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) {
    return _run(() async {
      final response = await _dio.get<dynamic>(
        path,
        queryParameters: queryParameters,
      );
      final data = response.data;
      if (data is List) return data;
      throw UnexpectedApiException(
        'La respuesta de $path no es una lista JSON.',
      );
    });
  }

  /// POST que espera un objeto JSON como respuesta.
  Future<Map<String, dynamic>> postJson(String path, {Object? data}) {
    return _run(() async {
      final response = await _dio.post<dynamic>(path, data: data);
      return _asJsonObject(response.data, path);
    });
  }

  /// POST cuyo resultado se ignora (204 No Content o cuerpo irrelevante).
  Future<void> postNoContent(String path, {Object? data}) {
    return _run(() async {
      await _dio.post<dynamic>(path, data: data);
    });
  }

  /// Ejecuta la petición traduciendo cualquier fallo a [ApiException].
  Future<T> _run<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (e) {
      throw _mapDioException(e);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw UnexpectedApiException('Ocurrió un error inesperado: $e');
    }
  }

  /// Valida que el cuerpo recibido sea un objeto JSON.
  Map<String, dynamic> _asJsonObject(Object? data, String path) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw UnexpectedApiException(
      'La respuesta de $path no es un objeto JSON válido.',
    );
  }

  /// Traduce un DioException a la excepción de dominio equivalente.
  ApiException _mapDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const ApiTimeoutException();
      case DioExceptionType.connectionError:
      case DioExceptionType.badCertificate:
        return const NetworkException();
      case DioExceptionType.cancel:
        return const RequestCancelledException();
      case DioExceptionType.badResponse:
        return _mapStatusCode(e.response);
      case DioExceptionType.unknown:
        // Dio agrupa aquí los SocketException que no alcanzó a clasificar.
        return e.error is Exception
            ? const NetworkException()
            : UnexpectedApiException(
                e.message ?? 'Ocurrió un error inesperado.',
              );
    }
  }

  /// Traduce el código HTTP de una respuesta de error.
  ApiException _mapStatusCode(Response<dynamic>? response) {
    final status = response?.statusCode ?? 0;
    final body = response?.data;
    final error = body is Map
        ? ApiErrorModel.fromJson(Map<String, dynamic>.from(body))
        : null;
    final message = error?.displayMessage;

    return switch (status) {
      400 || 422 => ValidationException(
        message ?? 'Los datos enviados no son válidos.',
        error,
      ),
      401 => UnauthorizedException(message ?? 'Credenciales inválidas.', error),
      403 => ForbiddenException(
        message ?? 'No tienes permisos para realizar esta acción.',
        error,
      ),
      404 => NotFoundException(
        message ?? 'El recurso solicitado no existe.',
        error,
      ),
      409 => ConflictException(message ?? 'El recurso ya existe.', error),
      >= 500 => ServerException(
        message ?? 'El servidor no pudo procesar la solicitud.',
        error,
      ),
      _ => UnexpectedApiException(
        message ?? 'Respuesta inesperada del servidor (HTTP $status).',
        error,
      ),
    };
  }
}
