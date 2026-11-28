# Favoritos de Quality: integración y pruebas

Base: `ApuntesUCT(2).zip`, suministrado como main. Esta rama se compila sin los PR pendientes de aprobación/rechazo y reportes. No implementa sus endpoints. Se conserva el contrato de favoritos de S3-04.

## 1. Flujo

1. Gateway enruta `/api/v1/quality` hacia Quality.
2. Quality consulta la identidad propia mediante el Bearer original en `GET /api/v1/auth/access-context`. Auth verifica el JWT con su mecanismo existente y lee actividad, rol y tokenVersion en su propia base. No se aceptan x-user-id/x-role como identidad. Todos los roles activos pueden gestionar exclusivamente sus favoritos.
3. PUT consulta el detalle público de Material por REST. Sólo PUBLISHED permite continuar; oculto/inexistente devuelve 404, incluso si ya estaba guardado. En una transacción local, un bloqueo por usuario/material serializa PUT/DELETE. Se conserva la restricción única existente. Nuevo: 201; existente: 200, mismo id/createdAt.
4. GET pagina las relaciones propias y cuenta todas, incluso las no disponibles, con RepeatableRead. Sólo comprueba la página solicitada en Material, con cuatro consultas simultáneas como máximo. El orden se conserva: createdAt DESC, id DESC.
5. Material 404 produce available=false. HTTP 200 exige id correcto y status=PUBLISHED; una respuesta inconsistente es 502. Fallos de red/servicio/plazo son 503. No se sirve una página parcial ni una copia antigua y no se inventa available=false ante errores.
6. DELETE elimina exclusivamente la relación del usuario autenticado. Devuelve 204 aunque no exista y no consulta Material. Funciona si éste está caído o el material fue ocultado/eliminado.

Cada FavoriteDto contiene únicamente `{id, materialId, createdAt, available}`. No se devuelven título, URL, estado privado, archivo, storageKey ni userId. Para mostrar información de un available=true la UI consulta el detalle público de Material y debe tolerar un 404 posterior. Se permite guardar material propio.

| Método y ruta | Cuerpo | Resultado |
| --- | --- | --- |
| PUT /api/v1/quality/materials/{materialId}/favorite | Ninguno | 201/200 FavoriteDto; oculto/inexistente 404 |
| GET /api/v1/quality/favorites/me?page=1&pageSize=20 | Ninguno | 200 FavoritePageDto |
| DELETE /api/v1/quality/materials/{materialId}/favorite | Ninguno | 204 sin cuerpo |

No se exige Idempotency-Key: idempotencia por recurso propio. No hay ruta para administrar favoritos ajenos. Query desconocida/repetida/vacía, UUID inválido o cuerpo en PUT/DELETE: 400. Sin autenticación/credencial revocada: 401; cuenta inactiva: 403. pageSize=1..100, page>=1 y offset<=2147483647. Todas las respuestas de estas rutas usan no-store.

La disponibilidad refleja cada comprobación autoritativa; no hay una transacción distribuida con Material ni una instantánea entre páginas. Un retiro posterior puede hacer que el siguiente detalle público devuelva 404.

## 2. Crear la rama y copiar archivos

Conserva primero cambios locales. Desde la raíz:

```powershell
git switch main
git pull --ff-only
git switch -c feat/quality-favorites
```

Copia el ZIP manteniendo rutas. NO lo copies encima de las ramas de los otros PR. Si main avanzó desde el ZIP base, combina los archivos afectados en vez de sobrescribir cambios del equipo.

`ARCHIVOS_MODIFICADOS.json` y `LEER_PRIMERO.txt` son informativos: no necesitan commit.

## 3. Archivos y responsabilidades

| Archivo o grupo | Cambio |
| --- | --- |
| quality-service/src/favorites/favorite.controller.ts | Tres endpoints, validación de entrada, HTTP y Swagger |
| favorite.service.ts | Persistencia propia, idempotencia, transacciones y paginación |
| favorite-contract.ts | UUID, rangos y rechazo de parámetros/cuerpo no permitidos |
| favorite-dependencies.ts | Consulta REST de identidad y disponibilidad, timeouts, sin SQL externo |
| favorite.guard.ts | Identidad actual del solicitante en todas las rutas |
| favorite-error.filter.ts | ErrorDto sanitizado, WWW-Authenticate y no-store; conserva salud existente |
| favorite-openapi.ts | Esquemas de respuesta acordados |
| favorites.module.ts | Registro de los componentes |
| quality.module.ts y setup-app.ts | Integración del módulo, filtro y Bearer Swagger |
| favorite-*.spec.ts | Validaciones, fallos de dependencias y concurrencia/plazo del listado |
| backend/test/quality-favorites.integration.cjs | PostgreSQL y HTTP reales, aislamiento, visibilidad, carreras y errores |
| Auth access-context.controller.ts y su prueba | Consulta de identidad vigente propia |
| Auth access-token.service.ts, login.service.ts y password-recovery.service.ts | Emisión y revocación por tokenVersion |
| Auth schema.prisma y 20261127000000_access_token_version | Columna de revocación, default 0 |
| Auth auth.module.ts y pruebas afectadas | Registro del controlador y regresiones |
| Gateway proxy.module.ts, pruebas y api-docs.ts | Enrutamiento Quality y actualización de pruebas/documentación |
| .env.example de Quality/Gateway | Orígenes de servicios, sin secretos |
| backend/package.json | Comando test:favorites |
| .github/workflows/pr-tests.yml | Trabajo de integración de favoritos con PostgreSQL temporal |

No se modifica código ni esquema de Material. No se añade una migración de Quality: Favorite y su unique(materialId,userId) ya existen en main. No se requieren dependencias npm nuevas.

### Coincidencias con los otros PR

Auth y el proxy son infraestructura común. La migración tokenVersion tiene exactamente el mismo nombre/contenido que los paquetes anteriores. Al integrar las ramas debe quedar UNA copia: no renombrarla para crear otra columna ni volver a ejecutar SQL manualmente. El endpoint access-context coincide con el de reportes y no debe duplicarse.

En Quality conservar FavoritesModule, ReportsModule y el módulo de moderación cuando correspondan. Combinar setup-app y el manejo de errores sin eliminar los registros de las otras funcionalidades. Mantener una sola ruta proxy Quality, combinar scripts test:favorites/test:reports/test:moderation y conservar los tres trabajos CI. Esas combinaciones requieren repetir sus suites después del merge/rebase.

## 4. Compilar y probar (PowerShell)

Desde `backend`:

```powershell
npm ci
npm run prisma:generate --workspace=auth-service --workspace=material-service --workspace=quality-service
npm run build --workspace=auth-service --workspace=material-service --workspace=quality-service --workspace=api-gateway
```

Levanta tus bases PostgreSQL de desarrollo/pruebas. Si en ESTA terminal todavía tienes configuradas las conexiones reales de reportes, puedes reutilizarlas sin volver a escribir credenciales:

```powershell
$env:FAVORITES_TEST_AUTH_DATABASE_URL = $env:REPORTS_TEST_AUTH_DATABASE_URL
$env:FAVORITES_TEST_MATERIAL_DATABASE_URL = $env:REPORTS_TEST_MATERIAL_DATABASE_URL
$env:FAVORITES_TEST_QUALITY_DATABASE_URL = $env:REPORTS_TEST_QUALITY_DATABASE_URL
```

Si no existen, asigna a FAVORITES_TEST_AUTH_DATABASE_URL, FAVORITES_TEST_MATERIAL_DATABASE_URL y FAVORITES_TEST_QUALITY_DATABASE_URL las DATABASE_URL reales de cada servicio. Las bases deben llamarse auth_db, material_db y quality_db. Usa los puertos PostgreSQL publicados al host, no los HTTP 3001/3003/3004. No pegues marcadores como `<puerto>` literalmente ni compartas credenciales.

Verifica sólo que existan, sin imprimir sus valores:

```powershell
'FAVORITES_TEST_AUTH_DATABASE_URL','FAVORITES_TEST_MATERIAL_DATABASE_URL','FAVORITES_TEST_QUALITY_DATABASE_URL' | ForEach-Object {
  if (-not [Environment]::GetEnvironmentVariable($_)) { throw "Falta configurar $_" }
}
npm run test:favorites
```

La prueba crea esquemas únicos `favorites_test_*`, aplica migraciones allí, genera claves RSA y usuarios temporales, inicia los cuatro servicios HTTP en puertos libres y limpia al terminar. No requiere cuentas manuales ni endpoints del PR de moderación. Usa LINK y no interviene MinIO. No equivale a un despliegue completo Docker/UI.

Después:

```powershell
npm run test:ci --workspace=quality-service --workspace=auth-service --workspace=api-gateway
npm run test:e2e --workspace=quality-service --workspace=api-gateway -- --runInBand
npm run lint --workspace=quality-service --workspace=auth-service --workspace=api-gateway
$env:QUALITY_TEST_DATABASE_URL = $env:FAVORITES_TEST_QUALITY_DATABASE_URL
npm run test:integration --workspace=quality-service
npm run test:api-docs
cd ..
node scripts/validate-quality-contracts.cjs
git diff --check
```

La suite E2E de Auth también debe comprobarse con su base de desarrollo migrada. Las pruebas temporales NO actualizan el esquema public de los .env.

## 5. Configuración local y migraciones

Auth conserva su configuración real de JWT y debe tener aplicada `20261127000000_access_token_version`. Quality conserva su esquema existente. Desde backend, con cada .env apuntando a su propia base y sin una DATABASE_URL global que las sobrescriba:

```powershell
npm run prisma:deploy --workspace=auth-service
npm run prisma:deploy --workspace=quality-service
npm run prisma:generate --workspace=auth-service --workspace=quality-service
```

Si Auth ya tiene esa migración registrada, deploy no la repite. P2022 token_version indica base no migrada o conexión equivocada. P3005 indica que hay que comparar el esquema existente y su historial antes de establecer un baseline. No usar migrate reset ni resolver todas las migraciones como aplicadas sin comprobar sus efectos.

En `.env` de Quality:

```dotenv
QUALITY_FAVORITES_AUTH_URL=http://127.0.0.1:3001
QUALITY_FAVORITES_MATERIAL_URL=http://127.0.0.1:3003
```

En Gateway: `QUALITY_SERVICE_URL=http://127.0.0.1:3004`. En Docker, usa los nombres de red de los servicios. Son orígenes sin ruta, query ni credenciales; HTTPS es obligatorio en producción para las dependencias de favoritos. No se sigue redirecciones con el Bearer. Un origen ausente/inválido devuelve 503 cuando se necesita.

La consulta a Auth y cada consulta a Material tienen timeout de 1500 ms. El conjunto de comprobaciones de una página tiene un plazo de 2500 ms y concurrencia máxima cuatro. El plazo total evita acumular consultas lentas; el listado falla con 503 en vez de devolver resultados incompletos. Conservar la semántica de fallo cerrado al ajustar esos límites en una tarea posterior.

Arranca Auth, Material, Quality y Gateway, cada uno en su terminal desde backend:

```powershell
npm run start:dev --workspace=auth-service
npm run start:dev --workspace=material-service
npm run start:dev --workspace=quality-service
npm run start:dev --workspace=api-gateway
```

Para preparar recursos en la UI, conserva también las dependencias habituales del proyecto. La prueba automática prepara materiales publicados como fixtures; esta tarea no implementa una ruta de publicación.

## 6. Comprobación manual

Usa una cuenta activa y un material PUBLISHED real de desarrollo. Inicia sesión sin escribir la contraseña en el historial:

```powershell
$base = 'http://localhost:3000/api/v1/quality'
$cred = Get-Credential -Message 'Cuenta de pruebas'
$login = @{email=$cred.UserName; password=$cred.GetNetworkCredential().Password} | ConvertTo-Json
$sesion = Invoke-RestMethod -Method Post -Uri 'http://localhost:3000/api/v1/auth/login' -ContentType 'application/json' -Body $login
$login = $null
$headers = @{Authorization="Bearer $($sesion.accessToken)"}
$materialId = 'REEMPLAZAR_POR_UUID_REAL_PUBLICADO'
Invoke-RestMethod -Method Put -Uri "$base/materials/$materialId/favorite" -Headers $headers
# Repetir debe conservar id y createdAt; no enviar body ni Idempotency-Key.
Invoke-RestMethod -Method Put -Uri "$base/materials/$materialId/favorite" -Headers $headers
Invoke-RestMethod -Uri "$base/favorites/me?page=1&pageSize=20" -Headers $headers
Invoke-RestMethod -Method Delete -Uri "$base/materials/$materialId/favorite" -Headers $headers
Invoke-RestMethod -Method Delete -Uri "$base/materials/$materialId/favorite" -Headers $headers
```

Para ver códigos HTTP puede utilizarse Postman o Invoke-WebRequest. Esperados: PUT nuevo 201, repetido 200; DELETE siempre 204 tras autenticar y validar UUID. Otra cuenta no ve ni borra esa relación. Un recurso oculto/inexistente no se puede agregar; si se oculta después de guardarlo, sigue listado sólo como referencia con available=false. No se altera Material.

La integración automática ya cubre esos casos, también con Material/Auth caídos y solicitudes concurrentes. Una prueba manual verifica la configuración habitual del entorno, no sustituye la automatizada.

## 7. PR y cierre

Adjuntar comandos/resultados y commit probado, sin credenciales. Revisar el perfil de identidad compartido con Auth y la integración de archivos comunes al aprobar las ramas. El workflow se ejecuta al abrir/actualizar PR; su éxito remoto está pendiente hasta verlo en GitHub. La tarea se cierra tras checks y revisión, no por copiar el ZIP.
