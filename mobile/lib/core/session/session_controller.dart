import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_session.dart';
import 'session_storage.dart';

final sessionControllerProvider = Provider<SessionController>((ref) {
  final controller = SessionController(ref.watch(sessionStorageProvider));
  ref.onDispose(controller.dispose);
  return controller;
});

/// Serializes storage and prevents old login/restore/HTTP results reviving a session.
class SessionController extends ChangeNotifier {
  SessionController(this.storage, {DateTime Function()? now})
    : now = now ?? DateTime.now;
  final SessionStorage storage;
  final DateTime Function() now;
  AuthSession? _current;
  bool _needsSignIn = false;

  /// Only expiry or a rejected credential prompts the user to sign in again.
  bool get needsSignIn => _needsSignIn;

  static const signInAgainMessage =
      'La sesión ya no es válida. Vuelve a iniciar sesión.';
  AuthSession? get current {
    if (_current != null && !_current!.expiresAt.isAfter(now().toUtc())) {
      final generation = ++_generation;
      _current = null;
      _needsSignIn = true;
      _timer?.cancel();
      unawaited(_serial(storage.delete).catchError((Object _) {}));
      // Reading expired credentials can happen during a widget/provider build.
      // Clear immediately, then notify without mutating providers in that build.
      scheduleMicrotask(() {
        if (!_disposed && generation == _generation) notifyListeners();
      });
    }
    return _current;
  }

  int _generation = 0;
  Timer? _timer;
  bool _disposed = false;
  Future<void> _operations = Future.value();
  Future<void>? _restoration;

  Future<T> _serial<T>(Future<T> Function() operation) {
    final result = _operations.then((_) => operation());
    _operations = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<void> restore() => _restoration ??= _restore();
  Future<void> _restore() async {
    final generation = _generation;
    final value = await _serial(storage.read);
    if (_disposed || generation != _generation || value == null) return;
    AuthSession session;
    try {
      session = AuthSession.restore(value, now());
    } on Object {
      await clear();
      return;
    }
    if (!_disposed && generation == _generation) _publish(session);
  }

  int beginLogin() {
    _needsSignIn = false;
    _restoration = Future.value();
    final generation = ++_generation;
    _publish(null);
    // Delete an older persisted identity before any new login can be committed.
    _loginCleanup = _serial(storage.delete);
    _loginCleanup.ignore();
    return generation;
  }

  Future<void> _loginCleanup = Future.value();

  Future<bool> accept(AuthSession session, int generation) async {
    await _loginCleanup;
    if (_disposed || generation != _generation) return false;
    await _serial(() => storage.write(session.encode()));
    if (_disposed || generation != _generation) return false;
    if (!session.expiresAt.isAfter(now().toUtc())) {
      await clear();
      return false;
    }
    _publish(session);
    return true;
  }

  Future<void> cancelLogin(int generation) async {
    if (!_disposed && generation == _generation) await clear();
  }

  Future<void> clear() => _clear();

  Future<void> _clear({bool needsSignIn = false}) {
    ++_generation;
    _needsSignIn = needsSignIn;
    _publish(null);
    return _serial(storage.delete);
  }

  Future<void> rejectCredential(String token) async {
    if (_current?.accessToken == token) {
      await _clear(needsSignIn: true);
    }
  }

  void _publish(AuthSession? session) {
    _timer?.cancel();
    _current = session;
    if (session != null) {
      _timer = Timer(session.expiresAt.difference(now().toUtc()), () {
        unawaited(_clear(needsSignIn: true).catchError((Object _) {}));
      });
    }
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    _timer?.cancel();
    super.dispose();
  }
}
