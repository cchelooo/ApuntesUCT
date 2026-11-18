# Sesión Mobile

El modo normal usa `POST /api/v1/auth/login` del Gateway. El usuario y el
access token de esa misma respuesta forman una sola sesión. El cliente revisa
estructura, identidad y vencimiento del JWT; la firma siempre la valida el
servidor. No existe verificación criptográfica local ni renovación automática.

`ApiClient` comparte `SessionController` con el estado de autenticación. Su
interceptor agrega Bearer solo dentro del origen y prefijo del Gateway, excluye
los endpoints públicos de Auth y cierra la sesión ante un 401 asociado al token
actual. Un 403 o una caída del servidor conservan la sesión. El cliente nativo
no sigue redirecciones HTTP automáticamente. No se registran cuerpos de login,
contraseñas ni credenciales en los logs de Dio.

`AUTH_DEMO_MODE=true` es una demostración explícita: no obtiene una credencial
real. Un error de red o una respuesta de Auth inválida nunca activa ese modo.
El registro real crea la cuenta y vuelve a Login; su respuesta no inicia sesión.
Auth todavía no publica logout remoto, refresh ni consulta del usuario actual:
el logout elimina la sesión local y el usuario actual proviene del login.

Las rutas de perfil, inicio, biblioteca, favoritos y subida requieren sesión.
Durante la restauración se muestra una espera, sin abrir contenido privado.
Los datos de cursos, estadísticas, insignias y edición de perfil siguen siendo
la preparación de UI existente; el nombre del usuario sí viene de Auth.

Pruebas: `flutter analyze` y `flutter test`. Los JWT de
`test/helpers/auth_session_fixture.dart` son datos controlados sin firma válida:
prueban comportamiento del cliente, no autenticación contra un servidor real.

## Persistencia nativa

Android e iOS guardan una única sesión mediante `flutter_secure_storage`;
Android tiene desactivado el backup de la app e iOS declara el acceso a Keychain
con accesibilidad limitada al dispositivo desbloqueado. La clave incluye el
Gateway para aislar entornos. No se guardan contraseñas ni refresh tokens.
En Web la sesión se conserva solo en memoria y requiere login al recargar.

Al arrancar, el estado permanece en espera mientras lee el almacenamiento.
Los valores corruptos, incompletos o vencidos se eliminan. Si falla leer,
guardar o confirmar el guardado, no se habilita una sesión nueva en memoria.
Logout borra únicamente la clave de sesión y limpia inmediatamente la memoria;
un fallo de borrado se comunica como error, nunca como confirmación de borrado.
Un dispositivo bloqueado puede impedir operar con Keychain: hay que desbloquearlo
y reintentar. No se promete revocar el JWT en el servidor, pues Auth no dispone
de ese endpoint.

Subida, versiones y resultado de descarga se reinician al cambiar de identidad.
Sus respuestas atrasadas no repueblan el estado de otra cuenta; no se borran
los archivos que el usuario ya descargó. Favoritos y perfil también reaccionan
al usuario activo. Los dobles de almacenamiento de `flutter_test_config.dart`
solo se aplican a pruebas unitarias/widgets, nunca a la app instalada.
