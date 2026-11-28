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

## Validación reproducible de sesión

`flutter test` cubre rechazo y éxito, indicador de login pendiente, rutas
privadas, identidad en Perfil, logout, expiración, un 401 frente a 403/502,
restauración corrupta/vencida, aislamiento de Gateway, almacenamiento fallido y
resultados atrasados de login/subida. Son pruebas con transporte y plataforma
controlados; no acreditan una firma JWT de servidor.

Para comprobar la integración nativa sin cuentas ni bases compartidas:

1. Activar Docker y preparar Backend con `npm ci` y `npm run build`.
2. Desde Mobile ejecutar `node tool/start_gateway_smoke.cjs`.
3. Tomar del `fixture.json` la URL del Gateway y los cuatro identificadores
   generados: material, universidad, carrera y asignatura.
4. Ejecutar, usando la URL apropiada para el dispositivo:

```sh
flutter test integration_test/session_gateway_native_test.dart -d <device> \
  --dart-define=RUN_NATIVE_SESSION_SMOKE=true \
  --dart-define=API_GATEWAY_URL=<gateway> \
  --dart-define=EXPECTED_MATERIAL_ID=<materialId> \
  --dart-define=EXPECTED_UNIVERSITY_ID=<universityId> \
  --dart-define=EXPECTED_CAREER_ID=<careerId> \
  --dart-define=EXPECTED_SUBJECT_ID=<subjectId>
```

La URL del fixture ya incluye `/api/v1`: no agregar el prefijo dos veces.
El stack crea una cuenta sintética, claves RSA nuevas, PostgreSQL y MinIO
propios. Desactiva el autor local de Material: la creación y una nueva versión
necesitan la firma real y el autor de Auth. Una actualización directa en esa
base desechable publica el PDF de prueba; esto NO valida moderación de Quality.
`Ctrl+C` retira los contenedores y procesos y elimina la clave privada temporal.
El reporte conserva estados HTTP y referencias, nunca tokens ni contraseñas.

El 17-11-2026 se verificó este recorrido en simulador iOS 26.5 y emulador
Android: rechazo de credenciales, login RS256, versión autorizada en Material,
guardado nativo, restauración con un nuevo contenedor de aplicación, logout,
bloqueo de ruta privada y rechazo de una firma deliberadamente dañada con 401,
borrando también la sesión guardada. No se sustituyen repositorios, transporte
ni plugins en esta prueba. La entrada del reintento se fija en el controlador
del campo porque el canal de texto seguro del simulador retenía el valor previo;
no acredita el comportamiento del teclado físico ni una prueba en iPhone real.


## Subida, versionado y accesos rechazados (#400–#402)

La subida usa el cliente compartido y el JWT de la sesión. El formulario envía
el archivo o enlace y su clasificación. Material determina el autor a partir
del token. La confirmación requiere un 201 con un material en
`PENDING_REVIEW` y una respuesta que no esté marcada como simulada.

El versionado usa el mismo cliente. Se ofrece para el autor activo de un
material publicado con archivo, según el `uploaderId` que devuelve Material.
El servidor vuelve a verificar la autoría. Un 201 actualiza el detalle y el
historial. Material aún no publica capacidades individuales para esta acción.

Un 401 que rechaza el token activo cierra esa sesión y muestra un aviso para
volver a iniciar sesión. Si la hoja de versión sigue abierta, se descarta el
archivo y se bloquea el envío. Un 403 informa la falta de permiso mientras
conserva la sesión. Ninguno de esos rechazos confirma que se creó un recurso.

El smoke nativo incluye creación de archivo y enlace, una versión por el
autor, rechazo 403 de otro usuario autenticado y rechazo 401 del JWT de
firma inválida. Moderación se verifica con transporte controlado en el
repositorio Quality y con el acceso directo sin sesión. La interfaz de
moderación y sus endpoints operativos siguen pendientes de integración.
