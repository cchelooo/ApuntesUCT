/// Configuración de entorno de la aplicación móvil.
///
/// Los valores se inyectan en tiempo de compilación mediante `--dart-define`,
/// de modo que el mismo código apunta a distintos entornos sin recompilaciones
/// manuales ni credenciales incrustadas en el repositorio:
///
/// ```bash
/// # Emulador Android (localhost del host se expone como 10.0.2.2)
/// flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1
///
/// # Dispositivo físico en la misma red
/// flutter run --dart-define=API_BASE_URL=http://<ip-del-equipo>:3000/api/v1
/// ```
///
/// El cliente sólo conoce la URL del API Gateway. Nunca las direcciones de los
/// microservicios internos (RNF-01).
abstract final class AppConfig {
  /// URL base del API Gateway que expone la API pública REST/JSON.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000/api/v1',
  );

  /// Tiempo máximo para establecer la conexión TCP/TLS.
  static const Duration connectTimeout = Duration(
    milliseconds: int.fromEnvironment(
      'API_CONNECT_TIMEOUT_MS',
      defaultValue: 10000,
    ),
  );

  /// Tiempo máximo de espera de la respuesta una vez enviada la petición.
  ///
  /// El objetivo de rendimiento del MVP es 2 s para consultas habituales
  /// (RNF-02); el timeout se fija por sobre ese objetivo para no cortar
  /// peticiones legítimas en redes lentas.
  static const Duration receiveTimeout = Duration(
    milliseconds: int.fromEnvironment(
      'API_RECEIVE_TIMEOUT_MS',
      defaultValue: 15000,
    ),
  );

  /// Tiempo máximo para enviar el cuerpo de la petición.
  static const Duration sendTimeout = Duration(
    milliseconds: int.fromEnvironment(
      'API_SEND_TIMEOUT_MS',
      defaultValue: 15000,
    ),
  );

  /// Habilita el registro de peticiones en consola. Sólo para desarrollo.
  static const bool enableHttpLogs = bool.fromEnvironment(
    'API_HTTP_LOGS',
    defaultValue: false,
  );

  /// Selecciona el origen de datos de autenticación.
  ///
  /// Por defecto la app usa el repositorio mock, porque Auth Service todavía no
  /// está desplegado. Con la bandera activa consume la API real:
  ///
  /// ```bash
  /// flutter run --dart-define=USE_REMOTE_API=true --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1
  /// ```
  static const bool useRemoteApi = bool.fromEnvironment(
    'USE_REMOTE_API',
    defaultValue: false,
  );
}
