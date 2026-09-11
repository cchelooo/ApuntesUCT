import 'package:dio/dio.dart';

import 'api_error_model.dart';

/// Jerarquía de errores que la capa de datos expone hacia presentación.
///
/// La UI nunca debe conocer `DioException` ni códigos HTTP crudos: el cliente
/// HTTP traduce cualquier fallo a una de estas variantes, de modo que las
/// pantallas sólo decidan qué mensaje mostrar.
///
/// Al ser `sealed`, un `switch` sobre la excepción es exhaustivo y el analizador
/// avisa si se agrega una variante nueva y algún consumidor no la contempla.
sealed class ApiException implements Exception {
  /// Mensaje apto para mostrar al usuario final.
  final String message;

  /// Cuerpo de error devuelto por la API, cuando existe.
  ///
  /// Se recibe por posición y no por nombre para que las subclases puedan
  /// declararlo como parámetro `super`.
  final ApiErrorModel? error;

  const ApiException(this.message, [this.error]);

  /// Código HTTP asociado, o `null` si el fallo ocurrió antes de la respuesta.
  int? get statusCode => error?.statusCode;

  @override
  String toString() => '$runtimeType: $message';

  /// Traduce un [DioException] a la excepción de dominio más adecuada.
  ///
  /// Es el punto de compatibilidad para consumidores que no usan [ApiClient]
  /// directamente (interceptores, pruebas, handlers genéricos).
  factory ApiException.fromDioException(DioException e) {
    final status = e.response?.statusCode ?? 0;
    final body = e.response?.data;
    ApiErrorModel? error = body is Map
        ? ApiErrorModel.fromJson(Map<String, dynamic>.from(body))
        : null;
    // Si el cuerpo no trae statusCode, usamos el HTTP real para no perderlo.
    if (error != null && error.statusCode == 0 && status != 0) {
      error = ApiErrorModel(
        statusCode: status,
        messages: error.messages,
        error: error.error,
        path: error.path,
      );
    }
    final message = error?.displayMessage;

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const ApiTimeoutException(
          'Tiempo de espera agotado. Intenta nuevamente.',
        );
      case DioExceptionType.connectionError:
      case DioExceptionType.badCertificate:
        return const NetworkException(
          'No se pudo establecer conexión con el servidor.',
        );
      case DioExceptionType.cancel:
        return const RequestCancelledException('La solicitud fue cancelada.');
      case DioExceptionType.badResponse:
        return switch (status) {
          400 || 422 => ValidationException(
            message ?? 'Los datos enviados no son válidos.',
            error,
          ),
          401 => UnauthorizedException(
            message ?? 'Credenciales inválidas.',
            error,
          ),
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
      case DioExceptionType.unknown:
        return e.error is Exception
            ? const NetworkException(
              'No se pudo establecer conexión con el servidor.',
            )
            : UnexpectedApiException(
              e.message ?? 'Ocurrió un error inesperado.',
            );
    }
  }
}

/// No se pudo establecer conexión con el API Gateway (sin red, host caído,
/// DNS inválido o certificado rechazado).
class NetworkException extends ApiException {
  const NetworkException([
    super.message = 'No se pudo conectar con el servidor. Revisa tu conexión.',
  ]);
}

/// La petición superó alguno de los timeouts configurados en `AppConfig`.
class ApiTimeoutException extends ApiException {
  const ApiTimeoutException([
    super.message =
        'El servidor tardó demasiado en responder. Intenta nuevamente.',
  ]);
}

/// 400/422: el cuerpo enviado no pasó la validación del backend.
class ValidationException extends ApiException {
  const ValidationException([
    super.message = 'Los datos enviados no son válidos.',
    super.error,
  ]);
}

/// 401: credenciales inválidas o token expirado.
class UnauthorizedException extends ApiException {
  const UnauthorizedException([
    super.message = 'Credenciales inválidas.',
    super.error,
  ]);
}

/// 403: la sesión es válida pero el rol no tiene permiso sobre el recurso.
class ForbiddenException extends ApiException {
  const ForbiddenException([
    super.message = 'No tienes permisos para realizar esta acción.',
    super.error,
  ]);
}

/// 404: el recurso solicitado no existe.
class NotFoundException extends ApiException {
  const NotFoundException([
    super.message = 'El recurso solicitado no existe.',
    super.error,
  ]);
}

/// 409: conflicto de estado, por ejemplo un correo ya registrado.
class ConflictException extends ApiException {
  const ConflictException([
    super.message = 'El recurso ya existe.',
    super.error,
  ]);
}

/// 5xx: el backend falló procesando una petición válida.
class ServerException extends ApiException {
  const ServerException([
    super.message = 'El servidor no pudo procesar la solicitud.',
    super.error,
  ]);
}

/// La petición fue cancelada antes de completarse (por ejemplo, la pantalla se
/// cerró mientras la llamada estaba en curso).
class RequestCancelledException extends ApiException {
  const RequestCancelledException([
    super.message = 'La solicitud fue cancelada.',
  ]);
}

/// El registro fue exitoso pero el backend no abrió sesión (por ejemplo,
/// porque requiere verificación de correo institucional).
class RequiresVerificationException extends ApiException {
  const RequiresVerificationException([
    super.message = 'Cuenta creada. Debes iniciar sesión para continuar.',
  ]);
}

/// Fallo no clasificado: respuesta con formato inesperado o error de parseo.
class UnexpectedApiException extends ApiException {
  const UnexpectedApiException([
    super.message = 'Ocurrió un error inesperado.',
    super.error,
  ]);
}
