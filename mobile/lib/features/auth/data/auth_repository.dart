import '../../../models/user_model.dart';

/// Contrato de autenticación consumido por el estado global de la aplicación.
abstract interface class AuthRepository {
  Future<UserModel> login({required String email, required String password});

  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
  });

  Future<String> requestPasswordRecovery({required String email});

  Future<String> resetPassword({
    required String token,
    required String password,
  });

  Future<UserModel> getCurrentUser();

  Future<void> logout();
}
