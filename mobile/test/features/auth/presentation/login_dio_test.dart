import 'dart:async';
import 'dart:convert';

import 'package:apuntesuct_mobile/core/network/api_client.dart';
import 'package:apuntesuct_mobile/features/auth/data/auth_repository.dart';
import 'package:apuntesuct_mobile/features/auth/data/mock_auth_repository.dart'
    show authDemoModeProvider, authRepositoryProvider;
import 'package:apuntesuct_mobile/features/auth/presentation/login_screen.dart';
import 'package:apuntesuct_mobile/models/user_model.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../helpers/auth_session_fixture.dart';

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
        (_) async =>
            _jsonResponse(loginFixture(email: 'estudiante2026@alu.uct.cl')),
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

    testWidgets('modo demo navega al Home sin consultar el Gateway', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final adapter = _StubAdapter(
        (_) => throw StateError('El modo demo no debe consultar el Gateway'),
      );
      final router = _router();
      addTearDown(router.dispose);

      await tester.pumpWidget(
        _testApp(router: router, adapter: adapter, demoMode: true),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).first,
        'estudiante2026',
      );
      await tester.enterText(find.byType(TextFormField).last, 'demo');
      await tester.tap(find.widgetWithText(FilledButton, 'Ingresar'));
      await tester.pumpAndSettle();

      expect(adapter.lastRequest, isNull);
      expect(find.text('HOME_AUTENTICADO'), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    });

    testWidgets('muestra el error del Gateway y permanece en Login', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final adapter = _StubAdapter(
        (_) async => _jsonResponse({
          'statusCode': 401,
          'message': 'Credenciales inválidas',
          'error': 'Unauthorized',
        }, statusCode: 401),
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
      expect(
        find.text(
          'Credenciales inválidas. Verifica tu correo institucional y contraseña.',
        ),
        findsOneWidget,
      );
      expect(find.text('HOME_AUTENTICADO'), findsNothing);
    });

    testWidgets(
      'impide envíos repetidos mientras una solicitud de login está en curso',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final pending = Completer<ResponseBody>();
        var requestCount = 0;
        final adapter = _StubAdapter((_) {
          requestCount++;
          return pending.future;
        });
        final router = _router();
        addTearDown(router.dispose);

        await tester.pumpWidget(_testApp(router: router, adapter: adapter));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byType(TextFormField).first,
          'estudiante2026',
        );
        await tester.enterText(find.byType(TextFormField).last, 'demo');

        await tester.tap(find.widgetWithText(FilledButton, 'Ingresar'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(requestCount, 1);

        // Intentos adicionales por botón o acción del teclado mientras carga
        await tester.tap(find.byType(FilledButton), warnIfMissed: false);
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(requestCount, 1);

        pending.complete(
          _jsonResponse(loginFixture(email: 'estudiante2026@alu.uct.cl')),
        );
        await tester.pumpAndSettle();

        expect(requestCount, 1);
        expect(find.text('HOME_AUTENTICADO'), findsOneWidget);
      },
    );

    testWidgets(
      'distingue errores de validación, credenciales y conexión sin exponer información sensible',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        var mode = '401';
        final adapter = _StubAdapter((options) async {
          if (mode == 'network') {
            throw DioException(
              requestOptions: options,
              type: DioExceptionType.connectionError,
              error: 'SocketException: Connection refused 10.0.2.2:3000',
            );
          }
          if (mode == '400') {
            return _jsonResponse({
              'statusCode': 400,
              'message': 'Texto arbitrario de validación del servidor',
              'error': 'Bad Request',
            }, statusCode: 400);
          }
          if (mode == '502') {
            return _jsonResponse({
              'statusCode': 502,
              'message': 'Auth Service no disponible',
            }, statusCode: 502);
          }
          return _jsonResponse({
            'statusCode': 401,
            'message': 'Credenciales inválidas',
            'error': 'Unauthorized',
          }, statusCode: 401);
        });
        final router = _router();
        addTearDown(router.dispose);

        await tester.pumpWidget(_testApp(router: router, adapter: adapter));
        await tester.pumpAndSettle();

        // 1. Error de validación local
        await tester.tap(find.widgetWithText(FilledButton, 'Ingresar'));
        await tester.pump();
        expect(find.text('El correo es obligatorio.'), findsOneWidget);
        expect(find.text('La contraseña es obligatoria.'), findsOneWidget);
        expect(adapter.lastRequest, isNull);

        // 2. Error de credenciales (401)
        await tester.enterText(
          find.byType(TextFormField).first,
          'estudiante2026',
        );
        await tester.enterText(
          find.byType(TextFormField).last,
          'ClaveSecreta99',
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Ingresar'));
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Credenciales inválidas. Verifica tu correo institucional y contraseña.',
          ),
          findsOneWidget,
        );
        expect(find.text('HOME_AUTENTICADO'), findsNothing);

        // 2b. Error 400 del servidor mapeado siempre a mensaje local de validación
        mode = '400';
        await tester.ensureVisible(
          find.widgetWithText(FilledButton, 'Ingresar'),
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Ingresar'));
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Los datos ingresados no son válidos. Revisa tu correo institucional y contraseña.',
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining('Texto arbitrario de validación del servidor'),
          findsNothing,
        );
        expect(find.text('HOME_AUTENTICADO'), findsNothing);

        // 3. Error de disponibilidad del servicio en Gateway (502)
        mode = '502';
        await tester.ensureVisible(
          find.widgetWithText(FilledButton, 'Ingresar'),
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Ingresar'));
        await tester.pumpAndSettle();

        expect(
          find.text(
            'El servicio de autenticación no está disponible en este momento. Intenta nuevamente más tarde.',
          ),
          findsOneWidget,
        );
        expect(find.text('HOME_AUTENTICADO'), findsNothing);

        // 4. Error de conexión de red
        mode = 'network';
        await tester.ensureVisible(
          find.widgetWithText(FilledButton, 'Ingresar'),
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Ingresar'));
        await tester.pumpAndSettle();

        expect(
          find.text(
            'No se pudo establecer conexión con el servidor. Verifica tu red o que el servidor esté activo.',
          ),
          findsOneWidget,
        );
        expect(find.textContaining('SocketException'), findsNothing);
        expect(find.textContaining('10.0.2.2'), findsNothing);
        expect(find.text('HOME_AUTENTICADO'), findsNothing);
      },
    );
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
  Future<String> requestPasswordRecovery({required String email}) {
    throw UnimplementedError();
  }

  @override
  Future<String> resetPassword({
    required String token,
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
  bool demoMode = false,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'http://localhost:3000/api/v1',
      validateStatus: (status) => status != null && status < 400,
    ),
  )..httpClientAdapter = adapter;

  return ProviderScope(
    overrides: [
      apiclientProvider.overrideWith((ref) {
        final client = ApiClient(customDio: dio);
        ref.onDispose(client.session.dispose);
        return client;
      }),
      authDemoModeProvider.overrideWithValue(demoMode),
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
