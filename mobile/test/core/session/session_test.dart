import 'dart:async';
import 'dart:convert';

import 'package:apuntesuct_mobile/core/network/api_client.dart';
import 'package:apuntesuct_mobile/core/session/auth_session.dart';
import 'package:apuntesuct_mobile/core/session/session_controller.dart';
import 'package:apuntesuct_mobile/core/session/session_storage.dart';
import 'package:apuntesuct_mobile/features/auth/data/dio_auth_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/auth_session_fixture.dart';

class _Transport implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  int status = 200;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? stream,
    Future<void>? cancel,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(
        options.path.endsWith('/auth/login')
            ? loginFixture()
            : {'message': 'controlled'},
      ),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test(
    'login attaches its token only inside the Gateway API boundary',
    () async {
      final transport = _Transport();
      final client = ApiClient(baseUrl: 'https://gateway.test/api/v1');
      client.dio.httpClientAdapter = transport;
      addTearDown(client.session.dispose);
      await DioAuthRepository(client)
          .login(email: 'estudiante@alu.uct.cl', password: 'secret');
      final token = client.session.current!.accessToken;
      expect(transport.requests.single.headers['Authorization'], isNull);
      await client.dio.get('/quality/favorites');
      expect(
        transport.requests.last.uri.toString(),
        'https://gateway.test/api/v1/quality/favorites',
      );
      expect(transport.requests.last.headers['Authorization'], 'Bearer $token');
      for (final path in [
        'https://storage.test/file',
        'https://gateway.test/api/v10/file',
        '/auth/register',
      ]) {
        await client.dio.get(path);
        expect(transport.requests.last.headers['Authorization'], isNull);
      }
      expect(client.session.toString(), isNot(contains(token)));
      expect(client.session.current.toString(), isNot(contains(token)));
    },
  );

  for (final status in [401, 403, 502]) {
    test(
      'HTTP $status ${status == 401 ? 'clears' : 'preserves'} the current session',
      () async {
        final client = ApiClient(baseUrl: 'https://gateway.test/api/v1');
        final transport = _Transport();
        client.dio.httpClientAdapter = transport;
        addTearDown(client.session.dispose);
        await DioAuthRepository(client)
            .login(email: 'estudiante@alu.uct.cl', password: 'secret');
        transport.status = status;
        await expectLater(
          client.dio.get('/quality/favorites'),
          throwsA(isA<DioException>()),
        );
        expect(client.session.current == null, status == 401);
      },
    );
  }

  test('invalid, mock, expired or inconsistent credentials cannot create a session', () {
    final now = DateTime.utc(2026, 11, 17);
    final cases = [
      {...loginFixture(now: now), 'accessToken': 'mock-token'},
      loginFixture(now: now, lifetime: Duration.zero),
      loginFixture(now: now)..['user']['active'] = false,
      loginFixture(now: now)..['user']['id'] = 'another-user',
      loginFixture(now: now)..['user']['role'] = 'ADMIN',
      {...loginFixture(now: now), 'tokenType': 'Basic'},
    ];
    for (final json in cases) {
      expect(() => AuthSession.fromLogin(json, now), throwsFormatException);
    }
  });

  test(
    'logout invalidates an in-flight login and removes stored credentials',
    () async {
      final storage = MemorySessionStorage();
      final session = SessionController(storage);
      addTearDown(session.dispose);
      final generation = session.beginLogin();
      await session.clear();
      expect(
        await session.accept(
          AuthSession.fromLogin(loginFixture(), DateTime.now()),
          generation,
        ),
        isFalse,
      );
      expect(session.current, isNull);
      expect(await storage.read(), isNull);
    },
  );

  test(
    'a late 401 from a previous identity cannot close a newer session',
    () async {
      final session = SessionController(MemorySessionStorage());
      addTearDown(session.dispose);
      final first = AuthSession.fromLogin(loginFixture(), DateTime.now());
      await session.accept(first, session.beginLogin());
      final next = AuthSession.fromLogin(
        loginFixture(email: 'otro@uct.cl'),
        DateTime.now(),
      );
      await session.accept(next, session.beginLogin());
      await session.rejectCredential(first.accessToken);
      expect(session.current?.user.email, 'otro@uct.cl');
    },
  );

  test(
    'expiration clears memory and persisted session without an HTTP request',
    () async {
      final storage = MemorySessionStorage();
      var now = DateTime.utc(2026, 11, 17);
      final session = SessionController(storage, now: () => now);
      addTearDown(session.dispose);
      await session.accept(
        AuthSession.fromLogin(loginFixture(now: now), now),
        session.beginLogin(),
      );
      now = now.add(const Duration(hours: 2));
      expect(session.current, isNull);
      await Future<void>.delayed(Duration.zero);
      expect(await storage.read(), isNull);
    },
  );
}
