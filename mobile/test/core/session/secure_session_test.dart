import 'dart:async';

import 'package:apuntesuct_mobile/core/session/auth_session.dart';
import 'package:apuntesuct_mobile/core/session/session_controller.dart';
import 'package:apuntesuct_mobile/core/session/session_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/auth_session_fixture.dart';

class _BlockedStorage implements SessionStorage {
  final pendingRead = Completer<String?>();
  String? value;
  bool rejectWrite = false;
  @override
  Future<String?> read() => pendingRead.future;
  @override
  Future<void> write(String value) async {
    if (rejectWrite) throw StateError('controlled storage failure');
    this.value = value;
  }

  @override
  Future<void> delete() async {
    value = null;
  }
}

void main() {
  test('a new login supersedes a failed restoration rather than keeping its failed future', () async {
    final store = _BlockedStorage();
    final session = SessionController(store);
    addTearDown(session.dispose);
    final failed = expectLater(session.restore(), throwsStateError);
    store.pendingRead.completeError(StateError('controlled read failure'));
    await failed;
    await session.accept(
      AuthSession.fromLogin(loginFixture(), DateTime.now()),
      session.beginLogin(),
    );
    await session.restore();
    expect(session.current?.user.email, 'estudiante@alu.uct.cl');
  });
  test('secure adapter restores a valid session across controller instances and deletes only its key', () async {
    FlutterSecureStorage.setMockInitialValues({'another-feature': 'keep'});
    final store = SecureSessionStorage(gatewayUrl: 'https://a.test/api/v1');
    final session = SessionController(store);
    final fixture = loginFixture();
    await session.accept(
      AuthSession.fromLogin(fixture, DateTime.now()),
      session.beginLogin(),
    );
    session.dispose();
    final restarted = SessionController(
      SecureSessionStorage(gatewayUrl: 'https://a.test/api/v1/'),
    );
    addTearDown(restarted.dispose);
    await restarted.restore();
    expect(restarted.current?.user.email, 'estudiante@alu.uct.cl');
    expect(restarted.current?.accessToken, fixture['accessToken']);
    await restarted.clear();
    final again = SessionController(store);
    addTearDown(again.dispose);
    await again.restore();
    expect(again.current, isNull);
    expect(
      await const FlutterSecureStorage().read(key: 'another-feature'),
      'keep',
    );
  });

  test(
    'tokens saved for one Gateway cannot restore into another environment',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final first = SecureSessionStorage(gatewayUrl: 'https://a.test/api/v1');
      await first.write(
        AuthSession.fromLogin(loginFixture(), DateTime.now()).encode(),
      );
      expect(
        await SecureSessionStorage(gatewayUrl: 'https://b.test/api/v1').read(),
        isNull,
      );
    },
  );

  for (final data in [
    'broken-json',
    AuthSession.fromLogin(loginFixture(), DateTime.now()).encode(),
  ]) {
    test(
      'corrupt or expired saved values are deleted rather than restored: ${data == 'broken-json' ? 'corrupt' : 'expired'}',
      () async {
        final store = MemorySessionStorage();
        await store.write(data);
        final session = SessionController(
          store,
          now: () => DateTime.now().add(const Duration(days: 1)),
        );
        addTearDown(session.dispose);
        await session.restore();
        expect(session.current, isNull);
        expect(await store.read(), isNull);
      },
    );
  }

  test(
    'logout during a pending restore cannot revive saved credentials',
    () async {
      final store = _BlockedStorage();
      final session = SessionController(store);
      addTearDown(session.dispose);
      final restoration = session.restore();
      final logout = session.clear();
      store.pendingRead.complete(
        AuthSession.fromLogin(loginFixture(), DateTime.now()).encode(),
      );
      await restoration;
      await logout;
      expect(session.current, isNull);
      expect(store.value, isNull);
    },
  );

  test('failed persistence never publishes an authenticated user', () async {
    final store = _BlockedStorage()..rejectWrite = true;
    final session = SessionController(store);
    addTearDown(session.dispose);
    await expectLater(
      session.accept(
        AuthSession.fromLogin(loginFixture(), DateTime.now()),
        session.beginLogin(),
      ),
      throwsStateError,
    );
    expect(session.current, isNull);
    expect(store.value, isNull);
  });
}
