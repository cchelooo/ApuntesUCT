import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/session/session_controller.dart';
import '../../../models/user_model.dart';
import 'auth_repository.dart';
import 'dio_auth_repository.dart';

export 'auth_repository.dart';

/// Implementación Mock de [AuthRepository] que simula latencia de red con [Future.delayed].
class MockAuthRepository implements AuthRepository {
  final Duration simulatedDelay;

  const MockAuthRepository({
    this.simulatedDelay = const Duration(milliseconds: 1000),
  });

  @override
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    // Simula el viaje por la red al API Gateway / Auth Service
    await Future.delayed(simulatedDelay);

    if (email.isEmpty || password.isEmpty) {
      throw Exception('Credenciales incompletas.');
    }

    if (password == 'error') {
      throw Exception('Credenciales inválidas (simulación de error 401).');
    }

    // Retorna usuario simulado exitoso
    return UserModel.mock(
      email: email,
      name: email.contains('@')
          ? email.split('@').first.replaceAll('.', '').toUpperCase()
          : 'Usuario Mock',
    );
  }

  @override
  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
  }) async {
    await Future.delayed(simulatedDelay);

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      throw Exception('Datos de registro incompletos.');
    }

    // Correo reservado para probar en la UI el caso "el correo ya existe".
    if (email.trim().toLowerCase() == 'registrado@uct.cl') {
      throw Exception(
        'El correo ya está registrado (simulación de error 409).',
      );
    }

    // El mock abre sesión de inmediato con la cuenta recién creada.
    return UserModel.mock(name: name, email: email);
  }

  @override
  Future<UserModel> getCurrentUser() async {
    await Future.delayed(simulatedDelay);
    return UserModel.mock();
  }

  @override
  Future<void> logout() async {
    await Future.delayed(simulatedDelay);
  }
}

/// Provider de autenticación usado por Login, Registro y Logout.
///
/// En modo normal las operaciones consumen el contrato real de Auth por Gateway.
/// El mock solo se activa explícitamente mediante AUTH_DEMO_MODE.
///
/// Para demostraciones sin Backend se puede ejecutar Mobile con
/// `--dart-define=AUTH_DEMO_MODE=true`. El modo normal sigue usando Dio para que
/// una caída del Gateway no quede oculta durante el desarrollo de integración.
final authDemoModeProvider = Provider<bool>((ref) {
  return const bool.fromEnvironment('AUTH_DEMO_MODE', defaultValue: false);
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (ref.watch(authDemoModeProvider)) {
    return const MockAuthRepository();
  }

  final apiClient = ref.watch(apiclientProvider);
  return DioAuthRepository(apiClient);
});

/// AsyncNotifier para gestionar el estado del usuario autenticado (Riverpod 3.x).
/// Se utiliza `AsyncValue<UserModel?>` para manejar de forma reactiva:
/// - Loading (cargando)
/// - Data (usuario logueado o null si no hay sesión)
/// - Error (fallo de red o credenciales incorrectas)
class AuthStateNotifier extends AsyncNotifier<UserModel?> {
  int _operation = 0;

  @override
  Future<UserModel?> build() async {
    if (ref.watch(authDemoModeProvider)) return null;
    final session = ref.watch(sessionControllerProvider);
    void changed() {
      if (!ref.mounted) return;
      final user = session.current?.user;
      // beginLogin clears the old identity; keep the pending login indicator.
      if (state.isLoading && user == null) return;
      state = AsyncData(user);
    }

    session.addListener(changed);
    ref.onDispose(() => session.removeListener(changed));
    await session.restore();
    return session.current?.user;
  }

  Future<void> login(String email, String password) async {
    final operation = ++_operation;
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref
          .read(authRepositoryProvider)
          .login(email: email, password: password),
    );
    if (ref.mounted && operation == _operation) state = result;
  }

  Future<void> register(String name, String email, String password) async {
    final operation = ++_operation;
    state = const AsyncLoading();
    final repository = ref.read(authRepositoryProvider);
    final result = await AsyncValue.guard(
      () => repository.register(name: name, email: email, password: password),
    );
    if (!ref.mounted || operation != _operation) return;
    // Registration returns a user, not an authenticated session.
    state = repository is DioAuthRepository && !result.hasError
        ? const AsyncData(null)
        : result;
  }

  Future<void> logout() async {
    ++_operation;
    final repository = ref.read(authRepositoryProvider);
    final cleanup = repository.logout();
    // Clear the UI immediately, including repositories substituted in tests/demo.
    state = const AsyncData(null);
    await cleanup;
  }
}

final authStateProvider = AsyncNotifierProvider<AuthStateNotifier, UserModel?>(
  AuthStateNotifier.new,
);
