import '../../../models/user_model.dart';

/// Contrato de autenticación consumido por el estado global de la aplicación.
///
/// Las operaciones distintas de login siguen formando parte del contrato para
/// conservar el flujo mock existente mientras Backend las implementa.
abstract interface class AuthRepository {
  Future<UserModel> login({required String email, required String password});

  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
  });

  Future<UserModel> getCurrentUser();

  Future<void> logout();
}
