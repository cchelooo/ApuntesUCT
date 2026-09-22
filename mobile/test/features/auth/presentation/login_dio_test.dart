import 'dart:async';
import 'dart:convert';

import 'package:apuntesuct_mobile/core/network/api_client.dart';
import 'package:apuntesuct_mobile/features/auth/data/auth_repository.dart';
import 'package:apuntesuct_mobile/features/auth/data/mock_auth_repository.dart'
    show authRepositoryProvider;
import 'package:apuntesuct_mobile/features/auth/presentation/login_screen.dart';
import 'package:apuntesuct_mobile/models/user_model.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;
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
  group('Login con Dio (#63)', () {
    testWidgets('envía el contrato esperado y navega tras respuesta exitosa', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final adapter = _StubAdapter(
        (_) async => _jsonResponse({
          'accessToken': 'header.payload.',
          'tokenType': 'Bearer',
          'expiresIn': 3600,
          'user': {
            'id': '00000000-0000-4000-8000-000000000092',
            'name': 'Estudiante de prueba',
            'email': 'estudiante2026@alu.uct.cl',
            'role': 'STUDENT',
            'active': true,
          },
        }),
      );
      final router = _router();
      addTearDown(router.dispose);

      await tester.pumpWidget(_testApp(router: router, adapter: adapter));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).first,
        'Estudiante2026',
      );
      await tester.enterText(find.byType(TextFormField).last, 'demo');
      await tester.tap(find.widgetWithText(FilledButton, 'Ingresar'));
      await tester.pumpAndSettle();

      expect(adapter.lastRequest?.method, 'POST');
      expect(
        adapter.lastRequest?.uri.toString(),
        'http://localhost:3000/api/v1/auth/login',
      );
      expect(adapter.lastRequest?.data, {
        'email': 'estudiante2026@alu.uct.cl',
        'password': 'demo',
      });

      expect(find.text('HOME_AUTENTICADO'), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    });

    testWidgets(
      'mantiene el botón en loading mientras el login está pendiente',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final repository = _PendingAuthRepository();
        final adapter = _StubAdapter(
          (_) => throw StateError('Dio no debe ejecutarse con el override'),
        );
        final router = _router();
        addTearDown(router.dispose);

        await tester.pumpWidget(
          _testApp(router: router, adapter: adapter, repository: repository),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byType(TextFormField).first,
          'estudiante2026',
        );
        await tester.enterText(find.byType(TextFormField).last, 'demo');
        await tester.tap(find.widgetWithText(FilledButton, 'Ingresar'));
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.byType(LoginScreen), findsOneWidget);

        repository.completeLogin();
        await tester.pumpAndSettle();

        expect(find.text('HOME_AUTENTICADO'), findsOneWidget);
      },
    );

    testWidgets('muestra el error del Gateway y permanece en Login', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final adapter = _StubAdapter(
        (_) async => _jsonResponse({
          'statusCode': 400,
          'message': 'Credenciales inválidas',
          'error': 'Bad Request',
        }, statusCode: 400),
      );
      final router = _router();
      addTearDown(router.dispose);

      await tester.pumpWidget(_testApp(router: router, adapter: adapter));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).first,
        'estudiante2026',
      );
      await tester.enterText(find.byType(TextFormField).last, 'incorrecta');
      await tester.tap(find.widgetWithText(FilledButton, 'Ingresar'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Credenciales inválidas'), findsOneWidget);
      expect(find.text('HOME_AUTENTICADO'), findsNothing);
    });
  });
}

class _PendingAuthRepository implements AuthRepository {
  final _loginResult = Completer<UserModel>();

  void completeLogin() {
    _loginResult.complete(
      UserModel.mock(
        email: 'estudiante2026@alu.uct.cl',
        name: 'Estudiante de prueba',
      ),
    );
  }

  @override
  Future<UserModel> login({required String email, required String password}) {
    return _loginResult.future;
  }

  @override
  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<UserModel> getCurrentUser() {
    throw UnimplementedError();
  }

  @override
  Future<void> logout() {
    throw UnimplementedError();
  }
}

Widget _testApp({
  required GoRouter router,
  required _StubAdapter adapter,
  AuthRepository? repository,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'http://localhost:3000/api/v1',
      validateStatus: (status) => status != null && status < 400,
    ),
  )..httpClientAdapter = adapter;

  return ProviderScope(
    overrides: [
      apiclientProvider.overrideWith((ref) => ApiClient(customDio: dio)),
      if (repository != null)
        authRepositoryProvider.overrideWithValue(repository),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

GoRouter _router() {
  return GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/',
        builder: (context, state) =>
            const Scaffold(body: Text('HOME_AUTENTICADO')),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const Scaffold(body: Text('REGISTRO')),
      ),
    ],
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
