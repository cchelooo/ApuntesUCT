import 'dart:async';
import 'dart:convert';

import 'package:apuntesuct_mobile/core/network/api_client.dart';
import 'package:apuntesuct_mobile/core/session/session_controller.dart';
import 'package:apuntesuct_mobile/core/session/session_storage.dart';
import 'package:apuntesuct_mobile/features/auth/data/mock_auth_repository.dart';
import 'package:apuntesuct_mobile/main.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/auth_session_fixture.dart';

class _Gateway implements HttpClientAdapter {
  Completer<void>? pending;
  int loginStatus = 401;
  bool authorized = false;
  @override
  Future<ResponseBody> fetch(
    RequestOptions request,
    Stream<List<int>>? stream,
    Future<void>? cancel,
  ) async {
    if (request.path == '/auth/login') {
      await pending?.future;
      return _json(
        loginStatus == 200
            ? loginFixture(name: 'Identidad real de prueba')
            : {'message': 'Credenciales inválidas'},
        loginStatus,
      );
    }
    authorized =
        request.headers['Authorization'] is String &&
        (request.headers['Authorization'] as String).startsWith('Bearer ');
    return _json({'message': 'Token rechazado'}, 401);
  }

  ResponseBody _json(Object data, int status) => ResponseBody.fromString(
    jsonEncode(data),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
  @override
  void close({bool force = false}) {}
}

void main() {
  testWidgets(
    'private routes, rejected login, pending state, identity, 401 and logout use production providers',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final gateway = _Gateway();
      final container = ProviderContainer(
        overrides: [
          sessionStorageProvider.overrideWithValue(MemorySessionStorage()),
          apiclientProvider.overrideWith((ref) {
            final client = ApiClient(
              baseUrl: 'https://gateway.test/api/v1',
              session: ref.watch(sessionControllerProvider),
            );
            client.dio.httpClientAdapter = gateway;
            ref.onDispose(() => client.dio.close(force: true));
            return client;
          }),
        ],
      );
      addTearDown(() {
        appRouter.go('/login');
        container.dispose();
      });
      appRouter.go('/profile');
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const MyApp()),
      );
      await _settle(tester);
      expect(appRouter.state.uri.path, '/login');
      for (final path in [
        '/',
        '/profile',
        '/library',
        '/favorites',
        '/materials/upload',
      ]) {
        appRouter.go(path);
        await _settle(tester);
        expect(appRouter.state.uri.path, '/login');
      }
      await tester.enterText(find.byType(TextFormField).first, 'estudiante');
      await tester.enterText(find.byType(TextFormField).last, 'incorrecta');
      await tester.tap(find.text('Ingresar'));
      await _settle(tester);
      expect(
        find.text(
          'Credenciales inválidas. Verifica tu correo institucional y contraseña.',
        ),
        findsOneWidget,
      );
      expect(container.read(sessionControllerProvider).current, isNull);
      expect(appRouter.state.uri.path, '/login');

      gateway.loginStatus = 200;
      gateway.pending = Completer<void>();
      await tester.tap(find.text('Ingresar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(container.read(authStateProvider).isLoading, isTrue);
      gateway.pending!.complete();
      await _settle(tester);
      expect(appRouter.state.uri.path, '/');
      appRouter.go('/profile');
      await _settle(tester);
      expect(find.text('Identidad real de prueba'), findsOneWidget);
      Object? rejection;
      container
          .read(apiclientProvider)
          .dio
          .get('/quality/favorites')
          .then<void>(
            (_) {},
            onError: (Object error) {
              rejection = error;
            },
          );
      await _settle(tester);
      expect(rejection, isA<DioException>());
      expect(gateway.authorized, isTrue);
      await _settle(tester);
      expect(appRouter.state.uri.path, '/login');
      expect(await container.read(sessionStorageProvider).read(), isNull);

      unawaited(
        container
            .read(authStateProvider.notifier)
            .login('estudiante@alu.uct.cl', 'correcta'),
      );
      await _settle(tester);
      expect(appRouter.state.uri.path, '/');
      await tester.tap(find.byTooltip('Cerrar sesión'));
      await _settle(tester);
      expect(appRouter.state.uri.path, '/login');
      expect(container.read(authStateProvider).asData?.value, isNull);
      appRouter.go('/profile');
      await _settle(tester);
      expect(appRouter.state.uri.path, '/login');
    },
  );
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}
