/// Modelo inmutable con las credenciales de sesión emitidas por Auth Service.
///
/// Corresponde al par de tokens JWT que devuelve el API Gateway tras un login o
/// un registro exitoso. Se mantiene separado de [UserModel] porque tiene otro
/// ciclo de vida: el usuario cambia poco, el token expira y se renueva.
///
/// Nota de seguridad: este modelo no debe escribirse en logs ni serializarse a
/// almacenamiento no seguro. [toString] omite el valor de los tokens a propósito.
class AuthTokensModel {
  /// JWT que autoriza las peticiones a la API pública.
  final String accessToken;

  /// Token de larga duración para renovar el [accessToken] sin re-autenticar.
  final String? refreshToken;

  /// Esquema del header Authorization. La API usa `Bearer`.
  final String tokenType;

  /// Segundos de vigencia del [accessToken] desde su emisión.
  final int? expiresIn;

  const AuthTokensModel({
    required this.accessToken,
    this.refreshToken,
    this.tokenType = 'Bearer',
    this.expiresIn,
  });

  /// Crea una instancia a partir del mapa JSON devuelto por la API.
  ///
  /// Acepta las dos formas que puede tomar la respuesta de autenticación:
  /// tokens al mismo nivel del objeto raíz, o anidados bajo `tokens`.
  factory AuthTokensModel.fromJson(Map<String, dynamic> json) {
    final source = json['tokens'] is Map
        ? Map<String, dynamic>.from(json['tokens'] as Map)
        : json;

    return AuthTokensModel(
      accessToken: source['accessToken'] as String,
      refreshToken: source['refreshToken'] as String?,
      tokenType: source['tokenType'] as String? ?? 'Bearer',
      expiresIn: (source['expiresIn'] as num?)?.toInt(),
    );
  }

  /// Serializa el modelo a un mapa JSON.
  Map<String, dynamic> toJson() {
    return {
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'tokenType': tokenType,
      'expiresIn': expiresIn,
    };
  }

  /// Valor listo para el header `Authorization` de las peticiones autenticadas.
  String get authorizationHeader => '$tokenType $accessToken';

  /// Factory para generar una instancia MOCK para pruebas de UI y estado.
  factory AuthTokensModel.mock({
    String accessToken = 'mock.access.token',
    String? refreshToken = 'mock.refresh.token',
    String tokenType = 'Bearer',
    int? expiresIn = 3600,
  }) {
    return AuthTokensModel(
      accessToken: accessToken,
      refreshToken: refreshToken,
      tokenType: tokenType,
      expiresIn: expiresIn,
    );
  }

  /// Permite crear una copia del modelo con ciertos campos modificados.
  AuthTokensModel copyWith({
    String? accessToken,
    String? refreshToken,
    String? tokenType,
    int? expiresIn,
  }) {
    return AuthTokensModel(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      tokenType: tokenType ?? this.tokenType,
      expiresIn: expiresIn ?? this.expiresIn,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthTokensModel &&
          runtimeType == other.runtimeType &&
          accessToken == other.accessToken &&
          refreshToken == other.refreshToken &&
          tokenType == other.tokenType &&
          expiresIn == other.expiresIn;

  @override
  int get hashCode =>
      accessToken.hashCode ^
      refreshToken.hashCode ^
      tokenType.hashCode ^
      expiresIn.hashCode;

  /// Representación segura: nunca expone el valor de los tokens.
  @override
  String toString() {
    return 'AuthTokensModel(tokenType: $tokenType, expiresIn: $expiresIn, '
        'accessToken: <oculto>, refreshToken: ${refreshToken == null ? 'null' : '<oculto>'})';
  }
}
