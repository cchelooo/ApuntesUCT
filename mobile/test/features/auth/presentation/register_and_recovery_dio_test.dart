import 'dart:convert';

import 'package:apuntesuct_mobile/core/network/api_client.dart';
import 'package:apuntesuct_mobile/features/auth/data/mock_auth_repository.dart'
    show authDemoModeProvider;
import 'package:apuntesuct_mobile/features/auth/presentation/forgot_password_screen.dart';
import 'package:apuntesuct_mobile/features/auth/presentation/login_screen.dart';
import 'package:apuntesuct_mobile/features/auth/presentation/register_screen.dart';
import 'package:apuntesuct_mobile/features/auth/presentation/reset_password_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../helpers/auth_session_fixture.dart';

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;
  final List<RequestOptions> requests = [];

  RequestOptions? get lastRequest => requests.isEmpty ? null : requests.last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('Registro institucional real y validaciones (#392)', () {
    testWidgets(
      'solicita y envía únicamente name, email y password, acepta contraseñas de 8+ caracteres sin exigir números y redirige a Login sin abrir sesión',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final adapter = _StubAdapter((options) async {
          return _jsonResponse({
            'user': loginFixture(
              name: 'Camila Soto',
              email: 'csoto2024@alu.uct.cl',
            )['user'],
          }, statusCode: 201);
        });
        final router = _router(initialLocation: '/register');
        addTearDown(router.dispose);

        await tester.pumpWidget(_testApp(router: router, adapter: adapter));
        await tester.pumpAndSettle();

        final fields = find.byType(TextFormField);
        expect(fields, findsNWidgets(4));

        // Contraseña de solo letras y espacios internos (válida según contrato S3-01)
        await tester.enterText(fields.at(0), '  Camila Soto  ');
        await tester.enterText(fields.at(1), 'CSOTO2024');
        await tester.enterText(fields.at(2), 'una clave institucional');
        await tester.enterText(fields.at(3), 'una clave institucional');
        await tester.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
        await tester.pumpAndSettle();

        expect(adapter.lastRequest?.method, 'POST');
        expect(
          adapter.lastRequest?.uri.toString(),
          'http://localhost:3000/api/v1/auth/register',
        );
        expect(adapter.lastRequest?.data, {
          'name': 'Camila Soto',
          'email': 'csoto2024@alu.uct.cl',
          'password': 'una clave institucional',
        });

        // Continúa al paso de acceso (Login) y no simula una sesión autenticada
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(
          find.text('Cuenta creada. Inicia sesión para continuar.'),
          findsAtLeastNWidgets(1),
        );
        expect(find.text('HOME_AUTENTICADO'), findsNothing);
      },
    );

    testWidgets(
      'valida requisitos institucionales y muestra error 409 o 400 sin perder lo escrito en el formulario',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        var statusToReturn = 409;
        final adapter = _StubAdapter((_) async {
          if (statusToReturn == 409) {
            return _jsonResponse({
              'statusCode': 409,
              'message': 'El correo ya está registrado',
              'error': 'Conflict',
            }, statusCode: 409);
          }
          return _jsonResponse({
            'statusCode': 400,
            'message': 'Datos inválidos',
            'error': 'Bad Request',
          }, statusCode: 400);
        });
        final router = _router(initialLocation: '/register');
        addTearDown(router.dispose);

        await tester.pumpWidget(_testApp(router: router, adapter: adapter));
        await tester.pumpAndSettle();

        final fields = find.byType(TextFormField);

        // 1. Validación local: contraseña de solo espacios o corta
        await tester.enterText(fields.at(0), 'ab');
        await tester.enterText(fields.at(1), 'camila');
        await tester.enterText(fields.at(2), '        ');
        await tester.enterText(fields.at(3), '        ');
        await tester.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
        await tester.pump();

        expect(
          find.text('El nombre debe tener al menos 3 caracteres.'),
          findsOneWidget,
        );
        expect(
          find.text('La contraseña no puede contener sólo espacios.'),
          findsOneWidget,
        );
        expect(adapter.lastRequest, isNull);

        // 2. Rechazo 409 del servidor conservando los textos ingresados
        await tester.enterText(fields.at(0), 'Camila Soto');
        await tester.enterText(fields.at(1), 'camila.soto');
        await tester.enterText(fields.at(2), 'claveSegura2026');
        await tester.enterText(fields.at(3), 'claveSegura2026');
        await tester.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
        await tester.pumpAndSettle();

        expect(find.byType(RegisterScreen), findsOneWidget);
        expect(
          find.text(
            'El correo institucional ya está registrado. Inicia sesión o recupera tu contraseña.',
          ),
          findsOneWidget,
        );
        expect(
          tester.widget<TextFormField>(fields.at(0)).controller?.text,
          'Camila Soto',
        );
        expect(
          tester.widget<TextFormField>(fields.at(1)).controller?.text,
          'camila.soto',
        );
        expect(
          tester.widget<TextFormField>(fields.at(2)).controller?.text,
          'claveSegura2026',
        );

        // 3. Rechazo 400 del servidor conservando los datos
        statusToReturn = 400;
        await tester.ensureVisible(
          find.widgetWithText(FilledButton, 'Crear cuenta'),
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Los datos ingresados no son válidos. Revisa tu nombre, correo institucional y contraseña.',
          ),
          findsOneWidget,
        );
        expect(
          tester.widget<TextFormField>(fields.at(0)).controller?.text,
          'Camila Soto',
        );
      },
    );
  });

  group('Recuperación de contraseña y navegación del flujo (#393)', () {
    testWidgets(
      'abre recuperación desde Login, muestra confirmación genérica del servidor, permite restablecer con token temporal y vuelve al acceso',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final validToken = 'a1b2c3d4' * 8; // 64 hex chars
        final adapter = _StubAdapter((options) async {
          if (options.path.endsWith('/auth/forgot-password')) {
            return _jsonResponse({
              'message':
                  'Si el correo corresponde a una cuenta habilitada, recibirás instrucciones para recuperar tu contraseña.',
            });
          }
          if (options.path.endsWith('/auth/reset-password')) {
            return _jsonResponse({
              'message': 'Contraseña restablecida correctamente.',
            });
          }
          throw StateError('Ruta inesperada: ${options.path}');
        });
        final router = _router(initialLocation: '/login');
        addTearDown(router.dispose);

        await tester.pumpWidget(_testApp(router: router, adapter: adapter));
        await tester.pumpAndSettle();

        // 1. Abrir recuperación desde Login
        await tester.tap(find.text('¿Olvidaste tu contraseña?'));
        await tester.pumpAndSettle();
        expect(find.byType(ForgotPasswordScreen), findsOneWidget);

        // Volver a Login y regresar a recuperación para verificar navegación bidireccional
        await tester.tap(find.text('Volver al inicio de sesión'));
        await tester.pumpAndSettle();
        expect(find.byType(LoginScreen), findsOneWidget);

        await tester.tap(find.text('¿Olvidaste tu contraseña?'));
        await tester.pumpAndSettle();
        expect(find.byType(ForgotPasswordScreen), findsOneWidget);

        // 2. Solicitar recuperación
        await tester.enterText(find.byType(TextFormField), 'csoto2024');
        await tester.tap(
          find.widgetWithText(FilledButton, 'Enviar instrucciones'),
        );
        await tester.pumpAndSettle();

        expect(
          adapter.lastRequest?.uri.toString(),
          'http://localhost:3000/api/v1/auth/forgot-password',
        );
        expect(adapter.lastRequest?.data, {'email': 'csoto2024@alu.uct.cl'});
        expect(
          find.text(
            'Si el correo corresponde a una cuenta habilitada, recibirás instrucciones para recuperar tu contraseña.',
          ),
          findsOneWidget,
        );

        // 3. Continuar a la pantalla de restablecimiento
        await tester.tap(find.text('Ingresar código y nueva contraseña'));
        await tester.pumpAndSettle();
        expect(find.byType(ResetPasswordScreen), findsOneWidget);

        // 4. Ingresar enlace con token de 64 caracteres y nueva contraseña
        final resetFields = find.byType(TextFormField);
        expect(resetFields, findsNWidgets(3));

        await tester.enterText(
          resetFields.at(0),
          'https://apuntes.uct.cl/reset-password?token=${validToken.toUpperCase()}',
        );
        await tester.enterText(resetFields.at(1), 'nueva clave institucional');
        await tester.enterText(resetFields.at(2), 'nueva clave institucional');
        await tester.tap(
          find.widgetWithText(FilledButton, 'Actualizar contraseña'),
        );
        await tester.pumpAndSettle();

        expect(
          adapter.lastRequest?.uri.toString(),
          'http://localhost:3000/api/v1/auth/reset-password',
        );
        expect(adapter.lastRequest?.data, {
          'token': validToken,
          'password': 'nueva clave institucional',
        });

        // 5. Regresa a Login con confirmación
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(
          find.text(
            'Contraseña restablecida correctamente. Inicia sesión con tu nueva contraseña.',
          ),
          findsAtLeastNWidgets(1),
        );
      },
    );

    testWidgets(
      'maneja token vencido con opción para solicitar uno nuevo y expone integración pendiente si el servicio no está disponible (502)',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final expiredToken = 'f' * 64;
        final adapter = _StubAdapter((options) async {
          if (options.path.endsWith('/auth/reset-password')) {
            return _jsonResponse({
              'statusCode': 400,
              'message': 'El token es inválido o ha expirado.',
              'error': 'Bad Request',
            }, statusCode: 400);
          }
          if (options.path.endsWith('/auth/forgot-password')) {
            return _jsonResponse({
              'statusCode': 502,
              'message': 'Auth Service no disponible',
            }, statusCode: 502);
          }
          throw StateError('Ruta inesperada: ${options.path}');
        });
        final router = _router(initialLocation: '/reset-password');
        addTearDown(router.dispose);

        await tester.pumpWidget(_testApp(router: router, adapter: adapter));
        await tester.pumpAndSettle();

        final resetFields = find.byType(TextFormField);
        await tester.enterText(resetFields.at(0), expiredToken);
        await tester.enterText(resetFields.at(1), 'claveValida2026');
        await tester.enterText(resetFields.at(2), 'claveValida2026');
        await tester.tap(
          find.widgetWithText(FilledButton, 'Actualizar contraseña'),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(
            'El código o enlace de recuperación es inválido, ya fue utilizado o ha expirado. Solicita uno nuevo para continuar.',
          ),
          findsOneWidget,
        );

        // Opción comprensible para reintentar solicitando un nuevo código
        await tester.tap(
          find.text('Solicitar un nuevo código de recuperación'),
        );
        await tester.pumpAndSettle();

        expect(find.byType(ForgotPasswordScreen), findsOneWidget);
        expect(
          find.text(
            'Solicita un nuevo código temporal para restablecer tu contraseña.',
          ),
          findsOneWidget,
        );

        // Si la API o el envío de correo no están disponibles (502), se informa explícitamente
        await tester.enterText(find.byType(TextFormField), 'csoto2024');
        await tester.tap(
          find.widgetWithText(FilledButton, 'Enviar instrucciones'),
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining('La integración permanece pendiente'),
          findsOneWidget,
        );
      },
    );
  });
}

Widget _testApp({required GoRouter router, required _StubAdapter adapter}) {
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
      authDemoModeProvider.overrideWithValue(false),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

GoRouter _router({required String initialLocation}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginScreen(
          initialSuccessMessage: state.uri.queryParameters['notice'],
        ),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => ForgotPasswordScreen(
          initialNotice: state.uri.queryParameters['notice'],
        ),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) => ResetPasswordScreen(
          initialToken: state.uri.queryParameters['token'],
        ),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) =>
            const Scaffold(body: Text('HOME_AUTENTICADO')),
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
