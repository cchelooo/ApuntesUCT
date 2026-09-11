import '../../../../models/user_model.dart';
import 'auth_tokens_model.dart';

/// Respuesta de `POST /auth/register`.
///
/// Los tokens son opcionales a propósito: el backend puede responder con sesión
/// iniciada (registro + login en un paso) o sólo con el usuario creado, si más
/// adelante se agrega confirmación de correo institucional. La UI consulta
/// [hasSession] para decidir si navega al Home o de vuelta a Login.
///
/// Formato esperado:
///
/// ```json
/// {
///   "user": {
///     "id": "22222222-2222-2222-2222-222222222222",
///     "name": "Camila Soto",
///     "email": "camila.soto@alu.uct.cl",
///     "role": "STUDENT",
///     "active": true
///   },
///   "accessToken": "eyJhbGciOi...",
///   "expiresIn": 3600
/// }
/// ```
class RegisterResponseModel {
  final UserModel user;
  final AuthTokensModel? tokens;

  const RegisterResponseModel({required this.user, this.tokens});

  /// Crea una instancia a partir del mapa JSON devuelto por la API.
  ///
  /// Acepta que el usuario venga bajo `user` o en la raíz del objeto, porque
  /// una API REST puede devolver directamente el recurso creado en un 201.
  factory RegisterResponseModel.fromJson(Map<String, dynamic> json) {
    final rawUser = json['user'] is Map
        ? Map<String, dynamic>.from(json['user'] as Map)
        : json;

    return RegisterResponseModel(
      user: UserModel.fromJson(rawUser),
      tokens: _parseTokens(json),
    );
  }

  /// Extrae los tokens sólo si la respuesta trae un `accessToken` utilizable.
  static AuthTokensModel? _parseTokens(Map<String, dynamic> json) {
    final source = json['tokens'] is Map
        ? Map<String, dynamic>.from(json['tokens'] as Map)
        : json;
    final accessToken = source['accessToken'];
    if (accessToken is! String || accessToken.isEmpty) return null;
    return AuthTokensModel.fromJson(source);
  }

  /// Indica si el registro dejó al usuario con sesión iniciada.
  bool get hasSession => tokens != null;

  /// Serializa el modelo a un mapa JSON.
  Map<String, dynamic> toJson() {
    return {'user': user.toJson(), if (tokens != null) ...tokens!.toJson()};
  }

  /// Factory para generar una instancia MOCK para pruebas de UI y estado.
  factory RegisterResponseModel.mock({
    UserModel? user,
    AuthTokensModel? tokens,
  }) {
    return RegisterResponseModel(
      user:
          user ??
          UserModel.mock(
            id: '22222222-2222-2222-2222-222222222222',
            name: 'Camila Soto',
            email: 'camila.soto@alu.uct.cl',
          ),
      tokens: tokens ?? AuthTokensModel.mock(),
    );
  }

  /// Permite crear una copia del modelo con ciertos campos modificados.
  RegisterResponseModel copyWith({UserModel? user, AuthTokensModel? tokens}) {
    return RegisterResponseModel(
      user: user ?? this.user,
      tokens: tokens ?? this.tokens,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RegisterResponseModel &&
          runtimeType == other.runtimeType &&
          user == other.user &&
          tokens == other.tokens;

  @override
  int get hashCode => user.hashCode ^ tokens.hashCode;

  @override
  String toString() => 'RegisterResponseModel(user: $user, tokens: $tokens)';
}
