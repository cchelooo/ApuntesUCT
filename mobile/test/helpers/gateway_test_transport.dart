import 'dart:async';
import 'dart:convert';

import 'package:apuntesuct_mobile/core/network/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

const testGatewayUrl = 'https://gateway.example.test/api/v1';

/// Reemplaza únicamente el transporte: conserva Dio, sus interceptores y los
/// repositorios/providers de producción. No abre conexiones de red.
class GatewayTestTransport implements HttpClientAdapter {
  GatewayTestTransport(this.respond, {this.allowedMethods = const {'GET'}});

  final FutureOr<ResponseBody> Function(RequestOptions) respond;
  final Set<String> allowedMethods;
  final requests = <RequestOptions>[];
  final bodies = <List<int>>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    expect(allowedMethods, contains(options.method));
    if (options.method == 'GET') expect(options.data, isNull);
    expect(options.uri.origin, 'https://gateway.example.test');
    expect(options.headers['Authorization'], 'Bearer integration-test-session');
    bodies.add(
      requestStream == null
          ? const []
          : await requestStream.expand((chunk) => chunk).toList(),
    );
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody gatewayJson(Object? data, {int status = 200}) =>
    ResponseBody.fromString(
      jsonEncode(data),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

ProviderContainer gatewayTestContainer(
  GatewayTestTransport transport, {
  List<Override> overrides = const [],
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: testGatewayUrl,
      headers: {'Authorization': 'Bearer integration-test-session'},
    ),
  )..httpClientAdapter = transport;
  final container = ProviderContainer(
    // Cada reintento debe ser explícito y verificable en la prueba.
    retry: (retryCount, error) => null,
    overrides: [
      apiclientProvider.overrideWithValue(ApiClient(customDio: dio)),
      ...overrides,
    ],
  );
  addTearDown(() {
    container.dispose();
    dio.close(force: true);
  });
  return container;
}
