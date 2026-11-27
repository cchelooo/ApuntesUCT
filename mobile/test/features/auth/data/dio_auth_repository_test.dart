import 'dart:convert';

import 'package:apuntesuct_mobile/core/errors/api_exception.dart';
import 'package:apuntesuct_mobile/core/network/api_client.dart';
import 'package:apuntesuct_mobile/features/auth/data/dio_auth_repository.dart';
import 'package:apuntesuct_mobile/features/auth/data/mock_auth_repository.dart';
import 'package:apuntesuct_mobile/models/user_model.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/auth_session_fixture.dart';

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
      final adapter = _StubAdapter((_) => _jsonResponse(loginFixture()));
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

    test('expone un mensaje comprensible de validación cuando el login falla con 400', () async {
      final adapter = _StubAdapter(
        (_) => _jsonResponse({
          'statusCode': 400,
          'message': 'Validation failed: unexpected backend text',
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
                'Los datos ingresados no son válidos. Revisa tu correo institucional y contraseña.',
              ),
        ),
      );
    });

    test('distingue credenciales incorrectas (401) de problemas de conexión o servidor (502)', () async {
      final unauthorizedAdapter = _StubAdapter(
        (_) => _jsonResponse({
          'statusCode': 401,
          'message': 'Credenciales inválidas',
          'error': 'Unauthorized',
        }, statusCode: 401),
      );
      final unauthorizedRepo = _repository(unauthorizedAdapter);

      await expectLater(
        unauthorizedRepo.login(
          email: 'estudiante@alu.uct.cl',
          password: 'incorrecta',
        ),
        throwsA(
          isA<ApiException>()
              .having((error) => error.statusCode, 'statusCode', 401)
              .having(
                (error) => error.message,
                'message',
                'Credenciales inválidas. Verifica tu correo institucional y contraseña.',
              ),
        ),
      );

      final unavailableAdapter = _StubAdapter(
        (_) => _jsonResponse({
          'statusCode': 502,
          'message': 'Auth Service no disponible',
        }, statusCode: 502),
      );
      final unavailableRepo = _repository(unavailableAdapter);

      await expectLater(
        unavailableRepo.login(
          email: 'estudiante@alu.uct.cl',
          password: 'demo',
        ),
        throwsA(
          isA<ApiException>()
              .having((error) => error.statusCode, 'statusCode', 502)
              .having(
                (error) => error.message,
                'message',
                'El servicio de autenticación no está disponible en este momento. Intenta nuevamente más tarde.',
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
            'No se pudo establecer una sesión válida y segura.',
          ),
        ),
      );
    });

    test('registra por Gateway sin abrir sesión ni delegar al mock', () async {
      final fallback = _FallbackSpy();
      final repository = _repository(
        _StubAdapter(
          (_) => _jsonResponse({
            'user': loginFixture(email: 'camila.soto@uct.cl')['user'],
          }),
        ),
        fallback: fallback,
      );

      final registeredUser = await repository.register(
        name: 'Camila Soto',
        email: 'camila.soto@uct.cl',
        password: 'Apuntes2026',
      );
      await expectLater(
        repository.getCurrentUser(),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)),
      );
      await repository.logout();

      expect(registeredUser.email, 'camila.soto@uct.cl');
      expect(fallback.registerCalls, 0);
      expect(fallback.currentUserCalls, 0);
      expect(fallback.logoutCalls, 0);
    });
  });
}

DioAuthRepository _repository(
  _StubAdapter adapter, {
  AuthRepository? fallback,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'http://localhost:3000/api/v1',
      validateStatus: (status) => status != null && status < 400,
    ),
  )..httpClientAdapter = adapter;

  final client = ApiClient(customDio: dio);
  addTearDown(client.session.dispose);
  return DioAuthRepository(
    client,
    fallback ?? const MockAuthRepository(simulatedDelay: Duration.zero),
  );
}

class _FallbackSpy implements AuthRepository {
  int registerCalls = 0;
  int currentUserCalls = 0;
  int logoutCalls = 0;

  @override
  Future<UserModel> login({required String email, required String password}) {
    throw UnimplementedError();
  }

  @override
  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
  }) async {
    registerCalls++;
    return UserModel.mock(name: name, email: email);
  }

  @override
  Future<UserModel> getCurrentUser() async {
    currentUserCalls++;
    return UserModel.mock(email: 'current@uct.cl');
  }

  @override
  Future<void> logout() async {
    logoutCalls++;
  }
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
