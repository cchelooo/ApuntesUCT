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
