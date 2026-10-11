import 'package:flutter/foundation.dart';

/// Excepción personalizada para configuraciones inválidas del Gateway.
class ApiConfigException implements Exception {
  final String message;
  ApiConfigException(this.message);

  @override
  String toString() => 'ApiConfigException: $message';
}

/// Configuración centralizada para la única entrada HTTP pública de Mobile.
class ApiConfig {
  static const String _envGatewayUrl = String.fromEnvironment(
    'API_GATEWAY_URL',
  );

  /// Valida que la URL tenga formato válido (esquema http/https y host presente)
  static String validateUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      throw ApiConfigException(
        'La URL base configurada "$url" no es válida. Debe incluir esquema (http:// o https://) y host.',
      );
    }
    return url;
  }

  /// Resuelve y valida la URL base adecuada según el entorno y plataforma para el Gateway (:3000)
  static String get gatewayBaseUrl {
    try {
      if (_envGatewayUrl.isNotEmpty) {
        return validateUrl(_envGatewayUrl);
      }

      // Android emulador utiliza 10.0.2.2 para mapear el localhost del host
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        return validateUrl('http://10.0.2.2:3000/api/v1');
      }

      // Simulador iOS, escritorio, Web o desarrollo local.
      return validateUrl('http://localhost:3000/api/v1');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error en la configuración del API Gateway: $e');
      }
      rethrow;
    }
  }
}
