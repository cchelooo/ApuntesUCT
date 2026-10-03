import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Excepción personalizada para configuraciones inválidas del Gateway o Microservicios
class ApiConfigException implements Exception {
  final String message;
  ApiConfigException(this.message);

  @override
  String toString() => 'ApiConfigException: $message';
}

/// Configuración centralizada para la conexión con el API Gateway y Microservicios
class ApiConfig {
  static const String _envGatewayUrl = String.fromEnvironment(
    'API_GATEWAY_URL',
  );

  static const String _envCatalogUrl = String.fromEnvironment(
    'CATALOG_SERVICE_URL',
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
      if (!kIsWeb && Platform.isAndroid) {
        return validateUrl('http://10.0.2.2:3000/api/v1');
      }

      // Linux desktop, Web o desarrollo local
      return validateUrl('http://localhost:3000/api/v1');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error en la configuración del API Gateway: $e');
      }
      rethrow;
    }
  }

  /// Resuelve y valida la URL base para el Catalog Service (:3002)
  /// Mientras el Gateway no exponga el proxy a /catalog
  static String get catalogBaseUrl {
    try {
      if (_envCatalogUrl.isNotEmpty) {
        return validateUrl(_envCatalogUrl);
      }

      if (!kIsWeb && Platform.isAndroid) {
        return validateUrl('http://10.0.2.2:3002/api/v1');
      }

      return validateUrl('http://localhost:3002/api/v1');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error en la configuración del Catalog Service: $e');
      }
      rethrow;
    }
  }
}
