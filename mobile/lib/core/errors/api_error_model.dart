/// Modelo del cuerpo de error que devuelve el API Gateway.
///
/// Sigue el formato por defecto de NestJS, donde `message` puede llegar como
/// texto simple (errores de negocio) o como lista de textos (errores de
/// validación de `class-validator`):
///
/// ```json
/// { "statusCode": 401, "message": "Credenciales inválidas", "error": "Unauthorized" }
/// { "statusCode": 400, "message": ["email must be an email"], "error": "Bad Request" }
/// ```
class ApiErrorModel {
  final int statusCode;
  final List<String> messages;
  final String? error;
  final String? path;

  const ApiErrorModel({
    required this.statusCode,
    required this.messages,
    this.error,
    this.path,
  });

  /// Crea una instancia a partir del cuerpo JSON de la respuesta de error.
  factory ApiErrorModel.fromJson(Map<String, dynamic> json) {
    return ApiErrorModel(
      statusCode: (json['statusCode'] as num?)?.toInt() ?? 0,
      messages: _parseMessages(json['message']),
      error: json['error'] as String?,
      path: json['path'] as String?,
    );
  }

  /// Normaliza `message`, que la API puede entregar como texto o como lista.
  static List<String> _parseMessages(Object? raw) {
    if (raw == null) return const [];
    if (raw is String) return [raw];
    if (raw is List) {
      return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }
    return [raw.toString()];
  }

  /// Serializa el modelo a un mapa JSON.
  Map<String, dynamic> toJson() {
    return {
      'statusCode': statusCode,
      'message': messages.length == 1 ? messages.first : messages,
      'error': error,
      'path': path,
    };
  }

  /// Mensaje único listo para mostrar en pantalla.
  ///
  /// Une los mensajes de validación en una sola línea, porque la UI muestra un
  /// solo banner de error por formulario.
  String get displayMessage =>
      messages.isEmpty ? (error ?? 'Error desconocido.') : messages.join('\n');

  /// Factory para generar una instancia MOCK de ejemplo.
  factory ApiErrorModel.mock({
    int statusCode = 401,
    List<String> messages = const ['Credenciales inválidas.'],
    String? error = 'Unauthorized',
    String? path = '/api/v1/auth/login',
  }) {
    return ApiErrorModel(
      statusCode: statusCode,
      messages: messages,
      error: error,
      path: path,
    );
  }

  @override
  String toString() =>
      'ApiErrorModel(statusCode: $statusCode, messages: $messages, error: $error, path: $path)';
}
