import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/user_model.dart';

/// Contrato abstracto para autenticación (preparado para integración real futura).
abstract class AuthRepository {
  Future<UserModel> login({required String email, required String password});

  /// Crea una cuenta institucional y devuelve el usuario resultante.
  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
  });

  Future<UserModel> getCurrentUser();
  Future<void> logout();
}

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
          ? email.split('@').first.replaceAll('.', ' ').toUpperCase()
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

/// Provider para inyectar la instancia de [AuthRepository] en cualquier parte de la app.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return const MockAuthRepository();
});

/// AsyncNotifier para gestionar el estado del usuario autenticado (Riverpod 3.x).
/// Se utiliza `AsyncValue<UserModel?>` para manejar de forma reactiva:
/// - Loading (cargando)
/// - Data (usuario logueado o null si no hay sesión)
/// - Error (fallo de red o credenciales incorrectas)
class AuthStateNotifier extends AsyncNotifier<UserModel?> {
  @override
  Future<UserModel?> build() async {
    // Inicialmente no hay usuario en sesión
    return null;
  }

  /// Ejecuta login asíncrono actualizando el estado de Riverpod
  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(authRepositoryProvider);
      return await repository.login(email: email, password: password);
    });
  }

  /// Registra una cuenta nueva y deja al usuario con sesión iniciada
  Future<void> register(String name, String email, String password) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(authRepositoryProvider);
      return await repository.register(
        name: name,
        email: email,
        password: password,
      );
    });
  }

  /// Cierra la sesión
  Future<void> logout() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(authRepositoryProvider);
      await repository.logout();
      return null;
    });
  }
}

/// Provider global reactivo del estado de autenticación con Notifier moderno
final authStateProvider = AsyncNotifierProvider<AuthStateNotifier, UserModel?>(
  AuthStateNotifier.new,
);
