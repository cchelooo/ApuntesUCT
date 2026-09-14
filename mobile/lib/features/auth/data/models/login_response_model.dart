import '../../../../models/user_model.dart';
import 'auth_tokens_model.dart';

/// Respuesta de `POST /auth/login`.
///
/// Une las dos piezas que devuelve Auth Service en un login exitoso: el usuario
/// autenticado y las credenciales de sesión.
///
/// Formato esperado (tokens planos o anidados bajo `tokens`):
///
/// ```json
/// {
///   "accessToken": "eyJhbGciOi...",
///   "refreshToken": "eyJhbGciOi...",
///   "tokenType": "Bearer",
///   "expiresIn": 3600,
///   "user": {
///     "id": "a8098c1a-f86e-11da-bd1a-00112444be1e",
///     "name": "Marcelo Henríquez",
///     "email": "marcelo.henriquez@uct.cl",
///     "role": "STUDENT",
///     "active": true
///   }
/// }
/// ```
class LoginResponseModel {
  final AuthTokensModel tokens;
  final UserModel user;

  const LoginResponseModel({required this.tokens, required this.user});

  /// Crea una instancia a partir del mapa JSON devuelto por la API.
  ///
  /// Acepta que el usuario venga bajo `user` o bajo `profile`, porque el
  /// contrato OpenAPI todavía no está publicado por INT2 y ambos nombres están
  /// en discusión. Si llega cualquier otra forma, falla de inmediato en vez de
  /// devolver un usuario a medias.
  factory LoginResponseModel.fromJson(Map<String, dynamic> json) {
    final rawUser = json['user'] ?? json['profile'];
    if (rawUser is! Map) {
      throw const FormatException(
        'La respuesta de login no incluye el objeto "user".',
      );
    }

    return LoginResponseModel(
      tokens: AuthTokensModel.fromJson(json),
      user: UserModel.fromJson(Map<String, dynamic>.from(rawUser)),
    );
  }

  /// Serializa el modelo a un mapa JSON.
  Map<String, dynamic> toJson() {
    return {...tokens.toJson(), 'user': user.toJson()};
  }

  /// Factory para generar una instancia MOCK para pruebas de UI y estado.
  factory LoginResponseModel.mock({AuthTokensModel? tokens, UserModel? user}) {
    return LoginResponseModel(
      tokens: tokens ?? AuthTokensModel.mock(),
      user: user ?? UserModel.mock(),
    );
  }

  /// Permite crear una copia del modelo con ciertos campos modificados.
  LoginResponseModel copyWith({AuthTokensModel? tokens, UserModel? user}) {
    return LoginResponseModel(
      tokens: tokens ?? this.tokens,
      user: user ?? this.user,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoginResponseModel &&
          runtimeType == other.runtimeType &&
          tokens == other.tokens &&
          user == other.user;

  @override
  int get hashCode => tokens.hashCode ^ user.hashCode;

  @override
  String toString() => 'LoginResponseModel(user: $user, tokens: $tokens)';
}
