import '../../../core/errors/api_exception.dart';
import '../../../models/user_model.dart';
import 'auth_api.dart';
import 'mock_auth_repository.dart' show AuthRepository;
import 'models/auth_models.dart';

/// Implementación de [AuthRepository] contra la API real del API Gateway.
///
/// Es el adaptador entre el contrato de dominio, que trabaja con [UserModel], y
/// [AuthApi], que trabaja con los modelos de respuesta completos. Los tokens no
/// cruzan esta frontera: [AuthApi] los deja en el `TokenStore` y el interceptor
/// los adjunta solo. Así la capa de presentación nunca manipula un JWT.
///
/// Es intercambiable con `MockAuthRepository`: ambas cumplen el mismo contrato,
/// y la app elige una u otra según la bandera `USE_REMOTE_API`.
class RemoteAuthRepository implements AuthRepository {
  final AuthApi _api;

  const RemoteAuthRepository(this._api);

  @override
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final response = await _api.login(
      LoginRequestModel(email: email, password: password),
    );
    return response.user;
  }

  @override
  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await _api.register(
      RegisterRequestModel(name: name, email: email, password: password),
    );

    // Si el backend no abrió sesión, el registro fue exitoso pero el usuario
    // aún no está autenticado; la UI debe pedir login.
    if (!response.hasSession) {
      throw const RequiresVerificationException(
        'Cuenta creada. Inicia sesión para continuar.',
      );
    }

    return response.user;
  }

  @override
  Future<UserModel> getCurrentUser() => _api.currentUser();

  @override
  Future<void> logout() => _api.logout();
}
