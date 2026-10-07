import 'package:apuntesuct_mobile/core/config/api_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const configuredGateway = String.fromEnvironment('API_GATEWAY_URL');

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('Android Emulator resuelve la entrada del Gateway del host', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(
      ApiConfig.gatewayBaseUrl,
      configuredGateway.isEmpty
          ? 'http://10.0.2.2:3000/api/v1'
          : configuredGateway,
    );
  });

  test('simulador iOS resuelve localhost del Gateway', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(
      ApiConfig.gatewayBaseUrl,
      configuredGateway.isEmpty
          ? 'http://localhost:3000/api/v1'
          : configuredGateway,
    );
  });

  test('desarrollo local conserva el mismo Gateway', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    expect(
      ApiConfig.gatewayBaseUrl,
      configuredGateway.isEmpty
          ? 'http://localhost:3000/api/v1'
          : configuredGateway,
    );
  });

  test('rechaza una configuración sin esquema, host o protocolo HTTP', () {
    for (final invalid in [
      '',
      'localhost:3000',
      'http:///api/v1',
      'ftp://example.test',
    ]) {
      expect(
        () => ApiConfig.validateUrl(invalid),
        throwsA(isA<ApiConfigException>()),
      );
    }
  });
}
