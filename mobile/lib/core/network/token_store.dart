/// Almacén del token de sesión vigente.
///
/// Se mantiene en memoria de forma deliberada: el alcance del Sprint 1 es
/// validar el flujo de autenticación contra la API, no la persistencia de
/// sesión. Al cerrar la app la sesión se pierde y el usuario vuelve a Login.
///
/// Pendiente para el sprint siguiente: respaldar el token en almacenamiento
/// seguro del dispositivo (flutter_secure_storage, Keychain/Keystore) para
/// soportar "mantener sesión iniciada". Ese cambio sólo debe tocar esta clase:
/// el resto de la app depende de la interfaz, no del medio de almacenamiento.
class TokenStore {
  String? _accessToken;
  String? _refreshToken;

  /// Token de acceso que el interceptor adjunta como Bearer en cada petición.
  String? get accessToken => _accessToken;

  /// Token de refresco, reservado para la renovación automática de sesión.
  String? get refreshToken => _refreshToken;

  /// Indica si hay una sesión activa en memoria.
  bool get hasSession => _accessToken != null && _accessToken!.isNotEmpty;

  /// Guarda los tokens recibidos tras un login o un registro exitoso.
  void save({required String accessToken, String? refreshToken}) {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
  }

  /// Borra la sesión en memoria. Se invoca al cerrar sesión y ante un 401.
  void clear() {
    _accessToken = null;
    _refreshToken = null;
  }
}
