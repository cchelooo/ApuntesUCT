import '../../../core/errors/api_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../models/user_model.dart';
import 'models/auth_models.dart';

/// Acceso tipado a los endpoints de autenticación del API Gateway.
///
/// Es la única clase que conoce las rutas de Auth. Todo lo demás trabaja con
/// los modelos de `models/`, de modo que un cambio de ruta o de contrato se
/// resuelve aquí y no se propaga a la UI.
class AuthApi {
  final ApiClient _client;

  const AuthApi(this._client);

  /// Rutas relativas a la URL base configurada en `AppConfig.apiBaseUrl`.
  static const String loginPath = '/auth/login';
  static const String registerPath = '/auth/register';
  static const String currentUserPath = '/auth/me';
  static const String logoutPath = '/auth/logout';

  /// `POST /auth/login` — autentica al usuario y abre sesión.
  ///
  /// Guarda los tokens recibidos, de modo que las peticiones siguientes salgan
  /// autenticadas sin que el llamador tenga que hacer nada.
  ///
  /// Lanza [UnauthorizedException] si las credenciales no son válidas y
  /// [ValidationException] si el cuerpo no pasa la validación del backend.
  Future<LoginResponseModel> login(LoginRequestModel request) async {
    final json = await _client.postJson(loginPath, data: request.toJson());
    final response = _parse(() => LoginResponseModel.fromJson(json), loginPath);

    _client.tokenStore.save(
      accessToken: response.tokens.accessToken,
      refreshToken: response.tokens.refreshToken,
    );
    return response;
  }

  /// `POST /auth/register` — crea la cuenta institucional.
  ///
  /// Si el backend devuelve tokens, la sesión queda abierta de inmediato.
  ///
  /// Lanza [ConflictException] si el correo ya está registrado.
  Future<RegisterResponseModel> register(RegisterRequestModel request) async {
    final json = await _client.postJson(registerPath, data: request.toJson());
    final response = _parse(
      () => RegisterResponseModel.fromJson(json),
      registerPath,
    );

    final tokens = response.tokens;
    if (tokens != null) {
      _client.tokenStore.save(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );
    }
    return response;
  }

  /// `GET /auth/me` — devuelve el usuario de la sesión vigente.
  ///
  /// Requiere token: sirve para restaurar la sesión al abrir la app y para
  /// comprobar que el interceptor está enviando el header `Authorization`.
  Future<UserModel> currentUser() async {
    final json = await _client.getJson(currentUserPath);
    final rawUser = json['user'] is Map
        ? Map<String, dynamic>.from(json['user'] as Map)
        : json;
    return _parse(() => UserModel.fromJson(rawUser), currentUserPath);
  }

  /// `POST /auth/logout` — cierra la sesión en el backend.
  ///
  /// El token local se descarta pase lo que pase: si el servidor no responde,
  /// dejar la sesión abierta en el dispositivo sería peor que perder la
  /// invalidación remota.
  Future<void> logout() async {
    try {
      await _client.postNoContent(logoutPath);
    } finally {
      _client.tokenStore.clear();
    }
  }

  /// Ejecuta un `fromJson` traduciendo un formato inesperado a [ApiException].
  ///
  /// Sin esto, un cambio de contrato del backend llegaría a la UI como un
  /// `TypeError` crudo en lugar de un mensaje accionable.
  T _parse<T>(T Function() body, String path) {
    try {
      return body();
    } on FormatException catch (e) {
      throw UnexpectedApiException(
        'La respuesta de $path no tiene el formato esperado: ${e.message}',
      );
    } on TypeError {
      throw UnexpectedApiException(
        'La respuesta de $path no tiene el formato esperado.',
      );
    }
  }
}
