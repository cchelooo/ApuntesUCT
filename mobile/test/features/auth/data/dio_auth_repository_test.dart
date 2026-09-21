import 'dart:convert';

import 'package:apuntesuct_mobile/core/errors/api_exception.dart';
import 'package:apuntesuct_mobile/core/network/api_client.dart';
import 'package:apuntesuct_mobile/features/auth/data/dio_auth_repository.dart';
import 'package:apuntesuct_mobile/features/auth/data/mock_auth_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.handler);

  final ResponseBody Function(RequestOptions options) handler;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('DioAuthRepository', () {
    test('consume POST /api/v1/auth/login y mapea el usuario real', () async {
      final adapter = _StubAdapter(
        (_) => _jsonResponse({
          'accessToken': 'header.payload.',
          'tokenType': 'Bearer',
          'expiresIn': 3600,
          'user': {
            'id': '00000000-0000-4000-8000-000000000092',
            'name': 'Estudiante de prueba',
            'email': 'estudiante@alu.uct.cl',
            'role': 'STUDENT',
            'active': true,
          },
        }),
      );
      final repository = _repository(adapter);

      final user = await repository.login(
        email: '  ESTUDIANTE@ALU.UCT.CL  ',
        password: 'demo',
      );

      expect(adapter.lastRequest?.method, 'POST');
      expect(
        adapter.lastRequest?.uri.toString(),
        'http://localhost:3000/api/v1/auth/login',
      );
      expect(adapter.lastRequest?.data, {
        'email': 'estudiante@alu.uct.cl',
        'password': 'demo',
      });
      expect(user.name, 'Estudiante de prueba');
      expect(user.email, 'estudiante@alu.uct.cl');
      expect(user.role, 'STUDENT');
    });

    test('expone el mensaje del Gateway cuando el login falla', () async {
      final adapter = _StubAdapter(
        (_) => _jsonResponse({
          'statusCode': 400,
          'message':
              'password must contain at least one non-whitespace character',
          'error': 'Bad Request',
        }, statusCode: 400),
      );
      final repository = _repository(adapter);

      await expectLater(
        repository.login(email: 'estudiante@alu.uct.cl', password: '   '),
        throwsA(
          isA<ApiException>()
              .having((error) => error.statusCode, 'statusCode', 400)
              .having(
                (error) => error.message,
                'message',
                'password must contain at least one non-whitespace character',
              ),
        ),
      );
    });

    test('rechaza una respuesta exitosa que no contiene user', () async {
      final adapter = _StubAdapter(
        (_) => _jsonResponse({
          'accessToken': 'header.payload.',
          'tokenType': 'Bearer',
          'expiresIn': 3600,
        }),
      );
      final repository = _repository(adapter);

      await expectLater(
        repository.login(email: 'estudiante@alu.uct.cl', password: 'demo'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.message,
            'message',
            'El servidor devolvió una respuesta de login inválida.',
          ),
        ),
      );
    });
  });
}

DioAuthRepository _repository(_StubAdapter adapter) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'http://localhost:3000/api/v1',
      validateStatus: (status) => status != null && status < 400,
    ),
  )..httpClientAdapter = adapter;

  return DioAuthRepository(
    ApiClient(customDio: dio),
    const MockAuthRepository(simulatedDelay: Duration.zero),
  );
}

ResponseBody _jsonResponse(Map<String, dynamic> body, {int statusCode = 200}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}
